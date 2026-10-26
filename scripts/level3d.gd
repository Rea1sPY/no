extends Node3D
## ساخت نقشه‌ی سه‌بعدی از روی data.gd: کف، دیوار، سقف، مبلمان، لامپ‌ها، لوله‌ها،
## تابلوها، لکه‌های خون، غبار و شبکه‌ی مسیریابی دشمن. همه‌چیز رویه‌ای ساخته می‌شود.

const W = preload("res://scripts/world.gd")
const CELL = W.CELL
const WALL_H = W.WALL_H
const InteractableScript = preload("res://scripts/interactable3d.gd")
const DoorScript = preload("res://scripts/door3d.gd")

var D = null
var gw = 0
var gh = 0
var solid = []
var room_grid = []
var prop = []
var edge_rects = []
var astar = null
var dynamic = null
var lamps = []
var power_on = false
var doors = {}
var secret_node = null
var _t = 0.0
var _lamp_t = 0.0
var _dust = null
var _dust_t = 0.0
var _bx = {}
var _cy = {}
var _swing = []
var _tubes = []


func build():
	D = Global.data
	gw = D["grid"]["w"]
	gh = D["grid"]["h"]
	_make_grid()
	_make_astar()
	_build_floors()
	_build_walls()
	_build_obstacles()
	_build_trim()
	_build_ceiling()
	_build_pipes()
	_build_props()
	_build_room_details()
	_build_hanging_lights()
	_build_decals()
	_flush_batches()
	_build_lamps()
	_build_exit()
	_build_dust()


# ---------- شبکه ----------
func _make_grid():
	solid = []
	room_grid = []
	prop = []
	for y in gh:
		var row = []
		var rrow = []
		var prow = []
		for x in gw:
			row.append(true)
			rrow.append("")
			prow.append(false)
		solid.append(row)
		room_grid.append(rrow)
		prop.append(prow)
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
				prop[y][x] = true
	for h in D["hides"]:
		solid[h["cell"][1]][h["cell"][0]] = true
		prop[h["cell"][1]][h["cell"][0]] = true


func is_solid(c):
	if c.x < 0 or c.y < 0 or c.x >= gw or c.y >= gh:
		return true
	return solid[c.y][c.x]


func pos_to_cell(p):
	return Vector2i(int(floor(p.x / CELL)), int(floor(p.z / CELL)))


func cell_to_pos(c):
	return Vector3(c.x * CELL + CELL * 0.5, 0.0, c.y * CELL + CELL * 0.5)


func room_at(p):
	var c = pos_to_cell(p)
	if c.x < 0 or c.y < 0 or c.x >= gw or c.y >= gh:
		return ""
	var id = room_grid[c.y][c.x]
	for r in D["rooms"]:
		if r["id"] == id:
			return r["name"]
	return ""


func free_dir(c):
	## اولین جهت آزاد اطراف یک خانه (برای چسباندن کمد/تابلو به دیوار).
	for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		if not is_solid(Vector2i(c.x + d.x, c.y + d.y)):
			return Vector3(d.x, 0.0, d.y)
	return Vector3(0, 0, 1)


# ---------- کف و سقف ----------
func _build_floors():
	var base = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(gw * CELL, 0.2, gh * CELL)
	base.mesh = bm
	base.material_override = W.mat("dark")
	base.position = Vector3(gw * CELL * 0.5, -0.11, gh * CELL * 0.5)
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(base)
	var fb = StaticBody3D.new()
	fb.collision_layer = 1
	fb.collision_mask = 0
	add_child(fb)
	var fcs = CollisionShape3D.new()
	var fsh = BoxShape3D.new()
	fsh.size = Vector3(gw * CELL, 0.2, gh * CELL)
	fcs.shape = fsh
	fcs.position = Vector3(gw * CELL * 0.5, -0.1, gh * CELL * 0.5)
	fb.add_child(fcs)
	for r in D["rooms"]:
		var mi = MeshInstance3D.new()
		var m = BoxMesh.new()
		m.size = Vector3(r["w"] * CELL, 0.1, r["h"] * CELL)
		mi.mesh = m
		var alt = r["id"] == "power" or r["id"] == "storage" or r["id"] == "archive"
		mi.material_override = W.floor_mat(r["floor"], alt)
		mi.position = Vector3((r["x"] + r["w"] * 0.5) * CELL, -0.05, (r["y"] + r["h"] * 0.5) * CELL)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	var ceil = MeshInstance3D.new()
	var cm = BoxMesh.new()
	cm.size = Vector3(gw * CELL, 0.2, gh * CELL)
	ceil.mesh = cm
	ceil.material_override = W.mat("ceiling")
	ceil.position = Vector3(gw * CELL * 0.5, WALL_H + 0.1, gh * CELL * 0.5)
	ceil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ceil)


# ---------- دیوارها ----------
func _near_floor(x, y):
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var nx = x + dx
			var ny = y + dy
			if nx >= 0 and ny >= 0 and nx < gw and ny < gh and not solid[ny][nx]:
				return true
	return false


func _make_edge_rects():
	var edge = []
	var used = []
	for y in gh:
		var er = []
		var ur = []
		for x in gw:
			er.append(solid[y][x] and not prop[y][x] and _near_floor(x, y))
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


