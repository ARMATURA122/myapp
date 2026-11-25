extends Node3D
# Загрузчик с диагностикой: пишет шаги запуска в файл и показывает прошлый результат

const LOG := "user://boot.log"
var label: Label
var text := ""


func mark(t: String) -> void:
	text += t + "\n"
	var f := FileAccess.open(LOG, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.flush()
		f.close()
	if label != null:
		label.text = text


func _ready() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 100
	add_child(cl)
	label = Label.new()
	label.position = Vector2(20, 20)
	label.size = Vector2(1240, 680)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	cl.add_child(label)

	var prev := ""
	if FileAccess.file_exists(LOG):
		prev = FileAccess.get_file_as_string(LOG)
	var healthy: bool = prev.find("OK game running") >= 0
	if not healthy:
		label.text = "ПРОШЛЫЙ ЗАПУСК:\n" + prev + "\n\nЗапуск через 6 сек..."
		await get_tree().create_timer(6.0).timeout
	text = ""
	mark("start")

	for path in ["res://car_visual.gd", "res://car.gd", "res://city.gd", "res://minimap.gd", "res://touch_controls.gd", "res://hud.gd", "res://game.gd"]:
		mark("load " + path)
		var sc = load(path)
		if sc == null or not sc.can_instantiate():
			mark("ОШИБКА в файле " + path)
			return
	mark("create game")
	var g = load("res://game.gd").new()
	g.boot = self
	add_child(g)
	mark("game added")
	await get_tree().create_timer(4.0).timeout
	if label != null:
		label.queue_free()
		label = null
