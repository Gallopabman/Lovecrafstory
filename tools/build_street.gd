extends SceneTree
## Genera res://scenes/levels/street.tscn: la avenida detrás del Hospital San Judas,
## segunda zona del juego (GDD: "calle: exteriores, primer contacto con la niebla abierta").
## Andamio de una sola pasada, igual que build_hospital: si se edita la escena en el
## editor, no volver a correrlo.
## Uso: <godot> --headless --path . -s res://tools/build_street.gd
##
## Planta (x = este, z = sur, 1 unidad = 1 m):
##   x = 0         fachada trasera del hospital (salida de emergencia)
##   x 0..65       avenida de dos manos (asfalto z -3..3, veredas hasta |z| = 6)
##   x 33..38      callejón al norte, que lleva a un patio cerrado (z -24..-34)
##   x ~50         barricada policial, con un paso por la vereda norte
##   x = 65.4      Teatro Imperio (cerrado: la próxima zona)

const OUT_SCENE := "res://scenes/levels/street.tscn"
const MAT_DIR := "res://assets/materials/street/"
const TEX_DIR := "res://assets/textures/hospital/"
const CITY := "res://assets/models/city/"
const CARS := "res://assets/models/props/cars/"
const POLYHAVEN := "res://assets/models/props/polyhaven/"
const HOSP := "res://assets/models/props/hospital/"
const FONT := "res://assets/fonts/pixel_operator/PixelOperator.ttf"

const STREET_END := 66.0
const WALK := 6.0      # borde exterior de las veredas (|z|)
const CAR_SCALE := 1.5  # el Car Kit de Kenney viene chico

## Edificios del City MegaKit: rango local en x del frente y profundidad (el frente está en z = 0).
const BUILDINGS := {
	"Building_Large_2": {"x": Vector2(-9.32, 11.32), "depth": 16.3},
	"Building_Medium_2_001": {"x": Vector2(-7.53, 7.53), "depth": 12.5},
	"Building_Small_1": {"x": Vector2(-7.23, 5.23), "depth": 12.2},
}

var scene_root: Node3D
var mats := {}
var counters := {}
var groups := {}

var GreyBoxScript: Script
var PropScript: Script
var InspectableScript: Script
var FlickerScript: Script
var GatedScript: Script


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

	_environment()
	_ground()
	_hospital_back()
	_buildings()
	_alley()
	_theater()
	_barricade()
	_parked_cars()
	_street_furniture()
	_lights()
	_secrets()
	_discovery()
	_inspectables()
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
		"ground": ["concrete", Color(0.34, 0.34, 0.34), 0.2],
		"collider": ["", Color(1, 1, 1), 1.0],
		"cap": ["concrete", Color(0.4, 0.38, 0.36), 0.5],
		"marquee": ["", Color(0.3, 0.08, 0.06), 1.0],
		"bulb": ["", Color(1.0, 0.85, 0.55), 1.0],
		"sign": ["", Color(0.12, 0.26, 0.2), 1.0],
		"tape": ["", Color(0.85, 0.7, 0.15), 1.0],
		"plywood": ["wood_floor", Color(0.62, 0.52, 0.4), 0.8],
		"metal": ["metal_green", Color(0.5, 0.52, 0.5), 0.9],
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
		if key == "bulb":
			m.set_shader_parameter(&"emission_color", Color(1.0, 0.8, 0.45))
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


func _ground() -> void:
	# Piso caminable (los tiles de la calle son solo visuales).
	_box(groups.Structure, "Ground", Vector3(40, -0.12, -10), Vector3(110, 0.2, 70), "ground")
	var tile := CITY + "Street_2Lane.gltf"
	var x := 3.0
	while x < STREET_END:
		_piece(tile, Vector3(x, 0.0, 0), 0.0, groups.Structure, Color(0.62, 0.62, 0.62))
		x += 6.0
	# Senda peatonal frente a la salida del hospital.
	_piece(CITY + "Decal_Crosswalk.gltf", Vector3(8.0, 0.01, 0), 90.0, groups.Structure, Color(0.7, 0.7, 0.68))
	# Callejón y patio: asfalto gastado.
	for z in [-9.0, -15.0, -21.0, -27.0, -33.0]:
		for ax in ([35.5] if z > -24.0 else [33.0, 39.0, 45.0]):
			_piece(CITY + "Street_Asphalt_6x6.gltf", Vector3(ax, 0.0, z), 0.0, groups.Structure, Color(0.5, 0.5, 0.5))
	for p in [Vector3(14, 0.01, 1.5), Vector3(41, 0.01, -1.2), Vector3(59, 0.01, 1.0)]:
		_prop(CITY + "Prop_ManholeCover.gltf", p, 0, {"col": false})


