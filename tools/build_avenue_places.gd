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
	for id in ["barrel_03", "Barrel_01"]:
		upgrades[id] = [id, {}]
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
	navmesh.agent_height = 2.0
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
# Pedido del usuario: "10 veces más grande". Dos plantas de 44 x 32 m (x 0-44, z 0-32),
# P1 a 3.6 m. Entrada al sur (z = 32, x = 22).
#   PB  z 22-32: denuncias | mesa de entradas (hall) | sala de espera
#       z 18-22: pasillo
#       z 8-18:  archivo | vestuarios | escalera | sala de guardia | calabozos (x 34-44, z 0-18)
#       z 0-8:   armería (cerrada) | garaje | depósito de evidencias (secreto, Difícil)
#   P1  z 22-32: oficina del comisario | investigaciones | interrogatorios (con observación)
#       z 8-18:  comedor | baños | escalera | dormitorios · brigada (x 34-44, z 0-18)
#       z 0-8:   radio | archivo de causas | oficial de servicio
# Secretos: el depósito de evidencias (Difícil) y el calabozo 3 (Insane).

const PW := 44.0
const PD := 32.0
const P1Y := 3.6         # piso de la planta alta
const CELL_X := 37.5     # frente de los calabozos
const STAIR_X := 22.0


## Rejas de un calabozo a lo largo de Z (en x fijo), con hueco de puerta en `door_z`.
func _cell_bars_x(x: float, z0: float, z1: float, door_z: float, door_open: bool, parent: Node = null) -> void:
	var holder: Node = parent if parent else groups.Structure
	var z := z0 + 0.12
	while z < z1:
		if not (absf(z - door_z) < 0.55 and door_open):
			_box(holder, "Bar", Vector3(x, PC / 2, z), Vector3(0.05, PC, 0.05), "bars", false)
		z += 0.2
	_box(holder, "BarRail", Vector3(x, 2.2, (z0 + z1) / 2), Vector3(0.06, 0.06, z1 - z0), "bars", false)
	if door_open:
		_box(holder, "BarsCollider", Vector3(x, PC / 2, (z0 + door_z - 0.55) / 2), Vector3(0.15, PC, door_z - 0.55 - z0), "bars", true, false)
		_box(holder, "BarsCollider", Vector3(x, PC / 2, (door_z + 0.55 + z1) / 2), Vector3(0.15, PC, z1 - door_z - 0.55), "bars", true, false)
	else:
		_box(holder, "BarsCollider", Vector3(x, PC / 2, (z0 + z1) / 2), Vector3(0.15, PC, z1 - z0), "bars", true, false)


func _police_station() -> Array:
	_environment()
	_police_structure()
	_police_stairs()
	_police_ground_rooms()
	_police_cells()
	_police_upper_rooms()
	_police_secrets()
	_police_enemies()
	_street_door("comisaria", Vector3(STAIR_X, 1.2, PD - 0.5), Vector3(STAIR_X, 0, PD - TE / 2 - 0.02), 180.0, 1.6, 2.6)
	return [Vector3(STAIR_X, 1.2, PD - 0.5), Vector3(STAIR_X, 0.05, PD - 2.6), &"hospital"]