func _build_walls():
	_make_edge_rects()
	var body = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for r in edge_rects:
		var mi = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(r.size.x * CELL, WALL_H, r.size.y * CELL)
		mi.mesh = bm
		mi.material_override = W.mat("wall_b" if (r.position.x * 3 + r.position.y) % 11 == 0 else "wall")
		mi.position = Vector3((r.position.x + r.size.x * 0.5) * CELL, WALL_H * 0.5, (r.position.y + r.size.y * 0.5) * CELL)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		var cs = CollisionShape3D.new()
		var sh = BoxShape3D.new()
		sh.size = bm.size
		cs.shape = sh
		cs.position = mi.position
		body.add_child(cs)


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
		return PackedVector3Array([b])
	var out = PackedVector3Array()
	for p in astar.get_point_path(ca, cb):
		out.append(Vector3(p.x, 0.0, p.y))
	if out.is_empty():
		out.append(b)
	return out


# ---------- مبلمان ----------
func _furniture_height(kind):
	match kind:
		"bed":
			return 0.55
		"desk", "table", "console":
			return 0.78
		"machine":
			return 1.65
		"crate":
			return 0.9
		"shelf", "rack":
			return 1.95
	return 1.0


func _build_obstacles():
	var body = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for o in D["obstacles"]:
		var w = o["w"] * CELL
		var d = o["h"] * CELL
		var cx = (o["x"] + o["w"] * 0.5) * CELL
		var cz = (o["y"] + o["h"] * 0.5) * CELL
		var h = _furniture_height(o["kind"])
		_make_furniture(Vector3(cx, 0, cz), o["kind"], w, d, h)
		var cs = CollisionShape3D.new()
		var sh = BoxShape3D.new()
		sh.size = Vector3(w, h, d)
		cs.shape = sh
		cs.position = Vector3(cx, h * 0.5, cz)
		body.add_child(cs)


func _make_furniture(o, kind, w, d, h):
	if kind == "bed":
		_b("dark", o + Vector3(0, 0.25, 0), Vector3(w, 0.22, d))
		_b("bed", o + Vector3(0, 0.43, 0), Vector3(w - 0.08, 0.2, d - 0.08))
		_b("cloth", o + Vector3(-w * 0.28, 0.58, 0), Vector3(w * 0.35, 0.12, d * 0.7))
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_b("metal", o + Vector3(sx * (w * 0.5 - 0.06), 0.17, sz * (d * 0.5 - 0.06)), Vector3(0.07, 0.34, 0.07))
	elif kind == "desk" or kind == "table" or kind == "console":
		_b("wood", o + Vector3(0, h - 0.04, 0), Vector3(w, 0.07, d))
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_b("dark", o + Vector3(sx * (w * 0.5 - 0.08), (h - 0.1) * 0.5, sz * (d * 0.5 - 0.08)), Vector3(0.07, h - 0.1, 0.07))
		if kind == "console":
			_b("dark", o + Vector3(0, h + 0.16, -d * 0.08), Vector3(w * 0.72, 0.06, d * 0.55), Vector3(-0.5, 0, 0))
			W.box(self, Vector3(w * 0.62, 0.02, d * 0.45), o + Vector3(0, h + 0.2, -d * 0.05), W.glow(Color(0.1, 0.7, 0.75), 1.0), Vector3(-0.5, 0, 0))
		else:
			_b("paper", o + Vector3(-w * 0.18, h + 0.01, 0), Vector3(0.28, 0.03, 0.2))
			_b("rust", o + Vector3(w * 0.22, h + 0.05, 0), Vector3(0.16, 0.1, 0.16))
	elif kind == "machine":
		_b("metal", o + Vector3(0, h * 0.5, 0), Vector3(w * 0.94, h, d * 0.9))
		_b("dark", o + Vector3(0, h * 0.62, d * 0.45), Vector3(w * 0.7, 0.55, 0.03))
		for i in 3:
			W.box(self, Vector3(0.06, 0.06, 0.02), o + Vector3(-w * 0.25 + i * 0.14, h * 0.35, d * 0.46), W.glow(Color(0.9, 0.15, 0.12), 1.4))
		_b("rust", o + Vector3(w * 0.18, h - 0.02, 0), Vector3(w * 0.3, 0.02, d * 0.2))
		for i in 4:
			_b("dark", o + Vector3(0, h * 0.18 + i * 0.08, d * 0.46), Vector3(w * 0.6, 0.02, 0.02))
	elif kind == "crate":
		_b("wood", o + Vector3(0, h * 0.5, 0), Vector3(w * 0.92, h, d * 0.92))
		for sx in [-1.0, 1.0]:
			_b("rust", o + Vector3(sx * w * 0.42, h * 0.5, 0), Vector3(0.04, h * 0.95, d * 0.94))
			_b("rust", o + Vector3(0, h * 0.5, sx * d * 0.42), Vector3(w * 0.94, h * 0.95, 0.04))
	elif kind == "shelf" or kind == "rack":
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_b("metal", o + Vector3(sx * (w * 0.5 - 0.03), h * 0.5, sz * (d * 0.5 - 0.03)), Vector3(0.05, h, 0.05))
		var n = 4
		for i in n:
			var yy = 0.25 + i * (h - 0.35) / float(n - 1)
			_b("dark", o + Vector3(0, yy, 0), Vector3(w - 0.04, 0.04, d - 0.04))
			if kind == "shelf" and i < 3:
				for k in 2:
					var off = (k - 0.5) * 0.32
					_b("paper" if k % 2 == 0 else "rust", o + Vector3(off, yy + 0.14, 0), Vector3(0.22, 0.24, 0.26))
			elif kind == "rack" and i < 3:
				W.box(self, Vector3(0.06, 0.05, 0.02), o + Vector3(-w * 0.3 + i * 0.1, yy + 0.12, d * 0.48), W.glow(Color(0.2, 1.0, 0.35), 1.5))
		if kind == "rack":
			for i in 2:
				_bc("rubber", o + Vector3(w * 0.5 - 0.06, h * 0.5, -d * 0.35 + i * 0.12), 0.018, h * 0.8)


