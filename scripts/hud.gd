extends CanvasLayer
## Giao diện: chỉ số, nhật ký, gợi ý tương tác và bảng menu lựa chọn.
## Toàn bộ UI được dựng bằng code nên không cần chỉnh scene.

var menu_open: bool = false
var inv_open: bool = false
var live_open: bool = false
var live_root: Control
var live_video_box: Control
var live_viewers: Label
var live_chat: VBoxContainer
var live_popup: Label
var live_hint: Label
var live_info: Dictionary = {}
var live_t: float = 0.0
var live_next_view: float = 0.0
var live_next_chat: float = 0.0
var live_done: Callable
const LIVE_SECONDS: float = 10.0
signal use_requested
signal pause_requested

var hotbar_box: HBoxContainer
var hotbar_slots: Array = []
var held_label: Label
var inv_panel: PanelContainer
var inv_grid: GridContainer
var inv_slots: Array = []
var inv_info: Label

var stats_label: Label
var debt_label: Label
var prompt_label: Label
var toast_label: Label
var log_label: Label
var hint_label: Label
var objective_label: Label
var panel: PanelContainer
var title_label: Label
var body_label: Label
var options_box: VBoxContainer
var skip_label: Label
var fade_rect: ColorRect
var day_card: Label
var fading: bool = false
var voice_player: AudioStreamPlayer
var vi_voice: String = ""
var voice_on: bool = true
var revealed: bool = true
var type_tween: Tween
var typing_done: bool = true
var line_started_ms: int = 0
## Cao độ giọng TTS theo người nói (khi chưa có file ghi âm)
const SPEAKER_PITCH: Dictionary = {"Linh": 1.35, "Vợ": 1.3, "Giám đốc": 0.75, "Chủ nợ": 0.6, "Chú Tư": 0.85, "Tôi": 1.0}
var log_lines: Array = []
var toast_id: int = 0


func _ready() -> void:
	layer = 10
	_build()
	GameState.changed.connect(refresh)
	GameState.message.connect(add_log)
	refresh()


func _make_label(font_size: int) -> Label:
	var l: Label = Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	l.add_theme_constant_override("outline_size", 4)
	return l


