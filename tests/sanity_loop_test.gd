extends SceneTree
## Test del loop de cordura: recorre refugio, goteo, horror, golpe, objetos,
## menú, estados/secretos y muerte. Guarda capturas en user://test_shots/.
## Uso: <godot> --path . -s res://tests/sanity_loop_test.gd

const OUT := "user://test_shots/"
var sanity: Node
var inventory: Node
var fails := 0


func check(cond: bool, msg: String) -> void:
	print(("OK   " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func shot(name: String) -> void:
	await frames(3)
	root.get_texture().get_image().save_png(OUT + "t_%s.png" % name)


func place(pos: Vector3, yaw: float) -> void:
	var p: Node3D = current_scene.get_node("Player")
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.set("_yaw", yaw)
	p.get_node("CameraPivot").global_position = pos + Vector3.UP * 1.5
	p.get_node("Visual").global_rotation.y = yaw


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	sanity = root.get_node("Sanity")
	inventory = root.get_node("Inventory")
	change_scene_to_file("res://scenes/levels/test_room.tscn")
	await frames(60)
	var player: Node3D = current_scene.get_node("Player")
	var anim: AnimationPlayer = player.anim_player

	# 1. Refugio y animación idle
	check(sanity.in_refuge(), "spawn dentro del refugio")
	check(is_equal_approx(sanity.drain_multiplier(), 0.25), "goteo reducido en refugio: %s" % sanity.drain_multiplier())
	check(anim.current_animation == &"CharacterArmature|Idle", "anim idle: %s" % anim.current_animation)
	await shot("01_refugio")
	place(Vector3(15.5, 0.05, 15.5), deg_to_rad(180))
	await frames(20)
	await shot("02_personaje_frente")

	# 2. Goteo afuera
	place(Vector3(0, 0.05, 8), 0.0)
	await frames(10)
	check(not sanity.in_refuge() and sanity.drain_multiplier() == 1.0, "afuera goteo normal")
	var before: float = sanity.current
	await create_timer(1.0).timeout
	check(sanity.current < before, "la cordura baja con el tiempo: %.3f -> %.3f" % [before, sanity.current])

	# 3. Ver horror nuevo (en -12,0,4): parado en (-4,0,4) mirando al oeste (+yaw = izquierda)
	var pre_sight: float = sanity.current
	place(Vector3(-4, 0.05, 4), deg_to_rad(90))
	await frames(40)
	check(sanity.has_seen(&"silueta_alta"), "horror registrado al verlo")
	check(pre_sight - sanity.current > 7.0, "ver horror nuevo baja cordura: %.1f" % (pre_sight - sanity.current))
	place(Vector3(-4, 0.05, 4), deg_to_rad(70))
	await frames(30)
	await shot("03_horror")
	var after_sight: float = sanity.current
	await frames(30)
	check(after_sight - sanity.current < 0.5, "segunda mirada no vuelve a bajar")

	# 4. Golpe
	var pre_hit: float = sanity.current
	sanity.take_hit(10.0)
	await frames(2)
	check(absf(pre_hit - sanity.current - 10.0) < 0.1, "golpe baja 10")
	check(anim.current_animation == &"CharacterArmature|HitRecieve", "anim de golpe: %s" % anim.current_animation)
	await frames(60)

	# 5. Recoger objeto con interact (duraznos sobre Crate1 en 2,1,-2)
	place(Vector3(2, 0.05, -0.9), 0.0)
	await frames(10)
	player._try_interact()
	await frames(5)
	check(inventory.entries.size() == 1, "recogió duraznos: %d entradas" % inventory.entries.size())
	await shot("04_recoger")

	# 6. Usar objetos
	var peaches: ItemData = load("res://assets/items/food_canned_peaches.tres")
	var comic: ItemData = load("res://assets/items/comic_lighthouse.tres")
	var vhs: ItemData = load("res://assets/items/movie_coast_vhs.tres")
	var letter: ItemData = load("res://assets/items/letter_marta_01.tres")
	sanity.current = 50.0
	inventory.use(peaches)
	check(is_equal_approx(sanity.current, 56.0), "comida +6: %.1f" % sanity.current)
	check(inventory.entries.is_empty(), "la comida se consume")
	inventory.add(comic)
	inventory.use(comic)
	var first: float = sanity.current
	inventory.use(comic)
	check(first - 56.0 > sanity.current - first, "cómic rinde menos al releer: +%.1f luego +%.1f" % [first - 56.0, sanity.current - first])
	inventory.add(vhs)
	var msg: String = inventory.use(vhs)
	check(msg.begins_with("Necesito"), "VHS sin electricidad afuera: '%s'" % msg)
	inventory.add(letter)
	inventory.use(letter)
	check(sanity.maximum == 110.0 and sanity.current == 110.0, "carta llena y sube máximo: %.0f/%.0f" % [sanity.current, sanity.maximum])

	# 7. Menú
	inventory.add(peaches, 2)
	var menu: Control = current_scene.get_node("GameUI/GameMenu")
	menu.open()
	check(paused, "menú pausa el juego")
	await shot("05_menu")
	var s_paused: float = sanity.current
	await frames(30)
	check(sanity.current == s_paused, "cordura no baja con el menú abierto")
	menu.item_list.select(inventory.entries.find(inventory.entries.filter(func(e): return e.item == letter)[0]))
	menu._use_selected()
	await shot("06_carta")
	menu.close()

	# 8. Estados y secretos: Inquieto -> símbolo; Quebrado -> la pared desaparece
	var symbol: Node3D = current_scene.get_node("Secrets/WallSymbol")
	var wall: Node3D = current_scene.get_node("Secrets/LyingWall")
	check(not symbol.visible and wall.visible, "lúcido: sin símbolo, pared presente")
	sanity.current = sanity.maximum * 0.6
	sanity.restore(0.0)
	sanity._update_state()
	place(Vector3(-2, 0.05, -11), 0.0)
	await create_timer(3.0).timeout
	check(sanity.state_name() == "Inquieto", "estado inquieto: %s" % sanity.state_name())
	check(symbol.visible and wall.visible, "inquieto: símbolo visible")
	await shot("07_inquieto")
	sanity.take_hit(sanity.current - sanity.maximum * 0.3)
	await create_timer(3.0).timeout
	check(sanity.state_name() == "Quebrado", "estado quebrado: %s" % sanity.state_name())
	check(not wall.visible, "quebrado: la pared que miente desaparece")
	await shot("08_quebrado")
	# el jugador puede atravesar donde estaba la pared
	place(Vector3(-2, 0.05, -14.5), 0.0)
	for i in 90:
		Input.action_press("move_forward")
		await physics_frame
	Input.action_release("move_forward")
	check(player.global_position.z < -16.5, "pasa por el hueco de la pared: z=%.2f" % player.global_position.z)
	sanity.take_hit(sanity.current - sanity.maximum * 0.08)
	await create_timer(3.0).timeout
	check(sanity.state_name() == "Al borde", "estado al borde")
	place(Vector3(0, 0.05, 6), 0.0)
	await frames(20)
	await shot("09_al_borde")

	# 9. Perderse
	sanity.take_hit(1000.0)
	await frames(2)
	check(not sanity.active and sanity.state_name() == "Perdido", "perdido a 0")
	check(anim.current_animation == &"CharacterArmature|Death", "anim de muerte")
	await create_timer(3.0).timeout
	await shot("10_perdido")
	await create_timer(5.0).timeout
	await frames(30)
	check(sanity.active and sanity.current > 99.0 and sanity.maximum == 100.0, "nuevo sobreviviente: %.0f/%.0f" % [sanity.current, sanity.maximum])
	check(inventory.entries.is_empty(), "inventario perdido")
	check(current_scene.get_node("Player") != player and sanity.in_refuge(), "reaparece en el refugio")

	print("RESULT: %d fallas" % fails)
	quit()
