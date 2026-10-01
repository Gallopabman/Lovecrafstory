extends Node
## Autoload "Shelter": el refugio como hogar (GDD, "Refugio y housing").
## - Blueprint estático: espacios fijos que se mejoran con materiales.
## - Nivel "cozy": no sube la cordura; hace que baje más lento en el refugio y
##   las mejoras habilitan estaciones que sí la suben (cocinar, descansar, radio, TV).
## - Bono de llegar a casa según lo que se logró en la salida (no se puede farmear).
## Todo esto sobrevive a la muerte del sobreviviente: el refugio se conserva.

signal changed
signal slot_upgraded(slot_id: StringName, level: int, refuge: StringName)
## Cambió el refugio activo.
signal moved(refuge: StringName)
signal materials_deposited(amounts: Dictionary)

const MATERIALS := {
	&"material_wood": preload("res://assets/items/material_wood.tres"),
	&"material_metal": preload("res://assets/items/material_metal.tres"),
	&"material_cloth": preload("res://assets/items/material_cloth.tres"),
	&"material_cable": preload("res://assets/items/material_cable.tres"),
}

## El blueprint. Cada nivel: nombre, descripción, costo {material: cantidad} y cozy que suma.
const SLOTS := {
	&"fire": {"name": "Fuego", "levels": [
		{"name": "Fogata en un tacho", "cozy": 1, "cost": {&"material_wood": 3},
			"desc": "Calor, luz y un lugar para cocinar. La comida caliente rinde más."},
		{"name": "Salamandra", "cozy": 1, "cost": {&"material_metal": 3, &"material_wood": 1},
			"desc": "Una estufa de verdad, con caño al techo. No hay humo ni miedo."},
	]},
	&"power": {"name": "Electricidad", "levels": [
		{"name": "Generador reparado", "cozy": 1, "cost": {&"material_cable": 2, &"material_metal": 1},
			"desc": "Vuelve la luz. Se pueden ver películas en la tele."},
		{"name": "Instalación prolija", "cozy": 1, "cost": {&"material_cable": 2, &"material_metal": 2},
			"desc": "Sin cables pelados. La radio vuelve a sonar: música de antes."},
	]},
	&"bed": {"name": "Cama", "levels": [
		{"name": "Cama armada", "cozy": 1, "cost": {&"material_wood": 2, &"material_cloth": 2},
			"desc": "Deja de ser un colchón en el piso. Se puede descansar de verdad."},
		{"name": "Cama con mantas", "cozy": 1, "cost": {&"material_cloth": 2},
			"desc": "Mantas y almohada. El descanso rinde más."},
	]},
	&"windows": {"name": "Ventanas", "levels": [
		{"name": "Tablones", "cozy": 1, "cost": {&"material_wood": 3},
			"desc": "Tapar las ventanas. La niebla ya no mira hacia adentro."},
		{"name": "Cortinas", "cozy": 1, "cost": {&"material_cloth": 2},
			"desc": "Tela sobre la madera. Parece una casa."},
	]},
	&"decor": {"name": "Decoración", "levels": [
		{"name": "Cuadros y fotos", "cozy": 1, "cost": {&"material_wood": 1, &"material_cloth": 1},
			"desc": "Fotos de desconocidos que sonríen. Mejor que nada."},
		{"name": "Plantas y alfombra", "cozy": 1, "cost": {&"material_cloth": 2},
			"desc": "Algo vivo en el cuarto. Una alfombra para los pies fríos."},
	]},
	# El alijo no suma cozy: suma lugar (ver `stash_capacity`).
	&"stash": {"name": "Alijo", "levels": [
		{"name": "Baúl de madera", "cozy": 0, "cost": {&"material_wood": 3, &"material_metal": 1},
			"desc": "Un baúl con bisagras de verdad. Entra el doble que en la caja de cartón."},
		{"name": "Armario con candado", "cozy": 0, "cost": {&"material_metal": 3, &"material_cable": 1},
			"desc": "Un armario de chapa, con estantes. Entra casi todo lo que uno junta."},
	]},
}
const SLOT_ORDER: Array[StringName] = [&"fire", &"power", &"bed", &"windows", &"decor", &"stash"]

@export_group("Goteo en el refugio")
## Multiplicador del goteo de cordura sin mejoras y con el refugio completo.
@export var drain_multiplier_bare := 0.6
@export var drain_multiplier_full := 0.1

