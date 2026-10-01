extends Node
## Autoload "Health": la vida del sobreviviente (pedido del usuario: "algo te daña,
## baja; si llega a 0, morís"). El daño se multiplica por la dificultad (Sanity).
## Se cura con comida, vendas y botiquines, y descansando en la cama del refugio.
## Al morir por daño el cuerpo queda donde cayó, con todo lo que llevaba encima.

signal changed(current: float, maximum: float)
signal died

@export var maximum := 100.0

var current := 100.0
var alive := true


func ratio() -> float:
	return current / maximum if maximum > 0.0 else 0.0


## Aplica daño (con el multiplicador de dificultad). Devuelve el daño real.
func take_damage(amount: float) -> float:
	if not alive or not Sanity.active or amount <= 0.0:
		return 0.0
	var dealt := amount * Sanity.damage_taken_multiplier()
	current = maxf(current - dealt, 0.0)
	changed.emit(current, maximum)
	if current <= 0.0:
		alive = false
		Sanity.end_life()
		died.emit()
	return dealt


func heal(amount: float) -> void:
	if not alive or amount <= 0.0:
		return
	current = minf(current + amount, maximum)
	changed.emit(current, maximum)


## Nuevo sobreviviente (o partida nueva): vida llena.
func reset() -> void:
	current = maximum
	alive = true
	changed.emit(current, maximum)


func save_data() -> Dictionary:
	return {"current": current}


func load_data(data: Dictionary) -> void:
	alive = true
	current = clampf(data.get("current", maximum), 1.0, maximum)
	changed.emit(current, maximum)
