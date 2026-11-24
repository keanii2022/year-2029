# Mood shots: assembles warehouse kit pieces into small scenes with fog and light and renders them,
# so the look can be judged before Roblox. Writes art/warehouse/_moodshots/<shot>.png.
# _kit/run.sh warehouse/moodshots.py            (all shots)
# _kit/run.sh warehouse/moodshots.py -- aisle   (one shot; names: aisle, installation, pillar)
import bpy, math, os, sys
from mathutils import Vector as V

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "_moodshots")
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
WANT = [a for a in args if a] or ["aisle", "installation", "pillar", "culdesac"]  # pockets render by name

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


def floor_strip(names, xs, ys, hole=None):
    i = 0
    for x in xs:
        for y in ys:
            if hole and hole[0] <= x <= hole[1] and hole[2] <= y <= hole[3]:
                continue
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


# ---------------------------------------------------------------- installations from POCKETS.md
def hall(fog=0.008, fog_color=(0.5, 0.52, 0.56), bg=0.0, hole=None):
    """A pitch-dark warehouse hall: concrete floor running off into black (minus a hole for sunken sets)."""
    wipe()
    world((bg, bg, bg), fog, fog_color)
    floor_strip(["floor_tile", "floor_cracked", "floor_tile", "floor_wet"], range(-96, 128, 32), range(-48, 208, 32), hole)


def grid(name, xs, ys, z=0.0, rot=0):
    for x in xs:
        for y in ys:
            place(name, (x, y, z), rot=rot)


def wall_run(name, x0, x1, y, levels=(0,), rot=0, every=16):
    """Walls along x at depth y (rot 0 faces -y, toward the camera)."""
    for x in range(x0, x1 + 1, every):
        for z in levels:
            place(name, (x, y, z), rot=rot)


def side_run(name, x, y0, y1, levels=(0,), rot=90, every=16):
    """Walls along y at x; rot 90 faces +x, -90 faces -x."""
    for y in range(y0, y1 + 1, every):
        for z in levels:
            place(name, (x, y, z), rot=rot)


def fill(center, z, size, energy, color=(1.0, 0.95, 0.88)):
    """Soft light from the set's own ceiling so its walls read; the hall around it stays black."""
    lamp("AREA", (center[0], center[1], z), energy, color, size=size, aim=(center[0], center[1], 0))


def torch(at, aim, energy=500):
    lamp("SPOT", at, energy, (1.0, 0.92, 0.8), size=0.2, aim=aim, spot=34)


def shot_pool():
    """Flooded white-tile halls, doorways into more water, one rubber duck."""
    hall(0.006, (0.55, 0.7, 0.7), hole=(-32, 32, 48, 112))
    # origins 2.9 below the floor: the lip meets the floor and the water sits 0.7 down
    grid("pool_floor", (-32, 0, 32), (48, 80, 112), -2.9)
    for x in (-32, 0, 32):
        place("pool_edge", (x, 33.5, -2.9))
    side_run("wall_tile", -48, 40, 120, (0, 16), rot=90)
    side_run("wall_tile", 48, 40, 120, (0, 16), rot=-90)
    for i, x in enumerate(range(-40, 41, 16)):
        place("wall_tile_doorway" if i in (1, 3) else "wall_tile", (x, 128, 0), rot=0)
        place("wall_tile", (x, 128, 16), rot=0)
    grid("drop_ceiling", (-40, -24, -8, 8, 24, 40), (40, 56, 72, 88, 104, 120), 32)
    for x in (-24, 0, 24):
        for y in (48, 80, 112):
            place("light_troffer", (x, y, 31.3))
            lamp("AREA", (x, y, 30.5), 2500, (0.9, 1.0, 1.0), size=4, aim=(x, y, 0))
    place("fun/rubber_duck", (5, 64, -0.7), rot=200)
    place("robots/cleaner", (-12, 96, -2.7), rot=160)
    fill((0, 80), 31, 80, 9000, (0.85, 1.0, 1.0))
    torch((0.5, 22, 5.2), (0, 70, 0))
    camera((0, 24, 6.0), (0, 110, 4), lens=22)
    render("pool")