func _police_structure() -> void:
	var y2 := P1Y + PC
	# Pisos: PB entero; P1 con el hueco de la escalera (x 20.8-23.2, z 12-18).
	# Pisos de PB sin superponerse (el de los calabozos y el del garaje son otro material).
	for r in [[0, 0, 12, PD, "police_floor"], [12, 0, 24, 8, "cell_floor"], [12, 8, 24, PD, "police_floor"],
			[24, 0, 34, PD, "police_floor"], [34, 0, PW, 18, "cell_floor"], [34, 18, PW, PD, "police_floor"]]:
		_floor(r[0], r[1], r[2], r[3], 0.0, r[4])
	for s in [[0, 0, PW, 12], [0, 18, PW, PD], [0, 12, 20.8, 18], [23.2, 12, PW, 18]]:
		_box(groups.Structure, "Slab", Vector3((s[0] + s[2]) / 2.0, P1Y - 0.175, (s[1] + s[3]) / 2.0),
			Vector3(s[2] - s[0], 0.15, s[3] - s[1]), "concrete")
		_ceiling(s[0], s[1], s[2], s[3], PC)
		_floor(s[0], s[1], s[2], s[3], P1Y, "police_floor")
	_ceiling(0, 0, PW, PD, y2)
	_box(groups.Structure, "Roof", Vector3(PW / 2, y2 + 0.3, PD / 2), Vector3(PW, 0.4, PD), "concrete", false)
	# Paredes exteriores con ventanas enrejadas en los dos pisos (la de la calle, con la entrada).
	var win := []
	for x in [6.0, 38.0]:
		win.append(_window(x))
	for x in [5.0, 13.0, 31.0, 39.0]:
		win.append(_window(x, P1Y))
	_wall("x", PD, -TE / 2, PW + TE / 2, 0.0, y2, TE, [[STAIR_X, 1.8, 0.0, 2.6]] + win, "police_wall", true)
	_wall("x", 0.0, -TE / 2, PW + TE / 2, 0.0, y2, TE, [_window(6.0, P1Y), _window(18.0, P1Y)], "police_wall", true)
	_wall("z", 0.0, 0.0, PD, 0.0, y2, TE, [_window(26.0), _window(13.0, P1Y), _window(27.0, P1Y)], "police_wall", true)
	_wall("z", PW, 0.0, PD, 0.0, y2, TE, [_window(27.0), _window(27.0, P1Y), _window(5.0, P1Y)], "police_wall", true)
	for w in [[6.0, 1.65, PD + 0.4], [38.0, 1.65, PD + 0.4]]:
		_box(groups.Structure, "FogWindow", Vector3(w[0], w[1], w[2]), Vector3(1.9, 1.3, 0.05), "lamp_off", false)
	# PB: pasillo (z 18-22) y filas.
	_wall("x", 22.0, 0.0, PW, 0.0, PC, T, [_door(7.0), [STAIR_X, 8.0, 0.0, 2.8], _door(37.0)], "police_wall", false)
	_wall("x", 18.0, 0.0, PW, 0.0, PC, T, [_door(6.0), _door(16.0), _door(STAIR_X), _door(29.0), _door(35.6)], "police_wall", false)
	for x in [14.0, 30.0]:
		_wall("z", x, 22.0, PD, 0.0, PC, T, [], "police_wall", false)
	for x in [12.0, 19.0, 25.0]:
		_wall("z", x, 8.0, 18.0, 0.0, PC, T, [], "police_wall", false)
	_wall("z", 34.0, 0.0, 18.0, 0.0, PC, T, [], "police_wall", false)
	_wall("x", 8.0, 0.0, 24.0, 0.0, PC, T, [_door(6.0), _door(16.0)], "police_wall", false)
	for x in [12.0, 24.0]:
		_wall("z", x, 0.0, 8.0, 0.0, PC, T, [], "police_wall", false)
	# P1.
	_wall("x", 22.0, 0.0, PW, P1Y, PC, T, [_door(7.0), _door(22.0), _door(32.5), _door(39.0)], "police_wall", false)
	_wall("x", 18.0, 0.0, PW, P1Y, PC, T, [_door(6.0), _door(16.0), _door(19.95), _door(29.0), _door(39.0)], "police_wall", false)
	for x in [14.0, 30.0, 35.0]:
		_wall("z", x, 22.0, PD, P1Y, PC, T, [[27.0, 2.2, 1.0, 2.0]] if x == 35.0 else [], "police_wall", false)
	for x in [12.0, 19.0, 25.0, 34.0]:
		_wall("z", x, 0.0 if x == 34.0 else 8.0, 18.0, P1Y, PC, T, [], "police_wall", false)
	_wall("x", 8.0, 0.0, 34.0, P1Y, PC, T, [_door(6.0), _door(22.0), _door(29.0)], "police_wall", false)
	for x in [12.0, 24.0]:
		_wall("z", x, 0.0, 8.0, P1Y, PC, T, [], "police_wall", false)
	# El vidrio espejado de la sala de interrogatorios (visto desde la observación, es oscuro).
	_box(groups.Structure, "OneWayGlass", Vector3(35.0, P1Y + 1.5, 27.0), Vector3(0.04, 1.0, 2.2), "gap_dark")
	# Carteles.
	# El pasillo (z 18-22) queda al norte de la pared 22 y al sur de la 18; los de la pared 8 se leen desde el sur.
	for s: Array in [["DENUNCIAS", 7.0, 22.0], ["ESPERA", 37.0, 22.0], ["ARCHIVO", 6.0, 18.0], ["VESTUARIOS", 16.0, 18.0],
			["ESCALERA", STAIR_X, 18.0], ["GUARDIA", 29.0, 18.0], ["CALABOZOS", 35.6, 18.0], ["ARMERÍA", 6.0, 8.0], ["GARAJE", 16.0, 8.0]]:
		var south: bool = s[2] != 22.0
		_room_sign(s[0], s[1], s[2] + (T / 2 if south else -T / 2), 0.0, south)
	for s: Array in [["COMISARIO", 7.0, 22.0], ["INVESTIGACIONES", 22.0, 22.0], ["OBSERVACIÓN", 32.5, 22.0],
			["INTERROGATORIO", 39.0, 22.0], ["COMEDOR", 6.0, 18.0], ["BAÑOS", 16.0, 18.0], ["ESCALERA", 19.95, 18.0],
			["DORMITORIOS", 29.0, 18.0], ["BRIGADA", 39.0, 18.0], ["RADIO", 6.0, 8.0], ["CAUSAS", 22.0, 8.0],
			["OFICIAL DE SERVICIO", 29.0, 8.0]]:
		var south: bool = s[2] != 22.0
		_room_sign(s[0], s[1], s[2] + (T / 2 if south else -T / 2), P1Y, south)
	_room_sign("COMISARÍA 12", STAIR_X, 22.0 + T / 2, 0.0, true, 2.95)
	# Luces: tubos, la mitad muertos.
	var modes := ["on", "flicker", "off", "on", "flicker", "off", "off"]
	var i := 0
	for level in [0, 1]:
		var y0: float = 0.0 if level == 0 else P1Y
		for p in [Vector2(7, 27), Vector2(22, 27), Vector2(37, 27), Vector2(6, 20), Vector2(17, 20), Vector2(28, 20), Vector2(39, 20),
				Vector2(6, 13), Vector2(16, 13), Vector2(29.5, 13), Vector2(39, 9), Vector2(6, 4), Vector2(18, 4), Vector2(29, 4)]:
			_police_light(p.x, p.y, y0, modes[i % modes.size()])
			i += 1


