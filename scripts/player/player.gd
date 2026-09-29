class_name Player
extends CharacterBody3D
## Controlador en tercera persona: movimiento relativo a la cámara, correr,
## cámara orbital con colisión (SpringArm3D), linterna, interacción y
## animaciones del modelo del superviviente.

const ANIM_IDLE := &"CharacterArmature|Idle"
const ANIM_WALK := &"CharacterArmature|Walk"
const ANIM_RUN := &"CharacterArmature|Run"
const ANIM_HIT := &"CharacterArmature|HitRecieve"
const ANIM_INTERACT := &"CharacterArmature|Interact"
const ANIM_DEATH := &"CharacterArmature|Death"
## El modelo del superviviente no trae salto: se toman del rig (compatible) del alien.
const ANIM_JUMP := &"CharacterArmature|Jump"
const ANIM_AIRBORNE := &"CharacterArmature|Jump_Idle"
const ANIM_LAND := &"CharacterArmature|Jump_Land"
const JUMP_ANIM_SOURCE := preload("res://assets/models/enemies/tentacled/tentacled.glb")
const LOOPING_ANIMS: Array[StringName] = [ANIM_IDLE, ANIM_WALK, ANIM_RUN, ANIM_AIRBORNE]

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
@export var hard_landing_time := 0.6

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
var can_control := true

var _yaw := 0.0
var _pitch := deg_to_rad(-15.0)
## Mientras sea > 0 una animación de acción (golpe, interactuar) tiene prioridad.
var _action_lock := 0.0
var _air_time := 0.0
## Tiempo desde que despegó, para dejar terminar la animación de impulso.
var _jump_timer := 0.0

@onready var visual: Node3D = $Visual
@onready var model: Node3D = $Visual/Model
@onready var flashlight: SpotLight3D = $Visual/Flashlight
@onready var interaction_area: Area3D = $Visual/InteractionArea
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var anim_player: AnimationPlayer = model.find_child("AnimationPlayer") as AnimationPlayer
@onready var combat: PlayerCombat = $Combat


func _ready() -> void:
	add_to_group(&"player")
	# El pivote se independiza del transform del jugador para poder suavizar el seguimiento.
	camera_pivot.top_level = true
	camera_pivot.global_position = _camera_target()
	_yaw = visual.global_rotation.y
	spring_arm.add_excluded_object(get_rid())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	PS1Materials.apply(model)
	var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	AnimationRetarget.import_animations(JUMP_ANIM_SOURCE, [ANIM_JUMP, ANIM_AIRBORNE, ANIM_LAND], anim_player, skeleton)
	for anim_name in LOOPING_ANIMS:
		anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
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
	elif event.is_action_pressed("interact"):
		_try_interact()


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
			play_action(ANIM_LAND)
		_air_time = 0.0

	combat.physics_update(delta)
	if Input.is_action_just_pressed("jump") and on_floor and can_control \
			and not combat.aiming and not is_busy():
		velocity.y = jump_velocity
		_jump_timer = 0.0
		anim_player.speed_scale = 1.0
		anim_player.play(ANIM_JUMP, 0.05)
	var input := Vector2.ZERO
	# Apuntar deja al personaje quieto (survival horror clásico).
	if can_control and _action_lock <= 0.0 and not combat.aiming:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, _yaw)
	is_running = Input.is_action_pressed("run") and direction.length_squared() > 0.01
	var target_velocity := direction * (run_speed if is_running else walk_speed)

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
	if speed > walk_speed * 1.15:
		anim = ANIM_RUN
		reference_speed = run_speed
	elif speed > 0.3:
		anim = ANIM_WALK
		reference_speed = walk_speed
	if anim_player.current_animation != anim:
		anim_player.play(anim, anim_blend_time)
	# Ajusta la cadencia de pasos a la velocidad real para que no patine.
	anim_player.speed_scale = 1.0 if anim == ANIM_IDLE else clampf(speed / reference_speed, 0.6, 1.3)


## Reproduce una animación de acción que bloquea el movimiento hasta terminar.
func play_action(anim: StringName) -> void:
	anim_player.speed_scale = 1.0
	anim_player.play(anim, 0.1)
	_action_lock = anim_player.get_animation(anim).length


## Hay una acción en curso (golpe recibido, ataque, interactuar, recargar).
func is_busy() -> bool:
	return _action_lock > 0.0


## Orientación horizontal de la cámara.
func yaw() -> float:
	return _yaw


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
	if can_control:
		play_action(ANIM_HIT)


func _on_lost() -> void:
	can_control = false
	anim_player.speed_scale = 1.0
	anim_player.play(ANIM_DEATH, 0.2)


func _camera_target() -> Vector3:
	return global_position + Vector3.UP * camera_height
