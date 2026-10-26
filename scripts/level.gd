extends Node2D
## ساخت نقشه از روی data.gd: کف، دیوارها (برخورد + سایه)، مبلمان، چراغ‌ها، درها و اشیای قابل تعامل، و شبکه‌ی مسیریابی دشمن.

const CELL = 32
const InteractableScript = preload("res://scripts/interactable.gd")
const DoorScript = preload("res://scripts/door.gd")

var D = null
var gw = 0
var gh = 0
var solid = []
var room_grid = []
var edge_rects = []
var astar = null
var body = null
var dynamic = null
var lamps = []
var power_on = false
var doors = {}
var secret_node = null


func build():
	D = Global.data
	gw = D["grid"]["w"]
	gh = D["grid"]["h"]
	_make_grid()
	_make_collision()
	_make_astar()
	_make_lamps()
	queue_redraw()


# ---------- شبکه ----------
func _make_grid():
	solid = []
	room_grid = []
	for y in gh:
		var row = []
		var rrow = []
		for x in gw:
			row.append(true)
			rrow.append("")
		solid.append(row)
		room_grid.append(rrow)
	for r in D["rooms"]:
		for y in range(r["y"], r["y"] + r["h"]):
			for x in range(r["x"], r["x"] + r["w"]):
				solid[y][x] = false
				room_grid[y][x] = r["id"]
	for d in D["doors"]:
		solid[d["cell"][1]][d["cell"][0]] = false
	for o in D["obstacles"]:
		for y in range(o["y"], o["y"] + o["h"]):
			for x in range(o["x"], o["x"] + o["w"]):
				solid[y][x] = true
	for h in D["hides"]:
		solid[h["cell"][1]][h["cell"][0]] = true


func is_solid(c):
	if c.x < 0 or c.y < 0 or c.x >= gw or c.y >= gh:
		return true
	return solid[c.y][c.x]


func pos_to_cell(p):
	return Vector2i(int(floor(p.x / CELL)), int(floor(p.y / CELL)))


func cell_to_pos(c):
	return Vector2(c.x * CELL + CELL * 0.5, c.y * CELL + CELL * 0.5)


func room_at(p):
	var c = pos_to_cell(p)
	if c.x < 0 or c.y < 0 or c.x >= gw or c.y >= gh:
		return ""
	var id = room_grid[c.y][c.x]
	for r in D["rooms"]:
		if r["id"] == id:
			return r["name"]
	return ""


# ---------- برخورد و سایه ----------
func _near_floor(x, y):
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var nx = x + dx
			var ny = y + dy
			if nx >= 0 and ny >= 0 and nx < gw and ny < gh and not solid[ny][nx]:
				return true
	return false


func _make_collision():
	var edge = []
	var used = []
	for y in gh:
		var er = []
		var ur = []
		for x in gw:
			er.append(solid[y][x] and _near_floor(x, y))
			ur.append(false)
		edge.append(er)
		used.append(ur)
	edge_rects = []
	for y in gh:
		for x in gw:
			if edge[y][x] and not used[y][x]:
				var w = 1
				while x + w < gw and edge[y][x + w] and not used[y][x + w]:
					w += 1
				var h = 1
				var ok = true
				while ok and y + h < gh:
					for xx in range(x, x + w):
						if not edge[y + h][xx] or used[y + h][xx]:
							ok = false
							break
					if ok:
						h += 1
				for yy in range(y, y + h):
					for xx in range(x, x + w):
						used[yy][xx] = true
				edge_rects.append(Rect2i(x, y, w, h))
	body = StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for r in edge_rects:
		var cs = CollisionShape2D.new()
		var rs = RectangleShape2D.new()
		rs.size = Vector2(r.size.x * CELL, r.size.y * CELL)
		cs.shape = rs
		cs.position = Vector2((r.position.x + r.size.x * 0.5) * CELL, (r.position.y + r.size.y * 0.5) * CELL)
		body.add_child(cs)
		var oc = LightOccluder2D.new()
		var poly = OccluderPolygon2D.new()
		var x0 = r.position.x * CELL
		var y0 = r.position.y * CELL
		var x1 = (r.position.x + r.size.x) * CELL
		var y1 = (r.position.y + r.size.y) * CELL
		poly.polygon = PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])
		oc.occluder = poly
		add_child(oc)


