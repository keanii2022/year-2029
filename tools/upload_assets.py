#!/usr/bin/env python3
"""Builds assets/manifest.json and src/shared/Logic/ManifestData.luau from art/, and uploads with --upload.

Dry run (default): walks art/, reads every model FBX for its part names, bounds and hinge points,
adds the MOVES.md notes, and rewrites both manifest files. Asset ids already in the manifest are kept.

Upload: python3 tools/upload_assets.py --upload
  needs env ROBLOX_API_KEY (Open Cloud key with asset read + write) and ROBLOX_CREATOR_ID (your user id).
  Resumable: anything that already has an id is skipped, and the manifest is saved after every upload.
  The key is only ever read from the environment and sent in the request header.

Python 3 stdlib only.
"""

import argparse
import json
import math
import os
import re
import shutil
import struct
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "art")
MANIFEST_JSON = os.path.join(ROOT, "assets", "manifest.json")
MANIFEST_LUAU = os.path.join(ROOT, "src", "shared", "Logic", "ManifestData.luau")

ASSETS_URL = "https://apis.roblox.com/assets/v1/assets"
OPERATIONS_URL = "https://apis.roblox.com/assets/v1/"
IMAGE_KINDS = {"posters": "poster", "posters/screens": "screen", "posters/scrawls": "scrawl"}


# ---------- FBX (binary, 7.x) ----------


def read_fbx(path):
    """Returns the top-level node list. Node = (name, props, children)."""
    with open(path, "rb") as f:
        data = f.read()
    if not data.startswith(b"Kaydara FBX Binary"):
        raise ValueError(f"{path}: not a binary FBX")
    version = struct.unpack_from("<I", data, 23)[0]
    header = "<QQQ" if version >= 7500 else "<III"
    header_size = struct.calcsize(header)
    scalar = {"Y": "<h", "C": "<?", "I": "<i", "F": "<f", "D": "<d", "L": "<q"}
    array = {"f": "f", "d": "d", "l": "q", "i": "i", "b": "?"}

    def node(pos):
        end, prop_count, _ = struct.unpack_from(header, data, pos)
        pos += header_size
        if end == 0:
            return None, pos
        name_len = data[pos]
        name = data[pos + 1 : pos + 1 + name_len].decode()
        pos += 1 + name_len
        props = []
        for _ in range(prop_count):
            kind = chr(data[pos])
            pos += 1
            if kind in scalar:
                props.append(struct.unpack_from(scalar[kind], data, pos)[0])
                pos += struct.calcsize(scalar[kind])
            elif kind in array:
                count, encoding, byte_len = struct.unpack_from("<III", data, pos)
                pos += 12
                raw = data[pos : pos + byte_len]
                pos += byte_len
                if encoding:
                    raw = zlib.decompress(raw)
                props.append(struct.unpack(f"<{count}{array[kind]}", raw))
            else:
                byte_len = struct.unpack_from("<I", data, pos)[0]
                pos += 4
                props.append(data[pos : pos + byte_len])
                pos += byte_len
        children = []
        while pos < end:
            child, pos = node(pos)
            if child is None:
                break
            children.append(child)
        return (name, props, children), end

    nodes, pos = [], 27
    while True:
        top, pos = node(pos)
        if top is None:
            break
        nodes.append(top)
    return nodes


def child(node, name):
    return next((c for c in node[2] if c[0] == name), None)


def object_name(raw):
    return raw.split(b"\x00")[0].decode()


def rotate_xyz(v, degrees):
    """FBX default euler order: X first, then Y, then Z."""
    x, y, z = v
    for axis, angle in enumerate(degrees):
        if not angle:
            continue
        c, s = math.cos(math.radians(angle)), math.sin(math.radians(angle))
        if axis == 0:
            y, z = y * c - z * s, y * s + z * c
        elif axis == 1:
            x, z = x * c + z * s, -x * s + z * c
        else:
            x, y = x * c - y * s, x * s + y * c
    return x, y, z


