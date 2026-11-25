extends Node3D

const CarScript = preload("res://car.gd")
const P := 114.0
const BLOCK := 90.0
const NB := 6
const EXT := 342.0
const GARAGE := Vector3(2000, 0, 2000)
const MAP_PX := 200.0
const MAP_SCALE := 200.0 / 720.0

var ui: CanvasLayer
var cam: Camera3D
var world: Node3D
var menu: Control
var hud: Control
var state := "menu"
var view_idx := 0
var preview = null
var player = null
var snap_cam := true
var touches: Dictionary = {}
var held: Dictionary = {}
var btn_rects: Dictionary = {}
var btn_nodes: Dictionary = {}
var info_label: Label
var speed_label: Label
var drift_label: Label
var race_label: Label
var msg_label: Label
var nitro_bar: ProgressBar
var minimap: Control
var arrow: Polygon2D
var toast_t := 0.0
var blocks: Array = []
var all_inter: Array = []
var race_spots: Array = []
var race_active := false
var race_k := 0
var cps: Array = []
var cp_i := 0
var time_left := 0.0
var beacon_cp = null
var win_tex: ImageTexture = null

func _ready() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_2X
	_build_environment()
	ui = CanvasLayer.new()
	add_child(ui)
	cam = Camera3D.new()
	cam.near = 0.2
	cam.far = 900.0
	add_child(cam)
	cam.make_current()
	view_idx = Game.selected
	show_menu()

# ------------------------------------------------------------ небо и солнце
func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.22, 0.48, 0.90)
	psm.sky_horizon_color = Color(0.72, 0.82, 0.95)
	psm.ground_horizon_color = Color(0.72, 0.80, 0.90)
	psm.ground_bottom_color = Color(0.45, 0.55, 0.65)
	psm.sun_angle_max = 30.0
	sky.sky_material = psm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.04
	env.fog_enabled = true
	env.fog_light_color = Color(0.75, 0.82, 0.92)
	env.fog_density = 0.0012
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.08
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -40, 0)
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.7
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 160.0
	add_child(sun)

