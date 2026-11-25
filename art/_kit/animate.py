# Animation clips for a robot or the dog. Imports the model FBX, puts a bone on every part (bone name = part name,
# so Roblox's FBX animation import maps bones onto the Motor6D parts), keys the clips, then writes per model:
#   anim/<clip>.fbx   armature only, one clip each, for Roblox's Animation Editor import
#   anim/anim.json    the same keys as numbers, so code could build KeyframeSequences instead
#   anim/preview.mp4  every clip in a row, for judging the motion
# _kit/run.sh _kit/animate.py robots/scout/scout.fbx
import bpy, json, math, os, subprocess, sys
from mathutils import Matrix, Vector as V, Euler

fbx = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
NAME = os.path.splitext(os.path.basename(fbx))[0]
FOLDER = os.path.dirname(fbx)
OUT = os.path.join(FOLDER, "anim")
TMP = os.environ.get("ANIM_TMP", os.path.join(OUT, "_frames"))
FPS = 30
os.makedirs(OUT, exist_ok=True)
os.makedirs(TMP, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=fbx)
scn = bpy.context.scene
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
names = {o.name for o in meshes}
bpy.context.view_layer.update()
zs = [(o.matrix_world @ v.co).z for o in meshes for v in o.data.vertices]
# the kit exports at global_scale 0.01, which comes back 100x off on re-import; every model here is 0.3 to 30 studs
_h = max(zs) - min(zs)
IMPORT_SCALE = 0.01 if _h > 30 else 100.0 if _h < 0.3 else 1.0
# back to studs, rotation and scale baked in, origins kept at the joints
for o in meshes:
    o.matrix_world = Matrix.Scale(IMPORT_SCALE, 4) @ o.matrix_world
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
bpy.context.view_layer.update()
pts = [o.matrix_world @ v.co for o in meshes for v in o.data.vertices]
lo = V([min(p[i] for p in pts) for i in range(3)])
hi = V([max(p[i] for p in pts) for i in range(3)])
H = hi.z - lo.z

CRITTER = NAME in ("pigeon", "rat", "moth")
KID = "lost_kid" in NAME
MANNEQUIN = "mannequin" in NAME or NAME == "sorter_decoy"
SORTER = NAME == "sorter"  # a robot built into a mannequin: hunter moves plus the mannequin freeze poses
DOG = "Body" in names and not CRITTER
if CRITTER:
    ROOT = "Body"
    PARENT = {"Head": "Body", "WingL": "Body", "WingR": "Body", "Tail": "Body"}
elif DOG:
    ROOT = "Body"
    PARENT = {"Head": "Body", "Jaw": "Head", "Tail": "Body", "LegFL": "Body", "LegFR": "Body", "LegBL": "Body", "LegBR": "Body"}
else:
    ROOT = "Torso"
    PARENT = {"Head": "Torso", "Extra": "Head", "Jaw": "Head", "Lid": "Head", "Legs": "Torso"}
    for pre in ("", "Left"):
        PARENT.update({pre + "UpperArm": "Torso", pre + "Forearm": pre + "UpperArm", pre + "Hand": pre + "Forearm",
                       pre + "Thigh": "Torso", pre + "Shin": pre + "Thigh"})
    PARENT.update({f"Leg{i}": "Torso" for i in range(1, 7)})
CRAWLER = "Leg1" in names
HUNTER = any(k in NAME for k in ("scout", "brute", "crawler"))


def joint_at(o):
    if o.name == "Body":  # the dog sits and rocks around its back hips
        back = [bpy.data.objects[n] for n in ("LegBL", "LegBR") if n in names]
        if back:
            return sum((b.matrix_world.translation for b in back), V()) / len(back)
    return o.matrix_world.translation.copy()


# Armature: every bone points straight up with no roll, so bone X = world X, bone Y = world Z, bone Z = world -Y.
arm_data = bpy.data.armatures.new(NAME + "_rig")
rig = bpy.data.objects.new(NAME + "_rig", arm_data)
scn.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
eb = {}
order = [ROOT] + [n for n in PARENT if n in names]
order += [n for n in names if n not in order]
for n in order:
    o = bpy.data.objects[n]
    b = arm_data.edit_bones.new(n)
    b.head = joint_at(o)
    b.tail = b.head + V((0, 0, H * 0.06))
    b.roll = 0
    eb[n] = b
