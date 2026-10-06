extends Node
## Autoload "Sanity": la cabeza del sobreviviente. En pantalla es la **locura**
## (pedido del usuario): `madness()` = 1 - cordura. Por dentro se sigue llevando la
## cordura (`current`, 0..`maximum`) porque de ella salen los estados del GDD.
## - Afuera la locura sube de a poco (goteo); en el refugio activo baja (más rápido
##   cuanto más cómodo es). Ver horrores nuevos y los gritos la suben de golpe.
## - Los objetos de esperanza la bajan. Al 100 % de locura el personaje se pierde.
## - La **dificultad** sale de la locura (Normal / Difícil / Insane): el jugador pega
##   menos, recibe más daño (Health) y aparecen más enemigos (DifficultySpawn).
## Los golpes físicos bajan la vida (autoload Health): `take_hit` los deriva ahí.

signal changed(current: float, maximum: float)
signal state_changed(new_state: State, old_state: State)
## Golpe o susto: `strength` 0..1 para efectos de pantalla.
signal shocked(strength: float)
signal hit_taken(amount: float)
signal horror_seen(horror_id: StringName)
## Locura al 100 %. Ver `lost_in_refuge` para saber cómo terminó.
signal lost
## El jugador llegó al refugio / salió de él (para el bono de llegar a casa).
signal refuge_entered
signal refuge_exited
signal difficulty_changed(level: int, previous: int)

## Rangos en % de la cordura máxima (tabla "Estados de cordura" del GDD).
enum State { LUCID, UNEASY, BROKEN, BRINK, LOST }
const STATE_NAMES := {
	State.LUCID: "Lúcido",
	State.UNEASY: "Inquieto",
	State.BROKEN: "Quebrado",
	State.BRINK: "Al borde",
	State.LOST: "Perdido",
}
enum Difficulty { NORMAL, HARD, INSANE }
const DIFFICULTY_NAMES := ["Normal", "Difícil", "Insane"]

@export var base_maximum := 100.0
## Goteo constante fuera del refugio: la locura llena la barra en ~3.7 minutos (pedido del usuario:
## "más violenta la subida"; antes, 0.15 = ~11 minutos).
@export var drain_per_second := 0.45
## Mientras algún enemigo te persigue o te ataca cerca, la locura sube más rápido.
@export var chase_drain_multiplier := 2.0
@export var chase_range := 15.0
## Locura que suma cada golpe (además de la vida que saca).
@export var hit_madness := 4.0
## Lo que baja la locura por segundo en el refugio activo, de a poco (x el multiplicador del
## refugio: x1 pelado, x3 con todas las mejoras = de ~14 a ~4.6 minutos para vaciarla).
@export var refuge_recovery_per_second := 0.12
@export var uneasy_below := 0.7
@export var broken_below := 0.4
@export var brink_below := 0.15
## Si la locura al 100 % mata (el Perdido / el infarto en el refugio, como pedía el GDD). Pedido del
## usuario: no; con la locura llena el juego solo se pone mucho más difícil (ver `full_madness_*`).
@export var full_madness_kills := false
## Con la locura al 100 %: lo que pega el jugador y lo que recibe (un escalón más que Insane).
@export var full_madness_damage_multiplier := 0.5
@export var full_madness_damage_taken_multiplier := 2.2

@export_group("Dificultad")
## Locura (0..1) desde la que el juego pasa a Difícil y a Insane.
@export var hard_from := 0.5
@export var insane_from := 0.75
## Daño que hace el jugador según la dificultad.
@export var player_damage_multipliers: Array[float] = [1.0, 0.8, 0.6]
## Daño que recibe según la dificultad.
@export var damage_taken_multipliers: Array[float] = [1.0, 1.35, 1.75]

var maximum := base_maximum
var current := base_maximum
var state := State.LUCID
var difficulty := Difficulty.NORMAL
## Vivo y en juego (no muerto ni perdido): si no, nada baja ni sube.
var active := true
## Cómo terminó el último sobreviviente: en el refugio muere (ataque cardíaco y
## el cuerpo queda en el piso); afuera se convierte en el Perdido.
var lost_in_refuge := false

var _refuges: Array[RefugeZone] = []
var _seen_horrors: Dictionary = {}


func _process(delta: float) -> void:
	if not active:
		return
	if in_refuge():
		_set_current(current + refuge_recovery_per_second * recovery_multiplier() * delta)
	else:
		var rate := drain_per_second * (chase_drain_multiplier if is_chased() else 1.0)
		_set_current(current - rate * delta)


## Si algún enemigo te está persiguiendo o atacando a menos de `chase_range`.
func is_chased() -> bool:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null:
		return false
	for enemy in get_tree().get_nodes_in_group(&"enemies"):
		var state: Variant = enemy.get("state")
		if (state == 1 or state == 2) and (enemy as Node3D).global_position.distance_to(player.global_position) <= chase_range:
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	# Atajos de debug para probar estados sin esperar.
	if not OS.is_debug_build() or not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_F9:
			take_hit(10.0)
		KEY_F10:
			_set_current(current - maximum * 0.25)
		KEY_F11:
			restore(maximum * 0.25)


func ratio() -> float:
	return current / maximum if maximum > 0.0 else 0.0


## La locura que se muestra: 0 = lúcido del todo, 1 = perdido.
func madness() -> float:
	return 1.0 - ratio()


