extends CharacterBody3D
## دشمن «ناظر» در دنیای سه‌بعدی: گشت، شنیدن، دیدن، تعقیب، جست‌وجو و وارسی کمدها.
## مدل از جعبه ساخته شده و دست و پا و چشم‌های قرمزش انیمیشن دارند.

const CELL = 1.0
const W = preload("res://scripts/world.gd")
enum {IDLE, PATROL, INVESTIGATE, CHASE, SEARCH, CHECK_HIDE}

var game = null
var level = null
var player = null
var P = {}
var state = IDLE
var path = PackedVector3Array()
var path_i = 0
var awareness = 0.0
var last_seen = Vector3.ZERO
var lose_timer = 0.0
var grace = 0.0
var repath_t = 0.0
var mem_t = 0.0
var wait_t = 0.0
var search_t = 0.0
var search_queue = []
var check_spot = ""
var heat = []
var step_t = 0.0
var _anim_t = 0.0
var _t = 0.0
var _eyes = []
var _glow = null
var _leg_l = null
var _leg_r = null
var _arm_l = null
var _arm_r = null
var _torso = null
var _head = null
var _move_spd = 0.0


func _ready():
	add_to_group("enemy3d")
	collision_layer = 8
	collision_mask = 1
	var cs = CollisionShape3D.new()
	var cap = CapsuleShape3D.new()
	cap.radius = 0.36
	cap.height = 1.9
	cs.shape = cap
	cs.position = Vector3(0, 0.95, 0)
	add_child(cs)
	_build_body()


func _build_body():
	var dark = StandardMaterial3D.new()
	dark.albedo_color = Color(0.035, 0.028, 0.035)
	dark.roughness = 0.98
	var coat = StandardMaterial3D.new()
	coat.albedo_color = Color(0.06, 0.05, 0.055)
	coat.roughness = 1.0
	_torso = Node3D.new()
	_torso.position = Vector3(0, 1.22, 0)
	add_child(_torso)
	W.box(_torso, Vector3(0.5, 0.72, 0.3), Vector3.ZERO, dark)
	W.box(_torso, Vector3(0.62, 0.6, 0.36), Vector3(0, -0.35, 0), coat, Vector3(0.08, 0, 0))
	W.box(_torso, Vector3(0.66, 0.16, 0.38), Vector3(0, -0.68, 0), coat)
	_head = Node3D.new()
	_head.position = Vector3(0, 0.56, 0)
	_torso.add_child(_head)
	W.box(_head, Vector3(0.26, 0.3, 0.24), Vector3.ZERO, dark)
	var eye_mat = W.glow(Color(1.0, 0.06, 0.08), 3.0)
	_eyes.append(W.sphere(_head, 0.028, Vector3(-0.065, 0.02, -0.128), eye_mat))
	_eyes.append(W.sphere(_head, 0.028, Vector3(0.065, 0.02, -0.128), eye_mat))
	# دست‌های بلند
	_arm_l = Node3D.new()
	_arm_l.position = Vector3(-0.34, 1.6, 0)
	add_child(_arm_l)
	W.box(_arm_l, Vector3(0.11, 0.92, 0.11), Vector3(0, -0.42, 0), dark, Vector3(0, 0, -0.06))
	W.box(_arm_l, Vector3(0.14, 0.18, 0.1), Vector3(0, -0.92, 0.01), dark)
	_arm_r = Node3D.new()
	_arm_r.position = Vector3(0.34, 1.6, 0)
	add_child(_arm_r)
	W.box(_arm_r, Vector3(0.11, 0.92, 0.11), Vector3(0, -0.42, 0), dark, Vector3(0, 0, 0.06))
	W.box(_arm_r, Vector3(0.14, 0.18, 0.1), Vector3(0, -0.92, 0.01), dark)
	_leg_l = Node3D.new()
	_leg_l.position = Vector3(-0.14, 0.92, 0)
	add_child(_leg_l)
	W.box(_leg_l, Vector3(0.17, 0.9, 0.19), Vector3(0, -0.45, 0), dark)
	W.box(_leg_l, Vector3(0.2, 0.1, 0.3), Vector3(0, -0.9, -0.04), dark)
	_leg_r = Node3D.new()
	_leg_r.position = Vector3(0.14, 0.92, 0)
	add_child(_leg_r)
	W.box(_leg_r, Vector3(0.17, 0.9, 0.19), Vector3(0, -0.45, 0), dark)
	W.box(_leg_r, Vector3(0.2, 0.1, 0.3), Vector3(0, -0.9, -0.04), dark)
	_glow = OmniLight3D.new()
	_glow.position = Vector3(0, 1.72, -0.1)
	_glow.light_color = Color(1.0, 0.1, 0.08)
	_glow.light_energy = 0.45
	_glow.omni_range = 3.2
	_glow.shadow_enabled = false
	add_child(_glow)


