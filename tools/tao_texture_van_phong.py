# -*- coding: utf-8 -*-
"""Texture cho văn phòng intro: màn hình máy tính, bảng trắng, mặt đồng hồ, thảm, trần, cảnh phố ngoài cửa sổ.
Chạy: python3 tools/tao_texture_van_phong.py  -> textures/van_phong/*.png"""
import math, os, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

GOC = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(GOC, "textures", "van_phong")
os.makedirs(OUT, exist_ok=True)
FD = "/usr/share/fonts/truetype/dejavu/"
F = lambda s, b=False: ImageFont.truetype(FD + ("DejaVuSans-Bold.ttf" if b else "DejaVuSans.ttf"), s)
FM = lambda s: ImageFont.truetype(FD + "DejaVuSansMono.ttf", s)
R = random.Random(45)
SW, SH = 1024, 580


def chrome(d, title, accent):
    d.rectangle([0, 0, SW, 34], fill=(32, 34, 38))
    d.text((14, 8), title, font=F(16), fill=(220, 220, 220))
    d.rectangle([0, 34, SW, 74], fill=accent)
    for i, t in enumerate(["Tệp", "Trang chủ", "Chèn", "Bố cục", "Dữ liệu", "Xem"]):
        d.text((16 + i * 110, 45), t, font=F(15), fill=(255, 255, 255))
    d.rectangle([0, SH - 26, SW, SH], fill=(225, 225, 225))


def bang_tinh():
    im = Image.new("RGB", (SW, SH), (255, 255, 255)); d = ImageDraw.Draw(im)
    chrome(d, "Doanh_thu_Q4_2026.xlsx - Excel", (33, 115, 70))
    d.rectangle([0, 74, SW, 104], fill=(245, 245, 245))
    d.text((10, 80), "fx   =SUM(D5:D40)", font=FM(15), fill=(60, 60, 60))
    cw, rh, x0, y0 = 118, 24, 46, 112
    heads = ["Mã", "Khách hàng", "Khu vực", "Doanh thu", "Chi phí", "Lợi nhuận", "% Tăng", "Ghi chú"]
    for c in range(8):
        d.rectangle([x0 + c * cw, y0, x0 + (c + 1) * cw, y0 + rh], fill=(230, 236, 230), outline=(200, 200, 200))
        d.text((x0 + c * cw + 6, y0 + 4), heads[c], font=F(14, True), fill=(30, 30, 30))
    names = ["Minh Phát", "Hòa Bình", "Thành Công", "Việt Tín", "An Khang", "Đại Dương", "Kim Long", "Sao Mai", "Tân Tiến", "Phú Gia", "Hưng Thịnh", "Nam Việt", "Đông Á", "Hồng Hà", "Thăng Long", "Bảo Châu", "Trường Sơn", "Ngọc Lan"]
    for r in range(18):
        y = y0 + (r + 1) * rh
        for c in range(8):
            d.rectangle([x0 + c * cw, y, x0 + (c + 1) * cw, y + rh], outline=(215, 215, 215), fill=(255, 255, 255) if r != 6 else (255, 247, 200))
        dt = R.randint(120, 980)
        cp = int(dt * R.uniform(0.5, 0.9))
        vals = ["KH%03d" % (r + 11), names[r], R.choice(["Hà Nội", "HCM", "Đà Nẵng", "Hải Phòng"]), "{:,}".format(dt * 1000000)[:11], "{:,}".format(cp * 1000000)[:11], "{:,}".format((dt - cp) * 1000000)[:11], "%+.1f%%" % R.uniform(-12, 25), ""]
        for c in range(8):
            col = (30, 30, 30) if c != 6 else ((20, 130, 50) if not vals[6].startswith("-") else (190, 30, 30))
            d.text((x0 + c * cw + 6, y + 4), vals[c], font=F(14), fill=col)
    for r in range(19):
        d.text((8, y0 + r * rh + 4), str(r + 4), font=F(13), fill=(110, 110, 110))
    return im


