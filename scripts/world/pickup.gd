class_name Pickup
extends Area3D
## Objeto recogible. El jugador lo toma con "interact" estando cerca.

const PS1_SHADER := preload("res://shaders/ps1_spatial.gdshader")

@export var item: ItemData
@export var count := 1

@onready var _mesh: MeshInstance3D = $Mesh


func _ready() -> void:
	add_to_group(&"interactable")
	if item:
		var material := ShaderMaterial.new()
		material.shader = PS1_SHADER
		material.set_shader_parameter(&"albedo_color", item.world_color)
		_mesh.material_override = material


func _process(delta: float) -> void:
	_mesh.rotate_y(delta * 0.8)


func interact(_player: Player) -> void:
	if item:
		Inventory.add(item, count)
	queue_free()
