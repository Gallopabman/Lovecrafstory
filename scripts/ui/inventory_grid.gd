class_name InventoryGrid
extends Control
## Dibuja la mochila en cuadrícula con cursor, y el objeto que se está moviendo
## (verde si entra, rojo si no). La lógica de entrada la maneja GameMenu.

@export var cell_size := 24
@export var cell_color := Color(0.075, 0.065, 0.06, 1)
@export var frame_color := Color(0.02, 0.018, 0.016, 1)
@export var line_color := Color(0.22, 0.19, 0.16, 1)
@export var shadow_color := Color(0.01, 0.01, 0.01, 1)
@export var cursor_color := Color(0.98, 0.86, 0.58, 1)
@export var valid_color := Color(0.3, 0.8, 0.35, 0.4)
@export var invalid_color := Color(0.85, 0.2, 0.15, 0.45)
@export var equipped_color := Color(0.95, 0.75, 0.3, 1)
## Latidos por segundo del cursor.
@export var pulse_speed := 0.9

## Si la cuadrícula tiene el foco (si no, el cursor queda apagado).
var focused := true

var cursor := Vector2i.ZERO
## Entrada que se está moviendo (vacía si ninguna) y su posición tentativa.
var held: Dictionary = {}
var held_cell := Vector2i.ZERO
var held_rotated := false


func _ready() -> void:
	custom_minimum_size = Vector2(Inventory.grid_size * cell_size)
	size = custom_minimum_size
	Inventory.changed.connect(queue_redraw)


func is_holding() -> bool:
	return not held.is_empty()


func hovered_entry() -> Dictionary:
	return Inventory.entry_at(cursor)


## Mueve el cursor (o el objeto sostenido). Devuelve false si se quiso salir
## por abajo, para que el menú pase el foco a la lista de cartas.
func move_cursor(delta: Vector2i) -> bool:
	var grid := Inventory.grid_size
	if is_holding():
		var fp := Inventory.footprint(held.item, held_rotated)
		held_cell = (held_cell + delta).clamp(Vector2i.ZERO, grid - fp)
		cursor = held_cell
	else:
		var target := cursor + delta
		if target.y >= grid.y:
			return false
		# Si el cursor está sobre un objeto grande, lo salta de una vez.
		var current := hovered_entry()
		if not current.is_empty() and delta != Vector2i.ZERO:
			var rect := Inventory.entry_rect(current)
			while rect.has_point(target) and Rect2i(Vector2i.ZERO, grid).has_point(target + delta):
				target += delta
		cursor = target.clamp(Vector2i.ZERO, grid - Vector2i.ONE)
	queue_redraw()
	return true


func begin_move(entry: Dictionary) -> void:
	held = entry
	held_cell = entry.cell
	held_rotated = entry.rotated
	cursor = held_cell
	queue_redraw()


func rotate_held() -> void:
	if not is_holding():
		return
	held_rotated = not held_rotated
	var fp := Inventory.footprint(held.item, held_rotated)
	held_cell = held_cell.clamp(Vector2i.ZERO, Inventory.grid_size - fp)
	cursor = held_cell
	queue_redraw()


func try_place() -> bool:
	if not is_holding() or not Inventory.move(held, held_cell, held_rotated):
		return false
	held = {}
	queue_redraw()
	return true


func cancel_move() -> void:
	if is_holding():
		cursor = held.cell
	held = {}
	queue_redraw()


