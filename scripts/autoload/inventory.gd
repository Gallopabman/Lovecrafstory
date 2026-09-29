extends Node
## Autoload "Inventory": lo que el sobreviviente lleva encima.
## Mochila en cuadrícula estilo Resident Evil: cada objeto ocupa `grid_size`
## celdas y puede girarse; la munición se apila. Las cartas van aparte y no
## ocupan lugar. Un arma de la mochila puede estar equipada.

signal changed
signal item_added(item: ItemData)
## No hubo lugar en la mochila.
signal add_failed(item: ItemData)
## El jugador tiró un objeto: el mundo tiene que hacerlo aparecer en el piso.
signal item_dropped(item: ItemData)
## Emitida al usar una carta, para que la UI muestre su texto.
signal letter_opened(item: ItemData)
## Cambió el arma equipada (entrada vacía = manos vacías).
signal equipped_changed(entry: Dictionary)

@export var grid_size := Vector2i(6, 4)

## Cada entrada: { "item": ItemData, "cell": Vector2i, "rotated": bool,
## "count": int (pilas), "loaded": int (balas en el cargador de un arma) }
var entries: Array[Dictionary] = []
var letters: Array[ItemData] = []
## Entrada del arma equipada, o vacía.
var equipped: Dictionary = {}

## Veces que se usó cada objeto (rendimiento decreciente y cartas ya leídas).
var _use_counts: Dictionary = {}


static func footprint(item: ItemData, rotated: bool) -> Vector2i:
	return Vector2i(item.grid_size.y, item.grid_size.x) if rotated else item.grid_size


static func entry_rect(entry: Dictionary) -> Rect2i:
	return Rect2i(entry.cell, footprint(entry.item, entry.rotated))


## Guarda una unidad del objeto: primero en una pila existente, si no en el
## primer lugar libre (probando también girado).
func add(item: ItemData) -> bool:
	if item.is_letter():
		letters.append(item)
	else:
		var stack := _find_stack_with_room(item)
		if not stack.is_empty():
			stack.count += 1
		else:
			var spot := find_space(item)
			if spot.is_empty():
				add_failed.emit(item)
				return false
			# Las armas encontradas vienen cargadas.
			entries.append({"item": item, "cell": spot.cell, "rotated": spot.rotated,
				"count": 1, "loaded": item.magazine_size})
	item_added.emit(item)
	changed.emit()
	return true


func find_space(item: ItemData) -> Dictionary:
	for rotated in [false, true]:
		if rotated and item.grid_size.x == item.grid_size.y:
			continue
		for y in grid_size.y:
			for x in grid_size.x:
				if can_place(item, Vector2i(x, y), rotated):
					return {"cell": Vector2i(x, y), "rotated": rotated}
	return {}


## `ignore` permite chequear el lugar de un objeto que se está moviendo.
func can_place(item: ItemData, cell: Vector2i, rotated: bool, ignore: Dictionary = {}) -> bool:
	var rect := Rect2i(cell, footprint(item, rotated))
	if not Rect2i(Vector2i.ZERO, grid_size).encloses(rect):
		return false
	for entry in entries:
		if not is_same(entry, ignore) and rect.intersects(entry_rect(entry)):
			return false
	return true


func entry_at(cell: Vector2i) -> Dictionary:
	for entry in entries:
		if entry_rect(entry).has_point(cell):
			return entry
	return {}


func move(entry: Dictionary, cell: Vector2i, rotated: bool) -> bool:
	if not can_place(entry.item, cell, rotated, entry):
		return false
	entry.cell = cell
	entry.rotated = rotated
	changed.emit()
	return true


func remove_entry(entry: Dictionary) -> void:
	var index := _index_of(entry)
	if index < 0:
		return
	entries.remove_at(index)
	if is_same(entry, equipped):
		equip({})
	changed.emit()


## Tira la pila entera al piso (una unidad por pickup).
func drop(entry: Dictionary) -> void:
	var item: ItemData = entry.item
	var count: int = entry.count
	remove_entry(entry)
	for i in count:
		item_dropped.emit(item)


## Todo lo que lleva encima, una vez por unidad (p. ej. para dejarlo en un cuerpo).
func all_items() -> Array[ItemData]:
	var items: Array[ItemData] = []
	for entry in entries:
		for i in entry.count:
			items.append(entry.item)
	items.append_array(letters)
	return items


