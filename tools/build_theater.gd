extends "res://tools/build_hospital.gd"
## Genera res://scenes/levels/theater.tscn: el Teatro Imperio, zona 3. Pedido del usuario:
## "por lo menos 10 veces más grande" que el primero (unos 950 m²): ahora ~9000 m² en tres
## niveles. El camarín principal sigue siendo el segundo refugio ("theater").
## Reusa los helpers del generador del hospital. Andamio de una sola pasada.
## Uso: <godot> --headless --path . -s res://tools/build_theater.gd
##
## Planta (x = este, z = sur), x 0-96, z -24..40. La entrada, desde la avenida, en x = 0.
##   Vestíbulo           x 0-24,  z -4..28  (doble altura; entrepiso a 5 m en x 16-24, escalera imperial)
##   Salón de espejos    x 0-24,  z -24..-4 (arriba, la administración)
##   Galería y bar       x 0-24,  z 28..40  (detrás, la sala de ensayo secreta)
##   Ala norte / sur     x 24-76, z -24..-10 / 26..40: pasillo y salas (ensayo, danza, máquinas /
##                       museo, bar de artistas, partituras)
##   Platea              x 24-60, z -10..26 (pullman y galería de palcos a 5 m)
##   Escenario           x 60-76, z -10..26 (a 1.1 m; la cantante)
##   Hombro y pasillo    x 76-87, z -24..40 (a 1.1 m)
##   Camarines           x 87-96, z -24..40 (taller, sastrería, camarines 2 y 3, depósito,
##                       camarín principal = refugio, camarín colectivo, muelle de carga)
##   Foso de máquinas    x 60-96, z -10..40 a -3.5 m (bajo el escenario; se baja desde el hombro)

const OUT := "res://scenes/levels/theater.tscn"
const THEATER_MAT_DIR := "res://assets/materials/theater/"
const S := 1.1          # alto del escenario y de las bambalinas
const SALA_H := 12.0
const FOYER_H := 10.0
const UP := 5.0         # el primer piso (entrepiso, pullman, palcos, administración)
const BACK_H := 4.0     # alto de las bambalinas sobre el escenario
const PIT := -3.5       # piso del foso de máquinas
const REFUGE := &"theater"
# El camarín principal (y sus mejoras) se armó para x 45-54, z 9-16: se corre entero.
const CAM_DX := 42.0
const CAM_DZ := 9.0


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
	_shell()
	_foyer()
	_galleries()
	_upper_floor()
	_wings()
	_hall()
	_stage()
	_backstage()
	_camarin_refuge()
	_machinery_pit()
	_secrets_theater()
	_places()
	_theater_items()
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




## Rampa invisible a lo largo de Z, con escalones visuales.
func _ramp_z(z0: float, y0: float, z1: float, y1: float, x: float, width: float, steps := 8, mat := "stage") -> void:
	var length := Vector2(z1 - z0, y1 - y0).length()
	var ramp := _box(groups.Structure, "Ramp", Vector3(x, (y0 + y1) / 2 - 0.05, (z0 + z1) / 2),
		Vector3(width, 0.1, length), "dark", true, false)
	ramp.rotation.x = -atan2(y1 - y0, z1 - z0)
	for i in steps:
		var top := y0 + (y1 - y0) * (i + 1) / steps
		var z := z0 + (z1 - z0) * (i + 0.5) / steps
		var bottom := minf(y0, y1)
		_box(groups.Structure, "Step", Vector3(x, (top + bottom) / 2, z), Vector3(width, absf(top - bottom), absf(z1 - z0) / steps), mat, false)


## Baranda con colisión (para no caerse de los pisos altos), a lo largo de un eje.
func _railing(axis: String, c: float, a0: float, a1: float, y: float) -> void:
	var mid := (a0 + a1) / 2
	var length := absf(a1 - a0)
	var size := Vector3(length, 1.0, 0.08) if axis == "x" else Vector3(0.08, 1.0, length)
	var pos := Vector3(mid, y + 0.5, c) if axis == "x" else Vector3(c, y + 0.5, mid)
	_box(groups.Structure, "Railing", pos, size, "gold")
	var top := Vector3(length, 0.06, 0.14) if axis == "x" else Vector3(0.14, 0.06, length)
	_box(groups.Structure, "RailingTop", pos + Vector3.UP * 0.52, top, "velvet", false)


# --- La caja del edificio ----------------------------------------------------------

func _shell() -> void:
	# Pisos.
	_floor(0, -4, 24, 28, 0.0, "carpet")
	_floor(0, -24, 24, -4, 0.0, "stage")
	_floor(0, 28, 24, 40, 0.0, "carpet")
	_floor(24, -24, 76, -10, 0.0, "floor_dirty")
	_floor(24, 26, 76, 40, 0.0, "floor_dirty")
	_floor(24, -10, 60, 26, 0.0, "carpet")
	_floor(60, -10, 96, 40, PIT, "concrete")
	# Bambalinas al norte del foso: macizas. Escenario, hombro y camarines sobre el foso: losa fina
	# con el hueco de la escalera (x 77-80, z 28-38).
	_slab(groups.Structure, "BackstageNorth", 76, -24, 96, -10, S, S, "stage")
	for s in [[60, -10, 76, 26], [76, -10, 96, 28], [76, 28, 77, 40], [80, 28, 96, 40], [77, 38, 80, 40]]:
		_slab(groups.Structure, "StageSlab", s[0], s[1], s[2], s[3], S, 0.3, "stage")
	# Cielorrasos.
	_slab(groups.Structure, "FoyerCeiling", 0, -4, 24, 28, FOYER_H + 0.1, 0.1, "theater_wall2", false)
	_slab(groups.Structure, "GalleryCeiling", 0, 28, 24, 40, UP + 0.1, 0.1, "theater_wall2", false)
	_slab(groups.Structure, "AdminCeiling", 0, -24, 24, -4, UP + 4.3, 0.1, "theater_wall2", false)
	for z in [[-24, -10], [26, 40]]:
		_slab(groups.Structure, "WingCeiling", 24, z[0], 76, z[1], 4.6, 0.1, "theater_wall2", false)
	_slab(groups.Structure, "HallCeiling", 24, -10, 76, 26, SALA_H + 0.1, 0.1, "theater_wall2", false)
	_slab(groups.Structure, "BackstageCeiling", 76, -24, 96, 40, S + BACK_H + 0.1, 0.1, "theater_wall2", false)
	# Paredes exteriores.
	_wall("z", 0.0, -24.0, 40.0, 0.0, SALA_H, TE, [[12.0, 3.0, 0.0, 3.5]], "theater_wall", false)
	_wall("x", -24.0, -TE / 2, 96.0 + TE / 2, 0.0, SALA_H, TE, [], "theater_wall", false)
	_wall("z", 96.0, -24.0, 40.0, 0.0, SALA_H, TE, [[21.5, 1.4, S + 1.0, S + 2.2]], "theater_wall", true)
	_wall("x", 40.0, -TE / 2, 96.0 + TE / 2, 0.0, SALA_H, TE, [[7.0, 2.0, 0.0, DOOR_H]], "theater_wall", false)
	_box(groups.Structure, "FogWindow", Vector3(96.45, S + 1.6, 21.5), Vector3(0.05, 1.4, 1.6), "fog_window", false)
	# Vestíbulo / platea y vestíbulo / galerías.
	_wall("z", 24.0, -4.0, 28.0, 0.0, SALA_H, TE, [[2.0, 2.4, 0.0, 3.0], [22.0, 2.4, 0.0, 3.0],
		[8.0, 2.0, UP, UP + 2.6], [16.0, 2.0, UP, UP + 2.6]], "theater_wall", false)
	_wall("z", 24.0, -24.0, -4.0, 0.0, FOYER_H, TE, [[-12.0, 2.0, 0.0, 2.6]], "theater_wall", false)
	_wall("z", 24.0, 28.0, 40.0, 0.0, FOYER_H, TE, [[29.0, 1.6, 0.0, 2.6]], "theater_wall", false)
	_wall("x", -4.0, 0.0, 24.0, 0.0, FOYER_H, TE, [[12.0, 3.0, 0.0, 3.5], [20.0, DOOR_W, UP, UP + DOOR_H]], "theater_wall", false)
	_wall("x", 28.0, 0.0, 24.0, 0.0, FOYER_H, TE, [[6.0, 3.0, 0.0, 3.5], [13.0, 3.0, 0.0, 3.5]], "theater_wall", false)
	# Platea / alas.
	_wall("x", -10.0, 24.0, 76.0, 0.0, SALA_H, TE, [_door(30.0), _door(46.0)], "theater_wall2", false)
	_wall("x", 26.0, 24.0, 76.0, 0.0, SALA_H, TE, [_door(30.0), _door(46.0)], "theater_wall2", false)
	# Zócalo dorado del vestíbulo.
	for z in [-3.83, 27.83]:
		_box(groups.Structure, "Trim", Vector3(12, 1.0, z), Vector3(24, 0.08, 0.04), "gold", false)


