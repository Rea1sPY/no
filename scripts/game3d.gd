extends Node3D
## کنترل‌کننده‌ی بازی اول‌شخص: حلقه‌ی ۶۰ ثانیه‌ای، تعامل‌ها، معماها، مرگ و
## بازگشت زمان، پایان‌ها، توقف و ذخیره. صحنه‌ی سه‌بعدی، رابط دو‌بعدی.

signal exit_requested

const LevelScript = preload("res://scripts/level3d.gd")
const PlayerScript = preload("res://scripts/player3d.gd")
const EnemyScript = preload("res://scripts/enemy3d.gd")
const TouchScript = preload("res://scripts/touch_controls.gd")
const HudScript = preload("res://scripts/hud.gd")
const FxScript = preload("res://scripts/fx.gd")
const PanelScript = preload("res://scripts/panel.gd")
const Popups = preload("res://scripts/popups.gd")
const Panels = preload("res://scripts/panels.gd")
const UI = preload("res://scripts/ui.gd")
const W = preload("res://scripts/world.gd")

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
var fx = null
var hud = null
var touch = null
var popup_layer = null
var target = null
var pause_panel = null
var env = null
var _hb_t = 0.0
var _alarm_t = 0.0
var _whisper_t = 8.0
var _route_t = 0.0
var _fov_t = 0.0
var _amb_t = 7.0
var _base_fov = 74.0
var _ending_id = ""


func _ready():
	_make_environment()
	level = LevelScript.new()
	add_child(level)
	level.build()
	player = PlayerScript.new()
	add_child(player)
	player.setup(self, level)
	enemy = EnemyScript.new()
	add_child(enemy)
	enemy.setup(self, level, player)
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
	_start_loop()


func _make_environment():
	var we = WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.004, 0.003, 0.006)
	# نور محیط بسیار کم است تا تاریکی واقعی حس شود. تنظیم «نور محیط» از بخش
	# تنظیمات حذف شده؛ شدت پایه اینجا ثابت است و فقط چراغ‌قوه/لامپ‌ها همه‌چیز را روشن می‌کنند.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.26, 0.31, 0.46)
	env.ambient_light_energy = 0.045
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.08
	env.fog_enabled = true
	env.fog_light_color = Color(0.016, 0.015, 0.026)
	env.fog_density = 0.022
	env.fog_sky_affect = 0.0
	we.environment = env
	add_child(we)
	var moon = DirectionalLight3D.new()
	moon.light_color = Color(0.4, 0.5, 0.8)
	moon.light_energy = 0.03
	moon.rotation = Vector3(-1.1, 0.6, 0)
	moon.shadow_enabled = false
	add_child(moon)


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
	_fov_t = 0.0
	# چراغ‌قوه از همان لحظه‌ی بیدار شدن در دست است تا بازی هیچ‌وقت در تاریکی مطلق نماند.
	inventory["flashlight"] = true
	Global.progress["has_flashlight"] = true
	level.reset_dynamic()
	var sp = Global.data["player"]["spawn"]
	player.has_flashlight = true
	player.set_has_flashlight(true)
	player.reset(level.cell_to_pos(Vector2i(sp[0], sp[1])))
	player.set_flash(true)
	var ep = Global.data["enemy"]["spawn"]
	enemy.reset(level.cell_to_pos(Vector2i(ep[0], ep[1])))
	state = "play"
	target = null
	touch.reset()
	touch.hint_text = ""
	touch.has_target = false
	if hud != null:
		hud.concealed = false
	if fx != null:
		fx.set_concealed(false)
	Sound.start_music()
	fx.set_danger(0.0)
	fx.fade_to(0.0, 0.7)
	_refresh_hud()
	if Global.progress["loop"] == 1:
		hud.banner("حلقه ۱", 2.2, Color(0.85, 0.85, 0.9))
		hud.toast("جوی‌استیک چپ حرکت، کشیدن سمت راست نگاه")
		hud.toast("دکمه‌ی چراغ را بزن؛ باتری دارد")
		touch.hint("چراغ‌قوه در دستت است — با دکمه‌ی «چراغ» خاموش و روشن کن", 9.0)
		player.pitch = -0.85
		var tw = create_tween()
		tw.set_trans(Tween.TRANS_SINE)
		tw.set_ease(Tween.EASE_OUT)
		tw.tween_property(player, "pitch", 0.06, 1.8)
		fx.fade_to(1.0, 0.01)
		fx.fade_to(0.0, 1.4)
	else:
		hud.banner("حلقه " + Global.fa(Global.progress["loop"]), 2.0, Color(0.85, 0.85, 0.9))
	_capture_mouse()
	Global.save_game()


