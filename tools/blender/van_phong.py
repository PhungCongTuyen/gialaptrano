# -*- coding: utf-8 -*-
# Dựng đồ văn phòng cho intro "60 Ngày" (chạy trong Blender, sau no60_lib.py).
# Dùng: exec(open(LIB).read()); OUT = "E:/gialaptrano/models/van_phong"; exec(open(THIS).read())
#
# Quy ước: Blender Z lên, mặt trước của đồ vật (phía người ngồi / cánh tủ) quay về -Y.
# write_glb đổi sang Godot: (x, y, z)_Blender -> (x, z, -y), nên mặt trước nằm về +Z trong Godot.
# Người ngồi quay mặt về +Y (Godot -Z), gốc toạ độ = tâm ghế trên sàn.
# Tên vật liệu được Godot dùng để gắn texture / phát sáng: ManHinh, DenLED, CanhNgoai, BangTrang, MatDongHo.
import bpy, bmesh, math, random, os
from mathutils import Vector, Matrix, Euler

try:
    OUT
except NameError:
    OUT = "E:/gialaptrano/models/van_phong"
os.makedirs(OUT, exist_ok=True)
SC = get_scene("VanPhong")
_WIN = bpy.context.window_manager.windows[0] if bpy.context.window_manager.windows else None
_OLD_SC = _WIN.scene if _WIN else None
if _WIN:
    _WIN.scene = SC   # để cảnh có depsgraph (modifier được tính)
R = random.Random(60)

# ------------------------------------------------------------------ vật liệu (màu tuyến tính)
M = {
    "MatBan": mat("MatBan", (0.72, 0.69, 0.63), 0.45),
    "VanGo": mat("VanGo", (0.36, 0.22, 0.12), 0.55),
    "KhungThep": mat("KhungThep", (0.42, 0.43, 0.45), 0.4, 0.6),
    "SonXam": mat("SonXam", (0.47, 0.48, 0.47), 0.42, 0.25),
    "SonXamSang": mat("SonXamSang", (0.62, 0.62, 0.6), 0.45, 0.2),
    "NiVach": mat("NiVach", (0.07, 0.14, 0.2), 0.95),
    "Nhom": mat("Nhom", (0.72, 0.73, 0.75), 0.3, 0.85),
    "NhuaDen": mat("NhuaDen", (0.018, 0.018, 0.02), 0.55),
    "VoMay": mat("VoMay", (0.012, 0.012, 0.014), 0.35),
    "DemGhe": mat("DemGhe", (0.02, 0.02, 0.024), 0.9),
    "LuoiGhe": mat("LuoiGhe", (0.025, 0.025, 0.03), 0.8),
    "ManHinh": mat("ManHinh", (0.2, 0.3, 0.5), 0.25),
    "Giay": mat("Giay", (0.85, 0.85, 0.82), 0.8),
    "SuTrang": mat("SuTrang", (0.8, 0.8, 0.78), 0.25),
    "Kinh": mat("Kinh", (0.55, 0.65, 0.7), 0.05, 0.0, 0.22),
    "KinhCuaSo": mat("KinhCuaSo", (0.6, 0.7, 0.75), 0.03, 0.0, 0.12),
    "NhuaTrang": mat("NhuaTrang", (0.78, 0.78, 0.76), 0.35),
    "NhuaXam": mat("NhuaXam", (0.5, 0.5, 0.49), 0.5),
    "NuocBinh": mat("NuocBinh", (0.25, 0.5, 0.85), 0.05, 0.0, 0.45),
    "NapXanh": mat("NapXanh", (0.05, 0.2, 0.6), 0.4),
    "VoiDo": mat("VoiDo", (0.6, 0.04, 0.03), 0.4),
    "VoiXanh": mat("VoiXanh", (0.03, 0.12, 0.6), 0.4),
    "DenXanh": mat("DenXanh", (0.1, 0.8, 0.4), 0.3),
    "BangTrang": mat("BangTrang", (0.86, 0.86, 0.85), 0.15),
    "MatDongHo": mat("MatDongHo", (0.85, 0.85, 0.82), 0.3),
    "ChauCay": mat("ChauCay", (0.18, 0.17, 0.16), 0.6),
    "Dat": mat("Dat", (0.06, 0.04, 0.03), 1.0),
    "LaCay": mat("LaCay", (0.04, 0.16, 0.05), 0.55),
    "LaCayVang": mat("LaCayVang", (0.35, 0.36, 0.08), 0.55),
    "TuongSon": mat("TuongSon", (0.74, 0.73, 0.69), 0.92),
    "ChanTuong": mat("ChanTuong", (0.16, 0.15, 0.14), 0.5),
    "ReManh": mat("ReManh", (0.78, 0.77, 0.72), 0.6),
    "TranThach": mat("TranThach", (0.8, 0.8, 0.78), 0.95),
    "DenLED": mat("DenLED", (0.95, 0.95, 0.92), 0.3),
    "CanhNgoai": mat("CanhNgoai", (0.7, 0.7, 0.7), 1.0),
    "CuaGo": mat("CuaGo", (0.3, 0.17, 0.08), 0.5),
    "BiaXanh": mat("BiaXanh", (0.04, 0.12, 0.45), 0.5),
    "BiaDo": mat("BiaDo", (0.5, 0.04, 0.04), 0.5),
    "BiaVang": mat("BiaVang", (0.75, 0.5, 0.04), 0.5),
    "BiaTrang": mat("BiaTrang", (0.75, 0.75, 0.72), 0.5),
    "BiaDen": mat("BiaDen", (0.03, 0.03, 0.03), 0.5),
    "CocSu": mat("CocSu", (0.75, 0.72, 0.65), 0.2),
    # người
    "Da": mat("Da", (0.62, 0.40, 0.28), 0.55),
    "Ao": mat("Ao", (0.75, 0.78, 0.82), 0.8),
    "Quan": mat("Quan", (0.04, 0.045, 0.06), 0.8),
    "GiayDa": mat("GiayDa", (0.015, 0.012, 0.01), 0.35),
    "Toc": mat("Toc", (0.012, 0.009, 0.008), 0.55),
    "MatNguoi": mat("MatNguoi", (0.01, 0.008, 0.006), 0.2),
    "Moi": mat("Moi", (0.45, 0.2, 0.16), 0.5),
    "CucAo": mat("CucAo", (0.6, 0.6, 0.58), 0.3),
    "TocBac": mat("TocBac", (0.1, 0.095, 0.09), 0.6),
    "GongKinh": mat("GongKinh", (0.02, 0.02, 0.02), 0.3, 0.5),
    "KinhMat": mat("KinhMat", (0.6, 0.65, 0.7), 0.05, 0.0, 0.18),
}


