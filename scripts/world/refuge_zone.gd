class_name RefugeZone
extends Area3D
## Zona del refugio: mientras el jugador está adentro la cordura baja más lento.
## Con `use_shelter` el goteo y la electricidad salen del blueprint (autoload
## Shelter: nivel cozy y generador); si no, de los valores fijos de abajo.

@export var use_shelter := false
## Factor aplicado al goteo de cordura (0.25 = baja 4 veces más lento). Sin `use_shelter`.
@export_range(0.0, 1.0) var drain_multiplier := 0.25
## Habilita películas y música. Sin `use_shelter`.
@export var has_electricity := true


func _ready() -> void:
	collision_layer = 0
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func current_drain_multiplier() -> float:
	return Shelter.drain_multiplier() if use_shelter else drain_multiplier


func current_has_electricity() -> bool:
	return Shelter.has_electricity() if use_shelter else has_electricity


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		Sanity.enter_refuge(self)


func _on_body_exited(body: Node3D) -> void:
	if body is Player:
		Sanity.exit_refuge(self)
