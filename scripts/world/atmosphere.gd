@tool
class_name Atmosphere
extends WorldEnvironment
## Controla la niebla PS1, el vertex jitter y los efectos de locura a través de
## los parámetros globales de shader (ver [shader_globals] en project.godot).
## En juego interpola entre los valores "Lúcido" y "Al borde" según la cordura:
## menos cordura = más niebla, más oscuridad y más temblor (GDD).

@export_group("Lúcido")
@export var fog_color := Color(0.5, 0.5, 0.52):
	set(value):
		fog_color = value
		_apply_preview()
## Distancia a la que empieza la niebla.
@export var fog_start := 2.0:
	set(value):
		fog_start = value
		_apply_preview()
## Distancia a la que la niebla es total.
@export var fog_end := 16.0:
	set(value):
		fog_end = value
		_apply_preview()
## Grilla a la que se ajustan los vértices. Más baja = más temblor.
@export var snap_resolution := Vector2(320, 240):
	set(value):
		snap_resolution = value
		_apply_preview()

@export_group("Al borde")
@export var insane_fog_color := Color(0.22, 0.21, 0.21):
	set(value):
		insane_fog_color = value
		_apply_preview()
@export var insane_fog_start := 0.5:
	set(value):
		insane_fog_start = value
		_apply_preview()
@export var insane_fog_end := 6.0:
	set(value):
		insane_fog_end = value
		_apply_preview()
@export var insane_snap_resolution := Vector2(110, 82):
	set(value):
		insane_snap_resolution = value
		_apply_preview()
## Factor de la luz ambiente al borde de la locura (solo en juego).
@export_range(0.0, 1.0) var insane_ambient_factor := 0.45

@export_group("Transiciones")
## Qué tan rápido el ambiente sigue a la cordura (evita saltos bruscos tras un golpe).
@export var insanity_follow_speed := 1.5
## Qué tan rápido se disipa el efecto de un golpe o susto.
@export var shock_decay := 1.2
## Solo editor: previsualiza el ambiente con esta locura (0 = lúcido, 1 = al borde).
@export_range(0.0, 1.0) var editor_preview_insanity := 0.0:
	set(value):
		editor_preview_insanity = value
		_apply_preview()

var _insanity := 0.0
var _shock := 0.0
var _base_ambient_energy := -1.0


func _ready() -> void:
	if Engine.is_editor_hint():
		_apply_preview()
		return
	_insanity = Sanity.insanity()
	Sanity.shocked.connect(func(strength: float) -> void: _shock = clampf(_shock + strength, 0.0, 1.0))
	_apply(_insanity, 0.0)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_insanity = lerpf(_insanity, Sanity.insanity(), 1.0 - exp(-insanity_follow_speed * delta))
	_shock = move_toward(_shock, 0.0, shock_decay * delta)
	_apply(_insanity, _shock)


func _apply_preview() -> void:
	if Engine.is_editor_hint():
		_apply(editor_preview_insanity, 0.0)


func _apply(insanity: float, shock: float) -> void:
	var color := fog_color.lerp(insane_fog_color, insanity)
	RenderingServer.global_shader_parameter_set(&"ps1_fog_color", color)
	RenderingServer.global_shader_parameter_set(&"ps1_fog_start", lerpf(fog_start, insane_fog_start, insanity))
	RenderingServer.global_shader_parameter_set(&"ps1_fog_end", lerpf(fog_end, insane_fog_end, insanity))
	RenderingServer.global_shader_parameter_set(&"ps1_snap_resolution", snap_resolution.lerp(insane_snap_resolution, insanity))
	RenderingServer.global_shader_parameter_set(&"ps1_insanity", insanity)
	RenderingServer.global_shader_parameter_set(&"ps1_shock", shock)
	# El fondo se funde con la niebla, como en Silent Hill.
	if environment:
		environment.background_color = color
		if not Engine.is_editor_hint():
			if _base_ambient_energy < 0.0:
				_base_ambient_energy = environment.ambient_light_energy
			environment.ambient_light_energy = _base_ambient_energy * lerpf(1.0, insane_ambient_factor, insanity)
