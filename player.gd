extends CharacterBody3D

const WM = preload("res://weapon_model.gd")

signal died
signal hit_marker(kill)

var cam: Camera3D
var head: Node3D
var weapon_root: Node3D
var shape: CapsuleShape3D
var body_cs: CollisionShape3D
var model: Node3D = null
var flash: Node3D = null

var move_in := Vector2.ZERO
var look_in := Vector2.ZERO
var fire_held := false
var aim_held := false
var sprint_in := false
var want_crouch := false

var yaw := 0.0
var pitch := 0.0
var health := 100.0
var regen_wait := 0.0
var damage_flash := 0.0
var crouch_k := 0.0
var bob_t := 0.0
var recoil_v := 0.0
var ads_k := 0.0
var sprint_k := 0.0
var sway := Vector2.ZERO
var land_dip := 0.0
var was_floor := true
var jump_req := false
var sprinting := false

var inv: Array = []
var cur := 0
var state := "idle"
var state_t := 0.0
var state_dur := 1.0
var fire_cd := 0.0
var fire_prev := false
var knife_done := false
var click1 := false
var click2 := false
var pump_t := 0.0
var stats: Dictionary = {}
var mag_node: Node3D = null
var pump_node: Node3D = null
var mag_base := Vector3.ZERO
var pump_base := Vector3.ZERO
var muzzle: Node3D = null
var sight_y := 0.075

func _ready() -> void:
	collision_layer = 16
	collision_mask = 1
	body_cs = CollisionShape3D.new()
	shape = CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.8
	body_cs.shape = shape
	body_cs.position = Vector3(0, 0.9, 0)
	add_child(body_cs)
	head = Node3D.new()
	head.position = Vector3(0, 1.6, 0)
	add_child(head)
	cam = Camera3D.new()
	cam.near = 0.03
	cam.far = 400.0
	cam.fov = G.fov
	head.add_child(cam)
	cam.make_current()
	weapon_root = Node3D.new()
	cam.add_child(weapon_root)
	load_loadout()

func reset(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	health = 100.0
	damage_flash = 0.0
	yaw = 0.0
	pitch = 0.0
	load_loadout()

func load_loadout() -> void:
	inv = []
	for wid in [G.slot1, G.slot2]:
		var st: Dictionary = G.stats(wid)
		inv.append({"id": wid, "ammo": int(st["mag"])})
	inv.append({"id": "knife", "ammo": 0})
	_equip(0)

func _equip(i: int) -> void:
	cur = i
	if model != null:
		model.queue_free()
		model = null
	var id: String = inv[i]["id"]
	if id == "knife":
		model = WM.build_knife()
		stats = {"name": "Нож", "zoom": 1.0, "reload": 0.0, "mag": 0, "rpm": 100.0, "recoil": 0.0, "noise": 20.0, "dmg": 70.0, "spread": 0.0, "pellets": 1, "auto": false}
	else:
		model = WM.build(id, G.att.get(id, {}))
		stats = G.stats(id)
	weapon_root.add_child(model)
	mag_node = model.get_node_or_null("Mag")
	pump_node = model.get_node_or_null("Pump")
	muzzle = model.get_node_or_null("Muzzle")
	flash = model.get_node_or_null("Muzzle/Flash")
	if mag_node != null:
		mag_base = mag_node.position
	if pump_node != null:
		pump_base = pump_node.position
	sight_y = float(model.get_meta("sight_y", 0.075))
	state = "switch"
	state_t = 0.0
	state_dur = 0.4

# ------------------------------------------------------------ действия
func switch_to(i: int) -> void:
	if i == cur or i < 0 or i > 2:
		return
	_equip(i)

func do_jump() -> void:
	jump_req = true

func do_reload() -> void:
	if cur == 2 or state != "idle":
		return
	if int(inv[cur]["ammo"]) >= int(stats["mag"]):
		return
	state = "reload"
	state_t = 0.0
	state_dur = float(stats["reload"])
	click1 = false
	click2 = false

func scoped() -> bool:
	return ads_k > 0.9 and cur != 2 and float(stats.get("zoom", 1.0)) >= 2.9

func take_damage(d: float, _from: Vector3) -> void:
	if health <= 0.0:
		return
	health -= d
	regen_wait = 5.0
	damage_flash = minf(1.0, damage_flash + d * 0.04)
	G.play(G.sfx["thud"], -4.0)
	if health <= 0.0:
		died.emit()

# ------------------------------------------------------------ стрельба
func _shoot() -> void:
	var w: Dictionary = stats
	inv[cur]["ammo"] = int(inv[cur]["ammo"]) - 1
	fire_cd = 60.0 / float(w["rpm"])
	recoil_v = clampf(recoil_v + float(w["recoil"]), 0.0, 4.0)
	var aim_mul := 0.6 if ads_k > 0.5 else 1.0
	pitch += deg_to_rad(0.35 * float(w["recoil"])) * aim_mul
	yaw += deg_to_rad(randf_range(-0.12, 0.12)) * float(w["recoil"])
	var moving := Vector2(velocity.x, velocity.z).length()
	var spread := float(w["spread"]) * (0.35 if ads_k > 0.5 else 1.0) * (1.0 + moving / 7.0)
	var origin := cam.global_position
	var bas := cam.global_transform.basis
	for i in int(w["pellets"]):
		var dir: Vector3 = -bas.z + bas.x * randf_range(-spread, spread) + bas.y * randf_range(-spread, spread)
		_hitscan(origin, dir.normalized(), float(w["dmg"]))
	if flash != null:
		flash.visible = true
		flash.rotation.z = randf() * TAU
		get_tree().create_timer(0.04).timeout.connect(_hide_flash)
	var silenced := float(w["noise"]) < 30.0
	G.play(G.sfx["shot_s"] if silenced else G.sfx["shot"], -4.0)
	get_tree().call_group("bots", "hear", global_position, float(w["noise"]))
	if str(inv[cur]["id"]) == "shotgun":
		pump_t = 1.0

func _hide_flash() -> void:
	if flash != null and is_instance_valid(flash):
		flash.visible = false

func _hitscan(origin: Vector3, dir: Vector3, dmg: float) -> void:
	var space := get_world_3d().direct_space_state
	var to := origin + dir * 200.0
	var q := PhysicsRayQueryParameters3D.create(origin, to, 3)
	q.collide_with_areas = true
	var r := space.intersect_ray(q)
	var end := to
	if not r.is_empty():
		end = r["position"]
		var col = r["collider"]
		if col is Area3D and col.has_meta("bot"):
			var bot = col.get_meta("bot")
			if is_instance_valid(bot):
				var killed: bool = bot.hit(str(col.get_meta("part")), dmg, end, dir)
				hit_marker.emit(killed)
		else:
			G.spark(end)
	var from := cam.global_position + dir * 0.5
	if muzzle != null:
		from = muzzle.global_position
	G.tracer(from, end)

func _knife_attack() -> void:
	state = "knife"
	state_t = 0.0
	state_dur = 0.45
	knife_done = false
	fire_cd = 0.5
	G.play(G.sfx["swish"], -2.0)

func _knife_hit() -> void:
	var space := get_world_3d().direct_space_state
	var origin := cam.global_position
	var dir := -cam.global_transform.basis.z
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * 2.6, 3)
	q.collide_with_areas = true
	var r := space.intersect_ray(q)
	if r.is_empty():
		return
	var col = r["collider"]
	if col is Area3D and col.has_meta("bot"):
		var bot = col.get_meta("bot")
		if is_instance_valid(bot):
			var killed: bool = bot.hit(str(col.get_meta("part")), 70.0, r["position"], dir)
			hit_marker.emit(killed)

