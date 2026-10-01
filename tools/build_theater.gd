extends "res://tools/build_hospital.gd"
## Genera res://scenes/levels/theater.tscn: el Teatro Imperio, zona 3 (GDD:
## "teatro"). Vestíbulo, sala con butacas, escenario con el jefe, bambalinas y el
## camarín principal, que es un segundo lugar para vivir (refugio "theater").
## Reusa los helpers del generador del hospital. Andamio de una sola pasada.
## Uso: <godot> --headless --path . -s res://tools/build_theater.gd
##
## Planta (x = este, z = sur):
##   Vestíbulo    x 0-14,  z 0-14   (entrada desde la avenida en x = 0; boletería y guardarropa)
##   Sala         x 14-33, z -2-16  (butacas, pasillos laterales y central)
##   Escenario    x 33-42, z -2-16  (a 1.1 m; rampas a los costados; el jefe)
##   Bambalinas   x 42-54, z -2-16  (a 1.1 m: pasillo, camarín, depósito, camarín principal)

const OUT := "res://scenes/levels/theater.tscn"
const THEATER_MAT_DIR := "res://assets/materials/theater/"
const S := 1.1          # alto del escenario y de las bambalinas
const HALL_H := 9.0     # alto de la sala
const FOYER_H := 5.0
const BACK_H := 3.4     # alto de las bambalinas sobre el escenario
const REFUGE := &"theater"


func _initialize() -> void:
	GreyBoxScript = load("res://scripts/world/grey_box.gd")
	PropScript = load("res://scripts/world/prop.gd")
	InspectableScript = load("res://scripts/world/inspectable.gd")
	FlickerScript = load("res://scripts/world/flicker_light.gd")
	GatedScript = load("res://scripts/world/sanity_gated.gd")
	RefugeScript = load("res://scripts/world/refuge_zone.gd")
	seed(1979)
	_make_materials()
	scene_root = Node3D.new()
	scene_root.name = "Theater"
	for g in ["Structure", "Lights", "Props", "Refuge", "Items", "Inspectables", "Secrets", "Enemies"]:
		groups[g] = _add(scene_root, Node3D.new(), g)
	groups.Structure.add_to_group(&"nav_source", true)
	groups.Props.add_to_group(&"nav_source", true)

	_theater_environment()
	_foyer()
	_hall()
	_stage()
	_backstage()
	_camarin_refuge()
	_secrets_theater()
	_places()
	_theater_enemies()
	_theater_systems()

	var packed := PackedScene.new()
	packed.pack(scene_root)
	var err := ResourceSaver.save(packed, OUT)
	print("Guardado %s (%s), nodos: %d" % [OUT, error_string(err), _count(scene_root)])
	scene_root.free()
	quit()


func _make_materials() -> void:
	super._make_materials()
	DirAccess.make_dir_recursive_absolute(THEATER_MAT_DIR)
	var shader: Shader = load("res://shaders/ps1_spatial.gdshader")
	var defs := {
		"carpet": ["floor_tiles_dirty", Color(0.45, 0.1, 0.09), 0.6],
		"velvet": ["wall_plaster", Color(0.5, 0.08, 0.07), 1.5],
		"theater_wall": ["wall_plaster", Color(0.55, 0.42, 0.35), 0.9],
		"theater_wall2": ["wall_plaster", Color(0.36, 0.2, 0.18), 0.9],
		"gold": ["wall_plaster", Color(0.72, 0.56, 0.28), 2.0],
		"stage": ["wood_floor", Color(0.42, 0.32, 0.24), 0.8],
		"dark": ["concrete", Color(0.12, 0.1, 0.1), 0.5],
		"piano": ["", Color(0.05, 0.045, 0.045), 1.0],
		"keys": ["", Color(0.85, 0.83, 0.76), 1.0],
		"footlight": ["", Color(1.0, 0.85, 0.6), 1.0],
		"mirror": ["", Color(0.55, 0.6, 0.62), 1.0],
		"fog_window": ["", Color(0.55, 0.56, 0.58), 1.0],
		"poster": ["", Color(0.78, 0.66, 0.46), 1.0],
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
		if key == "footlight":
			m.set_shader_parameter(&"emission_color", Color(1.0, 0.75, 0.45))
		if key == "fog_window":
			m.set_shader_parameter(&"emission_color", Color(0.35, 0.36, 0.38))
		var path := THEATER_MAT_DIR + "m_%s.tres" % key
		ResourceSaver.save(m, path)
		mats[key] = load(path)


# --- Helpers -----------------------------------------------------------------------

func _slab(parent: Node, base_name: String, x0: float, z0: float, x1: float, z1: float, y: float,
		thickness: float, mat: String, collision := true) -> Node3D:
	return _box(parent, base_name, Vector3((x0 + x1) / 2, y - thickness / 2, (z0 + z1) / 2),
		Vector3(x1 - x0, thickness, z1 - z0), mat, collision)


func _label(parent: Node, text: String, pos: Vector3, rot_y: float, color: Color, px := 0.008, size := 32) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = load("res://assets/fonts/pixel_operator/PixelOperator.ttf")
	label.font_size = size
	label.pixel_size = px
	label.modulate = color
	label.position = pos
	label.rotation_degrees.y = rot_y
	label.visibility_range_end = 14.0
	label.visibility_range_end_margin = 4.0
	label.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	_add(parent, label, "Label")


func _pickup(base_name: String, item_id: String, pos: Vector3, count := 1) -> void:
	_instance("res://scenes/world/pickup.tscn", groups.Items, base_name, pos,
		{"item": load("res://assets/items/%s.tres" % item_id), "count": count})


## Rampa invisible de (x0, y0) a (x1, y1) a lo largo de X, centrada en z.
func _ramp(x0: float, y0: float, x1: float, y1: float, z: float, width: float) -> void:
	var length := Vector2(x1 - x0, y1 - y0).length()
	var ramp := _box(groups.Structure, "Ramp", Vector3((x0 + x1) / 2, (y0 + y1) / 2 - 0.05, z),
		Vector3(length, 0.1, width), "dark", true, false)
	ramp.rotation.z = atan2(y1 - y0, x1 - x0)
	# Escalones solo visuales.
	var steps := 5
	for i in steps:
		var h := (y1 - y0) * (i + 1) / steps
		var x := x0 + (x1 - x0) * (i + 0.5) / steps
		_box(groups.Structure, "Step", Vector3(x, h / 2, z), Vector3((x1 - x0) / steps, h, width), "stage", false)


func _slot_t(slot_id: String, base_name: String, pos: Vector3) -> Node3D:
	var slot := _slot(slot_id, base_name, pos)
	slot.set("refuge_id", REFUGE)
	return slot


func _station_t(pos: Vector3, parent: Node, base_name: String, kind: int, radius := 0.9) -> void:
	var s := Area3D.new()
	s.set_script(load("res://scripts/world/shelter_station.gd"))
	s.set("kind", kind)
	s.set("radius", radius)
	s.set("refuge_id", REFUGE)
	s.position = pos
	_add(parent, s, base_name)


# --- Zona --------------------------------------------------------------------------

func _theater_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.035, 0.035)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.36, 0.34)
	env.ambient_light_energy = 0.55
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	world_env.set_script(load("res://scripts/world/atmosphere.gd"))
	world_env.set("fog_color", Color(0.07, 0.045, 0.045))
	world_env.set("fog_start", 2.0)
	world_env.set("fog_end", 22.0)
	world_env.set("insane_fog_color", Color(0.03, 0.005, 0.005))
	world_env.set("insane_fog_start", 0.5)
	world_env.set("insane_fog_end", 6.0)
	_add(scene_root, world_env, "Atmosphere")


