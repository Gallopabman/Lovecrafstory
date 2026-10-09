class_name ItemIcon
extends Control
## Íconos de objetos dibujados con primitivas (estilo pixel, sin texturas): una lata,
## una botella, un cómic, un VHS, una carta, la pistola, la barreta, balas y materiales.
## Como nodo, muestra en grande el objeto de `item` (la vista previa del menú);
## `draw_icon` sirve para dibujarlos en cualquier CanvasItem (la cuadrícula).

var item: ItemData:
	set(value):
		item = value
		queue_redraw()


func _draw() -> void:
	if item:
		draw_icon(self, item, Rect2(Vector2.ZERO, size))


static func draw_icon(canvas: CanvasItem, item: ItemData, rect: Rect2, alpha := 1.0) -> void:
	# El ícono ocupa un cuadrado centrado dentro de `rect` (con margen).
	var side := minf(rect.size.x, rect.size.y) * 0.8
	var box := Rect2(rect.get_center() - Vector2.ONE * side / 2, Vector2.ONE * side)
	var base := item.world_color
	base.a = alpha
	var dark := base.darkened(0.55)
	var light := base.lightened(0.35)
	var outline := Color(0.02, 0.02, 0.02, alpha)
	var id := String(item.id)
	match item.kind:
		ItemData.Kind.FOOD:
			if id.contains("water"):
				_bottle(canvas, box, base, light, outline)
			elif id.contains("chocolate"):
				_bar(canvas, box, base, light, outline)
			else:
				_can(canvas, box, base, light, dark, outline)
		ItemData.Kind.COMIC:
			_book(canvas, box, base, light, outline)
		ItemData.Kind.MOVIE:
			_tape(canvas, box, base, outline)
		ItemData.Kind.DIARY:
			_page(canvas, box, base, dark, outline)
		ItemData.Kind.LETTER:
			_envelope(canvas, box, base, dark, outline)
		ItemData.Kind.WEAPON:
			if item.is_ranged and item.pellets > 1:
				_shotgun(canvas, rect, Color(0.36, 0.37, 0.4, alpha), Color(0.45, 0.3, 0.2, alpha), outline)
			elif item.is_ranged:
				_pistol(canvas, box, Color(0.42, 0.43, 0.46, alpha), outline)
			elif id.contains("broom"):
				_broom(canvas, rect, Color(0.58, 0.42, 0.26, alpha), Color(0.75, 0.62, 0.32, alpha), outline)
			else:
				_crowbar(canvas, box, Color(0.62, 0.16, 0.12, alpha), outline, rect)
		ItemData.Kind.AMMO:
			if id.contains("shell"):
				_shells(canvas, box, Color(0.7, 0.16, 0.1, alpha), Color(0.85, 0.66, 0.3, alpha), outline)
			else:
				_bullets(canvas, box, Color(0.85, 0.66, 0.3, alpha), outline)
		ItemData.Kind.KEY:
			_key(canvas, box, base, outline)
		ItemData.Kind.MEDICINE:
			_medicine(canvas, box, item.max_stack > 1, outline, alpha)
		ItemData.Kind.MATERIAL:
			if id.contains("wood"):
				_planks(canvas, box, base, dark, outline)
			elif id.contains("metal"):
				_plate(canvas, box, base, dark, outline)
			elif id.contains("cable"):
				_coil(canvas, box, base, outline)
			else:
				_cloth(canvas, box, base, dark, outline)
		_:
			canvas.draw_rect(box, base)


static func _r(box: Rect2, x: float, y: float, w: float, h: float) -> Rect2:
	# Rectángulo en coordenadas relativas (0..1) dentro de `box`.
	return Rect2(box.position + Vector2(x, y) * box.size, Vector2(w, h) * box.size)


static func _p(box: Rect2, x: float, y: float) -> Vector2:
	return box.position + Vector2(x, y) * box.size


static func _framed(canvas: CanvasItem, rect: Rect2, fill: Color, outline: Color) -> void:
	canvas.draw_rect(rect, fill)
	canvas.draw_rect(rect, outline, false, 1.0)


