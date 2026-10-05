extends SceneTree
## Genera res://scenes/levels/street.tscn: la avenida detrás del Hospital San Judas,
## segunda zona del juego. Pedido del usuario: "por lo menos 10 veces más grande" que la
## cuadra original (66 x 12 m). Andamio de una sola pasada: si se edita la escena en el
## editor, no volver a correrlo. También guarda los helpers de calles y manzanas que usa
## tools/build_park.gd (el barrio).
## Uso: <godot> --headless --path . -s res://tools/build_street.gd
##
## Planta (x = este, z = sur, 1 unidad = 1 m):
##   Avenida     z 0, cuatro carriles (veredas hasta |z| = 9), de x 0 (la fachada de atrás del
##               hospital, salida de emergencia) a x 216 (Teatro Imperio). Barricada en x 160.
##   Paraná x 48 y Uruguay x 120: al norte, hasta Lavalle (z -72, x 42..126).
##   Callejón     x 60..66, de Lavalle al patio de servicio (x 54..74, z -112..-100).
##   Viamonte x 84 y Talcahuano x 180: al sur, hasta Tucumán (z 66, x 78..186).

const OUT_SCENE := "res://scenes/levels/street.tscn"
const MAT_DIR := "res://assets/materials/street/"
const TEX_DIR := "res://assets/textures/hospital/"
const CITY := "res://assets/models/city/"
const CARS := "res://assets/models/props/cars/"
const POLYHAVEN := "res://assets/models/props/polyhaven/"
const HOSP := "res://assets/models/props/hospital/"
const FONT := "res://assets/fonts/pixel_operator/PixelOperator.ttf"
const NATURE := "res://assets/models/nature/"
const FENCE_H := 2.3

const WALK := 6.0      # borde exterior de las veredas de una calle de dos manos (|z|)
const AVE := 9.0       # lo mismo para la avenida de cuatro carriles
const CAR_SCALE := 1.5  # el Car Kit de Kenney viene chico

const AVE_END := 216.0
const NORTH_X := [48.0, 120.0]
const SOUTH_X := [84.0, 180.0]
const LAVALLE_Z := -72.0
const LAVALLE_X := Vector2(42.0, 126.0)
const TUCUMAN_Z := 66.0
const TUCUMAN_X := Vector2(78.0, 186.0)
const ALLEY_X := Vector2(60.0, 66.0)
const PATIO := Rect2(54.0, -112.0, 20.0, 12.0)
const NICHE_X := 64.0
const BARRICADE_X := 160.0

## Edificios del City MegaKit: rango local en x del frente y profundidad (el frente está en z = 0).
const BUILDINGS := {
	"Building_Large_2": {"x": Vector2(-9.32, 11.32), "depth": 16.3},
	"Building_Medium_2_001": {"x": Vector2(-7.53, 7.53), "depth": 12.5},
	"Building_Small_1": {"x": Vector2(-7.23, 5.23), "depth": 12.2},
}
const MODELS := ["Building_Small_1", "Building_Medium_2_001", "Building_Large_2"]
const TINTS := [Color(0.6, 0.6, 0.62), Color(0.66, 0.62, 0.6), Color(0.68, 0.64, 0.6),
	Color(0.62, 0.64, 0.66), Color(0.58, 0.56, 0.55), Color(0.7, 0.66, 0.62)]

var scene_root: Node3D
var mats := {}
var counters := {}
var groups := {}

var GreyBoxScript: Script
var PropScript: Script
var InspectableScript: Script
var FlickerScript: Script
var GatedScript: Script

## Las puertas que se abren (casas chicas, comisaría, iglesia, la casa de Ferreyra):
## [id, modelo del edificio, origen (pie del frente), hacia dónde mira, escena, puerta, ancho, alto].
var specials := []


func _initialize() -> void:
	GreyBoxScript = load("res://scripts/world/grey_box.gd")
	PropScript = load("res://scripts/world/prop.gd")
	InspectableScript = load("res://scripts/world/inspectable.gd")
	FlickerScript = load("res://scripts/world/flicker_light.gd")
	GatedScript = load("res://scripts/world/sanity_gated.gd")
	seed(1987)
	_make_materials()

	scene_root = Node3D.new()
	scene_root.name = "Street"
	for g in ["Structure", "Buildings", "Lights", "Props", "Cars", "Items", "Inspectables", "Secrets", "Enemies"]:
		groups[g] = _add(scene_root, Node3D.new(), g)
	for g in ["Structure", "Buildings", "Props", "Cars"]:
		groups[g].add_to_group(&"nav_source", true)

	var houses := "res://scenes/levels/street_houses/%s.tscn"
	specials = [
		["ibarra", "Building_Small_1", Vector3(22.0, 0, -AVE), 0.0, houses, "door_wood_open", 1.2, 2.3],
		["comisaria", "Building_Large_2", Vector3(50.0, 0, AVE), 180.0, "res://scenes/levels/police_station.tscn", "door_metal_open", 1.6, 2.6],
		["almacen", "Building_Small_1", Vector3(130.0, 0, AVE), 180.0, houses, "door_wood_open", 1.2, 2.3],
		["pension", "Building_Medium_2_001", Vector3(190.0, 0, -AVE), 0.0, houses, "door_wood_open", 1.2, 2.3],
		["relojeria", "Building_Medium_2_001", Vector3(NORTH_X[1] - WALK, 0, -37.5), 90.0, houses, "door_wood_open", 1.2, 2.3],
		["ferreyra", "Building_Small_1", Vector3(100.0, 0, LAVALLE_Z - WALK), 0.0, houses, "door_wood_open", 1.2, 2.3],
		["iglesia", "Building_Large_2", Vector3(132.0, 0, TUCUMAN_Z - WALK), 0.0, "res://scenes/levels/church.tscn", "door_wood_open", 1.7, 2.8],
	]

	_environment()
	_ground()
	_hospital_back()
	_blocks()
	_alley()
	_theater()
	_barricade()
	_dressing()
	_street_signs()
	_secrets()
	_discovery()
	_inspectables()
	_house_doors()
	_items()
	_enemies()
	_street_extras()
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
		"ground": ["concrete", Color(0.34, 0.34, 0.34), 0.2],
		"collider": ["", Color(1, 1, 1), 1.0],
		"cap": ["concrete", Color(0.4, 0.38, 0.36), 0.5],
		"marquee": ["", Color(0.3, 0.08, 0.06), 1.0],
		"bulb": ["", Color(1.0, 0.85, 0.55), 1.0],
		"sign": ["", Color(0.12, 0.26, 0.2), 1.0],
		"tape": ["", Color(0.85, 0.7, 0.15), 1.0],
		"plywood": ["wood_floor", Color(0.62, 0.52, 0.4), 0.8],
		"metal": ["metal_green", Color(0.5, 0.52, 0.5), 0.9],
		"door_gap": ["", Color(0.015, 0.012, 0.012), 1.0],
		"iron": ["", Color(0.08, 0.08, 0.09), 1.0],
		"grass": ["concrete", Color(0.22, 0.3, 0.18), 0.25],
		"path": ["concrete", Color(0.55, 0.52, 0.48), 0.4],
		"water": ["", Color(0.08, 0.12, 0.14), 1.0],
		"window_dark": ["", Color(0.07, 0.08, 0.1), 1.0],
		"attic_glow": ["", Color(0.4, 0.12, 0.08), 1.0],
		"swing": ["metal_green", Color(0.45, 0.2, 0.15), 1.0],
		"asphalt": ["concrete", Color(0.2, 0.2, 0.21), 0.3],
		"sidewalk": ["concrete", Color(0.42, 0.41, 0.4), 0.5],
		"pit": ["", Color(0.01, 0.01, 0.012), 1.0],
		"rubble": ["concrete", Color(0.36, 0.33, 0.3), 0.7],
		"court": ["concrete", Color(0.5, 0.5, 0.49), 0.35],
		"plaster": ["concrete", Color(0.62, 0.6, 0.56), 0.5],
		"glass": ["", Color(0.05, 0.08, 0.09), 1.0],
		"guard_red": ["", Color(0.55, 0.06, 0.05), 1.0],
		"cross_red": ["", Color(0.8, 0.08, 0.06), 1.0],
		"pharma_green": ["", Color(0.1, 0.55, 0.2), 1.0],
		"sign_board": ["", Color(0.16, 0.15, 0.14), 1.0],
		"dumpster": ["metal_green", Color(0.2, 0.32, 0.22), 0.9],
		"tarp": ["", Color(0.72, 0.72, 0.68), 1.0],
		"biohazard": ["", Color(0.6, 0.1, 0.08), 1.0],
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
		match key:
			"bulb":
				m.set_shader_parameter(&"emission_color", Color(1.0, 0.8, 0.45))
			"attic_glow":
				m.set_shader_parameter(&"emission_color", Color(0.5, 0.12, 0.06))
			"guard_red":
				m.set_shader_parameter(&"emission_color", Color(0.45, 0.04, 0.03))
			"cross_red":
				m.set_shader_parameter(&"emission_color", Color(0.9, 0.08, 0.05))
			"glass":
				m.set_shader_parameter(&"emission_color", Color(0.03, 0.06, 0.065))
			"pharma_green":
				m.set_shader_parameter(&"emission_color", Color(0.08, 0.6, 0.18))
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
	if maxf(size.x, maxf(size.y, size.z)) > 1.5 and visible:
		b.set("subdivisions_per_meter", 1.0)
	if not collision:
		b.set("collision_enabled", false)
	if not visible:
		b.set("mesh_visible", false)
	b.position = center
	return _add(parent, b, base_name)


