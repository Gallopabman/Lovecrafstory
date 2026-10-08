extends Area3D
## Área interactuable que le pasa el "interact" a otro nodo (`target`), p. ej. un Npc.

var target: Node
var radius := 1.2
var enabled := true:
	set(value):
		enabled = value
		if _shape:
			_shape.disabled = not value
		if value:
			add_to_group(&"interactable")
		else:
			remove_from_group(&"interactable")

var _shape: CollisionShape3D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	_shape = CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	_shape.shape = sphere
	add_child(_shape)
	enabled = enabled


func interact(player: Node) -> void:
	if enabled and target and target.has_method("interact"):
		target.interact(player)
