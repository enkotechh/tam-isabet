extends Control
## Ana sahne: ekranlar (açılış, sınıf seçimi, oyun masası), pencereler, öğretici balonu,
## bildirimler ve efektler. Kurallar RunState'te; burası yalnızca çizer ve animasyon oynatır.

var run: RunState
var screen := ""
var busy := false
var last_tap = null          ## son dokunulan kart uid'i ya da "c<i>" (eşya)
var last_target := -1

var content: Control         ## ekranların kökü
var fx_layer: Control        ## animasyonlar ve parçacıklar
var overlay: Control         ## pencereler
var coach: PanelContainer
var focus_frame: Panel
var toasts: VBoxContainer
var toast_queue: Array = []
var toast_busy := false
var ui := {}                 ## oyun ekranı öğeleri
var backdrop: Backdrop

# ───────── Küçük çizim sınıfları ─────────
## Dark Deco zemin: mor-kızıl gece göğü, yıldızlar ve ay, projektör ışıkları,
## ışıklı pencereli gökdelen siluetleri, ince yağmur, kenarlarda altın çerçeve
class Backdrop extends Control:
	## "city": menü zemini · "table": oyun masası (oyuncunun gözünden)
	var mode := "city":
		set(v):
			mode = v
			queue_redraw()
	var felt_font: Font

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	## Dikey renk geçişi (üstten alta durak listesi: [oran, renk])
	func _vgrad(stops: Array, h: float) -> void:
		var w := size.x
		for i in stops.size() - 1:
			var a: Array = stops[i]
			var b: Array = stops[i + 1]
			var y0: float = h * float(a[0])
			var y1: float = h * float(b[0])
			var c0: Color = a[1]
			var c1: Color = b[1]
			draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(w, y0), Vector2(w, y1), Vector2(0, y1)]),
				PackedColorArray([c0, c0, c1, c1]))

	## Basamaklı (ziggurat) ya da iğne tepeli bir gökdelen çizer, pencerelerini yakar
	func _tower(rng: RandomNumberGenerator, x: float, bw: float, bh: float, base: float, col: Color, lit: float, win_a: float) -> void:
		var top := base - bh
		var pts := PackedVector2Array()
		var style := rng.randi() % 4
		pts.append(Vector2(x, base))
		if style == 0:
			pts.append(Vector2(x, top))
			pts.append(Vector2(x + bw, top))
		elif style == 1 or style == 2:
			# 2-3 basamak geri çekilme
			var steps := 2 + rng.randi() % 2
			var inset := bw * 0.14
			var cx := x
			var cy := top + bh * 0.16 * steps
			var ex := x + bw
			pts.append(Vector2(cx, cy))
			var left := PackedVector2Array()
			var right := PackedVector2Array()
			for s in steps:
				left.append(Vector2(cx, cy))
				cx += inset
				left.append(Vector2(cx, cy))
				cy -= bh * 0.16
				right.insert(0, Vector2(ex, cy + bh * 0.16))
				ex -= inset
				right.insert(0, Vector2(ex, cy + bh * 0.16))
			pts.append_array(left)
			pts.append(Vector2(cx, cy))
			if style == 2:
				var mid := (cx + ex) / 2
				pts.append(Vector2(mid - 1.0, cy - bh * 0.12))
				pts.append(Vector2(mid, cy - bh * 0.28))
				pts.append(Vector2(mid + 1.0, cy - bh * 0.12))
			pts.append(Vector2(ex, cy))
			pts.append_array(right)
		else:
			# sivri iğne tepe
			pts.append(Vector2(x, top + bh * 0.12))
			pts.append(Vector2(x + bw * 0.5, top - bh * 0.18))
			pts.append(Vector2(x + bw, top + bh * 0.12))
		pts.append(Vector2(x + bw, base))
		draw_colored_polygon(pts, col)
		# pencereler
		var wy := top + bh * 0.2
		while wy < base - 6:
			var wx := x + 3.0
			while wx < x + bw - 4:
				if rng.randf() < lit:
					draw_rect(Rect2(Vector2(wx, wy), Vector2(2.0, 3.0)), Color(UIKit.WINDOW, win_a * rng.randf_range(0.5, 1.0)))
				wx += 5.0
			wy += 7.0

	func _draw() -> void:
		var w := size.x
		# masa modunda şehir yalnızca üstteki pencerede görünür
		var h := size.y if mode != "table" else size.y * 0.25
		var rng := RandomNumberGenerator.new()
		rng.seed = 1929
		# gece göğü: üstte mor, ufukta kızıl-bordo ışık, altta siyah
		_vgrad([[0.0, UIKit.WOOD_1], [0.35, UIKit.SKY_TOP], [0.7, UIKit.SKY_GLOW], [0.86, Color("12070d")], [1.0, UIKit.WOOD_0]], h)
		# yıldızlar
		for i in 70:
			var p := Vector2(rng.randf() * w, rng.randf() * h * 0.6)
			draw_rect(Rect2(p, Vector2.ONE * rng.randf_range(0.8, 1.6)), Color(1, 0.95, 0.85, rng.randf_range(0.15, 0.55)))
		# ay ve hâlesi
		var moon := Vector2(w * 0.8, h * 0.13)
		for k in 6:
			draw_circle(moon, 16.0 + k * 9.0, Color(UIKit.GOLD_3, 0.025))
		draw_circle(moon, 13.0, Color("efe3c4", 0.85))
		draw_circle(moon + Vector2(4, -3), 11.0, Color("efe3c4", 0.25))
		# projektör ışıkları (ufuktan göğe)
		var horizon := h * 0.78
		for b in [[0.22, -0.32], [0.3, 0.12], [0.64, -0.08], [0.74, 0.3]]:
			var o := Vector2(w * float(b[0]), horizon)
			var ang: float = -PI / 2 + float(b[1])
			var L := h * 0.75
			var d := Vector2(cos(ang), sin(ang))
			var n := Vector2(-d.y, d.x)
			draw_polygon(PackedVector2Array([o, o + d * L + n * 34.0, o + d * L - n * 34.0]),
				PackedColorArray([Color(UIKit.GOLD_3, 0.10), Color(UIKit.GOLD_3, 0.0), Color(UIKit.GOLD_3, 0.0)]))
		# uzak siluet (sisli)
		var x := -10.0
		while x < w:
			var bw := rng.randf_range(18, 34)
			_tower(rng, x, bw, h * rng.randf_range(0.12, 0.3), h, Color("150d1c"), 0.12, 0.45)
			x += bw - rng.randf_range(0, 6)
		# yakın siluet (simsiyah, daha çok ışık)
		x = -14.0
		while x < w:
			var bw := rng.randf_range(26, 52)
			_tower(rng, x, bw, h * rng.randf_range(0.07, 0.2), h, Color("050408"), 0.22, 0.9)
			x += bw + rng.randf_range(-4, 2)
		# ince yağmur
		for i in 110:
			var p := Vector2(rng.randf() * (w + 40) - 20, rng.randf() * h)
			var l := rng.randf_range(8, 18)
			draw_line(p, p + Vector2(-l * 0.18, l), Color(0.75, 0.78, 0.9, rng.randf_range(0.04, 0.1)), 1.0, true)
		if mode == "table":
			_draw_table()
		# kenar çizgileri
		var m := 6.0
		var col := Color(UIKit.GOLD_2, 0.3)
		draw_polyline(DecoBox.closed(DecoBox.oct(Rect2(Vector2(m, m), size - Vector2(m * 2, m * 2)), 14)), col, 1.0, true)
		draw_polyline(DecoBox.closed(DecoBox.oct(Rect2(Vector2(m + 4, m + 4), size - Vector2(m * 2 + 8, m * 2 + 8)), 10)), Color(col, 0.14), 1.0, true)

	## Kumar masası: uzak kenarı ekranın üst kısmında, yakın kenarı (deri kol dayama)
	## altta kalan perspektifli çuha; ortada lamba ışığı ve masanın arması
	func _draw_table() -> void:
		var w := size.x
		var h := size.y
		var top := h * 0.2
		# odanın karanlığı (pencerenin altı)
		draw_rect(Rect2(0, h * 0.25, w, h), UIKit.WOOD_0)
		draw_line(Vector2(0, h * 0.25), Vector2(w, h * 0.25), Color(UIKit.BORDO, 0.9), 3.0)
		var far_l := w * 0.1
		var far_r := w * 0.9
		var near_l := -w * 0.35
		var near_r := w * 1.35
		var bot := h * 1.02
		# masanın gövdesi (koyu ahşap kenar)
		var rim := PackedVector2Array([Vector2(far_l - 10, top - 8), Vector2(far_r + 10, top - 8), Vector2(near_r + 30, bot), Vector2(near_l - 30, bot)])
		draw_colored_polygon(rim, Color("1a0c0e"))
		# çuha: uzakta koyu, ortada lamba altında açık yeşil
		var felt_far := Color("0a1f19")
		var felt_mid := Color("123a2d")
		var felt_near := Color("0c261e")
		var midy := top + (bot - top) * 0.45
		var t_mid := (midy - top) / (bot - top)
		var ml := lerpf(far_l, near_l, t_mid)
		var mr := lerpf(far_r, near_r, t_mid)
		draw_polygon(PackedVector2Array([Vector2(far_l, top), Vector2(far_r, top), Vector2(mr, midy), Vector2(ml, midy)]),
			PackedColorArray([felt_far, felt_far, felt_mid, felt_mid]))
		draw_polygon(PackedVector2Array([Vector2(ml, midy), Vector2(mr, midy), Vector2(near_r, bot), Vector2(near_l, bot)]),
			PackedColorArray([felt_mid, felt_mid, felt_near, felt_near]))
		# lamba ışığı havuzu
		var lc := Vector2(w * 0.5, midy)
		for k in 7:
			var rr := w * (0.62 - k * 0.07)
			_ellipse(lc, Vector2(rr, rr * 0.55), Color(1.0, 0.85, 0.55, 0.025))
		# altın kenar şeridi
		draw_line(Vector2(far_l, top), Vector2(far_r, top), Color(UIKit.GOLD_2, 0.7), 2.0, true)
		draw_line(Vector2(far_l, top), Vector2(near_l, bot), Color(UIKit.GOLD_2, 0.45), 2.0, true)
		draw_line(Vector2(far_r, top), Vector2(near_r, bot), Color(UIKit.GOLD_2, 0.45), 2.0, true)
		var inset := 14.0
		draw_line(Vector2(far_l + inset, top + 6), Vector2(far_r - inset, top + 6), Color(UIKit.GOLD_2, 0.2), 1.0, true)
		# çuhadaki arma: sekizgen içinde sıfır ve kumarhanenin adı
		var ac := Vector2(w * 0.5, top + (bot - top) * 0.36)
		var ar := Vector2(w * 0.3, w * 0.13)
		_ellipse_line(ac, ar, Color(UIKit.GOLD_2, 0.13), 1.5)
		_ellipse_line(ac, ar * 0.9, Color(UIKit.GOLD_2, 0.08), 1.0)
		if felt_font == null:
			felt_font = UIKit.title_font()
		var label := "THE GILDED ZERO"
		var fs := 15
		var tw := felt_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(felt_font, Vector2(ac.x - tw / 2, ac.y + fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UIKit.GOLD_2, 0.16))
		# yakın kenar: bordo deri kol dayama ve altın biye
		var ry := h * 0.885
		draw_rect(Rect2(0, ry, w, h - ry), Color("2a0b10"))
		draw_polygon(PackedVector2Array([Vector2(0, ry), Vector2(w, ry), Vector2(w, ry + 14), Vector2(0, ry + 14)]),
			PackedColorArray([Color("4a141c"), Color("4a141c"), Color("2a0b10"), Color("2a0b10")]))
		draw_line(Vector2(0, ry), Vector2(w, ry), Color(UIKit.GOLD_2, 0.75), 1.5, true)
		draw_line(Vector2(0, ry + 3), Vector2(w, ry + 3), Color(UIKit.GOLD_2, 0.25), 1.0, true)
		var x := 10.0
		while x < w:
			draw_circle(Vector2(x, ry + 9), 1.3, Color(UIKit.GOLD_1, 0.55))
			x += 14.0
		# kenarlarda karanlık (vinyet)
		for k in 5:
			var a := 0.08
			draw_rect(Rect2(0, 0, 18 - k * 3, h), Color(0, 0, 0, a))
			draw_rect(Rect2(w - 18 + k * 3, 0, 18 - k * 3, h), Color(0, 0, 0, a))

	func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 40:
			var a := TAU * i / 40.0
			pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
		draw_colored_polygon(pts, col)

	func _ellipse_line(c: Vector2, r: Vector2, col: Color, width: float) -> void:
		var pts := PackedVector2Array()
		for i in 49:
			var a := TAU * i / 48.0
			pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
		draw_polyline(pts, col, width, true)


