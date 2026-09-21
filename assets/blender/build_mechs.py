"""Mech Junkyard - procedural Blender mech models + side-view sprite renders.

Run: blender -b -P build_mechs.py
Outputs:
  assets/sprites/player/body_*.png      (7 frames, 300x340, no arm)
  assets/sprites/player/arm_*_*.png     (4 arms x rest/attack, 200x200, pivot=center)
  assets/sprites/enemies/<type>_*.png   (5 types x 6 frames, 300x340, arm baked)
  assets/blender/mech_junkyard.blend    (editable source for Jimmy)
Mechs face +X. Ortho camera. Transparent background. Feet at z=0.
"""
import bpy
import math
import os
from mathutils import Vector

OUT = os.path.expanduser("~/workspace/mech-junkyard/assets/sprites")
BLEND = os.path.expanduser("~/workspace/mech-junkyard/assets/blender/mech_junkyard.blend")

# ---------------------------------------------------------------- setup
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 24
scene.render.film_transparent = True
scene.view_settings.view_transform = "Standard"
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.resolution_percentage = 100

# Proven Cycles-CPU rig: bright point key/fill/rim (Blender 4.x watts).
# (Sun lights rendered black in this headless environment; EEVEE is broken
# here too, so we stay on Cycles CPU.)
def make_light(name, loc, energy, color):
    ld = bpy.data.lights.new(name, type="POINT")
    ld.energy = energy
    ld.color = color
    ld.shadow_soft_size = 1.2
    lo = bpy.data.objects.new(name, ld)
    lo.location = loc
    scene.collection.objects.link(lo)
    return lo

make_light("Key", (2.5, -6, 5.5), 1300.0, (1.0, 0.93, 0.82))
make_light("Fill", (-3.5, -5, 2.0), 450.0, (0.75, 0.85, 1.0))
make_light("Rim", (0.5, 6, 4.5), 700.0, (1.0, 0.85, 0.7))

# Ortho side-view camera: looks along +Y, up = +Z, mech faces +X (screen right).
cam_data = bpy.data.cameras.new("RCam")
cam_data.type = 'ORTHO'
cam_obj = bpy.data.objects.new("RCam", cam_data)
scene.collection.objects.link(cam_obj)
scene.camera = cam_obj
cam_obj.rotation_euler = (math.radians(90), 0, 0)

# ---------------------------------------------------------------- materials
def mat(name, color, metallic=0.55, rough=0.52, emission=None, estrength=0.0,
        alpha=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    if emission is not None:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = estrength
    if alpha is not None:
        bsdf.inputs["Alpha"].default_value = alpha
        m.blend_method = 'BLEND'
    return m

# ---------------------------------------------------------------- part builders
def _finish(o, material, bevel):
    o.data.materials.append(material)
    if bevel > 0:
        mod = o.modifiers.new("bev", 'BEVEL')
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = 'ANGLE'
    return o

def box(name, sx, sy, sz, loc, material, bevel=0.025, pivot_top=False):
    bpy.ops.mesh.primitive_cube_add(size=2, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = (sx / 2.0, sy / 2.0, sz / 2.0)
    if pivot_top:
        for v in o.data.vertices:
            v.co.z -= 1.0
        o.data.update()
    return _finish(o, material, bevel)

def cyl(name, r, h, loc, material, axis='Z', verts=12, bevel=0.0):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=h, vertices=verts,
                                        location=loc)
    o = bpy.context.active_object
    o.name = name
    if axis == 'X':
        o.rotation_euler = (0, math.radians(90), 0)
    elif axis == 'Y':
        o.rotation_euler = (math.radians(90), 0, 0)
    return _finish(o, material, bevel)

def sphere(name, r, loc, material, bevel=0.0):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc,
                                        segments=12, ring_count=8)
    o = bpy.context.active_object
    o.name = name
    return _finish(o, material, bevel)

def cone(name, r, h, loc, material, bevel=0.0):
    bpy.ops.mesh.primitive_cone_add(radius1=r, depth=h, location=loc,
                                    vertices=10)
    o = bpy.context.active_object
    o.name = name
    return _finish(o, material, bevel)

