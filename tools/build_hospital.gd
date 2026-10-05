extends SceneTree
## Genera res://scenes/levels/hospital.tscn: Hospital San Judas, primera zona del
## juego (GDD: "Edificio: interiores, tutorial de exploración y primeras cartas").
## Es un andamio de una sola pasada: después de editar la escena en el editor,
## NO volver a correrlo (pisaría los cambios).
## Uso: <godot> --headless --path . -s res://tools/build_hospital.gd
##
## Planta (x = este, z = sur, 1 unidad = 1 m). Tres pisos de 3.5 m (PB, P1 y P2) y el
## sótano (otra escena: tools/build_basement.gd, se entra con la llave de Ferreyra):
##   Fila norte  (z 0-8):   escalera | ascensor | farmacia / internación | ...
##   Pasillo     (z 8-11):  de punta a punta
##   Fila sur    (z 11-20): seguridad / dirección | hall / enfermería | ...

const OUT_SCENE := "res://scenes/levels/hospital.tscn"
const MAT_DIR := "res://assets/materials/hospital/"
const TEX_DIR := "res://assets/textures/hospital/"
const KENNEY := "res://assets/models/props/kenney/"
const HOSP := "res://assets/models/props/hospital/"

const W := 36.0  # ancho del edificio (x)
const D := 20.0  # profundidad (z)
const H := 3.5   # piso a piso
const CEIL := 3.2  # alto de cada planta hasta el cielorraso
const ROOF := 10.5  # tres plantas (pedido del usuario: "un piso más")
const T := 0.2   # paredes interiores
const TE := 0.3  # paredes exteriores
const DOOR_W := 1.6  # ancho suficiente para el acechador (radio de navegación 0.5)
const DOOR_H := 2.4
const WIN_W := 2.0

var scene_root: Node3D
var mats := {}
var counters := {}
var groups := {}

var GreyBoxScript: Script
var PropScript: Script
var InspectableScript: Script
var FlickerScript: Script
var GatedScript: Script
var RefugeScript: Script

## Presets de props: carpeta y altura real en metros (los assets vienen a escalas dispares).
var presets := {
	# Kenney Furniture Kit (CC0)
	"bedSingle": {"L": 2.1}, "desk": {"h": 0.76}, "deskCorner": {"h": 0.76},
	"chair": {"h": 0.9}, "chairDesk": {"h": 0.95}, "chairModernCushion": {"h": 0.85},
	"bench": {"h": 0.45}, "benchCushion": {"h": 0.5},
	"bookcaseOpen": {"h": 1.8}, "bookcaseOpenLow": {"h": 0.8}, "bookcaseClosed": {"h": 1.8},
	"bookcaseClosedDoors": {"h": 1.8}, "bookcaseClosedWide": {"h": 1.7},
	"cabinetBedDrawerTable": {"h": 0.55}, "cabinetTelevision": {"h": 0.55},
	"cardboardBoxClosed": {"h": 0.5}, "cardboardBoxOpen": {"h": 0.45},
	"coatRackStanding": {"h": 1.75}, "computerScreen": {"h": 0.42, "col": false},
	"computerKeyboard": {"L": 0.45, "col": false}, "kitchenBar": {"h": 1.05}, "kitchenBarEnd": {"h": 1.05},
	"kitchenCabinet": {"h": 0.9}, "kitchenSink": {"h": 1.0}, "kitchenFridge": {"h": 1.8},
	"kitchenMicrowave": {"h": 0.3, "col": false}, "kitchenCoffeeMachine": {"h": 0.35, "col": false},
	"lampRoundFloor": {"h": 1.6}, "lampRoundTable": {"h": 0.45, "col": false},
	"laptop": {"h": 0.22, "col": false}, "loungeSofa": {"h": 0.85}, "loungeChair": {"h": 0.85},
	"pottedPlant": {"h": 1.1}, "plantSmall1": {"h": 0.4, "col": false}, "radio": {"h": 0.25, "col": false},
	"rugRectangle": {"L": 3.0, "col": false}, "rugDoormat": {"L": 1.0, "col": false},
	"sideTable": {"h": 0.75}, "table": {"h": 0.78}, "tableCoffee": {"h": 0.45},
	"televisionVintage": {"h": 0.5, "col": false}, "televisionModern": {"h": 0.6, "anchor": 2, "col": false},
	"toilet": {"h": 0.8}, "bathroomSink": {"h": 0.95}, "bathroomMirror": {"h": 0.8, "anchor": 2, "col": false},
	"bathroomCabinet": {"h": 0.7, "anchor": 2, "col": false}, "trashcan": {"h": 0.6}, "books": {"h": 0.2, "col": false},
	"washer": {"h": 0.9}, "speaker": {"h": 1.0},
	# Poly Pizza (ver CREDITS.md)
	"wheelchair": {"dir": HOSP, "h": 0.95}, "iv_stand": {"dir": HOSP, "h": 1.9, "col": false},
	"vending_machine": {"dir": HOSP, "h": 1.9}, "file_cabinet": {"dir": HOSP, "h": 1.35},
	"locker": {"dir": HOSP, "h": 1.9}, "curtain": {"dir": HOSP, "h": 2.1, "rot": Vector3(0, -90, 0), "col": false},
	"fire_extinguisher": {"dir": HOSP, "h": 0.55, "col": false},
	"exit_sign": {"dir": HOSP, "h": 0.22, "rot": Vector3(0, -90, 0), "anchor": 2, "col": false},
	"mop_bucket": {"dir": HOSP, "h": 1.2}, "water_cooler": {"dir": HOSP, "h": 1.3},
	"first_aid_kit": {"dir": HOSP, "h": 0.35, "anchor": 2, "col": false},
	"blood": {"dir": HOSP, "L": 1.3, "col": false},
	"sign_hospital": {"dir": HOSP, "h": 0.6, "rot": Vector3(0, -90, 0), "anchor": 2, "col": false},
	"tall_cabinet": {"dir": HOSP, "h": 1.9},
	"bed_metal": {"dir": HOSP, "L": 2.1},
}

## Reemplazos por modelos más detallados de Poly Haven (CC0, escala real en metros).
## La clave es el nombre usado en las llamadas a _prop; el valor, el id de Poly Haven y su preset.
var upgrades := {
	"desk": ["metal_office_desk", {}], "deskCorner": ["metal_office_desk", {}],
	"chair": ["SchoolChair_01", {}], "chairDesk": ["modern_arm_chair_01", {}],
	"chairModernCushion": ["plastic_monobloc_chair_01", {}],
	"bookcaseOpen": ["steel_frame_shelves_01", {"h": 1.9}], "bookcaseOpenLow": ["worn_metal_rack", {"h": 0.9}],
	"bookcaseClosed": ["wooden_bookshelf_worn", {}], "bookcaseClosedDoors": ["wooden_bookshelf_worn", {}],
	"bookcaseClosedWide": ["wooden_bookshelf_worn", {}],
	"cabinetBedDrawerTable": ["ClassicNightstand_01", {}], "cabinetTelevision": ["vintage_wooden_drawer_01", {}],
	"cardboardBoxClosed": ["cardboard_box_01", {}], "cardboardBoxOpen": ["wooden_crate_01", {}],
	"loungeSofa": ["Sofa_01", {}], "loungeChair": ["ArmChair_01", {}],
	"tableCoffee": ["CoffeeTable_01", {}], "table": ["WoodenTable_03", {}], "sideTable": ["side_table_01", {}],
	"televisionVintage": ["Television_01", {"col": false}], "televisionModern": ["television_02", {"anchor": 2, "col": false}],
	"plantSmall1": ["potted_plant_04", {"col": false}], "washer": ["portable_generator", {}],
	"radio": ["boombox", {"col": false}], "kitchenMicrowave": ["vintage_microwave", {"h": 0.32, "col": false}],
	"bedSingle": ["vintage_day_bed", {}], "bed_metal": ["old_bed_frame", {}], "wheelchair": ["wheelchair_01", {}],
	"first_aid_kit": ["medical_box", {"anchor": 2, "col": false}], "lampRoundTable": ["desk_lamp_arm_01", {"col": false}],
	# Usados directamente por su nombre de Poly Haven.
	"barrel_stove": ["barrel_stove", {}], "scandinavian_masonry_heater": ["scandinavian_masonry_heater", {"h": 1.5}],
	"electric_stove": ["electric_stove", {}], "security_camera_01": ["security_camera_01", {"anchor": 2, "col": false}],
	"wall_clock": ["wall_clock", {"anchor": 2, "col": false}], "WetFloorSign_01": ["WetFloorSign_01", {"col": false}],
	"wooden_broom": ["wooden_broom", {"col": false}], "trashbag": ["trashbag", {}],
	"mounted_fluorescent_lights": ["mounted_fluorescent_lights", {"anchor": 1, "col": false}],
	"wooden_crate_02": ["wooden_crate_02", {}],
}
const POLYHAVEN := "res://assets/models/props/polyhaven/"
## Correcciones por modelo de Poly Haven (rotación para que el frente mire a +Z, etc.).
## Se completan mirando los renders de tools/preview_props.
var ph_fixes := {
	"SchoolChair_01": {"rot": Vector3(0, 90, 0)},
}

## Colores "de hospital" para la cama de Kenney y la de Quaternius.
var hospital_bed_colors := {"carpetWhite": Color(0.86, 0.88, 0.86), "carpet": Color(0.5, 0.62, 0.58),
	"wood": Color(0.72, 0.74, 0.74), "Red": Color(0.55, 0.64, 0.6), "DarkRed": Color(0.42, 0.5, 0.47),
	"Wood": Color(0.66, 0.68, 0.7)}


func _initialize() -> void:
	GreyBoxScript = load("res://scripts/world/grey_box.gd")
	PropScript = load("res://scripts/world/prop.gd")
	InspectableScript = load("res://scripts/world/inspectable.gd")
	FlickerScript = load("res://scripts/world/flicker_light.gd")
	GatedScript = load("res://scripts/world/sanity_gated.gd")
	RefugeScript = load("res://scripts/world/refuge_zone.gd")
	_make_materials()

	scene_root = Node3D.new()
	scene_root.name = "Hospital"
	for g in ["Structure", "Lights", "Props", "Refuge", "Items", "Inspectables", "Secrets", "Enemies"]:
		groups[g] = _add(scene_root, Node3D.new(), g)
	groups.Structure.add_to_group(&"nav_source", true)
	groups.Props.add_to_group(&"nav_source", true)

	_environment()
	_structure()
	_stairs()
	_lights()
	_refuge()
	_ground_floor_rooms()
	_first_floor_rooms()
	_second_floor_rooms()
	_basement_door()
	_details()
	_secrets()
	_difficulty_secrets()
	_discovery()
	_items()
	_enemies()
	_difficulty_enemies()
	_systems()

	var packed := PackedScene.new()
	var err := packed.pack(scene_root)
	if err != OK:
		push_error("pack falló: %s" % err)
	err = ResourceSaver.save(packed, OUT_SCENE)
	print("Guardado %s (%s), nodos: %d" % [OUT_SCENE, error_string(err), _count(scene_root)])
	scene_root.free()
	quit()


# --- Materiales -------------------------------------------------------------