## Masadaki küçük ayrıntılar: kül tablasında yanan puro ve dumanı, viski kadehi, fiş kulesi.
## Dokunmayı engellemez; konumlar oyun ekranı kurulunca ayarlanır.
class TableProps extends Control:
	var ashtray := Vector2(-999, -999)
	var glass := Vector2(-999, -999)
	var chips := Vector2(-999, -999)
	var corner: Control      ## açıklama satırının sağında boş bırakılan köşe
	var pile: Control        ## "Çekme" sayacı (fişler yanına konur)
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		# konumlar her karede yerleşimden okunur (ekran boyu ve satır yükseklikleri değişebilir)
		if is_instance_valid(corner):
			var cr := corner.get_global_rect()
			var o := get_global_rect().position
			glass = cr.position - o + Vector2(20, cr.size.y + 2)
			ashtray = cr.position - o + Vector2(cr.size.x - 40, cr.size.y + 4)
		if is_instance_valid(pile):
			var dr := pile.get_global_rect()
			chips = dr.position - get_global_rect().position + Vector2(92, dr.size.y / 2 + 10)
		queue_redraw()

	func _ell(c: Vector2, r: Vector2, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 32:
			var a := TAU * i / 32.0
			pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
		draw_colored_polygon(pts, col)

	func _draw() -> void:
		_draw_chips(chips)
		_draw_glass(glass)
		_draw_ashtray(ashtray)

	func _draw_ashtray(p: Vector2) -> void:
		# gölge, cam tabla
		_ell(p + Vector2(3, 5), Vector2(26, 10), Color(0, 0, 0, 0.45))
		_ell(p, Vector2(25, 10), Color("2b2a33"))
		_ell(p + Vector2(0, -1), Vector2(19, 7), Color("111015"))
		_ell(p + Vector2(-6, -3), Vector2(7, 2), Color(1, 1, 1, 0.08))
		# puro: tablanın kenarına yaslanmış, ucu yanıyor
		var a := p + Vector2(-2, -2)
		var b := p + Vector2(30, -12)
		draw_line(a, b, Color("4a2a17"), 5.0, true)
		draw_line(a + Vector2(0, -1), b + Vector2(0, -1), Color("6e4224"), 1.5, true)
		draw_line(a.lerp(b, 0.62), a.lerp(b, 0.7), Color(UIKit.BORDO.lightened(0.2)), 5.5, true)   # puro bandı
		draw_line(a.lerp(b, 0.64), a.lerp(b, 0.68), Color(UIKit.GOLD_2), 5.5, true)
		var glow := 0.65 + 0.35 * sin(t * 2.3) * sin(t * 0.7 + 1.0)
		draw_circle(a, 6.0, Color(1.0, 0.45, 0.1, 0.15 * glow))
		draw_circle(a, 3.2, Color(1.0, 0.4 + 0.2 * glow, 0.1, 0.9))
		draw_circle(a + Vector2(-1, 0), 1.8, Color(1.0, 0.85, 0.5, glow))
		# duman: yavaşça yükselip kıvrılan, sönen halkalar
		for i in 9:
			var k := fmod(t * 0.22 + i / 9.0, 1.0)
			var y := -k * 120.0
			var x := sin(k * 6.0 + t * 0.8 + i) * (4.0 + k * 16.0)
			var r := 3.0 + k * 13.0
			draw_circle(a + Vector2(x - 2, y - 4), r, Color(0.78, 0.76, 0.82, 0.10 * (1.0 - k) * minf(1.0, k * 6.0)))

	func _draw_glass(p: Vector2) -> void:
		_ell(p + Vector2(3, 3), Vector2(16, 6), Color(0, 0, 0, 0.45))
		var w := 13.0
		var h := 30.0
		# viski
		draw_colored_polygon(PackedVector2Array([p + Vector2(-w + 1, -h * 0.45), p + Vector2(w - 1, -h * 0.45), p + Vector2(w - 2, -2), p + Vector2(-w + 2, -2)]), Color(0.75, 0.38, 0.1, 0.75))
		_ell(p + Vector2(0, -h * 0.45), Vector2(w - 1, 3.5), Color(0.95, 0.6, 0.25, 0.8))
		# buz
		draw_rect(Rect2(p + Vector2(-5, -h * 0.5), Vector2(7, 6)), Color(1, 1, 1, 0.25))
		# cam ve kesme desen
		draw_polyline(PackedVector2Array([p + Vector2(-w, -h), p + Vector2(-w + 2, 0), p + Vector2(w - 2, 0), p + Vector2(w, -h)]), Color(1, 1, 1, 0.45), 1.2, true)
		_ell(p + Vector2(0, -h), Vector2(w, 3.5), Color(1, 1, 1, 0.06))
		draw_arc(p + Vector2(0, -h), w, 0, PI, 16, Color(1, 1, 1, 0.35), 1.0, true)
		for i in 3:
			var yy := -h * (0.2 + i * 0.25)
			draw_line(p + Vector2(-w + 2, yy), p + Vector2(0, yy - 5), Color(1, 1, 1, 0.12), 1.0, true)
			draw_line(p + Vector2(0, yy - 5), p + Vector2(w - 2, yy), Color(1, 1, 1, 0.12), 1.0, true)
		draw_line(p + Vector2(-w + 3, -h + 4), p + Vector2(-w + 4, -4), Color(1, 1, 1, 0.3), 1.5, true)

	func _draw_chips(p: Vector2) -> void:
		var cols := [UIKit.BORDO.lightened(0.15), Color("1d1d26"), UIKit.GOLD_1, UIKit.BORDO.lightened(0.15), Color("1d1d26")]
		_ell(p + Vector2(3, 4), Vector2(16, 6), Color(0, 0, 0, 0.45))
		for i in cols.size():
			var c := p + Vector2(0, -i * 4.0)
			var col: Color = cols[i]
			draw_rect(Rect2(c + Vector2(-14, -4), Vector2(28, 4)), col.darkened(0.35))
			_ell(c + Vector2(0, -4), Vector2(14, 5), col)
			for j in 4:
				var a := TAU * j / 4.0 + 0.4
				draw_line(c + Vector2(cos(a) * 9, sin(a) * 3.2 - 4), c + Vector2(cos(a) * 13, sin(a) * 4.6 - 4), Color(1, 1, 1, 0.5), 1.5, true)
		var top := p + Vector2(0, -(cols.size() - 1) * 4.0 - 4)
		_ell(top, Vector2(7, 2.4), Color(UIKit.GOLD_3, 0.5))

class Dial extends Control:
	var progress := 0.0:
		set(v):
			progress = v
			queue_redraw()
	func _draw() -> void:
		var c := size / 2
		var r := minf(size.x, size.y) / 2 - 3
		# dış sekizgen çerçeve + ışınlar
		draw_colored_polygon(DecoBox.oct(Rect2(c - Vector2(r + 3, r + 3), Vector2(r + 3, r + 3) * 2), r * 0.42), Color("050507"))
		draw_polyline(DecoBox.closed(DecoBox.oct(Rect2(c - Vector2(r + 3, r + 3), Vector2(r + 3, r + 3) * 2), r * 0.42)), UIKit.GOLD_2, 1.5, true)
		for i in 24:
			var a := TAU * i / 24.0
			var inner := r - (9.0 if i % 3 == 0 else 5.0)
			draw_line(c + Vector2(cos(a), sin(a)) * inner, c + Vector2(cos(a), sin(a)) * (r - 1), Color(UIKit.GOLD_2, 0.55), 1.0, true)
		draw_arc(c, r - 12, 0, TAU, 64, Color(UIKit.GOLD_0, 0.9), 6, true)
		if progress > 0:
			draw_arc(c, r - 12, -PI / 2, -PI / 2 + TAU * clampf(progress, 0, 1), 64, UIKit.GOLD_2, 6, true)
		draw_circle(c, r - 17, Color("101015"))
		draw_arc(c, r - 17, 0, TAU, 64, UIKit.GOLD_2, 1.0, true)
		draw_arc(c, r - 21, 0, TAU, 64, Color(UIKit.GOLD_2, 0.35), 1.0, true)

class Ring extends Control:
	var col := Color.WHITE
	var radius := 10.0:
		set(v):
			radius = v
			queue_redraw()
	func _draw() -> void:
		draw_arc(Vector2.ZERO, radius, 0, TAU, 48, col, 4.0, true)

class Bar extends Control:
	var value := 0.0:
		set(v):
			value = v
			queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("050507"))
		if value > 0:
			var fw := size.x * clampf(value, 0, 1)
			draw_rect(Rect2(Vector2(0, 1), Vector2(fw, size.y - 2)), UIKit.GOLD_2)
			var x := 6.0
			while x < fw:
				draw_line(Vector2(x, 1), Vector2(x - 4, size.y - 1), Color(UIKit.GOLD_0, 0.6), 1.0)
				x += 7.0
		draw_rect(Rect2(Vector2.ZERO, size), UIKit.GOLD_1, false, 1.0)

# ───────── Kurulum ─────────
func _ready() -> void:
	theme = UIKit.make_theme()
	var bg := Backdrop.new()
	backdrop = bg
	_full(bg)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	content = Control.new()
	_full(content)
	add_child(content)
	fx_layer = Control.new()
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full(fx_layer)
	add_child(fx_layer)
	overlay = Control.new()
	_full(overlay)
	overlay.visible = false
	add_child(overlay)

	focus_frame = Panel.new()
	var fs := UIKit.box(Color(0, 0, 0, 0), 14, 3, UIKit.GOLD_3)
	fs.draw_center = false
	fs.shadow_size = 14
	fs.shadow_color = Color(1, 0.85, 0.5, 0.45)
	fs.shadow_offset = Vector2.ZERO
	focus_frame.add_theme_stylebox_override("panel", fs)
	focus_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_frame.visible = false
	add_child(focus_frame)
	var ft := create_tween().set_loops()
	ft.tween_property(focus_frame, "modulate:a", 0.35, 0.7)
	ft.tween_property(focus_frame, "modulate:a", 1.0, 0.7)

	coach = PanelContainer.new()
	coach.visible = false
	add_child(coach)
	toasts = VBoxContainer.new()
	toasts.add_theme_constant_override("separation", 8)
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toasts)

	# katman sırası: ekran < efektler < pencereler < odak çerçevesi < öğretici < bildirimler
	fx_layer.z_index = 50
	overlay.z_index = 100
	focus_frame.z_index = 105
	coach.z_index = 110
	toasts.z_index = 120
	Progress.toast.connect(_on_toast)
	get_viewport().size_changed.connect(_on_resize)
	show_splash()

