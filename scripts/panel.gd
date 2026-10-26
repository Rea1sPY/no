extends Control
## پنجره‌ی تمام‌صفحه با عنوان، محتوای اسکرول‌شونده و دکمه بستن. اول add_child، بعد setup.

const UI = preload("res://scripts/ui.gd")

signal closed

var box = null
var scroll = null


func setup(title, close_text = "بستن"):
	process_mode = Node.PROCESS_MODE_ALWAYS
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	UI.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.82)
	UI.full_rect(dim)
	add_child(dim)
	var center = CenterContainer.new()
	UI.full_rect(center)
	add_child(center)
	var pc = PanelContainer.new()
	center.add_child(pc)
	var vs = get_viewport().get_visible_rect().size
	pc.custom_minimum_size = Vector2(minf(vs.x * 0.88, 1000.0), vs.y * 0.9)
	var outer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	pc.add_child(outer)
	outer.add_child(UI.label(title, 38, UI.RED))
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 14)
	scroll.add_child(box)
	outer.add_child(UI.button(close_text, close_panel))
	# ورود نرم پنجره
	modulate.a = 0.0
	var tw = create_tween()
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.18)


func close_panel():
	Global.save_game()
	closed.emit()
	queue_free()
