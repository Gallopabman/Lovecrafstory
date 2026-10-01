extends Control
## Menú de inicio: Continuar (si hay partida guardada), Jugar (partida nueva),
## Opciones (volumen general) y Salir. Teclado, gamepad o mouse.

@export_file("*.tscn") var first_scene := "res://scenes/levels/home.tscn"
@export var fade_time := 1.2
## El título titila de vez en cuando, como un tubo fluorescente.
@export var flicker_chance := 0.35

var _starting := false

@onready var main_panel: Control = %MainPanel
@onready var options_panel: OptionsPanel = %OptionsPanel
@onready var continue_button: Button = %ContinueButton
@onready var play_button: Button = %PlayButton
@onready var options_button: Button = %OptionsButton
@onready var quit_button: Button = %QuitButton
@onready var save_label: Label = %SaveLabel
@onready var title: Label = %Title
@onready var fade: ColorRect = %Fade


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Audio.set_ambience(&"")
	Audio.play_music(&"menu_music", -4.0)
	continue_button.pressed.connect(_on_continue)
	play_button.pressed.connect(_on_play)
	options_button.pressed.connect(_show_options)
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	options_panel.closed.connect(_on_options_closed)
	for button: Button in [continue_button, play_button, options_button, quit_button]:
		button.focus_entered.connect(Audio.play_ui.bind(&"menu_move"))
		button.mouse_entered.connect(button.grab_focus)
	quit_button.visible = OS.get_name() != "Web"
	var has_save := SaveGame.has_save() and not SaveGame.read().is_empty()
	continue_button.visible = has_save
	save_label.text = SaveGame.summary() if has_save else ""
	(continue_button if has_save else play_button).grab_focus.call_deferred()
	fade.modulate.a = 1.0
	create_tween().tween_property(fade, "modulate:a", 0.0, fade_time)


func _process(delta: float) -> void:
	title.modulate.a = 0.35 if randf() < flicker_chance * delta else 1.0


func _show_options() -> void:
	main_panel.hide()
	save_label.hide()
	options_panel.open()


func _on_options_closed() -> void:
	main_panel.show()
	save_label.show()
	options_button.grab_focus.call_deferred()


func _on_continue() -> void:
	_start(func() -> void: SaveGame.load_game())


func _on_play() -> void:
	_start(func() -> void:
		SaveGame.new_game()
		get_tree().change_scene_to_file(first_scene))


func _start(action: Callable) -> void:
	if _starting:
		return
	_starting = true
	Audio.play_ui(&"menu_confirm")
	Audio.play_music(&"")
	var tween := create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, fade_time)
	tween.tween_callback(action)