for n in order:
    if n != ROOT:
        eb[n].parent = eb[PARENT.get(n, ROOT)] if PARENT.get(n, ROOT) in eb else eb[ROOT]
bpy.ops.object.mode_set(mode="OBJECT")
for o in meshes:
    mw = o.matrix_world.copy()
    o.parent = rig
    o.parent_type = "BONE"
    o.parent_bone = o.name
    o.matrix_world = mw
for pb in rig.pose.bones:
    pb.rotation_mode = "XYZ"


# ---------- clip helpers: pose(t) returns {bone: (rx, ry, rz)} in world axis degrees, plus "_root": (dx, dy, dz) in studs ----------
# Right hand rule. Hanging limbs swing forward with negative rx. A head or torso leans forward with positive rx.
# Positive rz turns toward the model's own left (+x). Facing is -y.
S = lambda t, k=1, ph=0.0: math.sin(2 * math.pi * (t * k + ph))
C = lambda t, k=1, ph=0.0: math.cos(2 * math.pi * (t * k + ph))
ease = lambda x: x * x * (3 - 2 * x)


def ramp(t, a, b):
    return ease(min(1.0, max(0.0, (t - a) / (b - a))))


def window(t, a, b):
    return 1.0 if a <= t < b else 0.0


def add(p, bone, rx=0.0, ry=0.0, rz=0.0):
    if bone in names or bone == "_root":
        x, y, z = p.get(bone, (0.0, 0.0, 0.0))
        p[bone] = (x + rx, y + ry, z + rz)


def both(p, part, rx_right, rx_left=None, ry=0.0, rz=0.0):
    add(p, part, rx_right, ry, rz)
    add(p, "Left" + part, rx_right if rx_left is None else rx_left, -ry, -rz)


def walk_legs(p, t, amp, knee, lean=0.0):
    add(p, "Thigh", -amp * S(t) - lean)
    add(p, "LeftThigh", amp * S(t) - lean)
    add(p, "Shin", knee * max(0.0, C(t)))
    add(p, "LeftShin", knee * max(0.0, -C(t)))
    add(p, "_root", 0, 0, H * (0.012 * abs(C(t)) - 0.006))


def tripod(p, t, swing, lift):
    """Crawler legs: 1-3 on its right (x < 0), 4-6 on its left. Legs 1, 3, 5 step together, then 2, 4, 6."""
    for i in range(1, 7):
        ph = 0.0 if i in (1, 3, 5) else 0.5
        right = i <= 3
        sw = swing * S(t, 1, ph)
        up = lift * max(0.0, C(t, 1, ph))
        add(p, f"Leg{i}", 0, up if right else -up, sw if right else -sw)
    add(p, "_root", 0, 0, H * 0.02 * abs(S(t, 2)))


# ---------- robot clips ----------
def idle(t):
    p = {}
    add(p, "_root", 0, 0, H * 0.004 * S(t, 2))
    add(p, "Head", 3 * S(t, 1, 0.25), 0, 18 * S(t))
    both(p, "UpperArm", 3 * S(t, 2), -3 * S(t, 2))
    if CRAWLER:
        for i in range(1, 7):
            add(p, f"Leg{i}", 0, 2 * S(t, 2, i * 0.15), 0)
    return p


def walk(t):
    p = {}
    if CRAWLER:
        tripod(p, t, 20, 16)
    else:
        walk_legs(p, t, 24, 34)
        add(p, "UpperArm", 16 * S(t))
        add(p, "LeftUpperArm", -16 * S(t))
        both(p, "Forearm", -10)
    add(p, ROOT, 0, 0, 4 * S(t))
    add(p, "Head", 0, 0, -3 * S(t))
    return p


