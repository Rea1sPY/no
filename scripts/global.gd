extends Node
## وضعیت سراسری: تنظیمات، ذخیره‌سازی، پیشرفت دائمی، حافظه‌ی دشمن (یادگیری از حلقه‌های قبل).

signal settings_changed

const SAVE_PATH = "user://save.json"
const DataScript = preload("res://scripts/data.gd")
const SUPPORT_URL = "https://t.me/MateoHastam"
const CREATOR = "ReaLsPY"

var data = DataScript.DATA
var settings = {}
var progress = {}
var stats = {}
var endings = []
var memory = {}
var _light_tex = null
var ui_font = null
var _cone_tex = null


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_defaults()
	load_game()


func _defaults():
	settings = {
		"music": 0.7, "sfx": 0.9, "mute_music": false, "mute_sfx": false,
		"joy_sens": 1.0, "look_sens": 1.0, "invert_look": false,
		"ui_scale": 1.0, "vibration": true, "shake": true,
		"difficulty": "medium", "fx_high": true
	}
	stats = {"total_deaths": 0, "best_time": 0.0, "best_survival": 0.0}
	endings = []
	reset_progress()


func reset_progress():
	progress = {
		"started": false, "loop": 0, "deaths": 0,
		"notes": [], "docs": [], "code": [null, null, null, null],
		"levers": [], "wires": {}, "has_flashlight": false
	}
	memory = {"escape": {}, "hide": {}, "death": {}, "route": {}}


func diff():
	return data["difficulty"][settings["difficulty"]]


# ---------- ذخیره و بازیابی ----------
func save_game():
	var d = {"version": 1, "settings": settings, "progress": progress, "stats": stats, "endings": endings, "memory": memory}
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(d))
	f.close()


func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var text = FileAccess.get_file_as_string(SAVE_PATH)
	var d = JSON.parse_string(text)
	if typeof(d) != TYPE_DICTIONARY:
		return
	if d.has("settings") and typeof(d["settings"]) == TYPE_DICTIONARY:
		for k in d["settings"]:
			if settings.has(k):
				settings[k] = d["settings"][k]
	if d.has("progress") and typeof(d["progress"]) == TYPE_DICTIONARY:
		for k in d["progress"]:
			if progress.has(k):
				progress[k] = d["progress"][k]
	if d.has("stats") and typeof(d["stats"]) == TYPE_DICTIONARY:
		for k in d["stats"]:
			if stats.has(k):
				stats[k] = d["stats"][k]
	progress["loop"] = int(progress["loop"])
	progress["deaths"] = int(progress["deaths"])
	stats["total_deaths"] = int(stats["total_deaths"])
	if d.has("endings") and typeof(d["endings"]) == TYPE_ARRAY:
		endings = d["endings"]
	if d.has("memory") and typeof(d["memory"]) == TYPE_DICTIONARY:
		for k in memory:
			if d["memory"].has(k) and typeof(d["memory"][k]) == TYPE_DICTIONARY:
				memory[k] = d["memory"][k]


func set_setting(key, value):
	settings[key] = value
	settings_changed.emit()
	save_game()


func new_game():
	reset_progress()
	progress["started"] = true
	save_game()


func can_continue():
	return bool(progress.get("started", false))


# ---------- پیشرفت و سرنخ‌ها ----------
func has_note(id):
	return progress["notes"].has(id)


func add_note(id):
	## اگر یادداشت تازه باشد true برمی‌گرداند و سرنخ‌هایش را در دفترچه ثبت می‌کند.
	if progress["notes"].has(id):
		return false
	progress["notes"].append(id)
	for n in data["notes"]:
		if n["id"] == id:
			var rv = n["reveals"]
			if rv.has("code"):
				for k in rv["code"]:
					progress["code"][int(k)] = int(rv["code"][k])
			if rv.has("levers"):
				progress["levers"] = rv["levers"]
			if rv.has("wires"):
				progress["wires"] = rv["wires"]
	save_game()
	return true


func add_doc(id):
	if progress["docs"].has(id):
		return false
	progress["docs"].append(id)
	save_game()
	return true


func code_known():
	for c in progress["code"]:
		if c == null:
			return false
	return true


func code_text():
	var out = []
	for c in progress["code"]:
		if c == null:
			out.append("؟")
		else:
			out.append(fa(int(c)))
	return " ".join(out)


func unlock_ending(id):
	if not endings.has(id):
		endings.append(id)
	save_game()


