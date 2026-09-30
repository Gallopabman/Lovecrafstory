extends Control
## Menú de inicio: Jugar, Opciones (volumen general) y Salir.
## Se maneja con teclado, gamepad o mouse. La música es la del menú.

@export_file("*.tscn") var first_scene := "res://scenes/levels/hospital.tscn"
@export var fade_time := 1.2
## El título titila de vez en cuando, como un tubo fluorescente.
@export var flicker_chance := 0.35

var _starting := false

@onready var main_panel: Control = %MainPanel
@onready var options_panel: Control = %OptionsPanel
@onready var play_button: Button = %PlayButton
@onready var options_button: Button = %OptionsButton
@onready var quit_button: Button = %QuitButton
@onready var volume_slider: HSlider = %VolumeSlider
@onready var volume_value: Label = %VolumeValue
@onready var back_button: Button = %BackButton
@onready var title: Label = %Title
@onready var fade: ColorRect = %Fade


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Audio.set_ambience(&"")
	Audio.play_music(&"menu_music", -4.0)
	play_button.pressed.connect(_on_play)
	options_button.pressed.connect(_show_options.bind(true))
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	back_button.pressed.connect(_show_options.bind(false))
	volume_slider.value = Audio.master_volume * 100.0
	volume_slider.value_changed.connect(_on_volume_changed)
	_update_volume_label()
	for button: Control in [play_button, options_button, quit_button, back_button, volume_slider]:
		button.focus_entered.connect(Audio.play_ui.bind(&"menu_move"))
		button.mouse_entered.connect(button.grab_focus)
	quit_button.visible = OS.get_name() != "Web"
	_show_options(false, false)
	fade.modulate.a = 1.0
	create_tween().tween_property(fade, "modulate:a", 0.0, fade_time)


func _process(delta: float) -> void:
	title.modulate.a = 0.35 if randf() < flicker_chance * delta else 1.0


func _unhandled_input(event: InputEvent) -> void:
	if options_panel.visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		_show_options(false)
		get_viewport().set_input_as_handled()


func _show_options(show_options: bool, with_sound := true) -> void:
	main_panel.visible = not show_options
	options_panel.visible = show_options
	if with_sound:
		Audio.play_ui(&"menu_confirm" if show_options else &"menu_back")
	if show_options:
		volume_slider.grab_focus.call_deferred()
	else:
		Audio.save_settings()
		(options_button if with_sound else play_button).grab_focus.call_deferred()


func _on_volume_changed(value: float) -> void:
	Audio.set_master_volume(value / 100.0)
	_update_volume_label()
	Audio.play_ui(&"menu_move")


func _update_volume_label() -> void:
	volume_value.text = "%d%%" % roundi(volume_slider.value)


func _on_play() -> void:
	if _starting:
		return
	_starting = true
	Audio.play_ui(&"menu_confirm")
	Audio.play_music(&"")
	GameState.new_game()
	Inventory.clear()
	Sanity.reset()
	var tween := create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, fade_time)
	tween.tween_callback(func() -> void: get_tree().change_scene_to_file(first_scene))
