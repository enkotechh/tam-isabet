class_name CardView
extends Control
## Art Deco kart: köşeleri kesik oniks gövde, nadirlik renginde dış çizgi + altın iç çizgi,
## güneş ışınlı kemerli resim penceresi, elmas değer taşı, altın çizgili isim bandı ve fildişi açıklama.
## Üç katman: bu düğüm (gövde, ışınlar, kemer) → ikon (TextureRect) → üst katman (sayı, taşlar, yazılar).

signal pressed(view: CardView)

var card: Dictionary = {}       ## kart örneği {uid, tid, value, color} ya da sadece {tid}
var charm_id := ""
var charm_state: Dictionary = {}
var perk: Dictionary = {}       ## {title, icon, text}
var mini := false
var selected := false
var locked := false
var boosted := false
var dimmed := false
var card_w := 84.0

var _icon: TextureRect
var _over: Overlay

class Overlay extends Control:
	var cv: CardView
	func _draw() -> void:
		cv.draw_overlay(self)

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_over = Overlay.new()
	_over.cv = self
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_over)
	set_width(card_w)

func set_width(w: float) -> void:
	card_w = w
	custom_minimum_size = Vector2(w, roundf(w * 1.4))
	size = custom_minimum_size
	pivot_offset = size / 2
	_over.size = size
	queue_redraw()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(self)
		accept_event()

func uid() -> int:
	return int(card.get("uid", -1))

func _t() -> Dictionary:
	return Data.CARD.get(card.get("tid", ""), {})

func rarity() -> String:
	if charm_id != "":
		return Data.CHARM[charm_id].rarity
	if not perk.is_empty():
		return "rare"
	return _t().get("rarity", "common")

func _cls() -> String:
	if charm_id != "":
		return "charm"
	if not perk.is_empty():
		return "pyro" if perk.get("icon", "") == "heart" else "guard"
	return _t().get("cls", "neutral")

func display_name() -> String:
	if locked:
		return "Kilitli"
	if charm_id != "":
		return Data.CHARM[charm_id].name
	if not perk.is_empty():
		return perk.title
	var t := _t()
	if t.get("is_number", false):
		return Data.card_name(t.id, card.get("color", t.color), int(card.get("value", t.value)))
	return t.get("name", "")

func description() -> String:
	if locked:
		return "%s kart. Oynadıkça açılır." % Data.RARITY[rarity()].name
	if charm_id != "":
		var s: String = Data.CHARM[charm_id].text
		if int(charm_state.get("m", 0)) > 0:
			s += " (+%d)" % int(charm_state.m)
		return s
	if not perk.is_empty():
		return perk.text
	return _t().get("text", "")

func _value() -> int:
	return int(card.get("value", _t().get("value", 0)))

func _color() -> String:
	return str(card.get("color", _t().get("color", "")))

func _gem_text() -> String:
	if locked:
		return "?"
	if charm_id != "":
		return "✧"
	if not perk.is_empty():
		return "+1"
	var t := _t()
	if t.kind == "num" or (card.has("uid") and (t.has("roll") or t.has("dyn"))):
		return str(_value())
	if t.has("gem"):
		return t.gem
	return "✦" if t.kind == "spell" else ""

func _gem_color() -> Color:
	if locked:
		return Color("4a4752")
	if charm_id != "":
		return Color("2b2140")
	if not perk.is_empty():
		return Color("8a6a12")
	var t := _t()
	match t.kind:
		"num":
			var c := _color()
			return Color("7d45c9") if c == "rainbow" else Data.SUITS[c].gem
		"spell":
			return Color("6c2fa8")
		"curse":
			return Color("4a4752")
	return Color("1f5f99")

## Kartın ölçüleri: gövde, kemer (resim penceresi) ve ikon merkezi
func _geom() -> Dictionary:
	var w := size.x
	var h := size.y
	var body := Rect2(Vector2(w * 0.06, w * 0.06), size - Vector2(w * 0.12, w * 0.12))
	var aw := w * (0.36 if mini else 0.31)              ## kemer yarı genişliği
	var ah := w * (0.86 if mini else 0.66)              ## kemer yüksekliği
	var top := (h - ah) / 2.0 if mini else body.position.y + w * 0.08
	var arch_c := Vector2(w / 2, top + aw)              ## kemer yayının merkezi
	var bottom := top + ah
	var center := Vector2(w / 2, (top + bottom) / 2 + aw * 0.08)   ## ikon merkezi
	return {"w": w, "h": h, "body": body, "aw": aw, "top": top, "bottom": bottom, "arch_c": arch_c,
		"center": center, "R": aw * 0.92, "c": w * 0.09}

