class_name Player
extends CharacterBody3D
## Controlador en tercera persona: movimiento relativo a la cámara, correr,
## cámara orbital con colisión (SpringArm3D), linterna, interacción y
## animaciones del modelo del superviviente.

## Animaciones de la Universal Animation Library (ver SurvivorRig).
const ANIM_IDLE := SurvivorRig.IDLE
const ANIM_WALK := SurvivorRig.WALK
const ANIM_RUN := SurvivorRig.RUN
const ANIM_HIT := SurvivorRig.HIT
const ANIM_INTERACT := SurvivorRig.INTERACT
const ANIM_DEATH := SurvivorRig.DEATH
const ANIM_JUMP := SurvivorRig.JUMP
const ANIM_AIRBORNE := SurvivorRig.AIRBORNE
const ANIM_LAND := SurvivorRig.LAND
const ANIM_CROUCH_IDLE := SurvivorRig.CROUCH_IDLE
const ANIM_CROUCH_WALK := SurvivorRig.CROUCH_WALK

@export_group("Movimiento")
@export var walk_speed := 2.2
@export var run_speed := 4.5
## Qué tan rápido se alcanza la velocidad objetivo (mayor = más brusco).
@export var acceleration := 10.0
## Qué tan rápido el modelo gira hacia la dirección de movimiento.
@export var turn_speed := 10.0
## Velocidad vertical al saltar (4.2 m/s ≈ 0.9 m de altura).
@export var jump_velocity := 4.2
## Control del movimiento en el aire (0 = ninguno, 1 = igual que en el piso).
@export_range(0.0, 1.0) var air_control := 0.35
## Caídas más largas que esto (segundos en el aire) hacen la animación de aterrizaje.
@export var hard_landing_time := 1.1
## Metros entre pasos al caminar (corriendo, un poco más).
@export var step_length := 0.8

@export_group("Agacharse")
@export var crouch_speed := 1.2
## Alto de la cápsula agachado (parado: 1.8).
@export var crouch_height := 1.2
@export var crouch_camera_height := 1.0

@export_group("Sigilo")
## Multiplicador de la distancia a la que te ven los enemigos (1 = parado a la luz).
@export var crouch_visibility := 0.5
## La linterna encendida te delata en la oscuridad.
@export var flashlight_visibility := 1.4

@export_group("Cámara")
@export var camera_height := 1.5
@export var mouse_sensitivity := 0.003
@export var stick_sensitivity := 2.5
@export_range(-89.0, 0.0) var pitch_min_degrees := -60.0
@export_range(0.0, 89.0) var pitch_max_degrees := 35.0
## Suavizado del seguimiento de la cámara (mayor = más pegada al jugador).
@export var camera_follow_speed := 10.0

@export_group("Animación")
@export var anim_blend_time := 0.2

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_running := false
var is_crouching := false
var can_control := true

var _yaw := 0.0
var _pitch := deg_to_rad(-15.0)
## Mientras sea > 0 una animación de acción (golpe, interactuar) tiene prioridad.
var _action_lock := 0.0
var _air_time := 0.0
## Tiempo desde que despegó, para dejar terminar la animación de impulso.
var _jump_timer := 0.0
var _stand_height := 1.8
var _current_camera_height := 0.0
var _step_distance := 0.0

@onready var visual: Node3D = $Visual
@onready var model: Node3D = $Visual/Model
@onready var flashlight: SpotLight3D = $Visual/Flashlight
@onready var interaction_area: Area3D = $Visual/InteractionArea
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
var anim_player: AnimationPlayer
@onready var combat: PlayerCombat = $Combat
@onready var body_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	add_to_group(&"player")
	_place_at_spawn()
	# La cápsula cambia de alto al agacharse: copia propia para no tocar el recurso de la escena.
	body_shape.shape = body_shape.shape.duplicate()
	_stand_height = (body_shape.shape as CapsuleShape3D).height
	_current_camera_height = camera_height
	# El pivote se independiza del transform del jugador para poder suavizar el seguimiento.
	camera_pivot.top_level = true
	camera_pivot.global_position = _camera_target()
	_yaw = visual.global_rotation.y
	spring_arm.add_excluded_object(get_rid())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	PS1Materials.apply(model)
	anim_player = SurvivorRig.setup(model)
	anim_player.play(ANIM_IDLE)
	combat.setup()

	Sanity.hit_taken.connect(_on_hit_taken)
	Sanity.lost.connect(_on_lost)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * mouse_sensitivity
	elif event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif not can_control:
		return
	elif event.is_action_pressed("flashlight"):
		flashlight.visible = not flashlight.visible
		Audio.play_sfx(&"flashlight", global_position, -8.0)
	elif event.is_action_pressed("interact"):
		_try_interact()
	elif event.is_action_pressed("crouch"):
		set_crouching(not is_crouching)


