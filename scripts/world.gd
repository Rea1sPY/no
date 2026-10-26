extends RefCounted
## ابزار مشترک دنیای سه‌بعدی: اندازه‌ها، بافت‌های باکیفیت، متریال‌ها، ساخت مش و
## دسته‌بندی مش‌های تکراری در MultiMesh برای کم شدن تعداد draw call.
## بافت‌ها از پوشه‌ی textures/ خوانده می‌شوند؛ اگر نبودند نسخه‌ی رویه‌ای ساخته می‌شود.

const CELL = 1.0
const WALL_H = 2.8
const EYE = 1.62
const WALL_HALF = 0.5
const TEX_DIR = "res://textures/"

static var _mats = {}
static var _tex = {}
static var _nrm = {}
static var _box = null
static var _cyl = null


# ---------- بافت‌های رویه‌ای ----------
static func tex(name):
	if _tex.has(name):
		return _tex[name]
	var path = TEX_DIR + name + ".png"
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			_tex[name] = res
			return res
	# نسخه‌ی رویه‌ایِ ۱۲۸ پیکسلی، فقط پشتیبان.
	var kind = name
	match name:
		"concrete_wall", "ceiling_panel":
			kind = "concrete"
		"tile_floor":
			kind = "tile"
		"metal_panel":
			kind = "metal"
		"rust_metal":
			kind = "rust"
		"wood_planks":
			kind = "wood"
	var img = Image.create(128, 128, false, Image.FORMAT_RGB8)
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(name)
	for y in 128:
		for x in 128:
			var v = 0.5
			if kind == "concrete":
				v = 0.62 + rng.randf() * 0.16
				if rng.randf() < 0.018:
					v -= 0.28
				elif rng.randf() < 0.012:
					v += 0.18
			elif kind == "tile":
				var tx = x % 32
				var ty = y % 32
				v = 0.55 + rng.randf() * 0.12
				if tx < 2 or ty < 2:
					v *= 0.55
				elif tx < 4 or ty < 4:
					v *= 0.8
				if rng.randf() < 0.01:
					v *= 0.7
			elif kind == "wood":
				var grain = sin(float(y) * 0.7 + sin(float(x) * 0.16) * 3.0) * 0.06
				v = 0.42 + grain + rng.randf() * 0.10
				if x % 41 < 2:
					v *= 0.6
			elif kind == "metal":
				v = 0.52 + rng.randf() * 0.08
				if y % 7 < 2:
					v += 0.05
				if rng.randf() < 0.006:
					v -= 0.2
			elif kind == "rust":
				v = 0.34 + rng.randf() * 0.22
				if rng.randf() < 0.04:
					v *= 0.55
			img.set_pixel(x, y, Color(v, v, v))
	_tex[name] = ImageTexture.create_from_image(img)
	return _tex[name]


static func normal_tex(name):
	if _nrm.has(name):
		return _nrm[name]
	var path = TEX_DIR + name + "_n.png"
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			_nrm[name] = res
			return res
	_nrm[name] = null
	return null


static func _set_tex(m, name, scale = 0.55, bump = 1.0):
	m.albedo_texture = tex(name)
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(scale, scale, scale)
	m.uv1_triplanar_sharpness = 2.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var n = normal_tex(name)
	if n != null:
		m.normal_enabled = true
		m.normal_texture = n
		m.normal_scale = bump


