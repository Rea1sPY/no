extends Node
## نقطه‌ی شروع: تم سراسری، صفحه‌ی بارگذاری، سوئیچ بین منو و بازی با محو شدن، دکمه‌ی بازگشت اندروید.

const UI = preload("res://scripts/ui.gd")
const MenuScript = preload("res://scripts/main_menu.gd")
const GameScript = preload("res://scripts/game3d.gd")
const LoadingScript = preload("res://scripts/loading.gd")

var menu = null
var game = null
var loading = null
var veil = null


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().theme = UI.make_theme()
	get_tree().set_auto_accept_quit(false)
	_make_veil()
	_show_loading()


func _make_veil():
	## پرده‌ی مشکی روی همه‌چیز برای محو شدن نرم بین صفحه‌ها.
	var layer = CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	veil = ColorRect.new()
	veil.color = Color(0, 0, 0, 0)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.full_rect(veil)
	layer.add_child(veil)


func _transition(cb):
	## محو به سیاه، اجرای تغییر، محو به تصویر.
	if veil == null:
		cb.call()
		return
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw = create_tween()
	tw.tween_property(veil, "color:a", 1.0, 0.22)
	tw.tween_callback(cb)
	tw.tween_property(veil, "color:a", 0.0, 0.32)
	tw.tween_callback(_release_veil)


func _release_veil():
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _show_loading():
	loading = LoadingScript.new()
	add_child(loading)
	loading.finished.connect(_on_loaded)


func _on_loaded():
	loading = null
	_show_menu()


func _show_menu():
	if game != null:
		game.queue_free()
		game = null
	get_tree().paused = false
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu = MenuScript.new()
	add_child(menu)
	menu.start_game.connect(_start_game)


func _start_game():
	_transition(_start_game_now)


func _start_game_now():
	if menu != null:
		menu.queue_free()
		menu = null
	game = GameScript.new()
	game.exit_requested.connect(_back_to_menu)
	add_child(game)


func _back_to_menu():
	if game == null:
		return
	_transition(_show_menu)


func _notification(what):
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if loading != null:
			loading.skip()
		elif game != null:
			game.on_back()
		else:
			get_tree().quit()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		Global.save_game()
		get_tree().quit()
