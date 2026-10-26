extends Node2D
## کنترل‌کننده‌ی بازی: حلقه‌ی ۶۰ ثانیه‌ای، تعامل‌ها، معماها، مرگ و بازگشت زمان، پایان‌ها، توقف و ذخیره.

signal exit_requested

const LevelScript = preload("res://scripts/level.gd")
const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const TouchScript = preload("res://scripts/touch_controls.gd")
const HudScript = preload("res://scripts/hud.gd")
const FxScript = preload("res://scripts/fx.gd")
const PanelScript = preload("res://scripts/panel.gd")
const Popups = preload("res://scripts/popups.gd")
const Panels = preload("res://scripts/panels.gd")
const UI = preload("res://scripts/ui.gd")

var state = "play"
var time_left = 60.0
var elapsed = 0.0
var tension = 0.0
var danger = 0.0
var inventory = {}
var fuse_inserted = false
var levers_done = false
var power = false
var level = null
var player = null
var enemy = null
var camera = null
var canvas_mod = null
var fx = null
var hud = null
var touch = null
var popup_layer = null
var target = null
var pause_panel = null
var _hb_t = 0.0
var _alarm_t = 0.0
var _whisper_t = 8.0
var _route_t = 0.0
var _hint_t = 0.0
var _ending_id = ""


func _ready():
	canvas_mod = CanvasModulate.new()
	add_child(canvas_mod)
	level = LevelScript.new()
	add_child(level)
	level.build()
	player = PlayerScript.new()
	add_child(player)
	enemy = EnemyScript.new()
	add_child(enemy)
	camera = Camera2D.new()
	camera.zoom = Vector2(1.25, 1.25)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 9.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = level.gw * 32
	camera.limit_bottom = level.gh * 32
	player.add_child(camera)
	camera.make_current()
	fx = FxScript.new()
	add_child(fx)
	var hud_layer = CanvasLayer.new()
	hud_layer.layer = 5
	add_child(hud_layer)
	hud = HudScript.new()
	UI.full_rect(hud)
	hud_layer.add_child(hud)
	touch = TouchScript.new()
	UI.full_rect(touch)
	hud_layer.add_child(touch)
	popup_layer = CanvasLayer.new()
	popup_layer.layer = 20
	popup_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(popup_layer)
	touch.interact_pressed.connect(on_interact)
	touch.flash_pressed.connect(on_flash)
	touch.notebook_pressed.connect(on_notebook)
	touch.pause_pressed.connect(pause_game)
	player.setup(self, level)
	enemy.setup(self, level, player)
	_start_loop()


# ---------- حلقه ----------
func _start_loop():
	get_tree().paused = false
	Global.progress["loop"] += 1
	if Global.progress["loop"] > 1:
		Global.mem_decay()
	time_left = float(Global.data["loop_seconds"])
	elapsed = 0.0
	tension = 0.0
	danger = 0.0
	inventory = {}
	fuse_inserted = false
	levers_done = false
	power = false
	_hb_t = 0.0
	_alarm_t = 0.0
	_whisper_t = randf_range(6.0, 12.0)
	_hint_t = 0.0
	if Global.progress["has_flashlight"]:
		inventory["flashlight"] = true
	level.reset_dynamic()
	var sp = Global.data["player"]["spawn"]
	player.reset(level.cell_to_pos(Vector2i(sp[0], sp[1])))
	player.has_flashlight = inventory.has("flashlight")
	var ep = Global.data["enemy"]["spawn"]
	enemy.reset(level.cell_to_pos(Vector2i(ep[0], ep[1])))
	touch.reset()
	target = null
	state = "play"
	Sound.start_music()
	fx.set_danger(0.0)
	fx.fade_to(0.0, 0.7)
	hud.banner("حلقه " + Global.fa(Global.progress["loop"]), 2.0, Color(0.85, 0.85, 0.9))
	if Global.progress["loop"] == 1:
		hud.toast("با جوی‌استیک سمت چپ حرکت کن")
		hud.toast("فقط ۶۰ ثانیه وقت داری. چراغ‌قوه و کارت دسترسی را پیدا کن")
	_refresh_hud()
	Global.save_game()


func aggression():
	return 1.0 + 0.3 * tension


func _ambient():
	var b = 0.6 + float(Global.settings["brightness"]) * 0.9
	var base = Color(0.045, 0.045, 0.075)
	if power:
		base = Color(0.13, 0.085, 0.10)
	var f = 1.0
	if tension > 0.4 and randf() < 0.06 * tension:
		f = 0.45
	return Color(base.r * b * f, base.g * b * f, base.b * b * f, 1.0)