func _build() -> void:
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Bảng chỉ số góc trái
	stats_label = _make_label(18)
	stats_label.position = Vector2(14, 12)
	root.add_child(stats_label)

	# Bảng nợ góc phải
	debt_label = _make_label(18)
	debt_label.anchor_left = 1.0
	debt_label.anchor_right = 1.0
	debt_label.offset_right = -14
	debt_label.offset_top = 12
	debt_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	debt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(debt_label)

	# Tâm ngắm
	var cross: Label = _make_label(22)
	cross.text = "+"
	cross.anchor_left = 0.5
	cross.anchor_right = 0.5
	cross.anchor_top = 0.5
	cross.anchor_bottom = 0.5
	cross.grow_horizontal = Control.GROW_DIRECTION_BOTH
	cross.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(cross)

	# Gợi ý tương tác
	prompt_label = _make_label(22)
	prompt_label.anchor_left = 0.5
	prompt_label.anchor_right = 0.5
	prompt_label.anchor_top = 1.0
	prompt_label.anchor_bottom = 1.0
	prompt_label.offset_top = -120
	prompt_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(prompt_label)

	# Thông báo nhanh
	toast_label = _make_label(22)
	toast_label.anchor_left = 0.5
	toast_label.anchor_right = 0.5
	toast_label.anchor_top = 0.18
	toast_label.anchor_bottom = 0.18
	toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_label.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	root.add_child(toast_label)

	# Gợi ý điều khiển và mục tiêu (dùng ở phần intro)
	hint_label = _make_label(20)
	hint_label.anchor_left = 0.5
	hint_label.anchor_right = 0.5
	hint_label.anchor_top = 0.04
	hint_label.anchor_bottom = 0.04
	hint_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(hint_label)

	objective_label = _make_label(24)
	objective_label.anchor_left = 0.5
	objective_label.anchor_right = 0.5
	objective_label.anchor_top = 0.09
	objective_label.anchor_bottom = 0.09
	objective_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	objective_label.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	root.add_child(objective_label)

	# Nhật ký góc dưới trái
	log_label = _make_label(16)
	log_label.anchor_top = 1.0
	log_label.anchor_bottom = 1.0
	log_label.offset_left = 14
	log_label.offset_bottom = -12
	log_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	log_label.custom_minimum_size = Vector2(420, 0)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	root.add_child(log_label)

	# Bảng menu giữa màn hình
	# Khung thoại + lựa chọn: luôn nằm ở đáy màn hình
	var bottom: VBoxContainer = VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_FULL_RECT)
	bottom.offset_bottom = -18
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom)
	panel = PanelContainer.new()
	panel.visible = false
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.custom_minimum_size = Vector2(1040, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())   # không nền: không che cảnh game
	bottom.add_child(panel)

	var mc: MarginContainer = MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		mc.add_theme_constant_override("margin_" + side, 10)
	mc.add_theme_constant_override("margin_bottom", 26)
	mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(mc)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mc.add_child(vb)

	# lựa chọn nằm trên phụ đề
	options_box = VBoxContainer.new()
	options_box.add_theme_constant_override("separation", 2)
	options_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(options_box)

	title_label = _sub_label(21, Color(1, 0.84, 0.35))
	vb.add_child(title_label)

	body_label = _sub_label(25, Color(1, 1, 1))
	vb.add_child(body_label)

	# gợi ý bỏ qua ở góc dưới phải màn hình
	skip_label = _make_label(17)
	skip_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92, 0.85))
	skip_label.anchor_left = 1.0
	skip_label.anchor_right = 1.0
	skip_label.anchor_top = 1.0
	skip_label.anchor_bottom = 1.0
	skip_label.offset_left = -260
	skip_label.offset_right = -28
	skip_label.offset_top = -46
	skip_label.offset_bottom = -18
	skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip_label.visible = false
	root.add_child(skip_label)

	_build_hotbar(root)
	_build_inventory(root)

	# Thẻ "NGÀY n" hiện giữa màn hình khi sang ngày mới
	day_card = _make_label(72)
	day_card.set_anchors_preset(Control.PRESET_CENTER)
	day_card.anchor_top = 0.38
	day_card.anchor_bottom = 0.38
	day_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	day_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	day_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day_card.add_theme_constant_override("outline_size", 10)
	day_card.modulate.a = 0.0
	root.add_child(day_card)

	_build_live(root)

	# Màn đen dùng cho chuyển cảnh (nằm trên cùng)
	fade_rect = ColorRect.new()
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.color = Color(0, 0, 0, 1)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade_rect)

	voice_player = AudioStreamPlayer.new()
	voice_player.bus = "Voice"
	add_child(voice_player)
	if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		var vs: PackedStringArray = DisplayServer.tts_get_voices_for_language("vi")
		if vs.size() > 0:
			vi_voice = vs[0]


# ---------------------------------------------------------------- thanh nhanh & túi đồ

func _slot_style(sel: bool) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.07, 0.75)
	sb.set_border_width_all(3 if sel else 1)
	sb.border_color = Color(1, 0.85, 0.3) if sel else Color(0.6, 0.6, 0.6, 0.7)
	sb.set_corner_radius_all(4)
	return sb


func _make_slot(size: Vector2) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.custom_minimum_size = size
	p.add_theme_stylebox_override("panel", _slot_style(false))
	var l: Label = Label.new()
	l.add_theme_font_size_override("font_size", 13)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(size.x - 8, 0)
	p.add_child(l)
	return p


func _build_hotbar(root: Control) -> void:
	var col: VBoxContainer = VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_bottom = -14
	col.alignment = BoxContainer.ALIGNMENT_END
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(col)
	held_label = _make_label(16)
	held_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(held_label)
	hotbar_box = HBoxContainer.new()
	hotbar_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hotbar_box.add_theme_constant_override("separation", 6)
	hotbar_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(hotbar_box)
	for i in GameState.HOTBAR:
		var p: PanelContainer = _make_slot(Vector2(96, 62))
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hotbar_box.add_child(p)
		hotbar_slots.append(p)


