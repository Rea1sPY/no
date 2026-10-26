extends Node3D
## اشیای قابل تعامل سه‌بعدی: برداشتنی، یادداشت، کمد، جعبه‌فیوز، تابلو، هسته و پایانه.
## همه‌ی مدل‌ها از جعبه/استوانه ساخته می‌شوند و نور و درخشش خودشان را دارند.

const W = preload("res://scripts/world.gd")

var kind = ""
var id = ""
var info = {}
var state = 0
var highlight = false
var level = null
var _t = 0.0
var _item = null
var _ring = null
var _rings = []
var _screen = null
var _led = null
var _face = Vector3(0, 0, 1)


func setup(k, i, cell, d, lvl):
	kind = k
	id = i
	info = d
	level = lvl
	add_to_group("interactables")
	position = lvl.cell_to_pos(cell)
	_t = randf() * 6.0
	match kind:
		"pickup":
			_build_pickup()
		"note":
			_build_note()
		"hide":
			_build_hide(cell)
		"fusebox":
			_build_fusebox()
		"panel":
			_build_panel()
		"core":
			_build_core()
		"secret":
			_build_secret()
	_build_ring()


func _build_ring():
	_ring = W.torus(self, 0.26, 0.34, Vector3(0, 0.03, 0), W.glow(Color(1.0, 0.72, 0.3), 1.4))
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false


func set_highlight(on):
	highlight = on


func is_active():
	if kind == "hide":
		return true
	if kind == "secret":
		return Global.progress["notes"].size() >= 7
	return true


func prompt():
	match kind:
		"pickup":
			return "برداشتن: " + info["name"]
		"note":
			return "خواندن یادداشت"
		"hide":
			return "پنهان شدن: " + info["name"]
		"fusebox":
			return "نصب فیوز" if state == 0 else "فیوز نصب شده است"
		"panel":
			return "تابلوی دسته‌های برق"
		"core":
			return "هسته‌ی حلقه"
		"secret":
			return "پایانه‌ی پنهان"
	return "تعامل"


func _process(delta):
	_t += delta
	if _item != null:
		_item.position.y = 1.02 + sin(_t * 1.8) * 0.055
		_item.rotation.y += delta * 0.7
	if _ring != null:
		_ring.visible = highlight
		if highlight:
			var p = 0.94 + 0.1 * sin(_t * 5.0)
			_ring.scale = Vector3(p, 1.0, p)
	if _screen != null and kind == "secret":
		_screen.visible = is_active() and int(_t * 2.2) % 7 != 0
	if _led != null and kind == "fusebox" and state == 0:
		_led.visible = int(_t * 3.0) % 2 == 0
	for r in _rings:
		r.rotation.y += delta * 0.55
		r.rotation.z += delta * 0.2


# ---------- وسایل برداشتنی ----------
func _build_pickup():
	_item = Node3D.new()
	_item.position = Vector3(0, 1.02, 0)
	add_child(_item)
	var metal = W.mat("metal")
	var warm = W.glow(Color(1.0, 0.82, 0.35), 1.6)
	var cyan = W.glow(Color(0.2, 0.8, 1.0), 1.3)
	if id == "card":
		W.box(_item, Vector3(0.24, 0.01, 0.15), Vector3.ZERO, cyan)
		W.box(_item, Vector3(0.08, 0.012, 0.02), Vector3(-0.04, 0.008, 0), W.mat("paper"))
	elif id == "key":
		W.cyl(_item, 0.04, 0.03, Vector3(-0.07, 0, 0), warm, Vector3(PI * 0.5, 0, 0))
		W.box(_item, Vector3(0.16, 0.025, 0.03), Vector3(0.02, 0, 0), warm)
		W.box(_item, Vector3(0.03, 0.025, 0.055), Vector3(0.09, 0, 0.02), warm)
	elif id == "fuse":
		W.cyl(_item, 0.035, 0.16, Vector3.ZERO, W.mat("rust"), Vector3(PI * 0.5, 0, 0))
		W.cyl(_item, 0.04, 0.02, Vector3(0.075, 0, 0), metal, Vector3(PI * 0.5, 0, 0))
		W.cyl(_item, 0.04, 0.02, Vector3(-0.075, 0, 0), metal, Vector3(PI * 0.5, 0, 0))
	elif id == "flashlight":
		W.cyl(_item, 0.055, 0.22, Vector3.ZERO, metal, Vector3(PI * 0.5, 0, 0))
		W.cyl(_item, 0.075, 0.04, Vector3(0.12, 0, 0), W.glow(Color(1.0, 0.9, 0.5), 2.0), Vector3(PI * 0.5, 0, 0))
	else:
		W.box(_item, Vector3(0.22, 0.012, 0.3), Vector3.ZERO, W.mat("paper"), Vector3(0, 0.2, 0))
		W.box(_item, Vector3(0.06, 0.014, 0.05), Vector3(0.06, 0.002, 0.1), W.mat("blood"))
	W.sprite_glow(_item, Color(1.0, 0.9, 0.6, 0.35), 0.7)


