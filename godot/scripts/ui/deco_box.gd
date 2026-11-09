class_name DecoBox
extends StyleBox
## Art Deco kutu stili: köşeleri kesik (sekizgen) gövde, dış çizgi, isteğe bağlı iç ikinci çizgi
## ve köşe elmasları. StyleBoxFlat'in yerine panellerde, düğmelerde ve pencerelerde kullanılır.

@export var bg_color := Color("0e0e13")
@export var border_color := Color("d4af37")
@export var inner_color := Color(0, 0, 0, 0)   ## iç çizgi rengi (alfa 0 ise çizilmez)
@export var border_width := 1.5
@export var chamfer := 8.0
@export var inner_gap := 4.0
@export var ornaments := false                  ## köşelerde küçük elmaslar
@export var draw_center := true
@export var shadow_size := 0
@export var shadow_color := Color(0, 0, 0, 0.5)
@export var shadow_offset := Vector2(0, 3)

static func oct(r: Rect2, c: float) -> PackedVector2Array:
	c = clampf(c, 0.0, minf(r.size.x, r.size.y) * 0.45)
	var x := r.position.x
	var y := r.position.y
	var w := r.size.x
	var h := r.size.y
	return PackedVector2Array([
		Vector2(x + c, y), Vector2(x + w - c, y), Vector2(x + w, y + c), Vector2(x + w, y + h - c),
		Vector2(x + w - c, y + h), Vector2(x + c, y + h), Vector2(x, y + h - c), Vector2(x, y + c)])

static func closed(p: PackedVector2Array) -> PackedVector2Array:
	var q := p.duplicate()
	q.append(p[0])
	return q

static func diamond(c: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])

func _draw(ci: RID, rect: Rect2) -> void:
	if rect.size.x < 2 or rect.size.y < 2:
		return
	var RS := RenderingServer
	if shadow_size > 0:
		var sr := rect.grow(shadow_size * 0.35)
		sr.position += shadow_offset
		RS.canvas_item_add_polygon(ci, oct(sr, chamfer + shadow_size * 0.3), PackedColorArray([shadow_color]))
	var pts := oct(rect, chamfer)
	if draw_center and bg_color.a > 0:
		RS.canvas_item_add_polygon(ci, pts, PackedColorArray([bg_color]))
	if border_width > 0 and border_color.a > 0:
		RS.canvas_item_add_polyline(ci, closed(pts), PackedColorArray([border_color]), border_width, true)
	if inner_color.a > 0 and inner_gap > 0:
		var ir := rect.grow(-inner_gap)
		if ir.size.x > 4 and ir.size.y > 4:
			RS.canvas_item_add_polyline(ci, closed(oct(ir, maxf(0, chamfer - inner_gap * 0.6))), PackedColorArray([inner_color]), 1.0, true)
	if ornaments:
		var d := clampf(chamfer * 0.45, 2.5, 6.0)
		var g := chamfer * 0.5
		for c in [rect.position + Vector2(g, g), Vector2(rect.end.x - g, rect.position.y + g), rect.end - Vector2(g, g), Vector2(rect.position.x + g, rect.end.y - g)]:
			RS.canvas_item_add_polygon(ci, diamond(c, d), PackedColorArray([border_color]))