static func _can(c: CanvasItem, b: Rect2, base: Color, light: Color, dark: Color, o: Color) -> void:
	_framed(c, _r(b, 0.22, 0.18, 0.56, 0.66), base, o)
	c.draw_rect(_r(b, 0.22, 0.36, 0.56, 0.3), light)
	c.draw_rect(_r(b, 0.2, 0.14, 0.6, 0.08), dark)
	c.draw_rect(_r(b, 0.2, 0.82, 0.6, 0.06), dark)


static func _bottle(c: CanvasItem, b: Rect2, base: Color, light: Color, o: Color) -> void:
	_framed(c, _r(b, 0.3, 0.3, 0.4, 0.6), Color(base, base.a * 0.9), o)
	_framed(c, _r(b, 0.4, 0.12, 0.2, 0.2), base, o)
	c.draw_rect(_r(b, 0.36, 0.5, 0.28, 0.18), light)


static func _bar(c: CanvasItem, b: Rect2, base: Color, light: Color, o: Color) -> void:
	_framed(c, _r(b, 0.12, 0.3, 0.76, 0.4), base, o)
	c.draw_rect(_r(b, 0.12, 0.3, 0.3, 0.4), light)
	for i in 3:
		c.draw_line(_p(b, 0.5 + i * 0.12, 0.32), _p(b, 0.5 + i * 0.12, 0.68), Color(o, 0.5))


static func _book(c: CanvasItem, b: Rect2, base: Color, light: Color, o: Color) -> void:
	_framed(c, _r(b, 0.2, 0.08, 0.6, 0.84), base, o)
	c.draw_rect(_r(b, 0.2, 0.08, 0.1, 0.84), base.darkened(0.4))
	c.draw_rect(_r(b, 0.36, 0.18, 0.36, 0.2), light)
	c.draw_rect(_r(b, 0.36, 0.46, 0.36, 0.06), Color(1, 1, 1, base.a * 0.7))
	c.draw_rect(_r(b, 0.36, 0.58, 0.28, 0.06), Color(1, 1, 1, base.a * 0.5))


static func _tape(c: CanvasItem, b: Rect2, base: Color, o: Color) -> void:
	_framed(c, _r(b, 0.08, 0.26, 0.84, 0.5), Color(0.1, 0.1, 0.1, base.a), o)
	c.draw_rect(_r(b, 0.2, 0.32, 0.6, 0.16), base)
	for x in [0.33, 0.67]:
		c.draw_circle(_p(b, x, 0.6), b.size.x * 0.09, Color(0.75, 0.72, 0.65, base.a))
		c.draw_circle(_p(b, x, 0.6), b.size.x * 0.035, Color(0.1, 0.1, 0.1, base.a))


static func _envelope(c: CanvasItem, b: Rect2, base: Color, dark: Color, o: Color) -> void:
	var r := _r(b, 0.08, 0.24, 0.84, 0.54)
	_framed(c, r, base, o)
	c.draw_line(r.position, _p(b, 0.5, 0.56), dark, 1.0)
	c.draw_line(Vector2(r.end.x, r.position.y), _p(b, 0.5, 0.56), dark, 1.0)
	c.draw_circle(_p(b, 0.5, 0.58), b.size.x * 0.06, Color(0.6, 0.1, 0.08, base.a))


static func _pistol(c: CanvasItem, b: Rect2, metal: Color, o: Color) -> void:
	var body := PackedVector2Array([_p(b, 0.08, 0.3), _p(b, 0.92, 0.3), _p(b, 0.92, 0.46), _p(b, 0.5, 0.46),
		_p(b, 0.44, 0.84), _p(b, 0.22, 0.84), _p(b, 0.3, 0.46), _p(b, 0.08, 0.46)])
	c.draw_colored_polygon(body, metal)
	body.append(body[0])
	c.draw_polyline(body, o, 1.0)
	c.draw_rect(_r(b, 0.26, 0.56, 0.14, 0.24), metal.darkened(0.4))
	c.draw_line(_p(b, 0.42, 0.46), _p(b, 0.46, 0.6), o, 1.0)


