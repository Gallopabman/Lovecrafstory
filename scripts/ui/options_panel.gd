class_name OptionsPanel
extends Panel
## Opciones del juego (por ahora solo el volumen general). Se usa en el menú de
## inicio y en el de pausa. Guarda al cerrar.

signal closed

@onready var volume_slider: HSlider = %VolumeSlider
@onready var volume_value: Label = %VolumeValue
@onready var back_button: Button = %BackButton


func _ready() -> void:
	hide()
	volume_slider.value_changed.connect(_on_volume_changed)
	back_button.pressed.connect(close)
	for control: Control in [volume_slider, back_button]:
		control.focus_entered.connect(Audio.play_ui.bind(&"menu_move"))
		control.mouse_entered.connect(control.grab_focus)


func _input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		close()


func open() -> void:
	volume_slider.set_value_no_signal(Audio.master_volume * 100.0)
	_update_label()
	show()
	Audio.play_ui(&"menu_confirm")
	volume_slider.grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	hide()
	Audio.save_settings()
	Audio.play_ui(&"menu_back")
	closed.emit()


func _on_volume_changed(value: float) -> void:
	Audio.set_master_volume(value / 100.0)
	_update_label()
	Audio.play_ui(&"menu_move")


func _update_label() -> void:
	volume_value.text = "%d%%" % roundi(volume_slider.value)
