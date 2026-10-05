class_name Spitter
extends Stalker
## El Escupidor (pedido del usuario: un enemigo con ataque de rango). No se acerca: busca
## una distancia media, escupe una bola de bilis que viaja despacio (se puede esquivar)
## y, si el jugador se le viene encima, retrocede. De cerca igual araña.

@export_group("Escupida")
@export var spit_scene: PackedScene = preload("res://scenes/enemies/spit_projectile.tscn")
@export var spit_anim: StringName = &"CharacterArmature|Weapon"
@export var spit_range := 13.0
@export var spit_min_range := 4.0
## Distancia que prefiere: más cerca retrocede (y no escupe a menos de spit_min_range), más
## lejos se acerca.
@export var preferred_distance := Vector2(5.0, 9.0)
@export var retreat_speed := 1.6
@export var spit_damage := 10.0
@export var spit_speed := 9.0
@export var spit_cooldown := 2.6
@export var spit_hit_time := 0.45
## Altura de la boca (de donde sale la escupida).
@export var mouth_height := 1.5
@export var sound_spit: StringName = &"spit"

var _is_spit := false


func _chase(delta: float, player: Player, player_valid: bool) -> void:
	if not player_valid or _since_seen > lose_time:
		super._chase(delta, player, player_valid)
		return
	var distance := global_position.distance_to(player.global_position)
	var sees := _has_line_of_fire(player)
	if _cooldown <= 0.0 and sees and distance > spit_min_range and distance <= spit_range:
		_is_spit = true
		_start_attack(spit_anim)
		Audio.play_sfx(sound_spit, global_position)
		return
	_is_spit = false
	if distance <= attack_range:
		super._chase(delta, player, player_valid)
		return
	if sees and distance < preferred_distance.x:
		# Retrocede de espaldas, mirando al jugador.
		var away := global_position + (global_position - player.global_position).normalized() * 2.0
		_move_towards(away, retreat_speed, delta)
		_face(player.global_position, delta * 2.0)
		_play(anim_walk)
		return
	if sees and distance <= preferred_distance.y:
		_move_towards(Vector3.ZERO, 0.0, delta)
		_face(player.global_position, delta)
		_play(anim_idle)
		return
	super._chase(delta, player, player_valid)


func _attack(delta: float, player: Player, player_valid: bool) -> void:
	if not _is_spit:
		super._attack(delta, player, player_valid)
		return
	_move_towards(Vector3.ZERO, 0.0, delta)
	if player_valid:
		_face(player.global_position, delta * 3.0)
	_attack_timer += delta
	if _attack_hit_pending and _attack_timer >= spit_hit_time:
		_attack_hit_pending = false
		if player_valid:
			_spit_at(player)
	if _attack_timer >= anim_player.get_animation(_attack_anim).length:
		_cooldown = spit_cooldown
		_is_spit = false
		state = State.CHASE


func _spit_at(player: Player) -> void:
	var from := global_position + Vector3.UP * mouth_height + visual.global_basis.z * 0.4
	# Apunta al pecho, con un poco de ventaja si el jugador corre.
	var target := player.global_position + Vector3.UP * player.eye_height() * 0.8
	var flight := from.distance_to(target) / spit_speed
	var lead := Vector3(player.velocity.x, 0.0, player.velocity.z) * flight * 0.5
	var spit: Node3D = spit_scene.instantiate()
	# Apunta un poco más arriba para compensar la caída de la escupida.
	lead += Vector3.UP * 0.5 * float(spit.get("gravity")) * flight * flight
	spit.set("direction", (target + lead - from).normalized())
	spit.set("speed", spit_speed)
	spit.set("damage", spit_damage)
	spit.set("shooter", self)
	spit.position = from
	get_tree().current_scene.add_child(spit)


func _has_line_of_fire(player: Player) -> bool:
	var from := global_position + Vector3.UP * mouth_height
	var query := PhysicsRayQueryParameters3D.create(from, player.global_position + Vector3.UP * player.eye_height(), 1)
	query.exclude = [get_rid(), player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