func _capture_mouse():
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _release_mouse():
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func aggression():
	return 1.0 + 0.3 * tension


func _physics_process(delta):
	level.update_lamps(player.global_position, delta)
	if state != "play":
		return
	player.add_look(touch.take_look())
	time_left -= delta
	elapsed += delta
	tension = clampf(1.0 - time_left / 20.0, 0.0, 1.0)
	var prox = 0.0
	if enemy.state == EnemyScript.CHASE:
		prox = clampf(1.0 - enemy.global_position.distance_to(player.global_position) / 16.0, 0.2, 1.0)
	danger = maxf(tension * 0.8, prox)
	fx.set_danger(danger)
	Sound.set_tension(maxf(tension, prox * 0.7))
	_heartbeat(delta)
	_alarm(delta)
	_whispers(delta)
	_ambient(delta)
	player.move_input = touch.move_vec
	player.running = touch.run_held
	_route_t += delta
	if _route_t > 1.0:
		_route_t = 0.0
		Global.mem_add("route", Global.cell_key(level.pos_to_cell(player.global_position)), 0.2)
	_update_target()
	_update_camera(delta)
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


func _ambient(delta):
	## صداهای محیطی تصادفی: چکه‌ی آب، تق‌تق فلز و صدای کشیده شدن در دور.
	_amb_t -= delta
	if _amb_t > 0.0:
		return
	_amb_t = randf_range(5.0, 11.0)
	var pick = randi() % 3
	var p = player.global_position + Vector3(randf_range(-12, 12), randf_range(0.5, 2.4), randf_range(-12, 12))
	var d = p.distance_to(player.global_position)
	var db = -6.0 - d * 0.5
	if pick == 0:
		Sound.sfx("drip", db, randf_range(0.8, 1.2))
	elif pick == 1:
		Sound.sfx("creak", db - 4.0, randf_range(0.7, 1.0))
	else:
		Sound.sfx("clang", db - 6.0, randf_range(0.8, 1.1))


func _whispers(delta):
	if tension > 0.3:
		_whisper_t -= delta
		if _whisper_t <= 0.0:
			Sound.sfx("whisper", -8.0, randf_range(0.7, 1.1))
			_whisper_t = randf_range(4.0, 8.0)


func _update_camera(delta):
	var amt = 0.0
	if Global.settings["shake"]:
		amt = tension * 0.012
		if enemy.state == EnemyScript.CHASE:
			amt += 0.01
	player.camera.h_offset = randf_range(-1.0, 1.0) * amt
	player.camera.v_offset = randf_range(-1.0, 1.0) * amt
	var spd = Vector2(player.velocity.x, player.velocity.z).length()
	var sprint = clampf((spd - player.walk_speed) * 2.2, 0.0, 5.5)
	var want = _base_fov + (6.0 if enemy.state == EnemyScript.CHASE else 0.0) + tension * 2.0 + sprint
	player.camera.fov = lerpf(player.camera.fov, want, minf(1.0, delta * 2.2))


