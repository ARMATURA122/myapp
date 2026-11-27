extends Control

var player = null
var main = null
var edit_mode := false
var sel_btn := "fire"
var touches := {}
var held := {}
var stick := Vector2.ZERO
var stick_origin := Vector2.ZERO
var stick_idx := -1
var crouch_on := false
var msg := ""
var msg_t := 0.0
var hit_t := 0.0
var hit_kill := false
var kills := 0
var wave := 0
var scope_rect: ColorRect
var flash_rect: ColorRect
var done_btn: Button
var plus_btn: Button
var minus_btn: Button

const BTN_IDS := ["fire", "aim", "reload", "jump", "crouch", "w1", "w2", "w3", "inv"]
const BTN_LABEL := {"fire": "ОГОНЬ", "aim": "ПРИЦЕЛ", "reload": "ЗАРЯД", "jump": "ПРЫЖОК", "crouch": "ПРИСЕД", "w1": "1", "w2": "2", "w3": "НОЖ", "inv": "ИНВ"}
const BTN_DEF := {
	"fire": [0.88, 0.58, 1.3], "aim": [0.76, 0.38, 1.0], "reload": [0.66, 0.80, 0.9],
	"jump": [0.93, 0.88, 0.9], "crouch": [0.81, 0.88, 0.8],
	"w1": [0.42, 0.10, 0.9], "w2": [0.49, 0.10, 0.9], "w3": [0.56, 0.10, 0.9], "inv": [0.94, 0.10, 0.8]
}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform float aspect = 1.78;\nvoid fragment() {\n\tvec2 uv = UV - vec2(0.5);\n\tuv.x *= aspect;\n\tfloat d = length(uv);\n\tfloat a = smoothstep(0.30, 0.305, d);\n\tfloat ring = smoothstep(0.292, 0.30, d) * (1.0 - smoothstep(0.30, 0.31, d));\n\tCOLOR = vec4(0.0, 0.0, 0.0, max(a, ring));\n}\n"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	scope_rect = ColorRect.new()
	scope_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scope_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scope_rect.material = mat
	scope_rect.color = Color.WHITE
	scope_rect.visible = false
	add_child(scope_rect)
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color(1, 0, 0, 0)
	add_child(flash_rect)
	done_btn = Button.new()
	done_btn.text = "Готово"
	done_btn.custom_minimum_size = Vector2(140, 50)
	done_btn.pressed.connect(_on_done)
	done_btn.visible = false
	add_child(done_btn)
	plus_btn = Button.new()
	plus_btn.text = "+"
	plus_btn.custom_minimum_size = Vector2(60, 50)
	plus_btn.pressed.connect(_on_scale.bind(0.1))
	plus_btn.visible = false
	add_child(plus_btn)
	minus_btn = Button.new()
	minus_btn.text = "-"
	minus_btn.custom_minimum_size = Vector2(60, 50)
	minus_btn.pressed.connect(_on_scale.bind(-0.1))
	minus_btn.visible = false
	add_child(minus_btn)

func show_msg(t: String, secs := 2.5) -> void:
	msg = t
	msg_t = secs

func on_hit(kill: bool) -> void:
	hit_t = 0.25
	hit_kill = kill

func _on_done() -> void:
	main.finish_layout_edit()

func _on_scale(delta_s: float) -> void:
	var def: Array = BTN_DEF[sel_btn]
	var p: Array = G.hud_pos(sel_btn, def)
	G.hud[sel_btn] = [p[0], p[1], clampf(p[2] + delta_s, 0.5, 2.0)]

# ------------------------------------------------------------ положение кнопок
func _bpos(id: String) -> Vector2:
	var s := get_viewport_rect().size
	var p: Array = G.hud_pos(id, BTN_DEF[id])
	return Vector2(s.x * p[0], s.y * p[1])

func _brad(id: String) -> float:
	var p: Array = G.hud_pos(id, BTN_DEF[id])
	var base := 54.0 if id == "fire" else 38.0
	return base * p[2]

func _btn_at(pos: Vector2) -> String:
	var best := ""
	var best_d := 9999.0
	for id in BTN_IDS:
		var d := pos.distance_to(_bpos(id))
		if d <= _brad(id) * 1.15 and d < best_d:
			best = id
			best_d = d
	return best