# --- Vestíbulo ---------------------------------------------------------------------

func _foyer() -> void:
	# Boletería (x 0-5, z -4..2): ventanilla al vestíbulo.
	_wall("z", 5.0, -4.0, 2.0, 0.0, 3.0, T, [[0.0, 1.6, 1.0, 1.9]], "theater_wall2", true)
	_wall("x", 2.0, 0.0, 5.0 + T / 2, 0.0, 3.0, T, [[2.5, DOOR_W, 0.0, DOOR_H]], "theater_wall2", false)
	_slab(groups.Structure, "BoothCeiling", 0, -4, 5.1, 2.1, 3.1, 0.1, "theater_wall2", false)
	_counter(0.4, 4.6, -0.5, 0.0)
	_prop("chairDesk", Vector3(2.5, 0, -1.5), 0)
	_prop("cardboardBoxClosed", Vector3(0.6, 0, -3.4), 10)
	_point_light(Vector3(2.5, 2.6, -1.0), Color(1.0, 0.8, 0.55), 0.5, 4.0, true)
	_inspect(Vector3(4.6, 1.2, 0.0), ["El talonario de entradas. La última vendida: fila 7, butaca 13. Fecha: hoy.",
		"Todas las demás entradas del talonario están cortadas. Nadie las vendió. Están todas ocupadas."], 1.1)
	# Guardarropa (x 19-24, z -4..2, debajo del entrepiso).
	_wall("z", 19.0, -4.0, 2.0, 0.0, 3.0, T, [[-1.0, 2.4, 1.05, 2.6]], "theater_wall2", false)
	_wall("x", 2.0, 19.0 - T / 2, 24.0, 0.0, 3.0, T, [[21.5, DOOR_W, 0.0, DOOR_H]], "theater_wall2", false)
	_slab(groups.Structure, "CoatCeiling", 18.9, -4, 24, 2.1, 3.1, 0.1, "theater_wall2", false)
	for z in [-3.2, -2.0, -0.8]:
		_prop("coatRackStanding", Vector3(23.0, 0, z), randf_range(0, 360))
	_inspect(Vector3(18.9, 1.3, -1.0), ["Cientos de fichas del guardarropa colgadas en su tablero. Ningún abrigo.",
		"Una sola percha tiene algo: un tapado verde, igual al de la pensión."], 1.2)
	# La araña del techo, que titila.
	_box(groups.Lights, "Chandelier", Vector3(10.0, FOYER_H - 1.0, 12.0), Vector3(2.0, 0.8, 2.0), "gold", false)
	_box(groups.Lights, "ChandelierGlow", Vector3(10.0, FOYER_H - 1.5, 12.0), Vector3(1.5, 0.15, 1.5), "footlight", false)
	_point_light(Vector3(10.0, FOYER_H - 2.0, 12.0), Color(1.0, 0.78, 0.5), 1.6, 16.0, true)
	for p in [Vector3(4.0, 4.0, 4.0), Vector3(4.0, 4.0, 22.0)]:
		_point_light(p, Color(1.0, 0.72, 0.45), 0.7, 9.0)
	# Afiches enmarcados.
	for p: Array in [[Vector3(0.2, 2.2, 6.0), 90.0], [Vector3(0.2, 2.2, 18.0), 90.0], [Vector3(10.0, 2.2, -3.8), 0.0]]:
		var pos: Vector3 = p[0]
		var facing: float = p[1]
		var normal := Basis(Vector3.UP, deg_to_rad(facing)) * Vector3(0, 0, 0.03)
		var frame := Vector3(0.04, 1.7, 1.2) if facing == 90.0 else Vector3(1.2, 1.7, 0.04)
		var poster := Vector3(0.02, 1.5, 1.0) if facing == 90.0 else Vector3(1.0, 1.5, 0.02)
		_box(groups.Structure, "PosterFrame", pos, frame, "gold", false)
		_box(groups.Structure, "Poster", pos + normal, poster, "poster", false)
		_label(groups.Structure, "LA PALOMA\n\nFunción única\n3:15", pos + normal * 2.0, facing, Color(0.3, 0.08, 0.06), 0.006)
	for p in [Vector3(1.0, 0, 8.0), Vector3(1.0, 0, 16.0), Vector3(15.0, 0, 27.0)]:
		_prop("pottedPlant", p, 0, {"tint": Color(0.35, 0.3, 0.25)})
	# La gorra de Sosa y la escopeta de la comisaría, en un banco.
	_prop("benchCushion", Vector3(8.0, 0, 27.3), 180, {"tint": Color(0.6, 0.25, 0.22)})
	_prop("benchCushion", Vector3(3.0, 0, 27.3), 180, {"tint": Color(0.6, 0.25, 0.22)})
	_box(groups.Props, "PoliceCap", Vector3(8.3, 0.55, 27.3), Vector3(0.28, 0.1, 0.25), "dark", false)
	_inspect(Vector3(8.0, 0.8, 27.0), ["Una gorra de policía y la escopeta de la comisaría, apoyadas con cuidado en el banco.",
		"Como si alguien las hubiera dejado para entrar a la función sin molestar a nadie."], 1.2)
	# Puerta de vuelta a la avenida (dos hojas entreabiertas).
	var door := Area3D.new()
	door.set_script(load("res://scripts/world/zone_door.gd"))
	door.set("target_scene", "res://scenes/levels/street.tscn")
	door.set("target_spawn", &"from_theater")
	door.set("radius", 1.4)
	door.position = Vector3(0.6, 1.2, 12.0)
	_add(groups.Inspectables, door, "StreetDoor")
	_zone_door_visuals(door, Vector3(TE / 2 + 0.02, 0, 11.25), 90.0, "door_wood_open", "", 1.5, 3.4)
	_door_prop(door, "OpenDoorB", "door_wood_open", Vector3(TE / 2 + 0.02, 0, 12.75) - door.position, 90.0, 1.5, 3.4, true)
	_prop("rugRectangle", Vector3(4.0, 0.005, 12.0), 90, {"tint": Color(0.6, 0.18, 0.15)})


## La escalera imperial y el entrepiso (x 16-24, a 5 m), con columnas.
func _upper_floor() -> void:
	_slab(groups.Structure, "Mezzanine", 16, -4, 24, 28, UP, 0.3, "carpet")
	_ramp(4.0, 0.0, 16.0, UP, 22.0, 4.0)
	for z in [20.0, 24.0]:
		_box(groups.Structure, "StairBalustrade", Vector3(10.0, UP / 2 + 0.6, z), Vector3(12.4, 0.08, 0.1), "gold", false)
		_box(groups.Structure, "StairSide", Vector3(10.0, UP / 4, z), Vector3(12.0, UP / 2, 0.15), "theater_wall2")
	_railing("z", 16.0, -4.0, 20.0, UP)
	_railing("z", 16.0, 24.0, 28.0, UP)
	for z in [-2.0, 4.0, 10.0, 16.0]:
		_box(groups.Structure, "Column", Vector3(16.3, (UP - 0.3) / 2, z), Vector3(0.5, UP - 0.3, 0.5), "gold")
	# La administración, arriba del salón de los espejos (x 0-24, z -24..-4).
	_slab(groups.Structure, "AdminFloor", 0, -24, 24, -4, UP, 0.3, "wood")
	_wall("x", -14.0, 0.0, 24.0, UP, 4.2, T, [_door(5.0), _door(17.0)], "theater_wall2", false)
	_wall("z", 10.0, -24.0, -14.0, UP, 4.2, T, [], "theater_wall2", false)
	_point_light(Vector3(12.0, UP + 3.4, -9.0), Color(1.0, 0.8, 0.55), 0.6, 9.0, true)
	for z in [-12.6, -11.0]:
		for i in 6:
			_prop("file_cabinet", Vector3(2.0 + i * 3.4, UP, z if i % 2 == 0 else z - 0.2), 0)
	_inspect(Vector3(12.0, UP + 1.0, -9.0), ["El archivo de la administración. Programas, contratos, planillas de recaudación.",
		"La planilla de la función del 14 de marzo de 1979 dice: \"Localidades vendidas: 1. Recaudación: 0\"."], 1.4)
	# Oficina del director (x 0-10) y contaduría (x 10-24).
	_prop("desk", Vector3(5.0, UP, -22.0), 0)
	_prop("chairDesk", Vector3(5.0, UP, -22.9), 180)
	_prop("loungeChair", Vector3(8.4, UP, -16.0), -120)
	_prop("bookcaseClosedWide", Vector3(0.45, UP, -19.0), 90)
	_point_light(Vector3(5.0, UP + 2.2, -21.0), Color(1.0, 0.75, 0.5), 0.6, 5.0, true)
	_inspect(Vector3(5.0, UP + 1.0, -21.6), ["El escritorio del director. Una carta sin enviar, a la policía: \"No sé cómo explicarlo. Ella sigue en el teatro.\"",
		"Fechada en abril de 1979. Abajo, otra fecha, de este año, con la misma letra temblorosa: \"Sigue\"."], 1.2)
	for x in [13.0, 17.0, 21.0]:
		_prop("desk", Vector3(x, UP, -20.0), 0)
		_prop("chairDesk", Vector3(x, UP, -20.9), 180)
	_prop("tall_cabinet", Vector3(23.5, UP, -16.0), -90)


