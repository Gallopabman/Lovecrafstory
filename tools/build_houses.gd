extends "res://tools/build_hospital.gd"
## Genera las casas que se pueden visitar desde la avenida (zona 2): escenas chicas
## en res://scenes/levels/street_houses/<id>.tscn, cada una con su puerta de vuelta
## a la calle (SpawnPoint "house_<id>" en street.tscn). Reusa los helpers y los
## muebles del generador del hospital. Andamio de una sola pasada, como los otros.
## Uso: <godot> --headless --path . -s res://tools/build_houses.gd
##
## Cada interior: la puerta de calle está en la pared z = 0, en x = door_x, y la
## casa se extiende hacia -Z.

const OUT_DIR := "res://scenes/levels/street_houses/"
const HOUSE_MAT_DIR := "res://assets/materials/houses/"

## Nombres para el menú de inventario: GameMenu.ZONE_NAMES.
const HOUSES := {
	"ibarra": "HouseIbarra",
	"almacen": "HouseAlmacen",
	"relojeria": "HouseRelojeria",
	"pension": "HousePension",
	"ferreyra": "HouseFerreyra",
	"veterinaria": "HouseVeterinaria",
}

var house_id := ""
## Las casas que no dan a la avenida: a qué escena vuelven.
const RETURN_SCENES := {"veterinaria": "res://scenes/levels/park_street.tscn"}


func _initialize() -> void:
	GreyBoxScript = load("res://scripts/world/grey_box.gd")
	PropScript = load("res://scripts/world/prop.gd")
	InspectableScript = load("res://scripts/world/inspectable.gd")
	FlickerScript = load("res://scripts/world/flicker_light.gd")
	GatedScript = load("res://scripts/world/sanity_gated.gd")
	RefugeScript = load("res://scripts/world/refuge_zone.gd")
	seed(3150)
	_make_materials()
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	for id: String in HOUSES:
		house_id = id
		counters.clear()
		groups.clear()
		scene_root = Node3D.new()
		scene_root.name = HOUSES[id]
		for g in ["Structure", "Lights", "Props", "Items", "Inspectables", "Secrets", "Enemies"]:
			groups[g] = _add(scene_root, Node3D.new(), g)
		groups.Structure.add_to_group(&"nav_source", true)
		groups.Props.add_to_group(&"nav_source", true)
		_environment()
		var door_x: float = call("_house_" + id)
		_house_systems(door_x)
		var packed := PackedScene.new()
		packed.pack(scene_root)
		var path := OUT_DIR + id + ".tscn"
		var err := ResourceSaver.save(packed, path)
		print("Guardado %s (%s), nodos: %d" % [path, error_string(err), _count(scene_root)])
		scene_root.free()
	quit()


