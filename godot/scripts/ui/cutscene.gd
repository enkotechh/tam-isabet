class_name Cutscene
extends Control
## Hikâye ara sahnesi: kodla çizilen Dark Deco görüntüler, yavaş yakınlaşma, yağmur,
## film greni, harf harf beliren altyazı ve "Atla" düğmesi.
## Kullanım: var cs := Cutscene.new(); add_child(cs); await cs.play(scenes, "Başlık")
## scenes: [{art, text, caption?}] (Data.STORY biçimi). Dokunmak altyazıyı tamamlar / sonraki sahneye geçer.

signal advanced
signal done

const CHARS_PER_SEC := 34.0
const HOLD_SEC := 2.4        ## altyazı tamamlandıktan sonra kendiliğinden geçme süresi

var art: SceneArt
var fade: ColorRect
var sub: Label
var cap: Label
var head: Label
var skip_btn: Button
var skipping := false
var typing := false
var token := 0               ## eski sahnenin zamanlayıcısı yenisini geçirmesin

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	art = SceneArt.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	# altyazı için alt kısımda koyulaşan şerit
	var shade := ShadeBand.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	head = UIKit.title("", 24, UIKit.GOLD_3)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	head.offset_top = 70
	head.offset_bottom = 110
	head.modulate.a = 0
	add_child(head)

	cap = UIKit.label("", 15, UIKit.GOLD_2, UIKit.caps_font(), HORIZONTAL_ALIGNMENT_CENTER)
	cap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	cap.offset_top = -250
	cap.offset_bottom = -222
	add_child(cap)

	sub = UIKit.wrap(UIKit.label("", 20, UIKit.INK, UIKit.deco_font(), HORIZONTAL_ALIGNMENT_CENTER))
	sub.add_theme_color_override("font_outline_color", Color.BLACK)
	sub.add_theme_constant_override("outline_size", 5)
	sub.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	sub.offset_left = 28
	sub.offset_right = -28
	sub.offset_top = -210
	sub.offset_bottom = -70
	sub.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	add_child(sub)

	skip_btn = UIKit.button("Atla", false, true)
	skip_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	skip_btn.offset_left = -96
	skip_btn.offset_right = -16
	skip_btn.offset_top = 22
	skip_btn.offset_bottom = 58
	skip_btn.pressed.connect(func():
		skipping = true
		advanced.emit())
	add_child(skip_btn)

	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)

func _gui_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
		if typing:
			typing = false
			sub.visible_ratio = 1.0
		else:
			advanced.emit()
		accept_event()

## Sahneleri sırayla oynatır. title: başta beliren bölüm adı (boşsa gösterilmez)
func play(scenes: Array, title := "") -> void:
	if title != "":
		head.text = title
		var ht := create_tween()
		ht.tween_property(head, "modulate:a", 1.0, 0.8)
	for s in scenes:
		if skipping:
			break
		await _scene(s)
	var t := create_tween()
	t.tween_property(fade, "color:a", 1.0, 0.5)
	await t.finished
	done.emit()

func _scene(s: Dictionary) -> void:
	art.kind = String(s.get("art", "skyline"))
	art.t = 0.0
	art.scale = Vector2.ONE
	art.pivot_offset = get_viewport_rect().size * Vector2(0.5, 0.45)
	cap.text = UIKit.upper(String(s.get("caption", "")))
	sub.text = String(s.get("text", ""))
	sub.visible_ratio = 0.0
	# kararmadan açılış + yavaş yakınlaşma
	var zoom := create_tween()
	zoom.tween_property(art, "scale", Vector2(1.12, 1.12), 9.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var fin := create_tween()
	fin.tween_property(fade, "color:a", 0.0, 0.7)
	await fin.finished
	if skipping:
		return
	# altyazı harf harf
	typing = true
	var dur := maxf(0.6, sub.text.length() / CHARS_PER_SEC)
	var tt := create_tween()
	tt.tween_property(sub, "visible_ratio", 1.0, dur)
	tt.finished.connect(func(): typing = false)
	# dokunuşla ya da süre dolunca geç
	token += 1
	var my := token
	var timer := get_tree().create_timer(dur + HOLD_SEC)
	timer.timeout.connect(func():
		if my == token:
			advanced.emit())
	await advanced
	if tt.is_valid():
		tt.kill()
	typing = false
	sub.visible_ratio = 1.0
	if skipping:
		return
	var fo := create_tween()
	fo.tween_property(fade, "color:a", 1.0, 0.45)
	await fo.finished
	zoom.kill()

## Ekranın altını koyulaştıran şerit (altyazı okunurluğu)
class ShadeBand extends Control:
	func _draw() -> void:
		var h := size.y
		var y0 := h * 0.6
		draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(size.x, y0), Vector2(size.x, h), Vector2(0, h)]),
			PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.92), Color(0, 0, 0, 0.92)]))
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, h * 0.16), Vector2(0, h * 0.16)]),
			PackedColorArray([Color(0, 0, 0, 0.7), Color(0, 0, 0, 0.7), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]))


