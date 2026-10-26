extends CharacterBody2D
## دشمن «ناظر»: گشت، شنیدن صدا، دیدن، تعقیب، جست‌وجو و وارسی کمدها.
## حافظه‌ی دائمی (Global.memory): مسیرهای فرار، کمدهای پناه و محل مرگ‌ها؛ دشمن در حلقه‌های بعد آن‌ها را بیشتر وارسی می‌کند.

const CELL = 32
enum {IDLE, PATROL, INVESTIGATE, CHASE, SEARCH, CHECK_HIDE}

var game = null
var level = null
var player = null
var P = {}
var state = IDLE
var facing = 0.0
var path = PackedVector2Array()
var path_i = 0
var awareness = 0.0
var last_seen = Vector2.ZERO
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
var light = null
var _flicker = 0.0


func _ready():
	collision_layer = 8
	collision_mask = 1
	var cs = CollisionShape2D.new()
	var c = CircleShape2D.new()
	c.radius = 12.0
	cs.shape = c
	add_child(cs)
	light = PointLight2D.new()
	light.texture = Global.light_tex()
	light.texture_scale = 1.5
	light.energy = 0.75
	light.color = Color(1.0, 0.1, 0.1)
	add_child(light)
	z_index = 4


func setup(g, lvl, ply):
	game = g
	level = lvl
	player = ply


func reset(pos):
	P = Global.diff()
	global_position = pos
	velocity = Vector2.ZERO
	state = IDLE
	grace = float(P["grace"])
	awareness = 0.0
	path = PackedVector2Array()
	path_i = 0
	search_queue = []
	check_spot = ""
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


# ---------- فرمان‌ها از بیرون ----------
func hear(pos):
	if state == CHASE or grace > 0.0 or state == CHECK_HIDE:
		return
	state = INVESTIGATE
	_goto(pos)
	wait_t = 0.0


func on_player_hide(spot_id):
	## اگر دشمن دیده باشد بازیکن کجا پنهان شد، مستقیم همان‌جا را وارسی می‌کند.
	if grace > 0.0:
		return
	var d = global_position.distance_to(player.global_position)
	if state == CHASE or (awareness > 0.25 and d < float(P["vision"]) * 1.2 and _los(global_position, player.global_position)):
		_start_check(spot_id)


func is_checking(spot_id):
	return state == CHECK_HIDE and check_spot == spot_id


# ---------- هوش ----------
func _los(a, b):
	var space = get_world_2d().direct_space_state
	var q = PhysicsRayQueryParameters2D.create(a, b, 3)
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
	if path_i >= path.size():
		velocity = Vector2.ZERO
		return true
	var to = path[path_i] - global_position
	if to.length() < 7.0:
		path_i += 1
		return path_i >= path.size()
	var dir = to.normalized()
	velocity = dir * speed
	facing = lerp_angle(facing, dir.angle(), minf(1.0, 9.0 * delta))
	move_and_slide()
	_step_sound(delta)
	return false


func _step_sound(delta):
	step_t -= delta
	if step_t <= 0.0:
		step_t = 0.5
		var d = global_position.distance_to(player.global_position)
		if d < 520.0:
			Sound.sfx("step", -4.0 - d / 45.0, 0.6)


func _sense(delta):
	var to_p = player.global_position - global_position
	var dist = to_p.length()
	var seen = false
	if not player.concealed:
		var rng = float(P["vision"])
		if player.flash_on:
			rng *= 1.4
		if player.running:
			rng *= 1.15
		if dist < rng:
			var ang = absf(angle_difference(facing, to_p.angle()))
			var in_cone = ang < deg_to_rad(float(P["fov"]) * 0.5)
			if (in_cone or dist < 70.0) and _los(global_position, player.global_position):
				seen = true
	if seen:
		var closeness = clampf(1.0 - dist / (float(P["vision"]) * 1.4), 0.15, 1.0)
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
		var r = player.noise_radius * game.aggression()
		if not _los(global_position, player.global_position):
			r *= 0.6
		if dist < r:
			hear(player.global_position)


func _physics_process(delta):
	velocity = Vector2.ZERO
	if game == null or game.state != "play":
		return
	var aggr = game.aggression()
	if grace > 0.0:
		grace -= delta
		facing += delta * 0.6
		if grace <= 0.0:
			_next_patrol()
		queue_redraw()
		return
	_sense(delta)
	if state == PATROL:
		if _follow(float(P["patrol_speed"]) * aggr, delta):
			wait_t += delta
			if wait_t > 1.4:
				if randf() < _hide_chance():
					var spot = _pick_hide(global_position, 10)
					if spot != null:
						_start_check(spot)
						return
				_next_patrol()
	elif state == INVESTIGATE:
		if _follow(float(P["patrol_speed"]) * 1.25 * aggr, delta):
			wait_t += delta
			facing += delta * 1.5
			if wait_t > 2.0:
				_next_patrol()
	elif state == CHASE:
		repath_t -= delta
		if repath_t <= 0.0:
			repath_t = 0.35
			_goto(last_seen)
		_follow(float(P["chase_speed"]) * aggr, delta)
		mem_t -= delta
		if mem_t <= 0.0:
			mem_t = 0.3
			Global.mem_add("escape", Global.cell_key(level.pos_to_cell(player.global_position)), 1.0)
	elif state == SEARCH:
		search_t -= delta
		if _follow(float(P["patrol_speed"]) * 1.2 * aggr, delta):
			wait_t += delta
			facing += delta * 1.8
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
		if global_position.distance_to(target) > 40.0 and path_i < path.size():
			_follow(float(P["patrol_speed"]) * 1.3 * aggr, delta)
		else:
			wait_t += delta
			if wait_t > 0.6:
				if game.enemy_opened_spot(check_spot):
					return
				if wait_t > 1.6:
					_next_patrol()
	if state != CHASE and global_position.distance_to(player.global_position) < 24.0 and not player.concealed:
		game.player_caught(self)
		return
	if state == CHASE and global_position.distance_to(player.global_position) < 26.0 and not player.concealed:
		game.player_caught(self)
		return
	_flicker = randf()
	queue_redraw()


func _draw():
	var f = 0.7 + 0.3 * _flicker
	draw_circle(Vector2(0, 4), 15.0, Color(0, 0, 0, 0.4))
	draw_set_transform(Vector2.ZERO, facing, Vector2.ONE)
	# دست‌های بلند
	draw_line(Vector2(0, -8), Vector2(20, -12), Color(0.04, 0.03, 0.04), 4.0)
	draw_line(Vector2(0, 8), Vector2(20, 12), Color(0.04, 0.03, 0.04), 4.0)
	draw_circle(Vector2(0, 0), 13.0, Color(0.05, 0.035, 0.045))
	draw_circle(Vector2(5, 0), 8.0, Color(0.09, 0.06, 0.07))
	# چشم‌های قرمز
	draw_circle(Vector2(10, -3), 2.6, Color(1.0 * f, 0.05, 0.08))
	draw_circle(Vector2(10, 3), 2.6, Color(1.0 * f, 0.05, 0.08))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
