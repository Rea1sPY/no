extends Node2D
## اشیای قابل تعامل: برداشتنی‌ها، یادداشت‌ها، کمدها، جعبه‌فیوز، تابلوی دسته‌ها، هسته‌ی حلقه و پایانه‌ی مخفی.

var kind = ""
var id = ""
var info = {}
var state = 0
var highlight = false
var _t = 0.0


func setup(k, i, cell, d):
	kind = k
	id = i
	info = d
	position = Vector2(cell.x * 32 + 16, cell.y * 32 + 16)
	add_to_group("interactables")
	z_index = 2


func set_highlight(on):
	highlight = on


func is_active():
	if kind == "hide":
		return true
	if kind == "secret":
		return Global.progress["notes"].size() >= 7
	return true


func prompt():
	if kind == "pickup":
		return "برداشتن: " + info["name"]
	if kind == "note":
		return "خواندن یادداشت"
	if kind == "hide":
		return "پنهان شدن: " + info["name"]
	if kind == "fusebox":
		if state == 0:
			return "نصب فیوز"
		return "فیوز نصب شده است"
	if kind == "panel":
		return "تابلوی دسته‌های برق"
	if kind == "core":
		return "هسته‌ی حلقه"
	if kind == "secret":
		return "پایانه‌ی پنهان"
	return "تعامل"


func _process(delta):
	_t += delta
	if kind != "hide":
		queue_redraw()


func _draw():
	if kind == "hide":
		return
	var pulse = 0.5 + 0.5 * sin(_t * 3.0)
	if highlight:
		draw_arc(Vector2.ZERO, 20.0 + pulse * 3.0, 0.0, TAU, 28, Color(1, 0.85, 0.5, 0.9), 2.0)
	if kind == "pickup":
		_draw_pickup()
	elif kind == "note":
		draw_circle(Vector2.ZERO, 14.0, Color(1.0, 0.9, 0.6, 0.10 + 0.08 * pulse))
		draw_rect(Rect2(-8, -10, 16, 20), Color(0.85, 0.80, 0.65))
		for i in 4:
			draw_line(Vector2(-5, -6 + i * 4), Vector2(5, -6 + i * 4), Color(0.3, 0.25, 0.2), 1.0)
	elif kind == "fusebox":
		draw_rect(Rect2(-14, -14, 28, 28), Color(0.28, 0.28, 0.3))
		draw_rect(Rect2(-6, -6, 12, 12), Color(0.1, 0.1, 0.12))
		var led = Color(0.1, 0.9, 0.3) if state == 1 else Color(0.9, 0.1, 0.1)
		draw_circle(Vector2(8, -9), 3.0, led)
	elif kind == "panel":
		draw_rect(Rect2(-16, -14, 32, 28), Color(0.2, 0.2, 0.24))
		var cols = [Color(0.9, 0.1, 0.1), Color(0.2, 0.4, 1.0), Color(0.1, 0.8, 0.3), Color(0.95, 0.85, 0.1)]
		for i in 4:
			draw_circle(Vector2(-10 + i * 7, 0), 3.0, cols[i])
	elif kind == "core":
		var col = Color(0.6, 0.2, 1.0) if state == 0 else Color(0.2, 0.2, 0.25)
		draw_circle(Vector2.ZERO, 22.0 + pulse * 3.0 * (1 - state), Color(col.r, col.g, col.b, 0.25))
		draw_circle(Vector2.ZERO, 13.0, col)
		draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 20, Color(0.8, 0.8, 0.9), 2.0)
	elif kind == "secret":
		if Global.progress["notes"].size() >= 7:
			draw_rect(Rect2(-12, -10, 24, 20), Color(0.05, 0.2, 0.08))
			draw_rect(Rect2(-9, -7, 18, 12), Color(0.2, 0.9, 0.4, 0.7 + 0.3 * pulse))
		else:
			draw_rect(Rect2(-12, -10, 24, 20), Color(0.08, 0.08, 0.1))


func _draw_pickup():
	var pid = id
	draw_circle(Vector2.ZERO, 15.0, Color(1.0, 0.95, 0.7, 0.10 + 0.08 * (0.5 + 0.5 * sin(_t * 3.0))))
	if pid == "card":
		draw_rect(Rect2(-10, -6, 20, 12), Color(0.2, 0.7, 0.9))
		draw_rect(Rect2(-8, -2, 8, 3), Color(0.9, 0.95, 1.0))
	elif pid == "key":
		draw_circle(Vector2(-6, 0), 5.0, Color(0.95, 0.8, 0.2))
		draw_rect(Rect2(-2, -1.5, 13, 3), Color(0.95, 0.8, 0.2))
		draw_rect(Rect2(8, 1, 2, 4), Color(0.95, 0.8, 0.2))
	elif pid == "fuse":
		draw_rect(Rect2(-4, -9, 8, 18), Color(0.9, 0.55, 0.15))
		draw_rect(Rect2(-5, -10, 10, 3), Color(0.7, 0.7, 0.75))
		draw_rect(Rect2(-5, 7, 10, 3), Color(0.7, 0.7, 0.75))
	elif pid == "flashlight":
		draw_rect(Rect2(-9, -3, 14, 6), Color(0.35, 0.35, 0.4))
		draw_rect(Rect2(5, -4, 5, 8), Color(1.0, 0.9, 0.4))
	else:
		draw_rect(Rect2(-9, -8, 18, 16), Color(0.65, 0.1, 0.12))
		draw_rect(Rect2(-6, -5, 12, 3), Color(0.95, 0.9, 0.85))
		draw_rect(Rect2(-6, 0, 9, 2), Color(0.95, 0.9, 0.85))