@export_group("Estaciones")
@export var cooked_multiplier := 1.8
@export var rest_amount := [6.0, 10.0]
@export var rest_cooldown := 180.0
@export var radio_amount := 5.0
@export var radio_cooldown := 120.0

@export_group("Bono de llegar a casa")
## Por cada lugar nuevo descubierto en la salida (GDD: "grande").
@export var bonus_per_new_place := 4.0
## Por cada objeto traído (GDD: "medio"); las cartas cuentan como descubrimiento.
@export var bonus_per_item := 1.5
@export var bonus_per_letter := 4.0
@export var bonus_max := 30.0

@export_group("Alijo")
## Lugares del alijo por nivel (caja de cartón, baúl, armario). Las pilas ocupan uno solo.
@export var stash_capacity: Array[int] = [8, 16, 28]

## Los lugares que pueden ser refugio (GDD: uno solo activo; mudarse es una decisión).
## Cada uno tiene sus propias mejoras; los materiales del depósito se llevan al mudarse.
const REFUGES := {
	&"home": {"name": "Casa", "scene": "res://scenes/levels/home.tscn", "spawn": &"refuge"},
	&"hospital": {"name": "Refugio del San Judas", "scene": "res://scenes/levels/hospital.tscn",
		"spawn": &"refuge"},
	&"theater": {"name": "Camarín del Imperio", "scene": "res://scenes/levels/theater.tscn",
		"spawn": &"refuge"},
}

## Refugio activo: ahí llegan los sobrevivientes nuevos y solo ahí baja lento la cordura.
var active: StringName = &"home"
## Mejoras de cada refugio: { refugio: { espacio: nivel } }. Se conservan al mudarse.
var refuge_levels: Dictionary = {}
## Mejoras del refugio activo (atajo).
var levels: Dictionary:
	get:
		return refuge_levels[active]
var stock: Dictionary = {}
## El alijo (como el baúl de Resident Evil): lo que se deja en casa. Uno solo, en el refugio
## activo (viaja al mudarse) y sobrevive a la muerte del sobreviviente.
## Entradas como las de la mochila, sin lugar en la cuadrícula: { item, count, loaded, cooked }.
var stash: Array[Dictionary] = []
## Lugares descubiertos alguna vez (por cualquier sobreviviente).
var discovered: Dictionary = {}

var _trip_active := false
var _trip_places := 0
var _trip_items := 0
var _trip_letters := 0
var _cooldowns: Dictionary = {}


## El estado arranca en _init (no en _ready) para que nada que corra antes lo pise.
func _init() -> void:
	new_game()


func _ready() -> void:
	Sanity.refuge_entered.connect(_on_refuge_entered)
	Sanity.refuge_exited.connect(_on_refuge_exited)
	Sanity.lost.connect(func() -> void: _trip_active = false)
	Inventory.item_added.connect(_on_item_added)


func new_game() -> void:
	active = &"home"
	refuge_levels.clear()
	for refuge in REFUGES:
		var slots := {}
		for slot in SLOT_ORDER:
			slots[slot] = 0
		refuge_levels[refuge] = slots
	for id in MATERIALS:
		stock[id] = 0
	discovered.clear()
	stash.clear()
	_trip_active = false
	_cooldowns.clear()
	changed.emit()


func save_data() -> Dictionary:
	var saved_stash := []
	for entry in stash:
		var copy := entry.duplicate()
		copy.item = (entry.item as ItemData).resource_path
		saved_stash.append(copy)
	return {"active": active, "refuge_levels": refuge_levels.duplicate(true), "stock": stock.duplicate(),
		"stash": saved_stash, "discovered": discovered.duplicate(),
		"trip": [_trip_active, _trip_places, _trip_items, _trip_letters]}


func load_data(data: Dictionary) -> void:
	new_game()
	var saved_levels: Dictionary = data.get("refuge_levels", {})
	for refuge: StringName in saved_levels:
		if refuge_levels.has(refuge):
			refuge_levels[refuge].merge(saved_levels[refuge], true)
	if data.has("levels"):  # partidas de antes de los refugios múltiples
		refuge_levels[&"hospital"].merge(data.levels, true)
	active = data.get("active", &"hospital")
	stock.merge(data.get("stock", {}), true)
	stash.clear()
	for saved: Dictionary in data.get("stash", []):
		var entry := saved.duplicate()
		entry.item = load(saved.item)
		stash.append(entry)
	discovered = data.get("discovered", {})
	var trip: Array = data.get("trip", [false, 0, 0, 0])
	_trip_active = trip[0]
	_trip_places = trip[1]
	_trip_items = trip[2]
	_trip_letters = trip[3]
	changed.emit()


