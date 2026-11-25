import numpy as np
from PIL import Image
rng = np.random.default_rng(1125)
N = 8                 # số viên mỗi chiều trong 1 lần lặp
P = 256               # px mỗi viên (chu kỳ)
S = N * P
g = 5.0               # rộng kẽ (px)
bev = 9.0             # độ vát mép
r = P / 2 - g / 2     # bán kính trong bát giác
k = P - np.sqrt(2) * (r + g)

def pnoise(size, scale, seed):
    """nhiễu tuần hoàn (lặp liền mạch) bằng lọc FFT"""
    rr = np.random.default_rng(seed)
    w = rr.standard_normal((size, size))
    f = np.fft.fftfreq(size)
    fx, fy = np.meshgrid(f, f)
    rad = np.sqrt(fx**2 + fy**2) * size / scale
    filt = np.exp(-rad**2)
    n = np.real(np.fft.ifft2(np.fft.fft2(w) * filt))
    n = (n - n.mean()) / (n.std() + 1e-9)
    return n

yy, xx = np.mgrid[0:S, 0:S].astype(np.float32) + 0.5
ci = np.floor(xx / P).astype(int); cj = np.floor(yy / P).astype(int)
lx = xx - (ci + 0.5) * P; ly = yy - (cj + 0.5) * P
ax, ay = np.abs(lx), np.abs(ly)
CH = 1.47
d_oct = r - np.maximum(np.maximum(ax, ay), (ax + ay) / CH)
# góc gần nhất -> ô vuông xoay 45°
qx = xx - np.round(xx / P) * P; qy = yy - np.round(yy / P) * P
kk = P - CH * r - g * 1.25
d_sq = (kk - (np.abs(qx) + np.abs(qy))) / np.sqrt(2)
is_sq = d_sq > d_oct
d = np.where(is_sq, d_sq, d_oct)
inside = d > 0
h = np.clip(d / bev, 0, 1); h = h * h * (3 - 2 * h)        # độ cao (vát mép mềm)

# màu từng viên
pink = np.array([0.55, 0.31, 0.28]); yellow = np.array([0.55, 0.31, 0.28]); grey = np.array([0.76, 0.68, 0.45])
di = np.abs(np.arange(N) - 3.5)
band = np.add.outer(di, di)                  # [j,i]
is_yel_tile = (np.abs(band - 4) < 0.6) | (band < 1.5)
tile_var = rng.normal(0, 0.015, (N, N, 3)) + rng.normal(0, 0.03, (N, N, 1))
fade = rng.uniform(-0.04, 0.06, (N, N, 1))   # viên bạc màu
base = np.where(is_yel_tile[..., None], yellow, pink)[None] if False else None
col_tile = np.where(is_yel_tile[..., None], yellow, pink) + tile_var + fade * np.array([1, 1, 1])
C = col_tile[cj % N, ci % N]
sq_i = (np.round(xx / P).astype(int)) % N; sq_j = (np.round(yy / P).astype(int)) % N
sq_var = rng.normal(0, 0.03, (N, N, 1))
Csq = grey + sq_var[sq_j, sq_i]
col = np.where(is_sq[..., None], Csq, C)

# hạt bê tông + loang màu
grain = rng.standard_normal((S, S, 1)) * 0.025
blot = pnoise(S, 24, 2)[..., None]
col = col * (1 + 0.035 * blot) + grain
# mép viên sẫm hơn (bụi bám)
edge = (1 - h)[..., None]
rim = np.clip(1 - np.abs(d - bev * 0.55) / (bev * 0.45), 0, 1)[..., None] * inside[..., None]
col = col * (1 - 0.18 * edge) + 0.05 * rim

# kẽ gạch: vữa/đất
grout = np.array([0.52, 0.48, 0.40]) + rng.standard_normal((S, S, 1)) * 0.03
col = np.where(inside[..., None], col, grout)

# rêu: nhiều ở kẽ, lan ra mép viên theo vùng nhiễu
mn = pnoise(S, 10, 7) * 0.7 + pnoise(S, 40, 8) * 0.3
patch = np.clip((mn - 0.4) * 1.2, 0, 1)                       # vùng ẩm có rêu
fine = pnoise(S, 160, 9)
moss_in_gap = (~inside) * np.clip(0.15 + patch * 1.4 + 0.2 * fine, 0, 1)
moss_edge = inside * np.clip((1 - np.clip(d / 14, 0, 1)) * (patch * 1.3 + 0.1) + 0.15 * fine * patch - 0.2, 0, 1)
moss_flat = inside * np.clip((patch - 0.85) * 1.2 + 0.1 * fine, 0, 0.3)   # mảng rêu mỏng trên mặt gạch
m = np.clip(moss_in_gap + moss_edge + moss_flat, 0, 1)[..., None]
mosscol = np.stack([0.20 + 0.04 * fine, 0.26 + 0.05 * fine, 0.12 + 0.02 * fine], -1)
col = col * (1 - m * 0.85) + mosscol * (m * 0.85)

# vết bẩn, nước đọng, vết mòn
stain = np.clip(pnoise(S, 14, 11) - 1.1, 0, 1)[..., None]
col = col * (1 - 0.22 * stain)
wear = np.clip(pnoise(S, 6, 12) - 0.6, 0, 1)[..., None]
col = col + 0.08 * wear * inside[..., None]
spots = (rng.random((S, S)) < 0.0006)
from PIL import ImageFilter
sp = np.array(Image.fromarray((spots * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2.5)), np.float32) / 255
col = col * (1 - np.clip(sp * 6, 0, 0.5))[..., None]          # đốm kẹo cao su / vết đen
col = np.clip(col, 0, 1)
Image.fromarray((col * 255).astype(np.uint8)).save('/home/claude/tex/via_he_albedo.jpg', quality=92)

# normal map (OpenGL, Y+)
H = h * 1.0 + 0.04 * pnoise(S, 300, 13) * inside + 0.25 * moss_in_gap * 0.4
gx = (np.roll(H, -1, 1) - np.roll(H, 1, 1)) * 0.5
gy = (np.roll(H, -1, 0) - np.roll(H, 1, 0)) * 0.5
strength = 6.0
nx, ny, nz = -gx * strength, gy * strength, np.ones_like(H)
L = np.sqrt(nx**2 + ny**2 + nz**2)
n = np.stack([nx / L, ny / L, nz / L], -1) * 0.5 + 0.5
Image.fromarray((n * 255).astype(np.uint8)).save('/home/claude/tex/via_he_normal.png')
# roughness: rêu và kẽ nhám hơn, mặt gạch mòn hơi bóng
rough = np.clip(0.82 + 0.1 * m[..., 0] + 0.1 * (~inside) - 0.1 * wear[..., 0] + 0.03 * fine, 0, 1)
Image.fromarray((rough * 255).astype(np.uint8)).save('/home/claude/tex/via_he_rough.png')
print("ok", S)
