# -*- coding: utf-8 -*-
"""Texture phòng giám đốc: sàn gỗ, vân gỗ óc chó, tranh sơn thủy, biển tên, bằng khen, thảm.
Chạy: python3 tools/tao_texture_phong_giam_doc.py -> textures/phong_giam_doc/*.png"""
import math, os, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy.ndimage import gaussian_filter

GOC = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(GOC, "textures", "phong_giam_doc")
os.makedirs(OUT, exist_ok=True)
FD = "/usr/share/fonts/truetype/dejavu/"
F = lambda s, b=False, serif=False: ImageFont.truetype(FD + ("DejaVuSerif" if serif else "DejaVuSans") + ("-Bold" if b else "") + ".ttf", s)
rng = np.random.default_rng(9)


def van(S, rings=26.0, stretch=10.0, seed=0):
    """vân gỗ: vòng năm bị nhiễu, kéo dài theo trục dọc"""
    r = np.random.default_rng(seed)
    y, x = np.mgrid[0:S, 0:S].astype(np.float32) / S
    n1 = gaussian_filter(r.normal(0, 1, (S, S)), (S / 6, S / 60), mode="wrap")
    n1 /= n1.std() + 1e-6
    n2 = gaussian_filter(r.normal(0, 1, (S, S)), (S / 40, 1.2), mode="wrap")
    n2 /= n2.std() + 1e-6
    v = np.sin((x * rings + n1 * 1.6) * 2 * math.pi) * 0.5 + 0.5
    v = v ** 3
    return v, n2


