extends RefCounted
## پنجره‌های درون‌بازی: خواندن یادداشت/سند، صفحه‌کلید رمز، دسته‌های برق، سیم‌های هسته، صفحه‌ی پایان.

const UI = preload("res://scripts/ui.gd")
const PanelScript = preload("res://scripts/panel.gd")


static func _open(layer, title, pause, close_text = "بستن"):
	var p = PanelScript.new()
	layer.add_child(p)
	p.setup(title, close_text)
	if pause:
		layer.get_tree().paused = true
		p.closed.connect(func(): layer.get_tree().paused = false)
	return p


static func _color_button(text, col, cb):
	var b = UI.button(text, cb, 32)
	for st in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(st, UI.sb(col, col.lightened(0.35), 2))
	b.custom_minimum_size = Vector2(150, 90)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


static func read(layer, title, text):
	var p = _open(layer, title, true)
	p.box.add_child(UI.paragraph(text, 30))
	return p


static func keypad(layer, code, pause, on_ok, on_fail):
	var p = _open(layer, "قفل رمزی", pause, "انصراف")
	var entered = []
	var disp = UI.label("— — — —", 64, UI.BONE)
	p.box.add_child(disp)
	var refresh = func():
		var parts = []
		for i in 4:
			if i < entered.size():
				parts.append(Global.fa(entered[i]))
			else:
				parts.append("—")
		disp.text = " ".join(parts)
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for d in [1, 2, 3, 4, 5, 6, 7, 8, 9, -1, 0, -2]:
		var cb = func():
			if d == -1:
				entered.clear()
				refresh.call()
				return
			if d == -2:
				if entered.size() > 0:
					entered.pop_back()
				refresh.call()
				return
			if entered.size() >= 4:
				return
			entered.append(d)
			refresh.call()
			if entered.size() == 4:
				var ok = true
				for i in 4:
					if int(entered[i]) != int(code[i]):
						ok = false
				if ok:
					Sound.sfx("success")
					p.close_panel()
					on_ok.call()
				else:
					Sound.sfx("error")
					entered.clear()
					refresh.call()
					on_fail.call()
		var label = Global.fa(d)
		if d == -1:
			label = "پاک"
		elif d == -2:
			label = "حذف"
		var b = UI.button(label, cb, 40)
		b.custom_minimum_size = Vector2(130, 80)
		grid.add_child(b)
	p.box.add_child(grid)
	return p


static func levers(layer, order, pause, on_ok, on_fail):
	var p = _open(layer, "تابلوی دسته‌های برق", pause, "انصراف")
	var names = {"red": "قرمز", "blue": "آبی", "green": "سبز", "yellow": "زرد"}
	var cols = {"red": Color(0.75, 0.08, 0.08), "blue": Color(0.12, 0.28, 0.85), "green": Color(0.08, 0.55, 0.22), "yellow": Color(0.75, 0.65, 0.08)}
	var prog = {"i": 0}
	var info = UI.paragraph("دسته‌ها را به ترتیب درست بکش. اشتباه، سروصدا دارد!", 28)
	p.box.add_child(info)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	for k in ["red", "blue", "green", "yellow"]:
		var cb = func():
			Sound.sfx("lever")
			if k == order[prog["i"]]:
				prog["i"] += 1
				info.text = "درست! " + Global.fa(prog["i"]) + " از " + Global.fa(order.size())
				if prog["i"] >= order.size():
					Sound.sfx("success")
					p.close_panel()
					on_ok.call()
			else:
				prog["i"] = 0
				Sound.sfx("error")
				info.text = "اشتباه! صدای بلندی در ساختمان پیچید."
				on_fail.call()
		row.add_child(_color_button(names[k], cols[k], cb))
	p.box.add_child(row)
	return p


static func wires(layer, slot_map, pause, on_ok, on_fail):
	var p = _open(layer, "هسته‌ی حلقه: اتصال سیم‌ها", pause, "انصراف")
	var names = {"red": "قرمز", "blue": "آبی", "green": "سبز"}
	var cols = {"red": Color(0.75, 0.08, 0.08), "blue": Color(0.12, 0.28, 0.85), "green": Color(0.08, 0.55, 0.22)}
	var slot_names = ["بالا", "وسط", "پایین"]
	var st = {"sel": "", "assign": {}}
	var status = UI.paragraph("اول یک سیم را انتخاب کن، بعد نقطه‌ی مقصدش را.", 28)
	p.box.add_child(status)
	var refresh = func():
		var parts = []
		for w in st["assign"]:
			parts.append(names[w] + " ← " + slot_names[int(st["assign"][w])])
		var sel = ""
		if st["sel"] != "":
			sel = "انتخاب‌شده: " + names[st["sel"]] + "   "
		status.text = sel + "   ".join(parts) if parts.size() > 0 else sel + "سیم و نقطه را انتخاب کن."
	p.box.add_child(UI.label("سیم‌ها", 28, UI.RED))
	var row1 = HBoxContainer.new()
	row1.add_theme_constant_override("separation", 12)
	for w in ["red", "blue", "green"]:
		var cb = func():
			Sound.sfx("lever")
			st["sel"] = w
			refresh.call()
		row1.add_child(_color_button(names[w], cols[w], cb))
	p.box.add_child(row1)
	p.box.add_child(UI.label("نقطه‌ها", 28, UI.RED))
	var row2 = HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)
	for s in 3:
		var cb2 = func():
			if st["sel"] == "":
				return
			Sound.sfx("lever")
			for k in st["assign"].keys():
				if int(st["assign"][k]) == s:
					st["assign"].erase(k)
			st["assign"][st["sel"]] = s
			st["sel"] = ""
			refresh.call()
			if st["assign"].size() == 3:
				var ok = true
				for k2 in slot_map:
					if int(st["assign"].get(k2, -1)) != int(slot_map[k2]):
						ok = false
				if ok:
					Sound.sfx("success")
					p.close_panel()
					on_ok.call()
				else:
					Sound.sfx("error")
					st["assign"] = {}
					status.text = "اتصال اشتباه! جرقه زد و دوباره شروع شد."
					on_fail.call()
		var sb2 = _color_button(slot_names[s], Color(0.18, 0.12, 0.2), cb2)
		row2.add_child(sb2)
	p.box.add_child(row2)
	return p


static func ending(layer, title, text, stats_text, on_continue, on_menu):
	var p = _open(layer, title, true, "منوی اصلی")
	p.box.add_child(UI.paragraph(text, 32))
	p.box.add_child(UI.paragraph(stats_text, 24, UI.DIM))
	var cb = func():
		layer.get_tree().paused = false
		p.queue_free()
		on_continue.call()
	p.box.add_child(UI.button("ادامه‌ی کاوش (حلقه‌ی جدید)", cb, 28))
	p.closed.connect(on_menu)
	return p
