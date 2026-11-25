import numpy as np
from PIL import Image, ImageFilter
W, Hh = 512, 256   # u dọc phiến lá (0 = cuống, 1 = chóp), v ngang lá
u = (np.arange(W) + 0.5) / W
v = (np.arange(Hh) + 0.5) / Hh
U, V = np.meshgrid(u, v)
dv = np.abs(V - 0.5)
half = 0.5 * np.sin(np.pi * U) ** 0.8 + 1e-4            # mép lá (khớp hình mesh)
rel = np.clip(dv / half, 0, 1)                           # 0 = gân giữa, 1 = mép lá

def periodic_noise(shape, scale, seed):
    r = np.random.default_rng(seed)
    w = r.standard_normal(shape)
    fy = np.fft.fftfreq(shape[0])[:, None]; fx = np.fft.fftfreq(shape[1])[None, :]
    f = np.exp(-((fx * shape[1]) ** 2 + (fy * shape[0]) ** 2) / scale ** 2)
    n = np.real(np.fft.ifft2(np.fft.fft2(w) * f)); return (n - n.mean()) / n.std()

# gân giữa
mid = np.exp(-(dv / (0.012 + 0.012 * (1 - U))) ** 2)
# gân phụ: chạy chéo về phía chóp, hơi cong
lat = np.zeros_like(U)
for k in range(9):
    u0 = 0.06 + k * 0.095
    curve = u0 + 0.35 * dv + 1.1 * dv ** 2               # gân xiên về chóp
    d = np.abs(U - curve)
    lat = np.maximum(lat, np.exp(-(d / 0.006) ** 2) * (rel < 0.9) * (1 - 0.7 * rel))
# gân nhỏ dạng lưới
net = periodic_noise(U.shape, 60, 3)
fine = np.exp(-(np.abs(net) / 0.18) ** 2) * 0.35
veins = np.clip(mid + lat * 0.8 + fine * (1 - rel) * 0.6, 0, 1)

VARIANTS = {
    "la_vang":      dict(base=(0.86, 0.66, 0.14), vein=(0.96, 0.85, 0.45), spot=(0.55, 0.33, 0.08), green=0.0),
    "la_vang_xanh": dict(base=(0.74, 0.68, 0.18), vein=(0.90, 0.86, 0.45), spot=(0.50, 0.40, 0.10), green=0.6),
    "la_cam":       dict(base=(0.80, 0.40, 0.10), vein=(0.92, 0.62, 0.28), spot=(0.45, 0.18, 0.05), green=0.0),
    "la_nau":       dict(base=(0.48, 0.30, 0.13), vein=(0.62, 0.44, 0.22), spot=(0.28, 0.16, 0.07), green=0.0),
}
for i, (name, c) in enumerate(VARIANTS.items()):
    n1 = periodic_noise(U.shape, 8, 10 + i)[..., None]
    n2 = periodic_noise(U.shape, 30, 20 + i)[..., None]
    base = np.array(c["base"]) * (1 + 0.07 * n1) * (1 + 0.04 * n2)
    if c["green"] > 0:                                    # còn xanh dọc gân giữa
        g = (np.exp(-(rel / 0.45) ** 2) * c["green"] * np.clip(0.6 + 0.4 * n1[..., 0], 0, 1))[..., None]
        base = base * (1 - g) + np.array([0.42, 0.55, 0.15]) * g
    # đốm úa, mép cháy nâu
    spots = np.clip(periodic_noise(U.shape, 25, 40 + i) - 1.7, 0, 1)[..., None]
    edge = np.clip((rel - 0.82) / 0.18, 0, 1)[..., None] ** 1.5
    tip = np.clip((U - 0.85) / 0.15, 0, 1)[..., None]
    col = base * (1 - 0.7 * spots) + np.array(c["spot"]) * 0.7 * spots
    col = col * (1 - 0.55 * np.maximum(edge, tip * 0.6)) + np.array(c["spot"]) * 0.55 * np.maximum(edge, tip * 0.6)
    vv = veins[..., None]
    col = col * (1 - 0.75 * vv) + np.array(c["vein"]) * 0.75 * vv
    Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8)).save(f"{name}.png")
# normal map: gân nổi
Hm = veins * 1.0 + 0.15 * net * (1 - rel)
gx = (np.roll(Hm, -1, 1) - np.roll(Hm, 1, 1)) * 0.5
gy = (np.roll(Hm, -1, 0) - np.roll(Hm, 1, 0)) * 0.5
nx, ny, nz = -gx * 3.0, gy * 3.0, np.ones_like(Hm)
L = np.sqrt(nx ** 2 + ny ** 2 + nz ** 2)
Image.fromarray(((np.stack([nx / L, ny / L, nz / L], -1) * 0.5 + 0.5) * 255).astype(np.uint8)).save("la_normal.png")
# xem trước: ghép 4 lá (cắt theo hình lá)
prev = Image.new("RGB", (W, Hh * 4), (60, 60, 60))
mask = Image.fromarray(((dv < half) * 255).astype(np.uint8))
for i, name in enumerate(VARIANTS):
    prev.paste(Image.open(f"{name}.png"), (0, Hh * i), mask)
prev.save("la_preview.png")
print("ok")
