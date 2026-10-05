extends "res://tools/build_hospital.gd"
## Genera res://scenes/levels/hospital_basement.tscn: el sótano del Hospital San Judas
## (pedido del usuario: "grande, bastante lugar para recorrer, una zona con un boss";
## se entra solo con la llave que Ferreyra se llevó a su casa). Reusa los helpers del
## hospital. Andamio de una sola pasada.
## Uso: <godot> --headless --path . -s res://tools/build_basement.gd
##
## Planta (x = este, z = sur), 56 x 40 m, cielorraso a 3.2 m (el incinerador, a 6 m):
##   z 0-6     escalera | calderas | lavandería | grupo electrógeno | depósito
##   z 6-9     pasillo principal, de punta a punta
##   z 9-31    morgue | patología  · pasillo x 26-29 ·  residuos | INCINERADOR (el jefe)
##             archivo muerto | capilla
##   z 31-34   pasillo sur (x 0-46)
##   z 34-40   túnel de servicio | cámara frigorífica | taller  ·  sala de guardia (tras el jefe)

const BASEMENT_OUT := "res://scenes/levels/hospital_basement.tscn"
const BW := 56.0
const BD := 40.0
const TALL := 6.0  # alto del incinerador y de las paredes exteriores
const ARENA := Rect2(36.0, 9.0, 20.0, 22.0)
const BOSS_SCENE := "res://scenes/enemies/basement_boss.tscn"


func _initialize() -> void:
	GreyBoxScript = load("res://scripts/world/grey_box.gd")
	PropScript = load("res://scripts/world/prop.gd")
	InspectableScript = load("res://scripts/world/inspectable.gd")
	FlickerScript = load("res://scripts/world/flicker_light.gd")
	GatedScript = load("res://scripts/world/sanity_gated.gd")
	RefugeScript = load("res://scripts/world/refuge_zone.gd")
	seed(909)
	for id in ["Barrel_01", "barrel_03", "metal_trash_can", "utility_box_01", "steel_frame_shelves_01",
			"portable_generator", "worn_metal_rack", "plastic_crate_01", "wooden_crate_01", "medical_box"]:
		upgrades[id] = [id, {}]
	_make_materials()
	scene_root = Node3D.new()
	scene_root.name = "HospitalBasement"
	for g in ["Structure", "Lights", "Props", "Items", "Inspectables", "Secrets", "Enemies"]:
		groups[g] = _add(scene_root, Node3D.new(), g)
	groups.Structure.add_to_group(&"nav_source", true)
	groups.Props.add_to_group(&"nav_source", true)

	_basement_environment()
	_basement_structure()
	_basement_lights()
	_entry()
	_north_rooms()
	_morgue()
	_pathology()
	_dead_archive()
	_chapel()
	_waste_room()
	_incinerator()
	_guard_room()
	_south_rooms()
	_pipes()
	_basement_secrets()
	_basement_items()
	_basement_enemies()
	_basement_discovery()
	_basement_systems()

	var packed := PackedScene.new()
	packed.pack(scene_root)
	var err := ResourceSaver.save(packed, BASEMENT_OUT)
	print("Guardado %s (%s), nodos: %d" % [BASEMENT_OUT, error_string(err), _count(scene_root)])
	scene_root.free()
	quit()


func _make_materials() -> void:
	super._make_materials()
	var shader: Shader = load("res://shaders/ps1_spatial.gdshader")
	var defs := {
		"bodybag": ["", Color(0.1, 0.1, 0.11), 1.0],
		"drawer": ["metal_green", Color(0.62, 0.66, 0.66), 1.2],
		"tile_cold": ["floor_tiles", Color(0.6, 0.68, 0.7), 0.45],
		"furnace": ["metal_green", Color(0.2, 0.17, 0.15), 0.6],
		"biohazard": ["", Color(0.6, 0.1, 0.08), 1.0],
		"candle": ["", Color(0.95, 0.85, 0.6), 1.0],
		"sheet": ["", Color(0.8, 0.8, 0.76), 1.0],
		"pipe": ["metal_green", Color(0.42, 0.44, 0.42), 1.5],
		"basement_wall": ["concrete", Color(0.55, 0.56, 0.54), 0.45],
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
		if key == "candle":
			m.set_shader_parameter(&"emission_color", Color(1.0, 0.75, 0.4))
		var path := MAT_DIR + "m_%s.tres" % key
		ResourceSaver.save(m, path)
		mats[key] = load(path)


# --- Estructura --------------------------------------------------------------------

func _basement_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.03, 0.035)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.34, 0.38)
	env.ambient_light_energy = 0.25
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	world_env.set_script(load("res://scripts/world/atmosphere.gd"))
	world_env.set("fog_color", Color(0.03, 0.03, 0.035))
	world_env.set("fog_start", 1.5)
	world_env.set("fog_end", 14.0)
	world_env.set("insane_fog_color", Color(0.02, 0.01, 0.01))
	world_env.set("insane_fog_start", 0.5)
	world_env.set("insane_fog_end", 5.0)
	_add(scene_root, world_env, "Atmosphere")


## Una pared del sótano (mismo `_wall` del hospital, con el material de hormigón).
func _bwall(axis: String, c: float, a0: float, a1: float, openings: Array = [], height := CEIL, thick := T) -> void:
	_wall(axis, c, a0, a1, 0.0, height, thick, openings, "basement_wall", false)


