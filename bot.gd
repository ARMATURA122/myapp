extends CharacterBody3D

signal killed(bot)

var player = null
var tint := Color(0.3, 0.4, 0.3)
var parts := {}
var gun: MeshInstance3D = null
var dead := false
var alert := 0.0
var last_known := Vector3.ZERO
var think_t := 0.0
var can_see := false
var dist := 99.0
var strafe := 1.0
var strafe_t := 1.0
var fire_t := 1.5
var burst := 0
var walk_t := 0.0
var wander := Vector3.ZERO
var avoid_t := 0.0
var avoid_side := 1.0
var torso_hp := 100.0

func _ready() -> void:
	add_to_group("bots")
	collision_layer = 4
	collision_mask = 1 | 4
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.8
	cs.shape = cap
	cs.position = Vector3(0, 0.9, 0)
	add_child(cs)
	var skin := Color(0.8, 0.6, 0.5)
	var dark := tint.darkened(0.35)
	_make_part("torso", Vector3(0.46, 0.62, 0.26), Vector3(0, 1.15, 0), Vector3.ZERO, 100.0, tint)
	_make_part("head", Vector3(0.22, 0.24, 0.22), Vector3(0, 1.68, 0), Vector3.ZERO, 30.0, skin)
	_make_part("arm_l", Vector3(0.12, 0.55, 0.12), Vector3(-0.34, 1.42, 0), Vector3(0, -0.27, 0), 45.0, tint)
	_make_part("arm_r", Vector3(0.12, 0.55, 0.12), Vector3(0.34, 1.42, 0), Vector3(0, -0.27, 0), 45.0, tint)
	_make_part("leg_l", Vector3(0.16, 0.76, 0.16), Vector3(-0.12, 0.78, 0), Vector3(0, -0.38, 0), 55.0, dark)
	_make_part("leg_r", Vector3(0.16, 0.76, 0.16), Vector3(0.12, 0.78, 0), Vector3(0, -0.38, 0), 55.0, dark)
	gun = MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.06, 0.5, 0.07)
	gun.mesh = gm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.1, 0.1, 0.11)
	gmat.metallic = 0.6
	gun.material_override = gmat
	gun.position = Vector3(0, -0.6, 0)
	parts["arm_r"]["pivot"].add_child(gun)
	fire_t = randf_range(1.0, 2.0)

func _make_part(pname: String, size: Vector3, pivot_pos: Vector3, off: Vector3, hp: float, color: Color) -> void:
	var pv := Node3D.new()
	pv.position = pivot_pos
	add_child(pv)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	mi.material_override = m
	mi.position = off
	pv.add_child(mi)
	var area := Area3D.new()
	area.collision_layer = 2
	area.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size * 1.15
	cs.shape = bs
	cs.position = off
	area.add_child(cs)
	pv.add_child(area)
	area.set_meta("bot", self)
	area.set_meta("part", pname)
	parts[pname] = {"pivot": pv, "mesh": mi, "area": area, "hp": hp, "size": size, "off": off}

# ------------------------------------------------------------ ИИ
func hear(pos: Vector3, radius: float) -> void:
	if dead:
		return
	if global_position.distance_to(pos) < radius:
		alert = 8.0
		last_known = pos

func _pick_wander() -> void:
	wander = Vector3(randf_range(-150.0, 150.0), 0, randf_range(-150.0, 150.0))

func _think() -> void:
	if player.health <= 0.0:
		can_see = false
		return
	var pp: Vector3 = player.global_position
	var eye := global_position + Vector3(0, 1.6, 0)
	var peye: Vector3 = player.cam.global_position
	dist = global_position.distance_to(pp)
	can_see = false
	if dist < 70.0:
		var q := PhysicsRayQueryParameters3D.create(eye, peye, 1)
		var r := get_world_3d().direct_space_state.intersect_ray(q)
		if r.is_empty():
			var fwd := -global_transform.basis.z
			var to := (peye - eye).normalized()
			if alert > 0.0 or dist < 14.0 or fwd.dot(to) > 0.3:
				can_see = true
	if can_see:
		alert = 6.0
		last_known = pp

func _blocked(dir: Vector3) -> bool:
	var from := global_position + Vector3(0, 0.6, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 2.0, 1)
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func _physics_process(delta: float) -> void:
	if dead or player == null:
		return
	think_t -= delta
	if think_t <= 0.0:
		think_t = 0.15 + randf() * 0.1
		_think()
	alert = maxf(0.0, alert - delta)
	strafe_t -= delta
	if strafe_t <= 0.0:
		strafe_t = randf_range(1.2, 3.0)
		strafe = -strafe
	avoid_t = maxf(0.0, avoid_t - delta)
	var legs := int(parts.has("leg_l")) + int(parts.has("leg_r"))
	var base_speed := 3.0
	if legs == 1:
		base_speed = 1.3
	var arm_ok := parts.has("arm_r")
	var move_dir := Vector3.ZERO
	var face := Vector3.ZERO
	var spd := base_speed
	var pp: Vector3 = player.global_position
	var flat := Vector3(pp.x - global_position.x, 0, pp.z - global_position.z)
	if can_see and flat.length() > 0.1:
		face = flat
		var pref := 15.0
		if dist > pref + 4.0:
			move_dir = flat.normalized()
			spd = base_speed * 1.5
		elif dist < pref - 6.0:
			move_dir = -flat.normalized()
		move_dir += flat.normalized().cross(Vector3.UP) * strafe * 0.8
		if arm_ok and dist < 55.0:
			_fire(delta)
	elif alert > 0.0:
		var to := Vector3(last_known.x - global_position.x, 0, last_known.z - global_position.z)
		if to.length() < 3.0:
			alert = 0.0
		else:
			move_dir = to.normalized()
			face = move_dir
			spd = base_speed * 1.4
	else:
		var to2 := Vector3(wander.x - global_position.x, 0, wander.z - global_position.z)
		if wander == Vector3.ZERO or to2.length() < 3.0:
			_pick_wander()
		else:
			move_dir = to2.normalized()
			face = move_dir
			spd = base_speed * 0.7
	if move_dir.length() > 0.01:
		move_dir = move_dir.normalized()
		if avoid_t > 0.0 or _blocked(move_dir):
			if avoid_t <= 0.0:
				avoid_t = 1.0
				avoid_side = -avoid_side
			move_dir = move_dir.rotated(Vector3.UP, deg_to_rad(80.0) * avoid_side)
	velocity.x = move_dir.x * spd
	velocity.z = move_dir.z * spd
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= 20.0 * delta
	move_and_slide()
	if face.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-face.x, -face.z), clampf(delta * 8.0, 0.0, 1.0))
	_animate(delta, move_dir.length() > 0.01, can_see and arm_ok, spd)

