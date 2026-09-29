class_name GameMenu
extends Control
## Menú de estado e inventario. El juego no tiene HUD: la cordura solo se ve
## acá. Abrirlo pausa el juego.

@export var bar_pixels_per_point := 1.6
@export var bar_max_width := 296.0

@onready var sanity_bar: ProgressBar = %SanityBar
@onready var state_label: Label = %StateLabel
@onready var item_list: ItemList = %ItemList
@onready var name_label: Label = %NameLabel
@onready var description_label: Label = %DescriptionLabel
@onready var result_label: Label = %ResultLabel
@onready var empty_label: Label = %EmptyLabel
@onready var letter_panel: Panel = %LetterPanel
@onready var letter_label: Label = %LetterLabel

var _entries: Array[Dictionary] = []


func _ready() -> void:
	hide()
	letter_panel.hide()
	item_list.item_selected.connect(func(_index: int) -> void: _show_selected())
	item_list.item_activated.connect(func(_index: int) -> void: _use_selected())
	Inventory.changed.connect(_refresh_items)
	Inventory.letter_opened.connect(_open_letter)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"):
		if visible:
			close()
		elif Sanity.active:
			open()
		get_viewport().set_input_as_handled()
	elif not visible:
		return
	elif letter_panel.visible:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			letter_panel.hide()
			item_list.grab_focus()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		_use_selected()
		get_viewport().set_input_as_handled()


func open() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	result_label.text = ""
	letter_panel.hide()
	_refresh_sanity()
	_refresh_items()
	show()
	item_list.grab_focus()


func close() -> void:
	letter_panel.hide()
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _refresh_sanity() -> void:
	sanity_bar.max_value = Sanity.maximum
	sanity_bar.value = Sanity.current
	# La barra crece con las cartas: su ancho es proporcional a la cordura máxima.
	sanity_bar.size.x = minf(bar_pixels_per_point * Sanity.maximum, bar_max_width)
	state_label.text = Sanity.state_name()


func _refresh_items() -> void:
	var previous := item_list.get_selected_items()
	item_list.clear()
	_entries = Inventory.entries.duplicate()
	for entry in _entries:
		var item: ItemData = entry.item
		var text := item.display_name
		if entry.count > 1:
			text += "  x%d" % entry.count
		item_list.add_item(text)
	empty_label.visible = _entries.is_empty()
	if not _entries.is_empty():
		var index := clampi(previous[0] if not previous.is_empty() else 0, 0, _entries.size() - 1)
		item_list.select(index)
	_show_selected()
	if visible:
		_refresh_sanity()


func _selected_item() -> ItemData:
	var selected := item_list.get_selected_items()
	if selected.is_empty() or selected[0] >= _entries.size():
		return null
	return _entries[selected[0]].item


func _show_selected() -> void:
	var item := _selected_item()
	name_label.text = item.display_name if item else ""
	description_label.text = item.description if item else ""


func _use_selected() -> void:
	var item := _selected_item()
	if item:
		result_label.text = Inventory.use(item)
		_refresh_sanity()


func _open_letter(item: ItemData) -> void:
	letter_label.text = item.letter_text
	letter_panel.show()
