extends Node
## Tam İsabet — oyun verileri (autoload: Data).
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
	"guard": {"name": "Muhafız", "icon": "shield", "tagline": "Sabırlı oynar, canını korur.",
		"power": {"name": "Siper", "icon": "tower", "text": "Bu tur +1 oynama hakkı kazan."}},
	"alchemist": {"name": "Simyacı", "icon": "flask", "tagline": "Sayıları büker, sonucu ince ayarlar.",
		"power": {"name": "Damıtma", "icon": "potion", "text": "Sonraki oynamada toplam hedefe 1 uzaksa da isabet sayılır."}},
	"pyro": {"name": "Kor Büyücüsü", "icon": "flame", "tagline": "Elini yakar, büyük sayılarla vurur.",
		"power": {"name": "Kor Yığını", "icon": "spark", "text": "Seçili kartları ıskartaya at, yerine 1 fazlasını çek. Değiştirme hakkı harcamaz."}},
	"seer": {"name": "Kâhin", "icon": "eye", "tagline": "Olayları önceden görür ve yönlendirir.",
		"power": {"name": "Kehanet", "icon": "orb", "text": "Sıradaki olayı iki seçenekten biriyle değiştir."}},
}
const CLASS_KEYS := ["guard", "alchemist", "pyro", "seer"]

