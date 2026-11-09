extends Node
## Port Halloway — oyun verileri (autoload: Data).
## Renkler, nadirlikler, sınıflar, kartlar, tılsımlar, bekçiler, olaylar, başarımlar ve kilit sırası.
## Etkiler RunState içinde kart/tılsım/olay kimliğine göre işlenir.

const SUITS := {
	"red": {"name": "Kızıl", "color": Color("ff5a4b"), "gem": Color("d23b2f")},
	"blue": {"name": "Mavi", "color": Color("4b8dff"), "gem": Color("2f6fd6")},
	"green": {"name": "Yeşil", "color": Color("34c97f"), "gem": Color("22975c")},
	"gold": {"name": "Sarı", "color": Color("ffc23a"), "gem": Color("d29a1c")},
}
const SUIT_KEYS := ["red", "blue", "green", "gold"]

## Nadirlik: basitten nadire beyaz, mavi, mor, sarı, kırmızı
const RARITY := {
	"common": {"name": "Sıradan", "color": Color("ece7db"), "w": 60.0, "max": 2, "price": 3},
	"rare": {"name": "Nadir", "color": Color("4b8dff"), "w": 26.0, "max": 2, "price": 5},
	"unique": {"name": "Ender", "color": Color("b066ff"), "w": 10.0, "max": 2, "price": 7},
	"legendary": {"name": "Efsanevi", "color": Color("f5c518"), "w": 4.0, "max": 1, "price": 9},
	"epic": {"name": "Epik", "color": Color("ff3b3b"), "w": 1.5, "max": 1, "price": 12},
}
const RARITY_ORDER := ["common", "rare", "unique", "legendary", "epic"]

const CLASS_COLORS := {
	"neutral": [Color("7a634a"), Color("2e2219")],
	"guard": [Color("356fc6"), Color("0d2045")],
	"alchemist": [Color("2f9b66"), Color("0d3221")],
	"pyro": [Color("d5532c"), Color("470f07")],
	"seer": [Color("7b55dd"), Color("1f114a")],
	"curse": [Color("77737d"), Color("2a282e")],
	"charm": [Color("3b2d55"), Color("150e24")],
}

const CLASSES := {
	"guard": {"name": "Silas Crane", "icon": "shield", "tagline": "Sıfırdan geldi, her şeyini sıfıra oynar.",
		"power": {"name": "Ev Kuralı", "icon": "tower", "text": "Bu tur +1 oynama hakkı kazan."}},
	"alchemist": {"name": "Eddie Finch", "icon": "flask", "tagline": "Kart sayar, sonucu kuruşu kuruşuna hesaplar.",
		"power": {"name": "Kart Sayma", "icon": "potion", "text": "Sonraki oynamada toplam hedefe 1 uzaksa da isabet sayılır."}},
	"pyro": {"name": "Dedektif Harlow", "icon": "flame", "tagline": "Baskın yapar, masayı dağıtıp yeniden kurar.",
		"power": {"name": "Baskın", "icon": "spark", "text": "Seçili kartları ıskartaya at, yerine 1 fazlasını çek. Değiştirme hakkı harcamaz."}},
	"seer": {"name": "Vivienne Rook", "icon": "eye", "tagline": "Sahneden herkesi görür, olayları yönlendirir.",
		"power": {"name": "Sahne", "icon": "orb", "text": "Sıradaki olayı iki seçenekten biriyle değiştir."}},
}
const CLASS_KEYS := ["guard", "alchemist", "pyro", "seer"]