func setup(g, lvl, ply):
	game = g
	level = lvl
	player = ply


func reset(pos):
	P = Global.diff()
	global_position = Vector3(pos.x, 0.02, pos.z)
	velocity = Vector3.ZERO
	rotation = Vector3.ZERO
	state = IDLE
	grace = float(P["grace"])
	awareness = 0.0
	path = PackedVector3Array()
	path_i = 0
	search_queue = []
	check_spot = ""
	step_t = 0.0
	_anim_t = 0.0
	_compute_heat()


func _compute_heat():
	heat = []
	var pts = Global.data["patrol"]
	var maxh = 1.0
	for pt in pts:
		var h = 0.0
		for kind in ["escape", "death", "route"]:
			var mult = 0.3 if kind == "route" else 1.0
			var m = Global.memory[kind]
			for k in m:
				var c = Global.key_cell(k)
				if absi(c.x - pt[0]) + absi(c.y - pt[1]) <= 7:
					h += float(m[k]) * mult
		heat.append(h)
		maxh = maxf(maxh, h)
	for i in heat.size():
		heat[i] = heat[i] / maxh


func _weighted(items, weights):
	if items.is_empty():
		return null
	var total = 0.0
	for w in weights:
		total += w
	var r = randf() * total
	for i in items.size():
		r -= weights[i]
		if r <= 0.0:
			return items[i]
	return items[items.size() - 1]


# ---------- فرمان‌ها ----------
func hear(pos):
	if state == CHASE or grace > 0.0 or state == CHECK_HIDE:
		return
	state = INVESTIGATE
	_goto(pos)
	wait_t = 0.0


func on_player_hide(spot_id):
	if grace > 0.0:
		return
	var d = global_position.distance_to(player.global_position)
	if state == CHASE or (awareness > 0.25 and d < float(P["vision"]) * 1.2 and _los(global_position, player.global_position)):
		_start_check(spot_id)


func is_checking(spot_id):
	return state == CHECK_HIDE and check_spot == spot_id


# ---------- هوش ----------
func _los(a, b):
	var space = get_world_3d().direct_space_state
	var q = PhysicsRayQueryParameters3D.create(a + Vector3(0, 1.55, 0), b + Vector3(0, 1.45, 0), 3)
	q.collide_with_areas = false
	var r = space.intersect_ray(q)
	return r.is_empty()


func _goto(pos):
	path = level.find_path(global_position, pos)
	path_i = 0


func _start_chase():
	if state != CHASE:
		Sound.sfx("whisper", 0.0, 0.8)
		Global.vibrate(120)
	state = CHASE
	lose_timer = float(P["lose_time"])
	repath_t = 0.0


func _lose_player():
	state = SEARCH
	search_t = float(P["search_time"])
	wait_t = 0.0
	search_queue = []
	_goto(last_seen)
	if randf() < _hide_chance():
		var spot = _pick_hide(last_seen, 9)
		if spot != null:
			search_queue.append(spot)
	if randf() < _hide_chance() * 0.6:
		var spot2 = _pick_hide(last_seen, 12)
		if spot2 != null and not search_queue.has(spot2):
			search_queue.append(spot2)


