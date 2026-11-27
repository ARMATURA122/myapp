extends Node

const SAVE_PATH := "user://ruins_save.json"
const SLOTS := ["scope", "muzzle", "under", "mag"]
const SLOT_NAMES := {"scope": "Прицел", "muzzle": "Дульное", "under": "Подствольное", "mag": "Магазин"}
const WEAPON_IDS := ["ak", "m4", "smg", "shotgun", "sniper", "pistol"]

var weapons := {
	"ak": {"name": "AK-74", "dmg": 30.0, "rpm": 600.0, "mag": 30, "reload": 2.3, "spread": 0.010, "recoil": 1.0, "auto": true, "zoom": 1.0, "pellets": 1, "noise": 80.0},
	"m4": {"name": "M4A1", "dmg": 26.0, "rpm": 750.0, "mag": 30, "reload": 2.1, "spread": 0.008, "recoil": 0.8, "auto": true, "zoom": 1.0, "pellets": 1, "noise": 80.0},
	"smg": {"name": "MP5", "dmg": 19.0, "rpm": 900.0, "mag": 32, "reload": 1.8, "spread": 0.014, "recoil": 0.55, "auto": true, "zoom": 1.0, "pellets": 1, "noise": 65.0},
	"shotgun": {"name": "Дробовик", "dmg": 14.0, "rpm": 80.0, "mag": 6, "reload": 2.8, "spread": 0.05, "recoil": 2.2, "auto": false, "zoom": 1.0, "pellets": 8, "noise": 90.0},
	"sniper": {"name": "Снайперка", "dmg": 120.0, "rpm": 55.0, "mag": 5, "reload": 3.0, "spread": 0.001, "recoil": 3.0, "auto": false, "zoom": 3.0, "pellets": 1, "noise": 100.0},
	"pistol": {"name": "Пистолет", "dmg": 25.0, "rpm": 330.0, "mag": 12, "reload": 1.5, "spread": 0.012, "recoil": 0.9, "auto": false, "zoom": 1.0, "pellets": 1, "noise": 55.0},
}

var attachments := {
	"dot": {"name": "Коллиматор", "slot": "scope", "zoom": 1.4},
	"x4": {"name": "Оптика 4x", "slot": "scope", "zoom": 3.0},
	"x8": {"name": "Оптика 8x", "slot": "scope", "zoom": 6.0},
	"silencer": {"name": "Глушитель", "slot": "muzzle", "dmg": 0.92, "noise": 0.2},
	"brake": {"name": "Компенсатор", "slot": "muzzle", "recoil": 0.8},
	"grip": {"name": "Рукоять", "slot": "under", "recoil": 0.7, "spread": 0.9},
	"laser": {"name": "Лазер", "slot": "under", "spread": 0.8},
	"mag": {"name": "Увел. магазин", "slot": "mag", "mag": 1.5},
}

var slot1 := "ak"
var slot2 := "pistol"
var att := {}
var hud := {}
var fov := 75.0
var sens := 0.18
var res := 1.0
var fps_cap := 120
var kbm := false

var sfx := {}
var _blood_mesh: SphereMesh
var _blood_mat: StandardMaterial3D
var _tracer_mat: StandardMaterial3D
var _spark_mat: StandardMaterial3D

func _ready() -> void:
	load_data()
	_make_sounds()
	_blood_mesh = SphereMesh.new()
	_blood_mesh.radius = 0.025
	_blood_mesh.height = 0.05
	_blood_mesh.radial_segments = 5
	_blood_mesh.rings = 3
	_blood_mat = StandardMaterial3D.new()
	_blood_mat.albedo_color = Color(0.6, 0.02, 0.02)
	_blood_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tracer_mat = StandardMaterial3D.new()
	_tracer_mat.albedo_color = Color(1.0, 0.85, 0.4)
	_tracer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spark_mat = StandardMaterial3D.new()
	_spark_mat.albedo_color = Color(1.0, 0.7, 0.3)
	_spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	Engine.max_fps = fps_cap