func _galleries() -> void:
	# Salón de los espejos (x 0-24, z -24..-4).
	for x in [4.0, 10.0, 16.0, 22.0]:
		_box(groups.Structure, "Mirror", Vector3(x, 2.2, -23.82), Vector3(2.4, 3.0, 0.04), "mirror", false)
		_box(groups.Structure, "MirrorFrame", Vector3(x, 2.2, -23.86), Vector3(2.6, 3.2, 0.04), "gold", false)
	for z in [-20.0, -14.0, -8.0]:
		_box(groups.Structure, "Mirror", Vector3(0.18, 2.2, z), Vector3(0.04, 3.0, 2.4), "mirror", false)
	for p in [[Vector3(6.0, 0, -12.0), 90.0], [Vector3(18.0, 0, -12.0), -90.0], [Vector3(12.0, 0, -20.0), 0.0]]:
		_prop("loungeSofa", p[0], p[1], {"tint": Color(0.65, 0.25, 0.25)})
	_prop("tableCoffee", Vector3(12.0, 0, -12.0))
	for p in [Vector3(1.0, 0, -5.0), Vector3(23.0, 0, -5.0), Vector3(1.0, 0, -23.0)]:
		_prop("pottedPlant", p, 0, {"tint": Color(0.35, 0.3, 0.25)})
	_point_light(Vector3(12.0, 3.6, -14.0), Color(1.0, 0.72, 0.5), 0.8, 12.0, true)
	_inspect(Vector3(10.0, 1.6, -23.2), ["El salón de los espejos. En todos, el salón está lleno de gente de gala, esperando.",
		"Del lado de acá no hay nadie."], 1.6)
	# Galería de retratos y bar (x 0-24, z 28..40).
	for i in 6:
		var x := 2.0 + i * 3.5
		_box(groups.Structure, "PortraitFrame", Vector3(x, 2.2, 39.82), Vector3(1.0, 1.3, 0.04), "gold", false)
		_box(groups.Structure, "Portrait", Vector3(x, 2.2, 39.78), Vector3(0.8, 1.1, 0.02), "photo" if i % 2 == 0 else "photo2", false)
	_counter(2.0, 10.0, 31.0, 0.0)
	for x in [3.0, 5.5, 8.0]:
		_prop("chair", Vector3(x, 0, 32.2), 180)
	_prop("kitchenFridge", Vector3(0.5, 0, 29.0), 90)
	for p in [Vector3(15.0, 0, 33.0), Vector3(19.0, 0, 35.5)]:
		_prop("table", p)
		_prop("chair", p + Vector3(0, 0, 0.8), 180)
	_point_light(Vector3(6.0, 3.6, 31.5), Color(1.0, 0.7, 0.45), 0.7, 8.0, true)
	_point_light(Vector3(17.0, 3.6, 36.0), Color(1.0, 0.7, 0.45), 0.6, 8.0)
	_inspect(Vector3(14.0, 1.6, 39.4), ["Retratos de los artistas del Imperio. El del medio está vacío: queda el marco y una plaquita.",
		"\"Elena M. de Sosa, soprano. 1979\"."], 1.4)
	_inspect(Vector3(6.0, 1.2, 30.6), ["En la barra hay una copa de champán con marca de rouge, todavía con burbujas."], 1.2)


## Las alas: un pasillo y tres salas a cada lado de la platea. Al fondo, una rampa sube al
## nivel de las bambalinas.
func _wings() -> void:
	for side in [-1.0, 1.0]:
		var corridor_z: float = -12.0 if side < 0 else 28.0
		var wall_z: float = -14.0 if side < 0 else 30.0
		var far_z: float = -24.0 if side < 0 else 40.0
		_wall("x", wall_z, 24.0, 70.0, 0.0, 4.5, T, [_door(34.0), _door(52.0), _door(66.0)], "theater_wall2", false)
		for x in [44.0, 60.0]:
			_wall("z", x, minf(wall_z, far_z), maxf(wall_z, far_z), 0.0, 4.5, T, [], "theater_wall2", false)
		_wall("z", 70.0, minf(wall_z, far_z), maxf(wall_z, far_z), 0.0, 4.5, T, [], "theater_wall2", false)
		# La rampa del pasillo (x 70-76) hasta el hombro, y la pared de la sala de máquinas al este.
		_ramp(70.0, 0.0, 76.0, S, corridor_z, 3.6)
		_wall("z", 76.0, minf(wall_z, far_z), maxf(wall_z, far_z), 0.0, S + BACK_H, TE, [], "theater_wall2", false)
		_wall("x", wall_z, 70.0, 76.0, 0.0, S + BACK_H, T, [], "theater_wall2", false)
		for x in [32.0, 50.0, 64.0]:
			_point_light(Vector3(x, 3.6, corridor_z), Color(0.9, 0.62, 0.42), 0.55, 7.0, x == 50.0)
	_room_wings_content()


func _room_wings_content() -> void:
	# Norte: sala de ensayo grande (x 24-44), escuela de danza (44-60), sala de máquinas (60-70).
	_box(groups.Props, "UprightPiano", Vector3(34.0, 0.65, -23.4), Vector3(1.5, 1.3, 0.55), "piano")
	for i in 10:
		_prop("chair", Vector3(28.0 + (i % 5) * 2.0, 0, -18.0 - (i / 5) * 2.0), 0)
	_point_light(Vector3(34.0, 3.4, -19.0), Color(0.95, 0.8, 0.6), 0.6, 9.0, true)
	_inspect(Vector3(34.0, 1.2, -22.8), ["Un piano vertical con la tapa cerrada con llave. Adentro, alguien practica escalas, muy despacio."], 1.2)
	for x in [46.0, 50.0, 54.0, 58.0]:
		_box(groups.Structure, "DanceMirror", Vector3(x, 1.8, -23.82), Vector3(3.6, 2.6, 0.04), "mirror", false)
	_box(groups.Structure, "Barre", Vector3(52.0, 1.05, -23.5), Vector3(14.0, 0.06, 0.06), "rail", false)
	_point_light(Vector3(52.0, 3.4, -19.0), Color(0.85, 0.9, 1.0), 0.5, 9.0, true)
	_inspect(Vector3(52.0, 1.3, -23.0), ["La escuela de danza. En los espejos hay marcas de manos a la altura de la barra. De este lado no hay ninguna."], 1.4)
	for p in [Vector3(63.0, 0, -22.0), Vector3(67.0, 0, -22.0)]:
		_box(groups.Props, "AirHandler", p + Vector3.UP * 1.2, Vector3(3.0, 2.4, 2.0), "metal")
	_box(groups.Structure, "Duct", Vector3(65.0, 3.8, -18.0), Vector3(1.0, 0.8, 8.0), "metal", false)
	_prop("portable_generator" if upgrades.has("portable_generator") else "washer", Vector3(65.0, 0, -15.6), 0)
	# Sur: museo del teatro (x 24-44), bar de artistas (44-60), archivo de partituras (60-70).
	for i in 5:
		var p := Vector3(27.0 + i * 3.6, 0, 35.0)
		_box(groups.Props, "Vitrine", p + Vector3.UP * 0.5, Vector3(1.4, 1.0, 0.8), "counter")
		_box(groups.Props, "VitrineGlass", p + Vector3.UP * 1.3, Vector3(1.4, 0.6, 0.8), "mirror", false)
	_point_light(Vector3(34.0, 3.4, 35.0), Color(1.0, 0.8, 0.6), 0.6, 9.0)
	_inspect(Vector3(34.2, 1.2, 34.4), ["El museo del teatro. En una vitrina, el vestido de gala de \"La Paloma\". Está húmedo, como recién usado."], 1.3)
	_counter(46.0, 52.0, 38.6, 0.0)
	for p in [Vector3(48.0, 0, 33.0), Vector3(55.0, 0, 33.5)]:
		_prop("table", p)
		_prop("chair", p + Vector3(0.8, 0, 0), -90)
	_point_light(Vector3(52.0, 3.4, 35.0), Color(1.0, 0.65, 0.4), 0.6, 8.0, true)
	for x in [61.5, 63.5, 65.5, 67.5]:
		_prop("bookcaseOpen", Vector3(x, 0, 39.5), 180)
	for p in [Vector3(62.0, 0, 33.0), Vector3(66.0, 0, 34.0)]:
		_prop("cardboardBoxOpen", p, randf_range(0, 60))
	_inspect(Vector3(64.0, 1.2, 38.8), ["Partituras. Todas de \"La Paloma\", en todas las tonalidades posibles. Algunas en tonalidades que no existen."], 1.3)


