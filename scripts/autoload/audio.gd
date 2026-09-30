extends Node
## Autoload "Audio": efectos, ambiente, música y volumen.
## Los sonidos se buscan por nombre en `assets/audio/{sfx,ambience,music}/`:
## "step" usa step.ogg o, si hay variantes, step_1.ogg, step_2.ogg... al azar.
## Si un sonido no existe no pasa nada (así se puede cablear antes de tenerlo).
## Buses: Master, Music, SFX, Ambience (se crean acá si no están).

const FOLDERS := {
	&"sfx": "res://assets/audio/sfx/",
	&"ambience": "res://assets/audio/ambience/",
	&"music": "res://assets/audio/music/",
}
const EXTENSIONS: Array[String] = ["ogg", "wav", "mp3"]
const SETTINGS_PATH := "user://settings.cfg"

@export var pitch_variation := 0.08
@export var crossfade_time := 2.0
@export var sfx_max_distance := 30.0
## Latido: arranca en este estado de cordura y sube de volumen hasta el borde.
@export var heartbeat_min_db := -18.0
@export var heartbeat_max_db := 0.0

## 0..1, lo cambia el menú de opciones.
var master_volume := 0.8
## Sonido de pasos de la zona actual (lo fija LevelAudio).
var footstep: StringName = &"step"

var _library: Dictionary = {}
var _ambience: AudioStreamPlayer
var _ambience_name: StringName = &""
var _music: AudioStreamPlayer
var _music_name: StringName = &""
var _heartbeat: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in [&"Music", &"SFX", &"Ambience"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, &"Master")
	_scan()
	_ambience = _make_player(&"Ambience")
	_music = _make_player(&"Music")
	_heartbeat = _make_player(&"SFX")
	_heartbeat.stream = get_stream(&"heartbeat")
	load_settings()
	Sanity.horror_seen.connect(func(_id: StringName) -> void: play_sfx(&"scare", null, -3.0))
	Inventory.item_added.connect(func(_item: ItemData) -> void: play_ui(&"pickup"))
	Inventory.add_failed.connect(func(_item: ItemData) -> void: play_ui(&"menu_back"))


func _process(_delta: float) -> void:
	_update_heartbeat()


## Stream por nombre (una variante al azar), o null.
func get_stream(sound: StringName) -> AudioStream:
	var variants: Array = _library.get(sound, [])
	return variants.pick_random() if not variants.is_empty() else null


func has_sound(sound: StringName) -> bool:
	return _library.has(sound)


## Efecto. Con `position` suena en 3D en ese punto; sin ella, plano (UI).
func play_sfx(sound: StringName, position: Variant = null, volume_db := 0.0) -> void:
	var stream := get_stream(sound)
	if stream == null:
		return
	var node: Node
	if position is Vector3 and get_tree().current_scene is Node3D:
		var player3d := AudioStreamPlayer3D.new()
		player3d.max_distance = sfx_max_distance
		player3d.unit_size = 4.0
		player3d.volume_db = volume_db
		player3d.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
		player3d.bus = &"SFX"
		player3d.stream = stream
		player3d.finished.connect(player3d.queue_free)
		get_tree().current_scene.add_child(player3d)
		player3d.global_position = position
		player3d.play()
		node = player3d
	else:
		var player := AudioStreamPlayer.new()
		player.volume_db = volume_db
		player.pitch_scale = 1.0 + randf_range(-pitch_variation * 0.5, pitch_variation * 0.5)
		player.bus = &"SFX"
		player.stream = stream
		player.finished.connect(player.queue_free)
		add_child(player)
		player.play()
		node = player
	# Los efectos de pausa (UI) se escuchan con el juego pausado.
	node.process_mode = Node.PROCESS_MODE_ALWAYS if get_tree().paused else Node.PROCESS_MODE_PAUSABLE


func play_ui(sound: StringName) -> void:
	play_sfx(sound, null, -4.0)


## Loop de ambiente de la zona (con fundido). Nombre vacío = silencio.
func set_ambience(sound: StringName, volume_db := 0.0) -> void:
	if sound == _ambience_name:
		return
	_ambience_name = sound
	_crossfade(_ambience, get_stream(sound), volume_db)


func play_music(sound: StringName, volume_db := 0.0) -> void:
	if sound == _music_name:
		return
	_music_name = sound
	_crossfade(_music, get_stream(sound), volume_db)


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	var bus := AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(master_volume))
	AudioServer.set_bus_mute(bus, master_volume <= 0.001)


func save_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("audio", "master_volume", master_volume)
	config.save(SETTINGS_PATH)


func load_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	set_master_volume(config.get_value("audio", "master_volume", master_volume))


func _crossfade(player: AudioStreamPlayer, stream: AudioStream, volume_db: float) -> void:
	var tween := create_tween()
	if player.playing:
		tween.tween_property(player, "volume_db", -60.0, crossfade_time * 0.5)
	tween.tween_callback(func() -> void:
		player.stop()
		player.stream = stream
		if stream:
			set_loop(stream)
			player.volume_db = -60.0
			player.play())
	if stream:
		tween.tween_property(player, "volume_db", volume_db, crossfade_time * 0.5)


func _update_heartbeat() -> void:
	if _heartbeat.stream == null:
		return
	var in_game := get_tree().get_first_node_in_group(&"player") != null
	var ratio := Sanity.ratio()
	var broken := Sanity.state >= Sanity.State.BROKEN and Sanity.state != Sanity.State.LOST
	if in_game and broken and not get_tree().paused:
		# 0 al entrar en Quebrado (40 %), 1 al borde de perderse.
		var t := clampf(inverse_lerp(0.4, 0.0, ratio), 0.0, 1.0)
		_heartbeat.volume_db = lerpf(heartbeat_min_db, heartbeat_max_db, t)
		_heartbeat.pitch_scale = lerpf(1.0, 1.5, t)
		if not _heartbeat.playing:
			set_loop(_heartbeat.stream)
			_heartbeat.play()
	elif _heartbeat.playing:
		_heartbeat.stop()


func _make_player(bus: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	add_child(player)
	return player


func set_loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_end = int(wav.get_length() * wav.mix_rate)


func _scan() -> void:
	var numbered := RegEx.create_from_string("_\\d+$")
	for folder: String in FOLDERS.values():
		if not DirAccess.dir_exists_absolute(folder):
			continue
		for file in ResourceLoader.list_directory(folder):
			if not file.get_extension() in EXTENSIONS:
				continue
			var sound := StringName(numbered.sub(file.get_basename(), ""))
			if not _library.has(sound):
				_library[sound] = []
			_library[sound].append(load(folder + file))
