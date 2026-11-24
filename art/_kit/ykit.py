"""Year 2029 prop kit, on top of kit.py (the creepy robot kit).

A build file defines items:

    from ykit import *

    @item("couch", "furniture", size=1024)
    def couch(P):
        P.add("Body", box((7, 3, 2), cloth("#5a6a7a")))

    main()

Run through run.sh only (heat guard). Space: 1 unit = 1 stud, +z up, front faces -y, floor at z = 0.
Studs: a player is about 5 tall, so 1 stud is about 0.3 m. Use m(meters) to convert.
Every part name becomes one MeshPart in Roblox. Roblox moderation judges each MeshPart alone,
in flat grey, so keep pieces joined into whole objects, and never leave a lone rod with a
round end or a ring band on it as its own part.
"""
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *  # noqa
from kit import cull, preview, wipe, V

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ITEMS = {}


def m(meters):
    return meters / 0.3


def item(name, folder, size=512, pivots=None):
    """Registers a build function. pivots: {part: (x, y, z)} hinge points (door hinges, lids)."""

    def reg(fn):
        ITEMS[name] = (fn, folder, size, pivots or {})
        return fn

    return reg


def screen_material(folder):
    """Screen parts get their own image so Roblox can swap it (TV channels, posters, arcade screens).
    Uses <item>/screen.png if there is one, else the kit's test pattern."""
    own = os.path.join(folder, "screen.png")
    path = own if os.path.exists(own) else os.path.join(os.path.dirname(os.path.abspath(__file__)), "screen_default.png")
    mat = bpy.data.materials.new("screen")
    mat.use_nodes = True
    bs = mat.node_tree.nodes["Principled BSDF"]
    t = mat.node_tree.nodes.new("ShaderNodeTexImage")
    t.image = bpy.data.images.load(path)
    mat.node_tree.links.new(t.outputs[0], bs.inputs["Base Color"])
    mat.node_tree.links.new(t.outputs[0], bs.inputs["Emission Color"])
    bs.inputs["Emission Strength"].default_value = 0.6
    return mat


def screen_uv(o):
    """Flat 0 to 1 UVs across the screen's front (it faces -y), so any image fills it edge to edge."""
    xs = [v.co.x for v in o.data.vertices]
    zs = [v.co.z for v in o.data.vertices]
    x0, z0 = min(xs), min(zs)
    w, h = max(max(xs) - x0, 1e-6), max(max(zs) - z0, 1e-6)
    uv = o.data.uv_layers[0].data
    for p in o.data.polygons:
        for li in p.loop_indices:
            co = o.data.vertices[o.data.loops[li].vertex_index].co
            uv[li].uv = ((co.x - x0) / w, (co.z - z0) / h)


