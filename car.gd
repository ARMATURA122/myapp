extends CharacterBody3D

signal drift_done(points)

static var _livery_cache: ImageTexture = null

var gas := 0.0
var brake_in := 0.0
var steer_in := 0.0
var handbrake := false
var nitro_on := false
var locked := false
var nitro := 100.0
var nitro_max := 100.0
var accel := 20.0
var top := 50.0
var grip := 6.0
var drift_k := 0.5
var steer_rate := 1.9
var speed := 0.0
var drift_score := 0.0
var _drift_t := 0.0
var _length := 4.5
var _body: Node3D
var _spins: Array = []
var _front_pivots: Array = []
var _smoke: CPUParticles3D

func setup(idx: int, lv: Dictionary) -> void:
	var d: Dictionary = Game.cars[idx]
	accel = float(d["accel"]) * (1.0 + 0.10 * float(lv["engine"]))
	top = float(d["top"]) * (1.0 + 0.03 * float(lv["engine"]))
	grip = float(d["grip"]) + 0.4 * float(lv["tires"])
	drift_k = float(d["drift"])
	steer_rate = float(d["steer"])
	nitro_max = 100.0 + 40.0 * float(lv["nitro"])
	nitro = nitro_max
	_length = float(d["length"])
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_build(float(d["width"]), _length, d["color"], str(d["style"]))

static func _livery() -> ImageTexture:
	if _livery_cache != null:
		return _livery_cache
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	var blue := Color(0.07, 0.25, 0.65)
	var white := Color(0.93, 0.94, 0.96)
	for y in 256:
		for x in 256:
			var band := fmod(float(x) * 0.8 + float(y) * 1.4, 150.0)
			var c := white
			if band < 55.0 or y > 205:
				c = blue
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	_livery_cache = ImageTexture.create_from_image(img)
	return _livery_cache

func _box(size: Vector3, pos: Vector3, m: Material, rot_x := 0.0) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees.x = rot_x
	_body.add_child(mi)

