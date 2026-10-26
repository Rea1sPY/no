extends Control
## کنترل لمسی دید اول‌شخص: جوی‌استیک شناور سمت چپ برای حرکت، کشیدن سمت راست
## برای چرخاندن سر، و دکمه‌های تعامل/دویدن/چراغ/دفترچه/توقف.
## روی کامپیوتر: WASD، Shift، E، F، N، Esc و ماوس.

signal interact_pressed
signal flash_pressed
signal notebook_pressed
signal pause_pressed

var move_vec = Vector2.ZERO
var run_held = false
var flash_on = false
var battery = 100.0
var has_target = false
var hint_text = ""
var hint_ttl = 0.0
var _look_acc = Vector2.ZERO

var _joy_idx = -1
var _look_idx = -1
var _joy_center = Vector2.ZERO
var _joy_pos = Vector2.ZERO
var _look_last = Vector2.ZERO
var _btn_touch = {}
var _buttons = {}
var _radius = 95.0
var _default_center = Vector2(170, 560)
var _t = 0.0
var _last_size = Vector2.ZERO
var _last_scale = -1.0
var _press = {}
var _redraw_t = 0.0
var _knob_draw = Vector2.ZERO


func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	_layout(true)


func reset():
	_joy_idx = -1
	_look_idx = -1
	_btn_touch = {}
	_press = {}
	move_vec = Vector2.ZERO
	run_held = false
	_look_acc = Vector2.ZERO
	queue_redraw()


func hint(text, ttl = 7.0):
	hint_text = text
	hint_ttl = ttl


func take_look():
	var v = _look_acc
	_look_acc = Vector2.ZERO
	return v


func _layout(force = false):
	var vs = get_viewport_rect().size
	var sc = float(Global.settings.get("ui_scale", 1.0))
	if not force and vs == _last_size and absf(sc - _last_scale) < 0.001:
		return
	_last_size = vs
	_last_scale = sc
	var s = sc
	_radius = 95.0 * s
	_default_center = Vector2(170.0 * s, vs.y - 160.0 * s)
	_buttons = {
		"interact": {"c": Vector2(vs.x - 128.0 * s, vs.y - 138.0 * s), "r": 78.0 * s, "t": "تعامل"},
		"run": {"c": Vector2(vs.x - 268.0 * s, vs.y - 92.0 * s), "r": 56.0 * s, "t": "دویدن"},
		"flash": {"c": Vector2(vs.x - 96.0 * s, vs.y - 288.0 * s), "r": 54.0 * s, "t": "چراغ"},
		"notebook": {"c": Vector2(vs.x - 68.0 * s, 74.0 * s), "r": 44.0 * s, "t": "دفترچه"},
		"pause": {"c": Vector2(68.0 * s, 74.0 * s), "r": 40.0 * s, "t": "توقف"},
	}


func _hit(pos):
	var best = ""
	var bd = 1e9
	for k in _buttons:
		var b = _buttons[k]
		var d = pos.distance_to(b["c"])
		if d <= b["r"] * 1.18 and d < bd:
			bd = d
			best = k
	return best


func _input(event):
	if event is InputEventScreenTouch:
		if event.pressed:
			_down(event.index, event.position)
		else:
			_up(event.index)
	elif event is InputEventScreenDrag:
		_drag(event.index, event.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.keycode == KEY_SPACE:
			interact_pressed.emit()
		elif event.keycode == KEY_F:
			flash_pressed.emit()
		elif event.keycode == KEY_N or event.keycode == KEY_TAB:
			notebook_pressed.emit()
		elif event.keycode == KEY_ESCAPE:
			pause_pressed.emit()


func _down(idx, pos):
	var k = _hit(pos)
	if k != "":
		_btn_touch[idx] = k
		_press[k] = 1.0
		Global.vibrate(15)
		if k == "run":
			run_held = true
		elif k == "interact":
			interact_pressed.emit()
		elif k == "flash":
			flash_pressed.emit()
		elif k == "notebook":
			notebook_pressed.emit()
		elif k == "pause":
			pause_pressed.emit()
		queue_redraw()
		return
	if _joy_idx == -1 and pos.x < get_viewport_rect().size.x * 0.46 and pos.y > 120.0:
		_joy_idx = idx
		_joy_center = pos
		_joy_pos = pos
		move_vec = Vector2.ZERO
		queue_redraw()
		return
	if _look_idx == -1:
		_look_idx = idx
		_look_last = pos


func _up(idx):
	if idx == _joy_idx:
		_joy_idx = -1
		move_vec = Vector2.ZERO
	if idx == _look_idx:
		_look_idx = -1
	if _btn_touch.has(idx):
		if _btn_touch[idx] == "run":
			run_held = false
		_btn_touch.erase(idx)
	queue_redraw()


func _drag(idx, pos):
	if idx == _joy_idx:
		var off = pos - _joy_center
		if off.length() > _radius * 1.6:
			_joy_center = pos - off.normalized() * _radius * 1.6
			off = pos - _joy_center
		_joy_pos = pos
		var sens = float(Global.settings.get("joy_sens", 1.0))
		var v = off / (_radius / sens)
		if v.length() < 0.12:
			v = Vector2.ZERO
		move_vec = v.limit_length(1.0)
		queue_redraw()
	elif idx == _look_idx:
		_look_acc += pos - _look_last
		_look_last = pos


func _process(delta):
	_t += delta
	_layout()
	if _joy_idx == -1:
		var kv = Vector2(
			float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
			float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)))
		if kv != Vector2.ZERO:
			move_vec = kv.normalized()
			run_held = Input.is_key_pressed(KEY_SHIFT)
		elif not _btn_touch.values().has("run"):
			move_vec = Vector2.ZERO
			run_held = false
	for k in _press.keys():
		_press[k] = maxf(0.0, _press[k] - delta * 5.0)
	if hint_ttl > 0.0:
		hint_ttl -= delta
	# ۳۰ فریم در ثانیه برای رسم لمس کافی است و پردازنده را آزاد می‌کند.
	_redraw_t += delta
	if _redraw_t >= 0.0333:
		_redraw_t = 0.0
		queue_redraw()


