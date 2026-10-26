extends Node3D
## در سه‌بعدی: چارچوب، لنگه‌ی متحرک، چراغ وضعیت و کارت‌خوان. با باز شدن،
## لنگه نرم می‌چرخد و برخوردش قطع می‌شود؛ دشمن هم از آن رد می‌شود.

const W = preload("res://scripts/world.gd")

var kind = "door"
var id = ""
var needs = "none"
var info = {}
var is_open = false
var unlocked = false
var highlight = false
var level = null
var _pivot = null
var _body = null
var _led = null
var _ring = null
var _t = 0.0


func setup(d, lvl):
	id = d["id"]
	needs = d["needs"]
	info = d
	level = lvl
	var cell = Vector2i(int(d["cell"][0]), int(d["cell"][1]))
	position = lvl.cell_to_pos(cell)
	var horiz = lvl.is_solid(Vector2i(cell.x - 1, cell.y)) and lvl.is_solid(Vector2i(cell.x + 1, cell.y))
	if not horiz:
		rotation.y = PI * 0.5
	add_to_group("interactables")
	_t = randf() * 5.0
	_build()


func _build():
	var metal = W.mat("metal")
	var dark = W.mat("dark")
	# چارچوب
	W.box(self, Vector3(0.1, 2.28, 0.24), Vector3(-0.5, 1.14, 0), metal)
	W.box(self, Vector3(0.1, 2.28, 0.24), Vector3(0.5, 1.14, 0), metal)
	W.box(self, Vector3(1.1, 0.12, 0.26), Vector3(0, 2.28, 0), metal)
	W.box(self, Vector3(1.02, 0.05, 0.3), Vector3(0, 0.025, 0), metal)
	# لنگه
	_pivot = Node3D.new()
	_pivot.position = Vector3(-0.48, 0, 0)
	add_child(_pivot)
	W.box(_pivot, Vector3(0.96, 2.14, 0.1), Vector3(0.48, 1.09, 0), W.mat("door"))
	W.box(_pivot, Vector3(0.7, 0.55, 0.02), Vector3(0.48, 1.62, 0.06), W.mat("glass"))
	W.box(_pivot, Vector3(0.76, 0.05, 0.11), Vector3(0.48, 0.98, 0), dark)
	W.box(_pivot, Vector3(0.04, 0.2, 0.06), Vector3(0.88, 1.05, 0.09), metal)
	for i in 3:
		W.box(_pivot, Vector3(0.5, 0.025, 0.02), Vector3(0.48, 1.28 + i * 0.09, 0.06), dark)
	# چراغ و کارت‌خوان
	var led_col = Color(0.2, 0.9, 0.3)
	if needs == "card":
		led_col = Color(0.2, 0.7, 0.95)
	elif needs == "key":
		led_col = Color(0.95, 0.8, 0.2)
	elif needs == "code":
		led_col = Color(0.3, 0.95, 0.5)
	elif needs == "power":
		led_col = Color(0.95, 0.15, 0.15)
	_led = W.sphere(self, 0.045, Vector3(0.62, 1.35, 0.12), W.glow(led_col, 2.0))
	if needs != "none":
		W.box(self, Vector3(0.16, 0.24, 0.06), Vector3(0.62, 1.15, 0.12), dark)
		W.box(self, Vector3(0.1, 0.08, 0.02), Vector3(0.62, 1.2, 0.155), W.mat("screen_green" if needs == "code" else "screen_red"))
	# برخورد
	_body = StaticBody3D.new()
	_body.collision_layer = 2
	_body.collision_mask = 0
	add_child(_body)
	var cs = CollisionShape3D.new()
	var sh = BoxShape3D.new()
	sh.size = Vector3(1.0, 2.14, 0.12)
	cs.shape = sh
	cs.position = Vector3(0, 1.09, 0)
	_body.add_child(cs)
	_ring = W.torus(self, 0.42, 0.5, Vector3(0, 0.04, 0), W.glow(Color(1.0, 0.75, 0.3), 1.3))
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false


func set_highlight(on):
	highlight = on


func is_active():
	return not is_open


func prompt():
	if needs == "none":
		return "باز کردن در"
	if needs == "card":
		return "در قفل: کارت دسترسی"
	if needs == "key":
		return "در قفل: کلید"
	if needs == "code":
		return "در قفل: رمز ۴ رقمی"
	return "در برقی: نیاز به برق"


func open_door():
	if is_open:
		return
	is_open = true
	_ring.visible = false
	var shape = _body.get_child(0)
	shape.set_deferred("disabled", true)
	var tw = create_tween()
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(_pivot, "rotation:y", -2.06, 0.52)
	tw.set_trans(Tween.TRANS_SINE)
	tw.tween_property(_pivot, "rotation:y", -1.92, 0.16)
	var led = _led.material_override as StandardMaterial3D
	if led != null:
		led.albedo_color = Color(0.2, 1.0, 0.35)


func _process(delta):
	_t += delta
	if _ring != null:
		_ring.visible = highlight and not is_open
		if highlight:
			var s = 0.95 + 0.08 * sin(_t * 5.0)
			_ring.scale = Vector3(s, 1, s)
	if _led != null and not is_open:
		_led.scale = Vector3.ONE * (1.0 + 0.12 * sin(_t * 3.0 + float(needs.hash() % 10)))
