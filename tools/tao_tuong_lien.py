# Tường gạch bao quanh phố, liền một dải (không lặp ô):
#  - gach_nen.jpg/_normal.png: gạch xây tay không đều, lặp liền mạch mỗi 16 m
#  - mỗi cạnh i: vua_mau_i.jpg (màu lớp vữa vàng, 100 px/m), tuong_ban_i.png (bóng/ẩm/ố trên gạch, 50 px/m)
#  - mỗi cạnh i: tuong_canh_i.glb: khối vữa nhiều tầng (lót trắng mỏng, vữa vàng dày, lớp sơn trên cùng),
#    mép mượt bằng marching squares, kèm chu_son.json (vị trí chữ sơn vẽ tay)
import numpy as np, math, json, struct
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from scipy import ndimage

HW, HD = 603 * 0.1 / 2, 735 * 0.1 / 2
WALL_H = 3.2
SIDES = [2 * HW, 2 * HD, 2 * HW, 2 * HD]      # cùng thứ tự với town.gd
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FONT2 = "/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-Bold.ttf"

def pnoise(shape, cx, cy, seed):
    """nhiễu tuần hoàn; cx, cy = số chu kỳ tối đa theo mỗi trục trên toàn ảnh"""
    r = np.random.default_rng(seed); w = r.standard_normal(shape)
    fy = np.fft.fftfreq(shape[0])[:, None] * shape[0]; fx = np.fft.fftfreq(shape[1])[None, :] * shape[1]
    n = np.real(np.fft.ifft2(np.fft.fft2(w) * np.exp(-((fx / cx) ** 2 + (fy / cy) ** 2))))
    return (n - n.mean()) / (n.std() + 1e-9)

