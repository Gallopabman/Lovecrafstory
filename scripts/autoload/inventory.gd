extends Node
## Autoload "Inventory": lo que el sobreviviente lleva encima.
## Mochila en cuadrícula estilo Resident Evil: cada objeto ocupa `grid_size`
## celdas y puede girarse. Las cartas van aparte y no ocupan lugar.

signal changed
signal item_added(item: ItemData)
## No hubo lugar en la mochila.
signal add_failed(item: ItemData)
## El jugador tiró un objeto: el mundo tiene que hacerlo aparecer en el piso.
signal item_dropped(item: ItemData)
## Emitida al usar una carta, para que la UI muestre su texto.
signal letter_opened(item: ItemData)

@export var grid_size := Vector2i(6, 4)

## Cada entrada: { "item": ItemData, "cell": Vector2i, "rotated": bool }
var entries: Array[Dictionary] = []
var letters: Array[ItemData] = []

## Veces que se usó cada objeto (rendimiento decreciente y cartas ya leídas).
var _use_counts: Dictionary = {}


static func footprint(item: ItemData, rotated: bool) -> Vector2i:
	return Vector2i(item.grid_size.y, item.grid_size.x) if rotated else item.grid_size


static func entry_rect(entry: Dictionary) -> Rect2i:
	return Rect2i(entry.cell, footprint(entry.item, entry.rotated))


## Guarda el objeto en el primer lugar libre (probando también girado).
func add(item: ItemData) -> bool:
	if item.is_letter():
		letters.append(item)
	else:
		var spot := find_space(item)
		if spot.is_empty():
			add_failed.emit(item)
			return false
		entries.append({"item": item, "cell": spot.cell, "rotated": spot.rotated})
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
	var index := entries.find(entry)
	if index >= 0:
		entries.remove_at(index)
		changed.emit()


func drop(entry: Dictionary) -> void:
	var item: ItemData = entry.item
	remove_entry(entry)
	item_dropped.emit(item)


## Todo lo que lleva encima (mochila + cartas), por ejemplo para dejarlo en un cuerpo.
func all_items() -> Array[ItemData]:
	var items: Array[ItemData] = []
	for entry in entries:
		items.append(entry.item)
	items.append_array(letters)
	return items


func clear() -> void:
	entries.clear()
	letters.clear()
	_use_counts.clear()
	changed.emit()


## Devuelve el motivo por el que no se puede usar, o "" si se puede.
func use_blocker(item: ItemData) -> String:
	if item.requires_electricity and not Sanity.has_electricity():
		return "Necesito electricidad para esto."
	return ""


## Usa el objeto y devuelve un texto de resultado para la UI.
## `entry` es la entrada de la mochila (necesaria para consumir comida).
func use(item: ItemData, entry: Dictionary = {}) -> String:
	var blocker := use_blocker(item)
	if blocker:
		return blocker
	var times: int = _use_counts.get(item.id, 0)
	_use_counts[item.id] = times + 1
	var result := ""
	match item.kind:
		ItemData.Kind.FOOD:
			Sanity.restore(item.sanity_restore)
			remove_entry(entry if not entry.is_empty() else _find_entry(item))
			result = "Por un momento, todo parece normal."
		ItemData.Kind.COMIC, ItemData.Kind.MOVIE:
			Sanity.restore(item.sanity_restore * pow(item.reuse_falloff, times))
			result = "Me distrae." if times == 0 else "Ya me lo sé de memoria..."
		ItemData.Kind.LETTER:
			if times == 0:
				Sanity.increase_maximum(item.max_sanity_bonus)
				Sanity.fill()
				result = "No estoy solo en esto."
			letter_opened.emit(item)
	changed.emit()
	return result


func times_used(item: ItemData) -> int:
	return _use_counts.get(item.id, 0)


func _find_entry(item: ItemData) -> Dictionary:
	for entry in entries:
		if entry.item == item:
			return entry
	return {}
