class_name UIKit
extends RefCounted
## Ortak görünüm: Dark Deco paleti (gece siyahı, eskimiş altın, bordo, sis grisi), yazı tipleri
## (Limelight, Poiret One, Josefin Sans — OFL) ve düğme/panel/etiket üreticileri.

# Sabit adları eski sürümle aynı tutuldu; değerler Dark Deco paletine göre
# (hikâye belgesi: siyah #07080C, altın #C9A24A, bordo #5A141C, sis grisi #3B4252).
const WOOD_0 := Color("030407")    ## en koyu zemin
const WOOD_1 := Color("07080c")    ## ana zemin (gece siyahı)
const WOOD_2 := Color("0e1018")
const WOOD_3 := Color("1b1e2a")
const GOLD_0 := Color("5e4a1f")    ## koyu altın
const GOLD_1 := Color("9a7b35")
const GOLD_2 := Color("c9a24a")    ## eskimiş altın
const GOLD_3 := Color("ecd49a")    ## açık altın
const PARCH := Color("e6d9bb")     ## fildişi
const PARCH_INK := Color("1a1712")
const INK := Color("ece2c8")
const MUTED := Color("9c978e")
const HIT := Color("4fd1a1")       ## yeşim
const MISS := Color("e0564f")
const HEART := Color("c8344a")
const CHIPS := Color("2a3350")     ## gece mavisi
const MULT := Color("6e1822")      ## bordo
const SPELL := Color("9d6bd8")
const BORDO := Color("5a141c")
const FOG := Color("3b4252")       ## sis grisi
const SKY_TOP := Color("120b22")   ## gece göğü (mor)
const SKY_GLOW := Color("3a1226")  ## ufuktaki kızıl-mor ışık
const WINDOW := Color("f2c46a")    ## ışıklı pencere
const OUTLINE := Color("000000")

const FONT_TITLE := "res://assets/fonts/Limelight-Regular.ttf"
const FONT_DECO := "res://assets/fonts/PoiretOne-Regular.ttf"
const FONT_BODY := "res://assets/fonts/JosefinSans.ttf"

static var _title: Font
static var _deco: Font
static var _body: Font
static var _bold: Font
static var _caps: Font

static func _font(path: String, fallback: Array, weight: int, wght := 0, spacing := 0) -> Font:
	if ResourceLoader.exists(path):
		var base: Font = load(path)
		if wght == 0 and spacing == 0:
			return base
		var v := FontVariation.new()
		v.base_font = base
		if wght > 0:
			v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): wght}
		if spacing != 0:
			v.spacing_glyph = spacing
		return v
	var s := SystemFont.new()
	s.font_names = PackedStringArray(fallback)
	s.font_weight = weight
	return s

## Başlıklar ve düğmeler: Limelight
static func title_font() -> Font:
	if _title == null:
		_title = _font(FONT_TITLE, ["Georgia", "serif"], 700)
	return _title

## İnce süslü yazılar (alt başlık, slogan): Poiret One
static func deco_font() -> Font:
	if _deco == null:
		_deco = _font(FONT_DECO, ["Georgia", "serif"], 400, 0, 1)
	return _deco

## Gövde metni: Josefin Sans
static func body_font() -> Font:
	if _body == null:
		_body = _font(FONT_BODY, ["Avenir Next", "Segoe UI", "Arial", "sans-serif"], 500, 500)
	return _body

static func bold_font() -> Font:
	if _bold == null:
		_bold = _font(FONT_BODY, ["Avenir Next", "Segoe UI", "Arial", "sans-serif"], 700, 700)
	return _bold

## Aralıklı büyük harf etiketleri
static func caps_font() -> Font:
	if _caps == null:
		_caps = _font(FONT_BODY, ["Avenir Next", "Segoe UI", "Arial", "sans-serif"], 700, 700, 2)
	return _caps

static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 16
	t.set_color("font_color", "Label", INK)
	t.set_color("default_color", "RichTextLabel", INK)
	t.set_font("bold_font", "RichTextLabel", bold_font())
	return t

## Köşeleri kesik Art Deco kutu. radius, kesik köşe boyutuna çevrilir.
static func box(bg: Color, radius := 12, border := 0, border_col := GOLD_0, shadow := 0) -> DecoBox:
	var s := DecoBox.new()
	s.bg_color = bg
	s.chamfer = clampf(radius * 0.6, 0.0, 12.0)
	s.border_width = float(border)
	s.border_color = border_col
	s.shadow_size = shadow
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

