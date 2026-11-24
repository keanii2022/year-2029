# Night render of a robot FBX: dark warehouse floor, lit only by the player's flashlight, low camera looking up.
# Bright red in the texture glows (stands in for the Neon parts Roblox lights at night). Writes night.png beside the FBX.
# _kit/run.sh _kit/nightshot.py robots/scout_night/scout_night.fbx
import bpy, math, os, sys
from mathutils import Vector as V

fbx = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=fbx)
scn = bpy.context.scene
bpy.context.view_layer.update()
pts = [o.matrix_world @ v.co for o in bpy.data.objects if o.type == "MESH" for v in o.data.vertices]
lo = V([min(p[i] for p in pts) for i in range(3)])
hi = V([max(p[i] for p in pts) for i in range(3)])
h = max(hi.z - lo.z, hi.y - lo.y, (hi.x - lo.x) * 0.8)
mid = (lo + hi) / 2

for m in bpy.data.materials:
    if not m.node_tree:
        continue
    nt = m.node_tree
    bs = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    tex = next((n for n in nt.nodes if n.type == "TEX_IMAGE"), None)
    if not bs or not tex:
        continue
    bs.inputs["Roughness"].default_value = 0.55
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(tex.outputs[0], sep.inputs[0])
    gb = nt.nodes.new("ShaderNodeMath")
    gb.operation = "MAXIMUM"
    nt.links.new(sep.outputs[1], gb.inputs[0])
    nt.links.new(sep.outputs[2], gb.inputs[1])
    diff = nt.nodes.new("ShaderNodeMath")
    diff.operation = "SUBTRACT"
    nt.links.new(sep.outputs[0], diff.inputs[0])
    nt.links.new(gb.outputs[0], diff.inputs[1])
    mask = nt.nodes.new("ShaderNodeMapRange")
    mask.inputs["From Min"].default_value = 0.45
    mask.inputs["From Max"].default_value = 0.65
    mask.inputs["To Max"].default_value = 3.0
    nt.links.new(diff.outputs[0], mask.inputs[0])
    nt.links.new(tex.outputs[0], bs.inputs["Emission Color"])
    nt.links.new(mask.outputs[0], bs.inputs["Emission Strength"])

floor = bpy.data.meshes.new("floor")
s = h * 30
floor.from_pydata([(-s, -s, 0), (s, -s, 0), (s, s, 0), (-s, s, 0)], [], [(0, 1, 2, 3)])
fo = bpy.data.objects.new("floor", floor)
fo.location.z = lo.z
fm = bpy.data.materials.new("concrete")
fm.use_nodes = True
fb = fm.node_tree.nodes["Principled BSDF"]
fb.inputs["Base Color"].default_value = (0.05, 0.05, 0.055, 1)
fb.inputs["Roughness"].default_value = 0.7
floor.materials.append(fm)
scn.collection.objects.link(fo)

w = bpy.data.worlds.new("w")
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.004, 0.006, 0.012, 1)
scn.world = w

turn = math.radians(-18)
d = h * 1.2
cam_at = mid + V((math.sin(turn) * d, -math.cos(turn) * d, -h * 0.38))
cam_at.z = max(cam_at.z, lo.z + h * 0.12)

def place(o, at, look):
    o.location = at
    o.rotation_euler = (look - at).to_track_quat("-Z", "Y").to_euler()
    scn.collection.objects.link(o)

torch = bpy.data.lights.new("flashlight", "SPOT")
torch.energy = 160 * h * h
torch.spot_size = math.radians(48)
torch.spot_blend = 0.6
torch.color = (1.0, 0.93, 0.8)
place(bpy.data.objects.new("flashlight", torch), cam_at + V((h * 0.12, 0, -h * 0.05)), mid + V((0, 0, h * 0.12)))
rim = bpy.data.lights.new("rim", "AREA")
rim.energy = 40 * h * h
rim.size = h * 0.6
rim.color = (0.45, 0.6, 1.0)
place(bpy.data.objects.new("rim", rim), mid + V((-h * 1.1, h * 1.4, h * 0.9)), mid)

cam = bpy.data.cameras.new("c")
cam.lens = 30
cam.clip_start = 0.01
cam.clip_end = d * 100
co = bpy.data.objects.new("c", cam)
place(co, cam_at, mid + V((0, 0, h * 0.1)))
scn.camera = co
scn.render.engine = "CYCLES"
scn.cycles.samples = 48
scn.cycles.use_denoising = True
scn.render.resolution_x = 800
scn.render.resolution_y = 1000
scn.view_settings.view_transform = "Standard"
scn.view_settings.exposure = -0.4
scn.render.filepath = os.path.join(os.path.dirname(fbx), "night.png")
bpy.ops.render.render(write_still=True)
print("NIGHT", scn.render.filepath)