## Özel kartlar.
## kind: num (renkli sayı) | add (renksiz değer) | op (işlem) | wild (joker) | spell (hamle) | curse
const SPECIAL_CARDS := [
	# Nötr
	{"id": "mul2", "name": "Katla", "cls": "neutral", "rarity": "rare", "kind": "op", "op": "mul", "value": 2, "gem": "×2", "glyph": "×2", "text": "Seçimin toplamını 2 katına çıkarır."},
	{"id": "mul3", "name": "Üçe Katla", "cls": "neutral", "rarity": "unique", "kind": "op", "op": "mul", "value": 3, "gem": "×3", "glyph": "×3", "text": "Seçimin toplamını 3 katına çıkarır."},
	{"id": "div2", "name": "Yarı Yarıya", "cls": "neutral", "rarity": "common", "kind": "op", "op": "div", "value": 2, "gem": "÷2", "glyph": "÷2", "text": "Toplamı ikiye böler, küsuratı atar."},
	{"id": "joker", "name": "Joker", "cls": "neutral", "rarity": "rare", "kind": "wild", "max": 9, "gem": "★", "icon": "star", "text": "1 ile 9 arasında gereken değeri alır."},
	{"id": "shadow2", "name": "Komisyon", "cls": "neutral", "rarity": "common", "kind": "add", "value": -2, "gem": "−2", "icon": "moon", "text": "Toplamdan 2 düşer."},
	{"id": "shadow5", "name": "Haraç", "cls": "neutral", "rarity": "rare", "kind": "add", "value": -5, "gem": "−5", "icon": "moon", "text": "Toplamdan 5 düşer."},
	{"id": "add5", "name": "Bahşiş", "cls": "neutral", "rarity": "common", "kind": "add", "value": 5, "gem": "+5", "glyph": "+5", "text": "Toplama 5 ekler."},
	{"id": "add10", "name": "Para Tomarı", "cls": "neutral", "rarity": "rare", "kind": "add", "value": 10, "gem": "+10", "glyph": "+10", "text": "Toplama 10 ekler."},
	{"id": "square", "name": "Borsa Rüzgârı", "cls": "neutral", "rarity": "legendary", "kind": "op", "op": "square", "gem": "x²", "icon": "rune", "text": "Toplamın karesini alır. Çarpanlardan önce uygulanır."},
	{"id": "mirror", "name": "Sahte Defter", "cls": "neutral", "rarity": "legendary", "kind": "op", "op": "mirror", "gem": "⇄", "icon": "mirror", "text": "Sonucun basamaklarını ters çevirir: 17, 71 olur."},
	{"id": "equal", "name": "Ayarlı Masa", "cls": "neutral", "rarity": "rare", "kind": "op", "op": "equalize", "gem": "=", "icon": "scale", "text": "Seçimdeki tüm sayı kartları en yükseğinin değerini alır."},
	{"id": "echo", "name": "Tekrar Bahis", "cls": "neutral", "rarity": "common", "kind": "op", "op": "copy", "gem": "↺", "icon": "copy", "text": "Seçimdeki en yüksek sayı kartının değerini bir kez daha ekler."},
	{"id": "rainbow", "name": "Kaçak İçki", "cls": "neutral", "rarity": "rare", "kind": "num", "value": 3, "color": "rainbow", "icon": "rainbow", "text": "Değeri 3. Her rengin yerine geçer, renk serisini tamamlar."},
	{"id": "dice", "name": "Barbut Zarı", "cls": "neutral", "rarity": "rare", "kind": "add", "roll": [1, 12], "value": 6, "gem": "?", "icon": "dice", "text": "Eline her geldiğinde değeri 1–12 arasında yeniden belirlenir."},
	{"id": "coin", "name": "Altın Fiş", "cls": "neutral", "rarity": "unique", "kind": "num", "value": 7, "color": "gold", "icon": "coin", "on_hit": "triple", "on_miss": "lose_play", "text": "Değeri 7. İsabette kazanç ×3. Iskada 1 oynama hakkı daha gider."},
	{"id": "cursed13", "name": "Uğursuz 13", "cls": "neutral", "rarity": "rare", "kind": "add", "value": 13, "gem": "13", "icon": "skull", "on_play": "lose_discard", "text": "Değeri 13. Oynandığında 1 değiştirme hakkı yer."},
	{"id": "scout", "name": "Muhbir", "cls": "neutral", "rarity": "common", "kind": "spell", "spell": "draw2", "icon": "cards", "text": "2 kart çek."},
	{"id": "recall", "name": "Tahsilat", "cls": "neutral", "rarity": "common", "kind": "spell", "spell": "recall", "icon": "return", "text": "Iskartadaki son sayı kartını eline geri al."},
	{"id": "painter", "name": "Ayakkabı Boyacısı", "cls": "neutral", "rarity": "rare", "kind": "spell", "spell": "paint", "icon": "brush", "text": "Elindeki sayı kartlarını en çok bulunan renge boyar."},
	{"id": "shield", "name": "Rüşvet", "cls": "neutral", "rarity": "unique", "kind": "spell", "spell": "shield", "icon": "shield", "text": "Bu tur oynama hakların biterse can kaybetmezsin."},
	{"id": "timewarp", "name": "Gece Uzar", "cls": "neutral", "rarity": "epic", "kind": "spell", "spell": "plays2", "icon": "hourglass", "text": "Bu tur +2 oynama hakkı."},
	{"id": "compass", "name": "İçeriden Bilgi", "cls": "neutral", "rarity": "common", "kind": "spell", "spell": "compass", "icon": "compass", "text": "Hedefi 1–3 azaltır."},
	{"id": "sacrifice", "name": "Gözden Çıkar", "cls": "neutral", "rarity": "rare", "kind": "spell", "spell": "sacrifice", "icon": "dagger", "text": "Elinden rastgele bir kartı kalıcı olarak yok et, +1 oynama hakkı kazan."},
	# Silas Crane (kodda "guard")
	{"id": "spear", "name": "Sekiz Kat", "cls": "guard", "rarity": "common", "kind": "num", "value": 8, "color": "blue", "icon": "spear", "text": "Değeri 8."},
	{"id": "watch", "name": "Kapı Görevlisi", "cls": "guard", "rarity": "common", "kind": "add", "value": 4, "gem": "+4", "icon": "tower", "text": "Toplama 4 ekler."},
	{"id": "fortify", "name": "Ev Kuralı", "cls": "guard", "rarity": "rare", "kind": "spell", "spell": "plays1", "icon": "tower", "text": "Bu tur +1 oynama hakkı."},
	{"id": "discipline", "name": "Masamda Hile Yok", "cls": "guard", "rarity": "rare", "kind": "op", "op": "discipline", "value": 5, "gem": "+5", "icon": "swords", "text": "Seçimdeki sayı kartlarının hepsi aynı renkse toplama 5 ekler."},
	{"id": "wall", "name": "Gizli Kapı", "cls": "guard", "rarity": "unique", "kind": "spell", "spell": "wall", "icon": "wall", "text": "Bu tur can kaybını önler, +1 değiştirme hakkı verir."},
	{"id": "standard", "name": "Bordo Sedan", "cls": "guard", "rarity": "legendary", "kind": "num", "value": 5, "color": "gold", "icon": "banner", "on_hit": "heal", "text": "Değeri 5. İsabette 1 can kazandırır (en fazla 4)."},
	# Eddie Finch (kodda "alchemist")
	{"id": "distill", "name": "Kart Sayma", "cls": "alchemist", "rarity": "common", "kind": "add", "value": 3, "gem": "+3", "icon": "potion", "text": "Toplama 3 ekler."},
	{"id": "catalyst", "name": "Ezber", "cls": "alchemist", "rarity": "common", "kind": "op", "op": "per_card", "gem": "+n", "icon": "gear", "text": "Seçimdeki her kart için toplama 1 ekler."},
	{"id": "transmute", "name": "İşaretli Deste", "cls": "alchemist", "rarity": "rare", "kind": "spell", "spell": "transmute", "icon": "transform", "text": "Elindeki 1 ve 2 değerli sayı kartları 6 olur."},
	{"id": "elixir", "name": "Kasadan Sızıntı", "cls": "alchemist", "rarity": "rare", "kind": "spell", "spell": "elixir", "icon": "flask", "text": "Sınıf gücünü yeniler ve 1 kart çeker."},
	{"id": "div3", "name": "Pay", "cls": "alchemist", "rarity": "unique", "kind": "op", "op": "div", "value": 3, "gem": "÷3", "glyph": "÷3", "text": "Toplamı üçe böler, küsuratı atar."},
	{"id": "philo", "name": "Dahi Hesap", "cls": "alchemist", "rarity": "legendary", "kind": "wild", "max": 20, "gem": "★", "icon": "gem", "text": "1 ile 20 arasında gereken değeri alır."},
	# Dedektif Harlow (kodda "pyro")
	{"id": "spark", "name": "İhbar", "cls": "pyro", "rarity": "common", "kind": "num", "value": 2, "color": "red", "icon": "spark", "on_play": "draw1", "text": "Değeri 2. Oynandığında 1 kart çek."},
	{"id": "fuel", "name": "Delil Yak", "cls": "pyro", "rarity": "common", "kind": "spell", "spell": "fuel", "icon": "fuel", "text": "Elinden rastgele bir kartı yak. +1 değiştirme hakkı kazan."},
	{"id": "flamewave", "name": "Baskın", "cls": "pyro", "rarity": "rare", "kind": "spell", "spell": "flamewave", "icon": "wave", "text": "Elini ıskartaya at, 1 fazla kart çek."},
	{"id": "fireball", "name": "Tek Kurşun", "cls": "pyro", "rarity": "rare", "kind": "add", "value": 11, "gem": "11", "icon": "fireball", "exhaust": true, "text": "Değeri 11. Oynandıktan sonra desteden kalıcı olarak yanar."},
	{"id": "ash", "name": "Rook's Hall Külleri", "cls": "pyro", "rarity": "unique", "kind": "add", "dyn": "ash", "value": 0, "gem": "X", "icon": "ash", "text": "Değeri ıskartadaki kart sayısı kadar, en fazla 15."},
	{"id": "volcano", "name": "Kara Salı", "cls": "pyro", "rarity": "epic", "kind": "op", "op": "mul", "value": 4, "gem": "×4", "icon": "volcano", "exhaust": true, "text": "Toplamı 4 katına çıkarır. Oynandıktan sonra yanar."},
	# Vivienne Rook (kodda "seer")
	{"id": "moonlight", "name": "Hüzünlü Şarkı", "cls": "seer", "rarity": "common", "kind": "num", "value": 6, "color": "blue", "icon": "moon", "on_hit": "omen", "text": "Değeri 6. İsabette olay sayacını 1 ilerletir."},
	{"id": "thirdeye", "name": "Sahne Işığı", "cls": "seer", "rarity": "common", "kind": "spell", "spell": "thirdeye", "icon": "eye", "text": "Sıradaki olayı yenisiyle değiştirir ve 1 kart çeker."},
	{"id": "fog", "name": "Sigara Dumanı", "cls": "seer", "rarity": "common", "kind": "add", "value": -3, "gem": "−3", "icon": "fog", "on_play": "draw1", "text": "Toplamdan 3 düşer. Oynandığında 1 kart çek."},
	{"id": "orb", "name": "Dedikodu", "cls": "seer", "rarity": "rare", "kind": "spell", "spell": "orb", "icon": "orb", "text": "Olay sayacını 1 ilerletir."},
	{"id": "starmap", "name": "Babamın Defteri", "cls": "seer", "rarity": "unique", "kind": "spell", "spell": "starmap", "icon": "starmap", "text": "Çekme destesindeki en yüksek sayı kartını eline al."},
	{"id": "fate", "name": "Rulet Çarkı", "cls": "seer", "rarity": "epic", "kind": "op", "op": "tolerance", "value": 3, "gem": "≈", "icon": "thread", "text": "Toplam hedefe 3 veya daha yakınsa isabet sayılır."},
	# Lanet (olaylarla desteye girer, koleksiyonda yok)
	{"id": "stone", "name": "Senet", "cls": "curse", "rarity": "common", "kind": "curse", "value": 0, "gem": "0", "icon": "stone", "no_collect": true, "text": "Değeri 0. Ödenmemiş borç, elinde yer kaplar."},
]

