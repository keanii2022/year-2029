# Turns a one-piece model from Meshy (GLB or FBX) into the same moving parts as a model we already have.
# Every face goes to whichever part of the old model it sits closest to, the cut holes get capped,
# and each part's origin lands on the old part's joint, so the old rig, clips and code keep working.
# Run through run.sh from art/ (run.sh starts one Blender per name, so the old model is the only name):
#   MESHY=<new.glb> _kit/run.sh _kit/meshy_split.py [quick] <old.fbx>
# Options as env: NAME (defaults to the old model's, written over it), OUT (folder), TRIS=9000,
# TURN=degrees around z if Meshy faced the wrong way, FIT=long to scale by the longest side (guns) instead of height.
import bmesh, bpy, math, os, sys
from collections import Counter
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import check, preview  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:]
env = os.environ.get
NEW, OLD = os.path.abspath(env("MESHY")), os.path.abspath(args[0])
NAME = env("NAME") or os.path.splitext(os.path.basename(OLD))[0]
TRIS = int(env("TRIS", 9000))
TURN = float(env("TURN", 0))
FIT = env("FIT", "height")
NIGHT = bool(env("NIGHT"))  # the *_night robot: same mesh, paint darkened, Extra (the eye) red
OUT = os.path.abspath(env("OUT") or os.path.dirname(OLD))
os.makedirs(OUT, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)


def world_verts(o):
    return [o.matrix_world @ v.co for v in o.data.vertices]


def bounds(pts):
    return Vector([min(p[i] for p in pts) for i in range(3)]), Vector([max(p[i] for p in pts) for i in range(3)])


# ---------- the old model: part names, joints (object origins) and shapes ----------
bpy.ops.import_scene.fbx(filepath=OLD)
old = [o for o in bpy.data.objects if o.type == "MESH"]
# the kit exports at global_scale 0.01, so its FBXs come back at 1/100: work in studs like the kit does
STUDS = Matrix.Scale(1 / old[0].matrix_world.to_scale()[0], 4)
parts = []
for o in old:
    o.matrix_world = STUDS @ o.matrix_world
    pts = world_verts(o)
    tris = [[o.matrix_world @ o.data.vertices[i].co for i in p.vertices] for p in o.data.polygons]
    flat = [v for t in tris for v in t]
    polys, k = [], 0
    for t in tris:
        polys.append(list(range(k, k + len(t))))
        k += len(t)
    parts.append({"name": o.name, "pivot": o.matrix_world.translation.copy(), "bvh": BVHTree.FromPolygons(flat, polys), "pts": pts})
old_lo, old_hi = bounds([p for part in parts for p in part["pts"]])
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o)

# ---------- the new model: one mesh, turned, scaled and placed over the old one ----------
if NEW.lower().endswith((".glb", ".gltf")):
    bpy.ops.import_scene.gltf(filepath=NEW)
else:
    bpy.ops.import_scene.fbx(filepath=NEW)
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
new = bpy.context.view_layer.objects.active
new.name = "_meshy"  # frees the part names for the cut pieces
new.parent = None
new.data.transform(new.matrix_world)
new.matrix_world = Matrix.Identity(4)
new.data.transform(Matrix.Rotation(math.radians(TURN), 4, "Z"))
lo, hi = bounds([v.co for v in new.data.vertices])
if FIT == "long":
    s = max(old_hi - old_lo) / max(hi - lo)
else:
    s = (old_hi.z - old_lo.z) / (hi.z - lo.z)
mid_new = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
mid_old = Vector(((old_lo.x + old_hi.x) / 2, (old_lo.y + old_hi.y) / 2, old_lo.z))
new.data.transform(Matrix.Translation(mid_old) @ Matrix.Scale(s, 4) @ Matrix.Translation(-mid_new))

# Meshy's texture becomes our <name>_color.png
img = None
for m in new.data.materials:
    if m and m.use_nodes:
        for n in m.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image and img is None:
                img = n.image
if img is None:
    sys.exit("MISS no texture on the Meshy model")
if NIGHT:
    import numpy as np
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)
    grey = px[..., :3].mean(axis=2, keepdims=True)
    px[..., :3] = (px[..., :3] * 0.6 + grey * 0.4) * np.array([0.42, 0.4, 0.44], dtype=np.float32)
    px[:8, :8, :3] = np.array([1.0, 0.14, 0.08], dtype=np.float32)  # the red the night eye samples
    img.pixels.foreach_set(px.ravel())

# weld the copies glTF makes along texture seams (exact matches only: a looser weld eats Meshy's small faces)
wb = bmesh.new()
wb.from_mesh(new.data)
bmesh.ops.remove_doubles(wb, verts=wb.verts, dist=1e-6)
bmesh.ops.triangulate(wb, faces=[f for f in wb.faces if len(f.verts) > 3])
wb.to_mesh(new.data)
wb.free()
bpy.context.view_layer.objects.active = new
if len(new.data.polygons) > TRIS:
    md = new.modifiers.new("d", "DECIMATE")
    md.ratio = TRIS / len(new.data.polygons)
    bpy.ops.object.modifier_apply(modifier="d")

