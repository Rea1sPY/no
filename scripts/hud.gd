extends Control
## نمایش‌گر: تایمر ۶۰ ثانیه‌ای (همیشه بالای صفحه)، باتری چراغ‌قوه، آیتم‌ها، پیام‌ها و نشانه‌ی دیده‌شدن.

var time_left = 60.0
var loop_no = 1
var battery = 100.0
var has_flash = false
var items = []
var room_name = ""
var awareness = 0.0
var prompt = ""
var concealed = false
var danger = 0.0
var banner_text = ""
var banner_ttl = 0.0
var banner_color = Color(0.9, 0.1, 0.12)
var _toasts = []
var _t = 0.0
var _redraw_t = 0.0
var _prompt_a = 0.0
var _banner_a = 0.0
var _flash_a = 0.0


func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func toast(text):
	_toasts.append({"t": text, "ttl": 3.2})
	if _toasts.size() > 3:
		_toasts.pop_front()


func banner(text, ttl, color = Color(0.9, 0.1, 0.12)):
	banner_text = text
	banner_ttl = ttl
	banner_color = color


func _process(delta):
	_t += delta
	for t in _toasts:
		t["ttl"] -= delta
	while not _toasts.is_empty() and _toasts[0]["ttl"] <= 0.0:
		_toasts.pop_front()
	if banner_ttl > 0.0:
		banner_ttl -= delta
	_prompt_a = move_toward(_prompt_a, 1.0 if prompt != "" else 0.0, delta * 7.0)
	_banner_a = move_toward(_banner_a, 1.0 if banner_ttl > 0.0 else 0.0, delta * 5.0)
	_flash_a = move_toward(_flash_a, 1.0 if has_flash else 0.0, delta * 3.0)
	# رسم متن هر فریم لازم نیست؛ ۳۰ بار در ثانیه هم نرم دیده می‌شود و بار پردازنده را نصف می‌کند.
	_redraw_t += delta
	if _redraw_t >= 0.0333:
		_redraw_t = 0.0
		queue_redraw()


func _text(font, pos, text, size, color, width = -1.0, align = HORIZONTAL_ALIGNMENT_LEFT):
	draw_string(font, pos + Vector2(2, 2), text, align, width, size, Color(0, 0, 0, 0.9))
	draw_string(font, pos, text, align, width, size, color)


