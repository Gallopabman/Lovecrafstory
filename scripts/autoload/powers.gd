extends Node
## Poderes (pedido del usuario). El protagonista no recuerda los últimos meses: estuvo en un
## laboratorio del gobierno ("el Instituto") donde lo usaban para asomarse a la otra realidad.
## Los locos no están locos: ven el otro lado y la mente no les aguanta. Él sí aguanta, y puede
## usarlo. Cada página de su diario (ItemData kind DIARY, `power`) que lee le devuelve un poder.
## Usarlos sube la locura. Se conservan entre sobrevivientes (las páginas no se vuelven a encontrar).
## Los efectos los hace PlayerCombat; acá están el estado, los costos y los tiempos.

signal learned(power: StringName)
signal used(power: StringName)
signal empower_changed(active: bool)

const EMPOWER := &"empower"
const PUSH := &"push"
## Nombre para la UI y acción de entrada de cada poder.
const INFO := {
	EMPOWER: {"name": "Filo del otro lado", "short": "FILO", "action": "power_1", "key": "1", "pad": "cruceta izquierda"},
	PUSH: {"name": "Empujón", "short": "EMPUJE", "action": "power_2", "key": "2", "pad": "cruceta derecha"},
}

@export_group("Filo del otro lado")
## Cuánto dura el refuerzo del arma (segundos) y cuánto más pega.
@export var empower_duration := 40.0
@export var empower_damage_multiplier := 1.35
@export var empower_madness := 10.0

@export_group("Empujón")
@export var push_madness := 6.0
@export var push_range := 4.5
@export_range(0.0, 180.0) var push_half_angle := 70.0
@export var push_damage := 6.0
## Velocidad con la que salen despedidos (frenan enseguida: 1.5-2.5 m).
@export var push_speed := 24.0
@export var push_cooldown := 2.5

var known: Array[StringName] = []
var empower_left := 0.0
var _cooldowns := {}


func _physics_process(delta: float) -> void:
	for p: StringName in _cooldowns:
		_cooldowns[p] = maxf(_cooldowns[p] - delta, 0.0)
	if empower_left > 0.0:
		empower_left = maxf(empower_left - delta, 0.0)
		if empower_left == 0.0:
			empower_changed.emit(false)


func knows(power: StringName) -> bool:
	return known.has(power)


## Devuelve true si es nuevo.
func learn(power: StringName) -> bool:
	if power == &"" or known.has(power):
		return false
	known.append(power)
	learned.emit(power)
	return true


func display_name(power: StringName) -> String:
	return INFO.get(power, {}).get("name", String(power))


func is_empowered() -> bool:
	return empower_left > 0.0


## Multiplicador del daño del jugador (lo usa PlayerCombat).
func damage_multiplier() -> float:
	return empower_damage_multiplier if is_empowered() else 1.0


func cooldown_left(power: StringName) -> float:
	return _cooldowns.get(power, 0.0)


## Intenta usar un poder: si se puede, cobra la locura y devuelve true (el efecto lo hace quien llama).
func activate(power: StringName) -> bool:
	if not knows(power) or not Sanity.active or cooldown_left(power) > 0.0:
		return false
	match power:
		EMPOWER:
			var was := is_empowered()
			empower_left = empower_duration
			_cooldowns[power] = 1.0
			Sanity.add_madness(empower_madness)
			if not was:
				empower_changed.emit(true)
		PUSH:
			_cooldowns[power] = push_cooldown
			Sanity.add_madness(push_madness)
	used.emit(power)
	return true


## Al morir: el refuerzo se corta (los poderes aprendidos quedan).
func end_life() -> void:
	if is_empowered():
		empower_left = 0.0
		empower_changed.emit(false)
	_cooldowns.clear()


func new_game() -> void:
	known.clear()
	end_life()


func save_data() -> Dictionary:
	return {"known": known.map(func(p: StringName) -> String: return String(p)), "empower_left": empower_left}


func load_data(data: Dictionary) -> void:
	known.clear()
	for p: String in data.get("known", []):
		known.append(StringName(p))
	empower_left = data.get("empower_left", 0.0)
	_cooldowns.clear()
	empower_changed.emit(is_empowered())