# ------------------------------------------------------------ помощники
func _emit(c: Color, energy := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m

func _noise_tex(c0: Color, c1: Color, freq: float) -> NoiseTexture2D:
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

func _tex_mat(tex: Texture2D, uv_scale: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * uv_scale
	m.roughness = rough
	return m

func _window_mat(tint: Color) -> StandardMaterial3D:
	if win_tex == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		for cy in 8:
			for cx in 8:
				var r := rng.randf()
				var glass := Color(0.25, 0.38, 0.52)
				if r < 0.25:
					glass = Color(0.12, 0.18, 0.28)
				elif r > 0.9:
					glass = Color(0.9, 0.85, 0.6)
				for y in 8:
					for x in 8:
						var inside := x >= 2 and x <= 5 and y >= 2 and y <= 5
						img.set_pixel(cx * 8 + x, cy * 8 + y, glass if inside else Color(0.78, 0.76, 0.72))
		img.generate_mipmaps()
		win_tex = ImageTexture.create_from_image(img)
	var m := _tex_mat(win_tex, 0.036, 0.35)
	m.albedo_color = tint
	m.metallic = 0.25
	return m

func _add_box(parent: Node, pos: Vector3, size: Vector3, m: Material, collide := true) -> void:
	if m != null:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
		mi.material_override = m
		mi.position = pos
		parent.add_child(mi)
	if collide:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		cs.position = pos
		parent.add_child(cs)

func _plane(size: float, y: float, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	mi.mesh = pm
	mi.material_override = m
	mi.position = Vector3(0, y, 0)
	world.add_child(mi)

func _multimesh(mesh: Mesh, m: Material, xforms: Array) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = m
	world.add_child(mi)

func _lbl(t: String, size := 24, col := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	return l

func _btn(t: String, size := 26, min_size := Vector2(300, 64)) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", size)
	return b

func _clear_world() -> void:
	if world:
		world.queue_free()
		world = null
	preview = null
	player = null
	beacon_cp = null
	race_active = false
	blocks.clear()
	all_inter.clear()
	race_spots.clear()
	cps.clear()

func _toast(t: String, secs := 3.0) -> void:
	if msg_label:
		msg_label.text = t
		toast_t = secs

# ------------------------------------------------------------ гараж
func show_menu() -> void:
	state = "menu"
	if hud:
		hud.queue_free()
		hud = null
	touches.clear()
	held.clear()
	_clear_world()
	_build_garage()
	_spawn_preview()
	_build_menu()

func _build_garage() -> void:
	world = Node3D.new()
	add_child(world)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.55, 0.57, 0.6)
	fm.metallic = 0.3
	fm.roughness = 0.35
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(120, 120)
	fl.mesh = pm
	fl.material_override = fm
	fl.position = GARAGE
	world.add_child(fl)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 3.6
	tm.outer_radius = 3.8
	ring.mesh = tm
	ring.material_override = _emit(Color(0.1, 0.8, 1.0), 2.0)
	ring.position = GARAGE + Vector3(0, 0.05, 0)
	world.add_child(ring)

func _spawn_preview() -> void:
	if preview:
		preview.queue_free()
	preview = CarScript.new()
	preview.setup(view_idx, Game.levels(view_idx))
	preview.set_physics_process(false)
	world.add_child(preview)
	preview.position = GARAGE

func _build_menu() -> void:
	if menu:
		menu.queue_free()
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(menu)
	var vs := get_viewport().get_visible_rect().size
	var d: Dictionary = Game.cars[view_idx]
	var owned := view_idx in Game.owned
	var panel := PanelContainer.new()
	panel.position = Vector2(20, 20)
	menu.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	v.add_child(_lbl("Деньги: $%d" % Game.money, 30, Color(0.5, 1, 0.5)))
	v.add_child(_lbl(d["name"], 34))
	v.add_child(_lbl("Разгон %d   Макс. %d км/ч   Сцепление %.1f" % [int(d["accel"]), int(float(d["top"]) * 3.6), float(d["grip"])], 20))
	if owned:
		if Game.selected == view_idx:
			v.add_child(_lbl("Выбрана", 24, Color(1, 0.85, 0.3)))
		else:
			var sb := _btn("Выбрать")
			sb.pressed.connect(_on_select)
			v.add_child(sb)
		for k in Game.UPGRADES:
			var lvl: int = Game.levels(view_idx)[k]
			var maxed := lvl >= Game.MAX_LEVEL
			var cost: int = Game.upgrade_cost(view_idx, k)
			var price_txt := "МАКС" if maxed else "$" + str(cost)
			var ub := _btn("%s  %d/%d  %s" % [Game.UPGRADES[k], lvl, Game.MAX_LEVEL, price_txt], 22)
			ub.disabled = maxed or Game.money < cost
			ub.pressed.connect(_on_upgrade.bind(k))
			v.add_child(ub)
	else:
		var bb := _btn("Купить  $%d" % int(d["price"]))
		bb.disabled = Game.money < int(d["price"])
		bb.pressed.connect(_on_buy)
		v.add_child(bb)
	var prev := _btn("<", 34, Vector2(110, 80))
	prev.position = Vector2(vs.x * 0.5 - 140, vs.y - 110)
	prev.pressed.connect(_on_prev)
	menu.add_child(prev)
	var nxt := _btn(">", 34, Vector2(110, 80))
	nxt.position = Vector2(vs.x * 0.5 + 30, vs.y - 110)
	nxt.pressed.connect(_on_next)
	menu.add_child(nxt)
	var go := _btn("ЕХАТЬ", 40, Vector2(300, 100))
	go.position = Vector2(vs.x - 330, vs.y - 130)
	go.disabled = not owned
	go.pressed.connect(_on_go)
	menu.add_child(go)

func _on_select() -> void:
	Game.selected = view_idx
	Game.save_game()
	_build_menu()

func _on_upgrade(kind: String) -> void:
	Game.buy_upgrade(view_idx, kind)
	_build_menu()

func _on_buy() -> void:
	Game.buy_car(view_idx)
	_build_menu()

func _on_prev() -> void:
	view_idx = (view_idx - 1 + Game.cars.size()) % Game.cars.size()
	_spawn_preview()
	_build_menu()

func _on_next() -> void:
	view_idx = (view_idx + 1) % Game.cars.size()
	_spawn_preview()
	_build_menu()

func _on_go() -> void:
	Game.selected = view_idx
	Game.save_game()
	_start_world()

# ------------------------------------------------------------ город
func _build_city() -> void:
	world = Node3D.new()
	add_child(world)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var asphalt := _tex_mat(_noise_tex(Color(0.13, 0.13, 0.14), Color(0.27, 0.27, 0.29), 0.06), 0.05, 0.45)
	var grass := _tex_mat(_noise_tex(Color(0.18, 0.32, 0.12), Color(0.30, 0.46, 0.18), 0.05), 0.04, 1.0)
	var concrete := _tex_mat(_noise_tex(Color(0.55, 0.54, 0.52), Color(0.72, 0.71, 0.68), 0.08), 0.05, 0.9)
	_plane(4000.0, -0.1, grass)
	_plane(2.0 * (EXT + 12.0), 0.0, asphalt)

	# кварталы
	var park_set := {Vector2i(2, 2): true, Vector2i(3, 3): true, Vector2i(1, 4): true}
	for i in NB:
		for j in NB:
			blocks.append({"x": (i - 2.5) * P, "z": (j - 2.5) * P, "park": park_set.has(Vector2i(i, j))})
	var solid := StaticBody3D.new()
	world.add_child(solid)
	for b in blocks:
		var cx: float = b["x"]
		var cz: float = b["z"]
		_add_box(world, Vector3(cx, 0.0, cz), Vector3(BLOCK, 0.16, BLOCK), grass if b["park"] else concrete, false)
		if not b["park"]:
			_add_box(solid, Vector3(cx, 3.0, cz), Vector3(BLOCK - 8.0, 6.0, BLOCK - 8.0), null, true)
	# граница карты
	var half := EXT + 16.0
	for s in [-1.0, 1.0]:
		_add_box(solid, Vector3(0, 0.75, s * half), Vector3(2.0 * half + 4.0, 1.5, 3.0), concrete, true)
		_add_box(solid, Vector3(s * half, 0.75, 0), Vector3(3.0, 1.5, 2.0 * half + 4.0), concrete, true)

	# здания (MultiMesh: 3 вызова отрисовки на весь город)
	var tints := [Color(1, 1, 1), Color(0.9, 0.85, 0.8), Color(0.8, 0.88, 1.0)]
	var groups: Array = [[], [], []]
	for b in blocks:
		if b["park"]:
			continue
		var dist := Vector2(b["x"], b["z"]).length()
		for lx in [-1.0, 1.0]:
			for lz in [-1.0, 1.0]:
				var w := rng.randf_range(26.0, 36.0)
				var d := rng.randf_range(26.0, 36.0)
				var base := lerpf(120.0, 30.0, clampf(dist / 450.0, 0.0, 1.0))
				var h := base * rng.randf_range(0.5, 1.15) + 14.0
				var pos := Vector3(float(b["x"]) + lx * 20.0, h * 0.5, float(b["z"]) + lz * 20.0)
				groups[rng.randi() % 3].append(Transform3D(Basis.from_scale(Vector3(w, h, d)), pos))
	var unit := BoxMesh.new()
	unit.size = Vector3.ONE
	for gi in 3:
		_multimesh(unit, _window_mat(tints[gi]), groups[gi])

	# деревья и фонари
	var trunks: Array = []
	var crowns: Array = []
	var poles: Array = []
	var heads: Array = []
	for b in blocks:
		var cx: float = b["x"]
		var cz: float = b["z"]
		var spots: Array = []
		if b["park"]:
			for k in 45:
				spots.append(Vector3(cx + rng.randf_range(-40.0, 40.0), 0, cz + rng.randf_range(-40.0, 40.0)))
		else:
			for k in 5:
				var t := -36.0 + k * 18.0
				spots.append(Vector3(cx + t, 0, cz - 43.0))
				spots.append(Vector3(cx + t, 0, cz + 43.0))
				spots.append(Vector3(cx - 43.0, 0, cz + t))
				spots.append(Vector3(cx + 43.0, 0, cz + t))
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var lp := Vector3(cx + sx * 43.0, 0, cz + sz * 43.0)
					poles.append(Transform3D(Basis.from_scale(Vector3(0.25, 7.0, 0.25)), lp + Vector3(0, 3.5, 0)))
					heads.append(Transform3D(Basis.from_scale(Vector3(0.9, 0.3, 0.9)), lp + Vector3(0, 7.1, 0)))
		for sp in spots:
			var sc := rng.randf_range(0.8, 1.4)
			trunks.append(Transform3D(Basis.from_scale(Vector3(sc, sc, sc)), sp + Vector3(0, 1.5 * sc, 0)))
			crowns.append(Transform3D(Basis.from_scale(Vector3(sc, sc, sc)), sp + Vector3(0, 4.5 * sc, 0)))
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.3
	trunk_mesh.bottom_radius = 0.35
	trunk_mesh.height = 3.0
	trunk_mesh.radial_segments = 6
	trunk_mesh.rings = 1
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 2.2
	crown_mesh.height = 4.4
	crown_mesh.radial_segments = 8
	crown_mesh.rings = 4
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.3, 0.2, 0.12)
	var leaf := StandardMaterial3D.new()
	leaf.albedo_color = Color(0.2, 0.5, 0.15)
	leaf.roughness = 0.9
	_multimesh(trunk_mesh, bark, trunks)
	_multimesh(crown_mesh, leaf, crowns)
	var pole_m := StandardMaterial3D.new()
	pole_m.albedo_color = Color(0.15, 0.15, 0.17)
	_multimesh(unit, pole_m, poles)
	_multimesh(unit, _emit(Color(1.0, 0.9, 0.6), 1.0), heads)

	# разметка дороги
	var dashes: Array = []
	for r in 7:
		var rc := (r - 3) * P
		var t := -EXT
		while t <= EXT:
			var near := false
			for k in 7:
				if absf(t - (k - 3) * P) < 18.0:
					near = true
			if not near:
				dashes.append(Transform3D(Basis(), Vector3(t, 0.03, rc)))
				dashes.append(Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(rc, 0.03, t)))
			t += 12.0
	var dash_mesh := BoxMesh.new()
	dash_mesh.size = Vector3(5.0, 0.02, 0.4)
	_multimesh(dash_mesh, _emit(Color(1, 1, 1), 0.5), dashes)

	# места гонок: золотые маяки на перекрёстках
	for i in 7:
		for j in 7:
			if i == 3 and j == 3:
				continue
			all_inter.append(Vector3((i - 3) * P, 0, (j - 3) * P))
	var pool: Array = all_inter.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	for k in 7:
		var done: bool = k in Game.done
		var node := _make_beacon(pool[k], Color(1.0, 0.8, 0.1))
		node.visible = not done
		race_spots.append({"pos": pool[k], "node": node, "done": done, "seen": false})

func _make_beacon(pos: Vector3, col: Color) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 3.0
	cm.bottom_radius = 3.0
	cm.height = 90.0
	cm.radial_segments = 16
	cm.rings = 1
	cm.cap_top = false
	cm.cap_bottom = false
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col.r, col.g, col.b, 0.3)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.position = Vector3(0, 45, 0)
	mi.visibility_range_end = 150.0
	n.add_child(mi)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 3.6
	tm.outer_radius = 4.4
	ring.mesh = tm
	ring.material_override = _emit(col, 3.0)
	ring.position = Vector3(0, 0.3, 0)
	n.add_child(ring)
	world.add_child(n)
	return n

