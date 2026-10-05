extends SceneTree
## Recorrido del hospital: carga, refugio, escalera, navegación entre pisos,
## límites (rejas, puertas) y una captura por ambiente en user://test_shots/hospital/.
## Uso: <godot> --path . -s res://tests/hospital_tour_test.gd
## No usar class_name del juego acá (compila antes que los autoloads).

const OUT := "user://test_shots/hospital/"
const H := 3.5

var fails := 0


func check(cond: bool, msg: String) -> void:
	print(("OK   " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func player() -> Node3D:
	return current_scene.get_node("Player")


func place(pos: Vector3, yaw_deg: float, pitch_deg := -12.0) -> void:
	var p := player()
	var yaw := deg_to_rad(yaw_deg)
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.set("_yaw", yaw)
	p.set("_pitch", deg_to_rad(pitch_deg))
	p.camera_pivot.global_position = pos + Vector3.UP * p.camera_height
	p.visual.global_rotation.y = yaw


func shot(name: String) -> void:
	await frames(12)
	root.get_texture().get_image().save_png(OUT + "%s.png" % name)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	# Aislar de los dispositivos reales (gamepad conectado, teclado, mouse): el test solo
	# usa Input.action_press / InputEventAction, que no dependen de los bindings.
	for action in InputMap.get_actions():
		InputMap.action_erase_events(action)
	# Los tests guardan en otro archivo para no pisar la partida del jugador.
	root.get_node("SaveGame").path = "user://test_save.dat"
	var sanity := root.get_node("Sanity")
	# El refugio del hospital (el inicial ahora es la casa).
	root.get_node("Shelter").move_to(&"hospital")
	change_scene_to_file("res://scenes/levels/hospital.tscn")
	await frames(90)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player().set_process_unhandled_input(false)
	player().get_node("Combat").set_process_unhandled_input(false)
	for enemy in get_nodes_in_group(&"enemies"):
		enemy.set_physics_process(false)

	print("-- Carga")
	check(current_scene.name == "Hospital", "escena del hospital cargada")
	check(sanity.in_refuge() and not sanity.has_electricity(), "arranca en el refugio, sin electricidad (el generador empieza roto)")
	var props := current_scene.get_node("Props").get_child_count()
	check(props > 150, "mobiliario: %d props" % props)
	check(get_nodes_in_group(&"enemies").size() == 5, "5 acechadores (3 abajo, 2 en el 2° piso)")

	print("-- Navegación")
	await physics_frame
	var map: RID = player().get_world_3d().navigation_map
	var path := NavigationServer3D.map_get_path(map, Vector3(15.5, 0, 16.5), Vector3(16.5, H, 5.0), true)
	check(path.size() > 2 and path[path.size() - 1].distance_to(Vector3(16.5, H, 5.0)) < 1.0,
		"hay camino del hall (PB) a internación (P1): %d puntos, fin %s" % [path.size(), path[path.size() - 1] if path.size() > 0 else Vector3.ZERO])

	print("-- Escalera")
	place(Vector3(1.5, 0.05, 8.8), 0.0)
	await frames(5)
	var max_y := 0.0
	Input.action_press("move_forward")
	for i in 260:
		await physics_frame
		max_y = maxf(max_y, player().global_position.y)
	Input.action_release("move_forward")
	check(max_y > H - 0.3, "se sube la escalera caminando: y=%.2f" % max_y)
	# Segundo tramo: del pasillo de P1 (puerta del ex ascensor) al 2° piso.
	place(Vector3(7.5, H + 0.05, 9.0), 0.0)
	await frames(5)
	max_y = 0.0
	Input.action_press("move_forward")
	for i in 260:
		await physics_frame
		max_y = maxf(max_y, player().global_position.y)
	Input.action_release("move_forward")
	check(max_y > 2 * H - 0.3, "se sube al 2° piso: y=%.2f" % max_y)
	path = NavigationServer3D.map_get_path(map, Vector3(15.5, 0, 16.5), Vector3(22.2, 2 * H, 7.0), true)
	check(path.size() > 2 and path[path.size() - 1].distance_to(Vector3(22.2, 2 * H, 7.0)) < 1.0,
		"hay camino del hall a la terapia grupal (2° piso): %d puntos, fin %s" % [path.size(), path[path.size() - 1] if path.size() > 0 else Vector3.ZERO])

	print("-- Sótano")
	var basement: Node = current_scene.get_node("Inspectables/BasementDoor")
	place(Vector3(4.6, 0.05, 4.0), -90.0)
	await frames(3)
	basement.interact(player())
	await frames(3)
	check(current_scene.name == "Hospital", "sin la llave de Ferreyra el sótano no abre")
	await shot("20_puerta_sotano")

	print("-- Límites")
	# Contra las rejas de una ventana del hall: no se sale del edificio.
	place(Vector3(21.0, 0.05, 18.8), 180.0)
	Input.action_press("move_forward")
	for i in 120:
		await physics_frame
	Input.action_release("move_forward")
	check(player().global_position.z < 19.9, "las rejas frenan: z=%.2f" % player().global_position.z)
	# Contra la entrada principal.
	place(Vector3(15.5, 0.05, 17.8), 180.0)
	Input.action_press("move_forward")
	for i in 120:
		await physics_frame
	Input.action_release("move_forward")
	check(player().global_position.z < 19.9, "la entrada principal está cerrada: z=%.2f" % player().global_position.z)

	print("-- Capturas")
	player().flashlight.visible = true
	var shots := [
		["01_refugio", Vector3(27.0, 0.05, 6.6), -55.0],
		["02_refugio_cocina", Vector3(29.0, 0.05, 3.0), -100.0],
		["03_pasillo_pb", Vector3(1.5, 0.05, 9.5), -90.0],
		["04_hall", Vector3(22.5, 0.05, 12.4), 135.0],
		["05_recepcion", Vector3(14.0, 0.05, 17.5), 30.0],
		["06_farmacia", Vector3(16.2, 0.05, 7.2), 45.0],
		["07_consultorio", Vector3(24.0, 0.05, 7.2), 50.0],
		["08_seguridad", Vector3(5.8, 0.05, 12.4), 150.0],
		["09_banos", Vector3(30.8, 0.05, 11.8), -150.0],
		["10_escalera", Vector3(4.6, 0.05, 7.3), 40.0],
		["11_internacion", Vector3(23.2, H + 0.05, 7.2), 70.0],
		["12_quirofano", Vector3(25.0, H + 0.05, 7.2), -55.0],
		["13_direccion", Vector3(5.8, H + 0.05, 12.2), 150.0],
		["14_enfermeria", Vector3(15.5, H + 0.05, 10.0), 160.0],
		["15_deposito", Vector3(19.0, H + 0.05, 12.2), -150.0],
		["16_archivo", Vector3(26.8, H + 0.05, 12.2), -130.0],
		["17_pasillo_p1", Vector3(34.5, H + 0.05, 9.5), 90.0],
		["18_escalera_p1", Vector3(5.0, H + 0.05, 1.2), 120.0],
		["21_p2_pasillo", Vector3(1.5, 2 * H + 0.05, 9.5), -90.0],
		["22_p2_habitacion_203", Vector3(16.5, 2 * H + 0.05, 7.0), 10.0],
		["23_p2_aislamiento", Vector3(19.5, 2 * H + 0.05, 6.8), 0.0],
		["24_p2_terapia", Vector3(25.6, 2 * H + 0.05, 7.2), 30.0],
		["25_p2_sala_de_dia", Vector3(28.0, 2 * H + 0.05, 7.2), -50.0],
		["26_p2_psiquiatria", Vector3(5.8, 2 * H + 0.05, 12.2), 150.0],
		["27_p2_enfermeria", Vector3(9.0, 2 * H + 0.05, 12.2), -150.0],
		["28_p2_duchas", Vector3(27.5, 2 * H + 0.05, 12.2), -130.0],
		["29_p2_escalera", Vector3(3.0, 2 * H + 0.05, 2.0), -60.0],
	]
	for s: Array in shots:
		place(s[1], s[2])
		await shot(s[0])
	# El secreto: con cordura baja aparece el cuarto tapiado.
	sanity._set_current(sanity.maximum * 0.3)
	await frames(10)
	place(Vector3(31.0, H + 0.05, 15.5), -90.0)
	await create_timer(2.0).timeout
	await shot("19_cuarto_tapiado")
	check(not current_scene.get_node("Secrets/LyingWall").visible, "Quebrado: la pared del archivo desaparece")

	print("RESULT: %d fallas" % fails)
	quit()