func _physics_process(delta: float) -> void:
	_update_camera_rotation(delta)
	_action_lock = maxf(_action_lock - delta, 0.0)

	var on_floor := is_on_floor()
	_jump_timer += delta
	if not on_floor:
		velocity.y -= gravity * delta
		_air_time += delta
	else:
		if _air_time > hard_landing_time and can_control:
			play_action(ANIM_LAND, 1.8)
		_air_time = 0.0

	combat.physics_update(delta)
	# Apuntar, correr o saltar agachado primero te pone de pie (si hay lugar arriba).
	if is_crouching and (combat.aiming or Input.is_action_just_pressed("run") \
			or Input.is_action_just_pressed("jump")):
		set_crouching(false)
	if Input.is_action_just_pressed("jump") and on_floor and can_control \
			and not combat.aiming and not is_busy() and not is_crouching:
		velocity.y = jump_velocity
		_jump_timer = 0.0
		anim_player.speed_scale = 1.0
		anim_player.play(ANIM_JUMP, 0.05)
	var input := Vector2.ZERO
	# Apuntar deja al personaje quieto (survival horror clásico).
	if can_control and _action_lock <= 0.0 and not combat.aiming:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, _yaw)
	is_running = Input.is_action_pressed("run") and direction.length_squared() > 0.01 and not is_crouching
	var speed := crouch_speed if is_crouching else (run_speed if is_running else walk_speed)
	var target_velocity := direction * speed

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	# En el aire se conserva el impulso y se controla poco.
	var control := 1.0 if on_floor else air_control
	horizontal = horizontal.lerp(target_velocity, 1.0 - exp(-acceleration * control * delta))
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	if direction.length_squared() > 0.01:
		var target_yaw := atan2(-direction.x, -direction.z)
		visual.global_rotation.y = lerp_angle(visual.global_rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))

	move_and_slide()
	_update_animation(horizontal.length())
	if is_running:
		GameState.track(&"run_time", delta)
	elif is_crouching:
		GameState.track(&"crouch_time", delta)
	_update_footsteps(horizontal.length() * delta, on_floor)

	var target_height := crouch_camera_height if is_crouching else camera_height
	_current_camera_height = lerpf(_current_camera_height, target_height, 1.0 - exp(-8.0 * delta))
	camera_pivot.global_position = camera_pivot.global_position.lerp(
		_camera_target(), 1.0 - exp(-camera_follow_speed * delta))


func _update_camera_rotation(delta: float) -> void:
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	_yaw -= look.x * stick_sensitivity * delta
	_pitch -= look.y * stick_sensitivity * delta
	_pitch = clampf(_pitch, deg_to_rad(pitch_min_degrees), deg_to_rad(pitch_max_degrees))
	camera_pivot.rotation = Vector3(_pitch, _yaw, 0.0)


func _update_animation(speed: float) -> void:
	if not can_control or _action_lock > 0.0:
		return
	if combat.aiming:
		anim_player.speed_scale = 1.0
		if anim_player.current_animation != PlayerCombat.ANIM_AIM:
			anim_player.play(PlayerCombat.ANIM_AIM, 0.12)
		return
	# En el aire: se deja terminar el impulso y después la pose de vuelo.
	# (_air_time > 0.1 evita que un escalón chico cuente como caída.)
	if not is_on_floor() and (_air_time > 0.1 or _jump_timer < 0.1):
		anim_player.speed_scale = 1.0
		var jump_playing := anim_player.current_animation == ANIM_JUMP and anim_player.is_playing()
		if not jump_playing and anim_player.current_animation != ANIM_AIRBORNE:
			anim_player.play(ANIM_AIRBORNE, 0.15)
		return
	var anim := ANIM_IDLE
	var reference_speed := 1.0
	if is_crouching:
		anim = ANIM_CROUCH_WALK if speed > 0.2 else ANIM_CROUCH_IDLE
		reference_speed = crouch_speed * 1.6
	elif speed > walk_speed * 1.15:
		anim = ANIM_RUN
		reference_speed = run_speed
	elif speed > 0.3:
		anim = ANIM_WALK
		reference_speed = walk_speed
	if anim_player.current_animation != anim:
		anim_player.play(anim, anim_blend_time)
	# Ajusta la cadencia de pasos a la velocidad real para que no patine.
	var still := anim == ANIM_IDLE or anim == ANIM_CROUCH_IDLE
	anim_player.speed_scale = 1.0 if still else clampf(speed / reference_speed, 0.6, 1.3)