# --- La platea ---------------------------------------------------------------------

func _hall() -> void:
	# Butacas: 23 filas, tres bloques, mirando al escenario (+X).
	for row in 23:
		var x := 30.0 + row * 1.15
		for block: Vector2 in [Vector2(-8.6, -0.4), Vector2(1.4, 15.6), Vector2(17.4, 24.6)]:
			var width := block.y - block.x
			var z := (block.x + block.y) / 2
			_box(groups.Props, "SeatRow", Vector3(x, 0.22, z), Vector3(0.5, 0.44, width), "velvet")
			_box(groups.Props, "SeatBack", Vector3(x - 0.3, 0.55, z), Vector3(0.1, 1.1, width), "velvet")
			_box(groups.Props, "SeatEnd", Vector3(x - 0.05, 0.4, block.x - 0.01), Vector3(0.72, 0.8, 0.06), "gold", false)
			_box(groups.Props, "SeatEnd", Vector3(x - 0.05, 0.4, block.y + 0.01), Vector3(0.72, 0.8, 0.06), "gold", false)
	_label(groups.Props, "FILA 7", Vector3(30.0 + 6 * 1.15 - 0.36, 1.05, 3.2), -90, Color(0.8, 0.7, 0.45), 0.005)
	_inspect(Vector3(30.0 + 6 * 1.15, 0.8, 3.5), ["Fila 7, butaca 13. Está tibia. El resto de la sala está helada."], 1.2)
	# Luces de pasillo, apliques, carteles de salida.
	for x in [28.0, 36.0, 44.0, 52.0]:
		for z in [-9.8, 0.5, 16.5, 25.8]:
			_box(groups.Lights, "AisleLight", Vector3(x, 0.3, z), Vector3(0.2, 0.1, 0.05), "footlight", false)
	for x in [30.0, 40.0, 50.0]:
		for z in [-9.75, 25.75]:
			_box(groups.Lights, "Sconce", Vector3(x, 3.0, z), Vector3(0.3, 0.4, 0.1), "footlight", false)
			_point_light(Vector3(x, 3.0, z + (0.6 if z < 0 else -0.6)), Color(1.0, 0.7, 0.45), 0.8, 8.0, x == 40.0)
	for z in [2.0, 22.0]:
		_prop("exit_sign", Vector3(24.2, 3.2, z), -90)
	_point_light(Vector3(40.0, 8.0, 8.0), Color(0.8, 0.35, 0.3), 0.7, 16.0, true)
	# El pullman (x 24-36, a 5 m): filas escalonadas, pasillo central y la baranda.
	_slab(groups.Structure, "Pullman", 24, -10, 36, 26, UP, 0.35, "carpet")
	for row in 6:
		var x := 27.5 + row * 1.3
		var h := row * 0.2
		for block: Vector2 in [Vector2(-7.5, 6.8), Vector2(9.2, 23.5)]:
			var z := (block.x + block.y) / 2
			_box(groups.Props, "BalconySeat", Vector3(x, UP + h + 0.22, z), Vector3(0.5, 0.44, block.y - block.x), "velvet")
			if row > 0:
				_box(groups.Props, "BalconyRiser", Vector3(x + 0.1, UP + h / 2, z), Vector3(1.3, h, block.y - block.x), "carpet", false)
	_railing("z", 36.0, -7.5, 23.5, UP)
	# La galería de palcos: un balcón angosto a los dos lados, hasta el escenario.
	for side: Vector2 in [Vector2(-10.0, -7.5), Vector2(23.5, 26.0)]:
		_slab(groups.Structure, "BoxGallery", 36, side.x, 58, side.y, UP, 0.35, "carpet")
		var edge := side.y if side.x < 0 else side.x
		_railing("x", edge, 36.0, 58.0, UP)
		_railing("z", 58.0, side.x, side.y, UP)
		for x in [40.0, 44.0, 48.0, 52.0, 56.0]:
			_box(groups.Structure, "BoxDivider", Vector3(x, UP + 0.6, (side.x + side.y) / 2), Vector3(0.08, 1.2, 1.0), "gold", false)
	_inspect(Vector3(30.0, UP + 1.0, 8.0), ["El pullman. Desde acá se ve todo el escenario. Y la butaca 13 de la fila 7, iluminada aunque no haya luz."], 1.4)
	# Rampas de la platea al escenario, por los costados (cruzan la boca del escenario).
	_ramp(56.0, 0.0, 60.6, S, -8.6, 1.6)
	_ramp(56.0, 0.0, 60.6, S, 24.6, 1.6)


## El escenario: telón, candilejas, piano, la luz fantasma y el jefe.
func _stage() -> void:
	# Boca del escenario: la pared sobre el telón, con la abertura de 16 x 6.5 m y dos pasos laterales.
	_wall("z", 60.0, -10.0, 26.0, 0.0, SALA_H, 0.4, [[8.0, 16.0, S, S + 6.5], [-8.6, 1.8, 0.0, S + 2.4], [24.6, 1.8, 0.0, S + 2.4]],
		"theater_wall2", false)
	_box(groups.Structure, "Proscenium", Vector3(59.75, S + 6.6, 8.0), Vector3(0.12, 0.3, 16.4), "gold", false)
	for z in [1.0, 15.0]:
		_box(groups.Structure, "Curtain", Vector3(60.55, S + 3.25, z), Vector3(0.35, 6.5, 2.0), "velvet", false)
	_box(groups.Structure, "Valance", Vector3(60.55, S + 6.0, 8.0), Vector3(0.3, 1.0, 16.0), "velvet", false)
	for i in 16:
		_box(groups.Lights, "Footlight", Vector3(60.35, S + 0.06, 0.5 + i), Vector3(0.12, 0.08, 0.25), "footlight", false)
	for z in [3.5, 12.5]:
		_point_light(Vector3(61.0, S + 0.4, z), Color(1.0, 0.72, 0.45), 0.9, 7.0, true)
		_point_light(Vector3(67.0, S + 5.5, z), Color(1.0, 0.82, 0.65), 1.6, 13.0)
	var spot := SpotLight3D.new()
	spot.light_color = Color(1.0, 0.88, 0.75)
	spot.light_energy = 3.0
	spot.spot_range = 45.0
	spot.spot_angle = 12.0
	spot.position = Vector3(30.0, 8.0, 8.0)
	_add(groups.Lights, spot, "FollowSpot")
	spot.look_at_from_position(spot.position, Vector3(68.0, S, 8.0))
	# Pared del fondo, con dos puertas al hombro, y el telón de fondo.
	_wall("z", 76.0, -10.0, 26.0, 0.0, SALA_H, T, [[-6.0, DOOR_W, S, S + DOOR_H], [22.0, DOOR_W, S, S + DOOR_H]], "theater_wall2", false)
	_box(groups.Structure, "Backdrop", Vector3(75.6, S + 4.0, 8.0), Vector3(0.05, 8.0, 18.0), "velvet", false)
	# Las trampas del piso del escenario (solo visuales).
	for p in [Vector3(66.0, S + 0.04, 8.0), Vector3(70.0, S + 0.04, 0.0), Vector3(70.0, S + 0.04, 16.0)]:
		_box(groups.Props, "Trapdoor", p, Vector3(1.6, 0.02, 1.6), "planks", false)
	# El piano de cola.
	var piano := Vector3(66.0, S, 2.5)
	_box(groups.Props, "PianoBody", piano + Vector3(0, 0.75, 0), Vector3(1.5, 0.3, 2.1), "piano")
	_box(groups.Props, "PianoLid", piano + Vector3(0.2, 1.25, 0), Vector3(1.4, 0.04, 2.0), "piano", false)
	_box(groups.Props, "PianoKeys", piano + Vector3(-0.8, 0.87, 0), Vector3(0.18, 0.05, 1.4), "keys", false)
	for d in [Vector3(0.6, 0, 0.9), Vector3(0.6, 0, -0.9), Vector3(-0.6, 0, 0)]:
		_box(groups.Props, "PianoLeg", piano + d + Vector3(0, 0.3, 0), Vector3(0.1, 0.6, 0.1), "piano", false)
	_box(groups.Props, "PianoStool", piano + Vector3(-1.3, 0.25, 0), Vector3(0.4, 0.5, 0.5), "piano")
	_inspect(piano + Vector3(-0.9, 1.0, 0), ["Las teclas están tibias. En el atril, la partitura de \"La Paloma\".",
		"Alguien anotó en rojo sobre el pentagrama: otra vez, otra vez, otra vez."], 1.3)
	_label(groups.Props, "LA PALOMA", piano + Vector3(-0.75, 1.25, 0), -90, Color(0.2, 0.15, 0.12), 0.004)
	# La luz fantasma: la lamparita que los teatros dejan prendida en el escenario vacío.
	_box(groups.Props, "GhostLightPole", Vector3(70.0, S + 0.8, 13.0), Vector3(0.05, 1.6, 0.05), "dark", false)
	_box(groups.Props, "GhostLightBase", Vector3(70.0, S + 0.05, 13.0), Vector3(0.4, 0.1, 0.4), "dark", false)
	_box(groups.Props, "GhostLightBulb", Vector3(70.0, S + 1.7, 13.0), Vector3(0.1, 0.14, 0.1), "footlight", false)
	_point_light(Vector3(70.0, S + 1.7, 13.0), Color(1.0, 0.85, 0.6), 0.9, 6.0)
	_inspect(Vector3(70.0, S + 1.0, 13.0), ["La luz fantasma. Dicen que se deja prendida para que los fantasmas puedan actuar cuando no hay nadie.",
		"La lamparita es nueva."], 1.1)
	# Disparador: al acercarse al escenario, ella sale a cantar.
	var trigger := Area3D.new()
	trigger.set_script(load("res://scripts/world/boss_trigger.gd"))
	trigger.set("boss", NodePath("../../Enemies/Singer"))
	trigger.position = Vector3(57.0, 1.5, 8.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10.0, 3.0, 36.0)
	shape.shape = box
	_add(groups.Secrets, trigger, "BossTrigger")
	_add(trigger, shape, "Shape")