func _hide_chance():
	var total = 0.0
	for k in Global.memory["hide"]:
		total += float(Global.memory["hide"][k])
	return clampf(0.06 + float(P["learn"]) * 0.35 * minf(1.0, total / 6.0), 0.0, 0.85)


func _pick_hide(pos, max_cells):
	var ids = []
	var ws = []
	for h in Global.data["hides"]:
		var hp = level.cell_to_pos(Vector2i(h["cell"][0], h["cell"][1]))
		if pos.distance_to(hp) < max_cells * CELL:
			ids.append(h["id"])
			ws.append(0.25 + float(Global.memory["hide"].get(h["id"], 0.0)))
	return _weighted(ids, ws)


func _start_check(spot_id):
	state = CHECK_HIDE
	check_spot = spot_id
	wait_t = 0.0
	_goto(level.hide_pos(spot_id))


func _next_patrol():
	var pts = Global.data["patrol"]
	var ws = []
	for i in pts.size():
		ws.append(1.0 + float(P["learn"]) * 4.0 * heat[i])
	var idx = _weighted(range(pts.size()), ws)
	if idx == null:
		idx = 0
	state = PATROL
	wait_t = 0.0
	_goto(level.cell_to_pos(Vector2i(pts[idx][0], pts[idx][1])))


func _follow(speed, delta):
	_move_spd = 0.0
	if path_i >= path.size():
		velocity.x = 0
		velocity.z = 0
		return true
	var to = path[path_i] - global_position
	to.y = 0
	if to.length() < 0.4:
		path_i += 1
		return path_i >= path.size()
	var dir = to.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	velocity.y -= 16.0 * delta
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(1.0, 9.0 * delta))
	var was = global_position
	move_and_slide()
	if is_on_floor():
		velocity.y = 0.0
	_move_spd = speed
	_anim_t += delta * speed * 2.2
	_step_sound(delta)
	return false


func _step_sound(delta):
	step_t -= delta
	if step_t <= 0.0:
		step_t = 0.58
		var d = global_position.distance_to(player.global_position)
		if d < 12.0:
			Sound.sfx("step", -4.0 - d * 1.4, 0.6)


func _sense(delta):
	var to_p = player.global_position - global_position
	to_p.y = 0
	var dist = to_p.length()
	var seen = false
	var rng = 1.0
	if not player.concealed:
		rng = float(P["vision"]) / float(Global.data["cell"]) * CELL
		if player.flash_on:
			rng *= 1.45
		if player.running:
			rng *= 1.15
		if dist < rng:
			var fwd = -global_transform.basis.z
			var ang = fwd.angle_to(to_p.normalized())
			var in_cone = ang < deg_to_rad(float(P["fov"]) * 0.5)
			if (in_cone or dist < 2.2) and _los(global_position, player.global_position):
				seen = true
	if seen:
		var closeness = clampf(1.0 - dist / (rng * 1.4), 0.15, 1.0)
		awareness += delta / float(P["detect_time"]) * (0.5 + closeness)
		last_seen = player.global_position
		if state == CHASE:
			lose_timer = float(P["lose_time"])
	else:
		awareness = maxf(0.0, awareness - delta * 0.35)
		if state == CHASE:
			lose_timer -= delta
			if lose_timer <= 0.0:
				_lose_player()
	if awareness >= 1.0 and state != CHASE:
		_start_chase()
	if state != CHASE and not player.concealed and player.noise_radius > 0.0:
		var r = player.noise_radius * game.aggression() / float(Global.data["cell"]) * CELL
		if not _los(global_position, player.global_position):
			r *= 0.6
		if dist < r:
			hear(player.global_position)


