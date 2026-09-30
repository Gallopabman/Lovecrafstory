class_name SpawnPoint
extends Marker3D
## Lugar donde aparece el jugador al entrar a la zona por una ZoneDoor.
## El jugador queda mirando hacia -Z del marcador.

@export var spawn_id: StringName = &""


func _ready() -> void:
	add_to_group(&"spawn_points")