## Özel kartlar.
## kind: num (renkli sayı) | add (renksiz değer) | op (işlem) | wild (joker) | spell (büyü) | curse
const SPECIAL_CARDS := [
	# Nötr
	{"id": "mul2", "name": "×2 Çarpan", "cls": "neutral", "rarity": "rare", "kind": "op", "op": "mul", "value": 2, "gem": "×2", "glyph": "×2", "text": "Seçimin toplamını 2 katına çıkarır."},
	{"id": "mul3", "name": "×3 Çarpan", "cls": "neutral", "rarity": "unique", "kind": "op", "op": "mul", "value": 3, "gem": "×3", "glyph": "×3", "text": "Seçimin toplamını 3 katına çıkarır."},
	{"id": "div2", "name": "÷2 Bölücü", "cls": "neutral", "rarity": "common", "kind": "op", "op": "div", "value": 2, "gem": "÷2", "glyph": "÷2", "text": "Toplamı ikiye böler, küsuratı atar."},
	{"id": "joker", "name": "Joker", "cls": "neutral", "rarity": "rare", "kind": "wild", "max": 9, "gem": "★", "icon": "star", "text": "1 ile 9 arasında gereken değeri alır."},
	{"id": "shadow2", "name": "Gölge", "cls": "neutral", "rarity": "common", "kind": "add", "value": -2, "gem": "−2", "icon": "moon", "text": "Toplamdan 2 düşer."},
	{"id": "shadow5", "name": "Derin Gölge", "cls": "neutral", "rarity": "rare", "kind": "add", "value": -5, "gem": "−5", "icon": "moon", "text": "Toplamdan 5 düşer."},
	{"id": "add5", "name": "Takviye", "cls": "neutral", "rarity": "common", "kind": "add", "value": 5, "gem": "+5", "glyph": "+5", "text": "Toplama 5 ekler."},
	{"id": "add10", "name": "Kuşatma", "cls": "neutral", "rarity": "rare", "kind": "add", "value": 10, "gem": "+10", "glyph": "+10", "text": "Toplama 10 ekler."},
	{"id": "square", "name": "Kare Rünü", "cls": "neutral", "rarity": "legendary", "kind": "op", "op": "square", "gem": "x²", "icon": "rune", "text": "Toplamın karesini alır. Çarpanlardan önce uygulanır."},
	{"id": "mirror", "name": "Ayna", "cls": "neutral", "rarity": "legendary", "kind": "op", "op": "mirror", "gem": "⇄", "icon": "mirror", "text": "Sonucun basamaklarını ters çevirir: 17, 71 olur."},
	{"id": "equal", "name": "Eşitleyici", "cls": "neutral", "rarity": "rare", "kind": "op", "op": "equalize", "gem": "=", "icon": "scale", "text": "Seçimdeki tüm sayı kartları en yükseğinin değerini alır."},
	{"id": "echo", "name": "Yansıma", "cls": "neutral", "rarity": "common", "kind": "op", "op": "copy", "gem": "↺", "icon": "copy", "text": "Seçimdeki en yüksek sayı kartının değerini bir kez daha ekler."},
	{"id": "rainbow", "name": "Gökkuşağı", "cls": "neutral", "rarity": "rare", "kind": "num", "value": 3, "color": "rainbow", "icon": "rainbow", "text": "Değeri 3. Her rengin yerine geçer, renk serisini tamamlar."},
	{"id": "dice", "name": "Kumarbaz Zarı", "cls": "neutral", "rarity": "rare", "kind": "add", "roll": [1, 12], "value": 6, "gem": "?", "icon": "dice", "text": "Eline her geldiğinde değeri 1–12 arasında yeniden belirlenir."},
	{"id": "coin", "name": "Altın Sikke", "cls": "neutral", "rarity": "unique", "kind": "num", "value": 7, "color": "gold", "icon": "coin", "on_hit": "triple", "on_miss": "lose_play", "text": "Değeri 7. İsabette skor ×3. Iskada 1 oynama hakkı daha gider."},
	{"id": "cursed13", "name": "Lanetli 13", "cls": "neutral", "rarity": "rare", "kind": "add", "value": 13, "gem": "13", "icon": "skull", "on_play": "lose_discard", "text": "Değeri 13. Oynandığında 1 değiştirme hakkı yer."},
	{"id": "scout", "name": "Keşif", "cls": "neutral", "rarity": "common", "kind": "spell", "spell": "draw2", "icon": "cards", "text": "2 kart çek."},
	{"id": "recall", "name": "Geri Çağır", "cls": "neutral", "rarity": "common", "kind": "spell", "spell": "recall", "icon": "return", "text": "Iskartadaki son sayı kartını eline geri al."},
	{"id": "painter", "name": "Boyacı", "cls": "neutral", "rarity": "rare", "kind": "spell", "spell": "paint", "icon": "brush", "text": "Elindeki sayı kartlarını en çok bulunan renge boyar."},
	{"id": "shield", "name": "Kalkan", "cls": "neutral", "rarity": "unique", "kind": "spell", "spell": "shield", "icon": "shield", "text": "Bu tur oynama hakların biterse can kaybetmezsin."},
	{"id": "timewarp", "name": "Zaman Bükümü", "cls": "neutral", "rarity": "epic", "kind": "spell", "spell": "plays2", "icon": "hourglass", "text": "Bu tur +2 oynama hakkı."},
	{"id": "compass", "name": "Pusula", "cls": "neutral", "rarity": "common", "kind": "spell", "spell": "compass", "icon": "compass", "text": "Hedefi 1–3 azaltır."},
	{"id": "sacrifice", "name": "Kurban", "cls": "neutral", "rarity": "rare", "kind": "spell", "spell": "sacrifice", "icon": "dagger", "text": "Elinden rastgele bir kartı kalıcı olarak yok et, +1 oynama hakkı kazan."},
	# Muhafız
	{"id": "spear", "name": "Mızrak", "cls": "guard", "rarity": "common", "kind": "num", "value": 8, "color": "blue", "icon": "spear", "text": "Değeri 8."},
	{"id": "watch", "name": "Nöbet", "cls": "guard", "rarity": "common", "kind": "add", "value": 4, "gem": "+4", "icon": "tower", "text": "Toplama 4 ekler."},
	{"id": "fortify", "name": "Tahkimat", "cls": "guard", "rarity": "rare", "kind": "spell", "spell": "plays1", "icon": "tower", "text": "Bu tur +1 oynama hakkı."},
	{"id": "discipline", "name": "Disiplin", "cls": "guard", "rarity": "rare", "kind": "op", "op": "discipline", "value": 5, "gem": "+5", "icon": "swords", "text": "Seçimdeki sayı kartlarının hepsi aynı renkse toplama 5 ekler."},
	{"id": "wall", "name": "Kalkan Duvarı", "cls": "guard", "rarity": "unique", "kind": "spell", "spell": "wall", "icon": "wall", "text": "Bu tur can kaybını önler, +1 değiştirme hakkı verir."},
	{"id": "standard", "name": "Sancak", "cls": "guard", "rarity": "legendary", "kind": "num", "value": 5, "color": "gold", "icon": "banner", "on_hit": "heal", "text": "Değeri 5. İsabette 1 can kazandırır (en fazla 4)."},
	# Simyacı
	{"id": "distill", "name": "Damıtık Öz", "cls": "alchemist", "rarity": "common", "kind": "add", "value": 3, "gem": "+3", "icon": "potion", "text": "Toplama 3 ekler."},
	{"id": "catalyst", "name": "Katalizör", "cls": "alchemist", "rarity": "common", "kind": "op", "op": "per_card", "gem": "+n", "icon": "gear", "text": "Seçimdeki her kart için toplama 1 ekler."},
	{"id": "transmute", "name": "Dönüşüm", "cls": "alchemist", "rarity": "rare", "kind": "spell", "spell": "transmute", "icon": "transform", "text": "Elindeki 1 ve 2 değerli sayı kartları 6 olur."},
	{"id": "elixir", "name": "İksir", "cls": "alchemist", "rarity": "rare", "kind": "spell", "spell": "elixir", "icon": "flask", "text": "Sınıf gücünü yeniler ve 1 kart çeker."},
	{"id": "div3", "name": "Çözücü", "cls": "alchemist", "rarity": "unique", "kind": "op", "op": "div", "value": 3, "gem": "÷3", "glyph": "÷3", "text": "Toplamı üçe böler, küsuratı atar."},
	{"id": "philo", "name": "Filozof Taşı", "cls": "alchemist", "rarity": "legendary", "kind": "wild", "max": 20, "gem": "★", "icon": "gem", "text": "1 ile 20 arasında gereken değeri alır."},
	# Kor Büyücüsü
	{"id": "spark", "name": "Kıvılcım", "cls": "pyro", "rarity": "common", "kind": "num", "value": 2, "color": "red", "icon": "spark", "on_play": "draw1", "text": "Değeri 2. Oynandığında 1 kart çek."},
	{"id": "fuel", "name": "Yakıt", "cls": "pyro", "rarity": "common", "kind": "spell", "spell": "fuel", "icon": "fuel", "text": "Elinden rastgele bir kart yanar. +1 değiştirme hakkı kazan."},
	{"id": "flamewave", "name": "Alev Dalgası", "cls": "pyro", "rarity": "rare", "kind": "spell", "spell": "flamewave", "icon": "wave", "text": "Elini ıskartaya at, 1 fazla kart çek."},
	{"id": "fireball", "name": "Ateş Topu", "cls": "pyro", "rarity": "rare", "kind": "add", "value": 11, "gem": "11", "icon": "fireball", "exhaust": true, "text": "Değeri 11. Oynandıktan sonra desteden kalıcı olarak yanar."},
	{"id": "ash", "name": "Kül Yığını", "cls": "pyro", "rarity": "unique", "kind": "add", "dyn": "ash", "value": 0, "gem": "X", "icon": "ash", "text": "Değeri ıskartadaki kart sayısı kadar, en fazla 15."},
	{"id": "volcano", "name": "Volkan", "cls": "pyro", "rarity": "epic", "kind": "op", "op": "mul", "value": 4, "gem": "×4", "icon": "volcano", "exhaust": true, "text": "Toplamı 4 katına çıkarır. Oynandıktan sonra yanar."},
	# Kâhin
	{"id": "moonlight", "name": "Ay Işığı", "cls": "seer", "rarity": "common", "kind": "num", "value": 6, "color": "blue", "icon": "moon", "on_hit": "omen", "text": "Değeri 6. İsabette olay sayacını 1 ilerletir."},
	{"id": "thirdeye", "name": "Üçüncü Göz", "cls": "seer", "rarity": "common", "kind": "spell", "spell": "thirdeye", "icon": "eye", "text": "Sıradaki olayı yenisiyle değiştirir ve 1 kart çeker."},
	{"id": "fog", "name": "Sis", "cls": "seer", "rarity": "common", "kind": "add", "value": -3, "gem": "−3", "icon": "fog", "on_play": "draw1", "text": "Toplamdan 3 düşer. Oynandığında 1 kart çek."},
	{"id": "orb", "name": "Kristal Küre", "cls": "seer", "rarity": "rare", "kind": "spell", "spell": "orb", "icon": "orb", "text": "Olay sayacını 1 ilerletir."},
	{"id": "starmap", "name": "Yıldız Haritası", "cls": "seer", "rarity": "unique", "kind": "spell", "spell": "starmap", "icon": "starmap", "text": "Çekme destesindeki en yüksek sayı kartını eline al."},
	{"id": "fate", "name": "Kader İpliği", "cls": "seer", "rarity": "epic", "kind": "op", "op": "tolerance", "value": 3, "gem": "≈", "icon": "thread", "text": "Toplam hedefe 3 veya daha yakınsa isabet sayılır."},
	# Lanet (olaylarla desteye girer, koleksiyonda yok)
	{"id": "stone", "name": "Taş", "cls": "curse", "rarity": "common", "kind": "curse", "value": 0, "gem": "0", "icon": "stone", "no_collect": true, "text": "Değeri 0. Elinde yer kaplar."},
]