## Vestíbulo: alfombra roja, araña, boletería, guardarropa y la escalera al pullman (derrumbada).
func _foyer() -> void:
	_floor(0, 0, 14, 14, 0.0, "carpet")
	_slab(groups.Structure, "FoyerCeiling", 0, 0, 14, 14, FOYER_H + 0.1, 0.1, "theater_wall2", false)
	_wall("x", 0.0, -TE / 2, 14.0, 0.0, FOYER_H, TE, [], "theater_wall", false)
	# Pared sur con la abertura de la sala de ensayo escondida (la tapa la "pared que miente").
	_wall("x", 14.0, -TE / 2, 14.0, 0.0, FOYER_H, TE, [[5.0, 2.0, 0.0, DOOR_H]], "theater_wall", false)
	_wall("z", 0.0, 0.0, 14.0, 0.0, FOYER_H, TE, [[7.0, 2.4, 0.0, 3.0]], "theater_wall", false)
	_closed_door(Vector3(0.0, 0, 7.0), -90.0, 2.4, 3.0)
	# Zócalo dorado.
	for z in [0.17, 13.83]:
		_box(groups.Structure, "Trim", Vector3(7, 1.0, z), Vector3(14, 0.08, 0.04), "gold", false)

	# Boletería (x 0-4, z 0-4): ventanilla al vestíbulo y puerta al este.
	_wall("x", 4.0, 0.0, 4.0 + T / 2, 0.0, 3.0, T, [[2.0, 1.4, 1.0, 1.9]], "theater_wall2", true)
	_wall("z", 4.0, 0.0, 4.0, 0.0, 3.0, T, [[2.0, DOOR_W, 0.0, DOOR_H]], "theater_wall2", false)
	_slab(groups.Structure, "BoothCeiling", 0, 0, 4.1, 4.1, 3.1, 0.1, "theater_wall2", false)
	_counter(0.4, 3.6, 3.45, 0.0)
	_prop("chairDesk", Vector3(2.0, 0, 2.6), 0)
	_prop("cardboardBoxClosed", Vector3(0.6, 0, 0.6), 10)
	_point_light(Vector3(2.0, 2.6, 2.0), Color(1.0, 0.8, 0.55), 0.5, 4.0, true)
	_pickup("Shells1", "ammo_shells", Vector3(1.4, 1.05, 3.45), 4)
	_inspect(Vector3(2.8, 1.2, 3.45), ["El talonario de entradas. La última vendida: fila 7, butaca 13. Fecha: hoy.",
		"Todas las demás entradas del talonario están cortadas. Nadie las vendió. Están todas ocupadas."], 1.1)

	# Guardarropa (x 10-14, z 0-4): mostrador a media altura y puerta del lado oeste.
	_wall("x", 4.0, 10.0 - T / 2, 14.0, 0.0, 3.0, T, [[12.0, 2.4, 1.05, 2.6]], "theater_wall2", false)
	_wall("z", 10.0, 0.0, 4.0, 0.0, 3.0, T, [[2.0, DOOR_W, 0.0, DOOR_H]], "theater_wall2", false)
	_slab(groups.Structure, "CoatCeiling", 9.9, 0, 14, 4.1, 3.1, 0.1, "theater_wall2", false)
	for x in [10.8, 12.0, 13.2]:
		_prop("coatRackStanding", Vector3(x, 0, 1.0), randf_range(0, 360))
	_pickup("Cloth1", "material_cloth", Vector3(12.8, 0.0, 2.6), 2)
	_pickup("Chocolate", "food_chocolate_bar", Vector3(12.0, 1.1, 4.0))
	_inspect(Vector3(12.0, 1.3, 4.1), ["Cientos de fichas del guardarropa colgadas en su tablero. Ningún abrigo.",
		"Una sola percha tiene algo: un tapado verde, igual al de la pensión."], 1.2)

	# Escalera al pullman (derrumbada): solo visual, con cajas y cinta de peligro.
	for i in 8:
		var h := 0.3 * (i + 1)
		_box(groups.Structure, "FoyerStep", Vector3(9.4 + i * 0.45, h / 2, 13.1), Vector3(0.45, h, 1.4), "carpet")
	_box(groups.Structure, "StairRail", Vector3(11.0, 2.2, 12.35), Vector3(3.8, 0.06, 0.06), "gold", false)
	for p in [Vector3(12.9, 2.4, 13.0), Vector3(13.2, 2.4, 13.5)]:
		_prop("cardboardBoxClosed", p, randf_range(0, 40), {"col": false})
	_inspect(Vector3(10.5, 1.2, 12.0), ["La escalera al pullman se derrumbó a mitad de camino. Arriba, alguien aplaude despacio."], 1.3)

	# La araña del techo, que titila.
	_box(groups.Lights, "Chandelier", Vector3(7.0, FOYER_H - 0.7, 7.5), Vector3(1.2, 0.5, 1.2), "gold", false)
	_box(groups.Lights, "ChandelierGlow", Vector3(7.0, FOYER_H - 1.0, 7.5), Vector3(0.9, 0.12, 0.9), "footlight", false)
	_point_light(Vector3(7.0, FOYER_H - 1.3, 7.5), Color(1.0, 0.78, 0.5), 1.2, 11.0, true)
	# Afiches enmarcados.
	for p: Array in [[Vector3(1.5, 2.0, 13.8), 180.0], [Vector3(7.0, 2.2, 0.2), 0.0]]:
		var poster_pos: Vector3 = p[0]
		var facing: float = p[1]
		var normal := Vector3(0, 0, -0.03) if facing > 90.0 else Vector3(0, 0, 0.03)
		_box(groups.Structure, "PosterFrame", poster_pos, Vector3(1.2, 1.7, 0.04), "gold", false)
		_box(groups.Structure, "Poster", poster_pos + normal, Vector3(1.0, 1.5, 0.02), "poster", false)
		_label(groups.Structure, "LA PALOMA\n\nFunción única\n3:15", poster_pos + normal * 2.0, facing, Color(0.3, 0.08, 0.06), 0.006)
	for p in [Vector3(13.0, 0, 6.0), Vector3(13.0, 0, 9.0)]:
		_prop("pottedPlant", p, 0, {"tint": Color(0.35, 0.3, 0.25)})
	_prop("benchCushion", Vector3(2.0, 0, 13.2), 180, {"tint": Color(0.6, 0.25, 0.22)})
	_prop("benchCushion", Vector3(7.0, 0, 13.2), 180, {"tint": Color(0.6, 0.25, 0.22)})
	# La gorra de Sosa y la escopeta de la comisaría.
	_box(groups.Props, "PoliceCap", Vector3(7.3, 0.55, 13.2), Vector3(0.28, 0.1, 0.25), "dark", false)
	_pickup("Shotgun", "weapon_shotgun", Vector3(6.6, 0.5, 13.2))
	_pickup("Shells2", "ammo_shells", Vector3(7.8, 0.5, 13.3), 4)
	_inspect(Vector3(7.0, 0.8, 13.0), ["Una gorra de policía y la escopeta de la comisaría, apoyadas con cuidado en el banco.",
		"Como si alguien las hubiera dejado para entrar a la función sin molestar a nadie."], 1.2)
	# Puerta de vuelta a la avenida.
	var door := Area3D.new()
	door.set_script(load("res://scripts/world/zone_door.gd"))
	door.set("target_scene", "res://scenes/levels/street.tscn")
	door.set("target_spawn", &"from_theater")
	door.set("radius", 1.3)
	door.position = Vector3(0.6, 1.2, 7.0)
	_add(groups.Inspectables, door, "StreetDoor")