func _basement_structure() -> void:
	_box(groups.Structure, "Slab", Vector3(BW / 2, -0.16, BD / 2), Vector3(BW, 0.28, BD), "concrete")
	# Pisos por ambiente.
	for r in [[0, 0, BW, 6, "concrete"], [0, 6, BW, 9, "floor_dirty"], [0, 9, 13, 22, "tile_cold"],
			[13, 9, 26, 22, "tile_cold"], [0, 22, 26, 31, "floor_dirty"], [26, 9, 29, 31, "floor_dirty"],
			[29, 9, 36, 31, "concrete"], [36, 9, BW, 31, "concrete"], [0, 31, 46, 34, "floor_dirty"],
			[0, 34, 46, BD, "concrete"], [46, 31, BW, BD, "floor"]]:
		_floor(r[0], r[1], r[2], r[3], 0.0, r[4])
	# Cielorraso: bajo en todos lados salvo el incinerador.
	for r in [[0, 0, BW, 9], [0, 9, ARENA.position.x, 31], [0, 31, BW, BD]]:
		_box(groups.Structure, "Ceiling", Vector3((r[0] + r[2]) / 2.0, CEIL + 0.01, (r[1] + r[3]) / 2.0),
			Vector3(r[2] - r[0], 0.02, r[3] - r[1]), "ceiling", false)
	_box(groups.Structure, "ArenaCeiling", Vector3(ARENA.get_center().x, TALL + 0.01, ARENA.get_center().y),
		Vector3(ARENA.size.x, 0.02, ARENA.size.y), "concrete", false)
	# Paredes exteriores.
	_bwall("x", 0.0, -TE / 2, BW + TE / 2, [], TALL, TE)
	_bwall("x", BD, -TE / 2, BW + TE / 2, [], TALL, TE)
	_bwall("z", 0.0, TE / 2, BD - TE / 2, [], TALL, TE)
	_bwall("z", BW, TE / 2, BD - TE / 2, [], TALL, TE)
	# Fila norte (z 0-6) y pasillo principal (z 6-9).
	_bwall("x", 6.0, TE / 2, BW - TE / 2, [[3.0, 4.0, 0.0, 2.8], _door(13), _door(26), _door(38), _door(50)])
	for x in [6.0, 20.0, 32.0, 44.0]:
		_bwall("z", x, TE / 2, 6.0 - T / 2)
	_bwall("x", 9.0, TE / 2, ARENA.position.x, [_door(6.5), _door(19.5), [27.5, 3.0, 0.0, 2.8], _door(32.5)])
	_bwall("x", 9.0, ARENA.position.x, BW - TE / 2, [], TALL)
	# Bloque oeste (morgue, patología, archivo, capilla).
	_bwall("z", 13.0, 9.0 + T / 2, 31.0 - T / 2, [_door(15.5)])
	_bwall("x", 22.0, TE / 2, 26.0, [_door(9.0)])
	_bwall("z", 26.0, 9.0 + T / 2, 31.0 - T / 2, [_door(15.0), _door(27.0)])
	# Pasillo central (x 26-29) y la sala de residuos (x 29-36).
	_bwall("z", 29.0, 9.0 + T / 2, 31.0 - T / 2, [_door(15.0)])
	# El incinerador: paredes altas, una sola entrada (desde residuos) y la puerta trabada al sur.
	_bwall("z", ARENA.position.x, 9.0 + T / 2, 31.0 - T / 2, [[20.0, 2.4, 0.0, 2.8]], TALL)
	_bwall("x", 31.0, TE / 2, ARENA.position.x, [_door(6.5), _door(19.5), [27.5, 3.0, 0.0, 2.8], _door(32.5)])
	_bwall("x", 31.0, ARENA.position.x, BW - TE / 2, [[51.0, DOOR_W, 0.0, DOOR_H]], TALL)
	# Pasillo sur (z 31-34) y fila sur (z 34-40).
	_bwall("x", 34.0, TE / 2, 46.0, [_door(8.0), _door(23.0), _door(38.0)])
	for x in [16.0, 30.0]:
		_bwall("z", x, 34.0 + T / 2, BD - TE / 2)
	_bwall("z", 46.0, 31.0 + T / 2, BD - TE / 2)
	# Carteles sobre las puertas.
	for s: Array in [["CALDERAS", 13.0, 6.0, false], ["LAVANDERÍA", 26.0, 6.0, false], ["MÁQUINAS", 38.0, 6.0, false],
			["DEPÓSITO", 50.0, 6.0, false], ["MORGUE", 6.5, 9.0, true], ["PATOLOGÍA", 19.5, 9.0, true],
			["RESIDUOS", 32.5, 9.0, true], ["ARCHIVO", 6.5, 31.0, false], ["CAPILLA", 19.5, 31.0, false],
			["TALLER", 38.0, 34.0, true], ["FRIGORÍFICO", 23.0, 34.0, true], ["SERVICIO", 8.0, 34.0, true]]:
		# El cartel va del lado del pasillo: `facing_south` = la cara mira a +Z.
		var corridor_side_south: bool = s[3]
		_room_sign(s[0], s[1], s[2] - T / 2 if not corridor_side_south else s[2] + T / 2, 0.0, corridor_side_south)
	_label3d(groups.Structure, "INCINERADOR", Vector3(ARENA.position.x - 0.12, 3.2, 20.0), -90, Color(0.8, 0.2, 0.12), 0.009)