def shot_courtyard():
    """A courtyard indoors: walls of small windows, a few lit, grass squares, a sky for a ceiling."""
    hall(0.004, (0.5, 0.55, 0.6))
    grid("grid_floor", (-32, 0, 32), (48, 80, 112))
    side_run("window_grid_wall", -48, 40, 120, (0, 16, 32, 48), rot=90)
    side_run("window_grid_wall", 48, 40, 120, (0, 16, 32, 48), rot=-90)
    wall_run("window_grid_wall", -40, 40, 128, (0, 16, 32, 48))
    grid("sky_ceiling", (-32, 0, 32), (48, 80, 112), 64)
    lamp("AREA", (0, 80, 62), 30000, (0.75, 0.85, 1.0), size=90, aim=(0, 80, 0))
    lamp("AREA", (0, 80, 30), 40000, (1.0, 1.0, 1.0), size=60, aim=(0, 80, 100))  # lights the painted sky from below
    place("pink_bench", (0, 104, 0.7))
    place("robots/carrier", (-4, 104, 0.7), rot=180)
    camera((4, 14, 5.2), (0, 100, 26), lens=18)
    render("courtyard")


def shot_catwalk():
    """A white walkway over nothing under an endless grid of lights; a drinks machine where it stops."""
    wipe()
    world((0.0, 0.0, 0.0), 0.006, (0.6, 0.68, 0.72))
    for i in range(6):
        place("catwalk", (0, 16 + i * 32, 0))
    place("fun/vending_machine", (0, 196, 0), rot=180)
    for x in range(-96, 97, 16):
        for y in range(0, 320, 16):
            place("light_troffer", (x, y, 46))
    lamp("AREA", (0, 140, 45), 120000, (0.85, 0.95, 1.0), size=200, aim=(0, 140, 0))
    torch((0.5, -2, 5.2), (0, 60, 0))
    camera((0, -6, 5.6), (0, 120, 3), lens=20)
    render("catwalk")


def shot_blacksun():
    """A grass grid field under painted sky walls, and a black sun hanging where the sun should be."""
    hall(0.003, (0.6, 0.7, 0.85), bg=0.0)
    grid("grid_floor", (-64, -32, 0, 32, 64), (32, 64, 96, 128, 160))
    wall_run("wall_sky", -88, 88, 180, (0, 16, 32, 48))
    place("black_sun", (0, 170, 34))
    lamp("AREA", (0, 100, 70), 60000, (0.8, 0.88, 1.0), size=160, aim=(0, 100, 0))
    place("robots/crawler", (10, 110, 0.7), rot=170)
    camera((-6, 10, 5.4), (0, 170, 30), lens=22)
    render("blacksun")


def shot_mall():
    """A dead mall concourse: shutters down both sides, one shop sign still says it's open."""
    hall(0.01, (0.5, 0.5, 0.52))
    side_run("mall_shutter", -24, 16, 144, rot=90)
    side_run("mall_shutter", 24, 16, 144, rot=-90)
    side_run("wall_upper", -24, 16, 144, (16,), rot=90)
    side_run("wall_upper", 24, 16, 144, (16,), rot=-90)
    grid("drop_ceiling", (-16, 0, 16), range(16, 160, 16), 24)
    for y in (24, 72, 120):
        place("light_troffer", (0, y, 23.3))
        lamp("AREA", (0, y, 22.5), 3500 if y != 72 else 400, (0.9, 0.95, 1.0), size=6, aim=(0, y, 0))
    fill((0, 80), 23, 44, 9000, (0.85, 0.9, 1.0))
    place("mall_planter", (0, 48, 0))
    place("mall_kiosk", (0, 96, 0))
    place("pink_bench", (-12, 64, 0), rot=90)
    place("fun/neon_open_sign", (21.5, 112, 7), rot=-90)
    lamp("POINT", (20, 112, 7), 120, (1.0, 0.3, 0.4), size=1)
    place("haunt/greeter", (6, 140, 0), rot=180)
    torch((0.5, 2, 5.2), (0, 60, 0))
    camera((-4, 0, 5.2), (0, 140, 6), lens=22)
    render("mall")


