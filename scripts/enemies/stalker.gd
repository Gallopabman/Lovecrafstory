class_name Stalker
extends CharacterBody3D
## Enemigo acechador: deambula cerca de donde aparece, persigue al jugador
## cuando lo ve, lo oye correr u oye un disparo, y lo golpea (el daño es a la
## cordura). Tiene vida: se tambalea con cada golpe y muere para siempre
## (el mundo sigue como quedó). Matarlo devuelve un poco de cordura.

signal died

enum State { WANDER, CHASE, ATTACK, STAGGER, DEAD }

## Multiplica los colores del modelo (apagarlo lo vuelve más inquietante en la niebla).
@export var tint := Color(0.55, 0.5, 0.55)
## Textura para modelos que la traen aparte (se aplica a los materiales sin textura).
@export var albedo_texture: Texture2D

@export_group("Animaciones")
@export var anim_idle: StringName = &"idle"
@export var anim_walk: StringName = &"walk"
@export var anim_run: StringName = &"run"
@export var anim_attack: StringName = &"attack1_r"
@export var anim_hit: StringName = &"hurt"
@export var anim_death: StringName = &"dead1"
## Velocidad de reproducción de la animación de correr (para que no patine).
@export var run_anim_speed := 1.0
@export var max_health := 100.0
## Cordura que recupera el jugador al matarlo (alivio de sobrevivir al horror).
@export var kill_sanity_reward := 5.0

@export_group("Movimiento")
@export var wander_speed := 1.0
## Más rápido que el jugador caminando, más lento que corriendo.
@export var chase_speed := 3.3
@export var turn_speed := 6.0
@export var wander_radius := 6.0
@export var wander_pause := Vector2(1.5, 4.0)

@export_group("Percepción")
@export var sight_range := 11.0
@export_range(0.0, 180.0) var sight_half_angle := 70.0
## Distancia a la que oye al jugador correr.
@export var hearing_range := 7.0
## Distancia a la que lo nota siempre, aunque esté de espaldas.
@export var sense_range := 2.5
## Agachado, la distancia a la que te nota aunque esté de espaldas se multiplica por
## esto (0.4: de 2.5 m a 1 m). La vista usa `Player.visibility()` (agachado x0.5, linterna x1.4).
@export var crouch_sense_multiplier := 0.4
## Segundos sin ver al jugador antes de abandonar la persecución.
@export var lose_time := 4.0
@export var eye_height := 2.1

@export_group("Ataque")
@export var attack_range := 1.6
@export var attack_damage := 12.0
@export var attack_cooldown := 1.6
## Momento de la animación en que el golpe conecta.
@export var attack_hit_time := 0.45

@export_group("Sonidos")
@export var sound_idle: StringName = &"zombie_growl"
@export var sound_alert: StringName = &"zombie_growl"
@export var sound_attack: StringName = &"zombie_attack"
@export var sound_hurt: StringName = &"zombie_hurt"
@export var sound_death: StringName = &"zombie_death"
## Segundos entre gruñidos mientras deambula.
@export var idle_sound_interval := Vector2(5.0, 12.0)

@export_group("Daño recibido")
## Segundos que queda aturdido al recibir un golpe.
@export var stagger_time := 0.45
@export var hit_flash_color := Color(1.0, 0.15, 0.1)
@export var hit_flash_time := 0.12

var state := State.WANDER
var health := max_health
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _home := Vector3.ZERO
var _wander_wait := 0.0
var _since_seen := 0.0
var _attack_timer := 0.0
var _attack_hit_pending := false
var _cooldown := 0.0
var _stagger_timer := 0.0
var _flash_timer := 0.0
var _idle_sound_timer := 0.0
## Animación del ataque en curso (las subclases pueden tener más de uno).
var _attack_anim: StringName
var _materials: Array[ShaderMaterial] = []
var _base_colors: Array[Color] = []