func _full(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## iPhone çentiği ve alt çubuk için güvenli alan (görüntü birimlerinde)
func _safe() -> Dictionary:
	var out := {"top": 12.0, "bottom": 12.0}
	if OS.has_feature("mobile"):
		var ss := DisplayServer.screen_get_size()
		var sa := DisplayServer.get_display_safe_area()
		var k := get_viewport_rect().size.y / maxf(1, ss.y)
		out.top = maxf(12, sa.position.y * k)
		out.bottom = maxf(12, (ss.y - sa.end.y) * k)
	return out

func _screen_root() -> VBoxContainer:
	for ch in content.get_children():
		ch.queue_free()
	ui = {}
	backdrop.mode = "city"
	_close_ui_modal()
	coach.visible = false
	focus_frame.visible = false
	var safe := _safe()
	var m := MarginContainer.new()
	_full(m)
	m.add_theme_constant_override("margin_left", 16)
	m.add_theme_constant_override("margin_right", 16)
	m.add_theme_constant_override("margin_top", int(safe.top))
	m.add_theme_constant_override("margin_bottom", int(safe.bottom))
	content.add_child(m)
	var v := UIKit.vbox(10)
	m.add_child(v)
	return v

func _on_resize() -> void:
	if screen == "game" and run:
		_place_props()
		refresh()

# ───────── Açılış menüsü ─────────
func show_splash() -> void:
	screen = "splash"
	overlay.visible = false
	var root := _screen_root()
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 16)

	var fan := Control.new()
	fan.custom_minimum_size = Vector2(0, 190)
	root.add_child(fan)
	var ids := ["joker", "philo", "mul2"]
	for i in 3:
		var cv := CardView.new()
		cv.card = {"tid": ids[i]}
		cv.set_width(100)
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fan.add_child(cv)
		cv.set_anchors_preset(Control.PRESET_CENTER_TOP)
		cv.position = Vector2(-50 + (i - 1) * 78, 14 + absi(i - 1) * 18)
		cv.rotation = deg_to_rad((i - 1) * 15)
		cv.z_index = 2 if i == 1 else 1
		var bob := cv.create_tween().set_loops()
		bob.tween_property(cv, "position:y", cv.position.y - 9, 2.2 + i * 0.2).set_trans(Tween.TRANS_SINE)
		bob.tween_property(cv, "position:y", cv.position.y, 2.2 + i * 0.2).set_trans(Tween.TRANS_SINE)

	var t1 := UIKit.label("P  O  R  T", 20, UIKit.GOLD_2, UIKit.deco_font(), HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(t1)
	root.add_child(UIKit.divider(200))
	var t2 := UIKit.title("HALLOWAY", 50, UIKit.GOLD_2)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t2.add_theme_constant_override("outline_size", 10)
	t2.add_theme_color_override("font_shadow_color", Color(UIKit.GOLD_0, 0.9))
	t2.add_theme_constant_override("shadow_offset_y", 4)
	root.add_child(t2)
	root.add_child(UIKit.divider(200))
	var tag := UIKit.wrap(UIKit.label("Sıfırdan gelen adam, her şeyini sıfıra oynar.", 17, UIKit.GOLD_3, UIKit.deco_font(), HORIZONTAL_ALIGNMENT_CENTER))
	root.add_child(tag)

	# Ana menü: Devam Et (varsa), Hikâyeye Başla, Öğretici, Ayarlar
	var menu := UIKit.vbox(12)
	menu.custom_minimum_size.x = 300
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(menu)
	if run and run.lives > 0 and run.modal.get("type", "") != "over":
		var cont := UIKit.button("Devam Et", true)
		cont.pressed.connect(func(): show_game())
		menu.add_child(cont)
	var start := UIKit.button("Hikâyeye Başla", true)
	start.pressed.connect(start_story)
	menu.add_child(start)
	var tb := UIKit.button("Öğretici")
	tb.pressed.connect(func(): start_run("guard", true))
	menu.add_child(tb)
	var st := UIKit.button("Ayarlar")
	st.pressed.connect(func(): open_modal({"type": "settings"}))
	menu.add_child(st)
	var row := UIKit.hbox(12)
	var coll := UIKit.button("Koleksiyon", false, true)
	coll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coll.pressed.connect(func(): show_classes("Koleksiyon ve Desteler"))
	var ach := UIKit.button("Başarımlar", false, true)
	ach.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ach.pressed.connect(func(): open_modal({"type": "achievements"}))
	row.add_child(coll)
	row.add_child(ach)
	menu.add_child(row)

	var total := Data.UNLOCK_ORDER.size() + Data.NUMBER_CARDS.size()
	var best := UIKit.label("REKOR  %d FİŞ" % Progress.best, 14, UIKit.GOLD_3, UIKit.title_font(), HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(best)
	root.add_child(UIKit.label("%d/%d kart ve eşya açık · %d/%d başarım" % [Progress.p.unlocked.size(), total, Progress.p.ach.size(), Data.ACHIEVEMENTS.size()], 13, UIKit.MUTED, null, HORIZONTAL_ALIGNMENT_CENTER))
	_render_coach()

func _sound_label() -> String:
	return "Ses: Açık" if Sfx.enabled else "Ses: Kapalı"

## Sesi açar/kapatır, tercihi kaydeder ve yeni düğme yazısını döner
func _toggle_sound() -> String:
	Sfx.enabled = not Sfx.enabled
	Progress.p["sound"] = Sfx.enabled
	Progress.save()
	Sfx.play("click")
	return _sound_label()

# ───────── Sınıf seçimi ─────────
func show_classes(head := "Karakterini Seç") -> void:
	screen = "classes"
	var root := _screen_root()
	var bar := UIKit.hbox(10)
	var back := UIKit.button("<", false, true)
	back.custom_minimum_size = Vector2(44, 40)
	back.pressed.connect(show_splash)
	bar.add_child(back)
	var t := UIKit.title(head, 22)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(t)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(44, 0)
	bar.add_child(sp)
	root.add_child(bar)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var list := UIKit.vbox(14)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for k in Data.CLASS_KEYS:
		list.add_child(_class_panel(k))

func _class_panel(k: String) -> Control:
	var C: Dictionary = Data.CLASSES[k]
	var open := Progress.class_open(k)
	var cc: Array = Data.CLASS_COLORS[k]
	var p := UIKit.panel(cc[1] if open else Color("2a2620"), 18, 3, UIKit.GOLD_2 if open else Color("5a5248"))
	var v := UIKit.vbox(8)
	p.add_child(v)
	var head := UIKit.hbox(12)
	var em := UIKit.panel(cc[0] if open else Color("3a352e"), 32, 3, UIKit.GOLD_1)
	em.custom_minimum_size = Vector2(62, 62)
	var ic := UIKit.icon_rect(C.icon if open else "lock", 34, Color("fff8e0"))
	em.add_child(ic)
	head.add_child(em)
	var hv := UIKit.vbox(2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UIKit.title(C.name, 21, Color("fff4d6")))
	var lock_text := ""
	for a in Data.ACHIEVEMENTS:
		if ("class:" + k) in a.unlocks:
			lock_text = a.text
	for i in Data.STORY.size():
		if ("class:" + k) in Data.STORY[i].unlocks:
			lock_text = "Hikâyede %d. bölümü bitir." % (i + 1)
	hv.add_child(UIKit.wrap(UIKit.label(C.tagline if open else "Kilitli: " + lock_text, 14, Color("e8dcc2"))))
	head.add_child(hv)
	v.add_child(head)
	var pw := UIKit.panel(Color(0, 0, 0, 0.3), 12)
	var ph := UIKit.hbox(10)
	ph.add_child(UIKit.icon_rect(C.power.icon, 26, UIKit.GOLD_3))
	var pv := UIKit.vbox(0)
	pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pv.add_child(UIKit.label(C.power.name, 14, UIKit.GOLD_3, UIKit.title_font()))
	pv.add_child(UIKit.wrap(UIKit.label(C.power.text, 13, Color("e8dcc2"))))
	ph.add_child(pv)
	pw.add_child(ph)
	v.add_child(pw)
	if open:
		var n_open := Data.SPECIAL_CARDS.filter(func(c): return c.cls == k and Progress.is_unlocked(c.id)).size()
		var n_all := Data.SPECIAL_CARDS.filter(func(c): return c.cls == k).size()
		v.add_child(UIKit.label("Karakter kartları: %d/%d açık" % [n_open, n_all], 12, UIKit.MUTED))
		var custom: bool = Progress.deck_for(k) != Data.RECOMMENDED[k]
		v.add_child(UIKit.label("Kendi desteni kullanıyorsun." if custom else "Önerilen deste kullanılıyor.", 12, UIKit.MUTED))
		var btns := UIKit.hbox(10)
		btns.alignment = BoxContainer.ALIGNMENT_END
		var edit := UIKit.button("Desteyi Düzenle", false, true)
		edit.pressed.connect(func(): show_builder(k))
		btns.add_child(edit)
		var play := UIKit.button("Oyna", true, true)
		play.custom_minimum_size.x = 110
		play.pressed.connect(func(): start_run(k))
		btns.add_child(play)
		v.add_child(btns)
	return p

# ───────── Deste oluşturucu (koleksiyon) ─────────
var B: Dictionary = {}       ## {cls, list, tab, open}
var bui: Dictionary = {}     ## deste oluşturucu öğeleri

func show_builder(cls: String) -> void:
	screen = "builder"
	B = {"cls": cls, "list": Progress.deck_for(cls).duplicate(), "tab": "class", "open": false}
	bui = {}
	var root := _screen_root()
	root.add_theme_constant_override("separation", 8)
	var bar := UIKit.hbox(10)
	var back := UIKit.button("<", false, true)
	back.custom_minimum_size = Vector2(44, 40)
	back.pressed.connect(func(): show_classes("Koleksiyon ve Desteler"))
	bar.add_child(back)
	var t := UIKit.title("%s Destesi" % Data.CLASSES[cls].name, 20)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(t)
	bui.count = UIKit.title("", 16, UIKit.GOLD_3)
	bui.count.custom_minimum_size.x = 56
	bui.count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(bui.count)
	root.add_child(bar)

	var tabs := UIKit.hbox(6)
	bui.tabs = {}
	for tab in [["class", Data.CLASSES[cls].name], ["neutral", "Nötr"], ["num", "Sayılar"]]:
		var tb := UIKit.button(tab[1], false, true)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key: String = tab[0]
		tb.pressed.connect(func():
			B.tab = key
			_builder_grid())
		tabs.add_child(tb)
		bui.tabs[key] = tb
	root.add_child(tabs)
	bui.hint = UIKit.wrap(UIKit.label("", 13, UIKit.MUTED))
	root.add_child(bui.hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bui.scroll = scroll
	root.add_child(scroll)
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 12)
	bui.flow = flow
	scroll.add_child(flow)

	var deckbar := UIKit.panel(Color(UIKit.WOOD_2, 0.94), 16, 2, UIKit.GOLD_2)
	var dv := UIKit.vbox(8)
	deckbar.add_child(dv)
	var tg := Button.new()
	tg.flat = true
	tg.focus_mode = Control.FOCUS_NONE
	tg.alignment = HORIZONTAL_ALIGNMENT_LEFT
	tg.add_theme_color_override("font_color", UIKit.INK)
	tg.add_theme_font_size_override("font_size", 14)
	tg.pressed.connect(func():
		B.open = not B.open
		_builder_list())
	bui.toggle = tg
	dv.add_child(tg)
	var ls := ScrollContainer.new()
	ls.custom_minimum_size.y = 230
	ls.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bui.list_scroll = ls
	var lv := UIKit.vbox(4)
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bui.list = lv
	ls.add_child(lv)
	dv.add_child(ls)
	var brow := UIKit.hbox(8)
	var rec := UIKit.button("Önerilen", false, true)
	rec.pressed.connect(func():
		B.list = Data.RECOMMENDED[B.cls].duplicate()
		_builder_update())
	var clr := UIKit.button("Temizle", false, true)
	clr.pressed.connect(func():
		B.list = []
		_builder_update())
	var save := UIKit.button("Kaydet ve Oyna", true, true)
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save.pressed.connect(func():
		if B.list.size() != RunState.DECK_SIZE:
			return
		Progress.save_deck(B.cls, B.list)
		start_run(B.cls))
	bui.save = save
	brow.add_child(rec)
	brow.add_child(clr)
	brow.add_child(save)
	dv.add_child(brow)
	root.add_child(deckbar)
	await get_tree().process_frame
	_builder_grid()

func _builder_pool() -> Array:
	var pool: Array
	if B.tab == "num":
		pool = Data.NUMBER_CARDS.duplicate()
	elif B.tab == "class":
		pool = Data.SPECIAL_CARDS.filter(func(c): return c.cls == B.cls)
	else:
		pool = Data.SPECIAL_CARDS.filter(func(c): return c.cls == "neutral" and not c.get("no_collect", false))
	pool.sort_custom(Data.by_rarity)
	return pool.map(func(c): return c.id)

func _max_copies(id: String) -> int:
	return int(Data.RARITY[Data.CARD[id].rarity].max)

## Sekme değişince ızgarayı baştan kurar
func _builder_grid() -> void:
	if screen != "builder":
		return
	for ch in bui.flow.get_children():
		ch.queue_free()
	bui.cells = {}
	var cw := minf(104.0, (bui.scroll.size.x - 24) / 3.0)
	for id in _builder_pool():
		var cell := UIKit.vbox(2)
		var cv := CardView.new()
		cv.card = {"tid": id}
		cv.set_width(cw)
		var open := Progress.is_unlocked(id)
		cv.locked = not open
		if open:
			var cid: String = id
			cv.pressed.connect(func(v): _builder_add(cid, v))
		cell.add_child(cv)
		var cnt := UIKit.label("", 12, UIKit.GOLD_3, UIKit.bold_font(), HORIZONTAL_ALIGNMENT_CENTER)
		cell.add_child(cnt)
		bui.flow.add_child(cell)
		bui.cells[id] = {"view": cv, "count": cnt}
	bui.scroll.scroll_vertical = 0
	_builder_update()

## Sayaçları, ipucunu, listeyi ve düğmeleri günceller (ızgarayı yeniden kurmadan)
func _builder_update() -> void:
	var n: int = B.list.size()
	bui.count.text = "%d/%d" % [n, RunState.DECK_SIZE]
	bui.count.add_theme_color_override("font_color", UIKit.HIT if n == RunState.DECK_SIZE else UIKit.GOLD_3)
	for key in bui.tabs:
		var on: bool = key == B.tab
		bui.tabs[key].add_theme_stylebox_override("normal", UIKit.box(UIKit.GOLD_2 if on else Color(0, 0, 0, 0.35), 10, 1, UIKit.GOLD_0))
		bui.tabs[key].add_theme_color_override("font_color", Color("3a2306") if on else UIKit.MUTED)
	var pool := _builder_pool()
	var open := pool.filter(Progress.is_unlocked).size()
	var nums: int = B.list.filter(func(id): return Data.CARD[id].kind == "num").size()
	bui.hint.text = "Bu sekmede %d/%d kart açık. Nadirliğe göre sıralı: beyaz, mavi, mor, sarı, kırmızı. Aynı karttan en fazla 2, efsanevi ve epik karttan 1 tane. Destende %d sayı kartı var." % [open, pool.size(), nums]
	for id in bui.cells:
		var k: int = B.list.count(id)
		var mx := _max_copies(id)
		var cell: Dictionary = bui.cells[id]
		cell.count.text = ("%d/%d" % [k, mx]) if k > 0 else " "
		cell.view.dimmed = Progress.is_unlocked(id) and (k >= mx or n >= RunState.DECK_SIZE)
		cell.view.selected = k > 0
		cell.view.queue_redraw()
	bui.save.disabled = n != RunState.DECK_SIZE
	bui.save.text = "Kaydet ve Oyna" if n == RunState.DECK_SIZE else "%d kart eksik" % (RunState.DECK_SIZE - n)
	_builder_list()

func _builder_list() -> void:
	var n: int = B.list.size()
	bui.toggle.text = "%s  Deste listesi · %d/%d kart" % ["▾" if B.open else "▸", n, RunState.DECK_SIZE]
	bui.list_scroll.visible = B.open
	for ch in bui.list.get_children():
		ch.queue_free()
	if not B.open:
		return
	var uniq: Array = []
	for id in B.list:
		if not id in uniq:
			uniq.append(id)
	var defs: Array = uniq.map(func(id): return Data.CARD[id])
	defs.sort_custom(Data.by_rarity)
	if defs.is_empty():
		bui.list.add_child(UIKit.label("Desten boş. Yukarıdaki kartlara dokunarak ekle.", 13, UIKit.MUTED))
	for t in defs:
		var cc: Array = Data.CLASS_COLORS.get(t.cls, Data.CLASS_COLORS.neutral)
		var row := Button.new()
		row.focus_mode = Control.FOCUS_NONE
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var gem: String = str(t.value) if t.kind == "num" else str(t.get("gem", "✦"))
		row.text = "%s   %s   ×%d" % [gem, t.name, B.list.count(t.id)]
		row.tooltip_text = "Desteden bir tane çıkar"
		var rs := UIKit.box(cc[1], 8, 2, Data.RARITY[t.rarity].color)
		rs.content_margin_top = 6
		rs.content_margin_bottom = 6
		row.add_theme_stylebox_override("normal", rs)
		row.add_theme_stylebox_override("hover", rs)
		row.add_theme_stylebox_override("pressed", rs)
		row.add_theme_color_override("font_color", UIKit.INK)
		row.add_theme_font_size_override("font_size", 14)
		var rid: String = t.id
		row.pressed.connect(func():
			var i: int = B.list.rfind(rid)
			if i >= 0:
				B.list.remove_at(i)
			_builder_update())
		var minus := UIKit.label("−", 18, UIKit.MISS, UIKit.bold_font())
		minus.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
		minus.position.x -= 14
		minus.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(minus)
		bui.list.add_child(row)

func _builder_add(id: String, v: CardView) -> void:
	if B.list.size() >= RunState.DECK_SIZE or B.list.count(id) >= _max_copies(id):
		pop(v, 0.94)
		Sfx.play("deny")
		return
	B.list.append(id)
	Sfx.play("select")
	pop(v, 1.08)
	burst(v.get_global_rect().get_center(), [Data.RARITY[Data.CARD[id].rarity].color, Color.WHITE], 14, 160, 0)
	_builder_update()

# ───────── Oyun ─────────
## Hikâye modu: ilk seferde Prolog oynar, sonra Silas ile masaya oturulur
## (ilk oyunda öğretici masa). Her kat hikâyenin bir bölümüdür.
func start_story() -> void:
	if not Progress.story_seen(1) and not Progress.story_finished():
		Progress.mark_seen(1)
		await play_scenes(Data.STORY[0].scenes, "Prolog")
	start_run("guard", not Progress.p.tutorial_done, true)

## Ara sahneyi her şeyin üstünde oynatır, bitince kaldırır
func play_scenes(scenes: Array, title := "") -> void:
	var cs := Cutscene.new()
	cs.z_index = 115
	add_child(cs)
	Sfx.play("whoosh", 0.6)
	await cs.play(scenes, title)
	cs.queue_free()

## Kural motorunun istediği hikâye sahnesi: bölüm açılışı ya da kapanışı
func _story_scene(f: Dictionary) -> void:
	var ch: int = f.ch
	var C: Dictionary = Data.STORY[ch - 1]
	if f.part == "intro":
		await play_scenes(C.scenes, "Bölüm %d · %s" % [ch, C.title])
		return
	var last: Dictionary = C.scenes[C.scenes.size() - 1]
	var scenes: Array = [{"art": last.art, "caption": "Bölüm %d tamamlandı" % ch, "text": C.outro}]
	if ch == Data.STORY.size():
		scenes.append({"art": "sedan", "caption": "Son", "text": "Vivienne bordo sedanla yağmura karıştı. Hikâye bitti, ama Port Halloway'de masalar hiç kapanmaz."})
	await play_scenes(scenes, C.title)

func start_run(cls: String, tutorial := false, story := false) -> void:
	run = RunState.new()
	run.rng.randomize()
	run.start(cls, Progress.deck_for(cls), tutorial, story)
	last_target = -1
	last_tap = null
	show_game()
	banner("Öğretici" if tutorial else Data.CLASSES[cls].name, "Adım adım öğren" if tutorial else "Masa açıldı")

func show_game() -> void:
	screen = "game"
	var root := _screen_root()
	root.add_theme_constant_override("separation", 8)
	# oyuncunun gözünden kumar masası: zemin masa olur, üstüne puro, kadeh ve fişler
	backdrop.mode = "table"
	var props := TableProps.new()
	_full(props)
	props.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.props = props

	# üst çubuk
	var top := UIKit.hbox(8)
	var menu := UIKit.button("☰", false, true)
	menu.custom_minimum_size = Vector2(44, 40)
	menu.pressed.connect(func():
		if not busy and run.modal.is_empty():
			open_modal({"type": "pause"}))
	top.add_child(menu)
	ui.hearts = UIKit.hbox(2)
	top.add_child(ui.hearts)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	ui.round = UIKit.label("", 13, UIKit.MUTED, UIKit.title_font())
	top.add_child(ui.round)
	top.add_child(UIKit.icon_rect("coin", 20, Color("f5c518")))
	ui.gold = UIKit.label("", 18, Color("f5c518"), UIKit.title_font())
	top.add_child(ui.gold)
	root.add_child(top)

	# tılsım yuvaları
	var cp := UIKit.panel(Color(0, 0, 0, 0.35), 12)
	ui.charms = UIKit.hbox(6)
	ui.charms.alignment = BoxContainer.ALIGNMENT_CENTER
	cp.add_child(ui.charms)
	root.add_child(cp)

	# arena
	var arena := PanelContainer.new()
	arena.add_theme_stylebox_override("panel", UIKit.frame(Color(UIKit.WOOD_1, 0.78), UIKit.GOLD_2, 16.0, true))
	ui.arena = arena
	var ah := UIKit.hbox(6)
	arena.add_child(ah)
	ui.hero = UIKit.vbox(4)
	ui.hero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.hero.alignment = BoxContainer.ALIGNMENT_CENTER
	ah.add_child(ui.hero)
	var dial := Dial.new()
	dial.custom_minimum_size = Vector2(112, 112)
	ui.dial = dial
	var dv := UIKit.vbox(0)
	dv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dv.alignment = BoxContainer.ALIGNMENT_CENTER
	dv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dv.add_child(UIKit.label("HEDEF", 10, UIKit.MUTED, UIKit.title_font(), HORIZONTAL_ALIGNMENT_CENTER))
	ui.target = UIKit.title("", 34, UIKit.GOLD_3)
	ui.target.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dv.add_child(ui.target)
	dial.add_child(dv)
	ah.add_child(dial)
	ui.omen = UIKit.vbox(4)
	ui.omen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.omen.alignment = BoxContainer.ALIGNMENT_CENTER
	ah.add_child(ui.omen)
	root.add_child(arena)

	# masa paneli: masa hedefi (net fiş) + Bahis × Oran
	var sp := UIKit.panel(Color(0, 0, 0, 0.42), 16, 2, UIKit.GOLD_0)
	ui.scorepanel = sp
	var sv := UIKit.vbox(6)
	sp.add_child(sv)
	var srow := UIKit.hbox(10)
	sv.add_child(srow)
	var gv := UIKit.vbox(2)
	gv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.round_label = UIKit.label("", 11, UIKit.MUTED, UIKit.bold_font())
	ui.round_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	gv.add_child(ui.round_label)
	var gn := UIKit.hbox(6)
	ui.rscore = UIKit.title("0", 26, UIKit.GOLD_3)
	gn.add_child(ui.rscore)
	ui.goal = UIKit.label("", 14, UIKit.MUTED, UIKit.title_font())
	ui.goal.size_flags_vertical = Control.SIZE_SHRINK_END
	gn.add_child(ui.goal)
	gv.add_child(gn)
	ui.bar = Bar.new()
	ui.bar.custom_minimum_size = Vector2(0, 8)
	gv.add_child(ui.bar)
	srow.add_child(gv)
	var sb := UIKit.hbox(4)
	ui.scorebox = sb
	ui.chips_box = _score_cell("BAHİS", UIKit.CHIPS)
	ui.mult_box = _score_cell("ORAN", UIKit.MULT)
	sb.add_child(ui.chips_box)
	var x := UIKit.title("×", 20, UIKit.GOLD_3)
	x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sb.add_child(x)
	sb.add_child(ui.mult_box)
	srow.add_child(sb)
	var res := UIKit.hbox(16)
	ui.plays = UIKit.label("", 13, UIKit.MUTED, UIKit.bold_font())
	ui.discs = UIKit.label("", 13, UIKit.MUTED, UIKit.bold_font())
	res.add_child(ui.plays)
	res.add_child(ui.discs)
	sv.add_child(res)
	# bahis seçimi: masa minimumunun 1, 2 ve 4 katı
	var brow := UIKit.hbox(8)
	var bl := UIKit.label("BAHİS", 12, UIKit.GOLD_2, UIKit.caps_font())
	bl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brow.add_child(bl)
	ui.bet_btns = []
	for i in RunState.BET_STEPS.size():
		var bb := UIKit.button("", i == 0, true)
		bb.custom_minimum_size = Vector2(62, 32)
		bb.pressed.connect(func():
			if busy:
				return
			run.set_bet(i)
			Sfx.play("chip", 0.8 + i * 0.15)
			refresh())
		brow.add_child(bb)
		ui.bet_btns.append(bb)
	sv.add_child(brow)
	root.add_child(sp)

	ui.mods = UIKit.rich("", 13)
	root.add_child(ui.mods)
	ui.msg = UIKit.wrap(UIKit.label("", 14, UIKit.MUTED))
	root.add_child(ui.msg)

	var pv := UIKit.panel(Color(0, 0, 0, 0.4), 14, 2, UIKit.GOLD_0)
	ui.preview = pv
	var ph := UIKit.hbox(10)
	pv.add_child(ph)
	ui.expr = UIKit.wrap(UIKit.label("", 14, UIKit.MUTED))
	ui.expr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.expr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ph.add_child(ui.expr)
	ui.tot = UIKit.title("0", 26, UIKit.INK)
	ph.add_child(ui.tot)
	root.add_child(pv)

	# açıklama satırı; sağ köşe masadaki kadeh ve kül tablası için boş bırakılır
	var irow := UIKit.hbox(0)
	ui.info = UIKit.rich("", 13, UIKit.MUTED)
	ui.info.custom_minimum_size.y = 34
	ui.info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	irow.add_child(ui.info)
	var corner := Control.new()
	corner.custom_minimum_size = Vector2(118, 0)
	irow.add_child(corner)
	ui.props_corner = corner
	root.add_child(irow)

	var hand := HandView.new()
	hand.custom_minimum_size = Vector2(0, 170)
	hand.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand.card_pressed.connect(_on_card)
	ui.hand = hand
	root.add_child(hand)

	var act := UIKit.hbox(12)
	ui.swap = UIKit.button("Değiştir")
	ui.swap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.swap.pressed.connect(func():
		if busy:
			return
		run.swap_cards()
		refresh())
	ui.play = UIKit.button("Oyna", true)
	ui.play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.play.size_flags_stretch_ratio = 1.4
	ui.play.pressed.connect(_do_play)
	act.add_child(ui.swap)
	act.add_child(ui.play)
	root.add_child(act)

	var piles := UIKit.hbox(10)
	ui.deck_icon = UIKit.panel(Color(UIKit.WOOD_2, 0.94), 8, 2, UIKit.GOLD_2)
	ui.deck_icon.custom_minimum_size = Vector2(34, 46)
	piles.add_child(ui.deck_icon)
	ui.draw_n = UIKit.label("", 13, UIKit.MUTED)
	ui.draw_n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	piles.add_child(ui.draw_n)
	ui.sort = UIKit.button("Sırala", false, true)
	ui.sort.pressed.connect(func():
		if busy:
			return
		run.sort_mode = "value" if run.sort_mode == "color" else "color"
		run.sort_hand()
		refresh())
	piles.add_child(ui.sort)
	ui.deck_btn = UIKit.button("Deste", false, true)
	ui.deck_btn.pressed.connect(func():
		if not busy and run.modal.is_empty():
			open_modal({"type": "deck"}))
	piles.add_child(ui.deck_btn)
	root.add_child(piles)

	content.add_child(props)   # ekranın üstünde, eldeki kartların altında
	await get_tree().process_frame
	_place_props()
	refresh()

## Masadaki eşyaları elin iki yanına yerleştirir
func _place_props() -> void:
	if not ui.has("props") or not ui.has("hand"):
		return
	ui.props.corner = ui.props_corner
	ui.props.pile = ui.draw_n

func _score_cell(caption: String, col: Color) -> PanelContainer:
	var p := UIKit.panel(col, 10, 2, UIKit.GOLD_2)
	p.custom_minimum_size = Vector2(64, 0)
	var v := UIKit.vbox(0)
	v.add_child(UIKit.label(caption, 9, Color(1, 1, 1, 0.85), UIKit.bold_font(), HORIZONTAL_ALIGNMENT_CENTER))
	var val := UIKit.title("0", 24, Color.WHITE)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(val)
	p.add_child(v)
	p.set_meta("val", val)
	return p

func _cell_val(p: PanelContainer) -> Label:
	return p.get_meta("val")

## Oyun ekranını durumdan yeniden çizer
func refresh(show_modal := true) -> void:
	if screen != "game" or run == null or ui.is_empty():
		return
	var C: Dictionary = Data.CLASSES[run.cls]
	# canlar
	for ch in ui.hearts.get_children():
		ch.queue_free()
	for i in RunState.MAX_LIVES:
		ui.hearts.add_child(UIKit.icon_rect("heart", 24, UIKit.HEART if i < run.lives else Color(1, 1, 1, 0.18)))
	ui.round.text = "KAT %d · TUR %d" % [ceili(run.round / 3.0), run.round]
	ui.gold.text = str(run.gold)

	# tılsımlar
	for ch in ui.charms.get_children():
		ch.queue_free()
	for i in RunState.MAX_CHARMS:
		if i < run.charms.size():
			var cv := CardView.new()
			cv.charm_id = run.charms[i].cid
			cv.charm_state = run.charms[i].state
			cv.mini = true
			cv.set_width(50)
			cv.selected = last_tap is String and last_tap == "c%d" % i
			var idx: int = i
			cv.pressed.connect(func(_v):
				last_tap = "c%d" % idx
				refresh())
			ui.charms.add_child(cv)
		else:
			var slot := Panel.new()
			var ss := UIKit.box(Color(0, 0, 0, 0.2), 6, 1, Color(1, 0.9, 0.64, 0.25))
			slot.add_theme_stylebox_override("panel", ss)
			slot.custom_minimum_size = Vector2(50, 70)
			ui.charms.add_child(slot)

	# kahraman ve güç
	for ch in ui.hero.get_children():
		ch.queue_free()
	var cc: Array = Data.CLASS_COLORS[run.cls]
	var por := UIKit.panel(cc[0], 31, 3, UIKit.GOLD_1)
	por.custom_minimum_size = Vector2(58, 58)
	por.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	por.add_child(UIKit.icon_rect(C.icon, 30, Color("fff8e0")))
	ui.portrait = por
	ui.hero.add_child(por)
	ui.hero.add_child(UIKit.label(C.name, 11, UIKit.GOLD_3, UIKit.title_font(), HORIZONTAL_ALIGNMENT_CENTER))
	var pb := UIKit.button(C.power.name, false, true)
	pb.add_theme_font_size_override("font_size", 11)
	var pbs := UIKit.box(cc[0], 16, 2, UIKit.GOLD_1, 3)
	pbs.content_margin_top = 4
	pbs.content_margin_bottom = 4
	pbs.content_margin_left = 8
	pbs.content_margin_right = 8
	pb.add_theme_stylebox_override("normal", pbs)
	pb.add_theme_color_override("font_color", Color.WHITE)
	pb.disabled = run.power_used or busy or not run.modal.is_empty()
	pb.tooltip_text = C.power.text
	pb.pressed.connect(_do_power)
	ui.power = pb
	ui.hero.add_child(pb)

	# hedef
	ui.target.text = str(run.target)
	if last_target >= 0 and last_target != run.target:
		ui.target.pivot_offset = ui.target.size / 2
		ui.target.scale = Vector2(1, 0.1)
		create_tween().tween_property(ui.target, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	last_target = run.target

	# sıradaki olay
	for ch in ui.omen.get_children():
		ch.queue_free()
	var ev: Dictionary = Data.EVENTS[run.next_event]
	var ec := _event_card(run.next_event, 46)
	ec.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ui.omen.add_child(ec)
	ui.omen.add_child(UIKit.label(ev.name, 11, UIKit.INK, UIKit.title_font(), HORIZONTAL_ALIGNMENT_CENTER))
	var dots := ""
	for i in run.event_every():
		dots += "● " if i < run.ev_count else "○ "
	ui.omen.add_child(UIKit.label(dots.strip_edges(), 12, UIKit.GOLD_2, null, HORIZONTAL_ALIGNMENT_CENTER))
	ui.omen.tooltip_text = "Sıradaki olay: %s. %s" % [ev.name, ev.hint]

	# skor paneli
	var rl: String = "Öğretici" if (not run.tut.is_empty() and run.round == 1) else RunState.ROUND_TYPES[run.rtype]
	if run.boss != "":
		rl += ": " + Data.BOSSES[run.boss].name
	ui.round_label.text = UIKit.upper(rl)
	ui.round_label.add_theme_color_override("font_color", Color("ff8a7a") if run.boss != "" else UIKit.MUTED)
	ui.goal.text = "/ %d" % run.goal
	if not busy:
		ui.rscore.text = str(run.round_score)
		ui.bar.value = float(run.round_score) / run.goal
		ui.dial.progress = ui.bar.value
	ui.plays.text = "OYNAMA  %d" % run.plays
	ui.discs.text = "DEĞİŞTİRME  %d" % run.discards
	var opts: Array = run.bet_options()
	for i in ui.bet_btns.size():
		var bb: Button = ui.bet_btns[i]
		bb.text = str(opts[i])
		bb.modulate = Color(1, 1, 1, 1.0 if i == run.bet_level else 0.45)
		bb.disabled = busy

	# etkiler ve mesaj
	var chips: Array = []
	if run.boss != "":
		chips.append("[color=#ff8a7a][b]%s:[/b] %s[/color]" % [Data.BOSSES[run.boss].name, Data.BOSSES[run.boss].text])
	for m in run.mods:
		chips.append("[color=#ffe7a3][b]%s ×2[/b] · %d oynama[/color]" % [Data.SUITS[m.color].name, m.turns])
	if run.tol_next > 0:
		chips.append("[color=#8cc2ff][b]Damıtma: ±1[/b][/color]")
	if run.shield:
		chips.append("[color=#8cc2ff][b]Kalkan aktif[/b][/color]")
	ui.mods.text = "   ".join(PackedStringArray(chips))
	ui.mods.visible = not chips.is_empty()
	ui.msg.text = run.msg
	ui.msg.add_theme_color_override("font_color", {"hit": UIKit.HIT, "miss": UIKit.MISS, "spell": Color("d9b8ff")}.get(run.msg_kind, UIKit.MUTED))

	# önizleme
	var sc := run.sel_cards()
	var spell_only := sc.size() == 1 and run.is_spell(sc[0])
	var prev: Dictionary = {}
	var pv_col := UIKit.GOLD_0
	if sc.is_empty():
		ui.expr.text = "Kart seç, toplamı hedefe eşitle."
		ui.tot.text = "0"
		ui.tot.add_theme_color_override("font_color", UIKit.INK)
	elif spell_only:
		ui.expr.text = "Hamle: " + run.T(sc[0]).text
		ui.tot.text = "✦"
		pv_col = UIKit.SPELL
	elif sc.any(run.is_spell):
		ui.expr.text = "Hamle kartları tek başına kullanılır."
		ui.tot.text = "–"
	else:
		var r := run.evaluate(sc)
		if r.hit:
			prev = run.score_play(sc, true)
		var e: String = r.expr
		if run.is_combo(sc):
			e += "\nRenk serisi: +1 oran"
		if r.tol > 0:
			e += "\nTolerans ±%d" % r.tol
		ui.expr.text = e
		ui.tot.text = str(r.total)
		ui.tot.add_theme_color_override("font_color", UIKit.HIT if r.hit else (UIKit.MISS if r.total > run.target else UIKit.INK))
		if r.hit:
			pv_col = UIKit.HIT
	ui.preview.add_theme_stylebox_override("panel", UIKit.box(Color(0, 0, 0, 0.4), 14, 2, pv_col))
	if not busy:
		# isabet önizlemesi varsa onun oranı, yoksa seçili kart sayısının temel oranı
		_cell_val(ui.chips_box).text = str(run.bet())
		var odds: float = prev.get("mult", 0.0) if not prev.is_empty() else (float(RunState.base_odds(sc.size())) if not sc.is_empty() and not sc.any(run.is_spell) else 0.0)
		_cell_val(ui.mult_box).text = (RunState.fmt_mult(odds) + ":1") if odds > 0 else "–"
		ui.scorebox.modulate.a = 1.0 if not prev.is_empty() else 0.75

	# bilgi satırı
	var info := "Kartlara dokunarak seç. Seçtiğin kartın açıklaması burada görünür."
	if last_tap is String and int(last_tap.substr(1)) < run.charms.size():
		var ch: Dictionary = run.charms[int(last_tap.substr(1))]
		var d: Dictionary = Data.CHARM[ch.cid]
		info = "[b][color=#ffe7a3]%s[/color][/b] [color=#%s]%s eşya[/color]\n%s" % [d.name, Data.RARITY[d.rarity].color.to_html(false), Data.RARITY[d.rarity].name, d.text]
	else:
		var ic = null
		if last_tap is int:
			for c in run.hand:
				if c.uid == last_tap:
					ic = c
		if ic == null and not sc.is_empty():
			ic = sc[-1]
		if ic != null:
			var t := run.T(ic)
			var cls_txt: String = (" · " + Data.CLASSES[t.cls].name) if Data.CLASSES.has(t.cls) else ""
			info = "[b][color=#ffe7a3]%s[/color][/b] [color=#%s]%s%s[/color]\n%s" % [run.card_name(ic), Data.RARITY[t.rarity].color.to_html(false), Data.RARITY[t.rarity].name, cls_txt, t.text]
	ui.info.text = info

	# el
	ui.hand.deck_global = ui.deck_icon.get_global_rect().get_center()
	ui.hand.sync(run)

	ui.play.text = "Kullan" if spell_only else "Oyna (%d)" % run.plays
	ui.play.disabled = busy or sc.is_empty() or (sc.any(run.is_spell) and not spell_only) or (not spell_only and run.plays <= 0)
	ui.swap.text = "Değiştir (%d)" % run.discards
	ui.swap.disabled = busy or sc.is_empty() or run.discards <= 0
	ui.sort.text = "Sırala: Renk" if run.sort_mode == "color" else "Sırala: Değer"
	ui.draw_n.text = "Çekme %d" % run.draw.size()
	ui.deck_btn.text = "Deste (%d)" % run.master.size()

	_play_fx()
	if show_modal and not busy:
		_render_modal()
	_render_coach()

func _event_card(id: String, w: float) -> PanelContainer:
	var ev: Dictionary = Data.EVENTS[id]
	var col: Color = {"good": UIKit.HIT, "bad": UIKit.MISS}.get(ev.tone, UIKit.GOLD_2)
	var p := UIKit.panel(Color(UIKit.WOOD_2, 0.94), int(w * 0.2), 2, col)
	p.custom_minimum_size = Vector2(w, w * 1.4)
	p.add_child(UIKit.icon_rect(ev.icon, int(w * 0.55), col))
	return p

# ───────── Eylemler ─────────
func _on_card(card_uid: int) -> void:
	if busy or not run.modal.is_empty():
		return
	last_tap = card_uid
	Sfx.play("select", 1.1 if card_uid in run.sel else 0.95)
	run.toggle(card_uid)
	refresh()

func _do_power() -> void:
	if busy:
		return
	run.use_power()
	refresh()

func _do_play() -> void:
	if busy or run.sel.is_empty() or not run.modal.is_empty():
		return
	var sc := run.sel_cards()
	var spell := sc.size() == 1 and run.is_spell(sc[0])
	if sc.any(run.is_spell) and not spell:
		run.play()
		refresh()
		return
	if run.boss == "silence" and spell:
		run.play()
		refresh()
		return
	var views: Array = ui.hand.detach(run.sel.duplicate())
	for v in views:
		v.reparent(fx_layer, true)
		v.selected = false
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	run.play()
	busy = true
	refresh(false)
	if spell:
		await _animate_spell(views)
	else:
		await _animate_play(views, run.last_play)
	busy = false
	refresh()

func _animate_spell(views: Array) -> void:
	var center := get_viewport_rect().size * Vector2(0.5, 0.42)
	var col := Color("c1a2ff")
	for v in views:
		var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(v, "global_position", center - v.size / 2, 0.45)
		tw.tween_property(v, "rotation", 0.0, 0.45)
		tw.tween_property(v, "scale", Vector2(1.9, 1.9), 0.45)
		await tw.finished
		var t2 := create_tween().set_parallel(true)
		t2.tween_property(v, "scale", Vector2(2.3, 2.3), 0.3)
		t2.tween_property(v, "modulate", Color(3, 3, 3, 0), 0.3)
		ring(center, col, 140)
		burst(center, [col, Color.WHITE], 50, 340, 0)
		Sfx.play("spell")
		await t2.finished
		v.queue_free()

func _animate_play(views: Array, lp: Dictionary) -> void:
	var by_uid := {}
	for v in views:
		by_uid[v.uid()] = v
	# 1. kartlar elden masanın ortasına, çuhanın üstüne atılır: biraz yamuk,
	# hafif üst üste, her biri "şap" diye yere oturur
	var zone: Rect2 = ui.preview.get_global_rect()
	var n := views.size()
	var w := minf(76.0, (zone.size.x + 10 * (n - 1)) / maxf(1, n))
	var step := w - 10.0
	var total := (n - 1) * step + w
	var cy := zone.get_center().y - 14
	for i in n:
		var v: CardView = views[i]
		var s := w / v.size.x
		var c := Vector2(zone.get_center().x - total / 2 + i * step + w / 2, cy + randf_range(-6, 6))
		var rot := randf_range(-0.14, 0.14)
		v.z_index = 60 + i
		var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(v, "global_position", c - v.size / 2, 0.22)
		tw.tween_property(v, "rotation", rot, 0.22)
		tw.tween_property(v, "scale", Vector2(s * 1.18, s * 1.18), 0.22)
		Sfx.play("whoosh", 1.0 + i * 0.05)
		await tw.finished
		var land := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		land.tween_property(v, "scale", Vector2(s, s), 0.12)
		Sfx.play("chip", 0.7)
	await get_tree().create_timer(0.12).timeout
	var dial_c: Vector2 = ui.dial.get_global_rect().get_center()

	if not lp.get("hit", false):
		await get_tree().create_timer(0.25).timeout
		floater("Iska", dial_c + Vector2(0, -60), UIKit.MISS)
		if int(lp.get("bet", 0)) > 0:
			floater("−%d fiş" % int(lp.bet), ui.scorebox.get_global_rect().get_center() + Vector2(0, -36), UIKit.MISS, 24)
		Sfx.play("miss")
		flash(Color(1, 0.2, 0.15, 0.35))
		var t2 := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		for i in n:
			var v: CardView = views[i]
			t2.tween_property(v, "global_position:y", get_viewport_rect().size.y + 40, 0.6).set_delay(i * 0.05)
			t2.tween_property(v, "rotation", (i - n / 2.0) * 0.6, 0.6).set_delay(i * 0.05)
			t2.tween_property(v, "modulate:a", 0.3, 0.6).set_delay(i * 0.05)
		await t2.finished
		for v in views:
			v.queue_free()
		return

	# 2. bahis ve oran adım adım kurulur
	var sc: Dictionary = lp.score
	var chips_l := _cell_val(ui.chips_box)
	var mult_l := _cell_val(ui.mult_box)
	ui.scorebox.modulate.a = 1.0
	var i := 0
	for s in sc.steps:
		chips_l.text = str(s.chips)
		mult_l.text = RunState.fmt_mult(s.mult) + ":1"
		pop(ui.chips_box if s.kind == "chips" else ui.mult_box, 1.25)
		match s.kind:
			"chips": Sfx.play("chip", 1.0 + i * 0.06)
			"mult": Sfx.play("mult", 1.0 + i * 0.03)
			_: Sfx.play("xmult")
		var src: Control = null
		match s.src.t:
			"card":
				src = by_uid.get(s.src.uid)
			"charm":
				var idx: int = s.src.i
				if idx < ui.charms.get_child_count():
					src = ui.charms.get_child(idx)
			"dial":
				src = ui.dial
			_:
				src = ui.scorebox
		if src:
			pop(src, 1.18)
			floater(s.label, src.get_global_rect().get_center() + Vector2(0, -30), UIKit.GOLD_3 if s.kind == "chips" else Color("ffb3a8"), 15)
		i += 1
		await get_tree().create_timer(maxf(0.14, 0.3 - i * 0.018)).timeout

	# 3. kazanç, kartlar hedefe uçar
	pop(ui.scorebox, 1.15)
	floater("+%d fiş" % sc.total, ui.scorebox.get_global_rect().get_center() + Vector2(0, -36), Color.WHITE, 30)
	Sfx.play("coin")
	await get_tree().create_timer(0.3).timeout
	var t3 := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	for j in n:
		var v: CardView = views[j]
		t3.tween_property(v, "global_position", dial_c - v.size / 2, 0.38).set_delay(j * 0.04)
		t3.tween_property(v, "scale", Vector2(0.2, 0.2), 0.38).set_delay(j * 0.04)
		t3.tween_property(v, "modulate:a", 0.2, 0.38).set_delay(j * 0.04)
	await t3.finished
	for v in views:
		v.queue_free()
	Sfx.play("hit", 1.12 if sc.combo else 1.0)
	ring(dial_c, Color("ffd25a") if sc.combo else UIKit.GOLD_3, 130)
	burst(dial_c, [UIKit.GOLD_3, UIKit.GOLD_2, UIKit.HIT, Color("ff5a4b"), Color("4b8dff")], 110 if sc.combo else 60)
	floater("Renk Serisi!" if sc.combo else "İsabet!", dial_c + Vector2(0, -74), UIKit.GOLD_3, 28)
	shake(ui.arena)
	ui.rscore.text = str(run.round_score)
	pop(ui.rscore, 1.3)
	var bt := create_tween().set_parallel(true)
	bt.tween_property(ui.bar, "value", float(run.round_score) / run.goal, 0.5)
	bt.tween_property(ui.dial, "progress", minf(1.0, float(run.round_score) / run.goal), 0.5)
	await get_tree().create_timer(0.45).timeout

## Kural motorunun kuyruğa koyduğu efektleri oynatır
func _play_fx() -> void:
	if busy:
		return
	var q := run.fx
	run.fx = []
	var vp := get_viewport_rect().size
	var scenes: Array = []
	for f in q:
		match f.type:
			"round":
				Sfx.play("fanfare")
				banner("Masa Kazanıldı", "+%d / %d fiş" % [run.round_score, run.goal])
				burst(vp * Vector2(0.5, 0.4), [UIKit.GOLD_3, UIKit.GOLD_2, UIKit.HIT, UIKit.SPELL, Color("4b8dff"), Color("ff5a4b")], 140, 600)
			"boss":
				Sfx.play("boss")
				banner(Data.BOSSES[run.boss].name, Data.BOSSES[run.boss].text)
				flash(Color(1, 0.15, 0.15, 0.4))
			"life_lost":
				Sfx.play("life_lost")
				flash(Color(1, 0.1, 0.2, 0.6))
				shake(content)
			"shield":
				Sfx.play("shield")
				flash(Color(0.4, 0.7, 1, 0.5))
			"heal":
				Sfx.play("heal")
				if ui.has("hearts"):
					burst(ui.hearts.get_global_rect().get_center(), [UIKit.HEART, Color("ff9aa9")], 24, 200, 0)
			"power":
				Sfx.play("power")
				if ui.has("portrait"):
					var pc: Vector2 = ui.portrait.get_global_rect().get_center()
					ring(pc, Data.CLASS_COLORS[run.cls][0].lightened(0.4), 70)
					burst(pc, [Data.CLASS_COLORS[run.cls][0].lightened(0.4), Color.WHITE], 30, 220, 0)
					floater(f.name, pc + Vector2(30, -40), Color("d9b8ff"), 18)
			"spell":
				floater(f.name, vp * Vector2(0.5, 0.42) + Vector2(0, -90), Color("ecd6ff"), 26)
			"event":
				Sfx.play({"good": "event_good", "bad": "event_bad"}.get(f.tone, "event"))
				var col: Color = {"good": UIKit.HIT, "bad": UIKit.MISS}.get(f.tone, UIKit.GOLD_2)
				burst(vp * Vector2(0.5, 0.35), [col, Color.WHITE], 40, 300, 0)
				if f.tone == "bad":
					flash(Color(1, 0.3, 0.2, 0.3))
			"buy":
				Sfx.play("coin")
			"loan":
				Sfx.play("event_bad")
				banner("Kasadan Borç", "+%d fiş · destene bir Senet girdi" % int(f.amount))
			"scene":
				scenes.append(f)
	for f in scenes:
		await _story_scene(f)

# ───────── Pencereler ─────────
func open_modal(m: Dictionary) -> void:
	if screen == "game" and run:
		run.modal = m
		refresh()
	else:
		_show_sheet(m)

func _close_ui_modal() -> void:
	overlay.visible = false
	for ch in overlay.get_children():
		ch.queue_free()

func _render_modal() -> void:
	if run == null or run.modal.is_empty():
		if screen == "game":
			_close_ui_modal()
		return
	_show_sheet(run.modal)

func _show_sheet(m: Dictionary) -> void:
	for ch in overlay.get_children():
		ch.queue_free()
	overlay.visible = true
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.01, 0.8)
	_full(dim)
	overlay.add_child(dim)
	var safe := _safe()
	var mc := MarginContainer.new()
	_full(mc)
	mc.add_theme_constant_override("margin_left", 12)
	mc.add_theme_constant_override("margin_right", 12)
	mc.add_theme_constant_override("margin_top", int(safe.top) + 8)
	mc.add_theme_constant_override("margin_bottom", int(safe.bottom) + 8)
	overlay.add_child(mc)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mc.add_child(scroll)
	var col := UIKit.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	var top_sp := Control.new()
	top_sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(top_sp)
	var sheet := PanelContainer.new()
	var ss := UIKit.frame(Color(UIKit.WOOD_2, 0.94), UIKit.GOLD_2, 16.0, true)
	ss.shadow_size = 18
	ss.content_margin_left = 16
	ss.content_margin_right = 16
	ss.content_margin_top = 18
	ss.content_margin_bottom = 18
	sheet.add_theme_stylebox_override("panel", ss)
	sheet.custom_minimum_size.x = minf(440, get_viewport_rect().size.x - 24)
	sheet.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(sheet)
	var bot_sp := Control.new()
	bot_sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(bot_sp)
	var v := UIKit.vbox(12)
	sheet.add_child(v)
	_fill_sheet(v, m)
	sheet.pivot_offset = Vector2(sheet.custom_minimum_size.x / 2, 100)
	sheet.scale = Vector2(0.92, 0.92)
	create_tween().tween_property(sheet, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _eyebrow(v: VBoxContainer, text: String, head: String) -> void:
	v.add_child(UIKit.label(UIKit.upper(text), 11, UIKit.GOLD_2, UIKit.caps_font()))
	v.add_child(UIKit.wrap(UIKit.title(head, 25)))

func _para(v: VBoxContainer, text: String, col := Color("e3d5b8")) -> void:
	v.add_child(UIKit.wrap(UIKit.label(text, 15, col)))

func _btn(v: Container, text: String, gold: bool, cb: Callable, small := false) -> Button:
	var b := UIKit.button(text, gold, small)
	b.pressed.connect(cb)
	v.add_child(b)
	return b

func _card_view(c: Dictionary, w := 94.0, is_mini := false) -> CardView:
	var cv := CardView.new()
	cv.card = c
	cv.mini = is_mini
	cv.set_width(w)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return cv

func _fill_sheet(v: VBoxContainer, m: Dictionary) -> void:
	match m.type:
		"howto":
			_eyebrow(v, "Kurallar", "Nasıl Oynanır")
			for line in [
				"Elinden kart seç. Toplamları [b]hedefe tam eşit[/b] olsun ve [b]Oyna[/b]'ya bas.",
				"Her oynamadan önce [b]bahsini[/b] seç: masa minimumunun 1, 2 ya da 4 katı.",
				"İsabette masa [b]bahis × oran[/b] kadar fiş öder. Oran kart sayısına bağlı: 1 kart 4:1, 2 kart 3:1, 3 kart 2:1, daha fazlası 1:1. Renk serisi ve eşyalar oranı artırır. Iskada bahsin gider.",
				"Oynama hakların bitmeden masadan [b]hedef kadar net fiş[/b] kazan. Kazanamazsan 1 can gider. 2 canla başlarsın, en fazla 4 olur.",
				"Fişin masa minimumunun altına düşerse kasa borç verir, ama destene bir [b]Senet[/b] girer.",
				"Her kat 3 turdur: Küçük Masa, Büyük Masa ve özel kurallı [b]Engel[/b].",
				"Fiş hem paran hem skorun. Tur sonunda ödül alırsın. [b]Tüccarda[/b] fişle kart, eşya ve güçlendirme alırsın. [b]Eşyalar[/b] (en fazla 5) kalıcı bonus verir.",
				"Başta kartların çoğu [b]kilitlidir[/b]. Turları geçtikçe ve başarımlarla yenileri açılır.",
				"Nadirlik: [color=#ece7db]beyaz[/color] Sıradan, [color=#4b8dff]mavi[/color] Nadir, [color=#b066ff]mor[/color] Ender, [color=#f5c518]sarı[/color] Efsanevi, [color=#ff3b3b]kırmızı[/color] Epik."]:
				v.add_child(UIKit.rich("• " + line, 15, Color("e3d5b8")))
			_btn(v, "Anladım", true, _close_ui_or_modal)
		"settings":
			_eyebrow(v, "Tercihler", "Ayarlar")
			var snd := UIKit.button(_sound_label())
			snd.pressed.connect(func(): snd.text = _toggle_sound())
			v.add_child(snd)
			_btn(v, "Nasıl Oynanır", false, func(): _show_sheet({"type": "howto"}))
			_btn(v, "Kapat", true, _close_ui_or_modal)
		"achievements":
			_eyebrow(v, "%d/%d tamamlandı" % [Progress.p.ach.size(), Data.ACHIEVEMENTS.size()], "Başarımlar")
			for a in Data.ACHIEVEMENTS:
				var done: bool = a.id in Progress.p.ach
				var row := UIKit.panel(Color(0, 0, 0, 0.3), 12)
				var h := UIKit.hbox(12)
				var ic := UIKit.panel(Color("f5c518") if done else Color("2a2a33"), 19)
				ic.custom_minimum_size = Vector2(38, 38)
				ic.add_child(UIKit.icon_rect(a.icon if done else "lock", 22, Color("3a2306") if done else Color("8a8478")))
				h.add_child(ic)
				var tv := UIKit.vbox(0)
				tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				tv.add_child(UIKit.label(a.name, 15, UIKit.GOLD_3 if done else Color("e8dcc2"), UIKit.title_font()))
				tv.add_child(UIKit.wrap(UIKit.label(a.text, 13, Color("cfc2a6"))))
				var rew: Array = []
				for u in a.unlocks:
					rew.append((Data.CLASSES[u.substr(6)].name + " karakteri") if u.begins_with("class:") else (Data.CARD[u].name if Data.CARD.has(u) else Data.CHARM[u].name))
				tv.add_child(UIKit.wrap(UIKit.label("Ödül: " + ", ".join(PackedStringArray(rew)), 12, UIKit.MUTED)))
				h.add_child(tv)
				row.add_child(h)
				v.add_child(row)
			_para(v, "Ayrıca her geçtiğin tur, sıradaki kilitli kartı ya da eşyayı açar.", UIKit.MUTED)
			_btn(v, "Kapat", true, _close_ui_or_modal)
		"event":
			var ev: Dictionary = Data.EVENTS[m.id]
			_eyebrow(v, "Olay", ev.name)
			var row := UIKit.hbox(14)
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_child(_event_card(m.id, 96))
			if m.has("card"):
				row.add_child(_card_view(m.card, 100))
			v.add_child(row)
			_para(v, m.text)
			_para(v, "Sıradaki olay: " + Data.EVENTS[run.next_event].name, UIKit.MUTED)
			_btn(v, "Devam", true, func():
				run.close_modal()
				refresh())
		"prophecy":
			_eyebrow(v, "Sahne", "Olayı seç")
			_para(v, "Sıradaki olay %s. Yerine hangisi gelsin?" % Data.EVENTS[run.next_event].name)
			var row := UIKit.hbox(12)
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			for id in m.options:
				var b := VBoxContainer.new()
				b.add_child(_event_card(id, 70))
				var ob := UIKit.button(Data.EVENTS[id].name, false, true)
				ob.pressed.connect(func():
					run.choose_prophecy(id)
					refresh())
				b.add_child(ob)
				b.add_child(UIKit.wrap(UIKit.label(Data.EVENTS[id].hint, 12, UIKit.MUTED, null, HORIZONTAL_ALIGNMENT_CENTER)))
				b.custom_minimum_size.x = 140
				row.add_child(b)
			v.add_child(row)
			var on_cancel := func():
				run.modal = {}
				refresh()
			_btn(v, "Vazgeç", false, on_cancel, true)
		"cashout":
			_eyebrow(v, "%s kazanıldı · +%d/%d fiş" % [RunState.ROUND_TYPES[run.rtype], run.round_score, run.goal], "Ganimet")
			var box := UIKit.panel(Color(0, 0, 0, 0.3), 12)
			var bv := UIKit.vbox(6)
			for l in m.lines:
				var h := UIKit.hbox(8)
				var a := UIKit.label(l[0], 15, Color("e3d5b8"))
				a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				h.add_child(a)
				h.add_child(UIKit.label("+%d" % l[1], 15, UIKit.GOLD_3, UIKit.title_font()))
				bv.add_child(h)
			var th := UIKit.hbox(8)
			var ta := UIKit.label("Toplam", 17, UIKit.INK, UIKit.bold_font())
			ta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			th.add_child(ta)
			th.add_child(UIKit.icon_rect("coin", 22, Color("f5c518")))
			th.add_child(UIKit.title("+%d" % m.total, 20, Color("f5c518")))
			bv.add_child(th)
			box.add_child(bv)
			v.add_child(box)
			_btn(v, "Tüccara git", true, func():
				run.open_shop()
				refresh())
		"shop":
			_fill_shop(v)
		"remove":
			_eyebrow(v, "Desteni incelt · %d fiş" % run.remove_cost(), "Hangi kart gitsin?")
			_para(v, "Destende %d kart var. Dokunduğun kart kalıcı olarak çıkar." % run.master.size())
			var on_remove := func(c):
				run.remove_card_paid(c.uid)
				run.modal = {"type": "shop"}
				refresh()
			v.add_child(_card_grid(run.master, on_remove, true))
			var on_back := func():
				run.modal = {"type": "shop"}
				refresh()
			_btn(v, "Geri", false, on_back, true)
		"deck":
			_eyebrow(v, "Nadirliğe göre sıralı", "Destende %d kart" % run.master.size())
			_para(v, "Çekme destesinde %d, ıskartada %d, elinde %d kart var." % [run.draw.size(), run.discard.size(), run.hand.size()])
			v.add_child(_card_grid(run.master, Callable(), false))
			_btn(v, "Kapat", true, func():
				run.modal = {}
				refresh())
		"life":
			if m.get("shielded", false):
				_eyebrow(v, "Altın Kalkan kırıldı" if m.get("broke", false) else "Kalkan seni korudu", "Can kaybı yok")
				_para(v, "Tur hedefine ulaşamadın ama canın gitmedi. Tur %d yeni kartlarla baştan başlayacak." % run.round)
			else:
				_eyebrow(v, "Oynama hakkın bitti", "Bir can gitti")
				_para(v, "%d fişlik masa hedefinin %d kadarını kazandın. %d canın kaldı. Tur %d yeni kartlarla baştan başlayacak." % [run.goal, run.round_score, run.lives, run.round])
			_btn(v, "Turu yeniden dene", true, func():
				run.retry_round()
				refresh())
		"over":
			_eyebrow(v, "Canın kalmadı", "Oyun bitti")
			_para(v, "%s olarak %d. kattaki %d. tura kadar geldin. Toplam kazanç: %d fiş. Rekor: %d." % [Data.CLASSES[run.cls].name, ceili(run.round / 3.0), run.round, run.score, Progress.best])
			_para(v, "Açtığın kartlar ve başarımlar kalıcı.", UIKit.MUTED)
			var cls := run.cls
			_btn(v, "Aynı karakterle yeniden oyna", true, func(): start_run(cls))
			_btn(v, "Ana menü", false, func():
				run = null
				show_splash())
		"pause":
			_eyebrow(v, "%s · Tur %d" % [Data.CLASSES[run.cls].name, run.round], "Duraklatıldı")
			_btn(v, "Devam et", true, func():
				run.modal = {}
				refresh())
			_btn(v, "Nasıl oynanır", false, func(): _show_sheet({"type": "howto"}))
			var snd := UIKit.button(_sound_label())
			snd.pressed.connect(func(): snd.text = _toggle_sound())
			v.add_child(snd)
			_btn(v, "Ana menü", false, func():
				run.modal = {}
				show_splash())
			var cls := run.cls
			_btn(v, "Yeni oyun başlat", false, func(): start_run(cls))

func _close_ui_or_modal() -> void:
	if screen == "game" and run and not run.modal.is_empty() and run.modal.type in ["howto", "achievements", "settings"]:
		run.modal = {}
		refresh()
	elif screen == "game" and run and not run.modal.is_empty():
		_render_modal()
	else:
		_close_ui_modal()

func _card_grid(cards: Array, cb: Callable, clickable: bool) -> Control:
	var sorted := cards.duplicate()
	sorted.sort_custom(func(a, b): return Data.by_rarity(run.T(a), run.T(b)))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 8)
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	for c in sorted:
		var cv := CardView.new()
		cv.card = c
		cv.mini = true
		cv.set_width(56)
		if clickable:
			cv.pressed.connect(func(_v): cb.call(c))
		else:
			cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flow.add_child(cv)
	return flow

func _price_button(price: int, can: bool, cb: Callable, label := "") -> Button:
	var b := UIKit.button(label if label != "" else "%d fiş" % price, true, true)
	b.add_theme_font_size_override("font_size", 13)
	b.disabled = not can
	b.pressed.connect(cb)
	return b

func _ware(view: Control, btn: Control) -> VBoxContainer:
	var w := UIKit.vbox(6)
	view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	w.add_child(view)
	w.add_child(btn)
	return w

func _fill_shop(v: VBoxContainer) -> void:
	var sh := run.shop
	var head := UIKit.hbox(8)
	var hv := UIKit.vbox(2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nxt: String = ["small", "big", "boss"][run.round % 3]
	hv.add_child(UIKit.label(UIKit.upper("Kat %d · Sıradaki: %s" % [ceili((run.round + 1) / 3.0), RunState.ROUND_TYPES[nxt]]), 11, UIKit.GOLD_2, UIKit.caps_font()))
	hv.add_child(UIKit.title("Tüccar", 25))
	head.add_child(hv)
	head.add_child(UIKit.icon_rect("coin", 26, Color("f5c518")))
	head.add_child(UIKit.title(str(run.gold), 26, Color("f5c518")))
	v.add_child(head)

	var cw := minf(94.0, (sheet_width() - 52) / 3.0)
	v.add_child(UIKit.label("KARTLAR", 13, UIKit.GOLD_2, UIKit.title_font()))
	var row := UIKit.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in sh.cards.size():
		var o: Dictionary = sh.cards[i]
		var cv := _card_view(o.c, cw)
		cv.dimmed = o.sold
		var p := run.card_price(o.c)
		var idx: int = i
		var b: Control = UIKit.label("Alındı", 12, UIKit.MUTED, null, HORIZONTAL_ALIGNMENT_CENTER) if o.sold else _price_button(p, run.gold >= p, func():
			run.buy("card", idx)
			refresh())
		row.add_child(_ware(cv, b))
	v.add_child(row)

	v.add_child(UIKit.label("EŞYALAR · %d/%d YUVA" % [run.charms.size(), RunState.MAX_CHARMS], 13, UIKit.GOLD_2, UIKit.title_font()))
	var row2 := UIKit.hbox(10)
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	var full := run.charms.size() >= RunState.MAX_CHARMS
	for i in sh.charms.size():
		var o: Dictionary = sh.charms[i]
		var cv := CardView.new()
		cv.charm_id = o.id
		cv.set_width(cw)
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.dimmed = o.sold
		var p := run.charm_price(o.id)
		var idx: int = i
		var on_buy := func():
			run.buy("charm", idx)
			refresh()
		var b: Control = UIKit.label("Takıldı", 12, UIKit.MUTED, null, HORIZONTAL_ALIGNMENT_CENTER) if o.sold else _price_button(p, run.gold >= p and not full, on_buy, "Yuva dolu" if full else "")
		row2.add_child(_ware(cv, b))
	var pk: Dictionary = sh.perk
	var pv := CardView.new()
	pv.perk = RunState.PERKS[pk.k]
	pv.set_width(cw)
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv.dimmed = pk.sold
	var pp := run.price_of(RunState.PERKS[pk.k].price)
	var pb: Control = UIKit.label("Alındı", 12, UIKit.MUTED, null, HORIZONTAL_ALIGNMENT_CENTER) if pk.sold else _price_button(pp, run.gold >= pp, func():
		run.buy("perk", 0)
		refresh())
	row2.add_child(_ware(pv, pb))
	v.add_child(row2)

	if not run.charms.is_empty():
		v.add_child(UIKit.label("EŞYALARIN", 13, UIKit.GOLD_2, UIKit.title_font()))
		var row3 := UIKit.hbox(8)
		row3.alignment = BoxContainer.ALIGNMENT_CENTER
		for i in run.charms.size():
			var cv := CardView.new()
			cv.charm_id = run.charms[i].cid
			cv.charm_state = run.charms[i].state
			cv.mini = true
			cv.set_width(52)
			cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var idx: int = i
			var sb := UIKit.button("Sat +%d" % run.charm_sell_price(run.charms[i].cid), false, true)
			sb.add_theme_font_size_override("font_size", 11)
			sb.pressed.connect(func():
				Sfx.play("coin", 0.85)
				run.sell_charm(idx)
				refresh())
			row3.add_child(_ware(cv, sb))
		v.add_child(row3)

	var br := UIKit.hbox(10)
	var on_reroll := func():
		run.reroll()
		refresh()
	var rr := _btn(br, "Yenile · %d" % sh.reroll_cost, false, on_reroll, true)
	rr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rr.disabled = run.gold < sh.reroll_cost
	var on_rm := func():
		run.modal = {"type": "remove"}
		refresh()
	var rm := _btn(br, "Kart çıkar · %d" % run.remove_cost(), false, on_rm, true)
	rm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rm.disabled = sh.removed or run.gold < run.remove_cost() or run.master.size() <= 12
	v.add_child(br)
	_btn(v, "Sonraki tura geç", true, func():
		run.next_round()
		refresh())

func sheet_width() -> float:
	return minf(440, get_viewport_rect().size.x - 24) - 32

# ───────── Öğretici balonu ─────────
func _render_coach() -> void:
	var st: Dictionary = run.tut_step() if (run and screen == "game") else {}
	var visible_now: bool = not st.is_empty() and not busy and ((st.get("when", "") == "shop" and run.modal.get("type", "") == "shop") or (st.get("when", "") == "" and run.modal.is_empty()))
	focus_frame.visible = false
	if not visible_now:
		coach.visible = false
		return
	for ch in coach.get_children():
		ch.queue_free()
	var ps := UIKit.frame(UIKit.PARCH, UIKit.GOLD_1, 10.0, true)
	ps.inner_color = Color(UIKit.GOLD_1, 0.5)
	ps.content_margin_left = 14
	ps.content_margin_right = 14
	coach.add_theme_stylebox_override("panel", ps)
	var v := UIKit.vbox(6)
	coach.add_child(v)
	v.add_child(UIKit.label("ÖĞRETİCİ · %d/%d" % [run.tut.step + 1, RunState.TUT.size()], 11, Color("7a5a2a"), UIKit.title_font()))
	v.add_child(UIKit.rich(st.text.replace("[b]", "[b][color=#7a2a06]").replace("[/b]", "[/color][/b]"), 15, UIKit.PARCH_INK))
	var h := UIKit.hbox(10)
	var skip := LinkButton.new()
	skip.text = "Öğreticiyi atla"
	skip.add_theme_color_override("font_color", Color("7a5a2a"))
	skip.pressed.connect(func():
		run.end_tutorial()
		refresh())
	skip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(skip)
	if st.get("next", false):
		var on_next := func():
			run.tut_advance()
			refresh()
		_btn(h, "Devam", true, on_next, true)
	v.add_child(h)
	var vp := get_viewport_rect().size
	var safe := _safe()
	coach.visible = true
	coach.size = Vector2.ZERO
	coach.custom_minimum_size = Vector2(minf(460, vp.x - 24), 0)
	await get_tree().process_frame
	if not is_instance_valid(coach) or not coach.visible:
		return
	coach.reset_size()
	await get_tree().process_frame
	coach.reset_size()
	var y: float = (vp.y - coach.size.y - safe.bottom - 8) if st.get("when", "") == "shop" else safe.top + 6
	coach.position = Vector2((vp.x - coach.size.x) / 2, y)
	var key: String = st.get("focus", "")
	var target_map := {"dial": "dial", "hand": "hand", "play": "play", "score": "scorepanel", "swap": "swap", "power": "power", "omen": "omen"}
	if key != "" and target_map.has(key) and ui.has(target_map[key]):
		var r: Rect2 = ui[target_map[key]].get_global_rect().grow(5)
		focus_frame.position = r.position
		focus_frame.size = r.size
		focus_frame.visible = true

# ───────── Bildirimler (ekranın altında) ─────────
func _on_toast(info: Dictionary) -> void:
	toast_queue.append(info)
	if not toast_busy:
		_next_toast()

func _next_toast() -> void:
	if toast_queue.is_empty():
		toast_busy = false
		return
	toast_busy = true
	var t: Dictionary = toast_queue.pop_front()
	var eyebrow := ""
	var head := ""
	var sub := ""
	var pic: Control
	match t.kind:
		"ach":
			var a: Dictionary = {}
			for x in Data.ACHIEVEMENTS:
				if x.id == t.id:
					a = x
			eyebrow = "BAŞARIM AÇILDI"
			head = a.name
			sub = a.text
			pic = UIKit.panel(Color("f5c518"), 23, 2, UIKit.OUTLINE)
			pic.custom_minimum_size = Vector2(46, 46)
			pic.add_child(UIKit.icon_rect(a.icon, 26, Color("3a2306")))
		"class":
			var C: Dictionary = Data.CLASSES[t.id]
			eyebrow = "YENİ KARAKTER AÇILDI"
			head = C.name
			sub = C.tagline
			pic = UIKit.panel(Data.CLASS_COLORS[t.id][0], 23, 2, UIKit.GOLD_1)
			pic.custom_minimum_size = Vector2(46, 46)
			pic.add_child(UIKit.icon_rect(C.icon, 26, Color.WHITE))
		"charm":
			var c: Dictionary = Data.CHARM[t.id]
			eyebrow = "YENİ EŞYA AÇILDI"
			head = c.name
			sub = "%s · %s" % [Data.RARITY[c.rarity].name, c.text]
			var cv := CardView.new()
			cv.charm_id = t.id
			cv.mini = true
			cv.set_width(34)
			pic = cv
		_:
			var c: Dictionary = Data.CARD[t.id]
			eyebrow = "YENİ KART AÇILDI"
			head = c.name
			sub = "%s · %s" % [Data.RARITY[c.rarity].name, c.text]
			pic = _card_view({"tid": t.id}, 34, true)
	var p := PanelContainer.new()
	var ps := UIKit.frame(Color(UIKit.WOOD_2, 0.94), UIKit.GOLD_2 if t.kind == "ach" else UIKit.GOLD_1, 12.0, t.kind == "ach")
	ps.content_margin_left = 10
	ps.content_margin_right = 16
	p.add_theme_stylebox_override("panel", ps)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := UIKit.hbox(12)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(pic)
	var tv := UIKit.vbox(0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(UIKit.label(eyebrow, 10, Color("f5c518"), UIKit.bold_font()))
	tv.add_child(UIKit.label(head, 16, Color.WHITE, UIKit.title_font()))
	var sl := UIKit.label(sub, 12, Color("c9c4b8"))
	sl.custom_minimum_size.x = 10
	sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tv.add_child(sl)
	h.add_child(tv)
	p.add_child(h)
	toasts.add_child(p)
	var vp := get_viewport_rect().size
	var safe := _safe()
	var w := minf(420, vp.x - 24)
	toasts.custom_minimum_size = Vector2(w, 0)
	toasts.size = Vector2(w, 0)
	await get_tree().process_frame
	toasts.position = Vector2((vp.x - w) / 2, vp.y - toasts.size.y - safe.bottom - 6)
	p.modulate.a = 0
	p.position.y += 60
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "modulate:a", 1.0, 0.35)
	Sfx.play("achievement", 1.0 if t.kind == "ach" else 1.25, 0.0 if t.kind == "ach" else -5.0)
	burst(Vector2(vp.x / 2 - w / 2 + 33, vp.y - safe.bottom - 40), [Color("f5c518"), Color.WHITE], 20, 160, 0)
	await get_tree().create_timer(3.0).timeout
	var out := create_tween()
	out.tween_property(p, "modulate:a", 0.0, 0.35)
	await out.finished
	p.queue_free()
	_next_toast()

# ───────── Efektler ─────────
func burst(at: Vector2, colors: Array, amount := 40, speed := 380.0, gravity := 700.0) -> void:
	var p := CPUParticles2D.new()
	fx_layer.add_child(p)
	p.position = at
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = 1.2
	p.spread = 180
	p.direction = Vector2(0, -1)
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, gravity)
	p.damping_min = 20
	p.damping_max = 60
	p.angular_velocity_min = -360
	p.angular_velocity_max = 360
	p.scale_amount_min = 4
	p.scale_amount_max = 8
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	var cl: Array = colors if colors.size() > 1 else [colors[0], colors[0]]
	for i in cl.size():
		offs.append(float(i) / (cl.size() - 1))
		cols.append(cl[i])
	g.offsets = offs
	g.colors = cols
	p.color_initial_ramp = g
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	p.emitting = true
	get_tree().create_timer(1.6).timeout.connect(p.queue_free)

func ring(at: Vector2, col: Color, max_r := 120.0) -> void:
	var r := Ring.new()
	r.col = col
	r.position = at
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.add_child(r)
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(r, "radius", max_r, 0.6)
	tw.tween_property(r, "modulate:a", 0.0, 0.6)
	tw.finished.connect(r.queue_free)

func floater(text: String, at: Vector2, col: Color, fsize := 28) -> void:
	var l := UIKit.title(text, fsize, col)
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.add_child(l)
	await get_tree().process_frame
	if not is_instance_valid(l):
		return
	l.pivot_offset = l.size / 2
	l.position = at - l.size / 2
	l.scale = Vector2(0.4, 0.4)
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2(1.15, 1.15), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.12)
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 60, 0.9).set_delay(0.3)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.finished.connect(l.queue_free)