def shot_party():
    """A kids' party room set up for a party nobody came to."""
    hall(0.006)
    grid("carpet_party", (-16, 16), (48, 80), 0.2)
    wall_run("wall_party", -24, 24, 96)
    side_run("wall_party", -32, 40, 88, rot=90)
    side_run("wall_party", 32, 40, 88, rot=-90)
    grid("drop_ceiling", (-24, -8, 8, 24), (40, 56, 72, 88), 16)
    place("fun/vending_machine", (14, 92, 0), rot=0)
    lamp("POINT", (14, 88, 4), 150, (0.6, 0.8, 1.0), size=1.5)
    place("crate_stack_plastic", (22, 90, 0), rot=10)
    place("fun/arcade_cabinet", (-20, 92, 0))
    place("star_decal", (-6, 95.4, 9))
    place("star_decal", (4, 95.4, 11), rot=0)
    for x, y in ((-12, 56), (12, 56), (0, 80)):
        lamp("SPOT", (x, y, 15.5), 3000, (1.0, 0.92, 0.8), size=0.5, aim=(x, y, 0), spot=60)
    place("robots/cook", (-4, 76, 0.05), rot=200)
    fill((0, 68), 15.5, 50, 9000)
    camera((0, 22, 5.2), (0, 90, 7), lens=22)
    render("party")


def shot_office():
    """Yellow office walls that don't end, buzzing panels, one drinks machine, a chair facing a wall."""
    hall(0.012, (0.6, 0.6, 0.45))
    grid("carpet_office", (-32, 0, 32), (32, 64, 96, 128), 0.2)
    for x, y, r in ((-24, 48, 0), (-8, 48, 0), (24, 80, 0), (40, 80, 0), (-40, 112, 0), (-24, 112, 0), (8, 112, 0)):
        place("wall_office", (x, y, 0), rot=r)
    for x, y, r in ((16, 56, 90), (16, 40, 90), (-16, 88, 90), (-16, 104, 90), (32, 120, 90), (32, 136, 90)):
        place("wall_office", (x, y, 0), rot=r)
    grid("drop_ceiling", range(-40, 41, 16), range(24, 145, 16), 16)
    for x in (-24, 0, 24):
        for y in (40, 72, 104, 136):
            place("light_troffer", (x, y, 15.3))
            lamp("AREA", (x, y, 14.8), 1800, (1.0, 0.97, 0.75), size=5, aim=(x, y, 0))
    place("fun/vending_machine", (4, 100, 0))
    lamp("POINT", (4, 97, 4), 120, (0.6, 0.8, 1.0), size=1.5)
    place("furniture/office_chair", (-8, 50, 0.05), rot=180)
    camera((2, 6, 5.2), (0, 110, 5), lens=22)
    render("office")


def shot_basement():
    """A carpeted basement: stairs up into a wall, a TV on, a door onto a cold blue room."""
    hall(0.006)
    grid("carpet_office", (-16, 16), (48, 80), 0.2)
    for x in (-24, -8, 24):
        place("wall_lower", (x, 96, 0))
    side_run("wall_lower", -32, 40, 88, rot=90)
    side_run("wall_lower", 32, 40, 88, rot=-90)
    grid("drop_ceiling", (-24, -8, 8, 24), (40, 56, 72, 88), 14)
    place("stairs_to_wall", (-22, 80, 0), rot=0)
    place("doorway_blue", (8, 96, 0.2))
    lamp("AREA", (8, 99, 4), 600, (0.5, 0.7, 1.0), size=4, aim=(8, 60, 2))
    place("furniture/couch", (0, 60, 0.05), rot=180)
    place("fun/crt_tv", (0, 76, 0.05))
    lamp("POINT", (0, 74, 3), 60, (0.7, 0.8, 1.0), size=1)
    place("furniture/floor_lamp", (8, 58, 0.05))
    lamp("POINT", (8, 58, 5), 90, (1.0, 0.75, 0.45), size=0.6)
    fill((0, 68), 13.5, 40, 3500, (1.0, 0.85, 0.65))
    camera((6, 30, 5.2), (0, 90, 5), lens=22)
    render("basement")


