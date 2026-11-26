# -*- coding: utf-8 -*-
# Phòng giám đốc cho intro "60 Ngày" (chạy trong Blender, sau no60_lib.py).
# Dùng lại các hàm dựng hình của van_phong.py:
#   exec(LIB); VP_NO_RUN = True; OUT = ".../models/phong_giam_doc"; exec(van_phong.py); exec(phong_giam_doc.py)
# Quy ước giống van_phong.py: mặt trước đồ vật quay về -Y (Godot +Z); người ngồi quay mặt về +Y.
# Phòng 8 x 6 x 3 m. Trong Godot: cửa sổ ở tường +X, cửa ra vào ở tường +Z (Blender -Y), tủ sách ở tường -Z.
import bpy, bmesh, math, random
from mathutils import Vector, Matrix, Euler

R = random.Random(77)
M.update({
    "GoOc": mat("GoOc", (0.11, 0.05, 0.025), 0.4),
    "GoSang": mat("GoSang", (0.42, 0.26, 0.13), 0.45),
    "Dong": mat("Dong", (0.75, 0.52, 0.2), 0.3, 0.9),
    "Inox": mat("Inox", (0.8, 0.8, 0.82), 0.2, 1.0),
    "DaBo": mat("DaBo", (0.012, 0.01, 0.009), 0.35),
    "DaNau": mat("DaNau", (0.16, 0.06, 0.025), 0.4),
    "TuongKem": mat("TuongKem", (0.62, 0.55, 0.44), 0.9),
    "TranTrang": mat("TranTrang", (0.8, 0.79, 0.76), 0.9),
    "ReVai": mat("ReVai", (0.55, 0.45, 0.32), 0.9),
    "ReVoan": mat("ReVoan", (0.85, 0.84, 0.8), 0.9, 0.0, 0.55),
    "KhungDen": mat("KhungDen", (0.03, 0.03, 0.03), 0.4, 0.4),
    "TranhSonThuy": mat("TranhSonThuy", (0.8, 0.78, 0.7), 0.6),
    "BangTen": mat("BangTen", (0.02, 0.02, 0.02), 0.3),
    "BangKhen": mat("BangKhen", (0.85, 0.8, 0.6), 0.5),
    "ThamTrai": mat("ThamTrai", (0.3, 0.1, 0.06), 0.95),
    "SuNau": mat("SuNau", (0.25, 0.1, 0.04), 0.15),
    "SuTrangBong": mat("SuTrangBong", (0.85, 0.85, 0.82), 0.1),
    "VoCay": mat("VoCay", (0.25, 0.2, 0.12), 0.8),
    "BuomVang": mat("BuomVang", (0.7, 0.5, 0.15), 0.35, 0.8),
    "AoVest": mat("AoVest", (0.025, 0.03, 0.055), 0.75),
    "CaVat": mat("CaVat", (0.3, 0.03, 0.04), 0.5),
    "SachDo": mat("SachDo", (0.35, 0.05, 0.04), 0.6),
    "SachXanh": mat("SachXanh", (0.04, 0.12, 0.25), 0.6),
    "SachNau": mat("SachNau", (0.25, 0.14, 0.06), 0.6),
    "SachKem": mat("SachKem", (0.7, 0.62, 0.48), 0.6),
})
W, D, H = 8.0, 6.0, 3.0
WIN_Y0, WIN_Y1, WIN_Z0, WIN_Z1 = -1.6, 1.4, 0.55, 2.55      # cửa sổ tường +X (toạ độ Blender)
DOOR_X, DOOR_W, DOOR_H = 2.6, 1.0, 2.15                      # cửa ra vào tường -Y


