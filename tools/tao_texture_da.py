# Tạo texture chi tiết cho da tay và vải tay áo (lặp liền mạch), dùng chiếu triplanar trong Godot.
import numpy as np
from PIL import Image
S = 512
rng = np.random.default_rng(77)

def pnoise(scale, seed):
    r = np.random.default_rng(seed)
    w = r.standard_normal((S, S))
    f = np.fft.fftfreq(S)
    fx, fy = np.meshgrid(f, f)
    n = np.real(np.fft.ifft2(np.fft.fft2(w) * np.exp(-((fx * S) ** 2 + (fy * S) ** 2) / scale ** 2)))
    return (n - n.mean()) / n.std()

def save_normal(H, strength, path):
    gx = (np.roll(H, -1, 1) - np.roll(H, 1, 1)) * 0.5
    gy = (np.roll(H, -1, 0) - np.roll(H, 1, 0)) * 0.5
    nx, ny, nz = -gx * strength, gy * strength, np.ones_like(H)
    L = np.sqrt(nx ** 2 + ny ** 2 + nz ** 2)
    Image.fromarray(((np.stack([nx / L, ny / L, nz / L], -1) * 0.5 + 0.5) * 255).astype(np.uint8)).save(path)

# ---- da: màu (nhân với màu da) - loang đỏ nhẹ, đốm, tàn nhang lác đác
mott = pnoise(6, 1)[..., None]
mott2 = pnoise(20, 2)[..., None]
base = np.ones((S, S, 3))
base *= 1 + 0.035 * mott2
redness = np.clip(pnoise(9, 3), 0, None)[..., None]
base = base * (1 - 0.06 * redness) + np.array([1.0, 0.82, 0.8]) * 0.06 * redness
fr = (rng.random((S, S)) < 0.0007).astype(float)
from PIL import ImageFilter
fr = np.array(Image.fromarray((fr * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.6)), float)[..., None] / 255
base = base * (1 - np.clip(fr * 5, 0, 0.18) * np.array([0.6, 0.75, 0.85]))
base += rng.normal(0, 0.012, (S, S, 1))
Image.fromarray((np.clip(base * 0.97, 0, 1) * 255).astype(np.uint8)).save("da_chi_tiet.png")

# ---- da: normal - lỗ chân lông + vân da chéo nhỏ
pores = np.zeros((S, S))
pts = rng.integers(0, S, (5200, 2))
pores[pts[:, 0], pts[:, 1]] = 1.0
pores = np.array(Image.fromarray((pores * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.9)), float) / 255
yy, xx = np.mgrid[0:S, 0:S] / S
cross = np.abs(np.sin((xx + yy) * np.pi * 46 + pnoise(14, 5) * 0.8)) ** 12 + np.abs(np.sin((xx - yy) * np.pi * 38 + pnoise(14, 6) * 0.8)) ** 12
H = -pores * 2.2 - cross * 0.25 + pnoise(40, 7) * 0.06
save_normal(H, 2.0, "da_normal.png")
# nhám: lỗ chân lông và nếp nhám hơn
rough = np.clip(0.55 + pores * 0.25 + cross * 0.05 + pnoise(12, 8) * 0.04, 0, 1)
Image.fromarray((rough * 255).astype(np.uint8)).save("da_nham.png")

# ---- vải tay áo: vân dệt chéo (twill)
k = 64  # số sợi mỗi chiều
u = xx * k; v = yy * k
warp = (np.sin(u * 2 * np.pi) * 0.5 + 0.5)
weft = (np.sin(v * 2 * np.pi) * 0.5 + 0.5)
twill = ((np.floor(u) + np.floor(v)) % 4 < 2).astype(float)
Hf = np.where(twill > 0, warp, weft) + pnoise(30, 9) * 0.15
save_normal(Hf, 1.6, "vai_normal.png")
fab = np.ones((S, S, 3)) * (0.93 + 0.07 * Hf[..., None]) * (1 + 0.04 * pnoise(5, 10)[..., None])
Image.fromarray((np.clip(fab, 0, 1) * 255).astype(np.uint8)).save("vai_chi_tiet.png")
print("ok")