def shot_library():
    """A library on grass: shelves in rows, one green lamp on."""
    hall(0.008, (0.5, 0.45, 0.35))
    grid("turf_tile", (-32, 0, 32), (48, 80, 112))
    for row, y in enumerate((60, 76, 92, 108, 124)):
        for x in range(-40, 41, 4):
            if abs(x) > 6:
                place("furniture/bookshelf", (x, y, 0.7))
    place("reading_desk", (0, 46, 0.7))
    lamp("POINT", (2, 46, 3.5), 80, (0.7, 1.0, 0.6), size=0.4)
    for x, y in ((-24, 70), (24, 100), (0, 120)):
        lamp("AREA", (x, y, 20), 9000, (1.0, 0.85, 0.6), size=24, aim=(x, y, 0))
    camera((4, 22, 5.4), (0, 100, 5), lens=22)
    render("library")


def shot_nightlot():
    """A parking lot at night inside a building, under orange sodium lamps."""
    wipe()
    world((0.01, 0.006, 0.02), 0.01, (0.55, 0.4, 0.3))
    grid("parking_tile", (-48, -16, 16, 48), (16, 48, 80, 112, 144))
    for x, y in ((-32, 40), (32, 72), (-32, 104), (32, 136)):
        place("sodium_lamp", (x, y, 0.2))
        lamp("SPOT", (x, y, 25), 9000, (1.0, 0.55, 0.2), size=1, aim=(x, y, 0), spot=110)
    place("cart_corral", (8, 88, 0.2), rot=90)
    place("shopping_cart", (-6, 60, 0.2), rot=35)
    place("robots/brute", (20, 128, 0.2), rot=200)
    camera((-10, -4, 5.4), (0, 120, 6), lens=22)
    render("nightlot")


def shot_softplay():
    """A padded play corridor, too quiet, a mirror ball still turning."""
    hall(0.006)
    grid("padded_floor", (0,), (32, 64, 96, 128))
    side_run("padded_wall", -16, 24, 136, rot=90)
    side_run("padded_wall", 16, 24, 136, rot=-90)
    grid("drop_ceiling", (-8, 8), range(24, 145, 16), 16)
    place("fun/disco_ball", (0, 90, 12.5))
    for y, c in ((40, (1, 0.3, 0.4)), (80, (0.3, 0.5, 1)), (120, (1, 0.8, 0.2))):
        lamp("SPOT", (0, y, 15.5), 2500, c, size=0.5, aim=(0, y, 0), spot=70)
    fill((0, 80), 15.5, 30, 6000, (1.0, 0.9, 0.95))
    place("haunt/kid_ball", (3, 50, 0.4))
    place("haunt/kid_ball", (-4, 70, 0.4))
    camera((0, 14, 5.2), (0, 130, 4), lens=22)
    render("softplay")


def shot_monolith():
    """A huge black block hanging over a field of fake grass, no wires."""
    hall(0.006, (0.6, 0.65, 0.7))
    grid("turf_tile", (-64, -32, 0, 32, 64), (32, 64, 96, 128, 160))
    place("monolith", (0, 110, 18), rot=10)
    lamp("AREA", (0, 100, 90), 50000, (0.85, 0.9, 1.0), size=120, aim=(0, 100, 0))
    place("robots/scout", (-6, 80, 0.7), rot=170)
    camera((-4, 20, 3.5), (0, 110, 32), lens=20)
    render("monolith")


def shot_grandma():
    """A cosy living room where everything faces the wall and the TV is on with no cord."""
    hall(0.005)
    grid("floor_wood", (-16, 16), (48, 80), 0.2)
    wall_run("wall_pastel", -24, 24, 96)
    side_run("wall_pastel", -32, 40, 88, rot=90)
    side_run("wall_pastel", 32, 40, 88, rot=-90)
    fill((0, 70), 15.5, 40, 3000, (1.0, 0.8, 0.6))
    place("furniture/rug", (0, 70, 0.45))
    place("furniture/couch", (0, 90, 0.45), rot=0)
    place("furniture/armchair", (-14, 80, 0.45), rot=90)
    place("fun/crt_tv", (14, 62, 0.45), rot=-90)
    place("furniture/floor_lamp", (-22, 92, 0.45))
    place("ceiling_fan", (0, 70, 16))
    place("picture_frame", (10, 95.4, 8))
    lamp("POINT", (-22, 92, 5), 120, (1.0, 0.7, 0.4), size=0.6)
    lamp("POINT", (14, 62, 2.5), 40, (0.7, 0.8, 1.0), size=1)
    lamp("POINT", (0, 70, 14), 300, (1.0, 0.8, 0.55), size=2)
    camera((-4, 32, 5.2), (0, 88, 5), lens=22)
    render("grandma")


