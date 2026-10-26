extends Control
## صفحه‌ی بارگذاری سینمایی: لوگوی گلیچی، غبار و اسکن‌لاین، گزارش راه‌اندازی،
## نوار پیشرفت مرحله‌ای، نکته‌های تصادفی و انتقال نرم به منوی اصلی.

signal finished

const UI = preload("res://scripts/ui.gd")
const BarScript = preload("res://scripts/load_bar.gd")

const VERSION = "۲٫۰٫۰"
const BUILD = "BUILD 06 · FIRST PERSON 3D"

const TIPS = [
	"برای نگاه کردن، سمت راست صفحه را بکش؛ جوی‌استیک چپ حرکت است.",
	"چراغ‌قوه از ابتدا در دستت است؛ پرتو واقعی روی دیوار و در می‌افتد.",
	"دویدن صدا دارد؛ موجود صدای پا را می‌شنود.",
	"چراغ‌قوه باتری دارد. بی‌مورد روشنش نکن.",
	"کمدها پناهگاه‌اند، ولی او یاد می‌گیرد کجا قایم می‌شوی.",
	"هر حلقه دقیقاً ۶۰ ثانیه است؛ رمزها در دفترچه می‌مانند.",
	"اشتباه در معماها سر و صدا می‌کند و او را می‌کشاند.",
	"سه سند محرمانه پایانی دیگر را باز می‌کند.",
	"قبل از باز کردن در، نفس بگیر و گوش کن.",
	"هر بار که می‌میری، او بیشتر درباره‌ات می‌داند.",
]

var STAGES = [
	{"name": "بارگذاری هسته", "to": 0.12, "dur": 0.55, "log": "boot::core ................. OK"},
	{"name": "خواندن نقشه‌ی ساختمان", "to": 0.28, "dur": 0.60, "log": "map::rooms=%d doors=%d ....... OK"},
	{"name": "سنتز صداها", "to": 0.42, "dur": 0.50, "log": "audio::synth streams=18 .... OK"},
	{"name": "بارگذاری بافت‌ها و ساخت اتاق‌ها", "to": 0.58, "dur": 0.70, "log": "world::tex 2048 rooms ... OK"},
	{"name": "بیدار کردن ساکن", "to": 0.72, "dur": 0.55, "log": "ai::memory ................. OK"},
	{"name": "بازسازی حلقه‌ی ۶۰ ثانیه", "to": 0.87, "dur": 0.50, "log": "loop::60.0s ................ ARMED"},
	{"name": "اتصال به اتاق امنیت", "to": 1.00, "dur": 0.45, "log": "resident::awake ............ !!"},
]


var _t = 0.0
var _flick = 1.0
var _p = 0.0
var _target = 0.0
var _glitch = 0.0
var _done = false
var _skipped = false
var _stage_i = 0
var _tip_t = 0.0
var _tip_i = -1

var _logo = null
var _glitch_a = null
var _glitch_b = null
var _status = null
var _stage = null
var _pct = null
var _tip = null
var _bar = null
var _logs = null
var _enter = null
var _skip = null
var _rec = null

var _embers = []
var _grain = null
var _vig = null


func _ready():
	UI.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	process_mode = Node.PROCESS_MODE_ALWAYS
	_grain = _grain_tex()
	_build()
	_seed_embers()
	_run()


