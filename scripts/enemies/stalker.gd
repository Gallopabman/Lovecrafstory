class_name Stalker
extends CharacterBody3D
## Enemigo acechador: deambula cerca de donde aparece, persigue al jugador
## cuando lo ve o lo oye correr, y lo golpea (el daño es a la cordura).
## Se lo pierde de vista escapando: no hay combate todavía (pregunta abierta del GDD).

enum State { WANDER, CHASE, ATTACK }

const ANIM_IDLE := &"CharacterArmature|Idle"
const ANIM_WALK := &"CharacterArmature|Walk"
const ANIM_RUN := &"CharacterArmature|Run"
const ANIM_ATTACK := &"CharacterArmature|Punch"
const LOOPING_ANIMS: Array[StringName] = [ANIM_IDLE, ANIM_WALK, ANIM_RUN]

## Multiplica los colores del modelo (apagarlo lo vuelve más inquietante en la niebla).
@export var tint := Color(0.55, 0.5, 0.55)

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
## Segundos sin ver al jugador antes de abandonar la persecución.
@export var lose_time := 4.0
@export var eye_height := 2.1

@export_group("Ataque")
@export var attack_range := 1.6
@export var attack_damage := 12.0
@export var attack_cooldown := 1.6
## Momento de la animación en que el golpe conecta.
@export var attack_hit_time := 0.45

var state := State.WANDER
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _home := Vector3.ZERO
var _wander_wait := 0.0
var _since_seen := 0.0
var _attack_timer := 0.0
var _attack_hit_pending := false
var _cooldown := 0.0

@onready var visual: Node3D = $Visual
@onready var model: Node3D = $Visual/Model
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var anim_player: AnimationPlayer = model.find_child("AnimationPlayer") as AnimationPlayer


func _ready() -> void:
	_home = global_position
	PS1Materials.apply(model, tint)
	for anim_name in LOOPING_ANIMS:
		anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	anim_player.play(ANIM_IDLE)
	_wander_wait = randf_range(wander_pause.x, wander_pause.y)
	nav_agent.target_position = global_position


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	_cooldown = maxf(_cooldown - delta, 0.0)

	var player := get_tree().get_first_node_in_group(&"player") as Player
	var player_valid := player != null and player.can_control and Sanity.active
	if player_valid and _perceives(player):
		_since_seen = 0.0
		if state == State.WANDER:
			state = State.CHASE
	else:
		_since_seen += delta

	match state:
		State.WANDER:
			_wander(delta)
		State.CHASE:
			_chase(delta, player, player_valid)
		State.ATTACK:
			_attack(delta, player, player_valid)
	move_and_slide()


func _wander(delta: float) -> void:
	if nav_agent.is_navigation_finished():
		_move_towards(Vector3.ZERO, 0.0, delta)
		_play(ANIM_IDLE)
		_wander_wait -= delta
		if _wander_wait <= 0.0:
			var angle := randf() * TAU
			var offset := Vector3(cos(angle), 0.0, sin(angle)) * randf_range(1.5, wander_radius)
			nav_agent.target_position = _home + offset
			_wander_wait = randf_range(wander_pause.x, wander_pause.y)
		return
	_move_towards(nav_agent.get_next_path_position(), wander_speed, delta)
	_play(ANIM_WALK)


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
			_play(ANIM_IDLE)
		return
	_move_towards(nav_agent.get_next_path_position(), chase_speed, delta)
	_play(ANIM_RUN)


func _start_attack() -> void:
	state = State.ATTACK
	_attack_timer = 0.0
	_attack_hit_pending = true
	anim_player.play(ANIM_ATTACK, 0.1)


func _attack(delta: float, player: Player, player_valid: bool) -> void:
	_move_towards(Vector3.ZERO, 0.0, delta)
	if player_valid:
		_face(player.global_position, delta)
	_attack_timer += delta
	if _attack_hit_pending and _attack_timer >= attack_hit_time:
		_attack_hit_pending = false
		if player_valid and global_position.distance_to(player.global_position) <= attack_range * 1.3:
			Sanity.take_hit(attack_damage)
	if _attack_timer >= anim_player.get_animation(ANIM_ATTACK).length:
		_cooldown = attack_cooldown
		state = State.CHASE


func _perceives(player: Player) -> bool:
	var to_player := player.global_position - global_position
	var distance := to_player.length()
	if distance <= sense_range:
		return true
	if player.is_running and distance <= hearing_range:
		return true
	if distance > sight_range:
		return false
	var forward := visual.global_basis.z
	if rad_to_deg(forward.angle_to(Vector3(to_player.x, 0.0, to_player.z))) > sight_half_angle:
		return false
	var from := global_position + Vector3.UP * eye_height
	var query := PhysicsRayQueryParameters3D.create(from, player.global_position + Vector3.UP * 1.4, 1)
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
