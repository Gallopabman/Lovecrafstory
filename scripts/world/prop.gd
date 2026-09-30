@tool
class_name Prop
extends Node3D
## Mobiliario / utilería: instancia un modelo importado, lo escala (por factor o
## por altura real), lo apoya según `anchor`, lo pasa al shader PS1 (con colores
## por material opcionales) y le genera una colisión de caja a partir de su AABB.
## Funciona en el editor (@tool) para poder acomodar los muebles a ojo.

enum Anchor {
	## Apoyado en el piso: el origen queda abajo al centro.
	FLOOR,
	## Colgado del techo: el origen queda arriba al centro.
	CEILING,
	## Contra la pared: el origen queda en el centro de la cara de atrás (el frente mira a +Z).
	WALL,
	## Respeta el origen del modelo (piezas modulares que encastran entre sí: calles, edificios).
	ORIGIN,
}

@export var model: PackedScene:
	set(value):
		model = value
		_rebuild()
## Escala uniforme (Kenney Furniture Kit viene a la mitad del tamaño real: 2.0).
@export var model_scale := 1.0:
	set(value):
		model_scale = value
		_rebuild()
## Si es > 0, ignora `model_scale` y escala para que el modelo mida esta altura en metros.
@export var fit_height := 0.0:
	set(value):
		fit_height = value
		_rebuild()
## Si es > 0 (y no hay `fit_height`), escala para que la dimensión más grande mida esto.
## Útil para cosas planas (manchas, alfombras) donde la altura no sirve.
@export var fit_largest := 0.0:
	set(value):
		fit_largest = value
		_rebuild()
## Rotación del modelo dentro del prop (para corregir modelos con otro "arriba" o "frente").
@export var model_rotation := Vector3.ZERO:
	set(value):
		model_rotation = value
		_rebuild()
@export var anchor := Anchor.FLOOR:
	set(value):
		anchor = value
		_rebuild()
@export var tint := Color.WHITE:
	set(value):
		tint = value
		_rebuild()
## Colores por nombre de material del modelo (p. ej. {"carpet": Color(...)}).
@export var material_colors: Dictionary = {}:
	set(value):
		material_colors = value
		_rebuild()
@export var collision := true:
	set(value):
		collision = value
		_rebuild()

var _instance: Node3D
var _body: StaticBody3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_node_ready():
		return
	if _instance:
		_instance.free()
		_instance = null
	if _body:
		_body.free()
		_body = null
	if model == null:
		return
	# Nodos internos sin owner: no se guardan en la escena.
	_instance = model.instantiate() as Node3D
	add_child(_instance)
	_instance.rotation_degrees = model_rotation
	var raw := _local_aabb()
	var s := model_scale
	if fit_height > 0.0 and raw.size.y > 0.0001:
		s = fit_height / raw.size.y
	elif fit_largest > 0.0:
		var largest := maxf(raw.size.x, maxf(raw.size.y, raw.size.z))
		if largest > 0.0001:
			s = fit_largest / largest
	_instance.scale = Vector3.ONE * s
	var box := _local_aabb()
	var offset := Vector3.ZERO
	match anchor:
		Anchor.FLOOR:
			offset = -Vector3(box.get_center().x, box.position.y, box.get_center().z)
		Anchor.CEILING:
			offset = -Vector3(box.get_center().x, box.end.y, box.get_center().z)
		Anchor.WALL:
			offset = -Vector3(box.get_center().x, box.get_center().y, box.position.z)
	_instance.position = offset
	PS1Materials.apply(_instance, tint, material_colors)
	if collision:
		_body = StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = box.size.max(Vector3.ONE * 0.05)
		shape.shape = box_shape
		shape.position = box.get_center() + offset
		_body.add_child(shape)
		add_child(_body)


## AABB del modelo en el espacio de este nodo (sin depender de estar en el árbol).
func _local_aabb() -> AABB:
	var result := AABB()
	var first := true
	for mesh_instance: MeshInstance3D in _instance.find_children("*", "MeshInstance3D", true, false):
		if mesh_instance.mesh == null:
			continue
		var xform := _relative_transform(mesh_instance)
		var box := xform * mesh_instance.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


func _relative_transform(node: Node3D) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != self:
		if current is Node3D:
			xform = (current as Node3D).transform * xform
		current = current.get_parent()
	return xform
