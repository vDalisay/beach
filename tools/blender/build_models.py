"""Procedural low-poly models for Beach, built with Blender 4.4.

Run from the project root (Blender is not needed to play; its outputs are committed):

    blender -b --factory-startup --python tools/blender/build_models.py -- [--only=a,b] [--out=art/models]

Each model is faceted geometry with per-face vertex colours from PALETTE (a Palm City-like
set) and one shared vertex-colour material at roughness 0.8, matching the staged Synty
props. Loose-item models are a single mesh so DistantItemVisuals can batch them.
Blender is Z-up; the glTF exporter converts to Godot's Y-up, so Blender +Y becomes
Godot -Z (forward). Models stand on the XY plane at z = 0 unless noted.
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector
from mathutils.geometry import tessellate_polygon

PALETTE = {
    "white": "F2EFE6", "offwhite": "E6E0D2", "cream": "F6E7C1", "paper": "EDE6D6",
    "lightgrey": "C9CDD0", "grey": "8E969C", "steel": "A9B1B8", "darkgrey": "4A5057",
    "charcoal": "2E3338", "black": "1F2327",
    "red": "D6453D", "darkred": "A5302B", "orange": "F08A2E", "darkorange": "C9651E",
    "yellow": "F4C542", "mustard": "D9A42B", "gold": "E8B23A",
    "lime": "A7D14B", "green": "6FB24A", "darkgreen": "3F7F3A", "leaf": "7DBA4A",
    "teal": "2FA39A", "darkteal": "1E7169", "seafoam": "8FD1C0",
    "sky": "7FC3E8", "blue": "3E86C8", "darkblue": "2B5A96", "navy": "233D66",
    "royal": "2F5FC4", "purple": "8C5BB5", "lilac": "B79BD6", "pink": "E77FA6",
    "coral": "EF7B6B", "peach": "F2B58B", "salmon": "F09A7A",
    "brown": "8B5A34", "lightbrown": "B98352", "tan": "D8B27A", "wood": "A8703F",
    "darkwood": "6E4A2E", "bleachwood": "C9A77C", "bun": "D99A4E", "buntop": "E3A457",
    "patty": "6B3B22", "cheese": "F2C12E", "tomato": "D8412F", "fry": "F4CC56",
    "shell": "7A8452", "shelldark": "59633D", "shelllight": "9C9E6A", "turtleskin": "D9D7B4",
    "turtleskindark": "B7B58F", "gullwhite": "F4F4F0", "gullgrey": "A7AFB5", "gulldark": "2B2F33",
    "beak": "F2BE3A", "gullleg": "E9965A", "netgreen": "3E9C8A", "rope": "C8B48A",
    "clear": "D7E8EE", "clearblue": "A9D6E6", "splat": "F1F0EA", "splatcore": "9AA38F",
    "grime": "5E4A33", "grimedark": "3F3325",
    "coralbase": "F4EEE8", "coraltip": "FFFFFF", "coralshade": "C4BBB4",
    "cloud": "FFFFFF",
}

def rgba(value):
    text = PALETTE.get(value, value).lstrip("#")
    return tuple(int(text[i:i + 2], 16) / 255.0 for i in (0, 2, 4)) + (1.0,)


def T(loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    """Translation @ rotation (degrees, XYZ) @ scale."""
    if not isinstance(scale, (tuple, list)):
        scale = (scale, scale, scale)
    r = Euler(tuple(math.radians(a) for a in rot), "XYZ").to_matrix().to_4x4()
    return Matrix.Translation(Vector(loc)) @ r @ Matrix.Diagonal((scale[0], scale[1], scale[2], 1.0))


class Geo:
    """Plain polygon soup with one colour per face."""

    def __init__(self):
        self.verts = []
        self.faces = []
        self.colors = []

    def face(self, indices, color):
        self.faces.append(tuple(indices))
        self.colors.append(rgba(color) if isinstance(color, str) else color)

    def add(self, other, matrix=None, color=None):
        base = len(self.verts)
        for v in other.verts:
            self.verts.append(matrix @ v if matrix is not None else v.copy())
        for face, face_color in zip(other.faces, other.colors):
            self.faces.append(tuple(i + base for i in face))
            self.colors.append(rgba(color) if color else face_color)
        return self

    def jitter(self, amount, seed=0, keep_base=False):
        rng = random.Random(seed)
        moved = {}
        for i, v in enumerate(self.verts):
            key = (round(v.x, 4), round(v.y, 4), round(v.z, 4))
            if key not in moved:
                offset = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * amount
                if keep_base and v.z <= 1e-4:
                    offset.z = 0.0
                moved[key] = offset
            self.verts[i] = v + moved[key]
        return self

    def deform(self, fn):
        self.verts = [fn(v.copy()) for v in self.verts]
        return self


def _face_normal(geo, face):
    a, b, c = (geo.verts[i] for i in face[:3])
    n = (b - a).cross(c - a)
    return n.normalized() if n.length > 1e-9 else Vector((0, 0, 1))


def _from_bmesh(bm, color):
    geo = Geo()
    index = {}
    for v in bm.verts:
        index[v] = len(geo.verts)
        geo.verts.append(v.co.copy())
    for f in bm.faces:
        geo.face([index[v] for v in f.verts], color)
    bm.free()
    return geo


# --- primitives (local space, Z up) -------------------------------------------------------

def box(sx, sy, sz, color, chamfer=0.0, base=False):
    """Axis-aligned box; chamfer > 0 bevels every edge like the Synty props."""
    hx, hy, hz = sx / 2, sy / 2, sz / 2
    if chamfer <= 0.0:
        geo = Geo()
        for x in (-hx, hx):
            for y in (-hy, hy):
                for z in (-hz, hz):
                    geo.verts.append(Vector((x, y, z)))
        # index = x*4 + y*2 + z
        for quad in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
            geo.face(quad, color)
    else:
        c = min(chamfer, hx * 0.9, hy * 0.9, hz * 0.9)
        points = []
        for x in (-1, 1):
            for y in (-1, 1):
                for z in (-1, 1):
                    points.append((x * (hx - c), y * hy, z * hz))
                    points.append((x * hx, y * (hy - c), z * hz))
                    points.append((x * hx, y * hy, z * (hz - c)))
        geo = hull(points, color)
    if base:
        for i, v in enumerate(geo.verts):
            geo.verts[i] = v + Vector((0, 0, hz))
    return geo


def hull(points, color):
    bm = bmesh.new()
    for p in points:
        bm.verts.new(Vector(p))
    bmesh.ops.convex_hull(bm, input=bm.verts[:], use_existing_faces=False)
    loose = [v for v in bm.verts if not v.link_faces]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(1.0), verts=bm.verts[:], edges=bm.edges[:])
    return _from_bmesh(bm, color)


def cyl(r0, r1, h, segs, color, top=True, bottom=True, top_color=None, bottom_color=None, rot_offset=0.0):
    """Tapered cylinder from z = 0 to z = h. r1 = 0 makes a cone."""
    geo = Geo()
    for ring, (r, z) in enumerate(((r0, 0.0), (r1, h))):
        for i in range(segs):
            a = rot_offset + 2 * math.pi * i / segs
            geo.verts.append(Vector((math.cos(a) * r, math.sin(a) * r, z)))
    for i in range(segs):
        j = (i + 1) % segs
        if r1 <= 1e-6:
            geo.face((i, j, segs + i), color)
        else:
            geo.face((i, j, segs + j, segs + i), color)
    if bottom and r0 > 1e-6:
        geo.face(tuple(reversed(range(segs))), bottom_color or color)
    if top and r1 > 1e-6:
        geo.face(tuple(range(segs, 2 * segs)), top_color or color)
    return geo


def lathe(profile, segs, colors, cap_top=True, cap_bottom=True, rot_offset=0.0):
    """Revolve [(radius, z), ...] around Z. colors: one colour or one per band."""
    geo = Geo()
    rings = len(profile)
    for r, z in profile:
        for i in range(segs):
            a = rot_offset + 2 * math.pi * i / segs
            geo.verts.append(Vector((math.cos(a) * r, math.sin(a) * r, z)))
    for ring in range(rings - 1):
        band_color = colors[ring] if isinstance(colors, (list, tuple)) else colors
        for i in range(segs):
            j = (i + 1) % segs
            a, b = ring * segs + i, ring * segs + j
            c, d = (ring + 1) * segs + j, (ring + 1) * segs + i
            if profile[ring + 1][0] <= 1e-6:
                geo.face((a, b, d), band_color)
            elif profile[ring][0] <= 1e-6:
                geo.face((a, c, d), band_color)
            else:
                geo.face((a, b, c, d), band_color)
    first = colors[0] if isinstance(colors, (list, tuple)) else colors
    last = colors[-1] if isinstance(colors, (list, tuple)) else colors
    if cap_bottom and profile[0][0] > 1e-6:
        geo.face(tuple(reversed(range(segs))), first)
    if cap_top and profile[-1][0] > 1e-6:
        geo.face(tuple(range((rings - 1) * segs, rings * segs)), last)
    return geo


def sphere(r, segs, rings, color, z_min=-1.0):
    """UV sphere; z_min in [-1, 1] trims the bottom to a flat cap (domes, cushions)."""
    profile = []
    for k in range(rings + 1):
        phi = math.pi * k / rings
        z = -math.cos(phi)
        if z < z_min:
            continue
        profile.append((math.sin(phi) * r, z * r))
    if z_min > -1.0:
        profile.insert(0, (math.sqrt(max(0.0, 1 - z_min * z_min)) * r, z_min * r))
    return lathe(profile, segs, color, cap_bottom=z_min > -1.0)


def ico(r, color, subdiv=1):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=r)
    return _from_bmesh(bm, color)


def prism(poly, thickness, color, side_color=None, bottom_color=None):
    """Extrude a 2D polygon [(x, y), ...] (counter-clockwise) from z = 0 to z = thickness."""
    geo = Geo()
    n = len(poly)
    for z in (0.0, thickness):
        for x, y in poly:
            geo.verts.append(Vector((x, y, z)))
    tris = tessellate_polygon([[Vector((x, y, 0.0)) for x, y in poly]])
    for a, b, c in tris:
        geo.face((n + a, n + b, n + c) if _ccw(poly, a, b, c) else (n + a, n + c, n + b), color)
        geo.face((c, b, a) if _ccw(poly, a, b, c) else (a, b, c), bottom_color or side_color or color)
    for i in range(n):
        j = (i + 1) % n
        geo.face((i, j, n + j, n + i), side_color or color)
    return geo


def _ccw(poly, a, b, c):
    (x1, y1), (x2, y2), (x3, y3) = poly[a], poly[b], poly[c]
    return (x2 - x1) * (y3 - y1) - (y2 - y1) * (x3 - x1) > 0


def tube(path, radius, segs, color, cap=True, colors=None):
    """Sweep a polygon along a polyline of Vectors. radius: float or per-point list."""
    geo = Geo()
    points = [Vector(p) for p in path]
    radii = radius if isinstance(radius, (list, tuple)) else [radius] * len(points)
    normal = None
    for k, p in enumerate(points):
        if k == 0:
            tangent = (points[1] - points[0]).normalized()
        elif k == len(points) - 1:
            tangent = (points[k] - points[k - 1]).normalized()
        else:
            tangent = ((points[k + 1] - points[k]).normalized() + (points[k] - points[k - 1]).normalized()).normalized()
        if normal is None:
            helper = Vector((0, 0, 1)) if abs(tangent.z) < 0.9 else Vector((1, 0, 0))
            normal = tangent.cross(helper).normalized()
        else:
            normal = (normal - tangent * normal.dot(tangent)).normalized()
        binormal = tangent.cross(normal)
        for i in range(segs):
            a = 2 * math.pi * i / segs
            geo.verts.append(p + (normal * math.cos(a) + binormal * math.sin(a)) * radii[k])
    for k in range(len(points) - 1):
        band = colors[k] if colors else color
        for i in range(segs):
            j = (i + 1) % segs
            geo.face((k * segs + i, k * segs + j, (k + 1) * segs + j, (k + 1) * segs + i), band)
    if cap:
        geo.face(tuple(reversed(range(segs))), colors[0] if colors else color)
        last = (len(points) - 1) * segs
        geo.face(tuple(range(last, last + segs)), colors[-1] if colors else color)
    return geo


def blob_outline(count, r_min, r_max, seed):
    rng = random.Random(seed)
    points = []
    for i in range(count):
        a = 2 * math.pi * i / count
        r = rng.uniform(r_min, r_max)
        points.append((math.cos(a) * r, math.sin(a) * r))
    return points


def arc_path(radius, start_deg, end_deg, steps, z=0.0):
    return [Vector((math.cos(math.radians(a)) * radius, math.sin(math.radians(a)) * radius, z))
            for a in (start_deg + (end_deg - start_deg) * k / steps for k in range(steps + 1))]


# --- model registry -----------------------------------------------------------------------

MODELS = {}
# Mesh node names that existing scene contracts address (e.g. the stick's Visual/Shaft).
OBJECT_NAMES = {"tool_poking_stick": "Shaft"}


def model(name):
    def register(fn):
        MODELS[name] = fn
        return fn
    return register


# ===== Litter (A12–A14) =====

@model("litter_straw")
def litter_straw():
    """A12S bent drinking straw lying on its side, red and white stripes."""
    g = Geo()
    r = 0.0065
    points = [Vector((-0.11 + 0.0183 * k, 0, r)) for k in range(10)]
    colors = ["white" if k % 2 == 0 else "red" for k in range(9)]
    g.add(tube(points, r, 6, "white", colors=colors))
    # Flexible neck: short ridged section then an angled end.
    bend = [points[-1], points[-1] + Vector((0.012, 0.004, 0)), points[-1] + Vector((0.022, 0.012, 0))]
    g.add(tube(bend, r * 1.12, 6, "offwhite"))
    tip = [bend[-1], bend[-1] + Vector((0.026, 0.034, 0))]
    g.add(tube(tip, r, 6, "red"))
    return g


@model("litter_plastic_bag")
def litter_plastic_bag():
    """A12W crumpled plastic carrier bag with one looped handle."""
    g = Geo()
    body = ico(0.5, "clear", subdiv=1)
    body.jitter(0.09, seed=3)
    body.deform(lambda v: Vector((v.x * 0.34, v.y * 0.26, max(v.z, -0.25) * 0.09 + 0.024)))
    for i in range(len(body.colors)):
        body.colors[i] = rgba("clear") if i % 3 else rgba("clearblue")
    g.add(body)
    handle = arc_path(0.045, 20, 200, 6, z=0.0)
    g.add(tube(handle, 0.008, 4, "clear", cap=False), T((0.16, 0.0, 0.035), (70, 0, 90)))
    g.add(tube(arc_path(0.04, 0, 160, 5), 0.007, 4, "clearblue", cap=False), T((0.13, -0.05, 0.03), (80, 0, 60)))
    return g


@model("litter_drink_carton")
def litter_drink_carton():
    """A12C juice box with its straw, slightly crushed on one side."""
    g = Geo()
    body = box(0.064, 0.042, 0.105, "orange", chamfer=0.004, base=True)
    for i, face in enumerate(body.faces):
        n = _face_normal(body, face)
        if n.z > 0.9:
            body.colors[i] = rgba("white")
    body.deform(lambda v: Vector((v.x + (0.006 * (v.z / 0.105) if v.x > 0 else 0.0), v.y * (1.0 - 0.18 * (v.z / 0.105) * (1 if v.x > 0 else 0)), v.z)))
    g.add(body)
    g.add(box(0.05, 0.004, 0.05, "white"), T((0.0, -0.022, 0.05)))
    g.add(cyl(0.013, 0.013, 0.004, 8, "yellow"), T((0.0, -0.0245, 0.052), (90, 0, 0)))
    g.add(box(0.012, 0.004, 0.02, "leaf"), T((0.004, -0.0245, 0.068), (0, 30, 0)))
    straw = [Vector((0.016, 0.006, 0.1)), Vector((0.02, 0.008, 0.15)), Vector((0.036, 0.012, 0.172))]
    g.add(tube(straw, 0.0035, 5, "white"))
    return g


@model("litter_fries")
def litter_fries():
    """A13F upright red fries carton with fries sticking out and a few spilled."""
    g = Geo()
    carton = lathe([(0.03, 0.0), (0.044, 0.09)], 4, "red", cap_top=False, rot_offset=math.pi / 4)
    carton.deform(lambda v: Vector((v.x * 1.3, v.y * 0.66, v.z)))
    # Scalloped front rim, like a fries box.
    carton.deform(lambda v: Vector((v.x, v.y, v.z - (0.018 * (1.0 - abs(v.x) / 0.041)) if v.z > 0.08 and v.y < 0 else v.z)))
    g.add(carton)
    g.add(box(0.07, 0.036, 0.014, "white"), T((0.0, 0.0, 0.034)))
    g.add(cyl(0.011, 0.011, 0.003, 8, "yellow"), T((0.0, -0.0185, 0.05), (90, 0, 0)))
    rng = random.Random(11)
    for k in range(12):
        f = box(0.0085, 0.0085, rng.uniform(0.07, 0.1), "fry" if k % 3 else "mustard", base=True)
        g.add(f, T((rng.uniform(-0.03, 0.03), rng.uniform(-0.011, 0.011), 0.035), (rng.uniform(-14, 14), rng.uniform(-18, 18), rng.uniform(0, 90))))
    for k in range(4):
        g.add(box(0.0085, 0.0085, 0.065, "fry"), T((rng.uniform(-0.07, 0.07), -0.06 - rng.uniform(0.0, 0.04), 0.0043), (90, 0, rng.uniform(-60, 60))))
    return g


@model("litter_hamburger")
def litter_hamburger():
    """A13H hamburger with a bite out of it, on its crumpled wrapper."""
    g = Geo()
    wrapper = box(0.2, 0.18, 0.003, "paper", base=True)
    wrapper.jitter(0.006, seed=5, keep_base=True)
    g.add(wrapper, T(rot=(0, 0, 17)))
    segs = 9
    g.add(cyl(0.05, 0.053, 0.02, segs, "bun", top_color="buntop"), T((0, 0, 0.003)))
    g.add(cyl(0.054, 0.054, 0.014, segs, "patty"), T((0, 0, 0.023)))
    g.add(box(0.1, 0.1, 0.004, "cheese"), T((0, 0, 0.039), (0, 0, 22)))
    lettuce = Geo()
    ring = [(math.cos(2 * math.pi * k / 16) * (0.06 if k % 2 else 0.052), math.sin(2 * math.pi * k / 16) * (0.06 if k % 2 else 0.052)) for k in range(16)]
    lettuce.add(prism(ring, 0.006, "leaf"))
    g.add(lettuce, T((0, 0, 0.041)))
    g.add(cyl(0.048, 0.048, 0.006, segs, "tomato"), T((0, 0, 0.047)))
    top = sphere(0.055, segs, 6, "buntop", z_min=0.0)
    top.deform(lambda v: Vector((v.x, v.y, v.z * 0.62)))
    g.add(top, T((0, 0, 0.053)))
    rng = random.Random(2)
    for k in range(7):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(0.012, 0.038)
        z = 0.053 + 0.62 * math.sqrt(max(0.0, 0.055 ** 2 - d * d))
        g.add(box(0.006, 0.003, 0.003, "cream"), T((math.cos(a) * d, math.sin(a) * d, z), (0, 0, math.degrees(a))))
    # The bite: shave the +X side of everything above the wrapper.
    def bite(v):
        if v.z > 0.004 and v.x > 0.022:
            dy = abs(v.y)
            if dy < 0.034:
                v.x = 0.022 + (v.x - 0.022) * (dy / 0.034) ** 1.5
        return v
    g.deform(bite)
    return g


@model("litter_oil_container")
def litter_oil_container():
    """A14 sealed quart motor-oil bottle with a red cap and label band."""
    g = Geo()
    body = box(0.1, 0.058, 0.122, "charcoal", chamfer=0.008, base=True)
    g.add(body)
    shoulder = hull([(-0.05, -0.029, 0.118), (0.05, -0.029, 0.118), (-0.05, 0.029, 0.118), (0.05, 0.029, 0.118),
                     (0.02, -0.022, 0.15), (0.045, -0.022, 0.15), (0.02, 0.022, 0.15), (0.045, 0.022, 0.15)], "charcoal")
    g.add(shoulder)
    g.add(box(0.102, 0.06, 0.05, "yellow"), T((0, 0, 0.055)))
    g.add(box(0.07, 0.061, 0.018, "red"), T((-0.008, 0, 0.055)))
    g.add(cyl(0.013, 0.013, 0.014, 8, "charcoal"), T((0.033, 0, 0.148)))
    g.add(cyl(0.016, 0.016, 0.014, 8, "red", top_color="darkred"), T((0.033, 0, 0.16)))
    # Hollow handle loop on the tall side.
    g.add(tube(arc_path(0.022, 0, 180, 6), 0.007, 5, "charcoal", cap=False), T((-0.025, 0, 0.12), (90, 0, 0)))
    return g


# ===== Dirt (A15) =====

@model("residue_splat")
def residue_splat():
    """A15R gull dropping: an irregular white splat with a grey-green core and drops."""
    g = Geo()
    g.add(prism(blob_outline(14, 0.075, 0.13, seed=4), 0.006, "splat", side_color="offwhite"))
    g.add(prism(blob_outline(9, 0.028, 0.045, seed=8), 0.011, "splatcore"), T((0.012, -0.006, 0.0)))
    rng = random.Random(9)
    for k in range(6):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(0.15, 0.2)
        g.add(prism(blob_outline(6, 0.01, 0.018, seed=20 + k), 0.005, "splat"), T((math.cos(a) * d, math.sin(a) * d, 0.0)))
    return g


@model("furniture_stain")
def furniture_stain():
    """A15D grime patch: thin irregular smear, facing +Y (Godot -Z) like the old card."""
    g = Geo()
    g.add(prism(blob_outline(12, 0.07, 0.1, seed=31), 0.006, "grime", side_color="grimedark"))
    g.add(prism(blob_outline(8, 0.025, 0.045, seed=33), 0.009, "grimedark"), T((0.02, 0.015, 0.0)))
    g.add(prism(blob_outline(7, 0.012, 0.02, seed=35), 0.007, "grime"), T((-0.1, -0.05, 0.0)))
    # Stand the smear up: its face normal becomes +Y in Blender (Godot -Z), centred on the origin.
    return Geo().add(g, T((0, 0.003, 0), (90, 0, 0)))


# ===== Rescue attachments (A11) =====

def _quad_facing(geo, points, outward, color):
    """Append the quad (or triangle) wound so that its normal points along `outward`."""
    base = len(geo.verts)
    geo.verts.extend(Vector(p) for p in points)
    indices = list(range(base, base + len(points)))
    if _face_normal(geo, indices).dot(outward) < 0.0:
        indices.reverse()
    geo.face(indices, color)


@model("rescue_six_pack_rings")
def rescue_six_pack_rings():
    """A11R six-pack rings: one flat plastic web with six closed loops (2 x 3), joined along the
    middle strip and scalloped between loops on the outer edge, enlarged for readability.

    Designed with round holes (radius 1) on a square grid so every loop samples the same
    mirror-symmetric angles (30 degree steps plus the diagonals): the web corners fall exactly on
    samples and neighbouring loops share their border vertices. Then scaled to 0.50 x 0.26 m.
    """
    g = Geo()
    band, half, thickness = 0.3, 1.35, 0.008
    outer = 1.0 + band
    notch = half * math.tan(math.radians(30.0))     # web height left between loops on the edge
    kx, ky = 0.5 / (4.0 * half + 2.0 * outer), 0.26 / (2.0 * half + 2.0 * outer)
    angles = [math.radians(a) for a in (0, 30, 45, 60, 90, 120, 135, 150, 180, 210, 225, 240, 270, 300, 315, 330)]

    def radial(c, s, interior):
        x_side = interior["+x" if c > -1e-9 else "-x"]
        y_side = interior["+y" if s > -1e-9 else "-y"]
        if not x_side and not y_side:
            return outer
        ex, ey = (half if x_side else notch), (half if y_side else notch)
        reach = min(ex / abs(c) if abs(c) > 1e-9 else 1e9, ey / abs(s) if abs(s) > 1e-9 else 1e9)
        return max(outer, reach)

    for col in range(3):
        for row in range(2):
            cx, cy = (col - 1) * 2.0 * half, (row - 0.5) * 2.0 * half
            interior = {"+x": col < 2, "-x": col > 0, "+y": row == 0, "-y": row == 1}
            hole, rim = [], []
            for a in angles:
                c, s = math.cos(a), math.sin(a)
                r = radial(c, s, interior)
                hole.append((cx + c, cy + s))
                rim.append((cx + r * c, cy + r * s))
            for i in range(len(angles)):
                j = (i + 1) % len(angles)
                def at(p, z):
                    return Vector((p[0] * kx, p[1] * ky, z))
                _quad_facing(g, [at(hole[i], thickness), at(hole[j], thickness), at(rim[j], thickness), at(rim[i], thickness)], Vector((0, 0, 1)), "red")
                _quad_facing(g, [at(hole[i], 0.0), at(hole[j], 0.0), at(rim[j], 0.0), at(rim[i], 0.0)], Vector((0, 0, -1)), "darkred")
                centre = Vector((cx * kx, cy * ky, 0.0))
                mid_hole = (at(hole[i], 0.0) + at(hole[j], 0.0)) * 0.5
                _quad_facing(g, [at(hole[i], 0.0), at(hole[j], 0.0), at(hole[j], thickness), at(hole[i], thickness)], centre - mid_hole, "darkred")
                # Walls only on the outer edge; borders shared with a neighbouring loop stay open.
                shared = False
                for key, sign, axis, centre_value in (("+x", 1, 0, cx), ("-x", -1, 0, cx), ("+y", 1, 1, cy), ("-y", -1, 1, cy)):
                    line = centre_value + sign * half
                    if interior[key] and abs(rim[i][axis] - line) < 1e-6 and abs(rim[j][axis] - line) < 1e-6:
                        shared = True
                if not shared:
                    mid_rim = (at(rim[i], 0.0) + at(rim[j], 0.0)) * 0.5
                    _quad_facing(g, [at(rim[i], 0.0), at(rim[j], 0.0), at(rim[j], thickness), at(rim[i], thickness)], mid_rim - centre, "darkred")
    # Lies loosely crumpled rather than dead flat.
    g.deform(lambda v: Vector((v.x, v.y, v.z + 0.011 * math.sin(v.x * 10.0 + 0.5) + 0.007 * math.sin(v.y * 19.0 - 0.7) + 0.02)))
    return g


@model("rescue_net")
def rescue_net():
    """A11N tangled green fishing net clump with two floats and a rope end."""
    g = Geo()
    size, cells = 0.62, 7
    step = size / cells
    def height(x, y):
        return 0.05 + 0.045 * math.sin(x * 11.0 + 0.6) * math.cos(y * 9.0) + 0.03 * math.sin((x + y) * 17.0)
    for k in range(cells + 1):
        u = -size / 2 + k * step
        row = [Vector((u, -size / 2 + i * step / 2, height(u, -size / 2 + i * step / 2))) for i in range(cells * 2 + 1)]
        col = [Vector((-size / 2 + i * step / 2, u, height(-size / 2 + i * step / 2, u))) for i in range(cells * 2 + 1)]
        g.add(tube(row, 0.006, 3, "netgreen", cap=False))
        g.add(tube(col, 0.006, 3, "netgreen", cap=False))
    g.deform(lambda v: Vector((v.x * (1.0 - 0.25 * max(0.0, v.y) / 0.31), v.y, v.z)))
    g.add(cyl(0.045, 0.045, 0.07, 8, "orange", top_color="darkorange"), T((0.24, -0.2, 0.09), (90, 0, 30)))
    g.add(sphere(0.045, 8, 5, "white"), T((-0.22, 0.2, 0.08)))
    rope = [Vector((0.3, 0.02, 0.05)), Vector((0.38, 0.06, 0.02)), Vector((0.44, 0.02, 0.015)), Vector((0.5, 0.07, 0.012))]
    g.add(tube(rope, 0.011, 5, "rope"))
    return g


# ===== Handheld tools (A06–A10). Grip at the origin; working end points down -Z. =====

@model("tool_poking_stick")
def tool_poking_stick():
    """A06 wooden poking stick: yellow grip, steel ferrule and spike, wrist loop."""
    g = Geo()
    g.add(cyl(0.021, 0.021, 0.14, 8, "yellow", top_color="charcoal"), T((0, 0, -0.08)))
    g.add(cyl(0.024, 0.024, 0.016, 8, "charcoal"), T((0, 0, 0.06)))
    g.add(cyl(0.013, 0.012, 0.9, 6, "wood"), T((0, 0, -0.98)))
    g.add(cyl(0.016, 0.016, 0.03, 8, "steel"), T((0, 0, -1.01)))
    g.add(cyl(0.012, 0.0, 0.09, 6, "steel"), T((0, 0, -1.01), (180, 0, 0)))
    g.add(tube(arc_path(0.035, 200, 340, 5), 0.005, 4, "charcoal", cap=False), T((0, 0, 0.075), (90, 0, 90)))
    return g


@model("tool_vacuum")
def tool_vacuum():
    """A07V cordless litter vacuum: loop handle, motor body, clear bin, long wand."""
    g = Geo()
    handle = [Vector((0, -0.07, -0.05)), Vector((0, -0.07, 0.03)), Vector((0, 0.07, 0.03)), Vector((0, 0.09, -0.04))]
    g.add(tube(handle, 0.017, 6, "charcoal"))
    g.add(box(0.07, 0.09, 0.06, "darkgrey", chamfer=0.01), T((0, -0.07, -0.1)))
    g.add(cyl(0.058, 0.058, 0.2, 8, "teal", top_color="darkteal", bottom_color="charcoal"), T((0, -0.02, -0.075), (-90, 0, 0)))
    g.add(cyl(0.064, 0.064, 0.012, 8, "white"), T((0, 0.06, -0.075), (-90, 0, 0)))
    g.add(cyl(0.06, 0.05, 0.11, 8, "clearblue", top_color="clear"), T((0, 0.18, -0.075), (-90, 0, 0)))
    g.add(cyl(0.024, 0.024, 0.04, 8, "charcoal"), T((0, 0.29, -0.075), (-90, 0, 0)))
    wand = [Vector((0, 0.32, -0.075)), Vector((0, 0.46, -0.24)), Vector((0, 0.6, -0.5))]
    g.add(tube(wand, 0.02, 6, "steel"))
    nozzle = hull([(-0.07, 0.6, -0.5), (0.07, 0.6, -0.5), (-0.07, 0.64, -0.46), (0.07, 0.64, -0.46),
                   (-0.03, 0.57, -0.47), (0.03, 0.57, -0.47), (-0.03, 0.6, -0.43), (0.03, 0.6, -0.43)], "orange")
    g.add(nozzle)
    g.add(box(0.012, 0.02, 0.03, "lime"), T((0, -0.055, -0.035)))
    return g


@model("tool_sand_cleaner")
def tool_sand_cleaner():
    """A07S long-handled sand sifter: D grip, wooden handle, orange scoop with steel mesh."""
    g = Geo()
    grip = [Vector((-0.06, 0, -0.05)), Vector((-0.06, 0, 0.05)), Vector((0.06, 0, 0.05)), Vector((0.06, 0, -0.05))]
    g.add(tube(grip, 0.014, 6, "yellow", cap=False))
    g.add(cyl(0.014, 0.014, 0.12, 6, "yellow"), T((-0.06, 0, -0.05), (0, 90, 0)))
    g.add(cyl(0.022, 0.018, 0.08, 6, "charcoal"), T((0, 0, -0.13)))
    g.add(cyl(0.017, 0.017, 0.78, 6, "wood"), T((0, 0, -0.9)))
    w, d, h = 0.34, 0.1, 0.3
    top = -0.9
    for x in (-w / 2, w / 2):
        g.add(box(0.016, d, h, "orange", chamfer=0.003), T((x, 0.02, top - h / 2)))
    g.add(box(w, d, 0.02, "orange", chamfer=0.003), T((0, 0.02, top - h)))
    g.add(box(w, d, 0.02, "orange", chamfer=0.003), T((0, 0.02, top)))
    # Steel mesh floor at the back of the tray; the open side faces forward.
    for k in range(9):
        x = -w / 2 + w * (k + 0.5) / 9
        g.add(box(0.01, 0.01, h, "steel"), T((x, -0.028, top - h / 2)))
    for k in range(7):
        z = top - h * (k + 0.5) / 7
        g.add(box(w, 0.01, 0.01, "steel"), T((0, -0.028, z)))
    return g


@model("tool_metal_detector")
def tool_metal_detector():
    """A08 metal detector: arm cuff, grip, control box with screen, telescopic shaft, coil."""
    g = Geo()
    g.add(cyl(0.021, 0.021, 0.13, 8, "charcoal"), T((0, 0, -0.065)))
    g.add(tube(arc_path(0.045, 200, 340, 6), 0.012, 5, "darkgrey"), T((0, 0, 0.2), (90, 0, 0)))
    g.add(cyl(0.016, 0.016, 0.34, 6, "steel"), T((0, 0, -0.14)))
    g.add(box(0.07, 0.05, 0.1, "charcoal", chamfer=0.01), T((0, 0.04, -0.04)))
    g.add(box(0.05, 0.006, 0.045, "lime"), T((0, 0.066, -0.02)))
    g.add(box(0.012, 0.006, 0.012, "red"), T((0.015, 0.066, -0.075)))
    g.add(cyl(0.013, 0.013, 0.66, 6, "grey"), T((0, 0, -0.82)))
    g.add(cyl(0.019, 0.019, 0.04, 8, "charcoal"), T((0, 0, -0.52)))
    yoke = [Vector((0, 0, -0.82)), Vector((0, 0.03, -0.9)), Vector((0, 0.06, -0.95))]
    g.add(tube(yoke, 0.011, 5, "charcoal"))
    coil = lathe([(0.0, 0.0), (0.12, 0.0), (0.13, 0.012), (0.12, 0.024), (0.0, 0.024)], 12,
                 ["charcoal", "yellow", "yellow", "charcoal"], cap_top=False, cap_bottom=False)
    coil.deform(lambda v: Vector((v.x, v.y * 0.72, v.z)))
    g.add(coil, T((0, 0.06, -0.975), (-12, 0, 0)))
    return g


def _swept_strip(path, thickness, depth, colors, inset=0.0):
    """Sweep a thickness x depth section along an XZ polyline (a folded cloth cross-section).

    The section's two depth ends bulge out by `inset` at mid-thickness, so stacked layers show a
    soft crease between them. colors(k, outward) picks the colour of segment k's face.
    """
    g = Geo()
    points = [Vector((x, 0.0, z)) for x, z in path]
    normals = []
    for k, p in enumerate(points):
        a = points[max(k - 1, 0)]
        b = points[min(k + 1, len(points) - 1)]
        tangent = (b - a).normalized()
        normals.append(Vector((-tangent.z, 0.0, tangent.x)))
    def section(k):
        # Around the section: top face edge, bulge, bottom face edge on +Y, then back on -Y.
        up, reach = normals[k] * (thickness * 0.5), depth * 0.5
        p = points[k]
        return [p + up + Vector((0, reach - inset, 0)), p + Vector((0, reach, 0)), p - up + Vector((0, reach - inset, 0)),
                p - up + Vector((0, -reach + inset, 0)), p + Vector((0, -reach, 0)), p + up + Vector((0, -reach + inset, 0))]
    sections = [section(k) for k in range(len(points))]
    for k in range(len(points) - 1):
        a, b = sections[k], sections[k + 1]
        for i in range(6):
            j = (i + 1) % 6
            quad = [a[i], a[j], b[j], b[i]]
            middle = sum(quad, Vector()) / 4.0
            spine = (points[k] + points[k + 1]) * 0.5
            outward = middle - spine
            outward = Vector((0.0, math.copysign(1.0, outward.y), 0.0)) if i in (0, 1, 3, 4) else outward.normalized()
            _quad_facing(g, quad, outward, colors(k, outward))
    for k in (0, len(points) - 1):
        other = points[1] if k == 0 else points[-2]
        outward = (points[k] - other).normalized()
        _quad_facing(g, sections[k], outward, colors(k - (1 if k else 0), outward))
    return g


@model("tool_cloth")
def tool_cloth():
    """A10 folded terry washcloth: a soft three-layer letter fold with rounded folds on both
    sides and a woven hem stripe across the top layer's free edge. Centred on the grip."""
    width, depth, t = 0.16, 0.112, 0.0095
    half = width / 2.0
    left, right = -half + t, half - t      # fold centres (outer surfaces reach +-half)
    def fold(cx, cz, start, end, steps):
        return [(cx + 0.5 * t * math.sin(a), cz - 0.5 * t * math.cos(a))
                for a in (start + (end - start) * i / steps for i in range(1, steps))]
    # Bottom layer (free edge under the right fold), fold round the left, middle layer, fold round
    # the right, top layer ending in its hem short of the left fold. Layers sag and puff a little.
    hem_x = -half + 0.012
    stripe = (hem_x + 0.014, hem_x + 0.026)
    path = [(half - 0.005, 0.5 * t), (0.02, 0.45 * t), (left, 0.5 * t)]
    path += fold(left, t, 0.0, -math.pi, 4) + [(left, 1.5 * t)]
    path += [(0.0, 1.55 * t), (right, 1.5 * t)]
    path += fold(right, 2.0 * t, 0.0, math.pi, 4) + [(right, 2.5 * t)]
    path += [(0.035, 2.72 * t), (stripe[1], 2.66 * t), (stripe[0], 2.6 * t), (hem_x + 0.004, 2.5 * t), (hem_x, 2.4 * t)]
    top_start = len(path) - 6
    def colors(k, outward):
        if k >= top_start and outward.z > 0.5 and k == len(path) - 4:
            return "white"
        return "blue"
    strip = _swept_strip(path, t, depth, colors, inset=0.0035)
    # Soft corners: the layers bulge a touch in the middle of the depth.
    strip.deform(lambda v: Vector((v.x, v.y, v.z + 0.0025 * (1.0 - (2.0 * v.y / depth) ** 2) * (1.0 if v.z > 1.2 * t else 0.0))))
    return Geo().add(strip, T((0.0, 0.0, -1.5 * t)))


