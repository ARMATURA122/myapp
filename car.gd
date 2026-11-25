extends CharacterBody3D
# Аркадная физика машины

const CarVisual = preload("res://car_visual.gd")

var max_speed := 58.0
var accel := 24.0
var steer := 0.0
var in_steer := 0.0
var in_gas := 0.0
var in_brake := 0.0
var in_hand := false
var in_nitro := false
var locked := false
var nitro := 1.0
var speed_fwd := 0.0
var visual
var _prev_vf := 0.0
var _pitch := 0.0
var _roll := 0.0


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.85, 1.0, 4.3)
	shape.shape = box
	shape.position = Vector3(0, 0.5, 0)
	add_child(shape)
	floor_snap_length = 0.4
	visual = CarVisual.new()
	add_child(visual)
	visual.setup(Color(0.93, 0.94, 0.96), Color(0.10, 0.30, 0.65))


func place(pos: Vector3, yaw: float) -> void:
	position = pos
	rotation = Vector3(0.0, yaw, 0.0)
	velocity = Vector3.ZERO
	steer = 0.0
	speed_fwd = 0.0


func _physics_process(delta: float) -> void:
	var gas := in_gas
	var brk := in_brake
	var steer_target := in_steer
	if locked:
		gas = 0.0
		brk = 0.0
		steer_target = 0.0

	var fwd: Vector3 = -global_transform.basis.z
	var right: Vector3 = global_transform.basis.x
	var vf: float = velocity.dot(fwd)
	var vl: float = velocity.dot(right)

	var ms := max_speed
	var ac := accel
	if in_nitro and nitro > 0.02 and not locked and vf > 3.0:
		ms *= 1.3
		ac *= 2.0
		nitro = maxf(0.0, nitro - delta * 0.28)
	else:
		nitro = minf(1.0, nitro + delta * 0.05)

	if gas > 0.0:
		vf += ac * gas * clampf(1.0 - vf / ms, 0.0, 1.0) * delta
	if brk > 0.0:
		if vf > 0.5:
			vf = maxf(0.0, vf - 38.0 * brk * delta)
		else:
			vf = maxf(-12.0, vf - 12.0 * brk * delta)
	if gas <= 0.0 and brk <= 0.0:
		vf = move_toward(vf, 0.0, 4.0 * delta)
	if in_hand and not locked:
		vf = move_toward(vf, 0.0, 14.0 * delta)
	if vf > ms:
		vf = move_toward(vf, ms, 10.0 * delta)

	steer = move_toward(steer, steer_target, 4.5 * delta)
	var turn_speed: float = 2.4 / (1.0 + absf(vf) / 18.0)
	if in_hand:
		turn_speed *= 1.5
	rotate_y(-steer * turn_speed * clampf(vf / 5.0, -1.0, 1.0) * delta)

	var grip := 8.0
	if in_hand:
		grip = 1.6
	vl *= exp(-grip * delta)

	fwd = -global_transform.basis.z
	right = global_transform.basis.x
	var vy := velocity.y
	if is_on_floor():
		vy = 0.0
	else:
		vy -= 30.0 * delta
	velocity = fwd * vf + right * vl
	velocity.y = vy
	move_and_slide()

	for i in range(get_slide_collision_count()):
		var col := get_slide_collision(i)
		if absf(col.get_normal().y) < 0.4:
			velocity.x *= 0.985
			velocity.z *= 0.985
			break

	speed_fwd = velocity.dot(-global_transform.basis.z)
	var a: float = (speed_fwd - _prev_vf) / maxf(delta, 0.0001)
	_prev_vf = speed_fwd
	_update_visual(delta, a)


func _update_visual(delta: float, a: float) -> void:
	var k: float = 1.0 - exp(-8.0 * delta)
	var target_pitch: float = clampf(a * 0.0025, -0.06, 0.06)
	var target_roll: float = steer * clampf(absf(speed_fwd) / 40.0, 0.0, 1.0) * 0.07
	_pitch = lerpf(_pitch, target_pitch, k)
	_roll = lerpf(_roll, target_roll, k)
	visual.rotation = Vector3(_pitch, 0.0, _roll)
	visual.update_wheels(speed_fwd, steer, delta)
