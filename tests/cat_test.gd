extends SceneTree
## Teodoro: la nota de la veterinaria en casa, la Veterinaria San Roque (en Rondeau, en el
## barrio), el rescate de la jaula, el gato en el refugio y las caricias.
## Capturas en user://test_shots/cat/.
## Uso: <godot> --path . -s res://tests/cat_test.gd

const OUT := "user://test_shots/cat/"

var fails := 0
var sanity: Node
var game_state: Node
var shelter: Node


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
func place(pos: Vector3, yaw_deg: float, pitch_deg := -12.0) -> void:
	var p := player()
	var yaw := deg_to_rad(yaw_deg)
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.set("_yaw", yaw)
	p.set("_pitch", deg_to_rad(pitch_deg))
	p.camera_pivot.global_position = pos + Vector3.UP * p.camera_height
	p.visual.global_rotation.y = yaw


func settle() -> void:
	await frames(90)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player().set_process_unhandled_input(false)
	player().get_node("Combat").set_process_unhandled_input(false)
	for enemy in get_nodes_in_group(&"enemies"):
		enemy.set_physics_process(false)


func message() -> String:
	return current_scene.get_node("GameUI").pickup_label.text


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for action in InputMap.get_actions():
		InputMap.action_erase_events(action)
	root.get_node("SaveGame").path = "user://test_save.dat"
	sanity = root.get_node("Sanity")
	game_state = root.get_node("GameState")
	shelter = root.get_node("Shelter")
	root.get_node("SaveGame").new_game()
	change_scene_to_file("res://scenes/levels/home.tscn")
	await settle()

	print("-- La nota")
	check(current_scene.has_node("Items/LetterVet"), "en casa está la nota de la veterinaria")
	var home_cat: Node3D = current_scene.get_node("Props/Teodoro")
	check(not home_cat.visible, "Teodoro todavía no está en casa")
	place(Vector3(9.2, 0.05, 5.4), 0.0, -30.0)
	await shot("01_nota")
	current_scene.get_node("Items/LetterVet").interact(player())
	await frames(3)
	var inventory: Node = root.get_node("Inventory")
	check(inventory.letters.any(func(l: Resource) -> bool: return l.id == &"letter_vet_01"), "la nota se guarda con las cartas")

	print("-- La veterinaria")
	change_scene_to_file("res://scenes/levels/park_street.tscn")
	await settle()
	var door: Node3D = current_scene.get_node("Inspectables/Door_veterinaria")
	place(door.global_position * Vector3(1, 0, 1) + Vector3(0, 0.05, 2.6), 0.0, -5.0)
	await shot("02_frente")
	door.interact(player())
	await settle()
	check(current_scene.name == "HouseVeterinaria", "la puerta de Rondeau lleva a la veterinaria")
	for s: Array in [["03_sala_de_espera", Vector3(0.0, 0.05, -1.0), 20.0], ["04_consultorio", Vector3(-4.0, 0.05, -6.0), 10.0],
			["05_internacion", Vector3(2.0, 0.05, -8.5), 0.0]]:
		place(s[1], s[2])
		await shot(s[0])
	# Se llega caminando de la sala de espera a la internación (antes una silla tapaba la puerta).
	place(Vector3(3.0, 0.05, -1.5), 0.0, -10.0)
	Input.action_press("move_forward")
	for i in 180:
		await physics_frame
	Input.action_release("move_forward")
	check(player().global_position.z < -6.0, "se entra caminando a la internación: z=%.2f" % player().global_position.z)
	var nav_map: RID = player().get_world_3d().navigation_map
	var nav_path := NavigationServer3D.map_get_path(nav_map, Vector3(0, 0, -1.5), Vector3(2.1, 0, -9.5), true)
	check(nav_path.size() > 1 and nav_path[nav_path.size() - 1].distance_to(Vector3(2.1, 0, -9.5)) < 1.0, "y los enemigos también")
	var caged: Node3D = current_scene.get_node("Props/Teodoro")
	check(caged.visible, "Teodoro está en su jaula")
	place(Vector3(2.1, 0.05, -9.6), 0.0, -25.0)
	player().visual.visible = false
	await shot("06_teodoro_jaula")
	player().visual.visible = true
	sanity._set_current(sanity.maximum * 0.5)
	var before: float = sanity.current
	caged.interact(player())
	await frames(3)
	check(game_state.has_flag(&"cat_rescued"), "se rescata a Teodoro")
	check(not caged.visible, "la jaula queda vacía")
	check(sanity.current > before, "rescatarlo calma: %.0f -> %.0f" % [before, sanity.current])
	current_scene.get_node("Inspectables/StreetDoor").interact(player())
	await settle()
	var back: Node3D = current_scene.get_node("SpawnHouse_veterinaria")
	check(current_scene.name == "ParkStreet" and player().global_position.distance_to(back.global_position) < 0.5,
		"se vuelve a Rondeau, frente a la veterinaria")

	print("-- En casa")
	var plain: float = shelter.recovery_multiplier()
	game_state.flags.erase(&"cat_rescued")
	var without: float = shelter.recovery_multiplier()
	game_state.set_flag(&"cat_rescued")
	check(plain > without, "con Teodoro, el refugio calma más rápido: x%.2f -> x%.2f" % [without, plain])
	change_scene_to_file("res://scenes/levels/home.tscn")
	await settle()
	home_cat = current_scene.get_node("Props/Teodoro")
	check(home_cat.visible, "Teodoro está en casa")
	place(home_cat.global_position + Vector3(0.0, 0.05, 1.6), 0.0, -30.0)
	player().visual.visible = false
	await shot("07_teodoro_en_casa")
	player().visual.visible = true
	sanity._set_current(sanity.maximum * 0.5)
	before = sanity.current
	home_cat.interact(player())
	await frames(3)
	check(sanity.current >= before + 7.0, "acariciarlo baja la locura: %.0f -> %.0f" % [before, sanity.current])
	var after_pet: float = sanity.current
	home_cat.interact(player())
	await frames(3)
	check(sanity.current < after_pet + 1.0, "no se lo puede acariciar sin parar")
	check(message().length() > 0, "Teodoro responde: \"%s\"" % message())

	print("-- Otros refugios")
	shelter.move_to(&"hospital")
	change_scene_to_file("res://scenes/levels/hospital.tscn")
	await settle()
	check(current_scene.get_node("Props/Teodoro").visible, "si te mudás al hospital, Teodoro viene con vos")
	change_scene_to_file("res://scenes/levels/home.tscn")
	await settle()
	check(not current_scene.get_node("Props/Teodoro").visible, "y ya no está en casa")

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.dat"))
	print("RESULT: %d fallas" % fails)
	quit()