# ===== Swim gear (A09) =====

@model("gear_flippers")
def gear_flippers():
    """A09F pair of swim fins lying flat, slightly splayed."""
    g = Geo()
    blade_poly = [(-0.055, 0.0), (0.055, 0.0), (0.1, 0.34), (0.03, 0.36), (0.0, 0.33), (-0.03, 0.36), (-0.1, 0.34)]
    for side in (-1, 1):
        fin = Geo()
        blade = prism(blade_poly, 0.012, "blue", side_color="darkblue")
        blade.deform(lambda v: Vector((v.x, v.y, v.z + 0.06 * (v.y / 0.36) ** 2)))
        fin.add(blade, T((0, 0.1, 0.012)))
        for x in (-1, 1):
            rail = [Vector((x * 0.052, 0.1, 0.03)), Vector((x * 0.075, 0.25, 0.04)), Vector((x * 0.095, 0.43, 0.075))]
            fin.add(tube(rail, 0.01, 4, "darkblue"))
        fin.add(box(0.11, 0.17, 0.07, "charcoal", chamfer=0.02, base=True), T((0, 0.02, 0.0)))
        fin.add(box(0.1, 0.03, 0.02, "darkgrey"), T((0, -0.05, 0.075)))
        fin.add(tube(arc_path(0.05, 190, 350, 5), 0.009, 4, "charcoal", cap=False), T((0, -0.07, 0.035)))
        g.add(fin, T((side * 0.09, 0, 0), (0, 0, -side * 6)))
    return g


