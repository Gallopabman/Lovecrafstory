class_name LostOne
extends Stalker
## El Perdido (GDD): un sobreviviente que llegó a cordura 0 fuera de casa. Vaga por
## la zona donde cayó con todo lo que llevaba encima y es más duro que un acechador.
## Sus habilidades salen de cómo se jugó con ese sobreviviente (GameState.playstyle):
##   tirador   — disparaba mucho: si cayó con un arma de fuego, dispara de lejos.
##   bruto     — peleaba cuerpo a cuerpo: pega más fuerte y más seguido.
##   corredor  — corría todo el tiempo: persigue casi tan rápido como vos corriendo.
##   sigiloso  — andaba agachado: no hace ruido y solo se deja ver de cerca.
##   errante   — sin un estilo marcado: nada especial, pero sigue siendo un Perdido.
## Al matarlo suelta sus cosas y devuelve bastante cordura.

enum Style { WANDERER, SHOOTER, BRUTE, RUNNER, SNEAK }

const STYLE_NAMES := {
	Style.WANDERER: "errante", Style.SHOOTER: "tirador", Style.BRUTE: "bruto",
	Style.RUNNER: "corredor", Style.SNEAK: "sigiloso",
}

## Por debajo de este puntaje no hay estilo dominante (errante).
@export var min_style_score := 4.0
@export var loot_scatter := 0.6

@export_group("Tirador")
@export var ranged_range := 10.0
@export var ranged_min_range := 3.0
@export var ranged_damage := 9.0
@export var ranged_cooldown := 2.4
## Probabilidad de acertar a quemarropa y a distancia máxima.
@export var ranged_accuracy := Vector2(0.85, 0.4)
@export var ranged_hit_time := 0.25

@export_group("Bruto")
@export var brute_damage := 22.0
@export var brute_cooldown := 1.0

@export_group("Corredor")
@export var runner_speed := 4.2

@export_group("Sigiloso")
## Más lejos que esto no se lo ve (aparece de a ratos, como un parpadeo).
@export var sneak_visible_distance := 6.0

var lost_id := -1
var style := Style.WANDERER
var survivor := 0
var items: Array[ItemData] = []

var _ranged_weapon: ItemData
var _muzzle: OmniLight3D
var _is_ranged_attack := false


## Lo llama WorldPersistence antes de agregarlo a la escena.
func setup(data: Dictionary) -> void:
	lost_id = data.id
	survivor = data.survivor
	position = data.position
	items.assign(data.items)
	style = dominant_style(data.style, min_style_score)
	for item in items:
		if item.is_weapon() and item.is_ranged:
			_ranged_weapon = item
	# Sin arma de fuego encima no puede ser tirador: pelea a mano.
	if style == Style.SHOOTER and _ranged_weapon == null:
		style = Style.BRUTE


static func dominant_style(stats: Dictionary, threshold := 4.0) -> Style:
	var scores := {
		Style.SHOOTER: stats.get(&"shots", 0.0) * 1.5,
		Style.BRUTE: stats.get(&"melee", 0.0) * 1.2,
		Style.RUNNER: stats.get(&"run_time", 0.0) / 8.0,
		Style.SNEAK: stats.get(&"crouch_time", 0.0) / 5.0,
	}
	var best := Style.WANDERER
	var best_score := 0.0
	for s: Style in scores:
		if scores[s] > best_score:
			best = s
			best_score = scores[s]
	return best if best_score >= threshold else Style.WANDERER


func style_name() -> String:
	return STYLE_NAMES[style]


