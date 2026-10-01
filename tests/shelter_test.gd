extends SceneTree
## Test del refugio (blueprint): materiales, bono de llegar a casa, mejoras,
## estaciones (cocinar, descansar, radio, TV) y persistencia tras la muerte.
## Capturas en user://test_shots/shelter/.
## Uso: <godot> --path . -s res://tests/shelter_test.gd
## No usar class_name del juego acá (compila antes que los autoloads).

const OUT := "user://test_shots/shelter/"
const REFUGE_POS := Vector3(30.0, 0.05, 3.6)

var fails := 0
var sanity: Node
var inventory: Node
var shelter: Node

var wood: ItemData = load("res://assets/items/material_wood.tres")
var metal: ItemData = load("res://assets/items/material_metal.tres")
var cloth: ItemData = load("res://assets/items/material_cloth.tres")
var cable: ItemData = load("res://assets/items/material_cable.tres")
var peaches: ItemData = load("res://assets/items/food_canned_peaches.tres")
var vhs: ItemData = load("res://assets/items/movie_coast_vhs.tres")


func check(cond: bool, msg: String) -> void:
	print(("OK   " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func player() -> Node3D:
	return current_scene.get_node("Player")


func place(pos: Vector3, yaw_deg := 0.0, pitch_deg := -12.0) -> void:
	var p := player()
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.set("_yaw", deg_to_rad(yaw_deg))
	p.set("_pitch", deg_to_rad(pitch_deg))
	p.camera_pivot.global_position = pos + Vector3.UP * p.camera_height
	p.visual.global_rotation.y = deg_to_rad(yaw_deg)
	await frames(6)


func shot(name: String) -> void:
	await frames(10)
	root.get_texture().get_image().save_png(OUT + "%s.png" % name)


func isolate() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player().set_process_unhandled_input(false)
	player().get_node("Combat").set_process_unhandled_input(false)
	for enemy in get_nodes_in_group(&"enemies"):
		enemy.set_physics_process(false)


func slot_part(slot: String, part: String) -> Node3D:
	return current_scene.get_node("Refuge/%s/%s" % [slot, part])


func message() -> String:
	return current_scene.get_node("GameUI").pickup_label.text


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	# Aislar de los dispositivos reales (ver hospital_tour_test).
	for action in InputMap.get_actions():
		InputMap.action_erase_events(action)
	# Los tests guardan en otro archivo para no pisar la partida del jugador.
	root.get_node("SaveGame").path = "user://test_save.dat"
	sanity = root.get_node("Sanity")
	inventory = root.get_node("Inventory")
	shelter = root.get_node("Shelter")
	change_scene_to_file("res://scenes/levels/hospital.tscn")
	await frames(90)
	isolate()

	print("-- Refugio pelado")
	check(sanity.in_refuge() and shelter.cozy() == 0, "arranca en el refugio, cozy 0")
	check(is_equal_approx(sanity.drain_multiplier(), 0.6), "goteo sin mejoras x0.6: %.2f" % sanity.drain_multiplier())
	check(not sanity.has_electricity(), "sin electricidad (generador roto)")
	check(slot_part("SlotBed", "Only0").visible and not slot_part("SlotPower", "From1").visible, "colchón en el piso, luces apagadas")
	inventory.add(vhs)
	check((inventory.use(vhs) as String).begins_with("Necesito"), "sin electricidad no hay película")
	await place(Vector3(27.0, 0.05, 6.8), -60.0)
	await shot("01_refugio_pelado")

	print("-- Salida y regreso")
	await place(Vector3(20.0, 0.05, 9.5))
	check(not sanity.in_refuge(), "salió del refugio")
	await place(Vector3(15.0, 0.05, 15.0))
	check(shelter.discovered.has(&"pb_lobby"), "descubrió el hall")
	for i in 3:
		inventory.add(wood)
	for i in 2:
		inventory.add(cable)
	inventory.add(metal)
	check(inventory.entries.filter(func(e): return e.item == wood)[0].count == 3, "la madera se apila en la mochila")
	sanity._set_current(50.0)
	var before: float = sanity.current
	await place(REFUGE_POS)
	check(sanity.in_refuge(), "volvió al refugio")
	check(shelter.stock[&"material_wood"] == 0 and inventory.entries.any(func(e): return e.item == wood),
		"los materiales no se guardan solos")
	check(sanity.current - before > 10.0, "bono de llegar a casa: +%.1f" % (sanity.current - before))
	check(message().contains("alijo"), "aviso de dejarlos en el alijo: '%s'" % message())

	print("-- Alijo")
	var stash_menu: Control = current_scene.get_node("GameUI/StashMenu")
	check(slot_part("SlotStash", "Only0").visible, "el alijo arranca como una caja de cartón")
	await place(Vector3(34.1, 0.05, 5.4), -90.0)
	player()._try_interact()
	await frames(3)
	check(stash_menu.visible and paused, "la caja abre el alijo y pausa")
	stash_menu.store_materials()
	await frames(2)
	check(shelter.stock[&"material_wood"] == 3 and shelter.stock[&"material_cable"] == 2 and shelter.stock[&"material_metal"] == 1,
		"X deja los materiales para construir: %s" % shelter.stock)
	check(inventory.entries.filter(func(e): return e.item.is_material()).is_empty(), "la mochila quedó sin materiales")
	# Guardar el VHS (es lo único que queda en la mochila) y volver a sacarlo.
	stash_menu.transfer()
	await frames(2)
	check(shelter.stash.size() == 1 and shelter.stash[0].item == vhs and inventory.entries.is_empty(), "el VHS quedó en el alijo")
	await shot("01b_alijo")
	stash_menu._side = 1
	stash_menu.transfer()
	await frames(2)
	check(shelter.stash.is_empty() and inventory.entries.size() == 1, "y se puede volver a sacar")
	# Capacidad: 8 lugares en la caja; las pilas ocupan uno.
	inventory.clear()
	for i in 9:
		inventory.add_entry({"item": vhs, "count": 1})
	stash_menu._side = 0
	for i in 9:
		stash_menu._index[0] = 0
		stash_menu.transfer()
	check(shelter.stash_used() == 8 and inventory.entries.size() == 1, "la caja de cartón tiene 8 lugares")
	check(stash_menu.result_label.text.begins_with("El alijo está lleno"), "avisa que está lleno")
	stash_menu.close()
	await frames(3)
	shelter.stash.clear()
	inventory.clear()
	inventory.add(vhs)
	# Salir y volver sin lograr nada: no hay bono (no se puede farmear).
	await place(Vector3(20.0, 0.05, 9.5))
	var s0: float = sanity.current
	await place(REFUGE_POS)
	check(sanity.current <= s0 + 0.01, "entrar y salir sin nada no da bono")

	print("-- Plano y mejoras")
	var menu: Control = current_scene.get_node("GameUI/ShelterMenu")
	await place(Vector3(33.0, 0.05, 6.8), 180.0)
	player()._try_interact()
	await frames(3)
	check(menu.visible and paused, "el plano abre el menú y pausa")
	await shot("02_plano")
	var ev := InputEventAction.new()
	ev.action = "ui_accept"
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(3)
	check(shelter.level(&"fire") == 1 and shelter.stock[&"material_wood"] == 0, "construyó la fogata (3 madera)")
	check(shelter.cozy() == 1 and sanity.drain_multiplier() < 0.6, "cozy 1, goteo x%.2f" % sanity.drain_multiplier())
	menu._select(1)
	Input.parse_input_event(ev)
	await frames(3)
	check(shelter.level(&"power") == 1 and sanity.has_electricity(), "generador reparado: hay electricidad")
	menu._select(2)
	Input.parse_input_event(ev)
	await frames(3)
	check(shelter.level(&"bed") == 0 and menu.get_node("%ShelterResult").text.begins_with("Me faltan"), "sin materiales no se construye")
	menu.close()
	await frames(3)
	check(slot_part("SlotFire", "Only1").visible and slot_part("SlotPower", "From1").visible, "se ven la fogata y las luces")
	check((inventory.use(vhs) as String) != "" and not (inventory.use(vhs) as String).begins_with("Necesito"), "con luz se puede ver la película")
	await place(Vector3(27.0, 0.05, 6.8), -60.0)
	await shot("03_refugio_fuego_luz")

	print("-- Estaciones")
	inventory.add(peaches)
	await place(Vector3(28.4, 0.05, 3.6), 0.0)
	player()._try_interact()
	await frames(3)
	var e_food: Dictionary = inventory.entries.filter(func(e): return e.item == peaches)[0]
	check(e_food.get("cooked", false), "cocinó los duraznos en la fogata")
	sanity._set_current(40.0)
	var s1: float = sanity.current
	inventory.use(peaches, e_food)
	check(absf(sanity.current - s1 - 6.0 * shelter.cooked_multiplier) < 0.3, "comida caliente rinde x%.1f: +%.1f" % [shelter.cooked_multiplier, sanity.current - s1])
	check((shelter.rest() as String).begins_with("En este colchón"), "no se descansa en el colchón")
	for id in shelter.stock:
		shelter.stock[id] = 20
	for slot in shelter.SLOT_ORDER:
		while shelter.upgrade(slot):
			pass
	check(shelter.cozy() == shelter.cozy_max(), "refugio completo: cozy %d/%d" % [shelter.cozy(), shelter.cozy_max()])
	check(shelter.stash_capacity_now() == 28, "el alijo mejorado (armario) tiene 28 lugares")
	check(is_equal_approx(sanity.drain_multiplier(), 0.1), "goteo con el refugio completo x%.2f" % sanity.drain_multiplier())
	var s2: float = sanity.current
	check((shelter.rest() as String).begins_with("Dormí") and sanity.current - s2 > 9.0, "descansar en la cama con mantas: +%.1f" % (sanity.current - s2))
	check((shelter.rest() as String).begins_with("No tengo sueño"), "descansar tiene enfriamiento")
	var s3: float = sanity.current
	check((shelter.play_radio() as String).begins_with("Un tango") and sanity.current > s3, "la radio suena con la instalación prolija")
	await frames(5)
	check(slot_part("SlotWindows", "Only2").visible and slot_part("SlotDecor", "From2").visible, "cortinas, plantas y alfombra")
	check(slot_part("SlotStash", "Only2").visible and not slot_part("SlotStash", "Only0").visible, "el alijo ahora es un armario")
	await place(Vector3(27.0, 0.05, 6.8), -60.0)
	await shot("04_refugio_completo")
	await place(Vector3(34.5, 0.05, 6.5), -130.0)
	await shot("05_refugio_completo_b")

	print("-- Persistencia")
	sanity.take_hit(10000.0)
	await create_timer(8.0).timeout
	await frames(60)
	isolate()
	check(shelter.cozy() == shelter.cozy_max() and slot_part("SlotBed", "Only2").visible, "las mejoras sobreviven al sobreviviente")
	check(shelter.discovered.has(&"pb_lobby"), "los lugares descubiertos se recuerdan")

	print("RESULT: %d fallas" % fails)
	quit()