# --- Refugios ----------------------------------------------------------------

func refuge_name(refuge: StringName = &"") -> String:
	return REFUGES[_r(refuge)].name


func refuge_scene() -> String:
	return REFUGES[active].scene


func refuge_spawn() -> StringName:
	return REFUGES[active].spawn


func is_active(refuge: StringName) -> bool:
	return refuge == active


## Mudarse: los sobrevivientes nuevos llegan acá y el refugio anterior queda como está.
func move_to(refuge: StringName) -> void:
	if refuge == active or not REFUGES.has(refuge):
		return
	active = refuge
	moved.emit(refuge)
	changed.emit()


# --- Blueprint ---------------------------------------------------------------
# `refuge` vacío = el activo.

func level(slot: StringName, refuge: StringName = &"") -> int:
	return refuge_levels[_r(refuge)].get(slot, 0)


func max_level(slot: StringName) -> int:
	return SLOTS[slot].levels.size()


## Datos del próximo nivel, o {} si el espacio está completo.
func next_upgrade(slot: StringName, refuge: StringName = &"") -> Dictionary:
	var current := level(slot, refuge)
	return SLOTS[slot].levels[current] if current < max_level(slot) else {}


func can_afford(cost: Dictionary) -> bool:
	for id in cost:
		if stock.get(id, 0) < cost[id]:
			return false
	return true


func upgrade(slot: StringName, refuge: StringName = &"") -> bool:
	var r := _r(refuge)
	var next := next_upgrade(slot, r)
	if next.is_empty() or not can_afford(next.cost):
		return false
	for id in next.cost:
		stock[id] -= next.cost[id]
	refuge_levels[r][slot] = level(slot, r) + 1
	slot_upgraded.emit(slot, refuge_levels[r][slot], r)
	changed.emit()
	return true


func cozy(refuge: StringName = &"") -> int:
	var total := 0
	for slot in SLOT_ORDER:
		for i in level(slot, refuge):
			total += SLOTS[slot].levels[i].cozy
	return total


func cozy_max() -> int:
	var total := 0
	for slot in SLOT_ORDER:
		for lvl in SLOTS[slot].levels:
			total += lvl.cozy
	return total


## Cuánto se frena el goteo de cordura en el refugio según el nivel cozy.
func drain_multiplier(refuge: StringName = &"") -> float:
	return lerpf(drain_multiplier_bare, drain_multiplier_full, float(cozy(refuge)) / cozy_max())


func has_electricity(refuge: StringName = &"") -> bool:
	return level(&"power", refuge) >= 1


func _r(refuge: StringName) -> StringName:
	return active if refuge == &"" else refuge


func material_name(id: StringName) -> String:
	return MATERIALS[id].display_name


# --- Materiales --------------------------------------------------------------

## Lugares del alijo según su nivel.
func stash_capacity_now() -> int:
	return stash_capacity[mini(level(&"stash"), stash_capacity.size() - 1)]


## Lugares ocupados (las pilas de munición o comida ocupan uno).
func stash_used() -> int:
	return stash.size()


## Deja una entrada de la mochila en el alijo. Los materiales van al depósito de
## construcción (no ocupan lugar). Devuelve el texto para la UI.
func store(entry: Dictionary) -> String:
	var item: ItemData = entry.item
	if item.is_material():
		stock[item.id] = stock.get(item.id, 0) + entry.count
		Inventory.remove_entry(entry)
		materials_deposited.emit({item.id: entry.count})
		changed.emit()
		return "Dejé %d de %s para construir." % [entry.count, item.display_name.to_lower()]
	var stack := _stash_stack(item)
	if stack.is_empty() and stash_used() >= stash_capacity_now():
		return "El alijo está lleno. Hay que mejorarlo (ver el plano)."
	if not stack.is_empty():
		stack.count += entry.count
	else:
		var copy := entry.duplicate()
		copy.erase("cell")
		copy.erase("rotated")
		stash.append(copy)
	Inventory.remove_entry(entry)
	changed.emit()
	return "Guardado: %s." % item.display_name


