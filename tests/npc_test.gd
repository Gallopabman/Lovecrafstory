extends SceneTree
## Los NPC: el Flaco preso en la comisaría (la llave de los calabozos, la celda 5, después en su
## rincón del Pasaje Ombú con un regalo), el Dr. Ferreyra que huye en el hospital y el mendigo
## que duerme en la avenida. Capturas en user://test_shots/npcs/.
## Uso: <godot> --path . -s res://tests/npc_test.gd

const OUT := "user://test_shots/npcs/"

var fails := 0
var sanity: Node
var game_state: Node
var inventory: Node


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


func settle() -> void:
	await frames(90)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player().set_process_unhandled_input(false)
	player().get_node("Combat").set_process_unhandled_input(false)
	for enemy in get_nodes_in_group(&"enemies"):
		enemy.set_physics_process(false)


func message() -> String:
	return current_scene.get_node("GameUI").pickup_label.text


func has_item(id: StringName) -> int:
	var n := 0
	for e: Dictionary in inventory.entries:
		if e.item.id == id:
			n += e.get("count", 1)
	return n


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for action in InputMap.get_actions():
		InputMap.action_erase_events(action)
	root.get_node("SaveGame").path = "user://test_save.dat"
	sanity = root.get_node("Sanity")
	game_state = root.get_node("GameState")
	inventory = root.get_node("Inventory")
	root.get_node("SaveGame").new_game()

	print("-- El Flaco, preso")
	change_scene_to_file("res://scenes/levels/police_station.tscn")
	await settle()
	var flaco: Node3D = current_scene.get_node("Props/Flaco")
	var lock: Node = current_scene.get_node("Inspectables/FlacoCellLock")
	check(flaco.visible, "el Flaco está en el calabozo 5")
	place(Vector3(36.0, 0.05, 4.5), -90.0)
	player().visual.visible = false
	await shot("01_flaco_celda")
	player().visual.visible = true
	lock.interact(player())
	await frames(3)
	check(message().contains("Flaco"), "sin la llave, habla desde la reja: \"%s\"" % message().left(60))
	lock.interact(player())
	lock.interact(player())
	await frames(3)
	check(message().contains("oficial de servicio"), "dice dónde está la llave")
	current_scene.get_node("Items/KeyCells").interact(player())
	await frames(3)
	check(has_item(&"key_cells") > 0, "la llave de los calabozos estaba en el escritorio del oficial de servicio")
	lock.interact(player())
	await frames(3)
	check(game_state.has_flag(&"flaco_freed"), "con la llave se abre el calabozo")
	check(not flaco.visible, "el Flaco se va")
	place(Vector3(36.0, 0.05, 4.5), -90.0)
	Input.action_press("move_forward")
	for i in 90:
		await physics_frame
	Input.action_release("move_forward")
	check(player().global_position.x > 38.2, "la reja ya no está: x=%.2f" % player().global_position.x)

	print("-- El Flaco, en su rincón")
	change_scene_to_file("res://scenes/levels/park_street.tscn")
	await settle()
	var corner: Node3D = current_scene.get_node("Props/Flaco")
	check(corner.visible, "el Flaco volvió al Pasaje Ombú")
	place(corner.global_position + Vector3(-2.4, 0.0, 0.0), -90.0, -8.0)
	await shot("02_flaco_pasaje")
	var ammo_before := has_item(&"ammo_9mm")
	corner.interact(player())
	await frames(3)
	check(has_item(&"ammo_9mm") >= ammo_before + 12, "te regala balas: %d" % has_item(&"ammo_9mm"))
	corner.interact(player())
	await frames(3)
	check(message().begins_with("—"), "después charla: \"%s\"" % message().left(60))

	print("-- Ferreyra")
	change_scene_to_file("res://scenes/levels/hospital.tscn")
	await settle()
	var ferreyra: Node3D = current_scene.get_node("Props/Ferreyra")
	check(ferreyra.visible and not game_state.has_flag(&"ferreyra_fled"), "Ferreyra está en el pasillo")
	place(Vector3(4.0, 0.05, 9.5), -90.0, -5.0)
	var fled := false
	for i in 600:
		await physics_frame
		if i == 30:
			player().visual.visible = false
			await shot("03_ferreyra_huye")
			player().visual.visible = true
		if game_state.has_flag(&"ferreyra_fled"):
			fled = true
			break
	check(ferreyra.call("is_fleeing") or fled, "al verte, sale corriendo")
	check(fled and not ferreyra.visible, "y desaparece por una puerta (x=%.1f z=%.1f)" % [ferreyra.global_position.x, ferreyra.global_position.z])
	check(ferreyra.global_position.x > 30.0, "por la salida de emergencia (la más lejos): x=%.1f" % ferreyra.global_position.x)
	change_scene_to_file("res://scenes/levels/hospital.tscn")
	await settle()
	check(not current_scene.get_node("Props/Ferreyra").visible, "no vuelve a aparecer")

	print("-- El mendigo")
	change_scene_to_file("res://scenes/levels/street.tscn")
	await settle()
	var beggar: Node3D = current_scene.get_node("Props/Beggar")
	check(beggar.visible, "el mendigo duerme en la avenida")
	var spot := beggar.global_position
	place(spot + Vector3(-1.0, 0.0, 2.6), 0.0, -30.0)
	player().visual.visible = false
	await shot("04_mendigo")
	player().visual.visible = true
	var said := []
	for i in 4:
		beggar.interact(player())
		await frames(3)
		said.append(message())
	check(said[0] != said[1] and said[1] != said[2], "cada vez que le hablás, otra cosa")
	check(beggar.global_position.distance_to(spot) < 0.05, "y no se despierta ni se mueve")
	sanity._set_current(sanity.maximum * 0.3)
	await frames(3)
	beggar.interact(player())
	await frames(3)
	var broken_lines: PackedStringArray = beggar.get("texts_broken")
	check(broken_lines.has(message()), "con la cabeza rota, dice otras cosas: \"%s\"" % message().left(60))
	sanity._set_current(sanity.maximum)

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.dat"))
	print("RESULT: %d fallas" % fails)
	quit()
