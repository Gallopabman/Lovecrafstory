class_name Npc
extends CharacterBody3D
## Un personaje que no es enemigo (pedido del usuario: el Flaco, el Dr. Ferreyra, el mendigo).
## TALK: se le habla con E y va diciendo sus textos (otros si la cordura está rota).
## SLEEP: igual, pero acostado (pose = último cuadro de `anim_pose`): no se despierta.
## FLEE: cuando ve al jugador sale corriendo hasta `flee_target`, desaparece y marca `flee_flag`.
## Está o no según flags del mundo (`visible_flag` / `hidden_flag`).

enum Behavior { TALK, SLEEP, FLEE }

@export var behavior := Behavior.TALK
@export var model_scene: PackedScene
@export var model_scale := 1.0
@export var model_yaw := 0.0
## Corrimiento del modelo (p. ej. para centrar a uno acostado sobre su cápsula).
@export var model_offset := Vector3.ZERO
@export var tint := Color.WHITE
@export var anim_idle: StringName = &""
@export var anim_run: StringName = &""
## SLEEP: animación cuyo último cuadro es la pose (p. ej. la de morir = acostado).
@export var anim_pose: StringName = &""
@export var texts: PackedStringArray = []
## Lo que dice (o lo que se ve) desde Quebrado.
@export var texts_broken: PackedStringArray = []
@export var talk_radius := 1.6
## Solo está si este flag está marcado (vacío = siempre).
@export var visible_flag: StringName = &""
## Se va para siempre cuando se marca este flag.
@export var hidden_flag: StringName = &""

@export_group("Regalo")
## Lo que da la primera vez que se le habla (una sola vez por partida).
@export var gift_item: ItemData
@export var gift_count := 1
@export var gift_flag: StringName = &""
@export var gift_text := ""

@export_group("Huida")
## Por dónde se escapa: elige la salida más lejos del jugador.
@export var flee_targets: Array[NodePath] = []
@export var flee_sight := 14.0
@export var flee_speed := 4.6
## Cuánto se queda mirándote antes de salir corriendo.
@export var flee_delay := 0.9
@export var flee_flag: StringName = &""
@export var flee_text := ""

var _model: Node3D
var _anim: AnimationPlayer
var _area: Area3D
var _agent: NavigationAgent3D
var _index := 0
var _fleeing := false
var _flee_time := 0.0
var _target: Node3D
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.7
	shape.shape = capsule
	shape.position = Vector3.UP * 0.85
	if behavior == Behavior.SLEEP:
		capsule.height = 0.7
		shape.rotation_degrees.z = 90.0
		shape.position = Vector3.UP * 0.35
	add_child(shape)
	if model_scene:
		_model = model_scene.instantiate()
		_model.scale = Vector3.ONE * model_scale
		_model.rotation_degrees.y = model_yaw
		_model.position = model_offset
		add_child(_model)
		PS1Materials.apply(_model, tint)
		_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if behavior == Behavior.SLEEP:
		_pose(anim_pose)
	else:
		_loop(anim_idle)
	_area = Area3D.new()
	_area.set_script(load("res://scripts/world/interact_proxy.gd"))
	_area.set("target", self)
	_area.set("radius", talk_radius)
	_area.position = Vector3.UP * 0.9
	add_child(_area)
	if behavior == Behavior.FLEE:
		_agent = NavigationAgent3D.new()
		_agent.path_desired_distance = 0.6
		_agent.target_desired_distance = 0.8
		_agent.radius = 0.4
		add_child(_agent)
	GameState.flag_set.connect(func(_f: StringName) -> void: _refresh())
	_refresh()


func is_present() -> bool:
	if visible_flag != &"" and not GameState.has_flag(visible_flag):
		return false
	if hidden_flag != &"" and GameState.has_flag(hidden_flag):
		return false
	if behavior == Behavior.FLEE and flee_flag != &"" and GameState.has_flag(flee_flag):
		return false
	return true


func _refresh() -> void:
	var present := is_present()
	visible = present
	process_mode = Node.PROCESS_MODE_INHERIT if present else Node.PROCESS_MODE_DISABLED
	_area.set("enabled", present)


func interact(_player: Player) -> void:
	if not is_present() or _fleeing:
		return
	if gift_item and gift_flag != &"" and not GameState.has_flag(gift_flag):
		GameState.set_flag(gift_flag)
		for i in gift_count:
			Inventory.add(gift_item)
		if gift_text != "":
			GameState.post_message(gift_text)
			return
	var lines := texts_broken if not texts_broken.is_empty() and Sanity.state >= Sanity.State.BROKEN else texts
	if lines.is_empty():
		return
	GameState.post_message(lines[_index % lines.size()])
	_index += 1


func _physics_process(delta: float) -> void:
	if behavior != Behavior.FLEE:
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta
	if not _fleeing:
		var player := get_tree().get_first_node_in_group(&"player") as Node3D
		if player and _sees(player):
			_start_flee(player)
		move_and_slide()
		return
	_flee_time += delta
	# Primero se queda duro mirándote (para que se lo llegue a ver) y después corre.
	if _flee_time < 0.0:
		var player := get_tree().get_first_node_in_group(&"player") as Node3D
		if player:
			var to := player.global_position - global_position
			rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), 1.0 - exp(-8.0 * delta))
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	if _anim and anim_run != &"" and _anim.current_animation != anim_run:
		_loop(anim_run)
	# Llega a la puerta (o a lo más cerca que deja el navmesh) y se va por ahí.
	if _target == null or global_position.distance_to(_target.global_position) < 0.9 \
			or (_flee_time > 0.5 and _agent.is_navigation_finished()):
		_vanish()
		return
	var next := _agent.get_next_path_position()
	var dir := next - global_position
	dir.y = 0.0
	if dir.length() > 0.01:
		dir = dir.normalized()
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-10.0 * delta))
	velocity.x = dir.x * flee_speed
	velocity.z = dir.z * flee_speed
	move_and_slide()


func _sees(player: Node3D) -> bool:
	var to := player.global_position - global_position
	if to.length() > flee_sight:
		return false
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.5, player.global_position + Vector3.UP * 1.4, 1)
	query.exclude = [get_rid(), (player as CollisionObject3D).get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _start_flee(player: Node3D) -> void:
	_fleeing = true
	_flee_time = -flee_delay
	var best := -1.0
	for path in flee_targets:
		var t := get_node_or_null(path) as Node3D
		if t and t.global_position.distance_to(player.global_position) > best:
			best = t.global_position.distance_to(player.global_position)
			_target = t
	if _target:
		_agent.target_position = _target.global_position
	if flee_text != "":
		GameState.post_message(flee_text)
	Audio.play_sfx(&"npc_gasp", global_position)


func _vanish() -> void:
	Audio.play_sfx(&"door_open", global_position)
	if flee_flag != &"":
		GameState.set_flag(flee_flag)
	else:
		visible = false
		process_mode = Node.PROCESS_MODE_DISABLED


func is_fleeing() -> bool:
	return _fleeing


func _loop(anim_name: StringName) -> void:
	if _anim == null or anim_name == &"" or not _anim.has_animation(anim_name):
		return
	_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	_anim.play(anim_name, 0.2)


## Se queda quieto en el último cuadro de la animación (dormido, tirado).
func _pose(anim_name: StringName) -> void:
	if _anim == null or anim_name == &"" or not _anim.has_animation(anim_name):
		return
	_anim.play(anim_name)
	_anim.seek(_anim.get_animation(anim_name).length, true)
	_anim.pause()
