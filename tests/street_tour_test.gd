extends SceneTree
## Recorrido de la calle (zona 2): se sale del hospital forzando la salida de
## emergencia con la barreta, se recorre la avenida, se prueban los límites
## (barricada, edificios), el secreto del patio y la vuelta al hospital.
## Capturas en user://test_shots/street/.
## Uso: <godot> --path . -s res://tests/street_tour_test.gd
## No usar class_name del juego acá (compila antes que los autoloads).

const OUT := "user://test_shots/street/"
const TZ := 66.0

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


func shot(name: String) -> void:
	await frames(12)
	root.get_texture().get_image().save_png(OUT + "%s.png" % name)


func settle() -> void:
	await frames(90)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player().set_process_unhandled_input(false)
	player().get_node("Combat").set_process_unhandled_input(false)
	for enemy in get_nodes_in_group(&"enemies"):
		enemy.set_physics_process(false)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for action in InputMap.get_actions():
		InputMap.action_erase_events(action)
	# Los tests guardan en otro archivo para no pisar la partida del jugador.
	root.get_node("SaveGame").path = "user://test_save.dat"
	sanity = root.get_node("Sanity")
	inventory = root.get_node("Inventory")
	game_state = root.get_node("GameState")
	change_scene_to_file("res://scenes/levels/hospital.tscn")
	await settle()

	print("-- Salida de emergencia")
	var exit: Node = current_scene.get_node("Inspectables/EmergencyExit")
	exit.interact(player())
	await frames(3)
	check(current_scene.name == "Hospital" and not game_state.has_flag(&"hospital_exit_forced"), "sin barreta no se abre")
	inventory.add(load("res://assets/items/weapon_crowbar.tres"))
	exit.interact(player())
	await settle()
	check(current_scene.name == "Street", "con la barreta se sale a la calle")
	check(game_state.has_flag(&"hospital_exit_forced"), "la puerta queda forzada")
	check(player().global_position.distance_to(Vector3(2.8, 0, 0)) < 0.5, "aparece en la puerta del hospital: %s" % player().global_position)
	check(get_nodes_in_group(&"enemies").size() == 12, "9 acechadores y 3 escupidores: %d" % get_nodes_in_group(&"enemies").size())
	await shot("01_salida")

	print("-- Navegación")
	await physics_frame
	var map: RID = player().get_world_3d().navigation_map
	for t: Vector3 in [Vector3(64, 0, -106), Vector3(150, 0, 66), Vector3(120, 0, -40), Vector3(200, 0, 0)]:
		var path := NavigationServer3D.map_get_path(map, Vector3(5, 0, 0), t, true)
		check(path.size() > 1 and path[path.size() - 1].distance_to(t) < 1.0, "hay camino a %s: %d puntos" % [t, path.size()])

	print("-- Límites")
	place(Vector3(156.0, 0.05, 2.0), -90.0)
	await walk("move_forward", 150)
	check(player().global_position.x < 158.9, "la barricada frena: x=%.2f" % player().global_position.x)
	place(Vector3(156.0, 0.05, -8.3), -90.0)
	await walk("move_forward", 200)
	check(player().global_position.x > 163.0, "se pasa por la vereda norte: x=%.2f" % player().global_position.x)
	place(Vector3(20.0, 0.05, -7.5), 0.0)
	await walk("move_forward", 120)
	check(player().global_position.z > -9.4, "los edificios frenan: z=%.2f" % player().global_position.z)
	place(Vector3(210.0, 0.05, 0.0), -90.0)
	await walk("move_forward", 200)
	check(player().global_position.x < 216.0, "el teatro está cerrado: x=%.2f" % player().global_position.x)
	place(Vector3(64.0, 0.05, -96.0), 0.0)
	await walk("move_forward", 250)
	check(player().global_position.z > -111.6, "el patio está cerrado: z=%.2f" % player().global_position.z)
	place(Vector3(47.0, 0.05, -72.0), 90.0)
	await walk("move_forward", 200)
	check(player().global_position.x > 42.0, "Lavalle termina en una pared: x=%.2f" % player().global_position.x)

	print("-- Capturas")
	var shots := [
		["02_avenida", Vector3(3.0, 0.05, 1.5), -80.0],
		["03_hospital", Vector3(8.0, 0.05, -1.0), 100.0],
		["04_ambulancia", Vector3(25.0, 0.05, 1.5), -70.0],
		["05_parana", Vector3(48.0, 0.05, -20.0), 0.0],
		["06_lavalle", Vector3(56.0, 0.05, -72.0), -90.0],
		["07_callejon", Vector3(63.0, 0.05, -80.0), 0.0],
		["08_patio", Vector3(62.0, 0.05, -101.0), -30.0],
		["09_viamonte", Vector3(84.0, 0.05, 20.0), 180.0],
		["10_tucuman", Vector3(100.0, 0.05, TZ), -90.0],
		["11_iglesia", Vector3(132.0, 0.05, TZ), 0.0],
		["12_barricada", Vector3(152.0, 0.05, 1.0), -85.0],
		["13_teatro", Vector3(206.0, 0.05, -1.0), -90.0],
		["14_uruguay", Vector3(120.0, 0.05, -30.0), 90.0],
	]
	for s: Array in shots:
		place(s[1], s[2])
		await shot(s[0])

	print("-- Secreto del patio")
	sanity._set_current(sanity.maximum * 0.3)
	await frames(10)
	check(not current_scene.get_node("Secrets/LyingWall").visible, "Quebrado: el ladrillo flojo desaparece")
	place(Vector3(64.0, 0.05, -109.0), 0.0)
	await create_timer(2.0).timeout
	await shot("15_nicho")
	sanity._set_current(sanity.maximum)
	print("-- Casas")
	var houses := {
		"ibarra": ["HouseIbarra", [["20_ibarra_living", Vector3(0.0, 0.05, -1.2), 20.0], ["21_ibarra_cocina", Vector3(-0.5, 0.05, -1.5), -60.0]]],
		"almacen": ["HouseAlmacen", [["22_almacen", Vector3(-0.5, 0.05, -1.0), -20.0], ["23_almacen_estantes", Vector3(0.0, 0.05, -3.0), -80.0]]],
		"relojeria": ["HouseRelojeria", [["24_relojeria", Vector3(0.0, 0.05, -1.0), 10.0]]],
		"pension": ["HousePension", [["25_pension_pasillo", Vector3(-2.4, 0.05, -1.0), 0.0], ["26_pension_pieza", Vector3(1.2, 0.05, -1.4), 30.0]]],
	}
	for id: String in houses:
		var door: Node3D = current_scene.get_node("Inspectables/Door_" + id)
		place(door.global_position * Vector3(1, 0, 1) + Vector3(0, 0.05, 0), 0.0)
		door.interact(player())
		await settle()
		check(current_scene.name == houses[id][0], "se entra a %s" % id)
		for s: Array in houses[id][1]:
			place(s[1], s[2])
			await shot(s[0])
		current_scene.get_node("Inspectables/StreetDoor").interact(player())
		await settle()
		var spawn: Node3D = current_scene.get_node("SpawnHouse_" + id)
		check(current_scene.name == "Street" and player().global_position.distance_to(spawn.global_position) < 0.5,
			"se sale de %s a la vereda: %s vs %s" % [id, player().global_position, spawn.global_position])

	print("-- Vuelta al hospital")
	place(Vector3(1.4, 0.05, 0), 90.0)
	await frames(5)
	current_scene.get_node("Inspectables/HospitalDoor").interact(player())
	await settle()
	check(current_scene.name == "Hospital", "vuelve al hospital")
	check(player().global_position.distance_to(Vector3(33.4, 0, 9.5)) < 0.5, "entra por la salida de emergencia: %s" % player().global_position)
	await shot("11_vuelta")

	print("RESULT: %d fallas" % fails)
	quit()