func _build():
	var center = CenterContainer.new()
	UI.full_rect(center)
	center.offset_top = 96.0
	center.offset_bottom = -320.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(box)

	var holder = Control.new()
	holder.custom_minimum_size = Vector2(980, 132)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(holder)

	_glitch_b = UI.label("یک دقیقه تا مرگ", 84, Color(0.45, 0.0, 0.04, 0.75))
	_glitch_a = UI.label("یک دقیقه تا مرگ", 84, Color(0.15, 0.55, 0.62, 0.28))
	_logo = UI.label("یک دقیقه تا مرگ", 84, UI.BONE)
	for l in [_glitch_b, _glitch_a, _logo]:
		l.size = Vector2(980, 132)
		l.position = Vector2.ZERO
		l.add_theme_constant_override("outline_size", 9)
		holder.add_child(l)
	_glitch_b.position = Vector2(5, 3)
	_glitch_a.position = Vector2(-4, -2)

	_status = UI.label("ONE  MINUTE  TO  DIE", 20, Color(0.85, 0.15, 0.18, 0.9))
	box.add_child(_status)

	var sp0 = Control.new()
	sp0.custom_minimum_size = Vector2(0, 26)
	box.add_child(sp0)

	var line = ColorRect.new()
	line.color = Color(0.30, 0.04, 0.07, 0.9)
	line.custom_minimum_size = Vector2(520, 2)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(line)

	var tag = UI.label("مرکز تحقیقات — بخش ۷ · دسترسی ممنوع", 19, UI.DIM)
	box.add_child(tag)

	# ---------- نوار بالا: رد کردن ----------
	_skip = UI.button("رد کردن بارگذاری", _skip_pressed, 19)
	_skip.custom_minimum_size = Vector2(210, 46)
	_skip.position = Vector2(24, 20)
	add_child(_skip)

	# ---------- نوار بالا: نشانگر ضبط ----------
	_rec = UI.label("●  REC", 17, Color(0.9, 0.16, 0.18))
	_rec.position = Vector2(1090, 22)
	_rec.size = Vector2(160, 30)
	_rec.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rec)

	# ---------- نوار پایین: نکته، پیشرفت، وضعیت ----------
	var bottom = VBoxContainer.new()
	bottom.anchor_left = 0.0
	bottom.anchor_right = 1.0
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_left = 90.0
	bottom.offset_right = -90.0
	bottom.offset_top = -320.0
	bottom.offset_bottom = -26.0
	bottom.add_theme_constant_override("separation", 9)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)

	_tip = UI.label("", 20, Color(0.70, 0.62, 0.60))
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.custom_minimum_size = Vector2(0, 30)
	bottom.add_child(_tip)

	_bar = BarScript.new()
	_bar.custom_minimum_size = Vector2(0, 14)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(_bar)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(row)

	_stage = UI.label("در حال آماده‌سازی", 20, UI.BONE)
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_stage)

	_pct = UI.label("۰٪", 22, UI.RED)
	_pct.custom_minimum_size = Vector2(70, 0)
	_pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(_pct)

	_logs = VBoxContainer.new()
	_logs.add_theme_constant_override("separation", 2)
	_logs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(_logs)

	_enter = UI.button("ورود به ساختمان", _enter_pressed, 24)
	_enter.custom_minimum_size = Vector2(320, 58)
	_enter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_enter.visible = false
	bottom.add_child(_enter)

	var meta = UI.label("نسخه " + VERSION + "   ·   " + BUILD + "   ·   ساخته‌شده توسط " + Global.CREATOR, 16, Color(0.42, 0.36, 0.35))
	bottom.add_child(meta)

	_vig = TextureRect.new()
	UI.full_rect(_vig)
	_vig.texture = _vig_tex()
	_vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vig.stretch_mode = TextureRect.STRETCH_SCALE
	_vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vig)

	_next_tip()


func _run():
	await get_tree().process_frame
	for i in STAGES.size():
		if _done:
			return
		var st = STAGES[i]
		_stage_i = i
		_stage.text = st["name"]
		_target = float(st["to"])
		var line = st["log"]
		if line.contains("%d"):
			line = line % [Global.data["rooms"].size(), Global.data["doors"].size()]
		_add_log(line)
		if i == 3:
			Sound.sfx("whisper", -26.0, 0.85)
		if i == 5:
			_glitch = 0.55
			Sound.sfx("rewind", -28.0, 1.4)
		await get_tree().create_timer(float(st["dur"])).timeout
	if _done:
		return
	_p = 1.0
	_target = 1.0
	_finish_load()