# ------------------------------------------------------------ старт мира и HUD
func _start_world() -> void:
	if menu:
		menu.queue_free()
		menu = null
	_clear_world()
	_build_city()
	player = CarScript.new()
	player.setup(Game.selected, Game.levels(Game.selected))
	player.drift_done.connect(_on_drift_done)
	world.add_child(player)
	player.position = Vector3(0, 0, 30)
	_build_hud()
	state = "drive"
	snap_cam = true
	_toast("Езжай по городу и ищи золотые маяки - там начинаются гонки", 7.0)

func _respawn() -> void:
	player.global_position = Vector3(0, 0, 30)
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO

func _make_btn(id: String, text: String, rect: Rect2) -> void:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.18)
	sb.set_corner_radius_all(24)
	sb.set_border_width_all(3)
	sb.border_color = Color(1, 1, 1, 0.5)
	p.add_theme_stylebox_override("panel", sb)
	var l := _lbl(text, 28)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	hud.add_child(p)
	btn_rects[id] = rect
	btn_nodes[id] = p

func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)
	var vs := get_viewport().get_visible_rect().size
	info_label = _lbl("", 28)
	info_label.position = Vector2(24, 12)
	hud.add_child(info_label)
	speed_label = _lbl("0", 52)
	speed_label.position = Vector2(vs.x * 0.5 - 110, vs.y - 90)
	hud.add_child(speed_label)
	nitro_bar = ProgressBar.new()
	nitro_bar.position = Vector2(vs.x * 0.5 - 200, 20)
	nitro_bar.size = Vector2(400, 22)
	nitro_bar.show_percentage = false
	hud.add_child(nitro_bar)
	race_label = _lbl("", 28, Color(0.4, 0.95, 1.0))
	race_label.size = Vector2(vs.x, 40)
	race_label.position = Vector2(0, 50)
	race_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(race_label)
	arrow = Polygon2D.new()
	arrow.polygon = PackedVector2Array([Vector2(0, -30), Vector2(22, 22), Vector2(0, 10), Vector2(-22, 22)])
	arrow.color = Color(0.2, 0.9, 1.0)
	arrow.position = Vector2(vs.x * 0.5, 125)
	arrow.visible = false
	hud.add_child(arrow)
	msg_label = _lbl("", 30, Color(1, 1, 0.6))
	msg_label.size = Vector2(vs.x, 40)
	msg_label.position = Vector2(0, 175)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(msg_label)
	drift_label = _lbl("", 44, Color(1, 0.8, 0.2))
	drift_label.size = Vector2(vs.x, 60)
	drift_label.position = Vector2(0, 220)
	drift_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(drift_label)
	minimap = Control.new()
	minimap.position = Vector2(vs.x - MAP_PX - 16, 12)
	minimap.size = Vector2(MAP_PX, MAP_PX)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap.clip_contents = true
	minimap.draw.connect(_draw_minimap)
	hud.add_child(minimap)
	btn_rects.clear()
	btn_nodes.clear()
	var bh := vs.y
	_make_btn("garage", "Гараж", Rect2(24, 60, 140, 56))
	_make_btn("reset", "Сброс", Rect2(24, 124, 140, 56))
	_make_btn("left", "<", Rect2(30, bh - 190, 150, 160))
	_make_btn("right", ">", Rect2(200, bh - 190, 150, 160))
	_make_btn("gas", "ГАЗ", Rect2(vs.x - 200, bh - 230, 170, 200))
	_make_btn("brake", "СТОП", Rect2(vs.x - 390, bh - 120, 170, 90))
	_make_btn("drift", "ДРИФТ", Rect2(vs.x - 390, bh - 225, 170, 90))
	_make_btn("nitro", "НИТРО", Rect2(vs.x - 200, bh - 345, 170, 100))

