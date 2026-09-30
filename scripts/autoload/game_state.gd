extends Node
## Autoload "GameState": lo que persiste entre sobrevivientes de una misma partida.
## El mundo sigue tal cual quedó (GDD): objetos recogidos, objetos tirados y
## cuerpos. Se guarda a disco con SaveGame (`save_data` / `load_data`).
## También hace los fundidos a negro entre escenas (`change_scene`).

## Mensaje breve para mostrar en pantalla (lo muestra GameUI).
signal message_posted(text: String)
## Se marcó un hecho del mundo (puertas que se abren, jefes muertos...).
signal flag_set(flag: StringName)

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

## Si no está vacía, reemplaza la escena del refugio activo (los tests usan la sala de prueba).
var refuge_scene := ""
## SpawnPoint donde aparecer al cargar la próxima escena (vacío = donde esté el jugador).
var next_spawn: StringName = &""
## Al cargar una partida: { "position": Vector3, "yaw": float } del jugador.
var pending_player: Dictionary = {}

## Duración de cada mitad del fundido entre escenas.
@export var fade_time := 0.35

var _fade: ColorRect

## Enemigos muertos (clave: ruta del nodo). No reaparecen.
var killed_enemies: Dictionary = {}

var _next_id := 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Debajo del post-proceso (100) para que el negro también tenga el dithering.
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.modulate.a = 0.0
	layer.add_child(_fade)


## Cambia de escena con un fundido a negro.
func change_scene(scene_path: String) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", 1.0, fade_time)
	await tween.finished
	get_tree().paused = false
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await get_tree().process_frame
	create_tween().tween_property(_fade, "modulate:a", 0.0, fade_time)


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
	flag_set.emit(flag)


## Pasa a otra zona. El jugador aparece en el SpawnPoint `spawn`.
func travel(scene_path: String, spawn: StringName) -> void:
	next_spawn = spawn
	change_scene(scene_path)


## Nuevo sobreviviente: llega al refugio activo (Shelter).
func new_survivor() -> void:
	survivor_number += 1
	playstyle.clear()
	next_spawn = &"" if refuge_scene != "" else Shelter.refuge_spawn()
	change_scene(refuge_scene if refuge_scene != "" else Shelter.refuge_scene())


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
	pending_player = {}


# --- Guardado ------------------------------------------------------------------

func save_data() -> Dictionary:
	return {
		"survivor_number": survivor_number,
		"collected_pickups": collected_pickups.duplicate(),
		"dropped_items": dropped_items.map(_with_item_paths),
		"corpses": corpses.map(_with_item_paths),
		"lost_ones": lost_ones.map(_with_item_paths),
		"killed_enemies": killed_enemies.duplicate(),
		"playstyle": playstyle.duplicate(),
		"flags": flags.duplicate(),
		"next_id": _next_id,
	}


func load_data(data: Dictionary) -> void:
	survivor_number = data.get("survivor_number", 1)
	collected_pickups = data.get("collected_pickups", {})
	dropped_items.assign(data.get("dropped_items", []).map(_with_items))
	corpses.assign(data.get("corpses", []).map(_with_items))
	lost_ones.assign(data.get("lost_ones", []).map(_with_items))
	killed_enemies = data.get("killed_enemies", {})
	playstyle = data.get("playstyle", {})
	flags = data.get("flags", {})
	_next_id = data.get("next_id", 1)
	next_spawn = &""


## Copia de un registro con los ItemData cambiados por su ruta (`item` e `items`).
static func _with_item_paths(record: Dictionary) -> Dictionary:
	var copy := record.duplicate()
	if copy.has("item"):
		copy.item = (copy.item as ItemData).resource_path
	if copy.has("items"):
		copy.items = copy.items.map(func(item: ItemData) -> String: return item.resource_path)
	return copy


static func _with_items(record: Dictionary) -> Dictionary:
	var copy := record.duplicate()
	if copy.has("item"):
		copy.item = load(copy.item)
	if copy.has("items"):
		var items: Array[ItemData] = []
		for path: String in copy.items:
			items.append(load(path))
		copy.items = items
	return copy


func _new_id() -> int:
	_next_id += 1
	return _next_id