func _physics_process(delta):
	canvas_mod.color = _ambient()
	if state != "play":
		return
	time_left -= delta
	elapsed += delta
	tension = clampf(1.0 - time_left / 20.0, 0.0, 1.0)
	var prox = 0.0
	if enemy.state == EnemyScript.CHASE:
		prox = clampf(1.0 - enemy.global_position.distance_to(player.global_position) / 500.0, 0.2, 1.0)
	danger = maxf(tension * 0.8, prox)
	fx.set_danger(danger)
	Sound.set_tension(maxf(tension, prox * 0.7))
	_heartbeat(delta)
	_alarm(delta)
	_whispers(delta)
	player.move_input = touch.move_vec
	player.running = touch.run_held
	_route_t += delta
	if _route_t > 1.0:
		_route_t = 0.0
		Global.mem_add("route", Global.cell_key(level.pos_to_cell(player.global_position)), 0.2)
	_update_target()
	_update_camera()
	_refresh_hud()
	_check_exit()
	if time_left <= 0.0:
		_die("time")


func _heartbeat(delta):
	_hb_t -= delta
	if danger > 0.15 and _hb_t <= 0.0:
		Sound.sfx("heart", -4.0 + 6.0 * danger)
		Global.vibrate(40)
		_hb_t = lerpf(1.1, 0.38, danger)


func _alarm(delta):
	if time_left <= 10.0:
		_alarm_t -= delta
		if _alarm_t <= 0.0:
			Sound.sfx("alarm", -6.0, 1.0 + (10.0 - time_left) * 0.03)
			_alarm_t = 1.0 if time_left > 5.0 else 0.5


func _whispers(delta):
	if tension > 0.3:
		_whisper_t -= delta
		if _whisper_t <= 0.0:
			Sound.sfx("whisper", -8.0, randf_range(0.7, 1.1))
			_whisper_t = randf_range(4.0, 8.0)


func _update_camera():
	var amt = 0.0
	if Global.settings["shake"]:
		amt = tension * 2.5
		if enemy.state == EnemyScript.CHASE:
			amt += 2.0
	camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * amt


func _refresh_hud():
	hud.time_left = time_left
	hud.loop_no = Global.progress["loop"]
	hud.battery = player.battery
	hud.has_flash = player.has_flashlight
	hud.awareness = enemy.awareness if enemy.state != EnemyScript.IDLE else 0.0
	hud.room_name = level.room_at(player.global_position)
	var names = {"card": "کارت دسترسی", "key": "کلید", "fuse": "فیوز", "doc1": "سند ۱", "doc2": "سند ۲", "doc3": "سند ۳", "flashlight": "چراغ‌قوه"}
	var list = []
	for k in inventory:
		if names.has(k):
			list.append(names[k])
	hud.items = list
	touch.flash_on = player.flash_on


# ---------- تعامل ----------
func _update_target():
	var best = null
	var bd = 62.0
	if player.concealed:
		for n in get_tree().get_nodes_in_group("interactables"):
			if n.kind == "hide" and n.id == player.hidden_spot:
				best = n
	else:
		for n in get_tree().get_nodes_in_group("interactables"):
			if not n.is_inside_tree():
				continue
			if not n.is_active():
				continue
			var d = n.global_position.distance_to(player.global_position)
			if d < bd:
				bd = d
				best = n
	if best != target:
		if target != null and is_instance_valid(target):
			target.set_highlight(false)
		target = best
		if target != null:
			target.set_highlight(true)
	if target != null and is_instance_valid(target):
		if player.concealed:
			hud.prompt = "بیرون آمدن از " + target.info["name"]
		else:
			hud.prompt = target.prompt()
	else:
		hud.prompt = ""


func _puzzle_pause():
	return bool(Global.diff()["puzzle_pauses"])


func on_interact():
	if state != "play" or get_tree().paused:
		return
	if player.concealed:
		player.leave_hide()
		return
	if target == null or not is_instance_valid(target):
		return
	var k = target.kind
	if k == "pickup":
		_pickup(target)
	elif k == "note":
		_read_note(target)
	elif k == "door":
		_use_door(target)
	elif k == "hide":
		_enter_hide(target)
	elif k == "fusebox":
		_use_fusebox(target)
	elif k == "panel":
		_use_panel(target)
	elif k == "core":
		_use_core(target)
	elif k == "secret":
		_ending("secret")


