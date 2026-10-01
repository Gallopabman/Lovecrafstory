extends SceneTree
## El comienzo: la casa (refugio inicial), el ático cerrado, la calle de la plaza
## (rejas y calle cortada) y la puerta de guardia del hospital.
## Capturas en user://test_shots/home/.
## Uso: <godot> --path . -s res://tests/home_test.gd

const OUT := "user://test_shots/home/"
const AF := 2.9

var fails := 0
var sanity: Node
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


func message() -> String:
	return current_scene.get_node("GameUI").pickup_label.text


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for action in InputMap.get_actions():
		InputMap.action_erase_events(action)
	root.get_node("SaveGame").path = "user://test_save.dat"
	sanity = root.get_node("Sanity")
	shelter = root.get_node("Shelter")
	root.get_node("SaveGame").new_game()
	change_scene_to_file("res://scenes/levels/home.tscn")
	await settle()

	print("-- Casa")
	check(current_scene.name == "Home", "se empieza en casa")
	check(shelter.active == &"home" and sanity.in_refuge(), "la casa es el refugio activo")
	check(current_scene.has_node("Items/LetterMother"), "la nota de mamá está en la mesa")
	for s: Array in [["01_pieza", Vector3(2.6, 0.05, 3.4), 0.0], ["02_living", Vector3(5.5, 0.05, 9.0), 40.0],
			["03_cocina", Vector3(8.6, 0.05, 8.8), -40.0], ["04_escalera", Vector3(11.0, 0.05, 6.5), 10.0]]:
		place(s[1], s[2])
		await shot(s[0])

	print("-- Ático")
	var gate: Node = current_scene.get_node("Structure/AtticGate")
	place(Vector3(8.2, AF + 0.05, 1.0), 90.0)
	await frames(5)
	player()._try_interact()
	await frames(3)
	check(message().begins_with("No puedo entrar ahí. Mi madre se llevó la llave"), "mensaje del ático: '%s'" % message())
	check(not gate.is_open(), "la puerta del ático no se abre")
	place(Vector3(8.4, AF + 0.05, 1.0), 90.0)
	await walk("move_forward", 80)
	check(player().global_position.x > 7.6, "no se pasa por la puerta del ático: x=%.2f" % player().global_position.x)
	await shot("05_puerta_atico")
	var thing: Node3D = current_scene.get_node("Enemies/AtticThing")
	check(thing.dormant, "algo duerme en el ático")
	# Una mirada adentro (solo para la captura).
	thing.awaken()
	thing.set_physics_process(false)
	place(Vector3(1.4, AF + 0.05, 1.3), -142.0, -12.0)
	await create_timer(1.4).timeout
	await shot("06_atico")

	print("-- La calle de la plaza")
	place(Vector3(3.5, 0.05, 8.8), 180.0)
	await frames(5)
	current_scene.get_node("Inspectables/StreetDoor").interact(player())
	await settle()
	check(current_scene.name == "ParkStreet", "al salir de casa, la calle de la plaza")
	check(player().global_position.distance_to(Vector3(5.5, 0, -4.6)) < 0.5, "frente a la puerta de casa")
	await shot("07_salida")
	for s: Array in [["08_plaza", Vector3(20.0, 0.05, 3.5), 180.0], ["09_calle_este", Vector3(10.0, 0.05, 0.0), -90.0],
			["10_casa", Vector3(8.0, 0.05, 4.5), 20.0], ["11_hospital", Vector3(50.0, 0.05, 1.0), -90.0],
			["12_camion", Vector3(10.0, 0.05, 1.0), 90.0]]:
		place(s[1], s[2])
		await shot(s[0])

	print("-- Límites")
	place(Vector3(20.0, 0.05, 3.5), 180.0)
	await walk("move_forward", 150)
	check(player().global_position.z < 6.3, "la reja de la plaza frena: z=%.2f" % player().global_position.z)
	place(Vector3(30.0, 0.05, 3.5), 180.0)
	await walk("move_forward", 150)
	check(player().global_position.z < 6.3, "el portón está cerrado: z=%.2f" % player().global_position.z)
	place(Vector3(6.0, 0.05, 0.0), 90.0)
	await walk("move_forward", 200)
	check(player().global_position.x > 3.0, "la calle termina en el camión: x=%.2f" % player().global_position.x)
	place(Vector3(56.0, 0.05, 0.0), -90.0)
	await walk("move_forward", 200)
	check(player().global_position.x < 61.9, "el hospital es una pared: x=%.2f" % player().global_position.x)
	await physics_frame
	var map: RID = player().get_world_3d().navigation_map
	var path := NavigationServer3D.map_get_path(map, Vector3(20, 0, 0), Vector3(30, 0, 20), true)
	check(path.size() == 0 or path[path.size() - 1].distance_to(Vector3(30, 0, 20)) > 3.0, "no hay camino a la plaza")

	print("-- Secreto")
	sanity._set_current(sanity.maximum * 0.3)
	await frames(5)
	check(current_scene.get_node("Secrets/BenchLetter").visible, "Quebrado: aparece la carta debajo del banco")
	place(Vector3(20.0, 0.05, 3.2), 180.0, -25.0)
	await shot("13_carta_banco")
	sanity._set_current(sanity.maximum)

	print("-- Al hospital")
	place(Vector3(60.5, 0.05, 0.0), -90.0)
	await frames(5)
	current_scene.get_node("Inspectables/HospitalDoor").interact(player())
	await settle()
	check(current_scene.name == "Hospital", "la puerta de guardia lleva al hospital")
	check(player().global_position.distance_to(Vector3(1.5, 0, 9.5)) < 0.5, "entra por el oeste del pasillo")
	check(not sanity.in_refuge(), "la sala del personal ya no es el refugio")
	await shot("14_guardia")
	current_scene.get_node("Inspectables/GuardDoor").interact(player())
	await settle()
	check(current_scene.name == "ParkStreet" and player().global_position.distance_to(Vector3(60.0, 0, 0)) < 0.5,
		"y se vuelve a la calle de la plaza")

	print("-- El que viene después llega a casa")
	root.get_node("GameState").new_survivor()
	await settle()
	check(current_scene.name == "Home" and player().global_position.distance_to(Vector3(2.6, 0, 2.6)) < 0.5,
		"el sobreviviente nuevo aparece en su pieza")

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.dat"))
	print("RESULT: %d fallas" % fails)
	quit()
