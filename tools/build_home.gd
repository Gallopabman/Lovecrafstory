extends "res://tools/build_hospital.gd"
## Genera res://scenes/levels/home.tscn: la casa del protagonista, donde empieza el juego
## (refugio inicial "home"). Una planta chica y un ático cerrado con llave: la madre,
## médica, guardó ahí sus insumos para que él no recaiga. En el ático hay un jefe, pero
## la puerta no se puede abrir (todavía). Andamio de una sola pasada, como los otros.
## Uso: <godot> --headless --path . -s res://tools/build_home.gd
##
## Planta (x = este, z = sur), 13 x 10 m:
##   Pieza        x 0-5,    z 0-4.5      Baño      x 5-7.5, z 0-4.5
##   Living       x 0-7.5,  z 4.5-10     (puerta de calle en z = 10, x = 3.5)
##   Cocina       x 7.5-13, z 2-10       Escalera  x 7.5-13, z 0-2 (sube hacia el oeste)
##   Ático        x 0-7.5,  z 0-10, piso a 2.9 m (puerta en x = 7.5, z = 1, desde el descanso)

const OUT := "res://scenes/levels/home.tscn"
const HOME_MAT_DIR := "res://assets/materials/home/"
const HC := 2.8         # alto de la planta baja
const AF := 2.9         # piso del ático
const TOP := 5.2        # techo
const REFUGE := &"home"


func _initialize() -> void:
	GreyBoxScript = load("res://scripts/world/grey_box.gd")
	PropScript = load("res://scripts/world/prop.gd")
	InspectableScript = load("res://scripts/world/inspectable.gd")
	FlickerScript = load("res://scripts/world/flicker_light.gd")
	GatedScript = load("res://scripts/world/sanity_gated.gd")
	RefugeScript = load("res://scripts/world/refuge_zone.gd")
	seed(2024)
	_make_materials()
	scene_root = Node3D.new()
	scene_root.name = "Home"
	for g in ["Structure", "Lights", "Props", "Refuge", "Items", "Inspectables", "Secrets", "Enemies"]:
		groups[g] = _add(scene_root, Node3D.new(), g)
	groups.Structure.add_to_group(&"nav_source", true)
	groups.Props.add_to_group(&"nav_source", true)

	_environment()
	_shell_home()
	_rooms()
	_home_refuge()
	_attic()
	_home_items()
	_home_systems()

	var packed := PackedScene.new()
	packed.pack(scene_root)
	var err := ResourceSaver.save(packed, OUT)
	print("Guardado %s (%s), nodos: %d" % [OUT, error_string(err), _count(scene_root)])
	scene_root.free()
	quit()


func _make_materials() -> void:
	super._make_materials()
	DirAccess.make_dir_recursive_absolute(HOME_MAT_DIR)
	var shader: Shader = load("res://shaders/ps1_spatial.gdshader")
	var defs := {
		"home_wall": ["wall_plaster", Color(0.8, 0.74, 0.62), 1.2],
		"home_wall2": ["wall_plaster", Color(0.62, 0.68, 0.72), 1.2],
		"home_wall3": ["wall_plaster", Color(0.7, 0.62, 0.55), 1.2],
		"kitchen_tile": ["floor_tiles", Color(0.85, 0.8, 0.7), 0.6],
		"attic_wood": ["wood_floor", Color(0.45, 0.38, 0.3), 0.7],
		"brick": ["wall_plaster", Color(0.55, 0.3, 0.24), 2.0],
		"fog_window": ["", Color(0.55, 0.56, 0.58), 1.0],
		"bulb": ["", Color(1.0, 0.85, 0.6), 1.0],
		"oxygen": ["metal_green", Color(0.3, 0.55, 0.35), 1.0],
		"pills": ["", Color(0.85, 0.85, 0.9), 1.0],
		"scrawl_red": ["", Color(0.45, 0.04, 0.03), 1.0],
	}
	for key: String in defs:
		var d: Array = defs[key]
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter(&"albedo_color", d[1])
		if d[0] != "":
			m.set_shader_parameter(&"albedo_texture", load(TEX_DIR + d[0] + ".png"))
			m.set_shader_parameter(&"world_uv", true)
			m.set_shader_parameter(&"world_uv_scale", d[2])
		if key == "fog_window":
			m.set_shader_parameter(&"emission_color", Color(0.35, 0.36, 0.38))
		if key == "bulb":
			m.set_shader_parameter(&"emission_color", Color(1.0, 0.8, 0.5))
		var path := HOME_MAT_DIR + "m_%s.tres" % key
		ResourceSaver.save(m, path)
		mats[key] = load(path)


