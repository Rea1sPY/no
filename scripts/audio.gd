extends Node
## صدای بازی: همه‌ی صداها هنگام اجرا با کد ساخته می‌شوند (بدون فایل صوتی). موسیقی و جلوه‌ها جداگانه قابل قطع‌اند.

const RATE = 11025
const TAU2 = 6.2831853

var streams = {}
var sfx_players = []
var _next = 0
var drone = null
var tension_p = null
var _tension = 0.0


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	for i in 8:
		var p = AudioStreamPlayer.new()
		add_child(p)
		sfx_players.append(p)
	drone = AudioStreamPlayer.new()
	drone.stream = streams["drone"]
	add_child(drone)
	tension_p = AudioStreamPlayer.new()
	tension_p.stream = streams["tension"]
	add_child(tension_p)
	Global.settings_changed.connect(apply_settings)
	apply_settings()


func _db(v):
	if v <= 0.001:
		return -80.0
	return linear_to_db(v)


func apply_settings():
	var m = Global.settings["music"]
	if Global.settings["mute_music"]:
		m = 0.0
	drone.volume_db = _db(m) - 8.0
	set_tension(_tension)


func start_music():
	if not drone.playing:
		drone.play()
	if not tension_p.playing:
		tension_p.play()


func stop_music():
	drone.stop()
	tension_p.stop()


func set_tension(t):
	_tension = clampf(t, 0.0, 1.0)
	var m = Global.settings["music"]
	if Global.settings["mute_music"]:
		m = 0.0
	tension_p.volume_db = _db(m) + lerpf(-60.0, -14.0, _tension)
	tension_p.pitch_scale = 1.0 + 0.2 * _tension
	drone.pitch_scale = 1.0 - 0.06 * _tension


func sfx(sound_name, db = 0.0, pitch = 1.0):
	if Global.settings["mute_sfx"] or not streams.has(sound_name):
		return
	var p = sfx_players[_next]
	_next = (_next + 1) % sfx_players.size()
	p.stream = streams[sound_name]
	p.volume_db = db + _db(Global.settings["sfx"])
	p.pitch_scale = pitch
	p.play()


# ---------- ساخت صداها ----------
func _wav(samples, loop = false):
	var n = samples.size()
	var bytes = PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var v = clampf(samples[i], -1.0, 1.0)
		bytes.encode_s16(i * 2, int(v * 30000.0))
	var w = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = n
	return w


func _buf(seconds):
	var s = PackedFloat32Array()
	s.resize(int(RATE * seconds))
	return s


func _noise():
	return randf() * 2.0 - 1.0


func _build():
	streams["step"] = _wav(_make_step())
	streams["door"] = _wav(_make_door())
	streams["pickup"] = _wav(_make_pickup())
	streams["click"] = _wav(_make_tone(0.05, 700.0, 0.5, 20.0))
	streams["error"] = _wav(_make_buzz(0.3, 140.0))
	streams["success"] = _wav(_make_success())
	streams["alarm"] = _wav(_make_buzz(0.22, 880.0))
	streams["heart"] = _wav(_make_heart())
	streams["whisper"] = _wav(_make_whisper())
	streams["scare"] = _wav(_make_scare())
	streams["rewind"] = _wav(_make_rewind())
	streams["lever"] = _wav(_make_tone(0.12, 220.0, 0.8, 14.0))
	streams["drone"] = _wav(_make_drone(), true)
	streams["tension"] = _wav(_make_tension(), true)
	streams["drip"] = _wav(_make_drip())
	streams["creak"] = _wav(_make_creak())
	streams["clang"] = _wav(_make_clang())


func _make_drip():
	var s = _buf(0.5)
	var n = s.size()
	for i in n:
		var t = float(i) / RATE
		var f = lerpf(1400.0, 420.0, minf(1.0, t * 3.0))
		s[i] = sin(TAU2 * f * t) * exp(-t * 12.0) * 0.5
	return s


func _make_creak():
	var s = _buf(1.6)
	var n = s.size()
	var phase = 0.0
	var lp = 0.0
	for i in n:
		var t = float(i) / n
		var f = 180.0 + sin(t * 9.0) * 70.0 + t * 120.0
		phase += f / RATE
		var saw = fmod(phase, 1.0) * 2.0 - 1.0
		lp = lp * 0.72 + _noise() * 0.28
		var env = sin(PI * t) * (0.6 + 0.4 * sin(t * 40.0))
		s[i] = (saw * 0.18 + lp * 0.10) * env
	return s


func _make_clang():
	var s = _buf(1.8)
	var n = s.size()
	for i in n:
		var t = float(i) / RATE
		var v = sin(TAU2 * 320.0 * t) * 0.3 + sin(TAU2 * 487.0 * t) * 0.2 + sin(TAU2 * 731.0 * t) * 0.14
		s[i] = v * exp(-t * 3.0)
	return s


