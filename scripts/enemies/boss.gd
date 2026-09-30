class_name Boss
extends Stalker
## Jefe de zona: mucho más duro que un acechador. Duerme hasta que el jugador
## entra a su arena (`awaken`, lo llama un BossTrigger o recibir un disparo).
## - No se tambalea con cada golpe: acumula daño hasta `stagger_threshold`.
## - Grito: a distancia media, cada tanto, lastima la cordura aunque no te toque.
## - Furia: por debajo de `enrage_ratio` de vida es más rápido y ataca más seguido.
## Al morir marca `death_flag` en GameState (abre lo que estaba cerrado) y corta la música.

signal awakened

@export var death_flag: StringName = &""
@export var music: StringName = &"boss_music"
@export_multiline var awaken_text := ""
@export_multiline var death_text := ""

@export_group("Animaciones del jefe")
@export var anim_roar: StringName = &""
@export var anim_scream: StringName = &""

@export_group("Grito")
@export var scream_range := 11.0
@export var scream_min_range := 3.0
@export var scream_sanity := 7.0
@export var scream_cooldown := 9.0
## Momento del grito dentro de la animación.
@export var scream_hit_time := 0.5
@export var sound_scream: StringName = &"boss_roar"

@export_group("Aguante y furia")
## Daño acumulado que hace falta para que se tambalee.
@export var stagger_threshold := 70.0
@export_range(0.0, 1.0) var enrage_ratio := 0.5
@export var enrage_speed_multiplier := 1.3
@export var enrage_cooldown_multiplier := 0.65

var dormant := true
var enraged := false

var _scream_timer := 0.0
var _is_scream := false
var _damage_since_stagger := 0.0
var _hurt_sound_timer := 0.0


func _ready() -> void:
	super._ready()
	if is_queued_for_deletion():
		return
	_scream_timer = scream_cooldown * 0.5
	# Dormido: invisible y sin cuerpo hasta que empieza la pelea.
	visual.visible = false
	collision_layer = 0
	set_physics_process(false)


func awaken() -> void:
	if not dormant or state == State.DEAD:
		return
	dormant = false
	visual.visible = true
	collision_layer = 2
	set_physics_process(true)
	_since_seen = 0.0
	state = State.CHASE
	Audio.play_music(music)
	Audio.play_sfx(sound_scream, global_position, 4.0)
	Sanity.shocked.emit(0.8)
	if anim_roar != &"":
		_start_attack(anim_roar)
		_attack_hit_pending = false
		_is_scream = true
	if awaken_text:
		GameState.post_message(awaken_text)
	awakened.emit()


func take_damage(amount: float) -> void:
	if dormant:
		awaken()
	if state == State.DEAD:
		return
	_damage_since_stagger += amount
	if _damage_since_stagger < stagger_threshold and health - amount > 0.0:
		# Aguanta el golpe sin frenarse: solo destella.
		health -= amount
		_flash_timer = hit_flash_time
		_since_seen = 0.0
		if _hurt_sound_timer <= 0.0:
			Audio.play_sfx(sound_hurt, global_position)
			_hurt_sound_timer = 0.6
		_check_enrage()
		return
	_damage_since_stagger = 0.0
	_is_scream = false
	super.take_damage(amount)
	_check_enrage()


func _physics_process(delta: float) -> void:
	_scream_timer = maxf(_scream_timer - delta, 0.0)
	_hurt_sound_timer = maxf(_hurt_sound_timer - delta, 0.0)
	super._physics_process(delta)


func _chase(delta: float, player: Player, player_valid: bool) -> void:
	if player_valid and _scream_timer <= 0.0:
		var distance := global_position.distance_to(player.global_position)
		if distance > scream_min_range and distance <= scream_range:
			_scream_timer = scream_cooldown * (enrage_cooldown_multiplier if enraged else 1.0)
			_is_scream = true
			_start_attack(anim_scream if anim_scream != &"" else anim_attack)
			return
	_is_scream = false
	super._chase(delta, player, player_valid)


func _attack(delta: float, player: Player, player_valid: bool) -> void:
	if not _is_scream:
		super._attack(delta, player, player_valid)
		return
	_move_towards(Vector3.ZERO, 0.0, delta)
	if player_valid:
		_face(player.global_position, delta)
	_attack_timer += delta
	if _attack_hit_pending and _attack_timer >= scream_hit_time:
		_attack_hit_pending = false
		Audio.play_sfx(sound_scream, global_position, 3.0)
		if player_valid and global_position.distance_to(player.global_position) <= scream_range * 1.2:
			Sanity.take_hit(scream_sanity)
	if _attack_timer >= anim_player.get_animation(_attack_anim).length:
		_is_scream = false
		state = State.CHASE


func _die() -> void:
	super._die()
	Audio.play_music(&"")
	if death_flag != &"":
		GameState.set_flag(death_flag)
	if death_text:
		GameState.post_message(death_text)


func _check_enrage() -> void:
	if enraged or health > max_health * enrage_ratio:
		return
	enraged = true
	chase_speed *= enrage_speed_multiplier
	attack_cooldown *= enrage_cooldown_multiplier
	Audio.play_sfx(sound_scream, global_position, 4.0)
	Sanity.shocked.emit(0.5)