## Tılsımlar: kalıcı bonuslar (en fazla 5). Skor etkileri RunState._charm_score içinde.
const CHARMS := [
	{"id": "c_red", "name": "Kızıl Mühür", "rarity": "common", "icon": "gem", "text": "İsabetteki her Kızıl kart +1 Çarpan."},
	{"id": "c_blue", "name": "Mavi Mühür", "rarity": "common", "icon": "gem", "text": "İsabetteki her Mavi kart +1 Çarpan."},
	{"id": "c_green", "name": "Yeşil Mühür", "rarity": "common", "icon": "gem", "text": "İsabetteki her Yeşil kart +1 Çarpan."},
	{"id": "c_gold", "name": "Sarı Mühür", "rarity": "common", "icon": "gem", "text": "İsabetteki her Sarı kart +1 Çarpan."},
	{"id": "crowd", "name": "Kalabalık", "rarity": "common", "icon": "hand", "text": "4 veya daha fazla kartla yapılan isabette +3 Çarpan."},
	{"id": "goldtooth", "name": "Altın Diş", "rarity": "common", "icon": "tooth", "gold": 1, "text": "Her isabette +1 altın kazandırır."},
	{"id": "lone", "name": "Yalnız Kurt", "rarity": "rare", "icon": "wolf", "text": "2 veya daha az kartla yapılan isabette +4 Çarpan."},
	{"id": "hunter", "name": "Seri Avcısı", "rarity": "rare", "icon": "rainbow", "text": "Renk serisi yapan isabette +4 Çarpan."},
	{"id": "hoarder", "name": "Biriktirici", "rarity": "rare", "icon": "swap", "text": "Kalan her değiştirme hakkı için +1 Çarpan."},
	{"id": "merchant", "name": "Tüccar Dostu", "rarity": "rare", "icon": "bag", "discount": 1, "text": "Tüccardaki her şey 1 altın ucuz."},
	{"id": "even", "name": "Simetri", "rarity": "rare", "icon": "scale", "text": "Hedef çift sayıysa +3 Çarpan."},
	{"id": "spellbag", "name": "Büyü Kesesi", "rarity": "rare", "icon": "potion", "text": "Bu tur kullandığın her büyü için +2 Çarpan."},
	{"id": "nearshot", "name": "Yakın Atış", "rarity": "unique", "icon": "target", "tolerance": 1, "text": "Toplam hedefe 1 uzaksa da isabet sayılır."},
	{"id": "firststrike", "name": "İlk Darbe", "rarity": "unique", "icon": "bolt", "text": "Turun ilk oynaması isabetse skor ×2."},
	{"id": "prime", "name": "Asal Ruh", "rarity": "unique", "icon": "rune", "text": "Hedef asal sayıysa skor ×2."},
	{"id": "gambler", "name": "Kumar Masası", "rarity": "unique", "icon": "dice", "text": "Her isabette 0–6 arası rastgele Çarpan."},
	{"id": "stoneheart", "name": "Taş Kalp", "rarity": "unique", "icon": "stone", "text": "Destendeki her Taş için +2 Çarpan."},
	{"id": "seereye", "name": "Kâhin Gözü", "rarity": "legendary", "icon": "eye", "event_every": 2, "text": "Olaylar 3 yerine 2 isabette bir gerçekleşir."},
	{"id": "giant", "name": "Dev Avcısı", "rarity": "legendary", "icon": "tower", "text": "Hedef 30 veya üstüyse skor ×2."},
	{"id": "goldshield", "name": "Altın Kalkan", "rarity": "legendary", "icon": "shield", "life_save": true, "text": "Bir kez can kaybını önler, sonra kırılır."},
	{"id": "infinity", "name": "Sonsuz Halka", "rarity": "epic", "icon": "infinity", "text": "Her isabette kalıcı olarak +1 Çarpan biriktirir."},
	{"id": "crown", "name": "Hükümdar Tacı", "rarity": "epic", "icon": "crown", "plays_mod": -1, "text": "Skor ×3, ama her tur 1 oynama hakkın eksik olur."},
]