def chase(t):
    p = {}
    lean = 8 if CRAWLER else 14
    add(p, ROOT, lean, 0, 5 * S(t))
    if CRAWLER:
        tripod(p, t, 28, 22)
        for i in range(1, 7):
            add(p, f"Leg{i}", -lean * 0.3)
    else:
        walk_legs(p, t, 40, 60, lean)
    # arms reach forward for you, fingers out
    add(p, "UpperArm", -lean - 70 + 10 * S(t), 0, 0)
    add(p, "LeftUpperArm", -lean - 70 - 10 * S(t), 0, 0)
    both(p, "Forearm", -12)
    add(p, "Head", -lean * 0.6, 0, 6 * S(t, 2))
    return p


def grab(t):
    p = {}
    reach = ramp(t, 0.0, 0.35) - ramp(t, 0.6, 1.0) * 0.7
    add(p, ROOT, 16 * reach)
    if not CRAWLER:
        both(p, "Thigh", -16 * reach)
        both(p, "Shin", 8 * reach)
    both(p, "UpperArm", -16 * reach - 70 * reach)
    both(p, "Forearm", -25 * reach + 30 * ramp(t, 0.4, 0.55) * (1 - ramp(t, 0.7, 1.0)), rz=10 * ramp(t, 0.4, 0.5))
    both(p, "Hand", 25 * ramp(t, 0.4, 0.5))
    add(p, "Head", 12 * reach)
    return p


def study(t):
    """Day chore bot turning some old human object over in its hands, head cocked."""
    p = {}
    add(p, "_root", 0, 0, H * 0.003 * S(t, 2))
    add(p, "UpperArm", -45, 0, -8)
    add(p, "Forearm", -55)
    add(p, "Hand", 0, 0, 45 * S(t, 2))
    add(p, "LeftUpperArm", -30 + 6 * S(t, 3), 0, 8)
    add(p, "LeftForearm", -50 + 15 * max(0.0, S(t, 3)))
    add(p, "Head", 22, 14 * S(t, 1), 10 * S(t, 1, 0.3))
    return p


def scan(t):
    """Night sweep: slow heavy walk while the head sweeps side to side."""
    p = {}
    if CRAWLER:
        tripod(p, t * 2 % 1.0, 14, 10)
    else:
        walk_legs(p, t * 2 % 1.0, 16, 22, 6)
        add(p, "UpperArm", 8 * S(t, 2) - 6)
        add(p, "LeftUpperArm", -8 * S(t, 2) - 6)
    add(p, ROOT, 6)
    add(p, "Head", -4, 0, 55 * S(t))
    return p


def stall_pose(p):
    add(p, ROOT, 10, 6, 0)
    add(p, "Head", 38, 14, 8)
    both(p, "UpperArm", 6, 2, ry=4)
    both(p, "Forearm", 4)
    add(p, "Hand", 10)
    if CRAWLER:
        for i, (up, sw) in enumerate(((10, 6), (-4, 0), (2, -8), (-12, 4), (4, 10), (0, -6)), 1):
            add(p, f"Leg{i}", -4, up if i <= 3 else -up, sw)
    else:
        add(p, "Thigh", -22 - 10)  # frozen mid step
        add(p, "Shin", 26)
        add(p, "LeftThigh", 12 - 10)
        add(p, "LeftShin", 4)


def stall(t):
    """Hunter at lights on: frozen where it stood, slumped, with sudden twitches. Says ERROR. NEEDS MORE TRAINING."""
    p = {}
    stall_pose(p)
    add(p, "Head", -10 * window(t, 0.30, 0.34), -18 * window(t, 0.30, 0.34), 26 * window(t, 0.30, 0.34))
    add(p, "UpperArm", -35 * window(t, 0.62, 0.65))
    add(p, "Hand", 0, 0, 30 * window(t, 0.62, 0.66))
    shudder = window(t, 0.80, 0.88) * (1 if int(t * 90) % 2 else -1)
    add(p, "Head", 0, 0, 6 * shudder)
    add(p, ROOT, 0, 2 * shudder, 0)
    if CRAWLER:
        add(p, "Leg2", 0, 18 * window(t, 0.62, 0.66), 0)
    return p