# ------------------------------------------------------------------ 1) gạch nền lặp 16 m
def brick_tile(seed=7, length=16.0, ppm=256):
    rng = np.random.default_rng(seed)
    W, H = int(length * ppm), int(WALL_H * ppm)
    S2 = 2
    idimg = Image.new("I", (W * S2, H * S2), 0); d = ImageDraw.Draw(idimg)
    PX = ppm * S2
    y = -rng.uniform(0, 0.06) * PX; nid = 0
    while y < H * S2:
        ch = rng.uniform(0.062, 0.078) * PX
        gap_y = rng.uniform(0.008, 0.017) * PX
        x0 = -rng.uniform(0, 0.25) * PX; x = x0
        bricks = []
        while True:
            L = rng.choice([rng.uniform(0.2, 0.25)] * 3 + [rng.uniform(0.1, 0.13)]) * PX
            gx = rng.uniform(0.007, 0.02) * PX
            if x + L + gx > x0 + W * S2 - 0.12 * PX:
                L = x0 + W * S2 - x - gx         # viên cuối khép vòng lặp
                bricks.append((x, L)); break
            bricks.append((x, L)); x += L + gx
        for (bx, L) in bricks:
            hb = ch - gap_y + rng.uniform(-0.004, 0.004) * PX
            ang = rng.normal(0, 0.012)
            cx = bx + L / 2
            cy = y + ch / 2 + math.sin(cx / (W * S2) * 2 * math.pi * 4) * 0.006 * PX + rng.normal(0, 0.0015 * PX)
            pts = []
            corners = [(-L / 2, -hb / 2), (L / 2, -hb / 2), (L / 2, hb / 2), (-L / 2, hb / 2)]
            for k in range(4):
                (ax, ay), (bx2, by2) = corners[k], corners[(k + 1) % 4]
                for j in range(10):
                    t = j / 10; px_, py_ = ax + (bx2 - ax) * t, ay + (by2 - ay) * t
                    cut = abs(rng.normal(0, 0.0012 * PX)) + (rng.uniform(0, 0.005) * PX if j == 0 else 0)
                    nx_, ny_ = (by2 - ay), -(bx2 - ax); ln = math.hypot(nx_, ny_) or 1
                    pts.append((px_ + nx_ / ln * cut, py_ + ny_ / ln * cut))
            ca, sa = math.cos(ang), math.sin(ang)
            nid += 1
            for off in (-W * S2, 0, W * S2):     # vẽ lặp hai bên để nối liền mạch
                d.polygon([(cx + off + p * ca - q * sa, cy + p * sa + q * ca) for p, q in pts], fill=nid)
        y += ch
    ids = np.asarray(idimg.resize((W, H), Image.NEAREST)).astype(np.int64)
    brick = ids > 0
    dist = ndimage.distance_transform_edt(np.pad(brick, ((0, 0), (8, 8)), mode="wrap"))[:, 8:-8]
    nb = nid + 1
    base = np.array([0.74, 0.4, 0.24])
    tone = rng.normal(0, 0.025, (nb, 3)) + rng.normal(0, 0.055, (nb, 1))
    tone += (rng.random(nb) < 0.08)[:, None] * np.array([-0.2, -0.12, -0.06]) + (rng.random(nb) < 0.07)[:, None] * np.array([0.08, 0.1, 0.1])
    bc = np.clip(base + tone, 0, 1)[ids]
    grain = pnoise((H, W), length * 40, WALL_H * 40, seed + 1)[..., None] * 0.04 + rng.normal(0, 0.03, (H, W, 1))
    bev = np.clip(dist / 3.0, 0, 1)
    bc = bc * (1 + grain) * (0.8 + 0.2 * bev)[..., None]
    mort = np.array([0.58, 0.55, 0.5]) * (1 + 0.1 * pnoise((H, W), length * 22, WALL_H * 22, seed + 2)[..., None]) * (0.85 + 0.15 * rng.random((H, W, 1)))
    col = np.where(brick[..., None], bc, mort)
    h = np.where(brick, 0.55 + 0.1 * np.sqrt(bev), 0.25)
    # vài viên gạch lỗ
    for i in np.where(rng.random(nb) < 0.02)[0]:
        sl = ndimage.find_objects((ids == i).astype(int))
        if not sl or sl[0] is None: continue
        ys, xs = sl[0]
        cy, cx = (ys.start + ys.stop) / 2, (xs.start + xs.stop) / 2
        r = (ys.stop - ys.start) * 0.24; w_ = xs.stop - xs.start
        yy, xx = np.ogrid[ys, xs]
        for dx in (-w_ * 0.2, w_ * 0.2):
            m = ((xx - cx - dx) ** 2 + (yy - cy) ** 2 < r * r) & (ids[ys, xs] == i)
            col[ys, xs][m] = (0.12, 0.07, 0.05); h[ys, xs][m] = 0.05
    Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8)).save("gach_nen.jpg", quality=90)
    gx_ = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5; gy_ = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
    nx, ny, nz = -gx_ * 4, gy_ * 4, np.ones_like(h); L = np.sqrt(nx * nx + ny * ny + nz * nz)
    Image.fromarray(((np.stack([nx / L, ny / L, nz / L], -1) * 0.5 + 0.5) * 255).astype(np.uint8)).save("gach_nen_normal.png")

# ------------------------------------------------------------------ 2) trường vữa + mặt nạ tầng cho mỗi cạnh
TEXTS = [("KHOAN CẮT BÊ TÔNG", "ĐT: 0123.456.789"), ("VÁ XE", "BƠM XE - THAY SĂM"), ("HÚT BỂ PHỐT", "THÔNG CỐNG 24/24"),
         ("VÁ XE 50m →", None), ("CẤM ĐỔ RÁC", "PHẠT 2.000.000đ"), ("KHOAN CẮT BÊ TÔNG", None), ("CHO THUÊ NHÀ", "LH CHÍNH CHỦ")]
LEVELS = [(0.0, 0.006), (0.13, 0.019), (0.27, 0.025)]     # (ngưỡng trường, độ cao mặt) lót trắng / vữa vàng / lớp sơn

