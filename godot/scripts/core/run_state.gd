class_name RunState
extends RefCounted
## Bir oyunun (run) tüm durumu ve kuralları. Arayüzden bağımsızdır:
## arayüz eylemleri çağırır, sonra durumu ve `fx` kuyruğunu okuyup çizer. Testler de doğrudan bunu kullanır.
## Kart örneği: {uid, tid, value, color}

const MAX_LIVES := 4
const START_LIVES := 2
const DECK_SIZE := 24
const MAX_CHARMS := 5
const START_CHIPS := 20     ## başlangıç fişi
const BET_STEPS := [1, 2, 4] ## bahis seçenekleri: masa minimumunun katları
const ROUND_TYPES := {"small": "Küçük Masa", "big": "Büyük Masa", "boss": "Engel"}
const PERKS := {
	"life": {"title": "+1 Can", "icon": "heart", "price": 6, "text": "Canın 1 artar (en fazla 4)."},
	"play": {"title": "Sabır", "icon": "hourglass", "price": 8, "text": "Her tur +1 oynama hakkı."},
	"discard": {"title": "Esneklik", "icon": "swap", "price": 5, "text": "Her tur +1 değiştirme hakkı."},
	"hand": {"title": "Geniş El", "icon": "hand", "price": 7, "text": "Elinde 1 kart daha tutarsın."},
}

## Öğretici adımları. on: hangi eylem sonraki adıma geçirir · next: "Devam" düğmesi · when: yalnızca tüccarda göster
const TUT := [
	{"text": "Port Halloway'e hoş geldin! Amacın elindeki kartlarla ortadaki [b]HEDEF[/b] sayısını tam tutturmak.", "focus": "dial", "next": true},
	{"text": "Toplamı [b]10[/b] eden kartları seç. Örneğin Kızıl 4 ile Mavi 6.", "focus": "hand", "on": "select"},
	{"text": "Toplam 10 oldu. Şimdi [b]Oyna[/b]'ya bas.", "focus": "play", "on": "hit"},
	{"text": "Her oynamada [b]bahis[/b] yatırırsın. İsabette masa sana [b]bahis × oran[/b] kadar fiş öder. Az kartla tutturmak daha yüksek oran verir. Iskada bahsin gider. Turu geçmek için masadan hedef kadar fiş kazan.", "focus": "score", "next": true},
	{"text": "İşine yaramayan kartları seçip [b]Değiştir[/b]'e basarsan yerine yenileri gelir. Bir kart seç ve Değiştir'e bas.", "focus": "swap", "on": "swap"},
	{"text": "[b]Katla[/b] toplamı ikiye katlar. Yeşil 6 ile Katla'yı seçip 12 yap ve oyna.", "focus": "hand", "on": "hit"},
	{"text": "Mor taşlı kartlar [b]hamle kartıdır[/b]. Muhbir'i tek başına seç ve [b]Kullan[/b]'a bas.", "focus": "hand", "on": "spell"},
	{"text": "Her karakterin tur başına bir [b]gücü[/b] var. Silas'ın Ev Kuralı gücüne bas, +1 oynama hakkı al.", "focus": "power", "on": "power"},
	{"text": "Sağdaki kart [b]sıradaki olay[/b]: birkaç isabette bir gerçekleşir. Üstteki kalpler [b]canların[/b]: tur hedefine ulaşamazsan bir can gider.", "focus": "omen", "next": true},
	{"text": "Şimdi turu kendin bitir. Masa hedefine ulaşınca ödülünü alıp [b]tüccara[/b] gideceksin.", "focus": "score", "next": true},
	{"text": "Burası tüccar. Fişle kart, [b]eşya[/b] ve güçlendirme alabilirsin. Eşyalar kalıcı bonus verir. Hazır olunca sonraki tura geç.", "focus": "", "on": "shopnext", "when": "shop"},
]

var rng := RandomNumberGenerator.new()
var uid := 1
var cls := "guard"
var story := false        ## hikâye modu
var story_ch := 0         ## bu katın hikâye bölümü (1–8), 0 = bölüm yok
var round := 0
var score := 0              ## bu oyunda kazanılan toplam fiş (rekor)
var gold := START_CHIPS     ## fiş: hem para hem skor (adı eski sürümden kaldı)
var bet_level := 0          ## seçili bahis: BET_STEPS içindeki sıra
var loans := 0              ## kasadan alınan borç sayısı
var lives := START_LIVES
var master: Array = []
var draw: Array = []
var discard: Array = []
var hand: Array = []
var sel: Array = []          ## seçili kartların uid listesi
var charms: Array = []       ## {uid, cid, state}
var target := 0
var goal := 0
var round_score := 0        ## bu masada net kazanılan fiş (eksiye düşebilir)
var rtype := "small"
var boss := ""
var plays := 0
var discards := 0
var max_plays := 4
var max_discards := 3
var hand_size := 7
var mods: Array = []         ## {type: "boost", color, turns}
var plays_used := 0
var spells_round := 0
var msg := ""
var msg_kind := ""
var modal: Dictionary = {}   ## {} = pencere yok
var ev_count := 0
var next_event := ""
var event_due := false
var power_used := false
var shield := false
var tol_next := 0
var sort_mode := "value"
var last_score: Dictionary = {}
var last_play: Dictionary = {}   ## arayüz animasyonu için: {uids, hit, score}
var shop: Dictionary = {}
var tut: Dictionary = {}         ## {step} öğreticideyken
var fx: Array = []               ## arayüzün oynatacağı efektler