## Eşyalar (kodda "charm"): kalıcı bonuslar (en fazla 5). Oran/kazanç etkileri RunState._charm_score içinde.
const CHARMS := [
	{"id": "c_red", "name": "Kızıl Gül", "rarity": "common", "icon": "gem", "text": "Kızıl kart içeren isabette oran +1."},
	{"id": "c_blue", "name": "Mavi Mendil", "rarity": "common", "icon": "gem", "text": "Mavi kart içeren isabette oran +1."},
	{"id": "c_green", "name": "Yeşil Çuha", "rarity": "common", "icon": "gem", "text": "Yeşil kart içeren isabette oran +1."},
	{"id": "c_gold", "name": "Sarı Pırlanta", "rarity": "common", "icon": "gem", "text": "Sarı kart içeren isabette oran +1."},
	{"id": "crowd", "name": "Kalabalık Masa", "rarity": "common", "icon": "hand", "text": "4 veya daha fazla kartla yapılan isabette oran +2."},
	{"id": "goldtooth", "name": "Altın Çakmak", "rarity": "common", "icon": "tooth", "gold": 1, "text": "Her isabette masa minimumu kadar fiş kazandırır."},
	{"id": "lone", "name": "Yalnız Kurt", "rarity": "rare", "icon": "wolf", "text": "2 veya daha az kartla yapılan isabette oran +2."},
	{"id": "hunter", "name": "Seri Avcısı", "rarity": "rare", "icon": "rainbow", "text": "Renk serisi yapan isabette oran +2."},
	{"id": "hoarder", "name": "Kumbara", "rarity": "rare", "icon": "swap", "text": "Kalan her 2 değiştirme hakkı için oran +1."},
	{"id": "merchant", "name": "Karaborsa Dostu", "rarity": "rare", "icon": "bag", "discount": 1, "text": "Tüccardaki her şey %25 ucuz."},
	{"id": "even", "name": "Çift Zar", "rarity": "rare", "icon": "scale", "text": "Hedef çift sayıysa oran +1."},
	{"id": "spellbag", "name": "Hamle Defteri", "rarity": "rare", "icon": "potion", "text": "Bu tur kullandığın her hamle kartı için oran +1."},
	{"id": "nearshot", "name": "Kıl Payı", "rarity": "unique", "icon": "target", "tolerance": 1, "text": "Toplam hedefe 1 uzaksa da isabet sayılır."},
	{"id": "firststrike", "name": "İlk El", "rarity": "unique", "icon": "bolt", "text": "Turun ilk oynaması isabetse kazanç ×2."},
	{"id": "prime", "name": "Uğurlu Sayı", "rarity": "unique", "icon": "rune", "text": "Hedef asal sayıysa kazanç ×2."},
	{"id": "gambler", "name": "Rulet Masası", "rarity": "unique", "icon": "dice", "text": "Her isabette oran 0–3 arası rastgele artar."},
	{"id": "stoneheart", "name": "Borç Defteri", "rarity": "unique", "icon": "stone", "text": "Destendeki her Senet için oran +1."},
	{"id": "seereye", "name": "Muhbir Ağı", "rarity": "legendary", "icon": "eye", "event_every": 2, "text": "Olaylar 3 yerine 2 isabette bir gerçekleşir."},
	{"id": "giant", "name": "Büyük Balık", "rarity": "legendary", "icon": "tower", "text": "Hedef 30 veya üstüyse kazanç ×2."},
	{"id": "goldshield", "name": "Avukat", "rarity": "legendary", "icon": "shield", "life_save": true, "text": "Bir kez can kaybını önler, sonra kırılır."},
	{"id": "infinity", "name": "Sıfır Cebi", "rarity": "epic", "icon": "infinity", "text": "Her 3 isabette kalıcı olarak oran +1 birikir."},
	{"id": "crown", "name": "Kumar Babasının Yüzüğü", "rarity": "epic", "icon": "crown", "plays_mod": -1, "text": "Kazanç ×3, ama her tur 1 oynama hakkın eksik olur."},
]