func _make_materials() -> void:
	DirAccess.make_dir_recursive_absolute(MAT_DIR)
	var shader: Shader = load("res://shaders/ps1_spatial.gdshader")
	var defs := {
		"floor": ["floor_tiles", Color(0.78, 0.82, 0.8), 0.42],
		"floor_dirty": ["floor_tiles_dirty", Color(0.68, 0.68, 0.64), 0.35],
		"wood": ["wood_floor", Color(0.75, 0.62, 0.5), 0.5],
		"concrete": ["concrete", Color(0.5, 0.5, 0.5), 0.3],
		"wall": ["wall_hospital", Color(1, 1, 1), 1.0 / H],
		"ceiling": ["ceiling_office", Color(0.72, 0.72, 0.7), 0.42],
		"metal": ["metal_green", Color(0.75, 0.78, 0.75), 0.9],
		"door_gap": ["", Color(0.015, 0.012, 0.012), 1.0],
		"ground": ["concrete", Color(0.3, 0.3, 0.3), 0.15],
		"bars": ["", Color(0.1, 0.1, 0.1), 1.0],
		"lamp": ["", Color(0.9, 0.95, 0.9), 1.0],
		"lamp_off": ["", Color(0.35, 0.36, 0.35), 1.0],
		# Refugio
		"ember": ["", Color(0.3, 0.1, 0.05), 1.0],
		"photo": ["", Color(0.78, 0.62, 0.45), 1.0],
		"photo2": ["", Color(0.48, 0.58, 0.68), 1.0],
		"cloth": ["", Color(0.78, 0.76, 0.7), 1.0],
		"cork": ["wood_floor", Color(0.62, 0.45, 0.3), 1.2],
		"paper": ["", Color(0.88, 0.86, 0.78), 1.0],
		"blanket": ["", Color(0.55, 0.22, 0.17), 1.0],
		"mattress": ["", Color(0.7, 0.76, 0.72), 1.0],
		"or_pad": ["", Color(0.24, 0.42, 0.36), 1.0],
		"planks": ["wood_floor", Color(0.6, 0.48, 0.36), 0.8],
		"soot": ["metal_green", Color(0.22, 0.2, 0.19), 0.9],
		# Arquitectura
		"trim": ["wall_plaster", Color(0.8, 0.8, 0.74), 1.5],
		"rail": ["wood_floor", Color(0.55, 0.42, 0.3), 1.0],
		"sign": ["", Color(0.12, 0.26, 0.2), 1.0],
		"counter": ["wood_floor", Color(0.62, 0.55, 0.46), 0.7],
		"counter_top": ["ceiling_office", Color(0.7, 0.72, 0.7), 1.0],
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
		if key == "lamp":
			m.set_shader_parameter(&"emission_color", Color(0.85, 0.95, 0.85))
		if key == "ember":
			m.set_shader_parameter(&"emission_color", Color(1.0, 0.42, 0.12))
		var path := MAT_DIR + "m_%s.tres" % key
		ResourceSaver.save(m, path)
		mats[key] = load(path)


# --- Helpers ----------------------------------------------------------------

func _add(parent: Node, node: Node, base_name: String = "") -> Node:
	if base_name != "":
		counters[base_name] = counters.get(base_name, 0) + 1
		node.name = base_name if counters[base_name] == 1 else "%s%d" % [base_name, counters[base_name]]
	parent.add_child(node)
	node.owner = scene_root
	return node


func _count(node: Node) -> int:
	var n := 1
	for c in node.get_children():
		n += _count(c)
	return n


func _box(parent: Node, base_name: String, center: Vector3, size: Vector3, mat: String,
		collision := true, visible := true) -> Node3D:
	var b: StaticBody3D = GreyBoxScript.new()
	b.set("size", size)
	b.set("material", mats[mat])
	# Más vértices en superficies grandes: la luz por vértice queda más suave.
	if maxf(size.x, maxf(size.y, size.z)) > 1.5:
		b.set("subdivisions_per_meter", 2.0)
	if not collision:
		b.set("collision_enabled", false)
	if not visible:
		b.set("mesh_visible", false)
	b.position = center
	return _add(parent, b, base_name)


## Superficie de piso (0.02 de espesor, tope en `y`).
func _floor(x0: float, z0: float, x1: float, z1: float, y: float, mat: String) -> void:
	_box(groups.Structure, "Floor", Vector3((x0 + x1) / 2, y - 0.01, (z0 + z1) / 2),
		Vector3(x1 - x0, 0.02, z1 - z0), mat)


func _ceiling(x0: float, z0: float, x1: float, z1: float, y: float) -> void:
	_box(groups.Structure, "Ceiling", Vector3((x0 + x1) / 2, y + 0.01, (z0 + z1) / 2),
		Vector3(x1 - x0, 0.02, z1 - z0), "ceiling", false)


## Pared recta. `axis` "x": corre de a0 a a1 en X con z = c. "z": corre en Z con x = c.
## openings: [centro, ancho, abajo, arriba] con alturas relativas a y0.
## `bars` pone rejas en las aberturas que no llegan al piso (ventanas).
func _wall(axis: String, c: float, a0: float, a1: float, y0: float, height: float, thickness: float,
		openings: Array = [], mat := "wall", bars := true) -> void:
	openings.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var cursor := a0
	for op: Array in openings:
		var left: float = op[0] - op[1] / 2.0
		var right: float = op[0] + op[1] / 2.0
		if left > cursor:
			_wall_segment(axis, c, cursor, left, y0, 0.0, height, thickness, mat)
		if op[2] > 0.0:
			_wall_segment(axis, c, left, right, y0, 0.0, op[2], thickness, mat)
		if op[3] < height:
			_wall_segment(axis, c, left, right, y0, op[3], height, thickness, mat)
		if bars and op[2] > 0.0:
			_window_bars(axis, c, left, right, y0 + op[2], y0 + op[3])
		_opening_trim(axis, c, left, right, y0 + op[2], y0 + op[3], thickness, op[2] <= 0.0)
		cursor = right
	if cursor < a1:
		_wall_segment(axis, c, cursor, a1, y0, 0.0, height, thickness, mat)


## Marco de puerta (dos jambas + dintel) o alféizar de ventana. Solo visual.
func _opening_trim(axis: String, c: float, a: float, b: float, y_lo: float, y_hi: float, thickness: float,
		is_door: bool) -> void:
	var depth := thickness + 0.06
	var pieces := []
	if is_door:
		var h := y_hi - y_lo
		pieces.append([a - 0.04, y_lo + h / 2, 0.08, h + 0.08])
		pieces.append([b + 0.04, y_lo + h / 2, 0.08, h + 0.08])
		pieces.append([(a + b) / 2, y_hi + 0.04, b - a + 0.16, 0.08])
	else:
		pieces.append([(a + b) / 2, y_lo - 0.03, b - a + 0.1, 0.06])
	for p: Array in pieces:
		var center := Vector3(p[0], p[1], c) if axis == "x" else Vector3(c, p[1], p[0])
		var size := Vector3(p[2], p[3], depth) if axis == "x" else Vector3(depth, p[3], p[2])
		_box(groups.Structure, "Trim", center, size, "trim", false)


## Pasamanos de hospital a lo largo de un pasillo (se corta en las aberturas).
## `face` es la z de la cara de la pared; `side` +1/-1 hacia dónde sobresale.
func _handrail(face: float, side: float, x0: float, x1: float, y0: float, openings: Array) -> void:
	var cuts := []
	for op: Array in openings:
		cuts.append([op[0] - op[1] / 2.0 - 0.15, op[0] + op[1] / 2.0 + 0.15])
	cuts.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var cursor := x0
	for cut: Array in cuts + [[x1, x1]]:
		if cut[0] - cursor > 0.5:
			var z := face + side * 0.06
			_box(groups.Structure, "Handrail", Vector3((cursor + cut[0]) / 2, y0 + 0.9, z),
				Vector3(cut[0] - cursor, 0.06, 0.05), "rail", false)
			_box(groups.Structure, "HandrailGuard", Vector3((cursor + cut[0]) / 2, y0 + 0.9, face + side * 0.015),
				Vector3(cut[0] - cursor, 0.14, 0.02), "trim", false)
		cursor = maxf(cursor, cut[1])


## Mostrador (recepción, enfermería, farmacia): frente de madera y tapa laminada, a lo largo de X.
func _counter(x0: float, x1: float, z: float, y0: float) -> void:
	var mid := (x0 + x1) / 2.0
	_box(groups.Props, "Counter", Vector3(mid, y0 + 0.5, z), Vector3(x1 - x0, 1.0, 0.6), "counter")
	_box(groups.Props, "CounterTop", Vector3(mid, y0 + 1.02, z - 0.03), Vector3(x1 - x0 + 0.06, 0.04, 0.7), "counter_top", false)
	_box(groups.Props, "CounterKick", Vector3(mid, y0 + 0.05, z - 0.31), Vector3(x1 - x0, 0.1, 0.02), "soot", false)


## Cartel con el nombre del ambiente sobre una puerta (del lado del pasillo).
func _room_sign(text: String, x: float, z_face: float, y0: float, facing_south: bool, height := 2.62) -> void:
	var dz := 0.03 if facing_south else -0.03
	_box(groups.Structure, "SignPlate", Vector3(x, y0 + height, z_face + dz), Vector3(1.3, 0.2, 0.02), "sign", false)
	var label := Label3D.new()
	label.text = text
	label.font = load("res://assets/fonts/pixel_operator/PixelOperator.ttf")
	label.font_size = 16
	label.pixel_size = 0.0075
	label.modulate = Color(0.88, 0.9, 0.86)
	label.position = Vector3(x, y0 + height, z_face + dz * 1.8)
	label.rotation_degrees.y = 0.0 if facing_south else 180.0
	_add(groups.Structure, label, "SignText")


func _wall_segment(axis: String, c: float, a: float, b: float, y0: float, lo: float, hi: float,
		thickness: float, mat: String) -> void:
	var mid := (a + b) / 2.0
	var y := y0 + (lo + hi) / 2.0
	if axis == "x":
		_box(groups.Structure, "Wall", Vector3(mid, y, c), Vector3(b - a, hi - lo, thickness), mat)
	else:
		_box(groups.Structure, "Wall", Vector3(c, y, mid), Vector3(thickness, hi - lo, b - a), mat)


## Rejas soldadas: el límite real de la zona (no se puede salir por las ventanas).
func _window_bars(axis: String, c: float, a: float, b: float, y_lo: float, y_hi: float) -> void:
	var count := int((b - a) / 0.22)
	for i in range(1, count):
		var t := a + (b - a) * i / count
		var center := Vector3(t, (y_lo + y_hi) / 2, c) if axis == "x" else Vector3(c, (y_lo + y_hi) / 2, t)
		_box(groups.Structure, "Bar", center, Vector3(0.04, y_hi - y_lo, 0.04), "bars")
	var mid := Vector3((a + b) / 2, (y_lo + y_hi) / 2, c) if axis == "x" else Vector3(c, (y_lo + y_hi) / 2, (a + b) / 2)
	var size := Vector3(b - a, 0.04, 0.04) if axis == "x" else Vector3(0.04, 0.04, b - a)
	_box(groups.Structure, "Bar", mid, size, "bars")


func _door(center: float) -> Array:
	return [center, DOOR_W, 0.0, DOOR_H]


func _window(center: float, y_base := 0.0) -> Array:
	return [center, WIN_W, y_base + 1.0, y_base + 2.3]


## Puerta cerrada (hoja de metal apoyada contra la pared, del lado indicado).
func _closed_door(pos: Vector3, facing_deg: float, width := 1.3, height := 2.3) -> void:
	var dir := Vector3(sin(deg_to_rad(facing_deg)), 0, cos(deg_to_rad(facing_deg)))
	var size := Vector3(width, height, 0.06) if absf(dir.z) > 0.5 else Vector3(0.06, height, width)
	_box(groups.Structure, "DoorPanel", pos + dir * 0.13 + Vector3.UP * height / 2, size, "metal")


func _prop(model_name: String, pos: Vector3, rot_y := 0.0, extra := {}) -> Node3D:
	var preset: Dictionary = presets.get(model_name, {})
	var path: String = preset.get("dir", KENNEY) + model_name + ".glb"
	var from_polyhaven := upgrades.has(model_name)
	if from_polyhaven:
		var up: Array = upgrades[model_name]
		model_name = up[0]
		path = POLYHAVEN + model_name + "/" + model_name + ".gltf"
		preset = up[1].duplicate()
		preset.merge(ph_fixes.get(model_name, {}))
	var p: Node3D = PropScript.new()
	p.set("model", load(path))
	if preset.has("h") or extra.has("h"):
		p.set("fit_height", extra.get("h", preset.get("h", 1.0)))
	elif preset.has("L"):
		p.set("fit_largest", preset.L)
	else:
		p.set("model_scale", extra.get("s", preset.get("s", 1.0 if from_polyhaven else 2.0)))
	if preset.has("rot"):
		p.set("model_rotation", preset.rot)
	if preset.has("anchor"):
		p.set("anchor", preset.anchor)
	if extra.has("anchor"):
		p.set("anchor", extra.anchor)
	p.set("collision", extra.get("col", preset.get("col", true)))
	# Los muebles de Kenney son muy limpios y saturados: se apagan un poco. Los de Poly Haven, apenas.
	var default_tint := Color(0.85, 0.84, 0.82) if from_polyhaven \
		else (Color(0.78, 0.76, 0.74) if preset.get("dir", KENNEY) == KENNEY else Color.WHITE)
	p.set("tint", extra.get("tint", default_tint))
	if extra.has("colors"):
		p.set("material_colors", extra.colors)
	p.position = pos
	p.rotation_degrees.y = rot_y
	return _add(extra.get("parent", groups.Props), p, model_name)


func _inspect(pos: Vector3, texts: Array, radius := 0.9, parent: Node = null) -> void:
	var a := Area3D.new()
	a.set_script(InspectableScript)
	a.set("texts", PackedStringArray(texts))
	a.set("radius", radius)
	a.position = pos
	_add(parent if parent else groups.Inspectables, a, "Inspect")


## Espacio del blueprint del refugio. Sus hijos "Only<n>" / "From<n>" se muestran según el nivel.
func _slot(slot_id: String, base_name: String, pos: Vector3) -> Node3D:
	var slot := Node3D.new()
	slot.set_script(load("res://scripts/world/shelter_slot.gd"))
	slot.set("slot_id", StringName(slot_id))
	slot.position = pos
	return _add(groups.Refuge, slot, base_name)


func _only(slot: Node3D, level: int) -> Node3D:
	return _level_group(slot, "Only%d" % level)


func _from(slot: Node3D, level: int) -> Node3D:
	return _level_group(slot, "From%d" % level)


func _level_group(slot: Node3D, group_name: String) -> Node3D:
	var existing := slot.get_node_or_null(group_name)
	if existing:
		return existing
	var g := Node3D.new()
	g.name = group_name
	slot.add_child(g)
	g.owner = scene_root
	return g


## kind: 0 plano, 1 cocinar, 2 descansar, 3 radio (ShelterStation.Kind).
func _station(pos: Vector3, parent: Node, base_name: String, kind: int, radius := 0.9) -> void:
	var s := Area3D.new()
	s.set_script(load("res://scripts/world/shelter_station.gd"))
	s.set("kind", kind)
	s.set("radius", radius)
	s.position = pos
	_add(parent, s, base_name)


func _ceiling_light(x: float, z: float, level: int, mode := "on", energy := 1.0,
		color := Color(0.82, 0.95, 0.88)) -> void:
	var y := level * H + CEIL
	# Luminaria de Poly Haven con dos tubos (emisivos si la luz anda).
	_prop("mounted_fluorescent_lights", Vector3(x, y, z), 90, {"parent": groups.Lights})
	for dz in [-0.14, 0.14]:
		_box(groups.Lights, "Tube", Vector3(x + dz, y - 0.055, z), Vector3(0.06, 0.03, 0.82),
			"lamp" if mode != "off" else "lamp_off", false)
	if mode == "off":
		return
	var light := OmniLight3D.new()
	if mode == "flicker":
		light.set_script(FlickerScript)
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 7.0
	light.omni_attenuation = 1.3
	light.position = Vector3(x, y - 0.3, z)
	_add(groups.Lights, light, "Light")


func _point_light(pos: Vector3, color: Color, energy: float, light_range: float, flicker := false,
		parent: Node = null) -> void:
	var light := OmniLight3D.new()
	if flicker:
		light.set_script(FlickerScript)
		light.set("flicker_chance", 2.5 if parent else 0.35)
		light.set("min_energy_factor", 0.6 if parent else 0.1)
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.position = pos
	_add(parent if parent else groups.Lights, light, "Light")


func _loop_sound(parent: Node, sound: String, pos: Vector3, volume_db: float, unit := 2.0) -> void:
	var s := AudioStreamPlayer3D.new()
	s.set_script(load("res://scripts/world/loop_sound.gd"))
	s.set("sound", StringName(sound))
	s.volume_db = volume_db
	s.unit_size = unit
	s.position = pos
	_add(parent, s, "Sound")


func _instance(path: String, parent: Node, base_name: String, pos: Vector3, props := {}) -> Node:
	var inst: Node = load(path).instantiate()
	for k: String in props:
		inst.set(k, props[k])
	if inst is Node3D:
		(inst as Node3D).position = pos
	return _add(parent, inst, base_name)


# --- Estructura -------------------------------------------------------------

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.07, 0.075)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.43, 0.46)
	env.ambient_light_energy = 0.35
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	world_env.set_script(load("res://scripts/world/atmosphere.gd"))
	world_env.set("fog_color", Color(0.07, 0.07, 0.075))
	world_env.set("fog_start", 2.0)
	world_env.set("fog_end", 17.0)
	world_env.set("insane_fog_color", Color(0.02, 0.015, 0.015))
	world_env.set("insane_fog_start", 0.5)
	world_env.set("insane_fog_end", 6.0)
	_add(scene_root, world_env, "Atmosphere")