## Límite invisible (de x0,z0 a x1,z1, alto `height`).
func _blocker(x0: float, z0: float, x1: float, z1: float, height := 6.0, parent: Node = null) -> void:
	_box(parent if parent else groups.Structure, "Blocker",
		Vector3((x0 + x1) / 2, height / 2, (z0 + z1) / 2),
		Vector3(maxf(absf(x1 - x0), 0.3), height, maxf(absf(z1 - z0), 0.3)), "collider", true, false)


## Pieza del kit en su propio origen (sin centrar) y sin colisión propia.
func _piece(path: String, pos: Vector3, rot_y := 0.0, parent: Node = null, tint := Color(0.8, 0.79, 0.78),
		scale := 1.0) -> Node3D:
	var p: Node3D = PropScript.new()
	p.set("model", load(path))
	p.set("anchor", 3)  # Prop.Anchor.ORIGIN
	p.set("collision", false)
	p.set("model_scale", scale)
	p.set("tint", tint)
	p.position = pos
	p.rotation_degrees.y = rot_y
	return _add(parent if parent else groups.Structure, p, path.get_file().get_basename())


## Prop apoyado en el piso con su caja de colisión. `h` = alto real en metros.
func _prop(path: String, pos: Vector3, rot_y := 0.0, extra := {}) -> Node3D:
	var p: Node3D = PropScript.new()
	p.set("model", load(path))
	if extra.has("h"):
		p.set("fit_height", extra.h)
	elif extra.has("L"):
		p.set("fit_largest", extra.L)
	else:
		p.set("model_scale", extra.get("s", 1.0))
	if extra.has("anchor"):
		p.set("anchor", extra.anchor)
	p.set("collision", extra.get("col", true))
	p.set("tint", extra.get("tint", Color(0.8, 0.79, 0.77)))
	p.position = pos
	p.rotation_degrees.y = rot_y
	return _add(extra.get("parent", groups.Props), p, extra.get("name", path.get_file().get_basename()))


func _ph(id: String) -> String:
	return POLYHAVEN + id + "/" + id + ".gltf"


func _car(model: String, pos: Vector3, rot_y: float, tint := Color(0.7, 0.68, 0.66)) -> Node3D:
	return _prop(CARS + model + ".glb", pos, rot_y, {"s": CAR_SCALE, "tint": tint, "parent": groups.Cars})


## Edificio del kit con el frente mirando a `facing` (grados: 0 = +Z / sur, 180 = norte,
## 90 = este, -90 = oeste) y su colisión como una caja sin el porche.
func _building(model: String, origin: Vector3, facing: float, tint := Color(0.72, 0.7, 0.7)) -> void:
	_piece(CITY + model + ".gltf", origin, facing, groups.Buildings, tint)
	var info: Dictionary = BUILDINGS[model]
	var xr: Vector2 = info.x
	var local_center := Vector3((xr.x + xr.y) / 2, 0, -info.depth / 2)
	var basis := Basis(Vector3.UP, deg_to_rad(facing))
	var center: Vector3 = origin + basis * local_center
	var size := basis * Vector3(xr.y - xr.x, 0, info.depth)
	_box(groups.Buildings, "BuildingCollider", center + Vector3.UP * 10.0,
		Vector3(absf(size.x), 20.0, absf(size.z)), "collider", true, false)


## Pared de ladrillo (piezas de 2 x 4 m) de `a` a `b` sobre el piso, `rows` pisos de alto.
## Las piezas tienen una sola cara: con `double_sided` se pone otra de espaldas.
func _brick_wall(a: Vector3, b: Vector3, rows := 1, parent: Node = null, double_sided := true) -> void:
	var dir := (b - a)
	var length := dir.length()
	var count := maxi(roundi(length / 2.0), 1)
	var step := dir / count
	# El frente de la pieza mira a +Z local; se orienta hacia el lado "derecho" del recorrido.
	var facing := rad_to_deg(atan2(dir.x, dir.z)) - 90.0
	var back := Basis(Vector3.UP, deg_to_rad(facing)) * Vector3(0, 0, -0.2)
	var holder: Node3D = parent if parent else groups.Structure
	for i in count:
		for r in rows:
			var pos := a + step * (i + 0.5) + Vector3.UP * 4.0 * r
			_piece(CITY + "Brick_Plain_4.gltf", pos, facing, holder)
			if double_sided:
				_piece(CITY + "Brick_Plain_4.gltf", pos + back, facing + 180.0, holder)
	var normal := back * 0.5
	_box(holder, "WallCollider", (a + b) / 2 + normal + Vector3.UP * 2.0 * rows,
		Vector3(absf(dir.x) + 0.2 if absf(dir.x) > 0.01 else 0.2, 4.0 * rows, absf(dir.z) + 0.2 if absf(dir.z) > 0.01 else 0.2),
		"collider", true, false)


func _label(parent: Node, text: String, pos: Vector3, rot_y: float, color: Color, px := 0.01, size := 32) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = load(FONT)
	label.font_size = size
	label.pixel_size = px
	label.modulate = color
	label.position = pos
	label.rotation_degrees.y = rot_y
	# Los Label3D no usan el shader PS1: se desvanecen con la distancia para no atravesar la niebla.
	label.visibility_range_end = 16.0
	label.visibility_range_end_margin = 6.0
	label.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return _add(parent, label, "Label")


func _inspect(pos: Vector3, texts: Array, radius := 1.0) -> void:
	var a := Area3D.new()
	a.set_script(InspectableScript)
	a.set("texts", PackedStringArray(texts))
	a.set("radius", radius)
	a.position = pos
	_add(groups.Inspectables, a, "Inspect")


func _light(pos: Vector3, color: Color, energy: float, light_range: float, flicker := false) -> void:
	var light := OmniLight3D.new()
	if flicker:
		light.set_script(FlickerScript)
		light.set("flicker_chance", 0.6)
		light.set("min_energy_factor", 0.15)
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.omni_attenuation = 1.2
	light.position = pos
	_add(groups.Lights, light, "Light")


func _instance(path: String, parent: Node, base_name: String, pos: Vector3, props := {}) -> Node:
	var inst: Node = load(path).instantiate()
	for k: String in props:
		inst.set(k, props[k])
	if inst is Node3D:
		(inst as Node3D).position = pos
	return _add(parent, inst, base_name)



