class_name PlayerCombat
extends Node
## Combate del jugador. Armas de fuego: mantener "aim" (quieto, auto-apuntado al
## enemigo más cercano frente a la cámara, estilo Silent Hill) y "attack" para
## disparar; "reload" recarga con munición de la mochila. Cuerpo a cuerpo (o a
## mano limpia sin arma): "attack" golpea en arco hacia adelante.
## La locura empeora la puntería (la dispersión crece) y, según la dificultad,
## el jugador pega menos (`Sanity.player_damage_multiplier`).

const ANIM_AIM := SurvivorRig.AIM
const ANIM_SHOOT := SurvivorRig.SHOOT
const ANIM_SLASH := SurvivorRig.MELEE
const ANIM_PUNCH := SurvivorRig.PUNCH
const ANIM_RELOAD := SurvivorRig.RELOAD
const HAND_BONE := SurvivorRig.HAND_BONE

@export_group("Apuntar")
@export var auto_aim_range := 20.0
@export_range(0.0, 90.0) var auto_aim_angle := 35.0
## Dispersión del disparo (grados) lúcido y al borde de la locura.
@export var sane_spread := 1.0
@export var insane_spread := 12.0
@export var aim_camera_distance := 1.5
@export var aim_turn_speed := 14.0

@export_group("Cuerpo a cuerpo")
## Momento del golpe dentro de la animación.
@export var melee_hit_time := 0.4
@export_range(0.0, 180.0) var melee_half_angle := 70.0
## Velocidad de la animación del golpe con arma (1 = la original, ~1 s).
@export var melee_anim_speed := 1.2
@export var unarmed_damage := 6.0
@export var unarmed_range := 1.3
@export var unarmed_cooldown := 0.85

@export_group("Efectos")
@export var muzzle_flash_time := 0.06
## Color del otro lado (el brillo del arma y la onda del empujón).
@export var power_color := Color(0.55, 0.25, 1.0)

var aiming := false
## Enemigo al que apunta el auto-apuntado (o null).
var target: Node3D = null

var _cooldown := 0.0
var _default_camera_distance := 0.0
var _held_attachment: BoneAttachment3D
var _held_model: Node3D
var _muzzle_flash: OmniLight3D
var _held_materials: Array[ShaderMaterial] = []
## Brillo del Filo del otro lado: una luz en la mano y el arma que emite.
var _aura: OmniLight3D
var _aura_boost := 0.0

@onready var player: Player = get_parent()


## Lo llama Player en su _ready (los @onready del padre no existen en el _ready del hijo).
func setup() -> void:
	_default_camera_distance = player.spring_arm.spring_length
	var skeleton := player.model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_held_attachment = BoneAttachment3D.new()
	_held_attachment.bone_name = HAND_BONE
	skeleton.add_child(_held_attachment)
	_muzzle_flash = OmniLight3D.new()
	_muzzle_flash.light_color = Color(1.0, 0.8, 0.5)
	_muzzle_flash.light_energy = 4.0
	_muzzle_flash.omni_range = 6.0
	_muzzle_flash.position = Vector3(0.2, 1.45, -0.7)
	_muzzle_flash.visible = false
	player.visual.add_child(_muzzle_flash)
	_aura = OmniLight3D.new()
	_aura.light_color = power_color
	_aura.light_energy = 0.0
	_aura.omni_range = 1.8
	_aura.visible = false
	_held_attachment.add_child(_aura)
	Inventory.equipped_changed.connect(_on_equipped_changed)
	_on_equipped_changed(Inventory.equipped)


func _unhandled_input(event: InputEvent) -> void:
	if not player.can_control:
		return
	# El clic que recaptura el mouse no cuenta como ataque.
	if event is InputEventMouseButton and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event.is_action_pressed("attack"):
		attack()
	elif event.is_action_pressed("reload"):
		reload()
	elif event.is_action_pressed("power_1"):
		use_power(Powers.EMPOWER)
	elif event.is_action_pressed("power_2"):
		use_power(Powers.PUSH)