def shadow_blob(parent):
    import bmesh
    bpy.ops.mesh.primitive_circle_add(radius=1.0, location=(0.1, 0, 0.02))
    o = bpy.context.active_object
    o.name = parent.name + "_shadow"
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.faces.new(bm.verts)
    bm.to_mesh(o.data)
    bm.free()
    o.data.update()
    o.scale = (1.15, 0.42, 1.0)
    sm = mat(parent.name + "_shadowmat", (0, 0, 0), metallic=0, rough=1,
             alpha=0.38)
    o.data.materials.append(sm)
    o.parent = parent
    return o

def empty(name, loc, parent=None):
    e = bpy.data.objects.new(name, None)
    scene.collection.objects.link(e)
    e.location = loc
    if parent is not None:
        e.parent = parent
    return e

def keep_parent(child, par):
    """Parent while keeping the child's current world transform.

    Every part is created at its intended WORLD location, so parenting only
    needs to preserve it (previous parent_to tried to re-target the world
    location and mis-computed nested chains).
    """
    bpy.context.view_layer.update()
    child.parent = par
    child.matrix_parent_inverse = par.matrix_world.inverted()

# ---------------------------------------------------------------- mech rig
def build_mech(tag, pal, bulk=1.0, arm_kind="fist", spikes=False,
               head_fin=False, build_arm=True):
    """Build a full mech rig. Returns dict of named parts. Faces +X, feet z=0."""
    M = {
        "body": mat(tag + "_body", pal["body"], 0.6, 0.48),
        "dark": mat(tag + "_dark", pal["dark"], 0.45, 0.6),
        "accent": mat(tag + "_accent", pal["accent"], 0.7, 0.35),
        "glow": mat(tag + "_glow", pal["glow"], 0, 0.4,
                    emission=pal["glow"], estrength=6.0),
        "far": mat(tag + "_far", tuple(c * 0.55 for c in pal["body"]), 0.6, 0.55),
        "fardark": mat(tag + "_fardark", tuple(c * 0.55 for c in pal["dark"]),
                       0.45, 0.6),
    }
    rig = empty(tag + "_rig", (0, 0, 0))
    rig.scale = (bulk, bulk, bulk)
    P = {"rig": rig, "mats": M, "bulk": bulk, "tag": tag}

    # Chunky side-view proportions: narrow torso (y) so the near limbs read,
    # big legs, distinct head. Camera at -Y looking +Y; -Y is the near side.
    # Pelvis + torso.
    P["hips"] = box(tag + "_hips", 0.62, 0.58, 0.45, (0, 0, 1.88), M["dark"])
    keep_parent(P["hips"], rig)
    P["torso"] = box(tag + "_torso", 0.88, 0.60, 0.85, (0, 0, 2.52),
                     M["body"])
    keep_parent(P["torso"], P["hips"])
    P["chest"] = box(tag + "_chest", 0.20, 0.66, 0.60, (0.48, 0, 2.50),
                     M["dark"])
    keep_parent(P["chest"], P["torso"])
    # Chest glow vent.
    P["vent"] = box(tag + "_vent", 0.06, 0.36, 0.12, (0.60, 0, 2.35),
                    M["glow"], bevel=0.0)
    keep_parent(P["vent"], P["torso"])
    # Exhaust stacks.
    for i, sy in enumerate([-0.18, 0.18]):
        ex = cyl(tag + "_exhaust%d" % i, 0.09, 0.50, (-0.48, sy, 2.85),
                 M["dark"], verts=10)
        ex.rotation_euler = (0, math.radians(-12), 0)
        keep_parent(ex, P["torso"])
        P["exhaust%d" % i] = ex
    # Head + visor + antenna.
    P["head"] = box(tag + "_head", 0.46, 0.40, 0.38, (0.10, 0, 3.14),
                    M["dark"])
    keep_parent(P["head"], P["torso"])
    P["visor"] = box(tag + "_visor", 0.06, 0.30, 0.13, (0.34, 0, 3.16),
                     M["glow"], bevel=0.0)
    keep_parent(P["visor"], P["head"])
    ant = cyl(tag + "_antenna", 0.03, 0.40, (-0.08, 0, 3.52), M["dark"],
              verts=8)
    keep_parent(ant, P["head"])
    P["antenna"] = ant
    P["ant_tip"] = sphere(tag + "_anttip", 0.05, (-0.08, 0, 3.74),
                          M["accent"])
    keep_parent(P["ant_tip"], P["head"])
    if head_fin:
        fin = box(tag + "_fin", 0.5, 0.08, 0.3, (-0.12, 0, 3.38),
                  M["accent"])
        fin.rotation_euler = (0, math.radians(-25), 0)
        keep_parent(fin, P["head"])
        P["fin"] = fin
    if spikes:
        for i, sx in enumerate([-0.28, 0.05, 0.38]):
            sp = cone(tag + "_spike%d" % i, 0.11, 0.34, (sx, 0, 3.0),
                      M["dark"])
            keep_parent(sp, P["torso"])
            P["spike%d" % i] = sp

    # Legs: near leg (-Y) bright and fully in front of the torso.
    for side, (sy, lm, ldm) in (("n", (-0.32, M["body"], M["dark"])),
                                ("f", (0.32, M["far"], M["fardark"]))):
        thigh = box(tag + "_thigh_" + side, 0.42, 0.38, 0.70, (0, sy, 1.65),
                    lm, pivot_top=True)
        keep_parent(thigh, P["hips"])
        knee = box(tag + "_knee_" + side, 0.44, 0.40, 0.24, (0.06, sy, 0.98),
                   M["accent"] if side == "n" else ldm, bevel=0.02)
        keep_parent(knee, thigh)
        shin = box(tag + "_shin_" + side, 0.34, 0.34, 0.70, (0, sy, 0.95),
                   ldm, pivot_top=True)
        keep_parent(shin, thigh)
        foot = box(tag + "_foot_" + side, 0.70, 0.36, 0.22, (0.15, sy, 0.11),
                   ldm, bevel=0.02)
        keep_parent(foot, shin)
        P["thigh_" + side] = thigh
        P["shin_" + side] = shin
        P["foot_" + side] = foot
        P["knee_" + side] = knee

    # Arm: shoulder well in front of the torso (-Y) so it never hides.
    if build_arm:
        P.update(build_arm_parts(tag, M, arm_kind, P["torso"],
                                 (0.12, -0.52, 2.85)))
    P["shadow"] = shadow_blob(rig)
    return P

