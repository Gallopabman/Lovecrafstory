extends "res://tools/build_street.gd"
## Genera res://scenes/levels/park_street.tscn: la cuadra de casa, frente a la plaza.
## Es la primera salida del juego: casa (oeste, vereda norte) -> calle -> hospital (este).
## La plaza está enrejada y la calle cortada al oeste: la única forma de seguir es la
## puerta de guardia del Hospital San Judas. Andamio de una sola pasada.
## Uso: <godot> --headless --path . -s res://tools/build_park.gd
##
## Planta (x = este, z = sur):
##   z -6..6     calle de dos manos con veredas (casa al norte, x 0.5-15)
##   z 6.4..40   la plaza, rodeada de rejas (no se entra)
##   x = 0       la calle termina en un camión volcado
##   x = 62      la fachada oeste del hospital, con la puerta de guardia

const PARK_OUT := "res://scenes/levels/park_street.tscn"
const NATURE := "res://assets/models/nature/"
const PARK_END := 60.0
const FENCE_H := 2.3


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
	_north_side()
	_west_end()
	_hospital_side()
	_park()
	_fences()
	_park_street_props()
	_park_secrets()
	_park_places()
	_park_enemies()
	_extra_enemy(Vector3(40.0, 0.05, -1.0), 1)
	_extra_enemy(Vector3(18.0, 0.05, 2.0), 2)
	_extra_enemy(Vector3(24.0, 0.05, 30.0), 2, 6.0)
	_park_systems()

	var packed := PackedScene.new()
	packed.pack(scene_root)
	var err := ResourceSaver.save(packed, PARK_OUT)
	print("Guardado %s (%s), nodos: %d" % [PARK_OUT, error_string(err), _count(scene_root)])
	scene_root.free()
	quit()


