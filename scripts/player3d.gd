extends CharacterBody3D
## بازیکن اول‌شخص: راه رفتن/دویدن با شتاب نرم، دید با ماوس یا لمس، چراغ‌قوه‌ی
## واقعی (SpotLight) با باتری و لرزش، تکان سر، مدل دست‌ها و پنهان شدن.

const W = preload("res://scripts/world.gd")
const CELL = W.CELL

var game = null
var level = null
var walk_speed = 3.25
var run_speed = 5.3
var move_input = Vector2.ZERO
var running = false
var yaw = 0.0
var pitch = 0.0
var concealed = false
var hidden_spot = ""
var flash_on = false
var has_flashlight = false
var battery = 100.0
var drain = 1.7
var noise_walk = 70.0
var noise_run = 260.0
var noise_radius = 0.0
var camera = null
var flash = null
var spill = null
var fill = null
var beam = null
var _inner = null
var _view = null
var _lens = null
var _beam_mat = null
var _step_t = 0.0
var _bob_t = 0.0
var _breathe = 0.0
var _sway = Vector2.ZERO
var _look_impulse = Vector2.ZERO
var _t = 0.0
var _flash_flicker = 0.0
var _land = 0.0
var _was_floor = true


func _ready():
	add_to_group("player3d")
	collision_layer = 4
	collision_mask = 3
	var cs = CollisionShape3D.new()
	var cap = CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.7
	cs.shape = cap
	cs.position = Vector3(0, 0.85, 0)
	add_child(cs)
	camera = Camera3D.new()
	camera.position = Vector3(0, W.EYE, 0)
	camera.fov = 74.0
	camera.near = 0.03
	camera.far = 70.0
	add_child(camera)
	camera.make_current()
	_build_view()
	_build_lights()


func _build_lights():
	# چراغ‌قوه‌ی واقعی: یک SpotLight3D قوی که دقیقاً از لنز دوربین می‌تابد.
	flash = SpotLight3D.new()
	flash.position = Vector3(0.16, -0.1, 0.0)
	flash.light_color = Color(1.0, 0.94, 0.8)
	flash.light_energy = 9.0
	flash.spot_range = 30.0
	flash.spot_angle = 34.0
	flash.spot_angle_attenuation = 0.9
	flash.spot_attenuation = 1.1
	flash.shadow_enabled = false
	flash.visible = false
	camera.add_child(flash)
	# نور پخش‌شده‌ی اطراف دست، تا لبه‌ی پرتو هم کمی روشن باشد.
	spill = SpotLight3D.new()
	spill.position = Vector3(0.16, -0.1, 0.0)
	spill.light_color = Color(1.0, 0.9, 0.72)
	spill.light_energy = 1.25
	spill.spot_range = 9.0
	spill.spot_angle = 74.0
	spill.spot_attenuation = 1.4
	spill.shadow_enabled = false
	spill.visible = false
	camera.add_child(spill)
	# نور بسیار ضعیف برای این‌که چشم به تاریکی مطلق عادت کند.
	fill = OmniLight3D.new()
	fill.position = Vector3(0, -0.15, 0)
	fill.light_color = Color(0.55, 0.66, 0.95)
	fill.light_energy = 0.16
	fill.omni_range = 2.2
	fill.shadow_enabled = false
	camera.add_child(fill)
	# مخروط دیدنی نور: دو لایه تا لبه‌ها نرم و سه‌بعدی دیده شوند.
	_beam_mat = W.beam_mat(Color(1.0, 0.94, 0.78, 0.05))
	beam = _make_cone(1.7, 0.05, 8.0, 0.16, -3.9)
	beam.material_override = _beam_mat
	var inner_mat = W.beam_mat(Color(1.0, 0.97, 0.86, 0.06))
	var inner = _make_cone(0.85, 0.04, 7.4, 0.16, -3.55)
	inner.material_override = inner_mat
	inner.name = "BeamInner"
	inner.visible = false
	_inner = inner
	# درخشش لنز
	var flare = Sprite3D.new()
	flare.texture = Global.light_tex()
	flare.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	flare.modulate = Color(1.0, 0.95, 0.75, 0.55)
	flare.pixel_size = 0.004
	flare.no_depth_test = true
	flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flare.position = Vector3(0.01, -0.015, -0.39)
	flare.scale = Vector3.ONE * 1.6
	flare.visible = false
	_view.add_child(flare)
	_lens = flare


