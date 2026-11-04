class_name CardView
extends Control
## Tek bir kartı (ya da tılsımı / güçlendirmeyi) çizer: nadirlik renginde çerçeve, sınıf renginde gövde,
## oval resim penceresi, değer taşı, nadirlik taşı; tam boyda isim şeridi ve parşömen açıklama.
## Üç katman: bu düğüm (çerçeve, gövde, resim penceresi) → ikon (TextureRect) → üst katman (sayı, taşlar, yazılar).

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
		return Color("77737d")
	if charm_id != "":
		return Color("3b2d55")
	if not perk.is_empty():
		return Color("d29a1c")
	var t := _t()
	match t.kind:
		"num":
			var c := _color()
			return Color("b766ff") if c == "rainbow" else Data.SUITS[c].gem
		"spell":
			return Color("9a44d6")
		"curse":
			return Color("77737d")
	return Color("2a7fbf")

## Kartın ölçüleri: gövde dikdörtgeni, resim merkezi ve yarıçapı
func _geom() -> Dictionary:
	var w := size.x
	var h := size.y
	var inset := w * 0.05
	var body := Rect2(Vector2(inset, inset), size - Vector2(inset * 2, inset * 2))
	var R := w * (0.38 if mini else 0.30)
	var center := Vector2(w / 2, h * 0.5 if mini else body.position.y + w * 0.08 + R)
	return {"w": w, "h": h, "body": body, "R": R, "center": center, "r": w * 0.09}

static func _hex(center: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		var a := deg_to_rad(60.0 * i - 90.0)
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts

static func _text(ci: CanvasItem, font: Font, pos: Vector2, s: String, fsize: int, col: Color, width := -1.0, outline := 0) -> void:
	if outline > 0:
		ci.draw_string_outline(font, pos, s, HORIZONTAL_ALIGNMENT_CENTER, width, fsize, outline, UIKit.OUTLINE)
	ci.draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_CENTER, width, fsize, col)

# Alt katman: parıltı, çerçeve, gövde, resim penceresi
func _draw() -> void:
	var g := _geom()
	var w: float = g.w
	var r: float = g.r
	var rc: Color = Data.RARITY[rarity()].color
	var cc: Array = Data.CLASS_COLORS.get(_cls(), Data.CLASS_COLORS.neutral)

	if selected or rarity() == "epic":
		var glow := UIKit.box(Color(0, 0, 0, 0), int(r * 1.4))
		glow.draw_center = false
		glow.shadow_size = int(w * 0.16)
		glow.shadow_color = (UIKit.GOLD_2 if selected else Color("ff3b3b")) * Color(1, 1, 1, 0.75)
		glow.shadow_offset = Vector2.ZERO
		glow.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))

	UIKit.box(rc, int(r), maxi(1, int(w * 0.022)), rc.darkened(0.6), int(w * 0.07)).draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
	var hi := UIKit.box(Color(0, 0, 0, 0), int(r * 0.9), maxi(1, int(w * 0.012)), rc.lightened(0.55))
	hi.draw_center = false
	hi.draw(get_canvas_item(), Rect2(Vector2(w * 0.02, w * 0.02), size - Vector2(w * 0.04, w * 0.04)))

	var body: Rect2 = g.body
	UIKit.box(cc[1], int(r * 0.7), 1, UIKit.OUTLINE).draw(get_canvas_item(), body)
	var top := body.position + Vector2(r * 0.5, r * 0.5)
	var gw := body.size.x - r
	draw_polygon(PackedVector2Array([top, top + Vector2(gw, 0), top + Vector2(gw, body.size.y * 0.5), top + Vector2(0, body.size.y * 0.5)]),
		PackedColorArray([cc[0], cc[0], Color(cc[1], 0), Color(cc[1], 0)]))

	var R: float = g.R
	var center: Vector2 = g.center
	draw_circle(center, R + w * 0.035, UIKit.OUTLINE)
	draw_circle(center, R + w * 0.02, rc)
	draw_circle(center, R, cc[1].darkened(0.25))
	draw_circle(center, R * 0.9, cc[0].darkened(0.15))
	draw_circle(center + Vector2(0, -R * 0.38), R * 0.5, Color(1, 1, 1, 0.1))
	_sync_icon.call_deferred()
	_over.queue_redraw()

# Orta katman: resim penceresindeki ikon
func _sync_icon() -> void:
	var g := _geom()
	var R: float = g.R
	var center: Vector2 = g.center
	var t := _t()
	var name := ""
	var col := Color("fff6dc")
	var s := R * 1.15
	if locked:
		name = "lock"
		s = R
		col = Color(1, 1, 1, 0.7)
	elif charm_id != "":
		name = Data.CHARM[charm_id].icon
		col = Data.RARITY[rarity()].color.lightened(0.2)
	elif not perk.is_empty():
		name = perk.icon
		s = R * 1.1
	elif t.get("is_number", false):
		name = "suit_" + _color()
		col = Data.SUITS[_color()].color
		s = R * 1.45
	elif not t.has("glyph"):
		name = t.get("icon", "star")
	_icon.visible = name != ""
	if name != "":
		_icon.texture = Data.icon(name)
		_icon.modulate = col
		_icon.size = Vector2(s, s)
		_icon.position = center - Vector2(s, s) / 2