# --- Bambalinas --------------------------------------------------------------------

## El hombro (x 76-87, a 1.1 m) y los cuartos del fondo (x 87-96).
func _backstage() -> void:
	var y := S
	# La pared de los cuartos (x 87), con sus puertas, y las divisiones.
	_wall("z", 87.0, -24.0, 40.0, y, BACK_H, T, [_door(-17.0), _door(-6.0), _door(2.5), _door(10.5), _door(16.0),
		[21.5, DOOR_W, 0.0, DOOR_H], _door(29.0), _door(36.5)], "theater_wall", false)
	for z in [-10.0, -2.0, 7.0, 14.0, 18.0, 25.0, 33.0]:
		_wall("x", z, 87.0, 96.0, y, BACK_H, T, [], "theater_wall", false)
	for s: Array in [["TALLER", -17.0], ["SASTRERÍA", -6.0], ["CAMARÍN 3", 2.5], ["CAMARÍN 2", 10.5], ["DEPÓSITO", 16.0],
			["COLECTIVO", 29.0], ["CARGA", 36.5]]:
		_label(groups.Structure, s[0], Vector3(86.88, y + 2.6, s[1]), -90, Color(0.8, 0.7, 0.5), 0.005)
	# El hombro: decorados, cuerdas, contrapesos, la baranda de la escalera al foso.
	for p in [Vector3(78.0, y, -20.0), Vector3(80.5, y, -19.0), Vector3(78.5, y, 32.0)]:
		var flat := _box(groups.Props, "SetFlat", p + Vector3.UP * 1.8, Vector3(0.15, 3.6, 3.0), "plywood" if mats.has("plywood") else "planks")
		flat.rotation_degrees.y = randf_range(-20, 20)
	_box(groups.Props, "PinRail", Vector3(76.35, y + 1.1, 8.0), Vector3(0.15, 0.12, 30.0), "dark")
	for z in [-6.0, -2.0, 2.0, 6.0, 10.0, 14.0, 18.0, 22.0]:
		_box(groups.Structure, "Rope", Vector3(76.5, y + 2.0, z), Vector3(0.03, 4.0, 0.03), "dark", false)
		_box(groups.Props, "Sandbag", Vector3(76.6, y + 0.3, z + 0.4), Vector3(0.3, 0.4, 0.3), "planks", false)
	for p in [Vector3(85.5, y, -22.5), Vector3(85.0, y, -14.0), Vector3(85.6, y, 39.0)]:
		_prop(POLYHAVEN_CRATE, p, randf_range(0, 30), {"h": 0.8})
	_prop("coatRackStanding", Vector3(85.8, y, 5.0), 0)
	_point_light(Vector3(81.0, y + 3.0, -16.0), Color(0.9, 0.7, 0.5), 0.6, 9.0, true)
	_point_light(Vector3(81.0, y + 3.0, 8.0), Color(0.9, 0.7, 0.5), 0.5, 9.0, true)
	_point_light(Vector3(81.0, y + 3.0, 30.0), Color(0.9, 0.7, 0.5), 0.5, 9.0)
	_railing("z", 77.0, 28.0, 38.0, y)
	_railing("z", 80.0, 28.0, 38.0, y)
	_railing("x", 38.0, 77.0, 80.0, y)
	_inspect(Vector3(78.5, y + 1.0, 27.4), ["Una escalera de servicio baja al foso de máquinas. De abajo sube aire tibio y olor a polvo de telón."], 1.2)
	# Taller de escenografía (z -24..-10).
	_prop("desk", Vector3(92.0, y, -22.8), 0, {"tint": Color(0.6, 0.55, 0.5)})
	for p in [Vector3(89.0, y, -14.0), Vector3(94.5, y, -13.0)]:
		var flat := _box(groups.Props, "Flat", p + Vector3.UP * 1.5, Vector3(2.6, 3.0, 0.12), "planks")
		flat.rotation_degrees.y = randf_range(-15, 15)
	for p in [Vector3(95.0, y, -20.0), Vector3(95.2, y, -18.8)]:
		_prop("barrel_03" if upgrades.has("barrel_03") else "trashcan", p, 0, {"h": 0.9})
	_inspect(Vector3(92.0, y + 1.0, -22.4), ["El taller. Una escenografía a medio pintar: la fachada del Hospital San Judas, con todas las ventanas iluminadas."], 1.2)
	# Sastrería (z -10..-2): maniquíes y la mesa de corte.
	_box(groups.Props, "CuttingTable", Vector3(92.0, y + 0.45, -6.0), Vector3(3.0, 0.9, 1.2), "counter")
	for z in [-9.0, -3.0]:
		_box(groups.Props, "Mannequin", Vector3(95.0, y + 0.9, z), Vector3(0.4, 1.8, 0.3), "cloth")
	_prop("coatRackStanding", Vector3(88.0, y, -9.0), 0)
	# Camarín 3, del coro (z -2..7): bancos y espejos.
	_box(groups.Props, "ChorusVanity", Vector3(95.5, y + 0.4, 2.5), Vector3(0.7, 0.8, 6.0), "stage")
	_box(groups.Props, "ChorusMirror", Vector3(95.85, y + 1.6, 2.5), Vector3(0.04, 1.0, 5.6), "mirror", false)
	for z in [0.0, 2.5, 5.0]:
		_prop("chair", Vector3(94.6, y, z), -90)
	_point_light(Vector3(94.0, y + 2.4, 2.5), Color(1.0, 0.8, 0.55), 0.5, 6.0, true)
	# Camarín 2 (z 7..14): tocador con espejo, sillas, un perchero.
	_box(groups.Props, "Vanity", Vector3(95.5, y + 0.4, 10.5), Vector3(0.7, 0.8, 3.0), "stage")
	_box(groups.Props, "VanityMirror", Vector3(95.8, y + 1.6, 10.5), Vector3(0.04, 1.0, 2.6), "mirror", false)
	for i in 8:
		_box(groups.Lights, "MirrorBulb", Vector3(95.75, y + 2.15, 9.35 + i * 0.33), Vector3(0.06, 0.06, 0.06), "footlight", false)
	_point_light(Vector3(94.8, y + 2.0, 10.5), Color(1.0, 0.8, 0.55), 0.6, 5.0, true)
	_prop("chair", Vector3(94.6, y, 9.8), -90)
	_prop("coatRackStanding", Vector3(88.2, y, 13.2), 0)
	_prop("curtain", Vector3(89.5, y, 7.5), 0, {"h": 2.2, "tint": Color(0.55, 0.2, 0.18)})
	# Depósito de utilería (z 14..18).
	for p in [Vector3(95.0, y, 14.8), Vector3(95.0, y, 15.8), Vector3(94.0, y, 17.3), Vector3(88.3, y, 17.4)]:
		_prop(POLYHAVEN_CRATE, p, randf_range(0, 30), {"h": 0.8})
	_prop("bookcaseOpen", Vector3(91.5, y, 17.6), 180)
	_inspect(Vector3(93.0, y + 1.0, 16.0), ["Cabezas de utilería en un estante. Una tiene la cara de alguien que conocés."], 1.3)
	# Camarín colectivo (z 25..33): bancos, lockers.
	for z in [26.5, 27.5, 28.5, 29.5, 30.5]:
		_prop("locker", Vector3(95.5, y, z), -90)
	_prop("bench", Vector3(91.5, y, 29.0), 90)
	_point_light(Vector3(91.5, y + 2.4, 29.0), Color(0.9, 0.8, 0.65), 0.5, 6.0, true)
	# Muelle de carga (z 33..40): el portón al callejón, cerrado con cadena.
	_door_prop(groups.Structure, "DockDoor", "door_chained", Vector3(95.95, y, 36.5), -90.0, 3.0, 3.2)
	for p in [Vector3(89.0, y, 35.0), Vector3(90.0, y, 38.5), Vector3(93.5, y, 39.0)]:
		_prop(POLYHAVEN_CRATE, p, randf_range(0, 30), {"h": 0.8})
	_inspect(Vector3(95.0, y + 1.2, 36.5), ["El portón del muelle de carga. Del otro lado se oye el motor de un camión, en marcha, desde hace días."], 1.4)