## Tubo de techo a la altura de cada planta de la comisaría.
func _police_light(x: float, z: float, y0: float, mode: String) -> void:
	_prop("mounted_fluorescent_lights", Vector3(x, y0 + PC, z), 90, {"parent": groups.Lights})
	if mode == "off":
		return
	var light := OmniLight3D.new()
	if mode == "flicker":
		light.set_script(FlickerScript)
	light.light_color = Color(0.82, 0.92, 0.95)
	light.light_energy = 0.7
	light.omni_range = 7.0
	light.omni_attenuation = 1.3
	light.position = Vector3(x, y0 + PC - 0.3, z)
	_add(groups.Lights, light, "Light")


## Escalera recta de PB a P1 (x 20.8-23.2): se entra desde el pasillo y se llega al
## descanso de arriba (z 8-12); se sale al pasillo de P1 por la puerta de x 19.95.
func _police_stairs() -> void:
	var steps := 18
	var rise := P1Y / steps
	var run := 0.31
	var z_start := 17.7
	for i in steps:
		var top := (i + 1) * rise
		_box(groups.Structure, "Step", Vector3(STAIR_X, top / 2, z_start - (i + 0.5) * run), Vector3(2.4, top, run), "concrete", false)
	var length := Vector2(steps * run, P1Y).length()
	var ramp := _box(groups.Structure, "StairRamp", Vector3(STAIR_X, P1Y / 2 + 0.03, z_start - steps * run / 2),
		Vector3(2.4, 0.1, length + 0.3), "concrete", true, false)
	ramp.rotation.x = atan2(P1Y, steps * run)
	for x in [20.75, 23.25]:
		_box(groups.Structure, "StairSide", Vector3(x, P1Y / 2, z_start - steps * run / 2), Vector3(0.08, P1Y, steps * run),
			"concrete", true, false)
		_box(groups.Structure, "Rail", Vector3(x, P1Y + 0.5, 15.0), Vector3(0.08, 1.0, 6.0), "bars")
		_box(groups.Structure, "RailTop", Vector3(x, P1Y + 1.0, 15.0), Vector3(0.12, 0.05, 6.0), "metal")
	_box(groups.Structure, "RailEnd", Vector3(STAIR_X, P1Y + 0.5, 17.95), Vector3(2.5, 1.0, 0.08), "bars")
	var link := NavigationLink3D.new()
	link.bidirectional = true
	link.start_position = Vector3(STAIR_X, 0.0, 18.7)
	link.end_position = Vector3(STAIR_X, P1Y, 10.5)
	_add(scene_root, link, "StairLink")