## La sala: butacas rojas, pasillos, pullman colgando y las puertas desde el vestíbulo.
func _hall() -> void:
	_floor(14, -2, 33, 16, 0.0, "carpet")
	_slab(groups.Structure, "HallCeiling", 14, -2, 42, 16, HALL_H + 0.1, 0.1, "theater_wall2", false)
	_wall("z", 14.0, -2.0, 16.0, 0.0, HALL_H, TE, [_door(3.0), _door(11.0)], "theater_wall", false)
	_wall("x", -2.0, 14.0, 42.0, 0.0, HALL_H, TE, [], "theater_wall2", false)
	_wall("x", 16.0, 14.0, 42.0, 0.0, HALL_H, TE, [], "theater_wall2", false)
	# El pullman (inaccesible), colgando sobre las últimas filas.
	_slab(groups.Structure, "Balcony", 14, -2, 20, 16, 4.9, 0.35, "theater_wall2", false)
	_box(groups.Structure, "BalconyRail", Vector3(20.0, 5.3, 7.0), Vector3(0.15, 0.8, 18.0), "gold", false)
	# Butacas: 12 filas, dos bloques, mirando al escenario (+X).
	for row in 12:
		var x := 17.0 + row * 1.15
		for block: Vector2 in [Vector2(0.4, 6.0), Vector2(8.0, 13.6)]:
			var width := block.y - block.x
			var z := (block.x + block.y) / 2
			_box(groups.Props, "SeatRow", Vector3(x, 0.22, z), Vector3(0.5, 0.44, width), "velvet")
			_box(groups.Props, "SeatBack", Vector3(x - 0.3, 0.55, z), Vector3(0.1, 1.1, width), "velvet")
			_box(groups.Props, "SeatEnd", Vector3(x - 0.05, 0.4, block.x + 0.03), Vector3(0.62, 0.8, 0.06), "gold", false)
			_box(groups.Props, "SeatEnd", Vector3(x - 0.05, 0.4, block.y - 0.03), Vector3(0.62, 0.8, 0.06), "gold", false)
	_label(groups.Props, "FILA 7", Vector3(17.0 + 6 * 1.15 - 0.36, 1.05, 3.2), -90, Color(0.8, 0.7, 0.45), 0.005)
	# Luces de pasillo (bajas, rojas) y carteles de salida.
	for x in [16.5, 21.0, 25.5, 30.0]:
		for z in [-1.8, 15.8]:
			_box(groups.Lights, "AisleLight", Vector3(x, 0.3, z), Vector3(0.2, 0.1, 0.05), "footlight", false)
	for z in [3.0, 11.0]:
		_prop("exit_sign", Vector3(14.2, 2.75, z), -90)
	_point_light(Vector3(22.0, 3.0, 7.0), Color(0.8, 0.35, 0.3), 0.6, 10.0, true)
	# Apliques en las paredes de la sala (algunos titilan).
	for x in [17.0, 23.0, 29.0]:
		for z in [-1.75, 15.75]:
			_box(groups.Lights, "Sconce", Vector3(x, 3.0, z), Vector3(0.3, 0.4, 0.1), "footlight", false)
			_point_light(Vector3(x, 3.0, z + (0.6 if z < 0 else -0.6)), Color(1.0, 0.7, 0.45), 0.8, 7.5, x == 23.0)
	_pickup("Shells3", "ammo_shells", Vector3(24.0, 0.05, -1.2), 3)
	_pickup("Ammo9mm", "ammo_9mm", Vector3(28.5, 0.05, 15.3), 8)
	_inspect(Vector3(17.0 + 6 * 1.15, 0.8, 3.5), ["Fila 7, butaca 13. Está tibia. El resto de la sala está helada."], 1.2)