@model("gear_oxygen_tank")
def gear_oxygen_tank():
    """A09T yellow scuba cylinder with valve, regulator hose and mouthpiece."""
    g = Geo()
    profile = [(0.06, 0.0), (0.085, 0.02), (0.09, 0.05), (0.09, 0.45), (0.08, 0.52), (0.05, 0.56), (0.02, 0.575)]
    g.add(lathe(profile, 10, "yellow"))
    g.add(cyl(0.092, 0.092, 0.04, 10, "charcoal"), T((0, 0, 0.3)))
    g.add(cyl(0.0915, 0.0915, 0.07, 10, "white"), T((0, 0, 0.16)))
    g.add(cyl(0.02, 0.02, 0.05, 8, "steel"), T((0, 0, 0.57)))
    g.add(box(0.07, 0.035, 0.035, "steel", chamfer=0.006), T((0, 0, 0.625)))
    g.add(cyl(0.028, 0.028, 0.018, 8, "charcoal"), T((0.045, 0, 0.625), (0, 90, 0)))
    hose = [Vector((-0.035, 0, 0.625)), Vector((-0.1, 0.02, 0.6)), Vector((-0.14, 0.06, 0.48)), Vector((-0.13, 0.1, 0.36))]
    g.add(tube(hose, 0.011, 5, "charcoal"))
    g.add(cyl(0.032, 0.032, 0.045, 8, "charcoal", top_color="yellow"), T((-0.13, 0.12, 0.33), (-70, 0, 0)))
    g.add(cyl(0.095, 0.095, 0.03, 10, "darkgrey"), T((0, 0, 0.4)))
    return g


