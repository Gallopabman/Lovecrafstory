class_name GameMenu
extends Control
## Menú de estado e inventario. El juego no tiene HUD: la cordura solo se ve
## acá. Abrirlo pausa el juego. Mochila en cuadrícula estilo Resident Evil
## (usar, mover, girar, tirar) y lista de cartas aparte.

enum Section { GRID, LETTERS }

const HINT_GRID := [["E", "usar"], ["R", "mover"], ["X", "tirar"], ["Tab", "cerrar"]]
const HINT_HOLD := [["Q", "girar"], ["R", "soltar"], ["Esc", "cancelar"]]
const HINT_LETTERS := [["E", "leer"], ["Tab", "cerrar"]]
const KEY_COLOR := "#f0c890"
## Una línea por estado de cordura (Sanity.State).
const STATE_HINTS := [
	"Cabeza en su lugar.",
	"Algo no cierra.",
	"Todo respira.",
	"Ya casi no soy yo.",
	"",
]
const STATE_COLORS := [
	Color(0.75, 0.85, 0.7), Color(0.9, 0.8, 0.5), Color(0.95, 0.55, 0.35), Color(0.95, 0.25, 0.2), Color(0.6, 0.1, 0.1),
]
const ZONE_NAMES := {
	&"Hospital": "Hospital San Judas", &"Street": "La avenida", &"TestRoom": "Sala de prueba",
	&"HouseIbarra": "Depto. de los Ibarra", &"HouseAlmacen": "Almacén La Estrella",
	&"HouseRelojeria": "Relojería Kaufmann", &"HousePension": "Pensión Doña Rosa",
	&"HouseFerreyra": "Casa del Dr. Ferreyra", &"HouseVeterinaria": "Veterinaria San Roque", &"HospitalBasement": "Sótano del San Judas",
	&"Theater": "Teatro Imperio", &"Home": "Casa", &"ParkStreet": "El barrio",
	&"PoliceStation": "Comisaría 12", &"Church": "Parroquia San Judas",
}
const DIRECTIONS := {
	"ui_left": Vector2i.LEFT, "move_left": Vector2i.LEFT,
	"ui_right": Vector2i.RIGHT, "move_right": Vector2i.RIGHT,
	"ui_up": Vector2i.UP, "move_forward": Vector2i.UP,
	"ui_down": Vector2i.DOWN, "move_back": Vector2i.DOWN,
}

@export var bar_pixels_per_point := 0.9
@export var bar_max_width := 122.0
## Segundos que el resultado de una acción reemplaza a la ayuda del pie.
@export var result_seconds := 3.0

var _section := Section.GRID
var _last_result := ""
var _result_timer := 0.0

@onready var sanity_bar: ProgressBar = %SanityBar
@onready var state_label: Label = %StateLabel
@onready var grid: InventoryGrid = %InventoryGrid
@onready var letter_list: ItemList = %LetterList
@onready var name_label: Label = %NameLabel
@onready var description_label: Label = %DescriptionLabel
@onready var result_label: Label = %ResultLabel
@onready var hint_label: RichTextLabel = %HintLabel
@onready var letter_panel: Panel = %LetterPanel
@onready var letter_label: Label = %LetterLabel
@onready var survivor_label: Label = %SurvivorLabel
@onready var menu_title: Label = %MenuTitle
@onready var space_label: Label = %SpaceLabel
@onready var sanity_hint: Label = %SanityHint
@onready var item_preview: ItemIcon = %ItemPreview


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
			Audio.play_ui(&"menu_back")
		return
	var direction := _direction(event)
	if direction != Vector2i.ZERO:
		Audio.play_ui(&"menu_move")
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
	grid.focused = true
	show()
	_refresh()
	Audio.play_ui(&"inventory_open")