# ================================================================== VỎ PHÒNG
def bgd_phong():
    p = Prop("bgd_phong")
    T = 0.15
    w = p.bm("TuongKem")
    box(w, (0, D / 2 + T / 2, H / 2), (W + 2 * T, T, H))                       # tường sau (tủ sách)
    l0, l1 = DOOR_X - DOOR_W / 2, DOOR_X + DOOR_W / 2
    y = -D / 2 - T / 2
    box(w, ((-W / 2 - T + l0) / 2, y, H / 2), (l0 + W / 2 + T, T, H))
    box(w, ((W / 2 + T + l1) / 2, y, H / 2), (W / 2 + T - l1, T, H))
    box(w, (DOOR_X, y, (DOOR_H + H) / 2), (DOOR_W, T, H - DOOR_H))
    box(w, (-W / 2 - T / 2, 0, H / 2), (T, D, H))                               # tường trái (sofa)
    x = W / 2 + T / 2                                                            # tường phải: cửa sổ lớn
    box(w, (x, 0, WIN_Z0 / 2), (T, D, WIN_Z0))
    box(w, (x, 0, (WIN_Z1 + H) / 2), (T, D, H - WIN_Z1))
    box(w, (x, (-D / 2 + WIN_Y0) / 2, (WIN_Z0 + WIN_Z1) / 2), (T, WIN_Y0 + D / 2, WIN_Z1 - WIN_Z0))
    box(w, (x, (D / 2 + WIN_Y1) / 2, (WIN_Z0 + WIN_Z1) / 2), (T, D / 2 - WIN_Y1, WIN_Z1 - WIN_Z0))
    # chân tường gỗ
    g = p.bm("GoOc", bevel=0.003)
    box(g, (0, D / 2 - 0.01, 0.06), (W, 0.02, 0.12))
    box(g, (-W / 2 + 0.01, 0, 0.06), (0.02, D, 0.12))
    box(g, (W / 2 - 0.01, 0, 0.06), (0.02, D, 0.12))
    box(g, ((-W / 2 + l0) / 2, -D / 2 + 0.01, 0.06), (l0 + W / 2, 0.02, 0.12))
    box(g, ((W / 2 + l1) / 2, -D / 2 + 0.01, 0.06), (W / 2 - l1, 0.02, 0.12))
    # mảng ốp gỗ nan dọc sau lưng bàn giám đốc, tranh sơn thủy ở giữa
    x = -1.25
    while x < 1.25:
        box(g, (x + 0.03, D / 2 - 0.03, 1.38), (0.05, 0.04, 2.76))
        x += 0.07
    box(g, (0, D / 2 - 0.05, 2.79), (2.6, 0.08, 0.06))
    box(p.bm("Dong", bevel=0.002), (0, D / 2 - 0.055, 2.75), (2.5, 0.01, 0.012))
    kt = p.bm("Dong", bevel=0.004)
    TW, TH, TZ = 1.5, 0.78, 1.85
    for zz in (TZ - TH / 2 - 0.025, TZ + TH / 2 + 0.025):
        box(kt, (0, D / 2 - 0.075, zz), (TW + 0.1, 0.035, 0.05))
    for xx in (-TW / 2 - 0.025, TW / 2 + 0.025):
        box(kt, (xx, D / 2 - 0.075, TZ), (0.05, 0.035, TH + 0.1))
    quad_uv(p.bm("TranhSonThuy", ang=5), [(-TW / 2, D / 2 - 0.07, TZ - TH / 2), (TW / 2, D / 2 - 0.07, TZ - TH / 2), (TW / 2, D / 2 - 0.07, TZ + TH / 2), (-TW / 2, D / 2 - 0.07, TZ + TH / 2)])
    # cửa sổ: khung đen, kính, rèm vải hai bên + rèm voan giữa
    kd = p.bm("KhungDen", bevel=0.003)
    kg = p.bm("KinhCuaSo", ang=5)
    xw = W / 2 + 0.07
    box(kg, (xw, (WIN_Y0 + WIN_Y1) / 2, (WIN_Z0 + WIN_Z1) / 2), (0.006, WIN_Y1 - WIN_Y0, WIN_Z1 - WIN_Z0))
    for zz in (WIN_Z0 + 0.025, WIN_Z1 - 0.025, (WIN_Z0 + WIN_Z1) / 2 + 0.3):
        box(kd, (xw, (WIN_Y0 + WIN_Y1) / 2, zz), (0.07, WIN_Y1 - WIN_Y0, 0.05))
    for yy in (WIN_Y0 + 0.025, WIN_Y1 - 0.025, (WIN_Y0 + WIN_Y1) / 2):
        box(kd, (xw, yy, (WIN_Z0 + WIN_Z1) / 2), (0.07, 0.05, WIN_Z1 - WIN_Z0))
    box(p.bm("TuongKem"), (W / 2 - 0.08, (WIN_Y0 + WIN_Y1) / 2, WIN_Z0 - 0.015), (0.2, WIN_Y1 - WIN_Y0 + 0.1, 0.03))
    cyl(p.bm("Dong"), (W / 2 - 0.15, (WIN_Y0 + WIN_Y1) / 2, 2.72), 0.014, WIN_Y1 - WIN_Y0 + 1.4, seg=12, rot=(math.pi / 2, 0, 0))
    rv = p.bm("ReVai", sub=1, ang=180)
    for side, y0 in ((-1, WIN_Y0 - 0.55), (1, WIN_Y1 + 0.05)):
        b = bmesh.new()
        n = 11
        rows = []
        for j, z in enumerate((0.04, 0.9, 1.8, 2.7)):
            rows.append([rv.verts.new((W / 2 - 0.16 + 0.04 * math.sin(i * math.pi / 2), y0 + i * 0.05, z)) for i in range(n)])
        for j in range(len(rows) - 1):
            for i in range(n - 1):
                rv.faces.new([rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]])
        b.free()
    vo = p.bm("ReVoan", ang=5)
    n = int((WIN_Y1 - WIN_Y0) / 0.04)
    for i in range(n):
        yy = WIN_Y0 + i * 0.04
        for zz0, zz1 in ((0.04, 2.7),):
            pass
    rows = []
    for z in (0.05, 2.7):
        rows.append([vo.verts.new((W / 2 - 0.12 + 0.02 * math.sin(i * 1.3), WIN_Y0 + i * (WIN_Y1 - WIN_Y0) / (n - 1), z)) for i in range(n)])
    for i in range(n - 1):
        vo.faces.new([rows[0][i], rows[0][i + 1], rows[1][i + 1], rows[1][i]])
    # trần: viền hạ trần, khe đèn hắt, đèn âm trần tròn
    t = p.bm("TranTrang", ang=5)
    quad_uv(t, [(-W / 2, D / 2, H), (W / 2, D / 2, H), (W / 2, -D / 2, H), (-W / 2, -D / 2, H)])
    for xx, ww in ((-W / 2 + 0.3, 0.6), (W / 2 - 0.3, 0.6)):
        box(t, (xx, 0, H - 0.12), (ww, D, 0.24))
    for yy in (D / 2 - 0.3, -D / 2 + 0.3):
        box(t, (0, yy, H - 0.12), (W, 0.6, 0.24))
    led = p.bm("DenLED", ang=5)
    for xx in (-W / 2 + 0.6, W / 2 - 0.6):
        box(led, (xx + (0.01 if xx < 0 else -0.01), 0, H - 0.2), (0.01, D - 1.2, 0.03))
    for yy in (D / 2 - 0.6, -D / 2 + 0.6):
        box(led, (0, yy + (-0.01 if yy > 0 else 0.01), H - 0.2), (W - 1.2, 0.01, 0.03))
    vien = p.bm("Inox")
    for xx in (-W / 2 + 0.3, W / 2 - 0.3):
        for yy in (-1.8, 0.0, 1.8):
            cyl(vien, (xx, yy, H - 0.245), 0.06, 0.01, seg=20)
            cyl(led, (xx, yy, H - 0.252), 0.05, 0.004, seg=20)
    # cửa gỗ, tay nắm đồng
    cg = p.bm("GoOc", bevel=0.004)
    for xx in (l0 - 0.04, l1 + 0.04):
        box(cg, (xx, -D / 2 + 0.03, DOOR_H / 2), (0.08, 0.2, DOOR_H))
    box(cg, (DOOR_X, -D / 2 + 0.03, DOOR_H + 0.04), (DOOR_W + 0.16, 0.2, 0.08))
    box(cg, (DOOR_X, -D / 2 - 0.02, DOOR_H / 2), (DOOR_W - 0.02, 0.05, DOOR_H - 0.01))
    gs = p.bm("GoSang", bevel=0.003)
    for zz in (0.55, 1.55):
        box(gs, (DOOR_X, -D / 2 + 0.008, zz), (DOOR_W - 0.3, 0.012, 0.7))
    dg = p.bm("Dong", bevel=0.003)
    box(dg, (DOOR_X - 0.36, -D / 2 + 0.03, 1.02), (0.03, 0.03, 0.09))
    box(dg, (DOOR_X - 0.3, -D / 2 + 0.06, 1.02), (0.14, 0.02, 0.02))
    # cảnh phố ngoài cửa sổ
    quad_uv(p.bm("CanhNgoai", ang=5), [(W / 2 + 7, -12, -4), (W / 2 + 7, 12, -4), (W / 2 + 7, 12, 9), (W / 2 + 7, -12, 9)])
    done(p)