# ------------------------------------------------------------------ dựng hình
class Prop:
    def __init__(s, name):
        s.name = name
        s.g = {}

    def bm(s, m, bevel=0.0, sub=0, solid=0.0, ang=35):
        key = (m, bevel, sub, solid, ang)
        if key not in s.g:
            s.g[key] = bmesh.new()
        return s.g[key]

    def export(s, sub_name=None):
        clear_scene(SC)
        parts = []
        for (m, bevel, sub, solid, ang), b in s.g.items():
            ob = obj_from_bm(SC, "%s_%s" % (s.name, m), b, M[m])
            if solid > 0:
                md = ob.modifiers.new("so", "SOLIDIFY"); md.thickness = solid; md.offset = 0
            if bevel > 0:
                md = ob.modifiers.new("bv", "BEVEL"); md.width = bevel; md.segments = 2
                md.limit_method = 'ANGLE'; md.angle_limit = math.radians(40)
            if sub > 0:
                md = ob.modifiers.new("ss", "SUBSURF"); md.levels = sub; md.render_levels = sub
            parts.append((ob, ang))
        n = write_glb(OUT + "/" + (sub_name or s.name) + ".glb", parts)
        s.g = {}
        return n


def box(b, c, sz, rot=(0, 0, 0)):
    r = bmesh.ops.create_cube(b, size=1.0)
    Mx = Matrix.Translation(Vector(c)) @ Euler(rot).to_matrix().to_4x4() @ Matrix.Diagonal((sz[0], sz[1], sz[2], 1.0))
    bmesh.ops.transform(b, matrix=Mx, verts=r["verts"])


def cyl(b, c, r, h, seg=16, r2=None, rot=(0, 0, 0)):
    res = bmesh.ops.create_cone(b, cap_ends=True, cap_tris=False, segments=seg, radius1=r, radius2=(r if r2 is None else r2), depth=h)
    Mx = Matrix.Translation(Vector(c)) @ Euler(rot).to_matrix().to_4x4()
    bmesh.ops.transform(b, matrix=Mx, verts=res["verts"])


def ell(b, c, sc, seg=16, rings=10, rot=(0, 0, 0)):
    res = bmesh.ops.create_uvsphere(b, u_segments=seg, v_segments=rings, radius=1.0)
    Mx = Matrix.Translation(Vector(c)) @ Euler(rot).to_matrix().to_4x4() @ Matrix.Diagonal((sc[0], sc[1], sc[2], 1.0))
    bmesh.ops.transform(b, matrix=Mx, verts=res["verts"])
    return res["verts"]


def quad_uv(b, corners, uvs=((0, 0), (1, 0), (1, 1), (0, 1))):
    """corners theo thứ tự: dưới-trái, dưới-phải, trên-phải, trên-trái (nhìn từ phía mặt trước)"""
    ul = b.loops.layers.uv.verify()
    vs = [b.verts.new(Vector(p)) for p in corners]
    f = b.faces.new(vs)
    for lp, uv in zip(f.loops, uvs):
        lp[ul].uv = uv
    return f


def tube(b, pts, rads, ref=(1, 0, 0), seg=12, caps=True):
    """ống mặt cắt elip dọc theo đường gấp khúc, hai đầu bo tròn. rads: số hoặc (rx, ry)"""
    pts = [Vector(p) for p in pts]
    ref = Vector(ref)
    n = len(pts)
    base = []
    for i, p in enumerate(pts):
        t = (pts[1] - pts[0]) if i == 0 else ((pts[-1] - pts[-2]) if i == n - 1 else (pts[i + 1] - pts[i - 1]))
        t.normalize()
        sd = ref - t * ref.dot(t)
        if sd.length < 1e-4:
            sd = Vector((0, 1, 0)) - t * t.y
        sd.normalize()
        od = t.cross(sd)
        rr = rads[i]
        rx, ry = (rr, rr) if not isinstance(rr, (tuple, list)) else rr
        base.append((p, t, sd, od, rx, ry))
    rings = []
    if caps:
        p, t, sd, od, rx, ry = base[0]
        for a in (78, 55, 28):
            a = math.radians(a)
            rings.append((p - t * min(rx, ry) * math.sin(a), sd, od, rx * math.cos(a), ry * math.cos(a)))
    for p, t, sd, od, rx, ry in base:
        rings.append((p, sd, od, rx, ry))
    if caps:
        p, t, sd, od, rx, ry = base[-1]
        for a in (28, 55, 78):
            a = math.radians(a)
            rings.append((p + t * min(rx, ry) * math.sin(a), sd, od, rx * math.cos(a), ry * math.cos(a)))
    rows = []
    for c, sd, od, rx, ry in rings:
        rows.append([b.verts.new(c + sd * rx * math.cos(2 * math.pi * k / seg) + od * ry * math.sin(2 * math.pi * k / seg)) for k in range(seg)])
    for i in range(len(rows) - 1):
        for k in range(seg):
            b.faces.new([rows[i][k], rows[i][(k + 1) % seg], rows[i + 1][(k + 1) % seg], rows[i + 1][k]])
    if caps or True:
        b.faces.new(list(reversed(rows[0])))
        b.faces.new(rows[-1])


def done(p, name=None):
    n = p.export(name)
    LOG.append("%s: %d tam giác" % (name or p.name, n))


LOG = []