# ===== Wildlife (A01–A03, A05). Heads face +Y (Godot -Z). =====

def _turtle_flipper(length, stations, thickness, sweep):
    """Paddle flipper in joint space: the root sits inside the body at the origin and the blade
    runs along +X with its tip swept back (-Y). stations: (fraction along, width, leading share).
    Lens cross-section (leading edge, top, trailing edge, bottom) thinning towards the tip."""
    g = Geo()
    rings = []
    for u, width, lead in stations:
        x = u * length
        spine = -sweep * u * u
        half_thick = thickness * (1.0 - 0.72 * u) * 0.5
        front = Vector((x, spine + width * lead, 0.0))
        back = Vector((x, spine - width * (1.0 - lead), 0.0))
        ridge = front.lerp(back, 0.36)
        rings.append([front, ridge + Vector((0, 0, half_thick)), back, ridge - Vector((0, 0, half_thick))])
    tip = Vector((length, -sweep, 0.0))
    for k in range(len(rings)):
        a = rings[k]
        b = rings[k + 1] if k + 1 < len(rings) else None
        # Scaly top: darker leading half, lighter trailing half, alternating per segment.
        tops = ("shelldark", "shell") if k % 2 == 0 else ("shell", "shelldark")
        for side in range(4):
            color = tops[side] if side < 2 else "turtleskin"
            outward = Vector((0, 0, 1 if side < 2 else -1))
            if b is None:
                _quad_facing(g, [a[side], a[(side + 1) % 4], tip], outward, color)
            else:
                _quad_facing(g, [a[side], a[(side + 1) % 4], b[(side + 1) % 4], b[side]], outward, color)
    _quad_facing(g, rings[0], Vector((-1, 0, 0)), "turtleskindark")
    return g


def _turtle_outline(count):
    """Carapace plan outline, counter-clockwise from +X: broad shoulders, tapering to the tail."""
    points = []
    for k in range(count):
        a = 2 * math.pi * k / count
        c, s = math.cos(a), math.sin(a)
        points.append((c * 0.3 * (1.0 + 0.07 * s), s * (0.37 if s > 0 else 0.4)))
    return points