def san_go():
    """sàn gỗ sồi: ván 15 cm, dài 1,2 m, so le; ảnh 1024 = 2 m"""
    S = 1024
    img = np.zeros((S, S, 3), np.float32)
    plank_w = int(S * 0.15 / 2.0)
    plank_l = int(S * 1.2 / 2.0)
    base = np.array([0.62, 0.42, 0.24])
    for i in range(S // plank_w + 1):
        off = int(rng.integers(0, plank_l))
        for j in range(-1, S // plank_l + 2):
            y0 = i * plank_w; x0 = j * plank_l + off
            tone = base * rng.uniform(0.8, 1.12)
            g, n2 = van(256, rings=rng.uniform(5, 9), seed=int(rng.integers(0, 9999)))
            tile = np.array(Image.fromarray((g * 255).astype(np.uint8)).resize((plank_l, plank_w), Image.BILINEAR)) / 255.0
            n2t = np.array(Image.fromarray(((n2 * 0.5 + 0.5).clip(0, 1) * 255).astype(np.uint8)).resize((plank_l, plank_w))) / 255.0
            col = tone[None, None, :] * (0.82 + 0.18 * tile[..., None]) * (0.94 + 0.12 * n2t[..., None])
            ys, xs = slice(y0, min(S, y0 + plank_w)), slice(max(0, x0), min(S, x0 + plank_l))
            if xs.start >= xs.stop or ys.start >= ys.stop:
                continue
            img[ys, xs] = col[: ys.stop - ys.start, xs.start - x0: xs.stop - x0]
            img[y0:y0 + 2, xs] *= 0.55
            if 0 <= x0 < S:
                img[ys, x0:x0 + 2] *= 0.55
    Image.fromarray((img.clip(0, 1) * 255).astype(np.uint8)).save(os.path.join(OUT, "san_go.png"))


def van_go_oc():
    S = 512
    g, n2 = van(S, rings=14, seed=3)
    base = np.array([0.36, 0.2, 0.11])
    col = base[None, None, :] * (0.85 + 0.22 * g[..., None]) * (0.94 + 0.08 * n2[..., None])
    Image.fromarray((col.clip(0, 1) * 255).astype(np.uint8)).save(os.path.join(OUT, "van_go_oc.png"))


def tranh_son_thuy():
    """tranh thủy mặc: núi chồng lớp, sương, thác, thuyền nhỏ, dấu triện đỏ"""
    Wt, Ht = 1500, 780
    paper = np.ones((Ht, Wt, 3), np.float32) * np.array([0.93, 0.88, 0.76])
    paper *= (0.97 + 0.03 * gaussian_filter(rng.normal(0, 1, (Ht, Wt)), 2)[..., None])
    ink = np.zeros((Ht, Wt), np.float32)
    xs = np.arange(Wt)
    for layer, (base_y, amp, dark, blur) in enumerate(((0.42, 0.28, 0.35, 6), (0.55, 0.22, 0.55, 3), (0.72, 0.16, 0.8, 1.5))):
        prof = np.zeros(Wt)
        for k in range(1, 7):
            prof += np.sin(xs / Wt * math.pi * (k * 1.3) + rng.uniform(0, 6)) * amp / k * rng.uniform(0.5, 1.0)
        prof += gaussian_filter(rng.normal(0, 1, Wt), 8) * 0.02
        top = (base_y - np.abs(prof) * 0.9) * Ht
        m = np.zeros((Ht, Wt), np.float32)
        yy = np.arange(Ht)[:, None]
        d = yy - top[None, :]
        m = np.clip(1 - np.exp(-np.clip(d, 0, None) / (Ht * 0.06)), 0, 1)
        m *= np.clip(1 - (yy / Ht - base_y - 0.12) * 3, 0, 1)   # tan vào sương dưới chân núi
        tex = gaussian_filter(rng.normal(0, 1, (Ht, Wt)), (6, 1.2))
        m *= np.clip(0.75 + 0.5 * tex, 0, 1.2)
        m = gaussian_filter(m, blur)
        ink = np.maximum(ink, m * dark)
    # thác nước & sông
    ink[int(Ht * 0.45):int(Ht * 0.7), int(Wt * 0.62):int(Wt * 0.625)] *= 0.2
    ink[int(Ht * 0.86):, :] *= 0.15
    img = paper * (1 - ink[..., None] * np.array([0.82, 0.84, 0.86]))
    im = Image.fromarray((img.clip(0, 1) * 255).astype(np.uint8))
    d = ImageDraw.Draw(im)
    # thuyền
    d.polygon([(380, 700), (440, 700), (430, 712), (390, 712)], fill=(40, 38, 34))
    d.line([(410, 700), (410, 670)], fill=(40, 38, 34), width=2)
    # chim
    for bx, by in ((1050, 140), (1090, 120), (1120, 150)):
        d.arc([bx, by, bx + 22, by + 12], 200, 340, fill=(50, 48, 44), width=2)
    # chữ thư pháp dọc + triện đỏ
    for i, ch in enumerate("TÂM AN"):
        d.text((1360, 90 + i * 56), ch, font=F(46, True, True), fill=(30, 28, 25))
    d.rectangle([1362, 440, 1410, 488], fill=(170, 30, 25))
    d.text((1368, 448), "60", font=F(28, True, True), fill=(240, 220, 200))
    im.save(os.path.join(OUT, "tranh_son_thuy.png"))


def bang_ten():
    im = Image.new("RGB", (520, 160), (12, 12, 12))
    d = ImageDraw.Draw(im)
    d.rectangle([8, 8, 511, 151], outline=(190, 140, 60), width=4)
    t = "GIÁM ĐỐC"
    w = d.textlength(t, font=F(64, True, True))
    d.text(((520 - w) / 2, 40), t, font=F(64, True, True), fill=(215, 170, 80))
    im.save(os.path.join(OUT, "bang_ten.png"))


def bang_khen():
    im = Image.new("RGB", (840, 640), (246, 236, 205))
    d = ImageDraw.Draw(im)
    for k, c in ((14, (180, 30, 30)), (30, (200, 160, 70))):
        d.rectangle([k, k, 840 - k, 640 - k], outline=c, width=6)
    def ct(y, s, size, b=False, col=(150, 25, 25)):
        w = d.textlength(s, font=F(size, b, True)); d.text(((840 - w) / 2, y), s, font=F(size, b, True), fill=col)
    ct(70, "BẰNG KHEN", 64, True)
    ct(170, "Tặng: Công ty TNHH Giải pháp Số Minh Long", 26, False, (40, 30, 20))
    ct(215, "Đã có thành tích xuất sắc trong", 24, False, (40, 30, 20))
    ct(250, "chuyển đổi số năm 2026", 24, True, (40, 30, 20))
    d.ellipse([360, 380, 480, 500], outline=(190, 30, 30), width=6)
    d.ellipse([382, 402, 458, 478], outline=(190, 30, 30), width=3)
    ct(540, "Hà Nội, ngày 15 tháng 10 năm 2026", 22, False, (60, 50, 40))
    im.save(os.path.join(OUT, "bang_khen.png"))


def tham_trai():
    """thảm hoa văn kiểu Ba Tư, đỏ đô viền kem"""
    Wt, Ht = 600, 820
    im = Image.new("RGB", (Wt, Ht), (110, 22, 20)); d = ImageDraw.Draw(im)
    for k, c in ((0, (40, 30, 50)), (18, (190, 160, 110)), (34, (110, 22, 20)), (60, (40, 30, 50)), (70, (110, 22, 20))):
        d.rectangle([k, k, Wt - k, Ht - k], fill=c)
    for i in range(0, Wt, 30):
        d.polygon([(i, 26), (i + 15, 18), (i + 30, 26), (i + 15, 34)], fill=(150, 40, 30))
        d.polygon([(i, Ht - 26), (i + 15, Ht - 18), (i + 30, Ht - 26), (i + 15, Ht - 34)], fill=(150, 40, 30))
    cx, cy = Wt / 2, Ht / 2
    for r_, c in ((230, (190, 160, 110)), (200, (40, 30, 50)), (150, (150, 40, 30)), (90, (190, 160, 110)), (50, (40, 30, 50))):
        d.polygon([(cx, cy - r_ * 1.3), (cx + r_, cy), (cx, cy + r_ * 1.3), (cx - r_, cy)], fill=c)
    for (x, y) in ((140, 160), (Wt - 140, 160), (140, Ht - 160), (Wt - 140, Ht - 160)):
        d.ellipse([x - 40, y - 40, x + 40, y + 40], fill=(190, 160, 110)); d.ellipse([x - 22, y - 22, x + 22, y + 22], fill=(150, 40, 30))
    a = np.asarray(im).astype(np.float32) / 255
    a *= (0.9 + 0.1 * gaussian_filter(rng.normal(0, 1, (Ht, Wt)), 0.8))[..., None]
    Image.fromarray((a.clip(0, 1) * 255).astype(np.uint8)).save(os.path.join(OUT, "tham_trai.png"))


san_go(); van_go_oc(); tranh_son_thuy(); bang_ten(); bang_khen(); tham_trai()
print("xong", sorted(os.listdir(OUT)))