func _build_inventory(root: Control) -> void:
	inv_panel = PanelContainer.new()
	inv_panel.visible = false
	inv_panel.set_anchors_preset(Control.PRESET_CENTER)
	inv_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	inv_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.08, 0.92)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(16)
	inv_panel.add_theme_stylebox_override("panel", sb)
	root.add_child(inv_panel)
	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	inv_panel.add_child(vb)

	var t1: Label = Label.new()
	t1.text = "THANH NHANH  (phím 1 - 5)"
	t1.add_theme_font_size_override("font_size", 18)
	t1.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	vb.add_child(t1)
	var hot: HBoxContainer = HBoxContainer.new()
	hot.add_theme_constant_override("separation", 6)
	vb.add_child(hot)

	var sep: HSeparator = HSeparator.new()
	vb.add_child(sep)
	var t2: Label = Label.new()
	t2.text = "TÚI ĐỒ"
	t2.add_theme_font_size_override("font_size", 18)
	t2.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	vb.add_child(t2)
	inv_grid = GridContainer.new()
	inv_grid.columns = 5
	inv_grid.add_theme_constant_override("h_separation", 6)
	inv_grid.add_theme_constant_override("v_separation", 6)
	vb.add_child(inv_grid)

	for i in GameState.INV_SIZE:
		var p: PanelContainer = _make_slot(Vector2(110, 70))
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		# kéo thả bằng chuột
		p.set_drag_forwarding(_slot_get_drag.bind(i), _slot_can_drop.bind(i), _slot_drop.bind(i))
		p.mouse_entered.connect(_slot_hover.bind(i))
		if i < GameState.HOTBAR:
			hot.add_child(p)
		else:
			inv_grid.add_child(p)
		inv_slots.append(p)

	inv_info = Label.new()
	inv_info.add_theme_font_size_override("font_size", 15)
	inv_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inv_info.custom_minimum_size = Vector2(580, 48)
	vb.add_child(inv_info)
	var help: Label = Label.new()
	help.text = "Giữ chuột trái kéo đồ từ túi lên thanh nhanh (hoặc ngược lại)  ·  Tab / Esc: đóng"
	help.add_theme_font_size_override("font_size", 13)
	help.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vb.add_child(help)


func _slot_get_drag(_at: Vector2, i: int) -> Variant:
	var s: Dictionary = GameState.inventory[i]
	if s.is_empty():
		return null
	var prev: Label = Label.new()
	prev.text = _slot_text(s)
	prev.add_theme_font_size_override("font_size", 15)
	prev.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	prev.add_theme_constant_override("outline_size", 4)
	prev.modulate.a = 0.85
	(inv_slots[i] as Control).set_drag_preview(prev)
	return {"inv_slot": i}


func _slot_can_drop(_at: Vector2, data: Variant, _i: int) -> bool:
	return data is Dictionary and data.has("inv_slot")


func _slot_drop(_at: Vector2, data: Variant, i: int) -> void:
	GameState.move_slot(int(data["inv_slot"]), i)
	_slot_hover(i)


func _slot_hover(i: int) -> void:
	var s: Dictionary = GameState.inventory[i]
	inv_info.text = "" if s.is_empty() else _item_desc(str(s["id"]))


func _slot_text(slot: Dictionary) -> String:
	if slot.is_empty():
		return ""
	var n: String = GameState.item_name(str(slot["id"]))
	var c: int = int(slot["count"])
	return n if c <= 1 else "%s\nx%d" % [n, c]


