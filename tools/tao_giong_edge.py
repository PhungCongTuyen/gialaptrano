# -*- coding: utf-8 -*-
"""Tạo file giọng nói cho câu thoại bằng edge-tts (giọng AI của Microsoft Edge).

Cài:   python -m pip install edge-tts
Chạy:  python tools/tao_giong_edge.py            (chỉ tạo câu chưa có file)
       python tools/tao_giong_edge.py --lam-lai  (tạo lại tất cả)
       python tools/tao_giong_edge.py --thu intro_02 intro_05   (chỉ vài câu)

Đọc voice/danh_sach_cau_thoai.csv, ghi voice/<ten_file>.mp3.
Tiếng Việt có 2 giọng: vi-VN-HoaiMyNeural (nữ) và vi-VN-NamMinhNeural (nam).
Mỗi nhân vật được chỉnh cao độ và tốc độ riêng trong bảng NHAN_VAT bên dưới.
"""
import asyncio
import csv
import os
import sys

import edge_tts

NU = "vi-VN-HoaiMyNeural"
NAM = "vi-VN-NamMinhNeural"

# tiền tố tên người nói -> (giọng, tốc độ, cao độ)
NHAN_VAT = [
    ("Người dẫn chuyện", NU, "-8%", "-4Hz"),
    ("Tôi (nghĩ thầm)", NAM, "-6%", "-2Hz"),
    ("Tôi (độc thoại)", NAM, "-6%", "-2Hz"),
    ("Tôi", NAM, "+0%", "+0Hz"),
    ("Linh", NU, "+6%", "+10Hz"),
    ("Vợ", NU, "-2%", "-2Hz"),
    ("Giám đốc", NAM, "-6%", "-12Hz"),
    ("Chủ nợ", NAM, "+4%", "-18Hz"),
    ("Chú Tư", NAM, "-10%", "-8Hz"),
    ("Người từ công ty cũ", NAM, "+4%", "+8Hz"),
]
# tên cảnh (VĂN PHÒNG · 4:45 CHIỀU...) và người lạ: giọng dẫn chuyện
MAC_DINH = NHAN_VAT[0]

GOC = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
THU_MUC = os.path.join(GOC, "voice")
CSV = os.path.join(THU_MUC, "danh_sach_cau_thoai.csv")


def chon_giong(nguoi_noi):
    for nv in NHAN_VAT:
        if nguoi_noi.startswith(nv[0]):
            return nv
    return MAC_DINH


def lam_sach(t):
    t = t.replace("·", ",").replace("…", "...").replace("\n", ". ")
    for ch in "*#[]→—":
        t = t.replace(ch, " ")
    return " ".join(t.split())


async def tao(ten, nguoi_noi, cau):
    _, giong, toc_do, cao_do = chon_giong(nguoi_noi)
    out = os.path.join(THU_MUC, ten + ".mp3")
    tam = out + ".tmp"
    for lan in range(3):
        try:
            await edge_tts.Communicate(lam_sach(cau), giong, rate=toc_do, pitch=cao_do).save(tam)
            os.replace(tam, out)
            return True
        except Exception as e:  # mạng chập chờn: thử lại
            print("  loi", ten, lan + 1, e)
            await asyncio.sleep(2)
    return False


async def main():
    lam_lai = "--lam-lai" in sys.argv
    chi = []
    if "--thu" in sys.argv:
        chi = sys.argv[sys.argv.index("--thu") + 1:]
    with open(CSV, encoding="utf-8-sig") as f:
        dong = list(csv.DictReader(f))
    xong = loi = bo_qua = 0
    for d in dong:
        ten, nguoi, cau = d["ten_file"].strip(), d["nguoi_noi"].strip(), d["cau_thoai"].strip()
        if not ten or not cau or (chi and ten not in chi):
            continue
        if not lam_lai and not chi and os.path.exists(os.path.join(THU_MUC, ten + ".mp3")):
            bo_qua += 1
            continue
        ok = await tao(ten, nguoi, cau)
        print(("ok  " if ok else "LOI ") + ten + "  [" + chon_giong(nguoi)[0] + "]")
        xong += ok
        loi += not ok
    print("xong %d, loi %d, da co san %d" % (xong, loi, bo_qua))


if __name__ == "__main__":
    asyncio.run(main())