## Reja de barrotes de `a` a `b` (alineada a un eje): barrotes en una sola malla, dos
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


func _nature(model: String, pos: Vector3, height: float, rot := -1.0, parent: Node = null) -> void:
	var extra := {"h": height, "tint": Color(0.55, 0.6, 0.55), "col": false}
	if parent:
		extra["parent"] = parent
	_prop(NATURE + model + ".glb", pos, rot if rot >= 0.0 else randf_range(0, 360), extra)


## Tamaño alineado a los ejes de una caja de tamaño local `v` girada con `basis`.
func _rsize(basis: Basis, v: Vector3) -> Vector3:
	var r := basis * v
	return Vector3(absf(r.x), absf(r.y), absf(r.z))


## Una pared de ladrillo de a a b con la cara hacia `front` (vector del plano).
func _brick_facing(a: Vector3, b: Vector3, front: Vector3, rows := 2, parent: Node = null) -> void:
	var d := (b - a).normalized()
	if Vector3(-d.z, 0, d.x).dot(front) < 0.0:
		_brick_wall(b, a, rows, parent, false)
	else:
		_brick_wall(a, b, rows, parent, false)


## Una cuadra: edificios del kit uno al lado del otro sobre la línea a-b, con el frente
## hacia `facing` (0 = sur, 180 = norte, 90 = este, -90 = oeste). Lo que sobra se tapa con
## ladrillo y toda la línea lleva un límite invisible. Algunas puertas se tapian.
func _frontage(a: Vector3, b: Vector3, facing: float, doors := true) -> void:
	var dir := (b - a).normalized()
	var length := a.distance_to(b)
	var basis := Basis(Vector3.UP, deg_to_rad(facing))
	var front := basis * Vector3(0, 0, 1)
	var s := signf((basis * Vector3.RIGHT).dot(dir))
	var cursor := 0.0
	while true:
		var fits: Array = MODELS.filter(func(m: String) -> bool:
			var xr: Vector2 = BUILDINGS[m].x
			return xr.y - xr.x <= length - cursor + 0.05)
		if fits.is_empty():
			break
		var m: String = fits.pick_random()
		var xr: Vector2 = BUILDINGS[m].x
		var o := cursor - xr.x if s > 0 else cursor + xr.y
		var origin := a + dir * o
		_building(m, origin, facing, TINTS.pick_random())
		if doors:
			_door_prop(groups.Props, "BoardedDoor", "door_boarded" if randf() < 0.7 else "door_chained",
				origin + front * 0.05, facing, 1.2, 2.3)
		cursor += xr.y - xr.x
	if length - cursor > 0.6:
		_brick_facing(a + dir * cursor, b, front, 2, groups.Buildings)
	var mid := (a + b) / 2 - front * 0.35
	_box(groups.Buildings, "FrontageBlocker", mid + Vector3.UP * 4.0,
		_rsize(basis, Vector3(0, 8.0, 0.3)) + (Vector3(length, 0, 0) if absf(dir.x) > 0.5 else Vector3(0, 0, length)),
		"collider", true, false)


## Un montón de escombros que corta el paso (cajas inclinadas y una colisión).
func _rubble(center: Vector3, size: Vector3) -> void:
	var holder := _add(groups.Props, Node3D.new(), "Rubble")
	for i in 14:
		var p := center + Vector3(randf_range(-0.5, 0.5) * size.x, 0, randf_range(-0.5, 0.5) * size.z)
		var s := Vector3(randf_range(0.8, 2.6), randf_range(0.4, 1.4), randf_range(0.8, 2.2))
		var piece := _box(holder, "Debris", p + Vector3.UP * s.y * 0.35, s, "rubble" if randf() < 0.7 else "cap", false)
		piece.rotation_degrees = Vector3(randf_range(-25, 25), randf_range(0, 180), randf_range(-25, 25))
	for i in 3:
		var p := center + Vector3(randf_range(-0.3, 0.3) * size.x, 1.6, randf_range(-0.3, 0.3) * size.z)
		var beam := _box(holder, "Beam", p, Vector3(0.25, 0.25, randf_range(3.0, 5.0)), "metal", false)
		beam.rotation_degrees = Vector3(randf_range(-40, 40), randf_range(0, 180), 0)
	_box(holder, "RubbleCollider", center + Vector3.UP * 2.0, size + Vector3.UP * 4.0, "collider", true, false)


func _lamp(pos: Vector3, rot: float, lit := 0) -> void:
	_prop(_ph("street_lamp_01"), pos, rot, {"h": 4.5, "col": false})
	_blocker(pos.x - 0.12, pos.z - 0.12, pos.x + 0.12, pos.z + 0.12, 3.0, groups.Props)
	var arm := Basis(Vector3.UP, deg_to_rad(rot)) * Vector3(0, 0, 0.8)
	if lit == 1:
		_light(pos + Vector3.UP * 4.0 + arm, Color(1.0, 0.82, 0.55), 1.2, 9.0, true)
	elif lit == 2:
		_light(pos + Vector3.UP * 4.0 + arm, Color(0.85, 0.9, 1.0), 0.8, 8.0, false)


func _dumpster(pos: Vector3, rot: float) -> void:
	var holder := _add(groups.Props, Node3D.new(), "Dumpster")
	holder.position = pos
	holder.rotation_degrees.y = rot
	_box(holder, "Body", Vector3(0, 0.65, 0), Vector3(1.9, 1.3, 1.1), "dumpster")
	_box(holder, "Lid", Vector3(0, 1.33, -0.1), Vector3(1.95, 0.06, 0.9), "dumpster", false).rotation_degrees.x = -12.0


func _pickup(base_name: String, item: String, pos: Vector3, count := 1, parent: Node = null) -> void:
	_instance("res://scenes/world/pickup.tscn", parent if parent else groups.Items, base_name, pos,
		{"item": load("res://assets/items/%s.tres" % item), "count": count})


func _gated(base_name: String, threshold: int, mode := 0) -> Node3D:
	var gate := Node3D.new()
	gate.set_script(GatedScript)
	gate.set("threshold", threshold)
	gate.set("mode", mode)
	return _add(groups.Secrets, gate, base_name)



# --- Zona -------------------------------------------------------------------

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.51, 0.53)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.63, 0.66)
	env.ambient_light_energy = 0.55
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	world_env.set_script(load("res://scripts/world/atmosphere.gd"))
	# Niebla de exterior: clara y espesa, como en Silent Hill.
	world_env.set("fog_color", Color(0.5, 0.51, 0.53))
	world_env.set("fog_start", 1.5)
	world_env.set("fog_end", 20.0)
	world_env.set("insane_fog_color", Color(0.12, 0.08, 0.07))
	world_env.set("insane_fog_start", 0.5)
	world_env.set("insane_fog_end", 7.0)
	_add(scene_root, world_env, "Atmosphere")
	# Luz difusa de un cielo tapado.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-65, 30, 0)
	sun.light_color = Color(0.8, 0.82, 0.86)
	sun.light_energy = 0.35
	_add(scene_root, sun, "Overcast")




# --- El terreno y las calles -------------------------------------------------------

func _in_any(x: float, crosses: Array) -> bool:
	for cx: float in crosses:
		if absf(x - cx) < WALK:
			return true
	return false


