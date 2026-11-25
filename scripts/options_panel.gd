extends PanelContainer
## Bảng TÙY CHỌN: ngôn ngữ, độ nhạy chuột, âm lượng. Dùng ở màn hình chính và menu tạm dừng.
## Thay đổi áp dụng ngay và được lưu khi đóng.

signal closed

const UI = preload("res://scripts/ui_style.gd")

var _title: Label
var _rows: Dictionary = {}
var _lang: OptionButton
var _note: Label
var _back: Button


func _ready() -> void:
	add_theme_stylebox_override("panel", UI.panel_box())
	custom_minimum_size = Vector2(620, 0)
	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	add_child(vb)
	_title = UI.label("", 34, UI.ACCENT)
	vb.add_child(_title)
	# ngôn ngữ
	var lr: HBoxContainer = _row(vb, "language")
	_lang = OptionButton.new()
	_lang.add_theme_font_size_override("font_size", 22)
	_lang.custom_minimum_size = Vector2(260, 40)
	_lang.add_item("Tiếng Việt")
	_lang.add_item("English")
	_lang.selected = Settings.LANGS.find(Settings.lang)
	_lang.item_selected.connect(func(i: int):
		Settings.lang = Settings.LANGS[i]
		Settings.apply()
		_refresh())
	lr.add_child(_lang)
	_note = UI.label("", 16, UI.DIM)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_note)
	_slider(vb, "sens", 0.2, 3.0, 0.05, Settings.mouse_sens, func(v: float): Settings.mouse_sens = v, "x%.2f")
	_slider(vb, "vol_master", 0.0, 1.0, 0.01, Settings.vol_master, func(v: float): Settings.vol_master = v; Settings.apply(), "%d%%")
	_slider(vb, "vol_voice", 0.0, 1.0, 0.01, Settings.vol_voice, func(v: float): Settings.vol_voice = v; Settings.apply(), "%d%%")
	_slider(vb, "vol_sfx", 0.0, 1.0, 0.01, Settings.vol_sfx, func(v: float): Settings.vol_sfx = v; Settings.apply(), "%d%%")
	_back = UI.menu_button("", 26)
	_back.pressed.connect(close)
	vb.add_child(_back)
	Settings.changed.connect(_refresh)
	_refresh()
	_lang.grab_focus()


func _row(parent: Control, key: String) -> HBoxContainer:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	var l: Label = UI.label("", 22)
	l.custom_minimum_size = Vector2(230, 0)
	h.add_child(l)
	parent.add_child(h)
	_rows[key] = l
	return h


func _slider(parent: Control, key: String, lo: float, hi: float, step: float, val: float, cb: Callable, fmt: String) -> void:
	var h: HBoxContainer = _row(parent, key)
	var s: HSlider = HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = val
	s.custom_minimum_size = Vector2(240, 28)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(s)
	var v: Label = UI.label("", 20, UI.ACCENT)
	v.custom_minimum_size = Vector2(70, 0)
	h.add_child(v)
	var show: Callable = func(x: float) -> void:
		v.text = (fmt % (x * 100.0)) if fmt == "%d%%" else (fmt % x)
	show.call(val)
	s.value_changed.connect(func(x: float):
		cb.call(x)
		show.call(x))


func _refresh() -> void:
	if not is_instance_valid(_title):
		return
	_lang.selected = Settings.LANGS.find(Settings.lang)
	_title.text = Settings.t("opt_title")
	for k in _rows.keys():
		(_rows[k] as Label).text = Settings.t(k)
	_note.text = Settings.t("lang_note")
	_back.text = "← " + Settings.t("back")


func close() -> void:
	Settings.save_settings()
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
