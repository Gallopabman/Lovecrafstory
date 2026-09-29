class_name Corpse
extends Area3D
## Cuerpo de un sobreviviente que murió en el refugio (su corazón no aguantó).
## Queda en el piso con todo lo que llevaba; el siguiente puede revisarlo.

var corpse_id := -1

@onready var model: Node3D = $Model


func _ready() -> void:
	add_to_group(&"interactable")
	PS1Materials.apply(model, Color(0.75, 0.72, 0.72))
	# Congela la última pose de la animación de muerte.
	var anim_player := SurvivorRig.setup(model)
	anim_player.play(SurvivorRig.DEATH)
	anim_player.seek(anim_player.get_animation(SurvivorRig.DEATH).length, true)
	anim_player.pause()


func setup(data: Dictionary) -> void:
	corpse_id = data.id
	position = data.position
	rotation.y = data.yaw


func interact(_player: Player) -> void:
	var data := GameState.get_corpse(corpse_id)
	if data.is_empty() or data.items.is_empty():
		GameState.post_message("Ya no tiene nada. Descansa.")
		return
	var remaining: Array[ItemData] = []
	for item: ItemData in data.items:
		if not Inventory.add(item):
			remaining.append(item)
	data.items = remaining
	GameState.post_message("Recuperé sus cosas." if remaining.is_empty() else "No me entra todo lo que tenía.")
