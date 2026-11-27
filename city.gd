extends RefCounted

const PITCH := 78.0
const NB := 4

static func _noise_tex(c0: Color, c1: Color, freq: float) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.frequency = freq
	var t := NoiseTexture2D.new()
	t.noise = n
	t.width = 256
	t.height = 256
	t.seamless = true
	var g := Gradient.new()
	g.set_color(0, c0)
	g.set_color(1, c1)
	t.color_ramp = g
	return t

static func _mat(c0: Color, c1: Color, freq: float, uv: float, rough: float, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _noise_tex(c0, c1, freq)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * uv
	m.roughness = rough
	m.metallic = metal
	return m

static func _emit(c: Color, e: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	return m

static func _window_mat() -> StandardMaterial3D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for cy in 8:
		for cx in 8:
			var r := rng.randf()
			var glass := Color(0.08, 0.1, 0.13)
			if r > 0.93:
				glass = Color(0.3, 0.75, 0.8)
			elif r > 0.8:
				glass = Color(0.04, 0.05, 0.07)
			for y in 8:
				for x in 8:
					var inside := x >= 2 and x <= 5 and y >= 2 and y <= 6
					img.set_pixel(cx * 8 + x, cy * 8 + y, glass if inside else Color(0.32, 0.31, 0.3))
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * 0.05
	m.roughness = 0.7
	return m

static func _add(solid: StaticBody3D, groups: Dictionary, key: String, pos: Vector3, size: Vector3, rot := Vector3.ZERO, collide := true) -> void:
	var b := Basis.from_euler(rot)
	groups[key].append(Transform3D(b * Basis.from_scale(size), pos))
	if collide:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		cs.transform = Transform3D(b, pos)
		solid.add_child(cs)

static func _wall_x(solid: StaticBody3D, groups: Dictionary, key: String, a: float, b: float, z: float, h: float, rng: RandomNumberGenerator) -> void:
	var gx := rng.randf_range(a + 8.0, b - 8.0)
	_seg_x(solid, groups, key, a, gx - 2.5, z, h * rng.randf_range(0.55, 1.0))
	_seg_x(solid, groups, key, gx + 2.5, b, z, h * rng.randf_range(0.55, 1.0))

static func _seg_x(solid: StaticBody3D, groups: Dictionary, key: String, a: float, b: float, z: float, h: float) -> void:
	_add(solid, groups, key, Vector3((a + b) * 0.5, h * 0.5, z), Vector3(b - a, h, 1.0))

static func _wall_z(solid: StaticBody3D, groups: Dictionary, key: String, a: float, b: float, x: float, h: float, rng: RandomNumberGenerator) -> void:
	var gz := rng.randf_range(a + 8.0, b - 8.0)
	_seg_z(solid, groups, key, a, gz - 2.5, x, h * rng.randf_range(0.55, 1.0))
	_seg_z(solid, groups, key, gz + 2.5, b, x, h * rng.randf_range(0.55, 1.0))

static func _seg_z(solid: StaticBody3D, groups: Dictionary, key: String, a: float, b: float, x: float, h: float) -> void:
	_add(solid, groups, key, Vector3(x, h * 0.5, (a + b) * 0.5), Vector3(1.0, h, b - a))

static func _car(solid: StaticBody3D, groups: Dictionary, p: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	_add(solid, groups, "rust", p + b * Vector3(0, 0.7, 0), Vector3(4.2, 0.9, 1.9), Vector3(0, yaw, 0))
	_add(solid, groups, "rust", p + b * Vector3(-0.2, 1.4, 0), Vector3(2.2, 0.7, 1.7), Vector3(0, yaw, 0), false)

static func build(root: Node3D) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var solid := StaticBody3D.new()
	solid.collision_layer = 1
	solid.collision_mask = 0
	root.add_child(solid)
	var groups := {"conc": [], "brick": [], "rust": [], "wood": [], "win": [], "neon_p": [], "neon_c": []}
	var mats := {
		"conc": _mat(Color(0.35, 0.34, 0.33), Color(0.55, 0.54, 0.52), 0.05, 0.08, 0.95),
		"brick": _mat(Color(0.32, 0.17, 0.13), Color(0.5, 0.3, 0.22), 0.1, 0.12, 0.9),
		"rust": _mat(Color(0.3, 0.16, 0.09), Color(0.5, 0.3, 0.15), 0.08, 0.2, 0.7, 0.35),
		"wood": _mat(Color(0.3, 0.2, 0.1), Color(0.45, 0.32, 0.16), 0.12, 0.4, 0.85),
		"win": _window_mat(),
		"neon_p": _emit(Color(1.0, 0.2, 0.7), 2.5),
		"neon_c": _emit(Color(0.2, 0.9, 1.0), 2.5),
	}
	var ext := PITCH * NB * 0.5

	# земля
	var ground_mat := _mat(Color(0.1, 0.1, 0.11), Color(0.22, 0.22, 0.23), 0.04, 0.06, 0.9)
	var gm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(900, 900)
	gm.mesh = pm
	gm.material_override = ground_mat
	root.add_child(gm)
	var gcs := CollisionShape3D.new()
	var gsh := BoxShape3D.new()
	gsh.size = Vector3(900, 2, 900)
	gcs.shape = gsh
	gcs.position = Vector3(0, -1, 0)
	solid.add_child(gcs)

	# граница карты
	var edge := ext + 16.0
	for s in [-1.0, 1.0]:
		_add(solid, groups, "conc", Vector3(0, 3, s * edge), Vector3(edge * 2.0 + 4.0, 6, 2))
		_add(solid, groups, "conc", Vector3(s * edge, 3, 0), Vector3(2, 6, edge * 2.0 + 4.0))

	# кварталы
	for i in NB:
		for j in NB:
			var cx := (i - (NB - 1) / 2.0) * PITCH
			var cz := (j - (NB - 1) / 2.0) * PITCH
			var t := rng.randf()
			if t < 0.4:
				var w := rng.randf_range(34.0, 46.0)
				var d := rng.randf_range(34.0, 46.0)
				var h := rng.randf_range(22.0, 50.0)
				_add(solid, groups, "win", Vector3(cx, h * 0.5, cz), Vector3(w, h, d))
				if rng.randf() < 0.6:
					var sgn := 1.0 if rng.randf() < 0.5 else -1.0
					_add(solid, groups, "neon_p" if rng.randf() < 0.5 else "neon_c", Vector3(cx + sgn * (w * 0.5 + 0.2), h * 0.6, cz), Vector3(0.3, 5.0, 8.0), Vector3.ZERO, false)
				if rng.randf() < 0.5:
					_add(solid, groups, "conc", Vector3(cx + w * 0.5 + 5.0, 3.0, cz + d * 0.3), Vector3(10, 6, 12))
			elif t < 0.8:
				var w2 := 40.0
				var d2 := 40.0
				var h2 := rng.randf_range(10.0, 18.0)
				_wall_x(solid, groups, "brick", cx - w2 * 0.5, cx + w2 * 0.5, cz - d2 * 0.5, h2, rng)
				_wall_x(solid, groups, "brick", cx - w2 * 0.5, cx + w2 * 0.5, cz + d2 * 0.5, h2, rng)
				_wall_z(solid, groups, "brick", cz - d2 * 0.5, cz + d2 * 0.5, cx - w2 * 0.5, h2, rng)
				_wall_z(solid, groups, "brick", cz - d2 * 0.5, cz + d2 * 0.5, cx + w2 * 0.5, h2, rng)
				for k in 4:
					_add(solid, groups, "wood", Vector3(cx + rng.randf_range(-16, 16), 0.75, cz + rng.randf_range(-16, 16)), Vector3(1.5, 1.5, 1.5), Vector3(0, rng.randf() * PI, 0))
				_add(solid, groups, "conc", Vector3(cx + rng.randf_range(-8, 8), 1.5, cz + rng.randf_range(-8, 8)), Vector3(12, 3, 0.6), Vector3(0, rng.randf() * PI, 0))
			else:
				for k in 6:
					_add(solid, groups, "conc", Vector3(cx + rng.randf_range(-24, 24), 0.6, cz + rng.randf_range(-24, 24)), Vector3(rng.randf_range(4, 9), 1.2, 0.8), Vector3(0, rng.randf() * PI, 0))
				for k in 3:
					_car(solid, groups, Vector3(cx + rng.randf_range(-20, 20), 0, cz + rng.randf_range(-20, 20)), rng.randf() * TAU)
				for k in 6:
					_add(solid, groups, "wood", Vector3(cx + rng.randf_range(-24, 24), 0.75, cz + rng.randf_range(-24, 24)), Vector3(1.5, 1.5, 1.5), Vector3(0, rng.randf() * PI, 0))

	# мусор на улицах
	for k in NB + 1:
		var line := (k - NB / 2.0) * PITCH
		var t2 := -150.0
		while t2 <= 150.0:
			var r := rng.randf()
			if r < 0.3:
				_car(solid, groups, Vector3(t2 + rng.randf_range(-4, 4), 0, line + rng.randf_range(-5, 5)), rng.randf() * TAU)
			elif r < 0.55:
				_add(solid, groups, "conc", Vector3(t2, 0.5, line + rng.randf_range(-5, 5)), Vector3(3.0, 1.0, 0.7), Vector3(0, rng.randf() * PI, 0))
			elif r < 0.7:
				_add(solid, groups, "wood", Vector3(t2, 0.75, line + rng.randf_range(-5, 5)), Vector3(1.5, 1.5, 1.5), Vector3(0, rng.randf() * PI, 0))
			var r2 := rng.randf()
			if r2 < 0.3:
				_car(solid, groups, Vector3(line + rng.randf_range(-5, 5), 0, t2 + rng.randf_range(-4, 4)), rng.randf() * TAU)
			elif r2 < 0.5:
				_add(solid, groups, "conc", Vector3(line + rng.randf_range(-5, 5), 0.5, t2), Vector3(0.7, 1.0, 3.0), Vector3(0, rng.randf() * PI, 0))
			elif r2 < 0.65:
				_add(solid, groups, "conc", Vector3(line + rng.randf_range(-6, 6), 0.4, t2), Vector3(rng.randf_range(1.0, 3.0), 0.8, rng.randf_range(1.0, 3.0)), Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * PI, rng.randf_range(-0.3, 0.3)))
			t2 += 22.0

	# MultiMesh на каждый материал: мало вызовов отрисовки
	var unit := BoxMesh.new()
	unit.size = Vector3.ONE
	for key in groups.keys():
		var arr: Array = groups[key]
		if arr.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = unit
		mm.instance_count = arr.size()
		for n in arr.size():
			mm.set_instance_transform(n, arr[n])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mats[key]
		root.add_child(mmi)

	var spawns: Array = []
	for a in NB + 1:
		for b in NB + 1:
			spawns.append(Vector3((a - NB / 2.0) * PITCH, 0.3, (b - NB / 2.0) * PITCH))
	return {"spawns": spawns}