func _structure() -> void:
	# Terreno de afuera (se ve por las ventanas).
	_box(groups.Structure, "Ground", Vector3(W / 2, -0.45, D / 2), Vector3(W + 60, 0.3, D + 60), "ground")
	# Losa de PB y superficies de piso por ambiente.
	_box(groups.Structure, "Slab", Vector3(W / 2, -0.16, D / 2), Vector3(W, 0.28, D), "concrete")
	for r in [[0, 0, 9, 8, "concrete"], [9, 0, 17, 8, "floor"], [17, 0, 25, 8, "floor"],
			[25, 0, W, 8, "wood"], [0, 8, W, 11, "floor"], [0, 11, 7, D, "floor"],
			[7, 11, 24, D, "floor"], [24, 11, 30, D, "floor"], [30, 11, W, D, "floor_dirty"]]:
		_floor(r[0], r[1], r[2], r[3], 0.0, r[4])
	# Losa de P1 con el hueco de la escalera (x 0-2.8, z 2.1-7.9).
	for s in [[0, 0, W, 2.1], [0, 7.9, W, D], [2.8, 2.1, W, 7.9]]:
		_box(groups.Structure, "Slab", Vector3((s[0] + s[2]) / 2, H - 0.16, (s[1] + s[3]) / 2),
			Vector3(s[2] - s[0], 0.28, s[3] - s[1]), "concrete")
		_ceiling(s[0], s[1], s[2], s[3], CEIL - 0.02)
	for r in [[2.8, 0, 9, 8, "concrete"], [0, 0, 2.8, 2.1, "concrete"], [9, 0, 24, 8, "floor"],
			[24, 0, W, 8, "floor_dirty"], [0, 8, W, 11, "floor"], [0, 11, 7, D, "wood"],
			[7, 11, 18, D, "floor"], [18, 11, 26, D, "concrete"], [26, 11, 33, D, "floor"],
			[33, 11, W, D, "floor_dirty"]]:
		# Sin piso sobre el hueco de la escalera (la superficie de la escalera arranca en x 2.8).
		_floor(r[0], r[1], r[2], r[3], H, r[4])
	# Losa de P2 con el hueco de la segunda escalera (en el hueco del ascensor: x 6-9, z 2.1-7.9).
	for s in [[0, 0, W, 2.1], [0, 7.9, W, D], [0, 2.1, 6, 7.9], [9, 2.1, W, 7.9]]:
		_box(groups.Structure, "Slab", Vector3((s[0] + s[2]) / 2, 2 * H - 0.16, (s[1] + s[3]) / 2),
			Vector3(s[2] - s[0], 0.28, s[3] - s[1]), "concrete")
		_ceiling(s[0], s[1], s[2], s[3], H + CEIL - 0.02)
	for r in [[0, 0, 6, 8, "concrete"], [6, 0, 9, 2.1, "concrete"], [9, 0, 21, 8, "floor"], [21, 0, 27, 8, "wood"],
			[27, 0, W, 8, "floor"], [0, 8, W, 11, "floor"], [0, 11, 7, D, "wood"], [7, 11, 16, D, "floor"],
			[16, 11, 26, D, "floor_dirty"], [26, 11, W, D, "floor"]]:
		_floor(r[0], r[1], r[2], r[3], 2 * H, r[4])
	# Techo.
	_box(groups.Structure, "Roof", Vector3(W / 2, ROOF - 0.15, D / 2), Vector3(W, 0.3, D), "ceiling")

	# Paredes exteriores (de la losa al techo, con ventanas de los tres pisos).
	var hw := -0.3
	var eh := ROOF - hw
	var y2 := 2 * H + 0.3
	_wall("x", 0.0, -TE / 2, W + TE / 2, hw, eh, TE,
		[_window(13, 0.3), _window(21, 0.3), _window(30, 0.3), _window(33.5, 0.3),
		_window(11.5, H + 0.3), _window(15, H + 0.3), _window(18.5, H + 0.3), _window(22, H + 0.3),
		_window(10.5, y2), _window(13.5, y2), _window(16.5, y2), _window(19.5, y2), _window(24, y2), _window(31.5, y2)])
	_wall("x", D, -TE / 2, W + TE / 2, hw, eh, TE,
		[_window(3.5, 0.3), _window(10, 0.3), _window(21, 0.3), _window(27, 0.3),
		_window(3.5, H + 0.3), _window(10, H + 0.3), _window(15, H + 0.3), _window(29.5, H + 0.3),
		_window(3.5, y2), _window(11.5, y2), _window(21, y2), _window(29, y2), _window(33.5, y2)])
	_wall("z", 0.0, TE / 2, D - TE / 2, hw, eh, TE,
		[[9.5, DOOR_W, 0.0, -hw + DOOR_H], [16.5, DOOR_W, 0.0, -hw + DOOR_H], [9.5, 1.6, H + 1.3, H + 2.6],
		[9.5, 1.6, 2 * H + 1.3, 2 * H + 2.6]])
	_wall("z", W, TE / 2, D - TE / 2, hw, eh, TE, [[9.5, 1.6, H + 1.3, H + 2.6], [9.5, 1.6, 2 * H + 1.3, 2 * H + 2.6]])

	# Paredes interiores por planta.
	var plan := {
		0: {"north": [_door(1.5), _door(4.4), _door(12.5), _door(20.5), _door(28)],
			"south": [_door(3.5), [15.5, 7.0, 0.0, 2.8], _door(27), _door(33)],
			"signs": [["ESCALERA", 1.5, true], ["SERVICIO", 4.4, true], ["FARMACIA", 12.5, true],
				["CONSULTORIO 1", 20.5, true], ["PERSONAL", 28.0, true], ["SEGURIDAD", 3.5, false], ["HALL", 15.5, false],
				["CONSULTORIO 2", 27.0, false], ["BAÑOS", 33.0, false]],
			"north_parts": [6.0, 9.0, 17.0, 25.0], "south_parts": [7.0, 24.0, 30.0], "elevator": true},
		# En P1 el hueco del ascensor es ahora la escalera a P2 (la cabina quedó trabada abajo).
		1: {"north": [_door(4.3), _door(7.5), _door(12), _door(21), _door(29.5)],
			"south": [_door(3.5), [12.5, 5.0, 0.0, 2.8], _door(22), _door(29.5)],
			"signs": [["ESCALERA", 4.3, true], ["A 2° PISO", 7.5, true], ["INTERNACIÓN", 12.0, true],
				["INTERNACIÓN", 21.0, true], ["QUIRÓFANO", 29.5, true], ["DIRECCIÓN", 3.5, false],
				["ENFERMERÍA", 12.5, false], ["DEPÓSITO", 22.0, false], ["ARCHIVO", 29.5, false]],
			"north_parts": [6.0, 9.0, 24.0], "south_parts": [7.0, 18.0, 26.0], "elevator": false},
		# P2: Salud Mental (habitaciones chicas, terapia grupal, sala de día).
		2: {"north": [_door(4.3), _door(10.5), _door(13.5), _door(16.5), _door(19.5), _door(24), _door(31.5)],
			"south": [_door(3.5), _door(11.5), _door(21), _door(31)],
			"signs": [["ESCALERA", 4.3, true], ["HAB. 201", 10.5, true], ["HAB. 202", 13.5, true],
				["HAB. 203", 16.5, true], ["AISLAMIENTO", 19.5, true], ["TERAPIA GRUPAL", 24.0, true],
				["SALA DE DÍA", 31.5, true], ["PSIQUIATRÍA", 3.5, false], ["ENFERMERÍA SM", 11.5, false],
				["ARCHIVO SM", 21.0, false], ["DUCHAS", 31.0, false]],
			"north_parts": [9.0, 12.0, 15.0, 18.0, 21.0, 27.0], "south_parts": [7.0, 16.0, 26.0], "elevator": false},
	}
	for level: int in plan:
		var y0 := level * H
		var p: Dictionary = plan[level]
		var north_doors: Array = p.north
		var south_doors: Array = p.south
		_wall("x", 8.0, TE / 2, W - TE / 2, y0, CEIL, T, north_doors)
		_wall("x", 11.0, TE / 2, W - TE / 2, y0, CEIL, T, south_doors)
		# Pasamanos a los dos lados del pasillo (el ascensor de PB también corta el de la pared norte).
		_handrail(8.0 + T / 2, 1.0, 0.3, W - 0.3, y0, north_doors + ([[7.5, 1.5]] if p.elevator else []))
		_handrail(11.0 - T / 2, -1.0, 0.3, W - 0.3, y0, south_doors)
		for s: Array in p.signs:
			# Sobre las aberturas anchas (2.8 m) el cartel va más alto.
			var wide: bool = s[0] == "HALL" or s[0] == "ENFERMERÍA"
			_room_sign(s[0], s[1], 8.0 + T / 2 if s[2] else 11.0 - T / 2, y0, s[2], 3.0 if wide else 2.62)
		for x: float in p.north_parts:
			_wall("z", x, TE / 2, 8.0 - T / 2, y0, CEIL, T)
		for x: float in p.south_parts:
			_wall("z", x, 11.0 + T / 2, D - TE / 2, y0, CEIL, T)
	# Pared del archivo al cuarto tapiado (P1, x 33): con un hueco que tapa la "pared que miente".
	_wall("z", 33.0, 11.0 + T / 2, D - TE / 2, H, CEIL, T, [[15.5, DOOR_W, 0.0, DOOR_H]], "wall", false)

	# Puertas cerradas: ascensor (PB), entrada principal, salida de emergencia.
	_closed_door(Vector3(7.5, 0, 8.0), 0.0, 1.4)
	# La entrada principal, encadenada por Ferreyra (dos hojas, del lado de adentro).
	for x in [15.0, 16.0]:
		_door_prop(groups.Structure, "MainDoor", "door_chained", Vector3(x, 0, D - TE / 2 - 0.02), 180.0, 1.0, 2.4)