func _process(_delta: float) -> void:
	# El cursor late: se redibuja mientras el menú está abierto.
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	var grid := Inventory.grid_size
	var font := get_theme_default_font()
	var font_size := get_theme_default_font_size()
	# Fondo hundido y celdas con bisel (luz arriba a la izquierda, sombra abajo a la derecha).
	draw_rect(Rect2(Vector2.ZERO, size).grow(2), frame_color)
	for y in grid.y:
		for x in grid.x:
			var cell_rect := Rect2(Vector2(x, y) * cell_size, Vector2.ONE * cell_size).grow(-1)
			draw_rect(cell_rect, cell_color)
			draw_line(cell_rect.position, Vector2(cell_rect.end.x, cell_rect.position.y), shadow_color)
			draw_line(cell_rect.position, Vector2(cell_rect.position.x, cell_rect.end.y), shadow_color)
			draw_line(Vector2(cell_rect.position.x, cell_rect.end.y), cell_rect.end, line_color)
			draw_line(Vector2(cell_rect.end.x, cell_rect.position.y), cell_rect.end, line_color)

	for entry in Inventory.entries:
		var faded := is_same(entry, held)
		_draw_item(entry, Inventory.entry_rect(entry), faded, font, font_size)

	var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() / 1000.0 * TAU * pulse_speed)
	if is_holding():
		var fp := Inventory.footprint(held.item, held_rotated)
		var rect := Rect2i(held_cell, fp)
		var ok := Inventory.can_place(held.item, held_cell, held_rotated, held)
		draw_rect(_to_pixels(rect).grow(-1), valid_color if ok else invalid_color)
		_draw_item(held, rect, false, font, font_size)
		draw_rect(_to_pixels(rect).grow(-1), Color(cursor_color, pulse), false, 1.0)
	else:
		var hovered := hovered_entry()
		var rect := Inventory.entry_rect(hovered) if not hovered.is_empty() else Rect2i(cursor, Vector2i.ONE)
		var pixels := _to_pixels(rect)
		if focused:
			draw_rect(pixels.grow(-1), Color(cursor_color, 0.12 * pulse))
		draw_rect(pixels.grow(-1), Color(cursor_color, pulse if focused else 0.3), false, 1.0)
		# Esquinas marcadas, como un visor.
		if focused:
			for corner in [pixels.position, Vector2(pixels.end.x, pixels.position.y),
					Vector2(pixels.position.x, pixels.end.y), pixels.end]:
				draw_rect(Rect2(corner - Vector2(2, 2), Vector2(4, 4)), Color(cursor_color, pulse))


func _draw_item(entry: Dictionary, rect: Rect2i, faded: bool, font: Font, font_size: int) -> void:
	var item: ItemData = entry.item
	var pixels := _to_pixels(rect).grow(-2)
	var alpha := 0.3 if faded else 1.0
	var equipped := Inventory.is_equipped(entry)
	draw_rect(pixels, Color(item.world_color.darkened(0.78), 0.9 * alpha))
	ItemIcon.draw_icon(self, item, pixels, alpha)
	draw_rect(pixels, Color(equipped_color if equipped else item.world_color.darkened(0.2), 0.8 * alpha),
		false, 1.0)
	var text_color := Color(1, 0.96, 0.9, alpha)
	var shadow := Color(0, 0, 0, alpha)
	# En la mano: una marca arriba a la izquierda.
	if equipped:
		draw_rect(Rect2(pixels.position + Vector2(1, 1), Vector2(4, 4)), Color(equipped_color, alpha))
	# Comida cocinada: una marca naranja arriba a la derecha.
	if entry.get("cooked", false):
		draw_rect(Rect2(pixels.end.x - 5, pixels.position.y + 1, 4, 4), Color(1.0, 0.55, 0.2, alpha))
	# Abajo a la derecha: cantidad de la pila o balas en el cargador.
	var corner := ""
	if item.max_stack > 1:
		corner = str(entry.count)
	elif item.is_weapon() and item.is_ranged:
		corner = str(entry.loaded)
	if corner:
		var at := pixels.end + Vector2(-pixels.size.x, -1)
		draw_string(font, at + Vector2(1, 1), corner, HORIZONTAL_ALIGNMENT_RIGHT, pixels.size.x - 1, font_size, shadow)
		draw_string(font, at, corner, HORIZONTAL_ALIGNMENT_RIGHT, pixels.size.x - 1, font_size, text_color)

func _to_pixels(rect: Rect2i) -> Rect2:
	return Rect2(Vector2(rect.position * cell_size), Vector2(rect.size * cell_size))