func _add_log(text):
	## فقط سه خط آخر نگه داشته می‌شود تا گزارش با عنوان بزرگ قاطی نشود.
	while _logs.get_child_count() >= 3:
		var old = _logs.get_child(0)
		_logs.remove_child(old)
		old.queue_free()
	var l = UI.label(text, 16, Color(0.58, 0.45, 0.44))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.text_direction = Control.TEXT_DIRECTION_LTR
	l.modulate.a = 0.0
	_logs.add_child(l)
	var tw = create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.18)


func _next_tip():
	_tip_i = (_tip_i + 1) % TIPS.size()
	_tip.text = "نکته: " + TIPS[_tip_i]


func _finish_load():
	if _done:
		return
	_done = true
	_p = 1.0
	_target = 1.0
	_stage.text = "آماده"
	_pct.text = Global.fa(100) + "٪"
	_bar.value = 1.0
	_bar.hot = 1.0
	Sound.sfx("success", -8.0, 1.0)
	_skip.disabled = true
	_skip.modulate.a = 0.4
	_status.text = "سیستم آماده است"
	_status.add_theme_color_override("font_color", UI.RED)
	_enter.visible = true
	_enter.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(_enter, "modulate:a", 1.0, 0.3)
	var pulse = create_tween()
	pulse.set_loops(0)
	pulse.tween_property(_enter, "modulate", Color(0.82, 0.72, 0.72, 1.0), 0.7)
	pulse.tween_property(_enter, "modulate", Color(1, 1, 1, 1), 0.7)


func skip():
	if _done:
		return
	_skipped = true
	_add_log("skip::requested ............. OK")
	_finish_load()


func _skip_pressed():
	skip()


func _enter_pressed():
	if not _done:
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Sound.sfx("door", -10.0, 0.85)
	var tw = create_tween()
	tw.tween_property(_enter, "modulate:a", 0.0, 0.2)
	tw.tween_property(self, "modulate:a", 0.0, 0.45)
	tw.tween_callback(_leave)


func _leave():
	finished.emit()
	queue_free()


func _gui_input(event):
	if not _done:
		return
	if event is InputEventMouseButton and event.pressed:
		_enter_pressed()
	elif event is InputEventScreenTouch and event.pressed:
		_enter_pressed()


func _unhandled_input(event):
	if not _done:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_enter_pressed()


func _seed_embers():
	var vs = get_viewport_rect().size
	for i in 46:
		_embers.append({
			"p": Vector2(randf() * vs.x, randf() * vs.y),
			"v": Vector2(randf_range(-9.0, 9.0), randf_range(-26.0, -7.0)),
			"r": randf_range(0.8, 2.6),
			"a": randf_range(0.08, 0.34),
			"f": randf_range(0.6, 1.8),
		})


func _grain_tex():
	var img = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var v = randf()
			img.set_pixel(x, y, Color(1, 1, 1, v * 0.5))
	return ImageTexture.create_from_image(img)


func _vig_tex():
	var img = Image.create(96, 96, false, Image.FORMAT_RGBA8)
	for y in 96:
		for x in 96:
			var d = Vector2(x - 47.5, y - 47.5) / 47.5
			var v = clampf((d.length() - 0.45) / 0.75, 0.0, 1.0)
			img.set_pixel(x, y, Color(0, 0, 0, pow(v, 1.6) * 0.9))
	return ImageTexture.create_from_image(img)


