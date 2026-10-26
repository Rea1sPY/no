extends StaticBody2D
## در: بسته بودنش مانع بازیکن است (لایه‌ی ۲). دشمن از در عبور می‌کند ولی دیدش با در بسته قطع می‌شود.

var kind = "door"
var id = ""
var needs = "none"
var info = {}
var is_open = false
var unlocked = false
var highlight = false
var shape_node = null


func setup(d):
	id = d["id"]
	needs = d["needs"]
	info = d
	position = Vector2(d["cell"][0] * 32 + 16, d["cell"][1] * 32 + 16)
	collision_layer = 2
	collision_mask = 0
	shape_node = CollisionShape2D.new()
	var r = RectangleShape2D.new()
	r.size = Vector2(32, 32)
	shape_node.shape = r
	add_child(shape_node)
	add_to_group("interactables")
	z_index = 1
	queue_redraw()


func set_highlight(on):
	highlight = on
	queue_redraw()


func is_active():
	return not is_open


func open_door():
	is_open = true
	shape_node.set_deferred("disabled", true)
	queue_redraw()


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


func _draw():
	if is_open:
		draw_rect(Rect2(-16, -16, 5, 32), Color(0.16, 0.15, 0.17))
		return
	draw_rect(Rect2(-16, -16, 32, 32), Color(0.20, 0.18, 0.21))
	draw_rect(Rect2(-14, -14, 28, 28), Color(0.13, 0.12, 0.14))
	var led = Color(0.2, 0.9, 0.3)
	if needs == "card":
		led = Color(0.2, 0.7, 0.95)
	elif needs == "key":
		led = Color(0.95, 0.8, 0.2)
	elif needs == "code":
		led = Color(0.3, 0.95, 0.5)
	elif needs == "power":
		led = Color(0.95, 0.15, 0.15)
	if needs != "none":
		draw_circle(Vector2(0, 0), 4.0, led)
	if highlight:
		draw_rect(Rect2(-16, -16, 32, 32), Color(1, 0.85, 0.5, 0.9), false, 2.0)