def model_parts(path):
    """Every mesh part in Roblox space (y up, studs): bounds center, size and pivot (the part's origin)."""
    nodes = {n[0]: n for n in read_fbx(path)}
    models, geometry_vertices = {}, {}
    for obj in nodes["Objects"][2]:
        if obj[0] == "Model":
            transform = {"Lcl Translation": (0, 0, 0), "Lcl Rotation": (0, 0, 0), "Lcl Scaling": (1, 1, 1)}
            props = child(obj, "Properties70")
            for p in props[2] if props else []:
                key = p[1][0].decode()
                if key in transform:
                    transform[key] = tuple(p[1][4:7])
            models[obj[1][0]] = (object_name(obj[1][1]), transform)
        elif obj[0] == "Geometry" and child(obj, "Vertices"):
            geometry_vertices[obj[1][0]] = child(obj, "Vertices")[1][0]

    parent_of, geometry_of = {}, {}
    for link in nodes["Connections"][2]:
        kind, source, target = link[1][0], link[1][1], link[1][2]
        if kind != b"OO":
            continue
        if source in models:
            parent_of[source] = target
        elif source in geometry_vertices and target in models:
            geometry_of[target] = source

    def to_world(model_id, point):
        while model_id in models:
            transform = models[model_id][1]
            sx, sy, sz = transform["Lcl Scaling"]
            point = rotate_xyz((point[0] * sx, point[1] * sy, point[2] * sz), transform["Lcl Rotation"])
            tx, ty, tz = transform["Lcl Translation"]
            point = (point[0] + tx, point[1] + ty, point[2] + tz)
            model_id = parent_of.get(model_id)
        return point

    parts = []
    for model_id, geometry_id in geometry_of.items():
        flat = geometry_vertices[geometry_id]
        points = [to_world(model_id, flat[i : i + 3]) for i in range(0, len(flat), 3)]
        low = [min(p[a] for p in points) for a in range(3)]
        high = [max(p[a] for p in points) for a in range(3)]
        parts.append(
            {
                "name": models[model_id][0],
                "center": [round((low[a] + high[a]) / 2, 3) for a in range(3)],
                "size": [round(high[a] - low[a], 3) for a in range(3)],
                "pivot": [round(c, 3) for c in to_world(model_id, (0, 0, 0))],
            }
        )
    parts.sort(key=lambda p: p["name"])
    return parts


def overall_size(parts):
    low = [min(p["center"][a] - p["size"][a] / 2 for p in parts) for a in range(3)]
    high = [max(p["center"][a] + p["size"][a] / 2 for p in parts) for a in range(3)]
    return [round(high[a] - low[a], 3) for a in range(3)]


# ---------- MOVES.md ----------


def expand_parts(cell):
    """'Door1 to Door3' -> Door1, Door2, Door3. 'Glow, Spin' -> Glow, Spin."""
    names = []
    for piece in (s.strip() for s in cell.split(",")):
        span = re.fullmatch(r"([A-Za-z]+)(\d+) to [A-Za-z]+(\d+)", piece)
        if span:
            names += [f"{span[1]}{i}" for i in range(int(span[2]), int(span[3]) + 1)]
        elif piece:
            names.append(piece)
    return names


def read_moves(model_names, gun_names):
    """{model: [{part, does}]} from the MOVES.md tables."""
    moves, unknown = {}, set()
    with open(os.path.join(ART, "MOVES.md"), encoding="utf-8") as f:
        for line in f:
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if not line.startswith("|") or len(cells) != 3 or cells[0] in ("Item", "") or set(cells[0]) <= {"-"}:
                continue
            item_cell, part_cell, does = cells
            items = sorted(gun_names) if item_cell == "every gun" else [s.strip() for s in item_cell.split(",")]
            for item in items:
                if item not in model_names:
                    unknown.add(item)
                    continue
                for part in expand_parts(part_cell):
                    moves.setdefault(item, []).append({"part": part, "does": does})
    return moves, unknown


# ---------- manifest ----------


def rel(path):
    return os.path.relpath(path, ROOT)