func on_flash():
	if state != "play" or get_tree().paused:
		return
	if not player.has_flashlight:
		hud.toast("هنوز چراغ‌قوه نداری")
		return
	if not player.toggle_flash():
		hud.toast("باتری چراغ‌قوه تمام شده")
	Sound.sfx("click")


func on_notebook():
	if get_tree().paused:
		return
	touch.reset()
	get_tree().paused = true
	var p = Panels.notebook(popup_layer)
	p.closed.connect(func(): get_tree().paused = false)


func _pickup(n):
	var id = n.id
	inventory[id] = true
	if id == "flashlight":
		Global.progress["has_flashlight"] = true
		player.has_flashlight = true
		Global.save_game()
	var nm = n.info["name"]
	n.queue_free()
	target = null
	Sound.sfx("pickup")
	emit_noise(player.global_position, 40.0)
	hud.toast("برداشتی: " + nm)
	if id.begins_with("doc"):
		Global.add_doc(id)
		for d in Global.data["docs"]:
			if d["id"] == id:
				touch.reset()
				Popups.read(popup_layer, d["title"], d["text"])


func _read_note(n):
	var fresh = Global.add_note(n.id)
	touch.reset()
	Popups.read(popup_layer, n.info["title"], n.info["text"])
	if fresh:
		hud.toast("یادداشت در دفترچه ثبت شد")
		if Global.progress["notes"].size() >= 7:
			hud.toast("پایانه‌ی پنهان در انبار فعال شد!")
			Sound.sfx("whisper")


func _use_door(d):
	if d.is_open:
		return
	var ok = false
	var msg = ""
	if d.needs == "none":
		ok = true
	elif d.needs == "card":
		ok = inventory.has("card")
		msg = "کارت دسترسی لازم است"
	elif d.needs == "key":
		ok = inventory.has("key")
		msg = "کلید لازم است"
	elif d.needs == "power":
		ok = power
		msg = "برق قطع است؛ در برقی کار نمی‌کند"
	elif d.needs == "code":
		if d.unlocked:
			ok = true
		else:
			touch.reset()
			var code = Global.data["code"]
			Popups.keypad(popup_layer, code, _puzzle_pause(), _on_code_ok.bind(d), _on_code_fail.bind(d))
			return
	if ok:
		_open_door(d)
	else:
		Sound.sfx("error")
		hud.toast(msg)


func _on_code_ok(d):
	d.unlocked = true
	_open_door(d)


func _on_code_fail(d):
	emit_noise(d.global_position, 200.0)
	hud.toast("رمز اشتباه است")


func _open_door(d):
	d.open_door()
	Sound.sfx("door")
	emit_noise(d.global_position, 150.0)
	hud.toast(d.info["name"] + " باز شد")


func _enter_hide(n):
	player.enter_hide(n.id)
	Global.mem_add("hide", n.id, 1.0)
	enemy.on_player_hide(n.id)
	Sound.sfx("door", -12.0, 1.4)
	hud.toast("پنهان شدی. صدایی درنیاور")


func enemy_opened_spot(spot_id):
	## دشمن کمد را باز می‌کند: اگر بازیکن داخلش باشد گرفتار می‌شود.
	if player.concealed and player.hidden_spot == spot_id:
		player_caught(enemy)
		return true
	return false


func _use_fusebox(n):
	if n.state == 1:
		hud.toast("فیوز قبلاً نصب شده")
		return
	if inventory.has("fuse"):
		inventory.erase("fuse")
		n.state = 1
		fuse_inserted = true
		Sound.sfx("lever")
		hud.toast("فیوز نصب شد. حالا تابلوی دسته‌ها")
	else:
		Sound.sfx("error")
		hud.toast("فیوز لازم است")


func _use_panel(n):
	if levers_done:
		hud.toast("برق وصل است")
		return
	if not fuse_inserted:
		Sound.sfx("error")
		hud.toast("تابلو بدون فیوز کار نمی‌کند")
		return
	touch.reset()
	var order = Global.data["levers_order"]
	Popups.levers(popup_layer, order, _puzzle_pause(), _on_levers_ok, _on_levers_fail.bind(n))


func _on_levers_ok():
	levers_done = true
	_set_power(true)


func _on_levers_fail(n):
	emit_noise(n.global_position, 320.0)
	Global.vibrate(120)


func _set_power(on):
	power = on
	level.set_power(on)
	Sound.sfx("success")
	fx.flash(Color(1, 1, 1, 0.5), 0.5)
	hud.toast("برق وصل شد! در اضطراری فعال است")