## Lo llama Player en cada frame de física, antes de moverse.
func physics_update(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	var weapon := Inventory.equipped_item()
	aiming = player.can_control and weapon != null and weapon.is_ranged and Input.is_action_pressed("aim")
	target = _find_target() if aiming else null
	if aiming:
		var aim_at := target.global_position if target else player.global_position + _camera_forward()
		_face(aim_at, aim_turn_speed, delta)
	var camera_distance := aim_camera_distance if aiming else _default_camera_distance
	player.spring_arm.spring_length = lerpf(player.spring_arm.spring_length, camera_distance, 1.0 - exp(-10.0 * delta))
	_update_aura()


func attack() -> void:
	if _cooldown > 0.0 or player.is_busy():
		return
	var weapon := Inventory.equipped_item()
	if weapon == null:
		_melee(unarmed_damage, unarmed_range, unarmed_cooldown, ANIM_PUNCH)
	elif weapon.is_ranged:
		if aiming:
			_shoot(weapon)
	else:
		_melee(weapon.damage, weapon.attack_range, weapon.attack_cooldown, ANIM_SLASH, melee_anim_speed)


func reload() -> void:
	var weapon := Inventory.equipped_item()
	if weapon == null or not weapon.is_ranged or player.is_busy():
		return
	if Inventory.equipped.loaded >= weapon.magazine_size:
		return
	if Inventory.ammo_count(weapon.ammo_item) == 0:
		GameState.post_message("No me quedan balas.")
		return
	player.play_action(ANIM_RELOAD)
	Audio.play_sfx(weapon.reload_sound, player.global_position)
	Inventory.reload_equipped()


func _shoot(weapon: ItemData) -> void:
	if Inventory.equipped.loaded <= 0:
		if Inventory.ammo_count(weapon.ammo_item) > 0:
			reload()
		else:
			GameState.post_message("Está vacía.")
			Audio.play_sfx(&"dry_fire", player.global_position)
			_cooldown = weapon.attack_cooldown
		return
	Inventory.equipped.loaded -= 1
	Inventory.changed.emit()
	_cooldown = weapon.attack_cooldown
	player.play_action(ANIM_SHOOT)
	_flash_muzzle()
	Audio.play_sfx(weapon.shot_sound, player.global_position)
	GameState.track(&"shots")
	get_tree().call_group(&"enemies", &"hear_noise", player.global_position, weapon.noise_radius)

	var from := player.global_position + Vector3.UP * 1.4
	var aim_at: Vector3 = target.aim_point() if target else from + _camera_forward() * weapon.attack_range
	var aim_direction := (aim_at - from).normalized()
	# La locura abre la dispersión: con poca cordura se erra más. La escopeta suma su abanico.
	var spread := deg_to_rad(lerpf(sane_spread, insane_spread, Sanity.insanity()))
	var fan := deg_to_rad(weapon.pellet_spread)
	var side := aim_direction.cross(Vector3.UP).normalized()
	# Los perdigones que pegan en el mismo enemigo se suman en un solo golpe (un solo tambaleo).
	var damage_by_target := {}
	for i in maxi(weapon.pellets, 1):
		var direction := aim_direction.rotated(Vector3.UP, randf_range(-spread, spread) + randf_range(-fan, fan))
		direction = direction.rotated(side, (randf_range(-spread, spread) + randf_range(-fan, fan)) * 0.5)
		var query := PhysicsRayQueryParameters3D.create(from, from + direction * weapon.attack_range, 3)
		query.exclude = [player.get_rid()]
		var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.collider.has_method(&"take_damage"):
			damage_by_target[hit.collider] = damage_by_target.get(hit.collider, 0.0) + weapon.damage
	for enemy: Node in damage_by_target:
		enemy.take_damage(damage_by_target[enemy] * Sanity.player_damage_multiplier() * Powers.damage_multiplier())


func _melee(damage: float, reach: float, cooldown: float, anim: StringName, anim_speed := 1.0) -> void:
	_cooldown = cooldown
	# Se orienta solo hacia el enemigo más cercano que tenga adelante.
	var closest := _closest_enemy(reach * 1.6, 100.0)
	if closest:
		_face(closest.global_position, 0.0, 0.0)
	player.play_action(anim, anim_speed)
	GameState.track(&"melee")
	Audio.play_sfx(&"swing", player.global_position)
	await get_tree().create_timer(melee_hit_time, false).timeout
	if not is_instance_valid(player) or not player.can_control:
		return
	var enemies := _enemies_in_arc(reach + 0.5, melee_half_angle)
	if not enemies.is_empty():
		Audio.play_sfx(&"melee_hit", player.global_position)
	for enemy in enemies:
		enemy.take_damage(damage * Sanity.player_damage_multiplier() * Powers.damage_multiplier())


func _find_target() -> Node3D:
	var camera := player.get_viewport().get_camera_3d()
	if camera == null:
		return null
	var best: Node3D = null
	var best_angle := deg_to_rad(auto_aim_angle)
	var forward := _camera_forward()
	for enemy: Node3D in get_tree().get_nodes_in_group(&"enemies"):
		var to_enemy := enemy.global_position - player.global_position
		if to_enemy.length() > auto_aim_range:
			continue
		var angle := forward.angle_to(Vector3(to_enemy.x, 0.0, to_enemy.z))
		if angle > best_angle:
			continue
		var query := PhysicsRayQueryParameters3D.create(
			player.global_position + Vector3.UP * 1.4, enemy.aim_point(), 1)
		if not player.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			continue
		best = enemy
		best_angle = angle
	return best


func _closest_enemy(reach: float, half_angle: float) -> Node3D:
	var enemies := _enemies_in_arc(reach, half_angle)
	enemies.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_squared_to(player.global_position) \
			< b.global_position.distance_squared_to(player.global_position))
	return enemies[0] if not enemies.is_empty() else null


func _enemies_in_arc(reach: float, half_angle: float) -> Array[Node3D]:
	var result: Array[Node3D] = []
	var forward := -player.visual.global_basis.z
	for enemy: Node3D in get_tree().get_nodes_in_group(&"enemies"):
		var to_enemy := enemy.global_position - player.global_position
		to_enemy.y = 0.0
		if to_enemy.length() > reach:
			continue
		if rad_to_deg(forward.angle_to(to_enemy)) <= half_angle:
			result.append(enemy)
	return result