# ------------------------------------------------------------ касания
func _fix(p: Vector2) -> Vector2:
	var vr := get_viewport_rect().size
	if p.x > vr.x * 1.02 or p.y > vr.y * 1.02:
		var win := Vector2(DisplayServer.window_get_size())
		return p * vr / win
	return p

func _input(event: InputEvent) -> void:
	if main == null or player == null:
		return
	if not (edit_mode or main.state == "play"):
		return
	if event is InputEventScreenTouch:
		G.kbm = false
		var pos := _fix(event.position)
		if event.pressed:
			_press(event.index, pos)
		else:
			_release(event.index)
	elif event is InputEventScreenDrag:
		_drag(event.index, _fix(event.position), event.relative)

func _press(idx: int, pos: Vector2) -> void:
	var id := _btn_at(pos)
	if edit_mode:
		if id != "":
			sel_btn = id
			touches[idx] = {"kind": "edit", "id": id}
		return
	if id != "":
		touches[idx] = {"kind": "btn", "id": id}
		_btn_down(id)
	elif pos.x < get_viewport_rect().size.x * 0.45 and stick_idx == -1:
		stick_idx = idx
		stick_origin = pos
		stick = Vector2.ZERO
		touches[idx] = {"kind": "stick"}
	else:
		touches[idx] = {"kind": "look"}

func _btn_down(id: String) -> void:
	match id:
		"fire", "aim":
			held[id] = true
		"reload":
			player.do_reload()
		"jump":
			player.do_jump()
		"crouch":
			crouch_on = not crouch_on
		"w1":
			player.switch_to(0)
		"w2":
			player.switch_to(1)
		"w3":
			player.switch_to(2)
		"inv":
			main.open_inventory()

func _release(idx: int) -> void:
	if not touches.has(idx):
		return
	var t: Dictionary = touches[idx]
	if t["kind"] == "btn":
		held.erase(t["id"])
	elif t["kind"] == "stick":
		stick_idx = -1
		stick = Vector2.ZERO
	touches.erase(idx)

func _drag(idx: int, pos: Vector2, rel: Vector2) -> void:
	if not touches.has(idx):
		return
	var t: Dictionary = touches[idx]
	var kind: String = t["kind"]
	if kind == "look":
		player.look_in += rel
	elif kind == "stick":
		stick = ((pos - stick_origin) / 90.0).limit_length(1.0)
	elif kind == "edit":
		var s := get_viewport_rect().size
		var id: String = t["id"]
		var p: Array = G.hud_pos(id, BTN_DEF[id])
		G.hud[id] = [clampf(pos.x / s.x, 0.03, 0.97), clampf(pos.y / s.y, 0.05, 0.95), p[2]]

func apply() -> void:
	player.move_in = Vector2(stick.x, -stick.y)
	player.fire_held = held.has("fire")
	player.aim_held = held.has("aim")
	player.sprint_in = stick.length() > 0.92 and -stick.y > 0.5
	player.want_crouch = crouch_on

# ------------------------------------------------------------ кадр
func _process(delta: float) -> void:
	msg_t = maxf(0.0, msg_t - delta)
	hit_t = maxf(0.0, hit_t - delta)
	var s := get_viewport_rect().size
	if player != null:
		scope_rect.visible = player.scoped() and not edit_mode
		if scope_rect.visible:
			(scope_rect.material as ShaderMaterial).set_shader_parameter("aspect", s.x / s.y)
		flash_rect.color.a = player.damage_flash * 0.45
	done_btn.visible = edit_mode
	plus_btn.visible = edit_mode
	minus_btn.visible = edit_mode
	if edit_mode:
		done_btn.position = Vector2(s.x * 0.5 - 70.0, 56.0)
		plus_btn.position = Vector2(s.x * 0.5 + 80.0, 56.0)
		minus_btn.position = Vector2(s.x * 0.5 - 140.0, 56.0)
	queue_redraw()

