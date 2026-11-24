# Mood shots: assembles warehouse kit pieces into small scenes with fog and light and renders them,
# so the look can be judged before Roblox. Writes art/warehouse/_moodshots/<shot>.png.
# _kit/run.sh warehouse/moodshots.py            (all shots)
# _kit/run.sh warehouse/moodshots.py -- aisle   (one shot; names: aisle, installation, pillar)
import bpy, math, os, sys
from mathutils import Vector as V

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "_moodshots")
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
WANT = [a for a in args if a] or ["aisle", "installation", "pillar", "culdesac"]

_cache = {}


def wipe():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _cache.clear()


def load(name):
    """Imports a kit piece once; returns its root objects (hidden template)."""
    if name not in _cache:
        before = set(bpy.data.objects)
        folder = os.path.join(os.path.dirname(HERE), name) if "/" in name else os.path.join(HERE, name)
        bpy.ops.import_scene.fbx(filepath=os.path.join(folder, os.path.basename(name) + ".fbx"), global_scale=100.0)
        objs = [o for o in bpy.data.objects if o not in before]
        for o in objs:
            if o.type == "MESH" and "glow" in o.name.lower():
                glowify(o, GLOW.get(name, 6.0))
            o.hide_render = True
            o.hide_viewport = True
        _cache[name] = [o for o in objs if o.parent is None or o.parent not in objs]
        meshes = [o for o in objs if o.type == "MESH"]
        if meshes:
            print("CHECK size", name, tuple(round(d, 2) for d in meshes[0].dimensions), "scale", tuple(round(c, 3) for c in meshes[0].matrix_world.to_scale()))
    return _cache[name]


GLOW = {"sun_panel": 2.5}  # 15 big glowing panels light the whole set on their own; full strength washes it white


def glowify(o, strength=6.0):
    for slot in o.material_slots:
        if not slot.material or not slot.material.node_tree:
            continue
        # a model's parts share one baked material; copy it or the whole model glows
        m = slot.material = slot.material.copy()
        nt = m.node_tree
        bs = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
        tex = next((n for n in nt.nodes if n.type == "TEX_IMAGE"), None)
        if bs and tex:
            nt.links.new(tex.outputs[0], bs.inputs["Emission Color"])
            bs.inputs["Emission Strength"].default_value = strength


def place(name, at=(0, 0, 0), rot=0.0, scale=1.0):
    """Linked copy of a kit piece at a position, turned rot degrees around z."""
    root = bpy.data.objects.new(name + "_at", None)
    bpy.context.scene.collection.objects.link(root)
    root.location = at
    root.rotation_euler.z = math.radians(rot)
    root.scale = (scale, scale, scale)

    def copy(src, parent):
        o = src.copy()
        o.hide_render = False
        o.hide_viewport = False
        bpy.context.scene.collection.objects.link(o)
        o.parent = parent
        for child in src.children:
            copy(child, o)

    for src in load(name):
        copy(src, root)
    return root


