extends SceneTree
## Menú de inicio: foco en Jugar, opciones con el volumen (se guarda en
## user://settings.cfg), Jugar lleva al hospital, y con partida guardada aparece
## "Continuar". Capturas en user://test_shots/menu/.
## Uso: <godot> --path . -s res://tests/main_menu_test.gd

const OUT := "user://test_shots/menu/"
const SAVE := "user://test_save.dat"

var fails := 0


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


func open_menu() -> Node:
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await frames(20)
	await create_timer(1.5).timeout
	return current_scene


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for action in InputMap.get_actions():
		InputMap.action_erase_events(action)
	# Los tests guardan en otro archivo para no pisar la partida del jugador.
	root.get_node("SaveGame").path = SAVE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var audio := root.get_node("Audio")
	var previous_volume: float = audio.master_volume

	print("-- Sin partida guardada")
	var menu := await open_menu()
	check(menu.name == "MainMenu", "arranca en el menú de inicio")
	check(not menu.continue_button.visible, "sin partida no hay Continuar")
	check(menu.play_button.has_focus(), "el foco empieza en Jugar")
	check(not menu.options_panel.visible, "opciones ocultas")
	await shot("01_inicio")

	print("-- Opciones")
	menu.options_button.pressed.emit()
	await frames(3)
	var options: Node = menu.options_panel
	check(options.visible and not menu.main_panel.visible, "Opciones abre el panel")
	check(options.volume_slider.has_focus(), "el foco va al volumen")
	options.volume_slider.value = 35.0
	await frames(2)
	check(is_equal_approx(audio.master_volume, 0.35), "el volumen cambia el bus Master: %.2f" % audio.master_volume)
	check(options.volume_value.text == "35%", "muestra el porcentaje")
	await shot("02_opciones")
	options.back_button.pressed.emit()
	await frames(3)
	var config := ConfigFile.new()
	config.load("user://settings.cfg")
	check(is_equal_approx(config.get_value("audio", "master_volume", -1.0), 0.35), "el volumen se guarda")
	check(menu.main_panel.visible, "Volver regresa al menú")
	audio.set_master_volume(previous_volume)
	audio.save_settings()

	print("-- Jugar")
	menu.play_button.pressed.emit()
	await create_timer(2.0).timeout
	await frames(30)
	check(current_scene.name == "Home", "Jugar arranca en casa")
	check(root.get_node("GameState").survivor_number == 1, "partida nueva: sobreviviente #1")
	check(FileAccess.file_exists(SAVE), "al arrancar en casa (el refugio) se guarda solo")

	print("-- Continuar")
	menu = await open_menu()
	check(menu.continue_button.visible and menu.continue_button.has_focus(), "con partida aparece Continuar, con el foco")
	check(menu.save_label.text.begins_with("Sobreviviente #1"), "resumen de la partida: %s" % menu.save_label.text)
	await shot("03_continuar")
	menu.continue_button.pressed.emit()
	await create_timer(2.5).timeout
	await frames(30)
	check(current_scene.name == "Home", "Continuar carga la partida (en casa)")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("RESULT: %d fallas" % fails)
	quit()
