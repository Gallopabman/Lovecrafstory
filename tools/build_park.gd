extends "res://tools/build_street.gd"
## Genera res://scenes/levels/park_street.tscn: el barrio de casa, alrededor de la plaza.
## Es la primera salida del juego: casa (oeste, vereda norte de Larrea) -> barrio ->
## entrada de guardia del Hospital San Judas (este). Pedido del usuario: "por lo menos
## 10 veces más grande" que la cuadra original (62 x 12 m) y con los objetos espaciados.
## Andamio de una sola pasada.
## Uso: <godot> --headless --path . -s res://tools/build_park.gd
##
## Planta (x = este, z = sur; calles de 12 m con veredas):
##   Larrea      z 0,   x 0..180   la calle de casa. Corte en x 103..114: un socavón.
##   Rondeau     z -60, x 24..168  la paralela al norte (farmacia, autoservicio).
##   Sarmiento   x 42, Moreno x 96, Pichincha x 150: transversales entre Larrea y Rondeau.
##   Pasaje Ombú z -29.5, x 102..128, sale de Moreno: un callejón sin salida.
##   La plaza    x 0..84, z 6.4..46, enrejada al sur de Larrea (se entra solo en Insane).
##   Guardia     x 180..206, z -20..20: el patio de ambulancias y la entrada del hospital.
## Camino: casa -> Larrea al este -> el socavón corta -> Moreno o Sarmiento al norte ->
## Rondeau al este -> Pichincha al sur -> Larrea -> la guardia.

const PARK_OUT := "res://scenes/levels/park_street.tscn"

const A_END := 180.0
const B_Z := -60.0
const B_X0 := 24.0
const B_X1 := 168.0
const CROSS := [42.0, 96.0, 150.0]
const HOLE_X0 := 103.0
const HOLE_X1 := 114.0
const PLAZA_X := 84.0
const PLAZA_Z := 46.0
const GATE_X := 42.0
const FOUNTAIN := Vector3(42.0, 0.0, 24.0)
const LOT := Rect2(60.0, -90.0, 24.0, 24.0)
const PASAJE_Z0 := -32.0
const PASAJE_Z1 := -27.0
const PASAJE_END := 128.0
const COURT_X := 180.0
const HOSP_X := 206.0
const COURT_Z := 20.0
## Moreno sigue al sur, hacia el parque (una zona futura): cortada por un bloqueo policial.
const PARK_ROAD_X := 96.0
const PARK_ROAD_END := 52.0



func _initialize() -> void:
	GreyBoxScript = load("res://scripts/world/grey_box.gd")
	PropScript = load("res://scripts/world/prop.gd")
	InspectableScript = load("res://scripts/world/inspectable.gd")
	FlickerScript = load("res://scripts/world/flicker_light.gd")
	GatedScript = load("res://scripts/world/sanity_gated.gd")
	seed(1312)
	_make_materials()
	scene_root = Node3D.new()
	scene_root.name = "ParkStreet"
	for g in ["Structure", "Buildings", "Lights", "Props", "Cars", "Items", "Inspectables", "Secrets", "Enemies"]:
		groups[g] = _add(scene_root, Node3D.new(), g)
	for g in ["Structure", "Buildings", "Props", "Cars"]:
		groups[g].add_to_group(&"nav_source", true)

	_environment()
	_park_ground()
	_home_facade()
	_blocks()
	_west_end()
	_rondeau_ends()
	_sinkhole()
	_parking_lot()
	_pasaje()
	_storefronts()
	_hospital_court()
	_park()
	_fences()
	_dressing()
	_park_road()
	_street_signs()
	_park_lore()
	_park_secrets()
	_park_items()
	_park_places()
	_park_enemies()
	_park_systems()

	var packed := PackedScene.new()
	packed.pack(scene_root)
	var err := ResourceSaver.save(packed, PARK_OUT)
	print("Guardado %s (%s), nodos: %d" % [PARK_OUT, error_string(err), _count(scene_root)])
	scene_root.free()
	quit()


# --- El terreno y las calles -------------------------------------------------------

func _park_ground() -> void:
	var ground := _box(groups.Structure, "Ground", Vector3(104, -0.12, -23), Vector3(216, 0.2, 150), "ground")
	ground.set("subdivisions_per_meter", 0.25)
	var tile := CITY + "Street_2Lane.gltf"
	var gray := Color(0.6, 0.6, 0.6)
	# Larrea (z 0) y Rondeau (z -60): tramos de 6 m salvo en los cruces y el socavón.
	var x := 3.0
	while x < A_END:
		if not _in_cross(x) and (x < HOLE_X0 - 1.0 or x > HOLE_X1 + 1.0):
			_piece(tile, Vector3(x, 0.0, 0), 0.0, groups.Structure, gray)
		x += 6.0
	x = B_X0 + 3.0
	while x < B_X1:
		if not _in_cross(x):
			_piece(tile, Vector3(x, 0.0, B_Z), 0.0, groups.Structure, gray)
		x += 6.0
	# Las transversales (de norte a sur) y los cruces.
	for cx: float in CROSS:
		var z := -9.0
		while z > B_Z + 6.0:
			_piece(tile, Vector3(cx, 0.0, z), 90.0, groups.Structure, gray)
			z -= 6.0
		for cz in [0.0, B_Z]:
			# La vereda del lado sin calle sigue de largo (el asfalto del cruce no pasa por abajo).
			var side := 1.0 if cz == 0.0 else -1.0
			if not (cx == PARK_ROAD_X and cz == 0.0):
				_box(groups.Structure, "Crossing", Vector3(cx, OVERLAY_Y, cz - side * 1.5), Vector3(12.0, OVERLAY_H, 9.0), "asphalt", false)
				_box(groups.Structure, "SidewalkStrip", Vector3(cx, TILE_LIFT - 0.01, cz + side * 4.5), Vector3(12.0, 0.02, 3.0), "sidewalk", false)
			else:
				_box(groups.Structure, "Crossing", Vector3(cx, OVERLAY_Y, cz), Vector3(12.0, OVERLAY_H, 12.0), "asphalt", false)
			for arm in [-1.0, 1.0]:
				_piece(CITY + "Decal_Crosswalk.gltf", Vector3(cx + arm * 7.5, 0.01, cz), 90.0, groups.Structure,
					Color(0.7, 0.7, 0.68))
			_piece(CITY + "Decal_Crosswalk.gltf", Vector3(cx, 0.01, cz - side * 7.5), 0.0, groups.Structure, Color(0.7, 0.7, 0.68))
	for p in [Vector3(18, 0.01, 1.4), Vector3(66, 0.01, -1.2), Vector3(130, 0.01, 1.2), Vector3(70, 0.01, B_Z + 1.0),
			Vector3(96, 0.01, -30.0), Vector3(150, 0.01, -20.0)]:
		_prop(CITY + "Prop_ManholeCover.gltf", p, 0, {"col": false})


func _in_cross(x: float) -> bool:
	for cx: float in CROSS:
		if absf(x - cx) < 6.0:
			return true
	return false


## La fachada de casa: ladrillo, una planta y el ático (con una ventanita que brilla).
func _home_facade() -> void:
	var holder := _add(groups.Buildings, Node3D.new(), "HomeFacade")
	_brick_wall(Vector3(0.5, 0, -WALK), Vector3(15.0, 0, -WALK), 1, holder, false)
	_box(holder, "Roof", Vector3(7.75, 4.15, -11.0), Vector3(14.9, 0.3, 10.4), "cap", false)
	_box(holder, "AtticGable", Vector3(7.75, 4.9, -11.5), Vector3(14.5, 1.3, 8.0), "cap", false)
	_box(holder, "AtticWindow", Vector3(9.0, 4.9, -7.48), Vector3(0.8, 0.5, 0.04), "attic_glow", false)
	_light(Vector3(9.0, 4.9, -7.0), Color(0.9, 0.3, 0.2), 0.4, 3.5, true)
	_blocker(0.5, -16.0, 15.0, -WALK, 6.0, holder)
	for wx in [2.5, 9.8, 12.8]:
		_box(holder, "Window", Vector3(wx, 1.6, -5.97), Vector3(1.2, 1.1, 0.04), "window_dark", false)
		_box(holder, "WindowSill", Vector3(wx, 1.0, -5.92), Vector3(1.35, 0.08, 0.14), "cap", false)
	_label(holder, "1312", Vector3(5.5, 2.55, -5.9), 0, Color(0.75, 0.72, 0.65), 0.006)
	var door := Area3D.new()
	door.set_script(load("res://scripts/world/zone_door.gd"))
	door.set("target_scene", "res://scenes/levels/home.tscn")
	door.set("target_spawn", &"from_street")
	door.set("radius", 1.2)
	door.position = Vector3(5.5, 1.2, -5.6)
	_add(groups.Inspectables, door, "HomeDoor")
	_zone_door_visuals(door, Vector3(5.5, 0, -5.95), 0.0, "door_wood_open", "", 1.2, 2.3, true)
	_inspect(Vector3(3.6, 1.0, -5.4), ["El buzón de casa. Adentro, folletos del centro de día y una boleta de luz sin pagar."], 0.8)
	_inspect(Vector3(9.0, 2.0, -5.3), ["Arriba, en la ventanita del ático, hay una luz. Mamá no dejaría nada prendido."], 1.2)


