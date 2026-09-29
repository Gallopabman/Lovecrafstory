class_name ShelterStation
extends Area3D
## Estación del refugio que se usa con "interact": el plano (abre el menú de
## mejoras), el fuego (cocinar), la cama (descansar) o la radio (música).

enum Kind { BLUEPRINT, COOK, REST, RADIO }

@export var kind := Kind.BLUEPRINT
@export var radius := 0.9


func _ready() -> void:
	add_to_group(&"interactable")
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	add_child(shape)


func interact(_player: Player) -> void:
	match kind:
		Kind.BLUEPRINT:
			var menu := get_tree().get_first_node_in_group(&"shelter_menu")
			if menu:
				menu.open()
		Kind.COOK:
			GameState.post_message(Shelter.cook())
		Kind.REST:
			GameState.post_message(Shelter.rest())
		Kind.RADIO:
			GameState.post_message(Shelter.play_radio())