const POLYHAVEN_CRATE := "cardboardBoxOpen"


func _camarin_refuge() -> void:
	# La puerta trabada (FlagGate): abre cuando muere el jefe.
	var gate := Node3D.new()
	gate.set_script(load("res://scripts/world/flag_gate.gd"))
	gate.set("flag", &"theater_boss_dead")
	gate.set("locked_text", "La puerta del camarín principal no cede. Mientras ella cante, no va a ceder.")
	gate.set("open_text", "En el fondo del teatro, una puerta se destraba sola.")
	gate.set("open_model", load(DOORS + "door_wood_open.glb"))
	gate.set("open_model_scale", Vector3(DOOR_W / 1.02, DOOR_H / 2.1, 1.0))
	gate.set("open_model_yaw", -90.0)
	gate.position = Vector3(45.0 + CAM_DX, S, 12.5 + CAM_DZ)
	_add(groups.Structure, gate, "CamarinGate")
	_box(gate, "Door", Vector3(0, 1.2, 0), Vector3(0.1, 2.4, DOOR_W), "stage", true, false)
	_door_prop(gate, "Chained", "door_chained", Vector3(-0.06, 0, 0), -90.0, DOOR_W, DOOR_H)
	_label(groups.Structure, "PRIMERA ACTRIZ", Vector3(44.92 + CAM_DX, S + 2.5, 12.5 + CAM_DZ), -90, Color(0.8, 0.65, 0.35), 0.005)

	var zone := Area3D.new()
	zone.set_script(RefugeScript)
	zone.set("use_shelter", true)
	zone.set("refuge_id", REFUGE)
	zone.position = Vector3(49.6 + CAM_DX, S + 1.6, 12.5 + CAM_DZ)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8.6, 3.2, 6.6)
	shape.shape = box
	_add(groups.Refuge, zone, "RefugeZone")
	_add(zone, shape, "Shape")

	# Fijo: el tocador de la primera actriz, un diván, un biombo.
	_box(groups.Refuge, "StarVanity", Vector3(49.5 + CAM_DX, S + 0.4, 15.5 + CAM_DZ), Vector3(3.0, 0.8, 0.7), "stage")
	_box(groups.Refuge, "StarMirror", Vector3(49.5 + CAM_DX, S + 1.6, 15.84 + CAM_DZ), Vector3(2.6, 1.0, 0.04), "mirror", false)
	_prop("loungeSofa", Vector3(47.2 + CAM_DX, S, 9.8 + CAM_DZ), 0, {"tint": Color(0.65, 0.25, 0.25)})
	_prop("chair", Vector3(49.5 + CAM_DX, S, 14.7 + CAM_DZ), 0)
	_pickup("LetterMarta3", "letter_marta_03", Vector3(50.3 + CAM_DX, S + 0.82, 15.5 + CAM_DZ))
	_inspect(Vector3(49.5 + CAM_DX, S + 1.2, 15.2 + CAM_DZ), ["El espejo del camarín. Tu reflejo tarda un instante de más en moverse."], 1.2)
	_prop("radio", Vector3(48.4 + CAM_DX, S + 0.8, 15.5 + CAM_DZ), 180)
	_station_t(Vector3(48.4 + CAM_DX, S + 1.0, 15.2 + CAM_DZ), groups.Refuge, "RadioStation", 3)

	# El plano, clavado en el biombo de la entrada.
	_box(groups.Refuge, "BlueprintBoard", Vector3(46.0 + CAM_DX, S + 1.6, 9.12 + CAM_DZ), Vector3(1.0, 0.7, 0.03), "cork", false)
	_box(groups.Refuge, "BlueprintPaper", Vector3(46.0 + CAM_DX, S + 1.62, 9.14 + CAM_DZ), Vector3(0.8, 0.5, 0.01), "paper", false)
	_label(groups.Refuge, "PLANO", Vector3(46.0 + CAM_DX, S + 1.78, 9.16 + CAM_DZ), 0, Color(0.25, 0.2, 0.3), 0.008, 16)
	_station_t(Vector3(46.0 + CAM_DX, S + 1.2, 9.7 + CAM_DZ), groups.Refuge, "BlueprintStation", 0, 1.1)

	var warm := Color(1.0, 0.7, 0.42)
	# Fuego: brasero de utilería -> estufa de hierro.
	var fire := _slot_t("fire", "SlotFire", Vector3(53.0 + CAM_DX, S, 14.8 + CAM_DZ))
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
	var power := _slot_t("power", "SlotPower", Vector3(52.5 + CAM_DX, S, 10.0 + CAM_DZ))
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
	var bed := _slot_t("bed", "SlotBed", Vector3(47.0 + CAM_DX, S, 13.2 + CAM_DZ))
	var b0 := _only(bed, 0)
	_box(b0, "Mattress", Vector3(0, 0.08, 0), Vector3(0.95, 0.16, 2.0), "cloth", false)
	_inspect(Vector3(0, 0.3, 0), ["Un colchón de utilería, relleno de papel de diario. (Ver el plano.)"], 1.0, b0)
	_prop("bedSingle", Vector3.ZERO, 0, {"parent": _only(bed, 1)})
	var b2 := _only(bed, 2)
	_prop("bedSingle", Vector3.ZERO, 0, {"parent": b2})
	_box(b2, "Blanket", Vector3(0, 0.47, 0.25), Vector3(0.72, 0.06, 1.3), "velvet", false)
	_station_t(Vector3(0.6, 0.5, 0), _from(bed, 1), "RestStation", 2, 1.1)

	# Ventana: la niebla pegada al vidrio -> tablones -> cortinas de terciopelo.
	var windows := _slot_t("windows", "SlotWindows", Vector3(53.8 + CAM_DX, S, 12.5 + CAM_DZ))
	var w1 := _from(windows, 1)
	for y in [1.15, 1.5, 1.85, 2.2]:
		_box(w1, "Plank", Vector3(0, y, randf_range(-0.05, 0.05)), Vector3(0.04, 0.2, 1.6), "planks", false)
	var w2 := _only(windows, 2)
	for dz in [-1.0, 1.0]:
		_prop("curtain", Vector3(-0.1, 0, dz), 90, {"parent": w2, "h": 2.4, "tint": Color(0.6, 0.12, 0.1)})

	# Decoración: fotos de funciones viejas -> flores y alfombra.
	var decor := _slot_t("decor", "SlotDecor", Vector3.ZERO)
	var d1 := _from(decor, 1)
	for pic in [[Vector3(49.0 + CAM_DX, S + 1.7, 9.12 + CAM_DZ), "photo"], [Vector3(50.0 + CAM_DX, S + 1.55, 9.12 + CAM_DZ), "photo2"], [Vector3(51.0 + CAM_DX, S + 1.8, 9.12 + CAM_DZ), "photo"]]:
		_box(d1, "Frame", pic[0], Vector3(0.42, 0.5, 0.03), "gold", false)
		_box(d1, "Photo", pic[0] + Vector3(0, 0, 0.04), Vector3(0.3, 0.38, 0.01), pic[1], false)
	var d2 := _from(decor, 2)
	_prop("rugRectangle", Vector3(49.8 + CAM_DX, S + 0.005, 12.5 + CAM_DZ), 90, {"parent": d2, "tint": Color(0.6, 0.3, 0.25)})
	_prop("pottedPlant", Vector3(53.3 + CAM_DX, S, 15.3 + CAM_DZ), 0, {"parent": d2})
	_prop("plantSmall1", Vector3(50.8 + CAM_DX, S + 0.8, 15.5 + CAM_DZ), 0, {"parent": d2})

	# Alijo: el mismo de siempre (viaja con la mudanza), en el rincón de la entrada.
	var stash := _slot_t("stash", "SlotStash", Vector3(45.6 + CAM_DX, S, 15.3 + CAM_DZ))
	_stash_visuals(stash, 90.0)
	_station_t(Vector3(0.6, 0.7, 0), _from(stash, 0), "StashStation", 4, 1.0)




# --- El foso de máquinas (bajo el escenario) ---------------------------------------