def code():
    im = Image.new("RGB", (SW, SH), (30, 31, 36)); d = ImageDraw.Draw(im)
    d.rectangle([0, 0, SW, 30], fill=(45, 46, 52)); d.text((12, 6), "bao_cao_kho.py — Visual Studio Code", font=F(15), fill=(200, 200, 200))
    d.rectangle([0, 30, 200, SH], fill=(37, 38, 44))
    for i, f in enumerate(["▾ du_an_kho", "   api.py", "   bao_cao_kho.py", "   db.py", "   models.py", "   tests", "   README.md"]):
        d.text((10, 44 + i * 24), f, font=F(14), fill=(190, 190, 190) if i != 2 else (255, 255, 255))
    lines = [("kw", "import"), ("", " pandas "), ("kw", "as"), ("", " pd")], [("kw", "from"), ("", " db "), ("kw", "import"), ("", " ket_noi, lay_don_hang")], [], \
            [("kw", "def"), ("fn", " tong_hop_ton_kho"), ("", "(thang: "), ("ty", "int"), ("", "):")], [("", "    don = lay_don_hang(thang)")], \
            [("", "    bang = pd.DataFrame(don)")], [("cm", "    # gộp theo mã hàng, bỏ đơn huỷ")], [("", "    bang = bang[bang.trang_thai != "), ("st", "'huy'"), ("", "]")], \
            [("", "    kq = bang.groupby("), ("st", "'ma_hang'"), ("", ").agg({")], [("st", "        'so_luong'"), ("", ": "), ("st", "'sum'"), ("", ",")], \
            [("st", "        'gia_tri'"), ("", ": "), ("st", "'sum'"), ("", ",")], [("", "    })")], [("kw", "    return"), ("", " kq.sort_values("), ("st", "'gia_tri'"), ("", ")")], [], \
            [("kw", "if"), ("", " __name__ == "), ("st", "'__main__'"), ("", ":")], [("", "    "), ("fn", "print"), ("", "(tong_hop_ton_kho("), ("nu", "11"), ("", "))")]
    col = {"kw": (198, 120, 221), "fn": (97, 175, 239), "st": (152, 195, 121), "cm": (110, 120, 130), "ty": (229, 192, 123), "nu": (209, 154, 102), "": (210, 210, 210)}
    for i, ln in enumerate(lines):
        y = 44 + i * 27
        d.text((212, y), "%3d" % (i + 1), font=FM(17), fill=(100, 100, 110))
        x = 262
        for k, t in ln:
            d.text((x, y), t, font=FM(17), fill=col[k]); x += d.textlength(t, font=FM(17))
    d.rectangle([200, SH - 140, SW, SH - 24], fill=(24, 25, 29))
    d.text((212, SH - 132), "TERMINAL", font=F(13, True), fill=(180, 180, 180))
    d.text((212, SH - 104), "$ python bao_cao_kho.py", font=FM(15), fill=(200, 200, 200))
    d.text((212, SH - 80), "đang tổng hợp 12.408 đơn hàng...", font=FM(15), fill=(150, 200, 150))
    d.rectangle([0, SH - 24, SW, SH], fill=(0, 102, 184))
    return im


def email():
    im = Image.new("RGB", (SW, SH), (250, 250, 250)); d = ImageDraw.Draw(im)
    d.rectangle([0, 0, SW, 48], fill=(0, 95, 184)); d.text((16, 12), "Hộp thư — Outlook", font=F(19, True), fill=(255, 255, 255))
    d.rectangle([0, 48, 300, SH], fill=(240, 240, 240))
    mails = [("Phòng Nhân sự", "Thông báo tái cấu trúc bộ phận"), ("Trợ lý AI", "Báo cáo tuần đã tự động tạo"), ("Giám đốc", "Họp gấp 17:00"), ("Kế toán", "Bảng lương tháng 11"),
             ("IT Helpdesk", "Cập nhật hệ thống mới"), ("Linh", "Anh ơi gửi em file nhé"), ("Đối tác Minh Phát", "Xác nhận đơn hàng #4471")]
    for i, (a, s) in enumerate(mails):
        y = 58 + i * 70
        if i == 0:
            d.rectangle([0, y - 6, 300, y + 60], fill=(205, 225, 245))
        d.text((16, y), a, font=F(16, True), fill=(30, 30, 30)); d.text((16, y + 24), s[:30], font=F(14), fill=(80, 80, 80))
    d.text((330, 70), "Thông báo tái cấu trúc bộ phận", font=F(24, True), fill=(20, 20, 20))
    d.text((330, 110), "Phòng Nhân sự  •  16:32", font=F(15), fill=(100, 100, 100))
    body = ["Kính gửi toàn thể nhân viên,", "", "Nhằm nâng cao hiệu quả vận hành, công ty sẽ áp dụng", "hệ thống trợ lý AI cho các công việc tổng hợp số liệu,",
            "lập báo cáo và chăm sóc khách hàng từ tuần sau.", "", "Một số vị trí sẽ được sắp xếp lại. Trưởng bộ phận sẽ", "trao đổi trực tiếp với từng cá nhân trong hôm nay.", "", "Trân trọng."]
    for i, t in enumerate(body):
        d.text((330, 160 + i * 30), t, font=F(18), fill=(40, 40, 40))
    return im