func _label3d(parent: Node, text: String, pos: Vector3, rot_y: float, color: Color, px := 0.008) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = load("res://assets/fonts/pixel_operator/PixelOperator.ttf")
	label.font_size = 32
	label.pixel_size = px
	label.modulate = color
	label.position = pos
	label.rotation_degrees.y = rot_y
	return _add(parent, label, "Label")


func _basement_lights() -> void:
	# Pasillo principal y pasillo sur: casi todo muerto.
	for l in [[4.0, 7.5, "on"], [12.0, 7.5, "off"], [20.0, 7.5, "flicker"], [28.0, 7.5, "off"], [36.0, 7.5, "on"],
			[44.0, 7.5, "off"], [52.0, 7.5, "flicker"], [4.0, 32.5, "flicker"], [14.0, 32.5, "off"], [24.0, 32.5, "on"],
			[34.0, 32.5, "off"], [42.0, 32.5, "flicker"], [27.5, 14.0, "flicker"], [27.5, 26.0, "off"],
			[13.0, 3.0, "flicker"], [26.0, 3.0, "off"], [38.0, 3.0, "on"], [50.0, 3.0, "flicker"],
			[6.5, 15.5, "flicker"], [19.5, 15.5, "on"], [6.5, 26.5, "off"], [19.5, 26.5, "flicker"],
			[32.5, 20.0, "off"], [8.0, 37.0, "off"], [23.0, 37.0, "flicker"], [38.0, 37.0, "on"]]:
		_ceiling_light(l[0], l[1], 0, l[2], 0.8)


# --- Ambientes ---------------------------------------------------------------------

## La escalera de bajada (x 0-6, z 0-6): la puerta de arriba vuelve al hospital.
func _entry() -> void:
	var steps := 10
	for i in steps:
		var top := (i + 1) * 0.28
		_box(groups.Structure, "Step", Vector3(3.0, top / 2, 5.0 - i * 0.42), Vector3(3.0, top, 0.42), "concrete")
	_box(groups.Structure, "StairLanding", Vector3(3.0, 1.4, 0.6), Vector3(3.0, 2.8, 1.1), "concrete", false)
	_box(groups.Structure, "StairDoorFrame", Vector3(3.0, 2.8 + 1.15, 0.17), Vector3(1.5, 2.3, 0.04), "door_gap", false)
	_point_light(Vector3(3.0, 2.9, 1.2), Color(1.0, 0.85, 0.6), 0.6, 4.0, true)
	var door := Area3D.new()
	door.set_script(load("res://scripts/world/zone_door.gd"))
	door.set("target_scene", "res://scenes/levels/hospital.tscn")
	door.set("target_spawn", &"from_basement")
	door.set("radius", 1.5)
	door.position = Vector3(3.0, 1.2, 5.0)
	_add(groups.Inspectables, door, "HospitalDoor")
	_prop("WetFloorSign_01", Vector3(5.2, 0, 5.4), 30)
	_prop("wheelchair", Vector3(0.8, 0, 5.2), 120)
	_inspect(Vector3(5.0, 1.2, 1.5), ["Las paredes de la escalera tienen marcas de manos. Muchas. Todas hacia arriba."], 1.0)


func _north_rooms() -> void:
	# Calderas (x 6-20): tres calderas enormes y caños por todos lados.
	for x in [9.0, 13.5, 18.0]:
		_box(groups.Props, "Boiler", Vector3(x, 1.4, 2.0), Vector3(2.4, 2.8, 2.6), "furnace")
		_box(groups.Props, "BoilerPipe", Vector3(x, 3.0, 2.0), Vector3(0.4, 0.4, 2.6), "pipe", false)
		_box(groups.Props, "BoilerDoor", Vector3(x, 0.8, 3.33), Vector3(0.9, 0.7, 0.04), "soot", false)
	_point_light(Vector3(13.5, 0.6, 3.8), Color(1.0, 0.45, 0.2), 0.6, 4.0, true)
	_prop("barrel_03", Vector3(6.8, 0, 5.2), 0, {"h": 1.0})
	_inspect(Vector3(13.5, 1.2, 3.8), ["Una de las calderas está encendida. Nadie la alimenta, y sin embargo sigue caliente.",
		"Por la mirilla se ve el fuego. Adentro hay algo que no es carbón."], 1.2)
	# Lavandería (x 20-32): lavarropas industriales, carros y sábanas colgadas.
	for x in [21.5, 23.6, 25.7]:
		_box(groups.Props, "Washer", Vector3(x, 0.8, 0.9), Vector3(1.8, 1.6, 1.4), "drawer")
		_box(groups.Props, "WasherDoor", Vector3(x, 0.85, 1.62), Vector3(0.7, 0.7, 0.04), "window_dark" if mats.has("window_dark") else "soot", false)
	for p in [Vector3(28.5, 0, 2.0), Vector3(30.2, 0, 4.0)]:
		_box(groups.Props, "LaundryCart", p + Vector3.UP * 0.5, Vector3(0.9, 1.0, 1.4), "sheet")
	for i in 4:
		_box(groups.Props, "HangingSheet", Vector3(22.0 + i * 2.2, 1.6, 4.4), Vector3(1.8, 1.8, 0.02), "sheet", false)
	_box(groups.Props, "Clothesline", Vector3(26.0, 2.55, 4.4), Vector3(10.0, 0.02, 0.02), "bars", false)
	_inspect(Vector3(24.0, 1.3, 4.8), ["Sábanas colgadas a secar. Una tiene la forma de alguien, en manchas, como el sudario de una estampita."], 1.3)
	# Grupo electrógeno (x 32-44): tableros y el generador grande, muerto.
	_box(groups.Props, "Generator", Vector3(38.0, 1.0, 2.2), Vector3(4.0, 2.0, 2.4), "metal")
	for x in [33.0, 34.0, 42.0, 43.0]:
		_box(groups.Props, "Panel", Vector3(x, 1.2, 0.35), Vector3(0.8, 1.9, 0.4), "drawer")
	_prop("portable_generator", Vector3(42.4, 0, 4.6), -40)
	_inspect(Vector3(38.0, 1.5, 3.6), ["El grupo electrógeno del hospital. Alguien le cortó los cables con una tenaza, prolijamente, uno por uno."], 1.4)
	# Depósito de insumos (x 44-56).
	for x in [45.5, 47.5, 49.5, 51.5, 53.5]:
		_prop("steel_frame_shelves_01", Vector3(x, 0, 0.5), 0, {"h": 1.9})
	for x in [47.0, 50.0, 53.0]:
		_prop("steel_frame_shelves_01", Vector3(x, 0, 3.6), 180, {"h": 1.9})
	for p in [Vector3(45.2, 0, 5.3), Vector3(55.0, 0, 5.0), Vector3(55.2, 0, 2.2)]:
		_prop("cardboardBoxClosed", p, randf_range(-30, 30))