func _process(delta):
	_t += delta
	_flick = 0.92 + 0.08 * sin(_t * 11.0) * sin(_t * 3.7)
	if randf() < delta * 0.9:
		_flick *= 0.55
	if _glitch > 0.0:
		_glitch = maxf(0.0, _glitch - delta)
	elif randf() < delta * 0.55:
		_glitch = randf_range(0.12, 0.24)

	if not _done:
		_p = lerpf(_p, _target, minf(1.0, delta * 3.2))
		if _target - _p < 0.002:
			_p = _target
	_bar.value = _p
	_bar.hot = maxf(_bar.hot, 0.55 if _glitch > 0.0 else 0.0)
	if not _done:
		_pct.text = Global.fa(int(round(_p * 100.0))) + "٪"

	_tip_t += delta
	if _tip_t > 2.4 and not _done:
		_tip_t = 0.0
		_next_tip()
		_tip.modulate.a = 0.35
		var tw = create_tween()
		tw.tween_property(_tip, "modulate:a", 1.0, 0.35)

	_rec.modulate.a = 0.25 + 0.75 * absf(sin(_t * 2.2))

	var g = clampf(_glitch * 3.0, 0.0, 1.0)
	if _logo != null:
		if g > 0.02:
			_logo.position.x = randf_range(-6.0, 6.0) * g
			_glitch_a.position = Vector2(randf_range(-9.0, 9.0) * g, randf_range(-3.0, 3.0) * g)
			_glitch_b.position = Vector2(randf_range(-3.0, 12.0) * g, randf_range(-4.0, 4.0) * g)
			_logo.modulate.a = 0.72 + 0.28 * randf()
		else:
			_logo.position.x = 0.0
			_glitch_a.position = Vector2(-4, -2)
			_glitch_b.position = Vector2(5, 3)
			_logo.modulate.a = 1.0

	var vs = size
	for e in _embers:
		var p = e["p"] + e["v"] * delta
		p.x += sin(_t * e["f"] + p.y * 0.02) * 6.0 * delta
		if p.y < -12.0:
			p = Vector2(randf() * vs.x, vs.y + 12.0)
		if p.x < -12.0:
			p.x = vs.x + 12.0
		elif p.x > vs.x + 12.0:
			p.x = -12.0
		e["p"] = p
	queue_redraw()


func _draw():
	var vs = size
	if vs.x < 10.0 or vs.y < 10.0:
		return
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.012, 0.006, 0.014))

	var c = Vector2(vs.x * 0.5, vs.y * 0.42)
	for i in 7:
		draw_circle(c, 70.0 + i * 52.0, Color(0.46, 0.02, 0.05, 0.021 * _flick))

	for e in _embers:
		draw_circle(e["p"], e["r"], Color(0.92, 0.28, 0.22, e["a"] * _flick))

	var y = 0.0
	while y < vs.y:
		draw_rect(Rect2(0, y, vs.x, 1), Color(0, 0, 0, 0.17))
		y += 3.0

	var band = fmod(_t * 95.0, vs.y + 220.0) - 110.0
	draw_rect(Rect2(0, band, vs.x, 96), Color(0.5, 0.05, 0.07, 0.035))

	if _grain != null:
		var off = Vector2(fmod(_t * 39.0, 128.0), fmod(_t * 57.0, 128.0))
		draw_texture_rect(_grain, Rect2(-off, vs + Vector2(128, 128)), true, Color(1, 1, 1, 0.055))

	if _glitch > 0.02:
		var n = int(2 + 7 * clampf(_glitch * 3.0, 0.0, 1.0))
		for i in n:
			var yy = randf() * vs.y
			var hh = randf_range(2.0, 16.0)
			var xx = randf_range(-30.0, 30.0)
			draw_rect(Rect2(xx, yy, vs.x, hh), Color(1.0, 0.10, 0.16, 0.04 + 0.10 * randf()))

	# گوشه‌های قاب
	var m = 16.0
	var L = 30.0
	var col = Color(0.42, 0.06, 0.09, 0.75)
	draw_line(Vector2(m, m), Vector2(m + L, m), col, 2.0)
	draw_line(Vector2(m, m), Vector2(m, m + L), col, 2.0)
	draw_line(Vector2(vs.x - m, m), Vector2(vs.x - m - L, m), col, 2.0)
	draw_line(Vector2(vs.x - m, m), Vector2(vs.x - m, m + L), col, 2.0)
	draw_line(Vector2(m, vs.y - m), Vector2(m + L, vs.y - m), col, 2.0)
	draw_line(Vector2(m, vs.y - m), Vector2(m, vs.y - m - L), col, 2.0)
	draw_line(Vector2(vs.x - m, vs.y - m), Vector2(vs.x - m - L, vs.y - m), col, 2.0)
	draw_line(Vector2(vs.x - m, vs.y - m), Vector2(vs.x - m, vs.y - m - L), col, 2.0)