# --- Helpers ------------------------------------------------------------------------

func _slab(x0: float, z0: float, x1: float, z1: float, top: float, thickness: float, mat: String,
		collision := true) -> Node3D:
	return _box(groups.Structure, "Slab", Vector3((x0 + x1) / 2, top - thickness / 2, (z0 + z1) / 2),
		Vector3(x1 - x0, thickness, z1 - z0), mat, collision)


func _pickup(base_name: String, item_id: String, pos: Vector3, count := 1) -> void:
	_instance("res://scenes/world/pickup.tscn", groups.Items, base_name, pos,
		{"item": load("res://assets/items/%s.tres" % item_id), "count": count})


func _bulb(pos: Vector3, energy := 0.9, flicker := false, parent: Node = null, with_light := true) -> void:
	var holder: Node = parent if parent else groups.Lights
	_box(holder, "Cord", pos + Vector3(0, 0.25, 0), Vector3(0.015, 0.5, 0.015), "bars", false)
	_box(holder, "Bulb", pos, Vector3(0.07, 0.09, 0.07), "bulb", false)
	if with_light:
		_point_light(pos + Vector3(0, -0.2, 0), Color(1.0, 0.78, 0.52), energy, 6.0, flicker, holder)


func _fog_window(pos: Vector3, size: Vector3) -> void:
	_box(groups.Structure, "FogWindow", pos, size, "fog_window", false)


func _slot_h(slot_id: String, base_name: String, pos: Vector3) -> Node3D:
	var slot := _slot(slot_id, base_name, pos)
	slot.set("refuge_id", REFUGE)
	return slot


func _station_h(pos: Vector3, parent: Node, base_name: String, kind: int, radius := 0.9) -> void:
	var s := Area3D.new()
	s.set_script(load("res://scripts/world/shelter_station.gd"))
	s.set("kind", kind)
	s.set("radius", radius)
	s.set("refuge_id", REFUGE)
	s.position = pos
	_add(parent, s, base_name)


# --- La casa ------------------------------------------------------------------------