func _ready() -> void:
	match style:
		Style.BRUTE:
			attack_damage = brute_damage
			attack_cooldown = brute_cooldown
			anim_attack = SurvivorRig.MELEE
		Style.RUNNER:
			chase_speed = runner_speed
			lose_time *= 2.0
		Style.SNEAK:
			sound_idle = &""
			sound_alert = &""
			sight_range *= 1.3
	var sighting := get_node_or_null(^"HorrorSighting") as HorrorSighting
	if sighting:
		sighting.horror_id = StringName("perdido_%d" % lost_id)
	super._ready()
	if is_queued_for_deletion():
		return
	_hold_weapon()
	_muzzle = OmniLight3D.new()
	_muzzle.light_color = Color(1.0, 0.8, 0.5)
	_muzzle.light_energy = 4.0
	_muzzle.omni_range = 6.0
	_muzzle.position = Vector3(0.0, 1.45, 0.7)
	_muzzle.visible = false
	visual.add_child(_muzzle)
	Sanity.horror_seen.connect(_on_horror_seen)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if style == Style.SNEAK and state != State.DEAD:
		var player := get_tree().get_first_node_in_group(&"player") as Node3D
		var near := player != null and global_position.distance_to(player.global_position) < sneak_visible_distance
		# Lejos, se lo ve apenas un instante de vez en cuando.
		visual.visible = near or fmod(Time.get_ticks_msec() / 1000.0, 3.7) < 0.12


func _chase(delta: float, player: Player, player_valid: bool) -> void:
	if style == Style.SHOOTER and player_valid and _cooldown <= 0.0:
		var distance := global_position.distance_to(player.global_position)
		if distance > ranged_min_range and distance <= ranged_range and _has_line_of_fire(player):
			_is_ranged_attack = true
			_start_attack(SurvivorRig.SHOOT)
			return
	_is_ranged_attack = false
	super._chase(delta, player, player_valid)


func _attack(delta: float, player: Player, player_valid: bool) -> void:
	if not _is_ranged_attack:
		super._attack(delta, player, player_valid)
		return
	_move_towards(Vector3.ZERO, 0.0, delta)
	if player_valid:
		_face(player.global_position, delta * 3.0)
	_attack_timer += delta
	if _attack_hit_pending and _attack_timer >= ranged_hit_time:
		_attack_hit_pending = false
		_flash()
		Audio.play_sfx(&"gunshot", global_position)
		if player_valid and _has_line_of_fire(player):
			var distance := global_position.distance_to(player.global_position)
			var chance := lerpf(ranged_accuracy.x, ranged_accuracy.y, distance / ranged_range)
			# Agachado es más difícil de acertar.
			if player.is_crouching:
				chance *= 0.6
			if randf() < chance:
				Sanity.take_hit(ranged_damage)
	if _attack_timer >= anim_player.get_animation(_attack_anim).length:
		_cooldown = ranged_cooldown
		_is_ranged_attack = false
		state = State.CHASE


func _die() -> void:
	super._die()
	visual.visible = true
	var data := GameState.get_lost_one(lost_id)
	data.defeated = true
	GameState.post_message("El sobreviviente #%d por fin descansa." % survivor)


## Suelta lo que llevaba alrededor del cuerpo.
func loot_positions() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for i in items.size():
		var angle := TAU * i / maxf(items.size(), 1.0)
		result.append(global_position + Vector3(cos(angle), 0.05, sin(angle)) * loot_scatter)
	return result


func _key() -> String:
	return "lost_one_%d" % lost_id


func _has_line_of_fire(player: Player) -> bool:
	var from := global_position + Vector3.UP * 1.4
	var query := PhysicsRayQueryParameters3D.create(from, player.global_position + Vector3.UP * player.eye_height(), 1)
	query.exclude = [get_rid(), player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Lleva en la mano el arma que tenía (la de fuego si era tirador).
func _hold_weapon() -> void:
	var weapon: ItemData = _ranged_weapon if style == Style.SHOOTER else null
	if weapon == null:
		for item in items:
			if item.is_weapon() and not item.is_ranged and item.held_scene:
				weapon = item
	if weapon == null or weapon.held_scene == null:
		return
	var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = SurvivorRig.HAND_BONE
	skeleton.add_child(attachment)
	var held := weapon.held_scene.instantiate() as Node3D
	attachment.add_child(held)
	held.scale = Vector3.ONE / attachment.global_transform.basis.get_scale()
	PS1Materials.apply(held, tint)


func _flash() -> void:
	_muzzle.visible = true
	await get_tree().create_timer(0.06, false).timeout
	if is_instance_valid(_muzzle):
		_muzzle.visible = false


func _on_horror_seen(horror_id: StringName) -> void:
	if horror_id == StringName("perdido_%d" % lost_id):
		GameState.post_message("Tiene la ropa del sobreviviente #%d. Ya no es él." % survivor)