## Las manzanas: frentes de edificios a lo largo de todas las calles.
func _blocks() -> void:
	# Larrea, vereda norte (frentes al sur). La casa ocupa x 0.5..15.
	_frontage(Vector3(15.0, 0, -WALK), Vector3(36.0, 0, -WALK), 0)
	_frontage(Vector3(62.0, 0, -WALK), Vector3(90.0, 0, -WALK), 0)   # 48..62: el centro de día
	_frontage(Vector3(102.0, 0, -WALK), Vector3(144.0, 0, -WALK), 0)
	_frontage(Vector3(156.0, 0, -WALK), Vector3(A_END, 0, -WALK), 0)
	# Larrea, vereda sur (frentes al norte), después de la plaza.
	_frontage(Vector3(A_END, 0, WALK), Vector3(PARK_ROAD_X + WALK, 0, WALK), 180)
	_brick_facing(Vector3(PARK_ROAD_X - WALK, 0, WALK), Vector3(PLAZA_X, 0, WALK), Vector3.FORWARD, 2, groups.Buildings)
	_blocker(PLAZA_X, WALK, PARK_ROAD_X - WALK, WALK + 0.4, 8.0)
	# Rondeau, vereda sur (frentes al norte).
	_frontage(Vector3(36.0, 0, B_Z + WALK), Vector3(B_X0, 0, B_Z + WALK), 180)
	_frontage(Vector3(90.0, 0, B_Z + WALK), Vector3(48.0, 0, B_Z + WALK), 180)
	_frontage(Vector3(144.0, 0, B_Z + WALK), Vector3(102.0, 0, B_Z + WALK), 180)
	_frontage(Vector3(B_X1, 0, B_Z + WALK), Vector3(156.0, 0, B_Z + WALK), 180)
	# Rondeau, vereda norte (frentes al sur): el autoservicio en x 60..84, la farmacia en 96..110.
	_frontage(Vector3(B_X0, 0, B_Z - WALK), Vector3(LOT.position.x, 0, B_Z - WALK), 0)
	_frontage(Vector3(LOT.end.x, 0, B_Z - WALK), Vector3(96.0, 0, B_Z - WALK), 0)
	_frontage(Vector3(110.0, 0, B_Z - WALK), Vector3(B_X1, 0, B_Z - WALK), 0)
	# Las transversales: los edificios de las esquinas ponen el costado; en el medio de la
	# cuadra, uno de frente y ladrillo en los huecos (Moreno tiene la boca del pasaje).
	for cx: float in CROSS:
		for side in [-1.0, 1.0]:
			var lx: float = cx + side * WALK
			var facing := 90.0 if side < 0 else -90.0
			var front := Vector3(-side, 0, 0)
			var inset := Vector3(side * 0.3, 0, 0)
			if cx == 96.0 and side > 0:
				for seg: Vector2 in [Vector2(-WALK, PASAJE_Z1), Vector2(PASAJE_Z0, B_Z + WALK)]:
					_brick_facing(Vector3(lx, 0, seg.x) + inset, Vector3(lx, 0, seg.y) + inset, front, 2, groups.Buildings)
					_box(groups.Buildings, "CrossBlocker", Vector3(lx + side * 0.35, 4.0, (seg.x + seg.y) / 2),
						Vector3(0.3, 8.0, absf(seg.y - seg.x)), "collider", true, false)
				continue
			_box(groups.Buildings, "CrossBlocker", Vector3(lx + side * 0.35, 4.0, -30.0), Vector3(0.3, 8.0, 48.0),
				"collider", true, false)
			_brick_facing(Vector3(lx, 0, -WALK) + inset, Vector3(lx, 0, B_Z + WALK) + inset, front, 2, groups.Buildings)
			_frontage(Vector3(lx, 0, -22.0), Vector3(lx, 0, -38.0), facing)
	# Detrás de la reja este de la plaza.
	_brick_facing(Vector3(PLAZA_X + 0.3, 0, WALK + 0.4), Vector3(PLAZA_X + 0.3, 0, PLAZA_Z), Vector3.LEFT, 2, groups.Buildings)


## Al oeste Larrea termina: un camión volcado, vallas y la niebla.
func _west_end() -> void:
	_car("truck", Vector3(1.6, 0, -1.6), 70.0, Color(0.5, 0.5, 0.5))
	_car("van", Vector3(1.2, 0, 2.8), -40.0, Color(0.55, 0.5, 0.48))
	for i in 4:
		_prop(CARS + "cone.glb", Vector3(3.6 + randf_range(-0.4, 0.4), 0, -3.5 + i * 2.2), randf_range(0, 360), {"s": 1.0, "col": false})
	_blocker(-0.6, -WALK, 0.4, WALK + 0.4, 3.0)
	_blocker(0.4, -3.0, 3.0, 4.6, 2.0, groups.Props)
	_inspect(Vector3(3.2, 1.0, 0.5), ["Un camión volcado de punta a punta. Detrás, la niebla es una pared.",
		"Se oye algo grande respirando del otro lado. No voy a pasar por acá."], 2.0)


## Rondeau no sale del barrio: un edificio se vino abajo en cada punta.
func _rondeau_ends() -> void:
	_rubble(Vector3(B_X0 + 1.5, 0, B_Z), Vector3(3.5, 0, 12.0))
	_blocker(B_X0 - 0.4, B_Z - WALK, B_X0 + 0.2, B_Z + WALK, 6.0)
	_rubble(Vector3(B_X1 - 1.5, 0, B_Z), Vector3(3.5, 0, 12.0))
	_blocker(B_X1 - 0.2, B_Z - WALK, B_X1 + 0.4, B_Z + WALK, 6.0)
	_inspect(Vector3(B_X0 + 4.2, 1.0, B_Z), ["Se cayó la fachada entera del edificio de la esquina. Los escombros todavía están tibios.",
		"Entre los ladrillos asoma una mano. No la miro más."], 2.4)
	_inspect(Vector3(B_X1 - 4.2, 1.0, B_Z), ["Un andamio caído y medio edificio encima. Por acá no se sale del barrio."], 2.4)


## El socavón de Larrea: la calle se hundió justo pasando Moreno. Hay que dar la vuelta.
func _sinkhole() -> void:
	var holder := _add(groups.Props, Node3D.new(), "Sinkhole")
	var cx := (HOLE_X0 + HOLE_X1) / 2
	var w := HOLE_X1 - HOLE_X0
	_box(holder, "Pit", Vector3(cx, OVERLAY_Y, 0), Vector3(w - 1.2, OVERLAY_H, 2.0 * WALK - 0.6), "pit", false)
	# Bordes de asfalto partidos, hundiéndose hacia el pozo.
	for i in 18:
		var edge := i % 4
		var p := Vector3(cx, 0, 0)
		var rot := Vector3.ZERO
		match edge:
			0:
				p = Vector3(HOLE_X0 + 0.6, -0.15, randf_range(-5.5, 5.5))
				rot = Vector3(0, randf_range(-20, 20), randf_range(-30, -12))
			1:
				p = Vector3(HOLE_X1 - 0.6, -0.15, randf_range(-5.5, 5.5))
				rot = Vector3(0, randf_range(-20, 20), randf_range(12, 30))
			2:
				p = Vector3(randf_range(HOLE_X0 + 1, HOLE_X1 - 1), -0.15, -5.6)
				rot = Vector3(randf_range(12, 30), randf_range(-20, 20), 0)
			3:
				p = Vector3(randf_range(HOLE_X0 + 1, HOLE_X1 - 1), -0.15, 5.6)
				rot = Vector3(randf_range(-30, -12), randf_range(-20, 20), 0)
		var slab := _box(holder, "Slab", p, Vector3(randf_range(1.5, 2.6), 0.3, randf_range(1.5, 2.6)), "asphalt", false)
		slab.rotation_degrees = rot
	# Un caño reventado que cruza el pozo y una luz fría abajo.
	var pipe := _box(holder, "BrokenPipe", Vector3(cx - 1.0, -0.2, 0.5), Vector3(w - 2.0, 0.5, 0.5), "metal", false)
	pipe.rotation_degrees = Vector3(0, 12, -6)
	_light(Vector3(cx, -0.6, 0), Color(0.4, 0.5, 0.6), 0.5, 6.0, true)
	# Vallas de los dos lados y el límite.
	for bx in [HOLE_X0 - 0.4, HOLE_X1 + 0.4]:
		for z in [-4.5, -1.5, 1.5, 4.5]:
			_box(holder, "Barrier", Vector3(bx, 0.9, z), Vector3(0.1, 0.25, 2.6), "tape", false)
			_box(holder, "BarrierLeg", Vector3(bx, 0.45, z - 1.1), Vector3(0.1, 0.9, 0.1), "plywood", false)
			_box(holder, "BarrierLeg", Vector3(bx, 0.45, z + 1.1), Vector3(0.1, 0.9, 0.1), "plywood", false)
		for i in 3:
			_prop(CARS + "cone.glb", Vector3(bx + (-0.9 if bx < cx else 0.9), 0, randf_range(-5, 5)), randf_range(0, 360),
				{"s": 1.0, "col": false})
	_blocker(HOLE_X0 - 0.5, -WALK, HOLE_X1 + 0.5, WALK, 3.0, groups.Props)
	_label(holder, "PELIGRO - SOCAVÓN", Vector3(HOLE_X0 - 0.46, 1.25, 0), -90, Color(0.15, 0.12, 0.05), 0.006)
	_label(holder, "PELIGRO - SOCAVÓN", Vector3(HOLE_X1 + 0.46, 1.25, 0), 90, Color(0.15, 0.12, 0.05), 0.006)
	_inspect(Vector3(HOLE_X0 - 1.2, 1.0, 0), ["La calle se hundió entera. Abajo corre agua, y el ruido no es solo de agua.",
		"Para llegar al hospital voy a tener que dar la vuelta por Rondeau."], 2.5)
	_inspect(Vector3(HOLE_X1 + 1.2, 1.0, 0), ["Del otro lado del pozo se ve la esquina de Moreno. Parece a un paso. No lo es."], 2.5)