def wake(t):
    """Siren: the frozen hunter jerks back to life, head snapping up past straight, then settles ready to hunt."""
    p = {}
    k = 1 - ramp(t, 0.2, 0.32)
    stall_pose(p)
    p = {b: tuple(v * k for v in r) for b, r in p.items()}
    snap = ramp(t, 0.2, 0.32) * (1 - ramp(t, 0.32, 1.0))
    add(p, "Head", -20 * snap, 0, 10 * snap)
    add(p, ROOT, -6 * snap + 6 * ramp(t, 0.32, 1.0))
    both(p, "UpperArm", -40 * snap - 20 * ramp(t, 0.32, 1.0), ry=-15 * snap)
    both(p, "Forearm", -15 * ramp(t, 0.32, 1.0))
    if not CRAWLER:
        both(p, "Thigh", -6 * ramp(t, 0.32, 1.0))
        both(p, "Shin", 10 * ramp(t, 0.32, 1.0))
    return p


# ---------- dog clips ----------
def tail_wag(p, t, speed, amp):
    add(p, "Tail", 0, 0, amp * S(t, speed))


def dog_idle(t):
    p = {}
    add(p, "_root", 0, 0, H * 0.006 * S(t, 2))
    add(p, "Head", 5 * S(t, 1, 0.3), 6 * S(t, 1, 0.6), 20 * S(t))
    tail_wag(p, t, 4, 25)
    return p


def dog_walk(t):
    p = {}
    for leg, ph in (("LegFL", 0.0), ("LegBR", 0.0), ("LegFR", 0.5), ("LegBL", 0.5)):
        add(p, leg, -22 * S(t, 1, ph))
    add(p, "_root", 0, 0, H * 0.01 * abs(C(t)))
    add(p, "Head", 3 * S(t, 2))
    tail_wag(p, t, 2, 20)
    return p


def dog_run(t):
    p = {}
    for leg, ph in (("LegFL", 0.0), ("LegFR", 0.06), ("LegBL", 0.5), ("LegBR", 0.56)):
        add(p, leg, -38 * S(t, 1, ph))
    add(p, "Body", 7 * S(t, 1, 0.25))
    add(p, "_root", 0, 0, H * 0.04 * max(0.0, S(t, 1, 0.1)))
    add(p, "Head", -6 * S(t, 1, 0.25))
    add(p, "Tail", -15, 0, 8 * S(t, 2))
    return p


def dog_sit(t):
    p = {}
    k = ramp(t, 0.0, 0.5)
    add(p, "Body", -32 * k)
    add(p, "_root", 0, 0, -H * 0.06 * k)
    both_dog = (("LegBL", -62), ("LegBR", -62), ("LegFL", 32), ("LegFR", 32))
    for leg, a in both_dog:
        add(p, leg, a * k)
    add(p, "Head", 22 * k, 10 * ramp(t, 0.6, 0.8) * (1 - ramp(t, 0.85, 1.0)), 0)
    tail_wag(p, t, 3, 18 * ramp(t, 0.5, 0.7))
    return p


def dog_bark(t):
    p = {}
    for start in (0.1, 0.45):
        b = window(t, start, start + 0.14)
        add(p, "Head", -14 * b)
        add(p, "Jaw", 30 * b)
        add(p, "Body", -4 * b)
        both_front = ("LegFL", "LegFR")
        for leg in both_front:
            add(p, leg, 6 * b)
    tail_wag(p, t, 3, 15)
    return p


def dog_bite(t):
    p = {}
    lunge = ramp(t, 0.1, 0.35) * (1 - ramp(t, 0.6, 1.0))
    add(p, "_root", 0, -H * 0.25 * lunge, 0)
    add(p, "Body", 10 * lunge)
    add(p, "Head", 18 * lunge)
    add(p, "Jaw", 35 * ramp(t, 0.15, 0.3) * (1 - ramp(t, 0.35, 0.4)))
    for leg in ("LegFL", "LegFR"):
        add(p, leg, -30 * lunge)
    for leg in ("LegBL", "LegBR"):
        add(p, leg, 20 * lunge)
    add(p, "Tail", -20 * lunge)
    return p