## La morgue (x 0-13, z 9-22): la pared de las cámaras y las camillas.
func _morgue() -> void:
	for row in 3:
		for col in 7:
			var z := 10.4 + col * 1.5
			var y := 0.55 + row * 0.75
			var open := row == 1 and col == 3
			_box(groups.Props, "Drawer", Vector3(0.45 if not open else 1.4, y, z), Vector3(0.6 if not open else 2.2, 0.65, 1.3), "drawer",
				not open)
			_box(groups.Props, "DrawerHandle", Vector3(0.77 if not open else 2.52, y + 0.2, z), Vector3(0.04, 0.05, 0.4), "bars", false)
			if open:
				_box(groups.Props, "OpenDrawerBody", Vector3(1.4, y + 0.42, z), Vector3(1.9, 0.2, 0.6), "bodybag", false)
	_box(groups.Props, "DrawerWall", Vector3(0.45, 1.6, 15.6), Vector3(0.8, 3.2, 10.8), "drawer")
	_inspect(Vector3(2.4, 1.3, 14.9), ["Las cámaras de la morgue. Una está abierta y la bandeja afuera. La bolsa está vacía y cortada desde adentro.",
		"Las otras tienen etiquetas con fecha: todas del día 10. Algunas se mueven si uno se queda quieto."], 1.4)
	for p in [Vector3(5.5, 0, 12.0), Vector3(9.0, 0, 13.0), Vector3(5.5, 0, 18.5), Vector3(9.5, 0, 19.0)]:
		_prop("bed_metal", p, 90 + randf_range(-10, 10))
		_box(groups.Props, "BodyBag", p + Vector3(0, 0.62, 0), Vector3(1.8, 0.22, 0.55), "bodybag", false)
	_prop("blood", Vector3(7.0, 0.01, 15.5), 30)
	_prop("tall_cabinet", Vector3(12.5, 0, 20.5), -90)
	_inspect(Vector3(9.0, 1.0, 13.0), ["Una bolsa con una etiqueta: \"N.N. - mujer - traída por la policía\". Pesa poco. Demasiado poco."], 1.2)


## Patología (x 13-26, z 9-22): mesas de autopsia, piletas, instrumental.
func _pathology() -> void:
	for p in [Vector3(17.0, 0, 13.0), Vector3(22.0, 0, 13.0), Vector3(19.5, 0, 18.5)]:
		_box(groups.Props, "AutopsyBase", p + Vector3(0, 0.4, 0), Vector3(0.4, 0.8, 0.5), "bars")
		_box(groups.Props, "AutopsyTable", p + Vector3(0, 0.88, 0), Vector3(0.8, 0.08, 2.1), "drawer")
	_prop("blood", Vector3(17.0, 0.01, 14.0), 0)
	_prop("blood", Vector3(19.5, 0.01, 19.2), 100)
	for z in [10.5, 12.0]:
		_prop("kitchenSink", Vector3(25.5, 0, z), -90)
	for x in [14.5, 15.5]:
		_prop("tall_cabinet", Vector3(x, 0, 21.5), 180)
	_prop("iv_stand", Vector3(23.0, 0, 18.0))
	_prop("medical_box", Vector3(24.0, 0, 21.4), 180)
	_inspect(Vector3(19.5, 1.2, 18.5), ["Sobre la mesa, un informe de autopsia sin terminar: \"Órganos en posición normal. Pero hay más.\"",
		"\"Un segundo corazón, pequeño, en la base del cráneo. Late.\""], 1.2)


