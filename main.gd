extends Node3D
# Street Racer: Open World — открытый город, гонки нужно искать

const City = preload("res://city.gd")
const CarVisual = preload("res://car_visual.gd")
const PlayerCar = preload("res://car.gd")
const Hud = preload("res://hud.gd")

const SPAWN_CELL := Vector2i(4, 6)
const RACE_COUNT := 6
const SAVE_PATH := "user://save.json"

enum RS { IDLE, COUNTDOWN, RUNNING }

var rng := RandomNumberGenerator.new()
var fx_rng := RandomNumberGenerator.new()
var city
var car
var hud
var cam: Camera3D
var cam_yaw := 0.0

var races: Array = []
var state: int = RS.IDLE
var cur_race := -1
var route: Array = []
var next_cp := 1
var race_time := 0.0
var countdown := 0.0
var rival: Node3D = null
var rival_v = null
var rival_idx := 1
var rival_speed := 36.0
var rival_cur := 0.0
var beacon: Node3D
var money := 0


func _ready() -> void:
	process_physics_priority = 100
	rng.seed = 7741
	fx_rng.randomize()
	_setup_environment()
	city = City.new()
	add_child(city)
	city.build(rng)
	_spawn_car()
	hud = Hud.new()
	add_child(hud)
	_setup_camera()
	_setup_races()
	beacon = _make_beacon(Color(0.2, 0.8, 1.0), 6.0)
	beacon.visible = false
	add_child(beacon)
	_load_game()
	hud.show_msg("Исследуй город!\nИщи светящиеся кольца — это начало гонок", 6.0)


# ---------------------------------------------------------------- мир

func _setup_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.20, 0.45, 0.85)
	sky_mat.sky_horizon_color = Color(0.72, 0.84, 0.95)
	sky_mat.sky_curve = 0.18
	sky_mat.ground_horizon_color = Color(0.72, 0.84, 0.95)
	sky_mat.ground_bottom_color = Color(0.35, 0.38, 0.42)
	sky_mat.sun_angle_max = 40.0
	sky_mat.sun_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.74, 0.83, 0.93)
	env.fog_density = 0.0008
	env.fog_sky_affect = 0.25
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35.0, 160.0, 0.0)
	sun.light_color = Color(1.0, 0.93, 0.8)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 180.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)


func _spawn_car() -> void:
	car = PlayerCar.new()
	add_child(car)
	car.place(_spawn_pos(), 0.0)


func _spawn_pos() -> Vector3:
	return City.cell_to_pos(SPAWN_CELL.x, SPAWN_CELL.y) + Vector3(4.5, 0.1, 0.0)


func _setup_camera() -> void:
	cam = Camera3D.new()
	cam.near = 0.2
	cam.far = 900.0
	cam.fov = 72.0
	add_child(cam)
	cam.current = true
	cam_yaw = car.rotation.y
	_update_camera(0.016, true)


func _update_camera(delta: float, snap: bool = false) -> void:
	var k: float = 1.0 if snap else 1.0 - exp(-4.5 * delta)
	cam_yaw = lerp_angle(cam_yaw, car.rotation.y, k)
	var spd: float = absf(car.speed_fwd)
	var dist: float = 6.4 + spd * 0.035
	var behind := Vector3(sin(cam_yaw), 0.0, cos(cam_yaw))
	var cpos: Vector3 = car.position
	cam.position = cpos + behind * dist + Vector3(0.0, 2.3 + spd * 0.01, 0.0)
	cam.look_at(cpos + Vector3(0.0, 1.2, 0.0), Vector3.UP)
	cam.fov = lerpf(cam.fov, 70.0 + clampf(spd, 0.0, 70.0) * 0.28, 1.0 - exp(-3.0 * delta))


# ---------------------------------------------------------------- гонки

