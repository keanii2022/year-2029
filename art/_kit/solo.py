# Moderation check: renders every mesh part of an FBX alone, flat grey, no texture, in a grid.
# Roblox reviews each MeshPart this way. Look for shapes that read as body parts.
# blender -b --factory-startup -P _kit/solo.py -- path/to/model.fbx
import bpy, math, mathutils, os, sys
args = sys.argv[sys.argv.index("--") + 1:]
fbx = args[0]
side = "side" in args or bool(os.environ.get("SOLO_SIDE"))  # long things that point along -y (guns): turn them to show their profile
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=fbx)
scn = bpy.context.scene
grey = bpy.data.materials.new("g")
grey.use_nodes = True
grey.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.5, 0.5, 0.5, 1)
obs = [o for o in bpy.data.objects if o.type == "MESH"]
cols = min(4, len(obs))
gap = 0
for o in obs:
    bpy.context.view_layer.update()
    o.data.materials.clear()
    o.data.materials.append(grey)
    if side:
        o.matrix_world = mathutils.Matrix.Rotation(math.radians(90), 4, "Z") @ o.matrix_world
bpy.context.view_layer.update()
size = max(max(o.dimensions) for o in obs) * 1.4
for i, o in enumerate(obs):
    r, c = divmod(i, cols)
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ v.co for v in o.data.vertices]
    mid = sum(pts, pts[0] * 0) / len(pts)
    o.location += mathutils.Vector((c * size - mid.x, 0 - mid.y, -r * size - mid.z))
    cu = bpy.data.curves.new("t", "FONT")
    cu.body, cu.size, cu.align_x = o.name, size * 0.08, "CENTER"
    t = bpy.data.objects.new("t", cu)
    t.location = (c * size, -size * 0.5, -r * size - size * 0.45)
    t.rotation_euler = (math.radians(90), 0, 0)
    scn.collection.objects.link(t)
rows = math.ceil(len(obs) / cols)
w = bpy.data.worlds.new("w")
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (1, 1, 1, 1)
scn.world = w
for x, z, e in ((-1, 1, 3), (1, 0.5, 1.5)):
    l = bpy.data.lights.new("l", "SUN")
    l.energy = e
    lo = bpy.data.objects.new("l", l)
    lo.rotation_euler = (math.radians(60), math.radians(20 * x), math.radians(-30 * x))
    scn.collection.objects.link(lo)
cam = bpy.data.cameras.new("c")
cam.type = "ORTHO"
cam.ortho_scale = max(cols, rows) * size
co = bpy.data.objects.new("c", cam)
co.location = ((cols - 1) * size / 2, -size * 20, -(rows - 1) * size / 2)
co.rotation_euler = (math.radians(90), 0, 0)
cam.clip_end = size * 100
scn.collection.objects.link(co)
scn.camera = co
scn.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "CYCLES"
scn.render.resolution_x = cols * 300
scn.render.resolution_y = rows * 300
scn.render.filepath = os.path.join(os.path.dirname(fbx), "solo.png")
bpy.ops.render.render(write_still=True)
print("SOLO", scn.render.filepath)