func _police_ground_rooms() -> void:
	# Mesa de entradas (x 14-30, z 22-32): mostrador, bancos, carteles de búsqueda.
	_counter(17.5, 26.5, 25.6, 0.0)
	_prop("computerScreen", Vector3(19.0, 1.05, 25.6), 180)
	_prop("chairDesk", Vector3(20.5, 0, 24.8), 0)
	for x in [15.4, 16.9, 27.1, 28.6]:
		_prop("bench", Vector3(x, 0, 31.4), 180)
	_prop("pottedPlant", Vector3(14.6, 0, 22.6), 0, {"tint": Color(0.4, 0.38, 0.3)})
	_prop("water_cooler", Vector3(29.4, 0, 22.6), -90)
	for i in 4:
		_box(groups.Structure, "Poster", Vector3(14.17, 1.6, 26.2 + i * 0.75), Vector3(0.02, 0.6, 0.45), "paper", false)
	_label3d(groups.Structure, "SE BUSCA", Vector3(14.19, 2.0, 27.3), 90, Color(0.2, 0.15, 0.1), 0.006)
	_pickup("PoliceLog", "letter_police_02", Vector3(24.2, 1.07, 25.6))
	_inspect(Vector3(14.4, 1.5, 27.3), ["Carteles de \"se busca\". Las caras están todas raspadas con algo filoso.",
		"En uno, debajo de la raspadura, se lee: \"Ibáñez\"."], 1.2)
	# Denuncias (x 0-14): escritorios y la máquina de escribir.
	for x in [3.5, 10.0]:
		_prop("desk", Vector3(x, 0, 26.0), 0)
		_prop("chairDesk", Vector3(x, 0, 25.2), 180)
		_prop("chair", Vector3(x, 0, 27.0))
	_prop("file_cabinet", Vector3(0.45, 0, 30.5), 90)
	_inspect(Vector3(3.5, 1.0, 26.0), ["Una denuncia a medio tipear: \"La señora refiere que su hijo salió a la niebla y volvió con la voz cambiada\".",
		"El oficial dejó de escribir en la mitad de una palabra."], 1.1)
	# Sala de espera (x 30-44): sillas en fila, una tele apagada.
	for i in 6:
		_prop("chairModernCushion", Vector3(32.0 + i * 1.0, 0, 30.8), 180)
	_prop("televisionModern", Vector3(43.85, 1.6, 27.0), -90)
	_prop("vending_machine", Vector3(43.3, 0, 23.0), -90)
	_pickup("Chocolate", "food_chocolate_bar", Vector3(42.6, 0.05, 23.0))
	# Archivo (x 0-12, z 8-18): laberinto de archiveros.
	for row in 3:
		for k in 4:
			_prop("file_cabinet", Vector3(1.5 + k * 2.6, 0, 10.0 + row * 2.8), 0 if row % 2 == 0 else 180)
	_prop("cardboardBoxOpen", Vector3(11.0, 0, 17.2), 30)
	_inspect(Vector3(6.4, 1.0, 12.6), ["Expedientes de 1979. Un cajón entero con la misma etiqueta: \"Imperio\"."], 1.2)
	# Vestuarios (x 12-19): lockers y bancos.
	for z in [9.0, 10.0, 11.0, 12.0, 13.0, 14.0]:
		_prop("locker", Vector3(12.45, 0, z), 90)
	_prop("bench", Vector3(16.0, 0, 12.0), 90)
	_pickup("Cloth", "material_cloth", Vector3(18.3, 0.0, 9.0), 2)
	# Sala de guardia (x 25-34): mesa, café, el locker de Sosa.
	for z in [9.0, 10.0, 11.0]:
		_prop("locker", Vector3(25.45, 0, z), 90)
	_prop("table", Vector3(29.5, 0, 13.0), 0)
	for p in [[Vector3(29.5, 0, 13.9), 180], [Vector3(29.5, 0, 12.1), 0], [Vector3(28.6, 0, 13.0), 90]]:
		_prop("chair", p[0], p[1])
	_prop("kitchenCabinet", Vector3(33.5, 0, 9.0), -90)
	_prop("kitchenCoffeeMachine", Vector3(33.5, 0.95, 9.0), -90)
	_pickup("Bandage", "medicine_bandage", Vector3(29.5, 0.8, 13.0), 1)
	_inspect(Vector3(25.8, 1.2, 10.0), ["Lockers de los agentes. El de \"Sosa, R.\" está abierto y vacío. Adentro, una foto de una mujer cantando."], 1.0)
	# Armería (x 0-12, z 0-8): cerrada desde siempre.
	_door_prop(groups.Structure, "ArmoryDoor", "door_chained", Vector3(6.0, 0, 8.0 + T / 2 + 0.02), 180.0, DOOR_W, DOOR_H)
	_box(groups.Structure, "ArmoryLock", Vector3(6.0, DOOR_H / 2, 8.0), Vector3(DOOR_W, DOOR_H, 0.15), "concrete", true, false)
	_inspect(Vector3(6.0, 1.2, 8.8), ["La armería. Cadena, candado y un cartel escrito a mano: \"NO DARLES ARMAS A LOS QUE OYEN\"."], 1.2)
	# Garaje (x 12-24, z 0-8): un patrullero, bidones, herramientas.
	var car: Node3D = PropScript.new()
	car.set("model", load("res://assets/models/props/cars/police.glb"))
	car.set("model_scale", 1.5)
	car.set("tint", Color(0.7, 0.7, 0.72))
	car.position = Vector3(18.0, 0, 3.6)
	car.rotation_degrees.y = 90.0
	_add(groups.Props, car, "PoliceCar")
	for p in [Vector3(12.8, 0, 0.8), Vector3(13.6, 0, 0.7)]:
		_prop("barrel_03", p, randf_range(0, 360), {"h": 1.0})
	_prop("bookcaseOpenLow", Vector3(23.4, 0, 6.6), -90)
	_pickup("Metal", "material_metal", Vector3(22.8, 0, 1.2), 2)
	_pickup("Cable", "material_cable", Vector3(23.4, 0.9, 6.6), 2)
	_point_light(Vector3(18.0, 2.8, 4.0), Color(0.85, 0.9, 1.0), 0.6, 8.0, true)
	_inspect(Vector3(18.0, 1.0, 5.4), ["Un patrullero con el motor abierto. Le sacaron la batería y la radio.",
		"En el asiento de atrás hay marcas de uñas en el tapizado, de adentro hacia afuera."], 1.6)