func _machinery_pit() -> void:
	var y := PIT
	var h := S - 0.3 - PIT
	# Paredes del foso (las exteriores, del piso del foso a la losa del escenario).
	_wall("z", 60.0, -10.0, 40.0, y, h, TE, [], "theater_wall2", false)
	_wall("x", -10.0, 60.0, 96.0, y, h, TE, [], "theater_wall2", false)
	_wall("x", 40.0, 60.0, 96.0, y, h, TE, [], "theater_wall2", false)
	_wall("z", 96.0, -10.0, 40.0, y, h, TE, [], "theater_wall2", false)
	_wall("z", 76.0, -10.0, 40.0, y, h, T, [_door(0.0), _door(20.0)], "theater_wall2", false)
	_wall("x", 26.0, 60.0, 76.0, y, h, T, [], "theater_wall2", false)
	_wall("x", 15.0, 76.0, 96.0, y, h, T, [_door(86.0)], "theater_wall2", false)
	_wall("x", 28.0, 76.0, 96.0, y, h, T, [_door(83.0)], "theater_wall2", false)
	# La escalera desde el hombro (x 77-80, de z 28 a z 38).
	_ramp_z(28.0, S, 38.0, PIT, 78.5, 2.6, 14, "concrete")
	for x in [76.95, 80.05]:
		_box(groups.Structure, "PitStairWall", Vector3(x, (PIT + S - 0.3) / 2, 33.0), Vector3(0.1, S - 0.3 - PIT, 10.0), "theater_wall2")
	# Debajo del escenario: los mecanismos de las trampas, ruedas, cuerdas.
	for p in [Vector3(66.0, y, 8.0), Vector3(70.0, y, 0.0), Vector3(70.0, y, 16.0)]:
		_box(groups.Props, "TrapLift", p + Vector3.UP * (h / 2), Vector3(1.4, h, 1.4), "metal")
		_box(groups.Props, "TrapPlatform", p + Vector3.UP * 0.25, Vector3(1.8, 0.5, 1.8), "planks")
	for z in [-6.0, 4.0, 22.0]:
		_box(groups.Props, "Wheel", Vector3(63.0, y + 1.4, z), Vector3(0.4, 2.8, 2.8), "dark")
		_box(groups.Props, "Axle", Vector3(64.5, y + 1.4, z), Vector3(3.0, 0.2, 0.2), "metal", false)
	for x in [62.0, 68.0, 74.0]:
		_box(groups.Structure, "Beam", Vector3(x, S - 0.5, 15.0), Vector3(0.3, 0.4, 50.0), "planks", false)
	_point_light(Vector3(66.0, y + 3.0, 8.0), Color(0.9, 0.6, 0.4), 0.6, 10.0, true)
	_point_light(Vector3(70.0, y + 3.0, 26.0), Color(0.8, 0.7, 0.6), 0.4, 9.0, true)
	_inspect(Vector3(66.0, y + 1.0, 9.6), ["El mecanismo de la trampa central. Por acá subía la cantante, en la escena final, como si saliera del suelo.",
		"Las cuerdas están cortadas. Alguien la quiso dejar arriba."], 1.4)
	# Utilería vieja (x 76-96, z -10..15): decorados de otras temporadas.
	for p in [Vector3(80.0, y, -6.0), Vector3(84.0, y, -7.0), Vector3(90.0, y, 2.0), Vector3(94.0, y, 10.0)]:
		var flat := _box(groups.Props, "OldFlat", p + Vector3.UP * 1.5, Vector3(3.0, 3.0, 0.12), "planks")
		flat.rotation_degrees.y = randf_range(-40, 40)
	for x in [78.0, 81.0, 84.0]:
		_prop("bookcaseOpen", Vector3(x, y, 14.4), 180)
	for p in [Vector3(92.0, y, -8.5), Vector3(93.2, y, -8.0), Vector3(88.0, y, 6.0)]:
		_box(groups.Props, "Mannequin", p + Vector3.UP * 0.9, Vector3(0.4, 1.8, 0.3), "cloth")
	_point_light(Vector3(86.0, y + 3.0, 2.0), Color(0.8, 0.75, 0.65), 0.5, 10.0, true)
	_inspect(Vector3(92.6, y + 1.2, -7.4), ["Maniquíes con vestuario de 1979. Uno tiene puesto el uniforme del agente Sosa, recién planchado."], 1.2)
	# Calderas (z 15..28).
	for x in [81.0, 86.0, 91.0]:
		_box(groups.Props, "Boiler", Vector3(x, y + 1.3, 22.0), Vector3(2.2, 2.6, 2.4), "dark")
	_point_light(Vector3(86.0, y + 0.6, 23.4), Color(1.0, 0.45, 0.2), 0.5, 5.0, true)
	_loop_sound(groups.Props, "generator", Vector3(86.0, y + 1.0, 22.0), -14.0)


# --- Secretos ----------------------------------------------------------------------

func _secrets_theater() -> void:
	# Inquieto: en la pared del vestíbulo aparece la butaca que te espera.
	var hint := Node3D.new()
	hint.set_script(GatedScript)
	hint.set("threshold", 1)
	_add(groups.Secrets, hint, "WallSymbol")
	_label(hint, "FILA 7\nBUTACA 13", Vector3(10.0, 4.0, 27.82), 180, Color(0.55, 0.05, 0.03), 0.011)
	# Quebrado: la pared de la galería se abre a una sala de ensayo que no figura en los planos.
	var lying := Node3D.new()
	lying.set_script(GatedScript)
	lying.set("mode", 1)
	_add(groups.Secrets, lying, "LyingWall")
	var wall: StaticBody3D = GreyBoxScript.new()
	wall.set("size", Vector3(2.0 - 0.16, DOOR_H - 0.08, TE))
	wall.set("material", mats.theater_wall)
	wall.position = Vector3(7.0, (DOOR_H - 0.08) / 2, 40.0)
	_add(lying, wall, "Wall")
	# La sala de ensayo (x 4-10, z 40-44).
	_floor(4, 40, 10, 44, 0.0, "stage")
	_slab(groups.Structure, "RehearsalCeiling", 4, 40, 10, 44.2, 3.1, 0.1, "theater_wall2", false)
	_wall("x", 44.0, 4.0 - T / 2, 10.0 + T / 2, 0.0, 3.0, T, [], "theater_wall2", false)
	_wall("z", 4.0, 40.0, 44.0, 0.0, 3.0, T, [], "theater_wall2", false)
	_wall("z", 10.0, 40.0, 44.0, 0.0, 3.0, T, [], "theater_wall2", false)
	_box(groups.Props, "UprightPiano2", Vector3(7.0, 0.65, 43.6), Vector3(1.5, 1.3, 0.55), "piano")
	_box(groups.Props, "UprightKeys", Vector3(7.0, 0.78, 43.25), Vector3(1.3, 0.05, 0.2), "keys", false)
	_point_light(Vector3(7.0, 2.5, 42.5), Color(0.9, 0.5, 0.4), 0.5, 4.0, true)
	_pickup("Program", "letter_program_01", Vector3(6.6, 1.33, 43.6))
	_pickup("Shells5", "ammo_shells", Vector3(8.6, 0.05, 41.0), 6)
	# Quebrado: el público. Figuras paradas en los pasillos de la platea, mirando al escenario.
	var audience := Node3D.new()
	audience.set_script(GatedScript)
	audience.set("threshold", 2)
	_add(groups.Secrets, audience, "Audience")
	for p in [Vector3(34.0, 0, 0.5), Vector3(40.0, 0, 16.5), Vector3(46.0, 0, -9.5), Vector3(52.0, 0, 25.5),
			Vector3(30.0, UP, 8.0), Vector3(44.0, UP, 24.8)]:
		_instance("res://scenes/enemies/horror_placeholder.tscn", audience, "Figure", p)
	_label(audience, "ELLA CANTA PARA VOS", Vector3(60.75, S + 4.0, 8.0), -90, Color(0.6, 0.05, 0.03), 0.014)
	# Quebrado: el camarín 13, en el foso, que no existe en ningún plano.
	var cam13 := Node3D.new()
	cam13.set_script(GatedScript)
	cam13.set("mode", 1)
	_add(groups.Secrets, cam13, "Camarin13Wall")
	var w13: StaticBody3D = GreyBoxScript.new()
	w13.set("size", Vector3(T + 0.04, DOOR_H - 0.08, DOOR_W - 0.16))
	w13.set("material", mats.theater_wall2)
	w13.position = Vector3(89.0, PIT + (DOOR_H - 0.08) / 2, 36.0)
	_add(cam13, w13, "Wall")
	_wall("z", 89.0, 28.0, 40.0, PIT, S - 0.3 - PIT, T, [[36.0, DOOR_W, 0.0, DOOR_H]], "theater_wall2", false)
	_label(groups.Structure, "13", Vector3(88.88, PIT + 2.6, 36.0), -90, Color(0.75, 0.6, 0.35), 0.01)
	_box(groups.Props, "Vanity13", Vector3(95.5, PIT + 0.4, 36.0), Vector3(0.7, 0.8, 3.0), "stage")
	_box(groups.Props, "Mirror13", Vector3(95.85, PIT + 1.6, 36.0), Vector3(0.04, 1.0, 2.6), "mirror", false)
	_box(groups.Props, "Dress13", Vector3(92.0, PIT + 1.0, 39.4), Vector3(0.6, 2.0, 0.3), "velvet", false)
	_point_light(Vector3(94.0, PIT + 2.2, 36.0), Color(1.0, 0.6, 0.45), 0.6, 6.0, true)
	_inspect(Vector3(95.0, PIT + 1.2, 36.0), ["El camarín 13. En el espejo, escrito con rouge: \"Para cuando vuelvas, hijo\".",
		"Las flores del tocador están frescas. La tarjeta dice \"Rodolfo\"."], 1.2)
	var cam13_items := Node3D.new()
	cam13_items.set_script(GatedScript)
	_add(groups.Secrets, cam13_items, "Camarin13")
	_instance("res://scenes/world/pickup.tscn", cam13_items, "Cam13Kit", Vector3(94.6, PIT + 0.85, 35.4),
		{"item": load("res://assets/items/medicine_kit.tres"), "count": 1})
	_instance("res://scenes/world/pickup.tscn", cam13_items, "Cam13Shells", Vector3(93.0, PIT + 0.05, 38.4),
		{"item": load("res://assets/items/ammo_shells.tres"), "count": 8})