def bieu_do():
    im = Image.new("RGB", (SW, SH), (246, 247, 250)); d = ImageDraw.Draw(im)
    d.rectangle([0, 0, SW, 48], fill=(40, 44, 60)); d.text((16, 12), "Bảng điều khiển bán hàng — tháng 11", font=F(19, True), fill=(255, 255, 255))
    for i, (k, v, c) in enumerate([("Doanh thu", "4,82 tỷ", (40, 140, 90)), ("Đơn hàng", "12.408", (60, 110, 200)), ("Khách mới", "318", (200, 130, 40)), ("Tỉ lệ huỷ", "3,1%", (190, 60, 60))]):
        x = 20 + i * 250
        d.rounded_rectangle([x, 64, x + 230, 150], 10, fill=(255, 255, 255), outline=(220, 220, 225))
        d.text((x + 14, 74), k, font=F(16), fill=(110, 110, 120)); d.text((x + 14, 100), v, font=F(32, True), fill=c)
    d.rounded_rectangle([20, 166, 640, 560], 10, fill=(255, 255, 255), outline=(220, 220, 225))
    vals = [R.uniform(0.3, 1.0) for _ in range(12)]
    for i, v in enumerate(vals):
        x = 50 + i * 48; h = int(v * 300)
        d.rectangle([x, 530 - h, x + 30, 530], fill=(70, 130, 220))
    pts = [(65 + i * 48, 530 - int((0.25 + 0.6 * i / 11 + R.uniform(-0.08, 0.08)) * 300)) for i in range(12)]
    d.line(pts, fill=(230, 120, 40), width=4)
    d.rounded_rectangle([660, 166, 1004, 560], 10, fill=(255, 255, 255), outline=(220, 220, 225))
    a0 = -90
    for frac, c in ((0.42, (70, 130, 220)), (0.27, (40, 160, 110)), (0.18, (230, 150, 50)), (0.13, (200, 70, 80))):
        d.pieslice([712, 230, 952, 470], a0, a0 + frac * 360, fill=c); a0 += frac * 360
    d.ellipse([772, 290, 892, 410], fill=(255, 255, 255))
    return im


def bao_cao():
    im = Image.new("RGB", (SW, SH), (225, 228, 232)); d = ImageDraw.Draw(im)
    d.rectangle([0, 0, SW, 34], fill=(30, 70, 150)); d.text((14, 7), "Bao_cao_tuan_47.docx - Word", font=F(16), fill=(255, 255, 255))
    d.rectangle([0, 34, SW, 70], fill=(43, 87, 154))
    d.rectangle([200, 84, 824, SH], fill=(255, 255, 255))
    d.text((262, 110), "BÁO CÁO CÔNG VIỆC TUẦN 47", font=F(26, True), fill=(20, 20, 20))
    d.text((262, 150), "Phòng Kinh doanh  •  Người lập: Nguyễn Văn Nam", font=F(15), fill=(90, 90, 90))
    items = ["1. Hoàn thành tổng hợp doanh thu quý IV", "2. Làm việc với 6 khách hàng mới", "3. Đối soát công nợ tháng 11", "4. Đề xuất kế hoạch tháng 12"]
    for i, t in enumerate(items):
        d.text((262, 196 + i * 34), t, font=F(18), fill=(30, 30, 30))
    for i in range(6):
        y = 340 + i * 24
        d.line([(262, y), (262 + R.randint(380, 500), y)], fill=(170, 170, 170), width=8)
    d.text((262, SH - 70), "Đã lưu  ✓", font=F(18, True), fill=(30, 140, 70))
    return im


