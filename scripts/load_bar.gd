extends Control
## نوار پیشرفت صفحه‌ی بارگذاری: ریل تیره، پرشدن قرمز، خط‌های بخش‌بندی و سرِ درخشان.

var value = 0.0
var hot = 0.0
var _t = 0.0


func _process(delta):
	_t += delta
	hot = maxf(0.0, hot - delta * 1.8)
	queue_redraw()


func _draw():
	var vs = size
	if vs.x < 6.0 or vs.y < 6.0:
		return
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.045, 0.02, 0.03, 0.94), true)
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.32, 0.05, 0.08, 0.85), false, 1.0)
	var w = (vs.x - 4.0) * clampf(value, 0.0, 1.0)
	if w > 0.5:
		var fill = Rect2(Vector2(2, 2), Vector2(w, vs.y - 4.0))
		draw_rect(fill, Color(0.60, 0.05, 0.09), true)
		draw_rect(fill, Color(0.95, 0.22, 0.26, 0.45 + 0.55 * hot), false, 1.0)
		var pulse = 0.30 + 0.30 * sin(_t * 6.0)
		draw_rect(Rect2(Vector2(2 + w - 2.0, 0), Vector2(2.0, vs.y)), Color(1.0, 0.45, 0.45, pulse + 0.3 * hot), true)
	var x = 28.0
	while x < vs.x - 2.0:
		draw_line(Vector2(x, 1), Vector2(x, vs.y - 1), Color(0, 0, 0, 0.40), 1.0)
		x += 28.0
	var sx = fmod(_t * 190.0, vs.x)
	draw_rect(Rect2(Vector2(sx, 0), Vector2(2, vs.y)), Color(1.0, 0.6, 0.6, 0.10), true)