## Engeller (kodda "boss"): her katın 3. turu özel kurallıdır
const BOSSES := {
	"redban": {"name": "İçki Yasağı", "icon": "skull", "text": "Kızıl sayı kartları 0 değerinde sayılır."},
	"nodiscard": {"name": "Kapalı Kapılar", "icon": "swap", "text": "Bu tur değiştirme hakkı yok."},
	"slippery": {"name": "Hileli Çark", "icon": "shift", "text": "Her oynamadan sonra hedef değişir."},
	"heavy": {"name": "Borç Yükü", "icon": "hand", "text": "Elinde 1 kart eksik tutarsın."},
	"silence": {"name": "Polis Baskını", "icon": "fog", "text": "Hamle kartları kullanılamaz."},
	"short": {"name": "Sabaha Karşı", "icon": "hourglass", "text": "1 oynama hakkın eksik."},
}

## Olaylar (etkileri RunState._run_event içinde). tone: good | bad | neutral
const EVENTS := {
	"shift": {"w": 3, "name": "Hedef Kaydı", "tone": "neutral", "hint": "Hedef 1–4 sayı kayar.", "icon": "shift"},
	"reroll": {"w": 2, "name": "Yeni Hedef", "tone": "neutral", "hint": "Hedef baştan belirlenir.", "icon": "reroll"},
	"gift": {"w": 3, "name": "Cömert Müşteri", "tone": "good", "hint": "Destene güçlü bir kart girer.", "icon": "gift"},
	"treasure": {"w": 2, "name": "Kasa Payı", "tone": "good", "hint": "Kasadan fiş payı alırsın.", "icon": "coin"},
	"stone": {"w": 2, "name": "Senet Geldi", "tone": "bad", "hint": "Destene 0 değerli bir Senet girer.", "icon": "stone"},
	"burn": {"w": 2, "name": "Yangın", "tone": "bad", "hint": "Elinden rastgele bir kart yanar.", "icon": "flame"},
	"thief": {"w": 1, "name": "Yankesici", "tone": "bad", "hint": "En yüksek sayı kartın çalınır.", "icon": "mask"},
	"boost": {"w": 2, "name": "Şanslı Renk", "tone": "good", "hint": "Bir renk 2 oynama boyunca ×2 değer.", "icon": "bolt"},
	"wind": {"w": 2, "name": "Kapanış Uzadı", "tone": "good", "hint": "+1 oynama hakkı kazanırsın.", "icon": "wind"},
	"storm": {"w": 1, "name": "Sağanak", "tone": "bad", "hint": "1 değiştirme hakkı gider.", "icon": "storm"},
	"shadow": {"w": 2, "name": "Kirli Para", "tone": "neutral", "hint": "Destene eksi değerli bir kart girer.", "icon": "moon"},
	"swap": {"w": 1, "name": "Takas", "tone": "neutral", "hint": "Elindeki tüm kartlar yenilenir.", "icon": "swap"},
	"heal": {"w": 1, "name": "Bir Kadeh Viski", "tone": "good", "hint": "1 can kazanırsın (en fazla 4).", "icon": "spring"},
}