func _emit(c: Color, energy := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m

func _build(w: float, l: float, col: Color, style: String) -> void:
	_body = Node3D.new()
	add_child(_body)
	var paint := StandardMaterial3D.new()
	paint.metallic = 0.5
	paint.roughness = 0.25
	paint.clearcoat_enabled = true
	paint.clearcoat = 1.0
	paint.clearcoat_roughness = 0.05
	var accent_col := col.darkened(0.3)
	if style == "gtr":
		paint.albedo_texture = _livery()
		accent_col = Color(0.07, 0.25, 0.65)
	else:
		paint.albedo_color = col
	var accent := StandardMaterial3D.new()
	accent.albedo_color = accent_col
	accent.metallic = 0.5
	accent.roughness = 0.3
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.03, 0.05, 0.08)
	glass.metallic = 0.9
	glass.roughness = 0.05
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.03, 0.03, 0.03)
	dark.roughness = 0.7
	var chrome := StandardMaterial3D.new()
	chrome.albedo_color = Color(0.8, 0.8, 0.85)
	chrome.metallic = 1.0
	chrome.roughness = 0.15
	var head := _emit(Color(1.0, 0.95, 0.8), 1.5)
	var tail := _emit(Color(1.0, 0.05, 0.05), 1.5)

	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(w, 0.9, l)
	cs.shape = bs
	cs.position = Vector3(0, 0.6, 0)
	add_child(cs)

	# кузов
	_box(Vector3(w, 0.52, l), Vector3(0, 0.55, 0), paint)
	_box(Vector3(w * 0.94, 0.10, l * 0.30), Vector3(0, 0.84, -l * 0.30), paint, -4.0)
	_box(Vector3(w * 0.94, 0.10, l * 0.20), Vector3(0, 0.84, l * 0.36), paint, 3.0)
	_box(Vector3(w * 0.84, 0.46, l * 0.40), Vector3(0, 1.04, l * 0.04), glass)
	_box(Vector3(w * 0.82, 0.06, l * 0.30), Vector3(0, 1.29, l * 0.04), paint)
	# капот: воздухозаборники
	for sx in [-1.0, 1.0]:
		_box(Vector3(w * 0.18, 0.03, l * 0.14), Vector3(sx * w * 0.22, 0.90, -l * 0.30), dark)
	# перед
	_box(Vector3(w * 1.02, 0.30, 0.30), Vector3(0, 0.38, -l * 0.5 + 0.1), paint)
	_box(Vector3(w * 0.98, 0.04, 0.45), Vector3(0, 0.22, -l * 0.5), dark)
	_box(Vector3(w * 0.50, 0.14, 0.05), Vector3(0, 0.62, -l * 0.5 - 0.01), dark)
	for sx in [-1.0, 1.0]:
		_box(Vector3(w * 0.12, 0.10, 0.06), Vector3(sx * w * 0.09, 0.62, -l * 0.5 - 0.02), chrome)
		_box(Vector3(w * 0.20, 0.12, 0.06), Vector3(sx * w * 0.36, 0.62, -l * 0.5 - 0.01), head)
	_box(Vector3(w * 0.55, 0.10, 0.05), Vector3(0, 0.38, -l * 0.5 - 0.06), dark)
	# зад
	_box(Vector3(w * 1.02, 0.30, 0.30), Vector3(0, 0.38, l * 0.5 - 0.1), paint)
	for sx in [-1.0, 1.0]:
		_box(Vector3(w * 0.24, 0.10, 0.05), Vector3(sx * w * 0.36, 0.66, l * 0.5 + 0.01), tail)
		_box(Vector3(0.08, 0.12, l * 0.45), Vector3(sx * (w * 0.5 + 0.02), 0.28, 0.0), dark)
		_box(Vector3(0.12, 0.10, 0.18), Vector3(sx * (w * 0.5 + 0.06), 0.98, -l * 0.10), paint)
		for fz in [-1.0, 1.0]:
			_box(Vector3(0.14, 0.32, 1.0), Vector3(sx * (w * 0.5 + 0.04), 0.52, fz * l * 0.31), accent)

	# колёса
	var tire_m := StandardMaterial3D.new()
	tire_m.albedo_color = Color(0.04, 0.04, 0.04)
	tire_m.roughness = 0.9
	var rim_m := StandardMaterial3D.new()
	rim_m.albedo_color = Color(0.75, 0.75, 0.8)
	rim_m.metallic = 1.0
	rim_m.roughness = 0.2
	for sx in [-1.0, 1.0]:
		for fz in [-1.0, 1.0]:
			var pivot := Node3D.new()
			pivot.position = Vector3(sx * (w * 0.5 - 0.02), 0.35, fz * l * 0.31)
			var spin := Node3D.new()
			pivot.add_child(spin)
			var tire := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.35
			cm.bottom_radius = 0.35
			cm.height = 0.26
			cm.radial_segments = 20
			cm.rings = 1
			tire.mesh = cm
			tire.material_override = tire_m
			tire.rotation_degrees = Vector3(0, 0, 90)
			spin.add_child(tire)
			var rim := MeshInstance3D.new()
			var rm := CylinderMesh.new()
			rm.top_radius = 0.24
			rm.bottom_radius = 0.24
			rm.height = 0.28
			rm.radial_segments = 12
			rm.rings = 1
			rim.mesh = rm
			rim.material_override = rim_m
			rim.rotation_degrees = Vector3(0, 0, 90)
			spin.add_child(rim)
			for k in 2:
				var sp := MeshInstance3D.new()
				var sb := BoxMesh.new()
				sb.size = Vector3(0.02, 0.44, 0.06) if k == 0 else Vector3(0.02, 0.06, 0.44)
				sp.mesh = sb
				sp.material_override = dark
				sp.position = Vector3(sx * 0.145, 0, 0)
				spin.add_child(sp)
			add_child(pivot)
			_spins.append(spin)
			if fz < 0.0:
				_front_pivots.append(pivot)

	# дым при заносе
	_smoke = CPUParticles3D.new()
	_smoke.position = Vector3(0, 0.3, l * 0.5)
	_smoke.amount = 30
	_smoke.lifetime = 0.9
	_smoke.local_coords = false
	_smoke.emitting = false
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 6
	sm.rings = 3
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color(1, 1, 1, 1)
	mt.vertex_color_use_as_albedo = true
	mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_smoke.mesh = sm
	_smoke.material_override = mt
	var g := Gradient.new()
	g.set_color(0, Color(0.9, 0.9, 0.9, 0.55))
	g.set_color(1, Color(0.9, 0.9, 0.9, 0.0))
	_smoke.color_ramp = g
	_smoke.direction = Vector3(0, 1, 0)
	_smoke.spread = 40.0
	_smoke.initial_velocity_min = 1.0
	_smoke.initial_velocity_max = 2.5
	_smoke.gravity = Vector3(0, 0.5, 0)
	_smoke.scale_amount_min = 0.6
	_smoke.scale_amount_max = 1.4
	add_child(_smoke)