func _text(font: Font, t: String, pos: Vector2, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
	draw_string(font, pos + Vector2(1, 1), t, align, w, size, Color(0, 0, 0, 0.7))
	draw_string(font, pos, t, align, w, size, col)

func _draw() -> void:
	if player == null or main == null:
		return
	var s := get_viewport_rect().size
	var font := ThemeDB.fallback_font
	if main.state == "play" or edit_mode:
		var hp := clampf(player.health / 100.0, 0.0, 1.0)
		draw_rect(Rect2(20, 18, 200, 14), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(20, 18, 200.0 * hp, 14), Color(0.85, 0.25, 0.4))
		_text(font, "Волна %d    Убито %d" % [wave, kills], Vector2(20, 56), 18, Color.WHITE)
		_text(font, "%d FPS" % int(Engine.get_frames_per_second()), Vector2(s.x * 0.5 - 40.0, 24), 16, Color(0.8, 1.0, 0.8))
		if player.inv.size() > 0:
			var a: Dictionary = player.inv[player.cur]
			var nm: String = str(player.stats.get("name", ""))
			_text(font, nm, Vector2(s.x - 280.0, 30), 20, Color(0.85, 0.75, 1.0), HORIZONTAL_ALIGNMENT_RIGHT, 260.0)
			if player.cur != 2:
				var txt := "%d / %d" % [int(a["ammo"]), int(player.stats["mag"])]
				if player.state == "reload":
					txt = "перезарядка..."
				_text(font, txt, Vector2(s.x - 280.0, 62), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 260.0)
		if not edit_mode and not player.scoped():
			var c := s * 0.5
			var col := Color(1, 1, 1, 0.85)
			draw_line(c + Vector2(-12, 0), c + Vector2(-5, 0), col, 2.0)
			draw_line(c + Vector2(5, 0), c + Vector2(12, 0), col, 2.0)
			draw_line(c + Vector2(0, -12), c + Vector2(0, -5), col, 2.0)
			draw_line(c + Vector2(0, 5), c + Vector2(0, 12), col, 2.0)
		if hit_t > 0.0:
			var c2 := s * 0.5
			var hc := Color(1, 0.2, 0.2, 1) if hit_kill else Color(1, 1, 1, 1)
			draw_line(c2 + Vector2(-9, -9), c2 + Vector2(-4, -4), hc, 2.5)
			draw_line(c2 + Vector2(9, -9), c2 + Vector2(4, -4), hc, 2.5)
			draw_line(c2 + Vector2(-9, 9), c2 + Vector2(-4, 4), hc, 2.5)
			draw_line(c2 + Vector2(9, 9), c2 + Vector2(4, 4), hc, 2.5)
		if msg_t > 0.0:
			_text(font, msg, Vector2(0, 150), 34, Color(1, 0.9, 0.5), HORIZONTAL_ALIGNMENT_CENTER, s.x)
	if (not G.kbm) or edit_mode:
		_draw_controls(font, s)

func _draw_controls(font: Font, s: Vector2) -> void:
	if stick_idx != -1:
		draw_arc(stick_origin, 70.0, 0.0, TAU, 40, Color(1, 1, 1, 0.4), 3.0)
		draw_circle(stick_origin + stick * 60.0, 28.0, Color(1, 1, 1, 0.35))
	elif not edit_mode:
		var hint := Vector2(s.x * 0.14, s.y * 0.74)
		draw_arc(hint, 60.0, 0.0, TAU, 40, Color(1, 1, 1, 0.18), 2.0)
	for id in BTN_IDS:
		var p := _bpos(id)
		var r := _brad(id)
		var on := held.has(id)
		var active_slot := false
		if player != null and (id == "w1" and player.cur == 0 or id == "w2" and player.cur == 1 or id == "w3" and player.cur == 2):
			active_slot = true
		if id == "crouch" and crouch_on:
			active_slot = true
		var fill := Color(0.7, 0.5, 1.0, 0.45) if (on or active_slot) else Color(1, 1, 1, 0.12)
		draw_circle(p, r, fill)
		var edge := Color(1, 0.85, 0.3, 1.0) if (edit_mode and id == sel_btn) else Color(1, 1, 1, 0.5)
		draw_arc(p, r, 0.0, TAU, 36, edge, 2.5)
		var label: String = BTN_LABEL[id]
		var fs := 15
		if id == "w1":
			label = str(G.weapons[G.slot1]["name"])
			fs = 12
		elif id == "w2":
			label = str(G.weapons[G.slot2]["name"])
			fs = 12
		_text(font, label, p + Vector2(-r, 5), fs, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0)
	if edit_mode:
		_text(font, "Перетаскивай кнопки пальцем. Выбери кнопку и меняй размер + / -", Vector2(0, 130), 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, s.x)
