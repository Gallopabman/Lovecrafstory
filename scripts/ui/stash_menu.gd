class_name StashMenu
extends Control
## El alijo del refugio: la mochila a la izquierda y lo guardado a la derecha.
## Arriba/abajo elige, izquierda/derecha cambia de lado, E pasa el objeto al otro lado,
## X deja todos los materiales (van al depósito para construir). Pausa el juego.

enum Side { BACKPACK, STASH }

const HINTS := [["E", "pasar"], ["←→", "cambiar de lado"], ["X", "dejar materiales"], ["Esc", "salir"]]
const KEY_COLOR := "#f0c890"
## Nombres cortos de los materiales para la línea del depósito.
const MATERIAL_SHORT := {
	&"material_wood": "Madera", &"material_metal": "Chatarra", &"material_cloth": "Tela", &"material_cable": "Cables",
}

@export var result_seconds := 3.0

var _side := Side.BACKPACK
var _index := {Side.BACKPACK: 0, Side.STASH: 0}
var _result_timer := 0.0

@onready var title_label: Label = %StashTitle
@onready var capacity_label: Label = %StashCapacity
@onready var backpack_list: ItemList = %StashBackpackList
@onready var stash_list: ItemList = %StashList
@onready var detail_label: Label = %StashDetail
@onready var materials_label: Label = %StashMaterials
@onready var hint_label: RichTextLabel = %StashHint
@onready var result_label: Label = %StashResult


func _ready() -> void:
	add_to_group(&"stash_menu")
	hide()
	Shelter.changed.connect(_refresh)
	Inventory.changed.connect(_refresh)
	var parts: PackedStringArray = []
	for hint: Array in HINTS:
		parts.append("[color=%s][lb]%s[rb][/color] %s" % [KEY_COLOR, hint[0], hint[1]])
	hint_label.text = "   ".join(parts)


func _process(delta: float) -> void:
	if not visible:
		return
	if _result_timer > 0.0:
		_result_timer -= delta
		if _result_timer <= 0.0:
			result_label.text = ""
	hint_label.visible = result_label.text == ""


func _input(event: InputEvent) -> void:
	if not visible:
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_up", true) or event.is_action_pressed("move_forward", true):
		_move(-1)
	elif event.is_action_pressed("ui_down", true) or event.is_action_pressed("move_back", true):
		_move(1)
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("move_left") \
			or event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		_side = Side.STASH if _side == Side.BACKPACK else Side.BACKPACK
		Audio.play_ui(&"menu_move")
		_refresh()
	elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.is_action_pressed("interact")):
		transfer()
	elif event.is_action_pressed("inventory_drop"):
		store_materials()
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("menu"):
		close()


func open() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_side = Side.BACKPACK
	result_label.text = ""
	show()
	_refresh()
	Audio.play_ui(&"inventory_open")


func close() -> void:
	if not visible:
		return
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Audio.play_ui(&"inventory_close")


## Pasa lo elegido al otro lado.
func transfer() -> void:
	var index: int = _index[_side]
	var text := ""
	if _side == Side.BACKPACK:
		var entries := _backpack_entries()
		if index < entries.size():
			text = Shelter.store(entries[index])
	elif index < Shelter.stash.size():
		text = Shelter.take(index)
	if text:
		_show_result(text)
		Audio.play_ui(&"menu_back" if text.begins_with("El alijo") or text.begins_with("No me") else &"menu_confirm")
	_refresh()


func store_materials() -> void:
	var amounts := Shelter.store_materials()
	if amounts.is_empty():
		_show_result("No tengo materiales encima.")
		return
	var parts: PackedStringArray = []
	for id in amounts:
		parts.append("%d %s" % [amounts[id], Shelter.material_name(id).to_lower()])
	_show_result("Dejé para construir: %s." % ", ".join(parts))
	Audio.play_ui(&"menu_confirm")
	_refresh()


func _move(delta: int) -> void:
	var size := _backpack_entries().size() if _side == Side.BACKPACK else Shelter.stash.size()
	if size == 0:
		return
	_index[_side] = clampi(_index[_side] + delta, 0, size - 1)
	Audio.play_ui(&"menu_move")
	_refresh()


func _show_result(text: String) -> void:
	result_label.text = text
	_result_timer = result_seconds


## La mochila en orden de lectura (fila por fila), como se ve en la cuadrícula.
func _backpack_entries() -> Array[Dictionary]:
	var list: Array[Dictionary] = Inventory.entries.duplicate()
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.cell.y < b.cell.y or (a.cell.y == b.cell.y and a.cell.x < b.cell.x))
	return list


func _refresh() -> void:
	if not is_node_ready() or not visible:
		return
	var level := Shelter.level(&"stash")
	var container: String = "Caja de cartón" if level == 0 else Shelter.SLOTS[&"stash"].levels[level - 1].name
	title_label.text = "ALIJO  ·  %s" % container
	capacity_label.text = "%d/%d" % [Shelter.stash_used(), Shelter.stash_capacity_now()]
	var backpack := _backpack_entries()
	_fill(backpack_list, backpack, Side.BACKPACK)
	_fill(stash_list, Shelter.stash, Side.STASH)
	var selected: Array = backpack if _side == Side.BACKPACK else Shelter.stash
	var index: int = _index[_side]
	if index < selected.size():
		var item: ItemData = selected[index].item
		detail_label.text = "%s. %s" % [item.display_name, item.description]
	else:
		detail_label.text = "Nada para pasar." if _side == Side.BACKPACK else "El alijo está vacío."
	var parts: PackedStringArray = []
	for id in Shelter.MATERIALS:
		parts.append("%s %d" % [MATERIAL_SHORT.get(id, Shelter.material_name(id)), Shelter.stock.get(id, 0)])
	materials_label.text = " · ".join(parts)


func _fill(list: ItemList, entries: Array, side: int) -> void:
	list.clear()
	for entry: Dictionary in entries:
		list.add_item(_entry_text(entry))
	_index[side] = clampi(_index[side], 0, maxi(entries.size() - 1, 0))
	list.deselect_all()
	if side == _side and not entries.is_empty():
		list.select(_index[side])
		list.ensure_current_is_visible()
	list.modulate.a = 1.0 if side == _side else 0.55


static func _entry_text(entry: Dictionary) -> String:
	var item: ItemData = entry.item
	var text := item.display_name
	if item.max_stack > 1:
		text += " x%d" % entry.count
	elif item.is_weapon() and item.is_ranged:
		text += " (%d/%d)" % [entry.get("loaded", 0), item.magazine_size]
	if entry.get("cooked", false):
		text += " (caliente)"
	return text
