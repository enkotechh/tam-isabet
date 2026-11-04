class_name UIKit
extends RefCounted
## Ortak görünüm: renk paleti, yazı tipleri ve düğme/panel/etiket üreticileri (fantastik meyhane stili).

const WOOD_0 := Color("140c07")
const WOOD_1 := Color("22160d")
const WOOD_2 := Color("37241a")
const WOOD_3 := Color("5d3d22")
const GOLD_0 := Color("6e4a1a")
const GOLD_1 := Color("b98a3a")
const GOLD_2 := Color("e2b35a")
const GOLD_3 := Color("ffe7a3")
const PARCH := Color("e8d6ab")
const PARCH_INK := Color("3a2814")
const INK := Color("f3ead7")
const MUTED := Color("c2b194")
const HIT := Color("6be0a4")
const MISS := Color("ff6b5b")
const HEART := Color("ff4d6a")
const CHIPS := Color("2f6fd6")
const MULT := Color("d23b2f")
const SPELL := Color("b77bff")
const OUTLINE := Color("120a05")

static var _title: Font
static var _body: Font
static var _bold: Font

static func title_font() -> Font:
	if _title == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Cinzel", "Trajan Pro", "Georgia", "Times New Roman", "serif"])
		f.font_weight = 700
		_title = f
	return _title

static func body_font() -> Font:
	if _body == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Alegreya Sans", "Avenir Next", "Segoe UI", "Helvetica Neue", "Arial", "sans-serif"])
		f.font_weight = 500
		_body = f
	return _body

static func bold_font() -> Font:
	if _bold == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Alegreya Sans", "Avenir Next", "Segoe UI", "Helvetica Neue", "Arial", "sans-serif"])
		f.font_weight = 800
		_bold = f
	return _bold

static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 16
	t.set_color("font_color", "Label", INK)
	t.set_color("default_color", "RichTextLabel", INK)
	t.set_font("bold_font", "RichTextLabel", bold_font())
	return t

static func box(bg: Color, radius := 12, border := 0, border_col := GOLD_0, shadow := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if border > 0:
		s.set_border_width_all(border)
		s.border_color = border_col
	if shadow > 0:
		s.shadow_size = shadow
		s.shadow_color = Color(0, 0, 0, 0.45)
		s.shadow_offset = Vector2(0, 3)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.anti_aliasing = true
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

## Ahşap ya da altın plaket düğme
static func button(text: String, gold := false, small := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", title_font())
	b.add_theme_font_size_override("font_size", 14 if small else 17)
	var bg := Color("e2b35a") if gold else Color("4f331d")
	var fc := Color("3a2306") if gold else INK
	var normal := box(bg, 11 if small else 13, 2, GOLD_0, 5)
	normal.content_margin_top = 8 if small else 13
	normal.content_margin_bottom = 8 if small else 13
	var hover := normal.duplicate()
	hover.bg_color = bg.lightened(0.12)
	var pressed := normal.duplicate()
	pressed.bg_color = bg.darkened(0.12)
	pressed.shadow_size = 1
	var disabled := normal.duplicate()
	disabled.bg_color = Color("3a3530")
	disabled.border_color = Color("4a4038")
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", fc)
	b.add_theme_color_override("font_hover_color", fc)
	b.add_theme_color_override("font_pressed_color", fc)
	b.add_theme_color_override("font_disabled_color", Color("8a8070"))
	return b

static func panel(bg := Color(0, 0, 0, 0.38), radius := 14, border := 0, border_col := GOLD_0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, radius, border, border_col))
	return p

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
