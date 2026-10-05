extends SceneTree
## Menú de pausa y guardado: Esc pausa, guardar, cambiar el estado, cargar y
## comprobar que vuelve todo (escena, posición, mochila, arma, cordura, cartas,
## refugio, mundo). Guardado automático al cambiar de zona. Capturas en
## user://test_shots/save/.
## Uso: <godot> --path . -s res://tests/save_test.gd

const OUT := "user://test_shots/save/"
const SAVE := "user://test_save.dat"

var fails := 0
var sanity: Node
var inventory: Node
var game_state: Node
var shelter: Node
var save_game: Node


func check(cond: bool, msg: String) -> void:
	print(("OK   " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func shot(name: String) -> void:
	await frames(10)
	root.get_texture().get_image().save_png(OUT + "%s.png" % name)


func player() -> Node3D:
	return current_scene.get_node("Player")


func send_action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)


func settle() -> void:
	await frames(90)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for enemy in get_nodes_in_group(&"enemies"):
		enemy.set_physics_process(false)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for action in InputMap.get_actions():
		InputMap.action_erase_events(action)
	sanity = root.get_node("Sanity")
	inventory = root.get_node("Inventory")
	game_state = root.get_node("GameState")
	shelter = root.get_node("Shelter")
	save_game = root.get_node("SaveGame")
	save_game.path = SAVE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	save_game.new_game()
	change_scene_to_file("res://scenes/levels/hospital.tscn")
	await settle()

	print("-- Menú de pausa")
	var pause: Control = current_scene.get_node("GameUI/PauseMenu")
	# El cursor real sobre un botón le daría el foco (hover): se lo lleva a una esquina.
	root.warp_mouse(Vector2(2, 2))
	await send_action("pause")
	check(pause.visible and paused, "Esc abre la pausa y pausa el juego")
	check(pause.continue_button.has_focus(), "el foco en Continuar")
	await shot("01_pausa")
	pause.options_button.pressed.emit()
	await frames(3)
	check(pause.options_panel.visible and not pause.buttons.visible, "Opciones dentro de la pausa")
	await shot("02_pausa_opciones")
	await send_action("pause")
	check(not pause.options_panel.visible and pause.visible, "Esc cierra solo las opciones")
	await send_action("pause")
	check(not pause.visible and not paused, "Esc de nuevo vuelve al juego")

	print("-- Guardar")
	var crowbar: Resource = load("res://assets/items/weapon_crowbar.tres")
	var pistol: Resource = load("res://assets/items/weapon_pistol.tres")
	var peaches: Resource = load("res://assets/items/food_canned_peaches.tres")
	var letter: Resource = load("res://assets/items/letter_marta_01.tres")
	inventory.add(crowbar)
	inventory.add(pistol)
	inventory.add(peaches)
	inventory.add(letter)
	inventory.use(letter)
	var pistol_entry: Dictionary = inventory.entries[1]
	pistol_entry.loaded = 3
	inventory.equip(pistol_entry)
	# Ya visto antes de guardar: así, al cargar, verlo de nuevo no cambia la locura.
	sanity.register_sighting(&"delgado", 0.0)
	sanity._set_current(55.0)
	game_state.set_flag(&"hospital_exit_forced")
	shelter.stock[&"material_wood"] = 4
	shelter.levels[&"fire"] = 1
	shelter.stash.append({"item": peaches, "count": 2, "loaded": 0})
	# Recoger un chocolate del mundo.
	current_scene.get_node("Items/Chocolate1").interact(player())
	player().global_position = Vector3(20.0, 0.05, 9.5)
	player().visual.global_rotation.y = 1.0
	await frames(5)
	await send_action("pause")
	pause.save_button.pressed.emit()
	await frames(3)
	check(pause.result_label.text == "Partida guardada." and FileAccess.file_exists(SAVE), "Guardar partida escribe el archivo")
	await shot("03_guardada")
	await send_action("pause")

	print("-- Cambiar todo y cargar")
	inventory.clear()
	sanity._set_current(90.0)
	game_state.flags.clear()
	shelter.new_game()
	player().global_position = Vector3(30.0, 0.05, 3.6)
	check(save_game.load_game(), "load_game lee la partida")
	await settle()
	check(current_scene.name == "Hospital", "vuelve a la escena guardada")
	check(player().global_position.distance_to(Vector3(20.0, 0.05, 9.5)) < 0.3, "y a la posición: %s" % player().global_position)
	check(is_equal_approx(player().visual.global_rotation.y, 1.0), "y a la orientación")
	check(inventory.entries.size() == 4 and inventory.letters.size() == 1, "vuelve la mochila (4, con el chocolate) y la carta")
	check(inventory.equipped_item() == pistol and inventory.equipped.loaded == 3, "vuelve la pistola en la mano con 3 balas")
	check(inventory.times_used(letter) == 1, "la carta ya leída sigue leída")
	check(is_equal_approx(sanity.maximum, 110.0), "cordura máxima con la carta: %.0f" % sanity.maximum)
	# Lo guardado (la locura sigue subiendo mientras carga la escena, así que se mira el archivo).
	var saved_sanity: float = save_game.read().get("sanity", {}).get("current", -1.0)
	check(absf(saved_sanity - 55.0) < 1.0 and sanity.current <= saved_sanity, "cordura guardada: %.1f (ahora %.1f)" % [saved_sanity, sanity.current])
	check(game_state.has_flag(&"hospital_exit_forced"), "vuelven los hechos del mundo")
	check(shelter.stock[&"material_wood"] == 4 and shelter.level(&"fire") == 1, "vuelve el refugio")
	check(shelter.stash.size() == 1 and shelter.stash[0].item == peaches and shelter.stash[0].count == 2, "vuelve el alijo")
	check(not current_scene.has_node("Items/Chocolate1"), "lo recogido no reaparece")

	print("-- Guardado automático al cambiar de zona")
	current_scene.get_node("Inspectables/EmergencyExit").interact(player())
	await settle()
	check(current_scene.name == "Street", "sale a la calle")
	var data: Dictionary = save_game.read()
	check(data.get("scene", "") == "res://scenes/levels/street.tscn", "se guardó solo en la calle")

	print("-- Menú principal desde la pausa")
	await send_action("pause")
	pause = current_scene.get_node("GameUI/PauseMenu")
	pause.menu_button.pressed.emit()
	await create_timer(1.5).timeout
	await frames(10)
	check(current_scene.name == "MainMenu" and not paused, "vuelve al menú de inicio")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("RESULT: %d fallas" % fails)
	quit()