func _physics_process(delta: float) -> void:
	if locked:
		velocity = Vector3.ZERO
		return
	var fwd: Vector3 = -global_transform.basis.z
	var v := Vector3(velocity.x, 0.0, velocity.z)
	var vf: float = v.dot(fwd)

	# руление: положительный steer_in = налево
	var sp_k := clampf(absf(vf) / 8.0, 0.0, 1.0)
	var hi_k := 1.0 - clampf(absf(vf) / (top * 1.3), 0.0, 0.6)
	var rate := steer_rate * sp_k * hi_k
	if handbrake:
		rate *= 1.5
	var dir_sign := 1.0 if vf > -0.5 else -1.0
	rotate_y(steer_in * rate * dir_sign * delta)

	fwd = -global_transform.basis.z
	var right: Vector3 = global_transform.basis.x
	vf = v.dot(fwd)
	var vl: float = v.dot(right)

	# газ, нитро, тормоз
	var using_nitro := nitro_on and nitro > 0.0 and gas > 0.0
	var lim := top * (1.25 if using_nitro else 1.0)
	if using_nitro:
		nitro = maxf(0.0, nitro - 30.0 * delta)
	else:
		nitro = minf(nitro_max, nitro + 5.0 * delta)
	if gas > 0.0:
		var a := accel * (1.8 if using_nitro else 1.0)
		var fade := clampf(1.0 - pow(maxf(vf, 0.0) / lim, 3.0), 0.0, 1.0)
		vf += a * gas * fade * delta
	if brake_in > 0.0:
		if vf > 0.5:
			vf = maxf(0.0, vf - 38.0 * brake_in * delta)
		else:
			vf = maxf(vf - accel * 0.6 * brake_in * delta, -top * 0.3)
	if gas == 0.0 and brake_in == 0.0:
		vf = move_toward(vf, 0.0, 4.0 * delta)
	vf -= vf * 0.04 * delta

	# боковое сцепление / занос
	var g := grip
	if handbrake and absf(vf) > 6.0:
		g = 0.9
		vf -= vf * 0.35 * delta
	elif absf(steer_in) > 0.8 and absf(vf) > 28.0:
		g = grip * drift_k
	vl *= exp(-g * delta)

	velocity = fwd * vf + right * vl
	var before := Vector3(v.x, 0.0, v.z).length()
	move_and_slide()
	global_position.y = 0.0
	var after := Vector3(velocity.x, 0.0, velocity.z).length()
	if before > 10.0 and after < before * 0.5:
		velocity *= 0.7
	speed = velocity.dot(-global_transform.basis.z)

	# очки дрифта
	var slipping: bool = absf(vl) > 3.0 and absf(vf) > 8.0
	_smoke.emitting = slipping
	if slipping:
		drift_score += absf(vl) * absf(vf) * 0.05 * delta
		_drift_t = 0.7
	else:
		_drift_t -= delta
		if _drift_t <= 0.0 and drift_score > 0.0:
			drift_done.emit(drift_score)
			drift_score = 0.0

	# визуальные эффекты: крен, наклон, колёса
	_body.rotation.z = lerpf(_body.rotation.z, clampf(-steer_in * vf * 0.0012, -0.08, 0.08), clampf(delta * 6.0, 0.0, 1.0))
	var pitch := gas * 0.02 - (brake_in * 0.03 if vf > 2.0 else 0.0)
	_body.rotation.x = lerpf(_body.rotation.x, pitch, clampf(delta * 5.0, 0.0, 1.0))
	for s in _spins:
		s.rotation.x -= speed * delta / 0.35
	for p in _front_pivots:
		p.rotation.y = lerpf(p.rotation.y, steer_in * 0.45, clampf(delta * 10.0, 0.0, 1.0))
