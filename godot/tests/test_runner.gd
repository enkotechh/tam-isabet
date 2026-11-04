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
	check(RunState.goal_for(1) == 50 and RunState.goal_for(3) == 100, "tur hedefleri")

func test_scoring() -> void:
	print("Skor")
	var r := make_run()
	r.target = 10
	var sc := r.score_play(cards(r, ["n-red-4", "n-blue-6"]))
	check(sc.chips == 10 + 9 + 11 and sc.total == 30, "puan 10+(5+4)+(5+6)=30, çarpan 1")
	var combo := cards(r, ["n-red-1", "n-red-2", "n-red-3", "n-red-4"])
	check(r.is_combo(combo), "aynı renk 4 kart = renk serisi")
	r.charms.append({"uid": 998, "cid": "c_red", "state": {}})
	r.charms.append({"uid": 997, "cid": "crown", "state": {}})
	var sc2 := r.score_play(combo)
	check(is_equal_approx(sc2.mult, (1 + 2 + 4) * 3.0), "çarpan (1+2 seri+4 kızıl) ×3 taç = 21")

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
	check(r.tut.step == 3 and r.round_score == 30, "ilk isabet 30 skor")
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
					for i in r.shop.charms.size():
						r.buy("charm", i)
					if r.gold >= 12:
						r.buy("perk", 0)
					for i in 3:
						if r.gold >= 10 and not r.is_spell(r.shop.cards[i].c):
							r.buy("card", i)
					r.next_round()
				_:
					check(false, "bilinmeyen pencere " + str(m.type))
					return r.round
			continue
		if r.hand.is_empty():
			check(false, "pencere yokken el boş")
			return r.round
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