func _refresh_hud():
	if state != "play":
		return
	hud.time_left = time_left
	hud.loop_no = Global.progress["loop"]
	hud.battery = player.battery
	hud.has_flash = player.has_flashlight
	hud.awareness = enemy.awareness if enemy.state != EnemyScript.IDLE else 0.0
	hud.room_name = level.room_at(player.global_position)
	hud.concealed = player.concealed
	hud.items = _item_names()
	hud.danger = danger
	touch.flash_on = player.flash_on
	touch.battery = player.battery
	touch.has_target = target != null


func _item_names():
	var names = {"card": "کارت دسترسی", "key": "کلید", "fuse": "فیوز", "doc1": "سند ۱", "doc2": "سند ۲", "doc3": "سند ۳", "flashlight": "چراغ‌قوه"}
	var list = []
	for k in inventory:
		if names.has(k):
			list.append(names[k])
	return list


# ---------- تعامل ----------
func _update_target():
	var best = null
	var bd = 1e9
	if player.concealed:
		for n in get_tree().get_nodes_in_group("interactables"):
			if n.kind == "hide" and n.id == player.hidden_spot:
				best = n
	else:
		var eye = player.get_eye()
		var dir = -player.camera.global_transform.basis.z
		for n in get_tree().get_nodes_in_group("interactables"):
			if not n.is_inside_tree():
				continue
			if not n.is_active():
				continue
			var d = n.global_position.distance_to(player.global_position)
			if d > 2.6:
				continue
			var to = n.global_position + Vector3(0, 1.05, 0) - eye
			var dot = dir.dot(to.normalized()) if to.length() > 0.01 else -1.0
			if dot < -0.15 and d > 1.1:
				continue
			var score = d + (1.0 - dot) * 2.2
			if score < bd:
				bd = score
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
	touch.has_target = target != null


func _puzzle_pause():
	return bool(Global.diff()["puzzle_pauses"])


func on_interact():
	if state != "play" or get_tree().paused:
		return
	if player.concealed:
		player.leave_hide()
		hud.concealed = false
		fx.set_concealed(false)
		Sound.sfx("door", -14.0, 1.3)
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
	Sound.sfx("lever", -18.0, 1.8)


func on_notebook():
	if get_tree().paused:
		return
	touch.reset()
	_release_mouse()
	get_tree().paused = true
	var p = Panels.notebook(popup_layer)
	p.closed.connect(_on_notebook_closed)


func _pickup(n):
	var id = n.id
	inventory[id] = true
	if id == "flashlight":
		Global.progress["has_flashlight"] = true
		player.set_has_flashlight(true)
		Global.save_game()
	var nm = n.info["name"]
	n.queue_free()
	target = null
	touch.has_target = false
	Sound.sfx("pickup")
	emit_noise(player.global_position, 40.0)
	hud.toast("برداشتی: " + nm)
	if id.begins_with("doc"):
		Global.add_doc(id)
		for d in Global.data["docs"]:
			if d["id"] == id:
				touch.reset()
				_release_mouse()
				Popups.read(popup_layer, d["title"], d["text"])
				var pp = popup_layer.get_child(popup_layer.get_child_count() - 1)
				if pp.has_signal("closed"):
					pp.closed.connect(_capture_mouse, CONNECT_ONE_SHOT)


func _read_note(n):
	var fresh = Global.add_note(n.id)
	touch.reset()
	_release_mouse()
	Popups.read(popup_layer, n.info["title"], n.info["text"])
	var pp = popup_layer.get_child(popup_layer.get_child_count() - 1)
	if pp.has_signal("closed"):
		pp.closed.connect(_capture_mouse, CONNECT_ONE_SHOT)
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
			_release_mouse()
			var code = Global.data["code"]
			Popups.keypad(popup_layer, code, _puzzle_pause(), _on_code_ok.bind(d), _on_code_fail.bind(d))
			var pp = popup_layer.get_child(popup_layer.get_child_count() - 1)
			if pp.has_signal("closed"):
				pp.closed.connect(_capture_mouse, CONNECT_ONE_SHOT)
			return
	if ok:
		_open_door(d)
	else:
		Sound.sfx("error")
		hud.toast(msg)


