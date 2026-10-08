class_name KeyLock
extends Area3D
## Una cerradura que se abre una sola vez con una llave de la mochila (p. ej. la celda del
## Flaco en la comisaría): marca `unlock_flag`. Lo que bloquea va adentro de un FlagGate con
## el mismo flag, que lo saca al abrirse.

@export var required_item: ItemData
@export var unlock_flag: StringName = &""
## Sin la llave. Si hay varios textos, cada vez que se insiste muestra el siguiente.
@export var locked_texts: PackedStringArray = ["Está cerrado con llave."]
@export var unlock_text := ""
@export var radius := 1.2

var _index := 0
var _shape: CollisionShape3D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	_shape = CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	_shape.shape = sphere
	add_child(_shape)
	GameState.flag_set.connect(func(_f: StringName) -> void: _refresh())
	_refresh()


func is_open() -> bool:
	return GameState.has_flag(unlock_flag)


func _refresh() -> void:
	var open := is_open()
	_shape.disabled = open
	if open:
		remove_from_group(&"interactable")
	else:
		add_to_group(&"interactable")


func interact(_player: Node) -> void:
	if is_open():
		return
	if required_item and Inventory.all_items().has(required_item):
		Audio.play_sfx(&"door_unlock", global_position)
		if unlock_text != "":
			GameState.post_message(unlock_text)
		GameState.set_flag(unlock_flag)
		return
	if not locked_texts.is_empty():
		GameState.post_message(locked_texts[_index % locked_texts.size()])
		_index += 1