# ================================================================== BÀN GIÁM ĐỐC (2,2 x 0,95 + cánh phụ chữ L)
def bgd_ban():
    p = Prop("bgd_ban")
    g = p.bm("GoOc", bevel=0.006)
    box(g, (0, 0, 0.735), (2.2, 0.95, 0.05))
    box(g, (0, 0, 0.706), (2.16, 0.91, 0.012))
    box(p.bm("DaBo", bevel=0.004), (0, 0.18, 0.761), (0.72, 0.45, 0.004))
    for sx in (-1, 1):                                                       # hai hộc tủ
        box(g, (sx * 0.82, 0.0, 0.355), (0.52, 0.9, 0.71))
    box(g, (0, -0.43, 0.42), (1.14, 0.04, 0.6))                              # tấm chắn phía khách
    gs = p.bm("GoSang", bevel=0.003)
    box(gs, (0, -0.47, 0.5), (2.22, 0.02, 0.1))
    box(p.bm("Dong", bevel=0.002), (0, -0.482, 0.5), (2.22, 0.006, 0.012))
    for sx in (-1, 1):
        box(gs, (sx * 0.82, -0.452, 0.355), (0.5, 0.012, 0.66))
    dg = p.bm("Dong", bevel=0.002)
    for sx in (-1, 1):
        for i, z in enumerate((0.6, 0.42, 0.18)):
            box(g, (sx * 0.82, 0.453, z), (0.47, 0.01, 0.16 if i < 2 else 0.28))
            box(dg, (sx * 0.82, 0.466, z + (0.03 if i < 2 else 0.09)), (0.16, 0.016, 0.014))
    # cánh phụ chữ L bên phải giám đốc (phía -X)
    box(g, (-1.4, 0.72, 0.355), (0.5, 1.0, 0.71))
    box(g, (-1.4, 0.72, 0.725), (0.54, 1.04, 0.04))
    for z in (0.5, 0.2):
        box(dg, (-1.14, 0.72, z), (0.016, 0.16, 0.014))
    # đồ trên bàn: màn hình (quay về phía giám đốc), bàn phím, điện thoại, biển tên, ống bút, hồ sơ, chén trà, cây cảnh
    vm = p.bm("VoMay", bevel=0.003)
    box(vm, (-0.55, -0.15, 0.764), (0.24, 0.18, 0.008))
    box(vm, (-0.55, -0.17, 0.86), (0.05, 0.025, 0.19))
    box(vm, (-0.55, -0.16, 1.0), (0.6, 0.02, 0.36), rot=(math.radians(6), 0, math.radians(12)))
    mh = p.bm("ManHinh", ang=5)
    rot = Euler((math.radians(6), 0, math.radians(12))).to_matrix()
    cn = [Vector((0.28, 0, -0.165)), Vector((-0.28, 0, -0.165)), Vector((-0.28, 0, 0.165)), Vector((0.28, 0, 0.165))]
    quad_uv(mh, [tuple(Vector((-0.55, -0.16, 1.0)) + rot @ (c + Vector((0, 0.0115, 0)))) for c in cn])
    box(vm, (-0.25, 0.25, 0.768), (0.42, 0.14, 0.012), rot=(0, 0, math.radians(8)))
    nd = p.bm("NhuaDen", bevel=0.004)
    box(nd, (0.62, -0.05, 0.79), (0.2, 0.22, 0.05), rot=(math.radians(-10), 0, math.radians(-15)))
    box(nd, (0.6, -0.08, 0.83), (0.06, 0.2, 0.04), rot=(0, 0, math.radians(-15)))
    # biển tên chữ "GIÁM ĐỐC" quay về phía khách
    bt = p.bm("Dong", bevel=0.002)
    box(bt, (0.1, -0.36, 0.765), (0.3, 0.06, 0.01))
    box(p.bm("GoOc", bevel=0.002), (0.1, -0.35, 0.81), (0.28, 0.02, 0.09), rot=(math.radians(-15), 0, 0))
    rt = Euler((math.radians(-15), 0, 0)).to_matrix()
    cn = [Vector((-0.13, -0.0105, -0.04)), Vector((0.13, -0.0105, -0.04)), Vector((0.13, -0.0105, 0.04)), Vector((-0.13, -0.0105, 0.04))]
    quad_uv(p.bm("BangTen", ang=5), [tuple(Vector((0.1, -0.35, 0.81)) + rt @ c) for c in cn])
    cyl(p.bm("GoSang"), (0.42, -0.25, 0.81), 0.035, 0.1, seg=16)
    for i in range(4):
        cyl(p.bm(R.choice(["NhuaDen", "Dong", "VoiXanh"])), (0.42 + R.uniform(-0.015, 0.015), -0.25 + R.uniform(-0.015, 0.015), 0.88), 0.005, 0.14, seg=6, rot=(R.uniform(-0.2, 0.2), R.uniform(-0.2, 0.2), 0))
    for i, m in enumerate(["BiaXanh", "BiaDo", "BiaXanh", "Giay", "Giay"]):
        box(p.bm(m, bevel=0.002), (0.78, 0.25, 0.765 + i * 0.012), (0.24, 0.32, 0.011), rot=(0, 0, R.uniform(-0.1, 0.1)))
    su = p.bm("SuTrangBong", ang=50)
    lathe(su, [(0.0, 0.762), (0.07, 0.762), (0.075, 0.768), (0.0, 0.768)], seg=24)
    lathe(su, [(0.0, 0.768), (0.025, 0.768), (0.035, 0.8), (0.03, 0.8), (0.0, 0.772)], seg=20, cap_top=False)
    for v in su.verts:
        v.co.x += 0.35; v.co.y += 0.3
    # cây cảnh nhỏ góc bàn
    cp = p.bm("SuNau", ang=50)
    lathe(cp, [(0.05, 0.762), (0.065, 0.78), (0.07, 0.84), (0.0, 0.84)], seg=20)
    for v in cp.verts:
        v.co.x -= 0.95; v.co.y -= 0.3
    for i in range(14):
        a = R.uniform(0, 2 * math.pi); r = R.uniform(0.0, 0.05)
        ell(p.bm("LaCay", sub=1, ang=180), (-0.95 + math.cos(a) * r, -0.3 + math.sin(a) * r, 0.88 + R.uniform(0, 0.08)), (0.035, 0.035, 0.03), seg=8, rings=5)
    done(p)