# ───────── Kart yardımcıları ─────────
func T(c: Dictionary) -> Dictionary:
	return Data.CARD[c.tid]

func inst(tid: String) -> Dictionary:
	var t: Dictionary = Data.CARD[tid]
	var c := {"uid": uid, "tid": tid, "value": int(t.get("value", 0)), "color": str(t.get("color", ""))}
	uid += 1
	return c

func is_num(c: Dictionary) -> bool:
	return T(c).kind == "num"

func is_spell(c: Dictionary) -> bool:
	return T(c).kind == "spell"

func val(c: Dictionary) -> int:
	if T(c).get("dyn", "") == "ash":
		return mini(15, discard.size())
	return int(c.value)

func card_name(c: Dictionary) -> String:
	return Data.card_name(c.tid, c.color, int(c.value))

func has_charm(id: String) -> bool:
	for ch in charms:
		if ch.cid == id:
			return true
	return false

func pick(a: Array):
	return a[rng.randi_range(0, a.size() - 1)]

func shuffled(a: Array) -> Array:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp
	return a

func sel_cards() -> Array:
	return hand.filter(func(c): return c.uid in sel)

func event_every() -> int:
	return 2 if has_charm("seereye") else 3

func boost_color() -> String:
	for m in mods:
		if m.type == "boost":
			return m.color
	return ""

func same_color(nums: Array) -> bool:
	var cols := {}
	for c in nums:
		if c.color != "rainbow":
			cols[c.color] = true
	return cols.size() <= 1

func is_combo(cards: Array) -> bool:
	var nums := cards.filter(is_num)
	return nums.size() >= 3 and same_color(nums)

static func mirror_num(n: int) -> int:
	var s := str(absi(n)).reverse()
	return (-1 if n < 0 else 1) * int(s)

static func is_prime(n: int) -> bool:
	if n < 2:
		return false
	var i := 2
	while i * i <= n:
		if n % i == 0:
			return false
		i += 1
	return true

# ───────── Hesaplama ─────────
## Seçimin sonucunu hesaplar: {total, expr, tol, hit}
func evaluate(cards: Array, tgt: int = -1) -> Dictionary:
	if tgt < 0:
		tgt = target
	var bc := boost_color()
	var nums := cards.filter(is_num)
	var ops: Array = []
	var wilds: Array = []
	var adds: Array = []
	for c in cards:
		var k = T(c).kind
		if k == "op":
			ops.append(T(c))
		elif k == "wild":
			wilds.append(T(c))
		elif k == "add" or k == "curse":
			adds.append(c)
	var has := func(o: String) -> Array: return ops.filter(func(t): return t.op == o)

	var nv: Array = []
	for c in nums:
		if boss == "redban" and c.color == "red":
			nv.append(0)
		else:
			nv.append(val(c) * (2 if bc != "" and c.color == bc else 1))
	if has.call("equalize").size() > 0 and nv.size() > 0:
		var m: int = nv.max()
		nv = nv.map(func(_v): return m)
	var max_n: int = nv.max() if nv.size() > 0 else 0
	var terms: Array = nv.map(func(v): return str(v))
	var fixed := 0
	for v in nv:
		fixed += v
	for c in adds:
		var v := val(c)
		fixed += v
		terms.append(("−%d" % absi(v)) if v < 0 else str(v))
	for _t in has.call("copy"):
		fixed += max_n
		terms.append("↺%d" % max_n)
	for _t in has.call("per_card"):
		fixed += cards.size()
		terms.append(str(cards.size()))
	if nums.size() >= 2 and same_color(nums):
		for t in has.call("discipline"):
			fixed += int(t.value)
			terms.append(str(t.value))

	var mul := 1
	for t in has.call("mul"):
		mul *= int(t.value)
	var div := 1
	for t in has.call("div"):
		div *= int(t.value)
	var sq: bool = has.call("square").size() > 0
	var mir: bool = has.call("mirror").size() % 2 == 1
	var tol := maxi(tol_next, 1 if has_charm("nearshot") else 0)
	for t in has.call("tolerance"):
		tol = maxi(tol, int(t.value))

	var calc := func(w: int) -> int:
		var b := fixed + w
		if sq:
			b = b * b
		var r: int = (b * mul) / div
		return mirror_num(r) if mir else r

	var ws := 0
	if wilds.size() > 0:
		var lo := wilds.size()
		var hi := 0
		for t in wilds:
			hi += int(t.max)
		var bd := 1 << 30
		for s in range(lo, hi + 1):
			var d := absi(calc.call(s) - tgt)
			if d < bd:
				bd = d
				ws = s
		terms.append("★%d" % ws)
	var total: int = calc.call(ws)
	var e := " + ".join(PackedStringArray(terms)).replace("+ −", "− ") if terms.size() > 0 else "0"
	if sq:
		e = "(%s)²" % e
	elif (mul > 1 or div > 1) and terms.size() > 1:
		e = "(%s)" % e
	if mul > 1:
		e += " ×%d" % mul
	if div > 1:
		e += " ÷%d" % div
	if mir:
		e = "⇄ " + e
	return {"total": total, "expr": e, "tol": tol, "hit": absi(total - tgt) <= tol}