## El estacionamiento del autoservicio, al norte de Rondeau (sin salida).
func _parking_lot() -> void:
	var holder := _add(groups.Props, Node3D.new(), "ParkingLot")
	var x0 := LOT.position.x
	var x1 := LOT.end.x
	var z0 := LOT.position.y
	var z1 := LOT.end.y
	_box(holder, "LotFloor", Vector3((x0 + x1) / 2, OVERLAY_Y, (z0 + z1) / 2), Vector3(x1 - x0, OVERLAY_H, z1 - z0), "asphalt", false)
	for i in 6:
		_box(holder, "LotLine", Vector3(x0 + 3.0 + i * 3.6, 0.075, z0 + 5.5), Vector3(0.1, 0.01, 4.5), "tape", false)
	_brick_facing(Vector3(x0, 0, z1), Vector3(x0, 0, z0), Vector3.RIGHT, 1, holder)
	_brick_facing(Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3.LEFT, 1, holder)
	_building("Building_Large_2", Vector3((x0 + x1) / 2 + 1.0, 0, z0), 0, Color(0.6, 0.6, 0.58))
	_brick_facing(Vector3(x0, 0, z0 - 0.3), Vector3(x1, 0, z0 - 0.3), Vector3.BACK, 2, holder)
	_box(holder, "LotBlocker", Vector3((x0 + x1) / 2, 4.0, z0 - 0.4), Vector3(x1 - x0, 8.0, 0.3), "collider", true, false)
	_box(holder, "SignBoard", Vector3((x0 + x1) / 2 + 1.0, 4.6, z0 + 0.35), Vector3(9.0, 1.0, 0.15), "sign_board", false)
	_label(holder, "AUTOSERVICIO LOS ANDES", Vector3((x0 + x1) / 2 + 1.0, 4.6, z0 + 0.45), 0, Color(0.85, 0.75, 0.4), 0.009)
	_door_prop(holder, "LotDoor", "door_chained", Vector3((x0 + x1) / 2 + 1.0, 0, z0 + 0.05), 0.0, 1.8, 2.4)
	_car("sedan", Vector3(x0 + 4.5, 0, z0 + 6.0), 3.0, Color(0.45, 0.47, 0.5))
	_car("suv", Vector3(x0 + 15.5, 0, z0 + 6.4), -8.0, Color(0.5, 0.42, 0.38))
	_car("van", Vector3(x1 - 3.5, 0, z0 + 13.0), 75.0, Color(0.6, 0.6, 0.58))
	_car("taxi", Vector3(x0 + 9.0, 0, z1 - 7.0), 140.0, Color(0.75, 0.72, 0.6))
	_dumpster(Vector3(x0 + 1.4, 0, z0 + 12.0), 90.0)
	_dumpster(Vector3(x0 + 1.4, 0, z0 + 14.2), 90.0)
	# Changos: canastos de alambre (cajas finas).
	for p in [Vector3(x0 + 11.5, 0, z0 + 14.0), Vector3(x0 + 12.3, 0, z0 + 14.5), Vector3(x1 - 6.0, 0, z1 - 4.0)]:
		var cart := _box(holder, "Cart", p + Vector3.UP * 0.55, Vector3(0.55, 0.5, 0.9), "metal", false)
		cart.rotation_degrees.y = randf_range(0, 360)
	_prop(_ph("security_light"), Vector3(x0 + 0.2, 3.4, z0 + 8.0), 90, {"anchor": 2, "col": false, "h": 0.35, "parent": holder})
	_light(Vector3(x0 + 0.8, 3.2, z0 + 8.0), Color(0.75, 0.85, 1.0), 0.8, 8.0, true)
	for p in [Vector3(x1 - 1.0, 0, z0 + 2.5), Vector3(x0 + 18.0, 0, z0 + 1.2)]:
		_prop(POLYHAVEN + "trashbag/trashbag.gltf", p, randf_range(0, 360), {"h": 0.6})
	_inspect(Vector3((x0 + x1) / 2 + 1.0, 1.2, z0 + 1.0), ["El autoservicio está cerrado con una cadena. Por la vidriera se ven las góndolas vacías.",
		"Alguien escribió en el vidrio, con el dedo: \"NO QUEDA NADA\"."], 1.8)


## Pasaje Ombú: un callejón sin salida que sale de Moreno. Acá venía a comprar.
func _pasaje() -> void:
	var holder := _add(groups.Props, Node3D.new(), "Pasaje")
	var x0 := 96.0 + WALK
	_box(holder, "PasajeFloor", Vector3((x0 + PASAJE_END) / 2, OVERLAY_Y, (PASAJE_Z0 + PASAJE_Z1) / 2),
		Vector3(PASAJE_END - x0, OVERLAY_H, PASAJE_Z1 - PASAJE_Z0), "asphalt", false)
	_brick_facing(Vector3(x0, 0, PASAJE_Z1), Vector3(PASAJE_END, 0, PASAJE_Z1), Vector3.FORWARD, 2, holder)
	_brick_facing(Vector3(x0, 0, PASAJE_Z0), Vector3(PASAJE_END, 0, PASAJE_Z0), Vector3.BACK, 2, holder)
	_brick_facing(Vector3(PASAJE_END, 0, PASAJE_Z0), Vector3(PASAJE_END, 0, PASAJE_Z1), Vector3.LEFT, 2, holder)
	var mid_z := (PASAJE_Z0 + PASAJE_Z1) / 2
	# La esquina: un colchón, una frazada, latas, cajones.
	_box(holder, "Mattress", Vector3(PASAJE_END - 1.2, 0.1, mid_z + 1.2), Vector3(1.9, 0.2, 0.95), "plywood", false)
	_box(holder, "Blanket", Vector3(PASAJE_END - 1.4, 0.22, mid_z + 1.1), Vector3(1.2, 0.05, 0.9), "swing", false)
	for p in [Vector3(PASAJE_END - 0.6, 0, mid_z - 1.6), Vector3(PASAJE_END - 1.5, 0, mid_z - 1.9)]:
		_prop(_ph("wooden_crate_02"), p, randf_range(0, 360), {"h": 0.8})
	for p in [Vector3(118.0, 0, PASAJE_Z1 - 0.5), Vector3(124.0, 0, PASAJE_Z0 + 0.5), Vector3(110.0, 0, PASAJE_Z0 + 0.6)]:
		_prop(POLYHAVEN + "trashbag/trashbag.gltf", p, randf_range(0, 360), {"h": 0.6})
	_prop(_ph("metal_trash_can"), Vector3(114.0, 0, PASAJE_Z1 - 0.5), 0, {"h": 0.9})
	_prop(_ph("barrel_stove"), Vector3(PASAJE_END - 3.0, 0, mid_z + 1.6), 0, {"h": 0.9})
	_light(Vector3(PASAJE_END - 3.0, 0.9, mid_z + 1.6), Color(1.0, 0.5, 0.25), 0.5, 4.0, true)
	_prop(_ph("security_light"), Vector3(112.0, 3.2, PASAJE_Z1 - 0.1), 180, {"anchor": 2, "col": false, "h": 0.35})
	_light(Vector3(112.0, 3.0, PASAJE_Z1 - 0.6), Color(0.75, 0.85, 1.0), 0.5, 6.0, true)
	_inspect(Vector3(x0 + 1.5, 1.2, mid_z), ["Pasaje Ombú. No tendría que entrar acá.",
		"Doce meses sin pisarlo. Las piernas se acuerdan del camino solas."], 1.6)
	_inspect(Vector3(PASAJE_END - 1.6, 0.8, mid_z + 0.6), ["La esquina del Flaco. El colchón, la frazada, el tacho para el fuego. Nadie se llevó nada.",
		"Acá dejé el sueldo de tres meses y la guitarra de papá. Y casi todo lo demás.",
		"No hay nadie. Igual tengo las manos transpiradas, como antes."], 1.6)


## Fachadas con nombre: el centro de día (Larrea) y la farmacia (Rondeau).
func _storefronts() -> void:
	var center := _storefront(Vector3(48.0, 0, -WALK), Vector3(62.0, 0, -WALK), 0.0, "CENTRO DE DÍA RENACER",
		"ADICCIONES - SALUD MENTAL", Color(0.75, 0.8, 0.85))
	_inspect(center + Vector3(0, 1.2, 0.6), ["El Centro de Día. Martes y jueves, grupo a las seis. Yo me sentaba al lado de la ventana.",
		"En la vidriera sigue el cartel que pintamos entre todos: \"UN DÍA A LA VEZ\".",
		"La puerta tiene cadena. Del otro lado se oye una silla arrastrándose, despacio, en círculos."], 1.4)
	_box(groups.Props, "PosterWindow", Vector3(57.5, 1.7, -5.93), Vector3(1.6, 0.9, 0.02), "tarp", false)
	_label(groups.Props, "UN DÍA\nA LA VEZ", Vector3(57.5, 1.7, -5.9), 0, Color(0.3, 0.45, 0.7), 0.006)
	var pharmacy := _storefront(Vector3(96.0, 0, B_Z - WALK), Vector3(110.0, 0, B_Z - WALK), 0.0, "FARMACIA ALDO",
		"DE TURNO", Color(0.7, 0.9, 0.7))
	# La cruz verde, que titila sola aunque no haya luz en ningún lado.
	var cross := Vector3(108.5, 3.6, B_Z - WALK + 0.6)
	_box(groups.Props, "GreenCrossV", cross, Vector3(0.3, 1.0, 0.12), "pharma_green", false)
	_box(groups.Props, "GreenCrossH", cross, Vector3(1.0, 0.3, 0.07), "pharma_green", false)
	_light(cross + Vector3(0, 0, 0.6), Color(0.3, 1.0, 0.45), 0.8, 7.0, true)
	_inspect(pharmacy + Vector3(0, 1.2, 0.6), ["La farmacia de Don Aldo. Rompieron la vidriera y se llevaron todo, hasta los termómetros.",
		"Acá venía con recetas que no eran mías. Él sabía y me vendía igual, hasta que mamá vino a hablar con él.",
		"Después de eso me saludaba de lejos. Nunca supe si era vergüenza o lástima."], 1.4)