## Archivo muerto (x 0-13, z 22-31): un laberinto de archiveros.
func _dead_archive() -> void:
	for row in 3:
		for i in 5:
			if row == 1 and i == 2:
				continue
			_prop("file_cabinet", Vector3(1.5 + i * 2.2, 0, 24.0 + row * 2.4), 0 if row % 2 == 0 else 180)
	for p in [Vector3(11.5, 0, 30.0), Vector3(1.0, 0, 30.2), Vector3(6.0, 0, 29.8)]:
		_prop("cardboardBoxOpen", p, randf_range(0, 360))
	_inspect(Vector3(6.0, 1.0, 26.4), ["Cajas de historias clínicas de 1979. Una carpeta está fuera de lugar, encima de todo: \"Elena M. de Sosa\".",
		"Diagnóstico: \"Melancolía grave\". Alta voluntaria el 14 de marzo. Al lado, a mano: \"Va a cantar igual\"."], 1.4)


## La capilla del sótano (x 13-26, z 22-31): donde despedían a los muertos.
func _chapel() -> void:
	for row in 3:
		for side in [-1.0, 1.0]:
			_prop("bench", Vector3(19.5 + side * 2.2, 0, 25.0 + row * 1.6), 180)
	_box(groups.Props, "Altar", Vector3(19.5, 0.5, 30.2), Vector3(2.0, 1.0, 0.8), "counter")
	_box(groups.Props, "CrossV", Vector3(19.5, 2.2, 30.82), Vector3(0.12, 1.2, 0.06), "rail", false)
	_box(groups.Props, "CrossH", Vector3(19.5, 2.5, 30.82), Vector3(0.6, 0.12, 0.06), "rail", false)
	for dx in [-0.7, -0.3, 0.4, 0.8]:
		_box(groups.Props, "Candle", Vector3(19.5 + dx, 1.08, 30.1), Vector3(0.05, 0.16, 0.05), "candle", false)
	_point_light(Vector3(19.5, 1.5, 29.6), Color(1.0, 0.7, 0.4), 0.7, 5.0, true)
	_inspect(Vector3(19.5, 1.1, 29.6), ["Las velas están recién prendidas. Alguien sigue bajando a rezar.",
		"En el altar, un papel con una lista de nombres. El último, con letra apurada: \"Por los que bajamos vivos\"."], 1.4)


## Residuos patogénicos (x 29-36): la antesala del incinerador.
func _waste_room() -> void:
	for i in 6:
		_box(groups.Props, "BioBin", Vector3(30.0, 0.45, 11.0 + i * 1.0), Vector3(0.8, 0.9, 0.8), "biohazard")
	for p in [Vector3(34.5, 0, 12.0), Vector3(33.0, 0, 25.0), Vector3(30.5, 0, 28.5)]:
		_box(groups.Props, "WasteCart", p + Vector3.UP * 0.55, Vector3(1.0, 1.1, 1.6), "drawer")
	for p in [Vector3(35.0, 0, 27.0), Vector3(34.2, 0, 29.5), Vector3(30.2, 0, 23.0)]:
		_prop("trashbag", p, randf_range(0, 360))
	_prop("blood", Vector3(34.0, 0.01, 20.0), 90)
	_prop("blood", Vector3(35.4, 0.01, 21.4), 10)
	_inspect(Vector3(30.8, 1.2, 13.5), ["\"RESIDUOS PATOGÉNICOS\". Los tachos rebalsan. Algunas bolsas todavía están tibias."], 1.2)
	_inspect(Vector3(35.2, 1.4, 20.0), ["Del otro lado de la puerta del incinerador se oye respirar. Muchas respiraciones, a destiempo."], 1.4)