func _shell_home() -> void:
	# Pisos.
	_floor(0, 0, 5, 4.5, 0.0, "wood")
	_floor(5, 0, 7.5, 4.5, 0.0, "floor")
	_floor(0, 4.5, 7.5, 10, 0.0, "wood")
	_floor(7.5, 2, 13, 10, 0.0, "kitchen_tile")
	# El terreno, bien por debajo de los pisos (a la misma altura parpadeaban).
	_box(groups.Structure, "Ground", Vector3(6.5, -0.27, 5), Vector3(14, 0.3, 11), "concrete")
	# Techo de la planta baja (= piso del ático) y de la cocina; techo de la casa.
	_slab(0, 0, 7.5, 10, AF, AF - HC, "attic_wood")
	_slab(7.5, 2, 13, 10, HC + 0.02, 0.02, "home_wall", false)
	_slab(0, 0, 13, 10, TOP + 0.1, 0.1, "attic_wood", false)
	# Paredes exteriores, con la puerta de calle y las ventanas (dan a la niebla).
	_wall("x", 10.0, -TE / 2, 13.0 + TE / 2, 0.0, TOP, TE,
		[[3.5, 1.2, 0.0, 2.2], [1.3, 1.2, 1.0, 2.1], [6.0, 1.2, 1.0, 2.1], [10.5, 1.2, 1.0, 2.1]], "home_wall", false)
	_wall("x", 0.0, -TE / 2, 13.0 + TE / 2, 0.0, TOP, TE, [[2.5, 1.0, 1.1, 2.0]], "home_wall2", false)
	_wall("z", 0.0, 0.0, 10.0, 0.0, TOP, TE, [], "home_wall", false)
	_wall("z", 13.0, 0.0, 10.0, 0.0, TOP, TE, [], "home_wall", false)
	for x in [1.3, 6.0, 10.5]:
		_fog_window(Vector3(x, 1.55, 10.35), Vector3(1.3, 1.2, 0.05))
	_fog_window(Vector3(2.5, 1.55, -0.35), Vector3(1.1, 1.0, 0.05))
	# Sin electricidad, lo único que entra es la claridad gris de la niebla.
	for x in [1.3, 6.0, 10.5]:
		_point_light(Vector3(x, 1.6, 9.3), Color(0.7, 0.75, 0.8), 0.35, 3.5)
	_point_light(Vector3(2.5, 1.6, 0.7), Color(0.7, 0.75, 0.8), 0.3, 3.0)
	# Paredes interiores.
	_wall("x", 4.5, 0.0, 7.5, 0.0, HC, T, [[2.5, 1.0, 0.0, 2.1], [6.3, 1.0, 0.0, 2.1]], "home_wall3", false)
	_wall("z", 5.0, 0.0, 4.5, 0.0, HC, T, [], "home_wall2", false)
	# x = 7.5: la escalera (con la puerta del ático arriba), el baño y el living con el paso a la cocina.
	_wall("z", 7.5, 0.0, 2.0, 0.0, TOP, T, [[1.0, 1.0, AF, AF + 2.0]], "home_wall", false)
	_wall("z", 7.5, 2.0, 4.5, 0.0, TOP, T, [], "home_wall", false)
	_wall("z", 7.5, 4.5, 10.0, 0.0, HC, T, [[6.75, 2.5, 0.0, 2.3]], "home_wall", false)
	_wall("z", 7.5, 4.5, 10.0, HC, TOP - HC, T, [], "attic_wood", false)
	# La escalera: pared contra la cocina (con el paso abajo, al este) y la rampa que sube al oeste.
	_wall("x", 2.0, 7.5, 11.8, 0.0, TOP, T, [], "home_wall", false)
	_floor(7.5, 0, 13, 2, 0.0, "wood")
	var run := 12.8 - 8.6
	var ramp := _box(groups.Structure, "StairRamp", Vector3((12.8 + 8.6) / 2, AF / 2 - 0.05, 1.0),
		Vector3(Vector2(run, AF).length(), 0.1, 1.5), "dark_wood" if mats.has("dark_wood") else "wood", true, false)
	ramp.rotation.z = -atan2(AF, run)
	for i in 10:
		var h := AF * (i + 1) / 10.0
		var x := 12.8 - run * (i + 0.5) / 10.0
		_box(groups.Structure, "Step", Vector3(x, h / 2, 1.0), Vector3(run / 10.0, h, 1.5), "wood", false)
	_slab(7.6, 0.15, 8.6, 1.85, AF, 0.1, "wood")
	_box(groups.Structure, "Handrail", Vector3(10.6, 1.9, 1.75), Vector3(4.6, 0.05, 0.05), "rail", false)
	_bulb(Vector3(9.5, 4.6, 1.0), 0.6, true)
	_inspect(Vector3(12.3, 1.2, 1.4), ["La escalera al ático. Arriba algo se arrastra sobre las cajas.",
		"Siempre le dije a mamá que eran ratas. Ella nunca me contestó."], 1.0)


