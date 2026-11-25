# 60 Ngày (bản dựng đầu, greybox)

Game nhập vai 3D góc nhìn thứ nhất: trả 100 triệu trong 60 ngày bằng cách stream, nhặt nhạnh, đánh liều ở chỗ đỏ đen, và giữ vợ không bỏ đi.

## Intro (theo kịch bản trong bảng tính)
Game mở đầu ở văn phòng: Linh báo lên gặp giám đốc → chọn *lên luôn* hoặc *lên sau* (nghĩ thầm "Chắc là cần mình nộp báo cáo đây", nhặt báo cáo trên bàn bằng E, có hướng dẫn phím) → phòng giám đốc, nghe bị đuổi việc → bấm E nhận giấy cho nghỉ việc → ngày 1: độc thoại, chuyển cảnh đến máy tính, quyết định thử livestream, hiện thẻ "NGÀY 1" → chơi. Code ở `main.gd`, các hàm `_intro_*`.

## Cách chạy
1. Mở **Godot 4.2+** (bản Standard) → *Import* → chọn file `project.godot` trong thư mục này.
2. Bấm **F5** (Run). Nếu Godot hỏi cảnh chính, chọn `scenes/main.tscn`.

## Điều khiển
WASD di chuyển · chuột nhìn · Shift chạy · Space nhảy · **E tương tác** · **Q giơ tay xem đồng hồ** · **Tab túi đồ** · **1–5 / con lăn chọn đồ** · **F dùng đồ** · V bật/tắt giọng · **Esc tạm dừng / lưu game** · Space/click bỏ qua câu thoại · phím số 1–9 hoặc click để chọn.

## Cốt truyện theo ngày (theo sheet xương sống)
- Ngày 1–2: kênh mới, 1–5 người xem, thu nhập cố định 50k / 70k. Ngày 3: popup donate đầu tiên.
- Ngày 7 và 45: đóng tiền nhà (phòng trọ 2,5tr; nhà mới 4tr).
- Ngày 13 / 40 / 50, 20:00: chủ nợ đến thu 5tr / 10tr / 5tr. Thiếu tiền: góc stream bị đập, phải sửa ở cửa hàng máy tính (800k, hoặc 1,6tr nếu ngày 1 đã hỗn).
- Ngày 19: vợ không ngủ được vì đèn stream → mục tiêu thuê nhà mới (cọc 3tr). Hết ngày 27 chưa thuê: vợ về nhà ngoại, kết thúc xấu.
- Ngày 31: gặp Linh trước quán ăn, nghe tin đồn cuộn dây đồng trong công trường. Ngày 32: chú Tư bắt đầu bán lockpick.
- Ngày 36: tin lễ hội. Từ ngày 37: cổng công trường không còn bảo vệ gác, cạy khóa vào được; bên trong có bảo vệ đi tuần cầm đèn pin. Ctrl để cúi người. Lấy cuộn dây đồng (bán 10tr) và ra ngoài không bị thấy. Bị bắt: lần 1 tịch thu đồ, lần 2 phạt 2tr, lần 3 vào tù (kết thúc xấu). Sau khi lấy được: công trường bỏ ngỏ, đào vụn dây đồng 100k–500k (2 lần/ngày).
- Ngày 46: công ty cũ mua giọng nói và khuôn mặt (20tr, người xem và thu nhập stream giảm một nửa) hoặc từ chối (kênh AI nhái làm giảm view ngày 48–52, ngày 49 cộng đồng donate 5tr).
- Ngày 56: nhắc còn 4 ngày. Ngày 60: hết nợ → kết thúc tốt (tình cảm vợ ≥ 60) hoặc "không còn mặn nồng"; còn nợ → "Chiếc đàn của bố".

## Màn hình livestream
Mỗi buổi stream chiếu khoảng 10 giây: video gameplay (thư mục `video/`, file .ogv), số người xem nhảy lên xuống, chat chạy, popup donate. Space/click để bỏ qua sau 2 giây.

## Màn hình chính, tạm dừng, lưu game
Mở game là màn hình chính: Chơi mới / Tải game / Thoát. Trong game bấm **Esc** để mở menu tạm dừng: Tiếp tục, **Lưu game (3 ô)**, Tải game, Về màn hình chính, Thoát. Chỉ lưu được khi đang chơi tự do (không trong cắt cảnh). File lưu ở `user://save_1..3.json` (Windows: `%APPDATA%\Godot\app_userdata\No60Ngay`).

## Stream
Stream lúc nào cũng được, tối đa 8 tiếng mỗi ngày (chọn 1–4 tiếng mỗi lần). Giờ vàng 20:00–23:00 đông người xem nhất; ban ngày chỉ khoảng 35%, sau 0:00 khoảng 20%.
Nếu buổi stream kéo qua 23:00 khi vợ ở nhà, vợ trên giường nhắc "Anh ơi nghỉ đi...":
- Tắt stream → "Tôi off stream ở đây nhé anh em..." → bảng kết quả buổi stream.
- Phớt lờ → stream nốt số giờ đã chọn, tình cảm vợ -8, vợ nhận xét → bảng kết quả.
Sau 23:00 phố vắng, có 5 tên trấn lột đi lại trên đường đến 7:00 sáng (lại gần 3 m mất 5% tiền mặt).