# ================================================================== BÀN LÀM VIỆC (1,4 x 0,7, mặt 0,75)
def ban_lam_viec():
    p = Prop("ban_lam_viec")
    top = p.bm("MatBan", bevel=0.004)
    box(top, (0, 0, 0.7375), (1.4, 0.7, 0.025))
    st = p.bm("KhungThep", bevel=0.004)
    for sx in (-0.66, 0.66):
        for sy in (-0.29, 0.29):
            box(st, (sx, sy, 0.36), (0.045, 0.045, 0.72))
        box(st, (sx, 0, 0.02), (0.06, 0.68, 0.04))        # thanh chân
        box(st, (sx, 0, 0.705), (0.05, 0.62, 0.04))       # đỡ mặt bàn
    box(st, (0, 0.27, 0.48), (1.28, 0.015, 0.36))         # tấm chắn chân
    # vách ngăn nỉ phía sau, viền nhôm
    nv = p.bm("NiVach", bevel=0.003)
    box(nv, (0, 0.36, 0.95), (1.38, 0.028, 0.4))
    al = p.bm("Nhom", bevel=0.003)
    box(al, (0, 0.36, 1.155), (1.42, 0.036, 0.018))
    for sx in (-0.7, 0.7):
        box(al, (sx, 0.36, 0.95), (0.024, 0.036, 0.42))
    # hộc tủ di động dưới bàn bên phải: 3 ngăn kéo
    hc = p.bm("SonXamSang", bevel=0.004)
    box(hc, (0.42, 0.0, 0.31), (0.4, 0.5, 0.56))
    hk = p.bm("Nhom", bevel=0.002)
    for z in (0.5, 0.36, 0.16):
        box(hc, (0.42, -0.253, z), (0.39, 0.008, 0.125 if z > 0.2 else 0.24))
        box(hk, (0.42, -0.262, z + (0.04 if z > 0.2 else 0.09)), (0.12, 0.012, 0.012))
    # thùng máy tính bên trái
    vm = p.bm("VoMay", bevel=0.004)
    box(vm, (-0.45, 0.05, 0.225), (0.19, 0.42, 0.43))
    dx = p.bm("DenXanh")
    box(dx, (-0.45, -0.162, 0.4), (0.012, 0.004, 0.012))
    # màn hình 24"
    box(vm, (0, 0.2, 0.7545), (0.24, 0.18, 0.009))
    box(vm, (0, 0.235, 0.85), (0.055, 0.025, 0.2))
    box(vm, (0, 0.21, 0.99), (0.56, 0.028, 0.345), rot=(math.radians(-6), 0, 0))
    mh = p.bm("ManHinh", ang=5)
    w, h = 0.53, 0.3
    tilt = Matrix.Rotation(math.radians(-6), 3, 'X')
    cn = [Vector((-w / 2, 0, -h / 2)), Vector((w / 2, 0, -h / 2)), Vector((w / 2, 0, h / 2)), Vector((-w / 2, 0, h / 2))]
    quad_uv(mh, [tuple(Vector((0, 0.1955, 0.99)) + tilt @ c) for c in cn])
    # bàn phím, chuột
    box(vm, (0, -0.12, 0.756), (0.44, 0.145, 0.013), rot=(math.radians(3), 0, 0))
    ph = p.bm("NhuaDen", bevel=0.001)
    for r_ in range(4):
        box(ph, (-0.035, -0.17 + r_ * 0.032, 0.766 + r_ * 0.0017), (0.33, 0.024, 0.008))
    box(ph, (0.17, -0.12, 0.766), (0.08, 0.12, 0.008))
    ch = p.bm("VoMay", sub=1, ang=180)
    ell(ch, (0.32, -0.12, 0.762), (0.031, 0.055, 0.018))
    done(p)


# ================================================================== GHẾ XOAY LƯỚI
def ghe_xoay():
    p = Prop("ghe_xoay")
    nd = p.bm("NhuaDen", bevel=0.006)
    for k in range(5):
        a = 2 * math.pi * k / 5 + math.pi / 2
        box(nd, (math.cos(a) * 0.16, math.sin(a) * 0.16, 0.085), (0.32, 0.045, 0.035), rot=(0, 0, a))
        cyl(nd, (math.cos(a) * 0.31, math.sin(a) * 0.31, 0.03), 0.028, 0.03, seg=10, rot=(math.pi / 2, 0, a))
    cyl(nd, (0, 0, 0.1), 0.05, 0.06, seg=16)
    al = p.bm("Nhom")
    cyl(al, (0, 0, 0.27), 0.024, 0.3, seg=14)
    cyl(nd, (0, 0, 0.42), 0.04, 0.05, seg=14)
    dm = p.bm("DemGhe", bevel=0.028)
    box(dm, (0, 0.02, 0.47), (0.49, 0.47, 0.07))
    box(nd, (0, 0.0, 0.43), (0.3, 0.3, 0.03))
    # lưng lưới
    lg = p.bm("LuoiGhe", bevel=0.02)
    box(lg, (0, -0.245, 0.83), (0.45, 0.035, 0.52), rot=(math.radians(-8), 0, 0))
    box(nd, (0, -0.235, 0.83), (0.48, 0.04, 0.56), rot=(math.radians(-8), 0, 0))
    box(nd, (0, -0.2, 0.5), (0.07, 0.04, 0.18))
    box(nd, (0, -0.215, 0.56), (0.08, 0.06, 0.06))
    # tay vịn
    for sx in (-0.265, 0.265):
        box(nd, (sx, -0.04, 0.57), (0.035, 0.05, 0.19))
        box(nd, (sx, -0.01, 0.67), (0.065, 0.25, 0.028))
    # khung lưng: phần lưới ở giữa chìm hơn khung
    done(p)


# ================================================================== TỦ SẮT 2 KHOANG (kiểu Hòa Phát)
def tu_sat():
    p = Prop("tu_sat")
    s = p.bm("SonXam", bevel=0.004)
    W, D, H = 1.0, 0.45, 1.83
    box(s, (-W / 2 + 0.01, 0, H / 2), (0.02, D, H))
    box(s, (W / 2 - 0.01, 0, H / 2), (0.02, D, H))
    box(s, (0, D / 2 - 0.01, H / 2), (W, 0.02, H))
    box(s, (0, 0, H - 0.01), (W, D, 0.02))
    box(s, (0, 0, 0.04), (W, D, 0.08))
    box(s, (0, 0, 0.92), (W, D, 0.03))
    for z in (1.24, 1.55):
        box(s, (0, 0.01, z), (W - 0.04, D - 0.04, 0.015))
    # cánh dưới: 2 cánh mở, tay nắm
    for sx in (-0.25, 0.25):
        box(s, (sx, -D / 2 + 0.01, 0.5), (0.492, 0.02, 0.82))
    hk = p.bm("Nhom", bevel=0.003)
    for sx in (-0.03, 0.03):
        box(hk, (sx, -D / 2 - 0.008, 0.7), (0.016, 0.02, 0.16))
    box(hk, (0, -D / 2 - 0.002, 0.82), (0.025, 0.01, 0.025))
    # hồ sơ bên trong khoang kính
    for z0 in (0.935, 1.2475, 1.5575):
        x = -W / 2 + 0.05
        while x < W / 2 - 0.08:
            t = R.choice([0.05, 0.06, 0.075])
            hh = R.uniform(0.24, 0.29)
            m = R.choice(["BiaXanh", "BiaXanh", "BiaDo", "BiaVang", "BiaTrang", "BiaDen"])
            lean = R.choice([0, 0, 0, R.uniform(-0.12, 0.12)])
            box(p.bm(m, bevel=0.003), (x + t / 2, 0.02, z0 + hh / 2), (t - 0.004, 0.3, hh), rot=(0, lean, 0))
            x += t + R.choice([0, 0, 0.004, 0.02])
            if R.random() < 0.08:
                x += 0.12
    # cánh kính lùa, khung nhôm
    k = p.bm("Kinh", ang=5)
    for sx, yy in ((-0.24, -D / 2 + 0.02), (0.24, -D / 2 + 0.006)):
        box(k, (sx, yy, 1.37), (0.5, 0.005, 0.86))
        for zz in (0.95, 1.79):
            box(hk, (sx, yy, zz), (0.5, 0.014, 0.025))
        for xx in (sx - 0.245, sx + 0.245):
            box(hk, (xx, yy, 1.37), (0.02, 0.014, 0.86))
    done(p)


