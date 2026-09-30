class_name LevelAudio
extends Node
## Sonido de una zona: loop de ambiente, pasos y (opcional) música.
## Con poca cordura se suma un zumbido grave encima del ambiente.

@export var ambience: StringName = &""
@export var ambience_db := -6.0
@export var footstep: StringName = &"step"
@export var music: StringName = &""
@export var drone: StringName = &"drone"
@export var drone_max_db := -4.0

var _drone: AudioStreamPlayer


func _ready() -> void:
	Audio.footstep = footstep
	Audio.set_ambience(ambience, ambience_db)
	Audio.play_music(music)
	var stream := Audio.get_stream(drone)
	if stream:
		_drone = AudioStreamPlayer.new()
		_drone.bus = &"Ambience"
		_drone.stream = stream
		_drone.volume_db = -60.0
		add_child(_drone)
		Audio.set_loop(stream)
		_drone.play()


func _process(_delta: float) -> void:
	if _drone:
		# El zumbido aparece desde Inquieto y crece hasta el borde.
		var t := clampf(inverse_lerp(0.2, 1.0, Sanity.insanity()), 0.0, 1.0)
		_drone.volume_db = lerpf(-60.0, drone_max_db, sqrt(t))