# ---------- متریال‌ها ----------
static func mat(kind):
	if _mats.has(kind):
		return _mats[kind]
	var m = StandardMaterial3D.new()
	match kind:
		"wall":
			_set_tex(m, "concrete_wall", 0.42, 1.15)
			m.albedo_color = Color(0.78, 0.77, 0.82)
			m.roughness = 0.96
			m.vertex_color_use_as_albedo = true
		"wall_mold":
			_set_tex(m, "concrete_wall", 0.55, 1.15)
			m.albedo_color = Color(0.52, 0.58, 0.5)
			m.roughness = 1.0
		"wall_b":
			_set_tex(m, "concrete_wall_b", 0.45, 1.2)
			m.albedo_color = Color(0.82, 0.85, 0.78)
			m.roughness = 0.98
		"floor_b":
			_set_tex(m, "tile_floor_b", 0.42, 1.2)
			m.albedo_color = Color(1, 1, 1)
			m.roughness = 0.7
		"door":
			_set_tex(m, "metal_door", 0.62, 1.4)
			m.albedo_color = Color(0.9, 0.9, 0.9)
			m.metallic = 0.48
			m.roughness = 0.5
		"vent":
			_set_tex(m, "vent_grate", 0.9, 0.8)
			m.albedo_color = Color(0.7, 0.72, 0.75)
			m.metallic = 0.35
			m.roughness = 0.6
		"floor":
			_set_tex(m, "tile_floor", 0.45, 1.2)
			m.albedo_color = Color(1, 1, 1)
			m.roughness = 0.72
			m.vertex_color_use_as_albedo = true
		"ceiling":
			_set_tex(m, "ceiling_panel", 0.55, 0.9)
			m.albedo_color = Color(0.42, 0.41, 0.46)
			m.roughness = 1.0
		"dark":
			m.albedo_color = Color(0.06, 0.055, 0.07)
			m.roughness = 0.95
		"metal":
			_set_tex(m, "metal_panel", 0.55, 0.9)
			m.albedo_color = Color(0.72, 0.76, 0.8)
			m.metallic = 0.62
			m.roughness = 0.42
		"metal_dark":
			_set_tex(m, "metal_panel", 0.8, 0.9)
			m.albedo_color = Color(0.34, 0.35, 0.38)
			m.metallic = 0.55
			m.roughness = 0.55
		"rust":
			_set_tex(m, "rust_metal", 0.7, 1.2)
			m.albedo_color = Color(0.95, 0.86, 0.8)
			m.roughness = 0.9
			m.metallic = 0.2
		"wood":
			_set_tex(m, "wood_planks", 0.6, 1.0)
			m.albedo_color = Color(0.92, 0.86, 0.8)
			m.roughness = 0.88
		"bed":
			m.albedo_color = Color(0.28, 0.33, 0.45)
			m.roughness = 1.0
		"cloth":
			m.albedo_color = Color(0.30, 0.27, 0.29)
			m.roughness = 1.0
		"rubber":
			m.albedo_color = Color(0.09, 0.09, 0.1)
			m.roughness = 0.95
		"blood":
			m.albedo_color = Color(0.16, 0.015, 0.02)
			m.roughness = 0.55
			m.metallic = 0.1
		"paper":
			_set_tex(m, "paper_old", 1.4, 0.35)
			m.albedo_color = Color(1, 1, 1)
			m.roughness = 1.0
		"poster_a":
			m.albedo_texture = tex("poster_warning")
			m.albedo_color = Color(0.85, 0.83, 0.8)
			m.roughness = 0.95
		"poster_b":
			m.albedo_texture = tex("poster_notice")
			m.albedo_color = Color(0.85, 0.83, 0.8)
			m.roughness = 0.95
		"poster_terminal":
			m.albedo_texture = tex("poster_terminal")
			m.albedo_color = Color(0.85, 0.83, 0.8)
			m.roughness = 0.95
		"poster_blood":
			m.albedo_texture = tex("poster_blood")
			m.albedo_color = Color(0.85, 0.83, 0.8)
			m.roughness = 0.95
		"concrete":
			_set_tex(m, "concrete_wall", 0.6, 1.15)
			m.albedo_color = Color(0.8, 0.8, 0.84)
			m.roughness = 0.98
		"screen_green":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(0.16, 0.95, 0.42)
		"screen_red":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(1.0, 0.16, 0.18)
		"screen_violet":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(0.62, 0.28, 1.0)
		"glass":
			m.albedo_color = Color(0.35, 0.55, 0.62, 0.35)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.15
			m.metallic = 0.3
		_:
			m.albedo_color = Color(0.5, 0.5, 0.5)
	_mats[kind] = m
	return m


static func floor_mat(hex, alt = false):
	var key = "floor_" + hex + ("_b" if alt else "")
	if _mats.has(key):
		return _mats[key]
	var m = StandardMaterial3D.new()
	_set_tex(m, "tile_floor_b" if alt else "tile_floor", 0.45, 1.2)
	m.albedo_color = Color.html(hex).lightened(0.55 if not alt else 0.85)
	m.roughness = 0.72
	_mats[key] = m
	return m