## La fachada de atrás del Hospital San Judas: ladrillo, dos pisos, la salida de emergencia.
func _hospital_back() -> void:
	var holder := _add(groups.Structure, Node3D.new(), "HospitalBack")
	_brick_wall(Vector3(0, 0, WALK + 1.5), Vector3(0, 0, -WALK - 1.5), 2, holder, false)
	_box(holder, "Cornice", Vector3(-0.2, 8.1, 0), Vector3(0.8, 0.3, 15.6), "cap", false)
	# Puerta de metal (la que se forzó desde adentro).
	_piece(CITY + "DoorFrame_Metal_Single.gltf", Vector3(0.05, 0, 0), 90.0, holder, Color(0.6, 0.62, 0.6))
	_piece(CITY + "Door_1.gltf", Vector3(0.1, 0, 0.5), 90.0, holder, Color(0.5, 0.55, 0.52))
	_label(holder, "HOSPITAL SAN JUDAS", Vector3(0.12, 3.3, 0), 90, Color(0.75, 0.75, 0.7), 0.012)
	_label(holder, "SALIDA DE EMERGENCIA", Vector3(0.12, 2.55, 0), 90, Color(0.6, 0.1, 0.08), 0.006)
	for z in [-4.5, 4.5]:
		_piece(CITY + "Metal_FirstFloor_Window.gltf", Vector3(0.05, 4.2, z), 90.0, holder, Color(0.5, 0.5, 0.5))
	var door := Area3D.new()
	door.set_script(load("res://scripts/world/zone_door.gd"))
	door.set("target_scene", "res://scenes/levels/hospital.tscn")
	door.set("target_spawn", &"from_street")
	door.position = Vector3(0.6, 1.2, 0)
	_add(groups.Inspectables, door, "HospitalDoor")


func _buildings() -> void:
	# Vereda norte (frentes mirando al sur).
	_building("Building_Small_1", Vector3(7.23, 0, -WALK), 0)
	_building("Building_Large_2", Vector3(21.72, 0, -WALK), 0, Color(0.66, 0.62, 0.6))
	_building("Building_Medium_2_001", Vector3(45.53, 0, -WALK), 0)
	_building("Building_Small_1", Vector3(60.3, 0, -WALK), 0, Color(0.62, 0.64, 0.66))
	# Vereda sur (frentes mirando al norte).
	_building("Building_Large_2", Vector3(11.32, 0, WALK), 180)
	_building("Building_Small_1", Vector3(25.87, 0, WALK), 180, Color(0.68, 0.64, 0.6))
	_building("Building_Medium_2_001", Vector3(40.63, 0, WALK), 180, Color(0.62, 0.62, 0.64))
	_building("Building_Medium_2_001", Vector3(55.69, 0, WALK), 180)
	# Hueco entre el último edificio del sur y el teatro.
	_brick_wall(Vector3(63.2, 0, WALK), Vector3(65.5, 0, WALK), 2)
	_blocker(63.2, WALK, 65.5, 14.0, 8.0)