# ================================================================== GHẾ DA GIÁM ĐỐC (lưng cao) — người ngồi quay về +Y
def bgd_ghe_gd():
    p = Prop("bgd_ghe_gd")
    ix = p.bm("Inox", bevel=0.004)
    for k in range(5):
        a = 2 * math.pi * k / 5 + math.pi / 2
        box(ix, (math.cos(a) * 0.17, math.sin(a) * 0.17, 0.09), (0.34, 0.05, 0.03), rot=(0, 0, a))
        cyl(p.bm("NhuaDen"), (math.cos(a) * 0.33, math.sin(a) * 0.33, 0.035), 0.032, 0.035, seg=10, rot=(math.pi / 2, 0, a))
    cyl(ix, (0, 0, 0.28), 0.028, 0.32, seg=14)
    d = p.bm("DaBo", bevel=0.035)
    box(d, (0, 0.03, 0.49), (0.56, 0.54, 0.11))
    box(d, (0, -0.27, 0.98), (0.54, 0.11, 0.84), rot=(math.radians(-9), 0, 0))
    box(d, (0, -0.33, 1.33), (0.38, 0.1, 0.16), rot=(math.radians(-12), 0, 0))     # tựa đầu
    for z in (0.7, 0.88, 1.06):                                                    # đường may ngang
        box(p.bm("NhuaDen"), (0, -0.212 - (z - 0.7) * 0.15, z), (0.5, 0.01, 0.008), rot=(math.radians(-9), 0, 0))
    for sx in (-1, 1):
        box(ix, (sx * 0.3, -0.05, 0.58), (0.03, 0.03, 0.2))
        box(ix, (sx * 0.3, 0.12, 0.58), (0.03, 0.03, 0.2))
        box(d, (sx * 0.3, 0.03, 0.69), (0.08, 0.36, 0.04))
    done(p)