const ACHIEVEMENTS := [
	{"id": "tutorial", "name": "Çırak", "icon": "star", "text": "Öğreticiyi bitir.", "unlocks": ["joker", "echo"]},
	{"id": "firsthit", "name": "İlk İsabet", "icon": "target", "text": "İlk isabetini yap.", "unlocks": ["compass"]},
	{"id": "combo", "name": "Renk Ustası", "icon": "rainbow", "text": "Bir renk serisi yap.", "unlocks": ["rainbow", "c_green"]},
	{"id": "round3", "name": "Yolun Başı", "icon": "banner", "text": "Bir oyunda 3. turu geç.", "unlocks": ["dice"]},
	{"id": "boss1", "name": "Engel Aşan", "icon": "skull", "text": "Bir engel turunu geç.", "unlocks": ["shield", "hunter"]},
	{"id": "round6", "name": "Kararlı", "icon": "tower", "text": "Bir oyunda 6. turu geç.", "unlocks": ["coin"]},
	{"id": "big200", "name": "Büyük Vurgun", "icon": "bolt", "text": "Tek isabette 60 fiş kazan.", "unlocks": ["mul3"]},
	{"id": "score1000", "name": "Beş Yüz Fiş", "icon": "coin", "text": "Bir oyunda toplam 500 fiş kazan.", "unlocks": ["add10", "c_gold"]},
	{"id": "spells10", "name": "Hamle Ustası", "icon": "potion", "text": "Toplam 10 hamle kartı kullan.", "unlocks": ["painter", "spellbag"]},
	{"id": "charms3", "name": "Koleksiyoncu", "icon": "bag", "text": "Aynı anda 3 eşya taşı.", "unlocks": ["merchant"]},
	{"id": "five", "name": "Kalabalık El", "icon": "hand", "text": "5 veya daha fazla kartla isabet yap.", "unlocks": ["equal"]},
	{"id": "lives4", "name": "Dört Can", "icon": "heart", "text": "4 cana ulaş.", "unlocks": ["standard"]},
	{"id": "rich", "name": "Hazine", "icon": "coin", "text": "Aynı anda 100 fişe sahip ol.", "unlocks": ["goldshield"]},
	{"id": "round9", "name": "Kumar Babası", "icon": "crown", "text": "Bir oyunda 9. turu geç.", "unlocks": ["timewarp"]},
]