@model("turtle")
def turtle():
    """A01 green sea turtle: one domed carapace closing onto a cream plastron, neck and head coming
    out under the front margin, and flippers whose roots sit inside the body at their joints.
    Flippers are separate parts pivoting at their joints (FlapAnimator turns them about Z)."""
    def build(name):
        body = Geo()
        outline = _turtle_outline(12)
        # (outline scale, height, band colours) from the plastron up over the carapace.
        rings = [(0.6, 0.012), (0.86, 0.024), (1.0, 0.05), (0.9, 0.106), (0.68, 0.162), (0.36, 0.196)]
        bands = [["turtleskin"], ["turtleskindark"], ["shelldark", "shell"], ["shell", "shelldark", "shell", "shelllight"], ["shelldark", "shell"]]
        loops = []
        for scale, z in rings:
            loop = []
            for x, y in outline:
                lift = 0.0
                if z > 0.03:
                    lift += 0.014 * max(0.0, y / 0.37) ** 3          # nuchal margin lifts over the neck
                    lift += 0.01 * max(0.0, 1.0 - abs(x * scale) / 0.1) if z > 0.1 else 0.0   # low keel
                loop.append(Vector((x * scale, y * scale - 0.01 * (1.0 - scale), z + lift)))
            loops.append(loop)
        for band, colors in enumerate(bands):
            below, above = loops[band], loops[band + 1]
            for k in range(len(outline)):
                j = (k + 1) % len(outline)
                centre = (below[k] + above[j]) * 0.5
                outward = Vector((centre.x, centre.y, 0.0)) + Vector((0, 0, -0.2 if band < 2 else 0.4))
                _quad_facing(body, [below[k], below[j], above[j], above[k]], outward, colors[k % len(colors)])
        # Vertebral ridge along the top instead of a single apex: three spine points, the top ring
        # (12 points, 3 = front, 9 = rear) fanned onto them like the central row of scutes.
        top = loops[-1]
        spine = {"F": Vector((0.0, 0.075, 0.207)), "M": Vector((0.0, -0.02, 0.212)), "B": Vector((0.0, -0.115, 0.2))}
        fans = [("F", k, "shelllight" if k in (2, 3) else "shell") for k in (1, 2, 3, 4)]
        fans += [("M", k, "shell") for k in (11, 0, 5, 6)]
        fans += [("B", k, "shelllight" if k in (8, 9) else "shell") for k in (7, 8, 9, 10)]
        for point, k, color in fans:
            _quad_facing(body, [top[k], top[(k + 1) % 12], spine[point]], Vector((0, 0, 1)), color)
        for k, a, b in ((1, "F", "M"), (5, "M", "F"), (7, "B", "M"), (11, "M", "B")):
            _quad_facing(body, [top[k], spine[a], spine[b]], Vector((0, 0, 1)), "shelllight")
        _quad_facing(body, list(reversed(loops[0])), Vector((0, 0, -1)), "turtleskin")
        # Neck from inside the shell out under the lifted front margin; the head overlaps its end.
        neck = tube([Vector((0, 0.2, 0.07)), Vector((0, 0.36, 0.068)), Vector((0, 0.46, 0.08))], [0.078, 0.064, 0.054], 6, "turtleskindark", cap=False)
        for i, face in enumerate(neck.faces):
            n = _face_normal(neck, face)
            neck.colors[i] = rgba("shell" if n.z > 0.6 else "turtleskin" if n.z < -0.4 else "turtleskindark")
        body.add(neck)
        head = lathe([(0.0, 0.0), (0.05, 0.012), (0.064, 0.06), (0.056, 0.11), (0.032, 0.155), (0.0, 0.172)], 6, "turtleskin")
        head.deform(lambda v: Vector((v.x, v.y * 0.82, v.z)))
        head = Geo().add(head, T((0, 0.44, 0.086), (-90, 0, 0)))
        for i, face in enumerate(head.faces):
            n = _face_normal(head, face)
            if n.z > 0.35:
                head.colors[i] = rgba("shell" if n.y < 0.5 else "shelllight")
            elif n.z < -0.5:
                head.colors[i] = rgba("offwhite")
        body.add(head)
        for x in (-1, 1):
            body.add(box(0.012, 0.024, 0.02, "black"), T((x * 0.051, 0.545, 0.1)))
        body.add(cyl(0.032, 0.0, 0.13, 5, "turtleskindark"), T((0, -0.34, 0.036), (90, 0, 0)))
        objects = [make_object(name, body)]
        front = [(0.0, 0.085, 0.5), (0.14, 0.13, 0.56), (0.34, 0.145, 0.6), (0.58, 0.115, 0.62), (0.8, 0.075, 0.6)]
        back = [(0.0, 0.07, 0.5), (0.3, 0.12, 0.5), (0.62, 0.13, 0.48), (0.86, 0.085, 0.45)]
        joints = {"FlipperFL": ((0.2, 0.16, 0.056), front, 0.46, 0.14, -12, 4), "FlipperBL": ((0.17, -0.24, 0.042), back, 0.2, 0.03, -52, 3)}
        for part, (location, stations, length, sweep, heading, droop) in joints.items():
            flipper = Geo().add(_turtle_flipper(length, stations, 0.036 if part.endswith("FL") else 0.028, sweep), T(rot=(0, droop, heading)))
            for mirror, suffix in ((1, "L"), (-1, "R")):
                placed = Geo().add(flipper, T(scale=(mirror, 1, 1)))
                if mirror < 0:
                    placed.faces = [tuple(reversed(f)) for f in placed.faces]
                objects.append(make_object(part[:-1] + suffix, placed, parent=objects[0], location=(mirror * location[0], location[1], location[2])))
        return objects
    return build


def _fish(body_color, fin_color, stripe_fn=None, eye_ring="white"):
    g = Geo()
    profile = [(0.0, -0.12), (0.022, -0.1), (0.05, -0.05), (0.068, 0.02), (0.058, 0.08), (0.035, 0.12), (0.0, 0.15)]
    body = lathe(profile, 8, body_color)
    body.deform(lambda v: Vector((v.x * 0.42, v.y, v.z)))
    body = Geo().add(body, T(rot=(-90, 0, 0)))
    if stripe_fn:
        for i, face in enumerate(body.faces):
            center = sum((body.verts[k] for k in face), Vector()) / len(face)
            color = stripe_fn(center)
            if color:
                body.colors[i] = rgba(color)
    g.add(body)
    tail = prism([(-0.06, 0.0), (0.0, 0.035), (0.06, 0.0), (0.075, -0.07), (0.0, -0.03), (-0.075, -0.07)], 0.01, fin_color)
    g.add(tail, T((0.005, -0.11, 0.0), (0, 90, 0)))
    g.add(prism([(0.0, -0.07), (0.06, -0.02), (0.0, 0.05)], 0.008, fin_color), T((0.004, 0.0, 0.05), (0, 90, 0)))
    g.add(prism([(0.0, -0.05), (-0.035, -0.02), (0.0, 0.03)], 0.007, fin_color), T((0.0035, 0.0, -0.045), (0, 90, 0)))
    for x in (-1, 1):
        g.add(box(0.006, 0.022, 0.022, eye_ring), T((x * 0.021, 0.085, 0.018)))
        g.add(box(0.008, 0.012, 0.012, "black"), T((x * 0.023, 0.087, 0.018)))
        g.add(prism([(0.0, 0.0), (0.035, -0.012), (0.03, 0.012)], 0.004, fin_color), T((x * 0.026, 0.05, -0.01), (0, 0, 90 + x * 60)))
    return g


@model("fish_blue_tang")
def fish_blue_tang():
    """A02 royal blue reef fish with a navy saddle and yellow tail."""
    return _fish("royal", "yellow", stripe_fn=lambda c: "navy" if c.z > 0.02 and -0.06 < c.y < 0.07 else None)


@model("fish_yellow_tang")
def fish_yellow_tang():
    """A02 yellow reef fish with a dark eye bar."""
    return _fish("yellow", "gold", stripe_fn=lambda c: "charcoal" if 0.07 < c.y < 0.1 else None)


@model("fish_clown")
def fish_clown():
    """A02 orange reef fish with white bands."""
    return _fish("orange", "darkorange",
                 stripe_fn=lambda c: "white" if (0.07 < c.y < 0.1) or (-0.02 < c.y < 0.015) or (-0.1 < c.y < -0.075) else None)


def _starfish(color, dot_color):
    g = Geo()
    points = []
    for k in range(10):
        a = math.pi / 2 + 2 * math.pi * k / 10
        r = 0.16 if k % 2 == 0 else 0.062
        points.append(Vector((math.cos(a) * r, math.sin(a) * r, 0.0)))
    center = Vector((0, 0, 0.045))
    for k in range(10):
        p, q = points[k], points[(k + 1) % 10]
        top_p = Vector((p.x, p.y, 0.012 if k % 2 == 0 else 0.028))
        top_q = Vector((q.x, q.y, 0.012 if (k + 1) % 2 == 0 else 0.028))
        base = len(g.verts)
        g.verts.extend([center.copy(), top_p, top_q, p.copy(), q.copy()])
        g.face((base, base + 1, base + 2), color)
        g.face((base + 1, base + 3, base + 4, base + 2), color)
        g.face((base + 3, base, base + 4), color)
    rng = random.Random(3)
    for k in range(5):
        a = math.pi / 2 + 2 * math.pi * k / 5
        for d in (0.05, 0.09, 0.125):
            g.add(box(0.012, 0.012, 0.01, dot_color), T((math.cos(a) * d, math.sin(a) * d, 0.035 - d * 0.18), (0, 0, rng.uniform(0, 90))))
    return g


@model("starfish_orange")
def starfish_orange():
    """A03 orange sea star."""
    return _starfish("orange", "peach")


@model("starfish_purple")
def starfish_purple():
    """A03 purple sea star."""
    return _starfish("purple", "lilac")


def _gull_body():
    g = Geo()
    body = ico(1.0, "gullwhite", subdiv=1)
    body.deform(lambda v: Vector((v.x * 0.085, v.y * 0.17, v.z * 0.08)))
    g.add(body)
    head = ico(1.0, "gullwhite", subdiv=1)
    head.deform(lambda v: Vector((v.x * 0.052, v.y * 0.06, v.z * 0.052)))
    g.add(head, T((0, 0.15, 0.07)))
    g.add(cyl(0.014, 0.0, 0.06, 5, "beak"), T((0, 0.2, 0.066), (-90, 0, 0)))
    g.add(box(0.008, 0.008, 0.008, "red"), T((0, 0.232, 0.06)))
    for x in (-1, 1):
        g.add(box(0.006, 0.012, 0.012, "gulldark"), T((x * 0.045, 0.17, 0.085)))
    g.add(prism([(-0.05, 0.0), (0.05, 0.0), (0.035, -0.09), (-0.035, -0.09)], 0.015, "gullgrey"), T((0, -0.12, 0.005), (-8, 0, 0)))
    g.add(box(0.07, 0.03, 0.012, "gulldark"), T((0, -0.215, 0.006)))
    return g