def bang_trang_tex():
    W, H = 1024, 540
    im = Image.new("RGB", (W, H), (240, 241, 240)); d = ImageDraw.Draw(im)
    # vết lau mờ
    for _ in range(14):
        x, y = R.randint(0, W), R.randint(0, H)
        d.ellipse([x - 120, y - 30, x + 120, y + 30], fill=(232, 233, 233))
    im = im.filter(ImageFilter.GaussianBlur(14)); d = ImageDraw.Draw(im)
    blue, red, black = (30, 60, 170), (190, 40, 40), (35, 35, 40)
    d.text((40, 30), "KẾ HOẠCH Q4", font=F(46, True), fill=blue)
    d.line([(40, 90), (380, 94)], fill=blue, width=4)
    for i, t in enumerate(["- Doanh thu: 15 tỷ", "- Khách mới: +20%", "- Chuyển đổi số:", "   áp dụng AI ✓", "- Cắt giảm chi phí ?!"]):
        d.text((50, 120 + i * 52), t, font=F(32), fill=black if i != 3 else red)
    d.line([(560, 460), (560, 120)], fill=black, width=4); d.line([(560, 460), (980, 460)], fill=black, width=4)
    pts = [(560 + i * 60, 440 - int(i * 40 + R.uniform(-20, 20))) for i in range(8)]
    d.line(pts, fill=red, width=6)
    d.text((600, 100), "AI ↑ chi phí ↓", font=F(30, True), fill=red)
    d.ellipse([740, 380, 840, 440], outline=blue, width=4)
    d.text((40, 440), "Deadline 30/11 !!!", font=F(34, True), fill=red)
    return im


def dong_ho():
    S = 512
    im = Image.new("RGB", (S, S), (240, 240, 236)); d = ImageDraw.Draw(im)
    c = S / 2
    for i in range(60):
        a = math.radians(i * 6 - 90); r0 = 0.44 * S if i % 5 else 0.4 * S
        d.line([(c + math.cos(a) * r0, c + math.sin(a) * r0), (c + math.cos(a) * 0.47 * S, c + math.sin(a) * 0.47 * S)], fill=(20, 20, 20), width=3 if i % 5 else 8)
    for h in range(1, 13):
        a = math.radians(h * 30 - 90)
        t = str(h); w = d.textlength(t, font=F(44, True))
        d.text((c + math.cos(a) * 0.33 * S - w / 2, c + math.sin(a) * 0.33 * S - 26), t, font=F(44, True), fill=(20, 20, 20))
    def kim(deg, L, w, col):
        a = math.radians(deg - 90)
        d.line([(c - math.cos(a) * 0.06 * S, c - math.sin(a) * 0.06 * S), (c + math.cos(a) * L * S, c + math.sin(a) * L * S)], fill=col, width=w)
    kim((4 + 45 / 60) * 30, 0.24, 14, (15, 15, 15))   # 4:45
    kim(45 * 6, 0.38, 9, (15, 15, 15))
    kim(12 * 6, 0.42, 3, (200, 30, 30))
    d.ellipse([c - 12, c - 12, c + 12, c + 12], fill=(15, 15, 15))
    return im


def tham():
    """thảm ô vuông 50 cm, mỗi ô sợi chạy một hướng; ảnh 1024 = 2 m (4 x 4 ô)"""
    S = 1024; T = S // 4
    rng = np.random.default_rng(3)
    img = np.zeros((S, S), np.float32)
    for i in range(4):
        for j in range(4):
            n = rng.normal(0, 1, (T, T)).astype(np.float32)
            k = 9
            if (i + j) % 2:
                n = np.cumsum(n, axis=0); n = n - np.roll(n, k, axis=0)
            else:
                n = np.cumsum(n, axis=1); n = n - np.roll(n, k, axis=1)
            n = n / (n.std() + 1e-6)
            img[i * T:(i + 1) * T, j * T:(j + 1) * T] = n * 0.5 + rng.uniform(-0.25, 0.25)
    fine = rng.normal(0, 0.45, (S, S)).astype(np.float32)
    v = 0.5 + 0.07 * img + 0.05 * fine
    for k in range(0, S, T):
        v[k:k + 2, :] *= 0.9; v[:, k:k + 2] *= 0.9
    base = np.array([0.34, 0.36, 0.40])
    rgb = np.clip(base[None, None, :] * (v[..., None] * 1.8), 0, 1)
    Image.fromarray((rgb * 255).astype(np.uint8)).save(os.path.join(OUT, "tham.png"))


def tran():
    S = 256
    rng = np.random.default_rng(5)
    n = rng.normal(0, 1, (S, S))
    v = 0.86 + 0.025 * n
    for _ in range(260):
        x, y = rng.integers(0, S, 2)
        v[max(0, y - 1):y + 1, max(0, x - 1):x + 1] -= rng.uniform(0.08, 0.2)   # lỗ tiêu âm
    v[:3, :] *= 0.9; v[-3:, :] *= 0.9; v[:, :3] *= 0.9; v[:, -3:] *= 0.9
    rgb = np.clip(np.stack([v, v, v * 0.985], -1), 0, 1)
    Image.fromarray((rgb * 255).astype(np.uint8)).save(os.path.join(OUT, "tran.png"))