## El incinerador (x 36-56, z 9-31, 6 m de alto): la sala del jefe.
func _incinerator() -> void:
	var c := ARENA.get_center()
	# El horno, en la pared este, con la boca encendida y la chimenea.
	_box(groups.Props, "Furnace", Vector3(53.5, 2.2, 20.0), Vector3(4.6, 4.4, 7.0), "furnace")
	_box(groups.Props, "FurnaceMouth", Vector3(51.17, 1.3, 20.0), Vector3(0.04, 1.4, 2.4), "ember", false)
	_box(groups.Props, "Chimney", Vector3(53.5, 5.2, 20.0), Vector3(1.6, 1.6, 1.6), "soot", false)
	_point_light(Vector3(50.2, 1.3, 20.0), Color(1.0, 0.45, 0.15), 2.2, 13.0, true)
	# Columnas para cubrirse.
	for p in [Vector3(41.0, 0, 14.0), Vector3(41.0, 0, 26.0), Vector3(47.5, 0, 14.0), Vector3(47.5, 0, 26.0)]:
		_box(groups.Structure, "Column", p + Vector3.UP * TALL / 2, Vector3(0.8, TALL, 0.8), "basement_wall")
	# Montañas de bolsas y camillas.
	for i in 14:
		var p := Vector3(randf_range(38.0, 50.0), 0, randf_range(10.5, 29.5))
		if p.distance_to(Vector3(c.x, 0, c.y)) < 4.0:
			continue
		var bag := _box(groups.Props, "BodyBag", p + Vector3.UP * 0.12, Vector3(1.8, 0.24, 0.6), "bodybag", false)
		bag.rotation_degrees.y = randf_range(0, 180)
	for p in [Vector3(38.5, 0, 11.0), Vector3(49.0, 0, 29.5), Vector3(38.5, 0, 29.0)]:
		_prop("bed_metal", p, randf_range(0, 360))
	for p in [Vector3(44.0, 0.01, 17.0), Vector3(46.0, 0.01, 23.5), Vector3(42.0, 0.01, 21.0)]:
		_prop("blood", p, randf_range(0, 360))
	_point_light(Vector3(c.x, TALL - 0.4, c.y), Color(0.7, 0.75, 0.8), 0.9, 14.0, true)
	_inspect(Vector3(50.6, 1.2, 17.0), ["La boca del incinerador. Adentro no hay fuego: hay caras, apretadas, mirando para afuera."], 1.4)
	# El jefe y el disparador: se despierta apenas uno cruza la puerta.
	_instance(BOSS_SCENE, groups.Enemies, "BasementBoss", Vector3(46.0, 0.05, 20.0), {"wander_radius": 3.0})
	var trigger := Area3D.new()
	trigger.set_script(load("res://scripts/world/boss_trigger.gd"))
	trigger.set("boss", NodePath("../../Enemies/BasementBoss"))
	trigger.position = Vector3(39.0, 1.5, 20.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5.0, 3.0, 20.0)
	shape.shape = box
	_add(groups.Secrets, trigger, "BossTrigger")
	_add(trigger, shape, "Shape")
	# La puerta al sur (a la sala de guardia): trabada mientras viva.
	var gate := Node3D.new()
	gate.set_script(load("res://scripts/world/flag_gate.gd"))
	gate.set("flag", &"basement_boss_dead")
	gate.set("locked_text", "Una puerta de chapa con una ventanita. Del otro lado hay una luz prendida. No cede: algo la traba desde la sala.")
	gate.set("open_text", "En el fondo del incinerador, una puerta de chapa se destraba sola.")
	gate.set("open_model", load(DOORS + "door_metal_open.glb"))
	gate.set("open_model_scale", Vector3(DOOR_W / 1.02, DOOR_H / 2.1, 1.0))
	gate.set("open_model_yaw", 180.0)
	gate.position = Vector3(51.0, 0, 31.0)
	_add(groups.Structure, gate, "GuardGate")
	_box(gate, "Door", Vector3(0, 1.2, 0), Vector3(DOOR_W, 2.4, 0.1), "metal", true, false)
	_door_prop(gate, "Chained", "door_chained", Vector3(0, 0, -0.06), 180.0, DOOR_W, DOOR_H)


## La sala de guardia del sótano (x 46-56, z 31-40): detrás del jefe. Los médicos que
## bajaron a atender a los "pacientes" de abajo armaron acá su último puesto.
func _guard_room() -> void:
	_prop("bedSingle", Vector3(54.5, 0, 38.6), -90, {"colors": hospital_bed_colors})
	_prop("desk", Vector3(49.0, 0, 39.2))
	_prop("chairDesk", Vector3(49.0, 0, 38.3), 180)
	_prop("lampRoundTable", Vector3(49.8, 0.76, 39.3))
	_prop("tall_cabinet", Vector3(46.5, 0, 36.0), 90)
	_prop("medical_box", Vector3(55.5, 0, 33.0), -90)
	_prop("iv_stand", Vector3(53.0, 0, 36.5))
	_point_light(Vector3(49.6, 1.5, 38.6), Color(1.0, 0.85, 0.6), 0.9, 6.0)
	_inspect(Vector3(49.0, 1.0, 38.6), ["Un puesto de guardia improvisado. Un termo, mate frío, planillas de control cada dos horas.",
		"La última planilla tiene una sola anotación: \"Ya no son pacientes. Pero me reconocen. Vuelvo arriba a buscar a Ferreyra.\"",
		"La firma está corrida. Empieza con una I."], 1.3)
	_inspect(Vector3(54.0, 1.0, 38.6), ["Sobre la almohada, un estetoscopio. Mamá tiene uno igual, con la goma mordida en el mismo lugar."], 1.2)