# ---------- دسته‌بندی هندسه ----------
func _b(kind, pos, size, rot = Vector3.ZERO):
	if not _bx.has(kind):
		_bx[kind] = []
	_bx[kind].append(W.xf(pos, size, rot))


func _bc(kind, pos, radius, height, rot = Vector3.ZERO):
	if not _cy.has(kind):
		_cy[kind] = []
	_cy[kind].append(W.xf(pos, Vector3(radius * 2.0, height, radius * 2.0), rot))


func _flush_batches():
	for k in _bx:
		W.batch(self, W.mat(k), _bx[k])
	for k in _cy:
		W.batch(self, W.mat(k), _cy[k], true)


func _room(id):
	for r in D["rooms"]:
		if r["id"] == id:
			return r
	return null


func _cp(x, y, h = 0.0):
	return Vector3((float(x) + 0.5) * CELL, h, (float(y) + 0.5) * CELL)


# ---------- قرنیز و نوار محافظ دیوار ----------
func _build_trim():
	for y in gh:
		for x in gw:
			if not solid[y][x] or prop[y][x]:
				continue
			for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
				var nx = x + d.x
				var ny = y + d.y
				if nx < 0 or ny < 0 or nx >= gw or ny >= gh:
					continue
				if solid[ny][nx]:
					continue
				var px = (float(x) + 0.5 + d.x * 0.5) * CELL
				var pz = (float(y) + 0.5 + d.y * 0.5) * CELL
				if d.x != 0:
					_b("dark", Vector3(px, 0.09, pz), Vector3(0.06, 0.18, 1.0))
					_b("metal_dark", Vector3(px, 1.04, pz), Vector3(0.045, 0.05, 1.0))
				else:
					_b("dark", Vector3(px, 0.09, pz), Vector3(1.0, 0.18, 0.06))
					_b("metal_dark", Vector3(px, 1.04, pz), Vector3(1.0, 0.05, 0.045))


# ---------- سقف: تیر، دریچه، سینی کابل ----------
func _build_ceiling():
	for x in range(5, 59, 4):
		_b("concrete", Vector3(float(x), WALL_H - 0.12, 12.5), Vector3(0.24, 0.24, 3.0))
	for i in range(8, 59, 9):
		_b("metal_dark", Vector3(float(i), WALL_H - 0.04, 11.35), Vector3(0.62, 0.06, 0.34))
		W.quad(self, Vector2(0.56, 0.28), Vector3(float(i), WALL_H - 0.075, 11.35), W.mat("vent"), Vector3(PI * 0.5, 0, 0))
		for k in 4:
			_b("dark", Vector3(float(i) - 0.2 + k * 0.14, WALL_H - 0.075, 11.35), Vector3(0.05, 0.03, 0.28))
	_b("metal_dark", Vector3(30.5, WALL_H - 0.36, 13.55), Vector3(55.0, 0.05, 0.3))
	for i in range(4, 59, 3):
		_b("rust", Vector3(float(i), WALL_H - 0.31, 13.55), Vector3(0.05, 0.12, 0.2))
	for r in D["rooms"]:
		if r["id"] == "corridor":
			continue
		var x0 = (float(r["x"]) + 0.4) * CELL
		var x1 = (float(r["x"]) + float(r["w"]) - 0.4) * CELL
		var z = (float(r["y"]) + 0.35) * CELL
		_bc("rust", Vector3((x0 + x1) * 0.5, WALL_H - 0.2, z), 0.05, x1 - x0, Vector3(0, 0, PI * 0.5))
		_bc("metal_dark", Vector3((x0 + x1) * 0.5, WALL_H - 0.34, z + 0.16), 0.03, x1 - x0, Vector3(0, 0, PI * 0.5))


# ---------- لوله‌ها ----------
func _build_pipes():
	for z in [11.28, 12.72]:
		_bc("rust", Vector3(30.5, 2.62, z), 0.055, 55.0, Vector3(0, 0, PI * 0.5))
		_bc("metal_dark", Vector3(30.5, 2.48, z + 0.16), 0.035, 55.0, Vector3(0, 0, PI * 0.5))
	for i in range(5, 60, 6):
		_b("metal", Vector3(float(i), 2.7, 11.28), Vector3(0.06, 0.3, 0.06))
		_b("metal", Vector3(float(i), 2.7, 12.72), Vector3(0.06, 0.3, 0.06))
	for c in [[4, 11], [4, 13], [59, 11], [59, 13], [14, 11], [45, 13]]:
		_bc("rust", _cp(c[0], c[1], 1.4), 0.06, 2.8)
		_bc("metal", _cp(c[0], c[1], 0.12), 0.075, 0.08)