## Bekçiler: her katın 3. turu özel kurallıdır
const BOSSES := {
	"redban": {"name": "Kızıl Yasak", "icon": "skull", "text": "Kızıl sayı kartları 0 değerinde sayılır."},
	"nodiscard": {"name": "Kısır Döngü", "icon": "swap", "text": "Bu tur değiştirme hakkı yok."},
	"slippery": {"name": "Kaygan Hedef", "icon": "shift", "text": "Her oynamadan sonra hedef değişir."},
	"heavy": {"name": "Ağır El", "icon": "hand", "text": "Elinde 1 kart eksik tutarsın."},
	"silence": {"name": "Sessizlik", "icon": "fog", "text": "Büyü kartları kullanılamaz."},
	"short": {"name": "Dar Vakit", "icon": "hourglass", "text": "1 oynama hakkın eksik."},
}

## Olaylar (etkileri RunState._run_event içinde). tone: good | bad | neutral
const EVENTS := {
	"shift": {"w": 3, "name": "Hedef Kaydı", "tone": "neutral", "hint": "Hedef 1–4 sayı kayar.", "icon": "shift"},
	"reroll": {"w": 2, "name": "Yeni Hedef", "tone": "neutral", "hint": "Hedef baştan belirlenir.", "icon": "reroll"},
	"gift": {"w": 3, "name": "Hediye Kart", "tone": "good", "hint": "Destene güçlü bir kart girer.", "icon": "gift"},
	"treasure": {"w": 2, "name": "Hazine Sandığı", "tone": "good", "hint": "3–6 altın kazanırsın.", "icon": "coin"},
	"stone": {"w": 2, "name": "Taş Düştü", "tone": "bad", "hint": "Destene 0 değerli bir Taş girer.", "icon": "stone"},
	"burn": {"w": 2, "name": "Yangın", "tone": "bad", "hint": "Elinden rastgele bir kart yanar.", "icon": "flame"},
	"thief": {"w": 1, "name": "Hırsız", "tone": "bad", "hint": "En yüksek sayı kartın çalınır.", "icon": "mask"},
	"boost": {"w": 2, "name": "Renk Fırtınası", "tone": "good", "hint": "Bir renk 2 oynama boyunca ×2 değer.", "icon": "bolt"},
	"wind": {"w": 2, "name": "Arka Rüzgâr", "tone": "good", "hint": "+1 oynama hakkı kazanırsın.", "icon": "wind"},
	"storm": {"w": 1, "name": "Fırtına", "tone": "bad", "hint": "1 değiştirme hakkı gider.", "icon": "storm"},
	"shadow": {"w": 2, "name": "Gölge Kart", "tone": "neutral", "hint": "Destene eksi değerli bir kart girer.", "icon": "moon"},
	"swap": {"w": 1, "name": "Takas", "tone": "neutral", "hint": "Elindeki tüm kartlar yenilenir.", "icon": "swap"},
	"heal": {"w": 1, "name": "Şifa Kaynağı", "tone": "good", "hint": "1 can kazanırsın (en fazla 4).", "icon": "spring"},
}

