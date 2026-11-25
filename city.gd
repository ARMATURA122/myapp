extends Node3D
# Процедурный город: дороги, кварталы, здания с окнами, парки

const GRID := 9
const HALF := 4
const PITCH := 70.0
const ROAD_W := 18.0
const BLOCK := 52.0

const WINDOW_SHADER := """
shader_type spatial;

uniform vec4 wall_color : source_color = vec4(0.7, 0.7, 0.7, 1.0);
uniform vec4 glass_color : source_color = vec4(0.2, 0.35, 0.5, 1.0);
uniform float win_w = 3.0;
uniform float win_h = 3.6;
varying vec3 lpos;
varying vec3 lnor;

void vertex() {
	lpos = VERTEX;
	lnor = NORMAL;
}

void fragment() {
	float side = step(abs(lnor.y), 0.5);
	float u = mix(lpos.x, lpos.z, step(0.5, abs(lnor.x)));
	vec2 g = vec2(u / win_w, lpos.y / win_h);
	vec2 f = fract(g);
	float win = step(0.18, f.x) * step(f.x, 0.82) * step(0.22, f.y) * step(f.y, 0.78) * side;
	vec3 col = mix(wall_color.rgb, glass_color.rgb, win);
	ALBEDO = col;
	ROUGHNESS = mix(0.85, 0.12, win);
	METALLIC = win * 0.5;
}
"""

var _shader: Shader
var _walls: Array[Color] = [
	Color(0.78, 0.74, 0.68), Color(0.62, 0.62, 0.64), Color(0.55, 0.36, 0.30),
	Color(0.85, 0.82, 0.75), Color(0.45, 0.52, 0.58), Color(0.70, 0.58, 0.45)]
var _glass: Array[Color] = [
	Color(0.18, 0.30, 0.42), Color(0.12, 0.22, 0.32),
	Color(0.25, 0.38, 0.50), Color(0.20, 0.20, 0.25)]
var _tree_body: StaticBody3D
var _trunks: Array[Transform3D] = []
var _crowns: Array[Transform3D] = []


static func cell_to_pos(i: int, j: int) -> Vector3:
	return Vector3((i - HALF) * PITCH, 0.0, (j - HALF) * PITCH)


func _std(c: Color, rough: float = 0.8, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func build(rng: RandomNumberGenerator) -> void:
	_shader = Shader.new()
	_shader.code = WINDOW_SHADER
	_tree_body = StaticBody3D.new()
	add_child(_tree_body)
	_build_ground()

	var slab_mesh := BoxMesh.new()
	slab_mesh.size = Vector3(BLOCK, 0.14, BLOCK)
	var slab_mat := _std(Color(0.60, 0.60, 0.57), 0.9)
	var grass_mat := _std(Color(0.27, 0.50, 0.22), 0.95)

	for bi in range(-1, GRID):
		for bj in range(-1, GRID):
			var cx: float = (bi - HALF + 0.5) * PITCH
			var cz: float = (bj - HALF + 0.5) * PITCH
			var outer: bool = bi < 0 or bj < 0 or bi > GRID - 2 or bj > GRID - 2
			var park: bool = (not outer) and rng.randf() < 0.17

			var slab := MeshInstance3D.new()
			slab.mesh = slab_mesh
			slab.material_override = grass_mat if park else slab_mat
			slab.position = Vector3(cx, 0.07, cz)
			add_child(slab)

			if park:
				_add_park(cx, cz, rng)
			else:
				_add_lots(cx, cz, rng, outer)

	_finish_trees()
	_build_lane_marks()
	_build_walls()


func _build_ground() -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1600, 2, 1600)
	cs.shape = bs
	cs.position = Vector3(0, -1, 0)
	body.add_child(cs)
	add_child(body)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1600, 1600)
	mi.mesh = pm
	mi.material_override = _std(Color(0.13, 0.13, 0.14), 0.9)
	add_child(mi)