# ---------- the lost kid: slow, wrong, never quite human ----------
def kid_idle(t):
    """Dead still. A breath, a slow head roll, fingers that twitch on their own."""
    p = {}
    add(p, "Torso", 1.5 * S(t))
    add(p, "Head", 4, 8 * S(t) + 6, 3 * S(t, 1, 0.3))
    twitch = window(t, 0.62, 0.66) - window(t, 0.66, 0.7)
    add(p, "Hand", 25 * twitch)
    add(p, "LeftHand", -12 * window(t, 0.2, 0.24))
    both(p, "UpperArm", 2, 2, ry=-3)
    return p


def kid_tilt(t):
    """The head tilts slowly, far too far, holds, then snaps back."""
    p = {}
    k = ramp(t, 0.05, 0.6) * (1 - window(t, 0.88, 1.01))
    add(p, "Head", 10 * k, 78 * k, 8 * k)
    add(p, "Torso", 0, -6 * k, 0)
    both(p, "UpperArm", 2, 2, ry=-3)
    return p


def kid_giggle(t):
    """Hands up to the mask, shoulders shaking."""
    p = {}
    k = ramp(t, 0.0, 0.2) * (1 - ramp(t, 0.85, 1.0))
    shake = S(t, 9) * k
    add(p, "Torso", 6 * k + 3 * shake, 0, 2 * S(t, 9, 0.25) * k)
    add(p, "Head", 14 * k + 6 * shake, 6 * k)
    both(p, "UpperArm", -45 * k, ry=-10 * k)
    both(p, "Forearm", -95 * k, rz=20 * k)
    add(p, "_root", 0, 0, H * 0.006 * shake)
    return p


def kid_walk(t):
    """Stiff, a dragging step, arms hanging dead, head cocked."""
    p = {}
    add(p, "Thigh", -16 * S(t))
    add(p, "LeftThigh", 10 * S(t))
    add(p, "Shin", 22 * max(0.0, C(t)))
    add(p, "LeftShin", 8 * max(0.0, -C(t)))
    add(p, "_root", 0, 0, H * (0.01 * abs(C(t)) - 0.005))
    add(p, "Torso", 3, 4 * S(t), 0)
    add(p, "Head", 8, 24, 0)
    both(p, "UpperArm", 2 * S(t), -2 * S(t), ry=-2)
    return p


def kid_run(t):
    """Runs away giggling, arms flung back."""
    p = {}
    walk_legs(p, t, 42, 70, 10)
    add(p, "Torso", 14, 0, 8 * S(t))
    both(p, "UpperArm", 50, ry=-14)
    both(p, "Forearm", -20)
    add(p, "Head", -6, 10 * S(t, 2))
    return p


def kid_peek(t):
    """Leans out sideways from behind a shelf, head tipped further, then slides back."""
    p = {}
    k = ramp(t, 0.1, 0.45) * (1 - ramp(t, 0.75, 0.95))
    add(p, "Torso", 0, -34 * k)
    add(p, "Head", 0, -40 * k, 10 * k)
    add(p, "_root", -H * 0.12 * k, 0, 0)
    add(p, "LeftUpperArm", 0, 0, 0)
    add(p, "UpperArm", -20 * k, 20 * k)
    add(p, "Forearm", -40 * k)
    return p


def kid_point(t):
    """Slowly points at you. Holds it."""
    p = {}
    k = ramp(t, 0.1, 0.7)
    add(p, "UpperArm", -88 * k, 0, -6 * k)
    add(p, "Forearm", -4 * k)
    add(p, "Hand", -10 * k)
    add(p, "Head", 6 * k, 30 * ramp(t, 0.5, 0.9))
    return p


