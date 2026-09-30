class_name LoopSound
extends AudioStreamPlayer3D
## Sonido en loop en un punto del mundo (fuego, generador, tubo que zumba).
## Busca el sonido por nombre en Audio. Si el nodo se desactiva (ShelterSlot), se pausa.

@export var sound: StringName = &""


func _ready() -> void:
	bus = &"SFX"
	stream = Audio.get_stream(sound)
	if stream == null:
		return
	Audio.set_loop(stream)
	play(randf() * stream.get_length())