func _w2m(p: Vector3) -> Vector2:
	return Vector2(MAP_PX * 0.5 + p.x * MAP_SCALE, MAP_PX * 0.5 + p.z * MAP_SCALE)

func _draw_minimap() -> void:
	if player == null:
		return
	var m := minimap
	m.draw_rect(Rect2(Vector2.ZERO, Vector2(MAP_PX, MAP_PX)), Color(0.05, 0.07, 0.1, 0.65))
	var hs := BLOCK * 0.5 * MAP_SCALE
	for b in blocks:
		var c := _w2m(Vector3(b["x"], 0, b["z"]))
		var col := Color(0.2, 0.45, 0.2, 0.8) if b["park"] else Color(0.35, 0.37, 0.42, 0.9)
		m.draw_rect(Rect2(c - Vector2(hs, hs), Vector2(hs * 2.0, hs * 2.0)), col)
	for s in race_spots:
		if s["seen"] and not s["done"]:
			m.draw_circle(_w2m(s["pos"]), 5.0, Color(1, 0.8, 0.1))
	if race_active and cp_i < cps.size():
		m.draw_circle(_w2m(cps[cp_i]), 5.0, Color(0.2, 0.9, 1.0))
	var pp := _w2m(player.global_position)
	var f: Vector3 = -player.global_transform.basis.z
	var dir := Vector2(f.x, f.z).normalized()
	var perp := Vector2(-dir.y, dir.x)
	m.draw_colored_polygon(PackedVector2Array([pp + dir * 8.0, pp - dir * 5.0 + perp * 5.0, pp - dir * 5.0 - perp * 5.0]), Color(1, 0.2, 0.2))