class Prop:
    def __init__(self, name, folder):
        wipe()
        self.name = name
        self.dir = os.path.join(ROOT, folder, name)
        os.makedirs(self.dir, exist_ok=True)
        self.parts = {}

    def add(self, part, *obs):
        for o in obs:
            if isinstance(o, (list, tuple)):
                self.add(part, *o)
            elif o is not None:
                self.parts.setdefault(part, []).append(o)
        return obs[0] if len(obs) == 1 else obs

    def finish(self, size=512, pivots=None, quick=False, limit=6000):
        pivots = pivots or {}
        scn = bpy.context.scene
        final = []
        for part, obs in self.parts.items():
            bpy.ops.object.select_all(action="DESELECT")
            for o in obs:
                o.select_set(True)
            bpy.context.view_layer.objects.active = obs[0]
            if len(obs) > 1:
                bpy.ops.object.join()
            o = bpy.context.view_layer.objects.active
            o.name = part
            o.data.name = part
            final.append(o)
        pts = [v.co for o in final for v in o.data.vertices]
        lo = V([min(p[i] for p in pts) for i in range(3)])
        hi = V([max(p[i] for p in pts) for i in range(3)])
        shift = V(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
        for o in final:
            o.data.transform(Matrix.Translation(-shift))
        for o in final:
            cull(o)
        tris = lambda o: sum(len(p.vertices) - 2 for p in o.data.polygons)
        raw = sum(map(tris, final))
        if raw > limit:
            print("TRIMMING from", raw, "triangles")
            for o in final:
                md = o.modifiers.new("d", "DECIMATE")
                md.ratio = limit * 0.97 / raw
                bpy.context.view_layer.objects.active = o
                bpy.ops.object.modifier_apply(modifier="d")
                o.data.set_sharp_from_angle(angle=math.radians(48))
        bpy.ops.object.select_all(action="DESELECT")
        for o in final:
            o.select_set(True)
            o.data.uv_layers.new(name="UVMap")
        bpy.context.view_layer.objects.active = final[0]
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.0, area_weight=0.0)
        bpy.ops.object.mode_set(mode="OBJECT")
        for o in final:
            uv = o.data.uv_layers[0].data
            for p in o.data.polygons:
                k = 0.3 if o.data.materials[p.material_index].name.startswith("flat") else 1.0
                for i in p.loop_indices:
                    uv[i].uv = uv[i].uv * k
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.select_all(action="SELECT")
        bpy.ops.uv.pack_islands(rotate=True, margin_method="FRACTION", margin=0.004, shape_method="CONCAVE")
        bpy.ops.object.mode_set(mode="OBJECT")
        img = bpy.data.images.new(self.name + "_color", size, size)
        for mt in bpy.data.materials:
            if mt.node_tree and mt.users:
                t = mt.node_tree.nodes.new("ShaderNodeTexImage")
                t.image = img
                mt.node_tree.nodes.active = t
        scn.render.engine = "CYCLES"
        scn.cycles.samples = 4 if quick else 16
        scn.cycles.use_denoising = False
        scn.render.bake.use_selected_to_active = False
        scn.render.bake.margin = 4
        scn.view_settings.view_transform = "Standard"
        scn.world = bpy.data.worlds.new("w")
        bpy.ops.object.bake(type="EMIT")
        path = os.path.join(self.dir, self.name + "_color.png")
        img.filepath_raw = path
        img.file_format = "PNG"
        img.save()
        mat = bpy.data.materials.new(self.name)
        mat.use_nodes = True
        bs = mat.node_tree.nodes["Principled BSDF"]
        bs.inputs["Roughness"].default_value = 0.75
        t = mat.node_tree.nodes.new("ShaderNodeTexImage")
        t.image = bpy.data.images.load(path)
        mat.node_tree.links.new(t.outputs[0], bs.inputs["Base Color"])
        total = 0
        for o in final:
            o.data.materials.clear()
            o.data.materials.append(screen_material(self.dir) if o.name.startswith("Screen") else mat)
            if o.name.startswith("Screen"):
                screen_uv(o)
            for p in o.data.polygons:
                p.material_index = 0
            for a in ("lp", "g"):
                if a in o.data.attributes:
                    o.data.attributes.remove(o.data.attributes[a])
            md = o.modifiers.new("t", "TRIANGULATE")
            md.keep_custom_normals = True
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.modifier_apply(modifier="t")
            total += len(o.data.polygons)
            at = pivots.get(o.name)
            if at is not None:
                at = V(at) - shift
                o.data.transform(Matrix.Translation(-at))
                o.location = at
        fbx = os.path.join(self.dir, self.name + ".fbx")
        bpy.ops.object.select_all(action="DESELECT")
        for o in final:
            o.select_set(True)
        bpy.ops.export_scene.fbx(filepath=fbx, use_selection=True, global_scale=0.01, apply_scale_options="FBX_SCALE_NONE",
                                 axis_forward="-Z", axis_up="Y", path_mode="COPY", embed_textures=True, mesh_smooth_type="FACE",
                                 bake_anim=False, add_leaf_bones=False, object_types={"MESH"})
        d = hi - lo
        print(f"BUILT {self.name}: {total} triangles, {d.x:.2f} x {d.y:.2f} x {d.z:.2f} studs (w x d x h), parts {[o.name for o in final]}")
        if total > limit:
            print("TOO MANY TRIANGLES", total)
        preview(fbx, os.path.join(self.dir, "preview.png"), samples=12 if quick else 40, res=600 if quick else 800)


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    quick = "quick" in args
    names = [a for a in args if a not in ("quick", "all")] or list(ITEMS)
    for n in names:
        if n not in ITEMS:
            print("MISS", n, "not in", list(ITEMS))
            continue
        fn, folder, size, pivots = ITEMS[n]
        P = Prop(n, folder)
        fn(P)
        P.finish(size=size, pivots=pivots, quick=quick)