## Una fachada de local: ladrillo, el volumen del edificio, vidriera, cartel y una puerta
## con cadena. Devuelve el pie de la puerta.
func _storefront(a: Vector3, b: Vector3, facing: float, title: String, subtitle: String, color: Color) -> Vector3:
	var holder := _add(groups.Buildings, Node3D.new(), "Storefront")
	var basis := Basis(Vector3.UP, deg_to_rad(facing))
	var front := basis * Vector3(0, 0, 1)
	var right := basis * Vector3.RIGHT
	var mid := (a + b) / 2
	var width := a.distance_to(b)
	_brick_facing(a, b, front, 2, holder)
	_box(holder, "Mass", mid - front * 6.2 + Vector3.UP * 4.5, _rsize(basis, Vector3(width - 0.2, 9.0, 12.0)), "plaster", false)
	_box(holder, "MassCollider", mid - front * 6.2 + Vector3.UP * 4.5, _rsize(basis, Vector3(width, 9.0, 12.0)), "collider", true, false)
	_box(holder, "ShopWindow", mid + right * (width * 0.18) + front * 0.04 + Vector3.UP * 1.55,
		_rsize(basis, Vector3(width * 0.45, 1.9, 0.04)), "window_dark", false)
	_box(holder, "SignBoard", mid + front * 0.15 + Vector3.UP * 3.25, _rsize(basis, Vector3(width * 0.85, 0.9, 0.12)), "sign_board", false)
	_label(holder, title, mid + front * 0.23 + Vector3.UP * 3.38, facing, color, 0.008)
	_label(holder, subtitle, mid + front * 0.23 + Vector3.UP * 3.0, facing, color.darkened(0.2), 0.0045)
	var door := mid - right * (width * 0.27)
	_door_prop(holder, "ChainedDoor", "door_chained", door + front * 0.05, facing, 1.3, 2.4)
	return door


# --- La guardia del San Judas (pedido del usuario: "entrada trasera, pero con forma de
#     entrada de hospital, no que sea solo una puerta") ---------------------------------

func _hospital_court() -> void:
	var holder := _add(groups.Buildings, Node3D.new(), "HospitalCourt")
	var cz := 0.0
	# Piso del patio de ambulancias, con la franja amarilla y "AMBULANCIAS" pintado.
	_box(holder, "CourtFloor", Vector3((COURT_X + HOSP_X) / 2, OVERLAY_Y, cz), Vector3(HOSP_X - COURT_X, OVERLAY_H, 2 * COURT_Z), "court", false)
	for i in 7:
		var hatch := _box(holder, "Hatch", Vector3(193.0, 0.075, -5.0 + i * 1.6), Vector3(0.25, 0.01, 2.2), "tape", false)
		hatch.rotation_degrees.y = 45.0
	var floor_text := _label(holder, "SOLO AMBULANCIAS", Vector3(186.5, 0.02, cz), -90, Color(0.75, 0.65, 0.2), 0.012)
	floor_text.rotation_degrees = Vector3(-90, -90, 0)
	# Paredes del patio (el barrio de un lado, el estacionamiento del personal del otro).
	_brick_facing(Vector3(COURT_X + 0.3, 0, -COURT_Z), Vector3(COURT_X + 0.3, 0, -WALK), Vector3.RIGHT, 2, holder)
	_brick_facing(Vector3(COURT_X + 0.3, 0, WALK), Vector3(COURT_X + 0.3, 0, COURT_Z), Vector3.RIGHT, 2, holder)
	_brick_facing(Vector3(COURT_X, 0, -COURT_Z), Vector3(HOSP_X, 0, -COURT_Z), Vector3.BACK, 1, holder)
	_fence(Vector3(COURT_X, 4.0, -COURT_Z + 0.1), Vector3(HOSP_X, 4.0, -COURT_Z + 0.1), holder)
	_brick_facing(Vector3(COURT_X, 0, COURT_Z), Vector3(HOSP_X, 0, COURT_Z), Vector3.FORWARD, 1, holder)
	_box(holder, "StaffSign", Vector3(194.0, 2.4, -COURT_Z + 0.15), Vector3(4.0, 0.7, 0.06), "sign", false)
	_label(holder, "ESTACIONAMIENTO PERSONAL", Vector3(194.0, 2.4, -COURT_Z + 0.2), 0, Color(0.85, 0.85, 0.8), 0.006)
	# La fachada del hospital: tres pisos de ladrillo con ventanas y la masa del edificio.
	_brick_facing(Vector3(HOSP_X, 0, -COURT_Z), Vector3(HOSP_X, 0, COURT_Z), Vector3.LEFT, 1, holder)
	for row in [1, 2]:
		for i in int(COURT_Z):
			var piece := "Brick_Window_Square_Single.gltf" if i % 2 == 0 else "Brick_Plain_4.gltf"
			_piece(CITY + piece, Vector3(HOSP_X, 4.0 * row, -COURT_Z + 1.0 + i * 2.0), -90.0, holder)
	_box(holder, "HospitalMass", Vector3(HOSP_X + 15.2, 6.1, 0), Vector3(30.0, 12.2, 2 * COURT_Z + 20.0), "plaster", false)
	_box(holder, "Cornice", Vector3(HOSP_X - 0.2, 12.1, 0), Vector3(0.8, 0.3, 2 * COURT_Z), "cap", false)
	_box(holder, "HospitalCollider", Vector3(HOSP_X + 1.0, 6.0, 0), Vector3(2.0, 12.0, 2 * COURT_Z), "collider", true, false)
	_label(holder, "HOSPITAL SAN JUDAS", Vector3(HOSP_X - 0.12, 9.6, 0), -90, Color(0.78, 0.78, 0.72), 0.02)
	# La cruz roja, prendida.
	var red := Vector3(HOSP_X - 0.12, 7.2, 0)
	_box(holder, "RedCrossV", red, Vector3(0.12, 2.0, 0.6), "cross_red", false)
	_box(holder, "RedCrossH", red, Vector3(0.07, 0.6, 2.0), "cross_red", false)
	_light(red + Vector3(-1.0, 0, 0), Color(1.0, 0.25, 0.2), 1.0, 9.0, false)
	_court_platform(holder)
	_court_canopy(holder)
	_court_entrance(holder)
	_court_props(holder)


## El andén de las ambulancias (0.45 m), con rampas en las puntas y escalones al frente.
func _court_platform(holder: Node) -> void:
	var h := 0.45
	var x0 := 197.0
	_box(holder, "Platform", Vector3((x0 + HOSP_X) / 2, h / 2, 0), Vector3(HOSP_X - x0, h, 18.0), "path")
	_box(holder, "PlatformCurb", Vector3(x0 + 0.05, h / 2 + 0.02, 0), Vector3(0.14, h + 0.04, 18.0), "tape", false)
	for side in [-1.0, 1.0]:
		var ramp := _box(holder, "Ramp", Vector3((x0 + HOSP_X) / 2 + 0.5, h / 2 - 0.08, side * 11.2), Vector3(HOSP_X - x0 - 1.0, 0.2, 4.6), "path")
		ramp.rotation_degrees.x = 5.6 * side
		for rx in [x0 + 0.6, HOSP_X - 0.6]:
			var rail := _box(holder, "RampRail", Vector3(rx, h + 0.7, side * 11.2), Vector3(0.05, 0.05, 4.6), "metal", false)
			rail.rotation_degrees.x = 5.6 * side
	# Escalones al frente de la puerta, con una rampa invisible para caminarlos.
	for i in 2:
		var top := h - 0.15 * (i + 1)
		_box(holder, "Step", Vector3(x0 - 0.25 - i * 0.5, top / 2, 0), Vector3(0.5, top, 6.0), "path", false)
	var steps := _box(holder, "StepsRamp", Vector3(x0 - 0.5, h / 2 - 0.1, 0), Vector3(1.2, 0.2, 6.0), "collider", true, false)
	steps.rotation_degrees.z = rad_to_deg(atan2(h, 1.0))
	# Barandas a lo largo del borde, salvo frente a los escalones.
	for z in [-6.0, 6.0]:
		_box(holder, "PlatformRail", Vector3(x0 + 0.15, h + 0.5, z), Vector3(0.05, 0.05, 6.0), "metal", false)
		for pz in [z - 3.0, z, z + 3.0]:
			_box(holder, "RailPost", Vector3(x0 + 0.15, h + 0.25, pz), Vector3(0.05, 0.5, 0.05), "metal", false)