@onready var visual: Node3D = $Visual
@onready var model: Node3D = $Visual/Model
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var anim_player: AnimationPlayer = model.find_child("AnimationPlayer") as AnimationPlayer


func _ready() -> void:
	if GameState.is_killed(_key()):
		queue_free()
		return
	add_to_group(&"enemies")
	health = max_health
	_home = global_position
	_materials = PS1Materials.apply(model, tint, {}, albedo_texture)
	for material in _materials:
		_base_colors.append(material.get_shader_parameter(&"albedo_color"))
	for anim_name in [anim_idle, anim_walk, anim_run]:
		anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	anim_player.play(anim_idle)
	_wander_wait = randf_range(wander_pause.x, wander_pause.y)
	_idle_sound_timer = randf_range(idle_sound_interval.x, idle_sound_interval.y)
	nav_agent.target_position = global_position


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	_update_flash(delta)
	if state == State.DEAD:
		_move_towards(Vector3.ZERO, 0.0, delta)
		move_and_slide()
		return

	var player := get_tree().get_first_node_in_group(&"player") as Player
	var player_valid := player != null and player.can_control and Sanity.active
	if player_valid and _perceives(player):
		_since_seen = 0.0
		if state == State.WANDER:
			_alert()
	else:
		_since_seen += delta
	_idle_sound_timer -= delta
	if _idle_sound_timer <= 0.0:
		_idle_sound_timer = randf_range(idle_sound_interval.x, idle_sound_interval.y)
		Audio.play_sfx(sound_idle, global_position, -6.0)

	match state:
		State.WANDER:
			_wander(delta)
		State.CHASE:
			_chase(delta, player, player_valid)
		State.ATTACK:
			_attack(delta, player, player_valid)
		State.STAGGER:
			_move_towards(Vector3.ZERO, 0.0, delta)
			_stagger_timer -= delta
			if _stagger_timer <= 0.0:
				state = State.CHASE
	move_and_slide()


## Punto al que apunta el auto-apuntado del jugador.
func aim_point() -> Vector3:
	return global_position + Vector3.UP * 1.5


func is_dead() -> bool:
	return state == State.DEAD


func take_damage(amount: float) -> void:
	if state == State.DEAD:
		return
	health -= amount
	_flash_timer = hit_flash_time
	# Un golpe siempre lo alerta.
	_since_seen = 0.0
	if health <= 0.0:
		_die()
		return
	Audio.play_sfx(sound_hurt, global_position)
	state = State.STAGGER
	_stagger_timer = stagger_time
	_attack_hit_pending = false
	anim_player.play(anim_hit, 0.05)


## Un ruido fuerte (disparo) dentro de `radius` lo pone a perseguir.
func hear_noise(origin: Vector3, radius: float) -> void:
	if state == State.WANDER and global_position.distance_to(origin) <= radius:
		_since_seen = 0.0
		_alert()


func _alert() -> void:
	state = State.CHASE
	Audio.play_sfx(sound_alert, global_position)


func _die() -> void:
	state = State.DEAD
	Audio.play_sfx(sound_death, global_position)
	GameState.mark_killed(_key())
	# El cuerpo queda en el piso pero ya no bloquea ni se puede golpear.
	collision_layer = 0
	remove_from_group(&"enemies")
	anim_player.play(anim_death, 0.1)
	Sanity.restore(kill_sanity_reward)
	died.emit()


func _update_flash(delta: float) -> void:
	if _flash_timer <= 0.0 and _flash_timer > -1.0:
		return
	_flash_timer -= delta
	var amount := clampf(_flash_timer / hit_flash_time, 0.0, 1.0)
	for i in _materials.size():
		_materials[i].set_shader_parameter(&"albedo_color", _base_colors[i].lerp(hit_flash_color, amount))
	if _flash_timer <= 0.0:
		_flash_timer = 0.0


