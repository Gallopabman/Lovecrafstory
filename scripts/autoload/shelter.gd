extends Node
## Autoload "Shelter": el refugio como hogar (GDD, "Refugio y housing").
## - Blueprint estático: espacios fijos que se mejoran con materiales.
## - Nivel "cozy": no sube la cordura; hace que baje más lento en el refugio y
##   las mejoras habilitan estaciones que sí la suben (cocinar, descansar, radio, TV).
## - Bono de llegar a casa según lo que se logró en la salida (no se puede farmear).
## Todo esto sobrevive a la muerte del sobreviviente: el refugio se conserva.

signal changed
signal slot_upgraded(slot_id: StringName, level: int)
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
}
const SLOT_ORDER: Array[StringName] = [&"fire", &"power", &"bed", &"windows", &"decor"]

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

var levels: Dictionary = {}
var stock: Dictionary = {}
## Lugares descubiertos alguna vez (por cualquier sobreviviente).
var discovered: Dictionary = {}

var _trip_active := false
var _trip_places := 0
var _trip_items := 0
var _trip_letters := 0
var _cooldowns: Dictionary = {}


func _ready() -> void:
	for slot in SLOT_ORDER:
		levels[slot] = 0
	for id in MATERIALS:
		stock[id] = 0
	Sanity.refuge_entered.connect(_on_refuge_entered)
	Sanity.refuge_exited.connect(_on_refuge_exited)
	Sanity.lost.connect(func() -> void: _trip_active = false)
	Inventory.item_added.connect(_on_item_added)


# --- Blueprint ---------------------------------------------------------------

func level(slot: StringName) -> int:
	return levels.get(slot, 0)


func max_level(slot: StringName) -> int:
	return SLOTS[slot].levels.size()


## Datos del próximo nivel, o {} si el espacio está completo.
func next_upgrade(slot: StringName) -> Dictionary:
	var current := level(slot)
	return SLOTS[slot].levels[current] if current < max_level(slot) else {}


func can_afford(cost: Dictionary) -> bool:
	for id in cost:
		if stock.get(id, 0) < cost[id]:
			return false
	return true


func upgrade(slot: StringName) -> bool:
	var next := next_upgrade(slot)
	if next.is_empty() or not can_afford(next.cost):
		return false
	for id in next.cost:
		stock[id] -= next.cost[id]
	levels[slot] = level(slot) + 1
	slot_upgraded.emit(slot, levels[slot])
	changed.emit()
	return true


func cozy() -> int:
	var total := 0
	for slot in SLOT_ORDER:
		for i in level(slot):
			total += SLOTS[slot].levels[i].cozy
	return total


func cozy_max() -> int:
	var total := 0
	for slot in SLOT_ORDER:
		for lvl in SLOTS[slot].levels:
			total += lvl.cozy
	return total


## Cuánto se frena el goteo de cordura en el refugio según el nivel cozy.
func drain_multiplier() -> float:
	return lerpf(drain_multiplier_bare, drain_multiplier_full, float(cozy()) / cozy_max())


func has_electricity() -> bool:
	return level(&"power") >= 1


func material_name(id: StringName) -> String:
	return MATERIALS[id].display_name


# --- Materiales --------------------------------------------------------------

## Pasa todos los materiales de la mochila al depósito del refugio.
func deposit_materials() -> Dictionary:
	var amounts := {}
	for entry in Inventory.entries.duplicate():
		var item: ItemData = entry.item
		if item.is_material():
			amounts[item.id] = amounts.get(item.id, 0) + entry.count
			stock[item.id] = stock.get(item.id, 0) + entry.count
			Inventory.remove_entry(entry)
	if not amounts.is_empty():
		materials_deposited.emit(amounts)
		changed.emit()
	return amounts


# --- Estaciones --------------------------------------------------------------

func cook() -> String:
	if level(&"fire") < 1:
		return "Sin fuego no hay forma de cocinar."
	for entry in Inventory.entries:
		var item: ItemData = entry.item
		if item.kind == ItemData.Kind.FOOD and not entry.get("cooked", false):
			entry.cooked = true
			Inventory.changed.emit()
			return "Calenté %s. Va a rendir más." % item.display_name.to_lower()
	return "No tengo nada para cocinar."


func rest() -> String:
	if level(&"bed") < 1:
		return "En este colchón no se descansa. Hay que armar una cama."
	if not _cooldown_ready(&"rest"):
		return "No tengo sueño. Todavía no."
	Sanity.restore(rest_amount[mini(level(&"bed"), rest_amount.size()) - 1])
	_start_cooldown(&"rest", rest_cooldown)
	return "Dormí un rato. Soñé con una casa con ventanas."


func play_radio() -> String:
	if level(&"power") < 2:
		return "La radio está muerta. Falta una instalación decente."
	if not _cooldown_ready(&"radio"):
		return "Solo estática. Mejor más tarde."
	Sanity.restore(radio_amount)
	_start_cooldown(&"radio", radio_cooldown)
	return "Un tango viejo entre la estática. Por un momento, el mundo es normal."


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
	var deposited := deposit_materials()
	var lines: PackedStringArray = []
	if not deposited.is_empty():
		var parts: PackedStringArray = []
		for id in deposited:
			parts.append("%d %s" % [deposited[id], material_name(id).to_lower()])
		lines.append("Dejé en el refugio: %s." % ", ".join(parts))
	if _trip_active:
		_trip_active = false
		var bonus := minf(bonus_max, _trip_places * bonus_per_new_place
			+ _trip_items * bonus_per_item + _trip_letters * bonus_per_letter)
		if bonus > 0.0:
			Sanity.restore(bonus)
			lines.append("Volver a casa. Por fin." if bonus >= bonus_max * 0.5 else "Volver a casa.")
	if not lines.is_empty():
		GameState.post_message(" ".join(lines))