## Escalera recta de PB a P1 dentro del hueco (x 0.3-2.7). Los escalones son solo
## visuales; se camina sobre una rampa invisible (CharacterBody3D no sube escalones).
func _stairs() -> void:
	var steps := 20
	var rise := H / steps
	var run := 0.28
	var z_start := 7.7
	for i in steps:
		var top := (i + 1) * rise
		var z := z_start - (i + 0.5) * run
		_box(groups.Structure, "Step", Vector3(1.5, top / 2, z), Vector3(2.4, top, run), "concrete", false)
	var length := Vector2(steps * run, H).length()
	var angle := atan2(H, steps * run)
	var ramp := _box(groups.Structure, "StairRamp", Vector3(1.5, H / 2 + 0.03, z_start - steps * run / 2),
		Vector3(2.4, 0.1, length + 0.3), "concrete", true, false)
	ramp.rotation.x = angle
	# Pared invisible al costado de la escalera en PB (debajo del piso de P1).
	_box(groups.Structure, "StairSide", Vector3(2.75, H / 2, z_start - steps * run / 2),
		Vector3(0.08, H, steps * run), "concrete", true, false)
	# Baranda en P1 sobre el hueco.
	_box(groups.Structure, "Rail", Vector3(2.8, H + 0.5, 5.0), Vector3(0.08, 1.0, 5.8), "bars")
	_box(groups.Structure, "RailTop", Vector3(2.8, H + 1.0, 5.0), Vector3(0.12, 0.05, 5.8), "metal")
	# Segundo tramo, de P1 a P2, en el hueco del ascensor (x 6.3-8.7): se entra desde el
	# pasillo de P1 por x 7.5 y se llega al descanso de P2 (z 0-2.1).
	for i in steps:
		var top := (i + 1) * rise
		var z := z_start - (i + 0.5) * run
		_box(groups.Structure, "Step", Vector3(7.5, H + top / 2, z), Vector3(2.4, top, run), "concrete", false)
	var ramp2 := _box(groups.Structure, "StairRamp", Vector3(7.5, H + H / 2 + 0.03, z_start - steps * run / 2),
		Vector3(2.4, 0.1, length + 0.3), "concrete", true, false)
	ramp2.rotation.x = angle
	# Baranda en P2 sobre el hueco (del lado oeste; al este está la pared de x 9).
	_box(groups.Structure, "Rail", Vector3(6.0, 2 * H + 0.5, 5.0), Vector3(0.08, 1.0, 5.8), "bars")
	_box(groups.Structure, "RailTop", Vector3(6.0, 2 * H + 1.0, 5.0), Vector3(0.12, 0.05, 5.8), "metal")


func _lights() -> void:
	# Pasillos: tubos cada 6 m; algunos parpadean y otros están muertos (bolsones de oscuridad).
	var pb := {3: "on", 9: "flicker", 15: "on", 21: "off", 27: "on", 33: "flicker"}
	var p1 := {3: "off", 9: "on", 15: "flicker", 21: "on", 27: "off", 33: "flicker"}
	for x: int in pb:
		_ceiling_light(x, 9.5, 0, pb[x])
	for x: int in p1:
		_ceiling_light(x, 9.5, 1, p1[x])
	var p2 := {3: "flicker", 9: "off", 15: "on", 21: "flicker", 27: "off", 33: "on"}
	for x: int in p2:
		_ceiling_light(x, 9.5, 2, p2[x])
	for l in [[3.0, 4.0, "off"], [13.5, 4.0, "flicker"], [16.5, 4.0, "on"], [24.0, 4.0, "flicker"], [31.5, 4.0, "on"],
			[3.5, 15.5, "flicker"], [11.5, 15.5, "on"], [21.0, 15.5, "off"], [31.0, 15.5, "flicker"]]:
		_ceiling_light(l[0], l[1], 2, l[2])
	# Ambientes.
	for l in [[3.5, 4, 0, "flicker"], [13, 4, 0, "flicker"], [21, 4, 0, "on"], [3.5, 15.5, 0, "flicker"],
			[11, 15.5, 0, "on"], [20, 15.5, 0, "flicker"], [27, 15.5, 0, "off"], [33, 15.5, 0, "flicker"],
			[4.3, 4, 1, "flicker"], [12, 4, 1, "flicker"], [18, 4, 1, "off"], [21.5, 4, 1, "on"],
			[30, 4, 1, "flicker"], [3.5, 15.5, 1, "off"], [12.5, 15.5, 1, "on"], [22, 15.5, 1, "off"],
			[29.5, 15.5, 1, "flicker"]]:
		_ceiling_light(l[0], l[1], l[2], l[3])


# --- Ambientes --------------------------------------------------------------

## Refugio: sala de descanso del personal (PB, x 25-36, z 0-8). Luz cálida y generador.
func _refuge() -> void:
	var zone := Area3D.new()
	zone.set_script(RefugeScript)
	zone.position = Vector3(30.5, 1.6, 4.05)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10.6, 3.2, 7.7)
	shape.shape = box
	zone.set("use_shelter", true)
	_add(groups.Refuge, zone, "RefugeZone")
	_add(zone, shape, "Shape")

	# Mobiliario fijo (no depende de las mejoras).
	_prop("loungeSofa", Vector3(31, 0, 6.9), 180)
	_prop("tableCoffee", Vector3(31, 0, 5.2))
	_prop("cabinetTelevision", Vector3(31, 0, 0.55))
	_prop("televisionVintage", Vector3(31, 0.55, 0.55))
	_prop("bookcaseOpenLow", Vector3(28.6, 0, 0.45))
	_prop("radio", Vector3(28.6, 0.8, 0.45))
	_prop("kitchenCabinet", Vector3(35.4, 0, 1.4), -90)
	_prop("kitchenSink", Vector3(35.4, 0, 2.3), -90)
	_prop("kitchenFridge", Vector3(35.35, 0, 3.4), -90)
	_prop("kitchenMicrowave", Vector3(35.4, 0.9, 1.3), -90)
	_prop("kitchenCoffeeMachine", Vector3(35.45, 1.0, 2.6), -90)
	_prop("table", Vector3(27.8, 0, 5.4))
	_prop("chair", Vector3(27.4, 0, 6.3), 180)
	_prop("chair", Vector3(28.2, 0, 4.5))
	_prop("lampRoundFloor", Vector3(33.5, 0, 6.9))
	_inspect(Vector3(31, 0.8, 0.9), ["Un televisor viejo y una videocasetera. Sin electricidad no sirven de nada."])
	_station(Vector3(28.6, 0.9, 0.7), groups.Refuge, "RadioStation", 3)

	# El plano en la pared: abre el menú de mejoras.
	_box(groups.Refuge, "BlueprintBoard", Vector3(33.0, 1.6, 7.88), Vector3(1.0, 0.7, 0.03), "cork", false)
	_box(groups.Refuge, "BlueprintPaper", Vector3(33.0, 1.62, 7.86), Vector3(0.8, 0.5, 0.01), "paper", false)
	var title := Label3D.new()
	title.text = "PLANO"
	title.font = load("res://assets/fonts/pixel_operator/PixelOperator.ttf")
	title.font_size = 16
	title.pixel_size = 0.008
	title.modulate = Color(0.25, 0.2, 0.3)
	title.position = Vector3(33.0, 1.78, 7.84)
	title.rotation_degrees.y = 180
	_add(groups.Refuge, title, "BlueprintTitle")
	_station(Vector3(33.0, 1.2, 7.3), groups.Refuge, "BlueprintStation", 0, 1.1)

	var warm := Color(1.0, 0.7, 0.42)
	# Fuego: fogata en un tacho -> salamandra. Habilita cocinar.
	var fire := _slot("fire", "SlotFire", Vector3(28.4, 0, 2.6))
	_inspect(Vector3(0, 0.5, 0), ["Un rincón despejado, lejos de las cortinas. Acá se podría hacer fuego. (Ver el plano.)"], 0.9, _only(fire, 0))
	var l1 := _only(fire, 1)
	_prop("barrel_stove", Vector3.ZERO, 0, {"parent": l1})
	_box(l1, "Embers", Vector3(0, 0.88, 0), Vector3(0.3, 0.03, 0.3), "ember", false)
	_point_light(Vector3(0, 1.15, 0), warm, 1.3, 5.5, true, l1)
	_loop_sound(_from(fire, 1), "fire", Vector3(0, 0.8, 0), -8.0)
	var l2 := _only(fire, 2)
	_prop("scandinavian_masonry_heater", Vector3.ZERO, 0, {"parent": l2})
	_box(l2, "StoveWindow", Vector3(0, 0.45, 0.44), Vector3(0.3, 0.2, 0.02), "ember", false)
	_point_light(Vector3(0, 0.9, 0.8), warm, 1.6, 7.0, true, l2)
	_station(Vector3(0, 0.6, 0.3), _from(fire, 1), "CookStation", 1)

	# Electricidad: generador roto -> reparado -> instalación prolija.
	var power := _slot("power", "SlotPower", Vector3(25.8, 0, 7.3))
	var p0 := _only(power, 0)
	_prop("washer", Vector3.ZERO, 90, {"parent": p0, "tint": Color(0.3, 0.32, 0.3)})
	_inspect(Vector3(0.4, 0.6, -0.1), ["El generador. Tiene nafta, pero los cables están cortados. Necesita cables y algo de metal. (Ver el plano.)"], 0.9, p0)
	_point_light(Vector3(2.0, 1.0, -1.9), Color(1.0, 0.75, 0.45), 0.45, 3.5, true, p0)  # una vela en la mesa
	var p1 := _from(power, 1)
	_prop("washer", Vector3.ZERO, 90, {"parent": p1, "tint": Color(0.55, 0.6, 0.5)})
	_inspect(Vector3(0.4, 0.6, -0.1), ["El generador ronronea bajito. Mientras ande, acá hay luz."], 0.9, p1)
	_point_light(Vector3(4.7, 2.7, -3.3), warm, 1.1, 8.0, false, p1)
	_loop_sound(p1, "generator", Vector3(0, 0.5, 0), -16.0)
	_point_light(Vector3(7.6, 1.5, -0.7), warm, 0.8, 4.0, false, p1)
	var p2 := _only(power, 2)
	_box(p2, "Conduit", Vector3(-0.68, 2.2, -3.6), Vector3(0.05, 0.05, 7.0), "soot", false)

	# Cama: colchón en el piso -> cama armada -> cama con mantas. Habilita descansar.
	var bed := _slot("bed", "SlotBed", Vector3(25.8, 0, 2.0))
	var b0 := _only(bed, 0)
	_box(b0, "Mattress", Vector3(0, 0.08, 0), Vector3(0.95, 0.16, 2.0), "cloth", false)
	_inspect(Vector3(0, 0.3, 0), ["Un colchón en el piso, con olor a hospital. Así no se descansa. (Ver el plano.)"], 1.0, b0)
	# Nivel 1: la cama plegable armada. Nivel 2: la misma con mantas y almohada.
	_prop("bedSingle", Vector3(0.1, 0, 0), 90, {"parent": _only(bed, 1)})
	var b2 := _only(bed, 2)
	_prop("bedSingle", Vector3(0.1, 0, 0), 90, {"parent": b2})
	_box(b2, "Blanket", Vector3(0.12, 0.47, 0.25), Vector3(0.72, 0.06, 1.3), "blanket", false)
	_box(b2, "Pillow", Vector3(0.12, 0.5, -0.72), Vector3(0.55, 0.1, 0.35), "cloth", false)
	_station(Vector3(0.6, 0.5, 0), _from(bed, 1), "RestStation", 2, 1.1)

	# Ventanas: rejas desnudas -> tablones -> cortinas.
	var windows := _slot("windows", "SlotWindows", Vector3(0, 0, 0))
	var w1 := _from(windows, 1)
	var w2 := _only(windows, 2)
	for x in [30.0, 33.5]:
		for y in [1.15, 1.5, 1.85, 2.2]:
			_box(w1, "Plank", Vector3(x + randf_range(-0.05, 0.05), y, 0.2), Vector3(2.15, 0.2, 0.04), "planks", false)
		for dx in [-1.2, 1.2]:
			_prop("curtain", Vector3(x + dx, 0, 0.3), 0, {"parent": w2, "h": 2.4, "tint": Color(0.7, 0.32, 0.26)})

	# Decoración: nada -> cuadros y fotos -> plantas y alfombra.
	var decor := _slot("decor", "SlotDecor", Vector3(0, 0, 0))
	var d1 := _from(decor, 1)
	for pic in [[Vector3(25.12, 1.7, 4.4), "photo"], [Vector3(25.12, 1.55, 5.4), "photo2"], [Vector3(25.12, 1.8, 6.2), "photo"]]:
		_box(d1, "Frame", pic[0], Vector3(0.03, 0.5, 0.42), "planks", false)
		_box(d1, "Photo", pic[0] + Vector3(0.02, 0, 0), Vector3(0.01, 0.38, 0.3), pic[1], false)
	_prop("books", Vector3(28.3, 0.8, 0.45), 20, {"parent": d1})
	var d2 := _from(decor, 2)
	_prop("rugRectangle", Vector3(31, 0.005, 4.8), 0, {"parent": d2})
	_prop("pottedPlant", Vector3(35.3, 0, 7.4), 0, {"parent": d2})
	_prop("pottedPlant", Vector3(29.6, 0, 0.5), 0, {"parent": d2})
	_prop("plantSmall1", Vector3(27.9, 0.78, 5.6), 0, {"parent": d2})

	# Alijo: caja de cartón -> baúl -> armario con candado. Las cosas hay que dejarlas acá.
	var stash := _slot("stash", "SlotStash", Vector3(35.3, 0, 5.4))
	_stash_visuals(stash, -90.0)
	_station(Vector3(-0.5, 0.7, 0), _from(stash, 0), "StashStation", 4, 1.0)


