class_name DiscoveryZone
extends Area3D
## Un lugar del mundo (una habitación, un pasillo). La primera vez que el jugador
## entra cuenta como descubrimiento para el bono de llegar a casa (GDD).

@export var place_id: StringName = &""
@export var size := Vector3(4, 3, 4)


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	add_child(shape)
	body_entered.connect(func(body: Node3D) -> void:
		if body is Player:
			Shelter.discover(place_id))