func _use_core(n):
	if n.state == 1:
		return
	if not power:
		Sound.sfx("error")
		hud.toast("هسته بدون برق خاموش است")
		return
	touch.reset()
	var map = Global.data["wire_slots"]
	Popups.wires(popup_layer, map, _puzzle_pause(), _on_wires_ok.bind(n), _on_wires_fail.bind(n))


func _on_wires_ok(n):
	n.state = 1
	_ending("loop_end")


func _on_wires_fail(n):
	emit_noise(n.global_position, 260.0)
	Global.vibrate(100)


func emit_noise(pos, radius):
	if enemy != null and state == "play":
		if enemy.global_position.distance_to(pos) < radius:
			enemy.hear(pos)


func _doc_count():
	var n = 0
	for k in inventory:
		if k.begins_with("doc"):
			n += 1
	return n


func _check_exit():
	var c = level.pos_to_cell(player.global_position)
	if c.x >= 61 and power:
		if _doc_count() >= 3:
			_ending("truth")
		else:
			_ending("escape")


# ---------- مرگ و بازگشت زمان ----------
func player_caught(by):
	if state != "play":
		return
	_die("caught")


func _die(reason):
	if state != "play":
		return
	state = "dead"
	Global.progress["deaths"] += 1
	Global.stats["total_deaths"] += 1
	Global.record_survival(elapsed)
	Global.mem_add("death", Global.cell_key(level.pos_to_cell(player.global_position)), 2.0)
	for c in popup_layer.get_children():
		c.queue_free()
	pause_panel = null
	get_tree().paused = false
	touch.reset()
	player.move_input = Vector2.ZERO
	player.running = false
	Sound.sfx("scare")
	Global.vibrate(500)
	fx.flash(Color(0.7, 0.0, 0.05, 0.9), 0.8)
	if reason == "caught":
		fx.jumpscare()
		hud.banner("گرفتارت کرد...", 1.4)
	else:
		hud.banner("زمان تمام شد", 1.4)
	Global.save_game()
	await get_tree().create_timer(1.4).timeout
	if not is_inside_tree():
		return
	state = "rewind"
	fx.glitch(1.4, 1.0)
	Sound.sfx("rewind")
	hud.banner("بازگشت زمان", 1.2, Color(0.5, 0.8, 1.0))
	await get_tree().create_timer(1.2).timeout
	if not is_inside_tree():
		return
	fx.fade_to(1.0, 0.25)
	await get_tree().create_timer(0.3).timeout
	if not is_inside_tree():
		return
	_start_loop()


# ---------- پایان‌ها ----------
func _ending(id):
	if state != "play":
		return
	state = "ending"
	_ending_id = id
	Global.unlock_ending(id)
	if id != "secret":
		Global.record_time(elapsed)
	Global.record_survival(elapsed)
	Sound.stop_music()
	Sound.sfx("success")
	touch.reset()
	var e = Global.data["endings"][id]
	var st = "زمان: " + Global.fa(snappedf(elapsed, 0.1)) + " ثانیه   |   مرگ‌ها: " + Global.fa(Global.progress["deaths"]) + "   |   پایان‌های کشف‌شده: " + Global.fa(Global.endings.size()) + " از ۴"
	Popups.ending(popup_layer, e["title"], e["text"], st, _continue_after_ending, _exit_to_menu)


func _continue_after_ending():
	_start_loop()


func _exit_to_menu():
	get_tree().paused = false
	Global.save_game()
	Sound.stop_music()
	exit_requested.emit()


# ---------- توقف ----------
func pause_game():
	if state != "play" or pause_panel != null or get_tree().paused:
		return
	touch.reset()
	get_tree().paused = true
	var p = PanelScript.new()
	popup_layer.add_child(p)
	p.setup("توقف", "ادامه")
	p.box.add_child(UI.button("دفترچه‌ی سرنخ‌ها", func(): Panels.notebook(popup_layer)))
	p.box.add_child(UI.button("تنظیمات", func(): Panels.settings(popup_layer)))
	p.box.add_child(UI.button("راهنما", func(): Panels.help(popup_layer)))
	p.box.add_child(UI.button("خروج به منوی اصلی", func(): Panels.confirm(popup_layer, "از بازی خارج می‌شوی؟ پیشرفتت ذخیره می‌شود.", _exit_to_menu)))
	p.closed.connect(_on_pause_closed)
	pause_panel = p


func _on_pause_closed():
	pause_panel = null
	get_tree().paused = false


func on_back():
	if pause_panel != null and is_instance_valid(pause_panel):
		pause_panel.close_panel()
	elif state == "play":
		pause_game()


func _notification(what):
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		Global.save_game()
		if state == "play":
			pause_game()
