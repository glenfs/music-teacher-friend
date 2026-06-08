"""Procedural GRAND piano -> GLB, built in Blender (headless).

Run:
  "C:\\Program Files\\Blender Foundation\\Blender 4.3\\blender-launcher.exe" \
      --background --python generate_grand_piano.py

Output: grand_piano.glb next to this script. Units are metres, +Z up, keyboard
at the front (-Y), tail curving back (+Y). Distinct from the upright in
../piano/ — a wing-shaped case with an open, propped lid, 88 keys, 3 tapered
legs and a 3-pedal lyre.
"""

import bpy
import bmesh
import math
import os

OUT_DIR = os.path.dirname(os.path.abspath(__file__))
OUT_PATH = os.path.join(OUT_DIR, "grand_piano.glb")

# ---- scene reset --------------------------------------------------------
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


# ---- materials ----------------------------------------------------------
def make_mat(name, rgb, metallic=0.0, roughness=0.4):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


MAT_CASE = make_mat("PianoCaseBlack", (0.018, 0.018, 0.022), 0.0, 0.12)   # glossy black
MAT_WHITE = make_mat("KeyWhite", (0.95, 0.95, 0.90), 0.0, 0.32)
MAT_BLACK = make_mat("KeyBlack", (0.03, 0.03, 0.035), 0.0, 0.22)
MAT_GOLD = make_mat("Brass", (0.83, 0.67, 0.22), 1.0, 0.30)
MAT_FELT = make_mat("RedFelt", (0.42, 0.04, 0.06), 0.0, 0.9)
MAT_LIDIN = make_mat("LidUnderside", (0.05, 0.035, 0.03), 0.0, 0.5)


def add_box(name, size, location, mat):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (size[0], size[1], size[2])
    obj.data.materials.append(mat)
    return obj


def add_cylinder(name, radius, depth, location, mat, verts=20):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=location, vertices=verts)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


# ---- dimensions ---------------------------------------------------------
W = 1.46          # case width (X), keyboard spans this
KBD_FRONT = 0.0   # keys at the very front
CASE_FRONT = 0.16
CASE_BACK = 2.12
CASE_TOP = 0.80   # top surface of the body
CASE_THICK = 0.30
LEG_TOP = CASE_TOP - CASE_THICK   # 0.50, bottom of body


# ---- grand "wing" case outline (top view, x,y) --------------------------
def wing_outline():
    pts = []
    pts.append((0.0, CASE_FRONT))           # front-left (spine/front corner)
    pts.append((W, CASE_FRONT))             # front-right
    pts.append((W, CASE_FRONT + 0.78))      # treble side straight back a bit
    # curved bent side sweeping to the tail (quarter ellipse)
    cx, cy = 0.10, CASE_FRONT + 0.78
    rx = W - cx
    ry = CASE_BACK - cy
    steps = 14
    for i in range(1, steps + 1):
        t = (math.pi / 2.0) * (i / steps)
        pts.append((cx + rx * math.cos(t), cy + ry * math.sin(t)))
    pts.append((0.0, CASE_BACK))            # back-left (spine end)
    return pts