# ---------- give every face to its closest old part, then smooth the borders a few rounds ----------
bm = bmesh.new()
bm.from_mesh(new.data)
bm.faces.ensure_lookup_table()
vid = bm.verts.layers.int.new("vid")
for v in bm.verts:
    v[vid] = v.index
open_edges = {frozenset((e.verts[0].index, e.verts[1].index)) for e in bm.edges if e.is_boundary}  # holes Meshy made on purpose
# Decide on a copy stretched to the old model's width and depth: a slimmer Meshy body would otherwise hand
# its sleeves to the old torso. The real mesh keeps its own proportions.
nlo, nhi = bounds([v.co for v in bm.verts])
mid = (old_lo + old_hi) / 2
stretch = Vector([(old_hi[i] - old_lo[i]) / max(nhi[i] - nlo[i], 1e-6) for i in range(3)])
stretch.z = 1.0
nmid = (nlo + nhi) / 2


def probe(f):
    c = f.calc_center_median() - nmid
    return mid + Vector((c.x * stretch.x, c.y * stretch.y, c.z)) + Vector((0, 0, nmid.z - mid.z))


owner = []
for f in bm.faces:
    c = probe(f)
    best, bd = 0, 1e9
    for i, part in enumerate(parts):
        hit = part["bvh"].find_nearest(c)
        if hit[0] is not None and hit[3] < bd:
            best, bd = i, hit[3]
    owner.append(best)
for _ in range(3):  # a face surrounded by another part's faces joins them: no speckles along the cuts
    nxt = owner[:]
    for f in bm.faces:
        votes = Counter(owner[g.index] for e in f.edges for g in e.link_faces if g is not f)
        if votes:
            top, n = votes.most_common(1)[0]
            if top != owner[f.index] and n >= 2:
                nxt[f.index] = top
    owner = nxt

# Down a limb, anything past the next joint belongs to the next part (Meshy's hands and feet sit where
# the old model had sleeves or shins, so closest-surface alone hands them to the wrong piece).
names = [p["name"] for p in parts]
for pre in ("", "Left"):
    for a_, b_ in (("UpperArm", "Forearm"), ("Forearm", "Hand"), ("Thigh", "Shin")):
        if pre + a_ in names and pre + b_ in names:
            ia, ib = names.index(pre + a_), names.index(pre + b_)
            start, joint = parts[ia]["pivot"], parts[ib]["pivot"]
            axis = joint - start
            for f in bm.faces:
                if owner[f.index] == ia and (probe(f) - start).dot(axis) > axis.length_squared:
                    owner[f.index] = ib