func _ground() -> void:
	var ground := _box(groups.Structure, "Ground", Vector3(108, -0.12, -20), Vector3(224, 0.2, 196), "ground")
	ground.set("subdivisions_per_meter", 0.25)
	var gray := Color(0.62, 0.62, 0.62)
	# La avenida: tramos de 6 m de cuatro carriles, salvo en los cruces.
	var x := 3.0
	while x < AVE_END:
		if not _in_any(x, NORTH_X + SOUTH_X):
			_piece(CITY + "Street_4Lane.gltf", Vector3(x, 0.0, 0), 0.0, groups.Structure, gray)
		x += 6.0
	for cx: float in NORTH_X + SOUTH_X:
		var north: bool = NORTH_X.has(cx)
		_box(groups.Structure, "Crossing", Vector3(cx, -0.03, 0), Vector3(12.0, 0.04, 2 * AVE), "asphalt", false)
		# La vereda del lado sin calle sigue de largo.
		_box(groups.Structure, "SidewalkStrip", Vector3(cx, -0.01, (AVE - 1.5) * (1.0 if north else -1.0)),
			Vector3(12.0, 0.02, 3.0), "sidewalk", false)
		for arm in [-1.0, 1.0]:
			_piece(CITY + "Decal_Crosswalk.gltf", Vector3(cx + arm * 7.5, 0.01, 0), 90.0, groups.Structure, Color(0.7, 0.7, 0.68))
		# La transversal, hasta la paralela (Lavalle al norte, Tucumán al sur).
		var sign_z := -1.0 if north else 1.0
		var end_z := LAVALLE_Z + WALK if north else TUCUMAN_Z - WALK
		var z := sign_z * (AVE + 3.0)
		while absf(z) < absf(end_z) - 6.0:
			_piece(CITY + "Street_2Lane.gltf", Vector3(cx, 0.0, z), 90.0, groups.Structure, gray)
			z += sign_z * 6.0
		var par_z := LAVALLE_Z if north else TUCUMAN_Z
		var box_z0 := z - sign_z * 3.0
		var box_z1 := par_z + sign_z * WALK
		_box(groups.Structure, "Crossing", Vector3(cx, -0.03, (box_z0 + box_z1) / 2), Vector3(12.0, 0.04, absf(box_z1 - box_z0)),
			"asphalt", false)
		_box(groups.Structure, "SidewalkStrip", Vector3(cx, -0.01, par_z + sign_z * (WALK - 1.5)), Vector3(12.0, 0.02, 3.0),
			"sidewalk", false)
		_piece(CITY + "Decal_Crosswalk.gltf", Vector3(cx, 0.01, sign_z * (AVE + 1.5)), 0.0, groups.Structure, Color(0.7, 0.7, 0.68))
	# Lavalle y Tucumán.
	for par: Array in [[LAVALLE_Z, LAVALLE_X, NORTH_X], [TUCUMAN_Z, TUCUMAN_X, SOUTH_X]]:
		var span: Vector2 = par[1]
		x = span.x + 3.0
		while x < span.y:
			if not _in_any(x, par[2]):
				_piece(CITY + "Street_2Lane.gltf", Vector3(x, 0.0, par[0]), 0.0, groups.Structure, gray)
			x += 6.0
	# Callejón y patio: asfalto gastado.
	_box(groups.Structure, "AlleyFloor", Vector3((ALLEY_X.x + ALLEY_X.y) / 2, -0.01, (PATIO.end.y + LAVALLE_Z - WALK) / 2),
		Vector3(ALLEY_X.y - ALLEY_X.x, 0.02, absf(PATIO.end.y - (LAVALLE_Z - WALK))), "asphalt", false)
	_box(groups.Structure, "PatioFloor", Vector3(PATIO.get_center().x, -0.01, PATIO.get_center().y),
		Vector3(PATIO.size.x, 0.02, PATIO.size.y), "asphalt", false)
	for p in [Vector3(14, 0.01, 1.5), Vector3(70, 0.01, -2.4), Vector3(150, 0.01, 2.0), Vector3(48, 0.01, -40.0),
			Vector3(100, 0.01, LAVALLE_Z + 1.0), Vector3(84, 0.01, 35.0), Vector3(150, 0.01, TUCUMAN_Z - 1.0)]:
		_prop(CITY + "Prop_ManholeCover.gltf", p, 0, {"col": false})


## La fachada de atrás del Hospital San Judas: ladrillo, tres pisos, la salida de emergencia.
func _hospital_back() -> void:
	var holder := _add(groups.Structure, Node3D.new(), "HospitalBack")
	_brick_wall(Vector3(0, 0, AVE + 1.5), Vector3(0, 0, -AVE - 1.5), 3, holder, false)
	_box(holder, "Cornice", Vector3(-0.2, 12.1, 0), Vector3(0.8, 0.3, 2 * AVE + 3.6), "cap", false)
	_label(holder, "HOSPITAL SAN JUDAS", Vector3(0.12, 3.3, 0), 90, Color(0.75, 0.75, 0.7), 0.012)
	_label(holder, "SALIDA DE EMERGENCIA", Vector3(0.12, 2.55, 0), 90, Color(0.6, 0.1, 0.08), 0.006)
	for z in [-6.5, 6.5]:
		for wy in [4.2, 8.2]:
			_piece(CITY + "Metal_FirstFloor_Window.gltf", Vector3(0.05, wy, z), 90.0, holder, Color(0.5, 0.5, 0.5))
	var door := Area3D.new()
	door.set_script(load("res://scripts/world/zone_door.gd"))
	door.set("target_scene", "res://scenes/levels/hospital.tscn")
	door.set("target_spawn", &"from_street")
	door.position = Vector3(0.6, 1.2, 0)
	_add(groups.Inspectables, door, "HospitalDoor")
	# La puerta de metal de la salida de emergencia (la que se forzó desde adentro).
	_zone_door_visuals(door, Vector3(0.03, 0, 0), 90.0, "door_metal_open", "", 1.2, 2.3, true)
	_light(Vector3(0.8, 2.8, 0), Color(0.9, 0.35, 0.25), 0.7, 5.0, true)


## Una cuadra con edificios reservados (las puertas que se abren) y relleno al azar.
func _row(a: Vector3, b: Vector3, facing: float) -> void:
	var dir := (b - a).normalized()
	var length := a.distance_to(b)
	var basis := Basis(Vector3.UP, deg_to_rad(facing))
	var reserved := []
	for s: Array in specials:
		var origin: Vector3 = s[2]
		if absf(float(s[3]) - facing) > 0.1:
			continue
		# El origen tiene que estar sobre la línea.
		var rel := origin - a
		if absf(rel.dot(dir) - clampf(rel.dot(dir), 0.0, length)) > 0.01 or (rel - dir * rel.dot(dir)).length() > 0.05:
			continue
		var xr: Vector2 = BUILDINGS[s[1]].x
		var e0 := (origin + basis * Vector3(xr.x, 0, 0) - a).dot(dir)
		var e1 := (origin + basis * Vector3(xr.y, 0, 0) - a).dot(dir)
		reserved.append([minf(e0, e1), maxf(e0, e1), s])
	reserved.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
	var cursor := 0.0
	for r: Array in reserved:
		if r[0] - cursor > 0.6:
			_frontage(a + dir * cursor, a + dir * r[0], facing)
		var s: Array = r[2]
		_building(s[1], s[2], facing, TINTS.pick_random())
		cursor = r[1]
	if length - cursor > 0.6:
		_frontage(a + dir * cursor, b, facing)


## Una transversal: los edificios de las esquinas ponen el costado; en el medio, una fila
## propia y ladrillo atrás de todo (con huecos donde sale algo).
func _cross_sides(cx: float, z0: float, z1: float) -> void:
	var sz := signf(z1 - z0)
	for side in [-1.0, 1.0]:
		var lx: float = cx + side * WALK
		var facing := 90.0 if side < 0 else -90.0
		var front := Vector3(-side, 0, 0)
		var inset := Vector3(side * 0.3, 0, 0)
		_box(groups.Buildings, "CrossBlocker", Vector3(lx + side * 0.35, 4.0, (z0 + z1) / 2), Vector3(0.3, 8.0, absf(z1 - z0)),
			"collider", true, false)
		_brick_facing(Vector3(lx, 0, z0) + inset, Vector3(lx, 0, z1) + inset, front, 2, groups.Buildings)
		_row(Vector3(lx, 0, z0 + sz * 16.5), Vector3(lx, 0, z1 - sz * 16.5), facing)