# ------------------------------------------------------------ кадры: взгляд, оружие, анимации
func _process(delta: float) -> void:
	var zoom := float(stats.get("zoom", 1.0))
	if cur == 2:
		zoom = 1.0
	var sens := deg_to_rad(G.sens) / (1.0 + (zoom - 1.0) * ads_k * 0.6)
	yaw -= look_in.x * sens
	pitch = clampf(pitch - look_in.y * sens, -1.5, 1.5)
	var last_look := look_in
	look_in = Vector2.ZERO
	rotation.y = yaw
	head.rotation.x = pitch

	if state != "idle":
		state_t += delta
		_state_events()
		if state_t >= state_dur:
			_state_end()
	fire_cd = maxf(0.0, fire_cd - delta)
	if health > 0.0:
		var can_fire := state == "idle" and fire_cd <= 0.0
		if fire_held and can_fire:
			if cur == 2:
				if not fire_prev:
					_knife_attack()
			elif int(inv[cur]["ammo"]) <= 0:
				if not fire_prev:
					do_reload()
			elif bool(stats["auto"]) or not fire_prev:
				_shoot()
	fire_prev = fire_held

	regen_wait = maxf(0.0, regen_wait - delta)
	if regen_wait <= 0.0 and health > 0.0 and health < 100.0:
		health = minf(100.0, health + 10.0 * delta)
	damage_flash = maxf(0.0, damage_flash - delta * 1.5)

	_animate(delta, zoom, last_look)

func _state_events() -> void:
	if state == "reload":
		var t := state_t / maxf(state_dur, 0.01)
		if not click1 and t > 0.3:
			click1 = true
			G.play(G.sfx["click"], -6.0)
		if not click2 and t > 0.7:
			click2 = true
			G.play(G.sfx["click"], -6.0)
	elif state == "knife":
		if not knife_done and state_t > 0.15:
			knife_done = true
			_knife_hit()

func _state_end() -> void:
	if state == "reload":
		inv[cur]["ammo"] = int(stats["mag"])
	state = "idle"
	state_t = 0.0
	if mag_node != null:
		mag_node.position = mag_base
		mag_node.visible = true