## Hikâye modu: "Kumar Babası" (docs/hikaye/kumar-babasi.pdf). Her bölüm bir kattır (3 tur).
## Kat başlarken bölümün açılış sahneleri oynar (bir kez), engel turu kazanılınca
## kapanış cümlesi gösterilir ve "unlocks" açılır. art: ara sahnede çizilecek görüntü.
const STORY := [
	{"title": "Sıfır Numaralı Adam", "boss": "short", "scenes": [
		{"art": "wheel", "text": "Bu şehirde herkes kumar oynar. Ama yalnızca bir adam, her şeyini sıfıra oynar."},
		{"art": "sedan", "caption": "Port Halloway, Eylül 1929", "text": "Port Halloway, 1929. İçki yasak, kumar yasak. İkisi de hiç bu kadar para kazandırmamıştı."},
		{"art": "silhouette", "text": "Adı Silas Crane. Bu sokaklarda ayakkabı boyayarak büyüdü. Şimdi bu sokaklar onun."},
		{"art": "elevator", "text": "Herkes Meridian'ı sekiz katlı sanır. Dokuzuncu düğme ise aşağı iner."},
		{"art": "club", "text": "Burada Silas'ın kuralları geçer: Hile yok. Borç tahsil edilir. Ve yılda bir kez, her şey sıfıra oynanır."},
		{"art": "stage", "text": "O gece, yılın o gecesiydi. Ama top düşmeden önce yeni şarkıcı sahneye çıktı."},
		{"art": "eyes", "text": "Bu şarkıyı bilen iki kişi vardı. Biri Silas'tı. Öbürü on beş yıl önce ölmüştü."},
	], "outro": "Ertesi sabah otelin önünde siyah bir otomobil bekliyordu. Cornelius Black konuşmak istiyordu.",
		"unlocks": ["fortify", "discipline", "recall"]},
	{"title": "Kara Bankacı", "boss": "silence", "scenes": [
		{"art": "bank", "text": "Black & Sons Bankası. Belediye, polis ve liman tek bir adamın cebinde."},
		{"art": "silhouette", "text": "Cornelius Black, Gilded Zero'yu satın almak istedi. Silas cevabını tek kelimeyle verdi: Hayır."},
		{"art": "club", "text": "Aynı gece, dokuzuncu katın kapısında düdükler öttü."},
	], "outro": "Polis gizli kapıyı doğrudan bulmuştu. Kapının yerini bilen üç kişi vardı.",
		"unlocks": ["class:seer", "orb"]},
	{"title": "Kayıp Kız", "boss": "heavy", "scenes": [
		{"art": "stage", "text": "Vivienne her gece aynı şarkıyı söylüyordu. Arthur Rook'un mırıldandığı şarkıyı."},
		{"art": "eyes", "text": "Silas sonunda sordu. Cevap tek bir isimdi: Rook."},
	], "outro": "Vivienne gece yarısı Black'in arabasına bindi.",
		"unlocks": ["class:alchemist", "transmute"]},
	{"title": "Kasa Her Zaman Kazanır", "boss": "nodiscard", "scenes": [
		{"art": "fire", "caption": "Rook's Hall, 1914", "text": "1914. Hileli bir oyun, ardından yangın. Genç Silas kapıda kalakaldı."},
		{"art": "ledger", "text": "On beş yıl sonra kasada bir açık vardı. İz, Silas'ın sağ kolu Eddie'ye çıkıyordu."},
	], "outro": "Silas'ın ikinci kuralı: Borç her zaman tahsil edilir. Eddie ertesi sabah ortada yoktu.",
		"unlocks": ["class:pyro", "flamewave"]},
	{"title": "Dedektif", "boss": "redban", "scenes": [
		{"art": "skyline", "text": "Dedektif Thomas Harlow. Şehrin rüşvet almayan son polisi."},
		{"art": "silhouette", "text": "Black'e karşı bir teklifi vardı. Silas ilk kez kendi kuralını sorguladı."},
	], "outro": "Silas cevabını vermeden kapıya bir zarf bırakıldı. İçinde Eddie'nin şapkası vardı.",
		"unlocks": ["standard", "elixir", "fireball"]},
	{"title": "Defter", "boss": "heavy", "scenes": [
		{"art": "ledger", "text": "Vivienne, Black'in ofisinde 1914 yangınının kanıtını buldu: kırmızı kurdeleli bir defter."},
		{"art": "wheel", "text": "Silas, Black'i son bir masaya davet etti. Kumarhane bir yanda, bankanın hisseleri öbür yanda."},
	], "outro": "\"Tek tur. Her şey ortada.\" Black kabul etti ve gülümsedi.",
		"unlocks": ["philo", "mirror", "square"]},
	{"title": "Son Masa", "boss": "slippery", "scenes": [
		{"art": "wheel", "text": "Çark döndü. Black çarkı hilelemişti."},
		{"art": "stage", "text": "Ama Vivienne o gece çarkı değiştirmişti."},
	], "outro": "Top sıfıra düştü. Harlow kapıda belirdi. Black'in bileklerinde kelepçe vardı.",
		"unlocks": ["fate", "timewarp", "crown"]},
	{"title": "Kara Salı", "boss": "short", "scenes": [
		{"art": "crash", "caption": "29 Ekim 1929", "text": "Beş gün sonra borsa çöktü."},
		{"art": "club", "text": "Silas'ın kazandığı banka hisseleri bir gecede değersizleşti. Gilded Zero bomboştu."},
	], "outro": "Silas son fişini sıfıra koydu: \"Sıfırdan geldim. Sıfıra dönmekten korkmam.\"",
		"unlocks": ["volcano", "infinity"]},
]