func _south_rooms() -> void:
	# Túnel de servicio (x 0-16): cajones y estanterías.
	for x in [2.0, 4.5, 7.0]:
		_prop("worn_metal_rack", Vector3(x, 0, 39.4), 180, {"h": 1.9})
	for p in [Vector3(12.0, 0, 36.0), Vector3(13.0, 0, 38.6), Vector3(14.6, 0, 36.6), Vector3(1.2, 0, 35.2)]:
		_prop("wooden_crate_01", p, randf_range(0, 360))
	_prop("plastic_crate_01", Vector3(10.0, 0, 39.3), 10)
	# Cámara frigorífica (x 16-30): fría, azulada.
	for x in [17.5, 20.0, 22.5, 25.0, 27.5]:
		_prop("steel_frame_shelves_01", Vector3(x, 0, 39.5), 180, {"h": 1.9})
	_box(groups.Props, "HangingThing", Vector3(23.0, 2.0, 36.6), Vector3(0.6, 1.6, 0.4), "bodybag", false)
	_box(groups.Props, "Hook", Vector3(23.0, 3.0, 36.6), Vector3(0.04, 0.4, 0.04), "bars", false)
	_point_light(Vector3(23.0, 2.8, 37.0), Color(0.55, 0.75, 1.0), 0.6, 6.0)
	_inspect(Vector3(23.0, 1.4, 35.8), ["Algo cuelga de un gancho, envuelto en film. Tiene el tamaño de un chico. No lo voy a abrir."], 1.2)
	# Taller de mantenimiento (x 30-46): banco de trabajo y herramientas.
	_prop("desk", Vector3(38.0, 0, 39.3), 0, {"tint": Color(0.6, 0.55, 0.5)})
	for x in [31.0, 32.5]:
		_prop("worn_metal_rack", Vector3(x, 0, 39.4), 180, {"h": 1.9})
	_prop("portable_generator", Vector3(44.6, 0, 36.0), 70)
	_prop("Barrel_01", Vector3(45.2, 0, 39.2), 0, {"h": 1.0})
	_prop("wooden_broom", Vector3(35.0, 0, 39.5), 0)
	_inspect(Vector3(38.0, 1.0, 39.0), ["El banco del taller. Una soldadora, varillas de hierro y un plano del hospital con las ventanas marcadas en rojo.",
		"Acá se hicieron las rejas que Ferreyra mandó soldar."], 1.2)


## Caños y cables por el cielorraso de los pasillos.
func _pipes() -> void:
	for z in [6.4, 6.8]:
		_box(groups.Structure, "Pipe", Vector3(BW / 2, CEIL - 0.25, z), Vector3(BW - 0.6, 0.18, 0.18), "pipe", false)
	for z in [31.4, 33.6]:
		_box(groups.Structure, "Pipe", Vector3(23.0, CEIL - 0.25, z), Vector3(45.4, 0.15, 0.15), "pipe", false)
	_box(groups.Structure, "Pipe", Vector3(26.4, CEIL - 0.25, 20.0), Vector3(0.18, 0.18, 21.6), "pipe", false)


## Secretos por cordura y por dificultad.
func _basement_secrets() -> void:
	# Inquieto: las paredes de la morgue tienen nombres escritos.
	var names := Node3D.new()
	names.set_script(GatedScript)
	names.set("threshold", 1)
	_add(groups.Secrets, names, "MorgueNames")
	_label3d(names, "NO ESTAMOS MUERTOS\nESTAMOS ABAJO", Vector3(12.88, 1.8, 13.0), -90, Color(0.55, 0.05, 0.03), 0.007)
	# Quebrado: en la capilla, alguien sentado en el primer banco.
	var kneeling := Node3D.new()
	kneeling.set_script(GatedScript)
	kneeling.set("threshold", 2)
	_add(groups.Secrets, kneeling, "ChapelFigure")
	_instance("res://scenes/enemies/horror_placeholder.tscn", kneeling, "Figure", Vector3(17.3, 0.0, 28.2))
	# Quebrado: en el archivo, el hueco entre archiveros esconde un botiquín.
	var hidden := Node3D.new()
	hidden.set_script(GatedScript)
	hidden.set("threshold", 2)
	_add(groups.Secrets, hidden, "ArchiveStash")
	_instance("res://scenes/world/pickup.tscn", hidden, "HiddenShells", Vector3(5.9, 0.05, 26.4),
		{"item": load("res://assets/items/ammo_shells.tres"), "count": 4})
	# Difícil: la cámara 13 de la morgue se abre sola (munición de la policía que trajo los cuerpos).
	var drawer := _difficulty_gate("Drawer13", 1)
	_instance("res://scenes/world/pickup.tscn", drawer, "PoliceAmmo", Vector3(2.0, 1.4, 19.4),
		{"item": load("res://assets/items/ammo_9mm.tres"), "count": 10})
	_box(drawer, "OpenDrawer13", Vector3(1.6, 1.2, 19.4), Vector3(1.8, 0.1, 1.2), "drawer", false)


## Pocos objetos y bien repartidos: el sótano es largo y se pelea.
func _basement_items() -> void:
	var pickup := "res://scenes/world/pickup.tscn"
	for it: Array in [
			["Bandage1", "medicine_bandage", Vector3(24.0, 0.05, 20.8), 1],
			["Ammo1", "ammo_9mm", Vector3(55.0, 0.05, 2.2), 8],
			["Shells1", "ammo_shells", Vector3(38.0, 0.8, 39.2), 4],
			["Water1", "food_water_bottle", Vector3(13.6, 0.05, 38.6), 1],
			["Peaches1", "food_canned_peaches", Vector3(49.5, 0.05, 3.6), 1],
			["Metal1", "material_metal", Vector3(44.0, 0.0, 38.4), 3],
			["Cable1", "material_cable", Vector3(43.4, 0.0, 1.0), 3],
			["Cloth1", "material_cloth", Vector3(29.5, 0.0, 1.2), 3],
			["Wood1", "material_wood", Vector3(12.5, 0.0, 39.0), 2],
			# La sala de guardia, detrás del jefe.
			["GuardKit", "medicine_kit", Vector3(55.4, 0.05, 34.4), 1],
			["GuardShells", "ammo_shells", Vector3(48.4, 0.8, 39.2), 6],
			["GuardChocolate", "food_chocolate_bar", Vector3(49.6, 0.8, 39.2), 1]]:
		_instance(pickup, groups.Items, it[0], it[2], {"item": load("res://assets/items/%s.tres" % it[1]), "count": it[3]})