func _build_note():
	_item = Node3D.new()
	_item.position = Vector3(0, 1.02, 0)
	add_child(_item)
	W.box(_item, Vector3(0.24, 0.008, 0.32), Vector3.ZERO, W.mat("paper"), Vector3(0, 0.25, 0.1))
	for i in 3:
		W.box(_item, Vector3(0.16, 0.01, 0.012), Vector3(0, 0.006, -0.06 + i * 0.06), W.mat("blood"))
	W.sprite_glow(_item, Color(1.0, 0.85, 0.55, 0.28), 0.6)


# ---------- کمد ----------
func _build_hide(cell):
	var fd = level.free_dir(cell)
	_face = fd
	position = level.cell_to_pos(cell)
	rotation.y = atan2(fd.x, fd.z)
	var body = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var cs = CollisionShape3D.new()
	var sh = BoxShape3D.new()
	sh.size = Vector3(0.94, 2.1, 0.62)
	cs.shape = sh
	cs.position = Vector3(0, 1.05, 0)
	body.add_child(cs)
	var metal = W.mat("metal")
	W.box(self, Vector3(0.94, 2.1, 0.6), Vector3(0, 1.05, 0), metal)
	W.box(self, Vector3(0.86, 1.94, 0.02), Vector3(0, 1.07, 0.305), W.mat("dark"))
	for i in 3:
		for k in 3:
			W.box(self, Vector3(0.14, 0.015, 0.02), Vector3(-0.18 + k * 0.14, 1.62 + i * 0.09, 0.318), W.mat("rust"))
	W.box(self, Vector3(0.03, 0.1, 0.03), Vector3(0.34, 1.0, 0.325), W.glow(Color(0.9, 0.8, 0.4), 1.0))
	W.box(self, Vector3(0.96, 0.06, 0.62), Vector3(0, 2.12, 0), W.mat("rust"))


# ---------- جعبه فیوز ----------
func _build_fusebox():
	var fd = level.free_dir(Vector2i(int(position.x), int(position.z)))
	position -= fd * 0.35
	rotation.y = atan2(fd.x, fd.z)
	W.box(self, Vector3(0.62, 0.8, 0.22), Vector3(0, 1.45, 0.1), W.mat("metal"))
	W.box(self, Vector3(0.52, 0.68, 0.02), Vector3(0, 1.45, 0.22), W.mat("dark"))
	W.box(self, Vector3(0.3, 0.34, 0.03), Vector3(0, 1.45, 0.235), W.mat("rust"))
	_led = W.sphere(self, 0.045, Vector3(0.2, 1.72, 0.24), W.glow(Color(1.0, 0.12, 0.1), 2.0))
	W.box(self, Vector3(0.06, 0.06, 0.04), Vector3(-0.2, 1.18, 0.23), W.glow(Color(1.0, 0.7, 0.2), 1.0))
	W.label(self, "برق", Vector3(0, 1.05, 0.24), 0.0028, Color(0.9, 0.85, 0.7), Vector3.ZERO, 40)


