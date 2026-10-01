extends SceneTree
## Genera res://scenes/levels/hospital.tscn: Hospital San Judas, primera zona del
## juego (GDD: "Edificio: interiores, tutorial de exploración y primeras cartas").
## Es un andamio de una sola pasada: después de editar la escena en el editor,
## NO volver a correrlo (pisaría los cambios).
## Uso: <godot> --headless --path . -s res://tools/build_hospital.gd
##
## Planta (x = este, z = sur, 1 unidad = 1 m). Dos pisos de 3.5 m (PB y P1):
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
const ROOF := 7.0
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
	_details()
	_secrets()
	_discovery()
	_items()
	_enemies()
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
	# Techo.
	_box(groups.Structure, "Roof", Vector3(W / 2, ROOF - 0.15, D / 2), Vector3(W, 0.3, D), "ceiling")

	# Paredes exteriores (de la losa al techo, con ventanas de los dos pisos).
	var hw := -0.3
	var eh := ROOF - hw
	_wall("x", 0.0, -TE / 2, W + TE / 2, hw, eh, TE,
		[_window(13, 0.3), _window(21, 0.3), _window(30, 0.3), _window(33.5, 0.3),
		_window(11.5, H + 0.3), _window(15, H + 0.3), _window(18.5, H + 0.3), _window(22, H + 0.3)])
	_wall("x", D, -TE / 2, W + TE / 2, hw, eh, TE,
		[_window(3.5, 0.3), _window(10, 0.3), _window(21, 0.3), _window(27, 0.3),
		_window(3.5, H + 0.3), _window(10, H + 0.3), _window(15, H + 0.3), _window(29.5, H + 0.3)])
	_wall("z", 0.0, TE / 2, D - TE / 2, hw, eh, TE,
		[[9.5, DOOR_W, 0.0, -hw + DOOR_H], [9.5, 1.6, H + 1.3, H + 2.6]])
	_wall("z", W, TE / 2, D - TE / 2, hw, eh, TE, [[9.5, 1.6, H + 1.3, H + 2.6]])

	# Paredes interiores por planta.
	for level: int in [0, 1]:
		var y0 := level * H
		var north_doors := [_door(1.5), _door(12.5), _door(20.5), _door(28)] if level == 0 \
			else [_door(4.3), _door(12), _door(21), _door(29.5)]
		var south_doors := [_door(3.5), [15.5, 7.0, 0.0, 2.8], _door(27), _door(33)] if level == 0 \
			else [_door(3.5), [12.5, 5.0, 0.0, 2.8], _door(22), _door(29.5)]
		_wall("x", 8.0, TE / 2, W - TE / 2, y0, CEIL, T, north_doors)
		_wall("x", 11.0, TE / 2, W - TE / 2, y0, CEIL, T, south_doors)
		# Pasamanos a los dos lados del pasillo (el ascensor también corta el de la pared norte).
		_handrail(8.0 + T / 2, 1.0, 0.3, W - 0.3, y0, north_doors + [[7.5, 1.5]])
		_handrail(11.0 - T / 2, -1.0, 0.3, W - 0.3, y0, south_doors)
		var signs := [["ESCALERA", 1.5, true], ["FARMACIA", 12.5, true], ["CONSULTORIO 1", 20.5, true],
			["PERSONAL", 28.0, true], ["SEGURIDAD", 3.5, false], ["HALL", 15.5, false],
			["CONSULTORIO 2", 27.0, false], ["BAÑOS", 33.0, false]] if level == 0 else \
			[["ESCALERA", 4.3, true], ["INTERNACIÓN", 12.0, true], ["INTERNACIÓN", 21.0, true],
			["QUIRÓFANO", 29.5, true], ["DIRECCIÓN", 3.5, false], ["ENFERMERÍA", 12.5, false],
			["DEPÓSITO", 22.0, false], ["ARCHIVO", 29.5, false]]
		for s: Array in signs:
			# Sobre las aberturas anchas (2.8 m) el cartel va más alto.
			var wide: bool = s[0] == "HALL" or s[0] == "ENFERMERÍA"
			_room_sign(s[0], s[1], 8.0 + T / 2 if s[2] else 11.0 - T / 2, y0, s[2], 3.0 if wide else 2.62)
		var north_parts := [6.0, 9.0, 17.0, 25.0] if level == 0 else [6.0, 9.0, 24.0]
		for x in north_parts:
			_wall("z", x, TE / 2, 8.0 - T / 2, y0, CEIL, T)
		var south_parts := [7.0, 24.0, 30.0] if level == 0 else [7.0, 18.0, 26.0]
		for x in south_parts:
			_wall("z", x, 11.0 + T / 2, D - TE / 2, y0, CEIL, T)
	# Pared del archivo al cuarto tapiado (P1, x 33): con un hueco que tapa la "pared que miente".
	_wall("z", 33.0, 11.0 + T / 2, D - TE / 2, H, CEIL, T, [[15.5, DOOR_W, 0.0, DOOR_H]], "wall", false)

	# Puertas cerradas: ascensor (dos pisos), entrada principal, salida de emergencia.
	_closed_door(Vector3(7.5, 0, 8.0), 0.0, 1.4)
	_closed_door(Vector3(7.5, H, 8.0), 0.0, 1.4)
	_closed_door(Vector3(15.0, 0, D - 0.02), 180.0, 0.95, 2.4)
	_closed_door(Vector3(16.0, 0, D - 0.02), 180.0, 0.95, 2.4)
	_closed_door(Vector3(W - 0.02, 0, 9.5), -90.0, 1.2, 2.3)


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


func _lights() -> void:
	# Pasillos: tubos cada 6 m; algunos parpadean y otros están muertos (bolsones de oscuridad).
	var pb := {3: "on", 9: "flicker", 15: "on", 21: "off", 27: "on", 33: "flicker"}
	var p1 := {3: "off", 9: "on", 15: "flicker", 21: "on", 27: "off", 33: "flicker"}
	for x: int in pb:
		_ceiling_light(x, 9.5, 0, pb[x])
	for x: int in p1:
		_ceiling_light(x, 9.5, 1, p1[x])
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
	# Puerta de guardia (oeste del pasillo): por acá se entra desde la calle de la plaza, la de casa.
	_closed_door(Vector3(0.02, 0, 9.5), -90.0, 1.4, 2.3)
	var guard := Area3D.new()
	guard.set_script(load("res://scripts/world/zone_door.gd"))
	guard.set("target_scene", "res://scenes/levels/park_street.tscn")
	guard.set("target_spawn", &"from_hospital")
	guard.position = Vector3(0.6, 1.2, 9.5)
	_add(groups.Inspectables, guard, "GuardDoor")
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
	_inspect(Vector3(7.5, y + 1.2, 8.4), ["El ascensor. Adentro de la cabina, detenida entre pisos, algo golpea despacio. Siempre tres veces."])


## Detalles que hacen que el lugar se sienta real (Poly Haven, CC0).
func _details() -> void:
	# Cámaras de seguridad en los extremos de los pasillos, mirando hacia adentro.
	for level: int in [0, 1]:
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
	navmesh.agent_height = 2.25
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
	spawn.position = Vector3(34.6, 0.05, 9.5)
	spawn.rotation_degrees.y = 90.0
	_add(scene_root, spawn, "SpawnFromStreet")
	var park_spawn := Marker3D.new()
	park_spawn.set_script(load("res://scripts/world/spawn_point.gd"))
	park_spawn.set("spawn_id", &"from_park")
	park_spawn.position = Vector3(1.5, 0.05, 9.5)
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