static func _crowbar(c: CanvasItem, b: Rect2, red: Color, o: Color, rect: Rect2) -> void:
	# Cruza en diagonal todo el lugar del objeto (ocupa más de una celda).
	var inset := rect.grow(-minf(rect.size.x, rect.size.y) * 0.2)
	var a := Vector2(inset.position.x, inset.end.y)
	var z := Vector2(inset.end.x, inset.position.y)
	var width := maxf(b.size.x * 0.1, 2.0)
	c.draw_line(a, z, o, width + 2.0)
	c.draw_line(a, z, red, width)
	var hook := z + (z - a).normalized().rotated(PI * 0.5) * width * 2.0
	c.draw_line(z, hook, o, width + 2.0)
	c.draw_line(z, hook, red, width)


## El palo de escoba: un palo de madera en diagonal con el cepillo en la punta.
static func _broom(c: CanvasItem, rect: Rect2, wood: Color, straw: Color, o: Color) -> void:
	var inset := rect.grow(-minf(rect.size.x, rect.size.y) * 0.18)
	var a := Vector2(inset.end.x, inset.position.y)
	var z := Vector2(inset.position.x, inset.end.y)
	var width := maxf(rect.size.x * 0.08, 2.0)
	var head := a.lerp(z, 0.78)
	c.draw_line(a, head, o, width + 2.0)
	c.draw_line(a, head, wood, width)
	var dir := (z - a).normalized()
	var side := dir.rotated(PI * 0.5) * width * 2.2
	var brush := PackedVector2Array([head - side, head + side, z + side * 1.6, z - side * 1.6])
	c.draw_colored_polygon(brush, straw)
	c.draw_polyline(brush + PackedVector2Array([brush[0]]), o, 1.0)


static func _bullets(c: CanvasItem, b: Rect2, brass: Color, o: Color) -> void:
	for i in 3:
		var x := 0.18 + i * 0.24
		_framed(c, _r(b, x, 0.36, 0.16, 0.5), brass, o)
		c.draw_rect(_r(b, x, 0.2, 0.16, 0.18), Color(0.6, 0.45, 0.35, brass.a))


static func _planks(c: CanvasItem, b: Rect2, base: Color, dark: Color, o: Color) -> void:
	for i in 3:
		var r := _r(b, 0.1, 0.18 + i * 0.22, 0.8, 0.18)
		_framed(c, r, base if i != 1 else base.lightened(0.15), o)
		c.draw_line(r.position + Vector2(r.size.x * 0.3, 2), r.position + Vector2(r.size.x * 0.55, 2), dark)


static func _plate(c: CanvasItem, b: Rect2, base: Color, dark: Color, o: Color) -> void:
	_framed(c, _r(b, 0.14, 0.2, 0.72, 0.6), base, o)
	for p in [Vector2(0.24, 0.3), Vector2(0.76, 0.3), Vector2(0.24, 0.7), Vector2(0.76, 0.7)]:
		c.draw_circle(_p(b, p.x, p.y), b.size.x * 0.04, dark)


static func _coil(c: CanvasItem, b: Rect2, base: Color, o: Color) -> void:
	var center := b.get_center()
	for i in 3:
		var radius := b.size.x * (0.36 - i * 0.1)
		c.draw_arc(center, radius, 0, TAU, 20, o, 3.0)
		c.draw_arc(center, radius, 0, TAU, 20, base, 1.5)
	c.draw_line(center + Vector2(b.size.x * 0.36, 0), _p(b, 0.95, 0.9), base, 1.5)


static func _cloth(c: CanvasItem, b: Rect2, base: Color, dark: Color, o: Color) -> void:
	var shape := PackedVector2Array([_p(b, 0.12, 0.3), _p(b, 0.88, 0.22), _p(b, 0.84, 0.78), _p(b, 0.16, 0.82)])
	c.draw_colored_polygon(shape, base)
	shape.append(shape[0])
	c.draw_polyline(shape, o, 1.0)
	c.draw_line(_p(b, 0.2, 0.52), _p(b, 0.8, 0.46), dark, 1.0)