const ACHIEVEMENTS := [
	{"id": "tutorial", "name": "Çırak", "icon": "star", "text": "Öğreticiyi bitir.", "unlocks": ["joker", "echo"]},
	{"id": "firsthit", "name": "İlk İsabet", "icon": "target", "text": "İlk isabetini yap.", "unlocks": ["compass"]},
	{"id": "combo", "name": "Renk Ustası", "icon": "rainbow", "text": "Bir renk serisi yap.", "unlocks": ["rainbow", "c_green"]},
	{"id": "round3", "name": "Yolun Başı", "icon": "banner", "text": "Bir oyunda 3. turu geç.", "unlocks": ["class:pyro"]},
	{"id": "boss1", "name": "Bekçi Avcısı", "icon": "skull", "text": "Bir bekçiyi yen.", "unlocks": ["shield", "hunter"]},
	{"id": "round6", "name": "Kararlı", "icon": "tower", "text": "Bir oyunda 6. turu geç.", "unlocks": ["class:seer"]},
	{"id": "big200", "name": "Dev Vuruş", "icon": "bolt", "text": "Tek oynamada 200 skor yap.", "unlocks": ["mul3"]},
	{"id": "score1000", "name": "Bin Puan", "icon": "coin", "text": "Bir oyunda toplam 1000 skora ulaş.", "unlocks": ["add10", "c_gold"]},
	{"id": "spells10", "name": "Büyücü Çırağı", "icon": "potion", "text": "Toplam 10 büyü kullan.", "unlocks": ["painter", "spellbag"]},
	{"id": "charms3", "name": "Koleksiyoncu", "icon": "bag", "text": "Aynı anda 3 tılsım taşı.", "unlocks": ["merchant"]},
	{"id": "five", "name": "Kalabalık El", "icon": "hand", "text": "5 veya daha fazla kartla isabet yap.", "unlocks": ["equal"]},
	{"id": "lives4", "name": "Dört Can", "icon": "heart", "text": "4 cana ulaş.", "unlocks": ["standard"]},
	{"id": "rich", "name": "Hazine", "icon": "coin", "text": "Aynı anda 25 altına sahip ol.", "unlocks": ["goldshield"]},
	{"id": "round9", "name": "Efsane", "icon": "crown", "text": "Bir oyunda 9. turu geç.", "unlocks": ["timewarp"]},
]

const STARTER_CLASSES := ["guard", "alchemist"]
const CLASS_UNLOCK_CARDS := {"pyro": ["spark", "fuel"], "seer": ["moonlight", "thirdeye", "fog"]}
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
