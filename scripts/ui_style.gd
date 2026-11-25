extends RefCounted
## Kiểu giao diện dùng chung cho màn hình chính / tùy chọn / bản lưu.

const ACCENT: Color = Color(0.96, 0.78, 0.3)
const TEXT: Color = Color(0.93, 0.91, 0.86)
const DIM: Color = Color(0.62, 0.6, 0.56)
const PANEL_BG: Color = Color(0.07, 0.065, 0.06, 0.92)


static func panel_box() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = Color(ACCENT, 0.35)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(26)
	return sb


static func menu_button(text: String, size: int = 30) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", ACCENT)
	b.add_theme_color_override("font_focus_color", ACCENT)
	b.add_theme_color_override("font_pressed_color", Color(1, 0.9, 0.6))
	b.add_theme_color_override("font_disabled_color", Color(DIM, 0.45))
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	for st in ["normal", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, empty)
	var hov: StyleBoxFlat = StyleBoxFlat.new()
	hov.bg_color = Color(ACCENT, 0.08)
	hov.border_color = ACCENT
	hov.border_width_left = 3
	hov.set_content_margin_all(4)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("focus", hov)
	b.mouse_entered.connect(func(): if not b.disabled: b.grab_focus())
	return b


static func label(text: String, size: int, color: Color = TEXT) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func card_style(hover: bool) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.07) if hover else Color(1, 1, 1, 0.03)
	sb.border_color = ACCENT if hover else Color(1, 1, 1, 0.12)
	sb.set_border_width_all(2 if hover else 1)
	sb.set_corner_radius_all(5)
	sb.set_content_margin_all(16)
	return sb
