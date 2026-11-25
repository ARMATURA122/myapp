extends Node

const SAVE_PATH := "user://save.json"
const MAX_LEVEL := 5
const UPGRADES := {"engine": "Двигатель", "tires": "Шины", "nitro": "Нитро"}

var money := 5000
var owned: Array = [0]
var selected := 0
var up: Dictionary = {}

# power - мощность, top - макс. скорость (м/с), grip - сцепление, drift - насколько легко уводит в занос (меньше = легче)
var cars: Array = [
	{"name": "Street Hatch", "price": 0, "power": 42.0, "top": 42.0, "grip": 4.5, "drift": 0.8, "mass": 950.0, "width": 1.8, "length": 3.9, "color": Color(0.85, 0.1, 0.1)},
	{"name": "Muscle GT", "price": 18000, "power": 60.0, "top": 50.0, "grip": 4.2, "drift": 0.6, "mass": 1400.0, "width": 2.0, "length": 4.6, "color": Color(0.05, 0.05, 0.07)},
	{"name": "Drift King", "price": 30000, "power": 55.0, "top": 48.0, "grip": 3.8, "drift": 0.45, "mass": 1150.0, "width": 1.9, "length": 4.3, "color": Color(0.1, 0.35, 0.95)},
	{"name": "Hyper S", "price": 70000, "power": 85.0, "top": 58.0, "grip": 5.2, "drift": 0.7, "mass": 1100.0, "width": 2.0, "length": 4.5, "color": Color(1.0, 0.75, 0.0)},
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
	var cost := upgrade_cost(idx, kind)
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
		f.store_string(JSON.stringify({"money": money, "owned": owned, "selected": selected, "up": up}))

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
		up = d.get("up", {})