func _animate(delta: float, zoom: float, last_look: Vector2) -> void:
	var moving := Vector2(velocity.x, velocity.z).length()
	var speed_k := clampf(moving / 7.5, 0.0, 1.0)
	var aiming := aim_held and state != "reload" and not sprinting and cur != 2
	ads_k = move_toward(ads_k, 1.0 if aiming else 0.0, delta * 8.0)
	sprint_k = move_toward(sprint_k, 1.0 if sprinting else 0.0, delta * 6.0)
	if is_on_floor():
		bob_t += delta * (6.0 + moving * 1.3)
	var bob_mul := speed_k * (1.0 - ads_k * 0.85) * (1.0 + sprint_k * 0.7)
	var bob := Vector3(sin(bob_t) * 0.012, absf(cos(bob_t)) * 0.012, 0.0) * bob_mul
	recoil_v = move_toward(recoil_v, 0.0, delta * 6.0)
	pump_t = move_toward(pump_t, 0.0, delta * 2.5)
	sway = sway.lerp(Vector2(clampf(-last_look.x * 0.0006, -0.04, 0.04), clampf(last_look.y * 0.0006, -0.04, 0.04)), clampf(delta * 8.0, 0.0, 1.0))

	var hip := Vector3(0.2, -0.21, -0.42)
	var ads := Vector3(0.0, -sight_y, -0.36)
	var sprint_p := Vector3(0.14, -0.3, -0.34)
	var pos := hip.lerp(ads, ads_k).lerp(sprint_p, sprint_k)
	var rot := Vector3(-15.0, 35.0, 12.0) * sprint_k
	pos += bob + Vector3(sway.x, sway.y, 0.0)
	pos += Vector3(0.0, recoil_v * 0.008, recoil_v * 0.05) * (1.0 - ads_k * 0.5)
	rot += Vector3(recoil_v * 2.0, 0.0, 0.0)

	var t := state_t / maxf(state_dur, 0.01)
	if state == "reload":
		var d := sin(t * PI)
		pos += Vector3(-0.02 * d, -0.1 * d, 0.04 * d)
		rot += Vector3(-25.0 * d, 8.0 * d, 18.0 * d)
		if mag_node != null:
			var m := 0.0
			if t > 0.2 and t < 0.45:
				m = (t - 0.2) / 0.25
			elif t >= 0.45 and t < 0.6:
				m = 1.0
			elif t >= 0.6 and t < 0.8:
				m = 1.0 - (t - 0.6) / 0.2
			mag_node.position = mag_base + Vector3(0, -0.22 * m, 0)
			mag_node.visible = not (t >= 0.45 and t < 0.58)
	elif state == "switch":
		var e := 1.0 - t
		pos += Vector3(0.0, -0.45 * e, 0.1 * e)
		rot += Vector3(-45.0 * e, 0.0, 0.0)
	elif state == "knife":
		var a := sin(t * PI)
		pos += Vector3(-0.3 * a, 0.05 * a, -0.15 * a)
		rot += Vector3(-20.0 * a, 40.0 * (0.5 - t), 120.0 * (0.5 - t))
	if pump_node != null:
		pump_node.position = pump_base + Vector3(0.0, 0.0, 0.08 * sin(pump_t * PI))

	weapon_root.position = pos
	weapon_root.rotation_degrees = rot
	weapon_root.visible = not scoped()

	var target_fov := G.fov / lerpf(1.0, zoom, ads_k)
	if sprinting:
		target_fov += 6.0
	cam.fov = lerpf(cam.fov, target_fov, clampf(delta * 10.0, 0.0, 1.0))
	land_dip = move_toward(land_dip, 0.0, delta * 0.5)
	cam.position = Vector3(bob.x * 0.6, bob.y * 0.6 - land_dip, 0.0)

# ------------------------------------------------------------ движение
func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()
	crouch_k = move_toward(crouch_k, 1.0 if want_crouch else 0.0, delta * 8.0)
	shape.height = lerpf(1.8, 1.2, crouch_k)
	body_cs.position.y = shape.height * 0.5
	head.position.y = lerpf(1.6, 1.15, crouch_k)
	sprinting = sprint_in and move_in.y > 0.5 and on_floor and crouch_k < 0.3 and not fire_held and ads_k < 0.3 and health > 0.0
	var speed := 4.6
	if sprinting:
		speed = 7.8
	elif crouch_k > 0.5:
		speed = 2.4
	elif ads_k > 0.5:
		speed = 2.8
	var inp := move_in if health > 0.0 else Vector2.ZERO
	var dir := transform.basis * Vector3(inp.x, 0.0, -inp.y)
	dir.y = 0.0
	if dir.length() > 1.0:
		dir = dir.normalized()
	var target := dir * speed
	var accel := 16.0 if on_floor else 3.0
	velocity.x = lerpf(velocity.x, target.x, clampf(accel * delta, 0.0, 1.0))
	velocity.z = lerpf(velocity.z, target.z, clampf(accel * delta, 0.0, 1.0))
	var vy := velocity.y
	if on_floor:
		velocity.y = 0.0
		if jump_req and health > 0.0:
			velocity.y = 5.2
	else:
		velocity.y -= 16.0 * delta
	jump_req = false
	move_and_slide()
	if is_on_floor() and not was_floor:
		land_dip = clampf(-vy * 0.01, 0.0, 0.12)
	was_floor = is_on_floor()