func _arch(g: Dictionary, inset := 0.0) -> PackedVector2Array:
	var aw: float = g.aw - inset
	var ac: Vector2 = g.arch_c
	var pts := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		pts.append(ac + Vector2(cos(a), sin(a)) * aw)
	pts.append(Vector2(ac.x + aw, g.bottom - inset))
	pts.append(Vector2(ac.x - aw, g.bottom - inset))
	return pts

static func _text(ci: CanvasItem, font: Font, pos: Vector2, s: String, fsize: int, col: Color, width := -1.0, outline := 0) -> void:
	if outline > 0:
		ci.draw_string_outline(font, pos, s, HORIZONTAL_ALIGNMENT_CENTER, width, fsize, outline, UIKit.OUTLINE)
	ci.draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_CENTER, width, fsize, col)

# Alt katman: parıltı, gövde, çizgiler, güneş ışınları, kemer, yelpazeler
func _draw() -> void:
	var g := _geom()
	var w: float = g.w
	var c: float = g.c
	var rc: Color = Data.RARITY[rarity()].color
	var cc: Array = Data.CLASS_COLORS.get(_cls(), Data.CLASS_COLORS.neutral)
	var full := Rect2(Vector2.ZERO, size)
	var outer := DecoBox.oct(full, c)

	# parıltı (seçili: altın, epik: kırmızı)
	if selected or rarity() == "epic":
		var gc := UIKit.GOLD_3 if selected else Color("ff3b3b")
		draw_polyline(DecoBox.closed(DecoBox.oct(full.grow(4), c + 2)), Color(gc, 0.25), 8.0, true)
		draw_polyline(DecoBox.closed(DecoBox.oct(full.grow(2), c + 1)), Color(gc, 0.9), 2.0, true)

	# gölge ve gövde
	draw_colored_polygon(DecoBox.oct(Rect2(Vector2(1, 4), size), c), Color(0, 0, 0, 0.5))
	draw_colored_polygon(outer, Color("0b0b0f").lerp(cc[1], 0.45))
	var body: Rect2 = g.body
	draw_colored_polygon(DecoBox.oct(body, c * 0.7), Color("101015").lerp(cc[1], 0.3))

	# güneş ışınları (kemerin arkasında, gövde içinde)
	var ac: Vector2 = g.arch_c
	var ray_len := w * 0.6
	var n := 18
	for i in n:
		if i % 2 == 1:
			continue
		var a0 := PI + PI * i / n - 0.02
		var a1 := PI + PI * (i + 1) / n + 0.02
		var p0: Vector2 = _clamp_to(body, ac + Vector2(cos(a0), sin(a0)) * ray_len)
		var p1: Vector2 = _clamp_to(body, ac + Vector2(cos(a1), sin(a1)) * ray_len)
		draw_colored_polygon(PackedVector2Array([ac, p0, p1]), Color(rc, 0.13))

	# çizgiler: dış (nadirlik rengi) + iç (altın)
	draw_polyline(DecoBox.closed(outer), rc, maxf(1.5, w * 0.022), true)
	draw_polyline(DecoBox.closed(DecoBox.oct(full.grow(-w * 0.035), c * 0.75)), Color(UIKit.GOLD_2, 0.85), 1.0, true)

	# kemerli resim penceresi
	var arch := _arch(g)
	draw_colored_polygon(_arch(g, -w * 0.02), Color("050507"))
	draw_colored_polygon(arch, cc[0].darkened(0.55))
	draw_circle(g.center + Vector2(0, -g.aw * 0.2), g.aw * 0.55, Color(cc[0], 0.25))
	draw_polyline(DecoBox.closed(arch), UIKit.GOLD_2, maxf(1.0, w * 0.014), true)
	draw_polyline(DecoBox.closed(_arch(g, w * 0.03)), Color(rc, 0.7), 1.0, true)

	if not mini:
		# kemerin altında basamaklı süs
		var by: float = g.bottom + w * 0.025
		var cx := w / 2
		var s := w * 0.045
		draw_polyline(PackedVector2Array([Vector2(cx - s * 3, by + s), Vector2(cx - s * 2, by + s), Vector2(cx - s * 2, by), Vector2(cx - s, by),
			Vector2(cx - s, by - s * 0.6), Vector2(cx + s, by - s * 0.6), Vector2(cx + s, by), Vector2(cx + s * 2, by), Vector2(cx + s * 2, by + s), Vector2(cx + s * 3, by + s)]),
			Color(UIKit.GOLD_2, 0.7), 1.0, true)
		# alt köşelerde yelpazeler
		for k in 2:
			var corner := Vector2(body.position.x + w * 0.01, body.end.y - w * 0.01) if k == 0 else Vector2(body.end.x - w * 0.01, body.end.y - w * 0.01)
			var a_start := -PI / 2 if k == 0 else PI
			for rr in [w * 0.06, w * 0.1, w * 0.14]:
				draw_arc(corner, rr, a_start, a_start + PI / 2, 10, Color(UIKit.GOLD_2, 0.45), 1.0, true)

	# efsanevi/epik: üstte yarım güneş arması
	if rarity() in ["legendary", "epic"]:
		var tc := Vector2(w / 2, 0)
		draw_circle(tc, w * 0.13, Color("0b0b0f"))
		for i in 9:
			var a := PI + PI * (i + 0.5) / 9.0
			draw_line(tc + Vector2(cos(a), sin(a)) * w * 0.05, tc + Vector2(cos(a), sin(a)) * w * 0.13, rc, 1.5, true)
		draw_arc(tc, w * 0.13, PI, TAU, 16, rc, 1.5, true)
		draw_circle(tc, w * 0.04, rc)
	_sync_icon.call_deferred()
	_over.queue_redraw()