@model("gull_standing")
def gull_standing():
    """A05 standing herring gull with folded wings."""
    g = Geo()
    g.add(_gull_body(), T((0, 0, 0.16), (8, 0, 0)))
    for x in (-1, 1):
        wing = prism([(0.0, 0.09), (0.03, 0.05), (0.02, -0.16), (-0.005, -0.2)], 0.012, "gullgrey")
        g.add(wing, T((x * 0.078, 0.02, 0.19), (0, x * 80, 0)))
        g.add(box(0.012, 0.05, 0.012, "gulldark"), T((x * 0.07, -0.165, 0.165), (8, 0, 0)))
        g.add(box(0.014, 0.014, 0.1, "gullleg"), T((x * 0.035, 0.0, 0.05)))
        g.add(prism([(-0.025, 0.0), (0.025, 0.0), (0.0, 0.05)], 0.006, "gullleg"), T((x * 0.035, 0.0, 0.0)))
    return g


@model("gull_flying")
def gull_flying():
    """A05 gliding gull; wings are separate parts for a slow flap."""
    def build(name):
        objects = [make_object(name, _gull_body())]
        wing_poly = [(0.0, 0.06), (0.22, 0.05), (0.42, -0.01), (0.46, -0.05), (0.3, -0.07), (0.0, -0.06)]
        for part, side in (("WingL", 1), ("WingR", -1)):
            wing = prism(wing_poly, 0.012, "gullgrey")
            for i, face in enumerate(wing.faces):
                center = sum((wing.verts[k] for k in face), Vector()) / len(face)
                if center.x > 0.33:
                    wing.colors[i] = rgba("gulldark")
            placed = Geo().add(wing, T(scale=(side, 1, 1)))
            if side < 0:
                placed.faces = [tuple(reversed(f)) for f in placed.faces]
            objects.append(make_object(part, placed, parent=objects[0], location=(side * 0.06, 0.02, 0.03)))
        return objects
    return build


# ===== Reef plants (A04). Neutral light vertex colours; the game tints them for restoration. =====

def _branch(g, start, direction, length, radius, depth, rng, colors):
    end = start + direction * length
    g.add(tube([start, end], [radius, radius * 0.7], 4, colors[min(depth, len(colors) - 1)], cap=False))
    if depth == 0:
        tip = cyl(radius * 0.7, 0.0, radius * 2.2, 4, colors[0])
        g.add(tip, Matrix.Translation(end) @ direction.to_track_quat("Z", "Y").to_matrix().to_4x4())
        return
    for k in range(rng.choice((2, 3))):
        spin = rng.uniform(0, 2 * math.pi)
        tilt = math.radians(rng.uniform(24, 44))
        side = Vector((math.cos(spin), math.sin(spin), 0.0))
        new_direction = (direction * math.cos(tilt) + side * math.sin(tilt)).normalized()
        _branch(g, end, new_direction, length * rng.uniform(0.62, 0.78), radius * 0.68, depth - 1, rng, colors)


@model("coral_branching")
def coral_branching():
    """A04C staghorn coral clump, about 0.7 m tall."""
    g = Geo()
    rng = random.Random(41)
    colors = ["coraltip", "coralbase", "coralbase", "coralshade"]
    for k in range(5):
        a = 2 * math.pi * k / 5 + 0.4
        start = Vector((math.cos(a) * 0.08, math.sin(a) * 0.08, 0.0))
        direction = Vector((math.cos(a) * 0.4, math.sin(a) * 0.4, 1.0)).normalized()
        _branch(g, start, direction, 0.3, 0.045, 2, rng, colors)
    g.add(ico(0.12, "coralshade", subdiv=1), T((0, 0, 0.02), scale=(1.4, 1.4, 0.5)))
    return g


@model("coral_brain")
def coral_brain():
    """A04C brain coral mound with meandering ridges picked out by facet colour."""
    g = ico(1.0, "coralbase", subdiv=2)
    g.deform(lambda v: Vector((v.x * 0.34, v.y * 0.3, max(v.z, -0.1) * 0.22 + 0.022)))
    g.jitter(0.012, seed=17)
    for i, face in enumerate(g.faces):
        c = sum((g.verts[k] for k in face), Vector()) / len(face)
        wave = math.sin(c.x * 38.0 + math.sin(c.y * 21.0) * 2.2)
        g.colors[i] = rgba("coralshade" if wave > 0.25 else "coraltip" if wave < -0.55 else "coralbase")
    return g


@model("coral_fan")
def coral_fan():
    """A04C gorgonian sea fan: one gently cupped net fanning out from a short stalk. Ribs radiate
    from the stalk (three raised as veins) and the meshes get finer towards the base, where a
    solid palm joins the net to the stalk. Every strand belongs to the one net, so nothing
    floats. Single mesh, near-white for tinting, origin at the base."""
    g = Geo()
    rng = random.Random(8)
    base_z, reach, spread, foot = 0.09, 0.62, math.radians(52.0), 0.03
    squeeze = 0.305 / (reach * 0.9 * math.sin(spread))
    levels = [0.05, 0.24, 0.4, 0.54, 0.67, 0.79, 0.9, 1.0]     # row boundaries, stalk to rim
    columns = [4, 4, 4, 8, 8, 8, 8]                               # cells per row; row 0 is the palm
    veins = (-0.5, 0.0, 0.5)

    def at(across, out):
        """across in [-1, 1] over the fan, out in [0, 1] from the stalk to the rim."""
        phi = across * spread
        r = reach * out * (1.0 - 0.1 * across * across)
        x = math.sin(phi) * r * squeeze + across * foot * (1.0 - out)   # ribs rise from a short foot
        z = base_z + math.cos(phi) * r
        y = -0.045 * (x / 0.305) ** 2 + 0.016 * (z - 0.42) / 0.3 + 0.006 * math.sin(x * 11.0)
        return Vector((x, y, z))

    boundaries = []
    for j, out in enumerate(levels):
        count = max(columns[j - 1] if j > 0 else 0, columns[j] if j < len(columns) else 0)
        row = []
        for i in range(count + 1):
            across, o = -1.0 + 2.0 * i / count, out
            if 0 < i < count and 0 < j < len(levels) - 1:
                if not any(abs(across - v) < 1e-6 for v in veins):
                    across += rng.uniform(-0.22, 0.22) * 2.0 / count
                o += rng.uniform(-0.15, 0.15) * (levels[j + 1] - levels[j - 1]) * 0.5
            row.append(at(across, o))
        boundaries.append(row)
    facing = Vector((0.0, 1.0, 0.0))
    for j, count in enumerate(columns):
        lower, upper = boundaries[j], boundaries[j + 1]
        step_low, step_up = (len(lower) - 1) // count, (len(upper) - 1) // count
        for c in range(count):
            outline = lower[c * step_low:(c + 1) * step_low + 1] + list(reversed(upper[c * step_up:(c + 1) * step_up + 1]))
            color = "coralshade" if j == 0 else "coraltip" if j == len(columns) - 1 or c in (0, count - 1) else "coralbase"
            if j == 0:
                _quad_facing(g, outline, facing, color)
                continue
            middle = sum(outline, Vector()) / len(outline)
            opening = rng.uniform(0.52, 0.68)
            holes = [middle + (p - middle) * opening for p in outline]
            for k in range(len(outline)):
                n = (k + 1) % len(outline)
                _quad_facing(g, [outline[k], outline[n], holes[n], holes[k]], facing, color)
    # Veins: raised ribs from inside the stalk out along the three un-jittered rib lines.
    for across in veins:
        steps = (0, 2, 4, 7) if across == 0.0 else (0, 2, 4, 6)
        path = [Vector((0.0, 0.0, base_z - 0.02))]
        for j in steps:
            row = boundaries[j]
            path.append(row[round((across + 1.0) / 2.0 * (len(row) - 1))])
        g.add(tube(path, [0.02, 0.017, 0.013, 0.009, 0.006], 3, "coralbase", cap=False))
    g.add(cyl(0.03, 0.026, base_z + 0.04, 6, "coralshade", top=False))
    g.add(cyl(0.05, 0.03, 0.022, 6, "coralshade", top=False))
    return g


@model("coral_tube")
def coral_tube():
    """A04C cluster of open-topped tube coral of varied heights."""
    g = Geo()
    rng = random.Random(23)
    for k in range(7):
        a = 2 * math.pi * k / 7 + rng.uniform(-0.3, 0.3)
        d = 0.0 if k == 0 else rng.uniform(0.08, 0.17)
        r = rng.uniform(0.04, 0.065)
        h = rng.uniform(0.28, 0.72) * (1.15 if k == 0 else 1.0)
        tilt = (rng.uniform(-10, 10), rng.uniform(-10, 10), 0)
        body = cyl(r * 0.8, r, h, 7, "coralbase", top=False, bottom=False)
        rim = lathe([(r, h), (r * 1.08, h + 0.012), (r * 0.72, h + 0.01), (r * 0.7, h - 0.05)], 7, ["coraltip", "coraltip", "coralshade"], cap_top=True, cap_bottom=False)
        tube_geo = Geo().add(body).add(rim)
        g.add(tube_geo, T((math.cos(a) * d, math.sin(a) * d, 0.0), tilt))
    return g


@model("seaweed_kelp")
def seaweed_kelp():
    """A04P tall kelp: three wavy stalks with alternating blades, up to about 1.9 m."""
    g = Geo()
    rng = random.Random(5)
    blade_poly = [(0.0, 0.0), (0.028, 0.08), (0.02, 0.2), (0.0, 0.27), (-0.012, 0.16), (-0.02, 0.06)]
    for s in range(3):
        a = 2 * math.pi * s / 3 + 0.3
        base = Vector((math.cos(a) * 0.07, math.sin(a) * 0.07, 0.0))
        height = (1.9, 1.45, 1.15)[s]
        points = []
        for k in range(9):
            t = k / 8
            sway = math.sin(t * 5.0 + s) * 0.06
            points.append(base + Vector((math.cos(a) * (0.05 * t + sway), math.sin(a) * (0.05 * t + sway), height * t)))
        g.add(tube(points, [0.014 * (1.0 - 0.6 * k / 8) for k in range(9)], 4, "coralbase"))
        for k in range(1, 8):
            p = points[k]
            spin = math.degrees(a) + (90 if k % 2 else -90) + rng.uniform(-25, 25)
            blade = prism(blade_poly, 0.005, "coraltip" if k % 3 else "coralbase")
            g.add(blade, T(tuple(p), (rng.uniform(-35, -15), 0, spin)) @ T(rot=(90, 0, 0)))
    return g


@model("seagrass_tuft")
def seagrass_tuft():
    """A04P clump of curved seagrass blades, 0.5–0.95 m tall."""
    g = Geo()
    rng = random.Random(9)
    for k in range(12):
        a = 2 * math.pi * k / 12 + rng.uniform(-0.2, 0.2)
        outward = Vector((math.cos(a), math.sin(a), 0.0))
        across = Vector((-outward.y, outward.x, 0.0))
        height = rng.uniform(0.5, 0.95)
        lean = rng.uniform(0.12, 0.3)
        root = outward * rng.uniform(0.02, 0.1)
        base = len(g.verts)
        steps = 4
        for i in range(steps + 1):
            t = i / steps
            center = root + outward * lean * t * t + Vector((0, 0, height * t))
            width = 0.03 * (1.0 - t) + 0.004
            g.verts.append(center - across * width)
            g.verts.append(center + across * width)
        for i in range(steps):
            color = "coralshade" if i == 0 else "coralbase" if i < 3 else "coraltip"
            g.face((base + 2 * i, base + 2 * i + 1, base + 2 * i + 3, base + 2 * i + 2), color)
    return g


