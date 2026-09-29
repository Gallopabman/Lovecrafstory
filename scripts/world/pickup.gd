class_name Pickup
extends Area3D
## Objeto recogible. El jugador lo toma con "interact" estando cerca.
## Si no entra en la mochila, se queda en el piso.

const PS1_SHADER := preload("res://shaders/ps1_spatial.gdshader")

@export var item: ItemData
@export var count := 1

## >= 0 si es un objeto que tiró el jugador (lo registra GameState).
var dropped_id := -1

@onready var _mesh: MeshInstance3D = $Mesh


func _ready() -> void:
	if dropped_id < 0 and GameState.is_collected(_key()):
		queue_free()
		return
	add_to_group(&"interactable")
	if item and item.held_scene:
		# Armas: se muestra su modelo real, acostado y girando.
		var model := item.held_scene.instantiate() as Node3D
		model.rotation_degrees = item.pickup_rotation
		model.position.y = 0.1
		_mesh.mesh = null
		_mesh.add_child(model)
		PS1Materials.apply(model)
	elif item:
		var material := ShaderMaterial.new()
		material.shader = PS1_SHADER
		material.set_shader_parameter(&"albedo_color", item.world_color)
		_mesh.material_override = material
		# El placeholder toma la forma del objeto en la mochila.
		_mesh.scale = Vector3(item.grid_size.x, 1.0, item.grid_size.y) if not item.is_letter() else Vector3(1.0, 0.3, 1.0)


func _process(delta: float) -> void:
	_mesh.rotate_y(delta * 0.8)


func interact(_player: Player) -> void:
	if item == null:
		return
	while count > 0 and Inventory.add(item):
		count -= 1
	if count > 0:
		GameState.post_message("No me entra en la mochila.")
		return
	if dropped_id >= 0:
		GameState.remove_dropped(dropped_id)
	else:
		GameState.mark_collected(_key())
	queue_free()


func _key() -> String:
	return String(get_path())