# Üst katman: sayı/simge yazısı, taşlar, isim şeridi, açıklama
func draw_overlay(ci: CanvasItem) -> void:
	var g := _geom()
	var w: float = g.w
	var r: float = g.r
	var R: float = g.R
	var center: Vector2 = g.center
	var body: Rect2 = g.body
	var rc: Color = Data.RARITY[rarity()].color
	var t := _t()
	var light := Color("fff6dc")

	if not locked and charm_id == "" and perk.is_empty():
		if t.get("is_number", false):
			var fs := int(R * 1.05)
			_text(ci, UIKit.title_font(), Vector2(center.x - R, center.y + fs * 0.36), str(_value()), fs, Color.WHITE, R * 2, maxi(2, int(w * 0.05)))
		elif t.has("glyph"):
			var fs := int(R * (0.8 if t.glyph.length() > 2 else 0.95))
			_text(ci, UIKit.title_font(), Vector2(center.x - R, center.y + fs * 0.36), t.glyph, fs, light, R * 2, maxi(2, int(w * 0.04)))

	# nadirlik taşı
	var dg := w * 0.065
	var dp := center + Vector2(0, R + w * 0.01)
	ci.draw_colored_polygon(PackedVector2Array([dp + Vector2(0, -dg - 1.5), dp + Vector2(dg + 1.5, 0), dp + Vector2(0, dg + 1.5), dp + Vector2(-dg - 1.5, 0)]), UIKit.OUTLINE)
	ci.draw_colored_polygon(PackedVector2Array([dp + Vector2(0, -dg), dp + Vector2(dg, 0), dp + Vector2(0, dg), dp + Vector2(-dg, 0)]), rc.lightened(0.15))

	# değer taşı
	var gc := Vector2(w * 0.11, w * 0.11)
	var gr := w * 0.175
	ci.draw_colored_polygon(_hex(gc, gr + 1.5), UIKit.OUTLINE)
	ci.draw_colored_polygon(_hex(gc, gr), UIKit.GOLD_3)
	ci.draw_colored_polygon(_hex(gc, gr * 0.8), _gem_color())
	ci.draw_colored_polygon(_hex(gc + Vector2(-gr * 0.15, -gr * 0.2), gr * 0.35), Color(1, 1, 1, 0.18))
	var gt := _gem_text()
	var gfs := int(gr * (0.95 if gt.length() <= 2 else 0.75))
	_text(ci, UIKit.title_font(), Vector2(gc.x - gr, gc.y + gfs * 0.36), gt, gfs, Color.WHITE, gr * 2, 3)

	if boosted:
		var bt := Rect2(Vector2(w * 0.68, -w * 0.05), Vector2(w * 0.36, w * 0.2))
		UIKit.box(UIKit.GOLD_2, 4, 1, UIKit.OUTLINE).draw(ci.get_canvas_item(), bt)
		_text(ci, UIKit.bold_font(), Vector2(bt.position.x, bt.position.y + bt.size.y * 0.75), "×2", int(w * 0.13), Color("3a2306"), bt.size.x)

	if not mini:
		var ny := center.y + R + w * 0.1
		var np := Rect2(Vector2(body.position.x - w * 0.01, ny), Vector2(body.size.x + w * 0.02, w * 0.15))
		UIKit.box(Color("5a3a20"), 3, 1, UIKit.GOLD_1).draw(ci.get_canvas_item(), np)
		var nfs := int(w * 0.085)
		_text(ci, UIKit.title_font(), Vector2(np.position.x, np.position.y + np.size.y * 0.5 + nfs * 0.36), display_name(), nfs, Color("fff4d6"), np.size.x, 2)
		var ty := np.end.y + w * 0.04
		var tb := Rect2(Vector2(body.position.x + w * 0.04, ty), Vector2(body.size.x - w * 0.08, body.end.y - ty - w * 0.04))
		if tb.size.y > 8:
			UIKit.box(UIKit.PARCH, int(w * 0.05)).draw(ci.get_canvas_item(), tb)
			var tfs := int(w * 0.078)
			var f := UIKit.bold_font()
			var pad := w * 0.03
			var ts := f.get_multiline_string_size(description(), HORIZONTAL_ALIGNMENT_CENTER, tb.size.x - pad * 2, tfs)
			var y0 := tb.position.y + maxf(pad, (tb.size.y - ts.y) / 2) + f.get_ascent(tfs)
			ci.draw_multiline_string(f, Vector2(tb.position.x + pad, y0), description(), HORIZONTAL_ALIGNMENT_CENTER, tb.size.x - pad * 2, tfs, 5, UIKit.PARCH_INK)

	if locked or dimmed:
		UIKit.box(Color(0, 0, 0, 0.55), int(r)).draw(ci.get_canvas_item(), Rect2(Vector2.ZERO, size))