def build_manifest(old):
    old_models = {m["name"]: m for m in old.get("models", [])}
    old_sounds = {s["name"]: s for s in old.get("sounds", [])}
    old_images = {i["name"]: i for i in old.get("images", [])}

    models = []
    for group in sorted(os.listdir(ART)):
        group_dir = os.path.join(ART, group)
        if group.startswith((".", "_")) or group in ("sounds", "posters") or not os.path.isdir(group_dir):
            continue
        for name in sorted(os.listdir(group_dir)):
            fbx = os.path.join(group_dir, name, f"{name}.fbx")
            if not os.path.isfile(fbx):
                continue
            folder = os.path.dirname(fbx)
            texture = os.path.join(folder, f"{name}_color.png")
            screen = os.path.join(folder, "screen.png")
            anim = os.path.join(folder, "anim")
            parts = model_parts(fbx)
            previous = old_models.get(name, {})
            models.append(
                {
                    "name": name,
                    "group": group,
                    "fbx": rel(fbx),
                    "texture": rel(texture) if os.path.isfile(texture) else None,
                    "screen": rel(screen) if os.path.isfile(screen) else None,
                    "clips": sorted(f[:-4] for f in os.listdir(anim) if f.endswith(".fbx")) if os.path.isdir(anim) else [],
                    "size": overall_size(parts),
                    "parts": parts,
                    "moves": [],
                    "assetId": previous.get("assetId"),
                    "textureId": previous.get("textureId"),
                    "screenId": previous.get("screenId"),
                }
            )

    names = {m["name"] for m in models}
    guns = {m["name"] for m in models if {"Handle", "Mag"} <= {p["name"] for p in m["parts"]}}
    moves, unknown = read_moves(names, guns)
    for m in models:
        m["moves"] = moves.get(m["name"], [])

    sounds = []
    sound_dir = os.path.join(ART, "sounds")
    for folder, _, files in sorted(os.walk(sound_dir)):
        for file in sorted(files):
            if file.endswith(".mp3"):
                name = file[:-4]
                group = os.path.relpath(folder, sound_dir)
                sounds.append(
                    {
                        "name": name,
                        "group": "misc" if group == "." else group,
                        "file": rel(os.path.join(folder, file)),
                        "assetId": old_sounds.get(name, {}).get("assetId"),
                    }
                )
    sounds.sort(key=lambda s: (s["group"], s["name"]))

    images = []
    for sub, kind in IMAGE_KINDS.items():
        folder = os.path.join(ART, sub)
        for file in sorted(os.listdir(folder)):
            if file.endswith(".png"):
                name = file[:-4]
                images.append(
                    {
                        "name": name,
                        "kind": kind,
                        "file": rel(os.path.join(folder, file)),
                        "assetId": old_images.get(name, {}).get("assetId"),
                    }
                )

    for collection, label in ((models, "model"), (sounds, "sound"), (images, "image")):
        seen = set()
        for entry in collection:
            if entry["name"] in seen:
                sys.exit(f"duplicate {label} name: {entry['name']}")
            seen.add(entry["name"])

    return {"models": models, "sounds": sounds, "images": images}, unknown


# ---------- Luau output ----------


def luau(value, indent=0):
    pad, inner = "\t" * indent, "\t" * (indent + 1)
    if value is None:
        return "nil"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, list):
        if not value:
            return "{}"
        if all(isinstance(v, (int, float)) for v in value):
            return "{ " + ", ".join(repr(v) for v in value) + " }"
        return "{\n" + "".join(f"{inner}{luau(v, indent + 1)},\n" for v in value) + pad + "}"
    if isinstance(value, dict):
        fields = [(k, v) for k, v in value.items() if v is not None]
        if not fields:
            return "{}"
        return "{\n" + "".join(f"{inner}{k} = {luau(v, indent + 1)},\n" for k, v in fields) + pad + "}"
    raise TypeError(type(value))


def write_luau(manifest):
    """Only what the game needs at runtime: no file paths."""
    data = {
        "models": [
            {k: m[k] for k in ("name", "group", "size", "parts", "clips", "moves", "assetId", "textureId", "screenId")}
            for m in manifest["models"]
        ],
        "sounds": [{k: s[k] for k in ("name", "group", "assetId")} for s in manifest["sounds"]],
        "images": [{k: i[k] for k in ("name", "kind", "assetId")} for i in manifest["images"]],
    }
    body = (
        "-- Generated by tools/upload_assets.py from art/. Do not edit: rerun the script.\n"
        "-- Sizes and positions are studs in model space (y up, front faces +z). assetId is nil until uploaded.\n"
        f"return {luau(data)}\n"
    )
    with open(MANIFEST_LUAU, "w", encoding="utf-8") as f:
        f.write(body)
    # check.sh fails on unformatted Luau, so format the generated file when StyLua is around
    if shutil.which("stylua"):
        subprocess.run(["stylua", MANIFEST_LUAU], check=False)


def save(manifest):
    os.makedirs(os.path.dirname(MANIFEST_JSON), exist_ok=True)
    with open(MANIFEST_JSON, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=1, ensure_ascii=False)
        f.write("\n")
    write_luau(manifest)


# ---------- Open Cloud upload ----------

CONTENT_TYPES = {".fbx": "model/fbx", ".png": "image/png", ".mp3": "audio/mpeg"}
ASSET_TYPES = {".fbx": "Model", ".png": "Decal", ".mp3": "Audio"}


