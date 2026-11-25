extends Control
# Мини-карта: направление движения всегда вверх

const City = preload("res://city.gd")
const MAP_SCALE := 0.5

var player_pos := Vector3.ZERO
var player_yaw := 0.0
var markers: Array = []   # [Vector3, Color, bool(цель гонки)]


func _ready() -> void:
	custom_minimum_size = Vector2(170, 170)
	size = Vector2(170, 170)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c: Vector2 = size * 0.5
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.10, 0.12, 0.72))
	var fwd2 := Vector2(-sin(player_yaw), -cos(player_yaw))
	var phi: float = -PI * 0.5 - fwd2.angle()
	draw_set_transform(c, phi, Vector2(MAP_SCALE, MAP_SCALE))
	var ext: float = City.HALF * City.PITCH
	var pp := Vector2(player_pos.x, player_pos.z)
	for i in range(City.GRID):
		var k: float = (i - City.HALF) * City.PITCH
		draw_line(Vector2(k, -ext - 30.0) - pp, Vector2(k, ext + 30.0) - pp, Color(0.55, 0.58, 0.62), City.ROAD_W)
		draw_line(Vector2(-ext - 30.0, k) - pp, Vector2(ext + 30.0, k) - pp, Color(0.55, 0.58, 0.62), City.ROAD_W)
	for m in markers:
		var p: Vector3 = m[0]
		var col: Color = m[1]
		var is_target: bool = m[2]
		var q := Vector2(p.x, p.z) - pp
		var lim: float = 68.0 / MAP_SCALE
		if is_target and q.length() > lim:
			q = q.normalized() * lim
		draw_circle(q, 9.0 / MAP_SCALE, Color(0, 0, 0, 0.6))
		draw_circle(q, 7.0 / MAP_SCALE, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -10), c + Vector2(-7, 8), c + Vector2(7, 8)]), Color.WHITE)
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.5), false, 2.0)