# ───────── Bahis ve oran ─────────
## Masa minimumu: tur ilerledikçe büyür
static func min_bet_for(r: int) -> int:
	return 2 + maxi(1, r)

func min_bet() -> int:
	return min_bet_for(round)

## Bahis seçenekleri (fiş): minimumun 1, 2 ve 4 katı
func bet_options() -> Array:
	return BET_STEPS.map(func(k): return min_bet() * k)

## Bu oynamada yatırılacak bahis (fiş yetmezse elindeki kadar)
func bet() -> int:
	return clampi(min_bet() * BET_STEPS[bet_level], 0, maxi(0, gold))

func set_bet(i: int) -> void:
	bet_level = clampi(i, 0, BET_STEPS.size() - 1)

## Kart sayısına göre temel oran (N'e 1): az kartla tutturmak daha çok öder
static func base_odds(n: int) -> int:
	return {1: 4, 2: 3, 3: 2}.get(n, 1)

## İsabet ödemesi: bahis × oran (× katlayan etkiler). steps animasyonda tek tek gösterilir.
## Dönen sözlükte chips = bahis, mult = toplam oran (katlayıcılar dahil), total = kazanç.
func score_play(cards: Array, preview := false) -> Dictionary:
	var acc := {"chips": bet(), "mult": float(base_odds(cards.size())), "x": 1.0}
	var steps: Array = []
	_push(acc, steps, {"t": "bet"}, "Bahis %d fiş" % acc.chips, "chips")
	_push(acc, steps, {"t": "dial"}, "%d kart · %d:1" % [cards.size(), int(acc.mult)], "mult")
	var combo := is_combo(cards)
	if combo:
		acc.mult += 1
		_push(acc, steps, {"t": "combo"}, "Renk serisi +1 oran", "mult")
	for c in cards:
		if T(c).get("on_hit", "") == "triple":
			acc.x *= 3
			_push(acc, steps, {"t": "card", "uid": c.uid}, "Kazanç ×3", "x")
			break
	var nums := cards.filter(is_num)
	var stones := master.filter(func(c): return c.tid == "stone").size()
	for i in charms.size():
		_charm_score(i, charms[i], cards, nums, combo, stones, preview, acc, steps)
	var mult: float = acc.mult * acc.x
	return {"steps": steps, "chips": int(acc.chips), "mult": mult, "total": int(floor(acc.chips * mult)), "combo": combo}

func _push(acc: Dictionary, steps: Array, src: Dictionary, label: String, kind: String) -> void:
	steps.append({"src": src, "label": label, "kind": kind, "chips": int(acc.chips), "mult": acc.mult * acc.x})

func _charm_score(i: int, ch: Dictionary, cards: Array, nums: Array, combo: bool, stones: int, preview: bool, acc: Dictionary, steps: Array) -> void:
	var src := {"t": "charm", "i": i}
	var add_odds := func(n: float) -> void:
		acc.mult += n
		_push(acc, steps, src, "+%s oran" % fmt_mult(n), "mult")
	var times := func(n: float) -> void:
		acc.x *= n
		_push(acc, steps, src, "Kazanç ×%s" % fmt_mult(n), "x")
	match ch.cid:
		"c_red", "c_blue", "c_green", "c_gold":
			var col: String = ch.cid.substr(2)
			if nums.any(func(c): return c.color == col or c.color == "rainbow"):
				add_odds.call(1)
		"crowd":
			if cards.size() >= 4: add_odds.call(2)
		"lone":
			if cards.size() <= 2: add_odds.call(2)
		"hunter":
			if combo: add_odds.call(2)
		"hoarder":
			if discards >= 2: add_odds.call(discards / 2)
		"even":
			if target % 2 == 0: add_odds.call(1)
		"spellbag":
			if spells_round > 0: add_odds.call(spells_round)
		"firststrike":
			if plays_used == 0: times.call(2)
		"prime":
			if is_prime(target): times.call(2)
		"gambler":
			if not preview:
				var n := rng.randi_range(0, 3)
				if n > 0: add_odds.call(n)
		"stoneheart":
			if stones > 0: add_odds.call(stones)
		"giant":
			if target >= 30: times.call(2)
		"infinity":
			var m := int(ch.state.get("m", 0)) / 3
			if m > 0: add_odds.call(m)
		"crown":
			times.call(3)

## Fişi masa minimumunun altına düşen oyuncuya kasa borç verir; destene Senet girer
func _take_loan() -> void:
	var amt := min_bet() * 3
	gold += amt
	loans += 1
	var c := inst("stone")
	master.append(c)
	draw.append(c)
	fx.append({"type": "loan", "amount": amt})

static func fmt_mult(m: float) -> String:
	return str(int(m)) if is_equal_approx(m, roundf(m)) else "%.1f" % m

# ───────── Deste işlemleri ─────────
func new_target() -> int:
	var lo := 6 + 2 * round
	var hi := 12 + 3 * round
	var t := target
	while t == target:
		t = rng.randi_range(lo, hi)
	return t

func hand_limit() -> int:
	return hand_size + (-1 if boss == "heavy" else 0)

func _on_drawn(c: Dictionary) -> Dictionary:
	var roll = T(c).get("roll")
	if roll:
		c.value = rng.randi_range(roll[0], roll[1])
	return c

func draw_one():
	if draw.is_empty():
		if discard.is_empty():
			return null
		draw = shuffled(discard)
		discard = []
	return _on_drawn(draw.pop_back())