# ================================================================== TỦ HỒ SƠ 4 NGĂN KÉO
def tu_ho_so():
    p = Prop("tu_ho_so")
    W, D, H = 0.47, 0.62, 1.32
    s = p.bm("SonXam", bevel=0.004)
    box(s, (0, 0.01, H / 2), (W, D - 0.02, H))
    hk = p.bm("Nhom", bevel=0.002)
    nh = p.bm("BiaTrang")
    for i in range(4):
        z = 0.08 + i * 0.31 + 0.15
        box(s, (0, -D / 2 + 0.01, z), (W - 0.02, 0.02, 0.29))
        box(hk, (0, -D / 2 - 0.006, z - 0.03), (0.16, 0.02, 0.025))
        box(hk, (0, -D / 2 - 0.002, z + 0.07), (0.09, 0.006, 0.045))
        box(nh, (0, -D / 2 - 0.006, z + 0.07), (0.075, 0.004, 0.032))
    done(p)


# ================================================================== CÂY NƯỚC NÓNG LẠNH
def cay_nuoc():
    p = Prop("cay_nuoc")
    t = p.bm("NhuaTrang", bevel=0.02)
    box(t, (0, 0, 0.5), (0.32, 0.32, 1.0))
    x = p.bm("NhuaXam", bevel=0.01)
    box(x, (0, -0.15, 0.72), (0.24, 0.04, 0.2))
    box(x, (0, -0.15, 0.27), (0.24, 0.03, 0.04))
    cyl(p.bm("VoiDo"), (-0.05, -0.17, 0.79), 0.012, 0.05, seg=10)
    cyl(p.bm("VoiXanh"), (0.05, -0.17, 0.79), 0.012, 0.05, seg=10)
    nb = p.bm("NuocBinh", sub=1, ang=180)
    lathe(nb, [(0.04, 1.0), (0.05, 1.04), (0.12, 1.1), (0.135, 1.18), (0.13, 1.28), (0.135, 1.36), (0.12, 1.44), (0.06, 1.49), (0.04, 1.52)], seg=24)
    cyl(p.bm("NapXanh"), (0, 0, 1.53), 0.042, 0.03, seg=16)
    done(p)


# ================================================================== MÁY PHOTOCOPY
def may_in():
    p = Prop("may_in")
    a = p.bm("NhuaTrang", bevel=0.01)
    box(a, (0, 0, 0.3), (0.62, 0.6, 0.6))
    box(a, (0, 0.02, 0.8), (0.6, 0.56, 0.36))
    x = p.bm("NhuaXam", bevel=0.008)
    for z in (0.12, 0.3, 0.48):
        box(x, (0, -0.302, z), (0.56, 0.01, 0.15))
    box(x, (0, 0.02, 1.0), (0.6, 0.54, 0.05))           # nắp scan
    box(x, (0.2, -0.27, 0.96), (0.22, 0.14, 0.04), rot=(math.radians(20), 0, 0))  # bảng điều khiển
    box(p.bm("ManHinh"), (0.17, -0.3, 0.97), (0.1, 0.01, 0.06), rot=(math.radians(20), 0, 0))
    box(p.bm("Giay"), (-0.36, 0.0, 0.78), (0.12, 0.3, 0.015))  # khay giấy ra
    box(x, (-0.33, 0.0, 0.76), (0.08, 0.34, 0.02))
    nd = p.bm("NhuaDen")
    for sx in (-0.27, 0.27):
        for sy in (-0.26, 0.26):
            cyl(nd, (sx, sy, 0.015), 0.025, 0.03, seg=8)
    done(p)


# ================================================================== ĐIỀU HÒA TREO TƯỜNG
def dieu_hoa():
    p = Prop("dieu_hoa")
    t = p.bm("NhuaTrang", bevel=0.035)
    box(t, (0, 0, 0), (0.86, 0.22, 0.29))
    x = p.bm("NhuaXam", bevel=0.004)
    box(x, (0, -0.07, -0.135), (0.74, 0.08, 0.03), rot=(math.radians(-25), 0, 0))
    box(p.bm("DenXanh"), (0.28, -0.112, -0.03), (0.04, 0.004, 0.012))
    done(p)


# ================================================================== BẢNG TRẮNG + ĐỒNG HỒ
def bang_trang():
    p = Prop("bang_trang")
    al = p.bm("Nhom", bevel=0.004)
    W, H = 1.8, 0.95
    box(p.bm("BiaTrang"), (0, 0.01, 0), (W, 0.015, H))
    f = p.bm("BangTrang", ang=5)
    quad_uv(f, [(-W / 2 + 0.02, -0.0, -H / 2 + 0.02), (W / 2 - 0.02, -0.0, -H / 2 + 0.02), (W / 2 - 0.02, -0.0, H / 2 - 0.02), (-W / 2 + 0.02, -0.0, H / 2 - 0.02)])
    for z in (-H / 2, H / 2):
        box(al, (0, -0.005, z), (W + 0.02, 0.025, 0.025))
    for xx in (-W / 2, W / 2):
        box(al, (xx, -0.005, 0), (0.025, 0.025, H + 0.02))
    box(al, (0, -0.04, -H / 2 - 0.02), (W * 0.6, 0.07, 0.015))
    box(p.bm("VoiXanh"), (0.1, -0.04, -H / 2 - 0.006), (0.13, 0.016, 0.016), rot=(0, 0, 0.1))
    box(p.bm("NhuaDen"), (0.3, -0.04, -H / 2 - 0.006), (0.13, 0.016, 0.016), rot=(0, 0, -0.05))
    done(p)
    q = Prop("dong_ho")
    cyl(q.bm("NhuaDen", bevel=0.006), (0, 0.02, 0), 0.165, 0.045, seg=36, rot=(math.pi / 2, 0, 0))
    f = q.bm("MatDongHo", ang=5)
    ul = f.loops.layers.uv.verify()
    vs = [f.verts.new((0.15 * math.cos(2 * math.pi * k / 36), -0.003, 0.15 * math.sin(2 * math.pi * k / 36))) for k in range(36)]
    face = f.faces.new(list(reversed(vs)))
    for lp in face.loops:
        lp[ul].uv = (0.5 + lp.vert.co.x / 0.3, 0.5 + lp.vert.co.z / 0.3)
    done(q)


