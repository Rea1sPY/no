extends RefCounted
## پنجره‌های آماده: تنظیمات، راهنما، دفترچه‌ی سرنخ‌ها، انتخاب سختی، تأیید.

const UI = preload("res://scripts/ui.gd")
const PanelScript = preload("res://scripts/panel.gd")


static func _open(parent, title, close_text = "بستن"):
	var p = PanelScript.new()
	parent.add_child(p)
	p.setup(title, close_text)
	return p


static func _slider_row(box, text, key):
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l = UI.label(text, 26, UI.BONE, HORIZONTAL_ALIGNMENT_RIGHT)
	l.custom_minimum_size = Vector2(250, 0)
	row.add_child(l)
	var s = HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = Global.settings[key]
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(300, 44)
	s.value_changed.connect(func(v): Global.set_live(key, v))
	row.add_child(s)
	box.add_child(row)


static func _range_row(box, text, key, lo, hi):
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l = UI.label(text, 26, UI.BONE, HORIZONTAL_ALIGNMENT_RIGHT)
	l.custom_minimum_size = Vector2(250, 0)
	row.add_child(l)
	var s = HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = Global.settings[key]
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(300, 44)
	s.value_changed.connect(func(v): Global.set_live(key, v))
	row.add_child(s)
	box.add_child(row)


static func _check_row(box, text, key):
	var c = CheckButton.new()
	c.text = text
	c.button_pressed = bool(Global.settings[key])
	c.focus_mode = Control.FOCUS_NONE
	c.text_direction = Control.TEXT_DIRECTION_RTL
	c.toggled.connect(func(on): Global.set_setting(key, on))
	box.add_child(c)


static func settings(parent):
	var p = _open(parent, "تنظیمات")
	var b = p.box
	b.add_child(UI.label("صدا", 30, UI.RED))
	_slider_row(b, "صدای موسیقی", "music")
	_slider_row(b, "صدای جلوه‌ها", "sfx")
	_check_row(b, "قطع موسیقی", "mute_music")
	_check_row(b, "قطع جلوه‌های صوتی", "mute_sfx")
	b.add_child(UI.label("کنترل", 30, UI.RED))
	_range_row(b, "حساسیت جوی‌استیک", "joy_sens", 0.5, 1.6)
	_range_row(b, "حساسیت چرخش دید", "look_sens", 0.4, 2.0)
	_check_row(b, "برعکس کردن محور عمودی دید", "invert_look")
	_range_row(b, "اندازه‌ی دکمه‌ها", "ui_scale", 0.8, 1.4)
	_check_row(b, "لرزش گوشی", "vibration")
	b.add_child(UI.label("تصویر", 30, UI.RED))
	_check_row(b, "لرزش دوربین", "shake")
	_check_row(b, "افکت‌های تصویری کامل (گلیچ و سایه)", "fx_high")
	b.add_child(UI.label("سختی بازی", 30, UI.RED))
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var keys = ["easy", "medium", "hard"]
	var btns = []
	for k in keys:
		var bt = UI.button(Global.data["difficulty"][k]["name"], func(): pass, 26)
		bt.custom_minimum_size = Vector2(150, 60)
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(bt)
		btns.append(bt)
	for i in 3:
		var key = keys[i]
		var pick = func():
			Global.set_setting("difficulty", key)
			for j in 3:
				btns[j].disabled = (keys[j] == key)
		btns[i].pressed.connect(pick)
		btns[i].disabled = (keys[i] == Global.settings["difficulty"])
	b.add_child(row)
	b.add_child(UI.paragraph("تغییر سختی از حلقه‌ی بعدی اعمال می‌شود.", 22, UI.DIM))
	b.add_child(HSeparator.new())
	b.add_child(UI.label("ساخته‌شده توسط " + Global.CREATOR, 26, UI.BONE))
	b.add_child(UI.button("پشتیبانی (تلگرام)", Global.open_support, 28))
	return p


