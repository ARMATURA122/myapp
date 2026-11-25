extends Control
# Экранные кнопки с мультитачем + клавиатура для ПК

var steer := 0.0
var gas := 0.0
var brake := 0.0
var hand := false
var nitro := false

var touches := {}   # индекс пальца -> имя кнопки
var rects := {}
var active := {}
var sb: StyleBoxFlat

const LABELS := {"gas": "ГАЗ", "brake": "ТОРМОЗ", "nitro": "НИТРО", "hand": "ДРИФТ"}
const TINTS := {
	"left": Color(1, 1, 1), "right": Color(1, 1, 1),
	"gas": Color(0.3, 1.0, 0.4), "brake": Color(1.0, 0.3, 0.3),
	"nitro": Color(0.3, 0.7, 1.0), "hand": Color(1.0, 0.85, 0.2)}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	sb = StyleBoxFlat.new()
	sb.set_corner_radius_all(26)
	sb.set_border_width_all(3)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var s: Vector2 = get_viewport().get_visible_rect().size
	var b: float = clampf(s.y * 0.19, 64.0, 130.0)
	var m := 22.0
	rects["left"] = Rect2(m, s.y - m - b, b * 1.1, b)
	rects["right"] = Rect2(m + b * 1.1 + 14.0, s.y - m - b, b * 1.1, b)
	var gas_r := Rect2(s.x - m - b * 1.3, s.y - m - b * 1.4, b * 1.3, b * 1.4)
	rects["gas"] = gas_r
	var br := Rect2(gas_r.position.x - b * 1.1 - 14.0, s.y - m - b, b * 1.1, b)
	rects["brake"] = br
	rects["nitro"] = Rect2(gas_r.position.x, gas_r.position.y - b * 0.8 - 14.0, b * 1.3, b * 0.8)
	rects["hand"] = Rect2(br.position.x, br.position.y - b * 0.8 - 14.0, b * 1.1, b * 0.8)
	queue_redraw()


func _hit(p: Vector2) -> String:
	for key in rects:
		var r: Rect2 = rects[key]
		if r.grow(12.0).has_point(p):
			return key
	return ""


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var te := event as InputEventScreenTouch
		if te.pressed:
			var n: String = _hit(te.position)
			if n != "":
				touches[te.index] = n
		else:
			touches.erase(te.index)
	elif event is InputEventScreenDrag:
		var de := event as InputEventScreenDrag
		if touches.has(de.index):
			var n2: String = _hit(de.position)
			if n2 != "":
				touches[de.index] = n2


func _process(_delta: float) -> void:
	active.clear()
	for v in touches.values():
		active[v] = true
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		active["left"] = true
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		active["right"] = true
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		active["gas"] = true
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		active["brake"] = true
	if Input.is_key_pressed(KEY_SPACE):
		active["hand"] = true
	if Input.is_key_pressed(KEY_SHIFT):
		active["nitro"] = true
	steer = (1.0 if active.has("right") else 0.0) - (1.0 if active.has("left") else 0.0)
	gas = 1.0 if active.has("gas") else 0.0
	brake = 1.0 if active.has("brake") else 0.0
	hand = active.has("hand")
	nitro = active.has("nitro")
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for key in rects:
		var r: Rect2 = rects[key]
		var tint: Color = TINTS[key]
		var down: bool = active.has(key)
		sb.bg_color = Color(tint.r, tint.g, tint.b, 0.42 if down else 0.15)
		sb.border_color = Color(tint.r, tint.g, tint.b, 0.8 if down else 0.45)
		sb.draw(get_canvas_item(), r)
		var c: Vector2 = r.get_center()
		var k: float = minf(r.size.x, r.size.y) * 0.22
		if key == "left":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-k, 0), c + Vector2(k, -k * 1.2), c + Vector2(k, k * 1.2)]), Color(1, 1, 1, 0.9))
		elif key == "right":
			draw_colored_polygon(PackedVector2Array([c + Vector2(k, 0), c + Vector2(-k, -k * 1.2), c + Vector2(-k, k * 1.2)]), Color(1, 1, 1, 0.9))
		else:
			var fs: int = clampi(int(r.size.y * 0.26), 14, 34)
			draw_string(font, Vector2(r.position.x, c.y + fs * 0.35), LABELS[key], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, Color(1, 1, 1, 0.95))
