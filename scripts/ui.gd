extends RefCounted
## ابزارهای ساخت رابط با تم ترسناک (قرمز خونی، استخوانی، سیاه).

const RED = Color(0.82, 0.09, 0.14)
const DARK_RED = Color(0.36, 0.04, 0.07)
const BONE = Color(0.90, 0.86, 0.80)
const DIM = Color(0.62, 0.56, 0.54)
const PANEL = Color(0.055, 0.03, 0.045, 0.97)


static func sb(bg, border, width):
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(10)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


static func make_theme():
	var th = Theme.new()
	th.default_font = Global.get_font()
	th.default_font_size = 24
	th.set_color("font_color", "Label", BONE)
	th.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.95))
	th.set_constant("outline_size", "Label", 4)
	th.set_stylebox("normal", "Button", sb(Color(0.10, 0.045, 0.06, 0.96), DARK_RED, 2))
	th.set_stylebox("hover", "Button", sb(Color(0.16, 0.05, 0.07, 0.98), RED, 2))
	th.set_stylebox("pressed", "Button", sb(Color(0.34, 0.04, 0.08, 1.0), RED, 2))
	th.set_stylebox("disabled", "Button", sb(Color(0.06, 0.04, 0.05, 0.8), Color(0.2, 0.1, 0.1), 1))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", BONE)
	th.set_color("font_hover_color", "Button", Color(1, 1, 1))
	th.set_color("font_pressed_color", "Button", Color(1, 0.8, 0.8))
	th.set_color("font_disabled_color", "Button", Color(0.4, 0.34, 0.34))
	th.set_color("font_outline_color", "Button", Color(0, 0, 0, 0.9))
	th.set_constant("outline_size", "Button", 3)
	th.set_font_size("font_size", "Button", 28)
	th.set_stylebox("panel", "PanelContainer", sb(PANEL, DARK_RED, 3))
	th.set_color("font_color", "CheckButton", BONE)
	th.set_font_size("font_size", "CheckButton", 26)
	th.set_stylebox("slider", "HSlider", sb(Color(0.15, 0.05, 0.07), DARK_RED, 1))
	th.set_stylebox("grabber_area", "HSlider", sb(RED, RED, 1))
	th.set_stylebox("grabber_area_highlight", "HSlider", sb(Color(1, 0.2, 0.25), RED, 1))
	return th


static func label(text, size = 24, color = BONE, align = 1):
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.text_direction = Control.TEXT_DIRECTION_RTL
	return l


static func paragraph(text, size = 24, color = BONE):
	var l = label(text, size, color, HORIZONTAL_ALIGNMENT_RIGHT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func button(text, cb, size = 28):
	var b = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(260, 64)
	b.add_theme_font_size_override("font_size", size)
	b.text_direction = Control.TEXT_DIRECTION_RTL
	b.pivot_offset = Vector2(130, 32)
	b.mouse_entered.connect(func():
		var t = b.create_tween()
		t.set_trans(Tween.TRANS_SINE)
		t.tween_property(b, "scale", Vector2(1.025, 1.025), 0.12))
	b.mouse_exited.connect(func():
		var t = b.create_tween()
		t.set_trans(Tween.TRANS_SINE)
		t.tween_property(b, "scale", Vector2.ONE, 0.14))
	b.button_down.connect(func():
		b.pivot_offset = b.size * 0.5
		var t = b.create_tween()
		t.set_trans(Tween.TRANS_SINE)
		t.tween_property(b, "scale", Vector2(0.97, 0.97), 0.07))
	b.button_up.connect(func():
		var t = b.create_tween()
		t.set_trans(Tween.TRANS_SINE)
		t.tween_property(b, "scale", Vector2.ONE, 0.10))
	b.pressed.connect(Global.ui_click)
	b.pressed.connect(cb)
	return b


static func full_rect(c):
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