func _ground_floor_rooms() -> void:
	var y := 0.0
	# Farmacia (x 9-17, z 0-8).
	for x in [10.1, 11.3, 14.7, 15.9]:
		_prop("bookcaseOpen", Vector3(x, y, 0.35))
	for x in [10.8, 12.0, 13.2]:
		_prop("bookcaseOpen", Vector3(x, y, 4.0))
	_counter(13.5, 16.1, 6.9, y)
	_prop("cardboardBoxOpen", Vector3(10.0, y, 6.3), 25)
	_prop("cardboardBoxClosed", Vector3(9.7, y, 7.4))
	_prop("cardboardBoxClosed", Vector3(9.7, y + 0.34, 7.4), 15)
	_prop("trashcan", Vector3(16.5, y, 7.4))
	_prop("blood", Vector3(12.5, y + 0.01, 6.0), 40)
	_inspect(Vector3(13.0, 1.0, 1.0), ["Estantes saqueados. Quedan frascos de un antipsicótico vencido y, escondidas atrás, golosinas de la máquina."])

	# Consultorio 1 (x 17-25, z 0-8).
	_prop("desk", Vector3(21, y, 2.0), 180)
	_prop("chairDesk", Vector3(21, y, 1.1), 180)
	_prop("chair", Vector3(21, y, 3.3), 180)
	_prop("computerScreen", Vector3(21.3, y + 0.76, 1.9), 180)
	_prop("bedSingle", Vector3(18.6, y, 5.6), 90, {"colors": hospital_bed_colors})
	_prop("iv_stand", Vector3(19.6, y, 4.3))
	_prop("bathroomSink", Vector3(17.35, y, 1.6), 90)
	_prop("bookcaseClosed", Vector3(24.6, y, 5.0), -90)
	_prop("trashbag", Vector3(24.4, y, 7.3), 40)
	_inspect(Vector3(21, 1.0, 2.0), ["Una receta a medio escribir: \"Reposo. Evitar la niebla. No mirar a los...\". La tinta se corrió."])

	# Seguridad (x 0-7, z 11-20).
	_prop("desk", Vector3(3.5, y, 16.6))
	_prop("chairDesk", Vector3(3.5, y, 17.5))
	_prop("computerScreen", Vector3(3.1, y + 0.76, 16.5))
	_prop("computerScreen", Vector3(3.9, y + 0.76, 16.5), -10)
	_prop("radio", Vector3(4.4, y + 0.76, 16.9), 30)
	for z in [12.6, 13.4, 14.2]:
		_prop("locker", Vector3(0.45, y, z), 90)
	_prop("bookcaseClosedDoors", Vector3(6.55, y, 18.6), -90)
	_inspect(Vector3(3.5, 1.0, 16.4), ["Los monitores de las cámaras. Pasillos vacíos. En uno, alguien parado en el quirófano de arriba. Parpadeás y ya no está."])

	# Hall de entrada y sala de espera (x 7-24, z 11-20).
	_counter(8.2, 11.8, 13.4, y)
	_prop("computerScreen", Vector3(9.5, y + 1.05, 13.5), 0)
	_prop("chairDesk", Vector3(9.8, y, 14.4), 180)
	_prop("sign_hospital", Vector3(7.12, 1.9, 12.8), 90)
	for x in [17.2, 19.0]:
		for i in 5:
			_prop("chairModernCushion", Vector3(x, y, 14.2 + i * 0.9), 90)
	_prop("televisionModern", Vector3(23.88, 1.5, 16.0), -90)
	_prop("tableCoffee", Vector3(21.2, y, 16.1))
	_prop("books", Vector3(21.1, y + 0.45, 16.0), 30)
	_prop("vending_machine", Vector3(8.2, y, 19.3), 180)
	_prop("water_cooler", Vector3(9.6, y, 19.45), 180)
	for p in [Vector3(7.6, y, 11.6), Vector3(23.4, y, 11.6), Vector3(13.4, y, 19.4), Vector3(17.6, y, 19.4)]:
		_prop("pottedPlant", p)
	_prop("wheelchair", Vector3(12.2, y, 17.2), 35)
	_prop("trashcan", Vector3(11.4, y, 19.5))
	_prop("rugDoormat", Vector3(15.5, y + 0.005, 19.1))
	_prop("desk", Vector3(15.5, y, 19.2), 0, {"tint": Color(0.8, 0.8, 0.8)})
	_prop("cardboardBoxClosed", Vector3(14.9, y + 0.76, 19.3), 10)
	_prop("cardboardBoxClosed", Vector3(16.1, y, 18.9), -20)
	_prop("blood", Vector3(12.8, y + 0.01, 15.2), 110)
	_inspect(Vector3(15.5, 1.2, 19.3), ["La entrada principal. Cadenas gruesas, un candado del lado de afuera, y una barricada del de adentro.",
		"Alguien no quería que saliéramos. O que algo entrara."])
	_inspect(Vector3(10.0, 1.1, 13.2), ["El libro de ingresos. Última entrada: \"Mujer trae a su hija. Dice que la niebla le habló. Sala 2.\" Después, hojas arrancadas."])
	_inspect(Vector3(23.4, 1.4, 16.0), ["Estática. Por un segundo jurarías que alguien te mira desde la pantalla."])
	_inspect(Vector3(21.0, 1.6, 19.6), ["Rejas soldadas desde adentro. Del otro lado, solo niebla."])

	# Consultorio 2 (x 24-30, z 11-20). Sin luz.
	_prop("desk", Vector3(27, y, 17.6))
	_prop("chairDesk", Vector3(27, y, 18.5))
	_prop("chair", Vector3(27, y, 16.3), 180)
	_prop("bedSingle", Vector3(25.3, y, 13.4), 90, {"colors": hospital_bed_colors})
	_prop("iv_stand", Vector3(26.3, y, 12.1))
	_prop("bathroomCabinet", Vector3(29.88, 1.3, 14.0), -90)
	_prop("blood", Vector3(25.6, y + 0.01, 14.6), 200)

	# Baños (x 30-36, z 11-20).
	for x in [32.0, 34.0]:
		_box(groups.Structure, "Stall", Vector3(x, 1.0, 18.9), Vector3(0.06, 2.0, 1.9), "metal")
	for x in [31.0, 33.0, 35.0]:
		_prop("toilet", Vector3(x, y, 19.3), 180)
	for z in [12.4, 13.8]:
		_prop("bathroomSink", Vector3(35.65, y, z), -90)
		_prop("bathroomMirror", Vector3(35.88, 1.25, z), -90)
	_prop("mop_bucket", Vector3(30.8, y, 12.0))
	_inspect(Vector3(35.4, 1.4, 13.1), ["Tu reflejo tarda un instante en seguirte."])

	# Pasillo PB.
	_prop("bench", Vector3(5.5, y, 10.7), 180)
	_prop("bench", Vector3(22.5, y, 10.7), 180)
	_prop("fire_extinguisher", Vector3(16.0, 0.9, 8.18), 0, {"anchor": 2})
	_prop("fire_extinguisher", Vector3(34.5, 0.9, 10.82), 180, {"anchor": 2})
	_prop("exit_sign", Vector3(35.84, 2.75, 9.5), -90)
	_prop("exit_sign", Vector3(1.5, 2.65, 8.12), 0)
	_prop("wheelchair", Vector3(33.2, y, 9.1), -60)
	_prop("trashcan", Vector3(8.6, y, 10.7))
	_prop("blood", Vector3(2.0, y + 0.01, 9.4), 10)
	_inspect(Vector3(7.5, 1.2, 8.4), ["El ascensor está muerto. Las puertas no ceden ni un centímetro."])
	# Salida de emergencia a la calle (zona 2): se fuerza con la barreta.
	var exit := Area3D.new()
	exit.set_script(load("res://scripts/world/zone_door.gd"))
	exit.set("target_scene", "res://scenes/levels/street.tscn")
	exit.set("target_spawn", &"from_hospital")
	exit.set("required_item", load("res://assets/items/weapon_crowbar.tres"))
	exit.set("unlock_flag", &"hospital_exit_forced")
	exit.set("locked_text", "Salida de emergencia. La traba está oxidada; con algo para hacer palanca se podría forzar.")
	exit.set("unlock_text", "Metí la barreta en la traba y empujé. Cedió con un chillido.")
	exit.position = Vector3(35.6, 1.2, 9.5)
	_add(groups.Inspectables, exit, "EmergencyExit")
	_zone_door_visuals(exit, Vector3(W - TE / 2 - 0.02, 0, 9.5), -90.0, "door_metal_open", "door_chained", 1.2, 2.3)
	# Puerta de guardia (oeste del pasillo): por acá se entra desde la calle de la plaza, la de casa.
	var guard := Area3D.new()
	guard.set_script(load("res://scripts/world/zone_door.gd"))
	guard.set("target_scene", "res://scenes/levels/park_street.tscn")
	guard.set("target_spawn", &"from_hospital")
	guard.position = Vector3(0.6, 1.2, 9.5)
	_add(groups.Inspectables, guard, "GuardDoor")
	_zone_door_visuals(guard, Vector3(TE / 2 + 0.02, 0, 9.5), 90.0, "door_metal_open", "", DOOR_W, DOOR_H)
	var guard_sign := Label3D.new()
	guard_sign.text = "GUARDIA - AMBULANCIAS"
	guard_sign.font = load("res://assets/fonts/pixel_operator/PixelOperator.ttf")
	guard_sign.font_size = 16
	guard_sign.pixel_size = 0.0075
	guard_sign.modulate = Color(0.8, 0.2, 0.15)
	guard_sign.position = Vector3(0.18, 2.7, 9.5)
	guard_sign.rotation_degrees.y = 90.0
	_add(groups.Structure, guard_sign, "GuardSign")


func _first_floor_rooms() -> void:
	var y := H
	# Sala de internación (x 9-24, z 0-8): seis camas.
	var beds := [10.5, 13.0, 15.5, 18.0, 20.5, 23.0]
	for i in beds.size():
		var x: float = beds[i]
		_prop("bed_metal", Vector3(x, y, 1.5), 0)
		# Colchón en todas menos la cama 4 (la del paciente que salió a la niebla).
		if i != 3:
			_box(groups.Props, "Mattress", Vector3(x, y + 0.52, 1.55), Vector3(0.82, 0.14, 1.85), "mattress", false)
		_prop("cabinetBedDrawerTable", Vector3(x + 0.95, y, 0.45))
		_prop("iv_stand", Vector3(x - 0.85, y, 0.9))
		if i < beds.size() - 1:
			_prop("curtain", Vector3(x + 1.25, y, 1.6), 90)
	_prop("chair", Vector3(13.6, y, 3.4), 200)
	_prop("chair", Vector3(21.0, y, 3.2), 150)
	_prop("wheelchair", Vector3(16.6, y, 6.4), 120)
	_prop("blood", Vector3(18.0, y + 0.01, 3.3), 60)
	_prop("blood", Vector3(18.6, y + 0.01, 4.4), 150)
	_inspect(Vector3(18.0, y + 0.7, 1.5), ["Cama 4. Las correas están cortadas. Desde adentro."])
	_inspect(Vector3(11.5, y + 1.6, 0.4), ["Rejas soldadas. Abajo, el estacionamiento se pierde en la niebla. Hay una ambulancia con las puertas abiertas."])

	# Quirófano (x 24-36, z 0-8). Casi a oscuras.
	# Mesa de operaciones: pedestal de metal, base y colchoneta verde.
	_box(groups.Props, "OrBase", Vector3(30.0, y + 0.05, 4.0), Vector3(0.7, 0.1, 0.9), "soot")
	_box(groups.Props, "OrPedestal", Vector3(30.0, y + 0.45, 4.0), Vector3(0.28, 0.8, 0.4), "bars")
	_box(groups.Props, "OrFrame", Vector3(30.0, y + 0.88, 4.0), Vector3(0.62, 0.06, 2.0), "counter_top")
	_box(groups.Props, "OrPad", Vector3(30.0, y + 0.95, 4.0), Vector3(0.56, 0.08, 1.92), "or_pad", false)
	_prop("lampRoundFloor", Vector3(31.2, y, 3.0), 0, {"h": 2.0, "tint": Color(0.8, 0.85, 0.85)})
	for x in [25.4, 26.3]:
		_prop("kitchenCabinet", Vector3(x, y, 0.45))
	_prop("kitchenSink", Vector3(27.2, y, 0.45))
	for z in [2.0, 3.0, 4.0]:
		_prop("tall_cabinet", Vector3(35.6, y, z), -90)
	_prop("iv_stand", Vector3(28.8, y, 3.2))
	_prop("trashcan", Vector3(24.7, y, 7.3))
	_prop("blood", Vector3(29.6, y + 0.01, 4.8), 0)
	_prop("blood", Vector3(30.8, y + 0.01, 5.5), 90)
	_inspect(Vector3(30.0, y + 1.1, 4.0), ["Instrumental sin limpiar sobre la mesa. Nadie terminó esta operación."])

	# Dirección (x 0-7, z 11-20).
	_prop("rugRectangle", Vector3(3.5, y + 0.005, 15.3))
	_prop("desk", Vector3(3.5, y, 17.0))
	_prop("chairDesk", Vector3(3.5, y, 18.0), 180)
	_prop("lampRoundTable", Vector3(4.3, y + 0.76, 17.2))
	_prop("laptop", Vector3(2.7, y + 0.76, 17.1), 160)
	for z in [12.4, 14.2]:
		_prop("bookcaseClosedWide", Vector3(0.4, y, z), 90)
	_prop("loungeChair", Vector3(6.0, y, 13.0), -90)
	_prop("pottedPlant", Vector3(6.4, y, 19.4))
	_point_light(Vector3(4.3, y + 1.4, 17.0), Color(1.0, 0.8, 0.55), 0.7, 4.0)
	_inspect(Vector3(3.5, y + 1.0, 17.3), ["El teléfono no tiene tono. Aun así, del otro lado alguien respira."])

	# Enfermería (x 7-18, z 11-20).
	_counter(8.6, 13.7, 13.3, y)
	_prop("computerScreen", Vector3(10.2, y + 1.05, 13.4))
	_prop("chairDesk", Vector3(10.0, y, 14.3), 180)
	_prop("chairDesk", Vector3(12.6, y, 14.4), 160)
	for x in [8.2, 9.0, 9.8]:
		_prop("file_cabinet", Vector3(x, y, 19.5), 180)
	_prop("first_aid_kit", Vector3(12.5, y + 1.5, 19.84), 180)
	_prop("water_cooler", Vector3(16.8, y, 19.4), 180)
	for z in [15.0, 15.8]:
		_prop("locker", Vector3(17.55, y, z), -90)
	_prop("loungeSofa", Vector3(13.8, y, 19.1), 180)
	_prop("tableCoffee", Vector3(13.8, y, 17.9))
	_inspect(Vector3(11.0, y + 1.1, 13.1), ["Planilla de medicación. Todas las dosis del día 9 están tachadas. Encima alguien escribió: \"Ya no sirve dormirlos.\""])

	# Depósito (x 18-26, z 11-20). Sin luz.
	for x in [19.2, 20.4, 21.6]:
		_prop("bookcaseOpen", Vector3(x, y, 19.55), 180)
		_prop("bookcaseOpen", Vector3(x + 2.6, y, 15.6))
	for p in [Vector3(19.0, y, 12.2), Vector3(19.6, y, 12.4), Vector3(19.3, y + 0.34, 12.3), Vector3(24.8, y, 18.8),
			Vector3(25.2, y, 18.2), Vector3(23.3, y, 17.4)]:
		_prop("cardboardBoxClosed", p, randf_range(-30, 30))
	_prop("cardboardBoxOpen", Vector3(20.6, y, 16.8), 70)
	_prop("mop_bucket", Vector3(25.3, y, 12.1))
	_prop("tall_cabinet", Vector3(18.45, y, 16.0), 90)

	# Archivo (x 26-33, z 11-20).
	for z in [13.0, 16.4]:
		for i in 4:
			_prop("file_cabinet", Vector3(27.2 + i * 0.8, y, z), 180 if z > 15 else 0)
	_prop("desk", Vector3(31.5, y, 19.0))
	_prop("cardboardBoxOpen", Vector3(32.3, y, 12.0), 20)
	_prop("cardboardBoxClosed", Vector3(26.6, y, 19.4))
	_inspect(Vector3(28.4, y + 1.0, 13.6), ["Historias clínicas. Todas terminan el mismo día."])

	# Pasillo P1.
	_prop("bench", Vector3(10.5, y, 10.7), 180)
	_prop("bed_metal", Vector3(27.0, y, 9.6), 80, {"colors": hospital_bed_colors})
	_prop("blood", Vector3(27.5, y + 0.01, 10.2), 30)
	_prop("wheelchair", Vector3(6.6, y, 10.3), 200)
	_prop("fire_extinguisher", Vector3(20.0, y + 0.9, 8.18), 0, {"anchor": 2})
	_prop("exit_sign", Vector3(4.3, y + 2.65, 8.12), 0)
	_prop("trashcan", Vector3(34.8, y, 10.6))
	_inspect(Vector3(7.5, y + 1.2, 8.4), ["Donde estaba el ascensor ahora hay una escalera de servicio. La cabina quedó trabada abajo, en PB.",
		"Alguien atornilló un cartel a mano: \"SALUD MENTAL - 2° PISO\"."])