func refill() -> void:
	while hand.size() < hand_limit():
		var c = draw_one()
		if c == null:
			break
		hand.append(c)
	sort_hand()

func draw_n(n: int) -> void:
	for i in n:
		var c = draw_one()
		if c == null:
			break
		hand.append(c)
	sort_hand()

func insert_random(c: Dictionary) -> void:
	draw.insert(rng.randi_range(0, draw.size()), c)

func remove_forever(c: Dictionary) -> void:
	var f := func(x): return x.uid != c.uid
	master = master.filter(f)
	hand = hand.filter(f)
	draw = draw.filter(f)
	discard = discard.filter(f)
	sel = sel.filter(func(id): return id != c.uid)

func sort_hand() -> void:
	if sort_mode == "":
		return
	hand.sort_custom(_cmp_hand)

func _hand_key(c: Dictionary) -> Array:
	var k: int = Data.KIND_ORDER[T(c).kind]
	if sort_mode == "color":
		return [k, Data.SUIT_KEYS.find(c.color), int(c.value)]
	return [k, int(c.value), Data.SUIT_KEYS.find(c.color)]

func _cmp_hand(a: Dictionary, b: Dictionary) -> bool:
	var A := _hand_key(a)
	var B := _hand_key(b)
	for i in 3:
		if A[i] != B[i]:
			return A[i] < B[i]
	return false

## Açık kart havuzu ve nadirliğe göre rastgele seçim
func collectible(p_cls: String) -> Array:
	return Data.SPECIAL_CARDS.filter(func(c): return not c.get("no_collect", false) and (c.cls == "neutral" or c.cls == p_cls))

func weighted_pick(pool: Array, luck := 1.0, p_cls := ""):
	if pool.is_empty():
		return null
	var w := func(c) -> float:
		return float(Data.RARITY[c.rarity].w) * (1.0 if c.rarity == "common" else luck) * (1.5 if p_cls != "" and c.get("cls", "") == p_cls else 1.0)
	var total := 0.0
	for c in pool:
		total += w.call(c)
	var r := rng.randf() * total
	for c in pool:
		r -= w.call(c)
		if r <= 0:
			return c
	return pool[-1]

func roll_card_id(luck := 1.0, exclude: Array = []) -> String:
	var pool := collectible(cls).filter(func(c): return Progress.is_unlocked(c.id) and not c.id in exclude)
	if pool.is_empty():
		pool = collectible(cls).filter(func(c): return Progress.is_unlocked(c.id))
	var c = weighted_pick(pool, luck, cls)
	return c.id if c else "add5"

func roll_charm_id(exclude: Array = []) -> String:
	var pool := Data.CHARMS.filter(func(c): return Progress.is_unlocked(c.id) and not has_charm(c.id) and not c.id in exclude)
	var c = weighted_pick(pool)
	return c.id if c else ""

# ───────── Oyun akışı ─────────
## story: hikâye modu (her kat bir bölüm, engel turu kazanılınca hikâye ilerler)
func start(p_cls: String, deck_ids: Array, tutorial := false, p_story := false) -> void:
	cls = p_cls
	story = p_story
	uid = 1
	master = deck_ids.map(func(id): return inst(id))
	next_event = pick_next_event("")
	tut = {"step": 0} if tutorial else {}
	Progress.add_stat("runs")
	Progress.save()
	start_round()
	if not tut.is_empty():
		_tut_setup()

## Masa hedefi (net kazanılacak fiş): minimum × (masa türü + kat)
static func goal_for(r: int) -> int:
	var f := ceili(r / 3.0)
	return min_bet_for(r) * ([3, 5, 7][(r - 1) % 3] + f)

func start_round() -> void:
	round += 1
	rtype = ["small", "big", "boss"][(round - 1) % 3]
	boss = pick(Data.BOSSES.keys()) if rtype == "boss" else ""
	if story and rtype == "small":
		# yeni kat = hikâyenin sıradaki bölümü (hikâye bittiyse serbest devam)
		story_ch = 0 if Progress.story_finished() else Progress.story_done() + 1
		if story_ch > 0 and not Progress.story_seen(story_ch):
			Progress.mark_seen(story_ch)
			fx.append({"type": "scene", "part": "intro", "ch": story_ch})
	if story and rtype == "boss" and story_ch > 0:
		boss = Data.STORY[story_ch - 1].boss
	goal = goal_for(round)
	round_score = 0
	last_score = {}
	draw = shuffled(master.duplicate())
	discard = []
	hand = []
	sel = []
	var plays_mod := 0
	for ch in charms:
		plays_mod += int(Data.CHARM[ch.cid].get("plays_mod", 0))
	plays = maxi(1, max_plays + plays_mod + (-1 if boss == "short" else 0))
	discards = 0 if boss == "nodiscard" else max_discards
	mods = []
	plays_used = 0
	spells_round = 0
	power_used = false
	shield = false
	tol_next = 0
	if not tut.is_empty() and round == 1:
		plays = 9
		goal = 30
	target = new_target()
	refill()
	if boss != "":
		msg = "Engel: %s. %s" % [Data.BOSSES[boss].name, Data.BOSSES[boss].text]
		msg_kind = "miss"
		fx.append({"type": "boss"})
	else:
		msg = "Tur %d: masadan %d fiş kazan. Minimum bahis %d." % [round, goal, min_bet()]
		msg_kind = ""
	modal = {}
	if event_due:
		event_due = false
		fire_event()