func _basement_enemies() -> void:
	var stalker := "res://scenes/enemies/stalker.tscn"
	for e: Array in [["StalkerCorridor", Vector3(20.0, 0.05, 7.5), 6.0], ["StalkerMorgue", Vector3(7.0, 0.05, 16.0), 3.0],
			["StalkerPathology", Vector3(20.0, 0.05, 15.5), 3.0], ["StalkerChapel", Vector3(19.5, 0.05, 23.0), 2.0],
			["StalkerSouth", Vector3(30.0, 0.05, 32.5), 7.0], ["StalkerWorkshop", Vector3(40.0, 0.05, 37.0), 2.5],
			["StalkerLaundry", Vector3(26.0, 0.05, 2.8), 2.0]]:
		_instance(stalker, groups.Enemies, e[0], e[1], {"wander_radius": e[2]})
	_instance("res://scenes/enemies/spitter.tscn", groups.Enemies, "SpitterPathology", Vector3(19.5, 0.05, 20.5), {"wander_radius": 2.0})
	_instance("res://scenes/enemies/spitter.tscn", groups.Enemies, "SpitterSouth", Vector3(12.0, 0.05, 32.5), {"wander_radius": 4.0})
	_extra_enemy(Vector3(27.5, 0.05, 20.0), 1, 6.0)
	_extra_enemy(Vector3(48.0, 0.05, 7.5), 1, 4.0)
	_extra_enemy(Vector3(6.5, 0.05, 27.0), 2, 2.0)
	_extra_enemy(Vector3(32.5, 0.05, 18.0), 2, 3.0)
	_extra_enemy(Vector3(8.0, 0.05, 37.0), 2, 3.0)


func _basement_discovery() -> void:
	var parent := _add(scene_root, Node3D.new(), "Places")
	for p: Array in [["b_stairs", 0, 0, 6, 6], ["b_boilers", 6, 0, 20, 6], ["b_laundry", 20, 0, 32, 6],
			["b_power", 32, 0, 44, 6], ["b_supplies", 44, 0, 56, 6], ["b_corridor", 0, 6, 56, 9],
			["b_morgue", 0, 9, 13, 22], ["b_pathology", 13, 9, 26, 22], ["b_archive", 0, 22, 13, 31],
			["b_chapel", 13, 22, 26, 31], ["b_center", 26, 9, 29, 31], ["b_waste", 29, 9, 36, 31],
			["b_incinerator", 36, 9, 56, 31], ["b_south", 0, 31, 46, 34], ["b_service", 0, 34, 16, 40],
			["b_cold", 16, 34, 30, 40], ["b_workshop", 30, 34, 46, 40], ["b_guard", 46, 31, 56, 40]]:
		var zone := Area3D.new()
		zone.set_script(load("res://scripts/world/discovery_zone.gd"))
		zone.set("place_id", StringName(p[0]))
		zone.set("size", Vector3(p[3] - p[1] - 0.4, 2.8, p[4] - p[2] - 0.4))
		zone.position = Vector3((p[1] + p[3]) / 2.0, 1.4, (p[2] + p[4]) / 2.0)
		_add(parent, zone, String(p[0]))


func _basement_systems() -> void:
	var nav := NavigationRegion3D.new()
	var navmesh := NavigationMesh.new()
	navmesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	navmesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	navmesh.geometry_source_group_name = &"nav_source"
	navmesh.cell_size = 0.25
	navmesh.cell_height = 0.25
	navmesh.agent_height = 2.0  # el dintel de las puertas (2.4) corta el navmesh con 2.25
	navmesh.agent_radius = 0.5
	navmesh.agent_max_climb = 0.25
	navmesh.agent_max_slope = 40.0
	nav.navigation_mesh = navmesh
	nav.set_script(load("res://scripts/world/runtime_nav_bake.gd"))
	_add(scene_root, nav, "Navigation")
	var persistence := Node3D.new()
	persistence.set_script(load("res://scripts/world/world_persistence.gd"))
	_add(scene_root, persistence, "WorldPersistence")
	var level_audio := Node.new()
	level_audio.set_script(load("res://scripts/world/level_audio.gd"))
	level_audio.set("ambience", &"hospital")
	level_audio.set("ambience_db", -2.0)
	_add(scene_root, level_audio, "LevelAudio")
	_loop_sound(scene_root, "fire", Vector3(51.0, 1.3, 20.0), -6.0, 3.0)
	var spawn := Marker3D.new()
	spawn.set_script(load("res://scripts/world/spawn_point.gd"))
	spawn.set("spawn_id", &"from_hospital")
	spawn.position = Vector3(3.0, 0.05, 7.6)
	spawn.rotation_degrees.y = 180.0
	_add(scene_root, spawn, "SpawnFromHospital")
	_instance("res://scenes/player/player.tscn", scene_root, "Player", Vector3(3.0, 0.05, 7.6))
	_instance("res://scenes/effects/ps1_post_process.tscn", scene_root, "PS1PostProcess", Vector3.ZERO)
	var ui: Node = load("res://scenes/ui/game_ui.tscn").instantiate()
	_add(scene_root, ui, "GameUI")
