extends RefCounted

static func _mat(c: Color, metal := 0.0, rough := 0.6, emis := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	if emis > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emis
	return m

static func _box(parent: Node, size: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi

static func _cyl(parent: Node, r: float, length: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = length
	cm.radial_segments = 10
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = Vector3(90, 0, 0)
	parent.add_child(mi)
	return mi

static func _def(wid: String) -> Dictionary:
	match wid:
		"ak":
			return {"body": [Vector3(0.06, 0.09, 0.42), Vector3(0, 0, -0.05), "metal"], "barrel": [0.45, -0.5, 0.03],
				"hg": [Vector3(0.065, 0.06, 0.26), Vector3(0, 0, -0.36), "wood"], "stock": [Vector3(0.05, 0.1, 0.3), Vector3(0, -0.02, 0.3), "wood"],
				"mag": [Vector3(0.04, 0.17, 0.07), Vector3(0, -0.13, -0.12), -12.0], "grip": [Vector3(0.04, 0.1, 0.05), Vector3(0, -0.09, 0.1), 15.0],
				"muzzle": -0.72, "hand1": Vector3(0, -0.1, 0.1), "hand2": Vector3(0, -0.05, -0.36), "hg_z": -0.36, "sight": 0.075}
		"m4":
			return {"body": [Vector3(0.055, 0.085, 0.40), Vector3(0, 0, -0.05), "metal"], "barrel": [0.4, -0.48, 0.03],
				"hg": [Vector3(0.06, 0.055, 0.28), Vector3(0, 0, -0.34), "poly"], "stock": [Vector3(0.045, 0.09, 0.25), Vector3(0, -0.01, 0.28), "poly"],
				"mag": [Vector3(0.04, 0.15, 0.06), Vector3(0, -0.12, -0.1), 0.0], "grip": [Vector3(0.04, 0.1, 0.05), Vector3(0, -0.09, 0.1), 15.0],
				"muzzle": -0.68, "hand1": Vector3(0, -0.1, 0.1), "hand2": Vector3(0, -0.04, -0.34), "hg_z": -0.34, "sight": 0.075}
		"smg":
			return {"body": [Vector3(0.05, 0.08, 0.30), Vector3(0, 0, -0.03), "metal"], "barrel": [0.2, -0.32, 0.02],
				"hg": [Vector3(0.055, 0.05, 0.14), Vector3(0, -0.01, -0.2), "poly"], "stock": [Vector3(0.03, 0.07, 0.22), Vector3(0, 0, 0.25), "poly"],
				"mag": [Vector3(0.03, 0.2, 0.045), Vector3(0, -0.14, -0.08), 0.0], "grip": [Vector3(0.04, 0.1, 0.05), Vector3(0, -0.09, 0.08), 12.0],
				"muzzle": -0.42, "hand1": Vector3(0, -0.1, 0.08), "hand2": Vector3(0, -0.05, -0.2), "hg_z": -0.2, "sight": 0.065}
		"shotgun":
			return {"body": [Vector3(0.055, 0.08, 0.3), Vector3(0, 0, 0.0), "metal"], "barrel": [0.6, -0.45, 0.02],
				"hg": [Vector3(0.04, 0.04, 0.45), Vector3(0, -0.035, -0.4), "metal"], "stock": [Vector3(0.05, 0.1, 0.3), Vector3(0, -0.02, 0.3), "wood"],
				"mag": [Vector3(0.03, 0.02, 0.05), Vector3(0, -0.06, 0.0), 0.0], "grip": [Vector3(0.04, 0.1, 0.05), Vector3(0, -0.09, 0.1), 15.0],
				"pump": [Vector3(0.055, 0.05, 0.14), Vector3(0, -0.04, -0.35)],
				"muzzle": -0.78, "hand1": Vector3(0, -0.1, 0.1), "hand2": Vector3(0, -0.05, -0.35), "hg_z": -0.4, "sight": 0.06}
		"sniper":
			return {"body": [Vector3(0.055, 0.085, 0.45), Vector3(0, 0, 0.0), "metal"], "barrel": [0.8, -0.62, 0.02],
				"hg": [Vector3(0.05, 0.05, 0.3), Vector3(0, -0.01, -0.4), "poly"], "stock": [Vector3(0.05, 0.11, 0.35), Vector3(0, -0.02, 0.35), "poly"],
				"mag": [Vector3(0.035, 0.08, 0.06), Vector3(0, -0.08, 0.0), 0.0], "grip": [Vector3(0.04, 0.1, 0.05), Vector3(0, -0.09, 0.12), 15.0],
				"muzzle": -1.0, "hand1": Vector3(0, -0.1, 0.12), "hand2": Vector3(0, -0.05, -0.4), "hg_z": -0.4, "sight": 0.075, "builtin_scope": true}
		_:
			return {"body": [Vector3(0.035, 0.05, 0.2), Vector3(0, 0.03, -0.06), "metal"], "barrel": [0.02, -0.15, 0.03],
				"hg": [Vector3(0.03, 0.03, 0.06), Vector3(0, 0.0, -0.1), "poly"], "stock": null,
				"mag": [Vector3(0.028, 0.1, 0.04), Vector3(0, -0.075, 0.04), 0.0], "grip": [Vector3(0.032, 0.11, 0.055), Vector3(0, -0.05, 0.05), 12.0],
				"muzzle": -0.17, "hand1": Vector3(0, -0.08, 0.05), "hand2": Vector3(-0.03, -0.09, 0.04), "hg_z": -0.1, "sight": 0.065}

static func _arms(root: Node3D, h1: Vector3, h2: Vector3) -> void:
	var glove := _mat(Color(0.09, 0.09, 0.1), 0.0, 0.9)
	var sleeve := _mat(Color(0.18, 0.2, 0.16), 0.0, 0.9)
	_box(root, Vector3(0.06, 0.07, 0.09), h1, glove)
	_box(root, Vector3(0.075, 0.075, 0.42), h1 + Vector3(0.07, -0.1, 0.28), sleeve, Vector3(-14, -12, 0))
	_box(root, Vector3(0.06, 0.065, 0.1), h2, glove)
	_box(root, Vector3(0.075, 0.075, 0.5), h2 + Vector3(-0.14, -0.1, 0.28), sleeve, Vector3(-12, 20, 0))

static func build(wid: String, att: Dictionary) -> Node3D:
	var d: Dictionary = _def(wid)
	var root := Node3D.new()
	var metal := _mat(Color(0.13, 0.13, 0.15), 0.8, 0.35)
	var poly := _mat(Color(0.07, 0.07, 0.08), 0.1, 0.8)
	var wood := _mat(Color(0.38, 0.22, 0.1), 0.0, 0.7)
	var mats := {"metal": metal, "poly": poly, "wood": wood}
	var b: Array = d["body"]
	_box(root, b[0], b[1], mats[b[2]])
	var br: Array = d["barrel"]
	_box(root, Vector3(0.022, 0.022, br[0]), Vector3(0, br[2], br[1]), metal)
	var hg: Array = d["hg"]
	_box(root, hg[0], hg[1], mats[hg[2]])
	if d["stock"] != null:
		var st: Array = d["stock"]
		_box(root, st[0], st[1], mats[st[2]])
	var gr: Array = d["grip"]
	_box(root, gr[0], gr[1], poly, Vector3(gr[2], 0, 0))

	# магазин (отдельный узел, чтобы анимировать перезарядку)
	var mg: Array = d["mag"]
	var mag := Node3D.new()
	mag.name = "Mag"
	mag.position = mg[1]
	mag.rotation_degrees = Vector3(mg[2], 0, 0)
	root.add_child(mag)
	var ms: Vector3 = mg[0]
	var k := 1.0
	if att.get("mag", "") == "mag":
		k = 1.5
	_box(mag, Vector3(ms.x, ms.y * k, ms.z), Vector3(0, -ms.y * (k - 1.0) * 0.5, 0), poly)

	if d.has("pump"):
		var pm: Array = d["pump"]
		var pump := Node3D.new()
		pump.name = "Pump"
		pump.position = pm[1]
		root.add_child(pump)
		_box(pump, pm[0], Vector3.ZERO, wood)

	# обвесы
	var hgz: float = d["hg_z"]
	var sight: float = d["sight"]
	var under = att.get("under", "")
	if under == "grip":
		_box(root, Vector3(0.035, 0.11, 0.04), Vector3(0, -0.09, hgz), poly)
	elif under == "laser":
		_box(root, Vector3(0.03, 0.03, 0.08), Vector3(0.05, -0.03, hgz - 0.04), _mat(Color(1, 0.1, 0.1), 0.0, 0.5, 2.0))
	var scope = att.get("scope", "")
	if scope == "" and d.has("builtin_scope"):
		scope = "x4"
	if scope == "x4" or scope == "x8":
		var slen := 0.22 if scope == "x4" else 0.3
		_cyl(root, 0.03, slen, Vector3(0, 0.115, -0.05), poly)
		_cyl(root, 0.036, 0.04, Vector3(0, 0.115, -0.05 - slen * 0.5), poly)
		_box(root, Vector3(0.02, 0.05, 0.03), Vector3(0, 0.075, -0.05), poly)
		_cyl(root, 0.026, 0.01, Vector3(0, 0.115, -0.05 - slen * 0.5 - 0.02), _mat(Color(0.2, 0.5, 1.0), 0.0, 0.1, 1.5))
		sight = 0.115
	elif scope == "dot":
		_box(root, Vector3(0.05, 0.045, 0.05), Vector3(0, 0.085, -0.1), poly)
		_box(root, Vector3(0.012, 0.012, 0.012), Vector3(0, 0.09, -0.125), _mat(Color(1, 0.1, 0.1), 0.0, 0.5, 3.0))
		sight = 0.095
	else:
		_box(root, Vector3(0.012, 0.035, 0.012), Vector3(0, sight - 0.01, d["muzzle"] + 0.06), metal)
	var mz: float = d["muzzle"]
	var muz = att.get("muzzle", "")
	if muz == "silencer":
		_cyl(root, 0.024, 0.22, Vector3(0, br[2], mz - 0.08), _mat(Color(0.05, 0.05, 0.06), 0.6, 0.5))
		mz -= 0.2
	elif muz == "brake":
		_box(root, Vector3(0.04, 0.04, 0.06), Vector3(0, br[2], mz - 0.02), metal)
		mz -= 0.05

	var marker := Marker3D.new()
	marker.name = "Muzzle"
	marker.position = Vector3(0, br[2], mz)
	root.add_child(marker)
	var fl := MeshInstance3D.new()
	fl.name = "Flash"
	var qm := QuadMesh.new()
	qm.size = Vector2(0.28, 0.28) if muz != "silencer" else Vector2(0.1, 0.1)
	fl.mesh = qm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(1.0, 0.75, 0.3, 0.9)
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fl.material_override = fm
	fl.visible = false
	marker.add_child(fl)

	_arms(root, d["hand1"], d["hand2"])
	root.set_meta("sight_y", sight)
	return root

static func build_knife() -> Node3D:
	var root := Node3D.new()
	var steel := _mat(Color(0.75, 0.78, 0.82), 0.9, 0.2)
	var poly := _mat(Color(0.07, 0.07, 0.08), 0.1, 0.8)
	var glove := _mat(Color(0.09, 0.09, 0.1), 0.0, 0.9)
	var sleeve := _mat(Color(0.18, 0.2, 0.16), 0.0, 0.9)
	_box(root, Vector3(0.012, 0.045, 0.24), Vector3(0, 0.0, -0.2), steel)
	_box(root, Vector3(0.04, 0.05, 0.015), Vector3(0, 0.0, -0.075), poly)
	_box(root, Vector3(0.03, 0.04, 0.12), Vector3(0, 0.0, 0.0), poly)
	_box(root, Vector3(0.06, 0.07, 0.09), Vector3(0, -0.01, 0.02), glove)
	_box(root, Vector3(0.075, 0.075, 0.45), Vector3(0.05, -0.1, 0.28), sleeve, Vector3(-14, -10, 0))
	root.rotation_degrees = Vector3(0, 0, 0)
	root.set_meta("sight_y", 0.0)
	return root
