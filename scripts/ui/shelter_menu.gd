class_name ShelterMenu
extends Control
## Menú del plano del refugio: los espacios del blueprint, su nivel, lo que
## cuesta la próxima mejora contra lo que hay en el depósito, y el nivel cozy.
## Se abre desde la estación BLUEPRINT (el plano en la pared). Pausa el juego.

const HINT := "E / Enter: construir     Esc: salir"
const HINT_MOVE := "E / Enter: mudarse acá     Esc: salir"
const COLOR_OK := "#9fd59a"
const COLOR_MISSING := "#d58a7a"

var _index := 0
## Refugio del plano abierto (Shelter.REFUGES).
var _refuge: StringName = &"hospital"

@onready var cozy_bar: ProgressBar = %CozyBar
@onready var cozy_label: Label = %CozyLabel
@onready var slot_list: ItemList = %SlotList
@onready var upgrade_name: Label = %UpgradeName
@onready var upgrade_desc: Label = %UpgradeDesc
@onready var cost_label: RichTextLabel = %CostLabel
@onready var result_label: Label = %ShelterResult
@onready var stock_label: Label = %StockLabel
@onready var hint_label: Label = %ShelterHint
@onready var title_label: Label = $Title


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


func open(refuge: StringName = &"hospital") -> void:
	_refuge = refuge
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	result_label.text = ""
	hint_label.text = HINT if Shelter.is_active(_refuge) else HINT_MOVE
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
	# Un refugio que no es el activo: la única acción es mudarse (una decisión, GDD).
	if not Shelter.is_active(_refuge):
		var previous := Shelter.refuge_name()
		Shelter.move_to(_refuge)
		hint_label.text = HINT
		result_label.text = "Me mudé. %s queda como está; ahora esto es casa." % previous
		Audio.play_ui(&"menu_confirm")
		return
	var slot: StringName = Shelter.SLOT_ORDER[_index]
	var next := Shelter.next_upgrade(slot, _refuge)
	if next.is_empty():
		result_label.text = "Ya no se puede mejorar más."
	elif Shelter.upgrade(slot, _refuge):
		result_label.text = "Listo: %s." % next.name.to_lower()
		Audio.play_ui(&"menu_confirm")
	else:
		result_label.text = "Me faltan materiales."
		Audio.play_ui(&"menu_back")


func _refresh() -> void:
	if not is_node_ready():
		return
	var cozy := Shelter.cozy(_refuge)
	cozy_bar.max_value = Shelter.cozy_max()
	cozy_bar.value = cozy
	cozy_label.text = "Hogar %d/%d" % [cozy, Shelter.cozy_max()]
	title_label.text = Shelter.refuge_name(_refuge).to_upper()

	slot_list.clear()
	for slot in Shelter.SLOT_ORDER:
		slot_list.add_item("%s   %d/%d" % [Shelter.SLOTS[slot].name, Shelter.level(slot, _refuge), Shelter.max_level(slot)])
	slot_list.select(_index)

	if not Shelter.is_active(_refuge):
		upgrade_name.text = "Todavía no es mi refugio"
		upgrade_desc.text = ("Hoy vivo en: %s. Si me mudo, los que vengan después van a llegar acá "
			+ "y allá solo va a quedar lo que construí. Los materiales me los llevo.") % Shelter.refuge_name()
		cost_label.text = ""
	else:
		var slot: StringName = Shelter.SLOT_ORDER[_index]
		var next := Shelter.next_upgrade(slot, _refuge)
		if next.is_empty():
			upgrade_name.text = "%s: completo" % Shelter.SLOTS[slot].name
			upgrade_desc.text = Shelter.SLOTS[slot].levels[-1].desc
			cost_label.text = ""
		else:
			upgrade_name.text = "Nivel %d: %s" % [Shelter.level(slot, _refuge) + 1, next.name]
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