# ------------------------------------------------------------ ввод
func _fix_pos(p: Vector2) -> Vector2:
	var vr := get_viewport().get_visible_rect().size
	if p.x > vr.x * 1.02 or p.y > vr.y * 1.02:
		var win := Vector2(DisplayServer.window_get_size())
		return p * vr / win
	return p

func _input(event: InputEvent) -> void:
	if hud == null or state != "drive":
		return
	if event is InputEventScreenTouch:
		var pos := _fix_pos(event.position)
		if event.pressed:
			touches[event.index] = pos
			if btn_rects["garage"].has_point(pos):
				show_menu()
				return
			if btn_rects["reset"].has_point(pos):
				_respawn()
		else:
			touches.erase(event.index)
	elif event is InputEventScreenDrag:
		touches[event.index] = _fix_pos(event.position)
	else:
		return
	held.clear()
	for tp in touches.values():
		for id in btn_rects:
			if btn_rects[id].grow(20).has_point(tp):
				held[id] = true

func _control_player() -> void:
	var l := held.has("left") or Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A)
	var r := held.has("right") or Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)
	player.steer_in = float(l) - float(r)
	player.gas = 1.0 if (held.has("gas") or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W)) else 0.0
	player.brake_in = 1.0 if (held.has("brake") or Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S)) else 0.0
	player.handbrake = held.has("drift") or Input.is_key_pressed(KEY_SPACE)
	player.nitro_on = held.has("nitro") or Input.is_key_pressed(KEY_SHIFT)