func _camera_forward() -> Vector3:
	return Vector3.FORWARD.rotated(Vector3.UP, player.yaw())


## Gira el modelo hacia `point`. `speed` 0 = instantáneo.
func _face(point: Vector3, speed: float, delta: float) -> void:
	var to_point := point - player.global_position
	if Vector2(to_point.x, to_point.z).length_squared() < 0.0001:
		return
	var target_yaw := atan2(-to_point.x, -to_point.z)
	var weight := 1.0 if speed <= 0.0 else 1.0 - exp(-speed * delta)
	player.visual.global_rotation.y = lerp_angle(player.visual.global_rotation.y, target_yaw, weight)


func _flash_muzzle() -> void:
	_muzzle_flash.visible = true
	await get_tree().create_timer(muzzle_flash_time, false).timeout
	if is_instance_valid(_muzzle_flash):
		_muzzle_flash.visible = false


func _on_equipped_changed(entry: Dictionary) -> void:
	if _held_model:
		_held_model.queue_free()
		_held_model = null
	var item: ItemData = entry.item if not entry.is_empty() else null
	if item and item.held_scene:
		# Las escenas "held" están armadas en metros en el espacio del hueso de la mano;
		# si el esqueleto del glTF viene escalado, se compensa acá.
		_held_model = item.held_scene.instantiate() as Node3D
		_held_attachment.add_child(_held_model)
		_held_model.scale = Vector3.ONE / _held_attachment.global_transform.basis.get_scale()
		_held_materials = PS1Materials.apply(_held_model)
	else:
		_held_materials.clear()


## Poderes (Powers): 1 = Filo del otro lado, 2 = Empujón. Cuestan locura.
func use_power(power: StringName) -> void:
	if player.is_busy() or not Powers.knows(power):
		return
	if not Powers.activate(power):
		return
	match power:
		Powers.EMPOWER:
			Audio.play_sfx(&"power_empower", player.global_position)
			_pulse_aura(3.0)
		Powers.PUSH:
			_push()


func _push() -> void:
	player.play_action(ANIM_PUNCH, 1.6)
	Audio.play_sfx(&"swing", player.global_position)
	Audio.play_sfx(&"power_push", player.global_position)
	_shockwave()
	var origin := player.global_position
	var damage := Powers.push_damage * Sanity.player_damage_multiplier()
	for enemy in _enemies_in_arc(Powers.push_range, Powers.push_half_angle):
		var away := enemy.global_position - origin
		away.y = 0.0
		# Los más cerca salen más lejos.
		var strength := lerpf(1.0, 0.5, clampf(away.length() / Powers.push_range, 0.0, 1.0))
		if enemy.has_method(&"knock_back"):
			enemy.knock_back(away.normalized() * Powers.push_speed * strength, damage)
		else:
			enemy.take_damage(damage)
	get_tree().call_group(&"enemies", &"hear_noise", origin, Powers.push_range * 2.0)


## La onda del empujón: un anillo que se abre hacia adelante y se desvanece.
func _shockwave() -> void:
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.45
	mesh.outer_radius = 0.6
	mesh.rings = 16
	mesh.ring_segments = 6
	ring.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(power_color, 0.8)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	player.get_parent().add_child(ring)
	var forward := -player.visual.global_basis.z
	ring.global_position = player.global_position + Vector3.UP * 1.1 + forward * 0.6
	# El anillo queda de frente, perpendicular a hacia donde mira.
	ring.look_at(ring.global_position + Vector3.UP, forward)
	var flash := OmniLight3D.new()
	flash.light_color = power_color
	flash.light_energy = 3.0
	flash.omni_range = 5.0
	ring.add_child(flash)
	var tween := ring.create_tween().set_parallel()
	tween.tween_property(ring, "global_position", ring.global_position + forward * Powers.push_range * 0.7, 0.35)
	tween.tween_property(ring, "scale", Vector3.ONE * 3.5, 0.35)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.35)
	tween.tween_property(flash, "light_energy", 0.0, 0.35)
	tween.chain().tween_callback(ring.queue_free)


func _pulse_aura(amount: float) -> void:
	_aura_boost = amount


## El arma (o el puño) brilla mientras dura el Filo; parpadea cuando se está por terminar.
func _update_aura() -> void:
	var active := Powers.is_empowered()
	var t := Time.get_ticks_msec() / 1000.0
	var glow := 0.0
	if active:
		glow = 0.75 + 0.25 * sin(t * 6.0)
		if Powers.empower_left < 5.0 and fmod(t, 0.4) < 0.15:
			glow *= 0.2
	_aura_boost = move_toward(_aura_boost, 0.0, get_physics_process_delta_time() * 6.0)
	_aura.visible = active
	_aura.light_energy = glow * 0.9 + _aura_boost
	var emission := Color(power_color * (glow * 0.8 + _aura_boost * 0.3), 1.0)
	for material in _held_materials:
		material.set_shader_parameter(&"emission_color", emission if active else Color.BLACK)