## Vợ
Vợ đi làm lúc 7:00 (nếu bạn đang thức ở nhà, vợ chào: "Em đi làm đây, anh làm gì thì làm, giữ sức khỏe"...) và về lúc 18:00, ngủ từ 23:00. Lần gặp đầu sau giờ làm, vợ nói đã nấu cơm (mâm cơm trên bàn nhỏ, ăn vào no và hết khát 100%) hoặc làm tăng ca ăn ở công ty rồi. Nói chuyện tối đa 3 lần mỗi ngày, không tốn thời gian, mỗi lần +3 tình cảm. Tặng trang sức để tăng nhiều hơn.

## Đường phố theo giờ
Đường hẹp kiểu ngõ xóm (~5 m), không vạch kẻ. Người đi đường đi lại cả trên mặt đường lẫn vỉa hè, thỉnh thoảng vào quán ăn / tiệm vàng một lúc rồi đi ra; có những nhóm 2–3 người đứng nói chuyện. Nhìn vào ai đó và bấm **E** để nói chuyện (chỉ nói chuyện, không tốn thời gian; câu thoại đổi theo giờ, theo việc bạn đã nổi tiếng hay đang bị chủ nợ để ý — sửa trong `data/events.json`, mục `npc_lines`).
7:00–18:00: ~9 người đi đường + 3 nhóm; 18:00–23:00: 4 người + 1 nhóm; sau 23:00 không còn ai. Từ 23:00 đến 7:00 mọi hàng quán đóng cửa (trừ quán ăn), chú Tư về nhà, nhà chủ nợ đóng cửa.

## Thời gian, ngủ, đói, khát
12 phút ngoài đời = 1 ngày trong game. Lịch mỗi ngày cố định:
- **06:00** thức dậy · **07:00** vợ đi làm · **18:00** vợ về · **23:00** vợ đi ngủ, phố vắng, có trấn lột.
- **23:30** cảnh báo về nhà. **00:00** tự cắt cảnh: bảng tổng kết ngày cũ, ngủ đến 06:00 sáng hôm sau. Nếu lúc đó còn ở ngoài đường thì mất 5% tiền mặt.
- Có thể đi ngủ sớm ở giường: ngủ luôn đến 06:00.
- Stream tối đa 8 tiếng/ngày và phải kết thúc trước 00:00.
- Đồng hồ đeo tay (Q): giờ, ngày, đói, khát. Đói, khát tăng dần (khi ngủ chậm hơn); cạn quá lâu (khoảng 15-20 giờ) thì ngất, nhập viện (kết thúc xấu). Chỉ số chỉ còn: Độ no, Nước, Tiền, Tình cảm.

## Cấu trúc
| File | Vai trò |
| --- | --- |
| `scripts/game_state.gd` | Luật chơi, chỉ số, kinh tế (autoload `GameState`). Chỉnh cân bằng ở các hằng số đầu file |
| `scripts/main.gd` | Dựng đoạn phố, 2 căn phòng, các menu tương tác, luồng ngày |
| `scripts/hud.gd` | Giao diện chỉ số, nợ, nhật ký, menu |
| `scripts/player.gd` | Nhân vật góc nhìn thứ nhất |
| `data/events.json` | Sự kiện buổi sáng, bới rác, dẫm phân, dòng chat, lời vợ, các kết thúc. Thêm/sửa nội dung ở đây, không cần sửa code |

## Túi đồ và item
Thanh nhanh 5 ô (phím 1–5, hiện ở đáy màn hình) + túi 10 ô. Tab mở túi đồ: hàng 5 ô trên cùng là thanh nhanh, giữ chuột trái kéo đồ giữa túi và thanh nhanh (cùng loại thì cộng dồn). F dùng món đang cầm (ăn, uống).
- Bới đụn rác/lá: ra tiền mệnh giá VNĐ 1k–500k (500k khoảng 3%), hoặc đồ: ve chai (chai nhựa, vỏ lon, giấy, sắt vụn), dây đồng, bật lửa, điện thoại hỏng, lockpick, trang sức bạc/vàng (khuyên tai, nhẫn, vòng tay, dây chuyền); hoặc không có gì. Bới mất 5 giây (hoạt ảnh hai tay đào bới), không cộng trừ chỉ số.
- **Chú Tư ve chai** (vỉa hè cạnh chỗ đỏ đen): thu mua ve chai, đồng nát (chai, lon, giấy, sắt vụn, dây đồng, điện thoại hỏng, bật lửa) và bán lockpick (150k).
- **Tiệm vàng bạc** (căn nhà màu vàng ngay dưới quán ăn): mua lại trang sức, và bán trang sức để tặng vợ.
- **Tặng vợ** trang sức: nói chuyện với vợ → Tặng quà.
- **Lockpick**: lần đầu có sẽ hiện hướng dẫn đến cạy cổng khu công trường bỏ hoang.
- **Quán ăn**: bánh mì, mì ly, cơm hộp, nước lọc, nước ngọt (vào túi đồ).
- **Cửa hàng máy tính**: 3 dàn máy và 8 món đồ stream (mic, webcam, đèn, phông xanh, game) tăng người xem và donate.
Toàn bộ danh sách, giá, tỉ lệ rơi nằm trong `data/items.json`.