func _make_cone(radius, near_radius, length, x, z):
	var cone = CylinderMesh.new()
	cone.top_radius = radius
	cone.bottom_radius = near_radius
	cone.height = length
	cone.radial_segments = 20
	cone.rings = 2
	var mi = MeshInstance3D.new()
	mi.mesh = cone
	mi.position = Vector3(x, -0.1, z)
	mi.rotation = Vector3(-PI * 0.5, 0, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	camera.add_child(mi)
	return mi


func _build_view():
	_view = Node3D.new()
	_view.position = Vector3(0.3, -0.27, -0.42)
	camera.add_child(_view)
	var skin = StandardMaterial3D.new()
	skin.albedo_color = Color(0.62, 0.48, 0.4)
	skin.roughness = 0.85
	W.box(_view, Vector3(0.09, 0.09, 0.3), Vector3(-0.02, -0.02, 0.08), skin, Vector3(0.42, 0.1, 0))
	W.box(_view, Vector3(0.1, 0.1, 0.12), Vector3(0.01, -0.02, -0.07), skin, Vector3(0.2, 0, 0))
	W.box(_view, Vector3(0.1, 0.12, 0.1), Vector3(-0.07, -0.07, -0.16), skin, Vector3(0.1, 0, 0.25))
	W.cyl(_view, 0.038, 0.26, Vector3(0.01, -0.015, -0.2), W.mat("metal"), Vector3(PI * 0.5, 0, 0))
	W.cyl(_view, 0.062, 0.07, Vector3(0.01, -0.015, -0.34), W.mat("metal"), Vector3(PI * 0.5, 0, 0))
	W.cyl(_view, 0.05, 0.012, Vector3(0.01, -0.015, -0.377), W.mat("dark"), Vector3(PI * 0.5, 0, 0))
	_view.visible = false


func setup(g, lvl):
	game = g
	level = lvl
	var P = Global.data["player"]
	walk_speed = float(P["walk"]) / float(Global.data["cell"]) * CELL
	run_speed = float(P["run"]) / float(Global.data["cell"]) * CELL


func reset(pos):
	global_position = Vector3(pos.x, 0.02, pos.z)
	velocity = Vector3.ZERO
	concealed = false
	hidden_spot = ""
	collision_layer = 4
	yaw = 0.0
	pitch = 0.0
	rotation = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	camera.position = Vector3(0, W.EYE, 0)
	_bob_t = 0.0
	_breathe = 0.0
	_step_t = 0.0
	flash_on = false
	battery = 100.0
	move_input = Vector2.ZERO
	running = false
	var d = Global.diff()
	drain = float(d["battery_drain"])
	noise_walk = float(d["hear_walk"])
	noise_run = float(d["hear_run"])
	if flash != null:
		flash.visible = false
		spill.visible = false
		beam.visible = false
		if _inner != null:
			_inner.visible = false
		fill.visible = true
	if _view != null:
		_view.visible = has_flashlight
	if _lens != null:
		_lens.visible = false


func set_has_flashlight(on):
	has_flashlight = on
	if _view != null:
		_view.visible = on and not concealed


func add_look(px):
	## چرخش دید از روی درگ لمسی (پیکسل).
	var sens = 0.0029 * float(Global.settings.get("look_sens", 1.0))
	var inv = -1.0 if bool(Global.settings.get("invert_look", false)) else 1.0
	yaw -= px.x * sens
	pitch = clampf(pitch - px.y * sens * inv, -1.42, 1.42)
	_look_impulse += px * 0.02


func _unhandled_input(event):
	if game == null or game.state != "play" or get_tree().paused:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		add_look(event.relative * 0.85)


func _physics_process(delta):
	_t += delta
	noise_radius = 0.0
	if concealed:
		velocity = Vector3.ZERO
		_view.visible = false
		flash.visible = false
		spill.visible = false
		beam.visible = false
		if _inner != null:
			_inner.visible = false
		fill.visible = false
		_apply_camera(delta, 0.0)
		return
	_view.visible = has_flashlight
	fill.visible = true
	rotation.y = yaw
	var mv = move_input
	if mv.length() > 1.0:
		mv = mv.normalized()
	var fwd = Vector3(-sin(yaw), 0, -cos(yaw))
	var right = Vector3(cos(yaw), 0, -sin(yaw))
	var dir = right * mv.x + fwd * (-mv.y)
	var moving = dir.length() > 0.06
	var run_now = running and moving
	var spd = run_speed if run_now else walk_speed
	var target = dir * spd if moving else Vector3.ZERO
	var accel = 15.0 if moving else 11.0
	velocity.x = move_toward(velocity.x, target.x, accel * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * delta)
	velocity.y -= 16.0 * delta
	var vy = velocity.y
	move_and_slide()
	var grounded = is_on_floor()
	if grounded:
		velocity.y = 0.0
		if not _was_floor:
			_land = clampf(vy * 0.012, -0.07, 0.0)
	_was_floor = grounded
	_land = lerpf(_land, 0.0, minf(1.0, delta * 9.0))
	if moving:
		noise_radius = noise_run if run_now else noise_walk
		_bob_t += delta * (11.5 if run_now else 8.0)
		_step_t -= delta
		if _step_t <= 0.0:
			Sound.sfx("step", -2.0 if run_now else -8.0, randf_range(0.9, 1.1))
			_step_t = 0.28 if run_now else 0.46
		else:
			_step_t = maxf(0.0, _step_t)
	if flash_on:
		battery -= drain * delta
		if battery <= 0.0:
			battery = 0.0
			set_flash(false)
			if game != null:
				game.hud.toast("باتری چراغ‌قوه تمام شد")
	_apply_camera(delta, Vector2(velocity.x, velocity.z).length())
	_update_flash(delta)


func _apply_camera(delta, spd):
	_breathe += delta
	var amp = clampf(spd / run_speed, 0.0, 1.0) * 0.032
	var bob = sin(_bob_t) * amp
	var side = cos(_bob_t * 0.5) * amp * 0.55
	var breath = sin(_breathe * 1.35) * 0.0035
	_look_impulse = _look_impulse.lerp(Vector2.ZERO, minf(1.0, delta * 5.5))
	var roll = -side * 0.5 - clampf(_look_impulse.x * 0.006, -0.06, 0.06)
	camera.position = Vector3(side, W.EYE + bob + breath + _land, 0)
	camera.rotation.x = pitch
	camera.rotation.z = roll
	if _view != null:
		_sway = _sway.lerp(Vector2.ZERO, minf(1.0, delta * 7.0))
		var sway = _sway + Vector2(sin(_bob_t * 0.5) * amp * 0.7, -absf(bob) * 0.8)
		_view.position = Vector3(0.3 + sway.x, -0.27 + sway.y + breath * 0.7, -0.42)
		_view.rotation.z = sway.x * 0.7
		_view.rotation.x = sway.y * 0.5


func _update_flash(delta):
	if not flash_on:
		return
	var e = 9.0
	if battery < 30.0:
		_flash_flicker += delta
		var low = clampf(battery / 30.0, 0.0, 1.0)
		e *= lerpf(0.45, 1.0, low) * (0.75 + 0.25 * absf(sin(_flash_flicker * (8.0 + 6.0 * (1.0 - low)))))
	flash.light_energy = e
	spill.light_energy = 1.25 * (e / 9.0)
	_beam_mat.albedo_color.a = 0.05 * (e / 9.0)


func set_flash(on):
	if on and (not has_flashlight or battery <= 0.0):
		return false
	flash_on = on
	flash.visible = on and not concealed
	spill.visible = on and not concealed
	beam.visible = on and not concealed
	if _inner != null:
		_inner.visible = on and not concealed
	if _view != null:
		_view.visible = has_flashlight and not concealed
	if _lens != null:
		_lens.visible = on and not concealed
	# بالا آمدن نرم دست و چراغ‌قوه هنگام روشن کردن
	if _view != null:
		var tw = create_tween()
		tw.set_trans(Tween.TRANS_SINE)
		tw.set_ease(Tween.EASE_OUT)
		if on:
			_view.position = Vector3(0.3, -0.44, -0.42)
			tw.tween_property(_view, "position:y", -0.27, 0.22)
		else:
			tw.tween_property(_view, "position:y", -0.44, 0.16)
	return true


func toggle_flash():
	return set_flash(not flash_on)


func enter_hide(spot_id):
	concealed = true
	hidden_spot = spot_id
	collision_layer = 0
	velocity = Vector3.ZERO
	move_input = Vector2.ZERO
	set_flash(false)
	_view.visible = false


func leave_hide():
	concealed = false
	hidden_spot = ""
	collision_layer = 4
	_view.visible = has_flashlight
	fill.visible = true


func get_eye():
	return camera.global_position
