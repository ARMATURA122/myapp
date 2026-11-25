extends Node3D
# Процедурная модель машины (стиль M3 GTR: белая с синими полосами)

var spins: Array[Node3D] = []
var steer_pivots: Array[Node3D] = []
var _ang := 0.0


func _mat(c: Color, metal: float = 0.0, rough: float = 0.5, emit: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


func _box(size: Vector3, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	add_child(mi)
	return mi


func _cyl(parent: Node3D, radius: float, height: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 20
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	mi.rotation_degrees = Vector3(0, 0, 90)
	parent.add_child(mi)


func setup(body_col: Color, stripe_col: Color) -> void:
	var paint := _mat(body_col, 0.35, 0.22)
	paint.clearcoat_enabled = true
	paint.clearcoat = 1.0
	paint.clearcoat_roughness = 0.08
	var stripe := _mat(stripe_col, 0.35, 0.25)
	var glass := _mat(Color(0.04, 0.07, 0.11), 0.9, 0.04)
	var black := _mat(Color(0.03, 0.03, 0.035), 0.1, 0.6)
	var chrome := _mat(Color(0.75, 0.77, 0.8), 1.0, 0.2)
	var light := _mat(Color(1.0, 0.95, 0.8), 0.0, 0.2, 2.0)
	var tail := _mat(Color(1.0, 0.05, 0.04), 0.0, 0.3, 1.8)

	# кузов
	_box(Vector3(1.84, 0.46, 4.3), Vector3(0, 0.56, 0), paint)
	_box(Vector3(1.72, 0.10, 1.5), Vector3(0, 0.84, -1.25), paint)
	_box(Vector3(1.70, 0.08, 0.75), Vector3(0, 0.86, 1.65), paint)
	# салон и крыша
	_box(Vector3(1.56, 0.46, 2.0), Vector3(0, 1.04, 0.3), glass)
	_box(Vector3(1.50, 0.05, 1.55), Vector3(0, 1.30, 0.35), paint)
	for sx in range(2):
		var s: float = float(sx) * 2.0 - 1.0
		_box(Vector3(0.07, 0.5, 0.07), Vector3(0.77 * s, 1.04, -0.72), paint, Vector3(-28, 0, 0))
		_box(Vector3(0.10, 0.46, 0.40), Vector3(0.76 * s, 1.04, 1.2), paint)
		# боковые зеркала
		_box(Vector3(0.16, 0.10, 0.20), Vector3(0.97 * s, 0.95, -0.55), paint)
		# пороги
		_box(Vector3(0.04, 0.10, 2.2), Vector3(0.93 * s, 0.30, 0.2), black)
		# синие полосы по бокам
		_box(Vector3(0.02, 0.20, 2.4), Vector3(0.93 * s, 0.52, 0.5), stripe, Vector3(7, 0, 0))
		_box(Vector3(0.02, 0.30, 1.1), Vector3(0.93 * s, 0.62, -1.35), stripe)
		_box(Vector3(0.02, 0.28, 0.9), Vector3(0.93 * s, 0.62, 1.6), stripe)
		# арки колёс
		_box(Vector3(0.03, 0.46, 0.85), Vector3(0.93 * s, 0.45, -1.38), black)
		_box(Vector3(0.03, 0.46, 0.85), Vector3(0.93 * s, 0.45, 1.32), black)
		# фары и габариты
		_box(Vector3(0.42, 0.13, 0.05), Vector3(0.66 * s, 0.66, -2.16), light)
		_box(Vector3(0.45, 0.12, 0.05), Vector3(0.62 * s, 0.68, 2.16), tail)
		# выхлопы
		_box(Vector3(0.10, 0.10, 0.18), Vector3(0.45 * s, 0.22, 2.30), chrome)
		# ноздри BMW
		_box(Vector3(0.34, 0.20, 0.04), Vector3(0.20 * s, 0.62, -2.16), chrome)
		_box(Vector3(0.28, 0.15, 0.05), Vector3(0.20 * s, 0.62, -2.17), black)
		# чёрные вентиляции на капоте
		_box(Vector3(0.35, 0.012, 0.4), Vector3(0.3 * s, 0.9, -1.2), black)
	# синяя полоса на капоте и багажнике
	_box(Vector3(0.9, 0.012, 1.5), Vector3(0, 0.895, -1.25), stripe)
	_box(Vector3(1.0, 0.012, 0.6), Vector3(0, 0.905, 1.65), stripe)
	# бампера
	_box(Vector3(1.86, 0.24, 0.40), Vector3(0, 0.34, -2.12), paint)
	_box(Vector3(1.90, 0.05, 0.50), Vector3(0, 0.19, -2.20), paint)
	_box(Vector3(1.10, 0.10, 0.05), Vector3(0, 0.36, -2.33), black)
	_box(Vector3(1.84, 0.20, 0.30), Vector3(0, 0.30, 2.10), paint)
	# спойлер
	_box(Vector3(1.4, 0.04, 0.22), Vector3(0, 0.93, 2.05), stripe)

	# колёса
	var tyre := _mat(Color(0.04, 0.04, 0.04), 0.0, 0.9)
	var rim := _mat(Color(0.82, 0.84, 0.88), 1.0, 0.18)
	var hub := _mat(Color(0.05, 0.05, 0.06), 0.3, 0.5)
	for ix in range(2):
		var fx: float = float(ix) * 2.0 - 1.0
		for iz in range(2):
			var fz: float = -1.38 if iz == 0 else 1.32
			var pivot := Node3D.new()
			pivot.position = Vector3(0.86 * fx, 0.34, fz)
			add_child(pivot)
			var spin := Node3D.new()
			pivot.add_child(spin)
			_cyl(spin, 0.34, 0.27, tyre)
			_cyl(spin, 0.235, 0.285, rim)
			_cyl(spin, 0.15, 0.295, hub)
			spins.append(spin)
			if iz == 0:
				steer_pivots.append(pivot)


func update_wheels(speed: float, steer: float, delta: float) -> void:
	_ang = fposmod(_ang - speed * delta / 0.34, TAU)
	for s in spins:
		s.rotation.x = _ang
	for p in steer_pivots:
		p.rotation.y = -steer * 0.45
