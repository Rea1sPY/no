extends Control
## منوی اصلی: عنوان نفس‌کشنده، راهروی مه‌گرفته، غبار شناور، سایه‌ای که گاهی
## نزدیک می‌شود و ورود نرم و پله‌پله‌ی دکمه‌ها.

signal start_game
signal quit_game

const UI = preload("res://scripts/ui.gd")
const Panels = preload("res://scripts/panels.gd")
const VERSION = "۲٫۰٫۰"

var _t = 0.0
var _flick = 1.0
var title_a = null
var title_b = null
var cont_btn = null
var _buttons = []
var _motes = []
var _ghost = 0.0
var _ghost_t = 5.0
var _ghost_side = 1.0
var _enter = 0.0
var _par = Vector2.ZERO
var _par_t = Vector2.ZERO
var _pop = 0.0


func _ready():
	UI.full_rect(self)
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	title_b = UI.label("یک دقیقه تا مرگ", 92, Color(0.55, 0.0, 0.05))
	title_a = UI.label("یک دقیقه تا مرگ", 92, UI.BONE)
	_build_center()
	_seed_motes()
	Sound.start_music()
	Sound.set_tension(0.0)
	for i in _buttons.size():
		var b = _buttons[i]
		b.modulate.a = 0.0
		var tw = create_tween()
		tw.tween_interval(0.25 + i * 0.075)
		tw.tween_property(b, "modulate:a", 1.0, 0.32)
	_enter = 0.0


func _build_center():
	var center = CenterContainer.new()
	UI.full_rect(center)
	add_child(center)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	var tbox = Control.new()
	tbox.custom_minimum_size = Vector2(900, 110)
	tbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(tbox)
	for t in [title_b, title_a]:
		t.custom_minimum_size = Vector2(900, 110)
		t.size = Vector2(900, 110)
		t.add_theme_constant_override("outline_size", 8)
		t.pivot_offset = Vector2(450, 55)
		tbox.add_child(t)
	title_b.position = Vector2(5, 3)
	title_b.modulate.a = 0.8
	box.add_child(UI.label("ONE MINUTE TO DIE  ·  FIRST PERSON", 24, UI.RED))
	var sp = Control.new()
	sp.custom_minimum_size = Vector2(0, 14)
	box.add_child(sp)
	var b1 = UI.button("شروع بازی", _on_new)
	var b2 = UI.button("ادامه بازی", _on_continue)
	var b3 = UI.button("دفترچه‌ی سرنخ‌ها", _open_notebook)
	var b4 = UI.button("تنظیمات", _open_settings)
	var b5 = UI.button("راهنمای بازی", _open_help)
	cont_btn = b2
	b2.disabled = not Global.can_continue()
	_buttons = [b1, b2, b3, b4, b5]
	for b in _buttons:
		b.custom_minimum_size = Vector2(420, 66)
		box.add_child(b)
	var credit = UI.label("ساخته‌شده توسط " + Global.CREATOR, 22, UI.DIM)
	box.add_child(credit)
	var best = "—"
	if Global.stats["best_time"] > 0.0:
		best = Global.fa(snappedf(Global.stats["best_time"], 0.1)) + " ثانیه"
	var meta = UI.label("مرگ‌ها: " + Global.fa(Global.progress["deaths"]) + "   ·   بهترین زمان: " + best + "   ·   نسخه " + VERSION, 17, Color(0.42, 0.36, 0.35))
	box.add_child(meta)


func _open_notebook():
	Panels.notebook(self)


func _open_settings():
	Panels.settings(self)


func _open_help():
	Panels.help(self)


func _on_new():
	if Global.can_continue():
		Panels.confirm(self, "پیشرفت قبلی پاک می‌شود. مطمئنی؟", _pick_difficulty)
	else:
		_pick_difficulty()


func _pick_difficulty():
	Panels.difficulty(self, _begin_new)


func _begin_new():
	Global.new_game()
	start_game.emit()


func _on_continue():
	if Global.can_continue():
		start_game.emit()


func _seed_motes():
	for i in 54:
		_motes.append({
			"p": Vector2(randf(), randf()),
			"v": Vector2(randf_range(-0.006, 0.006), randf_range(-0.02, -0.006)),
			"r": randf_range(0.6, 2.2),
			"a": randf_range(0.06, 0.3),
			"f": randf_range(0.5, 1.7),
		})