func _blocks() -> void:
	# Avenida, vereda norte (frentes al sur) y vereda sur (frentes al norte).
	_row(Vector3(0.4, 0, -AVE), Vector3(NORTH_X[0] - WALK, 0, -AVE), 0)
	_row(Vector3(NORTH_X[0] + WALK, 0, -AVE), Vector3(NORTH_X[1] - WALK, 0, -AVE), 0)
	_row(Vector3(NORTH_X[1] + WALK, 0, -AVE), Vector3(AVE_END, 0, -AVE), 0)
	_row(Vector3(SOUTH_X[0] - WALK, 0, AVE), Vector3(0.4, 0, AVE), 180)
	_row(Vector3(SOUTH_X[1] - WALK, 0, AVE), Vector3(SOUTH_X[0] + WALK, 0, AVE), 180)
	_row(Vector3(AVE_END, 0, AVE), Vector3(SOUTH_X[1] + WALK, 0, AVE), 180)
	# Transversales.
	for cx: float in NORTH_X:
		_cross_sides(cx, -AVE, LAVALLE_Z + WALK)
	for cx: float in SOUTH_X:
		_cross_sides(cx, AVE, TUCUMAN_Z - WALK)
	# Lavalle: vereda sur entre las transversales; vereda norte con la boca del callejón.
	_row(Vector3(NORTH_X[1] - WALK, 0, LAVALLE_Z + WALK), Vector3(NORTH_X[0] + WALK, 0, LAVALLE_Z + WALK), 180)
	_row(Vector3(LAVALLE_X.x, 0, LAVALLE_Z - WALK), Vector3(ALLEY_X.x, 0, LAVALLE_Z - WALK), 0)
	_row(Vector3(ALLEY_X.y, 0, LAVALLE_Z - WALK), Vector3(LAVALLE_X.y, 0, LAVALLE_Z - WALK), 0)
	for ex: float in [LAVALLE_X.x, LAVALLE_X.y]:
		var inward := Vector3.RIGHT if ex < 100.0 else Vector3.LEFT
		_brick_facing(Vector3(ex, 0, LAVALLE_Z - WALK), Vector3(ex, 0, LAVALLE_Z + WALK), inward, 2, groups.Buildings)
	# Tucumán.
	_row(Vector3(SOUTH_X[0] + WALK, 0, TUCUMAN_Z - WALK), Vector3(SOUTH_X[1] - WALK, 0, TUCUMAN_Z - WALK), 0)
	_row(Vector3(TUCUMAN_X.y, 0, TUCUMAN_Z + WALK), Vector3(TUCUMAN_X.x, 0, TUCUMAN_Z + WALK), 180)
	for ex: float in [TUCUMAN_X.x, TUCUMAN_X.y]:
		var inward := Vector3.RIGHT if ex < 130.0 else Vector3.LEFT
		_brick_facing(Vector3(ex, 0, TUCUMAN_Z - WALK), Vector3(ex, 0, TUCUMAN_Z + WALK), inward, 2, groups.Buildings)
	_inspect(Vector3(LAVALLE_X.x + 1.2, 1.2, LAVALLE_Z), ["Lavalle termina en una pared. Alguien pintó encima, en letras enormes: \"NO HAY AFUERA\"."], 1.6)
	_inspect(Vector3(TUCUMAN_X.y - 1.2, 1.2, TUCUMAN_Z), ["Tucumán se corta contra el paredón de una fábrica. Del otro lado, máquinas que siguen andando."], 1.6)


## Callejón (x 60..66) desde Lavalle hasta un patio de servicio cerrado.
func _alley() -> void:
	var az0 := LAVALLE_Z - WALK
	var pz0 := PATIO.end.y
	var pz1 := PATIO.position.y
	_brick_facing(Vector3(ALLEY_X.x, 0, az0), Vector3(ALLEY_X.x, 0, pz0), Vector3.RIGHT, 2, groups.Structure)
	_brick_facing(Vector3(ALLEY_X.y, 0, az0), Vector3(ALLEY_X.y, 0, pz0), Vector3.LEFT, 2, groups.Structure)
	# El patio: x 54..74, z -112..-100.
	_brick_facing(Vector3(PATIO.position.x, 0, pz0), Vector3(ALLEY_X.x, 0, pz0), Vector3.FORWARD, 1, groups.Structure)
	_brick_facing(Vector3(ALLEY_X.y, 0, pz0), Vector3(PATIO.end.x, 0, pz0), Vector3.FORWARD, 1, groups.Structure)
	_brick_facing(Vector3(PATIO.position.x, 0, pz0), Vector3(PATIO.position.x, 0, pz1), Vector3.RIGHT, 1, groups.Structure)
	_brick_facing(Vector3(PATIO.end.x, 0, pz0), Vector3(PATIO.end.x, 0, pz1), Vector3.LEFT, 1, groups.Structure)
	# Pared norte con un hueco: el nicho del secreto.
	_brick_facing(Vector3(PATIO.position.x, 0, pz1), Vector3(NICHE_X - 1.0, 0, pz1), Vector3.BACK, 1, groups.Structure)
	_brick_facing(Vector3(NICHE_X + 1.0, 0, pz1), Vector3(PATIO.end.x, 0, pz1), Vector3.BACK, 1, groups.Structure)
	_box(groups.Structure, "NicheBack", Vector3(NICHE_X, 2.0, pz1 - 1.0), Vector3(2.4, 4.0, 0.2), "cap")
	_box(groups.Structure, "NicheTop", Vector3(NICHE_X, 2.6, pz1 - 0.5), Vector3(2.4, 2.8, 1.0), "cap")
	var props := [
		[_ph("barrel_03"), Vector3(61.0, 0, -82.0), 0.0, 1.0], [_ph("Barrel_01"), Vector3(61.2, 0, -83.1), 40.0, 1.0],
		[_ph("wooden_crate_02"), Vector3(65.2, 0, -88.5), 15.0, 0.8], [_ph("plastic_crate_01"), Vector3(65.3, 0, -89.6), 70.0, 0.4],
		[_ph("utility_box_01"), Vector3(60.5, 0, -95.0), 90.0, 1.2],
		[_ph("wooden_crate_02"), Vector3(72.8, 0, -101.3), 5.0, 0.8], [_ph("wooden_crate_02"), Vector3(72.9, 0, -102.4), 30.0, 0.8],
		[_ph("barrel_03"), Vector3(55.2, 0, -110.8), 0.0, 1.0], [_ph("plastic_crate_01"), Vector3(56.3, 0, -111.0), 10.0, 0.4],
		[POLYHAVEN + "trashbag/trashbag.gltf", Vector3(64.9, 0, -80.0), 20.0, 0.6],
		[POLYHAVEN + "trashbag/trashbag.gltf", Vector3(67.5, 0, -111.2), 80.0, 0.6],
	]
	for p: Array in props:
		_prop(p[0], p[1], p[2], {"h": p[3]})
	# El patio de servicio: un auto quemado, tachos, pallets, un colchón.
	_car("sedan", Vector3(68.0, 0, -108.5), 20.0, Color(0.2, 0.18, 0.17))
	_prop(CARS + "debris-tire.glb", Vector3(66.2, 0, -109.8), 70, {"s": 1.2, "col": false})
	for p in [Vector3(55.0, 0, -101.0), Vector3(55.9, 0, -101.2), Vector3(73.2, 0, -110.9)]:
		_prop(_ph("metal_trash_can"), p, randf_range(0, 360), {"h": 0.9})
	_box(groups.Props, "Mattress", Vector3(55.2, 0.1, -105.6), Vector3(0.95, 0.2, 1.9), "plywood", false)
	for p in [Vector3(58.5, 0, -110.8), Vector3(66.5, 0, -101.0), Vector3(62.5, 0, -102.1)]:
		_prop(POLYHAVEN + "trashbag/trashbag.gltf", p, randf_range(0, 360), {"h": 0.6})
	_prop(_ph("security_light"), Vector3(PATIO.end.x, 3.4, -106.0), -90, {"anchor": 2, "col": false, "h": 0.35})
	_light(Vector3(PATIO.end.x - 0.6, 3.2, -106.0), Color(0.75, 0.85, 1.0), 0.8, 7.0, true)
	_prop(_ph("security_light"), Vector3(ALLEY_X.x + 0.1, 3.2, -88.0), 90, {"anchor": 2, "col": false, "h": 0.35})