# ---------- مسیریابی ----------
func _make_astar():
	astar = AStarGrid2D.new()
	astar.size = Vector2i(gw, gh)
	astar.cell_size = Vector2(CELL, CELL)
	astar.offset = Vector2(CELL * 0.5, CELL * 0.5)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in gh:
		for x in gw:
			if solid[y][x]:
				astar.set_point_solid(Vector2i(x, y), true)


func nearest_free(c):
	if not is_solid(c):
		return c
	for r in range(1, 5):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var n = Vector2i(c.x + dx, c.y + dy)
				if not is_solid(n):
					return n
	return c


func find_path(a, b):
	var ca = nearest_free(pos_to_cell(a))
	var cb = nearest_free(pos_to_cell(b))
	if ca == cb:
		return PackedVector2Array([b])
	return astar.get_point_path(ca, cb)


# ---------- چراغ‌ها ----------
func _make_lamps():
	for c in D["lamps"]:
		var l = PointLight2D.new()
		l.texture = Global.light_tex()
		l.texture_scale = 2.6
		l.energy = 0.8
		l.color = Color(1.0, 0.35, 0.3)
		l.position = Vector2(c[0] * CELL + CELL * 0.5, c[1] * CELL + CELL * 0.5)
		l.enabled = false
		add_child(l)
		lamps.append(l)
	var e = PointLight2D.new()
	e.texture = Global.light_tex()
	e.texture_scale = 2.0
	e.energy = 0.9
	e.color = Color(1.0, 0.1, 0.1)
	e.position = Vector2(61.5 * CELL, 12.5 * CELL)
	add_child(e)


func set_power(on):
	power_on = on
	for l in lamps:
		l.enabled = on


# ---------- اشیای پویا (هر حلقه از نو ساخته می‌شوند) ----------
func reset_dynamic():
	if dynamic != null:
		dynamic.queue_free()
	dynamic = Node2D.new()
	add_child(dynamic)
	doors = {}
	set_power(false)
	for d in D["doors"]:
		var dn = DoorScript.new()
		dynamic.add_child(dn)
		dn.setup(d)
		doors[d["id"]] = dn
	for p in D["pickups"]:
		if p["id"] == "flashlight" and Global.progress["has_flashlight"]:
			continue
		_spawn("pickup", p["id"], p["cell"], p)
	for n in D["notes"]:
		_spawn("note", n["id"], n["cell"], n)
	for h in D["hides"]:
		_spawn("hide", h["id"], h["cell"], h)
	_spawn("fusebox", "fusebox", D["levers"]["fusebox"], {})
	_spawn("panel", "panel", D["levers"]["panel"], {})
	_spawn("core", "core", D["cores"]["pos"], {})
	secret_node = _spawn("secret", "secret", D["secret"]["cell"], {})


func _spawn(kind, id, cell, info):
	var n = InteractableScript.new()
	dynamic.add_child(n)
	n.setup(kind, id, Vector2i(cell[0], cell[1]), info)
	return n


func hide_pos(id):
	for h in D["hides"]:
		if h["id"] == id:
			return cell_to_pos(Vector2i(h["cell"][0], h["cell"][1]))
	return Vector2.ZERO


# ---------- نقاشی ----------
func _draw():
	if D == null:
		return
	draw_rect(Rect2(0, 0, gw * CELL, gh * CELL), Color(0.01, 0.008, 0.012))
	for r in D["rooms"]:
		var col = Color.html(r["floor"])
		draw_rect(Rect2(r["x"] * CELL, r["y"] * CELL, r["w"] * CELL, r["h"] * CELL), col)
		for i in range(r["w"] + 1):
			draw_line(Vector2((r["x"] + i) * CELL, r["y"] * CELL), Vector2((r["x"] + i) * CELL, (r["y"] + r["h"]) * CELL), Color(0, 0, 0, 0.25), 1.0)
		for j in range(r["h"] + 1):
			draw_line(Vector2(r["x"] * CELL, (r["y"] + j) * CELL), Vector2((r["x"] + r["w"]) * CELL, (r["y"] + j) * CELL), Color(0, 0, 0, 0.25), 1.0)
	for d in D["doors"]:
		draw_rect(Rect2(d["cell"][0] * CELL, d["cell"][1] * CELL, CELL, CELL), Color(0.06, 0.05, 0.07))
	_draw_decor()
	for r in edge_rects:
		var rc = Rect2(r.position.x * CELL, r.position.y * CELL, r.size.x * CELL, r.size.y * CELL)
		draw_rect(rc, Color(0.075, 0.062, 0.08))
		draw_rect(rc, Color(0.16, 0.13, 0.17), false, 2.0)
	for o in D["obstacles"]:
		_draw_furniture(Rect2(o["x"] * CELL, o["y"] * CELL, o["w"] * CELL, o["h"] * CELL), o["kind"])
	for h in D["hides"]:
		_draw_furniture(Rect2(h["cell"][0] * CELL, h["cell"][1] * CELL, CELL, CELL), h["kind"])


