extends CanvasLayer
## UI del juego: menú, avisos al recoger objetos, secuencia de "te perdiste"
## y overlay de debug (F3, solo en builds de debug).

@export var message_duration := 2.5
@export var lost_fade_delay := 1.5
@export var lost_fade_time := 2.5
@export var lost_hold_time := 3.0

@onready var pickup_label: Label = %PickupLabel
@onready var lost_screen: ColorRect = %LostScreen
@onready var debug_label: Label = %DebugLabel
@onready var game_menu: GameMenu = $GameMenu

var _message_timer := 0.0


func _ready() -> void:
	pickup_label.text = ""
	lost_screen.hide()
	debug_label.hide()
	Inventory.item_added.connect(_on_item_added)
	Sanity.lost.connect(_on_lost)


func _process(delta: float) -> void:
	pickup_label.visible = not game_menu.visible
	if _message_timer > 0.0:
		_message_timer -= delta
		pickup_label.modulate.a = clampf(_message_timer / 0.5, 0.0, 1.0)
	if debug_label.visible:
		debug_label.text = "Cordura %.1f / %.0f  (%s)\nGoteo x%.2f%s" % [
			Sanity.current, Sanity.maximum, Sanity.state_name(),
			Sanity.drain_multiplier(), "  refugio" if Sanity.in_refuge() else ""]


func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_F3:
		debug_label.visible = not debug_label.visible


func _on_item_added(item: ItemData, count: int) -> void:
	pickup_label.text = "Recogiste: %s%s" % [item.display_name, "  x%d" % count if count > 1 else ""]
	pickup_label.modulate.a = 1.0
	_message_timer = message_duration


## Al llegar a 0 el personaje se pierde y un nuevo sobreviviente empieza en el
## refugio. Todavía no hay Perdido ni mundo persistente: se recarga la escena.
func _on_lost() -> void:
	lost_screen.modulate.a = 0.0
	lost_screen.show()
	var tween := create_tween()
	tween.tween_interval(lost_fade_delay)
	tween.tween_property(lost_screen, "modulate:a", 1.0, lost_fade_time)
	tween.tween_interval(lost_hold_time)
	tween.tween_callback(_restart)


func _restart() -> void:
	Inventory.clear()
	Sanity.reset()
	get_tree().reload_current_scene()