## Pasa todos los materiales de la mochila al depósito. Devuelve {material: cantidad}.
func store_materials() -> Dictionary:
	var amounts := {}
	for entry in Inventory.entries.duplicate():
		var item: ItemData = entry.item
		if item.is_material():
			amounts[item.id] = amounts.get(item.id, 0) + entry.count
			store(entry)
	return amounts


## Saca una entrada del alijo a la mochila (si entra).
func take(index: int) -> String:
	if index < 0 or index >= stash.size():
		return ""
	var entry: Dictionary = stash[index]
	if not Inventory.add_entry(entry):
		return "No me entra en la mochila."
	stash.remove_at(index)
	changed.emit()
	return "En la mochila: %s." % (entry.item as ItemData).display_name


func _stash_stack(item: ItemData) -> Dictionary:
	if item.max_stack <= 1:
		return {}
	for entry in stash:
		if entry.item == item:
			return entry
	return {}


# --- Estaciones --------------------------------------------------------------

func cook(refuge: StringName = &"") -> String:
	if level(&"fire", refuge) < 1:
		return "Sin fuego no hay forma de cocinar."
	for entry in Inventory.entries:
		var item: ItemData = entry.item
		if item.kind == ItemData.Kind.FOOD and not entry.get("cooked", false):
			entry.cooked = true
			Inventory.changed.emit()
			return "Calenté %s. Va a rendir más." % item.display_name.to_lower()
	return "No tengo nada para cocinar."


func rest(refuge: StringName = &"") -> String:
	if level(&"bed", refuge) < 1:
		return "En este colchón no se descansa. Hay que armar una cama."
	if not _cooldown_ready(&"rest"):
		return "No tengo sueño. Todavía no."
	Sanity.restore(rest_amount[mini(level(&"bed", refuge), rest_amount.size()) - 1])
	_start_cooldown(&"rest", rest_cooldown)
	return "Dormí un rato. Soñé con una casa con ventanas."


func play_radio(refuge: StringName = &"") -> String:
	if level(&"power", refuge) < 2:
		return "La radio está muerta. Falta una instalación decente."
	if not _cooldown_ready(&"radio"):
		return "Solo estática. Mejor más tarde."
	Sanity.restore(radio_amount)
	_start_cooldown(&"radio", radio_cooldown)
	return "Un tango viejo entre la estática. Por un momento, el mundo es normal."


func radio_ready() -> bool:
	return _cooldown_ready(&"radio")


func _cooldown_ready(key: StringName) -> bool:
	return Time.get_ticks_msec() >= _cooldowns.get(key, 0)


func _start_cooldown(key: StringName, seconds: float) -> void:
	_cooldowns[key] = Time.get_ticks_msec() + int(seconds * 1000.0)


# --- Salidas y bono de llegar a casa -----------------------------------------

## Lo llaman las DiscoveryZone. Devuelve true si el lugar era nuevo.
func discover(place: StringName) -> bool:
	if discovered.has(place):
		return false
	discovered[place] = true
	if _trip_active:
		_trip_places += 1
	return true


func _on_item_added(item: ItemData) -> void:
	if not _trip_active:
		return
	if item.is_letter():
		_trip_letters += 1
	else:
		_trip_items += 1


func _on_refuge_exited() -> void:
	_trip_active = true
	_trip_places = 0
	_trip_items = 0
	_trip_letters = 0


func _on_refuge_entered() -> void:
	# Las cosas no se guardan solas: hay que dejarlas en el alijo (GDD: el refugio como casa).
	var lines: PackedStringArray = []
	if _trip_active:
		_trip_active = false
		var bonus := minf(bonus_max, _trip_places * bonus_per_new_place
			+ _trip_items * bonus_per_item + _trip_letters * bonus_per_letter)
		if bonus > 0.0:
			Sanity.restore(bonus)
			lines.append("Volver a casa. Por fin." if bonus >= bonus_max * 0.5 else "Volver a casa.")
	if Inventory.entries.any(func(e: Dictionary) -> bool: return (e.item as ItemData).is_material()):
		lines.append("Los materiales los tengo que dejar en el alijo.")
	if not lines.is_empty():
		GameState.post_message(" ".join(lines))
