extends SceneTree
## Test del loop completo: refugio, goteo, golpes, mochila en cuadrícula, menú,
## estados/secretos, enemigo, muerte en el refugio (cuerpo) y afuera, y
## persistencia del mundo. Guarda capturas en user://test_shots/.
## Uso: <godot> --path . -s res://tests/sanity_loop_test.gd
## No mover el mouse sobre la ventana mientras corre (gira la cámara).
## No usar class_name del juego acá: este script compila antes que los autoloads.

const OUT := "user://test_shots/"

var sanity: Node
var inventory: Node
var game_state: Node
var health: Node
var fails := 0

var peaches: ItemData = load("res://assets/items/food_canned_peaches.tres")
var comic: ItemData = load("res://assets/items/comic_lighthouse.tres")
var vhs: ItemData = load("res://assets/items/movie_coast_vhs.tres")
var letter: ItemData = load("res://assets/items/letter_marta_01.tres")
var water: ItemData = load("res://assets/items/food_water_bottle.tres")
var pistol: ItemData = load("res://assets/items/weapon_pistol.tres")
var crowbar: ItemData = load("res://assets/items/weapon_crowbar.tres")
var ammo: ItemData = load("res://assets/items/ammo_9mm.tres")


func check(cond: bool, msg: String) -> void:
	print(("OK   " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func seconds(s: float) -> void:
	await create_timer(s).timeout


func shot(name: String) -> void:
	await frames(3)
	root.get_texture().get_image().save_png(OUT + "%s.png" % name)


func player() -> Node3D:
	return current_scene.get_node("Player")


func stalker() -> Node3D:
	return current_scene.get_node("Stalker")


func place(pos: Vector3, yaw: float) -> void:
	var p: Node3D = player()
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.set("_yaw", yaw)
	p.camera_pivot.global_position = pos + Vector3.UP * p.camera_height
	p.visual.global_rotation.y = yaw


func set_ratio(r: float) -> void:
	sanity.restore(sanity.maximum)
	sanity._set_current(sanity.maximum * r)


func send_action(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(2)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await frames(2)


## Ignora el mouse/teclado reales (la ventana del test no debe capturar el mouse).
func isolate_input() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player().set_process_unhandled_input(false)
	player().get_node("Combat").set_process_unhandled_input(false)


## Espera a que termine la acción en curso y el enfriamiento del arma (las animaciones
## tienen duraciones distintas; el test no debe depender de ellas).
func until_ready(combat: Node) -> void:
	await frames(2)
	while player().is_busy() or combat._cooldown > 0.0:
		await physics_frame
	await frames(2)


func freeze_stalker(frozen: bool) -> void:
	# Solo se apaga la IA: deshabilitar el nodo lo sacaría del mundo físico (las balas lo atravesarían).
	stalker().set_physics_process(not frozen)
	freeze_others()


## El resto de los enemigos queda siempre congelado para no interferir.
func freeze_others() -> void:
	for enemy in current_scene.get_tree().get_nodes_in_group(&"enemies"):
		if enemy != stalker():
			enemy.set_physics_process(false)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	# Aislar de los dispositivos reales (ver hospital_tour_test).
	for action in InputMap.get_actions():
		InputMap.action_erase_events(action)
	# Los tests guardan en otro archivo para no pisar la partida del jugador.
	root.get_node("SaveGame").path = "user://test_save.dat"
	sanity = root.get_node("Sanity")
	inventory = root.get_node("Inventory")
	game_state = root.get_node("GameState")
	health = root.get_node("Health")
	# En la sala de prueba el refugio es la misma sala.
	game_state.refuge_scene = "res://scenes/levels/test_room.tscn"
	change_scene_to_file("res://scenes/levels/test_room.tscn")
	await frames(60)
	isolate_input()
	freeze_stalker(true)
	var anim: AnimationPlayer = player().anim_player

	print("-- Refugio y locura")
	check(sanity.in_refuge(), "spawn en refugio")
	check(anim.current_animation == &"CharacterArmature|Idle", "anim idle: %s vel=%s" % [anim.current_animation, player().velocity])
	await shot("01_refugio")
	sanity._set_current(sanity.maximum * 0.8)
	var in_refuge_before: float = sanity.madness()
	await seconds(1.0)
	check(sanity.madness() < in_refuge_before, "en el refugio la locura baja: %.3f -> %.3f" % [in_refuge_before, sanity.madness()])
	place(Vector3(0, 0.05, 8), 0.0)
	await frames(10)
	var before: float = sanity.madness()
	await seconds(1.0)
	check(not sanity.in_refuge() and sanity.madness() > before, "afuera la locura sube: %.3f -> %.3f" % [before, sanity.madness()])
	sanity.restore(1000.0)

	print("-- Golpe")
	var pre_hit: float = sanity.current
	var pre_health: float = health.current
	sanity.take_hit(10.0)
	await frames(2)
	check(absf(pre_health - health.current - 10.0) < 0.1, "golpe baja 10 de vida (Normal)")
	check(absf(pre_hit - sanity.current) < 0.1, "el golpe no toca la locura")
	check(anim.current_animation == &"CharacterArmature|HitRecieve", "anim de golpe")
	await frames(60)

	print("-- Correr y saltar")
	place(Vector3(0, 0.05, 8), 0.0)
	await seconds(0.5)
	Input.action_press("move_forward")
	Input.action_press("run")
	for i in 40:
		await physics_frame
	var run_speed := Vector2(player().velocity.x, player().velocity.z).length()
	check(run_speed > 4.0 and anim.current_animation == &"CharacterArmature|Run", "correr: %.1f m/s, anim %s" % [run_speed, anim.current_animation])
	Input.action_release("run")
	Input.action_release("move_forward")
	await seconds(0.8)
	check(anim.has_animation(&"CharacterArmature|Jump_Idle"), "animaciones de salto importadas del rig del alien")
	var ground_y: float = player().global_position.y
	var max_y := ground_y
	var air_anims := {}
	var ev := InputEventAction.new()
	ev.action = "jump"
	ev.pressed = true
	Input.parse_input_event(ev)
	for i in 70:
		await physics_frame
		max_y = maxf(max_y, player().global_position.y)
		if not player().is_on_floor():
			air_anims[anim.current_animation] = true
		if i == 18:
			await shot("00_salto")
	var ev_up := InputEventAction.new()
	ev_up.action = "jump"
	ev_up.pressed = false
	Input.parse_input_event(ev_up)
	check(max_y - ground_y > 0.6, "salta %.2f m" % (max_y - ground_y))
	check(player().is_on_floor(), "vuelve al piso")
	check(air_anims.has(&"CharacterArmature|Jump") or air_anims.has(&"CharacterArmature|Jump_Idle"), "anim de salto en el aire: %s" % [air_anims.keys()])

	print("-- Agacharse y sigilo")
	var p := player()
	place(Vector3(0, 0.05, 8), 0.0)
	await seconds(0.5)
	check(p.set_crouching(true) and p.is_crouching, "se agacha")
	check(is_equal_approx((p.body_shape.shape as CapsuleShape3D).height, 1.2), "la cápsula se achica")
	await frames(10)
	check(anim.current_animation == &"CrouchIdle", "pose agachada: %s" % anim.current_animation)
	Input.action_press("move_forward")
	for i in 40:
		await physics_frame
	var crouch_speed := Vector2(p.velocity.x, p.velocity.z).length()
	check(crouch_speed < 1.4 and anim.current_animation == &"CrouchWalk", "camina agachado: %.1f m/s, %s" % [crouch_speed, anim.current_animation])
	await shot("00_agachado")
	Input.action_release("move_forward")
	var ev_run := InputEventAction.new()
	ev_run.action = "run"
	ev_run.pressed = true
	Input.parse_input_event(ev_run)
	await frames(3)
	var ev_run_up := InputEventAction.new()
	ev_run_up.action = "run"
	Input.parse_input_event(ev_run_up)
	await frames(3)
	check(not p.is_crouching, "correr lo pone de pie")
	# Techo bajo: no se puede parar.
	place(Vector3(0, 0.05, 8), 0.0)
	await frames(5)
	p.set_crouching(true)
	var low := StaticBody3D.new()
	var low_shape := CollisionShape3D.new()
	low_shape.shape = BoxShape3D.new()
	(low_shape.shape as BoxShape3D).size = Vector3(2, 0.1, 2)
	low.add_child(low_shape)
	current_scene.add_child(low)
	low.global_position = Vector3(0, 1.45, 8)
	await physics_frame
	await physics_frame
	check(not p.set_crouching(false) and p.is_crouching, "con techo bajo no se puede parar")
	low.queue_free()
	await physics_frame
	await physics_frame
	# Detección: el acechador en (0,0,0) mirando hacia +Z (hacia el jugador).
	var watcher: Node3D = stalker()
	watcher.global_position = Vector3(0, 0.05, 0)
	watcher.visual.global_rotation.y = 0.0
	p.set_crouching(false)
	place(Vector3(0, 0.05, 7), 0.0)
	await physics_frame
	check(watcher._perceives(p), "parado a 7 m: lo ve")
	p.set_crouching(true)
	check(not watcher._perceives(p), "agachado a 7 m: no lo ve")
	p.flashlight.visible = true
	check(watcher._perceives(p), "agachado a 7 m con la linterna prendida: lo ve")
	p.flashlight.visible = false
	place(Vector3(0, 0.05, 4), 0.0)
	await physics_frame
	check(watcher._perceives(p), "agachado a 4 m al descubierto: lo ve")
	var cover := StaticBody3D.new()
	var cover_shape := CollisionShape3D.new()
	cover_shape.shape = BoxShape3D.new()
	(cover_shape.shape as BoxShape3D).size = Vector3(2, 1.5, 0.3)
	cover.add_child(cover_shape)
	current_scene.add_child(cover)
	cover.global_position = Vector3(0, 0.75, 2.5)
	await physics_frame
	await physics_frame
	check(not watcher._perceives(p), "agachado detrás de algo bajo: no lo ve")
	p.set_crouching(false)
	check(watcher._perceives(p), "parado detrás de lo mismo: lo ve")
	cover.queue_free()
	watcher.global_position = Vector3(10, 0.05, -8)
	await frames(3)

	print("-- Recoger")
	place(Vector3(2, 0.05, -0.9), 0.0)
	await frames(10)
	player()._try_interact()
	await frames(5)
	check(inventory.entries.size() == 1, "recogió duraznos")
	check(game_state.is_collected("/root/TestRoom/Items/Peaches1"), "pickup marcado como recogido")

	print("-- Mochila en cuadrícula")
	inventory.clear()
	var added := 0
	for i in 30:
		if inventory.add(peaches):
			added += 1
	check(added == 24, "mochila 6x4 llena con 24 objetos 1x1: %d" % added)
	inventory.clear()
	check(inventory.add(vhs) and inventory.add(comic) and inventory.add(water), "entran VHS 2x1, cómic 1x2 y agua 1x2")
	var e_vhs: Dictionary = inventory.entries[0]
	check(e_vhs.cell == Vector2i(0, 0) and inventory.entry_at(Vector2i(1, 0)) == e_vhs, "VHS ocupa (0,0)-(1,0)")
	var e_comic: Dictionary = inventory.entries[1]
	check(e_comic.cell == Vector2i(2, 0) and inventory.entry_at(Vector2i(2, 1)) == e_comic, "cómic ocupa (2,0)-(2,1)")
	check(not inventory.move(e_vhs, Vector2i(2, 1), false), "no se puede mover encima de otro")
	check(inventory.move(e_vhs, Vector2i(5, 1), true), "VHS girado entra vertical en la columna 5")
	check(inventory.footprint(vhs, true) == Vector2i(1, 2), "girado ocupa 1x2")
	inventory.letters.clear()
	inventory.add(letter)
	check(inventory.letters.size() == 1 and inventory.entries.size() == 3, "la carta va aparte, no ocupa lugar")
	# Tirar: aparece en el piso y se puede volver a juntar.
	place(Vector3(0, 0.05, 8), 0.0)
	await frames(5)
	inventory.drop(inventory.entries[2])
	await frames(5)
	check(game_state.dropped_items.size() == 1 and inventory.entries.size() == 2, "tirar el agua la deja en el mundo")
	var dropped: Node = current_scene.get_node("WorldPersistence").get_child(0)
	check(dropped != null and dropped.item == water, "pickup del agua en el piso")
	player()._try_interact()
	await frames(5)
	check(game_state.dropped_items.is_empty() and inventory.entries.size() == 3, "se vuelve a juntar")
	# Mochila llena: el objeto queda en el piso.
	inventory.clear()
	for i in 24:
		inventory.add(peaches)
	inventory.drop(inventory.entries[0])
	await frames(5)
	inventory.add(peaches)
	player()._try_interact()
	await frames(5)
	check(game_state.dropped_items.size() == 1, "con la mochila llena no se puede juntar")

	print("-- Usar objetos")
	inventory.clear()
	inventory.add(peaches)
	sanity.restore(100.0)
	sanity._set_current(50.0)
	var s0: float = sanity.current
	inventory.use(peaches, inventory.entries[0])
	check(absf(sanity.current - s0 - 6.0) < 0.1 and inventory.entries.is_empty(), "comida +6 y se consume")
	inventory.add(comic)
	var s1: float = sanity.current
	inventory.use(comic)
	var gain1: float = sanity.current - s1
	var s2: float = sanity.current
	inventory.use(comic)
	check(gain1 > sanity.current - s2 + 1.0, "cómic rinde menos al releer")
	inventory.add(vhs)
	check((inventory.use(vhs) as String).begins_with("Necesito"), "VHS sin electricidad afuera no se puede ver")

	print("-- Menú (entrada real)")
	inventory.clear()
	inventory.add(vhs)
	inventory.add(comic)
	inventory.add(peaches)
	inventory.add(water)
	inventory.add(letter)
	var menu: Control = current_scene.get_node("GameUI/GameMenu")
	await send_action("menu")
	check(menu.visible and paused, "Tab abre el menú y pausa")
	await shot("02_menu")
	# Mover el VHS de (0,0) a (0,2) con R, abajo x2, R.
	await send_action("inventory_move")
	check(menu.grid.is_holding(), "R agarra el objeto")
	await send_action("ui_down")
	await send_action("ui_down")
	await shot("03_menu_moviendo")
	await send_action("inventory_move")
	check(not menu.grid.is_holding() and inventory.entry_at(Vector2i(0, 2)).get("item") == vhs, "el VHS quedó en (0,2)")
	await send_action("ui_down")
	await send_action("ui_down")
	check(menu._section == 1, "bajando se llega a las cartas")
	await send_action("ui_accept")
	check(menu.letter_panel.visible and sanity.maximum == 110.0, "leer la carta: +10 máximo")
	await shot("04_carta")
	await send_action("interact")
	await send_action("menu")
	check(not menu.visible and not paused, "Tab cierra y despausa")

	print("-- Estados, secretos y alucinación")
	var symbol: Node3D = current_scene.get_node("Secrets/WallSymbol")
	var wall: Node3D = current_scene.get_node("Secrets/LyingWall")
	var hallucination: Node3D = current_scene.get_node("Hallucination")
	set_ratio(0.9)
	await frames(2)
	check(not symbol.visible and wall.visible and not hallucination.visible, "lúcido: sin símbolo ni alucinación")
	set_ratio(0.6)
	await frames(2)
	check(sanity.state_name() == "Inquieto" and symbol.visible and hallucination.visible, "inquieto: símbolo y alucinación")
	var pre_sight: float = sanity.current
	place(Vector3(-4, 0.05, 4), deg_to_rad(70))
	await frames(40)
	check(sanity.has_seen(&"silueta_alta") and pre_sight - sanity.current > 7.0, "ver la silueta baja cordura")
	await seconds(2.0)
	await shot("05_inquieto_silueta")
	set_ratio(0.3)
	await frames(2)
	check(sanity.state_name() == "Quebrado" and not wall.visible, "quebrado: la pared desaparece")
	place(Vector3(-2, 0.05, -14.5), 0.0)
	await seconds(1.0)  # que termine la animación de golpe de set_ratio
	print("   antes: pos=%s yaw=%s lock=%s ctrl=%s" % [player().global_position, player()._yaw, player()._action_lock, player().can_control])
	for i in 90:
		Input.action_press("move_forward")
		await physics_frame
		if i % 30 == 0: print("   i=%d pos=%s vel=%s" % [i, player().global_position, player().velocity])
	Input.action_release("move_forward")
	check(player().global_position.z < -16.5, "pasa por el hueco: z=%.2f" % player().global_position.z)

	print("-- Enemigo")
	set_ratio(0.95)
	await seconds(2.5)
	var st: Node3D = stalker()
	st.global_position = Vector3(8, 0.05, -2)
	freeze_stalker(false)
	# El jugador 7 m al sur (+Z), y el acechador mirándolo.
	place(Vector3(8, 0.05, 5), 0.0)
	st.visual.global_rotation.y = 0.0
	await frames(20)
	check(st.state != 0, "el acechador ve al jugador y persigue")
	check(sanity.has_seen(&"delgado"), "ver al acechador por primera vez baja cordura")
	await seconds(0.6)
	await shot("06_acechador")
	var pre_attack: float = health.current
	await seconds(3.5)
	check(pre_attack - health.current >= 11.0, "el acechador golpea (vida): -%.1f" % (pre_attack - health.current))
	await shot("07_golpe")
	# Escapar corriendo: se alejan y termina perdiéndolo.
	freeze_stalker(true)
	st.global_position = Vector3(10, 0.05, -8)
	st.state = 0

	print("-- Combate: pistola")
	sanity.restore(1000.0)
	await seconds(1.5)
	var combat: Node = player().get_node("Combat")
	inventory.clear()
	inventory.add(pistol)
	for i in 10:
		inventory.add(ammo)
	var e_pistol: Dictionary = inventory.entries[0]
	check(e_pistol.loaded == 8 and inventory.ammo_count(ammo) == 10 and inventory.entries.size() == 2, "pistola cargada (8) y 10 balas apiladas")
	inventory.use(pistol, e_pistol)
	check(inventory.is_equipped(e_pistol) and combat._held_model != null, "pistola equipada y en la mano")
	# Acechador congelado 7 m al frente.
	st.global_position = Vector3(8, 0.05, -2)
	place(Vector3(8, 0.05, 5), 0.0)
	await frames(5)
	Input.action_press("aim")
	await frames(10)
	check(combat.aiming and combat.target == st, "apuntar engancha al acechador")
	check(player().anim_player.current_animation == &"CharacterArmature|Idle_Gun_Pointing", "pose de apuntar")
	await shot("10_apuntando")
	# Cordura por debajo del máximo (pero lúcido) para ver la recompensa al matar.
	sanity.restore(1000.0)
	sanity._set_current(sanity.maximum * 0.8)
	var pre_kill: float = sanity.current
	var shots_fired := 0
	for i in 8:
		if st.is_dead():
			break
		combat.attack()
		shots_fired += 1
		if i == 0:
			await frames(4)
			await shot("11_disparo")
		await until_ready(combat)
	Input.action_release("aim")
	check(st.is_dead() and shots_fired == 4, "4 tiros matan al acechador (%d)" % shots_fired)
	check(e_pistol.loaded == 4, "quedan 4 en el cargador: %d" % e_pistol.loaded)
	check(sanity.current - pre_kill > 3.5, "matar un horror devuelve cordura: +%.1f" % (sanity.current - pre_kill))
	check(game_state.is_killed("/root/TestRoom/Stalker"), "muerte registrada en GameState")
	await seconds(1.5)
	await shot("12_acechador_muerto")
	await until_ready(combat)
	combat.reload()
	await until_ready(combat)
	check(e_pistol.loaded == 8 and inventory.ammo_count(ammo) == 6, "recargar: 8 cargadas, 6 en la mochila")
	# Sin balas: aviso.
	e_pistol.loaded = 0
	inventory.take_ammo(ammo, 100)
	Input.action_press("aim")
	await frames(5)
	combat.attack()
	await frames(3)
	Input.action_release("aim")
	check(current_scene.get_node("GameUI").pickup_label.text == "Está vacía.", "sin balas avisa")
	# Los disparos se oyen.
	var other: Node3D = current_scene.get_node("Stalker2")
	other.hear_noise(other.global_position + Vector3(10, 0, 0), 20.0)
	check(other.state == 1, "un disparo cercano pone a perseguir")
	other.state = 0

	print("-- Combate: barreta")
	await seconds(0.8)
	inventory.add(crowbar)
	var e_bar: Dictionary = inventory.entries.filter(func(e): return e.item == crowbar)[0]
	inventory.use(crowbar, e_bar)
	check(inventory.is_equipped(e_bar) and not inventory.is_equipped(e_pistol), "barreta equipada (reemplaza la pistola)")
	other.global_position = Vector3(8, 0.05, 3.8)
	place(Vector3(8, 0.05, 5), 0.0)
	await frames(10)
	var swings := 0
	for i in 8:
		if other.is_dead():
			break
		combat.attack()
		swings += 1
		if i == 0:
			await seconds(0.3)
			await shot("13_barretazo")
		await until_ready(combat)
	check(other.is_dead() and swings == 4, "4 barretazos matan (%d)" % swings)
	# Guardar el arma: mano vacía.
	inventory.use(crowbar, e_bar)
	check(inventory.equipped.is_empty() and combat._held_model == null, "guardar deja las manos vacías")

	print("-- Muerte en el refugio")
	sanity.restore(1000.0)
	inventory.clear()
	inventory.add(comic)
	inventory.add(peaches)
	place(Vector3(15.5, 0.05, 13.5), 0.0)
	await frames(10)
	print("   pos=%s active=%s state=%s ctrl=%s cordura=%.1f" % [player().global_position, sanity.active, sanity.state_name(), player().can_control, sanity.current])
	check(sanity.in_refuge(), "en el refugio")
	var old_player: Node3D = player()
	sanity.add_madness(10000.0)
	await frames(2)
	check(sanity.lost_in_refuge and old_player.anim_player.current_animation == &"CharacterArmature|Death", "muere en el refugio")
	await seconds(3.5)
	check(current_scene.get_node("GameUI").lost_label.text.begins_with("Su corazón"), "texto de ataque cardíaco")
	await shot("08_corazon")
	await seconds(4.5)
	await frames(30)
	isolate_input()
	check(not current_scene.has_node("Stalker") and not current_scene.has_node("Stalker2"), "los enemigos muertos no reaparecen")
	check(player() != old_player and game_state.survivor_number == 2, "nuevo sobreviviente #2")
	check(inventory.entries.is_empty() and sanity.maximum == 100.0, "sin inventario y cordura base")
	check(game_state.corpses.size() == 1 and game_state.corpses[0].items.size() == 2, "cuerpo con 2 objetos")
	var corpse: Array[Node] = current_scene.get_node("WorldPersistence").find_children("*", "Corpse", false, false)
	check(corpse.size() == 1, "el cuerpo está en el piso")
	check(not current_scene.has_node("Items/Peaches1"), "los duraznos recogidos no reaparecen")
	place(Vector3(15.5, 0.05, 14.6), deg_to_rad(180))
	await frames(10)
	await shot("09_cuerpo")
	player()._try_interact()
	await frames(5)
	check(inventory.entries.size() == 2 and game_state.corpses[0].items.is_empty(), "recupera las cosas del cuerpo")

	print("-- Muerte afuera")
	place(Vector3(0, 0.05, 8), 0.0)
	await frames(10)
	sanity.add_madness(10000.0)
	await frames(2)
	check(not sanity.lost_in_refuge, "se pierde afuera")
	await seconds(8.0)
	await frames(30)
	check(game_state.corpses.size() == 1 and game_state.lost_ones.size() == 1, "afuera no deja cuerpo: queda registrado para el Perdido")
	check(game_state.survivor_number == 3 and sanity.in_refuge(), "sobreviviente #3 en el refugio")

	print("-- El Perdido")
	var lost_nodes: Array[Node] = current_scene.get_node("WorldPersistence").find_children("*", "LostOne", false, false)
	check(lost_nodes.size() == 1, "el Perdido vaga donde cayó el #2")
	if lost_nodes.size() == 1:
		var lost: Node3D = lost_nodes[0]
		check(lost.global_position.distance_to(Vector3(0, 0, 8)) < 3.0, "aparece cerca de donde se perdió: %s" % lost.global_position)
		check(lost.items.size() == 2 and lost.style_name() == "errante", "lleva sus 2 objetos, estilo %s" % lost.style_name())
		check(lost.dominant_style({&"shots": 12.0}) == 1 and lost.dominant_style({&"crouch_time": 60.0}) == 4, "estilo según cómo se jugó")
		lost.set_physics_process(false)
		place(lost.global_position + Vector3(0, 0.05, 2.5), 0.0)
		await frames(10)
		await shot("10_perdido")
		var sanity_before: float = sanity.current
		var pickups_before: int = current_scene.get_node("WorldPersistence").find_children("*", "Pickup", false, false).size()
		lost.take_damage(10000.0)
		await frames(5)
		check(game_state.lost_ones[0].defeated and sanity.current > sanity_before, "matarlo lo hace descansar y da cordura")
		var loot: int = current_scene.get_node("WorldPersistence").find_children("*", "Pickup", false, false).size() - pickups_before
		check(loot == 2, "suelta lo que llevaba (%d)" % loot)

	print("-- Dificultad según la locura")
	sanity.restore(1000.0)
	health.reset()
	check(sanity.difficulty == 0 and sanity.difficulty_name() == "Normal", "lúcido: Normal")
	var spawn: Marker3D = Marker3D.new()
	spawn.set_script(load("res://scripts/world/difficulty_spawn.gd"))
	spawn.set("enemy_scene", load("res://scenes/enemies/stalker.tscn"))
	spawn.set("min_difficulty", 2)
	spawn.set("min_spawn_distance", 2.0)
	spawn.position = player().global_position + Vector3(0, 0, -6)
	current_scene.add_child(spawn)
	await frames(3)
	check(spawn.get_child_count() == 0, "en Normal no hay enemigo extra")
	sanity._set_current(sanity.maximum * 0.4)
	check(sanity.difficulty == 1 and is_equal_approx(sanity.player_damage_multiplier(), 0.8), "60 %% de locura: Difícil, pega x0.8")
	var hp: float = health.current
	sanity.take_hit(10.0)
	check(absf(hp - health.current - 13.5) < 0.1, "en Difícil un golpe de 10 saca 13.5")
	sanity._set_current(sanity.maximum * 0.2)
	await frames(5)
	check(sanity.difficulty == 2 and sanity.difficulty_name() == "Insane", "80 %% de locura: Insane")
	check(spawn.get_child_count() == 1, "en Insane aparece el enemigo extra")
	await shot("11_insane_hud")
	spawn.get_child(0).set_physics_process(false)

	print("-- Muerte por daño")
	sanity.restore(1000.0)
	place(Vector3(0, 0.05, 6), 0.0)
	await frames(10)
	inventory.add(peaches)
	var corpses_before: int = game_state.corpses.size()
	var lost_before: int = game_state.lost_ones.size()
	sanity.take_hit(10000.0)
	await frames(2)
	check(not health.alive and not sanity.active, "vida en 0: muere")
	await seconds(3.5)
	check(current_scene.get_node("GameUI").lost_label.text.begins_with("Moriste"), "texto de muerte")
	await seconds(4.5)
	await frames(30)
	check(game_state.corpses.size() == corpses_before + 1 and game_state.lost_ones.size() == lost_before,
		"muerto por daño deja el cuerpo (no un Perdido)")
	check(health.alive and is_equal_approx(health.current, health.maximum), "el nuevo sobreviviente llega con la vida llena")

	print("RESULT: %d fallas" % fails)
	quit()
