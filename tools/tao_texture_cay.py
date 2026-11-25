# Texture cho cây xanh: cành lá kép lông chim (RGBA) và vỏ cây (albedo + normal, lặp ngang).
import numpy as np, math
from PIL import Image, ImageDraw, ImageFilter
rng = np.random.default_rng(2026)

def frond(path, base, tip_light, seed, pairs=13, W=512, H=1024):
    r = np.random.default_rng(seed)
    S = 2  # vẽ to rồi thu nhỏ cho mịn
    im = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx = W * S / 2
    y0, y1 = H * S * 0.98, H * S * 0.03
    # cuống chính hơi cong
    pts = []
    for i in range(41):
        t = i / 40
        x = cx + math.sin(t * math.pi) * W * S * 0.03
        pts.append((x, y0 + (y1 - y0) * t))
    for j in range(pairs):
        t = 0.12 + 0.86 * j / (pairs - 1)
        px, py = pts[int(t * 40)]
        L = W * S * (0.36 - 0.13 * abs(t - 0.45) ** 1.2) * r.uniform(0.9, 1.08)
        wd = L * r.uniform(0.27, 0.33)
        for side in (-1, 1):
            ang = math.radians(r.uniform(52, 64))
            dx, dy = math.sin(ang) * side, -math.cos(ang)
            # lá chét hình mũi mác: đa giác quanh trục
            poly = []
            n = 18
            for k in range(n + 1):
                u = k / n
                w = wd * 0.5 * math.sin(math.pi * u) ** 0.75
                poly.append((u, w))
            outline = [(px + dx * L * u - dy * w * 0 + (-dy) * w, py + dy * L * u + dx * w) for u, w in poly] + \
                      [(px + dx * L * u - (-dy) * w, py + dy * L * u - dx * w) for u, w in reversed(poly)]
            shade = r.uniform(0.82, 1.12)
            tl = t ** 2 * tip_light
            col = tuple(int(min(255, (base[c] * (1 - tl) + (base[c] * 1.35 + 25) * tl) * shade)) for c in range(3))
            d.polygon(outline, fill=col + (255,))
            # gân giữa lá chét
            d.line([(px, py), (px + dx * L * 0.92, py + dy * L * 0.92)], fill=tuple(min(255, int(c * 1.25 + 18)) for c in col) + (255,), width=max(1, S))
        # lá chét đỉnh
    tx, ty = pts[-1]
    L = W * S * 0.3; wd = L * 0.3
    poly = [(tx - wd / 2 * math.sin(math.pi * u) ** 0.75, ty - L * u) for u in np.linspace(0, 1, 18)] + [(tx + wd / 2 * math.sin(math.pi * u) ** 0.75, ty - L * u) for u in np.linspace(1, 0, 18)]
    d.polygon(poly, fill=tuple(int(c * 1.1) for c in base) + (255,))
    d.line(pts, fill=(int(base[0] * 0.8 + 40), int(base[1] * 0.8 + 35), int(base[2] * 0.7 + 10), 255), width=4 * S)
    im = im.resize((W, H), Image.LANCZOS)
    a = np.asarray(im).astype(float)
    # nhiễu nhẹ trong lá
    n = rng.normal(0, 6, a.shape[:2])
    for c in range(3):
        a[..., c] = np.clip(a[..., c] + n * (a[..., 3] > 0), 0, 255)
    # giãn màu ra vùng trong suốt (tránh viền đen khi mipmap)
    rgb = Image.fromarray(a[..., :3].astype(np.uint8)); alpha = a[..., 3]
    filled = rgb.filter(ImageFilter.MaxFilter(9))
    m = (alpha > 10)[..., None]
    out = np.where(m, a[..., :3], np.asarray(filled).astype(float))
    Image.fromarray(np.dstack([out, alpha]).astype(np.uint8), "RGBA").save(path)

frond("la_kep_dam.png", (38, 78, 30), 0.25, 1)
frond("la_kep_vua.png", (52, 96, 36), 0.35, 2, pairs=14)
frond("la_kep_non.png", (88, 132, 48), 0.5, 3, pairs=12)
# ghép 3 biến thể thành 1 atlas ngang 1536x1024
atlas = Image.new("RGBA", (1536, 1024))
for i, f in enumerate(["la_kep_dam.png", "la_kep_vua.png", "la_kep_non.png"]):
    atlas.paste(Image.open(f), (i * 512, 0))
atlas.save("la_cay_atlas.png")

# ---- vỏ cây: xám nâu, vết nứt dọc, lặp ngang (u) và dọc (v)
S = 512
def pnoise(sx, sy, seed):
    r = np.random.default_rng(seed); w = r.standard_normal((S, S))
    fy = np.fft.fftfreq(S)[:, None]; fx = np.fft.fftfreq(S)[None, :]
    n = np.real(np.fft.ifft2(np.fft.fft2(w) * np.exp(-((fx * S / sx) ** 2 + (fy * S / sy) ** 2))))
    return (n - n.mean()) / n.std()
fiss = pnoise(24, 4, 5)                  # vết nứt chạy dọc
ridges = np.clip(1 - np.abs(fiss) * 0.9, 0, 1) ** 2
fine = pnoise(80, 30, 6)
blot = pnoise(5, 3, 7)
H = ridges * 0.8 + fine * 0.08 + 0.1 * blot
base = np.array([0.43, 0.39, 0.34])
col = base[None, None, :] * (0.65 + 0.45 * H[..., None]) * (1 + 0.06 * blot[..., None])
lich = np.clip(pnoise(8, 6, 8) - 1.2, 0, 1)[..., None]   # vệt rêu/địa y nhạt
col = col * (1 - 0.5 * lich) + np.array([0.55, 0.58, 0.45]) * 0.5 * lich
Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8)).save("vo_cay.png")
gx = (np.roll(H, -1, 1) - np.roll(H, 1, 1)) * 0.5; gy = (np.roll(H, -1, 0) - np.roll(H, 1, 0)) * 0.5
nx, ny, nz = -gx * 5, gy * 5, np.ones_like(H); L = np.sqrt(nx ** 2 + ny ** 2 + nz ** 2)
Image.fromarray(((np.stack([nx / L, ny / L, nz / L], -1) * 0.5 + 0.5) * 255).astype(np.uint8)).save("vo_cay_normal.png")
print("ok")
