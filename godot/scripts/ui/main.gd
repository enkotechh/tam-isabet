extends Control
## Ana sahne: ekranlar (açılış, sınıf seçimi, oyun masası), pencereler, öğretici balonu,
## bildirimler ve efektler. Kurallar RunState'te; burası yalnızca çizer ve animasyon oynatır.

var run: RunState
var screen := ""
var busy := false
var last_tap = null          ## son dokunulan kart uid'i ya da "c<i>" (tılsım)
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

# ───────── Küçük çizim sınıfları ─────────
class Planks extends Control:
	func _draw() -> void:
		var w := size.x
		var x := 0.0
		var i := 0
		while x < w:
			draw_rect(Rect2(x, 0, 46, size.y), UIKit.WOOD_1 if i % 2 == 0 else Color("2a1b10"))
			draw_rect(Rect2(x + 45, 0, 2, size.y), Color(0, 0, 0, 0.3))
			x += 46
			i += 1

class Dial extends Control:
	var progress := 0.0:
		set(v):
			progress = v
			queue_redraw()
	func _draw() -> void:
		var c := size / 2
		var r := minf(size.x, size.y) / 2 - 3
		draw_circle(c, r + 3, UIKit.OUTLINE)
		draw_circle(c, r, Color("0b1016"))
		if progress > 0:
			draw_arc(c, r - 5, -PI / 2, -PI / 2 + TAU * clampf(progress, 0, 1), 64, UIKit.GOLD_2, 9, true)
		draw_circle(c, r - 11, Color("26323f"))
		draw_arc(c, r - 15, 0, TAU, 64, Color(1, 0.9, 0.64, 0.18), 1, true)

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
		UIKit.box(Color("0b1016"), 4, 1, UIKit.GOLD_0).draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
		if value > 0:
			UIKit.box(UIKit.GOLD_2, 4).draw(get_canvas_item(), Rect2(Vector2.ZERO, Vector2(size.x * clampf(value, 0, 1), size.y)))