GPPM = 34   # điểm lưới / mét cho khối vữa (~2,9 cm)


def plaster_field(i, length, ppm=GPPM):
    nx, ny = int(round(length * ppm)) + 1, int(WALL_H * ppm) + 1
    c = length / 4.0
    f = pnoise((ny, nx), 2.2 * c, 2.2 * WALL_H / 4 * 1.0 + 1.2, 100 + i) * 0.8 \
        + pnoise((ny, nx), 9 * c, 7, 200 + i) * 0.13 + pnoise((ny, nx), 25 * c, 18, 300 + i) * 0.03
    yy = np.linspace(0, 1, ny)[:, None]                  # 0 = đỉnh tường
    cover = pnoise((1, nx), 0.35 * c, 1, 400 + i)[0] * 0.55   # đoạn dài còn nhiều vữa / bong gần hết
    f = f + (0.5 - yy) * 1.6 + cover[None, :] - 0.22
    return f

def plaster_color(i, length, f, ppm=100):
    W, H = int(round(length * ppm)), int(WALL_H * ppm)
    rng = np.random.default_rng(500 + i)
    c = length / 4
    pc = np.array([0.86, 0.72, 0.38]) * (1 + 0.07 * pnoise((H, W), 12 * c, 10, 600 + i)[..., None])
    pale = np.clip(pnoise((H, W), 3 * c, 2.4, 700 + i), 0, None)[..., None] * 0.18
    pc = pc * (1 - pale) + np.array([0.86, 0.84, 0.76]) * pale
    pc = pc * (1 - 0.08 * np.clip(pnoise((H, W), 4 * c, 3.2, 800 + i), 0, None)[..., None])
    yy = np.linspace(0, 1, H)[:, None]
    streak = np.clip(pnoise((H, W), 70 * c, 2.4, 900 + i) - 0.6, 0, None) * (1 - yy) * 0.12
    pc = pc * (1 - streak[..., None]) + rng.normal(0, 0.02, (H, W, 1))
    # viền nhạt ở mép mỗi tầng (lớp sơn bong lộ vữa nhạt hơn)
    fz = ndimage.zoom(f, (H / f.shape[0], W / f.shape[1]), order=1)[:H, :W]
    rim = np.clip(1 - (fz - LEVELS[2][0]) / 0.03, 0, 1) * (fz > LEVELS[2][0])
    pc = pc * (1 - 0.25 * rim[..., None]) + np.array([0.9, 0.82, 0.55]) * 0.25 * rim[..., None]
    img = Image.fromarray((np.clip(pc, 0, 1) * 255).astype(np.uint8)).convert("RGBA")
    # giấy dán rách đã ố
    top = fz > LEVELS[2][0] + 0.05
    for k in range(int(length / 3)):
        x = rng.uniform(0, W - 140); y = rng.uniform(30, H * 0.6)
        if not top[int(y), int(x)]: continue
        w_ = rng.uniform(25, 60); h_ = rng.uniform(20, 50)
        poly = [(x + rng.uniform(-4, 4), y + rng.uniform(-4, 4)), (x + w_ + rng.uniform(-4, 4), y + rng.uniform(-4, 4)),
                (x + w_ + rng.uniform(-8, 3), y + h_ * rng.uniform(0.4, 1)), (x + rng.uniform(0, w_), y + h_ + rng.uniform(-5, 5)),
                (x + rng.uniform(-3, 5), y + h_ * rng.uniform(0.5, 1))]
        tone = int(rng.uniform(175, 215))
        sh = Image.new("RGBA", img.size, (0, 0, 0, 0)); sd = ImageDraw.Draw(sh)
        sd.polygon(poly, fill=(tone, int(tone * 0.96), int(tone * 0.86), 215))
        for j in range(int(h_ / 5)):
            sd.line([(x + 3, y + 4 + j * 5), (x + w_ * rng.uniform(0.4, 0.9), y + 4 + j * 5)], fill=(110, 105, 115, 70), width=1)
        a = np.asarray(sh)[..., 3].astype(float) * top
        sh.putalpha(Image.fromarray(a.astype(np.uint8))); img.alpha_composite(sh)
    img.convert("RGB").save(f"vua_mau_{i}.jpg", quality=88)
    return fz