func _wander(delta: float) -> void:
	if nav_agent.is_navigation_finished():
		_move_towards(Vector3.ZERO, 0.0, delta)
		_play(anim_idle)
		_wander_wait -= delta
		if _wander_wait <= 0.0:
			var angle := randf() * TAU
			var offset := Vector3(cos(angle), 0.0, sin(angle)) * randf_range(1.5, wander_radius)
			nav_agent.target_position = _home + offset
			_wander_wait = randf_range(wander_pause.x, wander_pause.y)
		return
	_move_towards(nav_agent.get_next_path_position(), wander_speed, delta)
	_play(anim_walk)


func _chase(delta: float, player: Player, player_valid: bool) -> void:
	if not player_valid or _since_seen > lose_time:
		state = State.WANDER
		nav_agent.target_position = _home
		return
	nav_agent.target_position = player.global_position
	if global_position.distance_to(player.global_position) <= attack_range:
		if _cooldown <= 0.0:
			_start_attack()
		else:
			_move_towards(Vector3.ZERO, 0.0, delta)
			_face(player.global_position, delta)
			_play(anim_idle)
		return
	_move_towards(nav_agent.get_next_path_position(), chase_speed, delta)
	_play(anim_run)


func _start_attack(anim: StringName = anim_attack) -> void:
	state = State.ATTACK
	_attack_timer = 0.0
	_attack_hit_pending = true
	_attack_anim = anim
	anim_player.play(anim, 0.1)
	Audio.play_sfx(sound_attack, global_position)


func _attack(delta: float, player: Player, player_valid: bool) -> void:
	_move_towards(Vector3.ZERO, 0.0, delta)
	if player_valid:
		_face(player.global_position, delta)
	_attack_timer += delta
	if _attack_hit_pending and _attack_timer >= attack_hit_time:
		_attack_hit_pending = false
		if player_valid and _attack_connects(player):
			Sanity.take_hit(attack_damage)
	if _attack_timer >= anim_player.get_animation(_attack_anim).length:
		_cooldown = attack_cooldown
		state = State.CHASE


## El golpe llega si el jugador sigue cerca cuando conecta.
func _attack_connects(player: Player) -> bool:
	return global_position.distance_to(player.global_position) <= attack_range * 1.3


func _perceives(player: Player) -> bool:
	var to_player := player.global_position - global_position
	var distance := to_player.length()
	# Agachado cuesta verte (y notarte de cerca); con la linterna prendida, menos.
	var visibility := player.visibility()
	if distance <= sense_range * (crouch_sense_multiplier if player.is_crouching else 1.0):
		return true
	if player.is_running and distance <= hearing_range:
		return true
	if distance > sight_range * visibility:
		return false
	var forward := visual.global_basis.z
	if rad_to_deg(forward.angle_to(Vector3(to_player.x, 0.0, to_player.z))) > sight_half_angle:
		return false
	# Mira a la altura de los ojos del jugador: agachado detrás de un mostrador, no te ve.
	var from := global_position + Vector3.UP * eye_height
	var query := PhysicsRayQueryParameters3D.create(from, player.global_position + Vector3.UP * player.eye_height(), 1)
	query.exclude = [get_rid(), player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _move_towards(target: Vector3, speed: float, delta: float) -> void:
	var direction := Vector3.ZERO
	if speed > 0.0:
		direction = target - global_position
		direction.y = 0.0
		direction = direction.normalized()
		if direction != Vector3.ZERO:
			_face(global_position + direction, delta)
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).lerp(direction * speed, 1.0 - exp(-8.0 * delta))
	velocity.x = horizontal.x
	velocity.z = horizontal.z


## El modelo mira hacia +Z.
func _face(target: Vector3, delta: float) -> void:
	var to_target := target - global_position
	if Vector2(to_target.x, to_target.z).length_squared() < 0.0001:
		return
	var target_yaw := atan2(to_target.x, to_target.z)
	visual.global_rotation.y = lerp_angle(visual.global_rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))


func _play(anim: StringName) -> void:
	if anim_player.current_animation != anim:
		anim_player.play(anim, 0.25)


func _key() -> String:
	return String(get_path())
