extends Node3D

const CarScript = preload("res://car.gd")
const R := 160.0
const ROAD_W := 24.0
const LAPS := 3
const GARAGE := Vector3(900, 0, 900)

var ui: CanvasLayer
var cam: Camera3D
var world: Node3D
var menu: Control
var hud: Control
var state := "menu"
var view_idx := 0
var preview = null
var player = null
var cars_all: Array = []
var progress: Dictionary = {}
var finished: Array = []
var countdown := 0.0
var go_hide := 0.0
var race_time := 0.0
var touches: Dictionary = {}
var held: Dictionary = {}
var btn_rects: Dictionary = {}
var btn_nodes: Dictionary = {}
var info_label: Label
var speed_label: Label
var drift_label: Label
var big_label: Label
var nitro_bar: ProgressBar
var snap_cam := true

func _ready() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_2X
	_build_environment()
	ui = CanvasLayer.new()
	add_child(ui)
	cam = Camera3D.new()
	cam.near = 0.2
	cam.far = 700.0
	add_child(cam)
	cam.make_current()
	view_idx = Game.selected
	show_menu()

# ---------------------------------------------------------------- окружение
func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.04, 0.07, 0.25)
	psm.sky_horizon_color = Color(0.95, 0.45, 0.25)
	psm.ground_horizon_color = Color(0.5, 0.3, 0.25)
	psm.ground_bottom_color = Color(0.04, 0.04, 0.07)
	sky.sky_material = psm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.8, 0.5, 0.4)
	env.fog_density = 0.0025
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.2
	env.adjustment_contrast = 1.1
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-18, -60, 0)
	sun.light_color = Color(1.0, 0.7, 0.5)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)