func _on_drift_done(points: float) -> void:
	var gain := int(points * 0.3)
	if gain >= 20:
		Game.money += gain
		Game.save_game()
		_toast("Дрифт +$%d" % gain, 1.5)

# ------------------------------------------------------------ гонки
func _physics_process(delta: float) -> void:
	if state != "drive" or player == null:
		return
	_control_player()
	var pp := Vector3(player.global_position.x, 0, player.global_position.z)
	if race_active:
		time_left -= delta
		var tgt: Vector3 = cps[cp_i]
		if pp.distance_to(tgt) < 14.0:
			cp_i += 1
			time_left += 6.0
			if cp_i >= cps.size():
				_race_win()
				return
			beacon_cp.position = cps[cp_i]
			_toast("Точка %d/%d, +6 с" % [cp_i, cps.size()], 1.5)
		elif time_left <= 0.0:
			_race_end(false)
	else:
		for k in race_spots.size():
			var s: Dictionary = race_spots[k]
			var d := pp.distance_to(s["pos"])
			if d < 150.0:
				s["seen"] = true
			if d < 9.0 and not s["done"]:
				_race_start(k)
				break

func _race_start(k: int) -> void:
	race_active = true
	race_k = k
	var rng := RandomNumberGenerator.new()
	rng.seed = 500 + k
	cps = []
	var last: Vector3 = race_spots[k]["pos"]
	var total := 0.0
	for n in 5:
		var pick: Vector3 = all_inter[rng.randi() % all_inter.size()]
		for tries in 20:
			if absf(pick.x - last.x) + absf(pick.z - last.z) > 200.0:
				break
			pick = all_inter[rng.randi() % all_inter.size()]
		cps.append(pick)
		total += absf(pick.x - last.x) + absf(pick.z - last.z)
		last = pick
	cp_i = 0
	time_left = total / 22.0 + 25.0
	beacon_cp = _make_beacon(cps[0], Color(0.2, 0.9, 1.0))
	race_spots[k]["node"].visible = false
	_toast("ГОНКА! Проезжай голубые маяки, успей по времени", 4.0)

