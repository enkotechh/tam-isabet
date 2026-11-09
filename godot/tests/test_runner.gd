extends Node
## Kural motoru testleri. Çalıştırma (proje klasöründe):
##   godot --headless --path godot res://tests/test_runner.tscn
## Çıkış kodu 0 = hepsi geçti.

var failed := 0
var passed := 0

func _ready() -> void:
	Progress.save_enabled = false
	Progress.silent = true
	Progress.p = Progress.fresh()
	test_evaluate()
	test_scoring()
	test_tutorial()
	test_shop()
	test_decks()
	test_story()
	test_sfx()
	simulate()
	print("\nSONUÇ: %d geçti, %d kaldı" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)

func check(cond: bool, name: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("  KALDI: ", name)

func make_run(cls := "guard") -> RunState:
	var r := RunState.new()
	r.rng.seed = 12345
	r.start(cls, Data.RECOMMENDED[cls])
	return r

func cards(r: RunState, ids: Array) -> Array:
	return ids.map(func(id): return r.inst(id))

func test_evaluate() -> void:
	print("Hesaplama")
	var r := make_run()
	r.target = 10
	check(r.evaluate(cards(r, ["n-red-4", "n-blue-6"])).hit, "4 + 6 = 10")
	r.target = 12
	check(r.evaluate(cards(r, ["n-green-6", "mul2"])).total == 12, "6 ×2 = 12")
	check(r.evaluate(cards(r, ["n-green-6", "n-red-3", "mul2"])).total == 18, "(6+3) ×2 = 18")
	check(r.evaluate(cards(r, ["n-red-9", "n-red-8", "div2"])).total == 8, "(9+8) ÷2 = 8")
	r.target = 17
	check(r.evaluate(cards(r, ["n-red-9", "joker"])).total == 17, "9 + joker(8) = 17")
	r.target = 71
	check(r.evaluate(cards(r, ["n-red-9", "n-red-8", "mirror"])).total == 71, "ayna 17 -> 71")
	r.target = 25
	check(r.evaluate(cards(r, ["n-red-2", "n-red-3", "square"])).total == 25, "(2+3)² = 25")
	r.target = 10
	check(r.evaluate(cards(r, ["n-red-4", "n-red-4", "equal", "n-red-2"])).total == 12, "eşitleyici 4,4,2 -> 4,4,4")
	check(r.evaluate(cards(r, ["n-red-3", "n-red-4", "echo"])).total == 11, "yansıma 3+4+4")
	r.target = 11
	check(not r.evaluate(cards(r, ["n-red-4", "n-blue-6"])).hit, "10 ≠ 11 ıska")
	r.charms.append({"uid": 999, "cid": "nearshot", "state": {}})
	check(r.evaluate(cards(r, ["n-red-4", "n-blue-6"])).hit, "yakın atış ±1")

func test_scoring() -> void:
	print("Bahis ve oran")
	var r := make_run()
	r.target = 10
	check(r.gold == RunState.START_CHIPS and r.min_bet() == 3, "20 fişle başlar, 1. tur minimum bahis 3")
	check(r.bet_options() == [3, 6, 12], "bahis seçenekleri 3/6/12")
	var sc := r.score_play(cards(r, ["n-red-4", "n-blue-6"]))
	check(sc.chips == 3 and is_equal_approx(sc.mult, 3.0) and sc.total == 9, "2 kart: 3 fiş × 3:1 = 9")
	check(RunState.base_odds(1) == 4 and RunState.base_odds(3) == 2 and RunState.base_odds(6) == 1, "oran tablosu 4/3/2/1")
	r.set_bet(2)
	check(r.bet() == 12 and r.score_play(cards(r, ["n-red-4", "n-blue-6"])).total == 36, "yüksek bahis 12 × 3 = 36")
	r.gold = 5
	check(r.bet() == 5, "fiş yetmezse elindeki kadar yatırılır")
	r.gold = 20
	r.set_bet(0)
	var combo := cards(r, ["n-red-1", "n-red-2", "n-red-3", "n-red-4"])
	check(r.is_combo(combo), "aynı renk 4 kart = renk serisi")
	r.charms.append({"uid": 998, "cid": "c_red", "state": {}})
	r.charms.append({"uid": 997, "cid": "crown", "state": {}})
	var sc2 := r.score_play(combo)
	check(is_equal_approx(sc2.mult, (1 + 1 + 1) * 3.0), "oran (1 + seri 1 + kızıl 1) × taç 3 = 9")
	check(RunState.goal_for(1) == 12 and RunState.goal_for(3) == 40 and RunState.goal_for(6) == 72, "masa hedefleri 12/40/72")

	# ıska bahsi götürür, isabet kazandırır
	var r2 := make_run()
	r2.set_bet(1)
	var g0 := r2.gold
	r2.target = 99
	r2.hand = cards(r2, ["n-red-1"]) + r2.hand
	r2.sel = [r2.hand[0].uid]
	r2.play()
	check(r2.gold == g0 - 6 and r2.round_score == -6, "ıska: 6 fişlik bahis gitti")
	r2.modal = {}
	r2.target = 9
	r2.hand = cards(r2, ["n-blue-9"]) + r2.hand
	r2.sel = [r2.hand[0].uid]
	r2.play()
	check(r2.last_play.score.total == 24 and r2.round_score == 18, "isabet: 6 × 4:1 = +24, masada net +18")
	check(r2.modal.get("type", "") == "cashout" and r2.gold == g0 - 6 + 24 + 3 + 2 * 2, "hedef 12 aşıldı: masa ödülü 3 + kalan 2 oynama × 2")

	# fiş bitince kasa borç verir, destene Senet girer
	var r3 := make_run()
	r3.gold = 1
	var senet := r3.master.filter(func(c): return c.tid == "stone").size()
	r3.target = 99
	r3.hand = cards(r3, ["n-red-1"]) + r3.hand
	r3.sel = [r3.hand[0].uid]
	r3.play()
	check(r3.loans == 1 and r3.master.filter(func(c): return c.tid == "stone").size() == senet + 1, "borç alındı, Senet girdi")
	check(r3.gold == 1 + 9 - 3, "borç 9 fiş, ıskada 3 gitti")

func test_tutorial() -> void:
	print("Öğretici")
	Progress.p = Progress.fresh()
	var r := RunState.new()
	r.rng.seed = 7
	r.start("guard", Data.RECOMMENDED.guard, true)
	var one := func(tid: String) -> int:
		for c in r.hand:
			if c.tid == tid:
				return c.uid
		return -1
	r.tut_advance()
	check(r.tut.step == 1 and r.target == 10, "adım 1: el ve hedef kuruldu")
	r.toggle(one.call("n-red-4"))
	r.toggle(one.call("n-blue-6"))
	check(r.tut.step == 2, "seçim adımı geçti")
	r.play()
	check(r.tut.step == 3 and r.round_score == 9, "ilk isabet 3 × 3:1 = 9 fiş")
	r.tut_advance()
	r.sel = [r.hand[0].uid]
	r.swap_cards()
	check(r.tut.step == 5 and r.target == 12, "değiştir adımı geçti, hedef 12")
	r.modal = {}
	r.sel = [one.call("n-green-6"), one.call("mul2")]
	r.play()
	check(r.tut.step == 6, "×2 çarpan adımı geçti")
	r.modal = {}
	r.sel = [one.call("scout")]
	r.play()
	check(r.tut.step == 7, "büyü adımı geçti")
	r.modal = {}
	r.use_power()
	check(r.tut.step == 8, "güç adımı geçti")
	r.tut_advance()
	r.tut_advance()
	r.round_score = r.goal
	r._round_cleared()
	r.open_shop()
	r.next_round()
	check(r.tut.is_empty() and Progress.p.tutorial_done and "tutorial" in Progress.p.ach, "öğretici bitti, başarım açıldı")
	check(Progress.is_unlocked("joker"), "Çırak başarımı Joker'i açtı")

func test_shop() -> void:
	print("Tüccar")
	Progress.p = Progress.fresh()
	var r := make_run()
	r.gold = 40
	r.open_shop()
	check(r.shop.cards.size() == 3, "3 kart rafı")
	var n := r.master.size()
	check(r.buy("card", 0) and r.master.size() == n + 1, "kart alındı")
	if r.shop.charms.size() > 0:
		check(r.buy("charm", 0) and r.charms.size() == 1, "tılsım takıldı")
		var g := r.gold
		r.sell_charm(0)
		check(r.charms.is_empty() and r.gold > g, "tılsım satıldı")
	var cost: int = r.shop.reroll_cost
	r.reroll()
	check(r.shop.reroll_cost == cost + 1, "yenileme ücreti arttı")
	check(r.remove_card_paid(r.master[0].uid), "kart çıkarıldı")
	check(not r.remove_card_paid(r.master[0].uid), "tüccar başına bir kez çıkarılır")

func _clear_round(r: RunState) -> void:
	r.round_score = r.goal
	r._round_cleared()
	r.next_round()

func test_story() -> void:
	print("Hikâye")
	var saved: Dictionary = Progress.p
	Progress.p = Progress.fresh()
	check(Progress.story_done() == 0 and not Progress.class_open("seer"), "hikâye başta: 0 bölüm, Vivienne kilitli")
	check(not Progress.class_open("alchemist"), "Eddie başta kilitli")
	var r := RunState.new()
	r.rng.seed = 7
	r.start("guard", Data.RECOMMENDED.guard, false, true)
	check(r.story_ch == 1, "ilk kat 1. bölüm")
	check(r.fx.any(func(f): return f.type == "scene" and f.part == "intro" and f.ch == 1), "1. bölümün açılış sahnesi istendi")
	check(Progress.story_seen(1), "açılış sahnesi izlendi sayıldı")
	r.fx = []
	_clear_round(r)
	_clear_round(r)
	check(r.rtype == "boss" and r.boss == Data.STORY[0].boss, "engel turu bölümün engeli")
	r.fx = []
	r.round_score = r.goal
	r._round_cleared()
	check(Progress.story_done() == 1, "3 tur kazanınca hikâye ilerledi")
	check(r.fx.any(func(f): return f.type == "scene" and f.part == "outro" and f.ch == 1), "bölüm kapanış sahnesi istendi")
	check(Progress.is_unlocked("fortify") and Progress.is_unlocked("discipline"), "1. bölüm kartları açıldı")
	r.fx = []
	r.next_round()
	check(r.story_ch == 2 and r.fx.any(func(f): return f.type == "scene" and f.ch == 2), "sonraki kat 2. bölüm")
	_clear_round(r)
	_clear_round(r)
	r.round_score = r.goal
	r._round_cleared()
	check(Progress.story_done() == 2 and Progress.class_open("seer"), "2. bölüm Vivienne'i açtı")
	# kaybedip yeni oyuna başlayınca kalınan bölümden devam
	var r2 := RunState.new()
	r2.rng.seed = 8
	r2.start("guard", Data.RECOMMENDED.guard, false, true)
	check(r2.story_ch == 3, "yeni oyun kalınan bölümden (3) başlar")
	check(not Progress.complete_chapter(5), "bölüm atlanamaz")
	# serbest oyunda hikâye ilerlemez
	var r3 := RunState.new()
	r3.rng.seed = 9
	r3.start("guard", Data.RECOMMENDED.guard)
	check(r3.story_ch == 0 and not r3.fx.any(func(f): return f.type == "scene"), "serbest oyunda hikâye sahnesi yok")
	Progress.p = saved

func test_sfx() -> void:
	print("Sesler")
	var t0 := Time.get_ticks_msec()
	Sfx._build()
	print("  %d ses %d ms'de üretildi" % [Sfx.streams.size(), Time.get_ticks_msec() - t0])
	check(Sfx.streams.size() >= 22, "en az 22 ses var")
	var silent: Array = []
	for name in Sfx.streams:
		var d: PackedByteArray = Sfx.streams[name].data
		var peak := 0
		for i in range(0, d.size() - 1, 16):
			peak = maxi(peak, absi(d.decode_s16(i)))
		if peak < 2000:
			silent.append(name)
	check(silent.is_empty(), "sessiz ses yok " + str(silent))
	for name in ["click", "select", "chip", "hit", "miss", "fanfare", "achievement"]:
		check(Sfx.streams.has(name), "ses var: " + name)
	Sfx.play("chip", 1.2)
	Sfx.play("bilinmeyen")
	check(true, "çalma çağrıları hata vermedi")

func test_decks() -> void:
	print("Desteler")
	Progress.p = Progress.fresh()
	Progress.decks = {}
	check(Progress.deck_for("guard") == Data.RECOMMENDED.guard, "kayıt yoksa önerilen deste")
	var custom: Array = Data.RECOMMENDED.guard.duplicate()
	custom[0] = "n-red-9"
	Progress.save_deck("guard", custom)
	check(Progress.deck_for("guard") == custom, "kayıtlı 24 kartlık deste kullanılır")
	custom[1] = "timewarp"
	Progress.save_deck("guard", custom)
	check(Progress.deck_for("guard") == Data.RECOMMENDED.guard, "kilitli kart içeren deste reddedilir")
	Progress.save_deck("guard", custom.slice(0, 20))
	check(Progress.deck_for("guard") == Data.RECOMMENDED.guard, "24 kart olmayan deste reddedilir")
	Progress.decks = {}

## Bot: elindeki her alt kümeyi deneyip isabet arar. strong: en yüksek skoru seçer.
func bot_game(r: RunState, strong: bool) -> int:
	var guard := 0
	while guard < 3000:
		guard += 1
		var m := r.modal
		if not m.is_empty():
			match m.type:
				"over":
					return r.round
				"event":
					r.close_modal()
				"prophecy":
					r.choose_prophecy(m.options[0])
				"life":
					r.retry_round()
				"cashout":
					r.open_shop()
				"shop":
					# fiş aynı zamanda kasa: yedek bırakarak alışveriş
					var keep := r.min_bet() * 6
					for i in r.shop.charms.size():
						if r.gold - r.charm_price(r.shop.charms[i].id) >= keep:
							r.buy("charm", i)
					if r.gold - r.price_of(RunState.PERKS[r.shop.perk.k].price) >= keep * 2:
						r.buy("perk", 0)
					for i in 3:
						if r.gold - r.card_price(r.shop.cards[i].c) >= keep * 2 and not r.is_spell(r.shop.cards[i].c):
							r.buy("card", i)
					r.next_round()
				_:
					check(false, "bilinmeyen pencere " + str(m.type))
					return r.round
			continue
		if r.hand.is_empty():
			check(false, "pencere yokken el boş")
			return r.round
		# güçlü bot hedefe yaklaşırken büyük oynar
		r.set_bet(1 if strong and r.gold > r.min_bet() * 8 else 0)
		if not r.power_used and r.rng.randf() < 0.3:
			if r.cls == "pyro":
				r.sel = [r.hand[0].uid]
			r.use_power()
			continue
		var sp = null
		for c in r.hand:
			if r.is_spell(c):
				sp = c
		if sp != null and r.boss != "silence" and r.rng.randf() < 0.5:
			r.sel = [sp.uid]
			r.play()
			continue
		var h := r.hand.filter(func(c): return not r.is_spell(c))
		var L := mini(h.size(), 8)
		var best_sel: Array = []
		var best_t := -1
		var found := 0
		for mask in range(1, 1 << L):
			var s: Array = []
			for i in L:
				if mask & (1 << i):
					s.append(h[i])
			if r.evaluate(s).hit:
				found += 1
				var t: int = r.score_play(s, true).total if strong else 0
				if t > best_t:
					best_t = t
					best_sel = s
				if not strong or found >= 12:
					break
		if not best_sel.is_empty() and r.rng.randf() < (0.9 if strong else 0.7):
			r.sel = best_sel.map(func(c): return c.uid)
		elif r.discards > 0 and not h.is_empty():
			r.sel = [h[0].uid]
			r.swap_cards()
			continue
		else:
			r.sel = [r.hand[0].uid]
		r.play()
	check(false, "oyun bitmedi (döngü sınırı)")
	return r.round

func simulate() -> void:
	print("Simülasyon")
	for strong in [true, false]:
		var rounds: Array = []
		for cls in Data.CLASS_KEYS:
			for g in 6:
				Progress.p = Progress.fresh()
				Progress.p.classes = Data.CLASS_KEYS.duplicate()
				var r := RunState.new()
				r.rng.seed = 1000 + g * 31 + Data.CLASS_KEYS.find(cls) * 7
				r.start(cls, Data.RECOMMENDED[cls])
				rounds.append(bot_game(r, strong))
		var total := 0
		for x in rounds:
			total += x
		print("  %s bot: %d oyun, ortalama tur %.1f, en düşük %d, en yüksek %d" % ["güçlü" if strong else "zayıf", rounds.size(), float(total) / rounds.size(), rounds.min(), rounds.max()])
		check(rounds.size() == 24, "tüm oyunlar bitti")