# ---------------------------------------------------------------- помощники
func _emit(c: Color, energy := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m

func _plain(c: Color, rough := 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
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

func _window_tex() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for cy in 8:
		for cx in 8:
			var lit := rng.randf() < 0.55
			var warm := rng.randf() < 0.7
			var c := Color(0.02, 0.03, 0.05)
			if lit:
				c = Color(1.0, 0.85, 0.5) if warm else Color(0.5, 0.9, 1.0)
			for y in 8:
				for x in 8:
					var inside := x >= 2 and x <= 5 and y >= 2 and y <= 5
					img.set_pixel(cx * 8 + x, cy * 8 + y, c if inside else Color(0.05, 0.06, 0.09))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _add_box(parent: Node, pos: Vector3, size: Vector3, m: Material, rot_y := 0.0, collide := true) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	if collide:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		cs.position = pos
		cs.rotation.y = rot_y
		parent.add_child(cs)

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	if (b - a).cross(c - a).y > 0.0:
		var t := b
		b = c
		c = t
	for p in [a, b, c]:
		st.set_normal(Vector3.UP)
		st.add_vertex(p)

func _ring_mesh(r0: float, r1: float, y: float, n: int, dashed: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		if dashed and i % 2 == 1:
			continue
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var i0 := Vector3(cos(a0) * r0, y, sin(a0) * r0)
		var o0 := Vector3(cos(a0) * r1, y, sin(a0) * r1)
		var i1 := Vector3(cos(a1) * r0, y, sin(a1) * r0)
		var o1 := Vector3(cos(a1) * r1, y, sin(a1) * r1)
		_tri(st, i0, o0, i1)
		_tri(st, o0, o1, i1)
	return st.commit()

func _add_mesh(mesh: Mesh, m: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
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
	cars_all.clear()
	progress.clear()
	finished.clear()

# ---------------------------------------------------------------- гараж
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
	fm.albedo_color = Color(0.05, 0.05, 0.07)
	fm.metallic = 0.8
	fm.roughness = 0.18
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	fl.mesh = pm
	fl.material_override = fm
	fl.position = GARAGE
	world.add_child(fl)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 3.6
	tm.outer_radius = 3.8
	ring.mesh = tm
	ring.material_override = _emit(Color(0.1, 0.8, 1.0), 3.0)
	ring.position = GARAGE + Vector3(0, 0.05, 0)
	world.add_child(ring)
	var ol := OmniLight3D.new()
	ol.position = GARAGE + Vector3(0, 5, 0)
	ol.omni_range = 20.0
	ol.light_energy = 3.0
	ol.light_color = Color(0.7, 0.8, 1.0)
	world.add_child(ol)

func _spawn_preview() -> void:
	if preview:
		preview.queue_free()
	preview = CarScript.new()
	preview.freeze = true
	preview.setup(view_idx, Game.levels(view_idx), true)
	world.add_child(preview)
	preview.position = GARAGE + Vector3(0, 0.6, 0)

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
	v.add_child(_lbl("Мощность %d   Макс. %d км/ч   Сцепление %.1f" % [int(d["power"]), int(float(d["top"]) * 3.6), float(d["grip"])], 20))
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
			var cost := Game.upgrade_cost(view_idx, k)
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
	var race := _btn("ГОНКА", 40, Vector2(300, 100))
	race.position = Vector2(vs.x - 330, vs.y - 130)
	race.disabled = not owned
	race.pressed.connect(_on_race)
	menu.add_child(race)

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

func _on_race() -> void:
	Game.selected = view_idx
	Game.save_game()
	_start_race()

# ---------------------------------------------------------------- трасса
func _build_track() -> void:
	world = Node3D.new()
	add_child(world)
	var asphalt := StandardMaterial3D.new()
	asphalt.albedo_texture = _noise_tex(Color(0.10, 0.10, 0.11), Color(0.24, 0.24, 0.26), 0.08)
	asphalt.uv1_triplanar = true
	asphalt.uv1_world_triplanar = true
	asphalt.uv1_scale = Vector3.ONE * 0.06
	asphalt.roughness = 0.4
	var grass := StandardMaterial3D.new()
	grass.albedo_texture = _noise_tex(Color(0.06, 0.10, 0.05), Color(0.16, 0.22, 0.10), 0.05)
	grass.uv1_triplanar = true
	grass.uv1_world_triplanar = true
	grass.uv1_scale = Vector3.ONE * 0.04
	grass.roughness = 1.0
	var line_m := _emit(Color(1, 1, 1), 0.6)

	var ground := StaticBody3D.new()
	world.add_child(ground)
	_add_box(ground, Vector3(0, -0.5, 0), Vector3(1600, 1, 1600), grass)

	_add_mesh(_ring_mesh(R - ROAD_W / 2.0, R + ROAD_W / 2.0, 0.02, 128, false), asphalt)
	_add_mesh(_ring_mesh(R - 0.2, R + 0.2, 0.04, 96, true), line_m)
	_add_mesh(_ring_mesh(R - ROAD_W / 2.0 + 0.4, R - ROAD_W / 2.0 + 0.9, 0.04, 128, false), line_m)
	_add_mesh(_ring_mesh(R + ROAD_W / 2.0 - 0.9, R + ROAD_W / 2.0 - 0.4, 0.04, 128, false), line_m)

	# отбойники
	var wall := StaticBody3D.new()
	world.add_child(wall)
	var red := _plain(Color(0.8, 0.05, 0.05), 0.5)
	var white := _plain(Color(0.9, 0.9, 0.9), 0.5)
	var n := 72
	for side in [-1, 1]:
		var rr: float = R + side * (ROAD_W / 2.0 + 1.0)
		var seg: float = TAU * rr / n
		for i in n:
			var a: float = TAU * (i + 0.5) / n
			var pos := Vector3(cos(a) * rr, 0.6, sin(a) * rr)
			_add_box(wall, pos, Vector3(1.0, 1.2, seg + 0.4), red if i % 2 == 0 else white, -a)

	# город
	var city := StaticBody3D.new()
	world.add_child(city)
	var tex := _window_tex()
	var bmats: Array = []
	for t in [Color(1, 1, 1), Color(0.8, 0.85, 1.0), Color(1.0, 0.9, 0.8)]:
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.albedo_color = t
		m.emission_enabled = true
		m.emission_texture = tex
		m.emission_energy_multiplier = 1.4
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * 0.036
		m.roughness = 0.5
		m.metallic = 0.3
		bmats.append(m)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 110:
		var ang := rng.randf() * TAU
		var inside := rng.randf() < 0.3
		var rad: float = rng.randf_range(15.0, R - 40.0) if inside else rng.randf_range(R + 32.0, R + 300.0)
		var bw := rng.randf_range(14.0, 34.0)
		var bd := rng.randf_range(14.0, 34.0)
		var bh := rng.randf_range(18.0, 85.0)
		_add_box(city, Vector3(cos(ang) * rad, bh * 0.5, sin(ang) * rad), Vector3(bw, bh, bd), bmats[rng.randi() % 3], rng.randf() * PI)

	# фонари
	var pole := _plain(Color(0.1, 0.1, 0.1))
	var lamp := _emit(Color(1.0, 0.8, 0.5), 3.0)
	for i in 24:
		var a2 := TAU * i / 24.0
		var r2 := R + ROAD_W / 2.0 + 3.0
		var base := Vector3(cos(a2) * r2, 0, sin(a2) * r2)
		_add_box(world, base + Vector3(0, 4, 0), Vector3(0.3, 8, 0.3), pole, 0.0, false)
		_add_box(world, base + Vector3(0, 8.2, 0), Vector3(1.4, 0.3, 1.4), lamp, 0.0, false)

	# финишная арка и шахматная линия
	var black := _plain(Color(0.02, 0.02, 0.02))
	for j in 12:
		for row in 2:
			var mat: Material = line_m if (j + row) % 2 == 0 else black
			_add_box(world, Vector3(R - ROAD_W / 2.0 + (j + 0.5) * ROAD_W / 12.0, 0.06, (row - 0.5) * 1.5), Vector3(ROAD_W / 12.0, 0.04, 1.5), mat, 0.0, false)
	for sx in [-1, 1]:
		_add_box(world, Vector3(R + sx * (ROAD_W / 2.0 + 2.0), 4.5, 0), Vector3(1, 9, 1), pole, 0.0, false)
	_add_box(world, Vector3(R, 9.2, 0), Vector3(ROAD_W + 5.0, 1.5, 1.0), _emit(Color(1.0, 0.2, 0.6), 2.5), 0.0, false)

# ---------------------------------------------------------------- гонка
func _start_race() -> void:
	if menu:
		menu.queue_free()
		menu = null
	_clear_world()
	_build_track()
	_spawn_cars()
	_build_hud()
	state = "countdown"
	countdown = 4.0
	race_time = 0.0
	snap_cam = true

func _spawn_cars() -> void:
	var slots := [[-0.035, -5.0], [-0.035, 5.0], [-0.075, -5.0], [-0.075, 5.0]]
	var tints := [Color(0.9, 0.4, 0.0), Color(0.6, 0.1, 0.8), Color(0.1, 0.7, 0.3)]
	var plv := Game.levels(Game.selected)
	var ptop: float = float(Game.cars[Game.selected]["top"]) * (1.0 + 0.03 * plv["engine"])
	var ai_i := 0
	for s in 4:
		var is_player := (s == 2)
		var c = CarScript.new()
		if is_player:
			c.setup(Game.selected, plv)
		else:
			var idx := randi() % Game.cars.size()
			c.setup(idx, {"engine": 0, "tires": 0, "nitro": 0}, true, tints[ai_i])
			c.limit_mult = ptop * randf_range(0.85, 1.02) / c.top
			c.lane = slots[s][1]
			ai_i += 1
		world.add_child(c)
		var a: float = slots[s][0]
		var r: float = R + float(slots[s][1])
		var p := Vector3(cos(a) * r, 0.7, sin(a) * r)
		c.look_at_from_position(p, p + Vector3(-sin(a), 0, cos(a)))
		c.locked = true
		cars_all.append(c)
		progress[c] = {"last": a, "total": a}
		if is_player:
			player = c

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
	info_label = _lbl("", 30)
	info_label.position = Vector2(24, 16)
	hud.add_child(info_label)
	speed_label = _lbl("0", 52)
	speed_label.position = Vector2(vs.x * 0.5 - 110, vs.y - 90)
	hud.add_child(speed_label)
	drift_label = _lbl("", 44, Color(1, 0.8, 0.2))
	drift_label.size = Vector2(vs.x, 60)
	drift_label.position = Vector2(0, 70)
	drift_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(drift_label)
	big_label = _lbl("", 110, Color(1, 1, 0.4))
	big_label.size = Vector2(vs.x, 150)
	big_label.position = Vector2(0, 170)
	big_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(big_label)
	nitro_bar = ProgressBar.new()
	nitro_bar.position = Vector2(vs.x * 0.5 - 200, 20)
	nitro_bar.size = Vector2(400, 22)
	nitro_bar.show_percentage = false
	hud.add_child(nitro_bar)
	btn_rects.clear()
	btn_nodes.clear()
	var bh := vs.y
	_make_btn("left", "<", Rect2(30, bh - 190, 150, 160))
	_make_btn("right", ">", Rect2(200, bh - 190, 150, 160))
	_make_btn("gas", "ГАЗ", Rect2(vs.x - 200, bh - 230, 170, 200))
	_make_btn("brake", "СТОП", Rect2(vs.x - 390, bh - 120, 170, 90))
	_make_btn("drift", "ДРИФТ", Rect2(vs.x - 390, bh - 225, 170, 90))
	_make_btn("nitro", "НИТРО", Rect2(vs.x - 200, bh - 345, 170, 100))

func _input(event: InputEvent) -> void:
	if hud == null or (state != "race" and state != "countdown"):
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
		else:
			touches.erase(event.index)
	elif event is InputEventScreenDrag:
		touches[event.index] = event.position
	else:
		return
	held.clear()
	for pos in touches.values():
		for id in btn_rects:
			if btn_rects[id].grow(20).has_point(pos):
				held[id] = true

func _control_player() -> void:
	var l := held.has("left") or Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A)
	var r := held.has("right") or Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)
	player.steer_in = float(l) - float(r)
	player.gas = 1.0 if (held.has("gas") or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W)) else 0.0
	player.brake_in = 1.0 if (held.has("brake") or Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S)) else 0.0
	player.handbrake = held.has("drift") or Input.is_key_pressed(KEY_SPACE)
	player.nitro_on = held.has("nitro") or Input.is_key_pressed(KEY_SHIFT)