# ---------- وسایل کمکی ----------
func _crate(pos, s = 0.6, h = 0.0):
	_b("wood", pos + Vector3(0, h + s * 0.5, 0), Vector3(s, s, s))
	_b("rust", pos + Vector3(0, h + s * 0.5, 0), Vector3(s + 0.015, s * 0.09, s + 0.015))


func _barrel(pos):
	_bc("rust", pos + Vector3(0, 0.45, 0), 0.28, 0.9)
	_bc("metal_dark", pos + Vector3(0, 0.28, 0), 0.295, 0.05)
	_bc("metal_dark", pos + Vector3(0, 0.62, 0), 0.295, 0.05)


func _chair(pos, rot = Vector3.ZERO):
	var d = Vector3(sin(rot.y), 0, cos(rot.y))
	_b("metal_dark", pos + Vector3(0, 0.46, 0), Vector3(0.42, 0.05, 0.42), rot)
	_b("metal_dark", pos + Vector3(0, 0.74, 0) + d * 0.2, Vector3(0.42, 0.5, 0.05), rot)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_b("metal_dark", pos + Vector3(sx * 0.17, 0.22, sz * 0.17), Vector3(0.04, 0.44, 0.04))


func _locker(pos, rot = Vector3.ZERO):
	_b("metal", pos + Vector3(0, 1.05, 0), Vector3(0.9, 2.1, 0.55), rot)
	_b("dark", pos + Vector3(0, 1.15, 0.29), Vector3(0.72, 1.5, 0.02), rot)
	_b("metal_dark", pos + Vector3(0.3, 1.0, 0.3), Vector3(0.04, 0.12, 0.03), rot)


func _table(pos, w = 1.4, d = 0.7, h = 0.78):
	_b("wood", pos + Vector3(0, h, 0), Vector3(w, 0.07, d))
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_b("metal_dark", pos + Vector3(sx * (w * 0.5 - 0.1), h * 0.5, sz * (d * 0.5 - 0.08)), Vector3(0.06, h, 0.06))


func _monitor(pos, rot, col = Color(0.15, 0.85, 0.45)):
	_b("metal_dark", pos + Vector3(0, 0.08, 0), Vector3(0.5, 0.16, 0.32), rot)
	_b("dark", pos + Vector3(0, 0.28, 0) + Vector3(sin(rot.y), 0, cos(rot.y)) * 0.06, Vector3(0.5, 0.36, 0.05), rot)
	var scr = W.box(self, Vector3(0.4, 0.27, 0.01), pos + Vector3(0, 0.3, 0) + Vector3(sin(rot.y), 0, cos(rot.y)) * 0.09, W.glow(col, 1.5), rot)
	scr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _gurney(pos, rot = Vector3.ZERO):
	_b("metal", pos + Vector3(0, 0.62, 0), Vector3(1.9, 0.09, 0.72), rot)
	_b("cloth", pos + Vector3(0, 0.69, 0), Vector3(1.86, 0.07, 0.68), rot)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_b("metal_dark", pos + Vector3(sx * 0.78, 0.3, sz * 0.28), Vector3(0.05, 0.62, 0.05))
			_bc("rubber", pos + Vector3(sx * 0.8, 0.06, 0.3), 0.07, 0.04, Vector3(0, 0, PI * 0.5))


func _bench(pos, rot = Vector3.ZERO):
	_b("wood", pos + Vector3(0, 0.44, 0), Vector3(1.9, 0.08, 0.45), rot)
	_b("wood", pos + Vector3(0, 0.74, 0.18), Vector3(1.9, 0.4, 0.06), rot)
	for sx in [-1, 1]:
		_b("metal_dark", pos + Vector3(sx * 0.8, 0.22, 0), Vector3(0.08, 0.44, 0.4), rot)


func _shelf_unit(pos, rot, w = 1.8, h = 2.0, d = 0.5):
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_b("metal_dark", pos + Vector3(sx * (w * 0.5 - 0.03), h * 0.5, sz * (d * 0.5 - 0.03)), Vector3(0.05, h, 0.05), rot)
	for i in 4:
		var y = 0.3 + i * (h - 0.45) / 3.0
		_b("metal_dark", pos + Vector3(0, y, 0), Vector3(w, 0.04, d), rot)


func _papers(pos, rng, n = 5):
	for i in n:
		var o = Vector3(rng.randf_range(-0.7, 0.7), 0.012, rng.randf_range(-0.7, 0.7))
		_b("paper", pos + o, Vector3(0.21, 0.006, 0.29), Vector3(0, rng.randf_range(0, TAU), 0))


func _cable(pos, length, rot = Vector3.ZERO):
	_bc("rubber", pos, 0.022, length, rot)