# ───────── Kurulum ─────────
func _ready() -> void:
	theme = UIKit.make_theme()
	var bg := ColorRect.new()
	bg.color = UIKit.WOOD_1
	_full(bg)
	add_child(bg)
	var planks := Planks.new()
	_full(planks)
	planks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(planks)
	var glow := TextureRect.new()
	var gt := GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 0.75)
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 0.66, 0.3, 0.22))
	gr.set_color(1, Color(0, 0, 0, 0.45))
	gt.gradient = gr
	glow.texture = gt
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full(glow)
	add_child(glow)

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

	var t1 := UIKit.title("T A M", 18, UIKit.GOLD_2)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(t1)
	var t2 := UIKit.title("İsabet", 62, UIKit.GOLD_3)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t2.add_theme_constant_override("outline_size", 12)
	root.add_child(t2)
	var tag := UIKit.label("Hedefi tuttur. Desteni kur. Kaderi yen.", 16, UIKit.MUTED, null, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(tag)

	var menu := UIKit.vbox(12)
	menu.custom_minimum_size.x = 300
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(menu)
	if run and run.lives > 0 and run.modal.get("type", "") != "over":
		var cont := UIKit.button("Maceraya Devam Et", true)
		cont.pressed.connect(func(): show_game())
		menu.add_child(cont)
	var start := UIKit.button("Maceraya Başla" if Progress.p.tutorial_done else "Öğreticiyle Başla", true)
	start.pressed.connect(func():
		if not Progress.p.tutorial_done:
			start_run("guard", true)
		else:
			show_classes())
	menu.add_child(start)
	var coll := UIKit.button("Koleksiyon ve Desteler")
	coll.pressed.connect(func(): show_classes("Koleksiyon ve Desteler"))
	menu.add_child(coll)
	var ach := UIKit.button("Başarımlar")
	ach.pressed.connect(func(): open_modal({"type": "achievements"}))
	menu.add_child(ach)
	var row := UIKit.hbox(12)
	var tb := UIKit.button("Öğretici", false, true)
	tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tb.pressed.connect(func(): start_run("guard", true))
	var hb := UIKit.button("Nasıl Oynanır", false, true)
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.pressed.connect(func(): open_modal({"type": "howto"}))
	row.add_child(tb)
	row.add_child(hb)
	menu.add_child(row)

	var total := Data.UNLOCK_ORDER.size() + Data.NUMBER_CARDS.size()
	var best := UIKit.label("REKOR  %d" % Progress.best, 14, UIKit.GOLD_3, UIKit.title_font(), HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(best)
	root.add_child(UIKit.label("%d/%d kart ve tılsım açık · %d/%d başarım" % [Progress.p.unlocked.size(), total, Progress.p.ach.size(), Data.ACHIEVEMENTS.size()], 13, UIKit.MUTED, null, HORIZONTAL_ALIGNMENT_CENTER))
	_render_coach()

# ───────── Sınıf seçimi ─────────
func show_classes(head := "Sınıfını Seç") -> void:
	screen = "classes"
	var root := _screen_root()
	var bar := UIKit.hbox(10)
	var back := UIKit.button("‹", false, true)
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
		v.add_child(UIKit.label("Sınıf kartları: %d/%d açık" % [n_open, n_all], 12, UIKit.MUTED))
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
	var back := UIKit.button("‹", false, true)
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

	var deckbar := UIKit.panel(Color("2a1a0e"), 16, 2, UIKit.GOLD_1)
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
		return
	B.list.append(id)
	pop(v, 1.08)
	burst(v.get_global_rect().get_center(), [Data.RARITY[Data.CARD[id].rarity].color, Color.WHITE], 14, 160, 0)
	_builder_update()

# ───────── Oyun ─────────
func start_run(cls: String, tutorial := false) -> void:
	run = RunState.new()
	run.rng.randomize()
	run.start(cls, Progress.deck_for(cls), tutorial)
	last_target = -1
	last_tap = null
	show_game()
	banner("Öğretici" if tutorial else Data.CLASSES[cls].name, "Adım adım öğren" if tutorial else "Macera başlıyor")

func show_game() -> void:
	screen = "game"
	var root := _screen_root()
	root.add_theme_constant_override("separation", 8)

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
	var arena := UIKit.panel(Color("1d2833"), 22, 3, UIKit.GOLD_2)
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
	ui.target = UIKit.title("", 42, Color("fff6dc"))
	ui.target.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dv.add_child(ui.target)
	dial.add_child(dv)
	ah.add_child(dial)
	ui.omen = UIKit.vbox(4)
	ui.omen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.omen.alignment = BoxContainer.ALIGNMENT_CENTER
	ah.add_child(ui.omen)
	root.add_child(arena)

	# skor paneli: tur hedefi + Puan × Çarpan
	var sp := UIKit.panel(Color(0, 0, 0, 0.42), 16, 2, UIKit.GOLD_0)
	ui.scorepanel = sp
	var sv := UIKit.vbox(6)
	sp.add_child(sv)
	var srow := UIKit.hbox(10)
	sv.add_child(srow)
	var gv := UIKit.vbox(2)
	gv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.round_label = UIKit.label("", 11, UIKit.MUTED, UIKit.bold_font())
	ui.round_label.clip_text = true
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
	ui.chips_box = _score_cell("PUAN", UIKit.CHIPS)
	ui.mult_box = _score_cell("ÇARPAN", UIKit.MULT)
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

	ui.info = UIKit.rich("", 13, UIKit.MUTED)
	ui.info.custom_minimum_size.y = 34
	root.add_child(ui.info)

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
	ui.deck_icon = UIKit.panel(Color("4a2a1a"), 6, 2, UIKit.GOLD_1)
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

	await get_tree().process_frame
	refresh()

func _score_cell(caption: String, col: Color) -> PanelContainer:
	var p := UIKit.panel(col, 10, 2, col.darkened(0.5))
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
	ui.round_label.text = rl.to_upper()
	ui.round_label.add_theme_color_override("font_color", Color("ff8a7a") if run.boss != "" else UIKit.MUTED)
	ui.goal.text = "/ %d" % run.goal
	if not busy:
		ui.rscore.text = str(run.round_score)
		ui.bar.value = float(run.round_score) / run.goal
		ui.dial.progress = ui.bar.value
	ui.plays.text = "OYNAMA  %d" % run.plays
	ui.discs.text = "DEĞİŞTİRME  %d" % run.discards

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
		ui.expr.text = "Büyü: " + run.T(sc[0]).text
		ui.tot.text = "✦"
		pv_col = UIKit.SPELL
	elif sc.any(run.is_spell):
		ui.expr.text = "Büyü kartları tek başına kullanılır."
		ui.tot.text = "–"
	else:
		var r := run.evaluate(sc)
		if r.hit:
			prev = run.score_play(sc, true)
		var e: String = r.expr
		if run.is_combo(sc):
			e += "\nRenk serisi: +2 Çarpan"
		if r.tol > 0:
			e += "\nTolerans ±%d" % r.tol
		ui.expr.text = e
		ui.tot.text = str(r.total)
		ui.tot.add_theme_color_override("font_color", UIKit.HIT if r.hit else (UIKit.MISS if r.total > run.target else UIKit.INK))
		if r.hit:
			pv_col = UIKit.HIT
	ui.preview.add_theme_stylebox_override("panel", UIKit.box(Color(0, 0, 0, 0.4), 14, 2, pv_col))
	if not busy:
		var show_sc: Dictionary = prev if not prev.is_empty() else run.last_score
		_cell_val(ui.chips_box).text = str(show_sc.get("chips", 0))
		_cell_val(ui.mult_box).text = RunState.fmt_mult(show_sc.get("mult", 0.0))
		ui.scorebox.modulate.a = 0.7 if not prev.is_empty() else 1.0

	# bilgi satırı
	var info := "Kartlara dokunarak seç. Seçtiğin kartın açıklaması burada görünür."
	if last_tap is String and int(last_tap.substr(1)) < run.charms.size():
		var ch: Dictionary = run.charms[int(last_tap.substr(1))]
		var d: Dictionary = Data.CHARM[ch.cid]
		info = "[b][color=#ffe7a3]%s[/color][/b] [color=#%s]%s tılsım[/color]\n%s" % [d.name, Data.RARITY[d.rarity].color.to_html(false), Data.RARITY[d.rarity].name, d.text]
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
	var p := UIKit.panel(Color("2b2346"), int(w * 0.15), 2, col)
	p.custom_minimum_size = Vector2(w, w * 1.4)
	p.add_child(UIKit.icon_rect(ev.icon, int(w * 0.55), col))
	return p

# ───────── Eylemler ─────────
func _on_card(card_uid: int) -> void:
	if busy or not run.modal.is_empty():
		return
	last_tap = card_uid
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
		await t2.finished
		v.queue_free()

func _animate_play(views: Array, lp: Dictionary) -> void:
	var by_uid := {}
	for v in views:
		by_uid[v.uid()] = v
	# 1. kartlar sahneye (önizleme alanının üstüne) dizilir
	var zone: Rect2 = ui.preview.get_global_rect()
	var n := views.size()
	var w := minf(62.0, (zone.size.x - 8 * (n - 1)) / maxf(1, n))
	var total := n * w + (n - 1) * 8
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in n:
		var v: CardView = views[i]
		var s := w / v.size.x
		var c := Vector2(zone.position.x + (zone.size.x - total) / 2 + i * (w + 8) + w / 2, zone.get_center().y - 10)
		tw.tween_property(v, "global_position", c - v.size / 2, 0.32).set_delay(i * 0.04)
		tw.tween_property(v, "rotation", 0.0, 0.32).set_delay(i * 0.04)
		tw.tween_property(v, "scale", Vector2(s, s), 0.32).set_delay(i * 0.04)
	await tw.finished
	var dial_c: Vector2 = ui.dial.get_global_rect().get_center()

	if not lp.get("hit", false):
		await get_tree().create_timer(0.25).timeout
		floater("Iska", dial_c + Vector2(0, -60), UIKit.MISS)
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

	# 2. Puan × Çarpan adım adım sayılır
	var sc: Dictionary = lp.score
	var chips_l := _cell_val(ui.chips_box)
	var mult_l := _cell_val(ui.mult_box)
	ui.scorebox.modulate.a = 1.0
	var i := 0
	for s in sc.steps:
		chips_l.text = str(s.chips)
		mult_l.text = RunState.fmt_mult(s.mult)
		pop(ui.chips_box if s.kind == "chips" else ui.mult_box, 1.25)
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

	# 3. toplam skor, kartlar hedefe uçar
	pop(ui.scorebox, 1.15)
	floater(str(sc.total), ui.scorebox.get_global_rect().get_center() + Vector2(0, -36), Color.WHITE, 30)
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
	ring(dial_c, Color("ffd25a") if sc.combo else UIKit.GOLD_3, 130)
	burst(dial_c, [UIKit.GOLD_3, UIKit.GOLD_2, UIKit.HIT, Color("ff5a4b"), Color("4b8dff")], 110 if sc.combo else 60)
	floater("Renk Serisi!" if sc.combo else "Tam İsabet!", dial_c + Vector2(0, -74), UIKit.GOLD_3, 28)
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
	for f in q:
		match f.type:
			"round":
				banner("Tur Geçildi", "%d / %d skor" % [run.round_score, run.goal])
				burst(vp * Vector2(0.5, 0.4), [UIKit.GOLD_3, UIKit.GOLD_2, UIKit.HIT, UIKit.SPELL, Color("4b8dff"), Color("ff5a4b")], 140, 600)
			"boss":
				banner(Data.BOSSES[run.boss].name, Data.BOSSES[run.boss].text)
				flash(Color(1, 0.15, 0.15, 0.4))
			"life_lost":
				flash(Color(1, 0.1, 0.2, 0.6))
				shake(content)
			"shield":
				flash(Color(0.4, 0.7, 1, 0.5))
			"heal":
				if ui.has("hearts"):
					burst(ui.hearts.get_global_rect().get_center(), [UIKit.HEART, Color("ff9aa9")], 24, 200, 0)
			"power":
				if ui.has("portrait"):
					var pc: Vector2 = ui.portrait.get_global_rect().get_center()
					ring(pc, Data.CLASS_COLORS[run.cls][0].lightened(0.4), 70)
					burst(pc, [Data.CLASS_COLORS[run.cls][0].lightened(0.4), Color.WHITE], 30, 220, 0)
					floater(f.name, pc + Vector2(30, -40), Color("d9b8ff"), 18)
			"spell":
				floater(f.name, vp * Vector2(0.5, 0.42) + Vector2(0, -90), Color("ecd6ff"), 26)
			"event":
				var col: Color = {"good": UIKit.HIT, "bad": UIKit.MISS}.get(f.tone, UIKit.GOLD_2)
				burst(vp * Vector2(0.5, 0.35), [col, Color.WHITE], 40, 300, 0)
				if f.tone == "bad":
					flash(Color(1, 0.3, 0.2, 0.3))
			"buy":
				pass

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
	var ss := UIKit.box(Color("3a2616"), 20, 3, UIKit.GOLD_2, 18)
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
	v.add_child(UIKit.label(text.to_upper(), 11, UIKit.GOLD_2, UIKit.bold_font()))
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
				"Her isabet [b]Puan × Çarpan[/b] kadar skor verir. Puan: hedef + her kart için 5 + sayı kartlarının değeri. Çarpan: renk serisi ve tılsımlar.",
				"Oynama hakların bitmeden [b]tur hedef skoruna[/b] ulaş. Ulaşamazsan 1 can gider. 2 canla başlarsın, en fazla 4 olur.",
				"Her kat 3 turdur: Küçük Sınav, Büyük Sınav ve özel kurallı [b]Bekçi[/b].",
				"Tur sonunda altın kazanırsın. [b]Tüccarda[/b] kart, tılsım ve güçlendirme alırsın. [b]Tılsımlar[/b] (en fazla 5) kalıcı bonus verir.",
				"Başta kartların çoğu [b]kilitlidir[/b]. Turları geçtikçe ve başarımlarla yenileri açılır.",
				"Nadirlik: [color=#ece7db]beyaz[/color] Sıradan, [color=#4b8dff]mavi[/color] Nadir, [color=#b066ff]mor[/color] Ender, [color=#f5c518]sarı[/color] Efsanevi, [color=#ff3b3b]kırmızı[/color] Epik."]:
				v.add_child(UIKit.rich("• " + line, 15, Color("e3d5b8")))
			_btn(v, "Anladım", true, _close_ui_or_modal)
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
					rew.append((Data.CLASSES[u.substr(6)].name + " sınıfı") if u.begins_with("class:") else (Data.CARD[u].name if Data.CARD.has(u) else Data.CHARM[u].name))
				tv.add_child(UIKit.wrap(UIKit.label("Ödül: " + ", ".join(PackedStringArray(rew)), 12, UIKit.MUTED)))
				h.add_child(tv)
				row.add_child(h)
				v.add_child(row)
			_para(v, "Ayrıca her geçtiğin tur, sıradaki kilitli kartı ya da tılsımı açar.", UIKit.MUTED)
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
			_eyebrow(v, "Kehanet", "Kaderi seç")
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
			_eyebrow(v, "%s geçildi · %d/%d skor" % [RunState.ROUND_TYPES[run.rtype], run.round_score, run.goal], "Ganimet")
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
			_eyebrow(v, "Desteni incelt · 3 altın", "Hangi kart gitsin?")
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
				_para(v, "%d skor hedefinin %d kadarına ulaştın. %d canın kaldı. Tur %d yeni kartlarla baştan başlayacak." % [run.goal, run.round_score, run.lives, run.round])
			_btn(v, "Turu yeniden dene", true, func():
				run.retry_round()
				refresh())
		"over":
			_eyebrow(v, "Canın kalmadı", "Oyun bitti")
			_para(v, "%s olarak %d. kattaki %d. tura kadar geldin. Toplam skor: %d. Rekor: %d." % [Data.CLASSES[run.cls].name, ceili(run.round / 3.0), run.round, run.score, Progress.best])
			_para(v, "Açtığın kartlar ve başarımlar kalıcı.", UIKit.MUTED)
			var cls := run.cls
			_btn(v, "Aynı sınıfla yeniden oyna", true, func(): start_run(cls))
			_btn(v, "Ana menü", false, func():
				run = null
				show_splash())
		"pause":
			_eyebrow(v, "%s · Tur %d" % [Data.CLASSES[run.cls].name, run.round], "Duraklatıldı")
			_btn(v, "Devam et", true, func():
				run.modal = {}
				refresh())
			_btn(v, "Nasıl oynanır", false, func(): _show_sheet({"type": "howto"}))
			_btn(v, "Ana menü", false, func():
				run.modal = {}
				show_splash())
			var cls := run.cls
			_btn(v, "Yeni oyun başlat", false, func(): start_run(cls))

func _close_ui_or_modal() -> void:
	if screen == "game" and run and not run.modal.is_empty() and run.modal.type in ["howto", "achievements"]:
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
	var b := UIKit.button(label if label != "" else "%d altın" % price, true, true)
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
	hv.add_child(UIKit.label(("Kat %d · Sıradaki: %s" % [ceili((run.round + 1) / 3.0), RunState.ROUND_TYPES[nxt]]).to_upper(), 11, UIKit.GOLD_2, UIKit.bold_font()))
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

	v.add_child(UIKit.label("TILSIMLAR · %d/%d YUVA" % [run.charms.size(), RunState.MAX_CHARMS], 13, UIKit.GOLD_2, UIKit.title_font()))
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
		v.add_child(UIKit.label("TILSIMLARIN", 13, UIKit.GOLD_2, UIKit.title_font()))
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
	var rm := _btn(br, "Kart çıkar · 3", false, on_rm, true)
	rm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rm.disabled = sh.removed or run.gold < 3 or run.master.size() <= 12
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
	var ps := UIKit.box(UIKit.PARCH, 16, 2, UIKit.GOLD_1, 10)
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
			eyebrow = "YENİ SINIF AÇILDI"
			head = C.name
			sub = C.tagline
			pic = UIKit.panel(Data.CLASS_COLORS[t.id][0], 23, 2, UIKit.GOLD_1)
			pic.custom_minimum_size = Vector2(46, 46)
			pic.add_child(UIKit.icon_rect(C.icon, 26, Color.WHITE))
		"charm":
			var c: Dictionary = Data.CHARM[t.id]
			eyebrow = "YENİ TILSIM AÇILDI"
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
	var ps := UIKit.box(Color("17161c"), 40, 2, Color("f5c518") if t.kind == "ach" else Color(1, 1, 1, 0.25), 10)
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
	sl.clip_text = true
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