## Callejón al norte (x 33..38) que termina en un patio de servicio cerrado.
func _alley() -> void:
	# Tapar el fondo de los edificios que dan al callejón.
	_brick_wall(Vector3(38.0, 0, -18.5), Vector3(38.0, 0, -24.0))
	_brick_wall(Vector3(33.1, 0, -22.3), Vector3(33.1, 0, -24.0))
	# Patio: x 30..46, z -24..-34.
	_brick_wall(Vector3(30.0, 0, -24.0), Vector3(33.1, 0, -24.0))
	_brick_wall(Vector3(38.0, 0, -24.0), Vector3(46.0, 0, -24.0))
	_brick_wall(Vector3(46.0, 0, -24.0), Vector3(46.0, 0, -34.0))
	# Pared norte con un hueco en x 37..39: el nicho del secreto.
	_brick_wall(Vector3(46.0, 0, -34.0), Vector3(39.0, 0, -34.0))
	_brick_wall(Vector3(37.0, 0, -34.0), Vector3(30.0, 0, -34.0))
	_box(groups.Structure, "NicheBack", Vector3(38.0, 2.0, -35.0), Vector3(2.4, 4.0, 0.2), "cap")
	_box(groups.Structure, "NicheTop", Vector3(38.0, 2.6, -34.5), Vector3(2.4, 2.8, 1.0), "cap")
	_brick_wall(Vector3(30.0, 0, -34.0), Vector3(30.0, 0, -24.0))
	var props := [
		[_ph("barrel_03"), Vector3(34.0, 0, -12.0), 0.0, 1.0], [_ph("Barrel_01"), Vector3(34.2, 0, -13.1), 40.0, 1.0],
		[_ph("wooden_crate_02"), Vector3(37.2, 0, -16.5), 15.0, 0.8], [_ph("plastic_crate_01"), Vector3(37.3, 0, -17.6), 70.0, 0.4],
		[_ph("utility_box_01"), Vector3(33.5, 0, -20.0), 90.0, 1.2],
		[_ph("wooden_crate_02"), Vector3(44.8, 0, -25.3), 5.0, 0.8], [_ph("wooden_crate_02"), Vector3(44.9, 0, -26.4), 30.0, 0.8],
		[_ph("barrel_03"), Vector3(31.2, 0, -32.8), 0.0, 1.0], [_ph("plastic_crate_01"), Vector3(32.3, 0, -33.0), 10.0, 0.4],
		[POLYHAVEN + "trashbag/trashbag.gltf", Vector3(36.9, 0, -9.0), 20.0, 0.6],
		[POLYHAVEN + "trashbag/trashbag.gltf", Vector3(41.5, 0, -33.2), 80.0, 0.6],
	]
	for p: Array in props:
		_prop(p[0], p[1], p[2], {"h": p[3]})
	# El patio de servicio: un auto quemado, tachos, pallets, un colchón.
	_car("sedan", Vector3(42.0, 0, -30.5), 20.0, Color(0.2, 0.18, 0.17))
	_prop(CARS + "debris-tire.glb", Vector3(40.2, 0, -31.8), 70, {"s": 1.2, "col": false})
	for p in [Vector3(31.0, 0, -25.0), Vector3(31.9, 0, -25.2), Vector3(45.2, 0, -32.9)]:
		_prop(_ph("metal_trash_can"), p, randf_range(0, 360), {"h": 0.9})
	for p in [Vector3(33.5, 0, -28.5), Vector3(44.9, 0, -28.4)]:
		_prop(_ph("wooden_crate_02"), p, randf_range(0, 360), {"h": 0.8})
	_box(groups.Props, "Mattress", Vector3(31.2, 0.1, -29.6), Vector3(0.95, 0.2, 1.9), "plywood", false)
	for p in [Vector3(34.5, 0, -32.8), Vector3(40.5, 0, -25.0), Vector3(36.5, 0, -26.1)]:
		_prop(POLYHAVEN + "trashbag/trashbag.gltf", p, randf_range(0, 360), {"h": 0.6})
	_prop(_ph("security_light"), Vector3(46.0, 3.4, -28.0), -90, {"anchor": 2, "col": false, "h": 0.35})
	_light(Vector3(45.4, 3.2, -28.0), Color(0.75, 0.85, 1.0), 0.8, 7.0, true)
	for z in [-10.0, -19.0]:
		_prop(_ph("exterior_aircon_unit"), Vector3(38.0, 2.6, z), -90, {"anchor": 2, "col": false, "h": 0.9})
	_prop(_ph("security_light"), Vector3(33.1, 3.2, -14.0), 90, {"anchor": 2, "col": false, "h": 0.35})