## Los calabozos (x 34-44, z 0-18): pasillo al oeste, seis celdas de 3 m.
func _police_cells() -> void:
	for k in 6:
		var z0 := 15.0 - k * 3.0
		if k < 5:
			_wall("x", z0, CELL_X, PW, 0.0, PC, 0.15, [], "police_wall", false)
		var number := k + 1
		if number == 5:
			_flaco_cell(z0)
		elif number != 3:
			_cell_bars_x(CELL_X, z0, z0 + 3.0, z0 + 1.5, number != 2)
		_prop("bench", Vector3(43.2, 0, z0 + 1.5), -90, {"tint": Color(0.5, 0.5, 0.5)})
		_label3d(groups.Structure, str(number), Vector3(CELL_X - 0.08, 2.6, z0 + 1.5), -90, Color(0.8, 0.8, 0.75), 0.01)
	_box(groups.Props, "PocketWatch", Vector3(40.5, 0.02, 13.5), Vector3(0.08, 0.02, 0.08), "gold2", false)
	_inspect(Vector3(CELL_X - 0.6, 1.0, 13.5), ["El calabozo 2, el del relojero. La reja tiene el candado puesto.",
		"En el piso, un reloj de bolsillo parado a las tres y cuarto."], 1.2)
	_inspect(Vector3(CELL_X - 0.6, 1.0, 10.5), ["El calabozo 3 está cerrado. Adentro, alguien raspó la pared con las uñas hasta los ladrillos."], 1.2)
	_prop("desk", Vector3(35.6, 0, 1.2), 90)
	_prop("chairDesk", Vector3(36.4, 0, 1.2), -90)
	_pickup("Water", "food_water_bottle", Vector3(41.0, 0.05, 1.0))
	_prop("blood", Vector3(41.0, 0.01, 7.4), 40)