# ================================================================== GHẾ KHÁCH bọc da nâu
def bgd_ghe_khach():
    p = Prop("bgd_ghe_khach")
    d = p.bm("DaNau", bevel=0.03)
    box(d, (0, 0.02, 0.45), (0.56, 0.52, 0.1))
    box(d, (0, -0.24, 0.75), (0.56, 0.09, 0.56), rot=(math.radians(-8), 0, 0))
    for sx in (-1, 1):
        box(d, (sx * 0.3, -0.02, 0.6), (0.08, 0.56, 0.3))
    g = p.bm("GoOc", bevel=0.006)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(g, (sx * 0.26, sy * 0.22, 0.2), (0.045, 0.045, 0.4), rot=(sy * 0.06, -sx * 0.06, 0))
    done(p)


# ================================================================== TỦ SÁCH GỖ (rộng 1,3 m, cao 2,3 m)
def bgd_tu_sach(name, seed, ship=False):
    rr = random.Random(seed)
    p = Prop(name)
    g = p.bm("GoOc", bevel=0.004)
    Wt, Dt, Ht = 1.3, 0.42, 2.3
    box(g, (-Wt / 2 + 0.015, 0, Ht / 2), (0.03, Dt, Ht))
    box(g, (Wt / 2 - 0.015, 0, Ht / 2), (0.03, Dt, Ht))
    box(g, (0, 0, 0.05), (Wt, Dt, 0.1))
    box(g, (0, 0, Ht - 0.03), (Wt + 0.04, Dt + 0.03, 0.06))
    box(p.bm("GoSang"), (0, Dt / 2 - 0.01, Ht / 2), (Wt - 0.06, 0.02, Ht))
    box(g, (0, 0, Ht / 2), (0.025, Dt - 0.02, Ht - 0.1))
    shelves = [0.86, 1.22, 1.58, 1.94]
    for z in [0.82] + shelves:
        box(g, (0, 0.0, z), (Wt - 0.04, Dt - 0.03, 0.025))
    # cánh dưới gỗ, tay nắm đồng
    dg = p.bm("Dong", bevel=0.002)
    for sx in (-1, 1):
        box(g, (sx * 0.31, -Dt / 2 + 0.01, 0.46), (0.6, 0.02, 0.7))
        box(p.bm("GoSang", bevel=0.002), (sx * 0.31, -Dt / 2 - 0.002, 0.46), (0.5, 0.008, 0.6))
        box(dg, (sx * 0.05, -Dt / 2 - 0.02, 0.62), (0.014, 0.02, 0.14))
    # đồ trên kệ
    zs = [0.835] + shelves[:-1]
    for zi, z0 in enumerate(zs):
        for half in (-1, 1):
            x = half * 0.02 + (-Wt / 2 + 0.05 if half < 0 else 0.03)
            xend = -0.03 if half < 0 else Wt / 2 - 0.05
            kind = rr.choice(["sach", "sach", "hoso", "cup", "binh", "trong"])
            if ship and zi == 1 and half > 0:
                _ship(p, (0.3, 0.0, z0 + 0.015))
                continue
            if kind == "cup":
                c = (x + (xend - x) / 2, 0.0, z0 + 0.012)
                cup = p.bm("Dong", ang=40)
                lathe(cup, [(0.04, 0.0), (0.04, 0.03), (0.012, 0.04), (0.012, 0.11), (0.05, 0.14), (0.06, 0.22), (0.0, 0.2)], seg=18)
                for v in cup.verts:
                    if v.co.z < 0.25 and abs(v.co.x) < 0.07 and abs(v.co.y) < 0.07 and not hasattr(v, "_m"):
                        pass
                bmesh.ops.translate(cup, vec=Vector(c), verts=[v for v in cup.verts if v.co.z <= 0.23 and v.co.length < 0.3])
                box(p.bm("GoOc"), (c[0], c[1], z0 + 0.025), (0.1, 0.1, 0.03))
                continue
            if kind == "binh":
                v0 = p.bm("SuTrangBong", ang=60)
                lathe(v0, [(0.05, 0.0), (0.08, 0.06), (0.085, 0.14), (0.05, 0.22), (0.035, 0.26), (0.045, 0.28), (0.0, 0.27)], seg=20)
                bmesh.ops.translate(v0, vec=Vector((x + (xend - x) / 2, 0.0, z0 + 0.012)), verts=[v for v in v0.verts if v.co.z <= 0.3 and v.co.length < 0.4])
                continue
            if kind == "trong":
                continue
            while x < xend - 0.04:
                t = rr.choice([0.025, 0.03, 0.04, 0.05]) if kind == "sach" else 0.07
                hh = rr.uniform(0.22, 0.3) if kind == "sach" else 0.3
                m = rr.choice(["SachDo", "SachXanh", "SachNau", "SachKem", "BiaDen"]) if kind == "sach" else rr.choice(["BiaXanh", "BiaTrang", "BiaDen"])
                box(p.bm(m, bevel=0.002), (x + t / 2, 0.02, z0 + 0.012 + hh / 2), (t - 0.003, 0.26, hh))
                x += t
            if rr.random() < 0.5:   # vài cuốn nằm nghiêng
                box(p.bm("SachNau", bevel=0.002), (xend - 0.08, 0.02, z0 + 0.03), (0.15, 0.24, 0.035))
    # cánh kính khoang trên
    k = p.bm("Kinh", ang=5)
    for sx in (-1, 1):
        box(k, (sx * 0.31, -Dt / 2 + 0.008, 1.535), (0.6, 0.006, 1.38))
        for zz in (0.85, 2.22):
            box(g, (sx * 0.31, -Dt / 2 + 0.008, zz), (0.62, 0.02, 0.03))
        for xx in (sx * 0.31 - 0.3, sx * 0.31 + 0.3):
            box(g, (xx, -Dt / 2 + 0.008, 1.535), (0.025, 0.02, 1.4))
        box(dg, (sx * 0.04, -Dt / 2 - 0.006, 1.4), (0.012, 0.014, 0.12))
    done(p)


