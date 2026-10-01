class_name Inspectable
extends Area3D
## Algo que se puede examinar con "interact": muestra un texto breve (estilo
## Silent Hill). No da objetos ni cambia nada; cuenta la historia del lugar.
## Si tiene varios textos, cada vez que se examina muestra el siguiente.

## (Sin @export_multiline: el editor de Godot 4.7 no conserva ese hint en listas y borraba los textos al guardar.)
@export var texts: PackedStringArray = []
## Radio del área en la que el jugador puede examinarlo.
@export var radius := 0.8:
	set(value):
		radius = value
		if _shape:
			(_shape.shape as SphereShape3D).radius = value

var _index := 0
var _shape: CollisionShape3D


func _ready() -> void:
	add_to_group(&"interactable")
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	_shape = CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	_shape.shape = sphere
	add_child(_shape)


func interact(_player: Player) -> void:
	if texts.is_empty():
		return
	GameState.post_message(texts[_index])
	_index = mini(_index + 1, texts.size() - 1)