func _make_materials() -> void:
	super._make_materials()
	DirAccess.make_dir_recursive_absolute(HOUSE_MAT_DIR)
	var shader: Shader = load("res://shaders/ps1_spatial.gdshader")
	var defs := {
		"house_wall": ["wall_plaster", Color(0.78, 0.7, 0.6), 1.2],
		"house_wall2": ["wall_plaster", Color(0.6, 0.66, 0.62), 1.2],
		"house_wall3": ["wall_plaster", Color(0.72, 0.62, 0.66), 1.2],
		"fog_window": ["", Color(0.55, 0.56, 0.58), 1.0],
		"bulb": ["", Color(1.0, 0.85, 0.6), 1.0],
		"shelf_wood": ["wood_floor", Color(0.5, 0.38, 0.28), 1.0],
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
		var path := HOUSE_MAT_DIR + "m_%s.tres" % key
		ResourceSaver.save(m, path)
		mats[key] = load(path)


# --- Helpers de casa ------------------------------------------------------------

## Cuarto rectangular de x -w/2..w/2 y z -d..0, con la puerta de calle en `door_x`
## y ventanas (centros en x) en la pared del fondo que dan a la niebla.
func _shell(w: float, d: float, floor_mat: String, wall_mat: String, door_x := 0.0, windows: Array = []) -> void:
	var hw := w / 2.0
	_floor(-hw, -d, hw, 0.0, 0.0, floor_mat)
	_ceiling(-hw, -d, hw, 0.0, CEIL)
	_wall("x", 0.0, -hw - T / 2, hw + T / 2, 0.0, CEIL, T, [_door(door_x)], wall_mat, false)
	var openings := []
	for x: float in windows:
		openings.append([x, 1.4, 1.0, 2.2])
		# Del otro lado del vidrio, solo niebla.
		_box(groups.Structure, "FogWindow", Vector3(x, 1.6, -d - 0.4), Vector3(1.6, 1.4, 0.05), "fog_window", false)
	_wall("x", -d, -hw - T / 2, hw + T / 2, 0.0, CEIL, T, openings, wall_mat, true)
	_wall("z", -hw, -d, 0.0, 0.0, CEIL, T, [], wall_mat, false)
	_wall("z", hw, -d, 0.0, 0.0, CEIL, T, [], wall_mat, false)
	for x: float in windows:
		_point_light(Vector3(x, 1.6, -d + 0.6), Color(0.7, 0.75, 0.8), 0.35, 3.5)


## Lamparita colgando del techo.
func _bulb(x: float, z: float, energy := 1.0, flicker := false) -> void:
	_box(groups.Lights, "Cord", Vector3(x, CEIL - 0.25, z), Vector3(0.015, 0.5, 0.015), "bars", false)
	_box(groups.Lights, "Bulb", Vector3(x, CEIL - 0.52, z), Vector3(0.07, 0.09, 0.07), "bulb", false)
	_point_light(Vector3(x, CEIL - 0.7, z), Color(1.0, 0.78, 0.52), energy, 6.5, flicker)


func _pickup(base_name: String, item_id: String, pos: Vector3, count := 1) -> void:
	_instance("res://scenes/world/pickup.tscn", groups.Items, base_name, pos,
		{"item": load("res://assets/items/%s.tres" % item_id), "count": count})


func _stalker(pos: Vector3, wander := 1.5) -> void:
	_instance("res://scenes/enemies/stalker.tscn", groups.Enemies, "Stalker", pos, {"wander_radius": wander})


func _house_systems(door_x: float) -> void:
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
	level_audio.set("ambience_db", -10.0)
	_add(scene_root, level_audio, "LevelAudio")
	# Puerta de vuelta a la calle.
	var door := Area3D.new()
	door.set_script(load("res://scripts/world/zone_door.gd"))
	door.set("target_scene", RETURN_SCENES.get(house_id, "res://scenes/levels/street.tscn"))
	door.set("target_spawn", StringName("house_" + house_id))
	door.set("radius", 1.1)
	door.position = Vector3(door_x, 1.2, -0.3)
	_add(groups.Inspectables, door, "StreetDoor")
	_zone_door_visuals(door, Vector3(door_x, 0, -T / 2 - 0.02), 180.0, "door_wood_open", "", DOOR_W, DOOR_H)
	var spawn := Marker3D.new()
	spawn.set_script(load("res://scripts/world/spawn_point.gd"))
	spawn.set("spawn_id", &"inside")
	spawn.position = Vector3(door_x, 0.05, -2.1)
	_add(scene_root, spawn, "SpawnInside")
	_instance("res://scenes/player/player.tscn", scene_root, "Player", Vector3(door_x, 0.05, -1.3))
	_instance("res://scenes/effects/ps1_post_process.tscn", scene_root, "PS1PostProcess", Vector3.ZERO)
	var ui: Node = load("res://scenes/ui/game_ui.tscn").instantiate()
	_add(scene_root, ui, "GameUI")


# --- Casas -------------------------------------------------------------------------
# Cada una devuelve la x de su puerta de calle.

## Departamento de planta baja de una familia: living y cocina.
func _house_ibarra() -> float:
	_shell(7.0, 6.0, "wood", "house_wall", 0.0, [-1.3, 1.8])
	_bulb(-1.0, -3.2, 0.9, true)
	_bulb(2.2, -3.8, 0.6)
	# Living.
	_prop("rugRectangle", Vector3(-1.3, 0.005, -4.0), 0)
	_prop("loungeSofa", Vector3(-1.3, 0, -5.45), 0)
	_prop("tableCoffee", Vector3(-1.3, 0, -4.1), 0)
	_prop("cabinetTelevision", Vector3(-1.3, 0, -2.5), 180)
	_prop("televisionVintage", Vector3(-1.3, 0.55, -2.5), 180)
	_prop("bookcaseClosed", Vector3(-3.2, 0, -1.4), 90)
	_prop("loungeChair", Vector3(-2.9, 0, -3.9), 90)
	_prop("pottedPlant", Vector3(-3.0, 0, -5.5), 0, {"tint": Color(0.5, 0.45, 0.35)})
	# Cocina.
	_prop("kitchenCabinet", Vector3(1.4, 0, -5.55), 0)
	_prop("kitchenSink", Vector3(2.3, 0, -5.55), 0)
	_prop("kitchenCabinet", Vector3(3.1, 0, -5.55), 0)
	_prop("kitchenFridge", Vector3(3.1, 0, -3.6), -90)
	_prop("table", Vector3(1.6, 0, -2.9), 0)
	_prop("chair", Vector3(1.6, 0, -2.1), 180)
	_prop("chair", Vector3(0.9, 0, -3.2), 60)
	_prop("trashbag", Vector3(3.0, 0, -1.0), 30)
	_pickup("Peaches", "food_canned_peaches", Vector3(1.6, 0.8, -3.0))
	_pickup("Water", "food_water_bottle", Vector3(2.3, 1.02, -5.5))
	_pickup("Cloth", "material_cloth", Vector3(-1.3, 0.48, -5.35), 2)
	_inspect(Vector3(2.9, 1.3, -3.6), ["Una foto pegada con un imán: una nena con un globo. Atrás dice \"Lucía, 6 años\".",
		"Los imanes están ordenados en fila. Alguien los acomodó hace poco."], 1.0)
	_inspect(Vector3(-1.3, 0.9, -2.7), ["La pantalla está rajada desde adentro, como si algo hubiera querido salir."], 1.0)
	_inspect(Vector3(1.6, 1.0, -2.9), ["La mesa está puesta para tres. La comida lleva días servida y no tiene ni una mosca."], 1.0)
	return 0.0


## Almacén de barrio: mostrador, estantes y heladeras. Hay alguien entre los estantes.
func _house_almacen() -> float:
	_shell(8.0, 7.0, "floor_dirty", "house_wall2", 0.0, [2.4])
	_bulb(-1.5, -2.5, 1.0)
	_bulb(2.0, -4.8, 0.8, true)
	_counter(-3.6, -0.9, -2.2, 0.0)
	_prop("kitchenMicrowave", Vector3(-3.0, 1.04, -2.2), 0)
	for z in [-3.9, -5.6]:
		_prop("bookcaseOpen", Vector3(1.0, 0, z), 0)
		_prop("bookcaseOpen", Vector3(2.4, 0, z), 0)
	_prop("kitchenFridge", Vector3(3.5, 0, -2.2), -90)
	_prop("kitchenFridge", Vector3(3.5, 0, -3.2), -90)
	_prop("vending_machine", Vector3(-3.5, 0, -6.4), 90)
	for p in [Vector3(-2.2, 0, -6.4), Vector3(-1.6, 0, -6.5), Vector3(-2.0, 0.5, -6.45), Vector3(0.2, 0, -6.4)]:
		_prop("cardboardBoxClosed", p, randf_range(-20, 20))
	_prop("trashcan", Vector3(-0.4, 0, -1.0))
	_prop("WetFloorSign_01", Vector3(1.8, 0, -1.4), 30)
	_pickup("Chocolate1", "food_chocolate_bar", Vector3(1.0, 1.0, -3.9))
	_pickup("Chocolate2", "food_chocolate_bar", Vector3(2.4, 0.45, -5.6))
	_pickup("Peaches", "food_canned_peaches", Vector3(-2.2, 1.05, -2.2))
	_pickup("Water", "food_water_bottle", Vector3(3.3, 0.05, -4.4))
	_inspect(Vector3(-2.0, 1.2, -2.2), ["La caja registradora está abierta y llena. Nadie se llevó la plata.",
		"El libro de fiados. Última anotación: \"Sra. Ríos: leche y pan. Dice que paga mañana.\""], 1.2)
	_inspect(Vector3(3.3, 1.2, -2.7), ["Las heladeras zumban aunque no hay luz. Adentro, todo está congelado. Hasta las latas."], 1.2)
	_stalker(Vector3(1.7, 0.05, -4.75), 1.2)
	_extra_enemy(Vector3(-2.6, 0.05, -4.6), 2, 1.0)
	return 0.0


## Relojería: todos los relojes parados a la misma hora.
func _house_relojeria() -> float:
	_shell(6.0, 6.0, "wood", "house_wall3", 0.0, [0.3])
	_bulb(0.0, -3.0, 0.8, true)
	_counter(-2.6, 1.2, -2.0, 0.0)
	_prop("desk", Vector3(1.6, 0, -5.4), 0)
	_prop("lampRoundTable", Vector3(2.1, 0.76, -5.5), 0)
	_prop("chairDesk", Vector3(1.6, 0, -4.6), 180)
	_prop("bookcaseOpenLow", Vector3(-2.6, 0, -4.4), 90)
	_prop("bookcaseClosedDoors", Vector3(2.6, 0, -2.8), -90)
	_prop("cardboardBoxOpen", Vector3(-2.3, 0, -5.6), 20)
	# La pared de los relojes.
	for i in 9:
		var x := -2.5 + (i % 3) * 0.55
		var y := 1.5 + (i / 3) * 0.45
		_prop("wall_clock", Vector3(x, y, -5.88), 0)
	for i in 4:
		_prop("wall_clock", Vector3(-2.88, 1.7 + (i % 2) * 0.5, -1.2 - (i / 2) * 0.7), 90)
	_pickup("Metal", "material_metal", Vector3(1.6, 0.8, -5.3), 2)
	_pickup("Cable", "material_cable", Vector3(-2.6, 0.82, -4.4), 2)
	_pickup("Ammo", "ammo_9mm", Vector3(-0.6, 1.05, -2.0), 6)
	_inspect(Vector3(-2.0, 1.8, -5.4), ["Todos los relojes marcan las tres y cuarto. Los que tienen pila y los que no.",
		"El segundero de uno tiembla, como si quisiera avanzar y algo no lo dejara."], 1.2)
	_inspect(Vector3(1.6, 1.0, -5.1), ["Una lupa, pinzas, un reloj de bolsillo abierto. Adentro, en vez de engranajes, hay un diente."], 1.0)
	# Con poca cordura se oye (se lee) lo que dicen los relojes.
	var gated := Node3D.new()
	gated.set_script(GatedScript)
	gated.set("threshold", 2)
	_add(groups.Secrets, gated, "ClockWhisper")
	var label := Label3D.new()
	label.text = "TIC  TAC  TIC  TAC\nYA ES LA HORA"
	label.font = load("res://assets/fonts/pixel_operator/PixelOperator.ttf")
	label.font_size = 32
	label.pixel_size = 0.007
	label.modulate = Color(0.55, 0.05, 0.03)
	label.position = Vector3(0.6, 2.4, -5.88)
	_add(gated, label, "Label3D")
	return 0.0


## Pensión: un pasillo de entrada y la pieza del agente Sosa.
func _house_pension() -> float:
	_shell(9.0, 7.0, "wood", "house_wall", -2.4, [-3.0, 2.6])
	# Pared entre el pasillo (izquierda) y la pieza (derecha), con puerta al fondo.
	_wall("z", -0.6, -7.0, 0.0, 0.0, CEIL, T, [[-5.2, DOOR_W, 0.0, DOOR_H]], "house_wall3", false)
	_bulb(-2.4, -3.0, 0.6, true)
	_bulb(2.4, -3.6, 0.8)
	# Pasillo.
	_prop("coatRackStanding", Vector3(-4.0, 0, -1.0), 0)
	_prop("benchCushion", Vector3(-4.1, 0, -3.2), 90)
	_prop("pottedPlant", Vector3(-4.0, 0, -6.4), 0, {"tint": Color(0.45, 0.4, 0.3)})
	_prop("trashcan", Vector3(-1.1, 0, -1.0))
	_inspect(Vector3(-4.0, 1.4, -1.0), ["Un tapado verde colgado del perchero. Huele a naftalina y a perfume de otra época."], 1.0)
	# La pieza.
	_prop("rugRectangle", Vector3(2.2, 0.005, -3.8), 90)
	_prop("bedSingle", Vector3(3.3, 0, -4.6), 180)
	_prop("cabinetBedDrawerTable", Vector3(3.9, 0, -6.4), 0)
	_prop("bookcaseClosedDoors", Vector3(0.1, 0, -1.2), 90)
	_prop("chair", Vector3(0.6, 0, -3.4), 90)
	_prop("radio", Vector3(0.2, 0.0, -6.5), 0)
	_pickup("LetterSosa", "letter_sosa_01", Vector3(3.9, 0.58, -6.4))
	_pickup("KeyTheater", "key_theater", Vector3(3.6, 0.58, -6.2))
	_pickup("Wood", "material_wood", Vector3(0.4, 0.0, -5.0), 2)
	_pickup("Water", "food_water_bottle", Vector3(1.0, 0.05, -1.0))
	_inspect(Vector3(3.3, 0.8, -4.6), ["La cama está hecha con prolijidad de cuartel. Sobre la almohada, una gorra de policía."], 1.2)
	_stalker(Vector3(2.2, 0.05, -2.4), 1.5)
	_extra_enemy(Vector3(-2.4, 0.05, -5.6), 1, 1.0)
	return -2.4


## La casa del Dr. Ferreyra, el director del San Judas (pedido del usuario): living,
## escritorio y dormitorio. Se llevó la llave del sótano del hospital y no pudo tirarla.
func _house_ferreyra() -> float:
	_shell(10.0, 9.0, "wood", "house_wall2", -2.5, [-3.5, 2.5])
	# Pared del fondo del living (z -4.5), con dos puertas; y la que separa escritorio y dormitorio.
	_wall("x", -4.5, -5.0, 5.0, 0.0, CEIL, T, [_door(-2.5), _door(2.5)], "house_wall3", false)
	_wall("z", 0.0, -9.0, -4.5, 0.0, CEIL, T, [], "house_wall3", false)
	_bulb(-1.0, -2.2, 0.8)
	_bulb(-2.5, -6.8, 0.7, true)
	_bulb(2.5, -6.8, 0.4)
	# Living: buen gusto, polvo, y todo en su lugar.
	_prop("rugRectangle", Vector3(1.8, 0.005, -2.3), 90)
	_prop("loungeSofa", Vector3(2.0, 0, -3.8), 0)
	_prop("loungeChair", Vector3(3.9, 0, -2.0), -90)
	_prop("tableCoffee", Vector3(2.0, 0, -2.4))
	_prop("bookcaseClosedWide", Vector3(4.6, 0, -0.8), -90)
	_prop("lampRoundFloor", Vector3(0.4, 0, -4.0))
	_prop("coatRackStanding", Vector3(-4.3, 0, -0.8))
	_prop("pottedPlant", Vector3(-4.3, 0, -3.9), 0, {"tint": Color(0.45, 0.4, 0.3)})
	_box(groups.Props, "Portrait", Vector3(2.0, 1.8, -4.38), Vector3(1.0, 0.7, 0.04), "photo", false)
	_inspect(Vector3(2.0, 1.6, -3.9), ["Un retrato de Ferreyra joven, con el guardapolvo recién estrenado, el día que se recibió.",
		"Alguien le tachó los ojos con un bisturí. Con cuidado, como quien opera."], 1.2)
	_inspect(Vector3(-4.3, 1.4, -0.8), ["Un sobretodo y un paraguas. Las mangas del sobretodo tienen manchas marrones hasta el codo."], 0.9)
	# Escritorio (x -5..0, z -9..-4.5): el diario y la llave.
	_prop("desk", Vector3(-2.5, 0, -8.2))
	_prop("chairDesk", Vector3(-2.5, 0, -7.3), 180)
	_prop("lampRoundTable", Vector3(-1.7, 0.76, -8.3))
	for z in [-5.6, -7.0]:
		_prop("bookcaseClosed", Vector3(-4.6, 0, z), 90)
	_prop("file_cabinet", Vector3(-0.5, 0, -8.5))
	_prop("cardboardBoxOpen", Vector3(-1.0, 0, -5.2), 30)
	_pickup("LetterFerreyra2", "letter_ferreyra_02", Vector3(-2.8, 0.78, -8.2))
	_pickup("KeyBasement", "key_basement", Vector3(-2.5, 0.5, -7.25))
	_inspect(Vector3(-2.5, 1.0, -7.6), ["Sobre la silla, el saco de Ferreyra, doblado. En el bolsillo hay algo duro, frío y largo."], 1.0)
	_inspect(Vector3(-4.2, 1.3, -6.3), ["Tratados de psiquiatría, de neurología, de anatomía patológica. Un estante entero sobre el sueño.",
		"Los lomos de los últimos están marcados con la misma palabra, a mano: \"NIEBLA\"."], 1.1)
	# Dormitorio (x 0..5, z -9..-4.5): Ferreyra no salió nunca de acá.
	_prop("bedSingle", Vector3(3.2, 0, -7.7), 90)
	_prop("cabinetBedDrawerTable", Vector3(4.6, 0, -5.2), -90)
	_prop("chair", Vector3(1.0, 0, -8.3), 30)
	_prop("trashbag", Vector3(0.6, 0, -5.0), 70)
	_prop("blood", Vector3(2.4, 0.01, -6.2), 40)
	_inspect(Vector3(3.2, 0.9, -7.7), ["Ferreyra está acostado, vestido, con los zapatos puestos. Tiene las manos cruzadas sobre el pecho.",
		"En la mesa de luz, frascos vacíos y un vaso de agua. Se fue durmiendo. Eligió no ver lo que venía.",
		"No sé si siento lástima o bronca. Las dos cosas pesan lo mismo."], 1.3)
	_pickup("Kit", "medicine_kit", Vector3(4.6, 0.58, -5.2))
	_pickup("Shells", "ammo_shells", Vector3(-4.0, 0.05, -2.0), 4)
	_stalker(Vector3(1.0, 0.05, -1.6), 1.2)
	_extra_enemy(Vector3(-2.5, 0.05, -6.0), 2, 1.0)
	# En Quebrado, lo que escribió en la pared del escritorio antes de acostarse.
	var gated := Node3D.new()
	gated.set_script(GatedScript)
	gated.set("threshold", 2)
	_add(groups.Secrets, gated, "FerreyraWall")
	var label := Label3D.new()
	label.text = "LOS ENCERRÉ ABAJO\nPORQUE ME LLAMABAN\nPOR MI NOMBRE"
	label.font = load("res://assets/fonts/pixel_operator/PixelOperator.ttf")
	label.font_size = 32
	label.pixel_size = 0.006
	label.modulate = Color(0.55, 0.05, 0.03)
	label.position = Vector3(-0.12, 1.8, -6.8)
	label.rotation_degrees.y = -90
	_add(gated, label, "Label3D")
	return -2.5


## La Veterinaria San Roque (pedido del usuario: ahí está Teodoro, listo para el alta).
## Se entra desde Rondeau, en el barrio. Sala de espera con mostrador; atrás, el
## consultorio y la internación con las jaulas.
func _house_veterinaria() -> float:
	_shell(14.0, 12.0, "floor", "house_wall2", 0.0, [-4.5, 4.5])
	# Pared entre la sala de espera (z -5..0) y el fondo, y la que separa consultorio e internación.
	_wall("x", -5.0, -7.0, 7.0, 0.0, CEIL, T, [_door(-4.0), _door(3.0)], "house_wall", false)
	_wall("z", -1.0, -12.0, -5.0, 0.0, CEIL, T, [], "house_wall", false)
	_bulb(0.0, -2.5, 0.8, true)
	_bulb(-4.0, -8.5, 0.6)
	_bulb(3.0, -8.5, 0.5, true)
	# Sala de espera: mostrador, bancos, carteles, la pecera.
	# El mostrador a la derecha: la puerta de la internación (x 3) queda libre desde la sala de espera.
	_counter(4.4, 6.8, -3.4, 0.0)
	_prop("computerScreen", Vector3(5.6, 1.05, -3.3), 180)
	_prop("chairDesk", Vector3(5.8, 0, -4.3), 0)
	for x in [-6.0, -4.8]:
		_prop("bench", Vector3(x, 0, -1.0), 90)
	_prop("pottedPlant", Vector3(-6.4, 0, -4.4))
	_box(groups.Props, "FishTank", Vector3(-6.5, 1.1, -3.0), Vector3(0.5, 0.5, 1.2), "fog_window")
	_box(groups.Props, "FishTankStand", Vector3(-6.5, 0.42, -3.0), Vector3(0.5, 0.84, 1.2), "shelf_wood")
	for i in 3:
		_box(groups.Structure, "Poster", Vector3(-1.5 + i * 0.9, 1.6, -4.88), Vector3(0.6, 0.8, 0.02), "paper", false)
	_inspect(Vector3(-6.0, 1.2, -3.0), ["La pecera. El agua está turbia y los peces nadan todos juntos, en círculo, sin parar."], 1.0)
	_inspect(Vector3(5.0, 1.2, -3.0), ["En el mostrador, el libro de turnos. La última línea: \"Teodoro - ALTA - avisar a la familia\".",
		"Al lado, alguien dibujó un gato con birome. Tiene cara de enojado. Es igualito."], 1.2)
	_inspect(Vector3(-0.6, 1.5, -4.6), ["Carteles: \"VACUNACIÓN ANTIRRÁBICA\", \"CASTRÁ A TU MASCOTA\". Alguien escribió abajo, a mano: \"Teo, esto va por vos\"."], 1.2)
	# Consultorio (x -7..-1): camilla de acero, armario, pileta, balanza.
	_box(groups.Props, "ExamTable", Vector3(-4.0, 0.45, -8.5), Vector3(1.2, 0.9, 0.7), "metal")
	_prop("tall_cabinet", Vector3(-6.6, 0, -9.0), 90)
	_prop("kitchenSink", Vector3(-4.0, 0, -11.55), 0)
	_box(groups.Props, "Scale", Vector3(-2.0, 0.05, -10.8), Vector3(0.6, 0.1, 0.5), "metal", false)
	_prop("blood", Vector3(-3.6, 0.01, -7.4), 30)
	_inspect(Vector3(-4.0, 1.0, -8.5), ["La camilla de acero todavía tiene pelos grises pegados. Muchos. Demasiados para un solo animal."], 1.1)
	# Internación (x -1..7): las jaulas contra el fondo, dos filas.
	for row in 2:
		for i in 4:
			var center := Vector3(0.5 + i * 1.6, 0.55 + row * 1.0, -11.3)
			var open := (row == 1 and i == 0) or (row == 0 and i == 3)
			_cage(center, open, row == 0 and i == 1)
	_label3d_house("TEODORO\nALTA", Vector3(2.1, 1.25, -10.48), 0, Color(0.15, 0.15, 0.2))
	_cat(Vector3(2.1, 0.14, -11.3), 0.0, 0).set("radius", 1.6)
	_prop("blood", Vector3(5.2, 0.01, -9.8), 120)
	_inspect(Vector3(5.3, 1.0, -10.2), ["Dos jaulas están abiertas, con los barrotes doblados hacia afuera. Lo que había adentro salió solo."], 1.2)
	_prop("cardboardBoxOpen", Vector3(6.3, 0, -6.0), 30)
	_pickup("Bandage", "medicine_bandage", Vector3(-6.6, 1.0, -9.0))
	_pickup("Cloth", "material_cloth", Vector3(6.2, 0.45, -6.0), 2)
	_pickup("Chocolate", "food_chocolate_bar", Vector3(6.4, 1.05, -3.4))
	_stalker(Vector3(-4.0, 0.05, -10.4), 1.2)
	_extra_enemy(Vector3(4.0, 0.05, -7.0), 1, 1.5)
	_extra_enemy(Vector3(-5.0, 0.05, -2.0), 2, 1.0, "res://scenes/enemies/spitter.tscn")
	# Quebrado: en la jaula vacía de al lado, algo te mira.
	var gated := Node3D.new()
	gated.set_script(GatedScript)
	gated.set("threshold", 2)
	_add(groups.Secrets, gated, "CageWriting")
	_label3d_house("ÉL TAMBIÉN\nTE ESPERABA", Vector3(0.5, 2.6, -10.45), 0, Color(0.55, 0.05, 0.03), gated)
	return 0.0


## Una jaula de internación (caja de metal con barrotes al frente; abierta o no).
func _cage(center: Vector3, open: bool, has_cat: bool) -> void:
	var w := 1.4
	var h := 0.9
	var d := 0.9
	_box(groups.Props, "CageFloor", center + Vector3(0, -h / 2 + 0.02, 0), Vector3(w, 0.04, d), "metal", true)
	_box(groups.Props, "CageTop", center + Vector3(0, h / 2 - 0.02, 0), Vector3(w, 0.04, d), "metal", false)
	for sx in [-1.0, 1.0]:
		_box(groups.Props, "CageSide", center + Vector3(sx * (w / 2 - 0.02), 0, 0), Vector3(0.04, h, d), "metal", false)
	if open:
		# La puerta, arrancada, colgando de una bisagra.
		var door := _box(groups.Props, "CageDoorOpen", center + Vector3(-w / 2 - 0.3, -0.1, d / 2 + 0.3), Vector3(0.6, 0.7, 0.03), "bars", false)
		door.rotation_degrees = Vector3(10, 60, 15)
	else:
		for k in 7:
			_box(groups.Props, "CageBar", center + Vector3(-w / 2 + 0.1 + k * 0.2, 0, d / 2), Vector3(0.025, h - 0.06, 0.025), "bars", false)
	if has_cat:
		_box(groups.Props, "CageBlanket", center + Vector3(0, -h / 2 + 0.06, 0), Vector3(w - 0.2, 0.04, d - 0.2), "blanket", false)


func _label3d_house(text: String, pos: Vector3, yaw: float, color: Color, parent: Node = null) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = load("res://assets/fonts/pixel_operator/PixelOperator.ttf")
	label.font_size = 32
	label.pixel_size = 0.004
	label.modulate = color
	label.position = pos
	label.rotation_degrees.y = yaw
	_add(parent if parent else groups.Props, label, "Label")
