extends CanvasLayer
## UI del juego: menú, avisos breves, secuencia de muerte y overlay de debug
## (F3, solo en builds de debug).

const LOST_TEXT := "Te perdiste.\n\nAlguien más llegará al refugio."
const HEART_TEXT := "Su corazón no aguantó.\n\nAlguien más llegará al refugio."

@export var message_duration := 2.5
@export var reading_chars_per_second := 14.0
@export var lost_fade_delay := 1.5
@export var lost_fade_time := 2.5
@export var lost_hold_time := 3.0

@onready var pickup_label: Label = %PickupLabel
@onready var lost_screen: ColorRect = %LostScreen
@onready var lost_label: Label = %LostLabel
@onready var debug_label: Label = %DebugLabel
@onready var game_menu: GameMenu = $GameMenu
@onready var shelter_menu: ShelterMenu = $ShelterMenu

var _message_timer := 0.0


func _ready() -> void:
	pickup_label.text = ""
	lost_screen.hide()
	debug_label.hide()
	Inventory.item_added.connect(func(item: ItemData) -> void: _show_message("Recogí: %s" % item.display_name))
	GameState.message_posted.connect(_show_message)
	Sanity.lost.connect(_on_lost)


func _process(delta: float) -> void:
	pickup_label.visible = not game_menu.visible and not shelter_menu.visible
	if _message_timer > 0.0:
		_message_timer -= delta
		pickup_label.modulate.a = clampf(_message_timer / 0.5, 0.0, 1.0)
	if debug_label.visible:
		debug_label.text = "Cordura %.1f / %.0f  (%s)\nGoteo x%.2f%s  Sobreviviente #%d" % [
			Sanity.current, Sanity.maximum, Sanity.state_name(),
			Sanity.drain_multiplier(), "  refugio" if Sanity.in_refuge() else "",
			GameState.survivor_number]


func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_F3:
		debug_label.visible = not debug_label.visible


func _show_message(text: String) -> void:
	pickup_label.text = text
	pickup_label.modulate.a = 1.0
	# Los textos largos (objetos examinados) quedan más tiempo en pantalla.
	_message_timer = maxf(message_duration, text.length() / reading_chars_per_second)


## Cordura 0. En el refugio el sobreviviente muere y su cuerpo queda con sus
## cosas; afuera se pierde (a futuro, el Perdido). En ambos casos alguien nuevo
## llega al refugio. El mundo persiste en GameState; la escena se recarga.
func _on_lost() -> void:
	game_menu.close()
	lost_label.text = HEART_TEXT if Sanity.lost_in_refuge else LOST_TEXT
	lost_screen.modulate.a = 0.0
	lost_screen.show()
	var tween := create_tween()
	tween.tween_interval(lost_fade_delay)
	tween.tween_property(lost_screen, "modulate:a", 1.0, lost_fade_time)
	tween.tween_interval(lost_hold_time)
	tween.tween_callback(_restart)


func _restart() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player:
		var items := Inventory.all_items()
		if Sanity.lost_in_refuge:
			GameState.add_corpse(player.global_position, player.visual.global_rotation.y, items)
		else:
			GameState.add_lost_one(player.global_position, items)
	GameState.survivor_number += 1
	Inventory.clear()
	Sanity.reset()
	get_tree().reload_current_scene()