## La marquesina sobre la calle de las ambulancias, con el cartel de GUARDIA.
func _court_canopy(holder: Node) -> void:
	var x0 := 189.5
	_box(holder, "Canopy", Vector3((x0 + HOSP_X) / 2, 4.3, 0), Vector3(HOSP_X - x0, 0.35, 14.0), "cap")
	for z in [-6.4, 6.4]:
		_box(holder, "CanopyColumn", Vector3(x0 + 0.8, 2.1, z), Vector3(0.45, 4.2, 0.45), "plaster")
		_box(holder, "ColumnStripe", Vector3(x0 + 0.8, 0.5, z), Vector3(0.52, 0.25, 0.52), "tape", false)
	_box(holder, "CanopyFascia", Vector3(x0 - 0.05, 4.3, 0), Vector3(0.12, 1.0, 14.0), "guard_red", false)
	_label(holder, "GUARDIA", Vector3(x0 - 0.13, 4.38, 0), -90, Color(1.0, 0.95, 0.9), 0.022)
	_label(holder, "EMERGENCIAS · AMBULANCIAS", Vector3(x0 - 0.13, 3.98, 0), -90, Color(1.0, 0.85, 0.8), 0.006)
	for p in [Vector3(194.0, 4.0, -3.0), Vector3(200.0, 4.0, 3.0)]:
		_prop(_ph("mounted_fluorescent_lights"), p + Vector3.UP * 0.1, 90, {"anchor": 1, "col": false, "L": 1.2})
	_light(Vector3(194.0, 3.7, -3.0), Color(0.85, 0.95, 1.0), 1.1, 9.0, true)
	_light(Vector3(200.0, 3.7, 3.0), Color(0.85, 0.95, 1.0), 0.9, 8.0, false)
	_light(Vector3(x0 - 1.0, 4.3, 0), Color(1.0, 0.3, 0.25), 0.9, 7.0, true)


## El vestíbulo de vidrio con las puertas corredizas (una quedó a medio abrir).
func _court_entrance(holder: Node) -> void:
	var h := 0.45
	var vx := 203.4
	var half := 2.4
	var top := h + 3.0
	_box(holder, "VestibuleRoof", Vector3((vx + HOSP_X) / 2, top + 0.12, 0), Vector3(HOSP_X - vx + 0.3, 0.25, 2 * half + 0.3), "cap", false)
	# Adentro está oscuro: el fondo del vestíbulo (las puertas de adentro, abiertas) es negro.
	_box(holder, "InnerDark", Vector3(HOSP_X - 0.05, h + 1.5, 0), Vector3(0.04, 3.0, 2 * half - 0.1), "door_gap", false)
	_box(holder, "VestibuleFloor", Vector3((vx + HOSP_X) / 2, h + 0.04, 0), Vector3(HOSP_X - vx, 0.02, 2 * half - 0.1), "tarp", false)
	for z in [-half, half]:
		_box(holder, "VestibuleSide", Vector3((vx + HOSP_X) / 2, h + 1.5, z), Vector3(HOSP_X - vx, 3.0, 0.04), "glass")
		_box(holder, "SideFrame", Vector3(vx, h + 1.5, z), Vector3(0.12, 3.0, 0.12), "iron", false)
		_box(holder, "SideFrameTop", Vector3((vx + HOSP_X) / 2, top - 0.05, z), Vector3(HOSP_X - vx, 0.1, 0.1), "iron", false)
	# El dintel rojo con el cartel, como la marquesina.
	_box(holder, "DoorHeader", Vector3(vx - 0.02, top - 0.25, 0), Vector3(0.12, 0.5, 2 * half), "guard_red", false)
	_label(holder, "GUARDIA", Vector3(vx - 0.1, top - 0.2, 0), -90, Color(1.0, 0.95, 0.9), 0.011)
	_label(holder, "INGRESO PACIENTES", Vector3(vx - 0.1, top - 0.4, 0), -90, Color(1.0, 0.85, 0.8), 0.0045)
	for z in [-half + 0.4, half - 0.4]:
		_box(holder, "FixedPanel", Vector3(vx, h + 1.25, z), Vector3(0.04, 2.5, 0.8), "glass")
	# Hojas corredizas: la izquierda cerrada, la derecha corrida hasta la mitad.
	_box(holder, "SlidingLeft", Vector3(vx - 0.03, h + 1.25, -0.8), Vector3(0.04, 2.5, 1.6), "glass")
	_box(holder, "SlidingRight", Vector3(vx - 0.07, h + 1.25, 1.9), Vector3(0.04, 2.5, 1.6), "glass", false)
	for z in [-1.6, 0.0, 1.1, 2.7]:
		if absf(z) <= half:
			_box(holder, "Mullion", Vector3(vx - 0.04, h + 1.25, z), Vector3(0.18, 2.5, 0.07), "iron", false)
	for y in [h + 0.05, h + 2.5]:
		_box(holder, "DoorRail", Vector3(vx - 0.04, y, 0), Vector3(0.18, 0.1, 2 * half), "iron", false)
	# Las calcomanías de las hojas y la luz de emergencia de adentro.
	for z in [-0.8, 1.9]:
		_box(holder, "DoorStripe", Vector3(vx - 0.1, h + 1.4, z), Vector3(0.01, 0.08, 1.2), "tarp", false)
	_light(Vector3(HOSP_X - 1.0, h + 2.6, 0.6), Color(1.0, 0.2, 0.15), 0.7, 4.0, true)
	_light(Vector3(vx - 0.8, h + 2.9, 0), Color(0.85, 0.95, 1.0), 0.6, 4.0, true)
	_prop(HOSP + "exit_sign.glb", Vector3(vx - 0.06, top + 0.45, 0), -90, {"anchor": 2, "col": false, "L": 0.5})
	var door := Area3D.new()
	door.set_script(load("res://scripts/world/zone_door.gd"))
	door.set("target_scene", "res://scenes/levels/hospital.tscn")
	door.set("target_spawn", &"from_park")
	door.set("radius", 1.4)
	door.position = Vector3(vx - 0.6, h + 1.2, 0.5)
	_add(groups.Inspectables, door, "HospitalDoor")

func _court_props(holder: Node) -> void:
	var h := 0.45
	# La ambulancia, con las puertas de atrás abiertas, debajo de la marquesina.
	_car("ambulance", Vector3(193.5, 0, -2.5), 180.0, Color(0.8, 0.8, 0.8))
	_inspect(Vector3(193.5, 1.0, -2.5), ["Una ambulancia del San Judas, con las puertas de atrás abiertas.",
		"Adentro, una camilla vacía y un estetoscopio. En el piso, un gafete: \"Dra. M. Ibáñez\". Mamá."], 2.4)
	# En el andén: una camilla, sillas de ruedas, un pie de suero, los residuos patogénicos.
	_prop(HOSP + "bed_metal.glb", Vector3(199.5, h, -6.0), 75, {"L": 2.0, "tint": Color(0.75, 0.75, 0.72)})
	_prop(HOSP + "blood.glb", Vector3(199.3, h + 0.04, -5.0), 10, {"col": false, "L": 1.4})
	_prop(HOSP + "wheelchair.glb", Vector3(201.5, h, 6.2), 200, {"h": 0.95})
	_prop(HOSP + "wheelchair.glb", Vector3(204.8, h, -7.4), 120, {"h": 0.95})
	_prop(HOSP + "iv_stand.glb", Vector3(202.4, h, -5.2), 0, {"h": 1.8, "col": false})
	for i in 3:
		_box(holder, "BioBin", Vector3(205.2, h + 0.45, 4.0 + i * 1.0), Vector3(0.8, 0.9, 0.8), "biohazard")
	_label(holder, "RESIDUOS\nPATOGÉNICOS", Vector3(204.78, h + 0.6, 5.0), -90, Color(0.95, 0.9, 0.85), 0.004)
	_prop(_ph("WetFloorSign_01"), Vector3(202.0, h, -1.8), 30, {"h": 0.6, "col": false})
	# La carpa de triage, armada a las apuradas en el patio.
	var tent := Vector3(186.0, 0, 13.0)
	_box(holder, "TentRoof", tent + Vector3(0, 2.6, 0), Vector3(6.0, 0.08, 4.5), "tarp", false)
	for dx in [-2.9, 2.9]:
		for dz in [-2.1, 2.1]:
			_box(holder, "TentPole", tent + Vector3(dx, 1.3, dz), Vector3(0.08, 2.6, 0.08), "metal")
	_box(holder, "TentBanner", tent + Vector3(0, 2.35, -2.25), Vector3(3.0, 0.45, 0.03), "tarp", false)
	_label(holder, "TRIAGE - NIEBLA", Vector3(0, 0, 0) + tent + Vector3(0, 2.35, -2.28), 180, Color(0.6, 0.08, 0.06), 0.006)
	for i in 3:
		_prop(HOSP + "bed_metal.glb", tent + Vector3(-1.9 + i * 1.9, 0, 0.3), 0, {"L": 1.9, "tint": Color(0.7, 0.7, 0.68)})
	_box(holder, "BodyBag", tent + Vector3(1.9, 0.68, 0.3), Vector3(0.5, 0.25, 1.7), "window_dark", false)
	_inspect(tent + Vector3(0, 1.0, -1.0), ["Una carpa de triage. Tres camillas, una con una bolsa negra cerrada.",
		"En la lona alguien anotó nombres con fibra. El último está a medio escribir: \"Ib\"."], 2.2)
	# La garita de seguridad y la barrera rota, en la entrada del patio.
	var booth := Vector3(183.0, 0, -9.0)
	_box(holder, "Booth", booth + Vector3(0, 1.3, 0), Vector3(2.4, 2.6, 2.4), "plaster")
	_box(holder, "BoothRoof", booth + Vector3(0, 2.7, 0), Vector3(2.8, 0.15, 2.8), "cap", false)
	_box(holder, "BoothWindow", booth + Vector3(0, 1.6, 1.22), Vector3(1.8, 0.9, 0.04), "glass", false)
	_box(holder, "BoothWindowW", booth + Vector3(-1.22, 1.6, 0), Vector3(0.04, 0.9, 1.6), "glass", false)
	_label(holder, "SEGURIDAD", booth + Vector3(0, 2.35, 1.23), 0, Color(0.8, 0.8, 0.75), 0.005)
	_box(holder, "BarrierPost", Vector3(182.6, 0.55, -5.6), Vector3(0.3, 1.1, 0.3), "tape")
	var arm := _box(holder, "BarrierArm", Vector3(183.4, 0.12, -2.0), Vector3(0.12, 0.12, 6.5), "tape", false)
	arm.rotation_degrees.y = 18.0
	_inspect(booth + Vector3(0, 1.0, 1.6), ["La garita del guardia. La radio está prendida, solo ruido.",
		"En el libro de ingresos, la última línea: \"03:15 - entra una ambulancia sin chofer\"."], 1.6)
	for z in [-14.0, -11.0, 11.0, 14.0]:
		_prop(CITY + "Prop_Bollard.gltf", Vector3(196.5, 0, z), 0, {"col": false})
	_prop(_ph("Barrel_01"), Vector3(204.6, 0, -17.6), 0, {"h": 1.0})
	_prop(POLYHAVEN + "trashbag/trashbag.gltf", Vector3(182.0, 0, 17.8), 0, {"h": 0.6})