## El escenario: telón, candilejas, piano y el jefe.
func _stage() -> void:
	_slab(groups.Structure, "Stage", 33, -2, 42, 16, S, S, "stage")
	# Boca del escenario: la pared sobre el telón, con la abertura de 14 x 5.5 m.
	_wall("z", 33.1, -2.0, 16.0, S, HALL_H - S, 0.4, [[7.0, 14.0, 0.0, 5.5]], "theater_wall2", false)
	_box(groups.Structure, "Proscenium", Vector3(32.85, S + 5.6, 7.0), Vector3(0.12, 0.3, 14.4), "gold", false)
	# Telón recogido a los costados y bambalina de arriba.
	for z in [0.9, 13.1]:
		_box(groups.Structure, "Curtain", Vector3(33.55, S + 2.75, z), Vector3(0.35, 5.5, 1.8), "velvet", false)
	_box(groups.Structure, "Valance", Vector3(33.55, S + 5.1, 7.0), Vector3(0.3, 0.8, 14.0), "velvet", false)
	# Candilejas.
	for i in 14:
		_box(groups.Lights, "Footlight", Vector3(33.35, S + 0.06, 0.5 + i), Vector3(0.12, 0.08, 0.25), "footlight", false)
	_point_light(Vector3(34.0, S + 0.4, 3.5), Color(1.0, 0.72, 0.45), 0.9, 6.0, true)
	_point_light(Vector3(34.0, S + 0.4, 10.5), Color(1.0, 0.72, 0.45), 0.9, 6.0, true)
	# Luz de escena desde las varas.
	for z in [3.5, 10.5]:
		_point_light(Vector3(37.5, S + 4.5, z), Color(1.0, 0.82, 0.65), 1.5, 11.0)
	# Un seguidor desde el pullman apunta al centro del escenario.
	var spot := SpotLight3D.new()
	spot.light_color = Color(1.0, 0.88, 0.75)
	spot.light_energy = 3.0
	spot.spot_range = 22.0
	spot.spot_angle = 16.0
	spot.position = Vector3(20.0, 6.5, 7.0)
	_add(groups.Lights, spot, "FollowSpot")
	spot.look_at_from_position(spot.position, Vector3(38.0, S, 7.0))
	# Rampas (con escalones visuales) a los dos costados.
	_ramp(30.4, 0.0, 33.0, S, -1.15, 1.5)
	_ramp(30.4, 0.0, 33.0, S, 15.15, 1.5)
	# Pared del fondo del escenario, con dos puertas a las bambalinas (detrás del telón de fondo).
	_wall("z", 42.0, -2.0, 16.0, 0.0, HALL_H, T, [[3.0, DOOR_W, S, S + DOOR_H], [11.0, DOOR_W, S, S + DOOR_H]],
		"theater_wall2", false)
	_box(groups.Structure, "Backdrop", Vector3(41.6, S + 3.0, 7.0), Vector3(0.05, 6.0, 6.5), "velvet", false)
	# El piano de cola (con cajas: tapa, cuerpo, patas, teclado).
	var piano := Vector3(39.0, S, 3.2)
	_box(groups.Props, "PianoBody", piano + Vector3(0, 0.75, 0), Vector3(1.5, 0.3, 2.1), "piano")
	_box(groups.Props, "PianoLid", piano + Vector3(0.2, 1.25, 0), Vector3(1.4, 0.04, 2.0), "piano", false)
	_box(groups.Props, "PianoKeys", piano + Vector3(-0.8, 0.87, 0), Vector3(0.18, 0.05, 1.4), "keys", false)
	for d in [Vector3(0.6, 0, 0.9), Vector3(0.6, 0, -0.9), Vector3(-0.6, 0, 0)]:
		_box(groups.Props, "PianoLeg", piano + d + Vector3(0, 0.3, 0), Vector3(0.1, 0.6, 0.1), "piano", false)
	_box(groups.Props, "PianoStool", piano + Vector3(-1.3, 0.25, 0), Vector3(0.4, 0.5, 0.5), "piano")
	_inspect(piano + Vector3(-0.9, 1.0, 0), ["Las teclas están tibias. En el atril, la partitura de \"La Paloma\".",
		"Alguien anotó en rojo sobre el pentagrama: otra vez, otra vez, otra vez."], 1.3)
	_label(groups.Props, "LA PALOMA", piano + Vector3(-0.75, 1.25, 0), -90, Color(0.2, 0.15, 0.12), 0.004)
	# Disparador: al acercarse al escenario, ella sale a cantar.
	var trigger := Area3D.new()
	trigger.set_script(load("res://scripts/world/boss_trigger.gd"))
	trigger.set("boss", NodePath("../../Enemies/Singer"))
	trigger.position = Vector3(31.0, 1.5, 7.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(12.0, 3.0, 18.0)
	shape.shape = box
	_add(groups.Secrets, trigger, "BossTrigger")
	_add(trigger, shape, "Shape")


## Bambalinas (a la altura del escenario): pasillo, camarín, depósito y el camarín principal.
func _backstage() -> void:
	_slab(groups.Structure, "BackstageFloor", 42, -2, 54, 16, S, S, "stage")
	_slab(groups.Structure, "BackstageCeiling", 42, -2, 54, 16, S + BACK_H + 0.1, 0.1, "theater_wall2", false)
	_wall("x", -2.0, 42.0, 54.0 + TE / 2, S, BACK_H, TE, [], "theater_wall2", false)
	_wall("x", 16.0, 42.0, 54.0 + TE / 2, S, BACK_H, TE, [], "theater_wall2", false)
	_wall("z", 54.0, -2.0, 9.0, S, BACK_H, TE, [], "theater_wall2", false)
	_wall("z", 54.0, 9.0, 16.0, S, BACK_H, TE, [[12.5, 1.4, 1.0, 2.2]], "theater_wall2", true)
	_box(groups.Structure, "FogWindow", Vector3(54.45, S + 1.6, 12.5), Vector3(0.05, 1.4, 1.6), "fog_window", false)
	# Pared del pasillo con tres puertas, y las divisiones entre cuartos.
	_wall("z", 45.0, -2.0, 16.0, S, BACK_H, T, [_door(1.5), _door(7.0), _door(12.5)], "theater_wall", false)
	_wall("x", 5.0, 45.0, 54.0, S, BACK_H, T, [], "theater_wall", false)
	_wall("x", 9.0, 45.0, 54.0, S, BACK_H, T, [], "theater_wall", false)
	_point_light(Vector3(43.5, S + 2.6, 7.0), Color(0.9, 0.7, 0.5), 0.5, 7.0, true)
	# Pasillo: cuerdas y contrapesos, un baúl de utilería.
	_prop("cardboardBoxClosed", Vector3(43.0, S, -1.3), 20)
	_prop("coatRackStanding", Vector3(43.0, S, 15.3), 0)
	for z in [0.0, 5.5, 14.0]:
		_box(groups.Structure, "Rope", Vector3(42.4, S + 1.7, z), Vector3(0.03, 3.4, 0.03), "dark", false)

	# Camarín 2 (z -2..5): tocador con espejo, sillas, un perchero con vestuario.
	_box(groups.Props, "Vanity", Vector3(53.5, S + 0.4, 1.5), Vector3(0.7, 0.8, 3.0), "stage")
	_box(groups.Props, "VanityMirror", Vector3(53.8, S + 1.6, 1.5), Vector3(0.04, 1.0, 2.6), "mirror", false)
	for i in 8:
		_box(groups.Lights, "MirrorBulb", Vector3(53.75, S + 2.15, 0.35 + i * 0.33), Vector3(0.06, 0.06, 0.06), "footlight", false)
	_point_light(Vector3(52.8, S + 2.0, 1.5), Color(1.0, 0.8, 0.55), 0.6, 5.0, true)
	_prop("chair", Vector3(52.6, S, 0.8), -90)
	_prop("chair", Vector3(52.6, S, 2.3), -100)
	_prop("coatRackStanding", Vector3(46.2, S, 4.2), 0)
	_prop("curtain", Vector3(47.5, S, -1.5), 0, {"h": 2.2, "tint": Color(0.55, 0.2, 0.18)})
	_pickup("Shells4", "ammo_shells", Vector3(53.4, S + 0.82, 0.8), 4)
	_pickup("Water", "food_water_bottle", Vector3(53.4, S + 0.82, 2.2))
	_pickup("Cloth2", "material_cloth", Vector3(46.5, S, 0.5), 2)

	# Depósito de utilería (z 5..9): cajones, estantes, materiales. Hay alguien.
	for p in [Vector3(53.0, S, 5.8), Vector3(53.0, S, 6.8), Vector3(52.0, S, 8.3), Vector3(46.3, S, 8.4)]:
		_prop(POLYHAVEN_CRATE, p, randf_range(0, 30), {"h": 0.8})
	_prop("bookcaseOpen", Vector3(49.5, S, 8.6), 180)
	_pickup("Wood", "material_wood", Vector3(50.5, S, 6.0), 3)
	_pickup("Metal", "material_metal", Vector3(47.5, S, 6.2), 2)
	_pickup("Cable", "material_cable", Vector3(49.5, S + 0.9, 8.6), 2)
	_inspect(Vector3(51.0, S + 1.0, 7.0), ["Cabezas de utilería en un estante. Una tiene la cara de alguien que conocés."], 1.3)


const POLYHAVEN_CRATE := "cardboardBoxOpen"


## El camarín principal (z 9..16): el segundo lugar donde se puede vivir.
## La puerta no abre mientras la cantante siga en el escenario.
func _camarin_refuge() -> void:
	# La puerta trabada (FlagGate): abre cuando muere el jefe.
	var gate := Node3D.new()
	gate.set_script(load("res://scripts/world/flag_gate.gd"))
	gate.set("flag", &"theater_boss_dead")
	gate.set("locked_text", "La puerta del camarín principal no cede. Mientras ella cante, no va a ceder.")
	gate.set("open_text", "En el fondo del teatro, una puerta se destraba sola.")
	gate.position = Vector3(45.0, S, 12.5)
	_add(groups.Structure, gate, "CamarinGate")
	_box(gate, "Door", Vector3(0, 1.2, 0), Vector3(0.1, 2.4, DOOR_W), "stage")
	_box(gate, "Star", Vector3(-0.07, 1.9, 0), Vector3(0.02, 0.3, 0.3), "gold", false)
	_label(groups.Structure, "PRIMERA ACTRIZ", Vector3(44.92, S + 2.5, 12.5), -90, Color(0.8, 0.65, 0.35), 0.005)

	var zone := Area3D.new()
	zone.set_script(RefugeScript)
	zone.set("use_shelter", true)
	zone.set("refuge_id", REFUGE)
	zone.position = Vector3(49.6, S + 1.6, 12.5)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8.6, 3.2, 6.6)
	shape.shape = box
	_add(groups.Refuge, zone, "RefugeZone")
	_add(zone, shape, "Shape")

	# Fijo: el tocador de la primera actriz, un diván, un biombo.
	_box(groups.Refuge, "StarVanity", Vector3(49.5, S + 0.4, 15.5), Vector3(3.0, 0.8, 0.7), "stage")
	_box(groups.Refuge, "StarMirror", Vector3(49.5, S + 1.6, 15.84), Vector3(2.6, 1.0, 0.04), "mirror", false)
	_prop("loungeSofa", Vector3(47.2, S, 9.8), 0, {"tint": Color(0.65, 0.25, 0.25)})
	_prop("chair", Vector3(49.5, S, 14.7), 0)
	_pickup("LetterMarta3", "letter_marta_03", Vector3(50.3, S + 0.82, 15.5))
	_inspect(Vector3(49.5, S + 1.2, 15.2), ["El espejo del camarín. Tu reflejo tarda un instante de más en moverse."], 1.2)
	_prop("radio", Vector3(48.4, S + 0.8, 15.5), 180)
	_station_t(Vector3(48.4, S + 1.0, 15.2), groups.Refuge, "RadioStation", 3)

	# El plano, clavado en el biombo de la entrada.
	_box(groups.Refuge, "BlueprintBoard", Vector3(46.0, S + 1.6, 9.12), Vector3(1.0, 0.7, 0.03), "cork", false)
	_box(groups.Refuge, "BlueprintPaper", Vector3(46.0, S + 1.62, 9.14), Vector3(0.8, 0.5, 0.01), "paper", false)
	_label(groups.Refuge, "PLANO", Vector3(46.0, S + 1.78, 9.16), 0, Color(0.25, 0.2, 0.3), 0.008, 16)
	_station_t(Vector3(46.0, S + 1.2, 9.7), groups.Refuge, "BlueprintStation", 0, 1.1)

	var warm := Color(1.0, 0.7, 0.42)
	# Fuego: brasero de utilería -> estufa de hierro.
	var fire := _slot_t("fire", "SlotFire", Vector3(53.0, S, 14.8))
	_inspect(Vector3(0, 0.5, 0), ["Un rincón con piso de chapa. Acá se podría hacer fuego sin quemar el teatro. (Ver el plano.)"], 0.9, _only(fire, 0))
	var f1 := _only(fire, 1)
	_prop("barrel_stove", Vector3.ZERO, 0, {"parent": f1})
	_box(f1, "Embers", Vector3(0, 0.88, 0), Vector3(0.3, 0.03, 0.3), "ember", false)
	_point_light(Vector3(0, 1.15, 0), warm, 1.3, 5.5, true, f1)
	var f2 := _only(fire, 2)
	_prop("scandinavian_masonry_heater", Vector3.ZERO, -90, {"parent": f2})
	_point_light(Vector3(-0.8, 0.9, 0), warm, 1.6, 7.0, true, f2)
	_loop_sound(_from(fire, 1), "fire", Vector3(0, 0.8, 0), -8.0)
	_station_t(Vector3(-0.4, 0.6, 0), _from(fire, 1), "CookStation", 1)

	# Electricidad: las luces del espejo, primero apagadas.
	var power := _slot_t("power", "SlotPower", Vector3(52.5, S, 10.0))
	var p0 := _only(power, 0)
	_prop("washer", Vector3.ZERO, 180, {"parent": p0, "tint": Color(0.3, 0.32, 0.3)})
	_inspect(Vector3(0, 0.6, 0.4), ["El grupo electrógeno de emergencia del teatro. Está desarmado. (Ver el plano.)"], 0.9, p0)
	_point_light(Vector3(-3.0, 1.0, 5.2), Color(1.0, 0.75, 0.45), 0.45, 3.5, true, p0)  # una vela en el tocador
	var p1 := _from(power, 1)
	_prop("washer", Vector3.ZERO, 180, {"parent": p1, "tint": Color(0.55, 0.6, 0.5)})
	_loop_sound(p1, "generator", Vector3(0, 0.5, 0), -16.0)
	for i in 10:
		_box(p1, "MirrorBulb", Vector3(-4.2 + i * 0.3, 2.2, 5.8), Vector3(0.06, 0.06, 0.06), "footlight", false)
	_point_light(Vector3(-3.0, 2.3, 4.8), warm, 1.1, 8.0, false, p1)
	var p2 := _only(power, 2)
	_box(p2, "Conduit", Vector3(0, 2.8, 2.5), Vector3(0.05, 0.05, 5.0), "soot", false)
	_point_light(Vector3(-5.0, 2.8, 2.5), warm, 0.7, 6.0, false, p2)

	# Cama: colchón -> cama -> cama con mantas.
	var bed := _slot_t("bed", "SlotBed", Vector3(47.0, S, 13.2))
	var b0 := _only(bed, 0)
	_box(b0, "Mattress", Vector3(0, 0.08, 0), Vector3(0.95, 0.16, 2.0), "cloth", false)
	_inspect(Vector3(0, 0.3, 0), ["Un colchón de utilería, relleno de papel de diario. (Ver el plano.)"], 1.0, b0)
	_prop("bedSingle", Vector3.ZERO, 0, {"parent": _only(bed, 1)})
	var b2 := _only(bed, 2)
	_prop("bedSingle", Vector3.ZERO, 0, {"parent": b2})
	_box(b2, "Blanket", Vector3(0, 0.47, 0.25), Vector3(0.72, 0.06, 1.3), "velvet", false)
	_station_t(Vector3(0.6, 0.5, 0), _from(bed, 1), "RestStation", 2, 1.1)

	# Ventana: la niebla pegada al vidrio -> tablones -> cortinas de terciopelo.
	var windows := _slot_t("windows", "SlotWindows", Vector3(53.8, S, 12.5))
	var w1 := _from(windows, 1)
	for y in [1.15, 1.5, 1.85, 2.2]:
		_box(w1, "Plank", Vector3(0, y, randf_range(-0.05, 0.05)), Vector3(0.04, 0.2, 1.6), "planks", false)
	var w2 := _only(windows, 2)
	for dz in [-1.0, 1.0]:
		_prop("curtain", Vector3(-0.1, 0, dz), 90, {"parent": w2, "h": 2.4, "tint": Color(0.6, 0.12, 0.1)})

	# Decoración: fotos de funciones viejas -> flores y alfombra.
	var decor := _slot_t("decor", "SlotDecor", Vector3.ZERO)
	var d1 := _from(decor, 1)
	for pic in [[Vector3(49.0, S + 1.7, 9.12), "photo"], [Vector3(50.0, S + 1.55, 9.12), "photo2"], [Vector3(51.0, S + 1.8, 9.12), "photo"]]:
		_box(d1, "Frame", pic[0], Vector3(0.42, 0.5, 0.03), "gold", false)
		_box(d1, "Photo", pic[0] + Vector3(0, 0, 0.02), Vector3(0.3, 0.38, 0.01), pic[1], false)
	var d2 := _from(decor, 2)
	_prop("rugRectangle", Vector3(49.8, S + 0.005, 12.5), 90, {"parent": d2, "tint": Color(0.6, 0.3, 0.25)})
	_prop("pottedPlant", Vector3(53.3, S, 15.3), 0, {"parent": d2})
	_prop("plantSmall1", Vector3(50.8, S + 0.8, 15.5), 0, {"parent": d2})

	# Alijo: el mismo de siempre (viaja con la mudanza), en el rincón de la entrada.
	var stash := _slot_t("stash", "SlotStash", Vector3(45.6, S, 15.3))
	_stash_visuals(stash, 90.0)
	_station_t(Vector3(0.6, 0.7, 0), _from(stash, 0), "StashStation", 4, 1.0)


