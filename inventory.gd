extends Control

const WM = preload("res://weapon_model.gd")

var main = null
var sel := 0
var pivot: Node3D
var stats_label: Label
var slot_btns: Array = []
var w_btns := {}
var att_btns := {}
var fps_btn: Button
var fov_lbl: Label
var sens_lbl: Label
var res_lbl: Label

func _lbl(t: String, pos: Vector2, size: int, col := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = t
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	add_child(l)
	return l

func _btn(t: String, pos: Vector2, sz: Vector2, size := 18) -> Button:
	var b := Button.new()
	b.text = t
	b.position = pos
	b.custom_minimum_size = sz
	b.size = sz
	b.add_theme_font_size_override("font_size", size)
	add_child(b)
	return b

func _slider(pos: Vector2, w: float, mn: float, mx: float, step: float, val: float) -> HSlider:
	var s := HSlider.new()
	s.position = pos
	s.custom_minimum_size = Vector2(w, 30)
	s.size = Vector2(w, 30)
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value = val
	add_child(s)
	return s

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.03, 0.09, 0.96)
	add_child(bg)
	_lbl("ИНВЕНТАРЬ", Vector2(30, 14), 30, Color(0.8, 0.7, 1.0))

	# слоты
	for i in 3:
		var b := _btn("", Vector2(30, 70 + i * 62), Vector2(270, 54), 18)
		if i < 2:
			b.pressed.connect(_on_slot.bind(i))
		else:
			b.text = "3: Нож (фиксированный)"
			b.disabled = true
		slot_btns.append(b)
	_lbl("Оружие в выбранный слот", Vector2(30, 262), 16, Color(0.8, 0.8, 0.9))
	var n := 0
	for wid in G.WEAPON_IDS:
		var col := n % 2
		var row := n / 2
		var b := _btn(str(G.weapons[wid]["name"]), Vector2(30 + col * 138, 292 + row * 56), Vector2(130, 48), 16)
		b.pressed.connect(_on_weapon.bind(wid))
		w_btns[wid] = b
		n += 1

	# превью 3D
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.position = Vector2(320, 70)
	svc.size = Vector2(420, 300)
	add_child(svc)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.transparent_bg = true
	sv.size = Vector2i(420, 300)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(sv)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.55, 0.7)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	sv.add_child(we)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -35, 0)
	light.light_energy = 1.6
	sv.add_child(light)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.1, 1.6)
	cam.fov = 40.0
	sv.add_child(cam)
	pivot = Node3D.new()
	sv.add_child(pivot)
	stats_label = _lbl("", Vector2(320, 380), 17, Color(0.9, 0.9, 1.0))

	# обвесы
	_lbl("Обвесы", Vector2(770, 70), 20, Color(0.8, 0.7, 1.0))
	var i2 := 0
	for s in G.SLOTS:
		var b := _btn("", Vector2(770, 106 + i2 * 66), Vector2(460, 56), 18)
		b.pressed.connect(_on_att.bind(s))
		att_btns[s] = b
		i2 += 1

	# настройки
	fov_lbl = _lbl("", Vector2(30, 540), 15)
	var s1 := _slider(Vector2(30, 566), 250, 60.0, 100.0, 1.0, G.fov)
	s1.value_changed.connect(_on_fov)
	sens_lbl = _lbl("", Vector2(310, 540), 15)
	var s2 := _slider(Vector2(310, 566), 250, 0.05, 0.5, 0.01, G.sens)
	s2.value_changed.connect(_on_sens)
	res_lbl = _lbl("", Vector2(590, 540), 15)
	var s3 := _slider(Vector2(590, 566), 250, 0.5, 1.0, 0.05, G.res)
	s3.value_changed.connect(_on_res)
	fps_btn = _btn("", Vector2(880, 548), Vector2(180, 48), 16)
	fps_btn.pressed.connect(_on_fps)
	var lay := _btn("Раскладка кнопок", Vector2(1070, 548), Vector2(180, 48), 16)
	lay.pressed.connect(_on_layout)
	var close := _btn("ЗАКРЫТЬ", Vector2(1030, 630), Vector2(220, 60), 22)
	close.pressed.connect(_on_close)
	_update_settings_labels()
	refresh()

