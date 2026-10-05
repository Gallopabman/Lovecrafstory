class_name SpitProjectile
extends Node3D
## La escupida del Escupidor: una bola de bilis que viaja en línea recta (con un poco de
## caída). Si toca al jugador lo lastima; si pega en el escenario, deja una mancha.

@export var speed := 9.0
@export var damage := 10.0
@export var gravity := 1.5
@export var lifetime := 3.0
@export var splat_time := 6.0

var direction := Vector3.FORWARD
var shooter: Node3D

var _velocity := Vector3.ZERO
var _age := 0.0


func _ready() -> void:
	_velocity = direction * speed


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > lifetime:
		queue_free()
		return
	_velocity.y -= gravity * delta
	var from := global_position
	var to := from + _velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	if shooter and is_instance_valid(shooter):
		query.exclude = [(shooter as CollisionObject3D).get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = to
		rotate_y(delta * 8.0)
		return
	if hit.collider is Player:
		Sanity.take_hit(damage)
		Audio.play_sfx(&"spit_hit", hit.position)
	else:
		Audio.play_sfx(&"spit_splat", hit.position)
		_splat(hit.position, hit.normal)
	queue_free()


## Una mancha que se va borrando.
func _splat(pos: Vector3, normal: Vector3) -> void:
	var stain := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.35
	mesh.bottom_radius = 0.35
	mesh.height = 0.01
	mesh.radial_segments = 8
	stain.mesh = mesh
	var material := ($Ball as MeshInstance3D).material_override.duplicate() as ShaderMaterial
	stain.material_override = material
	get_tree().current_scene.add_child(stain)
	stain.global_position = pos + normal * 0.01
	if absf(normal.dot(Vector3.UP)) < 0.99:
		stain.look_at(stain.global_position + normal, Vector3.UP)
		stain.rotate_object_local(Vector3.RIGHT, PI / 2)
	var tween := stain.create_tween()
	tween.tween_interval(splat_time)
	tween.tween_property(stain, "scale", Vector3(0.1, 1.0, 0.1), 1.0)
	tween.tween_callback(stain.queue_free)
