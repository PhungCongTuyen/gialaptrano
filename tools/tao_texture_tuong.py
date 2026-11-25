# Texture tường gạch bao quanh phố: gạch đỏ, vữa vàng bong tróc, giấy dán sót lại, chữ quảng cáo vẽ tay.
# 4 biến thể (atlas 2x2). Mỗi ô = đoạn tường rộng 4 m, cao 3,2 m.
import numpy as np, math
from PIL import Image, ImageDraw, ImageFont, ImageFilter
W, H = 1024, 820
PXM = W / 4.0                      # pixel / mét
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FONT2 = "/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-Bold.ttf"

def pnoise(shape, scale, seed, sy=None):
    r = np.random.default_rng(seed); w = r.standard_normal(shape)
    fy = np.fft.fftfreq(shape[0])[:, None]; fx = np.fft.fftfreq(shape[1])[None, :]
    sy = sy or scale
    n = np.real(np.fft.ifft2(np.fft.fft2(w) * np.exp(-((fx * shape[1] / scale) ** 2 + (fy * shape[0] / sy) ** 2))))
    return (n - n.mean()) / n.std()

def bricks(seed):
    rng = np.random.default_rng(seed)
    ch = 0.07 * PXM; bl = 0.23 * PXM; mt = 0.012 * PXM
    yy, xx = np.mgrid[0:H, 0:W].astype(float)
    row = np.floor(yy / ch).astype(int)
    off = (row % 2) * bl * 0.5
    col = np.floor((xx + off) / bl).astype(int)
    lx = (xx + off) - col * bl; ly = yy - row * ch
    d_edge = np.minimum(np.minimum(lx, bl - lx), np.minimum(ly, ch - ly))
    brick = d_edge > mt * 0.5
    # màu từng viên
    nb = 4000
    ids = (row * 131 + col * 17) % nb
    base = np.array([0.74, 0.4, 0.24])
    tone = rng.normal(0, 0.025, (nb, 3)) + rng.normal(0, 0.055, (nb, 1))
    burnt = (rng.random(nb) < 0.08)[:, None] * np.array([-0.2, -0.12, -0.06])
    pale = (rng.random(nb) < 0.07)[:, None] * np.array([0.08, 0.1, 0.1])
    bc = np.clip(base + tone + burnt + pale, 0, 1)[ids]
    grain = pnoise((H, W), 160, seed + 1)[..., None] * 0.04 + rng.normal(0, 0.03, (H, W, 1))
    bc = bc * (1 + grain) * (0.86 + 0.14 * np.clip(d_edge / (mt * 2.5), 0, 1))[..., None]
    mort = np.array([0.6, 0.56, 0.5]) * (1 + 0.08 * pnoise((H, W), 90, seed + 2)[..., None])
    col_img = np.where(brick[..., None], bc, mort)
    h = np.where(brick, 0.62 + 0.04 * np.clip(d_edge / mt, 0, 1), 0.38)
    # lỗ gạch (gạch lỗ bị vỡ mặt): 2 lỗ tròn trên một số viên
    holes = np.zeros((H, W), bool)
    hv = rng.random(nb) < 0.022
    cx_list = []
    sel = hv[ids] & brick
    # tâm viên
    cxv = col * bl - off + bl / 2; cyv = row * ch + ch / 2
    for k, dx in ((0, -bl * 0.2), (1, bl * 0.2)):
        dd = (xx - (cxv + dx)) ** 2 + ((yy - cyv) * 1.0) ** 2
        holes |= sel & (dd < (ch * 0.24) ** 2)
    col_img = np.where(holes[..., None], np.array([0.12, 0.07, 0.05]), col_img)
    h = np.where(holes, 0.1, h)
    return col_img, h