# --- La plaza ----------------------------------------------------------------------

## La plaza (detrás de las rejas): pasto, senderos, una fuente, árboles y hamacas.
func _park() -> void:
	var holder := _add(groups.Props, Node3D.new(), "Park")
	var pz0 := WALK + 0.4
	_box(holder, "Grass", Vector3(PLAZA_X / 2, OVERLAY_Y, (pz0 + PLAZA_Z) / 2), Vector3(PLAZA_X, OVERLAY_H, PLAZA_Z - pz0), "grass", false)
	# Los senderos, 5 cm arriba del pasto; el que va de norte a sur, cortado donde cruza el otro.
	_box(holder, "PathX", Vector3(PLAZA_X / 2, 0.07, FOUNTAIN.z), Vector3(PLAZA_X - 1.0, 0.02, 2.4), "path", false)
	for seg: Vector2 in [Vector2(pz0 + 0.25, FOUNTAIN.z - 1.2), Vector2(FOUNTAIN.z + 1.2, PLAZA_Z - 0.25)]:
		_box(holder, "PathZ", Vector3(FOUNTAIN.x, 0.07, (seg.x + seg.y) / 2), Vector3(2.4, 0.02, seg.y - seg.x), "path", false)
	# La fuente seca.
	_box(holder, "FountainBasin", FOUNTAIN + Vector3(0, 0.3, 0), Vector3(4.6, 0.6, 4.6), "path")
	_box(holder, "FountainWater", FOUNTAIN + Vector3(0, 0.5, 0), Vector3(4.0, 0.05, 4.0), "water", false)
	_box(holder, "FountainColumn", FOUNTAIN + Vector3(0, 1.1, 0), Vector3(0.6, 1.6, 0.6), "path", false)
	_box(holder, "FountainBowl", FOUNTAIN + Vector3(0, 1.9, 0), Vector3(1.5, 0.2, 1.5), "path", false)
	# Árboles y arbustos (sin colisión: igual no se puede entrar salvo en Insane).
	var trees := ["tree_oak_dark", "tree_default_dark", "tree_detailed_dark", "tree_fat_darkh", "tree_thin_dark", "tree_tall_dark"]
	for i in 34:
		var p := Vector3(randf_range(3.0, PLAZA_X - 3.0), 0, randf_range(pz0 + 3.0, PLAZA_Z - 2.0))
		if absf(p.x - FOUNTAIN.x) < 4.0 or absf(p.z - FOUNTAIN.z) < 3.0:
			continue
		_nature(trees.pick_random(), p, randf_range(5.5, 8.0))
	for i in 30:
		var p := Vector3(randf_range(1.5, PLAZA_X - 1.5), 0, randf_range(pz0 + 1.0, pz0 + 2.0))
		if absf(p.x - GATE_X) < 2.5:
			continue
		_nature(["plant_bushLarge", "plant_bush", "plant_bushDetailed"].pick_random(), p, randf_range(0.8, 1.3))
	for p in [Vector3(16, 0, 20), Vector3(60, 0, 19.5), Vector3(50, 0, 36), Vector3(72, 0, 30)]:
		_nature(["rock_largeA", "rock_largeB", "stump_old"].pick_random(), p, 0.7)
	# Bancos alrededor de la fuente.
	for p in [[Vector3(36, 0, 22.4), 0.0], [Vector3(48, 0, 22.4), 0.0], [Vector3(36, 0, 25.6), 180.0], [Vector3(48, 0, 25.6), 180.0]]:
		_prop("res://assets/models/props/kenney/bench.glb", p[0], p[1], {"h": 0.45, "tint": Color(0.5, 0.42, 0.36), "col": false})
	# Las hamacas (estructura de caños, dos asientos colgando).
	var swing := Vector3(14.0, 0, 31.0)
	for dx in [-1.6, 1.6]:
		for dz in [-0.6, 0.6]:
			_box(holder, "SwingLeg", swing + Vector3(dx, 1.2, dz * 0.5), Vector3(0.08, 2.4, 0.08), "swing", false)
	_box(holder, "SwingBar", swing + Vector3(0, 2.4, 0), Vector3(3.4, 0.08, 0.08), "swing", false)
	for sx in [-0.7, 0.7]:
		for cz in [-0.15, 0.15]:
			_box(holder, "SwingChain", swing + Vector3(sx, 1.65, cz), Vector3(0.02, 1.5, 0.02), "iron", false)
		_box(holder, "SwingSeat", swing + Vector3(sx, 0.9, 0), Vector3(0.5, 0.05, 0.25), "plywood", false)
	# Tobogán.
	_box(holder, "SlideLadder", Vector3(20.0, 0.9, 31.0), Vector3(0.6, 1.8, 0.1), "swing", false)
	var slide := _box(holder, "Slide", Vector3(20.0, 0.95, 32.4), Vector3(0.6, 0.06, 3.0), "metal", false)
	slide.rotation_degrees.x = deg_to_rad(-33.0)
	# Faroles adentro de la plaza (uno titila).
	for p in [FOUNTAIN + Vector3(-3.5, 0, -2.5), FOUNTAIN + Vector3(3.5, 0, 2.5), Vector3(14, 0, 27.5), Vector3(70, 0, 24.0)]:
		_prop(_ph("street_lamp_01"), p, 0, {"h": 4.5, "col": false})
	_light(FOUNTAIN + Vector3(-3.5, 4.0, -2.5), Color(1.0, 0.82, 0.55), 1.1, 9.0, true)


func _fences() -> void:
	var fz := WALK + 0.4
	# La reja del frente tiene un portón en GATE_X ± 1 (ver abajo).
	_fence(Vector3(0.0, 0, fz), Vector3(GATE_X - 1.0, 0, fz))
	_fence(Vector3(GATE_X + 1.0, 0, fz), Vector3(PLAZA_X, 0, fz))
	_fence(Vector3(0.0, 0, fz), Vector3(0.0, 0, PLAZA_Z))
	_fence(Vector3(PLAZA_X, 0, fz), Vector3(PLAZA_X, 0, PLAZA_Z))
	_fence(Vector3(0.0, 0, PLAZA_Z), Vector3(PLAZA_X, 0, PLAZA_Z))
	# El portón de la plaza, encadenado... salvo en Insane: entonces no está.
	var gate := _difficulty_gate("PlazaGate", 2, true)
	_fence(Vector3(GATE_X - 1.0, 0, fz), Vector3(GATE_X + 1.0, 0, fz), gate)
	_box(gate, "GateChain", Vector3(GATE_X, 1.1, fz - 0.15), Vector3(0.6, 0.06, 0.06), "metal", false)
	_box(gate, "GatePadlock", Vector3(GATE_X, 1.0, fz - 0.2), Vector3(0.1, 0.14, 0.06), "metal", false)
	var gate_text := Area3D.new()
	gate_text.set_script(InspectableScript)
	gate_text.set("texts", PackedStringArray(["El portón de la plaza está cerrado con una cadena y un candado nuevo.",
		"Del otro lado, una hamaca se mueve sola, despacito, como si alguien recién se hubiera bajado."]))
	gate_text.set("radius", 1.4)
	gate_text.position = Vector3(GATE_X, 1.1, fz - 0.6)
	_add(gate, gate_text, "Inspect")
	# Lo que espera adentro (Insane): una pistola en el borde de la fuente.
	var reward := _difficulty_gate("PlazaReward", 2)
	var edge := FOUNTAIN.z - 2.45
	for it: Array in [["PlazaPistol", "weapon_pistol", Vector3(FOUNTAIN.x, 0.65, edge), 1],
			["PlazaAmmo", "ammo_9mm", Vector3(FOUNTAIN.x + 0.8, 0.65, edge), 10],
			["PlazaBandage", "medicine_bandage", Vector3(FOUNTAIN.x - 0.8, 0.65, edge), 2]]:
		_pickup(it[0], it[1], it[2], it[3], reward)
	var reward_text := Area3D.new()
	reward_text.set_script(InspectableScript)
	reward_text.set("texts", PackedStringArray(["En el borde de la fuente seca, una pistola envuelta en una bolsa de supermercado.",
		"Alguien la dejó para vos. Alguien que sabía que ibas a estar así de mal para poder entrar."]))
	reward_text.set("radius", 1.2)
	reward_text.position = Vector3(FOUNTAIN.x, 1.0, edge - 0.9)
	_add(reward, reward_text, "Inspect")