func _process(delta: float) -> void:
	if visible and pivot != null:
		pivot.rotation.y += delta * 0.7

func _wid() -> String:
	return G.slot1 if sel == 0 else G.slot2

func refresh() -> void:
	slot_btns[0].text = "1: " + str(G.weapons[G.slot1]["name"])
	slot_btns[1].text = "2: " + str(G.weapons[G.slot2]["name"])
	for i in 2:
		slot_btns[i].modulate = Color(1.0, 0.85, 1.0) if i == sel else Color(0.8, 0.8, 0.8)
	var wid := _wid()
	for id in w_btns.keys():
		w_btns[id].modulate = Color(1.0, 0.85, 1.0) if id == wid else Color(0.8, 0.8, 0.8)
	var a: Dictionary = G.att.get(wid, {})
	for s in G.SLOTS:
		var cur = a.get(s, "")
		var nm := "нет"
		if cur != "" and G.attachments.has(cur):
			nm = str(G.attachments[cur]["name"])
		att_btns[s].text = str(G.SLOT_NAMES[s]) + ": " + nm + "   (нажми, чтобы сменить)"
	var st: Dictionary = G.stats(wid)
	stats_label.text = "%s\nУрон: %d    Темп: %d выстр/мин\nМагазин: %d    Перезарядка: %.1f c\nОтдача: %.2f    Разброс: %.3f\nУвеличение: x%.1f    Шум: %d м" % [
		str(st["name"]), int(float(st["dmg"])), int(float(st["rpm"])), int(st["mag"]), float(st["reload"]),
		float(st["recoil"]), float(st["spread"]), float(st["zoom"]), int(float(st["noise"]))]
	for c in pivot.get_children():
		c.queue_free()
	var m: Node3D = WM.build(wid, a)
	m.position = Vector3(0, 0, 0.25)
	pivot.add_child(m)

func _update_settings_labels() -> void:
	fov_lbl.text = "Угол обзора (FOV): %d" % int(G.fov)
	sens_lbl.text = "Чувствительность: %.2f" % G.sens
	res_lbl.text = "Разрешение 3D: %d%%" % int(G.res * 100.0)
	fps_btn.text = "Лимит FPS: " + (str(G.fps_cap) if G.fps_cap > 0 else "без лимита")

func _on_slot(i: int) -> void:
	sel = i
	refresh()

func _on_weapon(wid: String) -> void:
	if sel == 0:
		if G.slot2 == wid:
			G.slot2 = G.slot1
		G.slot1 = wid
	else:
		if G.slot1 == wid:
			G.slot1 = G.slot2
		G.slot2 = wid
	refresh()

func _on_att(slot: String) -> void:
	var wid := _wid()
	var opts: Array = [""]
	for id in G.attachments.keys():
		if G.attachments[id]["slot"] == slot:
			opts.append(id)
	var a: Dictionary = G.att.get(wid, {})
	var i := opts.find(a.get(slot, ""))
	i = (i + 1) % opts.size()
	a[slot] = opts[i]
	G.att[wid] = a
	refresh()

func _on_fov(v: float) -> void:
	G.fov = v
	_update_settings_labels()

func _on_sens(v: float) -> void:
	G.sens = v
	_update_settings_labels()

func _on_res(v: float) -> void:
	G.res = v
	get_viewport().scaling_3d_scale = v
	_update_settings_labels()

func _on_fps() -> void:
	var opts := [60, 90, 120, 0]
	var i := opts.find(G.fps_cap)
	G.fps_cap = opts[(i + 1) % opts.size()]
	Engine.max_fps = G.fps_cap
	_update_settings_labels()

func _on_layout() -> void:
	main.edit_layout()

func _on_close() -> void:
	main.close_inventory()

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB or event.keycode == KEY_ESCAPE or event.keycode == KEY_I:
			main.close_inventory()
