class_name PauseMenu
extends Control
## Menú de pausa (Esc / Start): continuar, guardar, opciones, volver al menú de
## inicio o salir del juego. Pausa el árbol; no se abre con otro menú abierto.

@export_file("*.tscn") var main_menu_scene := "res://scenes/ui/main_menu.tscn"

@onready var buttons: Control = %PauseButtons
@onready var continue_button: Button = %ResumeButton
@onready var save_button: Button = %SaveButton
@onready var options_button: Button = %PauseOptionsButton
@onready var menu_button: Button = %MainMenuButton
@onready var quit_button: Button = %QuitGameButton
@onready var result_label: Label = %PauseResult
@onready var options_panel: OptionsPanel = %PauseOptions


func _ready() -> void:
	hide()
	continue_button.pressed.connect(close)
	save_button.pressed.connect(_on_save)
	options_button.pressed.connect(_on_options)
	menu_button.pressed.connect(_on_main_menu)
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	options_panel.closed.connect(_on_options_closed)
	for button: Button in [continue_button, save_button, options_button, menu_button, quit_button]:
		button.focus_entered.connect(Audio.play_ui.bind(&"menu_move"))
		button.mouse_entered.connect(button.grab_focus)
	quit_button.visible = OS.get_name() != "Web"


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if visible:
		# Con las opciones abiertas, Esc lo maneja el panel de opciones.
		if not options_panel.visible:
			get_viewport().set_input_as_handled()
			close()
	elif not get_tree().paused and SaveGame.can_save():
		get_viewport().set_input_as_handled()
		open()


func open() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	result_label.text = ""
	save_button.disabled = not SaveGame.can_save()
	buttons.show()
	show()
	Audio.play_ui(&"inventory_open")
	continue_button.grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	options_panel.hide()
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Audio.play_ui(&"inventory_close")


func _on_save() -> void:
	if SaveGame.save_game():
		result_label.text = "Partida guardada."
		Audio.play_ui(&"menu_confirm")
	else:
		result_label.text = "No se pudo guardar."
		Audio.play_ui(&"menu_back")


func _on_options() -> void:
	buttons.hide()
	result_label.text = ""
	options_panel.open()


func _on_options_closed() -> void:
	buttons.show()
	options_button.grab_focus.call_deferred()


func _on_main_menu() -> void:
	Audio.play_ui(&"menu_confirm")
	hide()
	GameState.change_scene(main_menu_scene)