def kid_wave(t):
    """A small, slow wave. Only the hand moves."""
    p = {}
    add(p, "LeftUpperArm", -20, 0, 0)
    add(p, "LeftForearm", -120)
    add(p, "LeftHand", 0, 0, 0)
    add(p, "LeftForearm", 0, 0, 22 * S(t, 2))
    add(p, "Head", 6, 18)
    return p


# ---------- mannequin: still poses it snaps between while nobody looks ----------
def mq_pose(pose):
    def fn(t):
        p = {}
        if pose == "stand":
            add(p, "LeftUpperArm", 0, -18)
            add(p, "LeftForearm", -70, 0, 50)
            add(p, "Head", 0, 0, 10)
        elif pose == "reach":
            add(p, "UpperArm", -85)
            add(p, "LeftUpperArm", -70)
            add(p, "Torso", 10)
            add(p, "Head", -8, 14)
            add(p, "Thigh", -20)
            add(p, "Shin", 15)
        elif pose == "turn":
            add(p, "Head", 0, 6, -100)
            add(p, "Torso", 0, 0, -20)
            both(p, "UpperArm", 4, ry=-6)
        elif pose == "crouch":
            add(p, "_root", 0, 0, -H * 0.2)
            both(p, "Thigh", -80)
            both(p, "Shin", 110)
            add(p, "Torso", 30)
            both(p, "UpperArm", -60, ry=-10)
            both(p, "Forearm", -30)
            add(p, "Head", -30)
        elif pose == "face":
            both(p, "UpperArm", -40, ry=-12)
            both(p, "Forearm", -110, rz=20)
            add(p, "Head", 25, 15)
        return p
    return fn


# ---------- critters ----------
def wings(p, amp, speed, t, base=0.0):
    flap = base + amp * S(t, speed)
    add(p, "WingL", 0, -flap)
    add(p, "WingR", 0, flap)


def pigeon_idle(t):
    """Looks around in little jerks, like pigeons do."""
    p = {}
    step = [0, 25, 25, -20, -20, 5, 5, 30][int(t * 8) % 8]
    add(p, "Head", 4 * window(t, 0.5, 0.6), 0, step)
    add(p, "Tail", 4 * S(t, 2))
    return p


def pigeon_peck(t):
    p = {}
    for a in (0.15, 0.45, 0.7):
        k = window(t, a, a + 0.1)
        add(p, "Body", 22 * k)
        add(p, "Head", 45 * k)
    add(p, "Tail", -10 * window(t, 0.15, 0.8))
    return p


def pigeon_walk(t):
    p = {}
    add(p, "Head", 0, 0, 0)
    add(p, "_root", 0, -H * 0.06 * ramp(t % 0.5 * 2, 0, 1), H * 0.02 * abs(S(t, 2)))
    add(p, "Head", -18 * S(t, 2), 0, 0)
    add(p, "Body", 0, 0, 6 * S(t))
    return p


def pigeon_fly(t):
    p = {}
    wings(p, 55, 4, t, 35)
    add(p, "Body", -10)
    add(p, "Head", -8)
    add(p, "Tail", -12)
    add(p, "_root", 0, 0, H * (0.25 + 0.06 * S(t, 4, 0.25)))  # hovers; the game flies it around
    return p


def pigeon_takeoff(t):
    """The burst: crouch, then up and away fast. This is the one that gives you away."""
    p = {}
    up = ramp(t, 0.15, 1.0)
    wings(p, 60 * ramp(t, 0.1, 0.2), 5, t, 40 * ramp(t, 0.1, 0.2))
    add(p, "Body", 10 * window(t, 0.0, 0.15) - 25 * up)
    add(p, "_root", 0, H * 0.6 * up, H * 0.9 * up)
    return p


def rat_idle(t):
    """Sniffing, whiskers going, tail sweeping."""
    p = {}
    add(p, "Head", 6 * S(t, 6) * window(t, 0.2, 0.7), 0, 15 * S(t))
    add(p, "Tail", 0, 0, 12 * S(t, 1, 0.3))
    return p