## El Teatro Imperio al fondo de la avenida: la próxima zona.
func _theater() -> void:
	var holder := _add(groups.Structure, Node3D.new(), "Theater")
	var tx := AVE_END
	_building("Building_Large_2", Vector3(tx, 0, -1.0), -90, Color(0.66, 0.58, 0.56))
	# Marquesina con lamparitas (siguen prendidas aunque no haya luz en ningún lado).
	_box(holder, "Marquee", Vector3(tx - 1.4, 4.2, 0), Vector3(2.2, 0.9, 9.0), "marquee", false)
	for i in 16:
		var z := -4.2 + i * (8.4 / 15.0)
		_box(holder, "Bulb", Vector3(tx - 2.52, 3.8, z), Vector3(0.08, 0.08, 0.08), "bulb", false)
		_box(holder, "Bulb", Vector3(tx - 2.52, 4.6, z), Vector3(0.08, 0.08, 0.08), "bulb", false)
	_label(holder, "TEATRO IMPERIO", Vector3(tx - 2.53, 4.22, 0), -90, Color(1.0, 0.85, 0.6), 0.015)
	_label(holder, "HOY: \"LA PALOMA\" - FUNCIÓN ÚNICA", Vector3(tx - 2.53, 3.42, 0), -90, Color(0.9, 0.8, 0.65), 0.0055)
	_light(Vector3(tx - 3.2, 3.6, 0), Color(1.0, 0.75, 0.45), 1.8, 10.0, true)
	for z in [-3.4, 3.4]:
		_prop(_ph("street_lamp_02"), Vector3(tx - 0.7, 2.2, z), -90, {"anchor": 2, "col": false, "h": 0.8})


## Barricada policial en x ~160: autos cruzados, vallas y conos. Se pasa por la vereda norte.
func _barricade() -> void:
	var bx := BARRICADE_X
	_car("police", Vector3(bx - 0.5, 0, 1.5), 75.0, Color(0.75, 0.74, 0.74))
	_car("police", Vector3(bx + 0.8, 0, 6.2), 110.0, Color(0.7, 0.7, 0.72))
	_car("van", Vector3(bx + 1.0, 0, -3.0), 70.0, Color(0.62, 0.6, 0.58))
	_car("police", Vector3(bx + 0.4, 0, -6.0), 95.0, Color(0.72, 0.72, 0.72))
	for i in 7:
		_prop(CARS + "cone.glb", Vector3(bx - 2.0 + randf_range(-0.6, 0.6), 0, -6.5 + i * 2.0), randf_range(0, 360), {"s": 1.0, "col": false})
	# Vallas de madera (tablones con franjas).
	for z in [8.0, -1.0]:
		_box(groups.Props, "Barrier", Vector3(bx + 2.8, 0.9, z), Vector3(0.1, 0.25, 1.8), "tape", true)
		_box(groups.Props, "BarrierLeg", Vector3(bx + 2.8, 0.45, z - 0.8), Vector3(0.1, 0.9, 0.1), "plywood", false)
		_box(groups.Props, "BarrierLeg", Vector3(bx + 2.8, 0.45, z + 0.8), Vector3(0.1, 0.9, 0.1), "plywood", false)
	# Límite: la barricada cierra la avenida salvo un paso de ~1.3 m pegado a la vereda norte.
	_blocker(bx - 1.6, -AVE + 1.4, bx + 2.6, AVE - 0.1, 2.2, groups.Props)


## Autos, faroles, basura y árboles a lo largo de las calles.
func _dressing() -> void:
	var cars := ["sedan", "taxi", "suv", "van", "sedan", "suv", "truck"]
	# [eje, coordenada fija, desde, hasta, distancia de los autos al centro, de las veredas]
	var streets := [
		["x", 0.0, 8.0, BARRICADE_X - 6.0, 5.0, AVE - 0.8], ["x", 0.0, BARRICADE_X + 6.0, AVE_END - 6.0, 5.0, AVE - 0.8],
		["x", LAVALLE_Z, LAVALLE_X.x + 4.0, LAVALLE_X.y - 4.0, 2.3, WALK - 0.8],
		["x", TUCUMAN_Z, TUCUMAN_X.x + 4.0, TUCUMAN_X.y - 4.0, 2.3, WALK - 0.8],
	]
	for cx: float in NORTH_X:
		streets.append(["z", cx, -(AVE + 5.0), LAVALLE_Z + WALK + 4.0, 2.3, WALK - 0.8])
	for cx: float in SOUTH_X:
		streets.append(["z", cx, AVE + 5.0, TUCUMAN_Z - WALK - 4.0, 2.3, WALK - 0.8])
	# Frente a cada puerta que se abre no se estaciona nada (ahí aparece el jugador al salir).
	var doors := []
	for s: Array in specials:
		doors.append((s[2] as Vector3) + Basis(Vector3.UP, deg_to_rad(s[3])) * Vector3(0, 0, 3.0))
	var lamp_i := 0
	for st: Array in streets:
		var along_x: bool = st[0] == "x"
		var c: float = st[1]
		var a0: float = minf(st[2], st[3])
		var a1: float = maxf(st[2], st[3])
		var crosses: Array = []
		if along_x:
			crosses = NORTH_X + SOUTH_X if c == 0.0 else (NORTH_X if c == LAVALLE_Z else SOUTH_X)
		var t := a0
		while t < a1:
			var p := Vector3(t, 0, c) if along_x else Vector3(c, 0, t)
			var side := 1.0 if randf() < 0.5 else -1.0
			var off: Vector3 = Vector3(0, 0, side * float(st[4])) if along_x else Vector3(side * float(st[4]), 0, 0)
			var near_door := false
			for d: Vector3 in doors:
				if Vector2(d.x - p.x - off.x, d.z - p.z - off.z).length() < 6.0:
					near_door = true
			if not near_door and not (along_x and _in_any(t, crosses)):
				var r := randf()
				if r < 0.38:
					var yaw := (92.0 if side > 0 else -88.0) if along_x else (0.0 if side > 0 else 180.0)
					_car(cars.pick_random(), p + off, yaw + randf_range(-7, 7), TINTS.pick_random())
				elif r < 0.52:
					var walk_off: Vector3 = Vector3(0, 0, side * float(st[5])) if along_x else Vector3(side * float(st[5]), 0, 0)
					_prop(POLYHAVEN + "trashbag/trashbag.gltf", p + walk_off, randf_range(0, 360), {"h": 0.6})
				elif r < 0.6:
					var walk_off: Vector3 = Vector3(0, 0, side * (float(st[5]) - 0.3)) if along_x else Vector3(side * (float(st[5]) - 0.3), 0, 0)
					_dumpster(p + walk_off, 0.0 if along_x else 90.0)
			t += randf_range(8.0, 13.0)
		# Faroles cada 24 m, alternando de vereda; casi todos muertos.
		t = a0 + 4.0
		while t < a1:
			var p := Vector3(t, 0, c) if along_x else Vector3(c, 0, t)
			if not (along_x and _in_any(t, crosses)):
				var north := lamp_i % 2 == 0
				var sw: float = float(st[5]) * (-1.0 if north else 1.0)
				var lp: Vector3 = p + (Vector3(0, 0, sw) if along_x else Vector3(sw, 0, 0))
				var rot := (0.0 if north else 180.0) if along_x else (90.0 if north else -90.0)
				_lamp(lp, rot, [1, 0, 0, 2, 0][lamp_i % 5])
				lamp_i += 1
			t += 24.0
	# La ambulancia del San Judas, chocada contra un farol.
	_car("ambulance", Vector3(30.5, 0, -2.2), -62.0, Color(0.8, 0.8, 0.8))
	for p in [[Vector3(31.6, 0, 0.2), "debris-bumper"], [Vector3(29.2, 0, -0.6), "debris-tire"]]:
		_prop(CARS + p[1] + ".glb", p[0], randf_range(0, 360), {"s": 1.0, "col": false})
	_prop(HOSP + "blood.glb", Vector3(30.0, 0.02, -3.6), 30, {"col": false, "L": 1.6})
	for p in [Vector3(28.0, 0, 7.6), Vector3(100.0, 0, 7.6), Vector3(66.0, 0, -7.6), Vector3(140.0, 0, -7.6)]:
		_prop(CITY + "Prop_Planter_Single.gltf", p, 0)
	for tx in [10.0, 74.0, 146.0, 200.0]:
		_nature("tree_thin_dark", Vector3(tx, 0, AVE - 1.2), 5.5)