# ---------- تابلوها و پوسترها ----------
func _poster(text, cx, cy, side, y, size, tex = "poster_a"):
	## side=1 یعنی دیوار شمالی (رو به جنوب)، side=-1 یعنی دیوار جنوبی.
	var pos = Vector3(cx * CELL, y, cy * CELL + (0.03 if side == 1 else -0.03))
	var rot = Vector3(0, 0 if side == 1 else PI, 0)
	W.quad(self, Vector2(1.15, 0.62), pos, W.mat(tex), rot)
	W.label(self, text, pos + Vector3(0, 0, 0.012 * side), 0.0032, Color(0.12, 0.09, 0.09), rot, size)


func _arrow(pos, rot):
	_b("rust", pos + Vector3(0, 0.01, 0), Vector3(0.5, 0.01, 0.12), rot)
	_b("rust", pos + Vector3(0.2, 0.01, 0.12), Vector3(0.34, 0.01, 0.1), rot + Vector3(0, 0.7, 0))
	_b("rust", pos + Vector3(0.2, 0.01, -0.12), Vector3(0.34, 0.01, 0.1), rot - Vector3(0, 0.7, 0))


# ---------- جزئیات محیط ----------
func _build_props():
	var rng = RandomNumberGenerator.new()
	rng.seed = 90210
	_poster("بخش ۷ — دسترسی ممنوع", 5, 3, 1, 1.65, 26, "poster_a")
	_poster("پروژه کرونوس", 22, 3, 1, 1.72, 30, "poster_b")
	_poster("خطر: ولتاژ بالا", 35, 3, 1, 1.68, 24, "poster_a")
	_poster("شیفت شب — سکوت", 6, 23, -1, 1.6, 24, "poster_b")
	_poster("خروج اضطراری", 58, 20, -1, 1.8, 26, "poster_terminal")
	_poster("آزمودنی ۰", 24, 10, -1, 1.7, 30, "poster_blood")
	# نوار خطر جلوی در خروجی و روی لبه‌ی پله‌ها
	W.decal(self, "hazard_stripes", Vector2(2.4, 0.45), Vector3(59.0, 0.016, 12.5), Vector3(-PI * 0.5, 0, 0), Color(1, 1, 1, 0.9))
	W.decal(self, "hazard_stripes", Vector2(1.6, 0.35), Vector3(36.4, 0.016, 10.9), Vector3(-PI * 0.5, PI * 0.5, 0), Color(1, 1, 1, 0.8))
	W.decal(self, "hazard_stripes", Vector2(1.6, 0.35), Vector3(50.6, 0.016, 10.9), Vector3(-PI * 0.5, PI * 0.5, 0), Color(1, 1, 1, 0.8))
	# کاغذها و آشغال‌های کف
	for i in 40:
		var p = _random_floor(rng)
		if p == Vector3.ZERO:
			continue
		var s = rng.randf_range(0.04, 0.13)
		_b("dark", p + Vector3(0, s * 0.5, 0), Vector3(s, s, s), Vector3(0, rng.randf_range(0, TAU), 0))
	for i in 30:
		var p2 = _random_floor(rng)
		if p2 == Vector3.ZERO:
			continue
		_b("paper", p2 + Vector3(0, 0.012, 0), Vector3(0.2, 0.005, 0.28), Vector3(0, rng.randf_range(0, TAU), 0))
	# صندلی‌های شکسته و نیمکت راهرو
	for i in 3:
		var x = 12.0 + i * 17.0
		_chair(Vector3(x, 0, 13.25), Vector3(0, rng.randf_range(-0.6, 0.6), 0))
	_bench(Vector3(24.0, 0, 13.45))
	_bench(Vector3(47.0, 0, 13.45), Vector3(0, PI, 0))
	# جعبه‌های کنار دیوار و بشکه
	for i in 8:
		var p3 = _random_floor(rng)
		if p3 == Vector3.ZERO:
			continue
		_crate(p3, rng.randf_range(0.38, 0.55), 0.0)
	for i in 5:
		var p4 = _random_floor(rng)
		if p4 == Vector3.ZERO:
			continue
		_barrel(p4)
	# کابل‌های کف راهرو
	for i in 6:
		var x0 = 6.0 + i * 9.0
		_cable(Vector3(x0 + 1.5, 0.03, 11.7), 3.2, Vector3(0, 0, PI * 0.5))
	# فلش‌های راهنما
	_arrow(Vector3(17.5, 0, 12.5), Vector3(0, PI * 0.5, 0))
	_arrow(Vector3(42.5, 0, 12.5), Vector3(0, PI * 0.5, 0))