func _refresh_items() -> void:
	var g = GameState
	if hotbar_slots.is_empty() or g.inventory.size() < g.INV_SIZE:
		return
	for i in g.HOTBAR:
		var p: PanelContainer = hotbar_slots[i]
		var txt: String = _slot_text(g.inventory[i])
		(p.get_child(0) as Label).text = ("%d\n" % (i + 1) if txt == "" else "") + txt
		p.add_theme_stylebox_override("panel", _slot_style(i == g.selected))
	var hid: String = g.selected_id()
	held_label.text = ("Đang cầm: " + g.item_name(hid) + "   (F: dùng)") if hid != "" else ""
	for i in g.INV_SIZE:
		var q: PanelContainer = inv_slots[i]
		(q.get_child(0) as Label).text = _slot_text(g.inventory[i])
		q.add_theme_stylebox_override("panel", _slot_style(i == g.selected))


func _item_desc(id: String) -> String:
	var g = GameState
	var info: Dictionary = g.item_info(id)
	var t: String = g.item_name(id)
	match str(info.get("type", "")):
		"junk":
			t += " — ve chai, bán cho chú Tư được %s/cái." % g.fmt_money(int(info.get("sell", 0)))
		"valuable":
			t += " — đồng nát, bán cho chú Tư được %s." % g.fmt_money(int(info.get("sell", 0)))
		"jewelry":
			t += " — trang sức: bán ở tiệm vàng bạc được %s, hoặc tặng vợ (+%d tình cảm)." % [g.fmt_money(int(info.get("sell", 0))), int(info.get("gift", 0))]
		"tool":
			t += " — " + str(info.get("desc", ""))
		"food", "drink":
			t += " — chọn trên thanh nhanh rồi bấm F để dùng."
	return t


func toggle_inventory() -> void:
	inv_open = not inv_open
	inv_panel.visible = inv_open
	inv_info.text = ""
	hotbar_box.visible = not inv_open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if inv_open else Input.MOUSE_MODE_CAPTURED
	_refresh_items()


# ---------------------------------------------------------------- màn hình livestream

func _build_live(root: Control) -> void:
	live_root = ColorRect.new()
	(live_root as ColorRect).color = Color(0.03, 0.03, 0.05, 0.97)
	live_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	live_root.visible = false
	root.add_child(live_root)
	var hb: HBoxContainer = HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 30
	hb.offset_top = 30
	hb.offset_right = -30
	hb.offset_bottom = -30
	hb.add_theme_constant_override("separation", 16)
	live_root.add_child(hb)
	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 3.0
	hb.add_child(left)
	var top: HBoxContainer = HBoxContainer.new()
	left.add_child(top)
	var live_tag: Label = Label.new()
	live_tag.text = " ● LIVE "
	live_tag.add_theme_font_size_override("font_size", 22)
	live_tag.add_theme_color_override("font_color", Color(1, 0.25, 0.25))
	top.add_child(live_tag)
	live_viewers = Label.new()
	live_viewers.add_theme_font_size_override("font_size", 22)
	top.add_child(live_viewers)
	live_video_box = Control.new()
	live_video_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	live_video_box.clip_contents = true
	left.add_child(live_video_box)
	live_popup = Label.new()
	live_popup.add_theme_font_size_override("font_size", 24)
	live_popup.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	live_popup.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	live_popup.add_theme_constant_override("outline_size", 6)
	live_popup.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	live_popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(live_popup)
	live_hint = Label.new()
	live_hint.add_theme_font_size_override("font_size", 14)
	live_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	left.add_child(live_hint)
	var right: PanelContainer = PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.13)
	sb.set_content_margin_all(10)
	right.add_theme_stylebox_override("panel", sb)
	hb.add_child(right)
	var rv: VBoxContainer = VBoxContainer.new()
	right.add_child(rv)
	var ct: Label = Label.new()
	ct.text = "CHAT"
	ct.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	rv.add_child(ct)
	live_chat = VBoxContainer.new()
	live_chat.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rv.add_child(live_chat)


## Danh sách video gameplay trong res://video (định dạng .ogv của Godot)
func _video_files() -> Array:
	var out: Array = []
	var d: DirAccess = DirAccess.open("res://video")
	if d == null:
		return out
	for f in d.get_files():
		var fn: String = f.replace(".import", "")
		if fn.ends_with(".ogv") and not out.has("res://video/" + fn):
			out.append("res://video/" + fn)
	return out


