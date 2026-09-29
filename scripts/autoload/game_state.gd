extends Node
## Autoload "GameState": lo que persiste entre sobrevivientes de una misma partida.
## El mundo sigue tal cual quedó (GDD): objetos recogidos, objetos tirados y
## cuerpos. Todavía no se guarda a disco.

## Mensaje breve para mostrar en pantalla (lo muestra GameUI).
signal message_posted(text: String)

var survivor_number := 1
## Pickups colocados en los niveles que ya se recogieron (clave: ruta del nodo).
var collected_pickups: Dictionary = {}
## Objetos que el jugador tiró: { "id": int, "item": ItemData, "position": Vector3 }
var dropped_items: Array[Dictionary] = []
## Sobrevivientes muertos en el refugio (ataque cardíaco): el cuerpo queda en el
## piso con todo lo que llevaba. { "id", "position", "yaw", "items": Array[ItemData] }
var corpses: Array[Dictionary] = []
## Sobrevivientes perdidos fuera de casa: base para construir al Perdido.
## { "survivor": int, "position": Vector3, "items": Array[ItemData] }
var lost_ones: Array[Dictionary] = []

var _next_id := 1


func post_message(text: String) -> void:
	message_posted.emit(text)


func mark_collected(key: String) -> void:
	collected_pickups[key] = true


func is_collected(key: String) -> bool:
	return collected_pickups.has(key)


func add_dropped(item: ItemData, position: Vector3) -> Dictionary:
	var data := {"id": _new_id(), "item": item, "position": position}
	dropped_items.append(data)
	return data


func remove_dropped(id: int) -> void:
	dropped_items = dropped_items.filter(func(d: Dictionary) -> bool: return d.id != id)


func add_corpse(position: Vector3, yaw: float, items: Array[ItemData]) -> Dictionary:
	var data := {"id": _new_id(), "position": position, "yaw": yaw, "items": items}
	corpses.append(data)
	return data


func get_corpse(id: int) -> Dictionary:
	for corpse in corpses:
		if corpse.id == id:
			return corpse
	return {}


func add_lost_one(position: Vector3, items: Array[ItemData]) -> void:
	lost_ones.append({"survivor": survivor_number, "position": position, "items": items})


func _new_id() -> int:
	_next_id += 1
	return _next_id