func record_time(used):
	if stats["best_time"] <= 0.0 or used < stats["best_time"]:
		stats["best_time"] = used
	save_game()


func record_survival(sec):
	if sec > stats["best_survival"]:
		stats["best_survival"] = sec


# ---------- حافظه‌ی دشمن ----------
func mem_add(kind, key, amount):
	var m = memory[kind]
	m[key] = float(m.get(key, 0.0)) + amount
	if m.size() > 500:
		_mem_prune(m)


func _mem_prune(m):
	var keys = m.keys()
	var worst = keys[0]
	for k in keys:
		if m[k] < m[worst]:
			worst = k
	m.erase(worst)


func mem_decay():
	## در شروع هر حلقه کمی از حافظه کم می‌شود تا دشمن قفل نشود.
	for kind in memory:
		var m = memory[kind]
		for k in m.keys():
			m[k] = m[k] * 0.96
			if m[k] < 0.05:
				m.erase(k)


func cell_key(c):
	return str(int(c.x)) + "," + str(int(c.y))


func key_cell(k):
	var p = k.split(",")
	return Vector2i(int(p[0]), int(p[1]))


# ---------- ابزارها ----------
func fa(n):
	if typeof(n) == TYPE_FLOAT and n == floorf(n):
		n = int(n)
	var s = str(n)
	var out = ""
	var digits = "۰۱۲۳۴۵۶۷۸۹"
	for i in s.length():
		var ch = s[i]
		if ch >= "0" and ch <= "9":
			out += digits[int(ch)]
		else:
			out += ch
	return out


func vibrate(ms):
	if settings["vibration"] and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


func light_tex():
	## بافت نور دایره‌ای (سفید در مرکز، سیاه در لبه) که برای همه‌ی نورها استفاده می‌شود.
	if _light_tex == null:
		var g = Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(0, 0, 0, 1))
		g.add_point(0.45, Color(0.45, 0.45, 0.45, 1))
		var t = GradientTexture2D.new()
		t.gradient = g
		t.width = 128
		t.height = 128
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		_light_tex = t
	return _light_tex


func _notification(what):
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


func get_font():
	## فونت بازی: اول fonts/horror.ttf اگر خودتان بگذارید، بعد فونت فارسیِ همراهِ پروژه.
	## از SystemFont استفاده نمی‌کنیم: روی اندروید قابل‌اعتماد نیست و اگر پیدا نشود
	## هیچ متنی رسم نمی‌شود (همان صفحه‌ی سیاه بعد از نصب APK).
	if ui_font == null:
		for path in ["res://fonts/horror.ttf", "res://fonts/Vazirmatn-Regular.ttf"]:
			if not ResourceLoader.exists(path):
				continue
			var f = load(path)
			# اگر پروژه بدون مرحله‌ی ایمپورت اجرا شود، فونتِ خام داده‌ی چهره ندارد.
			# در این حالت مستقیم از فایل TTF بارگذاری می‌کنیم تا متن هرگز خالی نماند.
			if f is FontFile and f.get_face_count() == 0:
				var raw = FontFile.new()
				if raw.load_dynamic_font(path) == OK and raw.get_face_count() > 0:
					f = raw
			if f != null:
				ui_font = f
				break
		if ui_font == null:
			ui_font = ThemeDB.fallback_font
	return ui_font


func set_live(key, value):
	settings[key] = value
	settings_changed.emit()


func ui_click():
	Sound.sfx("click")


func open_support():
	OS.shell_open(SUPPORT_URL)


func cone_tex():
	## بافت مخروط چراغ‌قوه: مبدأ در وسط لبه‌ی چپ و پرتو به سمت راست.
	if _cone_tex == null:
		var img = Image.create(128, 128, false, Image.FORMAT_RGBA8)
		var half = deg_to_rad(30.0)
		for y in 128:
			for x in 128:
				var dx = float(x)
				var dy = float(y) - 64.0
				var dist = sqrt(dx * dx + dy * dy)
				var v = 0.0
				if dx > 0.0 and dist < 128.0:
					var ang = absf(atan2(dy, dx))
					if ang < half:
						v = pow(1.0 - dist / 128.0, 0.8) * pow(1.0 - ang / half, 0.5)
				img.set_pixel(x, y, Color(v, v, v, 1.0))
		_cone_tex = ImageTexture.create_from_image(img)
	return _cone_tex
