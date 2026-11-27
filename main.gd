extends Node3D

const CityScript = preload("res://city.gd")
const PlayerScript = preload("res://player.gd")
const BotScript = preload("res://bot.gd")
const HudScript = preload("res://hud.gd")
const InvScript = preload("res://inventory.gd")

var state := "menu"
var inv_return := "menu"
var player = null
var hud = null
var inv_ui = null
var menu_ui: Control
var ui: CanvasLayer
var menu_cam: Camera3D
var spawns: Array = []
var bots: Array = []
var wave := 0
var kills := 0
var wave_timer := 0.0
var wave_pending := false
var respawn_t := 0.0
var orbit_t := 0.0
var kb_fire := false
var kb_aim := false
var kb_crouch := false

func _ready() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_2X
	get_viewport().scaling_3d_scale = G.res
	_build_env()
	var info: Dictionary = CityScript.build(self)
	spawns = info["spawns"]
	ui = CanvasLayer.new()
	add_child(ui)
	player = PlayerScript.new()
	add_child(player)
	player.position = Vector3(0, 0.5, 2)
	player.died.connect(_on_player_died)
	menu_cam = Camera3D.new()
	menu_cam.far = 600.0
	add_child(menu_cam)
	hud = HudScript.new()
	hud.player = player
	hud.main = self
	ui.add_child(hud)
	player.hit_marker.connect(hud.on_hit)
	inv_ui = InvScript.new()
	inv_ui.main = self
	ui.add_child(inv_ui)
	inv_ui.visible = false
	_build_menu()
	show_menu()

func _build_env() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.16, 0.18, 0.28)
	psm.sky_horizon_color = Color(0.85, 0.5, 0.35)
	psm.ground_horizon_color = Color(0.5, 0.35, 0.3)
	psm.ground_bottom_color = Color(0.1, 0.09, 0.1)
	sky.sky_material = psm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.6, 0.42, 0.35)
	env.fog_density = 0.006
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.1
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-14, -50, 0)
	sun.light_color = Color(1.0, 0.62, 0.4)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)

# ------------------------------------------------------------ меню
func _build_menu() -> void:
	menu_ui = Control.new()
	menu_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(menu_ui)
	var panel := ColorRect.new()
	panel.color = Color(0.04, 0.03, 0.08, 0.6)
	panel.position = Vector2(0, 0)
	panel.size = Vector2(520, 720)
	menu_ui.add_child(panel)
	var title := Label.new()
	title.text = "РУИНЫ"
	title.position = Vector2(40, 60)
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0))
	menu_ui.add_child(title)
	var sub := Label.new()
	sub.text = "Шутер от первого лица. Заброшенный город."
	sub.position = Vector2(44, 150)
	sub.add_theme_font_size_override("font_size", 18)
	menu_ui.add_child(sub)
	var play := Button.new()
	play.text = "ИГРАТЬ"
	play.position = Vector2(40, 230)
	play.size = Vector2(400, 80)
	play.add_theme_font_size_override("font_size", 30)
	play.pressed.connect(start_game)
	menu_ui.add_child(play)
	var inv := Button.new()
	inv.text = "ИНВЕНТАРЬ И НАСТРОЙКИ"
	inv.position = Vector2(40, 330)
	inv.size = Vector2(400, 70)
	inv.add_theme_font_size_override("font_size", 22)
	inv.pressed.connect(open_inventory)
	menu_ui.add_child(inv)
	var hint := Label.new()
	hint.text = "Клавиатура и мышь поддерживаются:\nпри подключении экранные кнопки скрываются.\nWASD, мышь, R, 1/2/3, Shift, Space, C, Tab."
	hint.position = Vector2(44, 440)
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	menu_ui.add_child(hint)

func _set_player_active(on: bool) -> void:
	player.visible = on
	player.set_process(on)
	player.set_physics_process(on)

func show_menu() -> void:
	state = "menu"
	hud.visible = false
	menu_ui.visible = true
	inv_ui.visible = false
	for b in bots:
		if is_instance_valid(b):
			b.queue_free()
	bots.clear()
	_set_player_active(false)
	menu_cam.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false

func start_game() -> void:
	state = "play"
	menu_ui.visible = false
	inv_ui.visible = false
	hud.visible = true
	_set_player_active(true)
	player.reset(Vector3(0, 0.5, 2))
	player.cam.make_current()
	wave = 0
	kills = 0
	hud.kills = 0
	hud.wave = 0
	wave_pending = false
	for b in bots:
		if is_instance_valid(b):
			b.queue_free()
	bots.clear()
	get_tree().paused = false
	_capture(true)
	_next_wave()