func _process(delta):
	_t += delta
	_enter = minf(1.0, _enter + delta * 0.7)
	_pop = minf(1.0, _pop + delta * 1.4)
	if OS.has_feature("mobile"):
		_par_t = Vector2(sin(_t * 0.21) * 12.0, cos(_t * 0.17) * 6.0)
	else:
		var mp = get_viewport().get_mouse_position()
		var hs = size * 0.5
		_par_t = (mp - hs) / maxf(1.0, hs.x) * 14.0
	_par = _par.lerp(_par_t, minf(1.0, delta * 1.8))
	_flick = 0.88 + 0.12 * sin(_t * 9.0) * sin(_t * 3.1)
	if randf() < 0.025:
		_flick *= 0.45
	if title_a != null:
		var s = (1.0 + 0.012 * sin(_t * 0.85)) * (0.93 + 0.07 * ease(_pop, 0.5))
		title_a.scale = Vector2(s, s)
		title_b.scale = Vector2(s, s)
		title_a.modulate.a = 0.92 + 0.08 * _flick
		if randf() < 0.07:
			title_a.position.x = randf_range(-4.0, 4.0)
			title_b.position.x = 5.0 + randf_range(-8.0, 8.0)
			title_b.position.y = 3.0 + randf_range(-3.0, 3.0)
		elif randf() < 0.3:
			title_a.position.x = 0.0
			title_b.position.x = 5.0
			title_b.position.y = 3.0
	_ghost_t -= delta
	if _ghost_t <= 0.0:
		_ghost = randf_range(0.35, 1.0)
		_ghost_side = -1.0 if randf() < 0.5 else 1.0
		_ghost_t = randf_range(6.0, 11.0)
	_ghost = maxf(0.0, _ghost - delta * 0.035)
	var vs = size
	for m in _motes:
		var p = m["p"] + m["v"] * delta
		p.y = fmod(p.y + 1.0, 1.0)
		p.x = fmod(p.x + 1.0, 1.0)
		m["p"] = p
	queue_redraw()


func _draw():
	var vs = size
	if vs.x < 20.0:
		return
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.013, 0.006, 0.014))
	var vp = Vector2(vs.x * 0.5 + sin(_t * 0.12) * 16.0 + _par.x, vs.y * 0.43 + _par.y)
	# درخشش قرمز پشت راهرو
	for i in 9:
		draw_circle(vp, 36.0 + i * 46.0, Color(0.55, 0.02, 0.04, 0.024 * _flick))
	# قاب‌های راهرو با عمق نرم
	for i in 12:
		var k = float(i) / 12.0
		var w = lerpf(vs.x * 0.62, vs.x * 0.055, k)
		var h = lerpf(vs.y * 1.02, vs.y * 0.09, k)
		var a = lerpf(0.10, 0.02, k)
		draw_rect(Rect2(vp - Vector2(w, h) * 0.5, Vector2(w, h)), Color(0.5, 0.03, 0.05, a * _flick), false, 1.6)
	# هاله‌ی نرم دور نشانگر، مثل نور گوشی روی دیوار
	var mg = get_viewport().get_mouse_position()
	if not OS.has_feature("mobile"):
		for i in 5:
			draw_circle(mg, 26.0 + i * 26.0, Color(0.9, 0.65, 0.35, 0.010 - i * 0.0015))
	# نور چراغ‌های دور
	for x in [-0.36, 0.36]:
		var lp = vp + Vector2(x * vs.x * 0.55, -vs.y * 0.11)
		draw_circle(lp, 18.0, Color(0.9, 0.55, 0.25, 0.035 * _flick))
		draw_circle(lp, 3.0, Color(1.0, 0.7, 0.35, 0.18 * _flick))
	# مه
	for i in 5:
		var y = vs.y * (0.3 + i * 0.12) + sin(_t * 0.4 + i) * 12.0
		draw_rect(Rect2(0, y, vs.x, 30.0 + i * 8.0), Color(0.4, 0.05, 0.07, 0.012))
	# سایه‌ی دور
	if _ghost > 0.01:
		var gh = vp + Vector2(_ghost_side * (vs.x * 0.16), vs.y * 0.06)
		var scale_g = 1.0 + _ghost * 0.9
		var alpha_g = 0.55 * minf(1.0, _ghost * 2.2)
		draw_rect(Rect2(gh.x - 9.0 * scale_g, gh.y - 36.0 * scale_g, 18.0 * scale_g, 48.0 * scale_g), Color(0.0, 0.0, 0.0, alpha_g))
		draw_circle(gh + Vector2(0, -30) * scale_g, 8.5 * scale_g, Color(0, 0, 0, alpha_g))
		if int(_t * 1.3) % 5 != 0:
			draw_circle(gh + Vector2(-3.2, -31) * scale_g, 1.5 * scale_g, Color(1.0, 0.08, 0.08, 0.6 + 0.4 * _ghost))
			draw_circle(gh + Vector2(3.2, -31) * scale_g, 1.5 * scale_g, Color(1.0, 0.08, 0.08, 0.6 + 0.4 * _ghost))
	# غبار
	for m in _motes:
		draw_circle(Vector2(m["p"].x * vs.x, m["p"].y * vs.y), m["r"], Color(0.9, 0.55, 0.5, m["a"] * _flick))
	# اسکن‌لاین
	var y = 0.0
	while y < vs.y:
		draw_rect(Rect2(0, y, vs.x, 1.0), Color(0, 0, 0, 0.13))
		y += 3.0
	var band = fmod(_t * 70.0, vs.y + 200.0) - 100.0
	draw_rect(Rect2(0, band, vs.x, 80.0), Color(0.5, 0.05, 0.07, 0.018))
	# حاشیه تاریک
	for i in 8:
		var m = float(i) * 6.0
		var a = 0.06 * (1.0 - float(i) / 8.0)
		draw_rect(Rect2(m, m, vs.x - m * 2.0, vs.y - m * 2.0), Color(0, 0, 0, a), false, 6.0)
	draw_rect(Rect2(0, 0, vs.x, 96), Color(0, 0, 0, 0.40))
	draw_rect(Rect2(0, vs.y - 100, vs.x, 100), Color(0, 0, 0, 0.55))
