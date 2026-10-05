extends SceneTree
## Teatro Imperio (zona 3): la llave de Sosa abre el candado, la escopeta dispara
## perdigones, el jefe despierta al acercarse al escenario, aguanta, se enfurece y
## muere; la puerta del camarín se abre y ahí uno se puede mudar (segundo refugio):
## el siguiente sobreviviente llega al teatro. Capturas en user://test_shots/theater/.
## Uso: <godot> --path . -s res://tests/theater_test.gd

const OUT := "user://test_shots/theater/"
const S := 1.1
const UPY := 5.0
const PITY := -3.5

var fails := 0
var sanity: Node
var inventory: Node
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


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for action in InputMap.get_actions():
		InputMap.action_erase_events(action)
	root.get_node("SaveGame").path = "user://test_save.dat"
	sanity = root.get_node("Sanity")
	inventory = root.get_node("Inventory")
	game_state = root.get_node("GameState")
	shelter = root.get_node("Shelter")
	root.get_node("SaveGame").new_game()
	change_scene_to_file("res://scenes/levels/street.tscn")
	await settle()

	print("-- Entrada")
	var door: Node = current_scene.get_node("Inspectables/TheaterDoor")
	door.interact(player())
	await frames(3)
	check(current_scene.name == "Street", "sin la llave el candado no abre")
	inventory.add(load("res://assets/items/key_theater.tres"))
	door.interact(player())
	await settle()
	check(current_scene.name == "Theater", "con la llave de Sosa se entra al teatro")
	check(player().global_position.distance_to(Vector3(2.8, 0, 12.0)) < 0.5, "aparece en la entrada del vestíbulo: %s" % player().global_position)
	var boss: Node3D = current_scene.get_node("Enemies/Singer")
	check(boss.dormant and not boss.visual.visible, "la cantante duerme, invisible")
	await shot("01_vestibulo")

	print("-- Escopeta")
	var shotgun_pickup: Node = current_scene.get_node("Items/Shotgun")
	shotgun_pickup.interact(player())
	current_scene.get_node("Items/Shells2").interact(player())
	var shotgun: Resource = load("res://assets/items/weapon_shotgun.tres")
	var entry: Dictionary = {}
	for e: Dictionary in inventory.entries:
		if e.item == shotgun:
			entry = e
	check(not entry.is_empty() and entry.loaded == 2, "la escopeta entra en la mochila, cargada con 2")
	inventory.use(shotgun, entry)
	var combat: Node = player().get_node("Combat")
	check(inventory.equipped_item() == shotgun, "escopeta en la mano")
	var stalker: Node3D = current_scene.get_node("Enemies/StalkerCoats")
	stalker.global_position = Vector3(7.0, 0.05, 4.5)
	place(Vector3(7.0, 0.05, 7.5), 0.0)
	await frames(5)
	Input.action_press("aim")
	await frames(10)
	var health_before: float = stalker.health
	combat.attack()
	await frames(3)
	Input.action_release("aim")
	var dealt: float = health_before - stalker.health
	check(dealt > shotgun.damage * 1.5 or stalker.is_dead(), "un disparo, varios perdigones: %.0f de daño" % dealt)
	check(entry.loaded == 1, "gasta un cartucho")
	await shot("02_escopeta")

	print("-- Recorrido")
	for s: Array in [["03_sala", Vector3(27.0, 0.05, 0.5), -90.0], ["04_butacas", Vector3(46.0, 0.05, 16.5), -60.0],
			["05_escenario", Vector3(64.0, S + 0.05, 22.0), -30.0], ["06_hombro", Vector3(81.0, S + 0.05, -2.0), 180.0],
			["07_camarin_2", Vector3(88.5, S + 0.05, 10.5), -90.0], ["07b_vestibulo", Vector3(3.0, 0.05, 2.0), -120.0],
			["07c_entrepiso", Vector3(20.0, UPY + 0.05, 2.0), 180.0], ["07d_pullman", Vector3(25.5, UPY + 0.05, 8.0), -90.0],
			["07e_palcos", Vector3(40.0, UPY + 0.05, 24.8), -90.0], ["07f_espejos", Vector3(12.0, 0.05, -6.0), 0.0],
			["07g_galeria", Vector3(12.0, 0.05, 30.0), 160.0], ["07h_ala_norte", Vector3(26.0, 0.05, -12.0), -90.0],
			["07i_foso", Vector3(62.0, PITY + 0.05, 8.0), -90.0], ["07j_administracion", Vector3(17.0, UPY + 0.05, -12.0), 160.0]]:
		place(s[1], s[2])
		await shot(s[0])

	print("-- Niveles")
	place(Vector3(2.5, 0.05, 22.0), -90.0)
	var top := 0.0
	Input.action_press("move_forward")
	for i in 700:
		await physics_frame
		top = maxf(top, player().global_position.y)
	Input.action_release("move_forward")
	check(top > UPY - 0.3, "la escalera imperial sube al entrepiso: y=%.2f" % top)
	place(Vector3(78.5, S + 0.05, 26.5), 180.0)
	var low := 10.0
	Input.action_press("move_forward")
	for i in 700:
		await physics_frame
		low = minf(low, player().global_position.y)
	Input.action_release("move_forward")
	check(low < PITY + 0.3, "se baja al foso de máquinas: y=%.2f" % low)
	await physics_frame
	var map: RID = player().get_world_3d().navigation_map
	for t: Vector3 in [Vector3(25.5, UPY, 0.0), Vector3(50.0, UPY, -8.8), Vector3(70.0, PITY, 8.0), Vector3(81.0, S, -4.0),
			Vector3(50.0, 0, 33.0), Vector3(12.0, UPY, -9.0), Vector3(85.0, PITY, 34.0), Vector3(86.0, PITY, 20.0)]:
		var path := NavigationServer3D.map_get_path(map, Vector3(3.0, 0, 12.0), t, true)
		check(path.size() > 1 and path[path.size() - 1].distance_to(t) < 1.2, "los enemigos llegan a %s (fin %s)" % [t, path[path.size() - 1] if path.size() > 0 else Vector3.ZERO])

	print("-- Jefe")
	var gate: Node3D = current_scene.get_node("Structure/CamarinGate")
	check(not gate.is_open(), "el camarín principal está trabado")
	place(Vector3(55.0, 0.05, 8.5), -90.0, -5.0)
	await frames(10)
	check(not boss.dormant and boss.visual.visible, "al acercarse al escenario, la cantante despierta")
	boss.set_physics_process(false)
	await shot("08_la_cantante")
	var max_health: float = boss.max_health
	boss.take_damage(40.0)
	check(boss.state != 3 and boss.health == max_health - 40.0, "40 de daño: no se tambalea")
	boss.take_damage(40.0)
	check(boss.state == 3, "al acumular daño, se tambalea")
	boss.take_damage(max_health * 0.5)
	check(boss.enraged, "por debajo de la mitad, se enfurece")
	var pre_kill: float = sanity.current
	sanity._set_current(sanity.maximum * 0.5)
	pre_kill = sanity.current
	boss.take_damage(max_health)
	await frames(3)
	check(boss.is_dead() and game_state.has_flag(&"theater_boss_dead"), "muere y deja la marca")
	check(sanity.current > pre_kill + 20.0, "matarla devuelve mucha cordura")
	check(gate.is_open(), "la puerta del camarín se destraba")
	await shot("09_derrotada")

	print("-- El camarín: mudarse")
	place(Vector3(91.0, S + 0.05, 21.5), 90.0)
	await frames(10)
	check(not sanity.in_refuge(), "el camarín todavía no es refugio (vivo en el hospital)")
	await shot("10_camarin")
	var menu: Control = current_scene.get_node("GameUI/ShelterMenu")
	current_scene.get_node("Refuge/BlueprintStation").interact(player())
	await frames(3)
	check(menu.visible and menu.upgrade_name.text.begins_with("Todavía no"), "el plano ofrece mudarse")
	await shot("11_plano_mudarse")
	menu._build()
	await frames(3)
	check(shelter.active == &"theater", "me mudé al teatro")
	menu.close()
	await frames(5)
	check(sanity.in_refuge(), "ahora el camarín es refugio")
	shelter.stock[&"material_cable"] = 5
	shelter.stock[&"material_metal"] = 5
	check(shelter.upgrade(&"power", &"theater") and shelter.level(&"power", &"hospital") == 0, "las mejoras son de cada refugio")
	await frames(5)
	await shot("12_camarin_con_luz")

	print("-- El que viene después llega al teatro")
	game_state.new_survivor()
	await settle()
	check(current_scene.name == "Theater", "el sobreviviente nuevo aparece en el teatro")
	check(player().global_position.distance_to(Vector3(91.0, S, 21.0)) < 0.6, "en el camarín: %s" % player().global_position)
	check(not current_scene.get_node("Enemies").has_node("Singer") or current_scene.get_node("Enemies/Singer").is_queued_for_deletion(),
		"la cantante no vuelve")
	var data: Dictionary = root.get_node("SaveGame").read()
	check(data.get("shelter", {}).get("active", &"") == &"theater", "el guardado recuerda el refugio nuevo")

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.dat"))
	print("RESULT: %d fallas" % fails)
	quit()
