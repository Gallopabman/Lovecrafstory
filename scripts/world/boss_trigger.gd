class_name BossTrigger
extends Area3D
## Despierta al jefe cuando el jugador entra a su arena.

@export var boss: NodePath


func _ready() -> void:
	collision_layer = 0
	body_entered.connect(func(body: Node3D) -> void:
		var target := get_node_or_null(boss) as Boss
		if body is Player and target:
			target.awaken())
