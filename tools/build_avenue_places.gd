extends "res://tools/build_hospital.gd"
## Genera las dos zonas nuevas de la avenida (pedido del usuario: "dos zonas nuevas,
## pueden ser lo que quieras"): la Comisaría 12 y la Parroquia San Judas Tadeo.
## Se entra por dos puertas de la avenida (street.tscn, spawn "house_comisaria" /
## "house_iglesia"); adentro, spawn "inside". Reusa los helpers del hospital.
## Andamio de una sola pasada, como los otros.
## Uso: <godot> --headless --path . -s res://tools/build_avenue_places.gd

const PLACES_MAT_DIR := "res://assets/materials/avenue_places/"
const PC := 3.2          # alto de la comisaría


func _initialize() -> void:
	GreyBoxScript = load("res://scripts/world/grey_box.gd")
	PropScript = load("res://scripts/world/prop.gd")
	InspectableScript = load("res://scripts/world/inspectable.gd")
	FlickerScript = load("res://scripts/world/flicker_light.gd")
	GatedScript = load("res://scripts/world/sanity_gated.gd")
	RefugeScript = load("res://scripts/world/refuge_zone.gd")
	seed(1212)
	_make_materials()
	_build("PoliceStation", "res://scenes/levels/police_station.tscn", _police_station)
	_build("Church", "res://scenes/levels/church.tscn", _church)
	quit()


func _build(root_name: String, out: String, content: Callable) -> void:
	counters.clear()
	groups.clear()
	scene_root = Node3D.new()
	scene_root.name = root_name
	for g in ["Structure", "Lights", "Props", "Items", "Inspectables", "Secrets", "Enemies"]:
		groups[g] = _add(scene_root, Node3D.new(), g)
	groups.Structure.add_to_group(&"nav_source", true)
	groups.Props.add_to_group(&"nav_source", true)
	var spawn_info: Array = content.call()
	_place_systems(spawn_info[0], spawn_info[1], spawn_info[2])
	var packed := PackedScene.new()
	packed.pack(scene_root)
	var err := ResourceSaver.save(packed, out)
	print("Guardado %s (%s), nodos: %d" % [out, error_string(err), _count(scene_root)])
	scene_root.free()