def wall_detail(i, length, f, ppm=GPPM):
    """nhân lên màu gạch: bóng đổ dưới mép vữa, ố chảy, ẩm rêu chân tường"""
    H, W = f.shape
    plaster = f > LEVELS[0][0]
    sh = ndimage.shift(plaster.astype(float), (int(0.035 * ppm + 0.5), int(0.012 * ppm + 0.5)), order=0)
    sh = ndimage.gaussian_filter(np.maximum(sh, ndimage.binary_dilation(plaster, iterations=2).astype(float)), 1.5)
    yy = np.linspace(0, 1, H)[:, None]
    c = length / 4
    damp = np.clip((yy - 0.78) * 4.5 + 0.3 * pnoise((H, W), 10 * c, 8, 1000 + i), 0, 1)
    streak = np.clip(pnoise((H, W), 50 * c, 2, 1100 + i) - 0.8, 0, None) * 0.25
    m = np.ones((H, W, 3))
    m *= (1 - 0.45 * sh * (~plaster))[..., None]
    m *= (1 - streak)[..., None]
    m = m * (1 - 0.35 * damp[..., None]) + np.array([0.3, 0.36, 0.2]) * 0.35 * damp[..., None]
    Image.fromarray((np.clip(m, 0, 1) * 255).astype(np.uint8)).save(f"tuong_ban_{i}.png")

# ------------------------------------------------------------------ 3) khối vữa nhiều tầng (marching squares)
EDGE = {0: ((0, 0), (1, 0)), 1: ((1, 0), (1, 1)), 2: ((1, 1), (0, 1)), 3: ((0, 1), (0, 0))}   # cạnh ô theo góc (cx, cy)
CASE_SEG = {1: [(3, 0)], 2: [(0, 1)], 3: [(3, 1)], 4: [(1, 2)], 5: [(3, 2), (1, 0)], 6: [(0, 2)], 7: [(3, 2)],
            8: [(2, 3)], 9: [(2, 0)], 10: [(0, 3), (2, 1)], 11: [(2, 1)], 12: [(1, 3)], 13: [(1, 0)], 14: [(0, 3)]}