## Çift altın çizgili, köşe elmaslı süs kutusu (pencereler, arena)
static func frame(bg := WOOD_1, line := GOLD_2, chamfer := 12.0, ornaments := true) -> DecoBox:
	var s := DecoBox.new()
	s.bg_color = bg
	s.border_color = line
	s.border_width = 1.5
	s.inner_color = Color(line, 0.55)
	s.inner_gap = 5.0
	s.chamfer = chamfer
	s.ornaments = ornaments
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s

static func label(text: String, size := 16, color := INK, font: Font = null, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	l.horizontal_alignment = align
	return l

static func title(text: String, size := 22, color := GOLD_3) -> Label:
	var l := label(text, size, color, title_font())
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", 6)
	return l

static func wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 10
	return l

static func rich(bbcode: String, size := 15, color := INK) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_color_override("default_color", color)
	r.text = bbcode
	return r

## Art Deco düğme: siyah gövde + altın çift çizgi, ya da dolu altın
static func button(text: String, gold := false, small := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", title_font())
	b.add_theme_font_size_override("font_size", 13 if small else 16)
	var bg := GOLD_2 if gold else WOOD_2
	var fc := Color("120e05") if gold else GOLD_3
	var normal := frame(bg, GOLD_3 if gold else GOLD_2, 7.0 if small else 10.0, false)
	normal.inner_color = Color(GOLD_0, 0.9) if gold else Color(GOLD_1, 0.6)
	normal.inner_gap = 3.0 if small else 4.0
	normal.shadow_size = 4
	normal.content_margin_top = 8 if small else 13
	normal.content_margin_bottom = 7 if small else 12
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	var hover: DecoBox = normal.duplicate()
	hover.bg_color = bg.lightened(0.12)
	var pressed: DecoBox = normal.duplicate()
	pressed.bg_color = bg.darkened(0.15)
	pressed.shadow_size = 0
	var disabled: DecoBox = normal.duplicate()
	disabled.bg_color = WOOD_1
	disabled.border_color = Color("4a4538")
	disabled.inner_color = Color(0, 0, 0, 0)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", fc)
	b.add_theme_color_override("font_hover_color", fc)
	b.add_theme_color_override("font_pressed_color", fc)
	b.add_theme_color_override("font_disabled_color", Color("6a6352"))
	b.pressed.connect(func(): Sfx.play("click"))
	return b

static func panel(bg := Color(0, 0, 0, 0.5), radius := 14, border := 0, border_col := GOLD_0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, radius, border, border_col))
	return p

## Ortası elmaslı yatay süs çizgisi
static func divider(width := 220.0, color := GOLD_2) -> Control:
	var d := DecoDivider.new()
	d.custom_minimum_size = Vector2(width, 14)
	d.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	d.color = color
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return d

class DecoDivider extends Control:
	var color := Color("d4af37")
	func _draw() -> void:
		var c := size / 2
		var w := size.x
		draw_line(Vector2(0, c.y - 2), Vector2(c.x - 12, c.y - 2), color, 1.0, true)
		draw_line(Vector2(0, c.y + 2), Vector2(c.x - 12, c.y + 2), Color(color, 0.5), 1.0, true)
		draw_line(Vector2(c.x + 12, c.y - 2), Vector2(w, c.y - 2), color, 1.0, true)
		draw_line(Vector2(c.x + 12, c.y + 2), Vector2(w, c.y + 2), Color(color, 0.5), 1.0, true)
		draw_colored_polygon(DecoBox.diamond(c, 6), color)
		draw_colored_polygon(DecoBox.diamond(c, 2.5), Color("0d0d12"))
		draw_colored_polygon(DecoBox.diamond(Vector2(c.x - 18, c.y), 2.5), color)
		draw_colored_polygon(DecoBox.diamond(Vector2(c.x + 18, c.y), 2.5), color)

static func vbox(sep := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func hbox(sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func icon_rect(name: String, size := 24, color := INK) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Data.icon(name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size)
	t.modulate = color
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

static func fmt_mult(m: float) -> String:
	return RunState.fmt_mult(m)

## Türkçe büyük harf: i → İ, ı → I (Godot'nun to_upper'ı dil bilmez)
static func upper(s: String) -> String:
	return s.replace("i", "İ").replace("ı", "I").to_upper()
