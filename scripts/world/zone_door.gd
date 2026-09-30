class_name ZoneDoor
extends Area3D
## Puerta entre zonas (mundo interconectado del GDD). Con "interact" lleva a otra
## escena y aparece en el SpawnPoint `target_spawn`. Puede estar trabada hasta que se
## use un objeto (p. ej. forzarla con la barreta); una vez abierta queda abierta.

@export_file("*.tscn") var target_scene := ""
@export var target_spawn: StringName = &""
## Objeto necesario para abrirla la primera vez (vacío = abierta).
@export var required_item: ItemData
## Clave en GameState.flags que marca que ya se abrió.
@export var unlock_flag: StringName = &""
@export_multiline var locked_text := "Está trabada."
@export_multiline var unlock_text := ""
@export var radius := 1.0


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


func is_open() -> bool:
	return required_item == null or GameState.has_flag(unlock_flag)


func interact(_player: Player) -> void:
	if not is_open():
		if not Inventory.all_items().has(required_item):
			GameState.post_message(locked_text)
			Audio.play_sfx(&"door_locked", global_position)
			return
		GameState.set_flag(unlock_flag)
		if unlock_text:
			GameState.post_message(unlock_text)
	GameState.travel(target_scene, target_spawn)