func _control_ai(c) -> void:
	var a := atan2(c.global_position.z, c.global_position.x)
	var ta: float = a + 0.10 + clampf(c.speed / 60.0, 0.0, 1.0) * 0.08
	var tr: float = R + c.lane
	var target := Vector3(cos(ta) * tr, 0, sin(ta) * tr)
	var loc: Vector3 = c.to_local(target)
	var ang := atan2(-loc.x, -loc.z)
	c.steer_in = clampf(ang * 2.0, -1.0, 1.0)
	c.gas = 1.0 - absf(c.steer_in) * 0.5
	c.brake_in = 0.0
	c.handbrake = false

func _physics_process(delta: float) -> void:
	if state == "countdown":
		countdown -= delta
		if countdown <= 1.0:
			state = "race"
			go_hide = 1.0
			big_label.text = "СТАРТ!"
			for c in cars_all:
				c.locked = false
		else:
			big_label.text = str(int(ceil(countdown - 1.0)))
		return
	if state != "race" and state != "done":
		return
	if state == "race":
		race_time += delta
		go_hide -= delta
		if go_hide <= 0.0:
			big_label.text = ""
		_control_player()
	for c in cars_all:
		if c != player:
			_control_ai(c)
	for c in cars_all:
		var p: Dictionary = progress[c]
		var a := atan2(c.global_position.z, c.global_position.x)
		p["total"] += wrapf(a - p["last"], -PI, PI)
		p["last"] = a
		if not (c in finished) and p["total"] >= LAPS * TAU:
			finished.append(c)
			if c == player:
				_finish_player()

