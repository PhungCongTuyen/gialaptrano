extends CanvasLayer
## Màn hình vào game: Bắt đầu / Tiếp tục (bảng bản lưu) / Tùy chọn / Thoát.
## Phía sau là cảnh phố lúc chiều tà, camera trôi chậm (do main.gd điều khiển).

signal start_game
signal load_slot(slot: int)
signal quit_game

const UI = preload("res://scripts/ui_style.gd")
const OptionsPanel = preload("res://scripts/options_panel.gd")

var root: Control
var menu_box: VBoxContainer
var title_l: Label
var sub_l: Label
var hint_l: Label
var btn: Dictionary = {}
var overlay: Control = null   # bảng đang mở (bản lưu / tùy chọn)


func _ready() -> void:
	layer = 20
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	# lớp tối dần từ trái sang phải để chữ dễ đọc
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.82))
	grad.set_color(1, Color(0, 0, 0, 0.0))
	grad.add_point(0.45, Color(0, 0, 0, 0.55))
	var gt: GradientTexture2D = GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	var shade: TextureRect = TextureRect.new()
	shade.texture = gt
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	# cột trái: tên game + nút
	var col: VBoxContainer = VBoxContainer.new()
	col.position = Vector2(90, 150)
	col.add_theme_constant_override("separation", 8)
	root.add_child(col)
	title_l = UI.label("60 NGÀY", 78, Color(1, 0.96, 0.88))
	title_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	title_l.add_theme_constant_override("outline_size", 6)
	col.add_child(title_l)
	sub_l = UI.label("", 20, UI.DIM)
	col.add_child(sub_l)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, 46)
	col.add_child(gap)
	menu_box = VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 6)
	col.add_child(menu_box)
	for k in ["start", "continue", "options", "quit"]:
		var b: Button = UI.menu_button("", 32)
		b.custom_minimum_size = Vector2(320, 0)
		menu_box.add_child(b)
		btn[k] = b
	btn["start"].pressed.connect(func(): start_game.emit())
	btn["continue"].pressed.connect(_open_saves)
	btn["options"].pressed.connect(_open_options)
	btn["quit"].pressed.connect(func(): quit_game.emit())
	hint_l = UI.label("", 15, Color(UI.DIM, 0.8))
	hint_l.anchor_top = 1.0
	hint_l.anchor_bottom = 1.0
	hint_l.position = Vector2(90, -50)
	root.add_child(hint_l)
	var ver: Label = UI.label("v0.1 · Godot 4", 14, Color(UI.DIM, 0.6))
	ver.anchor_left = 1.0
	ver.anchor_right = 1.0
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.position = Vector2(-150, -40)
	root.add_child(ver)
	Settings.changed.connect(_refresh)
	_refresh()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# hiện dần
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 1.2)
	(btn["continue"] if _has_saves() else btn["start"]).grab_focus()


func _has_saves() -> bool:
	for i in range(1, GameState.SAVE_SLOTS + 1):
		if not GameState.slot_info(i).is_empty():
			return true
	return false


func _refresh() -> void:
	sub_l.text = Settings.t("subtitle")
	hint_l.text = Settings.t("hint_menu")
	for k in btn.keys():
		(btn[k] as Button).text = Settings.t(k)
	btn["continue"].disabled = not _has_saves()


# ---------------------------------------------------------------- bảng bản lưu

func _open_saves() -> void:
	_close_overlay()
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.panel_box())
	p.custom_minimum_size = Vector2(640, 0)
	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	p.add_child(vb)
	vb.add_child(UI.label(Settings.t("saves"), 34, UI.ACCENT))
	var first: Control = null
	for i in range(1, GameState.SAVE_SLOTS + 1):
		var m: Dictionary = GameState.slot_info(i)
		var card: Button = Button.new()
		card.custom_minimum_size = Vector2(0, 96)
		card.focus_mode = Control.FOCUS_ALL
		card.add_theme_stylebox_override("normal", UI.card_style(false))
		card.add_theme_stylebox_override("hover", UI.card_style(true))
		card.add_theme_stylebox_override("focus", UI.card_style(true))
		card.add_theme_stylebox_override("pressed", UI.card_style(true))
		card.add_theme_stylebox_override("disabled", UI.card_style(false))
		var hb: HBoxContainer = HBoxContainer.new()
		hb.set_anchors_preset(Control.PRESET_FULL_RECT)
		hb.offset_left = 18
		hb.offset_right = -18
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_theme_constant_override("separation", 22)
		card.add_child(hb)
		var num: Label = UI.label(str(i), 44, UI.ACCENT if not m.is_empty() else Color(UI.DIM, 0.5))
		num.custom_minimum_size = Vector2(44, 0)
		num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		num.size_flags_vertical = Control.SIZE_FILL
		hb.add_child(num)
		var info: VBoxContainer = VBoxContainer.new()
		info.alignment = BoxContainer.ALIGNMENT_CENTER
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(info)
		if m.is_empty():
			info.add_child(UI.label(Settings.t("empty"), 22, Color(UI.DIM, 0.6)))
			card.disabled = true
		else:
			info.add_child(UI.label("%s  ·  %s" % [Settings.t("day") % int(m.get("day", 1)), str(m.get("clock", ""))], 24))
			info.add_child(UI.label("%s: %s     %s: %s" % [Settings.t("money"), GameState.fmt_money(int(m.get("money", 0))),
					Settings.t("debt"), GameState.fmt_money(int(m.get("debt", 0)))], 18, UI.DIM))
			info.add_child(UI.label("%s %s" % [Settings.t("saved_at"), str(m.get("saved_at", "")).replace("T", " ")], 15, Color(UI.DIM, 0.75)))
			card.pressed.connect(func(): load_slot.emit(i))
			card.mouse_entered.connect(func(): card.grab_focus())
			if first == null:
				first = card
		for lb in info.get_children():
			(lb as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(card)
	var back: Button = UI.menu_button("← " + Settings.t("back"), 26)
	back.pressed.connect(_close_overlay)
	vb.add_child(back)
	_show_overlay(p, first if first != null else back)


func _open_options() -> void:
	_close_overlay()
	var p: PanelContainer = OptionsPanel.new()
	_show_overlay(p, null)
	p.closed.connect(func():
		overlay = null
		menu_box.visible = true
		btn["options"].grab_focus())


func _show_overlay(p: Control, focus: Control) -> void:
	overlay = p
	menu_box.visible = false
	root.add_child(p)
	p.position = Vector2(600, 130)
	p.modulate.a = 0.0
	create_tween().tween_property(p, "modulate:a", 1.0, 0.2)
	if focus != null:
		focus.grab_focus()


func _close_overlay() -> void:
	if overlay != null and is_instance_valid(overlay):
		if overlay.has_method("close"):
			overlay.close()
			return
		overlay.queue_free()
	overlay = null
	menu_box.visible = true
	if btn["continue"].disabled:
		btn["start"].grab_focus()
	else:
		btn["continue"].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and overlay != null and not overlay.has_method("close"):
		get_viewport().set_input_as_handled()
		_close_overlay()


## Tắt dần rồi tự huỷ.
func dismiss() -> void:
	var tw: Tween = create_tween()
	tw.tween_property(root, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)