## Sahne görüntüleri. Şimdilik kodla çizilen yalın siluetler; grafik aşamasında
## illüstrasyonlarla değiştirilecek. kind: wheel, sedan, silhouette, elevator, club,
## stage, eyes, bank, fire, ledger, skyline, crash
class SceneArt extends Control:
	var kind := "skyline"
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		match kind:
			"wheel": _wheel()
			"sedan":
				_city(Color("4a0d12"), Color("c23a22"), 0.62)
				_street()
				_sedan(Vector2(w * 0.5, h * 0.72))
			"silhouette": _silhouette()
			"elevator": _elevator()
			"club": _club()
			"stage": _stage()
			"eyes": _eyes()
			"bank": _bank()
			"fire": _fire()
			"ledger": _ledger()
			"crash": _crash()
			_: _city(UIKit.SKY_TOP, UIKit.SKY_GLOW, 0.7)
		if kind in ["sedan", "skyline", "silhouette", "bank", "fire"]:
			_rain()
		_grain()

	# ── ortak parçalar ──
	func _grad(y0: float, y1: float, c0: Color, c1: Color) -> void:
		draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(size.x, y0), Vector2(size.x, y1), Vector2(0, y1)]),
			PackedColorArray([c0, c0, c1, c1]))

	func _city(top: Color, glow: Color, base_k: float) -> void:
		var w := size.x
		var h := size.y
		var base := h * base_k
		_grad(0, base * 0.55, Color("050307"), top)
		_grad(base * 0.55, base, top, glow)
		draw_rect(Rect2(0, base, w, h - base), Color("050407"))
		# projektörler ve zeplin
		for b in [[0.25, -0.35], [0.7, 0.28]]:
			var o := Vector2(w * float(b[0]), base)
			var a: float = -PI / 2 + float(b[1]) + sin(t * 0.4 + float(b[0]) * 6.0) * 0.12
			var d := Vector2(cos(a), sin(a))
			var n := Vector2(-d.y, d.x)
			draw_polygon(PackedVector2Array([o, o + d * h + n * 50, o + d * h - n * 50]),
				PackedColorArray([Color(1, 0.92, 0.75, 0.16), Color(1, 0.92, 0.75, 0), Color(1, 0.92, 0.75, 0)]))
		var zp := Vector2(fmod(t * 9.0, w + 160) - 80, h * 0.16)
		_ell(zp, Vector2(46, 12), Color("0c0a10"))
		draw_rect(Rect2(zp + Vector2(-8, 10), Vector2(16, 5)), Color("0c0a10"))
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		var x := -10.0
		while x < w:
			var bw := rng.randf_range(24, 54)
			var bh := h * rng.randf_range(0.18, 0.45)
			var top_y := base - bh
			draw_rect(Rect2(x, top_y, bw, bh), Color("07060a"))
			if rng.randf() < 0.5:
				draw_rect(Rect2(x + bw * 0.2, top_y - bh * 0.12, bw * 0.6, bh * 0.12), Color("07060a"))
				draw_polygon(PackedVector2Array([Vector2(x + bw * 0.42, top_y - bh * 0.12), Vector2(x + bw * 0.5, top_y - bh * 0.3), Vector2(x + bw * 0.58, top_y - bh * 0.12)]), PackedColorArray([Color("07060a"), Color("07060a"), Color("07060a")]))
			var wy := top_y + 8
			while wy < base - 6:
				var wx := x + 4
				while wx < x + bw - 4:
					if rng.randf() < 0.22:
						draw_rect(Rect2(wx, wy, 3, 4), Color(UIKit.WINDOW, rng.randf_range(0.4, 0.95)))
					wx += 7
				wy += 9
			x += bw + rng.randf_range(-2, 4)

	func _street() -> void:
		var w := size.x
		var h := size.y
		var y := h * 0.62
		draw_rect(Rect2(0, y, w, h - y), Color("0b0b10"))
		# ıslak asfalttaki yansımalar
		for i in 18:
			var rx := fmod(i * 53.0, w)
			draw_line(Vector2(rx, y + 10 + i * 9), Vector2(rx + 26, y + 10 + i * 9), Color(UIKit.WINDOW, 0.08), 2.0)

	func _sedan(c: Vector2) -> void:
		var col := Color("3a0c12")
		# farlar
		for s in [-1, 1]:
			var hp := c + Vector2(s * 52, -2)
			draw_polygon(PackedVector2Array([hp, hp + Vector2(s * 40 - 70, 90), hp + Vector2(s * 40 + 70, 90)]),
				PackedColorArray([Color(1, 0.9, 0.6, 0.35), Color(1, 0.9, 0.6, 0), Color(1, 0.9, 0.6, 0)]))
		draw_rect(Rect2(c + Vector2(-80, -20), Vector2(160, 30)), col)
		draw_polygon(PackedVector2Array([c + Vector2(-50, -20), c + Vector2(-34, -52), c + Vector2(34, -52), c + Vector2(50, -20)]), PackedColorArray([col, col, col, col]))
		draw_rect(Rect2(c + Vector2(-28, -46), Vector2(56, 22)), Color(UIKit.WINDOW, 0.25))
		draw_line(c + Vector2(-80, -6), c + Vector2(80, -6), Color(UIKit.GOLD_2, 0.7), 1.5)
		for s in [-1, 1]:
			draw_circle(c + Vector2(s * 54, 12), 14, Color("060507"))
			draw_circle(c + Vector2(s * 54, 12), 6, Color(UIKit.GOLD_1, 0.6))
			draw_circle(c + Vector2(s * 66, -6), 6, Color("fff1c8"))

	func _rain() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		for i in 160:
			var x := rng.randf() * (size.x + 60) - 30
			var sp := rng.randf_range(500, 800)
			var y := fmod(rng.randf() * size.y + t * sp, size.y + 30) - 15
			var l := rng.randf_range(10, 22)
			draw_line(Vector2(x, y), Vector2(x - l * 0.15, y + l), Color(0.8, 0.82, 0.95, rng.randf_range(0.06, 0.16)), 1.0)

	func _grain() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(t * 24.0)
		for i in 220:
			var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
			draw_rect(Rect2(p, Vector2(1.5, 1.5)), Color(1, 1, 1, rng.randf_range(0.02, 0.07)))
		# titreyen ışık
		var fl := 0.04 * (0.5 + 0.5 * sin(t * 13.0) * sin(t * 7.3))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, fl))

	func _ell(c: Vector2, r: Vector2, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 36:
			var a := TAU * i / 36.0
			pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
		draw_colored_polygon(pts, col)

	func _man(foot: Vector2, k: float, col: Color) -> void:
		# paltolu, şapkalı adam silueti
		var s := k
		draw_polygon(PackedVector2Array([foot + Vector2(-22, 0) * s, foot + Vector2(-16, -95) * s, foot + Vector2(16, -95) * s, foot + Vector2(22, 0) * s]), PackedColorArray([col, col, col, col]))
		draw_circle(foot + Vector2(0, -108) * s, 12 * s, col)
		draw_rect(Rect2(foot + Vector2(-20, -120) * s, Vector2(40, 4) * s), col)
		draw_rect(Rect2(foot + Vector2(-11, -134) * s, Vector2(22, 15) * s), col)

	# ── sahneler ──
	func _wheel() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(Vector2.ZERO, size), Color("08060a"))
		var c := Vector2(w * 0.5, h * 0.42)
		var r := w * 0.44
		for k in 6:
			draw_circle(c, r + 40 - k * 6, Color(1, 0.85, 0.55, 0.02))
		draw_circle(c, r, Color("2a160c"))
		draw_arc(c, r, 0, TAU, 96, UIKit.GOLD_2, 3.0, true)
		var rot := t * 0.5
		var n := 37
		for i in n:
			var a0 := rot + TAU * i / n
			var a1 := rot + TAU * (i + 1) / n
			var col := UIKit.GOLD_2 if i == 0 else (UIKit.BORDO if i % 2 == 1 else Color("0b0a0e"))
			var r0 := r * 0.62
			var r1 := r * 0.86
			draw_polygon(PackedVector2Array([c + Vector2(cos(a0), sin(a0)) * r0, c + Vector2(cos(a0), sin(a0)) * r1, c + Vector2(cos(a1), sin(a1)) * r1, c + Vector2(cos(a1), sin(a1)) * r0]),
				PackedColorArray([col, col, col, col]))
			draw_line(c + Vector2(cos(a0), sin(a0)) * r0, c + Vector2(cos(a0), sin(a0)) * r1, Color(UIKit.GOLD_1, 0.8), 1.0)
		draw_circle(c, r * 0.6, Color("1b0f09"))
		for i in 4:
			var a := rot * 1.0 + TAU * i / 4.0
			draw_line(c, c + Vector2(cos(a), sin(a)) * r * 0.5, UIKit.GOLD_2, 4.0, true)
		draw_circle(c, r * 0.12, UIKit.GOLD_2)
		draw_circle(c, r * 0.06, UIKit.GOLD_3)
		# top ters yönde döner, sıfırın yanında
		var ba := -t * 1.6
		var br := r * (0.93 - 0.05 * minf(1.0, t * 0.08))
		draw_circle(c + Vector2(cos(ba), sin(ba)) * br, 7, Color("f4efe4"))
		draw_circle(c + Vector2(cos(ba), sin(ba)) * br + Vector2(-2, -2), 2.5, Color.WHITE)

	func _silhouette() -> void:
		var w := size.x
		var h := size.y
		_grad(0, h, Color("1a0a12"), Color("070508"))
		# alçak açıdan üstüne kapanan binalar
		var col := Color("040306")
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w * 0.32, 0), Vector2(w * 0.1, h), Vector2(0, h)]), PackedColorArray([col, col, col, col]))
		draw_polygon(PackedVector2Array([Vector2(w, 0), Vector2(w * 0.68, 0), Vector2(w * 0.9, h), Vector2(w, h)]), PackedColorArray([col, col, col, col]))
		for i in 12:
			var y := h * (0.08 + i * 0.075)
			draw_rect(Rect2(w * (0.27 - i * 0.012), y, 6, 8), Color(UIKit.WINDOW, 0.5 if i % 3 else 0.15))
			draw_rect(Rect2(w * (0.71 + i * 0.012), y + 4, 6, 8), Color(UIKit.WINDOW, 0.15 if i % 2 else 0.55))
		_man(Vector2(w * 0.5, h * 0.82), 2.2, Color("020203"))
		var ember := Vector2(w * 0.5 + 34, h * 0.82 - 232)
		var g := 0.6 + 0.4 * sin(t * 2.0)
		draw_circle(ember, 16, Color(1, 0.4, 0.1, 0.12 * g))
		draw_circle(ember, 4, Color(1, 0.55, 0.15, g))
		for i in 6:
			var k := fmod(t * 0.25 + i / 6.0, 1.0)
			draw_circle(ember + Vector2(sin(k * 5 + i) * 10 * k, -k * 140), 4 + k * 16, Color(0.8, 0.8, 0.85, 0.1 * (1 - k)))

	func _elevator() -> void:
		var w := size.x
		var h := size.y
		_grad(0, h, Color("2a1d0c"), Color("0d0904"))
		var panel := Rect2(w * 0.2, h * 0.14, w * 0.6, h * 0.56)
		draw_rect(panel, Color("4a3514"))
		draw_rect(panel.grow(-6), Color("2c1f0b"))
		draw_rect(panel, UIKit.GOLD_2, false, 2.0)
		var f := UIKit.title_font()
		for i in 9:
			var col := i % 3
			var row := i / 3
			var c := panel.position + Vector2(panel.size.x * (0.25 + col * 0.25), panel.size.y * (0.22 + row * 0.26))
			var lit := i == 8 and t > 2.2
			draw_circle(c, 26, Color("8a6a2a") if not lit else Color("ffd27a"))
			draw_circle(c, 21, Color("1b1408") if not lit else Color("fff0c2"))
			if lit:
				draw_circle(c, 48, Color(1, 0.8, 0.4, 0.12))
			var label := str(i + 1)
			var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
			draw_string(f, c + Vector2(-tw / 2, 8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UIKit.GOLD_3 if not lit else Color("2a1a06"))
		# eldivenli parmak 9'a uzanır
		var target := panel.position + Vector2(panel.size.x * 0.75, panel.size.y * 0.74)
		var k := minf(1.0, t / 2.2)
		var tip := target.lerp(target + Vector2(140, 220), 1.0 - k)
		var glove := Color("0a0808")
		draw_line(tip, tip + Vector2(150, 260), glove, 34.0, true)
		draw_circle(tip, 14, glove)
		draw_line(tip + Vector2(40, 90), tip + Vector2(150, 260), Color("f2efe6"), 6.0)

	func _club() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(Vector2.ZERO, size), Color("070507"))
		# yelpaze biçimli altın tavan
		var c := Vector2(w * 0.5, -h * 0.05)
		for i in 15:
			var a := PI * 0.12 + PI * 0.76 * i / 14.0
			draw_line(c, c + Vector2(cos(a), sin(a)) * h * 0.5, Color(UIKit.GOLD_2, 0.35), 2.0, true)
		for k in [0.18, 0.28, 0.38]:
			draw_arc(c, h * k, PI * 0.12, PI * 0.88, 40, Color(UIKit.GOLD_2, 0.4), 1.5, true)
		# siyah mermer zemin
		_grad(h * 0.5, h, Color("0e0c12"), Color("030204"))
		for i in 7:
			draw_line(Vector2(w * 0.5, h * 0.5), Vector2(w * (i / 6.0) * 2.0 - w * 0.5, h), Color(1, 1, 1, 0.04), 1.0)
		# ortada rulet masası ve sarkan lamba ışığı
		var tc := Vector2(w * 0.5, h * 0.6)
		draw_polygon(PackedVector2Array([tc + Vector2(-20, -h * 0.5), tc + Vector2(20, -h * 0.5), tc + Vector2(120, 0), tc + Vector2(-120, 0)]),
			PackedColorArray([Color(1, 0.85, 0.5, 0.0), Color(1, 0.85, 0.5, 0.0), Color(1, 0.85, 0.5, 0.12), Color(1, 0.85, 0.5, 0.12)]))
		_ell(tc, Vector2(130, 34), Color("123a2d"))
		_ell(tc + Vector2(0, -3), Vector2(30, 10), UIKit.GOLD_1)
		# masanın çevresinde siluetler
		for i in 5:
			var x := w * (0.12 + i * 0.19)
			var y := h * (0.66 + (0.05 if i % 2 else 0.0))
			_man(Vector2(x, y), 0.9 + (i % 2) * 0.15, Color("020203"))

	func _stage() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(Vector2.ZERO, size), Color("060407"))
		# bordo perde
		for i in 9:
			var x := w * i / 8.0
			draw_rect(Rect2(x - 18, 0, 22, h * 0.7), Color(UIKit.BORDO, 0.55 + 0.25 * (i % 2)))
		var sc := Vector2(w * 0.5, h * 0.66)
		var sway := sin(t * 0.6) * 4.0
		draw_polygon(PackedVector2Array([Vector2(w * 0.5 - 18, 0), Vector2(w * 0.5 + 18, 0), sc + Vector2(120, 0), sc + Vector2(-120, 0)]),
			PackedColorArray([Color(1, 0.95, 0.8, 0.25), Color(1, 0.95, 0.8, 0.25), Color(1, 0.95, 0.8, 0.05), Color(1, 0.95, 0.8, 0.05)]))
		_ell(sc, Vector2(120, 22), Color(1, 0.95, 0.8, 0.12))
		# kırmızı elbiseli şarkıcı (kırmızı yalnızca onda)
		var red := Color("b3121f")
		var p := sc + Vector2(sway, 0)
		draw_polygon(PackedVector2Array([p + Vector2(-34, 0), p + Vector2(-12, -110), p + Vector2(12, -110), p + Vector2(34, 0)]), PackedColorArray([red, red.darkened(0.3), red.darkened(0.3), red]))
		draw_circle(p + Vector2(0, -124), 13, Color("e9d9c6"))
		draw_arc(p + Vector2(0, -128), 15, PI, TAU, 16, Color("101010"), 8.0)
		# mikrofon
		draw_line(sc + Vector2(-30, 0), sc + Vector2(-30, -120), Color("888070"), 2.0)
		draw_circle(sc + Vector2(-30, -124), 6, Color("c9c0a8"))

	func _eyes() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(Vector2.ZERO, size), Color("030203"))
		# panjurdan sızan ışık çizgileri
		for i in 9:
			var y := h * 0.22 + i * 26.0
			draw_polygon(PackedVector2Array([Vector2(0, y), Vector2(w, y - 30), Vector2(w, y - 18), Vector2(0, y + 12)]),
				PackedColorArray([Color(1, 0.85, 0.55, 0.0), Color(1, 0.85, 0.55, 0.22), Color(1, 0.85, 0.55, 0.22), Color(1, 0.85, 0.55, 0.0)]))
		var ey := h * 0.36
		for s in [-1, 1]:
			var c := Vector2(w * 0.5 + s * 62, ey)
			_ell(c, Vector2(34, 11), Color("d8cdb8"))
			draw_circle(c + Vector2(sin(t * 0.7) * 4, 0), 9, Color("2b1a10"))
			draw_circle(c + Vector2(sin(t * 0.7) * 4, 0), 4, Color("050303"))
			draw_circle(c + Vector2(sin(t * 0.7) * 4 - 3, -3), 2, Color(1, 1, 1, 0.9))
			draw_line(c + Vector2(-38, -16), c + Vector2(30, -20), Color("0a0706"), 5.0)

	func _bank() -> void:
		var w := size.x
		var h := size.y
		_grad(0, h, Color("161a24"), Color("07080c"))
		var top := h * 0.2
		var base := h * 0.72
		draw_polygon(PackedVector2Array([Vector2(w * 0.08, top + 40), Vector2(w * 0.5, top - 20), Vector2(w * 0.92, top + 40)]), PackedColorArray([Color("2e3442"), Color("3b4252"), Color("2e3442")]))
		draw_rect(Rect2(w * 0.08, top + 40, w * 0.84, 18), Color("3b4252"))
		for i in 6:
			var x := w * (0.13 + i * 0.15)
			draw_rect(Rect2(x, top + 58, 18, base - top - 58), Color("4a5263"))
			draw_rect(Rect2(x + 12, top + 58, 6, base - top - 58), Color("2a2f3b"))
		draw_rect(Rect2(w * 0.05, base, w * 0.9, 14), Color("3b4252"))
		var f := UIKit.caps_font()
		var label := "BLACK & SONS"
		var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(f, Vector2(w * 0.5 - tw / 2, top + 54), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UIKit.GOLD_2)
		draw_rect(Rect2(w * 0.44, top - 4, w * 0.12, 10), Color(UIKit.WINDOW, 0.7))

	func _fire() -> void:
		var w := size.x
		var h := size.y
		_grad(0, h, Color("240806"), Color("080304"))
		var base := h * 0.72
		draw_rect(Rect2(w * 0.12, h * 0.26, w * 0.76, base - h * 0.26), Color("0b0607"))
		for i in 3:
			draw_rect(Rect2(w * (0.12 + i * 0.04), h * (0.26 - i * 0.03), w * (0.76 - i * 0.08), 10), Color("0b0607"))
		for i in 12:
			var x := w * (0.18 + (i % 4) * 0.18)
			var y := h * (0.34 + (i / 4) * 0.11)
			var g := 0.5 + 0.5 * sin(t * 9.0 + i * 1.7)
			draw_rect(Rect2(x, y, 26, 34), Color(1.0, 0.45 + 0.2 * g, 0.1, 0.55 + 0.4 * g))
		for i in 14:
			var x := w * (0.1 + i * 0.06)
			var fh := 60 + 40 * sin(t * 6.0 + i)
			draw_polygon(PackedVector2Array([Vector2(x - 18, base), Vector2(x, base - fh), Vector2(x + 18, base)]),
				PackedColorArray([Color(1, 0.3, 0.05, 0.8), Color(1, 0.85, 0.3, 0.0), Color(1, 0.3, 0.05, 0.8)]))
		draw_rect(Rect2(0, base, w, h - base), Color("050304"))
		_man(Vector2(w * 0.5, h * 0.9), 1.0, Color("000000"))

	func _ledger() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(Vector2.ZERO, size), Color("0a0507"))
		_grad(h * 0.45, h, Color("2a0b10"), Color("12050a"))
		var lc := Vector2(w * 0.5, h * 0.55)
		for k in 6:
			_ell(lc, Vector2(w * (0.55 - k * 0.07), h * (0.2 - k * 0.025)), Color(1, 0.85, 0.5, 0.04))
		# açık defter
		var book := Rect2(w * 0.18, h * 0.47, w * 0.64, h * 0.17)
		draw_rect(book, Color("e7dcc0"))
		draw_line(Vector2(w * 0.5, book.position.y), Vector2(w * 0.5, book.end.y), Color("8a7a5a"), 2.0)
		for i in 7:
			var y := book.position.y + 14 + i * 14
			draw_line(Vector2(book.position.x + 12, y), Vector2(w * 0.5 - 10, y), Color(0.2, 0.15, 0.1, 0.45), 1.5)
			draw_line(Vector2(w * 0.5 + 10, y), Vector2(book.end.x - 12, y), Color(0.2, 0.15, 0.1, 0.45), 1.5)
		# kırmızı kurdele
		draw_line(Vector2(w * 0.52, book.position.y - 6), Vector2(w * 0.56, book.end.y + 40), Color("b3121f"), 5.0)
		# masa lambası (yeşil abajur)
		draw_polygon(PackedVector2Array([Vector2(w * 0.1, h * 0.3), Vector2(w * 0.3, h * 0.3), Vector2(w * 0.36, h * 0.38), Vector2(w * 0.04, h * 0.38)]),
			PackedColorArray([Color("0f5a3a"), Color("0f5a3a"), Color("1b7a50"), Color("1b7a50")]))
		draw_line(Vector2(w * 0.2, h * 0.38), Vector2(w * 0.2, h * 0.47), UIKit.GOLD_2, 4.0)

	func _crash() -> void:
		var w := size.x
		var h := size.y
		_grad(0, h, Color("1a0607"), Color("050304"))
		# düşen grafik çizgisi
		var pts := PackedVector2Array()
		for i in 12:
			var x := w * (0.08 + i * 0.075)
			var y := h * (0.25 + 0.02 * sin(i * 1.7)) + (0.0 if i < 6 else (i - 5) * (h * 0.06))
			pts.append(Vector2(x, y))
		draw_polyline(pts, Color("d23b2f"), 4.0, true)
		draw_line(Vector2(w * 0.08, h * 0.65), Vector2(w * 0.92, h * 0.65), Color(UIKit.GOLD_2, 0.5), 1.5)
		# yağan borsa şeridi
		var rng := RandomNumberGenerator.new()
		rng.seed = 29
		for i in 40:
			var x := rng.randf() * w
			var y := fmod(rng.randf() * h + t * rng.randf_range(40, 90), h)
			draw_line(Vector2(x, y), Vector2(x + 6 * sin(t + i), y + 14), Color("e7dcc0", 0.6), 2.0)
		var f := UIKit.title_font()
		var label := "BORSA ÇÖKTÜ"
		var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		draw_string(f, Vector2(w * 0.5 - tw / 2, h * 0.16), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("e7dcc0"))