def build_arm_parts(tag, M, arm_kind, torso_par, shoulder_loc, prefix="arm"):
    """Arm rig with pivot at shoulder. Returns parts dict (names prefixed)."""
    R = {}
    sx, sy, sz = shoulder_loc
    pad = sphere(tag + "_shoulderpad", 0.24, (sx, sy, sz), M["dark"])
    keep_parent(pad, torso_par)
    R[prefix + "_pad"] = pad
    up = box(tag + "_" + prefix + "_upper", 0.30, 0.30, 0.55,
             (sx, sy, sz), M["dark"], pivot_top=True)
    keep_parent(up, torso_par)
    R[prefix] = up  # rotating this swings the whole arm
    ex, ey, ez = sx + 0.1, sy, sz - 0.55  # elbow
    if arm_kind == "fist":
        fore = box(tag + "_" + prefix + "_fore", 0.26, 0.26, 0.45,
                   (ex, ey, ez), M["dark"], pivot_top=True)
        keep_parent(fore, up)
        fist = box(tag + "_" + prefix + "_fist", 0.42, 0.38, 0.38,
                   (ex + 0.08, ey, ez - 0.6), M["body"])
        keep_parent(fist, fore)
        kn = box(tag + "_" + prefix + "_kn", 0.44, 0.4, 0.12,
                 (ex + 0.08, ey, ez - 0.75), M["accent"], bevel=0.01)
        keep_parent(kn, fore)
        R[prefix + "_fore"] = fore
        R[prefix + "_fist"] = fist
        R[prefix + "_kn"] = kn
    elif arm_kind == "megafist":
        fore = box(tag + "_" + prefix + "_fore", 0.3, 0.3, 0.45,
                   (ex, ey, ez), M["dark"], pivot_top=True)
        keep_parent(fore, up)
        fist = box(tag + "_" + prefix + "_fist", 0.58, 0.52, 0.52,
                   (ex + 0.1, ey, ez - 0.65), M["dark"])
        keep_parent(fist, fore)
        plate = box(tag + "_" + prefix + "_plate", 0.6, 0.54, 0.14,
                    (ex + 0.1, ey, ez - 0.85), M["accent"], bevel=0.01)
        keep_parent(plate, fore)
        R[prefix + "_fore"] = fore
        R[prefix + "_fist"] = fist
        R[prefix + "_plate"] = plate
    elif arm_kind == "blade":
        fore = box(tag + "_" + prefix + "_fore", 0.24, 0.24, 0.4,
                   (ex, ey, ez), M["dark"], pivot_top=True)
        keep_parent(fore, up)
        blade = box(tag + "_" + prefix + "_blade", 0.9, 0.1, 0.22,
                    (ex + 0.45, ey, ez - 0.45), M["accent"], bevel=0.01)
        blade.rotation_euler = (0, math.radians(-8), 0)
        keep_parent(blade, fore)
        R[prefix + "_fore"] = fore
        R[prefix + "_blade"] = blade
    elif arm_kind == "buzzsaw":
        fore = box(tag + "_" + prefix + "_fore", 0.26, 0.26, 0.4,
                   (ex, ey, ez), M["dark"], pivot_top=True)
        keep_parent(fore, up)
        disc = cyl(tag + "_" + prefix + "_disc", 0.34, 0.1,
                   (ex + 0.12, ey, ez - 0.55), M["accent"], axis='Y', verts=20)
        keep_parent(disc, fore)
        R[prefix + "_disc"] = disc
        for i in range(10):
            a = math.radians(i * 36)
            tx = ex + 0.12 + math.cos(a) * 0.36
            tz = ez - 0.55 + math.sin(a) * 0.36
            tooth = box(tag + "_" + prefix + "_tooth%d" % i, 0.1, 0.1, 0.1,
                        (tx, ey, tz), M["accent"], bevel=0.0)
            keep_parent(tooth, fore)
            R[prefix + "_tooth%d" % i] = tooth
        hub = cyl(tag + "_" + prefix + "_hub", 0.09, 0.16,
                  (ex + 0.12, ey, ez - 0.55), M["glow"], axis='Y', verts=10)
        keep_parent(hub, fore)
        R[prefix + "_fore"] = fore
        R[prefix + "_hub"] = hub
    elif arm_kind == "cannon":
        barrel = cyl(tag + "_" + prefix + "_barrel", 0.17, 1.15,
                     (sx + 0.65, sy, sz - 0.62), M["dark"], axis='X', verts=14)
        keep_parent(barrel, up)
        muzzle = cyl(tag + "_" + prefix + "_muzzle", 0.22, 0.18,
                     (sx + 1.18, sy, sz - 0.62), M["accent"], axis='X',
                     verts=14)
        keep_parent(muzzle, up)
        tank = box(tag + "_" + prefix + "_tank", 0.4, 0.3, 0.3,
                   (sx + 0.3, sy, sz - 0.35), M["body"])
        keep_parent(tank, up)
        glowring = cyl(tag + "_" + prefix + "_glowring", 0.19, 0.06,
                       (sx + 1.1, sy, sz - 0.62), M["glow"], axis='X', verts=14)
        keep_parent(glowring, up)
        R[prefix + "_barrel"] = barrel
        R[prefix + "_muzzle"] = muzzle
        R[prefix + "_tank"] = tank
        R[prefix + "_glowring"] = glowring
    return R