# ---------- تابلو دسته‌ها ----------
func _build_panel():
	var fd = level.free_dir(Vector2i(int(position.x), int(position.z)))
	position -= fd * 0.35
	rotation.y = atan2(fd.x, fd.z)
	W.box(self, Vector3(0.72, 0.86, 0.22), Vector3(0, 1.42, 0.1), W.mat("metal"))
	W.box(self, Vector3(0.6, 0.72, 0.03), Vector3(0, 1.42, 0.22), W.mat("dark"))
	var cols = [Color(1.0, 0.12, 0.1), Color(0.15, 0.4, 1.0), Color(0.12, 0.9, 0.3), Color(1.0, 0.85, 0.1)]
	for i in 4:
		W.box(self, Vector3(0.06, 0.2, 0.04), Vector3(-0.24 + i * 0.16, 1.4, 0.235), W.glow(cols[i], 1.5))
	W.box(self, Vector3(0.32, 0.12, 0.02), Vector3(0, 1.62, 0.238), W.mat("screen_red"))
	W.label(self, "دسته‌های برق", Vector3(0, 0.95, 0.24), 0.0028, Color(0.9, 0.85, 0.7), Vector3.ZERO, 40)


# ---------- هسته ----------
func _build_core():
	var metal = W.mat("metal")
	W.cyl(self, 0.38, 0.16, Vector3(0, 0.08, 0), metal)
	W.cyl(self, 0.28, 0.55, Vector3(0, 0.4, 0), W.mat("dark"))
	W.cyl(self, 0.44, 0.08, Vector3(0, 0.72, 0), metal)
	var core_mat = W.glow(Color(0.62, 0.22, 1.0), 2.4)
	var s = W.sphere(self, 0.24, Vector3(0, 1.1, 0), core_mat)
	_rings.append(W.torus(self, 0.3, 0.36, Vector3(0, 1.1, 0), W.glow(Color(0.7, 0.4, 1.0), 1.6), Vector3(PI * 0.5, 0, 0)))
	_rings.append(W.torus(self, 0.36, 0.4, Vector3(0, 1.1, 0), W.glow(Color(0.45, 0.25, 0.9), 1.2)))
	for i in 4:
		var a = i * PI * 0.5
		W.box(self, Vector3(0.05, 0.5, 0.05), Vector3(cos(a) * 0.38, 0.98, sin(a) * 0.38), metal, Vector3(0.25 * sin(a), 0, -0.25 * cos(a)))
	var l = OmniLight3D.new()
	l.position = Vector3(0, 1.1, 0)
	l.light_color = Color(0.6, 0.3, 1.0)
	l.light_energy = 1.6
	l.omni_range = 5.0
	l.shadow_enabled = false
	add_child(l)
	var sb = StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	add_child(sb)
	var cs = CollisionShape3D.new()
	var sh = CylinderShape3D.new()
	sh.radius = 0.44
	sh.height = 1.0
	cs.shape = sh
	cs.position = Vector3(0, 0.5, 0)
	sb.add_child(cs)
	_screen = s


# ---------- پایانه پنهان ----------
func _build_secret():
	var fd = level.free_dir(Vector2i(int(position.x), int(position.z)))
	position -= fd * 0.34
	rotation.y = atan2(fd.x, fd.z)
	W.box(self, Vector3(0.62, 0.5, 0.18), Vector3(0, 1.25, 0.08), W.mat("metal"))
	_screen = W.box(self, Vector3(0.48, 0.32, 0.02), Vector3(0, 1.27, 0.18), W.mat("screen_green"))
	W.box(self, Vector3(0.5, 0.04, 0.28), Vector3(0, 0.98, 0.1), W.mat("dark"))
	W.label(self, "پایانه", Vector3(0, 1.55, 0.18), 0.0026, Color(0.6, 0.9, 0.7), Vector3.ZERO, 34)