func close() -> void:
	if visible:
		Audio.play_ui(&"inventory_close")
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
			if grid.try_place():
				Audio.play_ui(&"menu_confirm")
			else:
				result_label.text = "No entra ahí."
				Audio.play_ui(&"menu_back")
		elif event.is_action_pressed("inventory_rotate"):
			grid.rotate_held()
			Audio.play_ui(&"menu_move")
		elif _pressed(event, ["ui_cancel", "pause"]):
			grid.cancel_move()
			Audio.play_ui(&"menu_back")
		_show_details()
	elif _is_use(event):
		var entry := grid.hovered_entry()
		if not entry.is_empty():
			result_label.text = Inventory.use(entry.item, entry)
			Audio.play_ui(&"menu_confirm")
	elif event.is_action_pressed("inventory_move"):
		var entry := grid.hovered_entry()
		if not entry.is_empty():
			grid.begin_move(entry)
			result_label.text = ""
			Audio.play_ui(&"menu_confirm")
			_show_details()
	elif event.is_action_pressed("inventory_drop"):
		var entry := grid.hovered_entry()
		if not entry.is_empty():
			Inventory.drop(entry)
			result_label.text = "Lo dejé en el piso."
			Audio.play_ui(&"menu_back")
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
		Audio.play_ui(&"menu_confirm")
	elif _pressed(event, ["ui_cancel", "pause"]):
		close()


func _set_section(section: Section) -> void:
	_section = section
	if section == Section.LETTERS:
		letter_list.select(0)
	else:
		letter_list.deselect_all()
	grid.focused = section == Section.GRID
	grid.queue_redraw()
	_refresh_hint()


func _refresh() -> void:
	if not is_node_ready():
		return
	sanity_bar.max_value = Sanity.maximum
	sanity_bar.value = Sanity.maximum - Sanity.current  # la barra es de locura
	# La barra crece con las cartas: su ancho es proporcional a la cordura máxima.
	sanity_bar.size.x = minf(bar_pixels_per_point * Sanity.maximum, bar_max_width)
	state_label.text = Sanity.state_name()
	state_label.add_theme_color_override(&"font_color", STATE_COLORS[Sanity.state])
	sanity_hint.text = "Vida %d  ·  %s" % [roundi(Health.current), Sanity.difficulty_name()]
	var scene := get_tree().current_scene
	var zone: String = ZONE_NAMES.get(scene.name, "") if scene else ""
	menu_title.text = "SOBREVIVIENTE #%d" % GameState.survivor_number
	survivor_label.text = zone
	var used := 0
	for entry in Inventory.entries:
		var fp := Inventory.footprint(entry.item, entry.rotated)
		used += fp.x * fp.y
	space_label.text = "%d/%d" % [used, Inventory.grid_size.x * Inventory.grid_size.y]
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
	item_preview.item = item
	name_label.text = item.display_name if item else ""
	var description := item.description if item else ("Vacío." if _section == Section.GRID else "")
	if item and entry.get("cooked", false):
		name_label.text += "  (caliente)"
	if item and item.is_weapon():
		# Datos del arma al lado del nombre (la descripción queda para el texto).
		# "En la mano" ya se ve en la cuadrícula (borde dorado).
		if item.is_ranged:
			name_label.text += "\nCargador %d/%d\n%s: %d" % [entry.loaded, item.magazine_size,
				item.ammo_item.display_name, Inventory.ammo_count(item.ammo_item)]
		elif Inventory.is_equipped(entry):
			name_label.text += "\nEn la mano"
	description_label.text = description
	_refresh_hint()


func _refresh_hint() -> void:
	var hints: Array = HINT_LETTERS
	if _section == Section.GRID:
		hints = HINT_HOLD if grid.is_holding() else HINT_GRID
	var parts: PackedStringArray = []
	for hint: Array in hints:
		parts.append("[color=%s][lb]%s[rb][/color] %s" % [KEY_COLOR, hint[0], hint[1]])
	hint_label.text = "   ".join(parts)


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


## El resultado de la última acción se muestra un rato en el pie, en lugar de la ayuda.
func _process(delta: float) -> void:
	if not visible:
		return
	if result_label.text != _last_result:
		_last_result = result_label.text
		_result_timer = result_seconds
	elif _result_timer > 0.0:
		_result_timer -= delta
		if _result_timer <= 0.0:
			result_label.text = ""
			_last_result = ""
	hint_label.visible = result_label.text == ""