## Ocupa todo el lugar del objeto (3x1): caño largo y culata de madera.
static func _shotgun(c: CanvasItem, rect: Rect2, metal: Color, wood: Color, o: Color) -> void:
	var r := rect.grow(-2)
	var mid := r.get_center().y
	var barrel := Rect2(r.position.x + r.size.x * 0.35, mid - 3, r.size.x * 0.63, 3)
	_framed(c, barrel, metal, o)
	_framed(c, Rect2(barrel.position + Vector2(0, 3), Vector2(barrel.size.x * 0.7, 2)), metal.darkened(0.3), o)
	var stock := PackedVector2Array([Vector2(r.position.x, mid - 2), Vector2(r.position.x + r.size.x * 0.36, mid - 4),
		Vector2(r.position.x + r.size.x * 0.4, mid + 3), Vector2(r.position.x + r.size.x * 0.3, mid + 3),
		Vector2(r.position.x + 1, mid + 6)])
	c.draw_colored_polygon(stock, wood)
	stock.append(stock[0])
	c.draw_polyline(stock, o, 1.0)


static func _shells(c: CanvasItem, b: Rect2, red: Color, brass: Color, o: Color) -> void:
	for i in 3:
		var x := 0.16 + i * 0.25
		_framed(c, _r(b, x, 0.2, 0.2, 0.5), red, o)
		_framed(c, _r(b, x, 0.7, 0.2, 0.14), brass, o)


static func _key(c: CanvasItem, b: Rect2, base: Color, o: Color) -> void:
	var ring := _p(b, 0.3, 0.5)
	c.draw_circle(ring, b.size.x * 0.2, o)
	c.draw_circle(ring, b.size.x * 0.16, base)
	c.draw_circle(ring, b.size.x * 0.07, o)
	_framed(c, _r(b, 0.46, 0.45, 0.46, 0.1), base, o)
	_framed(c, _r(b, 0.74, 0.55, 0.07, 0.14), base, o)
	_framed(c, _r(b, 0.84, 0.55, 0.07, 0.1), base, o)


## Botiquín (caja blanca con cruz roja) o vendas (un rollo).
static func _medicine(c: CanvasItem, b: Rect2, bandage: bool, o: Color, alpha: float) -> void:
	var white := Color(0.92, 0.9, 0.86, alpha)
	var red := Color(0.8, 0.12, 0.1, alpha)
	if bandage:
		c.draw_circle(b.get_center(), b.size.x * 0.32, o)
		c.draw_circle(b.get_center(), b.size.x * 0.28, white)
		c.draw_circle(b.get_center(), b.size.x * 0.1, Color(0.7, 0.68, 0.62, alpha))
		return
	_framed(c, _r(b, 0.1, 0.25, 0.8, 0.55), white, o)
	c.draw_rect(_r(b, 0.42, 0.33, 0.16, 0.4), red)
	c.draw_rect(_r(b, 0.3, 0.45, 0.4, 0.16), red)
	c.draw_rect(_r(b, 0.38, 0.17, 0.24, 0.09), Color(0.5, 0.5, 0.5, alpha))


## Página arrancada de un cuaderno: renglones y una mancha.
static func _page(c: CanvasItem, b: Rect2, base: Color, dark: Color, o: Color) -> void:
	var r := _r(b, 0.2, 0.1, 0.6, 0.8)
	_framed(c, r, base, o)
	for i in 5:
		var y := r.position.y + r.size.y * (0.2 + i * 0.15)
		c.draw_line(Vector2(r.position.x + 2.0, y), Vector2(r.end.x - 2.0 - (i % 2) * 3.0, y), dark, 1.0)
	c.draw_circle(_p(b, 0.66, 0.74), b.size.x * 0.05, Color(0.35, 0.15, 0.5, base.a))
