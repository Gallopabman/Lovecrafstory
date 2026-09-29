class_name GameMenu
extends Control
## Menú de estado e inventario. El juego no tiene HUD: la cordura solo se ve
## acá. Abrirlo pausa el juego. Mochila en cuadrícula estilo Resident Evil
## (usar, mover, girar, tirar) y lista de cartas aparte.

enum Section { GRID, LETTERS }

const HINT_GRID := "E: usar   R: mover   X: tirar   Tab: cerrar"
const HINT_HOLD := "Q: girar   R: soltar   Esc: cancelar"
const HINT_LETTERS := "E: leer   Tab: cerrar"
const DIRECTIONS := {
	"ui_left": Vector2i.LEFT, "move_left": Vector2i.LEFT,
	"ui_right": Vector2i.RIGHT, "move_right": Vector2i.RIGHT,
	"ui_up": Vector2i.UP, "move_forward": Vector2i.UP,
	"ui_down": Vector2i.DOWN, "move_back": Vector2i.DOWN,
}

@export var bar_pixels_per_point := 1.6
@export var bar_max_width := 296.0

var _section := Section.GRID

@onready var sanity_bar: ProgressBar = %SanityBar
@onready var state_label: Label = %StateLabel
@onready var grid: InventoryGrid = %InventoryGrid
@onready var letter_list: ItemList = %LetterList
@onready var name_label: Label = %NameLabel
@onready var description_label: Label = %DescriptionLabel
@onready var result_label: Label = %ResultLabel
@onready var hint_label: Label = %HintLabel
@onready var letter_panel: Panel = %LetterPanel
@onready var letter_label: Label = %LetterLabel


func _ready() -> void:
	hide()
	letter_panel.hide()
	Inventory.changed.connect(_refresh)
	Inventory.letter_opened.connect(_open_letter)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"):
		if visible:
			close()
		elif Sanity.active and not get_tree().paused:
			open()
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return
	# Mientras el menú está abierto, toda la entrada es del menú.
	get_viewport().set_input_as_handled()
	if letter_panel.visible:
		if _pressed(event, ["ui_cancel", "pause", "interact", "ui_accept"]):
			letter_panel.hide()
		return
	var direction := _direction(event)
	if _section == Section.GRID:
		_grid_input(event, direction)
	else:
		_letters_input(event, direction)


func open() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	result_label.text = ""
	letter_panel.hide()
	_section = Section.GRID
	show()
	_refresh()


func close() -> void:
	grid.cancel_move()
	letter_panel.hide()
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _grid_input(event: InputEvent, direction: Vector2i) -> void:
	if direction != Vector2i.ZERO:
		if not grid.move_cursor(direction) and not Inventory.letters.is_empty():
			_set_section(Section.LETTERS)
		_show_details()
	elif grid.is_holding():
		if event.is_action_pressed("inventory_move") or _is_use(event):
			if not grid.try_place():
				result_label.text = "No entra ahí."
		elif event.is_action_pressed("inventory_rotate"):
			grid.rotate_held()
		elif _pressed(event, ["ui_cancel", "pause"]):
			grid.cancel_move()
		_show_details()
	elif _is_use(event):
		var entry := grid.hovered_entry()
		if not entry.is_empty():
			result_label.text = Inventory.use(entry.item, entry)
	elif event.is_action_pressed("inventory_move"):
		var entry := grid.hovered_entry()
		if not entry.is_empty():
			grid.begin_move(entry)
			result_label.text = ""
			_show_details()
	elif event.is_action_pressed("inventory_drop"):
		var entry := grid.hovered_entry()
		if not entry.is_empty():
			Inventory.drop(entry)
			result_label.text = "Lo dejé en el piso."
	elif _pressed(event, ["ui_cancel", "pause"]):
		close()


func _letters_input(event: InputEvent, direction: Vector2i) -> void:
	var index := _letter_index()
	if direction.y < 0:
		if index <= 0:
			_set_section(Section.GRID)
		else:
			letter_list.select(index - 1)
		_show_details()
	elif direction.y > 0:
		letter_list.select(mini(index + 1, Inventory.letters.size() - 1))
		_show_details()
	elif _is_use(event) and index >= 0:
		result_label.text = Inventory.use(Inventory.letters[index])
	elif _pressed(event, ["ui_cancel", "pause"]):
		close()


func _set_section(section: Section) -> void:
	_section = section
	if section == Section.LETTERS:
		letter_list.select(0)
	else:
		letter_list.deselect_all()
	grid.queue_redraw()
	_refresh_hint()


func _refresh() -> void:
	if not is_node_ready():
		return
	sanity_bar.max_value = Sanity.maximum
	sanity_bar.value = Sanity.current
	# La barra crece con las cartas: su ancho es proporcional a la cordura máxima.
	sanity_bar.size.x = minf(bar_pixels_per_point * Sanity.maximum, bar_max_width)
	state_label.text = Sanity.state_name()
	var selected := _letter_index()
	letter_list.clear()
	for letter in Inventory.letters:
		letter_list.add_item(letter.display_name)
	if _section == Section.LETTERS:
		if Inventory.letters.is_empty():
			_section = Section.GRID
		else:
			letter_list.select(clampi(selected, 0, Inventory.letters.size() - 1))
	grid.queue_redraw()
	_show_details()


func _show_details() -> void:
	var item: ItemData = null
	var entry: Dictionary = {}
	if _section == Section.LETTERS:
		var index := _letter_index()
		item = Inventory.letters[index] if index >= 0 else null
	else:
		entry = grid.held if grid.is_holding() else grid.hovered_entry()
		item = entry.item if not entry.is_empty() else null
	name_label.text = item.display_name if item else ""
	var description := item.description if item else ""
	if item and entry.get("cooked", false):
		name_label.text += "  (caliente)"
	if item and item.is_weapon():
		if Inventory.is_equipped(entry):
			name_label.text += "  (en la mano)"
		if item.is_ranged:
			description += "\n\nCargador: %d/%d   Balas: %d" % [
				entry.loaded, item.magazine_size, Inventory.ammo_count(item.ammo_item)]
	description_label.text = description
	_refresh_hint()


func _refresh_hint() -> void:
	if _section == Section.LETTERS:
		hint_label.text = HINT_LETTERS
	else:
		hint_label.text = HINT_HOLD if grid.is_holding() else HINT_GRID


func _letter_index() -> int:
	var selected := letter_list.get_selected_items()
	return selected[0] if not selected.is_empty() else -1


func _open_letter(item: ItemData) -> void:
	letter_label.text = item.letter_text
	letter_panel.show()


## Usar: A / Enter / Espacio, o la E del teclado. En el gamepad "interact" es X,
## que en el menú sirve para mover objetos.
static func _is_use(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_accept") or (event is InputEventKey and event.is_action_pressed("interact"))


static func _pressed(event: InputEvent, actions: Array[String]) -> bool:
	for action in actions:
		if event.is_action_pressed(action):
			return true
	return false


static func _direction(event: InputEvent) -> Vector2i:
	for action: String in DIRECTIONS:
		if not event.is_action_pressed(action, true):
			continue
		# El stick manda eventos continuos: solo cuenta el primero.
		if event is InputEventJoypadMotion and not Input.is_action_just_pressed(action):
			continue
		return DIRECTIONS[action]
	return Vector2i.ZERO