func _make_materials() -> void:
	super._make_materials()
	DirAccess.make_dir_recursive_absolute(PLACES_MAT_DIR)
	var shader: Shader = load("res://shaders/ps1_spatial.gdshader")
	var defs := {
		"police_wall": ["wall_plaster", Color(0.6, 0.64, 0.68), 1.2],
		"police_floor": ["floor_tiles_dirty", Color(0.6, 0.6, 0.58), 0.45],
		"cell_floor": ["concrete", Color(0.42, 0.42, 0.42), 0.4],
		"church_wall": ["wall_plaster", Color(0.72, 0.68, 0.6), 0.8],
		"church_floor": ["floor_tiles", Color(0.55, 0.45, 0.38), 0.35],
		"stone": ["concrete", Color(0.5, 0.48, 0.45), 0.4],
		"pew": ["wood_floor", Color(0.38, 0.26, 0.18), 1.2],
		"glass_red": ["", Color(0.5, 0.08, 0.06), 1.0],
		"glass_blue": ["", Color(0.08, 0.14, 0.45), 1.0],
		"glass_amber": ["", Color(0.55, 0.38, 0.1), 1.0],
		"candle": ["", Color(0.92, 0.88, 0.75), 1.0],
		"gold2": ["wall_plaster", Color(0.7, 0.55, 0.25), 2.0],
		"gap_dark": ["", Color(0.015, 0.012, 0.012), 1.0],
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
		if key.begins_with("glass"):
			m.set_shader_parameter(&"emission_color", (d[1] as Color) * 0.9)
		if key == "candle":
			m.set_shader_parameter(&"emission_color", Color(1.0, 0.75, 0.4))
		var path := PLACES_MAT_DIR + "m_%s.tres" % key
		ResourceSaver.save(m, path)
		mats[key] = load(path)


# --- Helpers ------------------------------------------------------------------------

func _pickup(base_name: String, item_id: String, pos: Vector3, count := 1, parent: Node = null) -> void:
	_instance("res://scenes/world/pickup.tscn", parent if parent else groups.Items, base_name, pos,
		{"item": load("res://assets/items/%s.tres" % item_id), "count": count})


func _stalker(pos: Vector3, wander := 3.0) -> void:
	_instance("res://scenes/enemies/stalker.tscn", groups.Enemies, "Stalker", pos, {"wander_radius": wander})


func _label3d(parent: Node, text: String, pos: Vector3, yaw: float, color: Color, px := 0.008) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = load("res://assets/fonts/pixel_operator/PixelOperator.ttf")
	label.font_size = 32
	label.pixel_size = px
	label.modulate = color
	label.position = pos
	label.rotation_degrees.y = yaw
	_add(parent, label, "Label")


## Rejas de un calabozo a lo largo de X (barrotes visuales + colisión), con hueco de puerta.
func _cell_bars(z: float, x0: float, x1: float, door_x: float, door_open: bool) -> void:
	var x := x0 + 0.12
	while x < x1:
		var in_door := absf(x - door_x) < 0.55
		if not (in_door and door_open):
			_box(groups.Structure, "Bar", Vector3(x, PC / 2, z), Vector3(0.05, PC, 0.05), "bars", false)
		x += 0.2
	_box(groups.Structure, "BarRail", Vector3((x0 + x1) / 2, 2.2, z), Vector3(x1 - x0, 0.06, 0.06), "bars", false)
	if door_open:
		_box(groups.Structure, "BarsCollider", Vector3((x0 + door_x - 0.55) / 2, PC / 2, z),
			Vector3(door_x - 0.55 - x0, PC, 0.15), "bars", true, false)
		_box(groups.Structure, "BarsCollider", Vector3((door_x + 0.55 + x1) / 2, PC / 2, z),
			Vector3(x1 - door_x - 0.55, PC, 0.15), "bars", true, false)
	else:
		_box(groups.Structure, "BarsCollider", Vector3((x0 + x1) / 2, PC / 2, z), Vector3(x1 - x0, PC, 0.15), "bars", true, false)


func _place_systems(door_pos: Vector3, spawn_pos: Vector3, ambience: StringName) -> void:
	var nav := NavigationRegion3D.new()
	var navmesh := NavigationMesh.new()
	navmesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	navmesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	navmesh.geometry_source_group_name = &"nav_source"
	navmesh.cell_size = 0.25
	navmesh.cell_height = 0.25
	navmesh.agent_height = 2.25
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
	level_audio.set("ambience", ambience)
	level_audio.set("ambience_db", -9.0)
	_add(scene_root, level_audio, "LevelAudio")
	var spawn := Marker3D.new()
	spawn.set_script(load("res://scripts/world/spawn_point.gd"))
	spawn.set("spawn_id", &"inside")
	spawn.position = spawn_pos
	_add(scene_root, spawn, "SpawnInside")
	_instance("res://scenes/player/player.tscn", scene_root, "Player", spawn_pos)
	_instance("res://scenes/effects/ps1_post_process.tscn", scene_root, "PS1PostProcess", Vector3.ZERO)
	var ui: Node = load("res://scenes/ui/game_ui.tscn").instantiate()
	_add(scene_root, ui, "GameUI")


## Puerta de vuelta a la avenida, con su modelo entreabierto.
func _street_door(id: String, pos: Vector3, wall_pos: Vector3, yaw: float, width: float, height: float) -> void:
	var door := Area3D.new()
	door.set_script(load("res://scripts/world/zone_door.gd"))
	door.set("target_scene", "res://scenes/levels/street.tscn")
	door.set("target_spawn", StringName("house_" + id))
	door.set("radius", 1.2)
	door.position = pos
	_add(groups.Inspectables, door, "StreetDoor")
	_zone_door_visuals(door, wall_pos, yaw, "door_wood_open" if id == "iglesia" else "door_metal_open", "", width, height)


# --- Comisaría 12 -------------------------------------------------------------------
# Planta: x 0-20, z 0-14. Entrada al sur (z = 14, x = 10). Mesa de entradas (z 9-14),
# oficina del comisario (x 0-7, z 0-9), sala de guardia (x 7-13), calabozos (x 13-20).
# Secretos: depósito de evidencias detrás de la guardia (Difícil) y el calabozo 3 (Insane).

func _police_station() -> Array:
	_environment()
	_floor(0, 0, 20, 14, 0.0, "police_floor")
	_floor(13, 0, 20, 9, 0.0, "cell_floor")
	_ceiling(0, 0, 20, 14, PC)
	_wall("x", 14.0, -TE / 2, 20 + TE / 2, 0.0, PC, TE, [[10.0, 1.4, 0.0, 2.4], _window(3.0), _window(17.0)], "police_wall", true)
	_wall("x", 0.0, -TE / 2, 20 + TE / 2, 0.0, PC, TE, [[10.0, DOOR_W, 0.0, DOOR_H]], "police_wall", false)
	_wall("z", 0.0, 0.0, 14.0, 0.0, PC, TE, [], "police_wall", false)
	_wall("z", 20.0, 0.0, 14.0, 0.0, PC, TE, [], "police_wall", false)
	# Pared entre la mesa de entradas y el fondo, con tres puertas.
	_wall("x", 9.0, 0.0, 20.0, 0.0, PC, T, [_door(3.5), _door(10.0), _door(16.5)], "police_wall", false)
	_wall("z", 7.0, 0.0, 9.0, 0.0, PC, T, [], "police_wall", false)
	_wall("z", 13.0, 0.0, 9.0, 0.0, PC, T, [], "police_wall", false)
	for x in [3.0, 17.0]:
		_box(groups.Structure, "FogWindow", Vector3(x, 1.65, 14.4), Vector3(1.9, 1.3, 0.05), "fog_window" if mats.has("fog_window") else "lamp_off", false)
	for p in [Vector3(5.0, 0, 11.5), Vector3(15.0, 0, 11.5), Vector3(3.5, 0, 4.5), Vector3(10.0, 0, 4.5), Vector3(16.5, 0, 6.5)]:
		_ceiling_light(p.x, p.z, 0, "flicker" if p.x == 10.0 else ("off" if p.x == 16.5 else "on"), 0.7)
	_room_sign("COMISARÍA 12", 10.0, 9.0 + T / 2, 0.0, true, 2.75)

	# Mesa de entradas (z 9-14): mostrador, bancos, carteles de búsqueda.
	_counter(6.5, 13.5, 10.6, 0.0)
	_prop("computerScreen", Vector3(8.0, 1.05, 10.6), 180)
	_prop("chairDesk", Vector3(9.5, 0, 9.8), 0)
	for x in [1.5, 3.0, 17.0, 18.5]:
		_prop("bench", Vector3(x, 0, 13.4), 180)
	_prop("pottedPlant", Vector3(0.6, 0, 9.6), 0, {"tint": Color(0.4, 0.38, 0.3)})
	_prop("water_cooler", Vector3(19.4, 0, 9.6), -90)
	for i in 4:
		_box(groups.Structure, "Poster", Vector3(0.17, 1.6, 10.2 + i * 0.75), Vector3(0.02, 0.6, 0.45), "paper", false)
	_label3d(groups.Structure, "SE BUSCA", Vector3(0.19, 2.0, 11.3), 90, Color(0.2, 0.15, 0.1), 0.006)
	_pickup("PoliceLog", "letter_police_02", Vector3(11.2, 1.07, 10.6))
	_inspect(Vector3(0.4, 1.5, 11.3), ["Carteles de \"se busca\". Las caras están todas raspadas con algo filoso.",
		"En uno, debajo de la raspadura, se lee: \"Ibáñez\"."], 1.2)

	# Oficina del comisario (x 0-7, z 0-9).
	_prop("desk", Vector3(3.5, 0, 2.0), 180)
	_prop("chairDesk", Vector3(3.5, 0, 2.9), 0)
	_prop("file_cabinet", Vector3(0.45, 0, 1.0), 90)
	_prop("file_cabinet", Vector3(0.45, 0, 2.0), 90)
	_prop("bookcaseClosed", Vector3(6.55, 0, 1.2), -90)
	_prop("wall_clock", Vector3(3.5, 2.3, 0.17), 0)
	_pickup("Ammo1", "ammo_9mm", Vector3(3.0, 0.8, 2.0), 8)
	_inspect(Vector3(3.5, 1.0, 2.2), ["El escritorio del comisario. Un expediente: \"Desaparición Elena M. de Sosa, 1979. Archivado\".",
		"Alguien lo desarchivó hace poco. Las hojas están húmedas."], 1.1)

	# Sala de guardia (x 7-13, z 0-9): lockers, mesa, café.
	for z in [0.6, 1.4, 2.2]:
		_prop("locker", Vector3(7.45, 0, z), 90)
	_prop("table", Vector3(10.5, 0, 5.0), 0)
	for p in [[Vector3(10.5, 0, 5.9), 180], [Vector3(10.5, 0, 4.1), 0], [Vector3(9.6, 0, 5.0), 90]]:
		_prop("chair", p[0], p[1])
	_prop("kitchenCoffeeMachine", Vector3(12.5, 0.95, 0.5), 0)
	_prop("kitchenCabinet", Vector3(12.5, 0, 0.5), 0)
	_pickup("Bandage", "medicine_bandage", Vector3(10.5, 0.8, 5.0), 1)
	_pickup("Metal", "material_metal", Vector3(8.0, 0, 7.8), 2)
	_pickup("Cable", "material_cable", Vector3(12.4, 0, 8.4), 1)
	_inspect(Vector3(7.8, 1.2, 1.4), ["Lockers de los agentes. El de \"Sosa, R.\" está abierto y vacío. Adentro, una foto de una mujer cantando."], 1.0)

	# Calabozos (x 13-20, z 0-9): tres celdas contra la pared norte (z 0-4), pasillo al sur.
	for i in 3:
		var x0 := 13.0 + i * 2.33
		if i > 0:
			_wall("z", x0, 0.0, 4.0, 0.0, PC, 0.15, [], "police_wall", false)
		_cell_bars(4.0, x0, x0 + 2.33, x0 + 1.17, i != 1)
		_prop("bench", Vector3(x0 + 1.17, 0, 0.7), 0, {"tint": Color(0.5, 0.5, 0.5)})
	_label3d(groups.Structure, "1", Vector3(14.17, 2.6, 4.1), 0, Color(0.8, 0.8, 0.75), 0.01)
	_label3d(groups.Structure, "2", Vector3(16.5, 2.6, 4.1), 0, Color(0.8, 0.8, 0.75), 0.01)
	_label3d(groups.Structure, "3", Vector3(18.83, 2.6, 4.1), 0, Color(0.8, 0.8, 0.75), 0.01)
	_box(groups.Props, "PocketWatch", Vector3(16.5, 0.02, 2.4), Vector3(0.08, 0.02, 0.08), "gold" if mats.has("gold") else "gold2", false)
	_inspect(Vector3(16.5, 1.0, 4.4), ["El calabozo 2, el del relojero. La reja tiene el candado puesto.",
		"En el piso, un reloj de bolsillo parado a las tres y cuarto."], 1.2)
	_inspect(Vector3(18.83, 1.0, 4.4), ["El calabozo 3 está cerrado. Adentro, alguien raspó la pared con las uñas hasta los ladrillos."], 1.2)

	# Secreto (Difícil): el depósito de evidencias, tapiado detrás de la sala de guardia (z < 0).
	var lying := _difficulty_gate("EvidenceWall", 1, true)
	var wall: StaticBody3D = GreyBoxScript.new()
	wall.set("size", Vector3(DOOR_W, DOOR_H, TE + 0.04))
	wall.set("material", mats.police_wall)
	wall.position = Vector3(10.0, DOOR_H / 2, 0.0)
	_add(lying, wall, "Wall")
	var room := _difficulty_gate("Evidence", 1)
	_box(room, "EvidenceFloor", Vector3(10.0, -0.01, -1.7), Vector3(4.0, 0.02, 3.0), "cell_floor")
	_box(room, "EvidenceCeiling", Vector3(10.0, PC + 0.01, -1.7), Vector3(4.0, 0.02, 3.0), "ceiling", false)
	_box(room, "EvidenceWallN", Vector3(10.0, PC / 2, -3.3), Vector3(4.2, PC, 0.2), "police_wall")
	_box(room, "EvidenceWallW", Vector3(7.9, PC / 2, -1.7), Vector3(0.2, PC, 3.2), "police_wall")
	_box(room, "EvidenceWallE", Vector3(12.1, PC / 2, -1.7), Vector3(0.2, PC, 3.2), "police_wall")
	_prop("bookcaseOpen", Vector3(8.4, 0, -2.6), 90, {"parent": room})
	_prop("bookcaseOpen", Vector3(11.6, 0, -2.6), -90, {"parent": room})
	for p in [Vector3(9.3, 0, -2.9), Vector3(10.7, 0, -2.9)]:
		_prop("cardboardBoxClosed", p, randf_range(-10, 10), {"parent": room, "h": 0.5})
	_point_light(Vector3(10.0, 2.6, -1.7), Color(0.85, 0.9, 1.0), 0.6, 4.5, true, room)
	_pickup("EvidenceShells", "ammo_shells", Vector3(8.4, 1.0, -2.6), 6, room)
	_pickup("EvidenceAmmo", "ammo_9mm", Vector3(11.6, 1.0, -2.6), 12, room)
	_pickup("EvidenceKit", "medicine_kit", Vector3(10.0, 0.05, -2.2), 1, room)
	# Secreto (Insane): el calabozo 3 se abre y adentro hay algo para vos.
	var cell := _difficulty_gate("Cell3Open", 2)
	_pickup("Cell3Kit", "medicine_kit", Vector3(18.8, 0.05, 1.4), 1, cell)
	_pickup("Cell3Shells", "ammo_shells", Vector3(18.2, 0.05, 2.4), 4, cell)
	_label3d(cell, "ACÁ ESTUVO\nTU MADRE", Vector3(18.83, 1.7, 0.17), 0, Color(0.55, 0.05, 0.03), 0.007)
	var cell_bars := _difficulty_gate("Cell3Bars", 2, true)
	_box(cell_bars, "Cell3Lock", Vector3(18.83, 1.1, 4.0), Vector3(1.1, 2.2, 0.15), "bars", true, false)
	for i in 5:
		_box(cell_bars, "Cell3DoorBar", Vector3(18.4 + i * 0.2, PC / 2, 4.0), Vector3(0.05, PC, 0.05), "bars", false)
	_box(cell_bars, "Cell3Padlock", Vector3(18.83, 1.1, 4.08), Vector3(0.1, 0.14, 0.06), "metal", false)

	# Enemigos.
	_stalker(Vector3(16.5, 0.05, 6.5), 2.5)
	_stalker(Vector3(4.0, 0.05, 6.0), 2.0)
	_extra_enemy(Vector3(10.0, 0.05, 11.8), 1, 3.0)
	_extra_enemy(Vector3(10.5, 0.05, 3.0), 2, 2.0)
	_extra_enemy(Vector3(3.5, 0.05, 11.5), 2, 2.0)

	_street_door("comisaria", Vector3(10.0, 1.2, 13.5), Vector3(10.0, 0, 14.0 - TE / 2 - 0.02), 180.0, 1.4, 2.4)
	return [Vector3(10.0, 1.2, 13.5), Vector3(10.0, 0.05, 11.4), &"hospital"]


# --- Parroquia San Judas Tadeo --------------------------------------------------------
# Planta: x 0-16, z 0-26. Entrada al sur (z = 26, x = 8). Nave con bancos, altar al norte
# (tarima a 0.5 m), confesionario, sacristía (x 11-16, z 0-5).
# Secreto (Insane): la trampa frente al altar se abre y baja a la cripta (y -3).

const NAVE_H := 7.0
const ALTAR_Y := 0.5
const CRYPT_Y := -3.0


func _church() -> Array:
	_environment()
	# Piso de la nave con el hueco de la trampa (x 7-9, z 6.5-8.5).
	# Piso de la nave con el hueco de la escalera de la cripta (x 7-9, z 6.5-12).
	_box(groups.Structure, "FloorA", Vector3(8.0, -0.15, 19.0), Vector3(16.0, 0.3, 14.0), "church_floor")
	_box(groups.Structure, "FloorB", Vector3(3.5, -0.15, 9.25), Vector3(7.0, 0.3, 5.5), "church_floor")
	_box(groups.Structure, "FloorC", Vector3(12.5, -0.15, 9.25), Vector3(7.0, 0.3, 5.5), "church_floor")
	_box(groups.Structure, "FloorD", Vector3(8.0, -0.15, 5.75), Vector3(16.0, 0.3, 1.5), "church_floor")
	_box(groups.Structure, "Ceiling", Vector3(8.0, NAVE_H + 0.1, 13.0), Vector3(16.0, 0.2, 26.0), "pew", false)
	_wall("x", 26.0, -TE / 2, 16 + TE / 2, 0.0, NAVE_H, TE, [[8.0, 1.8, 0.0, 2.9]], "church_wall", false)
	_wall("x", 0.0, -TE / 2, 16 + TE / 2, 0.0, NAVE_H, TE, [], "church_wall", false)
	_wall("z", 0.0, 0.0, 26.0, 0.0, NAVE_H, TE, [], "church_wall", false)
	_wall("z", 16.0, 0.0, 26.0, 0.0, NAVE_H, TE, [], "church_wall", false)
	# Vitrales (brillan solos) en las paredes laterales.
	var glass := ["glass_red", "glass_blue", "glass_amber"]
	for i in 4:
		var z := 8.0 + i * 4.5
		for x in [0.17, 15.83]:
			_box(groups.Structure, "StainedGlass", Vector3(x, 4.2, z), Vector3(0.04, 2.4, 1.0), glass[(i + int(x)) % 3], false)
		_point_light(Vector3(1.0, 4.0, z), Color(0.7, 0.5, 0.45), 0.35, 5.0)
		_point_light(Vector3(15.0, 4.0, z), Color(0.5, 0.55, 0.75), 0.35, 5.0)
	# Bancos (dos columnas, pasillo central x 7-9).
	for row in 9:
		var z := 10.0 + row * 1.6
		for block: Vector2 in [Vector2(1.0, 6.6), Vector2(9.4, 15.0)]:
			var mid := (block.x + block.y) / 2
			_box(groups.Props, "Pew", Vector3(mid, 0.23, z), Vector3(block.y - block.x, 0.46, 0.5), "pew")
			_box(groups.Props, "PewBack", Vector3(mid, 0.6, z + 0.3), Vector3(block.y - block.x, 1.2, 0.08), "pew", false)
			_box(groups.Props, "Kneeler", Vector3(mid, 0.1, z - 0.45), Vector3(block.y - block.x, 0.12, 0.2), "pew", false)
	# El altar (tarima z 0-5 a 0.5 m, con escalones al frente).
	_box(groups.Structure, "AltarStage", Vector3(8.0, ALTAR_Y / 2, 2.5), Vector3(16.0, ALTAR_Y, 5.0), "stone")
	var ramp := _box(groups.Structure, "AltarRamp", Vector3(8.0, ALTAR_Y / 2 - 0.05, 5.6), Vector3(4.0, 0.1, 1.3), "stone", true, false)
	ramp.rotation.x = atan2(ALTAR_Y, 1.2)
	for i in 3:
		_box(groups.Structure, "AltarStep", Vector3(8.0, (i + 1) * ALTAR_Y / 6, 6.0 - i * 0.4),
			Vector3(4.0, (i + 1) * ALTAR_Y / 3, 0.4), "stone", false)
	_box(groups.Props, "Altar", Vector3(8.0, ALTAR_Y + 0.5, 2.0), Vector3(2.6, 1.0, 1.0), "stone")
	_box(groups.Props, "AltarCloth", Vector3(8.0, ALTAR_Y + 1.01, 2.0), Vector3(2.7, 0.02, 1.1), "cloth", false)
	_box(groups.Structure, "CrossV", Vector3(8.0, 4.0, 0.2), Vector3(0.3, 4.0, 0.15), "pew", false)
	_box(groups.Structure, "CrossH", Vector3(8.0, 4.8, 0.2), Vector3(2.0, 0.3, 0.15), "pew", false)
	for x in [6.9, 9.1]:
		_box(groups.Props, "Candle", Vector3(x, ALTAR_Y + 1.15, 2.0), Vector3(0.06, 0.25, 0.06), "candle", false)
		_point_light(Vector3(x, ALTAR_Y + 1.5, 2.2), Color(1.0, 0.7, 0.4), 0.8, 6.0, true)
	# San Judas Tadeo (la imagen, hecha con cajas) a un costado del altar.
	_box(groups.Props, "StatueBase", Vector3(3.0, ALTAR_Y + 0.4, 1.0), Vector3(0.8, 0.8, 0.8), "stone")
	_box(groups.Props, "Statue", Vector3(3.0, ALTAR_Y + 1.6, 1.0), Vector3(0.45, 1.6, 0.4), "church_wall", false)
	_inspect(Vector3(3.0, ALTAR_Y + 1.4, 1.6), ["San Judas Tadeo, el de las causas perdidas. Le pusieron un barbijo.",
		"A sus pies hay papelitos doblados. Pedidos. Casi todos dicen lo mismo: \"que vuelva\"."], 1.2)
	_inspect(Vector3(8.0, ALTAR_Y + 1.2, 3.0), ["El altar. Las velas están recién prendidas. No hay nadie."], 1.2)

	# Confesionario (lado este, z 12-14).
	_box(groups.Props, "Confessional", Vector3(15.0, 1.25, 13.0), Vector3(1.6, 2.5, 2.4), "pew")
	_box(groups.Props, "ConfessionalCurtain", Vector3(14.18, 1.2, 13.0), Vector3(0.04, 2.0, 0.9), "velvet" if mats.has("velvet") else "blanket", false)
	_inspect(Vector3(14.0, 1.2, 13.0), ["El confesionario. Del otro lado de la rejilla alguien respira.",
		"\"Ya sé lo que viniste a decir\", susurra. \"Lo dijiste mil veces. No es tu culpa. Repetilo.\""], 1.1)

	# Sacristía (x 11-16, z 0-5) a la derecha del altar, sobre la tarima.
	_wall("x", 5.0, 11.0, 16.0, ALTAR_Y, NAVE_H - ALTAR_Y, T, [[13.5, DOOR_W, 0.0, DOOR_H]], "church_wall", false)
	_wall("z", 11.0, 0.0, 5.0, ALTAR_Y, NAVE_H - ALTAR_Y, T, [], "church_wall", false)
	_prop("desk", Vector3(13.5, ALTAR_Y, 0.6), 180)
	_prop("chairDesk", Vector3(13.5, ALTAR_Y, 1.4), 0)
	_prop("bookcaseClosedDoors", Vector3(15.5, ALTAR_Y, 3.2), -90)
	_pickup("PriestDiary", "letter_priest_01", Vector3(13.2, ALTAR_Y + 0.8, 0.6))
	_pickup("Water", "food_water_bottle", Vector3(14.0, ALTAR_Y + 0.8, 0.6))
	_pickup("Cloth", "material_cloth", Vector3(12.0, ALTAR_Y, 4.2), 2)
	_point_light(Vector3(13.5, ALTAR_Y + 2.4, 2.5), Color(1.0, 0.8, 0.55), 0.5, 5.0, true)
	_pickup("Wood", "material_wood", Vector3(1.4, 0.0, 24.5), 2)
	_pickup("Bandage", "medicine_bandage", Vector3(15.0, 0.05, 23.0), 1)

	# La trampa de la cripta: tapada (tablas) salvo en Insane.
	var cover := _difficulty_gate("CryptCover", 2, true)
	_box(cover, "HoleCover", Vector3(8.0, -0.15, 9.25), Vector3(2.0, 0.3, 5.5), "church_floor")
	_box(cover, "Trapdoor", Vector3(8.0, 0.01, 7.5), Vector3(1.8, 0.03, 1.8), "planks", false)
	_inspect(Vector3(8.0, 0.5, 7.5), ["Una trampa en el piso, clavada. Debajo, el aire es frío y huele a flores viejas."], 1.0)
	var crypt := _difficulty_gate("Crypt", 2)
	# Rampa invisible hacia abajo (de z 8.5 a z 12, de 0 a -3), con escalones visuales.
	var stairs := _box(crypt, "CryptRamp", Vector3(8.0, CRYPT_Y / 2 - 0.05, 8.8), Vector3(1.8, 0.1, Vector2(4.4, 3.0).length()), "stone", true, false)
	stairs.rotation.x = atan2(-CRYPT_Y, 4.4)
	for i in 8:
		var h := CRYPT_Y * (i + 1) / 8.0
		_box(crypt, "CryptStep", Vector3(8.0, h + 0.1, 6.9 + i * 0.55), Vector3(1.8, 0.2, 0.55), "stone", false)
	_box(crypt, "CryptStairWallW", Vector3(6.95, -1.5, 9.25), Vector3(0.1, 3.0, 5.5), "stone")
	_box(crypt, "CryptStairWallE", Vector3(9.05, -1.5, 9.25), Vector3(0.1, 3.0, 5.5), "stone")
	# La cripta (x 3-13, z 12-20, a -3 m).
	_box(crypt, "CryptFloor", Vector3(8.0, CRYPT_Y - 0.1, 15.4), Vector3(10.0, 0.2, 9.2), "stone")
	_box(crypt, "CryptCeiling", Vector3(8.0, CRYPT_Y + 2.6, 16.0), Vector3(10.0, 0.1, 8.0), "stone", false)
	for w: Array in [[Vector3(2.95, CRYPT_Y + 1.3, 16.0), Vector3(0.1, 2.6, 8.0)], [Vector3(13.05, CRYPT_Y + 1.3, 16.0), Vector3(0.1, 2.6, 8.0)],
			[Vector3(8.0, CRYPT_Y + 1.3, 20.05), Vector3(10.0, 2.6, 0.1)], [Vector3(5.0, CRYPT_Y + 1.3, 11.95), Vector3(4.0, 2.6, 0.1)],
			[Vector3(11.0, CRYPT_Y + 1.3, 11.95), Vector3(4.0, 2.6, 0.1)]]:
		_box(crypt, "CryptWall", w[0], w[1], "stone")
	for z in [13.5, 15.5, 17.5]:
		for x in [3.6, 12.4]:
			_box(crypt, "Niche", Vector3(x, CRYPT_Y + 0.9, z), Vector3(0.9, 0.6, 1.4), "gap_dark", false)
			_box(crypt, "Coffin", Vector3(x, CRYPT_Y + 0.35, z), Vector3(0.7, 0.5, 1.8), "pew")
	_point_light(Vector3(8.0, CRYPT_Y + 2.0, 16.0), Color(0.6, 0.7, 1.0), 1.1, 9.0, true, crypt)
	for p in [Vector3(4.5, CRYPT_Y + 1.6, 13.0), Vector3(11.5, CRYPT_Y + 1.6, 18.5)]:
		_box(crypt, "CryptCandle", p + Vector3(0, -0.8, 0), Vector3(0.06, 0.25, 0.06), "candle", false)
		_point_light(p, Color(1.0, 0.65, 0.35), 0.8, 5.0, true, crypt)
	_box(crypt, "Flowers", Vector3(8.0, CRYPT_Y + 0.05, 19.4), Vector3(1.2, 0.1, 0.4), "glass_red", false)
	_pickup("ElenaLetter", "letter_elena_01", Vector3(8.0, CRYPT_Y + 0.05, 19.0), 1, crypt)
	_pickup("CryptKit", "medicine_kit", Vector3(4.4, CRYPT_Y + 0.05, 13.0), 1, crypt)
	_pickup("CryptShells", "ammo_shells", Vector3(11.6, CRYPT_Y + 0.05, 18.2), 6, crypt)
	_label3d(crypt, "TODO LO QUE GUARDAMOS", Vector3(8.0, CRYPT_Y + 1.8, 19.95), 180, Color(0.55, 0.05, 0.03), 0.008)

	# Inquieto: una mujer arrodillada en la primera fila.
	var kneel := Node3D.new()
	kneel.set_script(GatedScript)
	kneel.set("threshold", 1)
	_add(groups.Secrets, kneel, "KneelingFigure")
	_instance("res://scenes/enemies/horror_placeholder.tscn", kneel, "Figure", Vector3(4.0, 0.0, 9.4))

	# Enemigos.
	_stalker(Vector3(8.0, 0.05, 16.0), 4.0)
	_stalker(Vector3(13.0, ALTAR_Y + 0.05, 3.0), 1.5)
	_extra_enemy(Vector3(8.0, 0.05, 22.0), 1, 3.0)
	_extra_enemy(Vector3(3.0, 0.05, 6.0), 2, 2.0)
	_extra_enemy(Vector3(8.0, CRYPT_Y + 0.05, 17.0), 2, 2.0)

	_street_door("iglesia", Vector3(8.0, 1.2, 25.5), Vector3(8.0, 0, 26.0 - TE / 2 - 0.02), 180.0, 1.8, 2.9)
	return [Vector3(8.0, 1.2, 25.5), Vector3(8.0, 0.05, 23.4), &"drone"]