## Carteles con el nombre de las calles en cada esquina de la avenida.
func _street_signs() -> void:
	var names := {48.0: "PARANÁ", 120.0: "URUGUAY", 84.0: "VIAMONTE", 180.0: "TALCAHUANO"}
	for cx: float in NORTH_X + SOUTH_X:
		var north: bool = NORTH_X.has(cx)
		var p := Vector3(cx - 5.6, 0, -AVE + 0.4 if north else AVE - 0.4)
		_box(groups.Props, "SignPole", p + Vector3.UP * 1.4, Vector3(0.06, 2.8, 0.06), "metal", false)
		_box(groups.Props, "SignPlate", p + Vector3.UP * 2.7, Vector3(1.2, 0.22, 0.03), "sign", false)
		_label(groups.Props, "AV. INDEPENDENCIA", p + Vector3(0, 2.7, 0.02), 0, Color(0.9, 0.9, 0.85), 0.0035)
		_box(groups.Props, "SignPlate", p + Vector3.UP * 2.45, Vector3(0.03, 0.22, 1.0), "sign", false)
		_label(groups.Props, names[cx], p + Vector3(0.02, 2.45, 0), 90, Color(0.9, 0.9, 0.85), 0.004)


## Secreto por cordura: en el patio, un ladrillo que "no está" cuando uno ya no da más.
func _secrets() -> void:
	var symbol := _gated("WallSymbol", 1)
	_label(symbol, "ELLA TE ESPERA\nEN EL IMPERIO", Vector3(PATIO.end.x - 0.12, 2.0, -106.0), -90, Color(0.55, 0.05, 0.03), 0.008)
	# Nicho en la pared norte del patio: la pared que miente lo tapa hasta Quebrado.
	var lying := _gated("LyingWall", 2, 1)
	_piece(CITY + "Brick_Plain_4.gltf", Vector3(NICHE_X, 0, PATIO.position.y + 0.4), 0, lying)
	_box(lying, "Collider", Vector3(NICHE_X, 1.0, PATIO.position.y + 0.3), Vector3(2.0, 2.0, 0.2), "collider", true, false)
	_box(groups.Secrets, "Niche", Vector3(NICHE_X, 0.4, PATIO.position.y - 0.3), Vector3(1.6, 0.8, 0.6), "cap", false)


func _discovery() -> void:
	var places := [
		["street_hospital", 0, -9, 42, 9], ["street_middle", 42, -9, 114, 9], ["street_east", 114, -9, 160, 9],
		["street_barricade", 160, -9, 216, 9], ["street_parana", 42, -66, 54, -9], ["street_uruguay", 114, -66, 126, -9],
		["street_lavalle", 42, -78, 126, -66], ["street_alley", 60, -100, 66, -78], ["street_yard", 54, -112, 74, -100],
		["street_viamonte", 78, 9, 90, 60], ["street_talcahuano", 174, 9, 186, 60], ["street_tucuman", 78, 60, 186, 72],
	]
	var parent := _add(scene_root, Node3D.new(), "Places")
	for p: Array in places:
		var zone := Area3D.new()
		zone.set_script(load("res://scripts/world/discovery_zone.gd"))
		zone.set("place_id", StringName(p[0]))
		zone.set("size", Vector3(p[3] - p[1] - 0.4, 3.0, p[4] - p[2] - 0.4))
		zone.position = Vector3((p[1] + p[3]) / 2.0, 1.5, (p[2] + p[4]) / 2.0)
		_add(parent, zone, String(p[0]))


## Las puertas que se abren (casas chicas, la comisaría, la iglesia, la casa de Ferreyra).
func _house_doors() -> void:
	var signs := {"comisaria": "COMISARÍA 12", "iglesia": "PARROQUIA SAN JUDAS TADEO", "almacen": "ALMACÉN LA ESTRELLA",
		"relojeria": "RELOJERÍA KAUFMANN", "pension": "PENSIÓN DOÑA ROSA"}
	for s: Array in specials:
		var id: String = s[0]
		var origin: Vector3 = s[2]
		var facing: float = s[3]
		var front := Basis(Vector3.UP, deg_to_rad(facing)) * Vector3(0, 0, 1)
		var porch: bool = s[1] == "Building_Small_1"
		var door := Area3D.new()
		door.set_script(load("res://scripts/world/zone_door.gd"))
		var scene: String = s[4]
		door.set("target_scene", scene % id if scene.contains("%s") else scene)
		door.set("target_spawn", &"inside")
		door.set("radius", 1.3)
		door.position = origin + front * 0.4 + Vector3.UP * 1.2
		_add(groups.Inspectables, door, "Door_" + id)
		_zone_door_visuals(door, origin + front * 0.05, facing, s[5], "", s[6], s[7], true)
		if signs.has(id):
			_box(groups.Props, "DoorSignBoard", origin + front * 0.12 + Vector3.UP * (float(s[7]) + 0.55),
				_rsize(Basis(Vector3.UP, deg_to_rad(facing)), Vector3(3.2, 0.5, 0.08)), "sign_board", false)
			_label(groups.Props, signs[id], origin + front * 0.18 + Vector3.UP * (float(s[7]) + 0.55), facing, Color(0.9, 0.82, 0.6), 0.006)
		# Al salir se aparece en la vereda mirando a la calle (las de porche, al pie de la escalera).
		var spawn := Marker3D.new()
		spawn.set_script(load("res://scripts/world/spawn_point.gd"))
		spawn.set("spawn_id", StringName("house_" + id))
		spawn.position = origin + front * (3.6 if porch else 2.6) + Vector3.UP * 0.05
		spawn.rotation_degrees.y = facing + 180.0
		_add(scene_root, spawn, "SpawnHouse_" + id)


func _inspectables() -> void:
	_inspect(Vector3(30.5, 1.0, -2.2), ["La ambulancia del San Judas. El parabrisas está roto desde adentro.",
		"El cinturón del conductor está cortado. No hay sangre. No hay nadie."], 2.2)
	_inspect(Vector3(BARRICADE_X - 0.5, 1.0, 1.5), ["Barricada de la policía. Nadie la custodia.",
		"Del lado del teatro, la niebla es más espesa. Casi tibia."], 2.0)
	# Teatro Imperio (zona 3): la cadena tiene un candado; la llave la tenía Sosa (pensión).
	var theater := Area3D.new()
	theater.set_script(load("res://scripts/world/zone_door.gd"))
	theater.set("target_scene", "res://scenes/levels/theater.tscn")
	theater.set("target_spawn", &"from_street")
	theater.set("required_item", load("res://assets/items/key_theater.tres"))
	theater.set("unlock_flag", &"theater_unlocked")
	theater.set("locked_text", "Las puertas del Imperio están encadenadas con un candado. Adentro alguien toca el piano, la misma melodía, una y otra vez.")
	theater.set("unlock_text", "La llave de Sosa entra en el candado. La cadena cae al piso como si pesara una tonelada.")
	theater.set("radius", 1.3)
	theater.position = Vector3(AVE_END - 1.1, 1.2, 0)
	_add(groups.Inspectables, theater, "TheaterDoor")
	_zone_door_visuals(theater, Vector3(AVE_END - 0.05, 0, 0), -90.0, "door_wood_open", "door_chained", 1.8, 2.8, true)
	var from_theater := Marker3D.new()
	from_theater.set_script(load("res://scripts/world/spawn_point.gd"))
	from_theater.set("spawn_id", &"from_theater")
	from_theater.position = Vector3(AVE_END - 4.4, 0.05, 0.0)
	from_theater.rotation_degrees.y = 90.0
	_add(scene_root, from_theater, "SpawnFromTheater")
	_inspect(Vector3(ALLEY_X.x + 3.0, 1.2, LAVALLE_Z - WALK - 0.8), ["Un callejón. Huele a basura mojada y a algo dulce que no debería estar ahí."], 1.5)
	_inspect(Vector3(PATIO.end.x - 0.3, 1.4, -106.0), ["Alguien escribió en la pared con los dedos."], 1.2)