func _race_end(win: bool) -> void:
	race_active = false
	if beacon_cp:
		beacon_cp.queue_free()
		beacon_cp = null
	if not win:
		race_spots[race_k]["node"].visible = true
		_toast("Время вышло. Вернись на золотой маяк и попробуй снова", 4.0)

func _race_win() -> void:
	var reward := 2500 + 400 * Game.done.size()
	Game.money += reward
	Game.done.append(race_k)
	Game.save_game()
	race_spots[race_k]["done"] = true
	_race_end(true)
	_toast("ПОБЕДА! +$%d" % reward, 5.0)

# ------------------------------------------------------------ камера и HUD
func _process(delta: float) -> void:
	if state == "menu":
		if preview:
			preview.rotation.y += delta * 0.5
		cam.global_position = GARAGE + Vector3(6.5, 2.2, 6.5)
		cam.look_at(GARAGE + Vector3(0, 0.7, 0))
		cam.fov = 60.0
		return
	if player == null:
		return
	_update_camera(delta)
	_update_hud(delta)

func _update_camera(delta: float) -> void:
	var fwd: Vector3 = -player.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var vel: Vector3 = player.velocity
	vel.y = 0.0
	var dir := fwd
	if vel.length() > 8.0:
		dir = fwd.lerp(vel.normalized(), 0.4).normalized()
	var target: Vector3 = player.global_position - dir * (7.5 + clampf(player.speed * 0.03, 0.0, 2.0)) + Vector3(0, 3.2, 0)
	if snap_cam:
		cam.global_position = target
		snap_cam = false
	else:
		cam.global_position = cam.global_position.lerp(target, clampf(delta * 6.0, 0.0, 1.0))
	cam.look_at(player.global_position + Vector3(0, 1.0, 0) + dir * 5.0)
	var tf := 68.0 + clampf(absf(player.speed), 0.0, 60.0) * 0.3
	if player.nitro_on and player.nitro > 0.0:
		tf += 10.0
	cam.fov = lerpf(cam.fov, tf, clampf(delta * 3.0, 0.0, 1.0))

func _update_hud(delta: float) -> void:
	info_label.text = "Деньги: $%d" % Game.money
	speed_label.text = "%d км/ч" % int(absf(player.speed) * 3.6)
	drift_label.text = ("ДРИФТ  %d" % int(player.drift_score)) if player.drift_score > 5.0 else ""
	nitro_bar.max_value = player.nitro_max
	nitro_bar.value = player.nitro
	toast_t -= delta
	if toast_t <= 0.0:
		msg_label.text = ""
	if race_active and cp_i < cps.size():
		var tgt: Vector3 = cps[cp_i]
		var to := Vector3(tgt.x - player.global_position.x, 0.0, tgt.z - player.global_position.z)
		race_label.text = "Гонка: точка %d/%d    %d м    %d с" % [cp_i + 1, cps.size(), int(to.length()), int(maxf(time_left, 0.0))]
		var cf: Vector3 = -cam.global_transform.basis.z
		cf.y = 0.0
		arrow.visible = true
		arrow.rotation = -cf.signed_angle_to(to, Vector3.UP)
	else:
		race_label.text = ""
		arrow.visible = false
	for id in btn_nodes:
		btn_nodes[id].modulate = Color(1, 1, 1, 1.0 if held.has(id) else 0.6)
	minimap.queue_redraw()