# ------------------------------------------------------------ характеристики оружия с обвесами
func stats(wid: String) -> Dictionary:
	var w: Dictionary = weapons[wid].duplicate()
	var a: Dictionary = att.get(wid, {})
	for s in SLOTS:
		var id = a.get(s, "")
		if id == "" or not attachments.has(id):
			continue
		var at: Dictionary = attachments[id]
		if at.has("zoom"):
			w["zoom"] = at["zoom"]
		if at.has("dmg"):
			w["dmg"] = float(w["dmg"]) * float(at["dmg"])
		if at.has("noise"):
			w["noise"] = float(w["noise"]) * float(at["noise"])
		if at.has("recoil"):
			w["recoil"] = float(w["recoil"]) * float(at["recoil"])
		if at.has("spread"):
			w["spread"] = float(w["spread"]) * float(at["spread"])
		if at.has("mag"):
			w["mag"] = int(round(float(w["mag"]) * float(at["mag"])))
	return w

func hud_pos(id: String, def: Array) -> Array:
	if hud.has(id):
		var h: Array = hud[id]
		if h.size() >= 3:
			return [float(h[0]), float(h[1]), float(h[2])]
	return def

# ------------------------------------------------------------ сохранение
func save_data() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"slot1": slot1, "slot2": slot2, "att": att, "hud": hud, "fov": fov, "sens": sens, "res": res, "fps_cap": fps_cap}))

func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not (d is Dictionary):
		return
	slot1 = str(d.get("slot1", slot1))
	slot2 = str(d.get("slot2", slot2))
	if not weapons.has(slot1):
		slot1 = "ak"
	if not weapons.has(slot2):
		slot2 = "pistol"
	att = d.get("att", {})
	hud = d.get("hud", {})
	fov = float(d.get("fov", fov))
	sens = float(d.get("sens", sens))
	res = float(d.get("res", res))
	fps_cap = int(d.get("fps_cap", fps_cap))

# ------------------------------------------------------------ звуки (синтез, без файлов)
func _noise_wav(dur: float, decay: float, vol: float, freq: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(dur * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in n:
		var t := float(i) / rate
		var env := exp(-t * decay)
		var s := (rng.randf() * 2.0 - 1.0) * env * vol + sin(t * freq * TAU) * env * vol * 0.5
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w

func _make_sounds() -> void:
	sfx["shot"] = _noise_wav(0.25, 18.0, 0.9, 90.0)
	sfx["shot_s"] = _noise_wav(0.12, 35.0, 0.35, 200.0)
	sfx["click"] = _noise_wav(0.05, 120.0, 0.5, 1800.0)
	sfx["thud"] = _noise_wav(0.18, 25.0, 0.8, 60.0)
	sfx["swish"] = _noise_wav(0.2, 12.0, 0.3, 600.0)

func play(stream, vol := 0.0) -> void:
	if stream == null:
		return
	var pl := AudioStreamPlayer.new()
	pl.stream = stream
	pl.volume_db = vol
	add_child(pl)
	pl.finished.connect(pl.queue_free)
	pl.play()

# ------------------------------------------------------------ эффекты
func blood(pos: Vector3, dir: Vector3, amount := 14) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.6
	p.mesh = _blood_mesh
	p.material_override = _blood_mat
	p.direction = dir
	p.spread = 55.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.5
	p.gravity = Vector3(0, -9.0, 0)
	scene.add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)

func tracer(a: Vector3, b: Vector3) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var d := a.distance_to(b)
	if d < 0.5:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.012, 0.012, d)
	mi.mesh = bm
	mi.material_override = _tracer_mat
	scene.add_child(mi)
	mi.global_position = (a + b) * 0.5
	var up := Vector3.UP
	if absf((b - a).normalized().y) > 0.98:
		up = Vector3.RIGHT
	mi.look_at(b, up)
	get_tree().create_timer(0.05).timeout.connect(mi.queue_free)

func spark(pos: Vector3) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.07, 0.07, 0.07)
	mi.mesh = bm
	mi.material_override = _spark_mat
	scene.add_child(mi)
	mi.global_position = pos
	get_tree().create_timer(0.08).timeout.connect(mi.queue_free)
