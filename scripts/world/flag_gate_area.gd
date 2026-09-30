extends Area3D
## Área interactuable de un FlagGate (lo crea el propio gate).

var gate: Node


func interact(_player: Player) -> void:
	gate.show_locked()