# ===== Structures and large props (A16) =====

@model("lifeguard_tower")
def lifeguard_tower():
    """A16L LA-style lifeguard tower: hut on stilts, a porch rail all round, and a railed access ramp that climbs
    from the sand on the sea side (-Y) up to the deck at the hut's front door."""
    g = Geo()
    deck_z = 1.8
    for x in (-1.15, 1.15):
        for y in (-1.15, 1.15):
            g.add(box(0.14, 0.14, deck_z, "bleachwood", base=True), T((x, y, 0.0)))
    for y in (-1.15, 1.15):
        g.add(box(2.3, 0.06, 0.1, "wood"), T((0, y, 0.9), (0, 32, 0)))
    for x in (-1.15, 1.15):
        g.add(box(0.06, 2.3, 0.1, "wood"), T((x, 0, 0.9), (32, 0, 0)))
    for k in range(9):
        g.add(box(3.0, 0.32, 0.08, "bleachwood" if k % 2 else "wood"), T((0, -1.4 + k * 0.35, deck_z + 0.04)))
    hut_z = deck_z + 0.08
    hut = box(2.2, 1.9, 1.75, "sky", chamfer=0.03, base=True)
    g.add(hut, T((0, 0.35, hut_z)))
    for x in (-1.1, 1.1):
        for y in (-0.6, 1.3):
            g.add(box(0.1, 0.1, 1.75, "white", base=True), T((x, y, hut_z)))
    # Front wall: the door (with a small window) at the head of the ramp, windows either side.
    g.add(box(0.72, 0.06, 1.36, "white"), T((0, -0.61, hut_z + 0.68)))
    g.add(box(0.36, 0.07, 0.36, "navy"), T((0, -0.615, hut_z + 1.02)))
    g.add(box(0.05, 0.08, 0.05, "darkgrey"), T((0.26, -0.64, hut_z + 0.68)))
    for x in (-0.73, 0.73):
        g.add(box(0.5, 0.06, 0.8, "navy"), T((x, -0.61, hut_z + 0.95)))
    g.add(box(0.06, 1.2, 0.7, "navy"), T((1.11, 0.35, hut_z + 0.95)))
    g.add(box(0.06, 1.2, 0.7, "navy"), T((-1.11, 0.35, hut_z + 0.95)))
    g.add(box(1.2, 0.06, 0.7, "navy"), T((0, 1.31, hut_z + 0.95)))
    g.add(box(0.5, 0.05, 0.36, "white"), T((0, -0.64, hut_z + 1.6)))
    g.add(box(0.3, 0.05, 0.08, "red"), T((0, -0.665, hut_z + 1.6)))
    g.add(box(0.08, 0.05, 0.3, "red"), T((0, -0.665, hut_z + 1.6)))
    roof_z = hut_z + 1.75
    g.add(hull([(-1.45, -0.95, roof_z), (1.45, -0.95, roof_z), (-1.45, 1.65, roof_z), (1.45, 1.65, roof_z),
                (-1.45, -0.95, roof_z + 0.12), (1.45, -0.95, roof_z + 0.12), (-1.45, 1.65, roof_z + 0.12), (1.45, 1.65, roof_z + 0.12),
                (-0.5, 0.2, roof_z + 0.62), (0.5, 0.2, roof_z + 0.62), (-0.5, 0.5, roof_z + 0.62), (0.5, 0.5, roof_z + 0.62)], "white"))
    g.add(box(2.95, 2.65, 0.08, "blue"), T((0, 0.35, roof_z + 0.04)))
    # Porch rail all round the deck, open only at the head of the ramp (between the posts at x = ±0.7).
    rail_z = deck_z + 0.08
    for x in (-1.45, -0.7, 0.7, 1.45):
        g.add(box(0.07, 0.07, 0.95, "white", base=True), T((x, -1.45, rail_z)))
    for x in (-1.45, 1.45):
        for y in (-0.7, 0.0, 0.7, 1.45):
            g.add(box(0.07, 0.07, 0.95, "white", base=True), T((x, y, rail_z)))
    for x in (-0.7, 0.0, 0.7):
        g.add(box(0.07, 0.07, 0.95, "white", base=True), T((x, 1.45, rail_z)))
    for z in (0.45, 0.9):
        g.add(box(0.8, 0.06, 0.06, "white"), T((-1.07, -1.45, rail_z + z)))
        g.add(box(0.8, 0.06, 0.06, "white"), T((1.07, -1.45, rail_z + z)))
        g.add(box(0.06, 2.96, 0.06, "white"), T((-1.45, 0.0, rail_z + z)))
        g.add(box(0.06, 2.96, 0.06, "white"), T((1.45, 0.0, rail_z + z)))
        g.add(box(2.96, 0.06, 0.06, "white"), T((0.0, 1.45, rail_z + z)))
    # Access ramp through the front rail opening: its head meets the deck edge flush with the deck
    # boards at the door, its foot rests on the sand. Built flat along +Y from the foot, then tilted.
    deck_top, foot_z = deck_z + 0.08, 0.055
    head_y, foot_y = -1.52, -4.86
    run, rise = head_y - foot_y, deck_top - foot_z
    angle = math.degrees(math.atan2(rise, run))
    length = math.hypot(rise, run)
    ramp = Geo()
    for k in range(12):
        ramp.add(box(1.32, length / 12 - 0.02, 0.06, "bleachwood" if k % 2 else "wood"), T((0, (k + 0.5) * length / 12, -0.03)))
    # Stringers start where their underside meets the sand, so nothing sinks below z = 0.
    start = (0.19 * math.cos(math.radians(angle)) - foot_z) / math.sin(math.radians(angle))
    for x in (-0.62, 0.62):
        ramp.add(box(0.08, length - start, 0.16, "wood"), T((x, (start + length) / 2, -0.11)))
    g.add(ramp, T((0, foot_y, foot_z), (angle, 0, 0)))
    def surface(y):
        return foot_z + rise * (y - foot_y) / run
    # Ramp rails in line with the opening posts: the handrail and mid rail climb from the foot post
    # and meet those posts at the heights of the porch rails. Posts are bolted down the stringers.
    newel_y = -1.45
    for x in (-0.7, 0.7):
        for f in (0.05, 0.37, 0.69):
            y = foot_y + f * run
            top, bottom = surface(y) + rail_z + 0.95 - surface(newel_y), max(0.0, surface(y) - 0.2)
            g.add(box(0.07, 0.07, top - bottom, "white", base=True), T((x, y, bottom)))
        low_y = foot_y + 0.05 * run
        rail_length = math.hypot(newel_y - low_y, surface(newel_y) - surface(low_y)) + 0.035
        for z in (0.45, 0.9):
            height = rail_z + z - surface(newel_y)
            middle = (low_y + newel_y) / 2
            g.add(box(0.06, rail_length, 0.06, "white"), T((x, middle, surface(middle) + height), (angle, 0, 0)))
    # Mid-span trestle under the stringers.
    mid_y = foot_y + 0.5 * run
    under = surface(mid_y) - 0.19 / math.cos(math.radians(angle))
    for x in (-0.62, 0.62):
        g.add(box(0.1, 0.1, under, "bleachwood", base=True), T((x, mid_y, 0.0)))
    g.add(box(1.32, 0.08, 0.1, "wood"), T((0, mid_y, under - 0.05)))
    g.add(cyl(0.035, 0.03, 2.2, 6, "white"), T((1.45, 1.45, rail_z)))
    g.add(prism([(0.0, 0.0), (0.6, 0.0), (0.6, 0.38), (0.0, 0.38)], 0.02, "red"), T((1.45, 1.45, rail_z + 1.7), (90, 0, 20)))
    return g


def _hull_section(y, half_width, sheer, keel_width):
    return [(-half_width, y, sheer), (-keel_width, y, 0.0), (keel_width, y, 0.0), (half_width, y, sheer)]


# Rowboat stations (y, half width at the sheer, sheer height, half width of the flat bottom), stern
# to bow. The inner skin is the outer one scaled by ROWBOAT_INNER_SCALE and raised ROWBOAT_INNER_LIFT.
ROWBOAT_STATIONS = [(-1.6, 0.55, 0.62, 0.34), (-1.1, 0.64, 0.58, 0.38), (-0.3, 0.68, 0.56, 0.4),
                    (0.5, 0.62, 0.58, 0.34), (1.1, 0.42, 0.64, 0.2), (1.5, 0.16, 0.74, 0.04), (1.62, 0.0, 0.8, 0.0)]
ROWBOAT_INNER_SCALE = (0.9, 0.97, 0.9)
ROWBOAT_INNER_LIFT = 0.05
# Thwarts (y, fore-and-aft depth); their tops are at ROWBOAT_THWART_TOP.
ROWBOAT_THWARTS = ((-1.05, 0.26), (-0.1, 0.26), (0.75, 0.24))
ROWBOAT_THWART_TOP = 0.465


def _rowboat_inner_half_width(y, z):
    """Half width of the rowboat's inner skin at (y, z); each side runs straight from bottom to sheer."""
    sx, sy, sz = ROWBOAT_INNER_SCALE
    yo, zo = y / sy, (z - ROWBOAT_INNER_LIFT) / sz
    stations = ROWBOAT_STATIONS
    for (y0, hw0, sh0, k0), (y1, hw1, sh1, k1) in zip(stations, stations[1:]):
        if yo <= y1 or y1 == stations[-1][0]:
            f = min(1.0, max(0.0, (yo - y0) / (y1 - y0)))
            hw, sheer, keel = hw0 + (hw1 - hw0) * f, sh0 + (sh1 - sh0) * f, k0 + (k1 - k0) * f
            return sx * (keel + (hw - keel) * zo / sheer)
    return 0.0