# ================================================================== CHẬU LƯỠI HỔ
def chau_cay():
    p = Prop("chau_cay")
    c = p.bm("ChauCay", ang=50)
    lathe(c, [(0.13, 0.0), (0.155, 0.03), (0.17, 0.36), (0.16, 0.37), (0.15, 0.34)], seg=28, cap_top=False)
    cyl(p.bm("Dat"), (0, 0, 0.33), 0.155, 0.01, seg=24)
    for i in range(11):
        a = R.uniform(0, 2 * math.pi)
        rr = R.uniform(0.0, 0.08)
        base = Vector((math.cos(a) * rr, math.sin(a) * rr, 0.32))
        lean = Vector((math.cos(a), math.sin(a), 0)) * R.uniform(0.03, 0.14)
        L = R.uniform(0.55, 0.95)
        pts = [base + lean * (t * t) + Vector((0, 0, L * t)) for t in (0, 0.25, 0.5, 0.75, 0.93, 1.0)]
        wid = R.uniform(0.028, 0.04)
        rads = [(wid * 0.7, 0.006), (wid, 0.007), (wid, 0.006), (wid * 0.8, 0.005), (wid * 0.4, 0.004), (0.002, 0.002)]
        ref = (math.cos(a + 1.3), math.sin(a + 1.3), 0)
        tube(p.bm("LaCay" if i % 4 else "LaCayVang", ang=180), pts, rads, ref=ref, seg=8)
    done(p)


# ================================================================== ĐỒ TRÊN BÀN
def do_tren_ban():
    p = Prop("do_tren_ban_1")
    g = p.bm("Giay", bevel=0.001)
    for i in range(6):
        box(g, (R.uniform(-0.01, 0.01), R.uniform(-0.01, 0.01), 0.752 + i * 0.006), (0.21, 0.297, 0.005), rot=(0, 0, R.uniform(-0.12, 0.12)))
    box(p.bm("BiaXanh", bevel=0.002), (0.0, 0.0, 0.79), (0.23, 0.31, 0.012), rot=(0, 0, 0.18))
    c = p.bm("CocSu", ang=50)
    lathe(c, [(0.0, 0.75), (0.036, 0.75), (0.04, 0.85), (0.035, 0.85), (0.032, 0.76), (0.0, 0.76)], seg=20, cap_bottom=False, cap_top=False)
    for v in c.verts:
        v.co.x += 0.2; v.co.y += 0.12
    tube(p.bm("CocSu", ang=180), [(0.24, 0.12, 0.83), (0.258, 0.12, 0.815), (0.258, 0.12, 0.785), (0.24, 0.12, 0.775)], [0.007] * 4, ref=(0, 1, 0), seg=8, caps=False)
    box(p.bm("VoMay", bevel=0.004), (-0.2, 0.15, 0.755), (0.07, 0.15, 0.01), rot=(0, 0, 0.3))
    done(p)
    q = Prop("do_tren_ban_2")
    x = -0.12
    for m in ("BiaDo", "BiaXanh", "BiaVang", "BiaXanh", "BiaTrang"):
        t = R.choice([0.04, 0.05, 0.06])
        box(q.bm(m, bevel=0.002), (x + t / 2, 0.1, 0.75 + 0.15), (t, 0.25, 0.3))
        x += t + 0.002
    cyl(q.bm("NhuaDen", ang=50), (0.12, 0.15, 0.8), 0.04, 0.1, seg=16)
    for i in range(4):
        box(q.bm(R.choice(["VoiXanh", "VoiDo", "NhuaDen"])), (0.12 + R.uniform(-0.02, 0.02), 0.15 + R.uniform(-0.02, 0.02), 0.87), (0.008, 0.008, 0.14), rot=(R.uniform(-0.15, 0.15), R.uniform(-0.15, 0.15), 0))
    g2 = q.bm("Giay", bevel=0.001)
    for i in range(3):
        box(g2, (-0.1, -0.1, 0.752 + i * 0.005), (0.297, 0.21, 0.004), rot=(0, 0, R.uniform(-0.3, 0.3)))
    done(q)


# ================================================================== VỎ PHÒNG 12 x 9 x 3 (cửa sổ phía +Y, cửa ra vào phía -Y)
RW, RD, RH = 12.0, 9.0, 3.0
WIN_X = (-3.6, 0.0, 3.6)
WIN_W, SILL, WTOP = 2.2, 0.85, 2.45
DOOR_X, DOOR_W, DOOR_H = 0.0, 1.0, 2.1


