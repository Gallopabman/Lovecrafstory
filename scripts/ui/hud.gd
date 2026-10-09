class_name Hud
extends Control
## HUD siempre visible (pedido del usuario): la barra de vida y la de locura, arriba a
## la izquierda, y la dificultad cuando no es Normal. Estilo de la UI del juego
## (pixel, marco oscuro). La barra de locura crece con la cordura máxima (cartas).

@export var bar_width := 70.0
## Ancho extra de la barra de locura por cada punto de cordura máxima sobre la base.
@export var pixels_per_extra_point := 0.4
@export var bar_max_width := 110.0
@export var health_color := Color(0.7, 0.12, 0.1)
@export var madness_color := Color(0.5, 0.25, 0.65)
@export var low_health_ratio := 0.3
@export var power_color := Color(0.7, 0.5, 1.0)

@onready var health_bar: ProgressBar = %HealthBar
@onready var madness_bar: ProgressBar = %MadnessBar
@onready var difficulty_label: Label = %DifficultyLabel

## Los poderes aprendidos, arriba a la derecha (y cuánto le queda al Filo).
var powers_label: Label


func _ready() -> void:
	_style(health_bar, health_color)
	_style(madness_bar, madness_color)
	powers_label = Label.new()
	powers_label.name = "PowersLabel"
	powers_label.position = Vector2(200, 4)
	powers_label.size = Vector2(114, 30)
	powers_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	powers_label.add_theme_color_override(&"font_color", power_color)
	powers_label.add_theme_color_override(&"font_shadow_color", Color.BLACK)
	powers_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(powers_label)
	Health.changed.connect(func(_c: float, _m: float) -> void: _refresh())
	Sanity.changed.connect(func(_c: float, _m: float) -> void: _refresh())
	Sanity.difficulty_changed.connect(func(_l: int, _p: int) -> void: _refresh())
	Sanity.state_changed.connect(func(_n: int, _o: int) -> void: _refresh())
	_refresh()


func _process(_delta: float) -> void:
	# Con poca vida la barra late; en Insane, el cartel también.
	var t := Time.get_ticks_msec() / 1000.0
	var low := Health.ratio() < low_health_ratio and Health.alive
	health_bar.modulate.a = 0.55 + 0.45 * absf(sin(t * 4.0)) if low else 1.0
	if Sanity.is_full_madness():
		difficulty_label.modulate.a = 0.4 + 0.6 * absf(sin(t * 6.0))
	elif Sanity.difficulty == Sanity.Difficulty.INSANE:
		difficulty_label.modulate.a = 0.6 + 0.4 * absf(sin(t * 3.0))
	_update_powers(t)


func _refresh() -> void:
	if not is_node_ready():
		return
	health_bar.max_value = Health.maximum
	health_bar.value = Health.current
	madness_bar.max_value = Sanity.maximum
	madness_bar.value = Sanity.maximum - Sanity.current
	var extra := maxf(Sanity.maximum - Sanity.base_maximum, 0.0)
	madness_bar.size.x = minf(bar_width + extra * pixels_per_extra_point, bar_max_width)
	match Sanity.difficulty:
		Sanity.Difficulty.NORMAL:
			difficulty_label.text = ""
		Sanity.Difficulty.HARD:
			difficulty_label.text = "DIFÍCIL"
			difficulty_label.add_theme_color_override(&"font_color", Color(0.95, 0.6, 0.3))
			difficulty_label.modulate.a = 1.0
		Sanity.Difficulty.INSANE:
			difficulty_label.text = "INSANE"
			difficulty_label.add_theme_color_override(&"font_color", Color(0.95, 0.2, 0.15))
	# Locura llena (no mata, pedido del usuario): el escalón más difícil.
	if Sanity.is_full_madness():
		difficulty_label.text = "AL LÍMITE"
		difficulty_label.add_theme_color_override(&"font_color", Color(0.7, 0.02, 0.02))


static func _style(bar: ProgressBar, color: Color) -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.03, 0.025, 0.025, 0.85)
	back.border_color = Color(0.32, 0.27, 0.22)
	back.set_border_width_all(1)
	bar.add_theme_stylebox_override(&"fill", fill)
	bar.add_theme_stylebox_override(&"background", back)
	bar.show_percentage = false


func _update_powers(t: float) -> void:
	var lines: PackedStringArray = []
	for power: StringName in Powers.known:
		var info: Dictionary = Powers.INFO.get(power, {})
		var line := "%s %s" % [info.get("key", ""), info.get("short", "")]
		if power == Powers.EMPOWER and Powers.is_empowered():
			line += " %ds" % ceili(Powers.empower_left)
		elif Powers.cooldown_left(power) > 0.0:
			line += " ..."
		lines.append(line)
	powers_label.text = "\n".join(lines)
	# Brilla mientras el Filo está activo.
	powers_label.modulate.a = 0.75 + 0.25 * absf(sin(t * 4.0)) if Powers.is_empowered() else 0.8