## Chiếu màn hình livestream khoảng 10 giây. info: viewers, day, popups [{t, text}], chat_good, chat_bad
func show_live(info: Dictionary, done: Callable) -> void:
	live_info = info
	live_done = done
	live_t = 0.0
	live_next_view = 0.0
	live_next_chat = 0.8
	live_popup.text = ""
	live_hint.text = ""
	for c in live_chat.get_children():
		c.queue_free()
	for c in live_video_box.get_children():
		c.queue_free()
	var vids: Array = _video_files()
	if vids.size() > 0:
		var vp: VideoStreamPlayer = VideoStreamPlayer.new()
		vp.stream = load(str(vids.pick_random()))
		vp.expand = true
		vp.set_anchors_preset(Control.PRESET_FULL_RECT)
		vp.autoplay = true
		vp.loop = true
		live_video_box.add_child(vp)
	else:
		var ph: ColorRect = ColorRect.new()
		ph.color = Color(0.12, 0.14, 0.2)
		ph.set_anchors_preset(Control.PRESET_FULL_RECT)
		live_video_box.add_child(ph)
		var pl: Label = Label.new()
		pl.text = "▶  (video gameplay sẽ hiện ở đây)"
		pl.set_anchors_preset(Control.PRESET_CENTER)
		pl.add_theme_font_size_override("font_size", 22)
		ph.add_child(pl)
	live_open = true
	live_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_live_viewers_tick()


func _live_viewers_tick() -> void:
	var v: int = int(live_info.get("viewers", 0))
	var shown: int = 0
	if int(live_info.get("day", 3)) <= 2:
		shown = randi_range(1, 5)
	else:
		shown = maxi(0, int(float(v) * randf_range(0.65, 1.15)))
	live_viewers.text = "  👁 %d người đang xem" % shown


func _live_add_chat(text: String) -> void:
	var l: Label = Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 15)
	live_chat.add_child(l)
	while live_chat.get_child_count() > 14:
		var o: Node = live_chat.get_child(0)
		live_chat.remove_child(o)
		o.queue_free()


func _live_process(delta: float) -> void:
	live_t += delta
	if live_t >= live_next_view:
		live_next_view = live_t + 0.6
		_live_viewers_tick()
	var v: int = int(live_info.get("viewers", 0))
	if live_t >= live_next_chat and (v >= 3 or randf() < 0.3):
		live_next_chat = live_t + randf_range(0.7, 1.8)
		var good: Array = live_info.get("chat_good", [])
		var bad: Array = live_info.get("chat_bad", [])
		var pool: Array = good if (bad.is_empty() or randf() < 0.75) else bad
		if pool.size() > 0:
			_live_add_chat("user%d: %s" % [randi_range(100, 9999), str(pool.pick_random())])
	elif live_t >= live_next_chat:
		live_next_chat = live_t + 1.5
	for p in live_info.get("popups", []):
		if not p.get("shown", false) and live_t >= float(p["t"]):
			p["shown"] = true
			live_popup.text = str(p["text"])
	live_hint.text = "Space / click: bỏ qua" if live_t > 2.0 else ""
	if live_t >= LIVE_SECONDS:
		_end_live()


func _end_live() -> void:
	if not live_open:
		return
	live_open = false
	live_root.visible = false
	for c in live_video_box.get_children():
		c.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if live_done.is_valid():
		live_done.call()


func _bar(v: int) -> String:
	var n: int = clampi(int(float(v) / 10.0 + 0.5), 0, 10)
	return "█".repeat(n) + "░".repeat(10 - n)