# ---------- جزئیات هر اتاق ----------
func _build_room_details():
	var rng = RandomNumberGenerator.new()
	rng.seed = 4411
	# --- اتاق شروع: تخت، پایه سرم، سینی ابزار ---
	_pole(Vector3(5.2, 0, 4.1))
	_table(Vector3(11.2, 0, 8.6), 1.2, 0.6, 0.76)
	_monitor(Vector3(11.2, 0.76, 8.6), Vector3(0, PI * 0.5, 0), Color(0.2, 0.9, 0.5))
	_locker(Vector3(11.6, 0, 4.2), Vector3(0, -PI * 0.5, 0))
	# --- آزمایشگاه: میز کار، شیشه‌های نمونه، دستگاه‌ها ---
	_table(Vector3(19.0, 0, 8.9), 4.2, 0.9, 0.82)
	for i in 5:
		var jp = Vector3(17.4 + i * 0.75, 0.94, 8.9)
		_bc("glass", jp + Vector3(0, 0.13, 0), 0.09, 0.26)
		_bc("metal", jp + Vector3(0, 0.02, 0), 0.1, 0.04)
		var gl = W.sphere(self, 0.06, jp + Vector3(0, 0.16, 0), W.glow(Color(0.25, 1.0, 0.55), 1.2))
		gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_monitor(Vector3(16.1, 0.82, 8.9), Vector3(0, 0, 0), Color(0.2, 0.8, 1.0))
	_monitor(Vector3(21.6, 0.82, 8.9), Vector3(0, 0, 0), Color(0.2, 1.0, 0.5))
	for i in 4:
		_cable(Vector3(16.5 + i * 1.2, 0.02, 9.5), 2.2, Vector3(0, 0, PI * 0.5))
	_shelf_unit(Vector3(27.6, 0, 8.2), Vector3(0, -PI * 0.5, 0), 2.4, 1.9, 0.5)
	# --- اتاق برق: ترانسفورماتور، کابل، تابلو ---
	_transformer(Vector3(33.6, 0, 5.2))
	_transformer(Vector3(40.5, 0, 5.2))
	for i in 6:
		_cable(Vector3(33.6 + i * 1.2, 0.03, 6.4), 1.6, Vector3(0, PI * 0.5, 0))
	_b("rust", Vector3(36.5, 1.55, 9.55), Vector3(0.7, 0.5, 0.06))
	W.label(self, "ولتاژ بالا", Vector3(36.5, 1.55, 9.62), 0.003, Color(0.95, 0.2, 0.15), Vector3.ZERO, 44)
	# --- انبار: بشکه، جعبه، پالت ---
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_b("wood", Vector3(56.6 + sx * 0.5, 0.06, 8.6 + sz * 0.5), Vector3(1.1, 0.12, 1.1))
	_crate(Vector3(56.2, 0, 8.2), 0.62, 0.12)
	_crate(Vector3(57.0, 0, 8.9), 0.55, 0.12)
	_crate(Vector3(56.5, 0, 8.5), 0.45, 0.74)
	_barrel(Vector3(45.9, 0, 8.9))
	_barrel(Vector3(46.8, 0, 8.9))
	_barrel(Vector3(45.9, 0, 9.7))
	for i in 3:
		_crate(Vector3(53.0 + i * 0.8, 0, 4.2), 0.5)
	# --- راهرو: تخت بیمار، ترالی، کپسول ---
	_gurney(Vector3(33.5, 0, 12.2), Vector3(0, 0.05, 0))
	_cart(Vector3(52.5, 0, 12.2))
	_bc("rust", Vector3(6.2, 0.35, 11.6), 0.12, 0.7)
	_bc("metal_dark", Vector3(6.2, 0.72, 11.6), 0.05, 0.12)
	# --- نگهبانی: میز، صندلی، مانیتور، تخته کلید ---
	_chair(Vector3(7.6, 0, 19.4), Vector3(0, 0.2, 0))
	_monitor(Vector3(6.8, 0.78, 18.4), Vector3(0, 0, 0), Color(0.3, 0.8, 1.0))
	_b("metal_dark", Vector3(9.4, 1.6, 17.95), Vector3(0.9, 0.5, 0.05))
	for i in 4:
		_b("metal", Vector3(9.05 + i * 0.22, 1.6, 18.0), Vector3(0.04, 0.12, 0.02))
	_b("paper", Vector3(6.4, 0.83, 18.9), Vector3(0.3, 0.01, 0.4), Vector3(0, 0.3, 0))
	_cup(Vector3(8.6, 0.78, 18.6))
	# --- امنیت: رک، کنسول، صندلی ---
	_chair(Vector3(29.4, 0, 19.4), Vector3(0, PI, 0))
	_chair(Vector3(26.2, 0, 19.4), Vector3(0, PI, 0))
	for i in 4:
		var sy = 0.4 + i * 0.35
		_b("rust", Vector3(28.4, sy, 18.4), Vector3(0.04, 0.05, 0.03))
		var gl2 = W.box(self, Vector3(0.03, 0.025, 0.012), Vector3(28.42, sy, 18.42), W.glow(Color(0.2, 1.0, 0.4), 2.0))
		gl2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_b("metal_dark", Vector3(23.4, 2.2, 15.05), Vector3(1.6, 0.7, 0.05))
	var scr = W.box(self, Vector3(1.45, 0.58, 0.01), Vector3(23.4, 2.2, 15.1), W.glow(Color(0.1, 0.7, 0.85), 1.1))
	scr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# --- آرشیو: جعبه‌های پرونده، نردبان ---
	for i in 3:
		for k in 3:
			_b("paper", Vector3(39.5 + i * 3.0, 0.37, 16.7 + k * 1.2), Vector3(0.34, 0.32, 0.42), Vector3(0, 0.05 * k, 0))
	_b("metal", Vector3(47.6, 1.3, 20.0), Vector3(0.08, 2.6, 0.5))
	for i in 5:
		_b("metal", Vector3(47.6, 0.35 + i * 0.5, 20.0), Vector3(0.5, 0.05, 0.06))
	_papers(Vector3(44.0, 0, 21.5), rng, 8)


