extends Control
## چهره‌ی ترسناک هنگام گرفتار شدن (کاملاً با کد کشیده می‌شود).

var t = 0.0


func _process(delta):
	t += delta
	if visible:
		queue_redraw()


func _draw():
	var c = size * 0.5
	var k = minf(size.x, size.y) / 720.0
	var wob = Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0)) * k
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.88))
	# سر
	var head = PackedVector2Array()
	for i in 24:
		var a = TAU * float(i) / 24.0
		head.append(c + wob + Vector2(cos(a) * 190.0, sin(a) * 270.0) * k)
	draw_colored_polygon(head, Color(0.05, 0.03, 0.04))
	# چشم‌ها
	for sx in [-1.0, 1.0]:
		var e = c + wob + Vector2(sx * 85.0, -60.0) * k
		draw_circle(e, 54.0 * k, Color(0.5, 0.0, 0.05, 0.55))
		draw_circle(e, 34.0 * k, Color(1.0, 0.05, 0.1))
		draw_circle(e, 12.0 * k, Color(1.0, 0.9, 0.8))
	# دهان دندانه‌دار
	var m = PackedVector2Array()
	m.append(c + wob + Vector2(-120.0, 90.0) * k)
	for i in 9:
		var x = -120.0 + i * 30.0
		var y = 90.0 + (30.0 if i % 2 == 0 else 0.0)
		m.append(c + wob + Vector2(x, y) * k)
	m.append(c + wob + Vector2(120.0, 90.0) * k)
	m.append(c + wob + Vector2(120.0, 190.0) * k)
	m.append(c + wob + Vector2(-120.0, 190.0) * k)
	draw_colored_polygon(m, Color(0.55, 0.0, 0.06))