func retry_round() -> void:
	round -= 1
	start_round()
	msg = "Tur %d yeniden başladı. Masadan %d fiş kazan." % [round, goal]

func toggle(card_uid: int) -> void:
	if card_uid in sel:
		sel.erase(card_uid)
	else:
		sel.append(card_uid)
	tut_event("select")

func play() -> void:
	if not modal.is_empty() or sel.is_empty():
		return
	var cards := sel_cards()
	if cards.any(is_spell):
		if cards.size() == 1:
			cast_spell(cards[0])
		else:
			msg = "Hamle kartları tek başına kullanılır."
			msg_kind = "miss"
		return
	if plays <= 0:
		return
	var loan_msg := ""
	if gold < min_bet():
		_take_loan()
		loan_msg = " Kasa %d fiş borç verdi, destene bir Senet girdi." % (min_bet() * 3)
	var stake := bet()
	var r := evaluate(cards)
	var sc: Dictionary = score_play(cards) if r.hit else {}
	last_play = {"uids": sel.duplicate(), "hit": r.hit, "score": sc, "bet": stake}
	plays -= 1
	hand = hand.filter(func(c): return not c.uid in sel)
	discard += cards
	sel = []
	tol_next = 0
	var extra_draw := 0
	for c in cards:
		var h = T(c).get("on_play", "")
		if h == "lose_discard":
			discards = maxi(0, discards - 1)
		if h == "draw1":
			extra_draw += 1
	plays_used += 1
	if r.hit:
		ev_count += 1
		for c in cards:
			var h = T(c).get("on_hit", "")
			if h == "omen":
				ev_count += 1
			if h == "heal" and lives < MAX_LIVES:
				lives += 1
				fx.append({"type": "heal"})
		round_score += sc.total
		score += sc.total
		gold += sc.total
		var g := 0
		for ch in charms:
			var d: Dictionary = Data.CHARM[ch.cid]
			g += int(d.get("gold", 0)) * min_bet()
			if ch.cid == "infinity":
				ch.state["m"] = int(ch.state.get("m", 0)) + 1
		gold += g
		Progress.add_stat("hits")
		Progress.achieve("firsthit")
		if sc.combo:
			Progress.achieve("combo")
		if cards.size() >= 5:
			Progress.achieve("five")
		if sc.total >= 60:
			Progress.achieve("big200")
		msg = "%s%d fiş × %s = +%d fiş%s." % ["Renk serisi! " if sc.combo else "İsabet! ", sc.chips, fmt_mult(sc.mult), sc.total, (", +%d" % g) if g > 0 else ""]
		if r.total != target:
			msg += " (%d ≈ %d)" % [r.total, target]
		msg_kind = "hit"
		fx.append({"type": "hit", "combo": sc.combo, "pts": sc.total})
	else:
		if cards.any(func(c): return T(c).get("on_miss", "") == "lose_play"):
			plays = maxi(0, plays - 1)
		gold -= stake
		round_score -= stake
		msg = "Iska: %d, hedef %d. Bahis gitti: −%d fiş." % [r.total, target, stake]
		msg_kind = "miss"
		fx.append({"type": "miss"})
	last_score = sc
	msg += loan_msg
	for c in cards:
		if T(c).get("exhaust", false):
			remove_forever(c)
	for m in mods:
		m.turns -= 1
	mods = mods.filter(func(m): return m.turns > 0)
	refill()
	draw_n(extra_draw)
	Progress.save()
	check_ach()
	var event_ready := ev_count >= event_every()
	if round_score >= goal:
		if event_ready:
			event_due = true
		_round_cleared()
	elif plays <= 0:
		if event_ready:
			event_due = true
		_lose_life()
	else:
		if r.hit or boss == "slippery":
			target = new_target()
			msg += " Yeni hedef: %d." % target
		if not check_stuck() and event_ready:
			fire_event()
	if r.hit:
		tut_event("hit")

func _round_cleared() -> void:
	Progress.submit_score(score)
	Progress.add_stat("rounds")
	Progress.p.stats["best_round"] = maxi(Progress.stat("best_round"), round)
	if round >= 3: Progress.achieve("round3")
	if round >= 6: Progress.achieve("round6")
	if round >= 9: Progress.achieve("round9")
	if rtype == "boss": Progress.achieve("boss1")
	if story and rtype == "boss" and story_ch > 0 and Progress.complete_chapter(story_ch):
		fx.append({"type": "scene", "part": "outro", "ch": story_ch})
	Progress.progress_unlock()
	if not tut.is_empty() and tut.step < TUT.size() - 1:
		tut.step = TUT.size() - 1
	var lines: Array = [["%s ödülü" % ROUND_TYPES[rtype], min_bet() * {"small": 1, "big": 2, "boss": 3}[rtype]]]
	if plays > 0:
		lines.append(["Kalan oynama hakkı (%d)" % plays, plays * ceili(min_bet() / 2.0)])
	var total := 0
	for l in lines:
		total += l[1]
	gold += total
	check_ach()
	Progress.save()
	modal = {"type": "cashout", "lines": lines, "total": total}
	fx.append({"type": "round"})