func _rooms() -> void:
	# Living (x 0-7.5, z 4.5-10).
	_prop("rugRectangle", Vector3(3.8, 0.005, 7.0), 0)
	_prop("loungeSofa", Vector3(3.8, 0, 5.2), 0)
	_prop("tableCoffee", Vector3(3.8, 0, 6.6), 0)
	_prop("loungeChair", Vector3(6.6, 0, 6.8), -90)
	_prop("cabinetTelevision", Vector3(4.67, 0, 9.55), 180)  # posición elegida por el usuario en el editor
	_prop("televisionVintage", Vector3(4.61, 0.55, 9.55), 180)
	_prop("bookcaseClosed", Vector3(7.1, 0, 9.0), -90)
	_prop("lampRoundFloor", Vector3(0.5, 0, 9.4))
	_bulb(Vector3(3.8, HC - 0.55, 7.0), 0.8, false, null, false)
	_inspect(Vector3(4.61, 0.9, 9.4), ["La tele vieja de la abuela. Mamá nunca quiso tirarla."])
	# Cocina (x 7.5-13, z 2-10).
	for p in [[Vector3(12.6, 0, 3.0), -90], [Vector3(12.6, 0, 3.9), -90]]:
		_prop("kitchenCabinet", p[0], p[1])
	_prop("kitchenSink", Vector3(12.6, 0, 4.8), -90)
	_prop("electric_stove", Vector3(12.6, 0, 5.8), -90)
	_prop("kitchenFridge", Vector3(12.55, 0, 7.0), -90)
	_prop("kitchenMicrowave", Vector3(12.65, 0.9, 3.0), -90)
	_prop("table", Vector3(9.8, 0, 6.5), 0)
	_prop("chair", Vector3(9.8, 0, 7.4), 180)
	_prop("chair", Vector3(9.8, 0, 5.6), 0)
	_prop("chair", Vector3(8.9, 0, 6.5), 90)
	_prop("trashcan", Vector3(8.0, 0, 9.4))
	_bulb(Vector3(9.8, HC - 0.55, 6.5), 0.8, false, null, false)
	_inspect(Vector3(12.5, 1.3, 7.0), ["Imanes de farmacias en la heladera. Una foto: mamá con guardapolvo, sonriendo cansada.",
		"Abajo, con su letra: \"Dr. M. Ibáñez - Guardia, San Judas\"."], 1.0)
	# Pieza (x 0-5, z 0-4.5).
	_prop("desk", Vector3(3.8, 0, 0.5), 180)
	_prop("chairDesk", Vector3(3.8, 0, 1.3), 0)
	_prop("bookcaseOpenLow", Vector3(0.45, 0, 3.8), 90)
	_prop("lampRoundTable", Vector3(4.2, 0.76, 0.5), 0)
	_bulb(Vector3(2.5, HC - 0.55, 2.2), 0.7, false, null, false)
	_inspect(Vector3(3.8, 1.0, 0.7), ["Mi escritorio. Folletos del centro de día y un calendario con días tachados.",
		"Doscientos doce días tachados. Después, nada."], 1.0)
	# Baño (x 5-7.5, z 0-4.5).
	_prop("toilet", Vector3(7.0, 0, 0.6), -90)
	_prop("bathroomSink", Vector3(5.5, 0, 0.45), 0)
	_prop("bathroomMirror", Vector3(5.5, 1.25, 0.12), 0)
	_bulb(Vector3(6.25, HC - 0.45, 2.0), 0.5, true, null, false)
	_inspect(Vector3(5.5, 1.1, 0.5), ["La cajita azul de la mañana, abierta. La tomé.",
		"¿La tomé?"], 0.9)


