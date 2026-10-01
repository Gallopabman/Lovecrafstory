class_name RefugeZone
extends Area3D
## Zona del refugio: mientras el jugador está adentro la locura baja.
## Con `use_shelter` el goteo y la electricidad salen del blueprint (autoload
## Shelter: nivel cozy y generador) y la zona solo cuenta si `refuge_id` es el
## refugio activo (hay uno solo; los demás son lugares donde se podría vivir).
## Sin `use_shelter`, valores fijos de abajo.

@export var use_shelter := false
@export var refuge_id: StringName = &"hospital"
## Multiplicador de lo rápido que baja la locura adentro. Sin `use_shelter`.
@export var recovery_multiplier := 1.0
## Habilita películas y música. Sin `use_shelter`.
@export var has_electricity := true

var _player_inside := false


func _ready() -> void:
	collision_layer = 0
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	Shelter.moved.connect(func(_refuge: StringName) -> void: _update())


func is_home() -> bool:
	return not use_shelter or Shelter.is_active(refuge_id)


func current_recovery_multiplier() -> float:
	return Shelter.recovery_multiplier(refuge_id) if use_shelter else recovery_multiplier


func current_has_electricity() -> bool:
	return Shelter.has_electricity(refuge_id) if use_shelter else has_electricity


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		_player_inside = true
		_update()


func _on_body_exited(body: Node3D) -> void:
	if body is Player:
		_player_inside = false
		_update()


func _update() -> void:
	if _player_inside and is_home():
		Sanity.enter_refuge(self)
	else:
		Sanity.exit_refuge(self)