func _lose_life() -> void:
	var gs = null
	for ch in charms:
		if ch.cid == "goldshield":
			gs = ch
	if shield or gs != null:
		var broke := not shield and gs != null
		if broke:
			charms.erase(gs)
		shield = false
		modal = {"type": "life", "shielded": true, "broke": broke}
		fx.append({"type": "shield"})
		return
	lives -= 1
	Progress.submit_score(score)
	fx.append({"type": "life_lost", "i": lives})
	modal = {"type": "over"} if lives <= 0 else {"type": "life"}

## Deste tükendiyse oynanacak kart kalmaz: tur kaybedilmiş sayılır
func check_stuck() -> bool:
	if not hand.is_empty() or not modal.is_empty():
		return false
	msg = "Destende oynanacak kart kalmadı."
	msg_kind = "miss"
	_lose_life()
	return true

func swap_cards() -> void:
	if not modal.is_empty() or sel.is_empty() or discards <= 0:
		return
	var cards := sel_cards()
	hand = hand.filter(func(c): return not c.uid in sel)
	discard += cards
	sel = []
	discards -= 1
	refill()
	msg = "%d kart değiştirildi." % cards.size()
	msg_kind = ""
	tut_event("swap")

func close_modal() -> void:
	modal = {}
	refill()
	check_stuck()

func check_ach() -> void:
	if gold >= 100: Progress.achieve("rich")
	if lives >= 4: Progress.achieve("lives4")
	if charms.size() >= 3: Progress.achieve("charms3")
	if score >= 500: Progress.achieve("score1000")
	if Progress.stat("spells") >= 10: Progress.achieve("spells10")

# ───────── Büyüler ─────────
func cast_spell(c: Dictionary) -> void:
	if boss == "silence":
		msg = "Polis Baskını: bu tur hamle kartı kullanılamaz."
		msg_kind = "miss"
		return
	var t := T(c)
	last_play = {"uids": [c.uid], "spell": true, "cls": t.cls}
	hand = hand.filter(func(x): return x.uid != c.uid)
	discard.append(c)
	sel = []
	var res := _spell(t.spell)
	if t.get("exhaust", false):
		remove_forever(c)
	spells_round += 1
	Progress.add_stat("spells")
	msg = "%s: %s" % [t.name, res]
	msg_kind = "spell"
	fx.append({"type": "spell", "name": t.name, "cls": t.cls})
	refill()
	Progress.save()
	check_ach()
	tut_event("spell")
	if check_stuck():
		return
	if ev_count >= event_every() and modal.is_empty():
		fire_event()

func _spell(id: String) -> String:
	match id:
		"draw2":
			draw_n(2)
			return "2 kart çektin."
		"recall":
			for i in range(discard.size() - 1, -1, -1):
				if is_num(discard[i]):
					var c: Dictionary = discard.pop_at(i)
					hand.append(c)
					sort_hand()
					return "%s eline döndü." % card_name(c)
			return "Iskartada sayı kartı yoktu."
		"paint":
			var cnt := {}
			for c in hand:
				if is_num(c) and c.color != "rainbow":
					cnt[c.color] = cnt.get(c.color, 0) + 1
			if cnt.is_empty():
				return "Elinde boyanacak sayı kartı yoktu."
			var col: String = cnt.keys()[0]
			for k in cnt:
				if cnt[k] > cnt[col]:
					col = k
			for c in hand:
				if is_num(c) and c.color != "rainbow":
					c.color = col
			return "Sayı kartların %s oldu." % Data.SUITS[col].name.to_lower()
		"shield":
			shield = true
			return "Bu tur can kaybetmeyeceksin."
		"plays2":
			plays += 2
			return "+2 oynama hakkı."
		"plays1":
			plays += 1
			return "+1 oynama hakkı."
		"compass":
			var old := target
			target = maxi(4, target - rng.randi_range(1, 3))
			return "Hedef %d iken %d oldu." % [old, target]
		"sacrifice":
			plays += 1
			if hand.is_empty():
				return "+1 oynama hakkı."
			var c: Dictionary = pick(hand)
			remove_forever(c)
			return "%s gözden çıkarıldı, +1 oynama hakkı." % card_name(c)
		"transmute":
			var n := 0
			for c in hand:
				if is_num(c) and c.value <= 2:
					c.value = 6
					n += 1
			return ("%d kart 6 oldu." % n) if n > 0 else "Elinde 1 veya 2 yoktu."
		"elixir":
			power_used = false
			draw_n(1)
			return "Karakter gücün yenilendi, 1 kart çektin."
		"flamewave":
			var n := hand.size()
			discard += hand
			hand = []
			draw_n(n + 1)
			return "%d yeni kart çektin." % (n + 1)
		"fuel":
			discards += 1
			if hand.is_empty():
				return "+1 değiştirme hakkı."
			var c: Dictionary = pick(hand)
			remove_forever(c)
			return "%s yandı, +1 değiştirme hakkı." % card_name(c)
		"orb":
			ev_count += 1
			return "Olay sayacı ilerledi."
		"starmap":
			var nums := draw.filter(is_num)
			if nums.is_empty():
				return "Çekme destesinde sayı kartı yok."
			nums.sort_custom(func(a, b): return a.value > b.value)
			var c: Dictionary = nums[0]
			draw.erase(c)
			hand.append(c)
			sort_hand()
			return "%s eline geldi." % card_name(c)
		"thirdeye":
			next_event = pick_next_event(next_event)
			draw_n(1)
			return "Sıradaki olay artık %s." % Data.EVENTS[next_event].name
		"wall":
			shield = true
			discards += 1
			return "Bu tur can kaybetmeyeceksin, +1 değiştirme hakkı."
	return ""