## El refugio inicial: la casa (mismos espacios que los otros refugios).
func _home_refuge() -> void:
	var zone := Area3D.new()
	zone.set_script(RefugeScript)
	zone.set("use_shelter", true)
	zone.set("refuge_id", REFUGE)
	zone.position = Vector3(6.5, 1.4, 5.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(12.8, 2.8, 9.8)
	shape.shape = box
	_add(groups.Refuge, zone, "RefugeZone")
	_add(zone, shape, "Shape")

	# El plano, en un corcho de la cocina.
	_box(groups.Refuge, "BlueprintBoard", Vector3(12.88, 1.6, 8.7), Vector3(0.03, 0.7, 1.0), "cork", false)
	_box(groups.Refuge, "BlueprintPaper", Vector3(12.84, 1.62, 8.7), Vector3(0.01, 0.5, 0.8), "paper", false)
	var title := Label3D.new()
	title.text = "PLANO"
	title.font = load("res://assets/fonts/pixel_operator/PixelOperator.ttf")
	title.font_size = 16
	title.pixel_size = 0.008
	title.modulate = Color(0.25, 0.2, 0.3)
	title.position = Vector3(12.84, 1.78, 8.7)
	title.rotation_degrees.y = -90
	_add(groups.Refuge, title, "BlueprintTitle")
	_station_h(Vector3(12.3, 1.2, 8.7), groups.Refuge, "BlueprintStation", 0, 1.1)
	_prop("radio", Vector3(7.1, 1.85, 9.0), -90)
	_station_h(Vector3(6.6, 1.2, 9.0), groups.Refuge, "RadioStation", 3)

	var warm := Color(1.0, 0.7, 0.42)
	# Fuego: el hogar a leña del living (apagado -> leños -> fuego grande).
	_box(groups.Structure, "Fireplace", Vector3(0.35, 0.6, 7.5), Vector3(0.5, 1.2, 1.6), "brick")
	_box(groups.Structure, "FireplaceMouth", Vector3(0.62, 0.4, 7.5), Vector3(0.05, 0.6, 0.9), "soot", false)
	_box(groups.Structure, "Chimney", Vector3(0.3, 2.0, 7.5), Vector3(0.4, 1.6, 1.0), "brick", false)
	var fire := _slot_h("fire", "SlotFire", Vector3(0.7, 0, 7.5))
	_inspect(Vector3(0, 0.6, 0), ["El hogar a leña, frío. Se podría prender. (Ver el plano.)"], 0.9, _only(fire, 0))
	for level in [1, 2]:
		var holder := _only(fire, level)
		_box(holder, "Logs", Vector3(-0.1, 0.12, 0), Vector3(0.35, 0.15, 0.6), "planks", false)
		_box(holder, "Embers", Vector3(-0.1, 0.22, 0), Vector3(0.3, 0.04, 0.5), "ember", false)
		_point_light(Vector3(0.3, 0.6, 0), warm, 1.2 if level == 1 else 1.8, 6.0 if level == 1 else 8.0, true, holder)
	_loop_sound(_from(fire, 1), "fire", Vector3(0, 0.5, 0), -8.0)
	_station_h(Vector3(0.5, 0.6, 0), _from(fire, 1), "CookStation", 1)

	# Electricidad: el grupo electrógeno del patio, en la puerta de atrás de la cocina.
	var power := _slot_h("power", "SlotPower", Vector3(12.4, 0, 9.4))
	var p0 := _only(power, 0)
	_prop("washer", Vector3.ZERO, -90, {"parent": p0, "tint": Color(0.3, 0.32, 0.3)})
	_inspect(Vector3(-0.3, 0.6, 0), ["El grupo electrógeno de mamá. Le faltan cables. (Ver el plano.)"], 0.9, p0)
	_point_light(Vector3(-2.6, 1.0, -2.9), Color(1.0, 0.75, 0.45), 0.4, 3.5, true, p0)  # una vela en la mesa
	var p1 := _from(power, 1)
	_prop("washer", Vector3.ZERO, -90, {"parent": p1, "tint": Color(0.55, 0.6, 0.5)})
	_loop_sound(p1, "generator", Vector3(0, 0.5, 0), -18.0)
	_point_light(Vector3(-8.6, 2.2, -2.4), warm, 0.9, 7.0, false, p1)
	_point_light(Vector3(-2.6, 2.2, -2.9), warm, 0.9, 7.0, false, p1)
	var p2 := _only(power, 2)
	_point_light(Vector3(-10.0, 2.2, -7.0), warm, 0.6, 5.0, false, p2)

	# Cama: el colchón tirado -> la cama armada -> con mantas.
	var bed := _slot_h("bed", "SlotBed", Vector3(1.2, 0, 1.6))
	var b0 := _only(bed, 0)
	_box(b0, "Mattress", Vector3(0, 0.08, 0), Vector3(0.95, 0.16, 2.0), "cloth", false)
	_box(b0, "Clothes", Vector3(0.6, 0.03, 1.2), Vector3(0.5, 0.06, 0.4), "blanket", false)
	_inspect(Vector3(0, 0.3, 0), ["El colchón en el piso. Hace meses que no armo la cama. (Ver el plano.)"], 1.0, b0)
	_prop("bedSingle", Vector3.ZERO, 0, {"parent": _only(bed, 1)})
	var b2 := _only(bed, 2)
	_prop("bedSingle", Vector3.ZERO, 0, {"parent": b2})
	_box(b2, "Blanket", Vector3(0, 0.47, 0.25), Vector3(0.72, 0.06, 1.3), "blanket", false)
	_station_h(Vector3(0.6, 0.5, 0), _from(bed, 1), "RestStation", 2, 1.1)

	# Ventanas del living: tablones -> cortinas.
	var windows := _slot_h("windows", "SlotWindows", Vector3.ZERO)
	var w1 := _from(windows, 1)
	var w2 := _only(windows, 2)
	for x in [1.3, 6.0]:
		for y in [1.15, 1.5, 1.85]:
			_box(w1, "Plank", Vector3(x + randf_range(-0.05, 0.05), y, 9.8), Vector3(1.4, 0.2, 0.04), "planks", false)
		for dx in [-0.75, 0.75]:
			_prop("curtain", Vector3(x + dx, 0, 9.75), 0, {"parent": w2, "h": 2.3, "tint": Color(0.5, 0.35, 0.3)})

	# Decoración: fotos con mamá -> plantas y alfombra.
	var decor := _slot_h("decor", "SlotDecor", Vector3.ZERO)
	var d1 := _from(decor, 1)
	for pic in [[Vector3(7.38, 1.7, 5.6), "photo"], [Vector3(7.38, 1.55, 8.0), "photo2"]]:
		_box(d1, "Frame", pic[0], Vector3(0.03, 0.5, 0.42), "planks", false)
		_box(d1, "Photo", pic[0] - Vector3(0.04, 0, 0), Vector3(0.01, 0.38, 0.3), pic[1], false)
	var d2 := _from(decor, 2)
	_prop("pottedPlant", Vector3(0.6, 0, 5.0), 0, {"parent": d2})
	_prop("pottedPlant", Vector3(8.0, 0, 2.6), 0, {"parent": d2})
	_prop("plantSmall1", Vector3(9.8, 0.78, 6.5), 0, {"parent": d2})

	# Alijo: en la pieza.
	var stash := _slot_h("stash", "SlotStash", Vector3(4.5, 0, 3.9))
	_stash_visuals(stash, -90.0)
	_station_h(Vector3(-0.6, 0.7, 0), _from(stash, 0), "StashStation", 4, 1.0)


## El ático: los insumos de mamá, bajo llave. Y algo más.
func _attic() -> void:
	# La puerta, que no se puede abrir (FlagGate con un flag que todavía nadie marca).
	var gate := Node3D.new()
	gate.set_script(load("res://scripts/world/flag_gate.gd"))
	gate.set("flag", &"attic_open")
	gate.set("locked_text", "No puedo entrar ahí. Mi madre se llevó la llave cuando guardó sus estúpidos medicamentos. Piensa que voy a recaer.")
	gate.position = Vector3(7.55, AF, 1.0)
	_add(groups.Structure, gate, "AtticGate")
	_box(gate, "Door", Vector3(0.05, 1.0, 0), Vector3(0.06, 2.0, 1.0), "planks", true, false)
	_door_prop(gate, "Chained", "door_chained", Vector3(0.06, 0, 0), 90.0, 1.0, 2.0)

	var y := AF
	# Paredes del ático (las exteriores ya llegan al techo): vigas y tablas.
	for x in [1.0, 3.0, 5.0, 7.0]:
		_box(groups.Structure, "Beam", Vector3(x, TOP - 0.15, 5.0), Vector3(0.2, 0.2, 10.0), "attic_wood", false)
	_bulb(Vector3(3.5, TOP - 0.6, 4.0), 1.0, true)
	_point_light(Vector3(5.0, y + 0.6, 8.5), Color(0.75, 0.85, 1.0), 0.3, 4.0, true)
	# Los insumos: cajas apiladas, sueros, tubos de oxígeno, un armario con candado.
	for p in [Vector3(0.6, y, 0.6), Vector3(1.4, y, 0.6), Vector3(0.6, y + 0.5, 0.6), Vector3(0.6, y, 1.4),
			Vector3(6.6, y, 9.2), Vector3(5.8, y, 9.3), Vector3(6.6, y + 0.5, 9.2)]:
		_prop("cardboardBoxClosed", p, randf_range(-15, 15), {"h": 0.5})
	_prop("tall_cabinet", Vector3(0.5, y, 5.0), 90)
	_prop("file_cabinet", Vector3(0.45, y, 6.4), 90)
	_prop("iv_stand", Vector3(4.6, y, 2.2), 30)
	_prop("iv_stand", Vector3(2.6, y, 8.0), -50)
	_prop("bed_metal", Vector3(3.6, y, 6.0), 90, {"tint": Color(0.6, 0.6, 0.62)})
	_prop("wheelchair", Vector3(6.2, y, 3.6), 200)
	for p in [Vector3(1.6, y, 9.4), Vector3(1.9, y, 9.5), Vector3(2.2, y, 9.4)]:
		_box(groups.Props, "OxygenTank", p + Vector3(0, 0.6, 0), Vector3(0.22, 1.2, 0.22), "oxygen")
	# Jeringas y blisters en el piso, alrededor de la cama.
	for i in 14:
		var p := Vector3(randf_range(2.6, 4.8), y + 0.01, randf_range(4.6, 7.6))
		_box(groups.Props, "Syringe", p, Vector3(0.12, 0.015, 0.015), "pills", false).rotation.y = randf() * TAU
	_label(groups.Secrets, "LO QUE GUARDASTE\nTE GUARDA", Vector3(3.6, y + 1.7, 9.82), 180, Color(0.5, 0.04, 0.03))
	# El jefe del ático (duerme; por ahora nadie llega hasta acá).
	_instance("res://scenes/enemies/attic_boss.tscn", groups.Enemies, "AtticThing", Vector3(3.6, y + 0.05, 4.2),
		{"wander_radius": 1.5})


func _label(parent: Node, text: String, pos: Vector3, rot_y: float, color: Color, px := 0.008) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = load("res://assets/fonts/pixel_operator/PixelOperator.ttf")
	label.font_size = 32
	label.pixel_size = px
	label.modulate = color
	label.position = pos
	label.rotation_degrees.y = rot_y
	_add(parent, label, "Label")


func _home_items() -> void:
	_pickup("LetterMother", "letter_mother_01", Vector3(9.8, 0.8, 6.2))
	_pickup("LetterVet", "letter_vet_01", Vector3(9.2, 0.8, 6.7))
	# El palo de escoba (pedido del usuario: un arma para que el comienzo no sea tan difícil),
	# apoyado en el piso de la pieza, al lado de la puerta.
	_pickup("Broom", "weapon_broom", Vector3(3.9, 0.06, 3.7))
	# La primera página del diario (poderes), en el escritorio de mi pieza: mi letra, cosas que no recuerdo.
	_pickup("DiaryPage1", "diary_page_01", Vector3(4.3, 0.78, 0.55))
	# Teodoro, cuando vuelve de la veterinaria: en el living, al lado del hogar.
	_cat(Vector3(1.8, 0.0, 6.4), 60.0, 1, &"home")
	_box(groups.Props, "CatBowl", Vector3(10.6, 0.03, 9.4), Vector3(0.22, 0.06, 0.22), "metal", false)
	_inspect(Vector3(10.6, 0.4, 9.4), ["El plato de Teodoro, vacío. Tiene su nombre escrito con marcador, en letra de mamá."], 0.8)
	_pickup("Peaches1", "food_canned_peaches", Vector3(12.6, 0.95, 3.9))
	_pickup("Peaches2", "food_canned_peaches", Vector3(12.6, 0.95, 3.0))
	_pickup("Water", "food_water_bottle", Vector3(10.2, 0.8, 6.8))
	_pickup("Chocolate", "food_chocolate_bar", Vector3(3.8, 0.47, 6.6))
	_pickup("Comic", "comic_lighthouse", Vector3(3.4, 0.78, 0.5))
	_pickup("VHS", "movie_coast_vhs", Vector3(4.61, 0.58, 9.3))
	_pickup("Wood", "material_wood", Vector3(1.0, 0.0, 9.3), 2)
	_pickup("Cloth", "material_cloth", Vector3(6.5, 0.0, 3.6), 1)


func _home_systems() -> void:
	var nav := NavigationRegion3D.new()
	var navmesh := NavigationMesh.new()
	navmesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	navmesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	navmesh.geometry_source_group_name = &"nav_source"
	navmesh.cell_size = 0.2
	navmesh.cell_height = 0.2
	navmesh.agent_height = 2.2
	navmesh.agent_radius = 0.4
	navmesh.agent_max_climb = 0.2
	nav.navigation_mesh = navmesh
	nav.set_script(load("res://scripts/world/runtime_nav_bake.gd"))
	_add(scene_root, nav, "Navigation")
	var persistence := Node3D.new()
	persistence.set_script(load("res://scripts/world/world_persistence.gd"))
	_add(scene_root, persistence, "WorldPersistence")
	var level_audio := Node.new()
	level_audio.set_script(load("res://scripts/world/level_audio.gd"))
	level_audio.set("ambience", &"hospital")
	level_audio.set("ambience_db", -14.0)
	_add(scene_root, level_audio, "LevelAudio")
	var door := Area3D.new()
	door.set_script(load("res://scripts/world/zone_door.gd"))
	door.set("target_scene", "res://scenes/levels/park_street.tscn")
	door.set("target_spawn", &"from_home")
	door.set("radius", 1.0)
	door.position = Vector3(3.5, 1.2, 9.6)
	_add(groups.Inspectables, door, "StreetDoor")
	_zone_door_visuals(door, Vector3(3.5, 0, 10.0 - TE / 2 - 0.02), 180.0, "door_wood_open", "", 1.2, 2.2)
	for s: Array in [[&"refuge", Vector3(2.6, 0.05, 2.6), 180.0], [&"from_street", Vector3(3.5, 0.05, 7.8), 0.0]]:
		var spawn := Marker3D.new()
		spawn.set_script(load("res://scripts/world/spawn_point.gd"))
		spawn.set("spawn_id", s[0])
		spawn.position = s[1]
		spawn.rotation_degrees.y = s[2]
		_add(scene_root, spawn, "Spawn_" + String(s[0]))
	_instance("res://scenes/player/player.tscn", scene_root, "Player", Vector3(2.6, 0.05, 2.6))
	_instance("res://scenes/effects/ps1_post_process.tscn", scene_root, "PS1PostProcess", Vector3.ZERO)
	var ui: Node = load("res://scenes/ui/game_ui.tscn").instantiate()
	_add(scene_root, ui, "GameUI")