def paint_text(img_rgba, text, pos, size, color, rot, seed, sub=None):
    rng = np.random.default_rng(seed)
    f = ImageFont.truetype(FONT2 if len(text) > 12 else FONT, size)
    tw = int(f.getlength(text)) + 40; th = int(size * 1.5)
    if sub:
        f2 = ImageFont.truetype(FONT, int(size * 0.6)); th += int(size * 0.9); tw = max(tw, int(f2.getlength(sub)) + 40)
    layer = Image.new("L", (tw, th), 0); d = ImageDraw.Draw(layer)
    d.text((20, 0), text, font=f, fill=255)
    if sub:
        d.text((20, int(size * 1.25)), sub, font=f2, fill=255)
    a = np.asarray(layer).astype(float) / 255
    # nét sơn không đều + vệt chảy
    a *= np.clip(0.75 + 0.35 * rng.standard_normal(a.shape) * 0 + 0.3 * pnoise(a.shape, 30, seed), 0.35, 1)
    drip = np.zeros_like(a)
    cols = np.where(a.max(0) > 0.5)[0]
    for x in rng.choice(cols, size=min(len(cols), 7), replace=False) if len(cols) else []:
        ys = np.where(a[:, x] > 0.5)[0]
        if len(ys):
            y0 = ys.max(); L = rng.integers(8, 40)
            drip[y0:y0 + L, max(0, x - 1):x + 2] = np.linspace(0.9, 0.0, len(range(y0, min(th, y0 + L))))[:, None]
    a = np.clip(a + drip, 0, 1)
    lay = Image.fromarray((a * 255).astype(np.uint8)).rotate(rot, expand=True, resample=Image.BICUBIC)
    col = Image.new("RGBA", lay.size, color + (0,)); col.putalpha(lay)
    img_rgba.alpha_composite(col, (int(pos[0]), int(pos[1])))

TEXTS = [("KHOAN CẮT BÊ TÔNG", "ĐT: 0123.456.789"), ("VÁ XE", "BƠM XE - THAY SĂM"), ("HÚT BỂ PHỐT", "THÔNG CỐNG 24/24"),
         ("KHOAN CẮT BÊ TÔNG", None), ("VÁ XE 50m →", None), ("CẤM ĐỔ RÁC", "PHẠT 2.000.000đ")]

