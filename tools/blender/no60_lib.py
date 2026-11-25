# Thư viện dựng model cho "Nợ 60 Ngày" (chạy bên trong Blender).
# Dùng: exec(open("/đường/dẫn/tools/blender/no60_lib.py").read())
# - write_glb(): ghi .glb trực tiếp (không dùng nút Export của Blender vì hay bị sập)
# - các hàm dựng tay, đồ cầm tay.
import bpy, bmesh, math, struct, json
from mathutils import Vector, Matrix


# ---------------------------------------------------------------- ghi GLB
def _smooth_normals(me, angle_deg):
    me.calc_loop_triangles()
    cos_lim = math.cos(math.radians(angle_deg))
    vf = {}
    for p in me.polygons:
        for vi in p.vertices:
            vf.setdefault(vi, []).append(p.index)
    pn = [p.normal.copy() for p in me.polygons]
    pa = [p.area for p in me.polygons]
    return vf, pn, pa, cos_lim


def write_glb(path, parts):
    """parts: list of (object, smooth_angle_deg). Mỗi vật liệu -> 1 primitive. Toạ độ Blender Z-up -> glTF Y-up."""
    prims = {}   # mat_name -> dict(pos, nor, idx, mat)
    for ob, ang in parts:
        dg = _dg(ob)
        oe = ob.evaluated_get(dg)
        me = oe.to_mesh()
        mw = ob.matrix_world.copy()
        nmat = mw.to_3x3().inverted().transposed()
        vf, pn, pa, cos_lim = _smooth_normals(me, ang)
        mats = [s.material for s in ob.material_slots] or [None]
        vmaps = {}
        for tri in me.loop_triangles:
            m = mats[tri.material_index] if tri.material_index < len(mats) else mats[0]
            key_m = m.name if m else "_default"
            P = prims.setdefault(key_m, {"pos": [], "nor": [], "idx": [], "mat": m})
            vmap = vmaps.setdefault(key_m, {})
            fn = pn[tri.polygon_index]
            for vi in tri.vertices:
                acc = Vector()
                for f in vf[vi]:
                    if pn[f].dot(fn) >= cos_lim:
                        acc += pn[f] * max(pa[f], 1e-10)
                n = acc.normalized() if acc.length > 0 else fn
                key = (vi, round(n.x, 3), round(n.y, 3), round(n.z, 3))
                if key not in vmap:
                    v = mw @ me.vertices[vi].co
                    nn = (nmat @ n).normalized()
                    vmap[key] = len(P["pos"])
                    P["pos"].append((v.x, v.z, -v.y))
                    P["nor"].append((nn.x, nn.z, -nn.y))
                P["idx"].append(vmap[key])
        oe.to_mesh_clear()
    pad = lambda b: b + b"\x00" * ((4 - len(b) % 4) % 4)
    binb = b""
    views, accs, gprims, gmats = [], [], [], []
    for i, (mname, P) in enumerate(prims.items()):
        pb = pad(b"".join(struct.pack("<3f", *p) for p in P["pos"]))
        nb = pad(b"".join(struct.pack("<3f", *n) for n in P["nor"]))
        ib = pad(b"".join(struct.pack("<I", k) for k in P["idx"]))
        base = len(views)
        for blob, tgt in ((pb, 34962), (nb, 34962), (ib, 34963)):
            views.append({"buffer": 0, "byteOffset": len(binb), "byteLength": len(blob), "target": tgt})
            binb += blob
        mn = [min(p[k] for p in P["pos"]) for k in range(3)]
        mx = [max(p[k] for p in P["pos"]) for k in range(3)]
        accs += [{"bufferView": base, "componentType": 5126, "count": len(P["pos"]), "type": "VEC3", "min": mn, "max": mx},
                 {"bufferView": base + 1, "componentType": 5126, "count": len(P["nor"]), "type": "VEC3"},
                 {"bufferView": base + 2, "componentType": 5125, "count": len(P["idx"]), "type": "SCALAR"}]
        gprims.append({"attributes": {"POSITION": 3 * i, "NORMAL": 3 * i + 1}, "indices": 3 * i + 2, "material": i})
        m = P["mat"]
        col, rough, metal, alpha = [0.8, 0.8, 0.8, 1.0], 0.6, 0.0, 1.0
        if m and m.use_nodes and "Principled BSDF" in m.node_tree.nodes:
            b = m.node_tree.nodes["Principled BSDF"]
            col = list(b.inputs["Base Color"].default_value)
            rough = b.inputs["Roughness"].default_value
            metal = b.inputs["Metallic"].default_value
            alpha = b.inputs["Alpha"].default_value
        col[3] = alpha
        gm = {"name": mname, "pbrMetallicRoughness": {"baseColorFactor": col, "metallicFactor": metal, "roughnessFactor": rough}}
        if alpha < 0.999:
            gm["alphaMode"] = "BLEND"
            gm["doubleSided"] = True
        gmats.append(gm)
    name = path.split("/")[-1].rsplit(".", 1)[0]
    g = {"asset": {"version": "2.0", "generator": "No60Ngay no60_lib"}, "scene": 0, "scenes": [{"nodes": [0]}],
         "nodes": [{"name": name, "mesh": 0}], "meshes": [{"name": name, "primitives": gprims}],
         "materials": gmats, "buffers": [{"byteLength": len(binb)}], "bufferViews": views, "accessors": accs}
    jb = json.dumps(g, separators=(",", ":")).encode()
    jb += b" " * ((4 - len(jb) % 4) % 4)
    with open(path, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(jb) + 8 + len(binb)))
        f.write(struct.pack("<I4s", len(jb), b"JSON")); f.write(jb)
        f.write(struct.pack("<I4s", len(binb), b"BIN\x00")); f.write(binb)
    return sum(len(P["idx"]) // 3 for P in prims.values())


# ---------------------------------------------------------------- tiện ích
def get_scene(name):
    sc = bpy.data.scenes.get(name) or bpy.data.scenes.new(name)
    return sc


def clear_scene(sc):
    for o in list(sc.collection.objects):
        bpy.data.objects.remove(o, do_unlink=True)


def mat(name, rgb, rough=0.5, metal=0.0, alpha=1.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    b.inputs["Alpha"].default_value = alpha
    return m


def obj_from_bm(sc, name, bm, material=None):
    me = bpy.data.meshes.new(name)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me)
    sc.collection.objects.link(ob)
    if material:
        me.materials.append(material)
    return ob


def _dg(ob):
    sc = ob.users_scene[0] if ob.users_scene else bpy.context.scene
    dg = sc.view_layers[0].depsgraph
    dg.update()
    return dg


def bake(ob):
    dg = _dg(ob)
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    old = ob.data; ob.modifiers.clear(); ob.data = me
    if old.users == 0:
        bpy.data.meshes.remove(old)


def capsule(bm, a, b, ra, rb, seg=10, rings=4):
    """ống bo tròn hai đầu từ điểm a (bán kính ra) đến b (bán kính rb)"""
    a, b = Vector(a), Vector(b)
    d = (b - a); L = d.length; d.normalize()
    up = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
    x = d.cross(up).normalized(); y = d.cross(x).normalized()
    loops = []
    # bán cầu đầu a
    for i in range(rings, 0, -1):
        t = (i / rings) * (math.pi / 2)
        loops.append((a - d * ra * math.sin(t), ra * math.cos(t)))
    loops.append((a, ra)); loops.append((b, rb))
    for i in range(1, rings + 1):
        t = (i / rings) * (math.pi / 2)
        loops.append((b + d * rb * math.sin(t), rb * math.cos(t)))
    rows = []
    for c, r in loops:
        r = max(r, 1e-5)
        rows.append([bm.verts.new(c + (x * math.cos(2 * math.pi * k / seg) + y * math.sin(2 * math.pi * k / seg)) * r) for k in range(seg)])
    for i in range(len(rows) - 1):
        for k in range(seg):
            bm.faces.new([rows[i][k], rows[i][(k + 1) % seg], rows[i + 1][(k + 1) % seg], rows[i + 1][k]])
    bm.faces.new(list(reversed(rows[0]))); bm.faces.new(rows[-1])


def loft(bm, rings_def, seg=16, cap=True):
    """rings_def: list of (center Vector, rx, rz) theo trục Y; mặt cắt elip trong mặt phẳng XZ"""
    rows = []
    for c, rx, rz in rings_def:
        rows.append([bm.verts.new((c[0] + rx * math.cos(2 * math.pi * k / seg), c[1], c[2] + rz * math.sin(2 * math.pi * k / seg))) for k in range(seg)])
    for i in range(len(rows) - 1):
        for k in range(seg):
            bm.faces.new([rows[i][k], rows[i][(k + 1) % seg], rows[i + 1][(k + 1) % seg], rows[i + 1][k]])
    if cap:
        bm.faces.new(list(reversed(rows[0]))); bm.faces.new(rows[-1])


def lathe(bm, profile, seg=24, cap_bottom=True, cap_top=True):
    """profile: list of (r, z) từ dưới lên; xoay quanh trục Z"""
    rows = []
    for r, z in profile:
        rows.append([bm.verts.new((r * math.cos(2 * math.pi * k / seg), r * math.sin(2 * math.pi * k / seg), z)) for k in range(seg)])
    for i in range(len(rows) - 1):
        for k in range(seg):
            bm.faces.new([rows[i][k], rows[i][(k + 1) % seg], rows[i + 1][(k + 1) % seg], rows[i + 1][k]])
    if cap_bottom:
        bm.faces.new(list(reversed(rows[0])))
    if cap_top:
        bm.faces.new(rows[-1])
    return rows


# ---------------------------------------------------------------- bàn tay
# Tay PHẢI, lòng bàn tay úp xuống (-Z), ngón tay hướng +Y, ngón cái phía -X. Cổ tay ở gốc toạ độ.
FINGERS = [  # tên, x gốc, y gốc, độ dài 3 đốt, bán kính gốc
    ("tro", -0.027, 0.098, (0.040, 0.025, 0.020), 0.0098),
    ("giua", -0.008, 0.102, (0.045, 0.028, 0.021), 0.0100),
    ("ap_ut", 0.011, 0.099, (0.042, 0.026, 0.020), 0.0094),
    ("ut", 0.028, 0.091, (0.033, 0.020, 0.018), 0.0082),
]

POSES = {
    # độ co (độ) ở 3 khớp mỗi ngón; ngón cái: (hướng gốc, co khớp 1, co khớp 2)
    "tha_long": {"curl": [(12, 14, 8), (14, 16, 8), (16, 18, 10), (18, 20, 12)], "spread": 4,
                 "thumb": {"dir": (-0.55, 0.75, -0.35), "bend": (12, 10)}},
    "cao": {"curl": [(38, 48, 30), (40, 50, 32), (42, 52, 32), (44, 54, 34)], "spread": 7,
            "thumb": {"dir": (-0.35, 0.8, -0.5), "bend": (25, 25)}},
    "nam": {"curl": [(62, 74, 48), (64, 76, 50), (66, 78, 50), (68, 80, 52)], "spread": 1,
            "thumb": {"dir": (0.05, 0.75, -0.65), "bend": (22, 28)}},
    "kep": {"curl": [(22, 20, 10), (24, 22, 10), (30, 30, 16), (36, 36, 20)], "spread": 2,
            "thumb": {"dir": (-0.05, 0.85, -0.55), "bend": (8, 8)}},
}


def build_hand(sc, name, pose, skin_mat, sleeve_mat, voxel=0.0022):
    P = POSES[pose]
    bm = bmesh.new()
    # lòng bàn tay: khối elip thuôn, bo tròn
    loft(bm, [(Vector((0, -0.012, 0.0)), 0.029, 0.019), (Vector((0, 0.012, -0.001)), 0.035, 0.018),
              (Vector((0.002, 0.045, -0.002)), 0.04, 0.016), (Vector((0.002, 0.08, -0.002)), 0.042, 0.0145),
              (Vector((0.002, 0.097, -0.002)), 0.039, 0.0125), (Vector((0.002, 0.106, -0.003)), 0.03, 0.009)], seg=20)
    # gò khớp ngón (đốt tay)
    for (nm, fx, fy, lens, r0) in FINGERS:
        capsule(bm, (fx, fy - 0.012, -0.0015), (fx, fy, -0.002), r0 * 1.05, r0 * 1.05, seg=10, rings=3)
    # gò ngón cái
    capsule(bm, (-0.022, 0.01, -0.008), (-0.03, 0.04, -0.008), 0.017, 0.013, seg=10, rings=3)
    # cẳng tay (thuôn từ cổ tay ra khuỷu)
    loft(bm, [(Vector((0, 0.0, 0)), 0.029, 0.019), (Vector((0, -0.03, 0)), 0.029, 0.02), (Vector((0, -0.15, 0.002)), 0.035, 0.026),
              (Vector((0, -0.3, 0.004)), 0.041, 0.032), (Vector((0, -0.45, 0.004)), 0.043, 0.034)], seg=18)
    # các ngón
    for i, (nm, fx, fy, lens, r0) in enumerate(FINGERS):
        curl = P["curl"][i]
        spread = math.radians((i - 1.5) * P["spread"])
        p = Vector((fx, fy, -0.002))
        a = 0.0
        r = r0
        for k, L in enumerate(lens):
            a += math.radians(curl[k])
            d = Vector((math.sin(spread) * math.cos(a), math.cos(spread) * math.cos(a), -math.sin(a)))
            q = p + d * L
            r2 = r * 0.86
            capsule(bm, p, q, r, r2, seg=10, rings=3)
            p, r = q, r2
    # ngón cái
    th = P["thumb"]
    base = Vector((-0.034, 0.022, -0.006))
    d0 = Vector(th["dir"]).normalized()
    m1 = base + d0 * 0.04
    capsule(bm, base, m1, 0.014, 0.0115, seg=10, rings=3)
    ax = d0.cross(Vector((0, 0, 1))).normalized()
    d1 = (Matrix.Rotation(math.radians(th["bend"][0]), 3, ax) @ d0).normalized()
    m2 = m1 + d1 * 0.03
    capsule(bm, m1, m2, 0.0115, 0.0098, seg=10, rings=3)
    d2 = (Matrix.Rotation(math.radians(th["bend"][0] + th["bend"][1]), 3, ax) @ d0).normalized()
    m3 = m2 + d2 * 0.026
    capsule(bm, m2, m3, 0.0098, 0.0085, seg=10, rings=3)
    ob = obj_from_bm(sc, name + "_da", bm, skin_mat)
    # hoà thành một khối mềm
    rm = ob.modifiers.new("remesh", 'REMESH'); rm.mode = 'VOXEL'; rm.voxel_size = voxel; rm.adaptivity = 0.0
    sm = ob.modifiers.new("smooth", 'SMOOTH'); sm.factor = 0.7; sm.iterations = 8
    dc = ob.modifiers.new("dec", 'DECIMATE'); dc.ratio = 0.12
    bake(ob)
    if len(ob.data.materials) == 0:
        ob.data.materials.append(skin_mat)
    # tay áo
    bm2 = bmesh.new()
    loft(bm2, [(Vector((0, -0.29, 0.004)), 0.05, 0.043), (Vector((0, -0.31, 0.004)), 0.053, 0.046),
               (Vector((0, -0.42, 0.004)), 0.056, 0.048), (Vector((0, -0.56, 0.004)), 0.058, 0.05)], seg=18)
    sl = obj_from_bm(sc, name + "_ao", bm2, sleeve_mat)
    return ob, sl


# ---------------------------------------------------------------- đồ cầm tay (trục dài theo +Z, gốc ở tâm chỗ cầm)
def build_items(sc):
    out = {}
    # chai nước lọc 500 ml
    bm = bmesh.new()
    prof = [(0.0, -0.1), (0.028, -0.1), (0.032, -0.095), (0.033, -0.06), (0.03, -0.045), (0.033, -0.03), (0.033, 0.03),
            (0.031, 0.05), (0.026, 0.07), (0.016, 0.085), (0.0135, 0.092), (0.0135, 0.098)]
    lathe(bm, prof, seg=24, cap_bottom=True, cap_top=True)
    body = obj_from_bm(sc, "chai_nuoc_than", bm, mat("ChaiTrong", (0.78, 0.88, 0.95), 0.08, alpha=0.38))
    bm = bmesh.new(); lathe(bm, [(0.0142, 0.096), (0.0145, 0.112), (0.0, 0.113)], seg=20, cap_bottom=True, cap_top=False)
    cap = obj_from_bm(sc, "chai_nuoc_nap", bm, mat("NapXanh", (0.02, 0.12, 0.55), 0.4))
    bm = bmesh.new(); lathe(bm, [(0.0336, -0.025), (0.0336, 0.028)], seg=24, cap_bottom=False, cap_top=False)
    lab = obj_from_bm(sc, "chai_nuoc_nhan", bm, mat("NhanXanhTrang", (0.12, 0.35, 0.8), 0.5))
    bm = bmesh.new(); lathe(bm, [(0.0, -0.096), (0.03, -0.096), (0.031, 0.03), (0.0, 0.03)], seg=20)
    water = obj_from_bm(sc, "chai_nuoc_nuoc", bm, mat("Nuoc", (0.55, 0.75, 0.9), 0.05, alpha=0.3))
    out["chai_nuoc"] = [(body, 50), (cap, 40), (lab, 40), (water, 50)]
    # lon nước ngọt
    bm = bmesh.new(); lathe(bm, [(0.0, -0.06), (0.026, -0.06), (0.033, -0.052), (0.033, 0.05), (0.027, 0.06), (0.0, 0.058)], seg=24)
    can = obj_from_bm(sc, "lon_than", bm, mat("LonDo", (0.6, 0.02, 0.02), 0.3, metal=0.5))
    bm = bmesh.new(); lathe(bm, [(0.0331, 0.035), (0.0331, 0.05)], seg=24, cap_bottom=False, cap_top=False)
    band = obj_from_bm(sc, "lon_vien", bm, mat("LonBac", (0.75, 0.75, 0.75), 0.25, metal=0.9))
    out["lon_nuoc"] = [(can, 40), (band, 40)]
    # bánh mì (trục dài +Z), bọc giấy một đầu
    bm = bmesh.new()
    rows = []
    for i in range(17):
        t = i / 16.0; z = -0.12 + t * 0.24
        r = 0.026 * (math.sin(math.pi * (0.03 + 0.94 * t)) ** 0.35)
        rows.append((Vector((0, z, 0)), r * 1.1, r * 0.78))
    loft(bm, rows, seg=16)
    for v in bm.verts:
        v.co = Vector((v.co.x, v.co.z, v.co.y))  # trục dài sang Z
    bread = obj_from_bm(sc, "banh_mi", bm, mat("VoBanh", (0.7, 0.4, 0.1), 0.5))
    bm = bmesh.new(); lathe(bm, [(0.03, -0.1), (0.032, -0.03), (0.029, -0.026)], seg=16, cap_bottom=False, cap_top=False)
    wrap = obj_from_bm(sc, "banh_mi_giay", bm, mat("GiayGoi", (0.8, 0.78, 0.7), 0.9))
    out["banh_mi"] = [(bread, 60), (wrap, 40)]
    # ly mì
    bm = bmesh.new(); lathe(bm, [(0.0, -0.05), (0.034, -0.05), (0.045, 0.05), (0.0, 0.05)], seg=24)
    cup = obj_from_bm(sc, "ly_mi", bm, mat("LyMiTrang", (0.85, 0.83, 0.78), 0.6))
    bm = bmesh.new(); lathe(bm, [(0.0405, 0.0), (0.0448, 0.035)], seg=24, cap_bottom=False, cap_top=False)
    cband = obj_from_bm(sc, "ly_mi_vien", bm, mat("LyMiDo", (0.6, 0.04, 0.03), 0.5))
    bm = bmesh.new(); lathe(bm, [(0.0, 0.05), (0.047, 0.05), (0.047, 0.053), (0.0, 0.053)], seg=24)
    lid = obj_from_bm(sc, "ly_mi_nap", bm, mat("NapGiay", (0.8, 0.7, 0.35), 0.5))
    out["ly_mi"] = [(cup, 40), (cband, 40), (lid, 40)]
    # hộp cơm xốp (nằm ngang, cầm ở đáy)
    bm = bmesh.new()
    for (z0, z1, sx, sy) in [(-0.03, 0.0, 0.095, 0.075), (0.0, 0.032, 0.1, 0.08)]:
        vs = bmesh.ops.create_cube(bm, size=1.0)["verts"]
        for v in vs:
            v.co = Vector((v.co.x * 2 * sx, v.co.y * 2 * sy, z0 if v.co.z < 0 else z1))
    box = obj_from_bm(sc, "hop_com", bm, mat("Xop", (0.88, 0.88, 0.85), 0.85))
    bv = box.modifiers.new("bv", 'BEVEL'); bv.width = 0.006; bv.segments = 2; bake(box)
    out["hop_com"] = [(box, 35)]
    # tờ giấy A4 (nằm trong mặt phẳng XZ, hướng mặt chữ về -Y, hơi cong)
    bm = bmesh.new(); W, H = 0.21, 0.297; nx, nz = 8, 10
    grid = [[bm.verts.new(((i / nx - 0.5) * W, 0.012 * (2 * i / nx - 1) ** 2, (j / nz - 0.5) * H)) for i in range(nx + 1)] for j in range(nz + 1)]
    for j in range(nz):
        for i in range(nx):
            bm.faces.new([grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]])
    sol = obj_from_bm(sc, "to_giay", bm, mat("Giay", (0.9, 0.9, 0.88), 0.9))
    s = sol.modifiers.new("s", 'SOLIDIFY'); s.thickness = 0.0008; bake(sol)
    out["to_giay"] = [(sol, 30)]
    # bìa báo cáo (bìa nhựa xanh + giấy bên trong)
    bm = bmesh.new()
    vs = bmesh.ops.create_cube(bm, size=1.0)["verts"]
    for v in vs:
        v.co = Vector((v.co.x * 0.225, v.co.y * 0.01, v.co.z * 0.31))
    cover = obj_from_bm(sc, "bia_bao_cao", bm, mat("BiaXanh", (0.03, 0.15, 0.45), 0.35))
    bv = cover.modifiers.new("bv", 'BEVEL'); bv.width = 0.004; bv.segments = 2; bake(cover)
    bm = bmesh.new()
    vs = bmesh.ops.create_cube(bm, size=1.0)["verts"]
    for v in vs:
        v.co = Vector((v.co.x * 0.205, -0.0055 + v.co.y * 0.001, v.co.z * 0.29))
    page = obj_from_bm(sc, "bia_bao_cao_giay", bm, mat("Giay", (0.9, 0.9, 0.88), 0.9))
    out["bia_bao_cao"] = [(cover, 30), (page, 30)]
    # cuộn dây đồng
    bm = bmesh.new()
    turns, R, r = 5, 0.045, 0.006
    rows = []
    for k in range(turns * 24 + 1):
        a = 2 * math.pi * k / 24
        c = Vector((R * math.cos(a), R * math.sin(a), -0.02 + 0.04 * k / (turns * 24)))
        t = Vector((-math.sin(a), math.cos(a), 0.0)).normalized(); n = Vector((math.cos(a), math.sin(a), 0)); b = t.cross(n)
        rows.append([bm.verts.new(c + (n * math.cos(2 * math.pi * j / 6) + b * math.sin(2 * math.pi * j / 6)) * r) for j in range(6)])
    for i in range(len(rows) - 1):
        for j in range(6):
            bm.faces.new([rows[i][j], rows[i][(j + 1) % 6], rows[i + 1][(j + 1) % 6], rows[i + 1][j]])
    coil = obj_from_bm(sc, "cuon_day_dong", bm, mat("Dong", (0.75, 0.33, 0.12), 0.3, metal=1.0))
    out["cuon_day_dong"] = [(coil, 50)]
    # điện thoại hỏng
    bm = bmesh.new(); vs = bmesh.ops.create_cube(bm, size=1.0)["verts"]
    for v in vs:
        v.co = Vector((v.co.x * 0.072, v.co.y * 0.009, v.co.z * 0.148))
    ph = obj_from_bm(sc, "dien_thoai", bm, mat("DenNham", (0.02, 0.02, 0.025), 0.4))
    bv = ph.modifiers.new("bv", 'BEVEL'); bv.width = 0.008; bv.segments = 3; bake(ph)
    bm = bmesh.new(); vs = bmesh.ops.create_cube(bm, size=1.0)["verts"]
    for v in vs:
        v.co = Vector((v.co.x * 0.064, -0.0047 + v.co.y * 0.0004, v.co.z * 0.13))
    scr = obj_from_bm(sc, "dien_thoai_man", bm, mat("ManHinh", (0.05, 0.07, 0.09), 0.1))
    out["dien_thoai"] = [(ph, 40), (scr, 30)]
    # bật lửa
    bm = bmesh.new(); vs = bmesh.ops.create_cube(bm, size=1.0)["verts"]
    for v in vs:
        v.co = Vector((v.co.x * 0.025, v.co.y * 0.012, -0.01 + v.co.z * 0.062))
    li = obj_from_bm(sc, "bat_lua", bm, mat("NhuaDoTrong", (0.7, 0.05, 0.05), 0.2))
    bv = li.modifiers.new("bv", 'BEVEL'); bv.width = 0.004; bv.segments = 2; bake(li)
    bm = bmesh.new(); vs = bmesh.ops.create_cube(bm, size=1.0)["verts"]
    for v in vs:
        v.co = Vector((v.co.x * 0.02, v.co.y * 0.011, 0.028 + v.co.z * 0.014))
    lt = obj_from_bm(sc, "bat_lua_dau", bm, mat("Bac", (0.7, 0.7, 0.7), 0.3, metal=1.0))
    out["bat_lua"] = [(li, 40), (lt, 40)]
    return out