func _pole(pos):
	_bc("metal", pos + Vector3(0, 0.9, 0), 0.02, 1.8)
	_bc("metal", pos + Vector3(0, 1.8, 0), 0.14, 0.04)
	_bc("metal", pos + Vector3(0, 0.1, 0), 0.16, 0.04)
	var bag = W.box(self, Vector3(0.16, 0.24, 0.05), pos + Vector3(0.13, 1.55, 0), W.glow(Color(0.55, 0.8, 1.0), 0.35))
	bag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _transformer(pos):
	_b("metal_dark", pos + Vector3(0, 0.75, 0), Vector3(1.2, 1.5, 1.0))
	for i in 5:
		_b("rust", pos + Vector3(-0.45 + i * 0.22, 0.75, 0.52), Vector3(0.05, 1.3, 0.05))
	_bc("rust", pos + Vector3(0, 1.7, 0), 0.06, 0.5)
	_bc("rubber", pos + Vector3(0.3, 1.9, 0), 0.035, 0.6, Vector3(0.3, 0, 0))


func _cart(pos):
	_b("metal", pos + Vector3(0, 0.85, 0), Vector3(0.8, 0.06, 0.5))
	_b("metal", pos + Vector3(0, 0.45, 0), Vector3(0.7, 0.05, 0.4))
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_bc("metal", pos + Vector3(sx * 0.3, 0.88, sz * 0.2), 0.015, 0.9)
			_bc("rubber", pos + Vector3(sx * 0.3, 0.06, sz * 0.2), 0.05, 0.04, Vector3(0, 0, PI * 0.5))
	_b("paper", pos + Vector3(0, 0.89, 0), Vector3(0.4, 0.01, 0.3))


func _cup(pos):
	_bc("paper", pos + Vector3(0, 0.07, 0), 0.045, 0.14)


# ---------- لامپ‌های آویزان متحرک ----------
func _build_hanging_lights():
	for i in 3:
		var x = 16.0 + i * 18.0
		var pivot = Node3D.new()
		pivot.position = Vector3(x, WALL_H - 0.02, 12.5)
		add_child(pivot)
		_bc("rubber", Vector3(0, -0.42, 0), 0.012, 0.8)
		var shade = W.cyl(pivot, 0.2, 0.14, Vector3(0, -0.86, 0), W.mat("metal_dark"))
		shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var bulb = W.sphere(pivot, 0.055, Vector3(0, -0.94, 0), W.glow(Color(1.0, 0.78, 0.42), 1.4))
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var l = OmniLight3D.new()
		l.position = Vector3(0, -0.95, 0)
		l.light_color = Color(1.0, 0.76, 0.45)
		l.light_energy = 0.9
		l.omni_range = 5.0
		l.shadow_enabled = false
		l.visible = false
		pivot.add_child(l)
		_swing.append({"node": pivot, "lamp": l, "phase": i * 1.7, "speed": 0.8 + i * 0.13})


func _build_decals():
	var rng = RandomNumberGenerator.new()
	rng.seed = 771
	# لکه‌های خون با بافت واقعی
	for i in 22:
		var p = _random_floor(rng)
		if p == Vector3.ZERO:
			continue
		var size = Vector2(rng.randf_range(0.6, 1.8), rng.randf_range(0.45, 1.2))
		W.decal(self, "blood_decal", size, p + Vector3(0, 0.014, 0), Vector3(-PI * 0.5, rng.randf_range(0, TAU), 0), Color(1, 1, 1, rng.randf_range(0.5, 0.95)))
	# رد کشیده‌ی خون در راهرو
	for i in 8:
		var x = 13.0 + i * 1.15
		W.decal(self, "blood_decal", Vector2(0.75, 0.5), Vector3(x, 0.013, 12.35 + sin(i) * 0.15), Vector3(-PI * 0.5, 0.3, 0), Color(1, 1, 1, 0.55))


# ---------- مکان تصادفی ----------
func _random_floor(rng):
	for tries in 18:
		var x = rng.randf_range(3.5, float(gw) - 3.0)
		var y = rng.randf_range(3.5, float(gh) - 3.0)
		var c = Vector2i(int(x), int(y))
		if is_solid(c):
			continue
		# چیزی جلوی نقطه‌ی بیدار شدن یا توی درها نگذار
		if absi(c.x - 6) + absi(c.y - 8) < 4:
			continue
		var blocked = false
		for d in D["doors"]:
			if absi(int(d["cell"][0]) - c.x) + absi(int(d["cell"][1]) - c.y) < 2:
				blocked = true
				break
		if blocked:
			continue
		return Vector3(x * CELL, 0, y * CELL)
	return Vector3.ZERO


