class_name RefugeZone
extends Area3D
## Zona del refugio: mientras el jugador está adentro la cordura baja más lento.
## A futuro el multiplicador saldrá del nivel "cozy" (blueprints del refugio).

## Factor aplicado al goteo de cordura (0.25 = baja 4 veces más lento).
@export_range(0.0, 1.0) var drain_multiplier := 0.25
## Habilita películas y música.
@export var has_electricity := true


func _ready() -> void:
	collision_layer = 0
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		Sanity.enter_refuge(self)


func _on_body_exited(body: Node3D) -> void:
	if body is Player:
		Sanity.exit_refuge(self)