# --- Ambientación ------------------------------------------------------------------

## Autos, faroles, basura y árboles a lo largo de las calles.
func _dressing() -> void:
	var cars := ["sedan", "taxi", "suv", "van", "sedan", "suv"]
	# Larrea.
	var x := 10.0
	while x < A_END - 4.0:
		if not _in_cross(x) and (x < HOLE_X0 - 3.0 or x > HOLE_X1 + 3.0) and absf(x - 5.5) > 4.0:
			var r := randf()
			if r < 0.4:
				var side := 1.0 if randf() < 0.5 else -1.0
				_car(cars.pick_random(), Vector3(x, 0, side * 2.3), (92.0 if side > 0 else -88.0) + randf_range(-6, 6), TINTS.pick_random())
			elif r < 0.55:
				_prop(POLYHAVEN + "trashbag/trashbag.gltf", Vector3(x, 0, -5.3 if randf() < 0.5 else 5.2), randf_range(0, 360), {"h": 0.6})
		x += randf_range(8.0, 13.0)
	# Rondeau.
	x = B_X0 + 6.0
	while x < B_X1 - 6.0:
		if not _in_cross(x):
			var r := randf()
			if r < 0.35:
				var side := 1.0 if randf() < 0.5 else -1.0
				_car(cars.pick_random(), Vector3(x, 0, B_Z + side * 2.3), (92.0 if side > 0 else -88.0) + randf_range(-8, 8), TINTS.pick_random())
			elif r < 0.5:
				_dumpster(Vector3(x, 0, B_Z + (4.9 if randf() < 0.5 else -4.9)), 0.0)
		x += randf_range(8.0, 13.0)
	# Las transversales.
	for cx: float in CROSS:
		var z := -12.0
		while z > B_Z + 10.0:
			var r := randf()
			if r < 0.35:
				var side := 1.0 if randf() < 0.5 else -1.0
				_car(cars.pick_random(), Vector3(cx + side * 2.3, 0, z), (0.0 if side > 0 else 180.0) + randf_range(-6, 6), TINTS.pick_random())
			elif r < 0.5:
				_prop(_ph("metal_trash_can"), Vector3(cx + (5.0 if randf() < 0.5 else -5.0), 0, z), randf_range(0, 360), {"h": 0.9})
			z -= randf_range(8.0, 12.0)
	# Faroles: casi todos muertos, algunos titilan.
	var lamp_i := 0
	for lx in range(8, int(A_END), 24):
		if (lx > HOLE_X0 - 2 and lx < HOLE_X1 + 2) or _in_cross(lx):
			continue
		var north := lamp_i % 2 == 0
		_lamp(Vector3(lx, 0, -5.2 if north else 5.2), 0.0 if north else 180.0, [1, 0, 0, 2][lamp_i % 4])
		lamp_i += 1
	for lx in range(30, int(B_X1), 24):
		if _in_cross(lx):
			continue
		var north := lamp_i % 2 == 0
		_lamp(Vector3(lx, 0, B_Z + (-5.2 if north else 5.2)), 0.0 if north else 180.0, [0, 1, 0, 0][lamp_i % 4])
		lamp_i += 1
	for cx: float in CROSS:
		_lamp(Vector3(cx - 5.2, 0, -30.0), 90.0, 1 if cx == 96.0 else 0)
	# Árboles de vereda en Larrea, del lado de la plaza no (ya están las rejas).
	for tx in [124.0, 138.0, 166.0]:
		_nature("tree_thin_dark", Vector3(tx, 0, 5.0), 5.0)
	for tx in [28.0, 76.0, 132.0]:
		_nature("tree_default_dark", Vector3(tx, 0, B_Z - 5.0), 5.5)
	# Un banco de la vereda, contra la reja de la plaza.
	_prop("res://assets/models/props/kenney/bench.glb", Vector3(20.0, 0, 5.4), 180, {"h": 0.45, "tint": Color(0.5, 0.42, 0.36)})
	_prop(_ph("utility_box_01"), Vector3(26.0, 0, -5.4), 0, {"h": 1.2})
	_prop(_ph("utility_box_01"), Vector3(130.0, 0, B_Z - 5.4), 0, {"h": 1.2})
	_dumpster(Vector3(38.0, 0, -31.0), 90.0)
	_dumpster(Vector3(155.0, 0, -47.0), -90.0)
	_inspect(Vector3(14.0, 1.0, 2.2), ["El auto de un vecino, con las llaves puestas y el motor frío. Nunca lo dejaba en la calle."], 2.0)


## Carteles con el nombre de las calles en cada esquina.
func _street_signs() -> void:
	var names := {42.0: "SARMIENTO", 96.0: "MORENO", 150.0: "PICHINCHA"}
	for cx: float in CROSS:
		for corner: Array in [[Vector3(cx - 5.6, 0, -5.6), "LARREA"], [Vector3(cx + 5.6, 0, B_Z + 5.6), "RONDEAU"]]:
			var p: Vector3 = corner[0]
			_box(groups.Props, "SignPole", p + Vector3.UP * 1.4, Vector3(0.06, 2.8, 0.06), "metal", false)
			_box(groups.Props, "SignPlate", p + Vector3.UP * 2.7, Vector3(1.0, 0.22, 0.03), "sign", false)
			_label(groups.Props, corner[1], p + Vector3(0, 2.7, 0.02), 0, Color(0.9, 0.9, 0.85), 0.004)
			_box(groups.Props, "SignPlate", p + Vector3.UP * 2.45, Vector3(0.03, 0.22, 1.0), "sign", false)
			_label(groups.Props, names[cx], p + Vector3(0.02, 2.45, 0), 90, Color(0.9, 0.9, 0.85), 0.004)


## Lore del protagonista (pedido del usuario: ex adicto en recuperación, con depresión).
func _park_lore() -> void:
	# El cartel de Narcóticos Anónimos en el poste de la esquina de Moreno.
	var pole := Vector3(96.0 - 5.6, 0, -5.6)
	_box(groups.Props, "NAPoster", pole + Vector3(0, 1.6, 0.04), Vector3(0.4, 0.55, 0.01), "tarp", false)
	_inspect(pole + Vector3(0, 1.2, 0.5), ["Un cartel pegado con cinta en el poste: \"NARCÓTICOS ANÓNIMOS. Jueves 20 h, salón de la Parroquia San Judas Tadeo. Sólo por hoy.\"",
		"Lo pegué yo, hace dos meses. Era mi tarea de servicio. Está casi despegado."], 1.2)
	_inspect(Vector3(20.0, 1.0, 4.6), ["El banco de la plaza. Acá me sentaba a esperar que se hiciera de noche para ir al pasaje.",
		"Después me sentaba acá a esperar que se me pasaran las ganas. Las dos cosas llevaban más o menos lo mismo."], 1.2)
	_label(groups.Props, "EL BARRIO NO OLVIDA\npero perdona", Vector3(150.0 + WALK - 0.15, 1.8, -12.0), -90,
		Color(0.8, 0.78, 0.72), 0.007)
	_inspect(Vector3(150.0 + 5.2, 1.0, -12.0), ["Una pintada en la persiana: \"EL BARRIO NO OLVIDA\". Abajo, con otra letra: \"Pero perdona\"."], 1.4)


## Secretos: la figura en las hamacas (Inquieto), la carta debajo del banco (Quebrado) y
## el Flaco, que sigue esperando en el pasaje (Quebrado).
func _park_secrets() -> void:
	var figure := _gated("SwingFigure", 1)
	_instance("res://scenes/enemies/horror_placeholder.tscn", figure, "Figure", Vector3(14.0, 0.0, 31.4))
	var letter := _gated("BenchLetter", 2)
	var pickup: Node = load("res://scenes/world/pickup.tscn").instantiate()
	pickup.set("item", load("res://assets/items/letter_self_01.tres"))
	(pickup as Node3D).position = Vector3(20.0, 0.05, 5.2)
	_add(letter, pickup, "LetterSelf")
	_label(letter, "VOLVISTE", Vector3(20.0, 0.03, 4.4), 0, Color(0.6, 0.06, 0.04), 0.01).rotation_degrees.x = -90
	var mid_z := (PASAJE_Z0 + PASAJE_Z1) / 2
	var writing := _gated("PasajeWriting", 1)
	_label(writing, "UNA SOLA\nNO ES NADA", Vector3(PASAJE_END - 0.12, 2.0, mid_z), -90, Color(0.55, 0.05, 0.03), 0.008)
	var dealer := _gated("PasajeDealer", 2)
	_instance("res://scenes/enemies/horror_placeholder.tscn", dealer, "Figure", Vector3(PASAJE_END - 2.0, 0.0, mid_z - 1.2))
	_label(dealer, "¿QUERÉS?", Vector3(PASAJE_END - 2.0, 2.3, mid_z - 1.2), -90, Color(0.75, 0.7, 0.6), 0.006)
	var glass := _gated("CourtWriting", 1)
	_label(glass, "MAMÁ ESTÁ\nADENTRO", Vector3(203.28, 2.35, -0.8), -90, Color(0.6, 0.05, 0.03), 0.006)