func _draw():
	var font = Global.get_font()
	var vs = get_viewport_rect().size
	if concealed:
		var bands = [[0.12, 0.32], [0.45, 0.56], [0.68, 1.0]]
		for b in bands:
			draw_rect(Rect2(0, vs.y * b[0], vs.x, vs.y * (b[1] - b[0])), Color(0.0, 0.0, 0.0, 0.93))
		for yy in [0.32, 0.56]:
			draw_rect(Rect2(0, vs.y * yy, vs.x, 2.0), Color(0.55, 0.45, 0.28, 0.35))
	var secs = int(ceil(maxf(0.0, time_left)))
	var low = time_left <= 10.0
	var tc = Color(0.95, 0.9, 0.85)
	if low:
		tc = Color(1.0, 0.15, 0.15) if int(_t * 4.0) % 2 == 0 else Color(1.0, 0.5, 0.45)
	draw_rect(Rect2(vs.x * 0.5 - 90.0, 10.0, 180.0, 78.0), Color(0, 0, 0, 0.45))
	_text(font, Vector2(vs.x * 0.5 - 90.0, 74.0), Global.fa(secs), 68, tc, 180.0, HORIZONTAL_ALIGNMENT_CENTER)
	var frac = clampf(time_left / 60.0, 0.0, 1.0)
	draw_rect(Rect2(vs.x * 0.5 - 90.0, 92.0, 180.0, 6.0), Color(0.2, 0.05, 0.06))
	draw_rect(Rect2(vs.x * 0.5 - 90.0, 92.0, 180.0 * frac, 6.0), tc)
	# حلقه و اتاق
	var info = "حلقه " + Global.fa(loop_no) + " · " + Global.diff()["name"]
	_text(font, Vector2(130, 40), info, 22, Color(0.85, 0.8, 0.78), 300.0)
	if room_name != "":
		_text(font, Vector2(130, 66), room_name, 20, Color(0.6, 0.55, 0.55), 300.0)
	# باتری چراغ‌قوه
	if _flash_a > 0.01:
		draw_rect(Rect2(130, 80, 150, 12), Color(0.15, 0.05, 0.06, _flash_a))
		var bc = Color(0.9, 0.8, 0.3, _flash_a)
		if battery < 25.0:
			bc = Color(0.9, 0.2, 0.15, _flash_a)
		draw_rect(Rect2(130, 80, 150.0 * battery / 100.0, 12), bc)
		_text(font, Vector2(290, 92), "باتری", 18, Color(0.8, 0.75, 0.7, _flash_a))
	# آیتم‌ها
	var y = 150.0
	for it in items:
		_text(font, Vector2(vs.x - 340.0, y), "• " + it, 22, Color(0.95, 0.88, 0.7), 320.0, HORIZONTAL_ALIGNMENT_RIGHT)
		y += 28.0
	# نشانه‌ی وسط صفحه
	if not concealed:
		var cc = Vector2(vs.x * 0.5, vs.y * 0.5)
		var focus = prompt != ""
		var col = Color(1.0, 0.78, 0.35, 0.9) if focus else Color(0.85, 0.82, 0.78, 0.55)
		var gap = 7.0 if focus else 9.0
		var ln = 10.0 if focus else 7.0
		draw_line(cc + Vector2(-gap - ln, 0), cc + Vector2(-gap, 0), col, 2.0)
		draw_line(cc + Vector2(gap, 0), cc + Vector2(gap + ln, 0), col, 2.0)
		draw_line(cc + Vector2(0, -gap - ln), cc + Vector2(0, -gap), col, 2.0)
		draw_line(cc + Vector2(0, gap), cc + Vector2(0, gap + ln), col, 2.0)
		draw_circle(cc, 1.6, col)
	# نشانه‌ی دیده‌شدن
	if awareness > 0.04:
		var a = clampf(awareness, 0.0, 1.0)
		var c = Vector2(vs.x * 0.5, 130.0)
		draw_circle(c, 18.0, Color(0.9, 0.1, 0.1, 0.15 + 0.5 * a))
		draw_circle(c, 7.0, Color(1.0, 0.95, 0.9, a))
	# پیام‌ها
	var ty = vs.y - 210.0
	for i in range(_toasts.size() - 1, -1, -1):
		var tt = _toasts[i]
		var al = clampf(tt["ttl"], 0.0, 1.0)
		_text(font, Vector2(vs.x * 0.5 - 360.0, ty), tt["t"], 26, Color(1, 0.95, 0.9, al), 720.0, HORIZONTAL_ALIGNMENT_CENTER)
		ty -= 34.0
	if _prompt_a > 0.01:
		var pa = _prompt_a
		_text(font, Vector2(vs.x * 0.5 - 300.0, vs.y - 60.0 + (1.0 - pa) * 8.0), prompt, 26, Color(1.0, 0.85, 0.5, pa), 600.0, HORIZONTAL_ALIGNMENT_CENTER)
	if banner_ttl > 0.0 or _banner_a > 0.01:
		var ba = clampf(banner_ttl, 0.0, 1.0) * _banner_a
		var bcol = Color(banner_color.r, banner_color.g, banner_color.b, ba)
		_text(font, Vector2(vs.x * 0.5 - 500.0, vs.y * 0.45 + (1.0 - _banner_a) * 14.0), banner_text, 84, bcol, 1000.0, HORIZONTAL_ALIGNMENT_CENTER)
	if concealed:
		_text(font, Vector2(vs.x * 0.5 - 300.0, vs.y - 96.0), "پنهان شده‌ای", 22, Color(0.85, 0.8, 0.7), 600.0, HORIZONTAL_ALIGNMENT_CENTER)
