class_name WorldPersistence
extends Node3D
## Reconstruye en el nivel lo que dejaron los sobrevivientes anteriores
## (objetos tirados, cuerpos y Perdidos) y hace aparecer en el piso lo que se tira.

const PICKUP_SCENE := preload("res://scenes/world/pickup.tscn")
const CORPSE_SCENE := preload("res://scenes/world/corpse.tscn")
const LOST_ONE_SCENE := preload("res://scenes/enemies/lost_one.tscn")

## Distancia delante del jugador a la que caen los objetos tirados.
@export var drop_distance := 0.7


func _ready() -> void:
	var here := GameState.current_scene_path()
	for data in GameState.dropped_items:
		if data.scene == here:
			_spawn_pickup(data)
	for data in GameState.corpses:
		if data.scene != here:
			continue
		var corpse := CORPSE_SCENE.instantiate() as Corpse
		corpse.setup(data)
		add_child(corpse)
	for data in GameState.lost_ones_here():
		var lost := LOST_ONE_SCENE.instantiate() as LostOne
		lost.setup(data)
		lost.died.connect(_on_lost_one_died.bind(lost))
		add_child(lost)
	Inventory.item_dropped.connect(_on_item_dropped)


## El Perdido suelta en el piso todo lo que llevaba.
func _on_lost_one_died(lost: LostOne) -> void:
	var positions := lost.loot_positions()
	for i in lost.items.size():
		_spawn_pickup(GameState.add_dropped(lost.items[i], positions[i]))


func _on_item_dropped(item: ItemData) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null:
		return
	var forward := -player.visual.global_basis.z
	var data := GameState.add_dropped(item, player.global_position + forward * drop_distance)
	_spawn_pickup(data)
	GameState.post_message("Dejé %s en el piso." % item.display_name)


func _spawn_pickup(data: Dictionary) -> void:
	var pickup := PICKUP_SCENE.instantiate() as Pickup
	pickup.item = data.item
	pickup.dropped_id = data.id
	pickup.position = data.position
	add_child(pickup)
