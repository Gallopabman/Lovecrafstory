class_name HorrorSighting
extends Node3D
## Baja la cordura la primera vez que el jugador ve este horror
## (en pantalla, dentro de la distancia y sin nada que tape la vista).

@export var horror_id: StringName = &"horror"
@export var first_sight_sanity := 8.0
## Conviene que sea menor que el fin de la niebla: lo que no se ve, no asusta.
@export var max_distance := 14.0
## Altura del punto que tiene que ser visible (la "cara").
@export var eye_height := 1.8
## El placeholder gira para mirar siempre al jugador.
@export var face_player := true

var _check_timer := 0.0

@onready var _notifier: VisibleOnScreenNotifier3D = $VisibleOnScreenNotifier3D


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null:
		return
	if face_player:
		var target := player.global_position
		target.y = global_position.y
		if global_position.distance_squared_to(target) > 0.01:
			look_at(target, Vector3.UP, true)

	if Sanity.has_seen(horror_id):
		return
	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = 0.2
	if _is_seen(player):
		Sanity.register_sighting(horror_id, first_sight_sanity)


func _is_seen(player: Node3D) -> bool:
	if not _notifier.is_on_screen():
		return false
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false
	var eye := global_position + Vector3.UP * eye_height
	var from := camera.global_position
	if from.distance_to(eye) > max_distance:
		return false
	# Solo el escenario (capa 1) tapa la vista; el jugador y los enemigos no.
	var query := PhysicsRayQueryParameters3D.create(from, eye, 1)
	query.exclude = [(player as CollisionObject3D).get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
