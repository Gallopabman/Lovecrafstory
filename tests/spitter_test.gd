extends SceneTree
## El Escupidor: ve al jugador de lejos, le escupe (proyectil visible), la escupida lastima
## y deja una mancha si pega en la pared; si el jugador se acerca, retrocede; y muere.
## Capturas en user://test_shots/spitter/.
## Uso: <godot> --path . -s res://tests/spitter_test.gd

const OUT := "user://test_shots/spitter/"

var fails := 0


func check(cond: bool, msg: String) -> void:
	print(("OK   " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func shot(name: String) -> void:
	await frames(6)
	root.get_texture().get_image().save_png(OUT + "%s.png" % name)


func player() -> Node3D:
	return current_scene.get_node("Player")


func place(pos: Vector3, yaw_deg: float, pitch_deg := -5.0) -> void:
	var p := player()
	var yaw := deg_to_rad(yaw_deg)
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.set("_yaw", yaw)
	p.set("_pitch", deg_to_rad(pitch_deg))
	p.camera_pivot.global_position = pos + Vector3.UP * p.camera_height
	p.visual.global_rotation.y = yaw


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for action in InputMap.get_actions():
		InputMap.action_erase_events(action)
	root.get_node("SaveGame").path = "user://test_save.dat"
	root.get_node("SaveGame").new_game()
	change_scene_to_file("res://scenes/levels/street.tscn")
	await frames(90)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player().set_process_unhandled_input(false)
	player().get_node("Combat").set_process_unhandled_input(false)
	for enemy in get_nodes_in_group(&"enemies"):
		enemy.set_physics_process(false)
	var health: Node = root.get_node("Health")

	print("-- Escupe")
	place(Vector3(14.0, 0.05, 0.0), -90.0)
	var spitter: Node3D = load("res://scenes/enemies/spitter.tscn").instantiate()
	current_scene.add_child(spitter)
	spitter.global_position = Vector3(24.0, 0.05, 0.0)
	spitter.visual.global_rotation.y = -PI / 2
	await frames(10)
	var before: float = health.current
	var saw_spit := false
	var spit_script: Script = load("res://scripts/enemies/spit_projectile.gd")
	for i in 300:
		await physics_frame
		if not saw_spit:
			for n in current_scene.get_children():
				if n.get_script() == spit_script:
					saw_spit = true
					await shot("01_escupida")
					break
		if health.current < before:
			break
	check(saw_spit, "escupe un proyectil")
	check(health.current < before, "la escupida lastima: vida %.0f -> %.0f" % [before, health.current])
	check(spitter.global_position.distance_to(player().global_position) > 4.0, "no se acerca: se queda a distancia")

	print("-- Se esquiva")
	health.heal(100.0)
	before = health.current
	place(Vector3(14.0, 0.05, 0.0), -90.0)
	# Si el jugador se mueve de costado, la escupida le pasa al lado y mancha la pared.
	Input.action_press("move_left")
	for i in 150:
		await physics_frame
	Input.action_release("move_left")
	check(health.current >= before - 10.0, "moviéndose de costado se esquiva casi todo: %.0f" % health.current)

	print("-- Retrocede")
	place(Vector3(spitter.global_position.x - 3.0, 0.05, spitter.global_position.z), -90.0)
	var start_x: float = spitter.global_position.x
	for i in 60:
		await physics_frame
	check(spitter.global_position.x > start_x + 0.3 or spitter.state == 2, "si te acercás, retrocede (o pega): x %.2f -> %.2f" % [start_x, spitter.global_position.x])
	await shot("02_retrocede")

	print("-- Muere")
	spitter.take_damage(500.0)
	await create_timer(1.5).timeout
	check(spitter.is_dead(), "muere")
	await shot("03_muerto")

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.dat"))
	print("RESULT: %d fallas" % fails)
	quit()