## P2: Salud Mental (pedido del usuario: un piso más). El protagonista estuvo internado
## acá, en la 203, cuando tocó fondo.
func _second_floor_rooms() -> void:
	var y := 2 * H
	# Descanso de la escalera (x 0-9, z 0-8).
	_prop("bench", Vector3(2.5, y, 0.5))
	_prop("pottedPlant", Vector3(0.6, y, 0.6))
	_prop("trashcan", Vector3(5.4, y, 7.4))
	_box(groups.Props, "Poster", Vector3(0.17, y + 1.6, 4.0), Vector3(0.02, 0.8, 0.6), "paper", false)
	_inspect(Vector3(0.6, y + 1.4, 4.0), ["Un afiche: \"PEDIR AYUDA NO ES DEBILIDAD\". Debajo, el número de la línea de prevención, tachado con birome hasta romper el papel."])

	# Habitaciones 201-203 (x 9-18): cama, mesa de luz, silla. Las ventanas tienen rejas, como todo.
	for x0: float in [9.0, 12.0, 15.0]:
		var cx := x0 + 1.5
		_prop("bedSingle", Vector3(cx + 0.4, y, 1.3), 0, {"colors": hospital_bed_colors})
		_prop("cabinetBedDrawerTable", Vector3(x0 + 0.45, y, 0.45))
		_prop("chair", Vector3(x0 + 0.6, y, 5.6), 40)
	_prop("blood", Vector3(13.4, y + 0.01, 4.6), 70)
	_prop("cardboardBoxOpen", Vector3(11.3, y, 6.8), 20)
	_inspect(Vector3(10.5, y + 0.8, 1.3), ["Las sábanas están atadas en una soga larga. No llega a ningún lado: la ventana tiene rejas."])
	# La 203: la suya.
	_prop("books", Vector3(15.5, y + 0.55, 0.45), 15)
	_prop("radio", Vector3(17.4, y, 6.9), 200)
	_inspect(Vector3(16.9, y + 0.8, 1.3), ["La 203. Acá estuve cuarenta y cinco días, hace dos años, cuando mamá me encontró en el baño.",
		"En la tablilla de los pies de la cama todavía hay una planilla: \"Episodio depresivo mayor. Consumo problemático. Riesgo: alto.\"",
		"Abajo, con la letra de mamá: \"Alta. Ya está. Vamos a casa.\""], 1.1)
	_inspect(Vector3(15.4, y + 1.4, 7.6), ["Las marcas en la pared, al lado de la puerta. Rayitas de a cinco. Las hice yo, con la uña. Cuarenta y cinco."])
	# Aislamiento (x 18-21): paredes acolchadas y un colchón en el piso.
	for z in [0.25]:
		_box(groups.Props, "Padding", Vector3(19.5, y + 1.5, z), Vector3(2.7, 2.9, 0.12), "mattress", false)
	for x in [18.2, 20.8]:
		_box(groups.Props, "Padding", Vector3(x, y + 1.5, 4.0), Vector3(0.12, 2.9, 7.3), "mattress", false)
	_box(groups.Props, "FloorMattress", Vector3(19.5, y + 0.1, 2.0), Vector3(1.9, 0.2, 0.95), "mattress", false)
	_inspect(Vector3(19.5, y + 0.6, 2.0), ["La sala de aislamiento. Las paredes acolchadas están rasguñadas desde adentro, a la altura de la cara."])

	# Terapia grupal (x 21-27): sillas en ronda y un pizarrón.
	for i in 8:
		var a := TAU * i / 8.0
		var p := Vector3(24.0 + cos(a) * 1.8, y, 4.0 + sin(a) * 1.8)
		_prop("chairModernCushion", p, rad_to_deg(-a) - 90.0)
	_box(groups.Props, "Whiteboard", Vector3(24.0, y + 1.5, 0.2), Vector3(2.4, 1.2, 0.04), "paper", false)
	var board := Label3D.new()
	board.text = "SÓLO POR HOY\n\n¿Qué me trajo acá?\n¿Qué me hace seguir?"
	board.font = load("res://assets/fonts/pixel_operator/PixelOperator.ttf")
	board.font_size = 16
	board.pixel_size = 0.006
	board.modulate = Color(0.2, 0.25, 0.45)
	board.position = Vector3(24.0, y + 1.5, 0.23)
	_add(groups.Props, board, "BoardText")
	_inspect(Vector3(24.0, y + 0.9, 4.0), ["Ocho sillas en ronda. Una está dada vuelta, mirando a la pared.",
		"En el grupo había una regla: lo que se dice acá, se queda acá. Ahora no queda nadie para escuchar."], 1.4)

	# Sala de día (x 27-36): mesas, sillones, la tele.
	_prop("loungeSofa", Vector3(33.5, y, 6.9), 180)
	_prop("tableCoffee", Vector3(33.5, y, 5.4))
	_prop("televisionVintage", Vector3(33.5, y + 0.55, 0.55))
	_prop("cabinetTelevision", Vector3(33.5, y, 0.55))
	for p in [Vector3(29.0, y, 2.5), Vector3(29.0, y, 5.5)]:
		_prop("table", p)
		_prop("chair", p + Vector3(0, 0, -0.8))
		_prop("chair", p + Vector3(0, 0, 0.8), 180)
	_prop("bookcaseClosed", Vector3(35.6, y, 3.0), -90)
	_prop("books", Vector3(29.0, y + 0.78, 2.5), 40)
	_inspect(Vector3(29.0, y + 1.0, 2.5), ["Un rompecabezas de mil piezas a medio armar: un faro en la costa. Faltan las piezas del cielo."])

	# Consultorio de psiquiatría (x 0-7, z 11-20).
	_prop("rugRectangle", Vector3(3.5, y + 0.005, 15.5))
	_prop("desk", Vector3(3.5, y, 17.8))
	_prop("chairDesk", Vector3(3.5, y, 18.7), 180)
	_prop("chair", Vector3(3.5, y, 16.7))
	_prop("loungeChair", Vector3(1.2, y, 13.0), 60)
	_prop("bookcaseClosedWide", Vector3(6.55, y, 13.5), -90)
	_prop("plantSmall1", Vector3(4.6, y + 0.76, 17.9))
	_point_light(Vector3(3.5, y + 1.6, 17.6), Color(1.0, 0.82, 0.6), 0.6, 4.0)
	_inspect(Vector3(3.5, y + 1.0, 17.8), ["Sobre el escritorio hay una carpeta con mi nombre, abierta en la última sesión.",
		"\"Refiere mejoría. Duerme mejor. Habla de la madre con menos culpa. Continuar seguimiento ambulatorio.\"",
		"Continuar. Me gusta esa palabra."], 1.1)

	# Enfermería de Salud Mental (x 7-16): el mostrador y el armario de los psicofármacos.
	_counter(8.4, 12.4, 13.3, y)
	_prop("chairDesk", Vector3(10.0, y, 14.3), 180)
	_prop("computerScreen", Vector3(9.6, y + 1.05, 13.4))
	for x in [14.2, 15.0]:
		_prop("tall_cabinet", Vector3(x, y, 19.5), 180)
	_prop("file_cabinet", Vector3(8.0, y, 19.5), 180)
	_prop("water_cooler", Vector3(15.5, y, 12.0), -90)
	_inspect(Vector3(14.6, y + 1.2, 19.0), ["El armario de los psicofármacos. \"BAJO LLAVE\", dice el cartel. Está abierto y vacío.",
		"Lo primero que alguien vino a buscar cuando empezó la niebla. Lo entiendo mejor de lo que quisiera."], 1.1)

	# Archivo de Salud Mental (x 16-26).
	for z in [13.2, 16.6]:
		for i in 5:
			_prop("file_cabinet", Vector3(17.4 + i * 0.85, y, z), 180 if z > 15 else 0)
	_prop("cardboardBoxOpen", Vector3(24.8, y, 19.2), 30)
	_prop("cardboardBoxClosed", Vector3(25.2, y, 12.2))
	_prop("blood", Vector3(22.0, y + 0.01, 15.0), 100)
	_inspect(Vector3(19.0, y + 1.0, 13.6), ["Historias clínicas de Salud Mental. Las del último mes dicen todas lo mismo, con distintas letras:",
		"\"El paciente refiere que la niebla le habla con la voz de alguien que perdió.\""])

	# Duchas (x 26-36).
	for x in [28.0, 30.0, 32.0, 34.0]:
		_box(groups.Structure, "ShowerWall", Vector3(x, y + 1.0, 18.8), Vector3(0.06, 2.0, 2.2), "metal")
	for x in [27.0, 29.0, 31.0, 33.0, 35.0]:
		_box(groups.Props, "ShowerHead", Vector3(x, y + 2.1, 19.75), Vector3(0.15, 0.08, 0.2), "metal", false)
	for z in [12.6, 14.0]:
		_prop("bathroomSink", Vector3(35.65, y, z), -90)
	_prop("mop_bucket", Vector3(26.8, y, 12.0))
	_prop("blood", Vector3(31.0, y + 0.01, 18.6), 30)
	_inspect(Vector3(31.0, y + 1.2, 18.6), ["Una de las duchas está abierta. No sale agua: sale niebla, tibia, despacio."])

	# Pasillo P2.
	_prop("bench", Vector3(27.5, y, 10.7), 180)
	_prop("wheelchair", Vector3(14.6, y, 10.4), 140)
	_prop("fire_extinguisher", Vector3(8.6, y + 0.9, 8.18), 0, {"anchor": 2})
	_prop("exit_sign", Vector3(4.3, y + 2.65, 8.12), 0)
	_prop("trashcan", Vector3(35.0, y, 10.6))

	# Secretos de P2: en Inquieto, el espejo de la 203 pregunta; en Quebrado, alguien está
	# sentado en la ronda de terapia, esperando su turno, y debajo del colchón de la 203
	# aparece lo que escondía hace dos años.
	var mirror := Node3D.new()
	mirror.set_script(GatedScript)
	mirror.set("threshold", 1)
	_add(groups.Secrets, mirror, "Room203Writing")
	var ask := Label3D.new()
	ask.text = "¿TE ACORDÁS\nDE ESTA CAMA?"
	ask.font = load("res://assets/fonts/pixel_operator/PixelOperator.ttf")
	ask.font_size = 32
	ask.pixel_size = 0.007
	ask.modulate = Color(0.55, 0.05, 0.03)
	ask.position = Vector3(16.5, y + 1.8, 0.17)
	_add(mirror, ask, "Label3D")
	var broken := Node3D.new()
	broken.set_script(GatedScript)
	broken.set("threshold", 2)
	_add(groups.Secrets, broken, "GroupFigure")
	_instance("res://scenes/enemies/horror_placeholder.tscn", broken, "Figure", Vector3(24.0, y, 2.2))
	_instance("res://scenes/world/pickup.tscn", broken, "HiddenKit", Vector3(16.9, y + 0.62, 2.0),
		{"item": load("res://assets/items/medicine_kit.tres"), "count": 1})
	_inspect(Vector3(16.9, y + 0.8, 2.6), ["Debajo del colchón hay un hueco cortado con una birome. Ahí escondía las pastillas que no tomaba.",
		"Ahora hay un botiquín. Alguien lo dejó para mí, sabiendo que iba a buscar acá."], 0.8, broken)