func _police_upper_rooms() -> void:
	var y := P1Y
	# Oficina del comisario (x 0-14, z 22-32).
	_prop("rugRectangle", Vector3(7.0, y + 0.005, 27.0))
	_prop("desk", Vector3(7.0, y, 30.0), 0)
	_prop("chairDesk", Vector3(7.0, y, 30.9), 180)
	_prop("chair", Vector3(7.0, y, 28.9))
	_prop("file_cabinet", Vector3(0.45, y, 24.0), 90)
	_prop("file_cabinet", Vector3(0.45, y, 25.0), 90)
	_prop("bookcaseClosedWide", Vector3(13.55, y, 27.0), -90)
	_prop("wall_clock", Vector3(7.0, y + 2.3, 31.83), 180)
	_pickup("Ammo1", "ammo_9mm", Vector3(6.4, y + 0.8, 30.0), 8)
	_inspect(Vector3(7.0, y + 1.0, 29.8), ["El escritorio del comisario. Un expediente: \"Desaparición Elena M. de Sosa, 1979. Archivado\".",
		"Alguien lo desarchivó hace poco. Las hojas están húmedas."], 1.1)
	# Investigaciones (x 14-30): escritorios y el pizarrón del caso.
	for p in [Vector3(17.0, y, 25.0), Vector3(17.0, y, 29.0), Vector3(27.0, y, 25.0)]:
		_prop("desk", p, 0)
		_prop("chairDesk", p + Vector3(0, 0, 0.9), 180)
	_box(groups.Props, "CaseBoard", Vector3(22.0, y + 1.6, 31.82), Vector3(4.0, 1.6, 0.04), "cork")
	for k in 9:
		_box(groups.Props, "CasePhoto", Vector3(20.4 + (k % 3) * 1.6, y + 1.1 + (k / 3) * 0.5, 31.75), Vector3(0.35, 0.28, 0.01), "paper", false)
	_box(groups.Props, "RedString", Vector3(22.0, y + 1.6, 31.77), Vector3(3.4, 0.02, 0.01), "glass_red", false)
	_inspect(Vector3(22.0, y + 1.4, 31.2), ["El pizarrón del caso. En el centro, la foto de la soprano Elena M. de Sosa. Hilos rojos hacia todos lados:",
		"el Teatro Imperio, el relojero Kaufmann, la parroquia, el San Judas. Y una foto nueva, de esta semana: el agente Sosa.",
		"Alguien escribió con marcador: \"SE LO LLEVÓ LA MISMA CANCIÓN\"."], 1.5)
	# Observación e interrogatorios (x 30-44).
	_prop("chair", Vector3(32.5, y, 27.0), -90)
	_prop("table", Vector3(39.5, y, 27.0), 0)
	_prop("chair", Vector3(39.5, y, 28.0), 180)
	_prop("chair", Vector3(39.5, y, 26.0), 0)
	_point_light(Vector3(39.5, y + 2.6, 27.0), Color(1.0, 0.9, 0.7), 0.8, 5.0, true)
	_inspect(Vector3(33.6, y + 1.4, 27.0), ["Del otro lado del vidrio espejado hay una mesa y dos sillas. En una, alguien sentado de espaldas.",
		"Parpadeás y la silla está vacía. La grabadora de la mesa sigue andando."], 1.2)
	_pickup("Water2", "food_water_bottle", Vector3(40.2, y + 0.8, 27.0))
	# Comedor (x 0-12, z 8-18).
	_prop("table", Vector3(6.0, y, 12.0))
	for p in [[Vector3(6.0, y, 12.9), 180], [Vector3(6.0, y, 11.1), 0]]:
		_prop("chair", p[0], p[1])
	_prop("kitchenCabinet", Vector3(0.45, y, 9.5), 90)
	_prop("kitchenSink", Vector3(0.45, y, 10.4), 90)
	_prop("kitchenFridge", Vector3(0.5, y, 11.5), 90)
	_pickup("Peaches", "food_canned_peaches", Vector3(6.0, y + 0.8, 12.0))
	# Baños (x 12-19).
	for z in [9.5, 11.0, 12.5]:
		_prop("bathroomSink", Vector3(18.55, y, z), -90)
	for x in [13.0, 14.6]:
		_prop("toilet", Vector3(x, y, 17.3), 180)
	# Dormitorios de guardia (x 25-34): cuchetas.
	for x in [26.5, 29.5, 32.5]:
		_prop("bedSingle", Vector3(x, y, 9.4), 0)
		_box(groups.Props, "UpperBunk", Vector3(x, y + 1.3, 9.4), Vector3(0.95, 0.12, 2.0), "mattress", false)
	_pickup("Wood", "material_wood", Vector3(33.4, y, 16.8), 2)
	# Brigada (x 34-44, z 0-18): la oficina de Sosa.
	_prop("desk", Vector3(39.0, y, 2.0), 180)
	_prop("chairDesk", Vector3(39.0, y, 2.9), 0)
	_prop("bookcaseClosedDoors", Vector3(43.55, y, 9.0), -90)
	_prop("file_cabinet", Vector3(34.6, y, 1.0), 90)
	_inspect(Vector3(39.0, y + 1.0, 2.2), ["El escritorio del agente Sosa. Un mapa de la avenida con la pensión marcada y el teatro tachado tres veces.",
		"En un post-it: \"Mamá. Fila 7, butaca 13. Ir solo.\""], 1.1)
	_pickup("Shells", "ammo_shells", Vector3(38.4, y + 0.8, 2.0), 4)
	# Radio (x 0-12, z 0-8), causas (12-24) y oficial de servicio (24-34).
	_prop("desk", Vector3(6.0, y, 0.7), 180)
	_prop("radio", Vector3(6.0, y + 0.76, 0.7), 180)
	_prop("chairDesk", Vector3(6.0, y, 1.6), 0)
	_inspect(Vector3(6.0, y + 1.0, 1.0), ["La radio de la comisaría, en la frecuencia de emergencias. Entre la estática, una voz de mujer canta muy bajito."], 1.1)
	for x in [13.5, 15.5, 17.5, 19.5, 21.5]:
		_prop("bookcaseOpen", Vector3(x, y, 0.4), 0)
	for p in [Vector3(14.5, y, 6.5), Vector3(19.0, y, 6.8)]:
		_prop("cardboardBoxClosed", p, randf_range(-30, 30))
	_prop("desk", Vector3(29.0, y, 0.8), 180)
	# La llave de los calabozos: la tenía el oficial de servicio (el Flaco lo sabe).
	_pickup("KeyCells", "key_cells", Vector3(28.6, y + 0.78, 0.7))
	_prop("chairDesk", Vector3(29.0, y, 1.7), 0)
	_prop("first_aid_kit", Vector3(33.8, y + 1.5, 4.0), -90)