static func blood_mat():
	if _mats.has("blood_decal"):
		return _mats["blood_decal"]
	var m = StandardMaterial3D.new()
	m.albedo_texture = tex("blood_decal")
	m.albedo_color = Color(1, 1, 1, 1)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.35
	m.metallic = 0.15
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	_mats["blood_decal"] = m
	return m


static func puddle_mat():
	if _mats.has("puddle"):
		return _mats["puddle"]
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(0.05, 0.055, 0.07, 0.72)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.06
	m.metallic = 0.85
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	_mats["puddle"] = m
	return m


static func glow(color, energy = 2.0):
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


static func beam_mat(color):
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.disable_receive_shadows = true
	m.vertex_color_use_as_albedo = false
	return m


# ---------- دسته‌بندی هندسه‌ی تکراری ----------
static func xf(pos, size, rot = Vector3.ZERO):
	return Transform3D(Basis.from_euler(rot) * Basis.from_scale(size), pos)


static func batch(parent, material, transforms, cyl = false, far = 0.0):
	## صدها جعبه/استوانه با یک draw call. برای قرنیز، لوله، آجر و زباله.
	if transforms.is_empty():
		return null
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = unit_cyl() if cyl else unit_box()
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if far > 0.0:
		mmi.visibility_range_end = far
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	parent.add_child(mmi)
	return mmi


static func vis(mi, far = 22.0):
	mi.visibility_range_end = far
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return mi


static func decal(parent, tex_name, size, pos, rot = Vector3(-PI * 0.5, 0, 0), color = Color(1, 1, 1, 1)):
	var m = StandardMaterial3D.new()
	m.albedo_texture = tex(tex_name)
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	var mi = quad(parent, size, pos, m, rot)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# ---------- مش‌های مشترک ----------
static func unit_box():
	if _box == null:
		_box = BoxMesh.new()
		_box.size = Vector3.ONE
	return _box


static func unit_cyl():
	if _cyl == null:
		_cyl = CylinderMesh.new()
		_cyl.top_radius = 0.5
		_cyl.bottom_radius = 0.5
		_cyl.height = 1.0
		_cyl.radial_segments = 12
		_cyl.rings = 1
	return _cyl


static func box(parent, size, pos, material, rot = Vector3.ZERO):
	var mi = MeshInstance3D.new()
	mi.mesh = unit_box()
	mi.material_override = material
	mi.scale = size
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func cyl(parent, radius, height, pos, material, rot = Vector3.ZERO):
	var mi = MeshInstance3D.new()
	mi.mesh = unit_cyl()
	mi.material_override = material
	mi.scale = Vector3(radius * 2.0, height, radius * 2.0)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func sphere(parent, radius, pos, material):
	var mi = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = material
	mi.scale = Vector3.ONE * radius
	mi.position = pos
	parent.add_child(mi)
	return mi


static func torus(parent, inner, outer, pos, material, rot = Vector3.ZERO):
	var mi = MeshInstance3D.new()
	var tm = TorusMesh.new()
	tm.inner_radius = inner
	tm.outer_radius = outer
	tm.rings = 24
	tm.ring_segments = 8
	mi.mesh = tm
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func quad(parent, size, pos, material, rot = Vector3.ZERO):
	var mi = MeshInstance3D.new()
	var qm = QuadMesh.new()
	qm.size = size
	mi.mesh = qm
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func label(parent, text, pos, pixel = 0.004, color = Color(0.9, 0.86, 0.78), rot = Vector3.ZERO, size = 48):
	var l = Label3D.new()
	l.text = text
	l.font = Global.get_font()
	l.font_size = size
	l.pixel_size = pixel
	l.modulate = color
	l.outline_size = 8
	l.outline_modulate = Color(0, 0, 0, 0.92)
	l.double_sided = true
	l.position = pos
	l.rotation = rot
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	parent.add_child(l)
	return l


static func sprite_glow(parent, color, scale = 0.55):
	var s = Sprite3D.new()
	s.texture = Global.light_tex()
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.modulate = color
	s.pixel_size = 0.01
	s.scale = Vector3.ONE * (scale / 1.28)
	s.no_depth_test = false
	parent.add_child(s)
	return s


static func disable_shadow(mi):
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