## La puerta del sótano (PB, en la pared este del cuarto de la escalera). Se abre con la
## llave que se llevó Ferreyra a su casa (zona de la avenida).
func _basement_door() -> void:
	var door := Area3D.new()
	door.set_script(load("res://scripts/world/zone_door.gd"))
	door.set("target_scene", "res://scenes/levels/hospital_basement.tscn")
	door.set("target_spawn", &"from_hospital")
	door.set("required_item", load("res://assets/items/key_basement.tres"))
	door.set("unlock_flag", &"hospital_basement_open")
	door.set("locked_text", "Una puerta de metal: \"SÓTANO - SOLO PERSONAL\". Tiene una cerradura nueva, de las buenas, y alguien soldó la manija para que no gire sin la llave.")
	door.set("unlock_text", "La llave de Ferreyra entra justa. Del otro lado sube un olor a formol y a algo quemado.")
	door.set("radius", 1.2)
	door.position = Vector3(5.4, 1.2, 4.0)
	_add(groups.Inspectables, door, "BasementDoor")
	_zone_door_visuals(door, Vector3(6.0 - T / 2 - 0.02, 0, 4.0), -90.0, "door_metal_open", "door_chained", 1.3, 2.3, true)
	var sign := Label3D.new()
	sign.text = "SÓTANO"
	sign.font = load("res://assets/fonts/pixel_operator/PixelOperator.ttf")
	sign.font_size = 16
	sign.pixel_size = 0.0075
	sign.modulate = Color(0.8, 0.2, 0.15)
	sign.position = Vector3(5.87, 2.6, 4.0)
	sign.rotation_degrees.y = -90.0
	_add(groups.Structure, sign, "BasementSign")
	_prop("WetFloorSign_01", Vector3(4.8, 0, 5.8), 200)
	var spawn := Marker3D.new()
	spawn.set_script(load("res://scripts/world/spawn_point.gd"))
	spawn.set("spawn_id", &"from_basement")
	spawn.position = Vector3(4.2, 0.05, 3.0)
	spawn.rotation_degrees.y = 180.0
	_add(scene_root, spawn, "SpawnFromBasement")


## Detalles que hacen que el lugar se sienta real (Poly Haven, CC0).
func _details() -> void:
	# Cámaras de seguridad en los extremos de los pasillos, mirando hacia adentro.
	for level: int in [0, 1, 2]:
		var y0 := level * H
		_prop("security_camera_01", Vector3(0.18, y0 + 2.9, 9.5), 90)
		_prop("security_camera_01", Vector3(35.82, y0 + 2.9, 8.6), -90)
	_prop("wall_clock", Vector3(16.5, 2.4, 11.12), 180)            # hall, sobre la abertura
	_prop("wall_clock", Vector3(12.5, H + 2.3, 19.84), 180)        # enfermería
	_prop("WetFloorSign_01", Vector3(24.0, 0, 9.3), 30)
	_prop("WetFloorSign_01", Vector3(31.5, 0, 12.4), -20)
	_prop("wooden_broom", Vector3(25.5, H, 12.8), 10)
	for p in [Vector3(8.8, 0, 7.4), Vector3(34.9, 0, 10.5), Vector3(19.2, H, 13.4), Vector3(35.2, H, 7.2)]:
		_prop("trashbag", p, randf_range(0, 360))
	_prop("electric_stove", Vector3(35.4, 0, 4.4), -90)


## Secretos por cordura (GDD: cada zona tiene al menos uno).
func _secrets() -> void:
	var y := H
	# Con cordura baja la pared del archivo "miente": aparece el cuarto tapiado.
	var symbol := Node3D.new()
	symbol.set_script(GatedScript)
	symbol.set("threshold", 1)
	_add(groups.Secrets, symbol, "WallSymbol")
	var label := Label3D.new()
	label.text = "ACÁ ESTÁN"
	label.font = load("res://assets/fonts/pixel_operator/PixelOperator.ttf")
	label.font_size = 32
	label.pixel_size = 0.01
	label.modulate = Color(0.55, 0.05, 0.03)
	# En la pared de al lado del hueco (no sobre la pared que desaparece).
	label.position = Vector3(32.88, y + 1.8, 13.2)
	label.rotation_degrees.y = -90
	_add(symbol, label, "Label3D")

	var lying := Node3D.new()
	lying.set_script(GatedScript)
	lying.set("mode", 1)
	_add(groups.Secrets, lying, "LyingWall")
	var wall: StaticBody3D = GreyBoxScript.new()
	wall.set("size", Vector3(T, DOOR_H, DOOR_W))
	wall.set("material", mats.wall)
	wall.position = Vector3(33.0, y + DOOR_H / 2, 15.5)
	_add(lying, wall, "Wall")

	# El cuarto tapiado donde se escondió Marta.
	_prop("bed_metal", Vector3(34.6, y, 18.2), 0, {"tint": Color(0.6, 0.55, 0.5)})
	_prop("cardboardBoxOpen", Vector3(35.2, y, 12.2), 40)
	_prop("blood", Vector3(34.4, y + 0.01, 14.8), 20)
	_prop("blood", Vector3(35.0, y + 0.01, 16.4), 120)
	var scrawl := Label3D.new()
	scrawl.text = "NO MIRES\nLA NIEBLA"
	scrawl.font = load("res://assets/fonts/pixel_operator/PixelOperator.ttf")
	scrawl.font_size = 32
	scrawl.pixel_size = 0.008
	scrawl.modulate = Color(0.45, 0.04, 0.03)
	scrawl.position = Vector3(35.83, y + 1.7, 15.5)
	scrawl.rotation_degrees.y = -90
	_add(groups.Secrets, scrawl, "Scrawl")


## Un lugar por ambiente: entrar por primera vez suma al bono de llegar a casa.
func _discovery() -> void:
	var places := [
		["pb_stairs", 0, 0, 6, 8, 0], ["pb_pharmacy", 9, 0, 17, 8, 0], ["pb_consult1", 17, 0, 25, 8, 0],
		["pb_corridor", 0, 8, 36, 11, 0], ["pb_security", 0, 11, 7, 20, 0], ["pb_lobby", 7, 11, 24, 20, 0],
		["pb_consult2", 24, 11, 30, 20, 0], ["pb_baths", 30, 11, 36, 20, 0],
		["p1_stairs", 0, 0, 6, 8, 1], ["p1_ward", 9, 0, 24, 8, 1], ["p1_surgery", 24, 0, 36, 8, 1],
		["p1_corridor", 0, 8, 36, 11, 1], ["p1_director", 0, 11, 7, 20, 1], ["p1_nurses", 7, 11, 18, 20, 1],
		["p1_storage", 18, 11, 26, 20, 1], ["p1_archive", 26, 11, 33, 20, 1], ["p1_hidden", 33, 11, 36, 20, 1],
		["p2_stairs", 0, 0, 6, 8, 2], ["p2_rooms", 9, 0, 18, 8, 2], ["p2_isolation", 18, 0, 21, 8, 2],
		["p2_group", 21, 0, 27, 8, 2], ["p2_dayroom", 27, 0, 36, 8, 2], ["p2_corridor", 0, 8, 36, 11, 2],
		["p2_psych", 0, 11, 7, 20, 2], ["p2_nurses", 7, 11, 16, 20, 2], ["p2_archive", 16, 11, 26, 20, 2],
		["p2_showers", 26, 11, 36, 20, 2],
	]
	var parent := _add(scene_root, Node3D.new(), "Places")
	for p: Array in places:
		var zone := Area3D.new()
		zone.set_script(load("res://scripts/world/discovery_zone.gd"))
		zone.set("place_id", StringName(p[0]))
		zone.set("size", Vector3(p[3] - p[1] - 0.4, 2.8, p[4] - p[2] - 0.4))
		zone.position = Vector3((p[1] + p[3]) / 2.0, p[5] * H + 1.4, (p[2] + p[4]) / 2.0)
		_add(parent, zone, String(p[0]))


func _items() -> void:
	var pickup := "res://scenes/world/pickup.tscn"
	var items := [
		# Refugio
		["VHS", "movie_coast_vhs", Vector3(30.6, 0.55, 0.7), 1],
		["Comic", "comic_lighthouse", Vector3(31.4, 0.46, 6.8), 1],
		# PB
		["Chocolate1", "food_chocolate_bar", Vector3(15.9, 1.2, 0.4), 1],
		["Chocolate2", "food_chocolate_bar", Vector3(11.3, 0.62, 0.4), 1],
		["Water1", "food_water_bottle", Vector3(14.8, 1.05, 6.9), 1],
		["Peaches1", "food_canned_peaches", Vector3(20.6, 0.76, 2.0), 1],
		["Crowbar", "weapon_crowbar", Vector3(1.4, 0.0, 16.4), 1],
		["Water2", "food_water_bottle", Vector3(27.4, 0.76, 17.5), 1],
		["Peaches2", "food_canned_peaches", Vector3(21.3, 0.45, 16.3), 1],
		# P1
		["Pistol", "weapon_pistol", Vector3(3.1, H + 0.76, 16.9), 1],
		["LetterFerreyra", "letter_ferreyra_01", Vector3(3.9, H + 0.76, 16.8), 1],
		["Ammo1", "ammo_9mm", Vector3(11.8, H + 1.05, 13.3), 8],
		["Chocolate3", "food_chocolate_bar", Vector3(13.8, H + 0.45, 17.9), 1],
		["Ammo2", "ammo_9mm", Vector3(21.6, H + 0.9, 19.5), 8],
		["Water3", "food_water_bottle", Vector3(24.2, H, 15.2), 1],
		["Peaches3", "food_canned_peaches", Vector3(20.5, H + 0.55, 0.45), 1],
		# Cuarto tapiado (secreto)
		["LetterMarta", "letter_marta_01", Vector3(34.6, H + 0.5, 18.2), 1],
		# P2 (pocos y separados)
		["Chocolate4", "food_chocolate_bar", Vector3(29.0, 2 * H + 0.78, 5.5), 1],
		["Ammo3", "ammo_9mm", Vector3(3.0, 2 * H + 0.76, 17.8), 6],
		["Bandage3", "medicine_bandage", Vector3(9.0, 2 * H + 1.05, 13.3), 1],
		["Cable4", "material_cable", Vector3(25.0, 2 * H, 18.6), 1],
		# Materiales para el refugio (alcanzan para las primeras mejoras, no para todas).
		["Wood1", "material_wood", Vector3(10.4, 0.0, 6.9), 2],
		["Wood2", "material_wood", Vector3(16.8, 0.0, 18.5), 1],
		["Wood3", "material_wood", Vector3(20.6, H, 17.9), 3],
		["Wood4", "material_wood", Vector3(32.0, H, 12.8), 2],
		["Metal1", "material_metal", Vector3(1.3, 0.0, 12.0), 2],
		["Metal2", "material_metal", Vector3(25.4, H + 0.9, 0.45), 2],
		["Metal3", "material_metal", Vector3(30.9, 0.0, 12.9), 1],
		["Cloth1", "material_cloth", Vector3(13.0, H + 0.72, 1.6), 2],
		["Cloth2", "material_cloth", Vector3(25.3, 0.72, 13.4), 1],
		["Cloth3", "material_cloth", Vector3(24.9, H, 19.2), 2],
		["Cloth4", "material_cloth", Vector3(13.8, H + 0.85, 19.1), 1],
		["Cable1", "material_cable", Vector3(4.4, 0.76, 17.2), 1],
		["Cable2", "material_cable", Vector3(9.8, H + 1.35, 19.5), 1],
		["Cable3", "material_cable", Vector3(4.6, 0.0, 2.0), 1],
	]
	for it: Array in items:
		_instance(pickup, groups.Items, it[0], it[2],
			{"item": load("res://assets/items/%s.tres" % it[1]), "count": it[3]})


