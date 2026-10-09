extends SceneTree
## Poderes: las páginas del diario (se leen al encontrarlas y enseñan el poder), el Filo del otro
## lado (más daño 40 s, el arma brilla), el Empujón (tira para atrás y lastima un poco), el costo en
## locura, el tiempo de espera, la muerte (los poderes y las páginas quedan) y el guardado.
## Capturas en user://test_shots/powers/.
## Uso: <godot> --path . -s res://tests/powers_test.gd

const OUT := "user://test_shots/powers/"

var fails := 0
var sanity: Node
var game_state: Node
var inventory: Node
var powers: Node


func check(cond: bool, msg: String) -> void:
	print(("OK   " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func physics(n: int) -> void:
	for i in n:
		await physics_frame


func shot(name: String) -> void:
	await frames(12)
	root.get_texture().get_image().save_png(OUT + "%s.png" % name)


func player() -> Node3D:
	return current_scene.get_node("Player")


func combat() -> Node:
	return player().get_node("Combat")


func menu() -> Node:
	return current_scene.get_node("GameUI/GameMenu")


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
	combat().set_process_unhandled_input(false)
	for enemy in get_nodes_in_group(&"enemies"):
		enemy.set_physics_process(false)


func message() -> String:
	return current_scene.get_node("GameUI").pickup_label.text


## Un acechador nuevo frente al jugador (a `distance` m, en la dirección en que mira).
func spawn_stalker(distance: float) -> Node3D:
	var s: Node3D = load("res://scenes/enemies/stalker.tscn").instantiate()
	s.name = "TestStalker"
	var forward: Vector3 = -player().visual.global_basis.z
	current_scene.add_child(s)
	s.global_position = player().global_position + forward * distance
	return s


func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for action in InputMap.get_actions():
		InputMap.action_erase_events(action)
	root.get_node("SaveGame").path = "user://test_save.dat"
	sanity = root.get_node("Sanity")
	game_state = root.get_node("GameState")
	inventory = root.get_node("Inventory")
	powers = root.get_node("Powers")
	root.get_node("SaveGame").new_game()

	print("-- La primera página")
	change_scene_to_file("res://scenes/levels/home.tscn")
	await settle()
	check(powers.known.is_empty(), "al empezar no sé ningún poder")
	var page: Node = current_scene.get_node("Items/DiaryPage1")
	place(page.global_position + Vector3(0.0, -0.78, 1.0), 0.0)
	page.interact(player())
	await frames(4)
	check(menu().visible and menu().letter_panel.visible, "la página se lee apenas la encuentro")
	check(menu().letter_label.text.contains("Instituto"), "es mi diario, del Instituto")
	await shot("01_pagina")
	check(menu().letter_hint.text.contains("seguir"), "es larga: se lee por partes")
	menu().call("_advance_letter")
	await frames(3)
	check(menu().letter_panel.visible and menu().letter_label.lines_skipped > 0, "E pasa a la parte que sigue")
	await shot("01b_pagina_sigue")
	check(powers.knows(&"empower"), "aprendí el Filo del otro lado")
	menu().call("_close_letter")
	await frames(3)
	check(not menu().visible and not paused, "al cerrarla, sigo jugando")
	check(message().contains("Filo del otro lado"), "me dice qué aprendí: \"%s\"" % message().left(70))
	check(inventory.letters.size() == 1, "la página queda con las cartas")

	print("-- Filo del otro lado")
	current_scene.get_node("Items/Broom").interact(player())
	for e: Dictionary in inventory.entries:
		if e.item.id == &"weapon_broom":
			inventory.use(e.item, e)
	check(inventory.equipped_item() != null, "con la escoba en la mano")
	place(Vector3(8.0, 0.05, 4.0), 0.0, -12.0)
	var before: float = sanity.madness()
	combat().use_power(&"empower")
	await physics(6)
	check(powers.is_empowered() and powers.empower_left > 39.0, "dura 40 segundos: %.1f" % powers.empower_left)
	check(sanity.madness() - before > 0.08, "sube la locura: %.0f%% -> %.0f%%" % [before * 100, sanity.madness() * 100])
	var mats: Array = combat().get("_held_materials")
	var glow: Color = mats[0].get_shader_parameter(&"emission_color") if not mats.is_empty() else Color.BLACK
	check(glow.b > 0.2, "el arma brilla: %s" % glow)
	var hud_text: String = current_scene.get_node("GameUI/Hud").powers_label.text
	check(hud_text.contains("FILO") and hud_text.contains("s"), "el HUD lo muestra: \"%s\"" % hud_text.replace("\n", " | "))
	var cam_pos: Vector3 = player().global_position
	place(cam_pos, 160.0, -15.0)
	await shot("02_filo")
	place(cam_pos, 0.0, -12.0)
	var stalker := spawn_stalker(1.4)
	await physics(2)
	stalker.set_physics_process(false)
	var hp: float = stalker.health
	combat().attack()
	await physics(40)
	var dealt: float = hp - stalker.health
	check(absf(dealt - 14.0 * 1.35) < 0.5, "la escoba pega más: %.1f (sin el Filo, 14)" % dealt)
	powers.empower_left = 0.3
	await physics(30)
	check(not powers.is_empowered(), "se termina")
	glow = mats[0].get_shader_parameter(&"emission_color") if not mats.is_empty() else Color.BLACK
	check(glow.b < 0.01, "y el brillo se apaga")
	stalker.queue_free()
	sanity._set_current(sanity.maximum)

	print("-- La segunda página")
	change_scene_to_file("res://scenes/levels/hospital.tscn")
	await settle()
	var page2: Node = current_scene.get_node("Items/DiaryPage2")
	place(page2.global_position + Vector3(-0.8, 0.0, 0.8), 0.0)
	page2.interact(player())
	await frames(4)
	check(menu().letter_panel.visible and menu().letter_label.text.contains("Empujá"), "la segunda página")
	await shot("03_pagina2")
	menu().call("_close_letter")
	await frames(3)
	check(powers.knows(&"push"), "aprendí el Empujón")

	print("-- Empujón")
	place(Vector3(12.0, 0.05, 9.5), 90.0, -10.0)
	await physics(4)
	var target := spawn_stalker(2.0)
	await physics(3)
	var start: Vector3 = target.global_position
	hp = target.health
	before = sanity.madness()
	combat().use_power(&"push")
	await physics(4)
	await shot("04_empujon")
	await physics(20)
	var moved := flat(target.global_position, start)
	check(moved > 0.8, "lo tira para atrás: %.2f m" % moved)
	check(flat(target.global_position, player().global_position) > flat(start, player().global_position), "lejos de mí")
	check(hp - target.health > 4.0 and hp - target.health < 10.0, "un poco de daño: %.1f" % (hp - target.health))
	check(sanity.madness() > before, "sube la locura")
	var after: float = sanity.madness()
	combat().use_power(&"push")
	await physics(2)
	check(sanity.madness() - after < 0.02, "hay que esperar para volver a usarlo")
	target.global_position = player().global_position + Vector3(30.0, 0.0, 0.0)
	var behind := spawn_stalker(-2.0)
	await physics(2)
	behind.set_physics_process(false)
	var behind_hp: float = behind.health
	await physics(160)
	combat().use_power(&"push")
	await physics(5)
	check(is_equal_approx(behind.health, behind_hp), "solo empuja lo que tengo adelante")
	target.queue_free()
	behind.queue_free()

	print("-- Morir y guardar")
	combat().use_power(&"empower")
	inventory.clear()
	powers.end_life()
	check(powers.knows(&"empower") and powers.knows(&"push"), "los poderes quedan para el próximo")
	check(inventory.letters.size() == 2, "y las páginas del diario también")
	check(not powers.is_empowered(), "el Filo se corta")
	check(not inventory.all_items().any(func(i: Resource) -> bool: return i.kind == 9), "las páginas no quedan en el cuerpo")
	root.get_node("SaveGame").save_game()
	powers.new_game()
	check(powers.known.is_empty(), "partida nueva: nada")
	root.get_node("SaveGame").load_game()
	await frames(60)
	check(powers.knows(&"empower") and powers.knows(&"push"), "al cargar, los poderes vuelven")

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.dat"))
	print("RESULT: %d fallas" % fails)
	quit()
