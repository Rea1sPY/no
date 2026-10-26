extends CharacterBody2D
## بازیکن: حرکت، دویدن (پرصدا)، چراغ‌قوه با باتری، پنهان شدن.

var game = null
var level = null
var walk_speed = 105.0
var run_speed = 170.0
var move_input = Vector2.ZERO
var running = false
var facing = 0.0
var concealed = false
var hidden_spot = ""
var flash_on = false
var has_flashlight = false
var battery = 100.0
var drain = 1.7
var noise_walk = 70.0
var noise_run = 260.0
var noise_radius = 0.0
var light_amb = null
var light_flash = null
var shape = null
var _step_t = 0.0
var _bob = 0.0


func _ready():
	collision_layer = 4
	collision_mask = 3
	shape = CollisionShape2D.new()
	var c = CircleShape2D.new()
	c.radius = 11.0
	shape.shape = c
	add_child(shape)
	light_amb = PointLight2D.new()
	light_amb.texture = Global.light_tex()
	light_amb.texture_scale = 1.2
	light_amb.energy = 0.55
	light_amb.color = Color(0.8, 0.85, 1.0)
	add_child(light_amb)
	light_flash = PointLight2D.new()
	light_flash.texture = Global.cone_tex()
	light_flash.texture_scale = 3.6
	light_flash.offset = Vector2(64.0 * 3.6, 0.0)
	light_flash.energy = 1.35
	light_flash.color = Color(1.0, 0.95, 0.8)
	light_flash.shadow_enabled = true
	light_flash.enabled = false
	add_child(light_flash)
	z_index = 5


func setup(g, lvl):
	game = g
	level = lvl
	var P = Global.data["player"]
	walk_speed = float(P["walk"])
	run_speed = float(P["run"])


func reset(pos):
	global_position = pos
	velocity = Vector2.ZERO
	concealed = false
	hidden_spot = ""
	visible = true
	collision_layer = 4
	flash_on = false
	light_flash.enabled = false
	battery = 100.0
	facing = 0.0
	move_input = Vector2.ZERO
	running = false
	var d = Global.diff()
	drain = float(d["battery_drain"])
	noise_walk = float(d["hear_walk"])
	noise_run = float(d["hear_run"])


func set_flash(on):
	if on and (not has_flashlight or battery <= 0.0):
		return false
	flash_on = on
	light_flash.enabled = on and not concealed
	return true


func toggle_flash():
	return set_flash(not flash_on)


func enter_hide(spot_id):
	concealed = true
	hidden_spot = spot_id
	visible = false
	collision_layer = 0
	velocity = Vector2.ZERO
	light_flash.enabled = false
	light_amb.enabled = false


func leave_hide():
	concealed = false
	hidden_spot = ""
	visible = true
	collision_layer = 4
	light_amb.enabled = true
	light_flash.enabled = flash_on


func _physics_process(delta):
	noise_radius = 0.0
	if concealed:
		velocity = Vector2.ZERO
		return
	var mv = move_input
	var moving = mv.length() > 0.12
	var spd = walk_speed
	var run_now = running and moving
	if run_now:
		spd = run_speed
	if moving:
		velocity = mv.limit_length(1.0) * spd
		facing = lerp_angle(facing, mv.angle(), minf(1.0, 12.0 * delta))
		noise_radius = noise_run if run_now else noise_walk
		_step_t -= delta
		_bob += delta * (14.0 if run_now else 9.0)
		if _step_t <= 0.0:
			Sound.sfx("step", -2.0 if run_now else -8.0, randf_range(0.9, 1.1))
			_step_t = 0.28 if run_now else 0.46
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	if flash_on:
		battery -= drain * delta
		if battery <= 0.0:
			battery = 0.0
			set_flash(false)
			if game != null:
				game.hud.toast("باتری چراغ‌قوه تمام شد")
	light_flash.rotation = facing
	queue_redraw()


func _draw():
	draw_circle(Vector2(1, 3), 12.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, facing, Vector2.ONE)
	var sway = sin(_bob) * 2.0
	draw_circle(Vector2(0, -7 + sway), 6.0, Color(0.18, 0.28, 0.4))
	draw_circle(Vector2(0, 7 - sway), 6.0, Color(0.18, 0.28, 0.4))
	draw_circle(Vector2(0, 0), 8.0, Color(0.22, 0.34, 0.48))
	draw_circle(Vector2(2, 0), 6.0, Color(0.85, 0.7, 0.58))
	draw_circle(Vector2(0, 0), 6.5, Color(0.1, 0.08, 0.1, 0.0))
	if has_flashlight:
		draw_rect(Rect2(8, 4, 9, 4), Color(0.4, 0.4, 0.45))
		if flash_on:
			draw_rect(Rect2(16, 4, 3, 4), Color(1.0, 0.95, 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