def build_level_mesh(f, thr, z, z_below, cell, H_m, length, thr_above=None):
    """mặt trên + thành bên của một tầng vữa; bỏ mặt trên ở ô bị tầng trên che kín"""
    ny, nx = f.shape
    ins = f > thr
    above = (f > thr_above) if thr_above is not None else np.zeros_like(ins)
    full_above = above[:-1, :-1] & above[1:, :-1] & above[:-1, 1:] & above[1:, 1:]
    top_v, top_i, side_v, side_i = [], [], [], []
    vmap = {}
    def P(gx, gy, zz):   # lưới -> toạ độ tường (x dọc, y lên, z ra phố)
        return (gx * cell, H_m - gy * cell, zz)
    def vid(gx, gy):
        key = (round(gx, 3), round(gy, 3))
        if key not in vmap:
            vmap[key] = len(top_v); top_v.append(P(gx, gy, z))
        return vmap[key]
    def add_top(poly):
        ids = [vid(gx, gy) for (gx, gy) in poly]
        for k in range(1, len(ids) - 1):
            top_i.extend([ids[0], ids[k + 1], ids[k]])     # CCW nhìn từ +z (glTF)
    def interp(c0, c1, x0, y0):
        (ax, ay), (bx, by) = c0, c1
        va, vb = f[y0 + ay, x0 + ax], f[y0 + by, x0 + bx]
        t = (thr - va) / (vb - va) if vb != va else 0.5
        t = min(max(t, 0.0), 1.0)
        return (x0 + ax + (bx - ax) * t, y0 + ay + (by - ay) * t)
    corner = [(0, 0), (1, 0), (1, 1), (0, 1)]
    for y0 in range(ny - 1):
        # hàng: chạy gộp các ô đầy
        x0 = 0
        while x0 < nx - 1:
            c = (ins[y0, x0] << 0) | (ins[y0, x0 + 1] << 1) | (ins[y0 + 1, x0 + 1] << 2) | (ins[y0 + 1, x0] << 3)
            if c == 15:
                if full_above[y0, x0]:
                    x0 += 1
                    continue
                xs = x0
                while x0 < nx - 1 and ins[y0, x0] and ins[y0, x0 + 1] and ins[y0 + 1, x0 + 1] and ins[y0 + 1, x0] and not full_above[y0, x0]:
                    x0 += 1
                add_top([(xs, y0), (x0, y0), (x0, y0 + 1), (xs, y0 + 1)])
                continue
            if c != 0:
                # đa giác phần trong ô
                pts = []
                for k in range(4):
                    ca, cb = corner[k], corner[(k + 1) % 4]
                    if ins[y0 + ca[1], x0 + ca[0]]:
                        pts.append((x0 + ca[0], y0 + ca[1]))
                    if ins[y0 + ca[1], x0 + ca[0]] != ins[y0 + cb[1], x0 + cb[0]]:
                        pts.append(interp(ca, cb, x0, y0))
                if c in (5, 10):
                    # điểm yên ngựa: tách thành hai tam giác góc
                    for k in range(4):
                        ca = corner[k]
                        if ins[y0 + ca[1], x0 + ca[0]]:
                            cp, cn = corner[(k - 1) % 4], corner[(k + 1) % 4]
                            add_top([interp(cp, ca, x0, y0), (x0 + ca[0], y0 + ca[1]), interp(ca, cn, x0, y0)])
                else:
                    add_top(pts)
                # thành bên theo đoạn đường viền
                for (e0, e1) in CASE_SEG[c]:
                    a = interp(*EDGE[e0], x0, y0); b = interp(*EDGE[e1], x0, y0)
                    pa0, pb0 = P(*a, z_below), P(*b, z_below)
                    pa1, pb1 = P(*a, z), P(*b, z)
                    dx, dy = pb0[0] - pa0[0], pb0[1] - pa0[1]
                    ln = math.hypot(dx, dy) or 1
                    nrm = (dy / ln, -dx / ln, 0.0)
                    # hướng pháp tuyến ra phía trường thấp hơn
                    mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
                    gx_ = f[y0, x0 + 1] + f[y0 + 1, x0 + 1] - f[y0, x0] - f[y0 + 1, x0]
                    gy_ = -(f[y0 + 1, x0] + f[y0 + 1, x0 + 1] - f[y0, x0] - f[y0, x0 + 1])  # y lưới ngược y tường
                    if nrm[0] * gx_ + nrm[1] * gy_ > 0:
                        nrm = (-nrm[0], -nrm[1], 0.0)
                    bse = len(side_v)
                    for p in (pa0, pb0, pb1, pa1):
                        side_v.append((p, nrm))
                    # tam giác CCW nhìn theo pháp tuyến
                    e = np.cross(np.subtract(pb0, pa0), np.subtract(pa1, pa0))
                    if np.dot(e, nrm) > 0:
                        side_i.extend([bse, bse + 1, bse + 2, bse, bse + 2, bse + 3])
                    else:
                        side_i.extend([bse, bse + 2, bse + 1, bse, bse + 3, bse + 2])
            x0 += 1
    return top_v, top_i, side_v, side_i