func refresh() -> void:
	if stats_label == null:
		return
	var g = GameState
	var house: String = "Nhà mới (rộng)" if g.new_house else "Phòng trọ (hẹp)"
	var lines: PackedStringArray = PackedStringArray()
	lines.append("NGÀY %d / %d  ·  Buổi %s   (Q: xem đồng hồ)" % [g.day, g.TOTAL_DAYS, g.time_name().to_lower()])
	lines.append("Tiền:       %s" % g.fmt_money(g.money))
	lines.append("Tình cảm:   %s %d" % [_bar(g.wife), g.wife])
	lines.append("Độ no:      %s %d" % [_bar(int(g.hunger)), int(g.hunger)])
	lines.append("Nước:       %s %d" % [_bar(int(g.thirst)), int(g.thirst)])
	lines.append("Follower:   %d   (lần stream gần nhất: %d view)" % [int(g.followers), g.last_viewers])
	lines.append("Máy: %s (độ bền %d%%)  ·  Đồ stream: %d món" % [g.pc_name(), int(g.pc_dur), g.gear.size()])
	lines.append(house)
	stats_label.text = "\n".join(lines)
	_refresh_items()

	var m: Dictionary = g.next_milestone()
	var short: int = maxi(0, int(m["need"]) - g.paid)
	var dl: PackedStringArray = PackedStringArray()
	dl.append("NỢ CÒN LẠI: %s" % g.fmt_money(g.remaining_debt()))
	dl.append("Đã trả: %s" % g.fmt_money(g.paid))
	dl.append("Mốc ngày %d: cần đã trả %s" % [int(m["day"]), g.fmt_money(int(m["need"]))])
	if short > 0:
		dl.append("Còn thiếu: %s" % g.fmt_money(short))
	else:
		dl.append("Đã đủ mốc này")
	dl.append("Nguy hiểm: %s %d" % [_bar(g.danger), g.danger])
	debt_label.text = "\n".join(dl)


func add_log(text: String) -> void:
	log_lines.append(text)
	while log_lines.size() > 6:
		log_lines.pop_front()
	log_label.text = "\n".join(PackedStringArray(log_lines))
	toast(text, 2.5)


func toast(text: String, secs: float = 2.5) -> void:
	toast_id += 1
	var my_id: int = toast_id
	toast_label.text = text
	get_tree().create_timer(secs).timeout.connect(_clear_toast.bind(my_id))


func _clear_toast(id: int) -> void:
	if toast_id == id:
		toast_label.text = ""


func set_hint(text: String) -> void:
	hint_label.text = text


func set_objective(text: String) -> void:
	objective_label.text = ("► " + text) if text != "" else ""


func _sub_label(size: int, col: Color) -> Label:
	var l: Label = Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	l.add_theme_constant_override("outline_size", 7)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(1020, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _option_button(text: String) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	b.add_theme_color_override("font_hover_color", Color(1, 0.84, 0.35))
	b.add_theme_color_override("font_focus_color", Color(1, 0.84, 0.35))
	b.add_theme_color_override("font_pressed_color", Color(1, 0.92, 0.6))
	b.add_theme_color_override("font_disabled_color", Color(0.7, 0.7, 0.7, 0.55))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	b.add_theme_constant_override("outline_size", 6)
	var e: StyleBoxEmpty = StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, e)
	b.mouse_entered.connect(func(): if not b.disabled: b.grab_focus())
	return b


func show_panels(v: bool) -> void:
	hotbar_box.visible = v
	held_label.visible = v
	stats_label.visible = v
	debt_label.visible = v
	log_label.visible = v


func set_prompt(text: String) -> void:
	if menu_open or text == "":
		prompt_label.text = ""
	else:
		prompt_label.text = "[E] " + text


