class_name ShelterMenu
extends Control
## Menú del plano del refugio: los espacios del blueprint, su nivel, lo que
## cuesta la próxima mejora contra lo que hay en el depósito, y el nivel cozy.
## Se abre desde la estación BLUEPRINT (el plano en la pared). Pausa el juego.

const HINT := "E / Enter: construir     Esc: salir"
const COLOR_OK := "#9fd59a"
const COLOR_MISSING := "#d58a7a"

var _index := 0

@onready var cozy_bar: ProgressBar = %CozyBar
@onready var cozy_label: Label = %CozyLabel
@onready var slot_list: ItemList = %SlotList
@onready var upgrade_name: Label = %UpgradeName
@onready var upgrade_desc: Label = %UpgradeDesc
@onready var cost_label: RichTextLabel = %CostLabel
@onready var result_label: Label = %ShelterResult
@onready var stock_label: Label = %StockLabel
@onready var hint_label: Label = %ShelterHint


func _ready() -> void:
	add_to_group(&"shelter_menu")
	hide()
	Shelter.changed.connect(_refresh)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_up", true) or event.is_action_pressed("move_forward", true):
		_select(_index - 1)
	elif event.is_action_pressed("ui_down", true) or event.is_action_pressed("move_back", true):
		_select(_index + 1)
	elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.is_action_pressed("interact")):
		_build()
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("menu"):
		close()


func open() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	result_label.text = ""
	hint_label.text = HINT
	show()
	_refresh()


func close() -> void:
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _select(index: int) -> void:
	_index = clampi(index, 0, Shelter.SLOT_ORDER.size() - 1)
	result_label.text = ""
	_refresh()


func _build() -> void:
	var slot: StringName = Shelter.SLOT_ORDER[_index]
	var next := Shelter.next_upgrade(slot)
	if next.is_empty():
		result_label.text = "Ya no se puede mejorar más."
	elif Shelter.upgrade(slot):
		result_label.text = "Listo: %s." % next.name.to_lower()
	else:
		result_label.text = "Me faltan materiales."


func _refresh() -> void:
	if not is_node_ready():
		return
	cozy_bar.max_value = Shelter.cozy_max()
	cozy_bar.value = Shelter.cozy()
	cozy_label.text = "Hogar %d/%d" % [Shelter.cozy(), Shelter.cozy_max()]

	slot_list.clear()
	for slot in Shelter.SLOT_ORDER:
		slot_list.add_item("%s   %d/%d" % [Shelter.SLOTS[slot].name, Shelter.level(slot), Shelter.max_level(slot)])
	slot_list.select(_index)

	var slot: StringName = Shelter.SLOT_ORDER[_index]
	var next := Shelter.next_upgrade(slot)
	if next.is_empty():
		upgrade_name.text = "%s: completo" % Shelter.SLOTS[slot].name
		upgrade_desc.text = Shelter.SLOTS[slot].levels[-1].desc
		cost_label.text = ""
	else:
		upgrade_name.text = "Nivel %d: %s" % [Shelter.level(slot) + 1, next.name]
		upgrade_desc.text = next.desc
		var lines: PackedStringArray = ["Necesito:"]
		for id in next.cost:
			var have: int = Shelter.stock.get(id, 0)
			var need: int = next.cost[id]
			lines.append("[color=%s]  %s  %d/%d[/color]" % [
				COLOR_OK if have >= need else COLOR_MISSING, Shelter.material_name(id), have, need])
		cost_label.text = "\n".join(lines)

	var parts: PackedStringArray = []
	for id in Shelter.MATERIALS:
		parts.append("%s %d" % [Shelter.material_name(id), Shelter.stock.get(id, 0)])
	stock_label.text = "Depósito: " + " · ".join(parts)