## El Teatro Imperio al fondo de la avenida: la próxima zona. Por ahora, cerrado.
func _theater() -> void:
	var holder := _add(groups.Structure, Node3D.new(), "Theater")
	_building("Building_Medium_2_001", Vector3(66.0, 0, 0), -90, Color(0.66, 0.58, 0.56))
	# Marquesina con lamparitas (siguen prendidas aunque no haya luz en ningún lado).
	_box(holder, "Marquee", Vector3(64.6, 4.2, 0), Vector3(2.2, 0.9, 7.0), "marquee", false)
	for i in 12:
		var z := -3.2 + i * (6.4 / 11.0)
		_box(holder, "Bulb", Vector3(63.48, 3.8, z), Vector3(0.08, 0.08, 0.08), "bulb", false)
		_box(holder, "Bulb", Vector3(63.48, 4.6, z), Vector3(0.08, 0.08, 0.08), "bulb", false)
	_label(holder, "TEATRO IMPERIO", Vector3(63.47, 4.22, 0), -90, Color(1.0, 0.85, 0.6), 0.013)
	_label(holder, "HOY: \"LA PALOMA\" - FUNCIÓN ÚNICA", Vector3(63.47, 3.42, 0), -90, Color(0.9, 0.8, 0.65), 0.005)
	_light(Vector3(62.8, 3.6, 0), Color(1.0, 0.75, 0.45), 1.6, 9.0, true)
	# Puertas encadenadas.
	_box(holder, "Chain", Vector3(65.25, 1.2, 0), Vector3(0.06, 0.06, 1.6), "metal", false)
	_box(holder, "Plank", Vector3(65.3, 1.6, 0), Vector3(0.05, 0.25, 2.4), "plywood", false)
	for z in [-2.8, 2.8]:
		_prop(_ph("street_lamp_02"), Vector3(65.3, 2.2, z), -90, {"anchor": 2, "col": false, "h": 0.8})


## Barricada policial en x ~50: autos cruzados, vallas y conos. Se pasa por la vereda norte.
func _barricade() -> void:
	_car("police", Vector3(49.5, 0, 0.8), 75.0, Color(0.75, 0.74, 0.74))
	_car("police", Vector3(50.8, 0, 4.2), 110.0, Color(0.7, 0.7, 0.72))
	_car("van", Vector3(51.0, 0, -1.5), 70.0, Color(0.62, 0.6, 0.58))
	for i in 5:
		_prop(CARS + "cone.glb", Vector3(48.0 + randf_range(-0.6, 0.6), 0, -1.0 + i * 1.3), randf_range(0, 360), {"s": 1.0, "col": false})
	# Vallas de madera (tablones con franjas).
	for z in [4.9, -3.0]:
		_box(groups.Props, "Barrier", Vector3(52.8, 0.9, z), Vector3(0.1, 0.25, 1.8), "tape", true)
		_box(groups.Props, "BarrierLeg", Vector3(52.8, 0.45, z - 0.8), Vector3(0.1, 0.9, 0.1), "plywood", false)
		_box(groups.Props, "BarrierLeg", Vector3(52.8, 0.45, z + 0.8), Vector3(0.1, 0.9, 0.1), "plywood", false)
	# Límite: la barricada cierra la calle salvo un paso de ~1.3 m pegado a la vereda norte.
	_blocker(48.8, -3.9, 52.5, WALK - 0.1, 2.0, groups.Props)


func _parked_cars() -> void:
	# Autos abandonados junto al cordón, con las puertas abiertas.
	_car("sedan", Vector3(12.0, 0, 2.2), 92.0)
	_car("taxi", Vector3(21.5, 0, -2.3), -88.0, Color(0.75, 0.72, 0.6))
	_car("suv", Vector3(28.5, 0, 2.4), 85.0, Color(0.6, 0.62, 0.66))
	_car("sedan", Vector3(39.5, 0, 2.1), 97.0, Color(0.55, 0.5, 0.5))
	# La ambulancia del San Judas, chocada contra un farol.
	_car("ambulance", Vector3(30.5, 0, -1.2), -62.0, Color(0.8, 0.8, 0.8))
	_car("truck", Vector3(58.5, 0, 3.6), 80.0, Color(0.55, 0.55, 0.55))
	for p in [[Vector3(31.6, 0, 1.2), "debris-bumper"], [Vector3(29.2, 0, 0.4), "debris-tire"],
			[Vector3(13.4, 0, 0.9), "debris-door"]]:
		_prop(CARS + p[1] + ".glb", p[0], randf_range(0, 360), {"s": 1.0, "col": false})


