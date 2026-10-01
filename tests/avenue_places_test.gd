extends SceneTree
## Las dos zonas nuevas de la avenida: Comisaría 12 y Parroquia San Judas Tadeo.
## Entrada y salida desde la avenida, recorrido, secretos por dificultad (el depósito de
## evidencias en Difícil; el calabozo 3 y la cripta en Insane) y la bajada a la cripta.
## Capturas en user://test_shots/places/.
## Uso: <godot> --path . -s res://tests/avenue_places_test.gd

const OUT := "user://test_shots/places/"

var fails := 0
var sanity: Node


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


func set_madness(m: float) -> void:
	sanity._set_current(sanity.maximum * (1.0 - m))


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for action in InputMap.get_actions():
		InputMap.action_erase_events(action)
	root.get_node("SaveGame").path = "user://test_save.dat"
	sanity = root.get_node("Sanity")
	root.get_node("SaveGame").new_game()
	change_scene_to_file("res://scenes/levels/street.tscn")
	await settle()

	print("-- Comisaría 12")
	current_scene.get_node("Inspectables/Door_comisaria").interact(player())
	await settle()
	check(current_scene.name == "PoliceStation", "la puerta de la avenida lleva a la comisaría")
	check(current_scene.has_node("Items/PoliceLog"), "el libro de guardia está en la mesa de entradas")
	for s: Array in [["01_comisaria_entrada", Vector3(10.0, 0.05, 11.4), 0.0], ["02_comisaria_oficina", Vector3(5.5, 0.05, 7.5), 30.0],
			["03_comisaria_guardia", Vector3(11.0, 0.05, 8.0), 10.0], ["04_calabozos", Vector3(16.5, 0.05, 7.5), 0.0]]:
		place(s[1], s[2])
		await shot(s[0])
	check(current_scene.get_node("Secrets/EvidenceWall").visible and not current_scene.get_node("Secrets/Evidence").visible,
		"en Normal el depósito de evidencias está tapiado")
	set_madness(0.6)
	await frames(5)
	check(not current_scene.get_node("Secrets/EvidenceWall").visible and current_scene.get_node("Secrets/Evidence").visible,
		"en Difícil la pared desaparece: el depósito de evidencias")
	place(Vector3(10.0, 0.05, 2.0), 0.0)
	await walk("move_forward", 90)
	check(player().global_position.z < -0.5, "se entra al depósito: z=%.2f" % player().global_position.z)
	await shot("05_evidencias")
	check(not current_scene.get_node("Secrets/Cell3Open").visible, "el calabozo 3 sigue cerrado en Difícil")
	set_madness(0.8)
	await frames(5)
	check(current_scene.get_node("Secrets/Cell3Open").visible and not current_scene.get_node("Secrets/Cell3Bars").visible,
		"en Insane se abre el calabozo 3")
	place(Vector3(18.83, 0.05, 6.0), 0.0)
	await walk("move_forward", 90)
	check(player().global_position.z < 3.5, "se entra al calabozo 3: z=%.2f" % player().global_position.z)
	await shot("06_calabozo_3")
	set_madness(0.0)
	await frames(3)
	current_scene.get_node("Inspectables/StreetDoor").interact(player())
	await settle()
	var back: Node3D = current_scene.get_node("SpawnHouse_comisaria")
	check(current_scene.name == "Street" and player().global_position.distance_to(back.global_position) < 0.5,
		"se vuelve a la avenida, frente a la comisaría")

	print("-- Parroquia San Judas Tadeo")
	current_scene.get_node("Inspectables/Door_iglesia").interact(player())
	await settle()
	check(current_scene.name == "Church", "la puerta de la avenida lleva a la iglesia")
	for s: Array in [["07_iglesia_nave", Vector3(8.0, 0.05, 23.4), 0.0], ["08_iglesia_altar", Vector3(8.0, 0.05, 9.0), 0.0],
			["09_confesionario", Vector3(11.5, 0.05, 13.0), -90.0], ["10_sacristia", Vector3(13.5, 0.55, 4.0), 0.0]]:
		place(s[1], s[2])
		await shot(s[0])
	check(current_scene.has_node("Items/PriestDiary"), "el diario del padre en la sacristía")
	check(not current_scene.get_node("Secrets/Crypt").visible, "la cripta está cerrada (Normal)")
	place(Vector3(8.0, 0.05, 13.0), 0.0)
	await walk("move_forward", 120)
	check(player().global_position.y > -0.3, "con la trampa cerrada no se cae: y=%.2f" % player().global_position.y)
	set_madness(0.8)
	await frames(5)
	check(current_scene.get_node("Secrets/Crypt").visible and not current_scene.get_node("Secrets/CryptCover").visible,
		"en Insane se abre la cripta")
	place(Vector3(8.0, 0.05, 6.2), 180.0)
	await walk("move_forward", 260)
	var crypt_y: float = player().global_position.y
	check(crypt_y < -2.8 and crypt_y > -3.2 and player().is_on_floor(), "se baja a la cripta y se queda en su piso: y=%.2f" % crypt_y)
	await shot("11_cripta")
	check(current_scene.has_node("Secrets/Crypt/ElenaLetter"), "en la cripta, la carta de Elena")
	set_madness(0.0)
	current_scene.get_node("Inspectables/StreetDoor").interact(player())
	await settle()
	check(current_scene.name == "Street", "se vuelve a la avenida desde la iglesia")

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.dat"))
	print("RESULT: %d fallas" % fails)
	quit()