# ---------------------------------------------------------------- poses
def _ry(o, deg):
    o.rotation_euler = (0, math.radians(deg), 0)

def reset_pose(P):
    for k, o in P.items():
        if k in ("rig", "mats", "bulk", "tag", "shadow"):
            continue
        if isinstance(o, bpy.types.Object):
            o.rotation_euler = (0, 0, 0)
    P["rig"].location = (0, 0, 0)

def pose_idle(P, variant=0):
    reset_pose(P)
    if variant == 1:
        P["rig"].location = (0, 0, -0.03)
        _ry(P["torso"], 2)
        _ry(P["head"], -3)

def pose_walk(P, frame):
    """frame 0..3 — alternating leg cycle."""
    reset_pose(P)
    ph = frame * math.pi / 2.0
    s = math.sin(ph)
    _ry(P["thigh_n"], 26 * s)
    _ry(P["thigh_f"], -26 * s)
    _ry(P["shin_n"], -(12 + 12 * math.sin(ph - 1.1)))
    _ry(P["shin_f"], -(12 + 12 * math.sin(ph + math.pi - 1.1)))
    _ry(P["foot_n"], 8 * s)
    _ry(P["foot_f"], -8 * s)
    P["rig"].location = (0, 0, -0.045 * abs(math.cos(ph)))
    _ry(P["torso"], 3 * s)
    if "arm" in P:
        _ry(P["arm"], 10 - 9 * s)  # arm counter-swing

