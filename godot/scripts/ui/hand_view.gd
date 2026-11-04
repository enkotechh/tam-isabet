class_name HandView
extends Control
## Eldeki kartları yelpaze şeklinde dizer. Yeni kartlar desteden uçarak gelir,
## seçilen kartlar yukarı kalkar. Kart görünümleri uid ile eşlenip yeniden kullanılır.

signal card_pressed(uid: int)

var views: Dictionary = {}     ## uid -> CardView
var deck_global := Vector2.ZERO
var card_w := 76.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS

func sync(run: RunState) -> void:
	var keep := {}
	for c in run.hand:
		keep[c.uid] = true
	for u in views.keys():
		if not keep.has(u):
			views[u].queue_free()
			views.erase(u)

	var n := run.hand.size()
	var W := size.x if size.x > 0 else 358.0
	card_w = clampf(W / 4.6, 60.0, 86.0)
	var pad := 10.0
	var step := minf(card_w * 0.9, (W - 2 * pad - card_w) / maxf(1, n - 1)) if n > 1 else 0.0
	var start := (W - (card_w + step * (n - 1))) / 2
	var bc := run.boost_color()
	var k := 0
	for i in n:
		var c: Dictionary = run.hand[i]
		var v: CardView = views.get(c.uid)
		var is_new := v == null
		if is_new:
			v = CardView.new()
			v.mini = true
			v.set_width(card_w)
			v.pressed.connect(func(cv): card_pressed.emit(cv.uid()))
			add_child(v)
			views[c.uid] = v
			v.global_position = deck_global - v.size / 2
			v.rotation = -0.6
			v.scale = Vector2(0.4, 0.4)
		elif not is_equal_approx(v.card_w, card_w):
			v.set_width(card_w)
		v.card = c
		v.selected = c.uid in run.sel
		v.boosted = run.T(c).kind == "num" and bc != "" and c.color == bc
		v.queue_redraw()
		var d := i - (n - 1) / 2.0
		var x := start + i * step
		var y := 34.0 + d * d * (1.6 if n > 6 else 2.4)
		var rot := deg_to_rad(d * (2.8 if n > 6 else 4.2))
		if v.selected:
			y -= 28
			rot *= 0.3
		v.z_index = i
		var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var delay := k * 0.06 if is_new else 0.0
		tw.tween_property(v, "position", Vector2(x, y), 0.4 if is_new else 0.2).set_delay(delay)
		tw.tween_property(v, "rotation", rot, 0.4 if is_new else 0.2).set_delay(delay)
		tw.tween_property(v, "scale", Vector2(1.07, 1.07) if v.selected else Vector2.ONE, 0.4 if is_new else 0.2).set_delay(delay)
		if is_new:
			k += 1

## Seçili kartların görünümlerini elden ayırır (oynama animasyonu için)
func detach(uids: Array) -> Array:
	var out: Array = []
	for u in uids:
		if views.has(u):
			out.append(views[u])
			views.erase(u)
	return out

func view_of(u: int) -> CardView:
	return views.get(u)