func _make_materials() -> void:
	super._make_materials()
	var shader: Shader = load("res://shaders/ps1_spatial.gdshader")
	var defs := {
		"iron": ["", Color(0.08, 0.08, 0.09), 1.0],
		"grass": ["concrete", Color(0.22, 0.3, 0.18), 0.25],
		"path": ["concrete", Color(0.55, 0.52, 0.48), 0.4],
		"water": ["", Color(0.08, 0.12, 0.14), 1.0],
		"window_dark": ["", Color(0.07, 0.08, 0.1), 1.0],
		"attic_glow": ["", Color(0.4, 0.12, 0.08), 1.0],
		"swing": ["metal_green", Color(0.45, 0.2, 0.15), 1.0],
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
		if key == "attic_glow":
			m.set_shader_parameter(&"emission_color", Color(0.5, 0.12, 0.06))
		var path := MAT_DIR + "m_%s.tres" % key
		ResourceSaver.save(m, path)
		mats[key] = load(path)


# --- Helpers -----------------------------------------------------------------------

## Reja de barrotes de `a` a `b` (alineada a un eje): barrotes con MultiMesh, dos
## travesaños, postes cada 3 m y una colisión invisible.
func _fence(a: Vector3, b: Vector3, parent: Node = null) -> void:
	var holder: Node = parent if parent else groups.Structure
	var dir := b - a
	var length := dir.length()
	# Todos los barrotes de un tramo en una sola malla (el shader PS1 no lee las
	# transformaciones de un MultiMesh).
	var count := int(length / 0.2)
	var bar := BoxMesh.new()
	bar.size = Vector3(0.035, FENCE_H, 0.035)
	var tool := SurfaceTool.new()
	for i in count:
		var p := a + dir * ((i + 0.5) / count) + Vector3.UP * FENCE_H / 2
		tool.append_from(bar, 0, Transform3D(Basis.IDENTITY, p))
	var bars := MeshInstance3D.new()
	bars.mesh = tool.commit()
	bars.material_override = mats.iron
	_add(holder, bars, "FenceBars")
	var along_x := absf(dir.x) > absf(dir.z)
	var mid := (a + b) / 2
	for y in [0.18, FENCE_H - 0.12]:
		_box(holder, "FenceRail", mid + Vector3.UP * y, Vector3(length, 0.05, 0.05) if along_x else Vector3(0.05, 0.05, length),
			"iron", false)
	var posts := maxi(int(length / 3.0), 1)
	for i in posts + 1:
		var p := a + dir * (float(i) / posts)
		_box(holder, "FencePost", p + Vector3.UP * (FENCE_H + 0.15) / 2, Vector3(0.1, FENCE_H + 0.15, 0.1), "iron", false)
	_box(holder, "FenceCollider", mid + Vector3.UP * 1.5, Vector3(length + 0.2, 3.0, 0.25) if along_x
		else Vector3(0.25, 3.0, length + 0.2), "collider", true, false)


func _nature(model: String, pos: Vector3, height: float, rot := -1.0) -> void:
	_prop(NATURE + model + ".glb", pos, rot if rot >= 0.0 else randf_range(0, 360),
		{"h": height, "tint": Color(0.55, 0.6, 0.55), "col": false})


# --- Zona --------------------------------------------------------------------------

func _park_ground() -> void:
	_box(groups.Structure, "Ground", Vector3(31, -0.12, 10), Vector3(70, 0.2, 70), "ground")
	var x := 3.0
	while x < PARK_END + 2.0:
		_piece(CITY + "Street_2Lane.gltf", Vector3(x, 0.0, 0), 0.0, groups.Structure, Color(0.6, 0.6, 0.6))
		x += 6.0
	_piece(CITY + "Decal_Crosswalk.gltf", Vector3(52.0, 0.01, 0), 90.0, groups.Structure, Color(0.7, 0.7, 0.68))
	for p in [Vector3(18, 0.01, 1.4), Vector3(44, 0.01, -1.2)]:
		_prop(CITY + "Prop_ManholeCover.gltf", p, 0, {"col": false})


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


func _north_side() -> void:
	_building("Building_Small_1", Vector3(22.23, 0, -WALK), 0, Color(0.6, 0.6, 0.62))
	_building("Building_Medium_2_001", Vector3(35.06, 0, -WALK), 0, Color(0.66, 0.62, 0.6))
	_building("Building_Small_1", Vector3(49.83, 0, -WALK), 0, Color(0.68, 0.64, 0.6))
	_brick_wall(Vector3(55.1, 0, -WALK), Vector3(62.0, 0, -WALK), 2)
	_blocker(55.1, -16.0, 62.0, -WALK, 8.0)


## Al oeste la calle termina: un camión volcado, vallas y la niebla.
func _west_end() -> void:
	_car("truck", Vector3(1.6, 0, -1.6), 70.0, Color(0.5, 0.5, 0.5))
	_car("van", Vector3(1.2, 0, 2.8), -40.0, Color(0.55, 0.5, 0.48))
	for i in 4:
		_prop(CARS + "cone.glb", Vector3(3.6 + randf_range(-0.4, 0.4), 0, -3.5 + i * 2.2), randf_range(0, 360), {"s": 1.0, "col": false})
	_blocker(-0.6, -WALK, 0.4, WALK + 0.4, 3.0)
	_blocker(0.4, -3.0, 3.0, 4.6, 2.0, groups.Props)
	_inspect(Vector3(3.2, 1.0, 0.5), ["Un camión volcado de punta a punta. Detrás, la niebla es una pared.",
		"Se oye algo grande respirando del otro lado. No voy a pasar por acá."], 2.0)


## Al este, la fachada oeste del San Judas, con la entrada de la guardia.
func _hospital_side() -> void:
	var holder := _add(groups.Buildings, Node3D.new(), "HospitalWest")
	_brick_wall(Vector3(62.0, 0, -16.0), Vector3(62.0, 0, 16.0), 2, holder, false)
	_box(holder, "Cornice", Vector3(62.2, 8.1, 0), Vector3(0.8, 0.3, 32.2), "cap", false)
	_label(holder, "HOSPITAL SAN JUDAS", Vector3(61.88, 3.4, 0), -90, Color(0.75, 0.75, 0.7), 0.012)
	_label(holder, "GUARDIA - AMBULANCIAS", Vector3(61.88, 2.6, 0), -90, Color(0.7, 0.12, 0.1), 0.007)
	_box(holder, "Canopy", Vector3(60.9, 2.95, 0), Vector3(2.2, 0.15, 4.0), "cap", false)
	_light(Vector3(60.8, 2.6, 0), Color(0.95, 0.3, 0.2), 0.8, 6.0, true)
	_car("ambulance", Vector3(57.0, 0, 3.3), 95.0, Color(0.8, 0.8, 0.8))
	_inspect(Vector3(57.0, 1.0, 3.3), ["Una ambulancia del San Judas, con las puertas de atrás abiertas.",
		"Adentro, una camilla vacía y un estetoscopio. En el piso, un gafete: \"Dra. M. Ibáñez\". Mamá."], 2.2)
	var door := Area3D.new()
	door.set_script(load("res://scripts/world/zone_door.gd"))
	door.set("target_scene", "res://scenes/levels/hospital.tscn")
	door.set("target_spawn", &"from_park")
	door.set("radius", 1.3)
	door.position = Vector3(61.4, 1.2, 0)
	_add(groups.Inspectables, door, "HospitalDoor")
	_zone_door_visuals(door, Vector3(61.95, 0, 0), -90.0, "door_metal_open", "", 1.4, 2.4, true)


## La plaza (detrás de las rejas): pasto, senderos, una fuente, árboles y hamacas.
func _park() -> void:
	var holder := _add(groups.Props, Node3D.new(), "Park")
	_box(holder, "Grass", Vector3(PARK_END / 2, -0.005, 23.2), Vector3(PARK_END, 0.03, 33.6), "grass", false)
	_box(holder, "PathX", Vector3(PARK_END / 2, 0.015, 20.0), Vector3(PARK_END - 1.0, 0.02, 2.4), "path", false)
	_box(holder, "PathZ", Vector3(30.0, 0.015, 23.2), Vector3(2.4, 0.02, 33.0), "path", false)
	# La fuente seca.
	_box(holder, "FountainBasin", Vector3(30.0, 0.3, 20.0), Vector3(4.6, 0.6, 4.6), "path")
	_box(holder, "FountainWater", Vector3(30.0, 0.5, 20.0), Vector3(4.0, 0.05, 4.0), "water", false)
	_box(holder, "FountainColumn", Vector3(30.0, 1.1, 20.0), Vector3(0.6, 1.6, 0.6), "path", false)
	_box(holder, "FountainBowl", Vector3(30.0, 1.9, 20.0), Vector3(1.5, 0.2, 1.5), "path", false)
	# Árboles y arbustos (sin colisión: igual no se puede entrar).
	var trees := ["tree_oak_dark", "tree_default_dark", "tree_detailed_dark", "tree_fat_darkh", "tree_thin_dark", "tree_tall_dark"]
	for p in [Vector3(6, 0, 12), Vector3(14, 0, 10.5), Vector3(22, 0, 13), Vector3(38, 0, 11.5), Vector3(46, 0, 13.5),
			Vector3(54, 0, 10.5), Vector3(8, 0, 25), Vector3(20, 0, 30), Vector3(40, 0, 27), Vector3(50, 0, 32),
			Vector3(56, 0, 24), Vector3(34, 0, 35), Vector3(4, 0, 36), Vector3(26, 0, 9.5), Vector3(44, 0, 22)]:
		_nature(trees.pick_random(), p, randf_range(5.5, 8.0))
	for i in 18:
		var p := Vector3(randf_range(1.5, PARK_END - 1.5), 0, randf_range(7.4, 8.4))
		_nature(["plant_bushLarge", "plant_bush", "plant_bushDetailed"].pick_random(), p, randf_range(0.8, 1.3))
	for p in [Vector3(16, 0, 18), Vector3(42, 0, 17.5), Vector3(36, 0, 30)]:
		_nature(["rock_largeA", "rock_largeB", "stump_old"].pick_random(), p, 0.7)
	# Bancos a los lados del sendero.
	for p in [[Vector3(24, 0, 18.4), 0.0], [Vector3(36, 0, 18.4), 0.0], [Vector3(24, 0, 21.6), 180.0], [Vector3(36, 0, 21.6), 180.0]]:
		_prop("res://assets/models/props/kenney/bench.glb", p[0], p[1], {"h": 0.45, "tint": Color(0.5, 0.42, 0.36), "col": false})
	# Las hamacas (estructura de caños, dos asientos colgando).
	var swing := Vector3(12.0, 0, 27.0)
	for dx in [-1.6, 1.6]:
		for dz in [-0.6, 0.6]:
			_box(holder, "SwingLeg", swing + Vector3(dx, 1.2, dz * 0.5), Vector3(0.08, 2.4, 0.08), "swing", false)
	_box(holder, "SwingBar", swing + Vector3(0, 2.4, 0), Vector3(3.4, 0.08, 0.08), "swing", false)
	for sx in [-0.7, 0.7]:
		for cz in [-0.15, 0.15]:
			_box(holder, "SwingChain", swing + Vector3(sx, 1.65, cz), Vector3(0.02, 1.5, 0.02), "iron", false)
		_box(holder, "SwingSeat", swing + Vector3(sx, 0.9, 0), Vector3(0.5, 0.05, 0.25), "plywood", false)
	# Tobogán.
	_box(holder, "SlideLadder", Vector3(18.0, 0.9, 27.0), Vector3(0.6, 1.8, 0.1), "swing", false)
	var slide := _box(holder, "Slide", Vector3(18.0, 0.95, 28.4), Vector3(0.6, 0.06, 3.0), "metal", false)
	slide.rotation.x = deg_to_rad(-33.0)
	# Faroles adentro de la plaza (uno titila).
	for p in [Vector3(26.5, 0, 17.5), Vector3(33.5, 0, 22.5)]:
		_prop(_ph("street_lamp_01"), p, 0, {"h": 4.5, "col": false})
	_light(Vector3(26.5, 4.0, 17.5), Color(1.0, 0.82, 0.55), 1.1, 9.0, true)


func _fences() -> void:
	# La reja del frente tiene un portón en x 29-31 (ver abajo).
	_fence(Vector3(0.0, 0, WALK + 0.4), Vector3(29.0, 0, WALK + 0.4))
	_fence(Vector3(31.0, 0, WALK + 0.4), Vector3(PARK_END, 0, WALK + 0.4))
	_fence(Vector3(0.0, 0, WALK + 0.4), Vector3(0.0, 0, 40.0))
	_fence(Vector3(PARK_END, 0, WALK + 0.4), Vector3(PARK_END, 0, 40.0))
	_fence(Vector3(0.0, 0, 40.0), Vector3(PARK_END, 0, 40.0))
	# Hueco entre la reja y el hospital, tapado.
	_brick_wall(Vector3(PARK_END, 0, WALK + 0.4), Vector3(62.0, 0, WALK + 0.4))
	# El portón de la plaza, encadenado... salvo en Insane: entonces no está.
	var gate := _difficulty_gate("PlazaGate", 2, true)
	_fence(Vector3(29.0, 0, WALK + 0.4), Vector3(31.0, 0, WALK + 0.4), gate)
	_box(gate, "GateChain", Vector3(30.0, 1.1, WALK + 0.25), Vector3(0.6, 0.06, 0.06), "metal", false)
	_box(gate, "GatePadlock", Vector3(30.0, 1.0, WALK + 0.2), Vector3(0.1, 0.14, 0.06), "metal", false)
	var gate_text := Area3D.new()
	gate_text.set_script(InspectableScript)
	gate_text.set("texts", PackedStringArray(["El portón de la plaza está cerrado con una cadena y un candado nuevo.",
		"Del otro lado, una hamaca se mueve sola, despacito, como si alguien recién se hubiera bajado."]))
	gate_text.set("radius", 1.4)
	gate_text.position = Vector3(30.0, 1.1, WALK - 0.2)
	_add(gate, gate_text, "Inspect")
	# Lo que espera adentro (Insane): una pistola en el borde de la fuente.
	var reward := _difficulty_gate("PlazaReward", 2)
	for it: Array in [["PlazaPistol", "weapon_pistol", Vector3(30.0, 0.65, 17.55), 1],
			["PlazaAmmo", "ammo_9mm", Vector3(30.8, 0.65, 17.55), 10],
			["PlazaBandage", "medicine_bandage", Vector3(29.2, 0.65, 17.55), 2]]:
		_instance("res://scenes/world/pickup.tscn", reward, it[0], it[2],
			{"item": load("res://assets/items/%s.tres" % it[1]), "count": it[3]})
	var reward_text := Area3D.new()
	reward_text.set_script(InspectableScript)
	reward_text.set("texts", PackedStringArray(["En el borde de la fuente seca, una pistola envuelta en una bolsa de supermercado.",
		"Alguien la dejó para vos. Alguien que sabía que ibas a estar así de mal para poder entrar."]))
	reward_text.set("radius", 1.2)
	reward_text.position = Vector3(30.0, 1.0, 16.6)
	_add(reward, reward_text, "Inspect")




func _park_street_props() -> void:
	_car("sedan", Vector3(14.0, 0, 2.2), 92.0, Color(0.5, 0.52, 0.55))
	_car("taxi", Vector3(40.0, 0, -2.3), -86.0, Color(0.75, 0.72, 0.6))
	_car("suv", Vector3(28.0, 0, 2.4), 88.0, Color(0.42, 0.45, 0.4))
	for x in [8.0, 20.0, 32.0, 44.0]:
		_prop(_ph("street_lamp_01"), Vector3(x, 0, -5.2), 0, {"h": 4.5, "col": false})
		_blocker(x - 0.12, -5.32, x + 0.12, -5.08, 3.0, groups.Props)
	_light(Vector3(20.0, 4.0, -4.4), Color(1.0, 0.82, 0.55), 1.2, 9.0, true)
	_light(Vector3(44.0, 4.0, -4.4), Color(0.85, 0.9, 1.0), 0.8, 8.0, false)
	# Un banco de la vereda, contra la reja de la plaza.
	_prop("res://assets/models/props/kenney/bench.glb", Vector3(20.0, 0, 5.4), 180, {"h": 0.45, "tint": Color(0.5, 0.42, 0.36)})
	for p in [Vector3(10.5, 0, -5.4), Vector3(36.0, 0, 5.3)]:
		_prop(POLYHAVEN + "trashbag/trashbag.gltf", p, randf_range(0, 360), {"h": 0.6})
	_prop(_ph("utility_box_01"), Vector3(26.0, 0, -5.4), 0, {"h": 1.2})
	_inspect(Vector3(14.0, 1.0, 2.2), ["El auto del vecino, con las llaves puestas y el motor frío. Él nunca lo dejaba en la calle."], 2.0)
	var items := [
		["Water", "food_water_bottle", Vector3(14.9, 0.05, 3.4), 1],
		["Chocolate", "food_chocolate_bar", Vector3(40.6, 0.05, -3.6), 1],
		["Wood", "material_wood", Vector3(3.8, 0.0, 4.4), 2],
		["Metal", "material_metal", Vector3(4.0, 0.0, -4.6), 1],
		["Cable", "material_cable", Vector3(56.2, 0.0, 5.0), 1],
	]
	for it: Array in items:
		_instance("res://scenes/world/pickup.tscn", groups.Items, it[0], it[2],
			{"item": load("res://assets/items/%s.tres" % it[1]), "count": it[3]})


## Secretos: la figura en las hamacas (Inquieto) y la carta debajo del banco (Quebrado).
func _park_secrets() -> void:
	var figure := Node3D.new()
	figure.set_script(GatedScript)
	figure.set("threshold", 1)
	_add(groups.Secrets, figure, "SwingFigure")
	_instance("res://scenes/enemies/horror_placeholder.tscn", figure, "Figure", Vector3(12.0, 0.0, 27.4))
	var letter := Node3D.new()
	letter.set_script(GatedScript)
	letter.set("threshold", 2)
	_add(groups.Secrets, letter, "BenchLetter")
	var pickup: Node = load("res://scenes/world/pickup.tscn").instantiate()
	pickup.set("item", load("res://assets/items/letter_self_01.tres"))
	(pickup as Node3D).position = Vector3(20.0, 0.05, 5.2)
	_add(letter, pickup, "LetterSelf")
	_label(letter, "VOLVISTE", Vector3(20.0, 0.03, 4.4), 0, Color(0.6, 0.06, 0.04), 0.01).rotation_degrees.x = -90


func _park_places() -> void:
	var parent := _add(scene_root, Node3D.new(), "Places")
	for p: Array in [["park_home", 0, -6, 20, 6], ["park_middle", 20, -6, 45, 6], ["park_hospital", 45, -6, 62, 6]]:
		var zone := Area3D.new()
		zone.set_script(load("res://scripts/world/discovery_zone.gd"))
		zone.set("place_id", StringName(p[0]))
		zone.set("size", Vector3(p[3] - p[1] - 0.4, 3.0, p[4] - p[2] - 0.4))
		zone.position = Vector3((p[1] + p[3]) / 2.0, 1.5, (p[2] + p[4]) / 2.0)
		_add(parent, zone, String(p[0]))


func _park_enemies() -> void:
	var stalker := "res://scenes/enemies/stalker.tscn"
	_instance(stalker, groups.Enemies, "StalkerStreet", Vector3(34.0, 0.05, 0.5), {"wander_radius": 6.0})
	# Uno adentro de la plaza: no puede salir, pero mira desde las rejas.
	_instance(stalker, groups.Enemies, "StalkerPark", Vector3(42.0, 0.05, 25.0), {"wander_radius": 8.0})


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
	for s: Array in [[&"from_home", Vector3(5.5, 0.05, -3.4), 180.0], [&"from_hospital", Vector3(58.8, 0.05, 0.0), 90.0]]:
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
