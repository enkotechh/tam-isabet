extends Node
## Kalıcı ilerleme (autoload: Progress): açılan kartlar/tılsımlar/sınıflar, başarımlar,
## istatistikler, rekor ve kayıtlı desteler. user://progress.json dosyasına yazılır.

signal toast(info: Dictionary)

const SAVE_PATH := "user://progress.json"

var p: Dictionary = {}
var best: int = 0
var decks: Dictionary = {}
var save_enabled := true   ## testlerde kapatılır
var silent := false        ## true iken bildirim üretilmez

func _ready() -> void:
	load_data()

func fresh() -> Dictionary:
	return {
		"v": 1,
		"unlocked": Data.STARTER_UNLOCKS.duplicate(),
		"classes": Data.STARTER_CLASSES.duplicate(),
		"ach": [],
		"stats": {"rounds": 0, "hits": 0, "spells": 0, "runs": 0, "best_round": 0},
		"tutorial_done": false,
	}

func load_data() -> void:
	p = fresh()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return
	if typeof(d.get("progress")) == TYPE_DICTIONARY and int(d.progress.get("v", 0)) == 1:
		p = d.progress
	best = int(d.get("best", 0))
	if typeof(d.get("decks")) == TYPE_DICTIONARY:
		decks = d.decks

func save() -> void:
	if not save_enabled:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"progress": p, "best": best, "decks": decks}))

func reset() -> void:
	p = fresh()
	best = 0
	decks = {}
	save()

func stat(key: String) -> int:
	return int(p.stats.get(key, 0))

func add_stat(key: String, n: int = 1) -> void:
	p.stats[key] = stat(key) + n

func is_unlocked(id: String) -> bool:
	return id in p.unlocked

func class_open(k: String) -> bool:
	return k in p.classes

func unlock(id: String) -> void:
	if id.begins_with("class:"):
		var k := id.substr(6)
		if k in p.classes:
			return
		p.classes.append(k)
		for c in Data.CLASS_UNLOCK_CARDS.get(k, []):
			if not is_unlocked(c):
				p.unlocked.append(c)
		_toast({"kind": "class", "id": k})
		save()
		return
	if is_unlocked(id):
		return
	p.unlocked.append(id)
	_toast({"kind": "charm" if Data.CHARM.has(id) else "card", "id": id})
	save()

func achieve(id: String) -> void:
	if id in p.ach:
		return
	for a in Data.ACHIEVEMENTS:
		if a.id == id:
			p.ach.append(id)
			_toast({"kind": "ach", "id": id})
			for u in a.unlocks:
				unlock(u)
			save()
			return

## Her geçilen tur, sıradaki kilitli kartı/tılsımı açar (nadirliğe göre basitten nadire)
func progress_unlock() -> void:
	for u in Data.UNLOCK_ORDER:
		if not is_unlocked(u.id) and (u.cls == "neutral" or u.cls in p.classes):
			unlock(u.id)
			return

func submit_score(score: int) -> void:
	if score > best:
		best = score
		save()

func deck_for(cls: String) -> Array:
	var d = decks.get(cls)
	if typeof(d) == TYPE_ARRAY and d.size() == RunState.DECK_SIZE:
		var ok := true
		for id in d:
			if not Data.CARD.has(id) or not is_unlocked(id):
				ok = false
				break
		if ok:
			return d
	return Data.RECOMMENDED[cls]

func save_deck(cls: String, list: Array) -> void:
	decks[cls] = list.duplicate()
	save()

func _toast(info: Dictionary) -> void:
	if not silent:
		toast.emit(info)
