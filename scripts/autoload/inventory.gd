extends Node
## Autoload "Inventory": lo que el sobreviviente lleva encima.
## Se pierde entero al morir (muta con el Perdido, ver GDD).

signal changed
signal item_added(item: ItemData, count: int)
## Emitida al usar una carta, para que la UI muestre su texto.
signal letter_opened(item: ItemData)

## Cada entrada: { "item": ItemData, "count": int }
var entries: Array[Dictionary] = []

## Veces que se usó cada reutilizable (rendimiento decreciente) y cartas leídas.
var _use_counts: Dictionary = {}


func add(item: ItemData, count := 1) -> void:
	var entry := _find(item)
	if entry.is_empty() or not item.is_stackable():
		entries.append({"item": item, "count": count})
	else:
		entry.count += count
	item_added.emit(item, count)
	changed.emit()


func remove(item: ItemData, count := 1) -> void:
	var entry := _find(item)
	if entry.is_empty():
		return
	entry.count -= count
	if entry.count <= 0:
		entries.erase(entry)
	changed.emit()


func clear() -> void:
	entries.clear()
	_use_counts.clear()
	changed.emit()


## Devuelve el motivo por el que no se puede usar, o "" si se puede.
func use_blocker(item: ItemData) -> String:
	if item.requires_electricity and not Sanity.has_electricity():
		return "Necesito electricidad para esto."
	return ""


## Usa el objeto y devuelve un texto de resultado para la UI.
func use(item: ItemData) -> String:
	var blocker := use_blocker(item)
	if blocker:
		return blocker
	var times_used: int = _use_counts.get(item.id, 0)
	_use_counts[item.id] = times_used + 1
	var result := ""
	match item.kind:
		ItemData.Kind.FOOD:
			Sanity.restore(item.sanity_restore)
			remove(item)
			result = "Por un momento, todo parece normal."
		ItemData.Kind.COMIC, ItemData.Kind.MOVIE:
			var amount := item.sanity_restore * pow(item.reuse_falloff, times_used)
			Sanity.restore(amount)
			result = "Me distrae." if times_used == 0 else "Ya me lo sé de memoria..."
		ItemData.Kind.LETTER:
			if times_used == 0:
				Sanity.increase_maximum(item.max_sanity_bonus)
				Sanity.fill()
				result = "No estoy solo en esto."
			letter_opened.emit(item)
	changed.emit()
	return result


func times_used(item: ItemData) -> int:
	return _use_counts.get(item.id, 0)


func _find(item: ItemData) -> Dictionary:
	for entry in entries:
		if entry.item == item:
			return entry
	return {}
