extends SceneTree
## Menú de inicio: foco en Jugar, opciones con el volumen (se guarda en
## user://settings.cfg) y Jugar lleva al hospital. Capturas en user://test_shots/menu/.
## Uso: <godot> --path . -s res://tests/main_menu_test.gd

const OUT := "user://test_shots/menu/"

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


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for action in InputMap.get_actions():
		InputMap.action_erase_events(action)
	var audio := root.get_node("Audio")
	var previous_volume: float = audio.master_volume
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await frames(20)
	await create_timer(1.5).timeout
	var menu := current_scene
	check(menu.name == "MainMenu", "arranca en el menú de inicio")
	check(menu.play_button.has_focus(), "el foco empieza en Jugar")
	check(not menu.options_panel.visible, "opciones ocultas")
	await shot("01_inicio")

	menu.options_button.pressed.emit()
	await frames(3)
	check(menu.options_panel.visible and not menu.main_panel.visible, "Opciones abre el panel")
	check(menu.volume_slider.has_focus(), "el foco va al volumen")
	menu.volume_slider.value = 35.0
	await frames(2)
	check(is_equal_approx(audio.master_volume, 0.35), "el volumen cambia el bus Master: %.2f" % audio.master_volume)
	check(menu.volume_value.text == "35%", "muestra el porcentaje")
	await shot("02_opciones")
	menu.back_button.pressed.emit()
	await frames(3)
	var config := ConfigFile.new()
	config.load("user://settings.cfg")
	check(is_equal_approx(config.get_value("audio", "master_volume", -1.0), 0.35), "el volumen se guarda")
	check(menu.main_panel.visible, "Volver regresa al menú")
	# Dejar el volumen como estaba.
	audio.set_master_volume(previous_volume)
	audio.save_settings()

	menu.play_button.pressed.emit()
	await create_timer(2.0).timeout
	await frames(30)
	check(current_scene.name == "Hospital", "Jugar carga el hospital")
	check(root.get_node("GameState").survivor_number == 1, "partida nueva: sobreviviente #1")

	print("RESULT: %d fallas" % fails)
	quit()