def shot_maze():
    """A plastic hedge maze under ceiling suns, too perfect, no way out."""
    hall(0.004, (0.6, 0.65, 0.7))
    grid("turf_tile", (-48, -16, 16, 48), (32, 64, 96, 128, 160))
    for x, y, r in ((-24, 40, 90), (-24, 56, 90), (24, 40, 90), (24, 56, 90), (-40, 64, 0), (24, 72, 90),
                    (24, 88, 90), (8, 96, 0), (-8, 96, 0), (-24, 88, 90), (-24, 104, 90), (-8, 112, 0), (24, 112, 90),
                    (8, 128, 0), (24, 128, 90), (-24, 128, 90), (-8, 144, 0)):
        place("hedge_wall", (x, y, 0.7), rot=r)
    grid("sun_panel", (-32, 0, 32), (48, 80, 112, 144), 50)
    lamp("AREA", (0, 100, 49), 40000, (0.9, 0.95, 1.0), size=100, aim=(0, 100, 0))
    place("lawn_flamingo", (8, 80, 0.7), rot=30)
    camera((0, 22, 5.4), (0, 100, 8), lens=22)
    render("maze")


def shot_playground():
    """A playground at blue hour inside a building: one swing wrapped over the bar."""
    wipe()
    world((0.02, 0.03, 0.06), 0.006, (0.4, 0.5, 0.7))
    floor_strip(["floor_tile", "floor_cracked"], range(-96, 128, 32), range(-48, 208, 32))
    grid("mulch_tile", (-16, 16), (48, 80))
    wall_run("wall_sky", -56, 56, 120, (0, 16, 32))
    place("slide", (-10, 70, 0.3), rot=30)
    place("swing_set", (12, 78, 0.3), rot=0)
    place("fake_tree", (-30, 96, 0))
    place("fake_tree", (32, 104, 0))
    lamp("AREA", (0, 80, 40), 15000, (0.55, 0.65, 1.0), size=80, aim=(0, 80, 0))
    lamp("SPOT", (40, 40, 20), 6000, (1.0, 0.55, 0.3), size=1, aim=(0, 80, 0), spot=40)
    camera((-6, 30, 5.2), (0, 90, 6), lens=22)
    render("playground")


def shot_nursery():
    """A nursery where the rocking horse is huge and the bed is tiny, moon in the window."""
    hall(0.005)
    grid("floor_wood", (-16, 16), (48, 80), 0.2)
    fill((0, 70), 30, 40, 4000, (0.75, 0.8, 1.0))
    wall_run("wall_pastel", -24, 24, 96, (0, 16))
    side_run("wall_pastel", -32, 40, 88, (0, 16), rot=90)
    side_run("wall_pastel", 32, 40, 88, (0, 16), rot=-90)
    place("rocking_horse_giant", (-4, 76, 0.45), rot=20)
    place("furniture/kid_bed", (16, 86, 0.45))
    place("furniture/toy_chest", (22, 72, 0.45), rot=-90)
    place("curtains", (-14, 95.2, 4))
    place("moon_window", (-14, 95.4, 9))
    lamp("SPOT", (-14, 90, 10), 1500, (0.7, 0.8, 1.0), size=1, aim=(0, 70, 0), spot=60)
    lamp("POINT", (16, 84, 3), 50, (1.0, 0.7, 0.4), size=0.5)
    camera((6, 30, 5.2), (0, 85, 10), lens=22)
    render("nursery")


SHOTS = {"aisle": shot_aisle, "installation": shot_installation, "pillar": shot_pillar, "culdesac": shot_culdesac,
         "pool": shot_pool, "courtyard": shot_courtyard, "catwalk": shot_catwalk, "blacksun": shot_blacksun, "mall": shot_mall,
         "party": shot_party, "office": shot_office, "basement": shot_basement, "library": shot_library,
         "nightlot": shot_nightlot, "softplay": shot_softplay, "monolith": shot_monolith, "grandma": shot_grandma,
         "maze": shot_maze, "playground": shot_playground, "nursery": shot_nursery}
for name in WANT:
    if name in SHOTS:
        SHOTS[name]()