## Secretos por cordura.
func _secrets_theater() -> void:
	# Inquieto: en la pared del vestíbulo aparece la butaca que te espera.
	var hint := Node3D.new()
	hint.set_script(GatedScript)
	hint.set("threshold", 1)
	_add(groups.Secrets, hint, "WallSymbol")
	_label(hint, "FILA 7\nBUTACA 13", Vector3(5.0, 3.1, 13.82), 180, Color(0.55, 0.05, 0.03), 0.009)
	# Quebrado: la pared del vestíbulo se abre a una sala de ensayo que no figura en los planos.
	var lying := Node3D.new()
	lying.set_script(GatedScript)
	lying.set("mode", 1)
	_add(groups.Secrets, lying, "LyingWall")
	var wall: StaticBody3D = GreyBoxScript.new()
	wall.set("size", Vector3(2.0, DOOR_H, TE))
	wall.set("material", mats.theater_wall)
	wall.position = Vector3(5.0, DOOR_H / 2, 14.0)
	_add(lying, wall, "Wall")
	# La sala de ensayo (x 3-7, z 14-17).
	_floor(3, 14, 7, 17, 0.0, "stage")
	_slab(groups.Structure, "RehearsalCeiling", 3, 14, 7, 17.2, 3.1, 0.1, "theater_wall2", false)
	_wall("x", 17.0, 3.0 - T / 2, 7.0 + T / 2, 0.0, 3.0, T, [], "theater_wall2", false)
	_wall("z", 3.0, 14.0, 17.0, 0.0, 3.0, T, [], "theater_wall2", false)
	_wall("z", 7.0, 14.0, 17.0, 0.0, 3.0, T, [], "theater_wall2", false)
	_box(groups.Props, "UprightPiano", Vector3(5.0, 0.65, 16.6), Vector3(1.5, 1.3, 0.55), "piano")
	_box(groups.Props, "UprightKeys", Vector3(5.0, 0.78, 16.25), Vector3(1.3, 0.05, 0.2), "keys", false)
	_point_light(Vector3(5.0, 2.5, 15.5), Color(0.9, 0.5, 0.4), 0.5, 4.0, true)
	_pickup("Program", "letter_program_01", Vector3(4.6, 1.33, 16.6))
	_pickup("Shells5", "ammo_shells", Vector3(6.3, 0.05, 15.0), 6)
	# Quebrado: el público. Figuras paradas en los pasillos, mirando al escenario.
	var audience := Node3D.new()
	audience.set_script(GatedScript)
	audience.set("threshold", 2)
	_add(groups.Secrets, audience, "Audience")
	for p in [Vector3(19.0, 0, 7.0), Vector3(23.6, 0, -1.0), Vector3(27.0, 0, 15.0), Vector3(29.5, 0, 7.0)]:
		_instance("res://scenes/enemies/horror_placeholder.tscn", audience, "Figure", p)
	_label(audience, "ELLA CANTA PARA VOS", Vector3(33.75, S + 3.5, 7.0), -90, Color(0.6, 0.05, 0.03), 0.012)