@model("rowboat")
def rowboat():
    """A16B small wooden rowboat hull, 3.2 m long (bow at +Y): thwarts and floorboards fitted inside
    the planking, a capped gunwale with rubrails and two rowlocks. The oars are rowboat_oars."""
    g = Geo()
    outer = Geo()
    ring = []
    for y, hw, sheer, keel in ROWBOAT_STATIONS:
        ring.append([Vector(p) for p in _hull_section(y, hw, sheer, keel)])
    for s in range(len(ring) - 1):
        a, b = ring[s], ring[s + 1]
        for k in range(3):
            # Twisted panels are split explicitly so the inner skin (a scaled copy) keeps the same
            # diagonal and stays inside the planking instead of poking through near the bow.
            base = len(outer.verts)
            outer.verts.extend([a[k], a[k + 1], b[k + 1], b[k]])
            color = "red" if k == 1 else "white"
            outer.face((base, base + 3, base + 2), color)
            outer.face((base, base + 2, base + 1), color)
    stern = ring[0]
    base = len(outer.verts)
    outer.verts.extend(stern)
    outer.faces.append((base, base + 1, base + 2, base + 3))
    outer.colors.append(rgba("white"))
    g.add(outer)
    inner_matrix = T((0, 0.0, ROWBOAT_INNER_LIFT), scale=ROWBOAT_INNER_SCALE)
    inner = Geo().add(outer, inner_matrix, color="lightbrown")
    inner.faces = [tuple(reversed(f)) for f in inner.faces]
    g.add(inner)
    # Gunwale capping closes the gap between the outer planking and the inner skin, stern to stem.
    for k in (0, 3):
        for s in range(len(ring) - 1):
            p, q = ring[s][k], ring[s + 1][k]
            _quad_facing(g, [p, q, inner_matrix @ q, inner_matrix @ p], Vector((0, 0, 1)), "blue")
    _quad_facing(g, [ring[0][0], ring[0][3], inner_matrix @ ring[0][3], inner_matrix @ ring[0][0]], Vector((0, 0, 1)), "blue")
    for side in (-1, 1):
        rail = [Vector((side * (hw + 0.018), y, sheer - 0.03)) for y, hw, sheer, keel in ROWBOAT_STATIONS[:-1]]
        rail.append(Vector((0.0, 1.595, 0.77)))
        g.add(tube(rail, 0.028, 4, "blue"))
    # Thwarts: each end follows the inner skin, so no plank pokes through the sides.
    top = ROWBOAT_THWART_TOP
    for y, depth in ROWBOAT_THWARTS:
        points = []
        for yy in (y - depth / 2.0, y + depth / 2.0):
            for z in (top - 0.05, top):
                x = _rowboat_inner_half_width(yy, z) - 0.006
                points += [(-x, yy, z), (x, yy, z)]
        g.add(hull(points, "wood"))
    # Floorboards on the flat inner bottom.
    for x in (-0.13, 0.0, 0.13):
        g.add(box(0.1, 2.25, 0.02, "darkwood" if x == 0.0 else "wood"), T((x, -0.18, ROWBOAT_INNER_LIFT + 0.012)))
    # Rowlocks on the gunwale capping, abaft the rowing thwart.
    y = -0.42
    for side in (-1, 1):
        x = side * (_rowboat_inner_half_width(y, 0.55) + 0.66) * 0.5
        g.add(cyl(0.022, 0.022, 0.035, 6, "darkgrey"), T((x, y, 0.55)))
        g.add(tube(arc_path(0.032, 180, 360, 4), 0.008, 4, "darkgrey", cap=False), T((x, y, 0.617), (90, 0, 90)))
    return g


def _oar(length=2.1):
    """One oar along +Y, grip end at the origin, blade lying flat (blade tip at y = length)."""
    g = Geo()
    g.add(tube([Vector((0, 0, 0)), Vector((0, 0.15, 0))], 0.017, 6, "darkwood"))
    g.add(tube([Vector((0, 0.15, 0)), Vector((0, length - 0.6, 0))], [0.024, 0.021], 6, "bleachwood"))
    g.add(tube([Vector((0, 0.5, 0)), Vector((0, 0.64, 0))], 0.027, 6, "darkwood"))
    blade = [(-0.02, length - 0.66), (0.02, length - 0.66), (0.075, length - 0.36), (0.07, length - 0.03),
             (0.0, length), (-0.07, length - 0.03), (-0.075, length - 0.36)]
    g.add(prism(blade, 0.016, "blue", side_color="darkblue"), T((0, 0, -0.008)))
    return g


@model("rowboat_oars")
def rowboat_oars():
    """A16B pair of oars resting on the rowboat's thwarts, in the rowboat's own frame (bow at +Y)."""
    g = Geo()
    z = ROWBOAT_THWART_TOP + 0.024
    g.add(_oar(), T((0.2, -1.28, z), (0, 0, 1.2)))
    g.add(_oar(), T((-0.21, -1.24, z), (0, 4, -0.8)))
    return g


@model("beach_tent")
def beach_tent():
    """A16T pop-up beach shelter: striped half dome open towards -Y, with a floor mat."""
    g = Geo()
    segs, rings = 10, 6
    verts = []
    for i in range(segs + 1):
        u = math.pi * i / segs
        row = []
        for j in range(rings + 1):
            v = (math.pi / 2) * j / rings
            x = math.cos(u) * math.cos(v) * 1.2
            y = math.sin(u) * math.cos(v) * 1.1
            z = math.sin(v) * 1.25
            row.append(Vector((x, y - 0.3, z)))
        verts.append(row)
    for i in range(segs):
        for j in range(rings):
            base = len(g.verts)
            g.verts.extend([verts[i][j], verts[i + 1][j], verts[i + 1][j + 1], verts[i][j + 1]])
            g.faces.append((base, base + 3, base + 2, base + 1))
            g.colors.append(rgba("orange" if i % 2 == 0 else "white"))
    front = [verts[i][0] + Vector((0, 0, 0.0)) for i in range(segs + 1)]
    arch = []
    for j in range(rings + 1):
        v = (math.pi / 2) * j / rings
        arch.append(Vector((math.cos(v) * 1.2, -0.3, math.sin(v) * 1.25)))
    arch_full = arch + [Vector((-p.x, p.y, p.z)) for p in reversed(arch[:-1])]
    g.add(tube(arch_full, 0.025, 4, "charcoal", cap=False))
    g.add(box(2.2, 1.35, 0.03, "blue", base=True), T((0, 0.25, 0.0)))
    g.add(box(2.2, 0.08, 0.035, "white", base=True), T((0, -0.38, 0.0)))
    for x in (-1.15, 1.15):
        g.add(box(0.25, 0.2, 0.08, "tan", chamfer=0.02, base=True), T((x, -0.35, 0.0)))
    return g


@model("storage_shelf")
def storage_shelf():
    """A16S one 1 m storage-shelf module; top board surface at z = 0.8 m. Modules tile along X."""
    g = Geo()
    for x in (-0.46, 0.46):
        for y in (-0.27, 0.27):
            g.add(box(0.06, 0.06, 0.8, "blue", base=True), T((x, y, 0.0)))
    for z, colors in ((0.75, ("wood", "bleachwood", "wood")), (0.28, ("bleachwood", "wood", "bleachwood"))):
        for k, color in enumerate(colors):
            g.add(box(1.0, 0.18, 0.05, color, chamfer=0.006, base=True), T((0, -0.19 + k * 0.19, z)))
        for y in (-0.27, 0.27):
            g.add(box(0.92, 0.04, 0.06, "darkblue"), T((0, y, z - 0.03)))
    g.add(box(0.92, 0.03, 0.12, "darkblue"), T((0, 0.27, 0.06)))
    g.add(box(0.04, 0.6, 0.04, "darkblue"), T((-0.46, 0, 0.5), (0, 0, 0)))
    return g


# ===== Clouds (look pass L4). Flat-bottomed low-poly cumulus in unit scale. =====

def _cumulus(seed, puffs):
    g = Geo()
    rng = random.Random(seed)
    for x, y, z, r in puffs:
        puff = ico(r, "cloud", subdiv=2)
        puff.jitter(r * 0.12, seed=rng.randint(0, 999))
        g.add(puff, T((x, y, z)))
    g.deform(lambda v: Vector((v.x, v.y, max(v.z, 0.0))))
    return g


@model("cloud_cumulus_a")
def cloud_cumulus_a():
    return _cumulus(1, [(0.0, 0.0, 0.2, 1.0), (1.1, 0.2, 0.05, 0.75), (-1.0, -0.1, 0.0, 0.7), (0.4, -0.3, 0.6, 0.7),
                        (-0.5, 0.25, 0.45, 0.6), (1.9, 0.0, -0.1, 0.5), (-1.8, 0.1, -0.15, 0.45)])


@model("cloud_cumulus_b")
def cloud_cumulus_b():
    return _cumulus(2, [(0.0, 0.0, 0.1, 0.8), (0.9, 0.1, 0.0, 0.6), (-0.8, 0.0, -0.05, 0.55), (0.3, 0.2, 0.45, 0.55),
                        (1.6, -0.1, -0.1, 0.42), (-1.5, 0.15, -0.12, 0.38)])


@model("cloud_cumulus_c")
def cloud_cumulus_c():
    return _cumulus(3, [(0.0, 0.0, 0.0, 0.6), (0.8, 0.0, -0.05, 0.5), (-0.7, 0.1, -0.08, 0.45), (0.2, -0.1, 0.3, 0.45),
                        (1.4, 0.1, -0.15, 0.35), (-1.3, 0.0, -0.15, 0.3), (2.0, 0.0, -0.2, 0.25)])


# --- export --------------------------------------------------------------------------------

def _material():
    mat = bpy.data.materials.get("Palette")
    if mat is None:
        mat = bpy.data.materials.new("Palette")
        mat.use_nodes = True
        mat.use_backface_culling = False
        nodes = mat.node_tree.nodes
        bsdf = nodes["Principled BSDF"]
        color = nodes.new("ShaderNodeVertexColor")
        color.layer_name = "Col"
        mat.node_tree.links.new(color.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.8
        bsdf.inputs["Metallic"].default_value = 0.0
    return mat


def make_object(name, geo, parent=None, location=(0, 0, 0)):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(v) for v in geo.verts], [], [list(f) for f in geo.faces])
    mesh.validate(clean_customdata=False)
    attribute = mesh.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    for poly, color in zip(mesh.polygons, geo.colors):
        for loop_index in poly.loop_indices:
            attribute.data[loop_index].color = color
    for poly in mesh.polygons:
        poly.use_smooth = False
    mesh.materials.append(_material())
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = location
    if parent is not None:
        obj.parent = parent
    return obj


def export(name, objects, out_dir):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    path = os.path.join(out_dir, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_texcoords=False, export_normals=True,
                              export_vertex_color="MATERIAL", export_materials="EXPORT",
                              export_animations=False, export_extras=False)
    tris = 0
    for obj in objects:
        if obj.type == "MESH":
            tris += sum(len(p.vertices) - 2 for p in obj.data.polygons)
    print("MODEL %s tris=%d -> %s" % (name, tris, path))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = None
    out_dir = os.path.join(os.getcwd(), "art", "models")
    for arg in argv:
        if arg.startswith("--only="):
            only = set(arg.split("=", 1)[1].split(","))
        elif arg.startswith("--out="):
            out_dir = os.path.abspath(arg.split("=", 1)[1])
    os.makedirs(out_dir, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for name, build in MODELS.items():
        if only and name not in only:
            continue
        result = build()
        if isinstance(result, Geo):
            objects = [make_object(OBJECT_NAMES.get(name, name), result)]
        else:
            objects = result(name)
        export(name, objects, out_dir)
        for obj in objects:
            bpy.data.objects.remove(obj, do_unlink=True)


if __name__ == "__main__":
    main()