func _draw():
	var font = Global.get_font()
	var s = float(Global.settings.get("ui_scale", 1.0))
	var base_center = _default_center
	var knob = _default_center
	var alpha = 0.20
	if _joy_idx != -1:
		base_center = _joy_center
		knob = _joy_center + (_joy_pos - _joy_center).limit_length(_radius)
		alpha = 0.38
	_knob_draw = _knob_draw.lerp(knob, 0.35)
	knob = _knob_draw
	draw_circle(base_center, _radius, Color(0.12, 0.01, 0.02, alpha))
	draw_circle(base_center, _radius * 0.94, Color(0.3, 0.03, 0.05, alpha * 0.5))
	draw_arc(base_center, _radius, 0.0, TAU, 40, Color(0.85, 0.12, 0.16, alpha + 0.22), 2.5)
	draw_circle(knob, _radius * 0.4, Color(0.8, 0.1, 0.14, alpha + 0.28))
	draw_arc(knob, _radius * 0.4, 0.0, TAU, 28, Color(1.0, 0.3, 0.32, alpha + 0.35), 2.0)
	for k in _buttons:
		var b = _buttons[k]
		var pressed = _btn_touch.values().has(k)
		var col = Color(0.16, 0.02, 0.03, 0.40)
		if pressed:
			col = Color(0.75, 0.08, 0.12, 0.75)
		if k == "flash" and flash_on:
			col = Color(0.6, 0.5, 0.1, 0.62)
		if k == "interact" and has_target:
			col = Color(0.62, 0.38, 0.06, 0.55)
		var pu = float(_press.get(k, 0.0))
		var rr = b["r"] * (1.0 + 0.07 * pu)
		draw_circle(b["c"], rr, col)
		draw_arc(b["c"], rr, 0.0, TAU, 36, Color(0.95, 0.2, 0.25, 0.8), 2.5)
		if k == "interact" and has_target:
			var pulse = 0.5 + 0.5 * sin(_t * 4.0)
			draw_arc(b["c"], rr + 5.0 + pulse * 4.0, 0.0, TAU, 40, Color(1.0, 0.75, 0.3, 0.25 + 0.35 * pulse), 2.0)
		draw_string(font, b["c"] + Vector2(-b["r"], 8.0 * s), b["t"], HORIZONTAL_ALIGNMENT_CENTER, b["r"] * 2.0, int(22.0 * s), Color(1, 0.92, 0.9, 0.95))
		if k == "flash":
			var frac = clampf(battery / 100.0, 0.0, 1.0)
			draw_arc(b["c"], rr + 5.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 32, Color(0.95, 0.8, 0.3, 0.9), 3.0)
	if hint_ttl > 0.0 and hint_text != "":
		var a = clampf(hint_ttl, 0.0, 1.0)
		var vs = get_viewport_rect().size
		draw_string(font, Vector2(vs.x * 0.5 - 380.0, vs.y * 0.5 + 150.0), hint_text, HORIZONTAL_ALIGNMENT_CENTER, 760.0, int(20.0 * s), Color(0.9, 0.82, 0.75, 0.75 * a))