func _police_secrets() -> void:
	# Difícil: el depósito de evidencias (x 24-34, z 0-8) estaba tapiado detrás de la guardia.
	var lying := _difficulty_gate("EvidenceWall", 1, true)
	var wall: StaticBody3D = GreyBoxScript.new()
	wall.set("size", Vector3(DOOR_W - 0.16, DOOR_H - 0.08, T + 0.04))
	wall.set("material", mats.police_wall)
	wall.position = Vector3(29.0, (DOOR_H - 0.08) / 2, 8.0)
	_add(lying, wall, "Wall")
	_wall("x", 8.0, 24.0, 34.0, 0.0, PC, T, [[29.0, DOOR_W, 0.0, DOOR_H]], "police_wall", false)
	var room := _difficulty_gate("Evidence", 1)
	for x in [24.6, 33.4]:
		for z in [1.5, 4.5]:
			_prop("bookcaseOpen", Vector3(x, 0, z), 90 if x < 29.0 else -90, {"parent": room})
	for p in [Vector3(27.5, 0, 0.7), Vector3(30.5, 0, 0.8), Vector3(29.0, 0, 3.0)]:
		_prop("cardboardBoxClosed", p, randf_range(-10, 10), {"parent": room, "h": 0.5})
	_point_light(Vector3(29.0, 2.6, 4.0), Color(0.85, 0.9, 1.0), 0.6, 6.0, true, room)
	_pickup("EvidenceShells", "ammo_shells", Vector3(24.6, 1.0, 1.5), 6, room)
	_pickup("EvidenceAmmo", "ammo_9mm", Vector3(33.4, 1.0, 4.5), 12, room)
	_pickup("EvidenceKit", "medicine_kit", Vector3(29.0, 0.55, 3.0), 1, room)
	_inspect(Vector3(29.0, 1.0, 3.8), ["El depósito de evidencias. Bolsas con etiquetas: \"Imperio 1979\", \"Imperio 1979\", \"Imperio 1979\".",
		"Alguien tapió la puerta con durlock y lo pintó del mismo color que la pared."], 1.2, room)
	# Insane: el calabozo 3 se abre y adentro hay algo para vos.
	var cell := _difficulty_gate("Cell3Open", 2)
	_pickup("Cell3Kit", "medicine_kit", Vector3(42.4, 0.05, 10.0), 1, cell)
	_pickup("Cell3Shells", "ammo_shells", Vector3(41.0, 0.05, 11.2), 4, cell)
	_label3d(cell, "ACÁ ESTUVO\nTU MADRE", Vector3(PW - 0.17, 1.7, 10.5), -90, Color(0.55, 0.05, 0.03), 0.007)
	_cell_bars_x(CELL_X, 9.0, 12.0, 10.5, true, cell)
	var cell_bars := _difficulty_gate("Cell3Bars", 2, true)
	_cell_bars_x(CELL_X, 9.0, 12.0, 10.5, false, cell_bars)
	_box(cell_bars, "Cell3Padlock", Vector3(CELL_X - 0.08, 1.1, 10.5), Vector3(0.06, 0.14, 0.1), "metal", false)


