class_name ShelterSlot
extends Node3D
## Un espacio fijo del blueprint del refugio (fuego, cama, ventanas...).
## Muestra la versión que corresponde al nivel actual según el nombre de cada hijo:
##   "Only<n>..." visible solo en el nivel n  (p. ej. Only0 = el colchón en el piso)
##   "From<n>..." visible desde el nivel n    (p. ej. From1Lights = luces con el generador)
## Los hijos ocultos se desactivan (luces, colisiones y estaciones incluidas).

@export var slot_id: StringName = &"fire"


func _ready() -> void:
	Shelter.slot_upgraded.connect(func(slot: StringName, _level: int) -> void:
		if slot == slot_id:
			_apply())
	_apply()


func _apply() -> void:
	var current := Shelter.level(slot_id)
	for child in get_children():
		var child_name := String(child.name)
		var present := true
		if child_name.begins_with("Only"):
			present = current == int(child_name.substr(4, 1))
		elif child_name.begins_with("From"):
			present = current >= int(child_name.substr(4, 1))
		if child is Node3D:
			(child as Node3D).visible = present
		child.process_mode = Node.PROCESS_MODE_INHERIT if present else Node.PROCESS_MODE_DISABLED