def phong_vo():
    p = Prop("phong_vo")
    T = 0.15
    w = p.bm("TuongSon")
    # tường cửa sổ (Blender +Y)
    y = RD / 2 + T / 2
    box(w, (0, y, SILL / 2), (RW + 2 * T, T, SILL))
    box(w, (0, y, (WTOP + RH) / 2), (RW + 2 * T, T, RH - WTOP))
    edges = [-RW / 2 - T] + [v for x in WIN_X for v in (x - WIN_W / 2, x + WIN_W / 2)] + [RW / 2 + T]
    for i in range(0, len(edges), 2):
        a, b_ = edges[i], edges[i + 1]
        box(w, ((a + b_) / 2, y, (SILL + WTOP) / 2), (b_ - a, T, WTOP - SILL))
    # tường cửa ra vào (Blender -Y)
    y2 = -RD / 2 - T / 2
    l0, l1 = DOOR_X - DOOR_W / 2, DOOR_X + DOOR_W / 2
    box(w, ((-RW / 2 - T + l0) / 2, y2, RH / 2), (l0 + RW / 2 + T, T, RH))
    box(w, ((RW / 2 + T + l1) / 2, y2, RH / 2), (RW / 2 + T - l1, T, RH))
    box(w, (DOOR_X, y2, (DOOR_H + RH) / 2), (DOOR_W, T, RH - DOOR_H))
    # hai tường bên
    for sx in (-1, 1):
        box(w, (sx * (RW / 2 + T / 2), 0, RH / 2), (T, RD, RH))
    # chân tường
    ct = p.bm("ChanTuong", bevel=0.003)
    for sx in (-1, 1):
        box(ct, (sx * (RW / 2 - 0.006), 0, 0.05), (0.012, RD, 0.1))
    box(ct, (0, RD / 2 - 0.006, 0.05), (RW, 0.012, 0.1))
    box(ct, ((-RW / 2 + l0) / 2, -RD / 2 + 0.006, 0.05), (l0 + RW / 2, 0.012, 0.1))
    box(ct, ((RW / 2 + l1) / 2, -RD / 2 + 0.006, 0.05), (RW / 2 - l1, 0.012, 0.1))
    # khung cửa sổ nhôm, kính, bậu, rèm lá
    al = p.bm("Nhom", bevel=0.003)
    kg = p.bm("KinhCuaSo", ang=5)
    bc = p.bm("NhuaTrang", bevel=0.004)
    rm = p.bm("ReManh", bevel=0.0)
    for x in WIN_X:
        yy = RD / 2 + 0.07
        box(kg, (x, yy, (SILL + WTOP) / 2), (WIN_W, 0.006, WTOP - SILL))
        for zz in (SILL + 0.025, WTOP - 0.025):
            box(al, (x, yy, zz), (WIN_W, 0.07, 0.05))
        for xx in (x - WIN_W / 2 + 0.025, x, x + WIN_W / 2 - 0.025):
            box(al, (xx, yy, (SILL + WTOP) / 2), (0.05 if xx != x else 0.04, 0.07, WTOP - SILL))
        box(bc, (x, RD / 2 - 0.03, SILL - 0.01), (WIN_W + 0.1, 0.16, 0.025))
        # rèm lá: kéo xuống quá nửa, lá nghiêng
        low = R.uniform(1.35, 1.8)
        z = WTOP - 0.06
        while z > low:
            box(rm, (x, RD / 2 - 0.05, z), (WIN_W - 0.06, 0.05, 0.003), rot=(math.radians(32), 0, 0))
            z -= 0.042
        box(rm, (x, RD / 2 - 0.05, WTOP - 0.03), (WIN_W - 0.02, 0.06, 0.04))
        box(al, (x, RD / 2 - 0.05, low - 0.01), (WIN_W - 0.06, 0.05, 0.012))
    # khung cửa ra vào
    cg = p.bm("CuaGo", bevel=0.004)
    for xx in (l0 - 0.035, l1 + 0.035):
        box(cg, (xx, -RD / 2 + 0.02, DOOR_H / 2), (0.07, 0.19, DOOR_H))
    box(cg, (DOOR_X, -RD / 2 + 0.02, DOOR_H + 0.035), (DOOR_W + 0.14, 0.19, 0.07))
    done(p)

    # cánh cửa: bản lề ở gốc toạ độ, cánh chạy theo +X
    q = Prop("cua_ra_vao")
    L = DOOR_W - 0.02
    cg = q.bm("CuaGo", bevel=0.004)
    box(cg, (L / 2, 0, DOOR_H / 2 - 0.005), (L, 0.04, DOOR_H - 0.01))
    box(q.bm("Kinh", ang=5), (L / 2 + 0.12, 0, 1.45), (0.16, 0.046, 0.7))
    hk = q.bm("Nhom", bevel=0.003)
    for sy in (-1, 1):
        box(hk, (L - 0.08, sy * 0.045, 1.0), (0.03, 0.03, 0.06))
        box(hk, (L - 0.15, sy * 0.065, 1.0), (0.14, 0.02, 0.02))
    done(q)

    # trần thạch cao: tấm 60 x 60, khung T, đèn LED âm trần
    t = Prop("tran")
    tr = t.bm("TranThach", ang=5)
    quad_uv(tr, [(-RW / 2, RD / 2, RH), (RW / 2, RD / 2, RH), (RW / 2, -RD / 2, RH), (-RW / 2, -RD / 2, RH)],
            uvs=((0, 0), (RW / 0.6, 0), (RW / 0.6, RD / 0.6), (0, RD / 0.6)))
    tb = t.bm("NhuaTrang")
    for i in range(1, int(RW / 0.6)):
        box(tb, (-RW / 2 + i * 0.6, 0, RH - 0.006), (0.022, RD, 0.012))
    for j in range(1, int(RD / 0.6)):
        box(tb, (0, -RD / 2 + j * 0.6, RH - 0.006), (RW, 0.022, 0.012))
    led = t.bm("DenLED", ang=5)
    fr = t.bm("Nhom")
    for i in range(int(RW / 0.6)):
        for j in range(int(RD / 0.6)):
            if i % 4 == 1 and j % 3 == 1:
                cx, cy = -RW / 2 + i * 0.6 + 0.3, -RD / 2 + j * 0.6 + 0.3
                box(led, (cx, cy, RH - 0.012), (0.56, 0.56, 0.01))
                box(fr, (cx, cy, RH - 0.008), (0.6, 0.6, 0.008))
                LEDS.append((cx, cy))
    done(t)

    # cảnh phố ngoài cửa sổ (texture gắn trong Godot)
    c = Prop("canh_ngoai")
    quad_uv(c.bm("CanhNgoai", ang=5), [(-16, RD / 2 + 7, -4), (16, RD / 2 + 7, -4), (16, RD / 2 + 7, 10), (-16, RD / 2 + 7, 10)])
    done(c)


LEDS = []