func _animate(delta: float, moving: bool, aiming: bool, spd: float) -> void:
	if moving:
		walk_t += delta * spd * 2.2
	var sw := sin(walk_t) * 0.7 if moving else 0.0
	if parts.has("leg_l"):
		parts["leg_l"]["pivot"].rotation.x = sw
	if parts.has("leg_r"):
		parts["leg_r"]["pivot"].rotation.x = -sw
	if parts.has("arm_r"):
		parts["arm_r"]["pivot"].rotation.x = deg_to_rad(80.0) if aiming else -sw * 0.6
	if parts.has("arm_l"):
		parts["arm_l"]["pivot"].rotation.x = deg_to_rad(65.0) if aiming else sw * 0.6

func _fire(delta: float) -> void:
	fire_t -= delta
	if fire_t > 0.0:
		return
	if burst > 0:
		burst -= 1
		fire_t = 0.11
		_shoot_at_player()
	else:
		burst = randi_range(3, 6)
		fire_t = randf_range(0.7, 1.5)

func _shoot_at_player() -> void:
	var chance := clampf(0.5 - dist * 0.009, 0.08, 0.5)
	if not parts.has("arm_l"):
		chance *= 0.7
	var from := global_position + Vector3(0, 1.4, 0) + (-global_transform.basis.z) * 0.8
	var target: Vector3 = player.cam.global_position
	if randf() < chance:
		player.take_damage(7.0, global_position)
	else:
		target += Vector3(randf_range(-1.5, 1.5), randf_range(-1.0, 1.0), randf_range(-1.5, 1.5))
	G.tracer(from, target)
	G.play(G.sfx["shot"], -8.0 - dist * 0.25)

# ------------------------------------------------------------ попадания и отрыв конечностей
func hit(pname: String, dmg: float, pos: Vector3, dir: Vector3) -> bool:
	if dead or not parts.has(pname):
		return false
	G.blood(pos, -dir, 12)
	G.play(G.sfx["thud"], -8.0)
	alert = 10.0
	last_known = player.global_position
	parts[pname]["hp"] = float(parts[pname]["hp"]) - dmg
	if pname != "torso":
		torso_hp -= dmg * 0.25
	else:
		torso_hp -= dmg
	if pname == "head" and float(parts["head"]["hp"]) <= 0.0:
		_sever("head", dir)
		_die(dir)
		return true
	if pname != "torso" and float(parts[pname]["hp"]) <= 0.0:
		_sever(pname, dir)
		if not parts.has("leg_l") and not parts.has("leg_r"):
			_die(dir)
			return true
	if torso_hp <= 0.0:
		_die(dir)
		return true
	return false

func _debris(pname: String, dir: Vector3, power: float) -> void:
	var p: Dictionary = parts[pname]
	var scene := get_tree().current_scene
	if scene == null:
		return
	var rb := RigidBody3D.new()
	rb.collision_layer = 8
	rb.collision_mask = 1
	rb.mass = 4.0
	var mi: MeshInstance3D = p["mesh"].duplicate()
	rb.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = p["size"]
	cs.shape = bs
	cs.position = p["off"]
	rb.add_child(cs)
	if pname == "arm_r" and gun != null:
		rb.add_child(parts["arm_r"]["pivot"].get_child(parts["arm_r"]["pivot"].get_child_count() - 1).duplicate())
	scene.add_child(rb)
	rb.global_transform = p["pivot"].global_transform
	rb.linear_velocity = dir * power + Vector3(randf_range(-2.0, 2.0), randf_range(2.0, 5.0), randf_range(-2.0, 2.0))
	rb.angular_velocity = Vector3(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))
	get_tree().create_timer(15.0).timeout.connect(rb.queue_free)

func _sever(pname: String, dir: Vector3) -> void:
	var p: Dictionary = parts[pname]
	var pv: Node3D = p["pivot"]
	G.blood(pv.global_position, dir, 24)
	_debris(pname, dir, 4.0)
	if pname != "head":
		var stump := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.07
		sm.height = 0.14
		sm.radial_segments = 6
		sm.rings = 3
		stump.mesh = sm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.55, 0.03, 0.03)
		stump.material_override = m
		stump.position = pv.position
		add_child(stump)
	pv.queue_free()
	parts.erase(pname)

func _die(dir: Vector3) -> void:
	if dead:
		return
	dead = true
	G.blood(global_position + Vector3(0, 1.2, 0), dir, 30)
	for pname in parts.keys():
		_debris(pname, dir, randf_range(1.0, 4.0))
	collision_layer = 0
	collision_mask = 0
	killed.emit(self)
	queue_free()