## Pocos objetos y lejos uno del otro (pedido del usuario): casi todos en los rincones.
func _park_items() -> void:
	_pickup("LetterSponsor", "letter_sponsor_01", Vector3(51.8, 0.05, -5.2))
	_pickup("Water", "food_water_bottle", Vector3(LOT.end.x - 1.2, 0.05, LOT.position.y + 1.0))
	_pickup("Peaches", "food_canned_peaches", Vector3(PASAJE_END - 0.8, 0.05, PASAJE_Z1 - 0.6))
	_pickup("Chocolate", "food_chocolate_bar", Vector3(B_X1 - 4.6, 0.05, B_Z + 5.0))
	_pickup("Bandage", "medicine_bandage", Vector3(186.0 - 1.9, 0.05, 14.6))
	_pickup("Wood", "material_wood", Vector3(B_X0 + 4.0, 0.0, B_Z - 4.6), 2)
	_pickup("Metal", "material_metal", Vector3(HOLE_X1 + 1.6, 0.0, 4.6))
	_pickup("Cable", "material_cable", Vector3(156.0 - 1.2, 0.0, -45.4))
	_pickup("Cloth", "material_cloth", Vector3(37.2, 0.0, -29.2))


func _park_places() -> void:
	var parent := _add(scene_root, Node3D.new(), "Places")
	for p: Array in [["park_home", 0, -6, 36, 6], ["park_plaza", 36, -6, 103, 6], ["park_east", 114, -6, 180, 6],
			["park_sarmiento", 36, -54, 48, -6], ["park_moreno", 90, -54, 102, -6], ["park_pichincha", 144, -54, 156, -6],
			["park_rondeau", 24, -66, 168, -54], ["park_lot", 60, -90, 84, -66], ["park_pasaje", 102, -32, 128, -27],
			["park_hospital", 180, -20, 206, 20]]:
		var zone := Area3D.new()
		zone.set_script(load("res://scripts/world/discovery_zone.gd"))
		zone.set("place_id", StringName(p[0]))
		zone.set("size", Vector3(p[3] - p[1] - 0.4, 3.0, p[4] - p[2] - 0.4))
		zone.position = Vector3((p[1] + p[3]) / 2.0, 1.5, (p[2] + p[4]) / 2.0)
		_add(parent, zone, String(p[0]))


func _park_enemies() -> void:
	var stalker := "res://scenes/enemies/stalker.tscn"
	_instance(stalker, groups.Enemies, "StalkerStreet", Vector3(72.0, 0.05, 0.5), {"wander_radius": 8.0})
	_instance(stalker, groups.Enemies, "StalkerMoreno", Vector3(96.0, 0.05, -38.0), {"wander_radius": 6.0})
	_instance(stalker, groups.Enemies, "StalkerRondeau", Vector3(128.0, 0.05, B_Z), {"wander_radius": 8.0})
	_instance(stalker, groups.Enemies, "StalkerLot", Vector3(70.0, 0.05, -80.0), {"wander_radius": 5.0})
	# Un escupidor en Rondeau: desde lejos, entre los autos.
	_instance("res://scenes/enemies/spitter.tscn", groups.Enemies, "SpitterRondeau", Vector3(150.0, 0.05, B_Z - 2.0), {"wander_radius": 4.0})
	# Uno adentro de la plaza: no puede salir, pero mira desde las rejas.
	_instance(stalker, groups.Enemies, "StalkerPark", Vector3(60.0, 0.05, 32.0), {"wander_radius": 8.0})
	# Más según la dificultad.
	_extra_enemy(Vector3(30.0, 0.05, -1.0), 1)
	_extra_enemy(Vector3(118.0, 0.05, -29.5), 1, 3.0)
	_extra_enemy(Vector3(56.0, 0.05, B_Z), 1, 6.0)
	_extra_enemy(Vector3(150.0, 0.05, -30.0), 1, 6.0)
	_extra_enemy(Vector3(140.0, 0.05, 1.0), 2)
	_extra_enemy(Vector3(188.0, 0.05, -10.0), 2, 4.0)
	_extra_enemy(Vector3(42.0, 0.05, -40.0), 2, 5.0)
	_extra_enemy(Vector3(24.0, 0.05, 34.0), 2, 6.0)


func _park_systems() -> void:
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
	level_audio.set("ambience", &"street")
	level_audio.set("ambience_db", -4.0)
	_add(scene_root, level_audio, "LevelAudio")
	for s: Array in [[&"from_home", Vector3(5.5, 0.05, -3.4), 180.0], [&"from_hospital", Vector3(200.4, 0.5, 0.8), 90.0]]:
		var spawn := Marker3D.new()
		spawn.set_script(load("res://scripts/world/spawn_point.gd"))
		spawn.set("spawn_id", s[0])
		spawn.position = s[1]
		spawn.rotation_degrees.y = s[2]
		_add(scene_root, spawn, "Spawn_" + String(s[0]))
	_instance("res://scenes/player/player.tscn", scene_root, "Player", Vector3(5.5, 0.05, -4.6))
	_instance("res://scenes/effects/ps1_post_process.tscn", scene_root, "PS1PostProcess", Vector3.ZERO)
	var ui: Node = load("res://scenes/ui/game_ui.tscn").instantiate()
	_add(scene_root, ui, "GameUI")


# --- Hacia el parque (pedido del usuario: una salida abierta pero bloqueada por la policía;
#     más adelante va a ser otra zona) ---------------------------------------------------

func _park_road() -> void:
	var holder := _add(groups.Props, Node3D.new(), "ParkRoad")
	var cx := PARK_ROAD_X
	var z := WALK + 3.0
	while z < PARK_ROAD_END:
		_piece(CITY + "Street_2Lane.gltf", Vector3(cx, 0.0, z), 90.0, groups.Structure, Color(0.6, 0.6, 0.6))
		z += 6.0
	# Al oeste, la reja de la plaza (con una pared atrás); al este, una cuadra de edificios.
	_brick_facing(Vector3(cx - WALK, 0, WALK), Vector3(cx - WALK, 0, PARK_ROAD_END), Vector3.RIGHT, 2, groups.Buildings)
	_blocker(cx - WALK - 0.4, WALK, cx - WALK, PARK_ROAD_END, 8.0)
	_frontage(Vector3(cx + WALK, 0, WALK + 16.5), Vector3(cx + WALK, 0, PARK_ROAD_END), -90)
	_brick_facing(Vector3(cx + WALK + 0.3, 0, WALK), Vector3(cx + WALK + 0.3, 0, PARK_ROAD_END), Vector3.LEFT, 2, groups.Buildings)
	_blocker(cx + WALK, WALK, cx + WALK + 0.4, PARK_ROAD_END, 8.0)
	# Al fondo, entre la niebla, los árboles del parque.
	for i in 9:
		_nature(["tree_oak_dark", "tree_default_dark", "tree_tall_dark"].pick_random(),
			Vector3(cx + randf_range(-5.0, 5.0), 0, PARK_ROAD_END - randf_range(0.5, 6.0)), randf_range(6.0, 8.5), -1.0, holder)
	_box(holder, "ParkSignPole", Vector3(cx + 5.4, 1.4, 30.0), Vector3(0.08, 2.8, 0.08), "metal", false)
	_box(holder, "ParkSign", Vector3(cx + 5.3, 2.5, 30.0), Vector3(0.04, 0.5, 1.6), "sign", false)
	_label(holder, "PARQUE CENTENARIO", Vector3(cx + 5.27, 2.5, 30.0), -90, Color(0.85, 0.85, 0.8), 0.005)
	_blocker(cx - WALK, PARK_ROAD_END, cx + WALK, PARK_ROAD_END + 0.4, 6.0)
	# El bloqueo: dos patrulleros en V, una camioneta, vallas, conos y cinta. No se pasa.
	var bz := WALK + 6.0
	_car("police", Vector3(cx - 2.6, 0, bz), 35.0, Color(0.75, 0.74, 0.74))
	_car("police", Vector3(cx + 2.6, 0, bz), -35.0, Color(0.7, 0.7, 0.72))
	_car("van", Vector3(cx, 0, bz + 3.2), 90.0, Color(0.6, 0.6, 0.62))
	for x in [cx - 4.8, cx + 4.8]:
		_box(holder, "Barrier", Vector3(x, 0.9, bz - 1.6), Vector3(1.6, 0.25, 0.1), "tape", false)
		_box(holder, "BarrierLeg", Vector3(x - 0.7, 0.45, bz - 1.6), Vector3(0.1, 0.9, 0.1), "plywood", false)
		_box(holder, "BarrierLeg", Vector3(x + 0.7, 0.45, bz - 1.6), Vector3(0.1, 0.9, 0.1), "plywood", false)
	for i in 6:
		_prop(CARS + "cone.glb", Vector3(cx - 4.5 + i * 1.8, 0, bz - 2.6 + randf_range(-0.3, 0.3)), randf_range(0, 360),
			{"s": 1.0, "col": false})
	_box(holder, "PoliceTape", Vector3(cx, 0.95, bz - 1.9), Vector3(2 * WALK, 0.04, 0.02), "tape", false)
	_box(holder, "BlockadeCollider", Vector3(cx, 1.5, bz), Vector3(2 * WALK, 3.0, 4.6), "collider", true, false)
	# Las balizas de un patrullero, todavía girando.
	_light(Vector3(cx - 2.6, 1.9, bz), Color(0.2, 0.35, 1.0), 1.0, 7.0, true)
	_light(Vector3(cx + 2.6, 1.9, bz), Color(1.0, 0.15, 0.1), 0.8, 6.0, true)
	_inspect(Vector3(cx, 1.0, bz - 3.2), ["Un bloqueo de la policía: patrulleros cruzados de vereda a vereda y cinta de \"NO PASAR\".",
		"Del otro lado la calle sigue hacia el Parque Centenario. Entre los árboles se mueve algo alto, despacio.",
		"Los patrulleros están vacíos. En la radio de uno, alguien repite un código que no conozco."], 2.6)