# ───────── Sınıf gücü (tur başına bir kez) ─────────
func use_power() -> void:
	if not modal.is_empty() or power_used:
		return
	var C: Dictionary = Data.CLASSES[cls]
	match cls:
		"alchemist":
			tol_next = 1
			msg = "Kart Sayma: sonraki oynamada 1 farkla da isabet sayılır."
		"pyro":
			if sel.is_empty():
				msg = "Baskın için önce ıskartaya atılacak kartları seç."
				msg_kind = ""
				return
			var cards := sel_cards()
			hand = hand.filter(func(c): return not c.uid in sel)
			discard += cards
			sel = []
			draw_n(cards.size() + 1)
			msg = "Baskın: %d kart atıldı, %d kart çekildi." % [cards.size(), cards.size() + 1]
		"seer":
			var a := pick_next_event(next_event)
			var b := pick_next_event(next_event)
			for i in 10:
				if b != a:
					break
				b = pick_next_event(next_event)
			modal = {"type": "prophecy", "options": [a, b]}
			return
		"guard":
			plays += 1
			msg = "Ev Kuralı: +1 oynama hakkı."
	power_used = true
	msg_kind = "spell"
	fx.append({"type": "power", "name": C.power.name})
	tut_event("power")

func choose_prophecy(id: String) -> void:
	next_event = id
	power_used = true
	modal = {}
	msg = "Sahne: sıradaki olay artık %s." % Data.EVENTS[id].name
	msg_kind = "spell"
	fx.append({"type": "power", "name": "Sahne"})

# ───────── Olaylar ─────────
func pick_next_event(exclude: String) -> String:
	var ids := Data.EVENTS.keys().filter(func(id): return id != exclude)
	var total := 0.0
	for id in ids:
		total += Data.EVENTS[id].w
	var r := rng.randf() * total
	for id in ids:
		r -= Data.EVENTS[id].w
		if r <= 0:
			return id
	return ids[0]

func _event_ok(id: String) -> bool:
	match id:
		"burn": return not hand.is_empty()
		"thief": return hand.any(is_num)
		"boost": return not mods.any(func(m): return m.type == "boost")
		"storm": return discards > 0
		"heal": return lives < MAX_LIVES
	return true

func fire_event() -> void:
	var id := next_event
	if not _event_ok(id):
		id = pick(Data.EVENTS.keys().filter(_event_ok))
	var res := _run_event(id)
	res["type"] = "event"
	res["id"] = id
	modal = res
	ev_count = 0
	next_event = pick_next_event(id)
	fx.append({"type": "event", "tone": Data.EVENTS[id].tone})

func _run_event(id: String) -> Dictionary:
	match id:
		"shift":
			var old := target
			var d := rng.randi_range(1, 4) * (-1 if rng.randf() < 0.5 else 1)
			target = maxi(4, target + d)
			return {"text": "Hedef %d iken %d oldu." % [old, target]}
		"reroll":
			var old := target
			target = new_target()
			return {"text": "Hedef %d yerine artık %d." % [old, target]}
		"gift":
			var c := inst(roll_card_id(1.6))
			master.append(c)
			insert_random(c)
			return {"text": "Destene kalıcı olarak %s eklendi." % card_name(c), "card": c}
		"treasure":
			var g := min_bet() * rng.randi_range(1, 2)
			gold += g
			return {"text": "Kasadan %d fiş payın geldi. Artık %d fişin var." % [g, gold]}
		"stone":
			var c := inst("stone")
			master.append(c)
			draw.append(c)
			return {"text": "Destene bir Senet girdi, sıradaki çekişte eline gelecek. Tüccarda desteden çıkarabilirsin.", "card": c}
		"burn":
			var c: Dictionary = pick(hand)
			remove_forever(c)
			refill()
			return {"text": "Elindeki %s yandı ve desteden tamamen çıktı." % card_name(c), "card": c}
		"thief":
			var nums := hand.filter(is_num)
			nums.sort_custom(func(a, b): return a.value > b.value)
			var c: Dictionary = nums[0]
			remove_forever(c)
			refill()
			return {"text": "En yüksek kartın %s çalındı." % card_name(c), "card": c}
		"boost":
			var col: String = pick(Data.SUIT_KEYS)
			mods.append({"type": "boost", "color": col, "turns": 2})
			return {"text": "Sonraki 2 oynamada %s sayı kartları iki kat değerli." % Data.SUITS[col].name.to_lower()}
		"wind":
			plays += 1
			return {"text": "Bu tur için +1 oynama hakkı kazandın."}
		"storm":
			discards -= 1
			return {"text": "Bu tur 1 değiştirme hakkını kaybettin."}
		"shadow":
			var c := inst("shadow2" if rng.randf() < 0.7 else "shadow5")
			master.append(c)
			insert_random(c)
			return {"text": "Destene %s eklendi. Toplamdan düşer, ince ayar için işe yarar." % card_name(c), "card": c}
		"swap":
			discard += hand
			hand = []
			sel = []
			refill()
			return {"text": "Elindeki tüm kartlar ıskartaya gitti, yeni bir el çekildi."}
		"heal":
			lives += 1
			fx.append({"type": "heal"})
			return {"text": "Bir can kazandın. Artık %d canın var." % lives}
	return {"text": ""}