## 0 mientras se está lúcido, 1 al llegar a 0. Maneja niebla, jitter y post-proceso.
func insanity() -> float:
	return clampf(1.0 - ratio() / uneasy_below, 0.0, 1.0)


func state_name(s: State = state) -> String:
	return STATE_NAMES[s]


func difficulty_name(d: int = difficulty) -> String:
	return DIFFICULTY_NAMES[d]


func player_damage_multiplier() -> float:
	if is_full_madness():
		return full_madness_damage_multiplier
	return player_damage_multipliers[difficulty]


func damage_taken_multiplier() -> float:
	if is_full_madness():
		return full_madness_damage_taken_multiplier
	return damage_taken_multipliers[difficulty]


## La locura llena (estado Perdido) sin morir: el juego en su punto más difícil.
func is_full_madness() -> bool:
	return state == State.LOST and not full_madness_kills


func in_refuge() -> bool:
	return not _refuges.is_empty()


func has_electricity() -> bool:
	return _refuges.any(func(r: RefugeZone) -> bool: return r.current_has_electricity())


## Qué tan rápido baja la locura en el refugio (el mejor de los que se esté pisando).
func recovery_multiplier() -> float:
	var multiplier := 0.0
	for refuge in _refuges:
		multiplier = maxf(multiplier, refuge.current_recovery_multiplier())
	return multiplier


## Baja la locura (comida, cómics, cartas, el bono de llegar a casa...).
func restore(amount: float) -> void:
	_set_current(current + amount)


## Sube la locura de golpe (gritos, eventos), con un susto en pantalla.
func add_madness(amount: float) -> void:
	if not active:
		return
	shocked.emit(clampf(amount / 15.0, 0.2, 1.0))
	_set_current(current - amount)


func fill() -> void:
	_set_current(maximum)


func increase_maximum(amount: float) -> void:
	maximum += amount
	changed.emit(current, maximum)


## Un golpe físico: baja la vida (con el multiplicador de dificultad) y sacude la pantalla.
func take_hit(amount: float) -> void:
	if not active:
		return
	var dealt := Health.take_damage(amount)
	if dealt <= 0.0:
		return
	hit_taken.emit(dealt)
	shocked.emit(clampf(dealt / 20.0, 0.2, 1.0))
	if Health.alive:
		_set_current(current - hit_madness)


func has_seen(horror_id: StringName) -> bool:
	return _seen_horrors.has(horror_id)


## Devuelve true si es la primera vez que se ve este horror.
func register_sighting(horror_id: StringName, amount: float) -> bool:
	if not active or has_seen(horror_id):
		return false
	_seen_horrors[horror_id] = true
	horror_seen.emit(horror_id)
	shocked.emit(clampf(amount / 15.0, 0.3, 1.0))
	_set_current(current - amount)
	return true


func enter_refuge(refuge: RefugeZone) -> void:
	if refuge in _refuges:
		return
	_refuges.append(refuge)
	if _refuges.size() == 1 and active:
		refuge_entered.emit()


func exit_refuge(refuge: RefugeZone) -> void:
	if refuge not in _refuges:
		return
	_refuges.erase(refuge)
	if _refuges.is_empty() and active:
		refuge_exited.emit()


## Murió por daño (Health): deja de correr el tiempo para este sobreviviente.
func end_life() -> void:
	active = false
	lost_in_refuge = in_refuge()


## Nuevo sobreviviente: la cordura máxima vuelve a la base; los horrores
## vistos se conservan porque el mundo sigue como quedó.
func reset() -> void:
	maximum = base_maximum
	current = maximum
	_refuges.clear()
	active = true
	_update_state()
	changed.emit(current, maximum)


## Partida nueva: además, se olvidan los horrores vistos.
func new_game() -> void:
	_seen_horrors.clear()
	reset()


func save_data() -> Dictionary:
	return {"current": current, "maximum": maximum, "seen": _seen_horrors.keys()}


func load_data(data: Dictionary) -> void:
	_refuges.clear()
	active = true
	maximum = data.get("maximum", base_maximum)
	current = clampf(data.get("current", maximum), 0.0, maximum)
	_seen_horrors.clear()
	for horror: StringName in data.get("seen", []):
		_seen_horrors[horror] = true
	_update_state()
	changed.emit(current, maximum)


func _set_current(value: float) -> void:
	if not active:
		return
	var previous := current
	current = clampf(value, 0.0, maximum)
	if current != previous:
		changed.emit(current, maximum)
		_update_state()


func _update_state() -> void:
	_update_difficulty()
	var r := ratio()
	var new_state := State.LUCID
	if current <= 0.0:
		new_state = State.LOST
	elif r < brink_below:
		new_state = State.BRINK
	elif r < broken_below:
		new_state = State.BROKEN
	elif r < uneasy_below:
		new_state = State.UNEASY
	if new_state == state:
		return
	var old_state := state
	state = new_state
	state_changed.emit(new_state, old_state)
	if new_state == State.LOST and full_madness_kills:
		active = false
		lost_in_refuge = in_refuge()
		lost.emit()
	elif new_state == State.LOST:
		GameState.post_message("La cabeza ya no da más. Todo late, todo habla. Pero sigo de pie.")


func _update_difficulty() -> void:
	var m := madness()
	var level := Difficulty.NORMAL
	if m >= insane_from:
		level = Difficulty.INSANE
	elif m >= hard_from:
		level = Difficulty.HARD
	if level == difficulty:
		return
	var previous := difficulty
	difficulty = level
	difficulty_changed.emit(level, previous)