func _finish_player() -> void:
	state = "done"
	held.clear()
	touches.clear()
	player.gas = 0.0
	player.steer_in = 0.0
	player.brake_in = 0.6
	player.handbrake = false
	player.nitro_on = false
	player.drift_bank += player.drift_score
	player.drift_score = 0.0
	var place: int = finished.find(player) + 1
	var prizes := [4000, 2500, 1500, 800]
	var prize: int = prizes[clampi(place - 1, 0, 3)]
	var dmoney := int(player.drift_bank * 0.5)
	Game.money += prize + dmoney
	Game.save_game()
	var vs := get_viewport().get_visible_rect().size
	var panel := PanelContainer.new()
	panel.position = Vector2(vs.x * 0.5 - 220, 110)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	v.add_child(_lbl("ФИНИШ! Место: %d" % place, 46, Color(1, 0.85, 0.3)))
	v.add_child(_lbl("Время: %s" % _fmt_time(race_time), 28))
	v.add_child(_lbl("Приз: $%d" % prize, 28, Color(0.5, 1, 0.5)))
	v.add_child(_lbl("Дрифт: +$%d" % dmoney, 28, Color(0.5, 1, 0.5)))
	var b := _btn("В гараж", 30, Vector2(300, 70))
	b.pressed.connect(show_menu)
	v.add_child(b)
	hud.add_child(panel)

func _fmt_time(t: float) -> String:
	return "%d:%05.2f" % [floori(t / 60.0), fmod(t, 60.0)]

# ---------------------------------------------------------------- камера и HUD
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
	_update_hud()

func _update_camera(delta: float) -> void:
	var fwd: Vector3 = -player.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var vel: Vector3 = player.linear_velocity
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

func _update_hud() -> void:
	var pt: float = progress[player]["total"]
	var place := 1
	for c in cars_all:
		if c != player and progress[c]["total"] > pt:
			place += 1
	var lap := clampi(int(floor(pt / TAU)) + 1, 1, LAPS)
	info_label.text = "Место %d/%d    Круг %d/%d    %s" % [place, cars_all.size(), lap, LAPS, _fmt_time(race_time)]
	speed_label.text = "%d км/ч" % int(absf(player.speed) * 3.6)
	drift_label.text = ("ДРИФТ  %d" % int(player.drift_score)) if player.drift_score > 5.0 else ""
	nitro_bar.max_value = player.nitro_max
	nitro_bar.value = player.nitro
	for id in btn_nodes:
		btn_nodes[id].modulate = Color(1, 1, 1, 1.0 if held.has(id) else 0.6)