def variant(seed, coverage, texts):
    rng = np.random.default_rng(seed)
    bc, bh = bricks(seed)
    # vùng vữa còn bám: nhiễu thô + mép vỡ sắc; trên cao còn nhiều hơn dưới chân
    yy = np.linspace(0, 1, H)[:, None]
    n = pnoise((H, W), 2.2, seed + 3) * 0.85 + pnoise((H, W), 9, seed + 4) * 0.12 + pnoise((H, W), 60, seed + 9) * 0.05
    n = n + (0.55 - yy) * 1.6 + (coverage - 0.5) * 2.0
    plaster = n > 0
    edge = np.abs(n) < 0.06
    # màu vữa vàng, loang ố, ố đen chảy từ trên xuống
    pc = np.array([0.8, 0.7, 0.46]) * (1 + 0.07 * pnoise((H, W), 12, seed + 5)[..., None])
    pale = np.clip(pnoise((H, W), 3, seed + 10), 0, None)[..., None] * 0.18
    pc = pc * (1 - pale) + np.array([0.86, 0.84, 0.76]) * pale
    pc = pc * (1 - 0.08 * np.clip(pnoise((H, W), 4, seed + 6), 0, None)[..., None])
    streak = np.clip(pnoise((H, W), 70, seed + 7, sy=3) - 0.6, 0, None) * (1 - yy) * 0.12
    pc = pc * (1 - streak[..., None]) + rng.normal(0, 0.02, (H, W, 1))
    # lớp lót trắng xám lộ ra ở mép vỡ
    under = np.array([0.82, 0.8, 0.74])
    rim = plaster & (n < 0.12)
    col = np.where(plaster[..., None], np.where(rim[..., None], under, pc), bc)
    h = np.where(plaster, 1.0, bh)
    img = Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8)).convert("RGBA")
    # giấy dán (quảng cáo cũ) rách trên mảng vữa
    d = ImageDraw.Draw(img)
    pm = Image.fromarray((plaster * 255).astype(np.uint8))
    for k in range(rng.integers(2, 6)):
        x = rng.uniform(0, W - 120); y = rng.uniform(40, H * 0.55)
        if not plaster[int(y), int(x)]:
            continue
        w_ = rng.uniform(50, 130); h_ = rng.uniform(40, 110)
        poly = [(x + rng.uniform(-8, 8), y + rng.uniform(-8, 8)), (x + w_ + rng.uniform(-8, 8), y + rng.uniform(-8, 8)),
                (x + w_ + rng.uniform(-15, 5), y + h_ * rng.uniform(0.4, 1)), (x + rng.uniform(0, w_), y + h_ + rng.uniform(-10, 10)),
                (x + rng.uniform(-5, 10), y + h_ * rng.uniform(0.5, 1))]
        tone = int(rng.uniform(175, 215))
        sheet = Image.new("RGBA", img.size, (0, 0, 0, 0)); sd = ImageDraw.Draw(sheet)
        sd.polygon(poly, fill=(tone, int(tone * 0.96), int(tone * 0.86), 210))
        for j in range(int(h_ / 9)):   # dòng chữ in mờ
            yy0 = y + 8 + j * 9
            sd.line([(x + 6, yy0), (x + w_ * rng.uniform(0.4, 0.9), yy0)], fill=(110, 105, 115, 70), width=2)
        if rng.random() < 0.5:
            sd.text((x + 8, y + 6), str(rng.integers(10, 99)), font=ImageFont.truetype(FONT, 22), fill=(40, 40, 60, 200))
        a = np.asarray(sheet)[..., 3].astype(float) * (np.asarray(pm) > 0)
        sheet.putalpha(Image.fromarray(a.astype(np.uint8)))
        img.alpha_composite(sheet)
    for i, (t, sub) in enumerate(texts):
        color = [(20, 20, 22), (150, 20, 15), (25, 45, 120)][rng.integers(0, 3)]
        size = int(rng.uniform(64, 86)) if len(t) < 10 else int(rng.uniform(44, 56))
        x = rng.uniform(30, W * 0.35); y = H * (0.1 + 0.42 * i) + rng.uniform(0, H * 0.12)
        paint_text(img, t, (x, y), size, color, rng.uniform(-4, 4), seed * 7 + i, sub)
    # rêu, ẩm chân tường
    out = np.asarray(img.convert("RGB")).astype(float) / 255
    damp = np.clip((yy - 0.78) * 4.5 + 0.3 * pnoise((H, W), 10, seed + 8), 0, 1)[..., None]
    out = out * (1 - 0.35 * damp) + np.array([0.2, 0.24, 0.12]) * 0.35 * damp
    return out, h

atlas = np.zeros((H * 2, W * 2, 3)); hat = np.zeros((H * 2, W * 2))
specs = [(11, 0.55, [TEXTS[0]]), (23, 0.35, [TEXTS[1]]), (37, 0.15, []), (51, 0.7, [TEXTS[2], TEXTS[4]])]
for i, (sd, cov, tx) in enumerate(specs):
    c, h = variant(sd, cov, tx)
    r, k = divmod(i, 2)
    atlas[r * H:(r + 1) * H, k * W:(k + 1) * W] = c; hat[r * H:(r + 1) * H, k * W:(k + 1) * W] = h
Image.fromarray((np.clip(atlas, 0, 1) * 255).astype(np.uint8)).save("tuong_gach.jpg", quality=90)
gx = (np.roll(hat, -1, 1) - np.roll(hat, 1, 1)) * 0.5; gy = (np.roll(hat, -1, 0) - np.roll(hat, 1, 0)) * 0.5
nx, ny, nz = -gx * 4, gy * 4, np.ones_like(hat); L = np.sqrt(nx ** 2 + ny ** 2 + nz ** 2)
Image.fromarray(((np.stack([nx / L, ny / L, nz / L], -1) * 0.5 + 0.5) * 255).astype(np.uint8)).save("tuong_gach_normal.png")
Image.fromarray((np.clip(atlas, 0, 1) * 255).astype(np.uint8)).resize((1024, 820)).save("prev.png")
print("ok")