## Bản đồ khu phố
Dựng theo ảnh bản đồ (1 px = 0,1 m), dữ liệu ở đầu phần `BẢN ĐỒ KHU PHỐ` trong `main.gd`: `ROADS` (mặt đường), `CORRIDORS` (khoảng đi lại của người đi đường), `BUILDINGS` (nhà: khung pixel, màu, chiều cao, mặt có cửa, loại tương tác), `SIDEWALKS` (vỉa hè, nơi rải đụn rác/lá). Tím = nhà mình, đỏ = chủ nợ, cam = đỏ đen, vàng = nhà cho thuê, hồng = đồ máy tính, xanh lá = quán ăn, vàng đậm (dưới quán ăn) = tiệm vàng bạc, xanh dương = nhà thường, xám = công trường bỏ hoang (tính năng riêng sẽ thêm sau).

Mỗi ngày có 4–5 đụn rác hoặc đụn lá xuất hiện ngẫu nhiên trên vỉa hè. Trỏ chuột vào đụn, bấm E là bới ngay (5 giây): ra tiền, đồ bán được, hoặc không có gì. Tỉ lệ chỉnh trong `data/items.json` (`dig_outcome`).

## Việc làm được trong game
- **Bàn stream** (trong nhà): chọn nội dung, thu donate, tăng follower. Máy yếu dễ treo.
- **Cửa hàng đồ máy tính**: mua dàn máy, đồ stream, sửa máy.
- **Nhà mới cho thuê**: studio rộng, +30% view, tiền thuê cao hơn.
- **Quán ăn**: ăn no, uống nước, rủ vợ đi ăn.
- **Nhà chủ nợ**: trả nợ. Các mốc: ngày 15 (đã trả 10tr), 30 (30tr), 45 (60tr), 60 (hết nợ 100tr). Trễ mốc bị phạt lãi 10% và nguy hiểm tăng.
- **Chỗ đỏ đen** (mở từ chiều): cược đỏ/đen, việc xám, vay nóng.
- **Ngoài phố**: bới đụn rác / đụn lá trên vỉa hè.

## Lưu ý
- Chữ tiếng Việt dùng font mặc định của Godot. Nếu thấy ô vuông, hãy thêm một font hỗ trợ tiếng Việt vào Project Settings → GUI → Theme → Custom Font.
- Bản này dùng khối hộp đơn giản; model đẹp, âm thanh và giọng nói sẽ thêm sau.

## Kiểm tra tự động (không cần mở editor)
Các kịch bản test nằm trong `tests/`. Chạy bằng Godot headless từ thư mục dự án, ví dụ:
`godot --headless res://tests/run_test6.tscn` (kịch bản theo ngày), `run_test7` (giờ giấc, nửa đêm), `run_test5` (người đi đường).

## Màn hình chính & tùy chọn
- `scripts/title_menu.gd`: Bắt đầu / Tiếp tục (bảng 3 ô lưu: ngày, giờ, tiền, nợ, lúc lưu) / Tùy chọn / Thoát.
  Nền là cảnh phố lúc chiều tà, camera trôi chậm.
- `scripts/options_panel.gd`: ngôn ngữ (Tiếng Việt / English), độ nhạy chuột, âm lượng tổng / lời thoại / hiệu ứng.
  Mở được cả từ menu tạm dừng (Esc). Cài đặt lưu ở `user://cai_dat.cfg` (autoload `Settings`, `scripts/settings.gd`).
- Tiếng Anh hiện áp dụng cho giao diện menu; cốt truyện và lời thoại vẫn tiếng Việt.

## Thoại kiểu phụ đề
- Câu thoại một mạch hiện như phụ đề phim ở mép dưới màn hình (chữ trắng viền đen, tên người nói màu vàng),
  không có nền che cảnh. Đọc xong tự chuyển câu; `[Space]` để bỏ qua (gợi ý ở góc dưới phải).
- Câu nào cũng có tiếng: ưu tiên file `voice/<mã câu>.ogg|wav|mp3`, không có thì dùng giọng đọc máy (TTS).
  Trên Windows cần cài giọng tiếng Việt: Settings > Time & Language > Speech > Add voices > Tiếng Việt.
- Câu có lựa chọn: các lựa chọn hiện dạng chữ có viền ngay trên phụ đề, chọn bằng chuột hoặc phím số.