func banner(head: String, sub := "") -> void:
	var vp := get_viewport_rect().size
	var band := PanelContainer.new()
	band.add_theme_stylebox_override("panel", UIKit.box(Color(0.05, 0.03, 0.02, 0.82), 0, 0))
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := UIKit.vbox(2)
	var t := UIKit.title(head, 40, UIKit.GOLD_3)
	t.add_theme_constant_override("outline_size", 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	if sub != "":
		v.add_child(UIKit.label(sub, 15, UIKit.INK, UIKit.title_font(), HORIZONTAL_ALIGNMENT_CENTER))
	band.add_child(v)
	fx_layer.add_child(band)
	band.custom_minimum_size = Vector2(vp.x, 0)
	await get_tree().process_frame
	if not is_instance_valid(band):
		return
	band.position = Vector2(0, vp.y * 0.4 - band.size.y / 2)
	band.pivot_offset = band.size / 2
	band.scale = Vector2(1, 0)
	var tw := create_tween()
	tw.tween_property(band, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.3)
	tw.tween_property(band, "modulate:a", 0.0, 0.4)
	tw.finished.connect(band.queue_free)

func flash(col: Color) -> void:
	var r := ColorRect.new()
	r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full(r)
	fx_layer.add_child(r)
	var tw := create_tween()
	tw.tween_property(r, "modulate:a", 0.0, 0.8)
	tw.finished.connect(r.queue_free)

func pop(c: Control, k := 1.2) -> void:
	if not is_instance_valid(c):
		return
	c.pivot_offset = c.size / 2
	var tw := create_tween()
	tw.tween_property(c, "scale", Vector2(k, k), 0.08)
	tw.tween_property(c, "scale", Vector2.ONE, 0.16)

func shake(c: Control) -> void:
	if not is_instance_valid(c):
		return
	var base := c.position
	var tw := create_tween()
	for d in [Vector2(-6, 2), Vector2(5, -2), Vector2(-4, 1), Vector2(3, 0), Vector2.ZERO]:
		tw.tween_property(c, "position", base + d, 0.06)
