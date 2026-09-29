class_name FlickerLight
extends OmniLight3D
## Luz de tubo vieja: parpadea al azar (cortes breves y bajones de intensidad).

## Probabilidad por segundo de que empiece un parpadeo.
@export var flicker_chance := 0.35
@export var min_energy_factor := 0.1

var _base_energy := 1.0
var _flicker_time := 0.0


func _ready() -> void:
	_base_energy = light_energy


func _process(delta: float) -> void:
	if _flicker_time > 0.0:
		_flicker_time -= delta
		light_energy = _base_energy * (randf_range(min_energy_factor, 1.0) if randf() < 0.6 else 0.0)
		if _flicker_time <= 0.0:
			light_energy = _base_energy
	elif randf() < flicker_chance * delta:
		_flicker_time = randf_range(0.08, 0.6)