func _make_step():
	var s = _buf(0.09)
	var n = s.size()
	var lp = 0.0
	for i in n:
		var t = float(i) / RATE
		lp = lp * 0.7 + _noise() * 0.3
		var env = exp(-float(i) / (n * 0.25))
		s[i] = (lp * 1.2 + sin(TAU2 * 80.0 * t) * 0.5) * env
	return s


func _make_door():
	var s = _buf(0.6)
	var n = s.size()
	var phase = 0.0
	for i in n:
		var t = float(i) / n
		var f = lerpf(95.0, 55.0, t)
		phase += f / RATE
		var saw = (fmod(phase, 1.0) * 2.0 - 1.0)
		var env = sin(PI * t)
		s[i] = (saw * 0.35 + _noise() * 0.08) * env
	return s


func _make_pickup():
	var s = _buf(0.22)
	var n = s.size()
	for i in n:
		var t = float(i) / RATE
		var f = 660.0
		if t > 0.1:
			f = 990.0
		var env = exp(-fmod(t, 0.1) * 18.0)
		s[i] = sin(TAU2 * f * t) * env * 0.5
	return s


func _make_tone(seconds, freq, amp, decay):
	var s = _buf(seconds)
	for i in s.size():
		var t = float(i) / RATE
		s[i] = sin(TAU2 * freq * t) * amp * exp(-t * decay)
	return s


func _make_buzz(seconds, freq):
	var s = _buf(seconds)
	var n = s.size()
	for i in n:
		var t = float(i) / RATE
		var sq = 1.0
		if fmod(t * freq, 1.0) > 0.5:
			sq = -1.0
		var env = 1.0 - float(i) / n
		s[i] = sq * 0.3 * env
	return s


func _make_success():
	var s = _buf(0.5)
	var notes = [523.0, 659.0, 784.0]
	for i in s.size():
		var t = float(i) / RATE
		var k = int(t / 0.15)
		if k > 2:
			k = 2
		var lt = t - k * 0.15
		s[i] = sin(TAU2 * notes[k] * t) * exp(-lt * 6.0) * 0.45
	return s


func _make_heart():
	var s = _buf(0.9)
	for i in s.size():
		var t = float(i) / RATE
		var v = sin(TAU2 * 55.0 * t) * exp(-t * 16.0) * 0.9
		if t > 0.28:
			var t2 = t - 0.28
			v += sin(TAU2 * 48.0 * t2) * exp(-t2 * 20.0) * 0.7
		s[i] = v
	return s


func _make_whisper():
	var s = _buf(1.4)
	var n = s.size()
	var lp = 0.0
	for i in n:
		var t = float(i) / n
		lp = lp * 0.82 + _noise() * 0.18
		s[i] = lp * sin(PI * t) * 0.9
	return s


func _make_scare():
	var s = _buf(1.0)
	var n = s.size()
	var phase = 0.0
	for i in n:
		var t = float(i) / RATE
		phase += lerpf(220.0, 70.0, float(i) / n) / RATE
		var saw = fmod(phase, 1.0) * 2.0 - 1.0
		var env = exp(-t * 2.5)
		s[i] = (_noise() * 0.6 + saw * 0.6) * env
	return s


func _make_rewind():
	var s = _buf(1.2)
	var n = s.size()
	var phase = 0.0
	for i in n:
		var t = float(i) / n
		phase += lerpf(1800.0, 150.0, t) / RATE
		var trem = 0.6 + 0.4 * sin(TAU2 * 18.0 * t)
		s[i] = (sin(TAU2 * phase) * 0.35 + _noise() * 0.12) * trem * sin(PI * t)
	return s


func _make_drone():
	var s = _buf(4.0)
	for i in s.size():
		var t = float(i) / RATE
		var trem = 1.0 + 0.25 * sin(TAU2 * 0.5 * t)
		var v = sin(TAU2 * 55.0 * t) * 0.35 + sin(TAU2 * 82.5 * t) * 0.22 + sin(TAU2 * 110.0 * t + 0.5) * 0.12
		s[i] = (v * trem + _noise() * 0.015) * 0.8
	return s


func _make_tension():
	var s = _buf(2.0)
	for i in s.size():
		var t = float(i) / RATE
		var trem = 0.7 + 0.3 * sin(TAU2 * 2.0 * t)
		s[i] = (sin(TAU2 * 440.0 * t) * 0.14 + sin(TAU2 * 466.0 * t) * 0.14 + sin(TAU2 * 220.0 * t) * 0.1) * trem
	return s