# ---------- چراغ‌ها ----------
func _build_lamps():
	for c in D["lamps"]:
		var cx = (c[0] + 0.5) * CELL
		var cz = (c[1] + 0.5) * CELL
		W.box(self, Vector3(0.7, 0.05, 0.2), Vector3(cx, WALL_H - 0.1, cz), W.mat("metal"))
		var glow_mat = W.glow(Color(1.0, 0.82, 0.58), 1.4)
		var tube = W.box(self, Vector3(0.62, 0.035, 0.12), Vector3(cx, WALL_H - 0.14, cz), glow_mat)
		tube.visible = false
		var l = OmniLight3D.new()
		l.position = Vector3(cx, WALL_H - 0.28, cz)
		l.light_color = Color(1.0, 0.74, 0.48)
		l.light_energy = 1.35
		l.omni_range = 7.5
		l.omni_attenuation = 1.25
		l.shadow_enabled = false
		l.visible = false
		add_child(l)
		lamps.append({"light": l, "tube": tube, "base": 1.35, "phase": randf() * TAU})


func set_power(on):
	power_on = on
	if not on:
		for lamp in lamps:
			lamp["light"].visible = false
			lamp["tube"].visible = false


func update_lamps(pos, delta):
	## فقط چند چراغ نزدیک روشن می‌شود تا موبایل اذیت نشود.
	_lamp_t -= delta
	if _lamp_t > 0.0:
		return
	_lamp_t = 0.35
	if not power_on:
		return
	var dists = []
	for i in lamps.size():
		var l = lamps[i]["light"]
		var d = l.global_position.distance_to(pos)
		dists.append({"i": i, "d": d})
	dists.sort_custom(func(a, b): return a["d"] < b["d"])
	for k in lamps.size():
		var i = dists[k]["i"]
		var on = k < 5 and dists[k]["d"] < 26.0
		lamps[i]["light"].visible = on
		lamps[i]["tube"].visible = on


func _process(delta):
	_t += delta
	for sw in _swing:
		var node = sw["node"]
		node.rotation.z = sin(_t * float(sw["speed"]) + float(sw["phase"])) * 0.16
		node.rotation.x = cos(_t * float(sw["speed"]) * 0.8 + float(sw["phase"])) * 0.07
		var lp = sw["lamp"]
		if lp != null:
			lp.visible = power_on and lp.light_energy > 0.0
	for lamp in lamps:
		if lamp["light"].visible:
			var f = 0.82 + 0.18 * sin(_t * 7.0 + lamp["phase"])
			if randf() < 0.006:
				f *= 0.25
			lamp["light"].light_energy = float(lamp["base"]) * f
	if _dust != null and get_tree().get_first_node_in_group("player3d") != null:
		_dust_t -= delta
		if _dust_t <= 0.0:
			_dust_t = 0.6
			_dust.global_position = get_tree().get_first_node_in_group("player3d").global_position + Vector3(0, 0.9, 0)


func _build_dust():
	var p = CPUParticles3D.new()
	p.amount = 42
	p.lifetime = 7.0
	p.preprocess = 5.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(5.5, 1.4, 5.5)
	p.direction = Vector3(0, -1, 0)
	p.spread = 25.0
	p.gravity = Vector3(0, -0.015, 0)
	p.initial_velocity_min = 0.01
	p.initial_velocity_max = 0.07
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.4
	p.color = Color(0.8, 0.85, 1.0, 0.22)
	var qm = QuadMesh.new()
	qm.size = Vector2(0.028, 0.028)
	p.mesh = qm
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = Color(1, 1, 1, 0.7)
	m.vertex_color_use_as_albedo = true
	p.material_override = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	_dust = p


# ---------- خروج ----------
func _build_exit():
	var red = OmniLight3D.new()
	red.position = Vector3(60.2, 2.2, 12.5)
	red.light_color = Color(1.0, 0.12, 0.1)
	red.light_energy = 1.1
	red.omni_range = 6.0
	red.shadow_enabled = false
	add_child(red)
	W.box(self, Vector3(0.18, 0.22, 0.18), Vector3(60.2, 2.55, 12.5), W.glow(Color(1.0, 0.1, 0.08), 2.0))
	var green = OmniLight3D.new()
	green.position = Vector3(60.3, 2.25, 11.8)
	green.light_color = Color(0.15, 1.0, 0.45)
	green.light_energy = 0.55
	green.omni_range = 3.5
	green.shadow_enabled = false
	add_child(green)
	W.box(self, Vector3(0.02, 0.3, 0.55), Vector3(60.49, 2.25, 12.15), W.glow(Color(0.12, 0.9, 0.35), 1.4))
	W.label(self, "خروج", Vector3(60.44, 2.26, 12.15), 0.0035, Color(0.8, 1.0, 0.85), Vector3(0, -PI * 0.5, 0), 42)


# ---------- اشیای پویا ----------
func reset_dynamic():
	if dynamic != null:
		dynamic.queue_free()
	dynamic = Node3D.new()
	add_child(dynamic)
	doors = {}
	set_power(false)
	for d in D["doors"]:
		var dn = DoorScript.new()
		dynamic.add_child(dn)
		dn.setup(d, self)
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
	n.setup(kind, id, Vector2i(cell[0], cell[1]), info, self)
	return n


func hide_pos(id):
	for h in D["hides"]:
		if h["id"] == id:
			return cell_to_pos(Vector2i(h["cell"][0], h["cell"][1]))
	return Vector3.ZERO