def canh_ngoai():
    """phố Hà Nội lúc 4:45 chiều nhìn từ tầng 5: trời vàng nhạt mù, nhà ống, cao ốc xa, cây"""
    W, H = 2048, 896
    rng = random.Random(7)
    sky = np.zeros((H, W, 3), np.float32)
    for y in range(H):
        t = y / H
        top = np.array([0.62, 0.72, 0.84]); hor = np.array([0.98, 0.86, 0.66])
        sky[y] = top * (1 - t) ** 1.4 + hor * (1 - (1 - t) ** 1.4)
    im = Image.fromarray((np.clip(sky, 0, 1) * 255).astype(np.uint8))
    d = ImageDraw.Draw(im)
    hz = int(H * 0.62)
    # lớp xa: cao ốc mờ
    for _ in range(26):
        w = rng.randint(50, 140); x = rng.randint(-50, W); h = rng.randint(120, 330)
        c = tuple(int(v) for v in (206 + rng.randint(-8, 8), 196 + rng.randint(-8, 8), 182 + rng.randint(-8, 8)))
        d.rectangle([x, hz - h, x + w, hz + 40], fill=c)
        for wy in range(hz - h + 10, hz, 16):
            d.line([(x + 6, wy), (x + w - 6, wy)], fill=tuple(v - 12 for v in c), width=3)
    im = im.filter(ImageFilter.GaussianBlur(3)); d = ImageDraw.Draw(im)
    # lớp gần: nhà ống nhiều màu, ban công, mái tôn, cửa sổ
    x = -20
    cols = [(214, 196, 150), (226, 214, 196), (190, 170, 150), (205, 120, 90), (230, 225, 210), (160, 170, 160), (220, 200, 120), (185, 190, 200)]
    while x < W:
        w = rng.randint(70, 150); h = rng.randint(140, 300)
        c = rng.choice(cols)
        top = H - h
        d.rectangle([x, top, x + w, H], fill=c)
        d.rectangle([x, top - 10, x + w, top], fill=tuple(max(0, v - 40) for v in c))
        for fy in range(top + 18, H - 30, 46):
            for fx in range(x + 10, x + w - 24, 34):
                d.rectangle([fx, fy, fx + 20, fy + 28], fill=(70, 80, 90) if rng.random() < 0.7 else (120, 110, 90))
            d.rectangle([x + 4, fy + 30, x + w - 4, fy + 34], fill=tuple(max(0, v - 50) for v in c))
        if rng.random() < 0.4:
            d.rectangle([x + 10, top - 40, x + 50, top - 10], fill=(110, 120, 130))    # bồn nước
        if rng.random() < 0.3:
            d.rectangle([x + w // 2, top - 70, x + w // 2 + 4, top], fill=(60, 60, 60))   # cột ăng ten
        x += w
    # cây xanh
    for _ in range(18):
        cx, cy, r = rng.randint(0, W), rng.randint(int(H * 0.72), H), rng.randint(40, 90)
        for k in range(8):
            ox, oy = rng.randint(-r, r), rng.randint(-r // 2, r // 2)
            g = rng.randint(70, 110)
            d.ellipse([cx + ox - r // 2, cy + oy - r // 2, cx + ox + r // 2, cy + oy + r // 2], fill=(50, g, 45))
    # dây điện
    for k in range(5):
        y0 = int(H * 0.7) + k * 14
        pts = [(xx, y0 + int(30 * math.sin(xx / W * math.pi * 2 + k))) for xx in range(0, W, 16)]
        d.line(pts, fill=(40, 40, 40), width=2)
    # mù chiều
    a = np.asarray(im).astype(np.float32) / 255.0
    haze = np.array([0.95, 0.86, 0.7])
    a = a * 0.82 + haze * 0.18
    Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).save(os.path.join(OUT, "canh_ngoai.png"))


for name, fn in (("man_hinh_bang_tinh", bang_tinh), ("man_hinh_code", code), ("man_hinh_email", email), ("man_hinh_bieu_do", bieu_do), ("man_hinh_bao_cao", bao_cao),
                 ("bang_trang", bang_trang_tex), ("mat_dong_ho", dong_ho)):
    fn().save(os.path.join(OUT, name + ".png"))
tham(); tran(); canh_ngoai()
print("xong", sorted(os.listdir(OUT)))
