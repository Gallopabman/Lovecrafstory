class_name FlagGate
extends Node3D
## Algo que bloquea el paso hasta que se marca `flag` en GameState (p. ej. la puerta
## del camarín, trabada mientras vive el jefe). Sus hijos Node3D son el bloqueo:
## se ocultan y se desactivan al abrirse. Con "interact" cerca muestra `locked_text`.

@export var flag: StringName = &""
@export_multiline var locked_text := "No abre."
@export_multiline var open_text := ""
@export var radius := 1.2

var _area: Area3D


func _ready() -> void:
	_area = Area3D.new()
	_area.collision_layer = 4
	_area.collision_mask = 0
	_area.monitoring = false
	_area.add_to_group(&"interactable")
	_area.set_script(load("res://scripts/world/flag_gate_area.gd"))
	_area.set("gate", self)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	_area.add_child(shape)
	_area.position = Vector3.UP * 1.2
	add_child(_area)
	GameState.flag_set.connect(func(f: StringName) -> void:
		if f == flag:
			_apply(true))
	_apply(false)


func is_open() -> bool:
	return GameState.has_flag(flag)


func _apply(announce: bool) -> void:
	var open := is_open()
	for child in get_children():
		if child == _area or not child is Node3D:
			continue
		(child as Node3D).visible = not open
		child.process_mode = Node.PROCESS_MODE_DISABLED if open else Node.PROCESS_MODE_INHERIT
	_area.process_mode = Node.PROCESS_MODE_DISABLED if open else Node.PROCESS_MODE_INHERIT
	if open:
		_area.remove_from_group(&"interactable")
		if announce:
			Audio.play_sfx(&"door_open", global_position)
			if open_text:
				GameState.post_message(open_text)


func show_locked() -> void:
	GameState.post_message(locked_text)
	Audio.play_sfx(&"door_locked", global_position)