func _places() -> void:
	var places := [
		["theater_foyer", 0, -4, 24, 28, 0.0], ["theater_mirrors", 0, -24, 24, -4, 0.0], ["theater_gallery", 0, 28, 24, 40, 0.0],
		["theater_north_wing", 24, -24, 76, -10, 0.0], ["theater_south_wing", 24, 26, 76, 40, 0.0],
		["theater_hall", 24, -10, 60, 26, 0.0], ["theater_pullman", 24, -10, 36, 26, UP], ["theater_admin", 0, -24, 24, -4, UP],
		["theater_stage", 60, -10, 76, 26, S], ["theater_backstage", 76, -24, 87, 40, S], ["theater_dressing", 87, -24, 96, 18, S],
		["theater_camarin", 87, 18, 96, 25, S], ["theater_dock", 87, 25, 96, 40, S], ["theater_pit", 60, -10, 96, 40, PIT],
		["theater_rehearsal", 4, 40, 10, 44, 0.0],
	]
	var parent := _add(scene_root, Node3D.new(), "Places")
	for p: Array in places:
		var zone := Area3D.new()
		zone.set_script(load("res://scripts/world/discovery_zone.gd"))
		zone.set("place_id", StringName(p[0]))
		zone.set("size", Vector3(p[3] - p[1] - 0.4, 2.8, p[4] - p[2] - 0.4))
		zone.position = Vector3((p[1] + p[3]) / 2.0, p[5] + 1.4, (p[2] + p[4]) / 2.0)
		_add(parent, zone, String(p[0]))


func _theater_items() -> void:
	_pickup("Shotgun", "weapon_shotgun", Vector3(7.6, 0.5, 27.3))
	_pickup("Shells2", "ammo_shells", Vector3(8.8, 0.5, 27.4), 4)
	_pickup("Shells1", "ammo_shells", Vector3(1.4, 1.05, -0.5), 4)
	_pickup("Cloth1", "material_cloth", Vector3(23.2, 0.0, 1.2), 2)
	_pickup("Chocolate", "food_chocolate_bar", Vector3(5.0, 1.07, 31.0))
	_pickup("Shells3", "ammo_shells", Vector3(46.0, 0.05, -9.6), 3)
	_pickup("Ammo9mm", "ammo_9mm", Vector3(52.0, 0.05, 25.6), 8)
	_pickup("Water", "food_water_bottle", Vector3(95.4, S + 0.82, 9.8))
	_pickup("Shells4", "ammo_shells", Vector3(95.4, S + 0.82, 11.2), 4)
	_pickup("Cloth2", "material_cloth", Vector3(88.5, S, 8.0), 2)
	_pickup("Wood", "material_wood", Vector3(92.5, S, 15.0), 3)
	_pickup("Metal", "material_metal", Vector3(89.5, S, 15.2), 2)
	_pickup("Cable", "material_cable", Vector3(91.5, S + 0.9, 17.6), 2)
	_pickup("Bandage1", "medicine_bandage", Vector3(12.0, UP + 0.8, -20.0))
	_pickup("Peaches", "food_canned_peaches", Vector3(48.0, 0.8, 33.0))
	_pickup("Ammo9mm2", "ammo_9mm", Vector3(65.0, PIT + 0.05, 23.0), 6)
	_pickup("Wood2", "material_wood", Vector3(93.0, PIT, -9.0), 2)
	_pickup("Metal2", "material_metal", Vector3(94.5, S, -21.0), 2)
	_pickup("Bandage2", "medicine_bandage", Vector3(30.0, UP + 0.05, 24.6))


func _theater_enemies() -> void:
	var stalker := "res://scenes/enemies/stalker.tscn"
	var spitter := "res://scenes/enemies/spitter.tscn"
	for e: Array in [["StalkerCoats", Vector3(22.0, 0.05, 0.5), 1.5], ["StalkerStorage", Vector3(91.5, S + 0.05, 16.0), 1.5],
			["StalkerMirrors", Vector3(12.0, 0.05, -16.0), 4.0], ["StalkerNorthWing", Vector3(50.0, 0.05, -12.0), 6.0],
			["StalkerSouthWing", Vector3(40.0, 0.05, 28.0), 6.0], ["StalkerAdmin", Vector3(12.0, UP + 0.05, -9.0), 3.0],
			["StalkerBackstage", Vector3(81.0, S + 0.05, -4.0), 4.0], ["StalkerPit", Vector3(70.0, PIT + 0.05, 8.0), 4.0],
			["StalkerDock", Vector3(91.0, S + 0.05, 36.0), 2.0]]:
		_instance(stalker, groups.Enemies, e[0], e[1], {"wander_radius": e[2]})
	for e: Array in [["SpitterPullman", Vector3(28.0, UP + 0.05, -9.0), 2.0], ["SpitterBoxes", Vector3(50.0, UP + 0.05, 24.8), 3.0],
			["SpitterPit", Vector3(86.0, PIT + 0.05, 6.0), 4.0]]:
		_instance(spitter, groups.Enemies, e[0], e[1], {"wander_radius": e[2]})
	# La cantante: el jefe del teatro (duerme hasta que te acercás al escenario).
	_instance("res://scenes/enemies/boss.tscn", groups.Enemies, "Singer", Vector3(68.0, S + 0.05, 8.5), {"wander_radius": 3.0})
	# Más público según la dificultad.
	_extra_enemy(Vector3(40.0, 0.05, 0.5), 1, 5.0)
	_extra_enemy(Vector3(81.0, S + 0.05, 20.0), 1, 3.0)
	_extra_enemy(Vector3(64.0, 0.05, 28.0), 1, 4.0)
	_extra_enemy(Vector3(12.0, 0.05, 34.0), 2, 3.0)
	_extra_enemy(Vector3(50.0, 0.05, 16.5), 2, 4.0)
	_extra_enemy(Vector3(80.0, PIT + 0.05, 20.0), 2, 3.0)
	_extra_enemy(Vector3(46.0, UP + 0.05, -8.8), 2, 3.0, "res://scenes/enemies/spitter.tscn")


func _theater_systems() -> void:
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
	# La escalera del foso: el navmesh se corta en el borde de la losa; un link une los dos niveles.
	var link := NavigationLink3D.new()
	link.bidirectional = true
	link.start_position = Vector3(78.5, S, 26.6)
	link.end_position = Vector3(78.5, PIT, 39.2)
	_add(nav, link, "PitLink")
	var persistence := Node3D.new()
	persistence.set_script(load("res://scripts/world/world_persistence.gd"))
	_add(scene_root, persistence, "WorldPersistence")
	var level_audio := Node.new()
	level_audio.set_script(load("res://scripts/world/level_audio.gd"))
	level_audio.set("ambience", &"theater")
	level_audio.set("ambience_db", -8.0)
	_add(scene_root, level_audio, "LevelAudio")
	for s: Array in [[&"from_street", Vector3(2.8, 0.05, 12.0), -90.0], [&"refuge", Vector3(49.0 + CAM_DX, S + 0.05, 12.0 + CAM_DZ), 90.0]]:
		var spawn := Marker3D.new()
		spawn.set_script(load("res://scripts/world/spawn_point.gd"))
		spawn.set("spawn_id", s[0])
		spawn.position = s[1]
		spawn.rotation_degrees.y = s[2]
		_add(scene_root, spawn, "Spawn_" + String(s[0]))
	_instance("res://scenes/player/player.tscn", scene_root, "Player", Vector3(1.6, 0.05, 12.0))
	_instance("res://scenes/effects/ps1_post_process.tscn", scene_root, "PS1PostProcess", Vector3.ZERO)
	var ui: Node = load("res://scenes/ui/game_ui.tscn").instantiate()
	_add(scene_root, ui, "GameUI")