func _street_furniture() -> void:
	for x in [5.0, 17.0, 29.0, 41.0, 53.0]:
		_prop(CITY + "Prop_Bollard.gltf", Vector3(x, 0, -3.3), 0, {"col": false})
	for x in [10.0, 26.0, 44.0]:
		_prop(CITY + "Prop_Planter_Single.gltf", Vector3(x, 0, 4.6), 0)
	for p in [Vector3(9.0, 0, -3.1), Vector3(23.0, 0, 3.1), Vector3(47.0, 0, -3.1)]:
		_prop(CITY + "Prop_Drain.gltf", p, 0, {"col": false})
	_prop(_ph("utility_box_01"), Vector3(18.5, 0, -5.4), 0, {"h": 1.2})
	_prop(_ph("utility_box_01"), Vector3(47.5, 0, 5.4), 180, {"h": 1.2})
	for p in [Vector3(3.2, 0, -5.2), Vector3(24.0, 0, 5.3), Vector3(56.5, 0, -5.3)]:
		_prop(POLYHAVEN + "trashbag/trashbag.gltf", p, randf_range(0, 360), {"h": 0.6})
	_prop(_ph("barrel_03"), Vector3(33.9, 0, 5.2), 0, {"h": 1.0})
	_prop(HOSP + "blood.glb", Vector3(30.0, 0.02, -2.6), 30, {"col": false, "L": 1.6})


## Faroles cada 12 m. Casi todos muertos; uno titila.
func _lights() -> void:
	var lamps := [[6.0, -5.2, 0], [18.0, 5.2, 180], [30.0, -5.2, 0], [42.0, 5.2, 180], [54.0, -5.2, 0]]
	for i in lamps.size():
		var l: Array = lamps[i]
		_prop(_ph("street_lamp_01"), Vector3(l[0], 0, l[1]), l[2], {"h": 4.5, "col": false})
		_blocker(l[0] - 0.12, l[1] - 0.12, l[0] + 0.12, l[1] + 0.12, 3.0, groups.Props)
		if i == 1:
			_light(Vector3(l[0], 4.0, l[1] - 0.8), Color(1.0, 0.82, 0.55), 1.4, 9.0, true)
		elif i == 3:
			_light(Vector3(l[0], 4.0, l[1] - 0.8), Color(0.85, 0.9, 1.0), 0.9, 8.0, false)
	# La luz de emergencia sobre la puerta del hospital.
	_light(Vector3(0.8, 2.8, 0), Color(0.9, 0.35, 0.25), 0.7, 5.0, true)


## Secreto por cordura: en el patio, un ladrillo que "no está" cuando uno ya no da más.
func _secrets() -> void:
	var symbol := Node3D.new()
	symbol.set_script(GatedScript)
	symbol.set("threshold", 1)
	_add(groups.Secrets, symbol, "WallSymbol")
	_label(symbol, "ELLA TE ESPERA\nEN EL IMPERIO", Vector3(45.88, 2.0, -29.0), -90, Color(0.55, 0.05, 0.03), 0.008)

	# Nicho en la pared norte del patio: la pared que miente lo tapa hasta Quebrado.
	var lying := Node3D.new()
	lying.set_script(GatedScript)
	lying.set("mode", 1)
	_add(groups.Secrets, lying, "LyingWall")
	_piece(CITY + "Brick_Plain_4.gltf", Vector3(38.0, 0, -33.6), 0, lying)
	_box(lying, "Collider", Vector3(38.0, 1.0, -33.7), Vector3(2.0, 2.0, 0.2), "collider", true, false)
	_box(groups.Secrets, "Niche", Vector3(38.0, 0.4, -34.3), Vector3(1.6, 0.8, 0.6), "cap", false)


func _discovery() -> void:
	var places := [
		["street_hospital", 0, -6, 20, 6], ["street_middle", 20, -6, 48, 6], ["street_barricade", 48, -6, 65, 6],
		["street_alley", 33, -24, 38, -6], ["street_yard", 30, -34, 46, -24],
	]
	var parent := _add(scene_root, Node3D.new(), "Places")
	for p: Array in places:
		var zone := Area3D.new()
		zone.set_script(load("res://scripts/world/discovery_zone.gd"))
		zone.set("place_id", StringName(p[0]))
		zone.set("size", Vector3(p[3] - p[1] - 0.4, 3.0, p[4] - p[2] - 0.4))
		zone.position = Vector3((p[1] + p[3]) / 2.0, 1.5, (p[2] + p[4]) / 2.0)
		_add(parent, zone, String(p[0]))