def build_wing(name, outline, top_z, thickness, mat, inset=0.0):
    mesh = bpy.data.meshes.new(name + "_mesh")
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    bm = bmesh.new()
    cxm = sum(p[0] for p in outline) / len(outline)
    cym = sum(p[1] for p in outline) / len(outline)
    verts = []
    for (x, y) in outline:
        if inset > 0.0:
            x += (cxm - x) * inset
            y += (cym - y) * inset
        verts.append(bm.verts.new((x, y, 0.0)))
    face = bm.faces.new(verts)
    res = bmesh.ops.extrude_face_region(bm, geom=[face])
    down = [g for g in res["geom"] if isinstance(g, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, vec=(0.0, 0.0, -thickness), verts=down)
    bm.normal_update()
    bm.to_mesh(mesh)
    bm.free()
    obj.location = (0.0, 0.0, top_z)
    obj.data.materials.append(mat)
    return obj


outline = wing_outline()
build_wing("Case", outline, CASE_TOP, CASE_THICK, MAT_CASE)

# Thin red felt strip behind the keys (front of the case top)
add_box("KeyFelt", (W, 0.02, 0.006), (W / 2.0, CASE_FRONT + 0.01, CASE_TOP + 0.004), MAT_FELT)


# ---- keyboard (88 keys) -------------------------------------------------
WHITE_COUNT = 52
ww = W / WHITE_COUNT          # white key width
wd = 0.145                    # white key depth
wh = 0.024                    # white key height
white_top = CASE_TOP + 0.012  # sit just proud of the case top
white_y = KBD_FRONT + wd / 2.0 + 0.005

# white letters cycle starting at A0 (leftmost white key)
LETTERS = ["A", "B", "C", "D", "E", "F", "G"]
BLACK_AFTER = {"A", "C", "D", "F", "G"}   # sharps exist to the right of these

bd = 0.095                    # black key depth
bh = 0.016                    # black key height (top sits above whites)
bw = ww * 0.58
black_top = white_top + 0.011
black_y = KBD_FRONT + bd / 2.0 + 0.005

for i in range(WHITE_COUNT):
    cx = ww * (i + 0.5)
    add_box("White_%02d" % i, (ww * 0.92, wd, wh), (cx, white_y, white_top - wh / 2.0), MAT_WHITE)
    letter = LETTERS[i % 7]
    if i < WHITE_COUNT - 1 and letter in BLACK_AFTER:
        bx = ww * (i + 1.0)   # on the boundary to the next white
        add_box("Black_%02d" % i, (bw, bd, bh), (bx, black_y, black_top - bh / 2.0), MAT_BLACK)


# ---- legs (3 tapered) ---------------------------------------------------
def add_leg(name, x, y):
    leg = add_cylinder(name, 0.055, LEG_TOP, (x, y, LEG_TOP / 2.0), MAT_CASE, verts=16)
    # taper toward the floor
    bm = bmesh.new()
    bm.from_mesh(leg.data)
    for v in bm.verts:
        if v.co.z < 0.0:  # bottom ring (local space: cylinder centred at origin)
            v.co.x *= 0.6
            v.co.y *= 0.6
    bm.to_mesh(leg.data)
    bm.free()
    return leg


add_leg("LegFrontL", 0.16, CASE_FRONT + 0.14)
add_leg("LegFrontR", W - 0.16, CASE_FRONT + 0.14)
add_leg("LegTail", 0.18, CASE_BACK - 0.30)


# ---- pedal lyre ---------------------------------------------------------
lyre_x = W / 2.0
add_box("LyreBoard", (0.18, 0.03, 0.34), (lyre_x, CASE_FRONT + 0.10, 0.17), MAT_CASE)
add_cylinder("LyreRodL", 0.012, 0.34, (lyre_x - 0.07, CASE_FRONT + 0.04, 0.17), MAT_GOLD, verts=10)
add_cylinder("LyreRodR", 0.012, 0.34, (lyre_x + 0.07, CASE_FRONT + 0.04, 0.17), MAT_GOLD, verts=10)
for pi, off in enumerate((-0.05, 0.0, 0.05)):
    add_box("Pedal_%d" % pi, (0.035, 0.10, 0.012), (lyre_x + off, CASE_FRONT - 0.02, 0.06), MAT_GOLD)


# ---- lid (open + propped) ----------------------------------------------
# Build the lid as a thin wing slightly inset, hinged along the spine (x=0),
# rotated open about the Y axis so the treble side lifts.
lid = build_wing("Lid", outline, CASE_TOP + CASE_THICK * 0.0, 0.028, MAT_CASE, inset=0.03)
# underside material as a second slot is overkill; keep glossy black top.
lid.location = (0.0, 0.0, CASE_TOP + 0.031)
lid.rotation_euler = (0.0, math.radians(-26.0), 0.0)   # hinge at x=0, treble side up

# prop stick holding the lid open
prop = add_cylinder("LidProp", 0.012, 0.62, (W * 0.62, CASE_BACK - 0.55, CASE_TOP + 0.30), MAT_GOLD, verts=10)
prop.rotation_euler = (math.radians(8.0), 0.0, math.radians(4.0))


# ---- export -------------------------------------------------------------
os.makedirs(OUT_DIR, exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=OUT_PATH,
    export_format="GLB",
    use_selection=False,
    export_apply=True,
)
print("WROTE_GLB:", OUT_PATH)