# ================================================================== NGƯỜI
def _head(p, c, female=False, hair_style="ngan", toc="Toc", kinh=False):
    c = Vector(c)
    da = p.bm("Da", sub=1, ang=180)
    ell(da, c, (0.08, 0.095, 0.11), seg=20, rings=14)
    ell(da, c + Vector((0, 0.016, -0.05)), (0.063, 0.066, 0.056), seg=16, rings=10)    # cằm, má
    ell(da, c + Vector((0, 0.092, 0.0)), (0.011, 0.015, 0.02), seg=10, rings=6, rot=(0.3, 0, 0))  # mũi
    for sx in (-1, 1):
        ell(da, c + Vector((sx * 0.08, -0.005, -0.004)), (0.012, 0.022, 0.03), seg=10, rings=6)  # tai
        ell(p.bm("MatNguoi", ang=180), c + Vector((sx * 0.031, 0.083, 0.018)), (0.011, 0.007, 0.0075), seg=10, rings=6)
        box(p.bm(toc, ang=60), c + Vector((sx * 0.032, 0.088, 0.04)), (0.03, 0.008, 0.006 if not female else 0.004), rot=(0, sx * -0.12, 0))
    ell(p.bm("Moi", ang=180), c + Vector((0, 0.08, -0.045)), (0.017, 0.007, 0.005), seg=10, rings=6)
    # tóc: vỏ cầu cắt theo chân tóc, làm dày bằng solidify
    dst = p.bm(toc, sub=1, solid=0.012, ang=180)
    vs = ell(dst, (0, 0, 0), (1, 1, 1), seg=24, rings=16)
    kill = []
    for v in vs:
        x, y, z = v.co
        # chân tóc: trán cao ở phía trước, phủ tai và gáy ở hai bên / phía sau
        if female:
            front, side, back = 0.42, -0.62, -0.95
        else:
            front, side, back = 0.36, -0.12, -0.55
        if y > 0.55:
            lim = front - 0.25 * abs(x) - (0.3 * x if female else 0.0)   # rẽ ngôi lệch
        elif y > -0.35:
            t = (y + 0.35) / 0.9
            lim = side + (front - side) * t * t
        else:
            lim = back
        if z < lim:
            kill.append(v)
        elif hair_style == "hoi" and z > 0.38 and y > -0.55:
            kill.append(v)   # hói đỉnh, còn tóc hai bên và sau gáy
    keep = [v for v in vs if v not in set(kill)]
    bmesh.ops.delete(dst, geom=kill, context='VERTS')
    sc = (0.087, 0.104, 0.119) if not female else (0.088, 0.104, 0.12)
    bmesh.ops.transform(dst, matrix=Matrix.Translation(c + Vector((0, -0.004, 0.006))) @ Matrix.Diagonal((*sc, 1.0)), verts=keep)
    if kinh:
        gk = p.bm("GongKinh", ang=40)
        for sx in (-1, 1):
            cx = c + Vector((sx * 0.032, 0.1, 0.017))
            for dz in (-0.014, 0.014):
                box(gk, cx + Vector((0, 0, dz)), (0.036, 0.004, 0.003))
            for dx in (-0.018, 0.018):
                box(gk, cx + Vector((dx, 0, 0)), (0.003, 0.004, 0.03))
            box(gk, c + Vector((sx * 0.07, 0.045, 0.022)), (0.003, 0.11, 0.004), rot=(0.05, 0, sx * 0.12))
        box(gk, c + Vector((0, 0.102, 0.022)), (0.03, 0.004, 0.003))
        box(p.bm("KinhMat", ang=5), c + Vector((-0.032, 0.1, 0.017)), (0.034, 0.002, 0.026))
        box(p.bm("KinhMat", ang=5), c + Vector((0.032, 0.1, 0.017)), (0.034, 0.002, 0.026))
    if hair_style == "dai":
        tb = p.bm(toc, sub=1, ang=180)
        tube(tb, [c + Vector((0, -0.05, 0.06)), c + Vector((0, -0.09, -0.06)), c + Vector((0, -0.095, -0.2)), c + Vector((0, -0.085, -0.33))],
             [(0.086, 0.05), (0.095, 0.045), (0.095, 0.035), (0.085, 0.022)], ref=(1, 0, 0), seg=12)
        for sx in (-1, 1):   # hai dải tóc trước vai
            tube(tb, [c + Vector((sx * 0.078, 0.0, 0.02)), c + Vector((sx * 0.088, -0.01, -0.1)), c + Vector((sx * 0.095, -0.025, -0.22))],
                 [(0.025, 0.035), (0.027, 0.04), (0.02, 0.03)], ref=(0, 1, 0), seg=10)
    elif hair_style == "duoi_ngua":
        tube(p.bm("Toc", sub=1, ang=180), [c + Vector((0, -0.1, 0.03)), c + Vector((0, -0.13, -0.04)), c + Vector((0, -0.125, -0.15)), c + Vector((0, -0.11, -0.25))],
             [0.03, 0.032, 0.026, 0.012], ref=(1, 0, 0), seg=10)
        cyl(p.bm("BiaDen"), c + Vector((0, -0.098, 0.035)), 0.022, 0.018, seg=12, rot=(1.3, 0, 0))


def _collar(p, c, tilt, r):
    """cổ áo sơ mi: hai vạt bẻ ra hai bên quanh chân cổ"""
    c = Vector(c)
    b = p.bm("Ao", sub=1, ang=180)
    for sx in (-1, 1):
        pts = [c + Vector((sx * r * math.sin(a), r * math.cos(a) * 0.9, 0.012 - 0.01 * (a / math.pi))) for a in (0.15, 0.9, 1.7, 2.6)]
        tube(b, pts, [(0.012, 0.03), (0.013, 0.032), (0.013, 0.03), (0.012, 0.026)], ref=(0, 0, 1), seg=8)