## Pocos objetos y bien repartidos por todo el mapa.
func _items() -> void:
	var items := [
		["LetterPolice", "letter_police_01", Vector3(BARRICADE_X + 0.2, 0.55, 6.9), 1],
		["LetterMarta2", "letter_marta_02", Vector3(NICHE_X, 0.82, PATIO.position.y - 0.3), 1],
		["Magazine", "comic_detective", Vector3(82.0, 0.05, LAVALLE_Z - 4.6), 1],
		["Water1", "food_water_bottle", Vector3(SOUTH_X[0] + 4.8, 0.05, 40.0), 1],
		["Chocolate1", "food_chocolate_bar", Vector3(AVE_END - 6.0, 0.05, 7.6), 1],
		["Peaches1", "food_canned_peaches", Vector3(72.5, 0.05, -104.5), 1],
		["Ammo1", "ammo_9mm", Vector3(BARRICADE_X + 1.4, 0.05, 3.2), 8],
		["Shells1", "ammo_shells", Vector3(BARRICADE_X - 0.8, 0.05, 8.2), 4],
		["Ammo2", "ammo_9mm", Vector3(55.2, 0.22, -105.6), 6],
		["Wood1", "material_wood", Vector3(72.3, 0.0, -100.8), 3],
		["Wood2", "material_wood", Vector3(65.0, 0.0, -90.8), 2],
		["Metal1", "material_metal", Vector3(31.8, 0.0, -0.9), 3],
		["Metal2", "material_metal", Vector3(170.0, 0.0, TUCUMAN_Z + 4.6), 2],
		["Cable1", "material_cable", Vector3(NORTH_X[0] - 4.6, 0.0, -52.0), 2],
		["Cable2", "material_cable", Vector3(60.7, 0.0, -97.0), 1],
		["Cloth1", "material_cloth", Vector3(NORTH_X[1] + 4.6, 0.0, -30.0), 2],
		["Bandage1", "medicine_bandage", Vector3(SOUTH_X[1] - 4.6, 0.05, 50.0), 1],
	]
	for it: Array in items:
		_instance("res://scenes/world/pickup.tscn", groups.Items, it[0], it[2],
			{"item": load("res://assets/items/%s.tres" % it[1]), "count": it[3]})


func _enemies() -> void:
	var stalker := "res://scenes/enemies/stalker.tscn"
	var spitter := "res://scenes/enemies/spitter.tscn"
	for e: Array in [["StalkerStreet", Vector3(24.0, 0.05, 0.5), 7.0], ["StalkerAvenue2", Vector3(96.0, 0.05, -1.0), 8.0],
			["StalkerAvenue3", Vector3(140.0, 0.05, 3.0), 6.0], ["StalkerParana", Vector3(48.0, 0.05, -40.0), 5.0],
			["StalkerAlley", Vector3(63.0, 0.05, -90.0), 3.0], ["StalkerYard", Vector3(64.0, 0.05, -107.0), 4.0],
			["StalkerViamonte", Vector3(84.0, 0.05, 32.0), 5.0], ["StalkerTucuman", Vector3(150.0, 0.05, TUCUMAN_Z), 7.0],
			["StalkerBarricade", Vector3(190.0, 0.05, -2.0), 5.0]]:
		_instance(stalker, groups.Enemies, e[0], e[1], {"wander_radius": e[2]})
	for e: Array in [["SpitterLavalle", Vector3(76.0, 0.05, LAVALLE_Z), 4.0], ["SpitterTucuman", Vector3(110.0, 0.05, TUCUMAN_Z - 2.0), 4.0],
			["SpitterTheater", Vector3(204.0, 0.05, -5.0), 3.0]]:
		_instance(spitter, groups.Enemies, e[0], e[1], {"wander_radius": e[2]})
	# Alucinación: una mujer bajo la marquesina (desde Inquieto).
	var hallucination := _gated("Hallucination", 1)
	_instance("res://scenes/enemies/horror_placeholder.tscn", hallucination, "Figure", Vector3(AVE_END - 3.5, 0.0, 1.5))


## Más enemigos en la avenida según la dificultad.
func _street_extras() -> void:
	_extra_enemy(Vector3(9.0, 0.05, -1.0), 1)
	_extra_enemy(Vector3(63.0, 0.05, -84.0), 1, 3.0)
	_extra_enemy(Vector3(120.0, 0.05, -50.0), 1, 4.0)
	_extra_enemy(Vector3(180.0, 0.05, 40.0), 1, 4.0)
	_extra_enemy(Vector3(60.0, 0.05, 2.0), 2)
	_extra_enemy(Vector3(170.0, 0.05, 3.0), 2, 3.0)
	_extra_enemy(Vector3(68.0, 0.05, -109.0), 2, 3.0)
	_extra_enemy(Vector3(130.0, 0.05, TUCUMAN_Z), 2, 5.0, "res://scenes/enemies/spitter.tscn")


func _systems() -> void:
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
	level_audio.set("ambience", &"street")
	level_audio.set("ambience_db", -4.0)
	_add(scene_root, level_audio, "LevelAudio")
	var spawn := Marker3D.new()
	spawn.set_script(load("res://scripts/world/spawn_point.gd"))
	spawn.set("spawn_id", &"from_hospital")
	spawn.position = Vector3(2.8, 0.05, 0)
	spawn.rotation_degrees.y = -90.0
	_add(scene_root, spawn, "SpawnFromHospital")
	# Por defecto (si se abre la escena directo) se aparece en la puerta del hospital.
	_instance("res://scenes/player/player.tscn", scene_root, "Player", Vector3(1.6, 0.05, 0))
	_instance("res://scenes/effects/ps1_post_process.tscn", scene_root, "PS1PostProcess", Vector3.ZERO)
	var ui: Node = load("res://scenes/ui/game_ui.tscn").instantiate()
	_add(scene_root, ui, "GameUI")


# --- Dificultad (pedido del usuario: más locura = más difícil, con recompensas) ---------

func _extra_enemy(pos: Vector3, min_difficulty: int, wander := 5.0,
		scene_path := "res://scenes/enemies/stalker.tscn", parent: Node = null) -> void:
	var spawn := Marker3D.new()
	spawn.set_script(load("res://scripts/world/difficulty_spawn.gd"))
	spawn.set("enemy_scene", load(scene_path))
	spawn.set("min_difficulty", min_difficulty)
	spawn.set("wander_radius", wander)
	spawn.position = pos
	_add(parent if parent else groups.Enemies, spawn, "ExtraHard" if min_difficulty == 1 else "ExtraInsane")


func _difficulty_gate(base_name: String, min_difficulty: int, hide_when_insane := false) -> Node3D:
	var gate := Node3D.new()
	gate.set_script(GatedScript)
	gate.set("use_difficulty", true)
	gate.set("threshold", min_difficulty)
	gate.set("mode", 1 if hide_when_insane else 0)
	return _add(groups.Secrets, gate, base_name)


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
