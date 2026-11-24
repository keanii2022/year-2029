# Contact sheet of every preview in a folder. blender -b --factory-startup -P _kit/sheet.py -- <folder> [cols]
import bpy, os, math, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
args = sys.argv[sys.argv.index("--") + 1:]
FOLDER = os.path.join(ROOT, args[0])
COLS = int(args[1]) if len(args) > 1 else 5
NAMES = sorted(n for n in os.listdir(FOLDER) if os.path.exists(os.path.join(FOLDER, n, "preview.png")))
rows = math.ceil(len(NAMES) / COLS)
W, H = 1.0, 1.1
bpy.ops.wm.read_factory_settings(use_empty=True)
scn = bpy.context.scene


def emit(color=None, img=None):
    mt = bpy.data.materials.new("m")
    mt.use_nodes = True
    t = mt.node_tree
    t.nodes.clear()
    e = t.nodes.new("ShaderNodeEmission")
    o = t.nodes.new("ShaderNodeOutputMaterial")
    t.links.new(e.outputs[0], o.inputs[0])
    if img:
        i = t.nodes.new("ShaderNodeTexImage")
        i.image = bpy.data.images.load(img)
        t.links.new(i.outputs[0], e.inputs[0])
    else:
        e.inputs[0].default_value = color
    return mt


def plane(x, y, w, h, mat):
    me = bpy.data.meshes.new("p")
    me.from_pydata([(x - w / 2, y - h / 2, 0), (x + w / 2, y - h / 2, 0), (x + w / 2, y + h / 2, 0), (x - w / 2, y + h / 2, 0)], [], [(0, 1, 2, 3)])
    uv = me.uv_layers.new()
    for i, c in enumerate(((0, 0), (1, 0), (1, 1), (0, 1))):
        uv.data[i].uv = c
    me.materials.append(mat)
    scn.collection.objects.link(bpy.data.objects.new("p", me))


ink = emit((0.02, 0.015, 0.03, 1))
for i, n in enumerate(NAMES):
    r, c = divmod(i, COLS)
    x, y = (c - (COLS - 1) / 2) * W, -r * H
    plane(x, y + 0.05, W * 0.97, W * 0.97, emit(img=os.path.join(FOLDER, n, "preview.png")))
    cu = bpy.data.curves.new("t", "FONT")
    cu.body, cu.size, cu.align_x, cu.align_y = n.replace("_", " "), 0.06, "CENTER", "CENTER"
    cu.materials.append(ink)
    ob = bpy.data.objects.new("t", cu)
    ob.location = (x, y - 0.5, 0.02)
    scn.collection.objects.link(ob)
w = bpy.data.worlds.new("w")
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.9, 0.9, 0.92, 1)
scn.world = w
cam = bpy.data.cameras.new("c")
cam.type = "ORTHO"
tw, th = COLS * W + 0.06, rows * H + 0.06
cam.ortho_scale = max(tw, th)
co = bpy.data.objects.new("c", cam)
co.location = (0, -(rows - 1) * H / 2 - 0.02, 5)
scn.collection.objects.link(co)
scn.camera = co
scn.render.engine = "CYCLES"
scn.cycles.samples = 4
scn.view_settings.view_transform = "Standard"
scn.render.resolution_x = int(tw * 360)
scn.render.resolution_y = int(th * 360)
scn.render.filepath = os.path.join(FOLDER, "sheet.png")
bpy.ops.render.render(write_still=True)