## options: mảng các Dictionary {"label": String, "cb": Callable, "disabled": bool}
## voice_text: câu được đọc thành tiếng; vid: tên file giọng trong res://voice/ (không có đuôi).
## Câu thoại chạy chữ và đọc xong trước, sau đó mới hiện các lựa chọn.
func show_menu(title: String, body: String, options: Array, voice_text: String = "", vid: String = "") -> void:
	title_label.text = title
	body_label.text = body
	for c in options_box.get_children():
		options_box.remove_child(c)
		c.queue_free()
	# Câu thoại một mạch (chỉ có nút "Tiếp tục"): hiện như phụ đề, đọc xong tự chuyển, Space để bỏ qua.
	sub_mode = options.size() == 1 and str(options[0].get("label", "")) in ["Tiếp tục", "Continue", "OK"]
	sub_next = options[0].get("cb", Callable()) if sub_mode else Callable()
	sub_hold = -1.0
	if not sub_mode:
		var i: int = 1
		for o in options:
			var opt: Dictionary = o
			var b: Button = _option_button("%d.  %s" % [i, str(opt.get("label", "OK"))])
			b.disabled = bool(opt.get("disabled", false))
			var cb: Callable = opt.get("cb", Callable())
			b.pressed.connect(_choose.bind(cb))
			options_box.add_child(b)
			i += 1
	panel.visible = true
	menu_open = true
	hotbar_box.visible = false
	held_label.visible = false
	prompt_label.text = ""
	log_label.visible = false
	if not sub_mode:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Chạy chữ
	options_box.visible = false
	skip_label.text = Settings.t("skip_hint")
	skip_label.visible = true
	revealed = false
	typing_done = false
	line_started_ms = Time.get_ticks_msec()
	if type_tween != null and type_tween.is_valid():
		type_tween.kill()
	body_label.visible_ratio = 0.0
	var dur: float = clampf(float(body.length()) * 0.025, 0.3, 4.0)
	type_tween = create_tween()
	type_tween.tween_property(body_label, "visible_ratio", 1.0, dur)
	type_tween.tween_callback(_on_typed)
	# câu nào cũng có tiếng: không truyền câu đọc riêng thì đọc chính nội dung
	var say: String = voice_text if voice_text != "" else body
	sub_voiced = speak(title, say, vid)


var sub_mode: bool = false
var sub_next: Callable = Callable()
var sub_hold: float = -1.0
var sub_voiced: bool = false


## Chuyển sang câu tiếp (phụ đề).
func _sub_advance() -> void:
	var cb: Callable = sub_next
	sub_mode = false
	sub_next = Callable()
	skip_label.visible = false
	hide_menu()
	if cb.is_valid():
		cb.call()


func _on_typed() -> void:
	typing_done = true


func _process(_d: float) -> void:
	if live_open:
		_live_process(_d)
	if menu_open and sub_mode and not fading:
		if typing_done and not is_speaking():
			if sub_hold < 0.0:
				# đọc xong: giữ phụ đề thêm chút; không có giọng thì giữ theo độ dài câu
				var n: float = float(body_label.text.length())
				sub_hold = 0.6 if sub_voiced else clampf(n * 0.055, 1.8, 7.0)
			else:
				sub_hold -= _d
				if sub_hold <= 0.0:
					_sub_advance()
		return
	if menu_open and not revealed and typing_done and not is_speaking():
		_reveal()


func _reveal() -> void:
	if type_tween != null and type_tween.is_valid():
		type_tween.kill()
	body_label.visible_ratio = 1.0
	typing_done = true
	revealed = true
	skip_label.visible = false
	options_box.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for c in options_box.get_children():
		var b: Button = c as Button
		if b != null and not b.disabled:
			b.grab_focus()
			break


func _choose(cb: Callable) -> void:
	if not revealed:
		return
	hide_menu()
	if cb.is_valid():
		cb.call()


func hide_menu() -> void:
	stop_voice()
	sub_mode = false
	skip_label.visible = false
	panel.visible = false
	menu_open = false
	hotbar_box.visible = stats_label.visible
	held_label.visible = stats_label.visible
	log_label.visible = stats_label.visible
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ---------------------------------------------------------------- giọng nói

func speak(speaker: String, text: String, vid: String = "") -> bool:
	stop_voice()
	if not voice_on or text == "":
		return false
	if vid != "":
		for ext in ["ogg", "wav", "mp3"]:
			var p: String = "res://voice/%s.%s" % [vid, ext]
			if ResourceLoader.exists(p):
				var st: AudioStream = load(p) as AudioStream
				if st != null:
					voice_player.stream = st
					voice_player.play()
					return true
	if vi_voice != "":
		var pitch: float = 1.0
		for k in SPEAKER_PITCH.keys():
			if speaker.begins_with(str(k)):
				pitch = float(SPEAKER_PITCH[k])
		DisplayServer.tts_speak(_speakable(text), vi_voice, Settings.tts_volume(), pitch, 1.0)
		return true
	return false