# ───────── Tüccar ─────────
## Tüccar fiyatı: temel fiyat masa minimumuyla büyür; Karaborsa Dostu %25 indirir
func price_of(base: int) -> int:
	var p := ceili(base * min_bet() / 3.0)
	if has_charm("merchant"):
		p = ceili(p * 0.75)
	return maxi(1, p)

func remove_cost() -> int:
	return price_of(3)

func card_price(c: Dictionary) -> int:
	return price_of(Data.RARITY[T(c).rarity].price)

func charm_price(id: String) -> int:
	return price_of(Data.RARITY[Data.CHARM[id].rarity].price + 1)

func charm_sell_price(id: String) -> int:
	return maxi(1, charm_price(id) / 2)

func _stock_shop() -> Dictionary:
	var cs: Array = []
	var tids: Array = []
	for i in 3:
		var c := inst(roll_card_id(1.0, tids))
		tids.append(c.tid)
		cs.append({"c": c, "sold": false})
	var ch: Array = []
	var ids: Array = []
	for i in 2:
		var id := roll_charm_id(ids)
		if id != "":
			ids.append(id)
			ch.append({"id": id, "sold": false})
	var perks := PERKS.keys().filter(func(k): return not (k == "life" and lives >= MAX_LIVES) and not (k == "hand" and hand_size >= 9))
	var perk: String = "life" if lives < MAX_LIVES and rng.randf() < 0.45 else pick(perks)
	return {"cards": cs, "charms": ch, "perk": {"k": perk, "sold": false}}

func open_shop() -> void:
	shop = _stock_shop()
	shop["reroll_cost"] = price_of(2)
	shop["removed"] = false
	modal = {"type": "shop"}

func buy(kind: String, i: int) -> bool:
	if kind == "card":
		var o: Dictionary = shop.cards[i]
		var p := card_price(o.c)
		if o.sold or gold < p:
			return false
		gold -= p
		o.sold = true
		master.append(o.c)
		msg = "%s destene eklendi." % card_name(o.c)
	elif kind == "charm":
		var o: Dictionary = shop.charms[i]
		var p := charm_price(o.id)
		if o.sold or gold < p or charms.size() >= MAX_CHARMS:
			return false
		gold -= p
		o.sold = true
		charms.append({"uid": uid, "cid": o.id, "state": {}})
		uid += 1
		msg = "%s takıldı." % Data.CHARM[o.id].name
	elif kind == "perk":
		var o: Dictionary = shop.perk
		var p := price_of(PERKS[o.k].price)
		if o.sold or gold < p:
			return false
		gold -= p
		o.sold = true
		match o.k:
			"life":
				if lives < MAX_LIVES:
					lives += 1
					fx.append({"type": "heal"})
			"play": max_plays += 1
			"discard": max_discards += 1
			"hand": hand_size += 1
	msg_kind = ""
	fx.append({"type": "buy"})
	check_ach()
	return true

func sell_charm(i: int) -> void:
	if i < 0 or i >= charms.size():
		return
	gold += charm_sell_price(charms[i].cid)
	charms.remove_at(i)

func reroll() -> void:
	if gold < shop.reroll_cost:
		return
	gold -= shop.reroll_cost
	var cost: int = shop.reroll_cost + maxi(1, min_bet() / 3)
	var removed: bool = shop.removed
	shop = _stock_shop()
	shop["reroll_cost"] = cost
	shop["removed"] = removed

func remove_card_paid(card_uid: int) -> bool:
	var cost := remove_cost()
	if gold < cost or shop.get("removed", true) or master.size() <= 12:
		return false
	for c in master:
		if c.uid == card_uid:
			remove_forever(c)
			gold -= cost
			shop.removed = true
			return true
	return false

func next_round() -> void:
	tut_event("shopnext")
	shop = {}
	start_round()

# ───────── Öğretici ─────────
func tut_step() -> Dictionary:
	if tut.is_empty() or tut.step >= TUT.size():
		return {}
	return TUT[tut.step]

func _set_hand(ids: Array) -> void:
	discard += hand
	hand = []
	for id in ids:
		var c := inst(id)
		master.append(c)
		hand.append(c)
	sel = []

func _add_to_hand(ids: Array) -> void:
	for id in ids:
		var c := inst(id)
		master.append(c)
		hand.append(c)

func _tut_setup() -> void:
	match int(tut.step):
		1:
			_set_hand(["n-red-4", "n-blue-6", "n-green-2", "n-gold-3", "n-red-1", "n-blue-5", "n-green-7"])
			target = 10
		5:
			_add_to_hand(["n-green-6", "mul2"])
			target = 12
		6:
			_add_to_hand(["scout"])

func tut_event(ev: String) -> void:
	var st := tut_step()
	if st.is_empty() or st.get("on", "") != ev:
		return
	if ev == "select" and not evaluate(sel_cards()).hit:
		return
	tut_advance()

func tut_advance() -> void:
	if tut.is_empty():
		return
	tut.step += 1
	if tut.step >= TUT.size():
		end_tutorial()
		return
	_tut_setup()

func end_tutorial() -> void:
	tut = {}
	Progress.p.tutorial_done = true
	Progress.save()
	Progress.achieve("tutorial")