func _on_code_ok(d):
	d.unlocked = true
	_capture_mouse()
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
	hud.concealed = true
	fx.set_concealed(true)
	hud.toast("پنهان شدی. صدایی درنیاور")


func enemy_opened_spot(spot_id):
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
	_release_mouse()
	var order = Global.data["levers_order"]
	Popups.levers(popup_layer, order, _puzzle_pause(), _on_levers_ok, _on_levers_fail.bind(n))
	var pp = popup_layer.get_child(popup_layer.get_child_count() - 1)
	if pp.has_signal("closed"):
		pp.closed.connect(_capture_mouse, CONNECT_ONE_SHOT)


func _on_levers_ok():
	levers_done = true
	_set_power(true)
	_capture_mouse()


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
	_release_mouse()
	var map = Global.data["wire_slots"]
	Popups.wires(popup_layer, map, _puzzle_pause(), _on_wires_ok.bind(n), _on_wires_fail.bind(n))
	var pp = popup_layer.get_child(popup_layer.get_child_count() - 1)
	if pp.has_signal("closed"):
		pp.closed.connect(_capture_mouse, CONNECT_ONE_SHOT)


func _on_wires_ok(n):
	n.state = 1
	_capture_mouse()
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


# ---------- مرگ و بازگشت ----------
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
	player.flash_on = false
	player.flash.visible = false
	player.spill.visible = false
	player.beam.visible = false
	if player._inner != null:
		player._inner.visible = false
	Sound.sfx("scare")
	Global.vibrate(500)
	fx.flash(Color(0.7, 0.0, 0.05, 0.9), 0.8)
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(player.camera, "rotation:z", 0.55, 0.55)
	tw.tween_property(player.camera, "position:y", 0.55, 0.6)
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
	_release_mouse()
	var e = Global.data["endings"][id]
	var st = "زمان: " + Global.fa(snappedf(elapsed, 0.1)) + " ثانیه   |   مرگ‌ها: " + Global.fa(Global.progress["deaths"]) + "   |   پایان‌های کشف‌شده: " + Global.fa(Global.endings.size()) + " از ۴"
	Popups.ending(popup_layer, e["title"], e["text"], st, _continue_after_ending, _exit_to_menu)


func _continue_after_ending():
	_start_loop()


func _exit_to_menu():
	get_tree().paused = false
	_release_mouse()
	Global.save_game()
	Sound.stop_music()
	exit_requested.emit()


# ---------- توقف ----------
func pause_game():
	if state != "play" or pause_panel != null or get_tree().paused:
		return
	touch.reset()
	_release_mouse()
	get_tree().paused = true
	var p = PanelScript.new()
	popup_layer.add_child(p)
	p.setup("توقف", "ادامه")
	p.box.add_child(UI.button("دفترچه‌ی سرنخ‌ها", _open_notebook))
	p.box.add_child(UI.button("تنظیمات", _open_settings))
	p.box.add_child(UI.button("راهنما", _open_help))
	p.box.add_child(UI.button("خروج به منوی اصلی", _confirm_exit))
	p.closed.connect(_on_pause_closed)
	pause_panel = p


func _on_notebook_closed():
	get_tree().paused = false
	_capture_mouse()


func _open_notebook():
	Panels.notebook(popup_layer)


func _open_settings():
	Panels.settings(popup_layer)


func _open_help():
	Panels.help(popup_layer)


func _confirm_exit():
	Panels.confirm(popup_layer, "از بازی خارج می‌شوی؟ پیشرفتت ذخیره می‌شود.", _exit_to_menu)


func _on_pause_closed():
	pause_panel = null
	get_tree().paused = false
	_capture_mouse()


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