def bright_spot(head, part):
    """Extra is the glowing eye: the brightest bit of the head's paint, nearest the old eye."""
    import numpy as np
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)
    luv = bm.loops.layers.uv.active
    eye = part["pivot"]
    cands = []
    for f in bm.faces:
        if owner[f.index] != head:
            continue
        u = sum(lp[luv].uv.x for lp in f.loops) / len(f.loops)
        v = sum(lp[luv].uv.y for lp in f.loops) / len(f.loops)
        r, g, b_, _ = px[int(v * h) % h, int(u * w) % w]
        cands.append((max(r, g, b_), (probe(f) - eye).length, f.index))
    if not cands:
        return []
    cands.sort(reverse=True)
    top = [c for c in cands if c[0] >= max(0.75, cands[0][0] * 0.9)]
    top = sorted(top, key=lambda c: c[1])[:max(6, len(cands) // 40)]
    return [c[2] for c in top]


# Moving gun parts (a drum, a pump, a slide) take everything inside their old space, so the whole piece moves.
for name in [n for n in (env("BOXGRAB") or "").split(",") if n in names]:
    i = names.index(name)
    plo, phi = bounds(parts[i]["pts"])
    pad = 0.02
    took = 0
    for f in bm.faces:
        c = probe(f)
        if all(plo[k] - pad <= c[k] <= phi[k] + pad for k in range(3)):
            owner[f.index] = i
            took += 1
    print(f"CHECK {name} took {took} faces inside its old space")


# A small part that won nothing (an eye in Extra, say) takes whatever now sits inside its old spot.
for i, part in enumerate(parts):
    if i not in owner:
        plo, phi = bounds(part["pts"])
        pad = Vector((0.04, 0.04, 0.04))
        grab = [f.index for f in bm.faces if all(plo[k] - pad[k] <= probe(f)[k] <= phi[k] + pad[k] for k in range(3))]
        if len(grab) < 4 and part["name"] in ("Extra", "Glow"):
            # the eye or light: brightest paint on the piece that sits where it used to be
            centre = sum(part["pts"], Vector()) / len(part["pts"])
            host = names.index("Head") if part["name"] == "Extra" and "Head" in names else \
                owner[min(range(len(bm.faces)), key=lambda j: (probe(bm.faces[j]) - centre).length)]
            grab = grab + bright_spot(host, part)
        if len(grab) < 4:  # still nothing: the faces nearest where it used to be, so the part exists for the rig and code
            centre = sum(part["pts"], Vector()) / len(part["pts"])
            k = max(20, len(bm.faces) // 200)
            grab = sorted(range(len(bm.faces)), key=lambda j: (probe(bm.faces[j]) - centre).length)[:k]
        for j in grab:
            owner[j] = i
        print(f"CHECK {part['name']} was empty, took {len(grab)} faces")

# Below the hips is leg: shorts and skirts hanging off the body go with the thigh on their side.
if "Torso" in names:
    it = names.index("Torso")
    for side in ("", "Left"):
        if side + "Thigh" in names:
            ih = names.index(side + "Thigh")
            hip = parts[ih]["pivot"]
            for f in bm.faces:
                c = probe(f)
                if owner[f.index] == it and c.z < hip.z - 0.12 and c.x * hip.x > 0 and abs(c.x) > 0.04:
                    owner[f.index] = ih

own = bm.faces.layers.int.new("own")  # face indices don't survive bm.copy(), a layer does
for f in bm.faces:
    f[own] = owner[f.index]

uv = bm.loops.layers.uv.active
mat = bpy.data.materials.new(NAME)
mat.use_nodes = True
bs = mat.node_tree.nodes["Principled BSDF"]
bs.inputs["Roughness"].default_value = 0.75
tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
tex.image = img
mat.node_tree.links.new(tex.outputs[0], bs.inputs["Base Color"])

final = []
for i, part in enumerate(parts):
    pb = bm.copy()
    pb.faces.ensure_lookup_table()
    pown = pb.faces.layers.int["own"]
    bmesh.ops.delete(pb, geom=[f for f in pb.faces if f[pown] != i], context="FACES")
    if not pb.faces:
        print(f"MISS {part['name']}: no faces landed on it")
        pb.free()
        continue
    # cap the cut holes; caps take the colour from the edge they close
    edge_uv = {}
    puv = pb.loops.layers.uv.active
    for f in pb.faces:
        for lp in f.loops:
            edge_uv[lp.vert.index] = lp[puv].uv.copy()
    pvid = pb.verts.layers.int["vid"]
    cut = [e for e in pb.edges if e.is_boundary and frozenset((e.verts[0][pvid], e.verts[1][pvid])) not in open_edges]
    caps = bmesh.ops.holes_fill(pb, edges=cut, sides=0)["faces"]
    for f in caps:
        u = edge_uv.get(f.loops[0].vert.index)
        for lp in f.loops:
            if u is not None:
                lp[puv].uv = u
    bmesh.ops.triangulate(pb, faces=[f for f in pb.faces if len(f.verts) > 3])
    if NIGHT and part["name"] == "Extra":
        red = Vector((3 / img.size[0], 3 / img.size[1]))
        for f in pb.faces:
            for lp in f.loops:
                lp[puv].uv = red
    me = bpy.data.meshes.new(part["name"])
    pb.to_mesh(me)
    pb.free()
    o = bpy.data.objects.new(part["name"], me)
    bpy.context.scene.collection.objects.link(o)
    me.materials.clear()
    me.materials.append(mat)
    for p in me.polygons:
        p.material_index = 0
        p.use_smooth = True  # Meshy shapes are soft; the cut drops its normals, smooth shading brings the look back
    me.transform(Matrix.Translation(-part["pivot"]))
    o.location = part["pivot"]
    final.append(o)
bm.free()
bpy.data.objects.remove(new)

img.scale(1024, 1024) if img.size[0] > 1024 else None
img.filepath_raw = os.path.join(OUT, NAME + "_color.png")
img.file_format = "PNG"
img.save()
img.name = "_meshy_tex"
tex.image = bpy.data.images.load(img.filepath_raw)
tex.image.name = NAME + "_color.png"

fbx = os.path.join(OUT, NAME + ".fbx")
bpy.ops.object.select_all(action="DESELECT")
for o in final:
    o.select_set(True)
bpy.ops.export_scene.fbx(filepath=fbx, use_selection=True, global_scale=0.01, apply_scale_options="FBX_SCALE_NONE",
                         axis_forward="-Z", axis_up="Y", path_mode="COPY", embed_textures=True, mesh_smooth_type="FACE",
                         bake_anim=False, add_leaf_bones=False, object_types={"MESH"})
total = sum(len(o.data.polygons) for o in final)
print(f"BUILT {NAME}: {total} triangles from Meshy, {len(final)}/{len(parts)} parts")
for o in final:
    print(f"   {o.name}: {len(o.data.polygons)}")
if total > 10000:
    print("TOO MANY TRIANGLES, stay under 10000")
check(fbx)
preview(fbx, os.path.join(OUT, "preview.png"), samples=24 if "quick" in args else 64)