func clear() -> void:
	entries.clear()
	letters.clear()
	_use_counts.clear()
	equip({})
	changed.emit()


func is_equipped(entry: Dictionary) -> bool:
	return not equipped.is_empty() and is_same(entry, equipped)


func equip(entry: Dictionary) -> void:
	equipped = entry
	equipped_changed.emit(entry)
	changed.emit()


func equipped_item() -> ItemData:
	return equipped.item if not equipped.is_empty() else null


func ammo_count(ammo: ItemData) -> int:
	var total := 0
	for entry in entries:
		if entry.item == ammo:
			total += entry.count
	return total


## Saca hasta `amount` unidades de munición de las pilas. Devuelve cuántas sacó.
func take_ammo(ammo: ItemData, amount: int) -> int:
	var taken := 0
	for entry in entries.duplicate():
		if taken >= amount:
			break
		if entry.item != ammo:
			continue
		var take := mini(entry.count, amount - taken)
		entry.count -= take
		taken += take
		if entry.count <= 0:
			remove_entry(entry)
	if taken > 0:
		changed.emit()
	return taken


## Recarga el arma equipada con munición de la mochila. Devuelve las balas cargadas.
func reload_equipped() -> int:
	var weapon := equipped_item()
	if weapon == null or not weapon.is_ranged or weapon.ammo_item == null:
		return 0
	var missing: int = weapon.magazine_size - equipped.loaded
	var taken := take_ammo(weapon.ammo_item, missing)
	equipped.loaded += taken
	changed.emit()
	return taken


## Devuelve el motivo por el que no se puede usar, o "" si se puede.
func use_blocker(item: ItemData) -> String:
	if item.requires_electricity and not Sanity.has_electricity():
		return "Necesito electricidad para esto."
	return ""


## Usa el objeto y devuelve un texto de resultado para la UI.
## `entry` es la entrada de la mochila (comida a consumir, arma a equipar).
func use(item: ItemData, entry: Dictionary = {}) -> String:
	var blocker := use_blocker(item)
	if blocker:
		return blocker
	if entry.is_empty() and not item.is_letter():
		entry = _find_entry(item)
	var result := ""
	match item.kind:
		ItemData.Kind.FOOD:
			Sanity.restore(item.sanity_restore)
			_consume_one(entry)
			result = "Por un momento, todo parece normal."
		ItemData.Kind.COMIC, ItemData.Kind.MOVIE:
			var times: int = _use_counts.get(item.id, 0)
			Sanity.restore(item.sanity_restore * pow(item.reuse_falloff, times))
			result = "Me distrae." if times == 0 else "Ya me lo sé de memoria..."
		ItemData.Kind.LETTER:
			if _use_counts.get(item.id, 0) == 0:
				Sanity.increase_maximum(item.max_sanity_bonus)
				Sanity.fill()
				result = "No estoy solo en esto."
			letter_opened.emit(item)
		ItemData.Kind.WEAPON:
			if is_equipped(entry):
				equip({})
				result = "Guardé %s." % item.display_name.to_lower()
			else:
				equip(entry)
				result = "Tengo %s en la mano." % item.display_name.to_lower()
		ItemData.Kind.AMMO:
			var weapon := equipped_item()
			if weapon == null or weapon.ammo_item != item:
				return "No tengo equipada un arma para esto."
			if reload_equipped() == 0:
				return "Ya está cargada."
			result = "Cargué %s." % weapon.display_name.to_lower()
	_use_counts[item.id] = _use_counts.get(item.id, 0) + 1
	changed.emit()
	return result


func times_used(item: ItemData) -> int:
	return _use_counts.get(item.id, 0)


func _consume_one(entry: Dictionary) -> void:
	if entry.is_empty():
		return
	entry.count -= 1
	if entry.count <= 0:
		remove_entry(entry)


func _find_stack_with_room(item: ItemData) -> Dictionary:
	if item.max_stack <= 1:
		return {}
	for entry in entries:
		if entry.item == item and entry.count < item.max_stack:
			return entry
	return {}


func _find_entry(item: ItemData) -> Dictionary:
	for entry in entries:
		if entry.item == item:
			return entry
	return {}


func _index_of(entry: Dictionary) -> int:
	for i in entries.size():
		if is_same(entries[i], entry):
			return i
	return -1