def nguoi_ngoi(name, female):
    p = Prop(name)
    k = 0.93 if female else 1.0
    ao = p.bm("Ao", sub=1, ang=180)
    tube(ao, [(0, -0.05, 0.64), (0, -0.035, 0.76), (0, -0.02, 0.9), (0, 0.0, 1.0), (0, 0.01, 1.08), (0, 0.03, 1.135)],
         [(0.16 * k, 0.115), (0.145 * k, 0.1), (0.15 * k, 0.105), (0.168 * k, 0.11), (0.172 * k, 0.095), (0.1 * k, 0.065)], ref=(1, 0, 0), seg=16)
    _collar(p, (0, 0.035, 1.125), (0, 0.01, 0.0), 0.06 * k)
    for z, y in ((1.07, 0.1), (0.985, 0.105), (0.9, 0.08), (0.815, 0.066)):
        ell(p.bm("CucAo", ang=180), (0, y, z), (0.007, 0.004, 0.007), seg=8, rings=5)
    for sx in (-1, 1):
        ell(ao, (sx * 0.165 * k, 0.0, 1.07), (0.065, 0.065, 0.06), seg=12, rings=8)
        tube(ao, [(sx * 0.185 * k, 0.0, 1.07), (sx * 0.197 * k, 0.08, 0.97), (sx * 0.205 * k, 0.16, 0.87)], [0.056, 0.05, 0.046], ref=(0, 1, 0), seg=12)
    q = p.bm("Quan", sub=1, ang=180)
    ell(q, (0, -0.03, 0.585), (0.172 * k, 0.15, 0.1), seg=16, rings=10)
    for sx in (-1, 1):
        x0 = sx * 0.095 * k
        tube(q, [(x0, -0.02, 0.58), (sx * 0.1, 0.18, 0.575), (sx * 0.108, 0.37, 0.565), (sx * 0.112, 0.43, 0.5), (sx * 0.114, 0.45, 0.3), (sx * 0.115, 0.45, 0.12)],
             [0.088 * k, 0.078 * k, 0.062, 0.058, 0.05, 0.042], ref=(1, 0, 0), seg=14)
        ell(p.bm("GiayDa", sub=1, ang=180), (sx * 0.115, 0.5, 0.045), (0.046, 0.12, 0.042), seg=14, rings=8)
    tube(p.bm("Da", sub=1, ang=180), [(0, 0.035, 1.11), (0, 0.06, 1.24)], [0.047 * k, 0.045 * k], ref=(1, 0, 0), seg=12)
    _head(p, (0, 0.075, 1.33), female, "dai" if female else "ngan")
    done(p)


def cang_tay(name, sx):
    """cẳng tay + bàn tay đang gõ phím, gốc = khuỷu tay. sx = 1 tay phải, -1 tay trái"""
    p = Prop(name)
    da = p.bm("Da", sub=1, ang=180)
    tube(da, [(0, 0, 0), (sx * -0.04, 0.18, -0.04), (sx * -0.072, 0.35, -0.072)], [0.043, 0.038, 0.03], ref=(1, 0, 0), seg=12)
    ell(da, (sx * -0.083, 0.415, -0.083), (0.043, 0.06, 0.017), seg=14, rings=8, rot=(0.18, 0, sx * 0.15))
    ell(da, (sx * -0.05, 0.39, -0.075), (0.014, 0.035, 0.013), seg=10, rings=6, rot=(0.3, 0, sx * 0.6))   # ngón cái
    tube(p.bm("Ao", sub=1, ang=180), [(0, -0.03, 0.005), (sx * -0.012, 0.055, -0.007)], [0.052, 0.049], ref=(1, 0, 0), seg=12)
    done(p)


def linh():
    """Linh đứng: thân, 2 chân (gốc ở hông), 2 tay (gốc ở vai). Mặt quay về +Y."""
    p = Prop("linh_than")
    ao = p.bm("Ao", sub=1, ang=180)
    tube(ao, [(0, 0, 0.92), (0, 0, 1.03), (0, 0.005, 1.13), (0, 0.01, 1.24), (0, 0, 1.33), (0, 0, 1.385)],
         [(0.145, 0.1), (0.122, 0.085), (0.13, 0.092), (0.146, 0.1), (0.158, 0.085), (0.09, 0.06)], ref=(1, 0, 0), seg=16)
    for sx in (-1, 1):
        ell(ao, (sx * 0.15, 0.0, 1.33), (0.058, 0.058, 0.055), seg=12, rings=8)
    _collar(p, (0, 0.0, 1.375), (0, 0.0, 0.0), 0.055)
    for z, y in ((1.31, 0.086), (1.22, 0.102), (1.13, 0.092), (1.04, 0.08)):
        ell(p.bm("CucAo", ang=180), (0, y, z), (0.006, 0.004, 0.006), seg=8, rings=5)
    ell(p.bm("Quan", sub=1, ang=180), (0, 0, 0.9), (0.16, 0.11, 0.1), seg=16, rings=10)
    tube(p.bm("Da", sub=1, ang=180), [(0, 0.0, 1.36), (0, 0.012, 1.465)], [0.042, 0.04], ref=(1, 0, 0), seg=12)
    _head(p, (0, 0.02, 1.55), True, "dai")
    done(p)
    for sx, nm in ((-1, "linh_chan_trai"), (1, "linh_chan_phai")):
        q = Prop(nm)
        tube(q.bm("Quan", sub=1, ang=180), [(0, 0, 0.03), (0, 0.0, -0.2), (sx * 0.004, 0.0, -0.41), (sx * 0.006, -0.006, -0.62), (sx * 0.006, -0.01, -0.81)],
             [0.082, 0.07, 0.054, 0.045, 0.036], ref=(1, 0, 0), seg=14)
        ell(q.bm("GiayDa", sub=1, ang=180), (sx * 0.006, 0.035, -0.86), (0.04, 0.105, 0.035), seg=14, rings=8)
        done(q)
    for sx, nm in ((-1, "linh_tay_trai"), (1, "linh_tay_phai")):
        q = Prop(nm)
        tube(q.bm("Ao", sub=1, ang=180), [(0, 0, 0), (sx * 0.018, 0, -0.14), (sx * 0.028, 0.0, -0.26), (sx * 0.032, 0.02, -0.4), (sx * 0.034, 0.03, -0.49)],
             [0.047, 0.043, 0.038, 0.033, 0.03], ref=(0, 1, 0), seg=12)
        da = q.bm("Da", sub=1, ang=180)
        ell(da, (sx * 0.035, 0.035, -0.565), (0.018, 0.038, 0.062), seg=12, rings=8)
        tube(da, [(sx * 0.034, 0.03, -0.48), (sx * 0.035, 0.033, -0.52)], [0.026, 0.024], ref=(0, 1, 0), seg=10)
        done(q)


# ================================================================== chạy
if not globals().get("VP_NO_RUN", False):
    ban_lam_viec(); ghe_xoay(); tu_sat(); tu_ho_so(); cay_nuoc(); may_in(); dieu_hoa(); bang_trang(); chau_cay(); do_tren_ban()
    phong_vo()
    nguoi_ngoi("nguoi_ngoi_nam", False)
    nguoi_ngoi("nguoi_ngoi_nu", True)
    cang_tay("cang_tay_phai", 1)
    cang_tay("cang_tay_trai", -1)
    linh()
    clear_scene(SC)
    if _WIN and _OLD_SC:
        _WIN.scene = _OLD_SC
    result = {"log": LOG, "leds": len(LEDS)}
