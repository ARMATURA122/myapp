extends VehicleBody3D

var gas := 0.0
var brake_in := 0.0
var steer_in := 0.0
var handbrake := false
var nitro_on := false
var locked := false
var nitro := 100.0
var nitro_max := 100.0
var power := 40.0
var top := 40.0
var grip := 4.5
var drift_k := 0.7
var limit_mult := 1.0
var lane := 0.0
var speed := 0.0
var drift_score := 0.0
var drift_bank := 0.0
var _drift_t := 0.0
var _flip_t := 0.0
var _rear_mult := 1.0
var _rear: Array = []

func setup(idx: int, lv: Dictionary, ai := false, tint := Color(0, 0, 0, 0)) -> void:
	var d: Dictionary = Game.cars[idx]
	mass = d["mass"]
	power = d["power"] * (1.0 + 0.10 * lv["engine"])
	top = d["top"] * (1.0 + 0.03 * lv["engine"])
	grip = d["grip"] + 0.4 * lv["tires"]
	drift_k = d["drift"]
	nitro_max = 100.0 + 40.0 * lv["nitro"]
	nitro = nitro_max
	linear_damp = 0.05
	angular_damp = 0.8
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.3, 0)
	var col: Color = d["color"]
	if tint.a > 0.0:
		col = tint
	_build(d["width"], d["length"], col, ai)

func _box(size: Vector3, pos: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	add_child(mi)

func _emit(c: Color, energy := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m

func _build(w: float, l: float, col: Color, ai: bool) -> void:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = col
	paint.metallic = 0.7
	paint.roughness = 0.25
	paint.clearcoat_enabled = true
	paint.clearcoat = 1.0
	paint.clearcoat_roughness = 0.05
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.03, 0.05, 0.08)
	glass.metallic = 0.9
	glass.roughness = 0.05
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.03, 0.03, 0.03)
	var head := _emit(Color(1.0, 0.95, 0.8), 3.0)
	var tail := _emit(Color(1.0, 0.05, 0.05), 3.0)

	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(w, 0.6, l)
	cs.shape = bs
	cs.position = Vector3(0, 0.5, 0)
	add_child(cs)

	_box(Vector3(w, 0.45, l), Vector3(0, 0.45, 0), paint)
	_box(Vector3(w * 0.84, 0.42, l * 0.46), Vector3(0, 0.88, l * 0.06), glass)
	_box(Vector3(w * 0.80, 0.05, l * 0.40), Vector3(0, 1.10, l * 0.06), paint)
	_box(Vector3(w, 0.07, 0.4), Vector3(0, 1.0, l * 0.5 - 0.1), paint)
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.08, 0.3, 0.08), Vector3(sx * w * 0.3, 0.85, l * 0.5 - 0.1), dark)
		_box(Vector3(0.45, 0.12, 0.05), Vector3(sx * w * 0.3, 0.55, -l * 0.5), head)
		_box(Vector3(0.45, 0.12, 0.05), Vector3(sx * w * 0.3, 0.55, l * 0.5), tail)

	if not ai:
		var sp := SpotLight3D.new()
		sp.position = Vector3(0, 0.7, -l * 0.5)
		sp.spot_range = 45.0
		sp.spot_angle = 32.0
		sp.light_energy = 4.0
		add_child(sp)

	var tire := StandardMaterial3D.new()
	tire.albedo_color = Color(0.04, 0.04, 0.04)
	tire.roughness = 0.9
	var rim := StandardMaterial3D.new()
	rim.albedo_color = Color(0.75, 0.75, 0.8)
	rim.metallic = 1.0
	rim.roughness = 0.2
	for sx in [-1.0, 1.0]:
		for fz in [-1.0, 1.0]:
			var wl := VehicleWheel3D.new()
			wl.position = Vector3(sx * (w * 0.5 + 0.02), 0.45, fz * l * 0.32)
			wl.wheel_radius = 0.35
			wl.wheel_rest_length = 0.2
			wl.suspension_travel = 0.3
			wl.suspension_stiffness = 45.0
			wl.suspension_max_force = 14000.0
			wl.damping_compression = 0.6
			wl.damping_relaxation = 0.8
			wl.wheel_roll_influence = 0.15
			wl.friction_slip = grip
			wl.use_as_steering = fz < 0.0
			wl.use_as_traction = fz > 0.0
			var mi := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.35
			cm.bottom_radius = 0.35
			cm.height = 0.28
			cm.radial_segments = 20
			cm.rings = 1
			mi.mesh = cm
			mi.material_override = tire
			mi.rotation_degrees = Vector3(0, 0, 90)
			wl.add_child(mi)
			var ri := MeshInstance3D.new()
			var rm := CylinderMesh.new()
			rm.top_radius = 0.22
			rm.bottom_radius = 0.22
			rm.height = 0.3
			rm.radial_segments = 12
			rm.rings = 1
			ri.mesh = rm
			ri.material_override = rim
			ri.rotation_degrees = Vector3(0, 0, 90)
			wl.add_child(ri)
			add_child(wl)
			if fz > 0.0:
				_rear.append(wl)

func _physics_process(delta: float) -> void:
	if locked:
		engine_force = 0.0
		brake = 0.05 * mass
		return
	var bx := global_transform.basis.x
	speed = linear_velocity.dot(-global_transform.basis.z)
	var lat := linear_velocity.dot(bx)
	var spd := absf(speed)

	# руление
	var max_steer := lerpf(0.55, 0.2, clampf(spd / 45.0, 0.0, 1.0))
	if handbrake:
		max_steer *= 1.3
	steering = move_toward(steering, steer_in * max_steer, delta * 4.5)

	# сцепление задних колёс / дрифт
	var target_mult := 1.0
	if handbrake and spd > 6.0:
		target_mult = 0.25
	elif absf(steer_in) > 0.7 and spd > 22.0:
		target_mult = drift_k
	_rear_mult = lerpf(_rear_mult, target_mult, clampf(delta * 8.0, 0.0, 1.0))
	for w in _rear:
		w.friction_slip = grip * _rear_mult
	if handbrake and spd > 8.0:
		apply_torque(Vector3.UP * steer_in * mass * 3.0)

	# газ, нитро, тормоз
	var limit := top * limit_mult
	var using_nitro := nitro_on and nitro > 0.0 and gas > 0.0
	if using_nitro:
		limit *= 1.25
		nitro = maxf(0.0, nitro - 30.0 * delta)
	else:
		nitro = minf(nitro_max, nitro + 5.0 * delta)
	var eng := power * gas
	if using_nitro:
		eng *= 1.8
	if speed > 0.0:
		eng *= clampf(1.0 - pow(speed / limit, 4.0), 0.0, 1.0)
	var br := 0.0
	if brake_in > 0.0:
		if speed > 1.5:
			br = brake_in * 0.028 * mass
		else:
			eng = -power * 0.5 * brake_in
	elif gas == 0.0:
		br = 0.003 * mass
	engine_force = eng
	brake = br

	# очки дрифта
	if spd > 10.0 and absf(lat) > 3.0:
		drift_score += absf(lat) * spd * 0.05 * delta
		_drift_t = 0.7
	else:
		_drift_t -= delta
		if _drift_t <= 0.0 and drift_score > 0.0:
			drift_bank += drift_score
			drift_score = 0.0

	# если перевернулась - ставим на колёса
	if global_transform.basis.y.y < 0.25:
		_flip_t += delta
		if _flip_t > 2.0:
			_flip_t = 0.0
			global_transform = Transform3D(Basis(Vector3.UP, rotation.y), global_position + Vector3(0, 1.5, 0))
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO
	else:
		_flip_t = 0.0