def request(method, url, api_key, body=None, content_type=None):
    """Retries rate limits and server hiccups with backoff."""
    headers = {"x-api-key": api_key}
    if content_type:
        headers["Content-Type"] = content_type
    for attempt in range(6):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, data=body, method=method, headers=headers), timeout=120) as r:
                return json.loads(r.read() or b"{}")
        except urllib.error.HTTPError as e:
            if e.code == 429 or e.code >= 500:
                wait = int(e.headers.get("Retry-After") or 0) or 2**attempt * 5
                print(f"  {e.code}, waiting {wait}s")
                time.sleep(wait)
                continue
            raise RuntimeError(f"{e.code} {e.read().decode(errors='replace')[:300]}") from None
    raise RuntimeError("gave up after repeated rate limits")


def upload_file(path, display_name, api_key, creator_id):
    ext = os.path.splitext(path)[1]
    meta = {
        "assetType": ASSET_TYPES[ext],
        "displayName": display_name[:50],
        "description": "Year 2029",
        "creationContext": {"creator": {"userId": str(creator_id)}},
    }
    with open(os.path.join(ROOT, path), "rb") as f:
        content = f.read()
    boundary = uuid.uuid4().hex
    body = b"".join(
        [
            f'--{boundary}\r\nContent-Disposition: form-data; name="request"\r\nContent-Type: application/json\r\n\r\n'.encode(),
            json.dumps(meta).encode(),
            f'\r\n--{boundary}\r\nContent-Disposition: form-data; name="fileContent"; filename="{os.path.basename(path)}"\r\n'.encode(),
            f"Content-Type: {CONTENT_TYPES[ext]}\r\n\r\n".encode(),
            content,
            f"\r\n--{boundary}--\r\n".encode(),
        ]
    )
    operation = request("POST", ASSETS_URL, api_key, body, f"multipart/form-data; boundary={boundary}")
    for _ in range(60):
        if operation.get("done"):
            if "error" in operation:
                raise RuntimeError(json.dumps(operation["error"])[:300])
            return int(operation["response"]["assetId"])
        time.sleep(2)
        operation = request("GET", OPERATIONS_URL + operation["path"], api_key)
    raise RuntimeError("operation never finished")


def upload_all(manifest):
    api_key = os.environ.get("ROBLOX_API_KEY")
    creator_id = os.environ.get("ROBLOX_CREATOR_ID")
    if not api_key or not creator_id:
        sys.exit("Set ROBLOX_API_KEY and ROBLOX_CREATOR_ID first.")

    jobs = []
    for m in manifest["models"]:
        jobs.append((m, "assetId", m["fbx"], m["name"]))
        if m["texture"]:
            jobs.append((m, "textureId", m["texture"], f"{m['name']}_color"))
        if m["screen"]:
            jobs.append((m, "screenId", m["screen"], f"{m['name']}_screen"))
    jobs += [(s, "assetId", s["file"], s["name"]) for s in manifest["sounds"]]
    jobs += [(i, "assetId", i["file"], i["name"]) for i in manifest["images"]]

    todo = [j for j in jobs if j[0][j[1]] is None]
    print(f"{len(jobs) - len(todo)} already uploaded, {len(todo)} to go")
    failed = 0
    for n, (entry, field, path, display_name) in enumerate(todo, 1):
        try:
            entry[field] = upload_file(path, display_name, api_key, creator_id)
            save(manifest)
            print(f"[{n}/{len(todo)}] {path} -> {entry[field]}")
        except (RuntimeError, OSError, KeyError, ValueError) as e:
            failed += 1
            print(f"[{n}/{len(todo)}] FAILED {path}: {e}")
    print(f"done, {failed} failed" + (" (rerun to retry them)" if failed else ""))


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--upload", action="store_true", help="upload everything without an asset id yet")
    args = parser.parse_args()

    old = {}
    if os.path.isfile(MANIFEST_JSON):
        with open(MANIFEST_JSON, encoding="utf-8") as f:
            old = json.load(f)
    manifest, unknown = build_manifest(old)
    save(manifest)
    print(
        f"manifest: {len(manifest['models'])} models, {len(manifest['sounds'])} sounds, {len(manifest['images'])} images"
    )
    if unknown:
        print(f"MOVES.md items with no model folder: {', '.join(sorted(unknown))}")
    if args.upload:
        upload_all(manifest)


if __name__ == "__main__":
    main()