func _draw_decor():
	var rng = RandomNumberGenerator.new()
	rng.seed = 1337
	for i in 26:
		var p = Vector2(rng.randf_range(100.0, gw * CELL - 100.0), rng.randf_range(100.0, gh * CELL - 100.0))
		var c = pos_to_cell(p)
		if not is_solid(c):
			draw_circle(p, rng.randf_range(5.0, 16.0), Color(0.28, 0.02, 0.03, 0.55))
	# راه‌راه هشدار جلوی خروج
	for i in 6:
		draw_rect(Rect2(59 * CELL + i * 10, 11 * CELL, 5, CELL * 3), Color(0.55, 0.45, 0.05, 0.35))


func _draw_furniture(rc, kind):
	var base = Color(0.20, 0.15, 0.12)
	var edge = Color(0.32, 0.25, 0.2)
	if kind == "bed":
		base = Color(0.17, 0.2, 0.28)
	elif kind == "machine":
		base = Color(0.16, 0.18, 0.2)
		edge = Color(0.28, 0.32, 0.36)
	elif kind == "crate":
		base = Color(0.26, 0.19, 0.1)
		edge = Color(0.4, 0.3, 0.16)
	elif kind == "shelf":
		base = Color(0.18, 0.16, 0.13)
	elif kind == "rack":
		base = Color(0.1, 0.11, 0.13)
		edge = Color(0.2, 0.22, 0.26)
	elif kind == "console":
		base = Color(0.1, 0.16, 0.17)
	elif kind == "locker" or kind == "cabinet" or kind == "closet":
		base = Color(0.17, 0.2, 0.21)
		edge = Color(0.3, 0.34, 0.36)
	draw_rect(rc, base)
	draw_rect(rc, edge, false, 2.0)
	if kind == "crate":
		draw_line(rc.position, rc.position + rc.size, edge, 2.0)
		draw_line(rc.position + Vector2(rc.size.x, 0), rc.position + Vector2(0, rc.size.y), edge, 2.0)
	elif kind == "shelf":
		var n = int(maxf(rc.size.x, rc.size.y) / CELL)
		for i in n:
			if rc.size.y > rc.size.x:
				draw_line(rc.position + Vector2(0, i * CELL), rc.position + Vector2(rc.size.x, i * CELL), edge, 2.0)
			else:
				draw_line(rc.position + Vector2(i * CELL, 0), rc.position + Vector2(i * CELL, rc.size.y), edge, 2.0)
	elif kind == "machine" or kind == "rack":
		var n2 = int(maxf(rc.size.x, rc.size.y) / CELL)
		for i in n2:
			var p = rc.position + Vector2(10, 10) + (Vector2(0, i * CELL) if rc.size.y > rc.size.x else Vector2(i * CELL, 0))
			draw_circle(p, 3.0, Color(0.9, 0.15, 0.15))
	elif kind == "console":
		for i in int(rc.size.x / CELL):
			draw_rect(Rect2(rc.position + Vector2(i * CELL + 5, 6), Vector2(22, 12)), Color(0.1, 0.45, 0.5))
	elif kind == "locker" or kind == "cabinet" or kind == "closet":
		draw_line(rc.position + Vector2(CELL * 0.5, 4), rc.position + Vector2(CELL * 0.5, CELL - 4), edge, 2.0)
		draw_circle(rc.position + Vector2(CELL * 0.5 + 5, CELL * 0.5), 2.0, Color(0.8, 0.7, 0.3))
