extends Node
## Autoload "Sanity": la cordura es el recurso central del juego (ver GDD).
## Baja con el tiempo (más lento en el refugio), con golpes y al ver horrores
## nuevos. Sube con objetos de esperanza. Al llegar a 0 el personaje se pierde.

signal changed(current: float, maximum: float)
signal state_changed(new_state: State, old_state: State)
## Golpe o susto: `strength` 0..1 para efectos de pantalla.
signal shocked(strength: float)
signal hit_taken(amount: float)
signal horror_seen(horror_id: StringName)
## Cordura en 0. Ver `lost_in_refuge` para saber cómo terminó.
signal lost

## Rangos en % de la cordura máxima (tabla "Estados de cordura" del GDD).
enum State { LUCID, UNEASY, BROKEN, BRINK, LOST }
const STATE_NAMES := {
	State.LUCID: "Lúcido",
	State.UNEASY: "Inquieto",
	State.BROKEN: "Quebrado",
	State.BRINK: "Al borde",
	State.LOST: "Perdido",
}

@export var base_maximum := 100.0
## Goteo constante fuera del refugio (100 -> 0 en ~11 minutos).
@export var drain_per_second := 0.15
@export var uneasy_below := 0.7
@export var broken_below := 0.4
@export var brink_below := 0.15

var maximum := base_maximum
var current := base_maximum
var state := State.LUCID
var active := true
## Cómo terminó el último sobreviviente: en el refugio muere (ataque cardíaco y
## el cuerpo queda en el piso); afuera se convierte en el Perdido.
var lost_in_refuge := false

var _refuges: Array[RefugeZone] = []
var _seen_horrors: Dictionary = {}


func _process(delta: float) -> void:
	if active:
		_set_current(current - drain_per_second * drain_multiplier() * delta)


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


## 0 mientras se está lúcido, 1 al llegar a 0. Maneja niebla, jitter y post-proceso.
func insanity() -> float:
	return clampf(1.0 - ratio() / uneasy_below, 0.0, 1.0)


func state_name(s: State = state) -> String:
	return STATE_NAMES[s]


func in_refuge() -> bool:
	return not _refuges.is_empty()


func has_electricity() -> bool:
	return _refuges.any(func(r: RefugeZone) -> bool: return r.has_electricity)


func drain_multiplier() -> float:
	var multiplier := 1.0
	for refuge in _refuges:
		multiplier = minf(multiplier, refuge.drain_multiplier)
	return multiplier


func restore(amount: float) -> void:
	_set_current(current + amount)


func fill() -> void:
	_set_current(maximum)


func increase_maximum(amount: float) -> void:
	maximum += amount
	changed.emit(current, maximum)


func take_hit(amount: float) -> void:
	if not active:
		return
	hit_taken.emit(amount)
	shocked.emit(clampf(amount / 20.0, 0.2, 1.0))
	_set_current(current - amount)


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
	if refuge not in _refuges:
		_refuges.append(refuge)


func exit_refuge(refuge: RefugeZone) -> void:
	_refuges.erase(refuge)


## Nuevo sobreviviente: la cordura máxima vuelve a la base; los horrores
## vistos se conservan porque el mundo sigue como quedó.
func reset() -> void:
	maximum = base_maximum
	current = maximum
	_refuges.clear()
	active = true
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
	if new_state == State.LOST:
		active = false
		lost_in_refuge = in_refuge()
		lost.emit()