const STARTER_CLASSES := ["guard"]
const CLASS_UNLOCK_CARDS := {"alchemist": ["distill", "catalyst"], "pyro": ["spark", "fuel"], "seer": ["moonlight", "thirdeye", "fog"]}
const KIND_ORDER := {"num": 0, "add": 1, "wild": 2, "op": 3, "spell": 4, "curse": 5}

## Kurulumda üretilenler
var NUMBER_CARDS: Array = []
var CARD: Dictionary = {}
var CHARM: Dictionary = {}
var RECOMMENDED: Dictionary = {}
var STARTER_UNLOCKS: Array = []
var UNLOCK_ORDER: Array = []

func _init() -> void:
	for c in SUIT_KEYS:
		for v in range(1, 10):
			NUMBER_CARDS.append({"id": "n-%s-%d" % [c, v], "name": "%s %d" % [SUITS[c].name, v], "cls": "neutral", "rarity": "common",
				"kind": "num", "value": v, "color": c, "is_number": true, "text": "Değeri %d." % v})
	for c in NUMBER_CARDS + SPECIAL_CARDS:
		CARD[c.id] = c
	for c in CHARMS:
		CHARM[c.id] = c

	var base := []
	for c in SUIT_KEYS:
		for v in range(1, 5):
			base.append("n-%s-%d" % [c, v])
	base += ["n-red-6", "n-blue-7", "n-green-8", "n-gold-9"]
	RECOMMENDED = {
		"guard": base + ["mul2", "spear", "watch", "add5"],
		"alchemist": base + ["mul2", "distill", "catalyst", "add5"],
		"pyro": base + ["mul2", "spark", "fuel", "add5"],
		"seer": base + ["mul2", "moonlight", "thirdeye", "fog"],
	}

	for c in NUMBER_CARDS:
		STARTER_UNLOCKS.append(c.id)
	STARTER_UNLOCKS += ["mul2", "add5", "shadow2", "div2", "scout", "spear", "watch", "distill", "catalyst", "c_red", "c_blue", "crowd", "goldtooth"]

	for c in SPECIAL_CARDS:
		if not c.get("no_collect", false):
			UNLOCK_ORDER.append({"id": c.id, "rarity": c.rarity, "cls": c.cls})
	for c in CHARMS:
		UNLOCK_ORDER.append({"id": c.id, "rarity": c.rarity, "cls": "neutral"})
	UNLOCK_ORDER.sort_custom(func(a, b): return rarity_rank(a.rarity) < rarity_rank(b.rarity))

func rarity_rank(r: String) -> int:
	return RARITY_ORDER.find(r)

func card_name(tid: String, color: String = "", value: int = 0) -> String:
	var t: Dictionary = CARD[tid]
	if t.get("is_number", false):
		return "%s %d" % [SUITS[color].name, value]
	return t.name

## Kartları nadirliğe, sonra türe ve değere göre sıralar (basitten nadire)
func by_rarity(a: Dictionary, b: Dictionary) -> bool:
	var ra := rarity_rank(a.rarity)
	var rb := rarity_rank(b.rarity)
	if ra != rb:
		return ra < rb
	var ka: int = KIND_ORDER.get(a.get("kind", ""), 9)
	var kb: int = KIND_ORDER.get(b.get("kind", ""), 9)
	if ka != kb:
		return ka < kb
	if a.get("value", 0) != b.get("value", 0):
		return a.get("value", 0) < b.get("value", 0)
	return a.name < b.name

func icon(name: String) -> Texture2D:
	var path := "res://assets/icons/%s.svg" % name
	if ResourceLoader.exists(path):
		return load(path)
	return null
