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
		ItemData.Kind.LETTER:
			_envelope(canvas, box, base, dark, outline)
		ItemData.Kind.WEAPON:
			if item.is_ranged:
				_pistol(canvas, box, Color(0.42, 0.43, 0.46, alpha), outline)
			else:
				_crowbar(canvas, box, Color(0.62, 0.16, 0.12, alpha), outline, rect)
		ItemData.Kind.AMMO:
			_bullets(canvas, box, Color(0.85, 0.66, 0.3, alpha), outline)
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
