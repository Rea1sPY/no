extends CanvasLayer
## افکت‌های تصویری: حاشیه‌ی تاریک/قرمز خطر، گلیچ بازگشت زمان، فلاش، محو شدن و جامپ‌اسکر.

const UI = preload("res://scripts/ui.gd")
const ScareScript = preload("res://scripts/scare.gd")

const VIGNETTE = """
shader_type canvas_item;
uniform float danger = 0.0;
uniform float strength = 0.55;
void fragment() {
	vec2 p = UV - 0.5;
	float v = smoothstep(0.28, 0.85, length(p) * 1.3);
	vec3 c = mix(vec3(0.0), vec3(0.55, 0.0, 0.02), danger);
	COLOR = vec4(c, v * (strength + danger * 0.35));
}
"""

const POST = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float glitch = 0.0;
uniform float t = 0.0;
float rnd(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}
void fragment() {
	vec2 uv = SCREEN_UV;
	float band = floor(uv.y * 24.0 + t * 30.0);
	float r = rnd(vec2(band, floor(t * 20.0)));
	if (r < glitch * 0.5) {
		uv.x += (rnd(vec2(band, t)) - 0.5) * 0.15 * glitch;
	}
	vec4 base = texture(screen_tex, uv);
	vec4 rc = texture(screen_tex, uv + vec2(0.012 * glitch, 0.0));
	vec4 bc = texture(screen_tex, uv - vec2(0.012 * glitch, 0.0));
	vec3 col = vec3(rc.r, base.g, bc.b);
	col *= 0.9 + 0.1 * sin(SCREEN_UV.y * 900.0);
	COLOR = vec4(col, 1.0);
}
"""

var vig = null
var post = null
var flash_rect = null
var fade_rect = null
var scare = null
var danger = 0.0
var _danger_shown = 0.0
var _glitch = 0.0
var _glitch_len = 0.0
var _glitch_peak = 0.0
var _t = 0.0


func _ready():
	layer = 1
	process_mode = Node.PROCESS_MODE_ALWAYS
	vig = ColorRect.new()
	UI.full_rect(vig)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vig.color = Color(1, 1, 1, 1)
	vig.material = _mat(VIGNETTE)
	add_child(vig)
	post = ColorRect.new()
	UI.full_rect(post)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post.color = Color(1, 1, 1, 1)
	post.material = _mat(POST)
	post.visible = false
	add_child(post)
	flash_rect = ColorRect.new()
	UI.full_rect(flash_rect)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color(1, 0, 0, 0)
	add_child(flash_rect)
	scare = ScareScript.new()
	UI.full_rect(scare)
	scare.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scare.visible = false
	add_child(scare)
	fade_rect = ColorRect.new()
	UI.full_rect(fade_rect)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.color = Color(0, 0, 0, 1)
	add_child(fade_rect)


func _mat(code):
	var sh = Shader.new()
	sh.code = code
	var m = ShaderMaterial.new()
	m.shader = sh
	return m


func set_concealed(_v):
	## پرده‌ی شکاف‌دار کمد در HUD کشیده می‌شود؛ اینجا فقط نگه می‌داریم.
	pass


func set_danger(v):
	danger = clampf(v, 0.0, 1.0)


func flash(color, dur):
	flash_rect.color = color
	var tw = create_tween()
	tw.tween_property(flash_rect, "color:a", 0.0, dur)


func fade_to(alpha, dur):
	var tw = create_tween()
	tw.tween_property(fade_rect, "color:a", alpha, dur)


func glitch(dur, strength):
	_glitch_len = dur
	_glitch = dur
	_glitch_peak = strength


func jumpscare():
	scare.visible = true
	await get_tree().create_timer(1.1).timeout
	scare.visible = false


func _process(delta):
	_t += delta
	_danger_shown = lerpf(_danger_shown, danger, minf(1.0, delta * 4.0))
	var pulse = 0.0
	if _danger_shown > 0.1:
		pulse = (0.5 + 0.5 * sin(_t * (3.0 + 6.0 * _danger_shown))) * 0.25 * _danger_shown
	vig.material.set_shader_parameter("danger", clampf(_danger_shown + pulse, 0.0, 1.0))
	if _glitch > 0.0:
		_glitch -= delta
		var amt = _glitch_peak * clampf(_glitch / maxf(0.01, _glitch_len), 0.0, 1.0)
		if Global.settings["fx_high"]:
			post.visible = true
			post.material.set_shader_parameter("glitch", amt)
			post.material.set_shader_parameter("t", _t)
		else:
			flash_rect.color = Color(0.4, 0.0, 0.1, 0.25 * amt)
	elif post.visible:
		post.visible = false