## Bỏ ký hiệu khó đọc trước khi đưa cho giọng đọc máy.
func _speakable(t: String) -> String:
	var out: String = t.replace("·", ",").replace("…", "...").replace("\n", ". ")
	for ch in ["*", "#", "[", "]", "→", "—"]:
		out = out.replace(ch, " ")
	return out


func is_speaking() -> bool:
	if voice_player.playing:
		return true
	if vi_voice != "":
		# Cho TTS một nhịp để bắt đầu đọc trước khi kiểm tra
		if Time.get_ticks_msec() - line_started_ms < 400:
			return true
		return DisplayServer.tts_is_speaking()
	return false


func play_sfx(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var st: AudioStream = load(path) as AudioStream
	if st == null:
		return
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.stream = st
	p.bus = "SFX"
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func stop_voice() -> void:
	if voice_player != null:
		voice_player.stop()
	if vi_voice != "":
		DisplayServer.tts_stop()


# ---------------------------------------------------------------- chuyển cảnh

## Tối dần -> gọi mid (đổi cảnh) -> sáng dần.
func transition(mid: Callable, dur: float = 0.6) -> void:
	fading = true
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw: Tween = create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, dur)
	tw.tween_callback(mid)
	tw.tween_interval(0.3)
	tw.tween_property(fade_rect, "color:a", 0.0, dur)
	tw.tween_callback(_fade_done)


func show_day_card(day: int, total: int) -> void:
	day_card.text = "NGÀY %d\n%d ngày còn lại" % [day, total - day + 1]
	var tw: Tween = create_tween()
	tw.tween_property(day_card, "modulate:a", 1.0, 0.6)
	tw.tween_interval(1.8)
	tw.tween_property(day_card, "modulate:a", 0.0, 0.8)


func fade_from_black(dur: float = 1.0) -> void:
	fading = true
	fade_rect.color.a = 1.0
	var tw: Tween = create_tween()
	tw.tween_property(fade_rect, "color:a", 0.0, dur)
	tw.tween_callback(_fade_done)


func _fade_done() -> void:
	fading = false
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if live_open:
		if live_t > 2.0 and ((event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_E]) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)):
			_end_live()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_V:
		voice_on = not voice_on
		if not voice_on:
			stop_voice()
		toast("Giọng nói: " + ("BẬT" if voice_on else "TẮT"), 1.5)
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE and not menu_open and not fading:
		if inv_open:
			toggle_inventory()
		elif stats_label.visible:
			pause_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if not menu_open and not fading and stats_label.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			var k: int = event.physical_keycode
			if k == KEY_TAB:
				toggle_inventory()
				get_viewport().set_input_as_handled()
				return
			if inv_open:
				return
			if k >= KEY_1 and k <= KEY_5:
				GameState.select_slot(k - KEY_1)
				return
			if k == KEY_F:
				use_requested.emit()
				return
		elif event is InputEventMouseButton and event.pressed and not inv_open:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				GameState.select_slot((GameState.selected + GameState.HOTBAR - 1) % GameState.HOTBAR)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				GameState.select_slot((GameState.selected + 1) % GameState.HOTBAR)
		return
	if not menu_open or fading:
		return
	if sub_mode:
		var sk: bool = event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_SPACE, KEY_ENTER]
		if sk:
			stop_voice()
			_sub_advance()
			get_viewport().set_input_as_handled()
		return
	if not revealed:
		var skip: bool = false
		if event is InputEventKey and event.pressed and not event.echo:
			skip = event.physical_keycode in [KEY_SPACE, KEY_ENTER]
		if skip:
			if typing_done:
				stop_voice()
			_reveal()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var idx: int = int(event.physical_keycode) - int(KEY_1)
		if idx >= 0 and idx < options_box.get_child_count():
			var b: Button = options_box.get_child(idx) as Button
			if b != null and not b.disabled:
				b.pressed.emit()
				get_viewport().set_input_as_handled()