static func _clamp_to(r: Rect2, p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))

# Orta katman: kemerdeki ikon
func _sync_icon() -> void:
	var g := _geom()
	var R: float = g.R
	var center: Vector2 = g.center
	var t := _t()
	var name := ""
	var col := UIKit.GOLD_3
	var s := R * 1.15
	if locked:
		name = "lock"
		s = R
		col = Color(1, 1, 1, 0.55)
	elif charm_id != "":
		name = Data.CHARM[charm_id].icon
		col = Data.RARITY[rarity()].color.lightened(0.25)
	elif not perk.is_empty():
		name = perk.icon
		s = R * 1.1
	elif t.get("is_number", false):
		name = "suit_" + _color()
		col = Data.SUITS[_color()].color
		s = R * 1.5
	elif not t.has("glyph"):
		name = t.get("icon", "star")
	_icon.visible = name != ""
	if name != "":
		_icon.texture = Data.icon(name)
		_icon.modulate = col
		_icon.size = Vector2(s, s)
		_icon.position = center - Vector2(s, s) / 2

# Üst katman: sayı/simge yazısı, taşlar, isim bandı, açıklama
func draw_overlay(ci: CanvasItem) -> void:
	var g := _geom()
	var w: float = g.w
	var R: float = g.R
	var center: Vector2 = g.center
	var body: Rect2 = g.body
	var rc: Color = Data.RARITY[rarity()].color
	var t := _t()

	if not locked and charm_id == "" and perk.is_empty():
		if t.get("is_number", false):
			var fs := int(R * 1.1)
			_text(ci, UIKit.title_font(), Vector2(center.x - R, center.y + fs * 0.36), str(_value()), fs, Color.WHITE, R * 2, maxi(2, int(w * 0.05)))
		elif t.has("glyph"):
			var fs := int(R * (0.8 if t.glyph.length() > 2 else 0.98))
			_text(ci, UIKit.title_font(), Vector2(center.x - R, center.y + fs * 0.36), t.glyph, fs, UIKit.GOLD_3, R * 2, maxi(2, int(w * 0.04)))

	# nadirlik elması (kemerin dibinde)
	var dp := Vector2(w / 2, g.bottom)
	var dg := w * 0.05
	ci.draw_colored_polygon(DecoBox.diamond(dp, dg + 1.5), UIKit.OUTLINE)
	ci.draw_colored_polygon(DecoBox.diamond(dp, dg), rc)
	ci.draw_colored_polygon(DecoBox.diamond(dp + Vector2(0, -dg * 0.3), dg * 0.35), Color(1, 1, 1, 0.45))

	# değer elması (sol üst)
	var gc := Vector2(w * 0.15, w * 0.15)
	var gr := w * 0.16
	ci.draw_colored_polygon(DecoBox.diamond(gc + Vector2(1, 2), gr + 2), Color(0, 0, 0, 0.6))
	ci.draw_colored_polygon(DecoBox.diamond(gc, gr + 1.5), UIKit.OUTLINE)
	ci.draw_colored_polygon(DecoBox.diamond(gc, gr), UIKit.GOLD_2)
	ci.draw_colored_polygon(DecoBox.diamond(gc, gr * 0.78), _gem_color())
	ci.draw_polyline(DecoBox.closed(DecoBox.diamond(gc, gr * 0.62)), Color(UIKit.GOLD_3, 0.5), 1.0, true)
	var gt := _gem_text()
	var gfs := int(gr * (0.82 if gt.length() <= 2 else 0.6))
	_text(ci, UIKit.title_font(), Vector2(gc.x - gr, gc.y + gfs * 0.38), gt, gfs, Color.WHITE, gr * 2, 3)

	if boosted:
		var bt := Rect2(Vector2(w * 0.66, -w * 0.06), Vector2(w * 0.38, w * 0.2))
		UIKit.box(UIKit.GOLD_2, 6, 1, UIKit.OUTLINE).draw(ci.get_canvas_item(), bt)
		_text(ci, UIKit.title_font(), Vector2(bt.position.x, bt.position.y + bt.size.y * 0.76), "×2", int(w * 0.13), Color("120e05"), bt.size.x)

	if not mini:
		# isim bandı
		var ny: float = g.bottom + w * 0.1
		var np := Rect2(Vector2(body.position.x, ny), Vector2(body.size.x, w * 0.15))
		ci.draw_rect(np, Color("070709"))
		ci.draw_line(np.position, Vector2(np.end.x, np.position.y), UIKit.GOLD_2, 1.0, true)
		ci.draw_line(Vector2(np.position.x, np.end.y), np.end, UIKit.GOLD_2, 1.0, true)
		ci.draw_colored_polygon(DecoBox.diamond(Vector2(np.position.x + w * 0.04, np.get_center().y), w * 0.025), UIKit.GOLD_2)
		ci.draw_colored_polygon(DecoBox.diamond(Vector2(np.end.x - w * 0.04, np.get_center().y), w * 0.025), UIKit.GOLD_2)
		var nfs := int(w * 0.072)
		_text(ci, UIKit.caps_font(), Vector2(np.position.x + w * 0.07, np.position.y + np.size.y * 0.5 + nfs * 0.36), UIKit.upper(display_name()), nfs, UIKit.GOLD_3, np.size.x - w * 0.14)
		# fildişi açıklama
		var ty := np.end.y + w * 0.04
		var tb := Rect2(Vector2(body.position.x + w * 0.05, ty), Vector2(body.size.x - w * 0.1, body.end.y - ty - w * 0.05))
		if tb.size.y > 8:
			var tp := DecoBox.oct(tb, w * 0.04)
			ci.draw_colored_polygon(tp, UIKit.PARCH)
			ci.draw_polyline(DecoBox.closed(tp), UIKit.GOLD_1, 1.0, true)
			var tfs := int(w * 0.076)
			var f := UIKit.bold_font()
			var pad := w * 0.035
			var ts := f.get_multiline_string_size(description(), HORIZONTAL_ALIGNMENT_CENTER, tb.size.x - pad * 2, tfs)
			var y0 := tb.position.y + maxf(pad, (tb.size.y - ts.y) / 2) + f.get_ascent(tfs)
			ci.draw_multiline_string(f, Vector2(tb.position.x + pad, y0), description(), HORIZONTAL_ALIGNMENT_CENTER, tb.size.x - pad * 2, tfs, 5, UIKit.PARCH_INK)

	if locked or dimmed:
		ci.draw_colored_polygon(DecoBox.oct(Rect2(Vector2.ZERO, size), g.c), Color(0, 0, 0, 0.6))
