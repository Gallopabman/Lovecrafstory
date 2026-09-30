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
## Sobrevivientes perdidos fuera de casa: cada uno vaga como el Perdido por la zona
## donde cayó. { "id", "survivor", "scene", "position", "items": Array[ItemData],
## "style": Dictionary (ver `playstyle`), "defeated": bool }
var lost_ones: Array[Dictionary] = []

## Cómo juega el sobreviviente actual; define las habilidades de su Perdido.
## Se reinicia con cada sobreviviente.
var playstyle: Dictionary = {}

## Hechos del mundo que persisten (puertas forzadas, etc.).
var flags: Dictionary = {}

## Escena del refugio: ahí llega cada sobreviviente nuevo.
var refuge_scene := "res://scenes/levels/hospital.tscn"
## SpawnPoint donde aparecer al cargar la próxima escena (vacío = donde esté el jugador).
var next_spawn: StringName = &""

## Enemigos muertos (clave: ruta del nodo). No reaparecen.
var killed_enemies: Dictionary = {}

var _next_id := 1


func post_message(text: String) -> void:
	message_posted.emit(text)


func mark_collected(key: String) -> void:
	collected_pickups[key] = true


func is_collected(key: String) -> bool:
	return collected_pickups.has(key)


func mark_killed(key: String) -> void:
	killed_enemies[key] = true


func is_killed(key: String) -> bool:
	return killed_enemies.has(key)


func add_dropped(item: ItemData, position: Vector3) -> Dictionary:
	var data := {"id": _new_id(), "item": item, "position": position, "scene": current_scene_path()}
	dropped_items.append(data)
	return data


func remove_dropped(id: int) -> void:
	dropped_items = dropped_items.filter(func(d: Dictionary) -> bool: return d.id != id)


func add_corpse(position: Vector3, yaw: float, items: Array[ItemData]) -> Dictionary:
	var data := {"id": _new_id(), "position": position, "yaw": yaw, "items": items,
		"scene": current_scene_path()}
	corpses.append(data)
	return data


func get_corpse(id: int) -> Dictionary:
	for corpse in corpses:
		if corpse.id == id:
			return corpse
	return {}


## Objetos tirados, cuerpos y Perdidos se guardan por escena.
func current_scene_path() -> String:
	var scene := get_tree().current_scene
	return scene.scene_file_path if scene else ""


func add_lost_one(position: Vector3, items: Array[ItemData]) -> Dictionary:
	var data := {"id": _new_id(), "survivor": survivor_number, "scene": current_scene_path(),
		"position": position, "items": items, "style": playstyle.duplicate(), "defeated": false}
	lost_ones.append(data)
	return data


func lost_ones_here() -> Array[Dictionary]:
	var here := current_scene_path()
	return lost_ones.filter(func(d: Dictionary) -> bool: return d.scene == here and not d.defeated)


func get_lost_one(id: int) -> Dictionary:
	for data in lost_ones:
		if data.id == id:
			return data
	return {}


## Suma a una estadística de estilo de juego (disparos, golpes, tiempo agachado...).
func track(stat: StringName, amount: float = 1.0) -> void:
	playstyle[stat] = playstyle.get(stat, 0.0) + amount


func has_flag(flag: StringName) -> bool:
	return flags.get(flag, false)


func set_flag(flag: StringName, value := true) -> void:
	flags[flag] = value


## Pasa a otra zona. El jugador aparece en el SpawnPoint `spawn`.
func travel(scene_path: String, spawn: StringName) -> void:
	next_spawn = spawn
	get_tree().change_scene_to_file.call_deferred(scene_path)


## Nuevo sobreviviente: llega al refugio.
func new_survivor() -> void:
	survivor_number += 1
	playstyle.clear()
	next_spawn = &""
	get_tree().change_scene_to_file.call_deferred(refuge_scene)


## Partida nueva desde el menú de inicio.
func new_game() -> void:
	survivor_number = 1
	collected_pickups.clear()
	dropped_items.clear()
	corpses.clear()
	lost_ones.clear()
	killed_enemies.clear()
	playstyle.clear()
	flags.clear()
	next_spawn = &""


func _new_id() -> int:
	_next_id += 1
	return _next_id