def pose_attack(P):
    reset_pose(P)
    P["rig"].location = (0.06, 0, -0.09)
    _ry(P["torso"], 13)
    _ry(P["head"], -8)
    _ry(P["thigh_n"], 22)
    _ry(P["shin_n"], -14)
    _ry(P["thigh_f"], -16)
    _ry(P["shin_f"], -8)
    if "arm" in P:
        _ry(P["arm"], -72)
        if "arm_fore" in P:
            _ry(P["arm_fore"], -12)

def pose_arm(arm_rig, tag, pose):
    """arm_rig: parts from build_arm_parts with prefix 'arm'. Shoulder at origin."""
    for k, o in arm_rig.items():
        if isinstance(o, bpy.types.Object):
            o.rotation_euler = (0, 0, 0)
    if pose == "rest":
        _ry(arm_rig["arm"], 16)
    elif pose == "attack":
        _ry(arm_rig["arm"], -68)
        if "arm_fore" in arm_rig:
            _ry(arm_rig["arm_fore"], -14)

# ---------------------------------------------------------------- render
def render(path, w, h, ortho, cx, cz):
    scene.render.resolution_x = w
    scene.render.resolution_y = h
    cam_data.ortho_scale = ortho
    cam_obj.location = (cx, -8, cz)
    bpy.context.view_layer.update()
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("rendered", path)

def set_visible(objs, vis):
    for o in objs:
        o.hide_render = not vis

def all_rig_objects(P):
    return [o for k, o in P.items()
            if isinstance(o, bpy.types.Object) and k != "shadow"]

# ---------------------------------------------------------------- build everything
PAL_PLAYER = {"body": (0.25, 0.65, 0.77), "dark": (0.11, 0.17, 0.2),
              "accent": (1.0, 0.6, 0.24), "glow": (0.49, 0.98, 1.0)}
PAL_WALKER = {"body": (0.42, 0.5, 0.37), "dark": (0.16, 0.2, 0.15),
              "accent": (0.77, 0.63, 0.25), "glow": (1.0, 0.7, 0.28)}
PAL_SPEEDER = {"body": (0.5, 0.42, 0.37), "dark": (0.2, 0.16, 0.15),
               "accent": (0.25, 0.77, 0.63), "glow": (0.49, 1.0, 0.83)}
PAL_CRUSHER = {"body": (0.5, 0.37, 0.37), "dark": (0.2, 0.15, 0.15),
               "accent": (0.77, 0.25, 0.25), "glow": (1.0, 0.42, 0.42)}
PAL_GUNNER = {"body": (0.45, 0.38, 0.5), "dark": (0.18, 0.15, 0.22),
              "accent": (0.75, 0.55, 1.0), "glow": (0.85, 0.6, 1.0)}
PAL_CHARGER = {"body": (0.55, 0.48, 0.32), "dark": (0.22, 0.18, 0.12),
               "accent": (1.0, 0.55, 0.2), "glow": (1.0, 0.62, 0.25)}

player = build_mech("player", PAL_PLAYER, bulk=1.0, build_arm=False)
walker = build_mech("walker", PAL_WALKER, bulk=1.0, arm_kind="fist")
speeder = build_mech("speeder", PAL_SPEEDER, bulk=0.86, arm_kind="blade",
                     head_fin=True)
