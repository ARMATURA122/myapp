extends Node

const SAVE_PATH := "user://save_v2.json"
const MAX_LEVEL := 5
const UPGRADES := {"engine": "Двигатель", "tires": "Шины", "nitro": "Нитро"}

var money := 3000
var owned: Array = [0]
var selected := 0
var up: Dictionary = {}
var done: Array = []

# accel - разгон, top - макс. скорость (м/с), grip - сцепление, drift - доля сцепления при заносе (меньше = легче дрифт), steer - поворот
var cars: Array = [
	{"name": "M3 GTR", "price": 0, "accel": 20.0, "top": 52.0, "grip": 6.0, "drift": 0.45, "steer": 1.9, "width": 1.8, "length": 4.5, "color": Color(0.93, 0.94, 0.96), "style": "gtr"},
	{"name": "Muscle GT", "price": 20000, "accel": 25.0, "top": 58.0, "grip": 5.0, "drift": 0.40, "steer": 1.7, "width": 2.0, "length": 4.8, "color": Color(0.06, 0.06, 0.08), "style": "solid"},
	{"name": "Drift King", "price": 35000, "accel": 23.0, "top": 56.0, "grip": 4.5, "drift": 0.30, "steer": 2.1, "width": 1.85, "length": 4.4, "color": Color(1.0, 0.45, 0.05), "style": "solid"},
	{"name": "Hyper S", "price": 80000, "accel": 34.0, "top": 72.0, "grip": 7.0, "drift": 0.50, "steer": 2.0, "width": 2.0, "length": 4.6, "color": Color(1.0, 0.8, 0.0), "style": "solid"},
]

func _ready() -> void:
	load_game()

func levels(idx: int) -> Dictionary:
	var d: Dictionary = up.get(str(idx), {})
	return {"engine": int(d.get("engine", 0)), "tires": int(d.get("tires", 0)), "nitro": int(d.get("nitro", 0))}

func upgrade_cost(idx: int, kind: String) -> int:
	var lv: int = levels(idx)[kind]
	return 1500 * (lv + 1)

func buy_upgrade(idx: int, kind: String) -> bool:
	var lv: Dictionary = levels(idx)
	if lv[kind] >= MAX_LEVEL:
		return false
	var cost: int = upgrade_cost(idx, kind)
	if money < cost:
		return false
	money -= cost
	lv[kind] += 1
	up[str(idx)] = lv
	save_game()
	return true

func buy_car(idx: int) -> bool:
	var price: int = cars[idx]["price"]
	if idx in owned or money < price:
		return false
	money -= price
	owned.append(idx)
	save_game()
	return true

func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"money": money, "owned": owned, "selected": selected, "up": up, "done": done}))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if d is Dictionary:
		money = int(d.get("money", money))
		selected = int(d.get("selected", 0))
		owned = []
		for x in d.get("owned", [0]):
			owned.append(int(x))
		done = []
		for x in d.get("done", []):
			done.append(int(x))
		up = d.get("up", {})