def _ship(p, base):
    """thuyền buồm mạ vàng 'Thuận buồm xuôi gió'"""
    b = Vector(base)
    hull = p.bm("GoOc", sub=1, ang=180)
    tube(hull, [b + Vector((-0.22, 0, 0.05)), b + Vector((-0.1, 0, 0.04)), b + Vector((0.1, 0, 0.04)), b + Vector((0.22, 0, 0.07))],
         [(0.03, 0.03), (0.05, 0.035), (0.05, 0.035), (0.015, 0.02)], ref=(0, 1, 0), seg=10)
    box(p.bm("GoOc"), b + Vector((0, 0, 0.012)), (0.12, 0.06, 0.024))
    for i, x in enumerate((-0.11, 0.0, 0.11)):
        hmast = 0.28 if i == 1 else 0.22
        cyl(p.bm("Dong"), b + Vector((x, 0, 0.07 + hmast / 2)), 0.004, hmast, seg=6)
        for j in range(2 if i != 1 else 3):
            z = 0.12 + j * 0.075
            w = 0.07 - j * 0.012
            box(p.bm("BuomVang", bevel=0.0), b + Vector((x, 0.006, z + 0.03)), (w * 1.6, 0.006, 0.06), rot=(0.12, 0, 0))


# ================================================================== SOFA DA + BÀN TRÀ + BỘ ẤM CHÉN
def bgd_sofa(name, seats):
    p = Prop(name)
    Wd = 0.62 * seats + 0.36
    d = p.bm("DaNau", bevel=0.035)
    box(d, (0, 0, 0.24), (Wd, 0.86, 0.26))
    for i in range(seats):
        x = -Wd / 2 + 0.18 + 0.31 + i * 0.62
        box(d, (x, -0.04, 0.42), (0.6, 0.66, 0.13))
        box(d, (x, 0.32, 0.66), (0.6, 0.2, 0.46), rot=(math.radians(-10), 0, 0))
    box(d, (0, 0.4, 0.55), (Wd, 0.08, 0.6))
    for sx in (-1, 1):
        box(d, (sx * (Wd / 2 - 0.09), 0.0, 0.42), (0.18, 0.86, 0.38))
    g = p.bm("GoOc", bevel=0.004)
    for sx in (-1, 1):
        for sy in (-1, 1):
            cyl(g, (sx * (Wd / 2 - 0.08), sy * 0.35, 0.05), 0.025, 0.1, seg=10, r2=0.018)
    done(p)