def rat_scurry(t):
    p = {}
    add(p, "Body", 0, 0, 7 * S(t))
    add(p, "_root", 0, -H * 1.5 * t, H * 0.06 * abs(S(t, 2)))
    add(p, "Head", -4 * S(t, 2), 0, -6 * S(t))
    add(p, "Tail", 0, 0, -20 * S(t))
    return p


def rat_rear(t):
    """Up on its back legs, sniffing toward your light, then down and gone."""
    p = {}
    k = ramp(t, 0.05, 0.3) * (1 - ramp(t, 0.75, 0.9))
    add(p, "Body", -55 * k)
    add(p, "_root", 0, H * 0.1 * k, H * 0.35 * k)
    add(p, "Head", 35 * k + 6 * S(t, 7) * k)
    add(p, "Tail", -30 * k)
    return p


def moth_flutter(t):
    p = {}
    wings(p, 60, 12, t, 10)
    add(p, "_root", H * 0.4 * S(t, 1), H * 0.3 * C(t, 2), H * (0.6 + 0.3 * S(t, 3)))
    add(p, "Body", 10 * S(t, 3), 0, 0)
    return p


def moth_rest(t):
    p = {}
    wings(p, 20, 1, t, 18)
    return p


if CRITTER:
    CLIPS = {"pigeon": [("idle", pigeon_idle, 48, True), ("peck", pigeon_peck, 40, True), ("walk", pigeon_walk, 24, True),
                         ("fly", pigeon_fly, 16, True), ("takeoff", pigeon_takeoff, 30, False)],
             "rat": [("idle", rat_idle, 48, True), ("scurry", rat_scurry, 16, True), ("rear", rat_rear, 60, False)],
             "moth": [("flutter", moth_flutter, 90, True), ("rest", moth_rest, 60, True)]}[NAME]
elif KID:
    CLIPS = [("idle", kid_idle, 120, True), ("tilt", kid_tilt, 120, False), ("giggle", kid_giggle, 60, False), ("walk", kid_walk, 44, True),
             ("run", kid_run, 18, True), ("peek", kid_peek, 90, False), ("point", kid_point, 75, False), ("wave", kid_wave, 60, True)]
elif MANNEQUIN:
    CLIPS = [(n, mq_pose(n), 12, False) for n in ("stand", "reach", "turn", "crouch", "face")]
elif DOG:
    CLIPS = [("idle", dog_idle, 60, True), ("walk", dog_walk, 30, True), ("run", dog_run, 16, True), ("sit", dog_sit, 60, False),
             ("bark", dog_bark, 36, False), ("bite", dog_bite, 24, False)]
else:
    CLIPS = [("idle", idle, 60, True), ("walk", walk, 32, True), ("chase", chase, 20 if not CRAWLER else 14, True), ("grab", grab, 30, False)]
    if not HUNTER and not SORTER:
        CLIPS.append(("study", study, 90, True))
    CLIPS.append(("scan", scan, 64, True))
    if HUNTER or SORTER:
        CLIPS += [("stall", stall, 90, True), ("wake", wake, 30, False)]
    if SORTER:  # same names as sorter_decoy's, so a real one and a decoy can hold the same pose
        CLIPS += [(n, mq_pose(n), 12, False) for n in ("stand", "reach", "turn", "crouch", "face")]

# ---------- key the clips ----------
data = {"model": NAME, "fps": FPS,
        "axes": "Degrees around Blender world axes (x right, y back, z up; the model faces -y). Roblox: rx is around X, "
                "rz is around Y, ry is around -Z. root is the root part offset in studs, Blender axes.", "clips": {}}