func _places() -> void:
	var places := [
		["theater_foyer", 0, 0, 14, 14, 0.0], ["theater_hall", 14, -2, 33, 16, 0.0], ["theater_stage", 33, -2, 42, 16, S],
		["theater_backstage", 42, -2, 45, 16, S], ["theater_camarin", 45, 9, 54, 16, S], ["theater_rehearsal", 3, 14, 7, 17, 0.0],
	]
	var parent := _add(scene_root, Node3D.new(), "Places")
	for p: Array in places:
		var zone := Area3D.new()
		zone.set_script(load("res://scripts/world/discovery_zone.gd"))
		zone.set("place_id", StringName(p[0]))
		zone.set("size", Vector3(p[3] - p[1] - 0.4, 2.8, p[4] - p[2] - 0.4))
		zone.position = Vector3((p[1] + p[3]) / 2.0, p[5] + 1.4, (p[2] + p[4]) / 2.0)
		_add(parent, zone, String(p[0]))


func _theater_enemies() -> void:
	var stalker := "res://scenes/enemies/stalker.tscn"
	_instance(stalker, groups.Enemies, "StalkerCoats", Vector3(8.0, 0.05, 2.6), {"wander_radius": 2.5})
	_instance(stalker, groups.Enemies, "StalkerStorage", Vector3(49.5, S + 0.05, 7.0), {"wander_radius": 1.5})
	# La cantante: el jefe del teatro (duerme hasta que te acercás al escenario).
	_instance("res://scenes/enemies/boss.tscn", groups.Enemies, "Singer", Vector3(38.0, S + 0.05, 7.5), {"wander_radius": 3.0})
	# Más público según la dificultad.
	_extra_enemy(Vector3(22.0, 0.05, 7.0), 1, 4.0)
	_extra_enemy(Vector3(43.5, S + 0.05, 9.0), 1, 2.0)
	_extra_enemy(Vector3(5.0, 0.05, 9.0), 2, 3.0)
	_extra_enemy(Vector3(28.0, 0.05, 14.8), 2, 3.0)


func _theater_systems() -> void:
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
	level_audio.set("ambience", &"theater")
	level_audio.set("ambience_db", -8.0)
	_add(scene_root, level_audio, "LevelAudio")
	for s: Array in [[&"from_street", Vector3(1.6, 0.05, 7.0), -90.0], [&"refuge", Vector3(49.0, S + 0.05, 12.0), 90.0]]:
		var spawn := Marker3D.new()
		spawn.set_script(load("res://scripts/world/spawn_point.gd"))
		spawn.set("spawn_id", s[0])
		spawn.position = s[1]
		spawn.rotation_degrees.y = s[2]
		_add(scene_root, spawn, "Spawn_" + String(s[0]))
	_instance("res://scenes/player/player.tscn", scene_root, "Player", Vector3(1.6, 0.05, 7.0))
	_instance("res://scenes/effects/ps1_post_process.tscn", scene_root, "PS1PostProcess", Vector3.ZERO)
	var ui: Node = load("res://scenes/ui/game_ui.tscn").instantiate()
	_add(scene_root, ui, "GameUI")