def bgd_ban_tra():
    p = Prop("bgd_ban_tra")
    g = p.bm("GoOc", bevel=0.006)
    box(g, (0, 0, 0.2), (1.0, 0.5, 0.04))
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(g, (sx * 0.5, sy * 0.25, 0.2), (0.05, 0.05, 0.4))
    box(p.bm("Kinh", ang=5), (0, 0, 0.415), (1.2, 0.65, 0.012))
    # khay + ấm + 4 chén
    box(p.bm("GoSang", bevel=0.006), (0.1, 0.0, 0.43), (0.42, 0.28, 0.02))
    su = p.bm("SuTrangBong", sub=1, ang=180)
    lathe(su, [(0.0, 0.44), (0.05, 0.44), (0.065, 0.47), (0.065, 0.51), (0.04, 0.54), (0.02, 0.545), (0.0, 0.55)], seg=20)
    for v in su.verts:
        v.co.x += 0.0
    tube(su, [(0.06, 0.0, 0.5), (0.1, 0.0, 0.52), (0.12, 0.0, 0.545)], [0.012, 0.009, 0.006], ref=(0, 1, 0), seg=8)
    tube(su, [(-0.06, 0.0, 0.53), (-0.09, 0.0, 0.52), (-0.09, 0.0, 0.48), (-0.06, 0.0, 0.47)], [0.008] * 4, ref=(0, 1, 0), seg=8)
    ell(su, (0, 0, 0.555), (0.012, 0.012, 0.01), seg=8, rings=5)
    c2 = p.bm("SuTrangBong", ang=50)
    for cx, cy in ((0.2, -0.07), (0.27, -0.07), (0.2, 0.07), (0.27, 0.07)):
        res = lathe(c2, [(0.0, 0.44), (0.018, 0.44), (0.026, 0.475), (0.022, 0.475), (0.0, 0.446)], seg=14, cap_top=False)
    # dời các chén vào chỗ: lathe trả về các vòng theo thứ tự tạo
    vs = [v for v in c2.verts]
    per = len(vs) // 4
    for k, (cx, cy) in enumerate(((0.2, -0.07), (0.27, -0.07), (0.2, 0.07), (0.27, 0.07))):
        for v in vs[k * per:(k + 1) * per]:
            v.co.x += cx; v.co.y += cy
    # đĩa hoa quả
    dq = p.bm("SuTrangBong", ang=50)
    lathe(dq, [(0.0, 0.42), (0.1, 0.42), (0.13, 0.44), (0.0, 0.43)], seg=24)
    for v in dq.verts:
        v.co.x -= 0.35
    for i in range(5):
        ell(p.bm(R.choice(["VoiDo", "LaCayVang"]), sub=1, ang=180), (-0.35 + R.uniform(-0.05, 0.05), R.uniform(-0.05, 0.05), 0.47 + (0.03 if i == 4 else 0)), (0.035, 0.035, 0.033), seg=10, rings=6)
    done(p)


# ================================================================== CÂY PHÁT TÀI trong chậu sứ
def bgd_cay():
    p = Prop("bgd_cay")
    lathe(p.bm("SuNau", ang=50), [(0.14, 0.0), (0.2, 0.05), (0.22, 0.3), (0.2, 0.46), (0.21, 0.48), (0.19, 0.48)], seg=28)
    cyl(p.bm("Dat"), (0, 0, 0.45), 0.19, 0.02, seg=24)
    for k, (h, ox, oy) in enumerate(((1.25, 0.03, 0.02), (0.95, -0.05, 0.03), (0.7, 0.02, -0.05))):
        tube(p.bm("VoCay", sub=1, ang=180), [(ox, oy, 0.45), (ox * 1.5, oy * 1.5, 0.45 + h * 0.5), (ox * 2, oy * 2, 0.45 + h)], [0.03, 0.027, 0.024], ref=(1, 0, 0), seg=10)
        top = Vector((ox * 2, oy * 2, 0.45 + h))
        for i in range(16):
            a = i / 16 * 2 * math.pi + R.uniform(-0.2, 0.2)
            up = R.uniform(0.1, 0.9)
            L = R.uniform(0.35, 0.55)
            dirv = Vector((math.cos(a), math.sin(a), up)).normalized()
            pts = [top + dirv * L * t + Vector((0, 0, -0.25 * L * t * t)) for t in (0, 0.35, 0.7, 1.0)]
            ref = (-math.sin(a), math.cos(a), 0)
            tube(p.bm("LaCay" if i % 3 else "LaCayVang", ang=180), pts, [(0.02, 0.004), (0.035, 0.004), (0.03, 0.003), (0.003, 0.002)], ref=ref, seg=6)
    done(p)


# ================================================================== THẢM, BẰNG KHEN
def bgd_tham():
    p = Prop("bgd_tham")
    f = p.bm("ThamTrai", ang=5)
    quad_uv(f, [(-1.1, -1.5, 0.006), (1.1, -1.5, 0.006), (1.1, 1.5, 0.006), (-1.1, 1.5, 0.006)])
    box(p.bm("ThamTrai"), (0, 0, 0.003), (2.2, 3.0, 0.005))
    done(p)


def bgd_bang_khen():
    p = Prop("bgd_bang_khen")
    kt = p.bm("Dong", bevel=0.003)
    Wb, Hb = 0.42, 0.32
    box(p.bm("GoOc", bevel=0.003), (0, 0.012, 0), (Wb + 0.06, 0.02, Hb + 0.06))
    for zz in (-Hb / 2 - 0.015, Hb / 2 + 0.015):
        box(kt, (0, 0.0, zz), (Wb + 0.06, 0.02, 0.025))
    for xx in (-Wb / 2 - 0.015, Wb / 2 + 0.015):
        box(kt, (xx, 0.0, 0), (0.025, 0.02, Hb + 0.06))
    quad_uv(p.bm("BangKhen", ang=5), [(-Wb / 2, -0.001, -Hb / 2), (Wb / 2, -0.001, -Hb / 2), (Wb / 2, -0.001, Hb / 2), (-Wb / 2, -0.001, Hb / 2)])
    done(p)


