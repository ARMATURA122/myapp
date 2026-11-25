extends CanvasLayer
# Интерфейс: скорость, деньги, сообщения, мини-карта, управление

const TouchControls = preload("res://touch_controls.gd")
const MiniMap = preload("res://minimap.gd")

var controls
var minimap
var speed_label: Label
var info_label: Label
var msg_label: Label
var big_label: Label
var race_label: Label
var nitro_bar: ProgressBar
var msg_timer := 0.0
var big_timer := 0.0


func _ready() -> void:
	controls = TouchControls.new()
	add_child(controls)
	minimap = MiniMap.new()
	add_child(minimap)
	speed_label = _make_label(60, HORIZONTAL_ALIGNMENT_CENTER)
	info_label = _make_label(26, HORIZONTAL_ALIGNMENT_LEFT)
	msg_label = _make_label(32, HORIZONTAL_ALIGNMENT_CENTER)
	big_label = _make_label(120, HORIZONTAL_ALIGNMENT_CENTER)
	race_label = _make_label(28, HORIZONTAL_ALIGNMENT_CENTER)
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_label.modulate.a = 0.0
	nitro_bar = ProgressBar.new()
	nitro_bar.min_value = 0.0
	nitro_bar.max_value = 1.0
	nitro_bar.step = 0.001
	nitro_bar.show_percentage = false
	nitro_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(nitro_bar)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _make_label(sz: int, align: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", maxi(3, int(sz * 0.12)))
	l.horizontal_alignment = align as HorizontalAlignment
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _layout() -> void:
	var s: Vector2 = get_viewport().get_visible_rect().size
	minimap.position = Vector2(s.x - 186.0, 16.0)
	info_label.position = Vector2(20, 14)
	info_label.size = Vector2(420, 90)
	msg_label.position = Vector2(s.x * 0.2, s.y * 0.16)
	msg_label.size = Vector2(s.x * 0.6, 120)
	big_label.position = Vector2(0, s.y * 0.20)
	big_label.size = Vector2(s.x, 180)
	race_label.position = Vector2(s.x * 0.2, 14)
	race_label.size = Vector2(s.x * 0.6, 80)
	speed_label.position = Vector2(s.x * 0.5 - 170.0, s.y - 112.0)
	speed_label.size = Vector2(340, 90)
	nitro_bar.position = Vector2(s.x * 0.5 - 130.0, s.y - 30.0)
	nitro_bar.size = Vector2(260, 12)


func set_stats(kmh: float, nitro: float, money: int, found: int, total: int) -> void:
	speed_label.text = "%d км/ч" % int(kmh)
	nitro_bar.value = nitro
	info_label.text = "$ %d\nГонки найдено: %d / %d" % [money, found, total]


func show_msg(t: String, dur: float = 3.0) -> void:
	msg_label.text = t
	msg_label.modulate.a = 1.0
	msg_timer = dur


func show_big(t: String, dur: float = 0.0) -> void:
	big_label.text = t
	big_label.modulate.a = 1.0
	big_timer = dur


func set_race_text(t: String) -> void:
	race_label.text = t


func _process(delta: float) -> void:
	if msg_timer > 0.0:
		msg_timer -= delta
		if msg_timer < 0.6:
			msg_label.modulate.a = maxf(0.0, msg_timer / 0.6)
	if big_timer > 0.0:
		big_timer -= delta
		if big_timer <= 0.0:
			big_label.text = ""
