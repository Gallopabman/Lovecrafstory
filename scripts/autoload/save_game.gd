extends Node
## Autoload "SaveGame": guarda y carga la partida en disco (un solo espacio).
## Junta el estado de GameState, Inventory, Sanity y Shelter, la escena y dónde
## está el jugador. Guardado manual desde el menú de pausa y automático al cambiar
## de zona y al llegar al refugio. Formato: texto de `var_to_str` (los objetos,
## por su ruta de recurso).

signal saved

const VERSION := 1

## Los tests usan otro archivo para no pisar la partida del jugador.
var path := "user://save.dat"
## Guardado automático (al cambiar de zona y al entrar al refugio).
var autosave_enabled := true


func _ready() -> void:
	Sanity.refuge_entered.connect(func() -> void: autosave.call_deferred())


func has_save() -> bool:
	return FileAccess.file_exists(path)


## Se puede guardar si hay un jugador vivo en una zona.
func can_save() -> bool:
	return Sanity.active and get_tree().get_first_node_in_group(&"player") != null


func save_game() -> bool:
	if not can_save():
		return false
	var player := get_tree().get_first_node_in_group(&"player") as Player
	var data := {
		"version": VERSION,
		"scene": get_tree().current_scene.scene_file_path,
		"player": {"position": player.global_position, "yaw": player.visual.global_rotation.y},
		"game_state": GameState.save_data(),
		"inventory": Inventory.save_data(),
		"sanity": Sanity.save_data(),
		"health": Health.save_data(),
		"shelter": Shelter.save_data(),
		"date": Time.get_datetime_string_from_system(false, true),
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("No se pudo guardar en %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(var_to_str(data))
	file.close()
	saved.emit()
	return true


func autosave() -> void:
	if autosave_enabled:
		save_game()


## Lo guardado, o vacío si no hay partida (o es de otra versión).
func read() -> Dictionary:
	if not has_save():
		return {}
	var data: Variant = str_to_var(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("version", 0) != VERSION:
		return {}
	return data


## Una línea para el menú: "Sobreviviente #2 · 2026-09-30 21:14".
func summary() -> String:
	var data := read()
	if data.is_empty():
		return ""
	return "Sobreviviente #%d  ·  %s" % [data.game_state.get("survivor_number", 1), data.get("date", "")]


func load_game() -> bool:
	var data := read()
	if data.is_empty():
		return false
	GameState.load_data(data.game_state)
	Inventory.load_data(data.inventory)
	Sanity.load_data(data.sanity)
	Health.load_data(data.get("health", {}))
	Shelter.load_data(data.shelter)
	GameState.pending_player = data.player
	GameState.change_scene(data.scene)
	return true


## Partida nueva: todo vuelve a cero (no borra lo guardado hasta el próximo guardado).
func new_game() -> void:
	GameState.new_game()
	Inventory.clear()
	Sanity.new_game()
	Health.reset()
	Shelter.new_game()