func _enemies() -> void:
	var stalker := "res://scenes/enemies/stalker.tscn"
	# Hall de entrada, internación y el depósito a oscuras.
	_instance(stalker, groups.Enemies, "StalkerLobby", Vector3(15.5, 0.05, 16.5), {"wander_radius": 4.0})
	_instance(stalker, groups.Enemies, "StalkerWard", Vector3(16.5, H + 0.05, 5.0), {"wander_radius": 4.0})
	_instance(stalker, groups.Enemies, "StalkerStorage", Vector3(22.0, H + 0.05, 17.5), {"wander_radius": 2.5})
	# P2: uno en el pasillo y otro en la sala de terapia.
	_instance(stalker, groups.Enemies, "StalkerP2Corridor", Vector3(18.0, 2 * H + 0.05, 9.6), {"wander_radius": 6.0})
	_instance(stalker, groups.Enemies, "StalkerGroup", Vector3(24.0, 2 * H + 0.05, 6.6), {"wander_radius": 1.5})
	_instance("res://scenes/enemies/spitter.tscn", groups.Enemies, "SpitterDayRoom", Vector3(31.0, 2 * H + 0.05, 4.0), {"wander_radius": 2.0})
	# Alucinación: la figura del quirófano que se ve en las cámaras (desde Inquieto).
	var hallucination := Node3D.new()
	hallucination.set_script(GatedScript)
	hallucination.set("threshold", 1)
	_add(groups.Secrets, hallucination, "Hallucination")
	_instance("res://scenes/enemies/horror_placeholder.tscn", hallucination, "Figure", Vector3(33.5, H, 6.2))


func _systems() -> void:
	var nav := NavigationRegion3D.new()
	var navmesh := NavigationMesh.new()
	navmesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	navmesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	navmesh.geometry_source_group_name = &"nav_source"
	navmesh.cell_size = 0.25
	navmesh.cell_height = 0.25
	navmesh.agent_height = 2.0  # con 2.25 los dinteles de las puertas (2.4) cortan el navmesh en algunos pisos
	navmesh.agent_radius = 0.5
	navmesh.agent_max_climb = 0.25
	navmesh.agent_max_slope = 40.0
	nav.navigation_mesh = navmesh
	nav.set_script(load("res://scripts/world/runtime_nav_bake.gd"))
	_add(scene_root, nav, "Navigation")
	# El pie de la escalera queda pegado a la puerta y el navmesh se corta ahí:
	# un link une la puerta de PB con el descanso de P1 (los enemigos suben por la rampa).
	var link := NavigationLink3D.new()
	link.bidirectional = true
	link.start_position = Vector3(1.5, 0.0, 8.7)
	link.end_position = Vector3(1.5, H, 1.1)
	_add(nav, link, "StairLink")
	var link2 := NavigationLink3D.new()
	link2.bidirectional = true
	link2.start_position = Vector3(7.5, H, 8.7)
	link2.end_position = Vector3(7.5, 2 * H, 1.1)
	_add(nav, link2, "StairLink")
	var persistence := Node3D.new()
	persistence.set_script(load("res://scripts/world/world_persistence.gd"))
	_add(scene_root, persistence, "WorldPersistence")
	var level_audio := Node.new()
	level_audio.set_script(load("res://scripts/world/level_audio.gd"))
	level_audio.set("ambience", &"hospital")
	_add(scene_root, level_audio, "LevelAudio")
	# Volviendo de la calle se entra por la salida de emergencia, mirando al oeste.
	var spawn := Marker3D.new()
	spawn.set_script(load("res://scripts/world/spawn_point.gd"))
	spawn.set("spawn_id", &"from_street")
	spawn.position = Vector3(33.4, 0.05, 9.5)
	spawn.rotation_degrees.y = 90.0
	_add(scene_root, spawn, "SpawnFromStreet")
	var park_spawn := Marker3D.new()
	park_spawn.set_script(load("res://scripts/world/spawn_point.gd"))
	park_spawn.set("spawn_id", &"from_park")
	park_spawn.position = Vector3(2.7, 0.05, 9.5)
	park_spawn.rotation_degrees.y = -90.0
	_add(scene_root, park_spawn, "SpawnFromPark")
	# Donde llega cada sobreviviente nuevo mientras este sea el refugio activo.
	var refuge_spawn := Marker3D.new()
	refuge_spawn.set_script(load("res://scripts/world/spawn_point.gd"))
	refuge_spawn.set("spawn_id", &"refuge")
	refuge_spawn.position = Vector3(30.0, 0.05, 3.6)
	_add(scene_root, refuge_spawn, "SpawnRefuge")
	# El sobreviviente arranca en el refugio, mirando al televisor.
	_instance("res://scenes/player/player.tscn", scene_root, "Player", Vector3(30.0, 0.05, 3.6))
	_instance("res://scenes/effects/ps1_post_process.tscn", scene_root, "PS1PostProcess", Vector3.ZERO)
	var ui: Node = load("res://scenes/ui/game_ui.tscn").instantiate()
	_add(scene_root, ui, "GameUI")


## El alijo de un refugio según su nivel (lo usa también el teatro).
func _stash_visuals(slot: Node3D, rot: float) -> void:
	_prop("cardboardBoxClosed", Vector3.ZERO, rot, {"parent": _only(slot, 0), "h": 0.55})
	_prop("wooden_crate_02", Vector3.ZERO, rot, {"parent": _only(slot, 1), "h": 0.75})
	_prop("locker", Vector3.ZERO, rot, {"parent": _only(slot, 2), "tint": Color(0.55, 0.6, 0.58)})


# --- Dificultad (pedido del usuario: más locura = más difícil, con recompensas) ---------

## Un acechador extra que solo aparece desde cierta dificultad (DifficultySpawn).
func _extra_enemy(pos: Vector3, min_difficulty: int, wander := 4.0,
		scene_path := "res://scenes/enemies/stalker.tscn", parent: Node = null) -> void:
	var spawn := Marker3D.new()
	spawn.set_script(load("res://scripts/world/difficulty_spawn.gd"))
	spawn.set("enemy_scene", load(scene_path))
	spawn.set("min_difficulty", min_difficulty)
	spawn.set("wander_radius", wander)
	spawn.position = pos
	_add(parent if parent else groups.Enemies, spawn, "ExtraHard" if min_difficulty == 1 else "ExtraInsane")


## Secreto que depende de la dificultad: lo de adentro de `holder` existe solo desde
## `min_difficulty` (REVEAL) o solo por debajo (HIDE: paredes que "mienten").
func _difficulty_gate(base_name: String, min_difficulty: int, hide_when_insane := false) -> Node3D:
	var gate := Node3D.new()
	gate.set_script(GatedScript)
	gate.set("use_difficulty", true)
	gate.set("threshold", min_difficulty)
	gate.set("mode", 1 if hide_when_insane else 0)
	return _add(groups.Secrets, gate, base_name)


func _difficulty_enemies() -> void:
	_extra_enemy(Vector3(21.0, 0.05, 9.6), 1, 5.0)
	_extra_enemy(Vector3(13.0, H + 0.05, 9.6), 1, 5.0)
	_extra_enemy(Vector3(27.5, 0.05, 15.5), 2, 2.5)
	_extra_enemy(Vector3(14.0, H + 0.05, 4.0), 2, 3.0)
	_extra_enemy(Vector3(30.0, H + 0.05, 9.6), 2, 4.0)
	_extra_enemy(Vector3(31.0, 2 * H + 0.05, 9.6), 1, 4.0)
	_extra_enemy(Vector3(12.0, 2 * H + 0.05, 15.5), 2, 3.0)


## La armería de seguridad (desde Difícil): detrás de la pared de Seguridad, al oeste,
## Ferreyra tapió las armas de los guardias. Hay una escopeta mucho antes del teatro.
func _difficulty_secrets() -> void:
	var wall_gate := _difficulty_gate("ArmoryWall", 1, true)
	var wall: StaticBody3D = GreyBoxScript.new()
	wall.set("size", Vector3(TE, DOOR_H, DOOR_W))
	wall.set("material", mats.wall)
	wall.position = Vector3(0.0, DOOR_H / 2, 16.5)
	_add(wall_gate, wall, "Wall")
	# Una pista desde Inquieto (estado de cordura), en la pared de los lockers.
	var hint := Node3D.new()
	hint.set_script(GatedScript)
	hint.set("threshold", 1)
	_add(groups.Secrets, hint, "ArmoryHint")
	var label := Label3D.new()
	label.text = "ACÁ ADENTRO\nESTÁN LAS ARMAS"
	label.font = load("res://assets/fonts/pixel_operator/PixelOperator.ttf")
	label.font_size = 32
	label.pixel_size = 0.007
	label.modulate = Color(0.55, 0.05, 0.03)
	label.position = Vector3(0.17, 1.9, 16.5)
	label.rotation_degrees.y = 90
	_add(hint, label, "Label3D")
	# El cuarto (x -3.2..0, z 15..18), afuera del edificio.
	var room := _difficulty_gate("Armory", 1)
	_box(room, "ArmoryFloor", Vector3(-1.6, -0.01, 16.5), Vector3(3.2, 0.02, 3.0), "concrete")
	_box(room, "ArmoryCeiling", Vector3(-1.6, CEIL + 0.01, 16.5), Vector3(3.2, 0.02, 3.0), "ceiling", false)
	_box(room, "ArmoryWallW", Vector3(-3.3, CEIL / 2, 16.5), Vector3(0.2, CEIL, 3.2), "wall")
	_box(room, "ArmoryWallN", Vector3(-1.6, CEIL / 2, 14.9), Vector3(3.4, CEIL, 0.2), "wall")
	_box(room, "ArmoryWallS", Vector3(-1.6, CEIL / 2, 18.1), Vector3(3.4, CEIL, 0.2), "wall")
	_box(room, "GunRack", Vector3(-3.1, 1.3, 16.5), Vector3(0.15, 1.6, 2.4), "metal", false)
	_box(room, "Table", Vector3(-1.6, 0.42, 17.6), Vector3(1.6, 0.84, 0.6), "counter")
	_point_light(Vector3(-1.6, 2.6, 16.5), Color(0.9, 0.85, 0.7), 0.7, 4.5, true, room)
	var pickup := "res://scenes/world/pickup.tscn"
	for it: Array in [["ArmoryShotgun", "weapon_shotgun", Vector3(-1.8, 0.9, 17.6), 1],
			["ArmoryShells", "ammo_shells", Vector3(-1.0, 0.9, 17.6), 6],
			["ArmoryKit", "medicine_kit", Vector3(-2.6, 0.05, 15.5), 1]]:
		_instance(pickup, room, it[0], it[2], {"item": load("res://assets/items/%s.tres" % it[1]), "count": it[3]})
	_inspect(Vector3(-2.9, 1.4, 16.5), ["La armería de los guardias. Alguien la tapió con durlock y pintura del mismo verde.",
		"Faltan casi todas las armas. Quedó la escopeta, como si alguien hubiera sabido que ibas a venir."], 1.0, room)
	# Remedios: es un hospital.
	for it: Array in [["Bandage1", "medicine_bandage", Vector3(12.0, 1.05, 4.0), 2],
			["Bandage2", "medicine_bandage", Vector3(27.0, H + 0.9, 3.0), 1],
			["MedKit1", "medicine_kit", Vector3(13.2, H + 0.95, 13.4), 1]]:
		_instance(pickup, groups.Items, it[0], it[2], {"item": load("res://assets/items/%s.tres" % it[1]), "count": it[3]})


# --- Puertas (pedido del usuario: que se note cuáles se pueden cruzar) ---------------

const DOORS := "res://assets/models/doors/"


## Modelo de puerta sin colisión (assets/models/doors: origen abajo al centro, frente +Z,
## 1.02 x 2.1 m) en `pos` (piso, sobre el plano de la pared), con el frente hacia `yaw`.
## Se estira a `width` x `height`. Con `exact_name` el nodo se llama así (para que una
## ZoneDoor encuentre su "OpenDoor" / "LockedDoor"); si no, se numera.
func _door_prop(parent: Node, node_name: String, model: String, pos: Vector3, yaw: float,
		width := 1.02, height := 2.1, exact_name := false) -> Node3D:
	var p: Node3D = PropScript.new()
	p.set("model", load(DOORS + model + ".glb"))
	p.set("anchor", 3)  # Prop.Anchor.ORIGIN
	p.set("collision", false)
	p.set("tint", Color(0.85, 0.82, 0.78))
	p.position = pos
	p.rotation_degrees.y = yaw
	p.scale = Vector3(width / 1.02, height / 2.1, 1.0)
	if exact_name:
		p.name = node_name
		parent.add_child(p)
		p.owner = scene_root
		return p
	return _add(parent, p, node_name)


## Las puertas visibles de una ZoneDoor: la entreabierta y, si se traba, la cerrada.
## `wall_pos` es el pie de la puerta sobre la pared (en coordenadas del nivel).
func _zone_door_visuals(door: Node3D, wall_pos: Vector3, yaw: float, open_model: String,
		locked_model := "", width := 1.02, height := 2.1, facade := false) -> void:
	var rel := wall_pos - door.position
	var open_yaw := yaw
	if facade:
		# Fachada sin hueco real: la hoja se abre hacia afuera y atrás hay un "interior" oscuro.
		open_yaw = yaw + 180.0
		var front := Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3.FORWARD * -1.0
		var size := Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(width * 0.92, height * 0.97, 0.02)
		var gap := _box(door, "DoorGap", rel + front * 0.012 + Vector3.UP * height * 0.485,
			Vector3(absf(size.x), absf(size.y), absf(size.z)), "door_gap", false)
		gap.name = "DoorGap"
	_door_prop(door, "OpenDoor", open_model, rel, open_yaw, width, height, true)
	if locked_model != "":
		_door_prop(door, "LockedDoor", locked_model, rel, yaw, width, height, true)