## Reproduce una animación de acción que bloquea el movimiento hasta terminar.
## `speed` acelera animaciones largas (el bloqueo se acorta en proporción).
func play_action(anim: StringName, speed := 1.0) -> void:
	anim_player.speed_scale = speed
	anim_player.play(anim, 0.1)
	_action_lock = anim_player.get_animation(anim).length / speed


## Hay una acción en curso (golpe recibido, ataque, interactuar, recargar).
func is_busy() -> bool:
	return _action_lock > 0.0


## Orientación horizontal de la cámara.
func yaw() -> float:
	return _yaw


## Agacharse o pararse. Para pararse tiene que haber lugar arriba (debajo de una
## mesa, no). Devuelve si quedó en el estado pedido.
func set_crouching(crouch: bool) -> bool:
	if crouch == is_crouching:
		return true
	if crouch and not (can_control and is_on_floor()):
		return false
	if not crouch and not _has_headroom():
		return false
	is_crouching = crouch
	var capsule := body_shape.shape as CapsuleShape3D
	capsule.height = crouch_height if crouch else _stand_height
	body_shape.position.y = capsule.height / 2.0
	return true


## Altura de los ojos: los enemigos miran a este punto (cubrirse detrás de algo bajo sirve).
func eye_height() -> float:
	return 0.85 if is_crouching else 1.4


## Qué tan fácil es verte: agachado cuesta más; con la linterna prendida, menos.
func visibility() -> float:
	var factor := crouch_visibility if is_crouching else 1.0
	if flashlight.visible:
		factor *= flashlight_visibility
	return factor


func _has_headroom() -> bool:
	var from := global_position + Vector3.UP * (crouch_height - 0.05)
	var to := global_position + Vector3.UP * (_stand_height + 0.05)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _try_interact() -> void:
	var closest: Node3D = null
	var closest_distance := INF
	for area in interaction_area.get_overlapping_areas():
		if not area.is_in_group(&"interactable"):
			continue
		var distance := global_position.distance_squared_to(area.global_position)
		if distance < closest_distance:
			closest = area
			closest_distance = distance
	if closest:
		play_action(ANIM_INTERACT)
		closest.interact(self)


func _on_hit_taken(_amount: float) -> void:
	Audio.play_sfx(&"player_hurt", global_position)
	if can_control:
		play_action(ANIM_HIT)


func _on_lost() -> void:
	can_control = false
	Audio.play_sfx(&"player_death", global_position)
	anim_player.speed_scale = 1.0
	anim_player.play(ANIM_DEATH, 0.2)


## Un paso cada `step_length` metros recorridos; agachado casi no suenan.
func _update_footsteps(distance: float, on_floor: bool) -> void:
	if not on_floor:
		return
	_step_distance += distance
	var length := step_length * (1.4 if is_running else 1.0)
	if _step_distance >= length:
		_step_distance = 0.0
		var volume := -14.0 if is_crouching else (-2.0 if is_running else -7.0)
		Audio.play_sfx(Audio.footstep, global_position, volume)


## Al llegar desde otra zona aparece en el SpawnPoint pedido, mirando hacia su -Z.
func _place_at_spawn() -> void:
	if GameState.next_spawn == &"":
		return
	for node in get_parent().find_children("*", "Marker3D", true, false):
		if node is SpawnPoint and node.spawn_id == GameState.next_spawn:
			global_position = node.global_position
			visual.global_rotation.y = node.global_rotation.y
			break
	GameState.next_spawn = &""


func _camera_target() -> Vector3:
	return global_position + Vector3.UP * _current_camera_height