func _make_beacon(col: Color, radius: float) -> Node3D:
	var n := Node3D.new()
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = col
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = radius - 0.45
	tm.outer_radius = radius + 0.45
	tm.rings = 40
	tm.ring_segments = 8
	ring.mesh = tm
	ring.material_override = ring_mat
	ring.position = Vector3(0, 0.6, 0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(ring)

	var beam_mat := StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam_mat.albedo_color = Color(col.r, col.g, col.b, 0.16)
	var beam := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 30.0
	cm.radial_segments = 24
	cm.cap_top = false
	cm.cap_bottom = false
	beam.mesh = cm
	beam.material_override = beam_mat
	beam.position = Vector3(0, 15.0, 0)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(beam)
	n.set_meta("ring_mat", ring_mat)
	n.set_meta("beam_mat", beam_mat)
	return n


func _set_beacon_color(n: Node3D, col: Color) -> void:
	var rm: StandardMaterial3D = n.get_meta("ring_mat")
	var bm: StandardMaterial3D = n.get_meta("beam_mat")
	rm.albedo_color = col
	bm.albedo_color = Color(col.r, col.g, col.b, 0.16)


func _cell_dist(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func _setup_races() -> void:
	var chosen: Array[Vector2i] = []
	var tries := 0
	while chosen.size() < RACE_COUNT and tries < 1000:
		tries += 1
		var c := Vector2i(rng.randi_range(0, City.GRID - 1), rng.randi_range(0, City.GRID - 1))
		if _cell_dist(c, SPAWN_CELL) < 3:
			continue
		var ok := true
		for o in chosen:
			if _cell_dist(c, o) < 3:
				ok = false
				break
		if ok:
			chosen.append(c)
	for c in chosen:
		var pos: Vector3 = City.cell_to_pos(c.x, c.y)
		var n := _make_beacon(Color(1.0, 0.8, 0.1), 6.5)
		n.position = pos
		add_child(n)
		races.append({
			"pos": pos, "found": false, "done": false, "armed": true,
			"node": n, "route": _build_route(c)})


func _build_route(start: Vector2i) -> Array:
	var cells: Array[Vector2i] = [start]
	var cur := start
	var horiz: bool = rng.randf() < 0.5
	var legs := 0
	var guard := 0
	while legs < 5 and guard < 200:
		guard += 1
		var n: int = rng.randi_range(2, 4)
		var sgn: int = 1 if rng.randf() < 0.5 else -1
		var dir := Vector2i(sgn, 0) if horiz else Vector2i(0, sgn)
		var nxt: Vector2i = cur + dir * n
		if not _cell_ok(nxt):
			nxt = cur - dir * n
			if not _cell_ok(nxt):
				continue
		cells.append(nxt)
		cur = nxt
		legs += 1
		horiz = not horiz
	var pts: Array = []
	for c in cells:
		pts.append(City.cell_to_pos(c.x, c.y))
	return pts


func _cell_ok(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < City.GRID and c.y < City.GRID


func _count_found() -> int:
	var n := 0
	for r in races:
		if r["found"]:
			n += 1
	return n


func _check_races() -> void:
	for i in range(races.size()):
		var r: Dictionary = races[i]
		var p: Vector3 = r["pos"]
		var d: float = Vector2(car.position.x - p.x, car.position.z - p.z).length()
		if not r["found"] and d < 110.0:
			r["found"] = true
			hud.show_msg("Найдена гонка! (%d / %d)\nЗаедь в кольцо, чтобы начать" % [_count_found(), races.size()], 4.0)
			_save_game()
		if d > 30.0:
			r["armed"] = true
		if state == RS.IDLE and r["armed"] and d < 7.5:
			_start_race(i)
			return


func _start_race(i: int) -> void:
	cur_race = i
	var r: Dictionary = races[i]
	route = r["route"]
	state = RS.COUNTDOWN
	countdown = 3.99
	next_cp = 1
	race_time = 0.0
	var dir: Vector3 = (route[1] - route[0]).normalized()
	var right: Vector3 = dir.cross(Vector3.UP)
	var yaw: float = atan2(-dir.x, -dir.z)
	car.place(route[0] + right * 3.0, yaw)
	car.locked = true
	cam_yaw = yaw
	_make_rival(route[0] - right * 3.0, yaw)
	beacon.position = route[1]
	beacon.visible = true
	hud.show_msg("Гонка! Проезжай чекпоинты по порядку", 3.0)


func _make_rival(pos: Vector3, yaw: float) -> void:
	if rival != null:
		rival.queue_free()
	rival = Node3D.new()
	var v = CarVisual.new()
	rival.add_child(v)
	v.setup(Color(0.75, 0.05, 0.07), Color(0.08, 0.08, 0.09))
	rival.position = pos
	rival.rotation.y = yaw
	add_child(rival)
	rival_v = v
	rival_idx = 1
	rival_speed = fx_rng.randf_range(34.0, 42.0)
	rival_cur = 0.0


func _update_rival(delta: float) -> void:
	if rival == null:
		return
	var tgt: Vector3 = route[rival_idx]
	var prev: Vector3 = route[rival_idx - 1]
	var leg: Vector3 = (tgt - prev).normalized()
	var aim: Vector3 = tgt - leg.cross(Vector3.UP) * 3.0
	var to: Vector3 = aim - rival.position
	to.y = 0.0
	if to.length() < 6.0:
		rival_idx += 1
		if rival_idx >= route.size():
			_race_end(false, "Соперник приехал первым!")
		return
	var want: float = atan2(-to.x, -to.z)
	var diff: float = absf(angle_difference(rival.rotation.y, want))
	rival.rotation.y = lerp_angle(rival.rotation.y, want, 1.0 - exp(-4.0 * delta))
	var f: float = clampf(1.0 - diff / PI * 0.9, 0.4, 1.0)
	rival_cur = move_toward(rival_cur, rival_speed * f, 20.0 * delta)
	var fwd: Vector3 = -rival.global_transform.basis.z
	rival.position += fwd * rival_cur * delta
	rival_v.update_wheels(rival_cur, 0.0, delta)


func _update_race(delta: float) -> void:
	if state == RS.COUNTDOWN:
		countdown -= delta
		if countdown <= 0.0:
			state = RS.RUNNING
			car.locked = false
			hud.show_big("СТАРТ!", 1.0)
		else:
			hud.show_big(str(ceili(countdown)))
	elif state == RS.RUNNING:
		race_time += delta
		_update_rival(delta)
		if state != RS.RUNNING:
			return
		var cp: Vector3 = route[next_cp]
		var d: float = Vector2(car.position.x - cp.x, car.position.z - cp.z).length()
		if d < 12.0:
			next_cp += 1
			if next_cp >= route.size():
				_race_end(true, "ПОБЕДА!")
				return
			beacon.position = route[next_cp]
		hud.set_race_text("Чекпоинт %d / %d\nВремя %.1f" % [next_cp, route.size() - 1, race_time])
		if race_time > 240.0:
			_race_end(false, "Время вышло")


func _race_end(win: bool, msg: String) -> void:
	state = RS.IDLE
	car.locked = false
	beacon.visible = false
	hud.set_race_text("")
	hud.show_big("")
	if rival != null:
		rival.queue_free()
		rival = null
	var r: Dictionary = races[cur_race]
	r["armed"] = false
	if win:
		var reward: int = 1000 + int(maxf(0.0, 60.0 - race_time)) * 20
		money += reward
		r["done"] = true
		_set_beacon_color(r["node"], Color(0.2, 1.0, 0.4))
		hud.show_msg("%s\nВремя: %.1f с   +$%d" % [msg, race_time, reward], 5.0)
	else:
		hud.show_msg(msg, 4.0)
	_save_game()


# ---------------------------------------------------------------- сохранение

func _save_game() -> void:
	var found: Array = []
	var done: Array = []
	for i in range(races.size()):
		if races[i]["found"]:
			found.append(i)
		if races[i]["done"]:
			done.append(i)
	var data := {"money": money, "found": found, "done": done}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))
		f.close()


func _load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	money = int(parsed.get("money", 0))
	for i in parsed.get("found", []):
		var idx: int = int(i)
		if idx >= 0 and idx < races.size():
			races[idx]["found"] = true
	for i in parsed.get("done", []):
		var idx2: int = int(i)
		if idx2 >= 0 and idx2 < races.size():
			races[idx2]["done"] = true
			_set_beacon_color(races[idx2]["node"], Color(0.2, 1.0, 0.4))


# ---------------------------------------------------------------- цикл

func _physics_process(delta: float) -> void:
	var c = hud.controls
	car.in_steer = c.steer
	car.in_gas = c.gas
	car.in_brake = c.brake
	car.in_hand = c.hand
	car.in_nitro = c.nitro
	if car.position.y < -5.0:
		car.place(_spawn_pos(), 0.0)
	_check_races()
	_update_race(delta)
	_update_camera(delta)


func _process(_delta: float) -> void:
	var kmh: float = absf(car.speed_fwd) * 3.6
	hud.set_stats(kmh, car.nitro, money, _count_found(), races.size())
	var list: Array = []
	for r in races:
		if r["found"]:
			var col := Color(0.2, 1.0, 0.4) if r["done"] else Color(1.0, 0.8, 0.1)
			list.append([r["pos"], col, false])
	if state != RS.IDLE:
		list.append([route[next_cp], Color(0.2, 0.8, 1.0), true])
	var mm = hud.minimap
	mm.player_pos = car.position
	mm.player_yaw = car.rotation.y
	mm.markers = list
	mm.queue_redraw()