func _physics_process(delta):
	_t += delta
	if game == null or game.state != "play":
		return
	var aggr = game.aggression()
	if grace > 0.0:
		grace -= delta
		rotation.y += delta * 0.6
		if grace <= 0.0:
			_next_patrol()
		_animate(delta)
		return
	_sense(delta)
	if state == PATROL:
		if _follow(float(P["patrol_speed"]) / float(Global.data["cell"]) * CELL * aggr, delta):
			wait_t += delta
			if wait_t > 1.4:
				if randf() < _hide_chance():
					var spot = _pick_hide(global_position, 10)
					if spot != null:
						_start_check(spot)
						return
				_next_patrol()
	elif state == INVESTIGATE:
		if _follow(float(P["patrol_speed"]) * 1.25 / float(Global.data["cell"]) * CELL * aggr, delta):
			wait_t += delta
			rotation.y += delta * 1.5
			if wait_t > 2.0:
				_next_patrol()
	elif state == CHASE:
		repath_t -= delta
		if repath_t <= 0.0:
			repath_t = 0.35
			_goto(last_seen)
		_follow(float(P["chase_speed"]) / float(Global.data["cell"]) * CELL * aggr, delta)
		mem_t -= delta
		if mem_t <= 0.0:
			mem_t = 0.3
			Global.mem_add("escape", Global.cell_key(level.pos_to_cell(player.global_position)), 1.0)
	elif state == SEARCH:
		search_t -= delta
		if _follow(float(P["patrol_speed"]) * 1.2 / float(Global.data["cell"]) * CELL * aggr, delta):
			wait_t += delta
			rotation.y += delta * 1.8
			if wait_t > 1.6 and not search_queue.is_empty():
				var s = search_queue.pop_front()
				_start_check(s)
				return
			if search_t <= 0.0 or (wait_t > 2.5 and search_queue.is_empty()):
				_next_patrol()
		mem_t -= delta
		if mem_t <= 0.0:
			mem_t = 0.4
			Global.mem_add("escape", Global.cell_key(level.pos_to_cell(player.global_position)), 0.5)
	elif state == CHECK_HIDE:
		var target = level.hide_pos(check_spot)
		if global_position.distance_to(target) > 1.2 and path_i < path.size():
			_follow(float(P["patrol_speed"]) * 1.3 / float(Global.data["cell"]) * CELL * aggr, delta)
		else:
			wait_t += delta
			if wait_t > 0.6:
				if game.enemy_opened_spot(check_spot):
					return
				if wait_t > 1.6:
					_next_patrol()
	if state != CHASE and global_position.distance_to(player.global_position) < 0.85 and not player.concealed:
		game.player_caught(self)
		return
	if state == CHASE and global_position.distance_to(player.global_position) < 0.95 and not player.concealed:
		game.player_caught(self)
		return
	_animate(delta)


func _animate(delta):
	var moving = _move_spd > 0.1
	var amp = 0.65 if state == CHASE else 0.42
	var sw = sin(_anim_t) * amp if moving else sin(_t * 1.2) * 0.04
	if _leg_l != null:
		_leg_l.rotation.x = sw
		_leg_r.rotation.x = -sw
	if _arm_l != null:
		var arm_sw = -sw * 0.8
		if state == CHASE:
			arm_sw = -1.15 + sin(_anim_t * 0.5) * 0.25
		_arm_l.rotation.x = arm_sw
		_arm_r.rotation.x = -arm_sw
	if _torso != null:
		_torso.position.y = 1.22 + absf(sw) * 0.045
		_torso.rotation.z = sin(_anim_t * 0.5) * 0.035
	if _head != null:
		if state == CHASE and player != null:
			var to = player.global_position - global_position
			var want = wrapf(atan2(-to.x, -to.z) - rotation.y, -PI, PI)
			_head.rotation.y = lerp_angle(_head.rotation.y, clampf(want, -0.9, 0.9), minf(1.0, delta * 4.0))
			_head.rotation.x = sin(_t * 9.0) * 0.015
		else:
			_head.rotation.y = lerp_angle(_head.rotation.y, sin(_t * 0.7) * 0.18, minf(1.0, delta * 2.0))
			_head.rotation.x = 0.0
	if _glow != null:
		_glow.light_energy = 0.35 + (0.8 if state == CHASE else 0.0) + sin(_t * 8.0) * 0.08
	for e in _eyes:
		e.visible = int(_t * 3.0) % 11 != 0


func _move_speed():
	return _move_spd