# ================================================================== GIÁM ĐỐC ngồi (thân + đầu tách riêng để gật/ngẩng đầu)
def giam_doc():
    p = Prop("giam_doc_than")
    av = p.bm("AoVest", sub=1, ang=180)
    tube(av, [(0, -0.05, 0.62), (0, -0.03, 0.76), (0, -0.015, 0.9), (0, 0.0, 1.0), (0, 0.01, 1.08), (0, 0.025, 1.13)],
         [(0.18, 0.14), (0.185, 0.155), (0.178, 0.145), (0.182, 0.12), (0.185, 0.1), (0.11, 0.07)], ref=(1, 0, 0), seg=16)
    # áo sơ mi trắng + cà vạt lộ ra ở cổ chữ V
    ao = p.bm("Ao", sub=1, ang=180)
    tube(ao, [(0, 0.09, 0.93), (0, 0.1, 1.02), (0, 0.075, 1.11)], [(0.05, 0.03), (0.07, 0.035), (0.06, 0.03)], ref=(1, 0, 0), seg=10)
    _collar(p, (0, 0.035, 1.125), (0, 0, 0), 0.062)
    cv = p.bm("CaVat", sub=1, ang=180)
    tube(cv, [(0, 0.098, 1.105), (0, 0.118, 1.04), (0, 0.13, 0.96), (0, 0.13, 0.9)], [(0.012, 0.006), (0.018, 0.006), (0.026, 0.006), (0.012, 0.005)], ref=(1, 0, 0), seg=8)
    ell(cv, (0, 0.1, 1.11), (0.016, 0.012, 0.014), seg=8, rings=5)
    for sx in (-1, 1):   # ve áo
        box(av, (sx * 0.06, 0.125, 0.99), (0.05, 0.02, 0.2), rot=(0.12, sx * 0.15, sx * -0.35))
        ell(av, (sx * 0.175, 0.0, 1.075), (0.07, 0.07, 0.065), seg=12, rings=8)
        # tay áo vest: vai -> khuỷu -> cổ tay đặt trên bàn
        tube(av, [(sx * 0.19, 0.0, 1.07), (sx * 0.215, 0.09, 0.95), (sx * 0.225, 0.2, 0.84), (sx * 0.19, 0.36, 0.81), (sx * 0.155, 0.48, 0.795)],
             [0.06, 0.056, 0.05, 0.045, 0.042], ref=(0, 1, 0), seg=12)
        tube(ao, [(sx * 0.153, 0.48, 0.795), (sx * 0.145, 0.51, 0.792)], [0.04, 0.038], ref=(0, 1, 0), seg=10)
        da = p.bm("Da", sub=1, ang=180)
        ell(da, (sx * 0.13, 0.575, 0.782), (0.045, 0.065, 0.018), seg=14, rings=8, rot=(0.05, 0, sx * -0.25))
        ell(da, (sx * 0.1, 0.55, 0.785), (0.014, 0.035, 0.013), seg=10, rings=6, rot=(0.1, 0, sx * -0.9))
        box(p.bm("CucAo"), (sx * 0.06 + 0.0, 0.145, 0.86 - (0.1 if sx > 0 else 0.0)), (0.012, 0.006, 0.012))
    q = p.bm("Quan", sub=1, ang=180)
    ell(q, (0, -0.03, 0.585), (0.185, 0.16, 0.105), seg=16, rings=10)
    for sx in (-1, 1):
        tube(q, [(sx * 0.1, -0.02, 0.58), (sx * 0.105, 0.18, 0.575), (sx * 0.112, 0.37, 0.565), (sx * 0.116, 0.43, 0.5), (sx * 0.118, 0.45, 0.3), (sx * 0.12, 0.45, 0.12)],
             [0.092, 0.082, 0.064, 0.06, 0.051, 0.043], ref=(1, 0, 0), seg=14)
        ell(p.bm("GiayDa", sub=1, ang=180), (sx * 0.12, 0.5, 0.045), (0.048, 0.125, 0.042), seg=14, rings=8)
    tube(p.bm("Da", sub=1, ang=180), [(0, 0.035, 1.1), (0, 0.055, 1.215)], [0.054, 0.052], ref=(1, 0, 0), seg=12)
    done(p)
    h = Prop("giam_doc_dau")
    _head(h, (0, 0.02, 0.095), False, "hoi", toc="TocBac", kinh=True)
    done(h)


bgd_phong(); bgd_ban(); bgd_ghe_gd(); bgd_ghe_khach()
bgd_tu_sach("bgd_tu_sach_a", 11, ship=True); bgd_tu_sach("bgd_tu_sach_b", 23)
bgd_sofa("bgd_sofa_3", 3); bgd_sofa("bgd_sofa_1", 1); bgd_ban_tra(); bgd_cay(); bgd_tham(); bgd_bang_khen()
giam_doc()
clear_scene(SC)
if _WIN and _OLD_SC:
    _WIN.scene = _OLD_SC
result = {"log": LOG}