def lamp(kind, at, energy, color=(1, 1, 1), size=1.0, aim=None, spot=60):
    data = bpy.data.lights.new(kind, kind)
    data.energy = energy
    data.color = color
    if kind == "AREA":
        data.size = size
    if kind == "SPOT":
        data.spot_size = math.radians(spot)
        data.spot_blend = 0.5
    if kind in ("POINT", "SPOT"):
        data.shadow_soft_size = size
    o = bpy.data.objects.new(kind, data)
    o.location = at
    if aim is not None:
        o.rotation_euler = (V(aim) - V(at)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(o)
    return o


def world(color, fog_density, fog_color=(0.6, 0.62, 0.66)):
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    nt = w.node_tree
    nt.nodes["Background"].inputs[0].default_value = (*color, 1)
    vol = nt.nodes.new("ShaderNodeVolumePrincipled")
    vol.inputs["Density"].default_value = fog_density
    vol.inputs["Color"].default_value = (*fog_color, 1)
    nt.links.new(vol.outputs[0], nt.nodes["World Output"].inputs["Volume"])
    bpy.context.scene.world = w


def camera(at, look, lens=22):
    data = bpy.data.cameras.new("cam")
    data.lens = lens
    data.clip_end = 2000
    o = bpy.data.objects.new("cam", data)
    o.location = at
    o.rotation_euler = (V(look) - V(at)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(o)
    bpy.context.scene.camera = o


def render(shot):
    scn = bpy.context.scene
    try:
        scn.render.engine = "BLENDER_EEVEE"
        ee = scn.eevee
        for attr, val in (("volumetric_tile_size", "4"), ("volumetric_samples", 96), ("volumetric_end", 600),
                          ("taa_render_samples", 64), ("use_shadows", True)):
            if hasattr(ee, attr):
                setattr(ee, attr, val)
    except TypeError:
        scn.render.engine = "CYCLES"
        scn.cycles.samples = 64
        scn.cycles.use_denoising = True
    scn.view_settings.view_transform = "AgX"
    scn.view_settings.look = "AgX - Medium High Contrast"
    scn.render.resolution_x, scn.render.resolution_y = 1600, 900
    os.makedirs(OUT, exist_ok=True)
    scn.render.filepath = os.path.join(OUT, shot + ".png")
    bpy.ops.render.render(write_still=True)
    print("BUILT moodshot", shot, scn.render.engine)


def floor_strip(names, xs, ys):
    i = 0
    for x in xs:
        for y in ys:
            place(names[i % len(names)], (x, y, 0), rot=(i * 90) % 360 if "lane" not in names[i % len(names)] else 0)
            i += 1


def shot_aisle():
    """Player's eye down a long racking aisle under dying fluorescent strips, fog eating the far end."""
    wipe()
    world((0.004, 0.005, 0.006), 0.016, (0.5, 0.56, 0.58))
    floor_strip(["floor_tile", "floor_wet", "floor_cracked", "floor_tile", "floor_lane"], (-16, 16), range(-16, 240, 32))
    bays = ["rack_bay_full", "rack_bay_sparse", "rack_bay_full", "rack_bay_bulk", "rack_bay_furniture",
            "rack_bay_full", "rack_bay_sparse", "rack_bay_full", "rack_bay_bulk", "rack_bay_full"]
    for i in range(18):
        y = i * 12.1
        place(bays[i % len(bays)], (-7.2, y, 0), rot=90)
        place(bays[(i + 4) % len(bays)] if i != 9 else "rack_collapsed", (7.2, y, 0), rot=-90)
    for x in (-7.2, 7.2):
        place("rack_end", (x, -6.1, 0), rot=90 if x < 0 else -90)
    place("pallet_wrapped", (1.5, 26, 0), rot=12)
    place("box_pile_small", (-2.2, 44, 0), rot=-30)
    place("oil_drum", (2.6, 58, 0))
    place("caution_tape", (0, 92, 0))
    place("shopping_cart", (-1.5, 16, 0), rot=150)
    fixtures = ["light_strip", "light_strip_dead", "light_strip", "light_dangling", "light_strip_dead",
                "light_strip", "light_strip_dead", "light_strip_dead", "light_strip", "light_strip_dead"]
    for i, f in enumerate(fixtures):
        y = 8 + i * 20
        place(f, (0, y, 34), rot=90)
        if f != "light_strip_dead":
            lamp("AREA", (0, y, 31.5), 2200 if f == "light_strip" else 700, (0.82, 0.95, 0.92), size=6,
                 aim=(0, y, 0))
    place("aisle_sign_hanging", (0, 70, 34), rot=0)
    lamp("SPOT", (0.6, -1.5, 5.2), 900, (1.0, 0.92, 0.8), size=0.2, aim=(0, 30, 3), spot=38)
    camera((0.8, -4, 5.2), (0, 60, 7), lens=20)
    render("aisle")


def shot_installation():
    """A pitch-dark hall; far off, one lit pocket: lime curved walls, blue carpet, one giant orange chair."""
    wipe()
    world((0.0, 0.0, 0.0), 0.006, (0.5, 0.5, 0.55))
    floor_strip(["floor_tile", "floor_cracked", "floor_tile", "floor_wet"], range(-80, 96, 32), range(-48, 140, 32))
    cx, cy = 0, 96
    for x in (cx - 16, cx + 16):
        for y in (cy - 16, cy + 16):
            place("floor_carpet_blue", (x, y, 0.05))
    place("wall_curved", (cx - 24, cy + 24, 0), rot=0)
    place("wall_curved", (cx + 24, cy + 24, 0), rot=-90)
    place("wall_pastel", (cx - 8, cy + 31.5, 0))
    place("wall_pastel", (cx + 8, cy + 31.5, 0))
    place("giant_chair", (cx + 6, cy + 10, 0.1), rot=-25, scale=1.7)
    place("robots/scout", (cx - 9, cy + 2, 0.1), rot=200)
    place("star_decal", (cx - 10, cy + 30.9, 9))
    for x in (cx - 16, cx, cx + 16):
        for y in (cy - 8, cy + 8, cy + 24):
            place("drop_ceiling", (x, y, 32))
    lamp("AREA", (cx, cy + 8, 31), 14000, (1.0, 0.97, 0.9), size=34, aim=(cx, cy + 8, 0))
    place("rack_bay_sparse", (-40, 20, 0), rot=90)
    place("rack_bay_full", (-40, 32.1, 0), rot=90)
    place("rack_bay_full", (40, 26, 0), rot=-90)
    place("pallet_tower", (-24, 50, 0), rot=20)
    place("light_strip_dead", (0, 30, 34), rot=90)
    lamp("SPOT", (0.5, -2.5, 5.2), 120, (1.0, 0.92, 0.8), size=0.2, aim=(0, 40, 1), spot=32)
    camera((-3, 30, 5.2), (0, 96, 11), lens=26)
    render("installation")


def shot_pillar():
    """Standing at the foot of a giant pillar that climbs into the fog, racks around it, one high-bay light."""
    wipe()
    world((0.03, 0.033, 0.038), 0.006, (0.62, 0.64, 0.66))
    floor_strip(["floor_tile", "floor_lane", "floor_wet", "floor_cracked"], range(-96, 112, 32), range(-112, 80, 32))
    for i in range(6):
        place(("rack_bay_full", "rack_bay_sparse", "rack_bay_bulk")[i % 3], (-30, -70 + i * 12.1, 0), rot=90)
        place(("rack_bay_bulk", "rack_bay_full", "rack_bay_furniture")[i % 3], (30, -70 + i * 12.1, 0), rot=-90)
    place("giant_pillar_base", (0, 16, 0))
    for i in range(1, 12):
        place("giant_pillar", (0, 16, 32 * i), rot=90 * i)
    for i, y in enumerate((-20, -7.9, 4.2)):
        place(("rack_bay_full", "rack_bay_bulk", "rack_bay_full")[i], (-26, y, 0), rot=90)
        place(("rack_bay_sparse", "rack_bay_full", "rack_bay_furniture")[i], (26, y, 0), rot=-90)
    place("pallet_tower", (-14, -4, 0), rot=10)
    place("furniture_heap", (13, 0, 0), rot=-20)
    place("caution_tape", (0, -2, 0))
    place("bollard", (-8, -2, 0))
    place("bollard", (8, -2, 0))
    place("light_highbay", (-14, 6, 40))
    lamp("SPOT", (-14, 6, 37), 22000, (0.85, 0.95, 1.0), size=2, aim=(-6, 10, 0), spot=70)
    place("light_highbay", (14, -10, 40))
    lamp("SPOT", (14, -10, 37), 18000, (0.85, 0.95, 1.0), size=2, aim=(10, -6, 0), spot=70)
    lamp("SPOT", (0, -14, 0.5), 250000, (1.0, 0.85, 0.65), size=1, aim=(0, 10, 220), spot=34)
    lamp("SPOT", (-40, -60, 90), 120000, (0.7, 0.78, 0.9), size=6, aim=(0, 16, 90), spot=24)
    camera((-6, -80, 5.2), (0, 16, 60), lens=20)
    render("pillar")


def shot_culdesac():
    """Round a corner in the dark warehouse into a fake suburb under a ceiling sun: pastel fronts, warm empty windows."""
    wipe()
    world((0.002, 0.002, 0.003), 0.0035, (0.6, 0.64, 0.7))
    floor_strip(["floor_tile", "floor_cracked", "floor_tile", "floor_wet"], range(-80, 112, 32), range(-48, 208, 32))
    for y in (0, 32, 64, 96):
        place("street_tile", (0, y, 0.02))
        place("street_curb", (-19, y, 0.02), rot=90)
        place("street_curb", (19, y, 0.02), rot=-90)
    c = (0, 124)
    for rot, (ox, oy) in ((0, (16, 16)), (90, (-16, 16)), (180, (-16, -16)), (270, (16, -16))):
        place("culdesac_end", (c[0] + ox, c[1] + oy, 0.02), rot=rot)
    for x in (-38, 38):
        for y in (0, 32, 64, 96, 128):
            place("turf_tile", (x, y, 0.02))
    for x in (-32, 0, 32):
        place("turf_tile", (x, 172, 0.02))
    # front faces -y before turning; +90 turns it to face +x (left row), -90 to face -x (right row)
    left = [("house_ranch", 6), ("house_twostory", 40), ("house_tiny", 74)]
    right = [("house_garage", 8), ("house_tiny", 42), ("house_ranch", 78)]
    for name, y in left:
        place(name, (-36, y, 0.7), rot=90)
        place("mailbox", (-23.5, y - 6, 0.7), rot=90)
        place("hedge", (-27, y + 9, 0.7), rot=90)
    for name, y in right:
        place(name, (36, y, 0.7), rot=-90)
        place("mailbox", (23.5, y - 6, 0.7), rot=-90)
    place("driveway", (30, 8, 0.02), rot=-90)
    place("house_twostory", (0, 168, 0.7))
    place("welcome_mat", (4, 162, 0.72))
    place("fake_tree", (-28, 24, 0.7))
    place("fake_tree", (27, 60, 0.7))
    place("lawn_flamingo", (-26, 50, 0.7), rot=70)
    place("lawn_flamingo", (-25, 53, 0.7), rot=70)
    place("tricycle", (-27, 0, 0.7), rot=40)
    place("garden_sprinkler", (26, 30, 0.7))
    for x, y in ((-19.5, 22), (19.5, 58), (-19.5, 92), (19.5, 112)):
        place("streetlamp", (x, y, 0.7))
        lamp("POINT", (x, y, 10.6), 260, (1.0, 0.78, 0.5), size=0.4)
    for x in (-32, 0, 32):
        for y in (16, 48, 80, 112, 144):
            place("sun_panel", (x, y, 64))
    lamp("AREA", (0, 80, 63), 40000, (0.86, 0.92, 1.0), size=110, aim=(0, 80, 0))
    # stage floods across the street wash each row of fronts, like lights on a film set
    for side in (-1, 1):
        for y in (10, 50, 90):
            lamp("AREA", (-side * 6, y, 22), 9000, (1.0, 0.96, 0.9), size=24, aim=(side * 36, y, 6))
    lamp("AREA", (0, 120, 22), 9000, (1.0, 0.96, 0.9), size=24, aim=(0, 166, 6))
    # the warehouse it sits in: racks fading into the dark past the roofs, the corner you came round
    for i in range(10):
        place(("rack_bay_full", "rack_bay_sparse", "rack_bay_bulk")[i % 3], (-60 + i * 12.1, 210, 0))
    place("wall_lower", (-24, -40, 0), rot=90)
    place("wall_upper", (-24, -40, 16), rot=90)
    place("rack_end", (-20, -30, 0), rot=90)
    lamp("SPOT", (-4.4, -45.5, 5.2), 600, (1.0, 0.92, 0.8), size=0.2, aim=(0, 40, 2), spot=34)
    camera((-5, -46, 5.4), (2, 110, 9), lens=22)
    render("culdesac")


SHOTS = {"aisle": shot_aisle, "installation": shot_installation, "pillar": shot_pillar, "culdesac": shot_culdesac}
for name in WANT:
    if name in SHOTS:
        SHOTS[name]()
