extends SceneTree
## El sótano del San Judas: la llave está en la casa de Ferreyra (avenida), abre la puerta
## del sótano en PB, el sótano se recorre entero, el jefe del incinerador despierta, muere
## y destraba la sala de guardia. Capturas en user://test_shots/basement/.
## Uso: <godot> --path . -s res://tests/basement_test.gd

const OUT := "user://test_shots/basement/"

var fails := 0
var sanity: Node
var inventory: Node
var game_state: Node


func check(cond: bool, msg: String) -> void:
	print(("OK   " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func shot(name: String) -> void:
	await frames(12)
	root.get_texture().get_image().save_png(OUT + "%s.png" % name)


func player() -> Node3D:
	return current_scene.get_node("Player")


## yaw 0 = mirando al norte (-Z), -90 = al este (+X), 90 = al oeste, 180 = al sur.
func place(pos: Vector3, yaw_deg: float, pitch_deg := -10.0) -> void:
	var p := player()
	var yaw := deg_to_rad(yaw_deg)
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.set("_yaw", yaw)
	p.set("_pitch", deg_to_rad(pitch_deg))
	p.camera_pivot.global_position = pos + Vector3.UP * p.camera_height
	p.visual.global_rotation.y = yaw


func walk(action: String, steps: int) -> void:
	Input.action_press(action)
	for i in steps:
		await physics_frame
	Input.action_release(action)


func settle() -> void:
	await frames(90)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player().set_process_unhandled_input(false)
	player().get_node("Combat").set_process_unhandled_input(false)
	for enemy in get_nodes_in_group(&"enemies"):
		enemy.set_physics_process(false)


func has_item(id: StringName) -> bool:
	for e: Dictionary in inventory.entries:
		if e.item.id == id:
			return true
	return false


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for action in InputMap.get_actions():
		InputMap.action_erase_events(action)
	root.get_node("SaveGame").path = "user://test_save.dat"
	sanity = root.get_node("Sanity")
	inventory = root.get_node("Inventory")
	game_state = root.get_node("GameState")
	root.get_node("SaveGame").new_game()
	change_scene_to_file("res://scenes/levels/street.tscn")
	await settle()

	print("-- La casa de Ferreyra")
	current_scene.get_node("Inspectables/Door_ferreyra").interact(player())
	await settle()
	check(current_scene.name == "HouseFerreyra", "la puerta de la avenida lleva a la casa de Ferreyra")
	for s: Array in [["01_ferreyra_living", Vector3(-2.5, 0.05, -1.0), -40.0], ["02_ferreyra_escritorio", Vector3(-1.0, 0.05, -5.2), 140.0],
			["03_ferreyra_dormitorio", Vector3(1.0, 0.05, -5.2), -140.0]]:
		place(s[1], s[2])
		await shot(s[0])
	current_scene.get_node("Items/KeyBasement").interact(player())
	current_scene.get_node("Items/LetterFerreyra2").interact(player())
	await frames(3)
	check(has_item(&"key_basement"), "la llave del sótano estaba en el saco")
	check(inventory.letters.any(func(l: Resource) -> bool: return l.id == &"letter_ferreyra_02"), "y el diario de Ferreyra")
	current_scene.get_node("Inspectables/StreetDoor").interact(player())
	await settle()
	check(current_scene.name == "Street", "se vuelve a la avenida")

	print("-- La puerta del sótano")
	change_scene_to_file("res://scenes/levels/hospital.tscn")
	await settle()
	place(Vector3(4.6, 0.05, 4.0), -90.0)
	await frames(3)
	current_scene.get_node("Inspectables/BasementDoor").interact(player())
	await settle()
	check(current_scene.name == "HospitalBasement", "con la llave se baja al sótano")
	check(game_state.has_flag(&"hospital_basement_open"), "la puerta queda abierta")
	check(player().global_position.distance_to(Vector3(3.0, 0, 7.6)) < 0.5, "aparece al pie de la escalera: %s" % player().global_position)
	var boss: Node3D = current_scene.get_node("Enemies/BasementBoss")
	check(boss.dormant and not boss.visual.visible, "algo duerme en el incinerador")
	check(get_nodes_in_group(&"enemies").size() >= 8, "acechadores en el sótano: %d" % get_nodes_in_group(&"enemies").size())

	print("-- Navegación")
	await physics_frame
	var map: RID = player().get_world_3d().navigation_map
	for target: Vector3 in [Vector3(45.0, 0, 20.0), Vector3(8.0, 0, 37.0), Vector3(6.5, 0, 27.0), Vector3(50.0, 0, 3.0)]:
		var path := NavigationServer3D.map_get_path(map, Vector3(3.0, 0, 7.6), target, true)
		check(path.size() > 1 and path[path.size() - 1].distance_to(target) < 1.0, "se llega a %s: %d puntos, fin %s" % [target, path.size(), path[path.size() - 1] if path.size() > 0 else Vector3.ZERO])

	print("-- Recorrido")
	player().flashlight.visible = true
	for s: Array in [["04_escalera", Vector3(3.0, 0.05, 8.0), 0.0], ["05_pasillo", Vector3(2.0, 0.05, 7.5), -90.0],
			["06_calderas", Vector3(13.0, 0.05, 5.4), 10.0], ["07_lavanderia", Vector3(26.0, 0.05, 5.4), -20.0],
			["08_maquinas", Vector3(38.0, 0.05, 5.4), 0.0], ["09_deposito", Vector3(50.0, 0.05, 5.4), 20.0],
			["10_morgue", Vector3(6.5, 0.05, 10.0), 150.0], ["11_patologia", Vector3(19.5, 0.05, 10.0), 170.0],
			["12_archivo", Vector3(6.5, 0.05, 30.0), 20.0], ["13_capilla", Vector3(19.5, 0.05, 23.0), 180.0],
			["14_residuos", Vector3(32.5, 0.05, 10.0), 180.0], ["15_pasillo_sur", Vector3(2.0, 0.05, 32.5), -90.0],
			["16_frigorifico", Vector3(23.0, 0.05, 34.6), 180.0], ["17_taller", Vector3(38.0, 0.05, 34.6), 180.0]]:
		place(s[1], s[2])
		await shot(s[0])

	print("-- El jefe")
	var gate: Node3D = current_scene.get_node("Structure/GuardGate")
	check(not gate.is_open(), "la sala de guardia está trabada")
	place(Vector3(35.0, 0.05, 20.0), -90.0)
	await walk("move_forward", 60)
	await frames(10)
	check(not boss.dormant and boss.visual.visible, "al entrar al incinerador, despierta")
	boss.set_physics_process(false)
	await create_timer(1.2).timeout
	place(Vector3(42.0, 0.05, 21.0), -100.0)
	await create_timer(0.6).timeout
	await shot("18_el_del_sotano")
	sanity._set_current(sanity.maximum * 0.5)
	var before: float = sanity.current
	boss.take_damage(boss.max_health * 2.0)
	await frames(3)
	check(boss.is_dead() and game_state.has_flag(&"basement_boss_dead"), "muere y deja la marca")
	check(sanity.current > before + 20.0, "matarlo devuelve mucha cordura")
	check(gate.is_open(), "la puerta de la sala de guardia se destraba")
	await create_timer(1.5).timeout
	await shot("19_derrotado")
	place(Vector3(51.0, 0.05, 29.0), 180.0)
	await walk("move_forward", 120)
	check(player().global_position.z > 31.5, "se entra a la sala de guardia: z=%.2f" % player().global_position.z)
	place(Vector3(51.0, 0.05, 33.0), 180.0)
	await shot("20_sala_de_guardia")

	print("-- Secretos")
	sanity._set_current(sanity.maximum * 0.3)
	await frames(5)
	check(current_scene.get_node("Secrets/ChapelFigure").visible, "Quebrado: alguien reza en la capilla")
	place(Vector3(10.0, 0.05, 14.0), -90.0)
	await shot("21_morgue_nombres")
	sanity._set_current(sanity.maximum)

	print("-- Vuelta al hospital")
	place(Vector3(3.0, 0.05, 6.0), 0.0)
	await frames(3)
	current_scene.get_node("Inspectables/HospitalDoor").interact(player())
	await settle()
	check(current_scene.name == "Hospital", "la escalera vuelve al hospital")
	check(player().global_position.distance_to(Vector3(4.2, 0, 3.0)) < 0.5, "junto a la puerta del sótano: %s" % player().global_position)
	await shot("22_vuelta")

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.dat"))
	print("RESULT: %d fallas" % fails)
	quit()
