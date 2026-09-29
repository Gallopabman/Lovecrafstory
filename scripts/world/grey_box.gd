@tool
class_name GreyBox
extends StaticBody3D
## Caja de greyboxing: genera malla subdividida + colisión a partir de `size`.
## La subdivisión evita que el mapeo afín y la niebla por vértice se deformen
## en polígonos grandes (los juegos de PS1 hacían lo mismo).

@export var size := Vector3.ONE:
	set(value):
		size = value
		_rebuild()
@export var subdivisions_per_meter := 1.0:
	set(value):
		subdivisions_per_meter = value
		_rebuild()
@export var material: Material:
	set(value):
		material = value
		_rebuild()

var _mesh_instance: MeshInstance3D
var _collision: CollisionShape3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_node_ready():
		return
	if _mesh_instance == null:
		# Nodos internos sin owner: no se guardan en la escena.
		_mesh_instance = MeshInstance3D.new()
		add_child(_mesh_instance)
		_collision = CollisionShape3D.new()
		add_child(_collision)

	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.subdivide_width = _subdivisions(size.x)
	mesh.subdivide_height = _subdivisions(size.y)
	mesh.subdivide_depth = _subdivisions(size.z)
	mesh.material = material
	_mesh_instance.mesh = mesh

	var shape := BoxShape3D.new()
	shape.size = size
	_collision.shape = shape


func _subdivisions(length: float) -> int:
	return maxi(0, ceili(length * subdivisions_per_meter) - 1)
