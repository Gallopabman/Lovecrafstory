class_name ShelterStation
extends Area3D
## Estación del refugio que se usa con "interact": el plano (abre el menú de
## mejoras), el fuego (cocinar), la cama (descansar), la radio (música) o el alijo.

enum Kind { BLUEPRINT, COOK, REST, RADIO, STASH }

@export var kind := Kind.BLUEPRINT
@export var radius := 0.9
## A qué refugio pertenece (Shelter.REFUGES).
@export var refuge_id: StringName = &"hospital"
## Cuánto suena la radio al prenderla.
@export var radio_seconds := 45.0

var _radio: AudioStreamPlayer3D


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


func interact(_player: Player) -> void:
	match kind:
		Kind.BLUEPRINT:
			var menu := get_tree().get_first_node_in_group(&"shelter_menu")
			if menu:
				menu.open(refuge_id)
		Kind.COOK:
			GameState.post_message(Shelter.cook(refuge_id))
		Kind.REST:
			GameState.post_message(Shelter.rest(refuge_id))
		Kind.STASH:
			# Solo en casa: el alijo vive en el refugio activo.
			if not Shelter.is_active(refuge_id):
				GameState.post_message("Todavía no vivo acá. Mis cosas están en %s." % Shelter.refuge_name())
				return
			var stash := get_tree().get_first_node_in_group(&"stash_menu")
			if stash:
				stash.open()
		Kind.RADIO:
			var worked := Shelter.level(&"power", refuge_id) >= 2 and Shelter.radio_ready()
			GameState.post_message(Shelter.play_radio(refuge_id))
			_play_radio(worked)


## Un tango entre la estática (o solo estática si no anda o ya sonó).
func _play_radio(worked: bool) -> void:
	if _radio and _radio.playing:
		return
	if _radio == null:
		_radio = AudioStreamPlayer3D.new()
		_radio.bus = &"SFX"
		_radio.unit_size = 3.0
		add_child(_radio)
	_radio.stream = Audio.get_stream(&"radio_music" if worked else &"radio_static")
	if _radio.stream == null:
		return
	_radio.volume_db = -4.0 if worked else -10.0
	_radio.play()
	var tween := create_tween()
	tween.tween_interval(radio_seconds if worked else 3.0)
	tween.tween_property(_radio, "volume_db", -60.0, 2.0)
	tween.tween_callback(_radio.stop)