static func help(parent):
	var p = _open(parent, "راهنمای بازی")
	var b = p.box
	var lines = [
		"تو در یک مرکز تحقیقاتی متروکه بیدار می‌شوی. فقط ۶۰ ثانیه وقت داری.",
		"با گرفتار شدن یا تمام شدن زمان، حلقه از نو شروع می‌شود؛ اما یادداشت‌ها و رمزهایی که پیدا کرده‌ای می‌مانند.",
		"دشمن از رفتار تو یاد می‌گیرد: مسیرهای فرار و کمدهایی که زیاد استفاده کنی را بیشتر وارسی می‌کند.",
		"جوی‌استیک سمت چپ حرکت است و کشیدن سمت راست صفحه سر را می‌چرخاند. دکمه‌ی «تعامل» برای برداشتن، باز کردن در و پنهان شدن است.",
		"دویدن سریع‌تر است اما صدا دارد و دشمن می‌شنود. چراغ‌قوه راه را روشن می‌کند اما دیده می‌شود و باتری دارد.",
		"وسط صفحه نشانه‌ی کوچکی است؛ وقتی روی چیزی قرار بگیرد زرد می‌شود و می‌توانی تعامل کنی.",
		"برای پنهان شدن کنار کمد «تعامل» را بزن. اگر دشمن دیده باشد کجا رفتی، سراغ همان کمد می‌آید.",
		"دفترچه‌ی سرنخ‌ها رمزها و ترتیب دسته‌ها و سیم‌ها را نگه می‌دارد.",
		"سه پایان اصلی و یک پایان مخفی وجود دارد. سه سند محرمانه، خاموش کردن هسته‌ی حلقه و فرار ساده را امتحان کن."
	]
	for t in lines:
		b.add_child(UI.paragraph(t, 26))
	return p


static func notebook(parent):
	var p = _open(parent, "دفترچه‌ی سرنخ‌ها")
	var b = p.box
	b.add_child(UI.label("رمزها و سرنخ‌ها", 30, UI.RED))
	b.add_child(UI.paragraph("رمز اتاق امنیت: " + Global.code_text(), 28))
	var lv = "؟"
	if Global.progress["levers"].size() > 0:
		var names = {"red": "قرمز", "blue": "آبی", "green": "سبز", "yellow": "زرد"}
		var parts = []
		for c in Global.progress["levers"]:
			parts.append(names[c])
		lv = " ← ".join(parts)
	b.add_child(UI.paragraph("ترتیب دسته‌های برق: " + lv, 28))
	var wr = "؟"
	if Global.progress["wires"].size() > 0:
		wr = "قرمز بالا، آبی وسط، سبز پایین"
	b.add_child(UI.paragraph("سیم‌های هسته: " + wr, 28))
	b.add_child(UI.label("یادداشت‌ها (" + Global.fa(Global.progress["notes"].size()) + " از ۷)", 30, UI.RED))
	for n in Global.data["notes"]:
		if Global.has_note(n["id"]):
			b.add_child(UI.label(n["title"], 26, UI.BONE, HORIZONTAL_ALIGNMENT_RIGHT))
			b.add_child(UI.paragraph(n["text"], 22, UI.DIM))
	b.add_child(UI.label("اسناد محرمانه (" + Global.fa(Global.progress["docs"].size()) + " از ۳)", 30, UI.RED))
	for d in Global.data["docs"]:
		if Global.progress["docs"].has(d["id"]):
			b.add_child(UI.label(d["title"], 26, UI.BONE, HORIZONTAL_ALIGNMENT_RIGHT))
			b.add_child(UI.paragraph(d["text"], 22, UI.DIM))
	b.add_child(UI.label("آمار و پایان‌ها", 30, UI.RED))
	b.add_child(UI.paragraph("تعداد مرگ‌ها: " + Global.fa(Global.progress["deaths"]) + "   |   کل مرگ‌ها: " + Global.fa(Global.stats["total_deaths"]), 24))
	var best = "—"
	if Global.stats["best_time"] > 0.0:
		best = Global.fa(snappedf(Global.stats["best_time"], 0.1)) + " ثانیه"
	b.add_child(UI.paragraph("بهترین زمان فرار: " + best, 24))
	b.add_child(UI.paragraph("بیشترین زمان بقا: " + Global.fa(snappedf(Global.stats["best_survival"], 0.1)) + " ثانیه", 24))
	var titles = {"escape": "فرار", "truth": "حقیقت", "loop_end": "پایان چرخه", "secret": "پایان مخفی"}
	for k in titles:
		var ok = Global.endings.has(k)
		var mark = "✔ " if ok else "؟ "
		var nm = titles[k] if ok else "هنوز کشف نشده"
		b.add_child(UI.paragraph(mark + nm, 24, UI.BONE if ok else UI.DIM))
	return p


static func difficulty(parent, on_pick):
	var p = _open(parent, "سختی را انتخاب کن", "انصراف")
	var b = p.box
	var keys = ["easy", "medium", "hard"]
	for k in keys:
		var d = Global.data["difficulty"][k]
		var cb = func():
			Global.set_setting("difficulty", k)
			p.close_panel()
			on_pick.call()
		var bt = UI.button(d["name"], cb, 32)
		bt.custom_minimum_size = Vector2(300, 70)
		b.add_child(bt)
		b.add_child(UI.paragraph(d["desc"], 22, UI.DIM))
	return p


static func confirm(parent, text, on_yes):
	var p = _open(parent, "تأیید", "انصراف")
	p.box.add_child(UI.paragraph(text, 28))
	var cb = func():
		p.close_panel()
		on_yes.call()
	p.box.add_child(UI.button("بله", cb, 30))
	return p