func _police_enemies() -> void:
	_stalker(Vector3(35.7, 0.05, 9.0), 2.5)
	_stalker(Vector3(6.0, 0.05, 13.0), 2.0)
	_stalker(Vector3(22.0, P1Y + 0.05, 20.0), 6.0)
	_stalker(Vector3(29.5, P1Y + 0.05, 13.0), 2.0)
	_instance("res://scenes/enemies/spitter.tscn", groups.Enemies, "Spitter", Vector3(22.0, P1Y + 0.05, 26.5), {"wander_radius": 2.0})
	_extra_enemy(Vector3(22.0, 0.05, 20.0), 1, 5.0)
	_extra_enemy(Vector3(16.0, 0.05, 4.0), 1, 2.0)
	_extra_enemy(Vector3(7.0, P1Y + 0.05, 26.0), 2, 2.0)
	_extra_enemy(Vector3(39.0, P1Y + 0.05, 8.0), 2, 2.0)
	_extra_enemy(Vector3(37.0, 0.05, 27.0), 2, 2.0)


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
	_box(groups.Props, "AltarCloth", Vector3(8.0, ALTAR_Y + 1.03, 2.0), Vector3(2.7, 0.02, 1.1), "cloth", false)
	_box(groups.Structure, "CrossV", Vector3(8.0, 4.0, 0.2), Vector3(0.3, 4.0, 0.15), "pew", false)
	_box(groups.Structure, "CrossH", Vector3(8.0, 4.8, 0.2), Vector3(2.0, 0.3, 0.1), "pew", false)
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
	_box(cover, "Trapdoor", Vector3(8.0, 0.03, 7.5), Vector3(1.8, 0.03, 1.8), "planks", false)
	_inspect(Vector3(8.0, 0.5, 7.5), ["Una trampa en el piso, clavada. Debajo, el aire es frío y huele a flores viejas."], 1.0)
	var crypt := _difficulty_gate("Crypt", 2)
	# Rampa invisible hacia abajo (de z 8.5 a z 12, de 0 a -3), con escalones visuales.
	var stairs := _box(crypt, "CryptRamp", Vector3(8.0, CRYPT_Y / 2 - 0.05, 8.8), Vector3(1.8, 0.1, Vector2(4.4, 3.0).length()), "stone", true, false)
	stairs.rotation.x = atan2(-CRYPT_Y, 4.4)
	for i in 8:
		var h := CRYPT_Y * (i + 1) / 8.0
		_box(crypt, "CryptStep", Vector3(8.0, h + 0.1, 6.9 + i * 0.55), Vector3(1.8, 0.2, 0.55), "stone", false)
	_box(crypt, "CryptStairWallW", Vector3(6.95, -1.65, 9.2), Vector3(0.1, 2.7, 5.4), "stone")
	_box(crypt, "CryptStairWallE", Vector3(9.05, -1.65, 9.2), Vector3(0.1, 2.7, 5.4), "stone")
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


# --- El Flaco (pedido del usuario: el tranza del barrio, preso en el calabozo 5) ------

## El calabozo 5 (z0..z0+3): cerrado con llave, con el Flaco adentro. La reja va en un FlagGate
## (`flaco_freed`) y la cerradura es un KeyLock que se abre con la llave de los calabozos.
func _flaco_cell(z0: float) -> void:
	var gate := Node3D.new()
	gate.set_script(load("res://scripts/world/flag_gate.gd"))
	gate.set("flag", &"flaco_freed")
	gate.set("locked_text", "")
	gate.set("radius", 0.01)
	_add(groups.Structure, gate, "FlacoCellBars")
	_cell_bars_x(CELL_X, z0, z0 + 3.0, z0 + 1.5, false, gate)
	var lock := Area3D.new()
	lock.set_script(load("res://scripts/world/key_lock.gd"))
	lock.set("required_item", load("res://assets/items/key_cells.tres"))
	lock.set("unlock_flag", &"flaco_freed")
	lock.set("locked_texts", PackedStringArray([
		"—¡Eh! ¡Pibe! ¿Sos vos? —Es el Flaco, el del pasaje. Está flaco de verdad ahora, con los ojos hundidos y la ropa colgando.",
		"—Me trajeron el día dos, por las dudas, dijeron. Después los canas se fueron y no volvió nadie. Hace días que no como.",
		"—Las llaves las tenía el oficial de servicio. Arriba, en su escritorio. Dale, pibe, sacame de acá.",
		"—Ya sé. Yo te vendía. No te voy a pedir que me perdones. Te pido que no me dejes acá adentro con esa cosa respirando en el calabozo de al lado.",
	]))
	lock.set("unlock_text", "La llave gira. El Flaco sale despacio, como si la reja todavía estuviera ahí. —Gracias, pibe. En serio. Me vuelvo al pasaje, a mi rincón. Pasá cuando quieras: te debo una.")
	lock.set("radius", 1.4)
	lock.position = Vector3(CELL_X - 0.4, 1.1, z0 + 1.5)
	_add(groups.Inspectables, lock, "FlacoCellLock")
	_npc("Flaco", "flaco", Vector3(42.4, 0.05, z0 + 1.5), -90.0, {
		"hidden_flag": &"flaco_freed",
		"talk_radius": 0.6,
	})
	_box(groups.Props, "FlacoBlanket", Vector3(43.3, 0.03, z0 + 1.0), Vector3(1.0, 0.04, 1.6), "cloth", false)
	# Un foco pelado que todavía anda: para que se lo vea desde la reja.
	var bulb := OmniLight3D.new()
	bulb.set_script(FlickerScript)
	bulb.light_color = Color(1.0, 0.85, 0.6)
	bulb.light_energy = 0.6
	bulb.omni_range = 4.0
	bulb.position = Vector3(41.2, 2.5, z0 + 1.5)
	_add(groups.Lights, bulb, "FlacoBulb")