actions = []
for clip, fn, length, loop in CLIPS:
    act = bpy.data.actions.new(f"{NAME}_{clip}")
    rig.animation_data_create()
    rig.animation_data.action = act
    keys, root = {}, []
    for f in range(0, length + 1):
        p = fn(f / length)
        for pb in rig.pose.bones:
            rx, ry, rz = p.get(pb.name, (0.0, 0.0, 0.0))
            pb.rotation_euler = Euler((math.radians(rx), math.radians(rz), math.radians(-ry)), "XYZ")
            pb.location = (0, 0, 0)
            if pb.name == ROOT:
                dx, dy, dz = p.get("_root", (0.0, 0.0, 0.0))
                pb.location = (dx, dz, -dy)
                pb.keyframe_insert("location", frame=f)
                root.append([f, round(dx, 4), round(dy, 4), round(dz, 4)])
            pb.keyframe_insert("rotation_euler", frame=f)
            keys.setdefault(pb.name, []).append([f, round(rx, 2), round(ry, 2), round(rz, 2)])
    for fc in act.fcurves if hasattr(act, "fcurves") else []:
        for kp in fc.keyframe_points:
            kp.interpolation = "LINEAR"
    data["clips"][clip] = {"frames": length, "loop": loop, "keys": keys, "root": root}
    actions.append((clip, act, length, loop))

json.dump(data, open(os.path.join(OUT, "anim.json"), "w"))

for clip, act, length, loop in actions:
    rig.animation_data.action = act
    scn.frame_start, scn.frame_end = 0, length
    scn.render.fps = FPS
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, clip + ".fbx"), use_selection=True, object_types={"ARMATURE"},
                             global_scale=0.01, apply_scale_options="FBX_SCALE_NONE", axis_forward="-Z", axis_up="Y",
                             add_leaf_bones=False, bake_anim=True, bake_anim_use_all_actions=False, bake_anim_use_nla_strips=False,
                             bake_anim_force_startend_keying=True, bake_anim_simplify_factor=0.0)

# ---------- preview video ----------
floor = bpy.data.meshes.new("floor")
s = H * 20
floor.from_pydata([(-s, -s, lo.z), (s, -s, lo.z), (s, s, lo.z), (-s, s, lo.z)], [], [(0, 1, 2, 3)])
scn.collection.objects.link(bpy.data.objects.new("floor", floor))
mid = (lo + hi) / 2
span = max(H, hi.x - lo.x, (hi.y - lo.y) * 0.8)
cam = bpy.data.cameras.new("c")
cam.lens = 40
co = bpy.data.objects.new("c", cam)
a = math.radians(-32)
d = span * 2.6
co.location = mid + V((math.sin(a) * d, -math.cos(a) * d, span * 0.35))
co.rotation_euler = (mid - co.location).to_track_quat("-Z", "Y").to_euler()
scn.collection.objects.link(co)
scn.camera = co
cu = bpy.data.curves.new("label", "FONT")
cu.size = span * 0.07
label = bpy.data.objects.new("label", cu)
label.parent = co
label.location = (-span * 0.62, span * 0.72, -d * 0.97)
scn.collection.objects.link(label)
scn.render.engine = "BLENDER_WORKBENCH"
shade = scn.display.shading
shade.light = "STUDIO"
shade.color_type = "TEXTURE"
shade.show_shadows = True
shade.show_cavity = True
scn.render.resolution_x, scn.render.resolution_y = 540, 600
scn.render.image_settings.file_format = "PNG"
for f in os.listdir(TMP):
    if f.endswith(".png"):
        os.remove(os.path.join(TMP, f))
n = 0
for clip, act, length, loop in actions:
    rig.animation_data.action = act
    cu.body = f"{NAME.replace('_', ' ')}: {clip}"
    for _ in range(2 if loop and length < 40 else 1):
        for f in range(0, length):
            scn.frame_set(f)
            scn.render.filepath = os.path.join(TMP, f"{n:05d}.png")
            bpy.ops.render.render(write_still=True)
            n += 1
    for _ in range(8 if not loop else 0):  # hold the last pose of one-shot clips a moment
        scn.frame_set(length)
        scn.render.filepath = os.path.join(TMP, f"{n:05d}.png")
        bpy.ops.render.render(write_still=True)
        n += 1
mp4 = os.path.join(OUT, "preview.mp4")
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", os.path.join(TMP, "%05d.png"),
                "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "26", mp4], check=True)
print(f"CHECK anim {NAME}: {len(actions)} clips ({', '.join(c[0] for c in actions)}), {n} frames, height {H:.2f} studs, mp4 {os.path.getsize(mp4) // 1024} KB")