def write_glb(path, prims):
    """prims: list of (name_material, positions Nx3, normals Nx3, uvs Nx2 or None, indices)"""
    binb = b""; views = []; accs = []; gp = []; mats = []
    def add(arr, tgt):
        nonlocal binb
        b = arr.tobytes(); b += b"\x00" * ((4 - len(b) % 4) % 4)
        views.append({"buffer": 0, "byteOffset": len(binb), "byteLength": len(arr.tobytes()), "target": tgt}); binb += b
        return len(views) - 1
    for mi, (mname, pos, nor, uv, idx) in enumerate(prims):
        pos = np.asarray(pos, np.float32); nor = np.asarray(nor, np.float32); idx = np.asarray(idx, np.uint32)
        a = {}
        v = add(pos, 34962); accs.append({"bufferView": v, "componentType": 5126, "count": len(pos), "type": "VEC3",
                                          "min": pos.min(0).tolist(), "max": pos.max(0).tolist()}); a["POSITION"] = len(accs) - 1
        v = add(nor, 34962); accs.append({"bufferView": v, "componentType": 5126, "count": len(nor), "type": "VEC3"}); a["NORMAL"] = len(accs) - 1
        if uv is not None:
            uv = np.asarray(uv, np.float32)
            v = add(uv, 34962); accs.append({"bufferView": v, "componentType": 5126, "count": len(uv), "type": "VEC2"}); a["TEXCOORD_0"] = len(accs) - 1
        v = add(idx, 34963); accs.append({"bufferView": v, "componentType": 5125, "count": len(idx), "type": "SCALAR"})
        gp.append({"attributes": a, "indices": len(accs) - 1, "material": mi})
        mats.append({"name": mname, "pbrMetallicRoughness": {"baseColorFactor": [0.85, 0.8, 0.7, 1], "metallicFactor": 0, "roughnessFactor": 1}})
    g = {"asset": {"version": "2.0", "generator": "No60Ngay tao_tuong_lien"}, "scene": 0, "scenes": [{"nodes": [0]}],
         "nodes": [{"name": path.split("/")[-1][:-4], "mesh": 0}], "meshes": [{"primitives": gp}], "materials": mats,
         "buffers": [{"byteLength": len(binb)}], "bufferViews": views, "accessors": accs}
    jb = json.dumps(g, separators=(",", ":")).encode(); jb += b" " * ((4 - len(jb) % 4) % 4)
    with open(path, "wb") as fo:
        fo.write(struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(jb) + 8 + len(binb)))
        fo.write(struct.pack("<I4s", len(jb), b"JSON")); fo.write(jb)
        fo.write(struct.pack("<I4s", len(binb), b"BIN\x00")); fo.write(binb)

def side_mesh(i, length, f, cell=1.0 / GPPM):
    yellow = {"p": [], "n": [], "uv": [], "i": []}
    mid = {"p": [], "n": [], "uv": [], "i": []}
    white = {"p": [], "n": [], "i": []}
    prev_z = 0.0
    for li, (thr, z) in enumerate(LEVELS):
        thr_up = LEVELS[li + 1][0] + 0.02 if li + 1 < len(LEVELS) else None
        tv, ti, sv, si = build_level_mesh(f, thr, z, prev_z, cell, WALL_H, length, thr_up)
        if li == 0:   # mặt lót trắng
            b = len(white["p"]); white["p"] += tv; white["n"] += [(0, 0, 1)] * len(tv); white["i"] += [b + k for k in ti]
        else:         # li=1: vữa be (lớp trát); li=2: lớp sơn vàng. UV theo toàn chiều dài cạnh
            dst = mid if li == 1 else yellow
            b = len(dst["p"]); dst["p"] += tv; dst["n"] += [(0, 0, 1)] * len(tv)
            dst["uv"] += [(p[0] / length, 1 - p[1] / WALL_H) for p in tv]; dst["i"] += [b + k for k in ti]
        b = len(white["p"]); white["p"] += [p for p, n in sv]; white["n"] += [n for p, n in sv]; white["i"] += [b + k for k in si]
        prev_z = z
    write_glb(f"tuong_canh_{i}.glb", [("VuaVang", yellow["p"], yellow["n"], yellow["uv"], yellow["i"]),
                                       ("VuaNen", mid["p"], mid["n"], mid["uv"], mid["i"]),
                                       ("VuaTrang", white["p"], white["n"], None, white["i"])])
    return (len(yellow["i"]) + len(mid["i"]) + len(white["i"])) // 3