func _add_lots(cx: float, cz: float, rng: RandomNumberGenerator, outer: bool) -> void:
	for ix in range(2):
		for iz in range(2):
			var lx: float = cx + (float(ix) * 2.0 - 1.0) * 13.0
			var lz: float = cz + (float(iz) * 2.0 - 1.0) * 13.0
			var w: float = rng.randf_range(19.0, 24.0)
			var d: float = rng.randf_range(19.0, 24.0)
			var dist: float = Vector2(lx, lz).length()
			var base: float = lerpf(70.0, 12.0, clampf(dist / 330.0, 0.0, 1.0))
			var h: float = base * rng.randf_range(0.45, 1.4) + 8.0
			if outer:
				w = 26.0
				d = 26.0
				h = maxf(h, 35.0)
			_add_building(Vector3(lx, 0.0, lz), Vector3(w, h, d), rng)


func _add_building(pos: Vector3, size: Vector3, rng: RandomNumberGenerator) -> void:
	var body := StaticBody3D.new()
	body.position = Vector3(pos.x, size.y * 0.5, pos.z)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	var wc: Color = _walls[rng.randi() % _walls.size()]
	var gc: Color = _glass[rng.randi() % _glass.size()]
	mat.set_shader_parameter("wall_color", wc)
	mat.set_shader_parameter("glass_color", gc)
	mat.set_shader_parameter("win_w", rng.randf_range(2.6, 3.8))
	mat.set_shader_parameter("win_h", rng.randf_range(3.2, 4.0))
	mi.material_override = mat
	body.add_child(mi)
	add_child(body)


func _add_park(cx: float, cz: float, rng: RandomNumberGenerator) -> void:
	for k in range(14):
		var tx: float = cx + rng.randf_range(-22.0, 22.0)
		var tz: float = cz + rng.randf_range(-22.0, 22.0)
		var s: float = rng.randf_range(0.8, 1.4)
		var b := Basis().scaled(Vector3(s, s, s))
		_trunks.append(Transform3D(b, Vector3(tx, 1.5 * s, tz)))
		_crowns.append(Transform3D(b, Vector3(tx, 4.6 * s, tz)))
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.5 * s
		cyl.height = 3.0 * s
		cs.shape = cyl
		cs.position = Vector3(tx, 1.5 * s, tz)
		_tree_body.add_child(cs)


func _multimesh(mesh: Mesh, mat: Material, xforms: Array[Transform3D], shadows: bool) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	if not shadows:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _finish_trees() -> void:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.28
	trunk.bottom_radius = 0.38
	trunk.height = 3.0
	trunk.radial_segments = 8
	_multimesh(trunk, _std(Color(0.35, 0.24, 0.15), 0.95), _trunks, true)
	var crown := SphereMesh.new()
	crown.radius = 2.6
	crown.height = 5.2
	crown.radial_segments = 12
	crown.rings = 6
	_multimesh(crown, _std(Color(0.18, 0.46, 0.16), 0.9), _crowns, true)


func _build_lane_marks() -> void:
	var xf: Array[Transform3D] = []
	for i in range(GRID):
		var k: float = (i - HALF) * PITCH
		for seg in range(GRID - 1):
			var a: float = (seg - HALF) * PITCH + ROAD_W * 0.5 + 3.0
			var b: float = (seg + 1 - HALF) * PITCH - ROAD_W * 0.5 - 3.0
			var t: float = a
			while t < b:
				xf.append(Transform3D(Basis(), Vector3(k, 0.03, t + 1.5)))
				xf.append(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(t + 1.5, 0.03, k)))
				t += 7.0
	var dash := BoxMesh.new()
	dash.size = Vector3(0.3, 0.02, 3.0)
	_multimesh(dash, _std(Color(0.95, 0.88, 0.45), 0.8), xf, false)


func _build_walls() -> void:
	var lim: float = HALF * PITCH + ROAD_W * 0.5 + 3.0
	var body := StaticBody3D.new()
	add_child(body)
	var defs: Array = [
		[Vector3(lim + 2.0, 10, 0), Vector3(4, 20, 760)],
		[Vector3(-lim - 2.0, 10, 0), Vector3(4, 20, 760)],
		[Vector3(0, 10, lim + 2.0), Vector3(760, 20, 4)],
		[Vector3(0, 10, -lim - 2.0), Vector3(760, 20, 4)]]
	for d in defs:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = d[1]
		cs.shape = bs
		cs.position = d[0]
		body.add_child(cs)