func _inspectables() -> void:
	_inspect(Vector3(30.5, 1.0, -1.2), ["La ambulancia del San Judas. El parabrisas está roto desde adentro.",
		"El cinturón del conductor está cortado. No hay sangre. No hay nadie."], 2.2)
	_inspect(Vector3(49.5, 1.0, 0.8), ["Barricada de la policía. Nadie la custodia.",
		"Del lado del teatro, la niebla es más espesa. Casi tibia."], 2.0)
	_inspect(Vector3(64.9, 1.2, 0), ["Las puertas del Imperio están encadenadas y tapiadas con tablones.",
		"Adentro alguien toca el piano. La misma melodía, una y otra vez.",
		"(El teatro será la próxima zona.)"], 1.3)
	_inspect(Vector3(12.0, 1.0, 2.2), ["Las llaves siguen puestas. El motor no hace ni un ruido.",
		"En el asiento de atrás, una sillita de bebé vacía."], 2.0)
	_inspect(Vector3(35.5, 1.2, -6.8), ["Un callejón. Huele a basura mojada y a algo dulce que no debería estar ahí."], 1.5)
	_inspect(Vector3(46.2, 1.4, -29.0), ["Alguien escribió en la pared con los dedos."], 1.2)


func _items() -> void:
	var pickup := "res://scenes/world/pickup.tscn"
	var items := [
		["LetterPolice", "letter_police_01", Vector3(50.2, 0.55, 4.9), 1],
		["LetterMarta2", "letter_marta_02", Vector3(38.0, 0.82, -34.3), 1],
		["Magazine", "comic_detective", Vector3(26.2, 0.05, 4.0), 1],
		["Water1", "food_water_bottle", Vector3(12.9, 0.05, 3.3), 1],
		["Chocolate1", "food_chocolate_bar", Vector3(58.0, 0.05, 1.3), 1],
		["Peaches1", "food_canned_peaches", Vector3(43.5, 0.05, -26.5), 1],
		["Ammo1", "ammo_9mm", Vector3(51.4, 0.05, 3.2), 8],
		["Ammo2", "ammo_9mm", Vector3(31.2, 0.22, -29.6), 6],
		["Wood1", "material_wood", Vector3(44.3, 0.0, -24.8), 3],
		["Wood2", "material_wood", Vector3(36.8, 0.0, -14.8), 2],
		["Metal1", "material_metal", Vector3(31.8, 0.0, 1.9), 3],
		["Metal2", "material_metal", Vector3(57.1, 0.0, 2.3), 2],
		["Cable1", "material_cable", Vector3(18.8, 0.0, -4.7), 2],
		["Cable2", "material_cable", Vector3(33.7, 0.0, -21.0), 1],
		["Cloth1", "material_cloth", Vector3(22.0, 0.0, -1.2), 2],
	]
	for it: Array in items:
		_instance(pickup, groups.Items, it[0], it[2],
			{"item": load("res://assets/items/%s.tres" % it[1]), "count": it[3]})


func _enemies() -> void:
	var stalker := "res://scenes/enemies/stalker.tscn"
	_instance(stalker, groups.Enemies, "StalkerStreet", Vector3(24.0, 0.05, 0.5), {"wander_radius": 7.0})
	_instance(stalker, groups.Enemies, "StalkerAlley", Vector3(35.5, 0.05, -18.0), {"wander_radius": 3.0})
	_instance(stalker, groups.Enemies, "StalkerYard", Vector3(40.0, 0.05, -29.0), {"wander_radius": 4.0})
	_instance(stalker, groups.Enemies, "StalkerBarricade", Vector3(57.0, 0.05, -2.0), {"wander_radius": 5.0})
	# Alucinación: una mujer bajo la marquesina (desde Inquieto).
	var hallucination := Node3D.new()
	hallucination.set_script(GatedScript)
	hallucination.set("threshold", 1)
	_add(groups.Secrets, hallucination, "Hallucination")
	_instance("res://scenes/enemies/horror_placeholder.tscn", hallucination, "Figure", Vector3(62.5, 0.0, 1.5))


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
	spawn.position = Vector3(1.6, 0.05, 0)
	spawn.rotation_degrees.y = -90.0
	_add(scene_root, spawn, "SpawnFromHospital")
	# Por defecto (si se abre la escena directo) se aparece en la puerta del hospital.
	_instance("res://scenes/player/player.tscn", scene_root, "Player", Vector3(1.6, 0.05, 0))
	_instance("res://scenes/effects/ps1_post_process.tscn", scene_root, "PS1PostProcess", Vector3.ZERO)
	var ui: Node = load("res://scenes/ui/game_ui.tscn").instantiate()
	_add(scene_root, ui, "GameUI")