crusher = build_mech("crusher", PAL_CRUSHER, bulk=1.32, arm_kind="megafist",
                     spikes=True)
gunner = build_mech("gunner", PAL_GUNNER, bulk=0.95, arm_kind="cannon")
charger = build_mech("charger", PAL_CHARGER, bulk=1.12, arm_kind="fist",
                     spikes=True)

# Player arms rendered separately (pivot at shoulder = frame center).
arm_rigs = {}
for arm_kind in ["fist", "megafist", "buzzsaw", "cannon"]:
    mats = player["mats"]
    arig_root = empty("armrig_" + arm_kind, (0, 0, 0))
    # fake torso parent at shoulder-relative coords: shoulder at origin
    torso_proxy = empty("armrig_" + arm_kind + "_torso", (0, 0, 0))
    parts = build_arm_parts("armrender_" + arm_kind, mats, arm_kind,
                            torso_proxy, (0, 0, 0))
    parts["root"] = arig_root
    parts["proxy"] = torso_proxy
    arm_rigs[arm_kind] = parts

all_mechs = {"player": player, "walker": walker, "speeder": speeder,
             "crusher": crusher, "gunner": gunner, "charger": charger}

# Hide everything to start.
for m in all_mechs.values():
    set_visible(all_rig_objects(m) + [m["shadow"]], False)
for a in arm_rigs.values():
    set_visible([o for o in a.values() if isinstance(o, bpy.types.Object)],
                False)

BODY_FRAMES = [("idle0", lambda P: pose_idle(P, 0)),
               ("idle1", lambda P: pose_idle(P, 1)),
               ("walk0", lambda P: pose_walk(P, 0)),
               ("walk1", lambda P: pose_walk(P, 1)),
               ("walk2", lambda P: pose_walk(P, 2)),
               ("walk3", lambda P: pose_walk(P, 3)),
               ("attack", pose_attack)]

# Player body (no arm).
set_visible(all_rig_objects(player) + [player["shadow"]], True)
for fname, fn in BODY_FRAMES:
    fn(player)
    render(os.path.join(OUT, "player", "body_%s.png" % fname),
           300, 340, 4.4, 0.1, 1.85)
set_visible(all_rig_objects(player) + [player["shadow"]], False)

# Player arms: rest + attack, pivot at frame center.
ARM_NAMES = {"fist": "rusty_fist", "megafist": "crusher_fist",
             "buzzsaw": "buzzsaw", "cannon": "cannon_arm"}
for arm_kind, parts in arm_rigs.items():
    objs = [o for o in parts.values() if isinstance(o, bpy.types.Object)]
    set_visible(objs, True)
    for pose in ["rest", "attack"]:
        pose_arm(parts, arm_kind, pose)
        # Shoulder pivot lands exactly at frame center (100,100).
        render(os.path.join(OUT, "player",
                            "arm_%s_%s.png" % (ARM_NAMES[arm_kind], pose)),
               200, 200, 3.2, 0.0, 0.0)
    set_visible(objs, False)

# Enemies: idle0, walk0..3, attack (arm baked).
ENEMY_FRAMES = [("idle", lambda P: pose_idle(P, 0)),
                ("walk0", lambda P: pose_walk(P, 0)),
                ("walk1", lambda P: pose_walk(P, 1)),
                ("walk2", lambda P: pose_walk(P, 2)),
                ("walk3", lambda P: pose_walk(P, 3)),
                ("attack", pose_attack)]
for ename, P in [("walker", walker), ("speeder", speeder),
                 ("crusher", crusher), ("gunner", gunner),
                 ("charger", charger)]:
    bulk = P["bulk"]
    set_visible(all_rig_objects(P) + [P["shadow"]], True)
    for fname, fn in ENEMY_FRAMES:
        fn(P)
        render(os.path.join(OUT, "enemies", "%s_%s.png" % (ename, fname)),
               300, 340, 4.4 * bulk, 0.1 * bulk, 1.85 * bulk)
    set_visible(all_rig_objects(P) + [P["shadow"]], False)

bpy.ops.wm.save_as_mainfile(filepath=BLEND)
print("saved", BLEND)