func _capture(on: bool) -> void:
	if on and G.kbm:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# ------------------------------------------------------------ инвентарь и раскладка
func open_inventory() -> void:
	inv_return = state
	state = "inv"
	get_tree().paused = true
	hud.visible = false
	menu_ui.visible = false
	inv_ui.visible = true
	inv_ui.refresh()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_inventory() -> void:
	G.save_data()
	inv_ui.visible = false
	get_tree().paused = false
	if inv_return == "play":
		state = "play"
		hud.visible = true
		player.load_loadout()
		_capture(true)
	else:
		state = "menu"
		menu_ui.visible = true

func edit_layout() -> void:
	inv_ui.visible = false
	hud.visible = true
	hud.edit_mode = true

func finish_layout_edit() -> void:
	hud.edit_mode = false
	hud.visible = false
	inv_ui.visible = true
	G.save_data()

# ------------------------------------------------------------ волны ботов
func _next_wave() -> void:
	wave += 1
	hud.wave = wave
	hud.show_msg("Волна %d" % wave, 3.0)
	var count := mini(3 + wave * 2, 12)
	var palette := [Color(0.28, 0.33, 0.25), Color(0.35, 0.3, 0.22), Color(0.25, 0.27, 0.32), Color(0.4, 0.22, 0.2)]
	for i in count:
		var pos := Vector3.ZERO
		for t in 20:
			var sp: Vector3 = spawns[randi() % spawns.size()]
			pos = sp
			if sp.distance_to(player.global_position) > 50.0:
				break
		var b = BotScript.new()
		b.tint = palette[randi() % palette.size()]
		b.player = player
		add_child(b)
		b.global_position = pos + Vector3(randf_range(-3.0, 3.0), 0.3, randf_range(-3.0, 3.0))
		b.killed.connect(_on_bot_killed)
		bots.append(b)

func _on_bot_killed(b) -> void:
	bots.erase(b)
	kills += 1
	hud.kills = kills
	if bots.is_empty():
		wave_pending = true
		wave_timer = 3.0
		hud.show_msg("Волна зачищена", 2.5)

func _on_player_died() -> void:
	hud.show_msg("Вы погибли", 3.0)
	respawn_t = 3.0
	player.fire_held = false

# ------------------------------------------------------------ кадр
func _process(delta: float) -> void:
	if state == "menu":
		orbit_t += delta * 0.15
		menu_cam.global_position = Vector3(cos(orbit_t) * 110.0, 28.0, sin(orbit_t) * 110.0)
		menu_cam.look_at(Vector3(0, 6, 0))
		return
	if state != "play":
		return
	if G.kbm:
		var mv := Vector2(float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)), float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S)))
		player.move_in = mv
		player.sprint_in = Input.is_key_pressed(KEY_SHIFT)
		player.want_crouch = kb_crouch or Input.is_key_pressed(KEY_CTRL)
		player.fire_held = kb_fire
		player.aim_held = kb_aim
	else:
		hud.apply()
	if respawn_t > 0.0:
		respawn_t -= delta
		if respawn_t <= 0.0:
			player.reset(Vector3(0, 0.5, 2))
			hud.show_msg("Возрождение", 1.5)
	if wave_pending:
		wave_timer -= delta
		if wave_timer <= 0.0:
			wave_pending = false
			_next_wave()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		G.kbm = false
		kb_fire = false
		kb_aim = false
		return
	var real := false
	if event is InputEventMouse or event is InputEventKey:
		real = event.device != -1
	if not real:
		return
	if not G.kbm:
		G.kbm = true
		if state == "play":
			_capture(true)
	if state != "play":
		return
	if event is InputEventMouseMotion:
		player.look_in += event.relative
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			kb_fire = event.pressed
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			kb_aim = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			player.switch_to(clampi(player.cur - 1, 0, 2))
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			player.switch_to(clampi(player.cur + 1, 0, 2))
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				player.do_reload()
			KEY_1:
				player.switch_to(0)
			KEY_2:
				player.switch_to(1)
			KEY_3:
				player.switch_to(2)
			KEY_SPACE:
				player.do_jump()
			KEY_C:
				kb_crouch = not kb_crouch
			KEY_TAB, KEY_ESCAPE, KEY_I:
				open_inventory()