# ------------------------------------------------------------------ 4) chữ sơn vẽ tay
def paint_text_png(text, sub, color, seed, path):
    rng = np.random.default_rng(seed)
    size = 96 if len(text) < 10 else 70
    f = ImageFont.truetype(FONT2 if len(text) > 12 else FONT, size)
    tw = int(f.getlength(text)) + 40; th = int(size * 1.45)
    if sub:
        f2 = ImageFont.truetype(FONT, int(size * 0.6)); th += int(size * 0.85); tw = max(tw, int(f2.getlength(sub)) + 40)
    th += 40
    lay = Image.new("L", (tw, th), 0); d = ImageDraw.Draw(lay)
    d.text((20, 0), text, font=f, fill=255)
    if sub: d.text((20, int(size * 1.25)), sub, font=f2, fill=255)
    a = np.asarray(lay).astype(float) / 255
    a *= np.clip(0.7 + 0.3 * pnoise(a.shape, a.shape[1] / 20, a.shape[0] / 20, seed), 0.35, 1)
    cols = np.where(a.max(0) > 0.5)[0]
    for x in (rng.choice(cols, size=min(len(cols), 9), replace=False) if len(cols) else []):
        ys = np.where(a[:, x] > 0.5)[0]
        if len(ys):
            y0 = ys.max(); L = int(rng.integers(8, 38)); y1 = min(th, y0 + L)
            a[y0:y1, max(0, x - 1):x + 2] = np.maximum(a[y0:y1, max(0, x - 1):x + 2], np.linspace(0.85, 0, y1 - y0)[:, None])
    rgba = np.zeros((th, tw, 4), np.uint8); rgba[..., :3] = color; rgba[..., 3] = (a * 235).astype(np.uint8)
    Image.fromarray(rgba).save(path)
    return tw, th

if __name__ == "__main__":
    brick_tile()
    decals = []
    rng = np.random.default_rng(42)
    text_files = []
    for k, (t, sub) in enumerate(TEXTS):
        color = [(22, 22, 24), (150, 22, 16), (26, 46, 120)][k % 3]
        w, h = paint_text_png(t, sub, color, 70 + k, f"chu_son_{k}.png")
        text_files.append((f"chu_son_{k}.png", w, h))
    info = {}
    for i, L in enumerate(SIDES):
        f = plaster_field(i, L)
        plaster_color(i, L, f)
        wall_detail(i, L, f)
        info[i] = side_mesh(i, L, f)
        # chữ: chỉ đặt nơi lớp sơn trên cùng phủ kín cả khung chữ
        top = f > LEVELS[2][0] + 0.03
        placed = []
        for tries in range(2000):
            k = int(rng.integers(0, len(text_files)))
            fn, w, h = text_files[k]
            wm = w / 330.0; hm = h / 330.0                    # chữ cao ~20-30 cm
            x = rng.uniform(0.5, L - wm - 0.5); y = rng.uniform(1.0, WALL_H - hm - 0.2)
            c0, c1 = int(x * GPPM), int((x + wm) * GPPM); r0, r1 = int((WALL_H - y - hm) * GPPM), int((WALL_H - y) * GPPM)
            if not top[r0:r1 + 1, c0:c1 + 1].all(): continue
            if any(abs(x - px) < 6 for px in placed): continue
            placed.append(x)
            decals.append({"side": i, "file": fn, "x": round(x, 3), "y": round(y, 3), "w": round(wm, 3), "h": round(hm, 3)})
            if len(placed) >= max(2, int(L / 14)): break
    json.dump(decals, open("chu_son.json", "w"), ensure_ascii=False, indent=1)
    print(info, len(decals))
