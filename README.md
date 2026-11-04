# Tam İsabet

Kartlarla hedef sayıya tam ulaşmaya çalıştığın, fantastik temalı bir roguelike bulmaca kart oyunu.

- Bir sınıf seçip desteni kuruyorsun.
- Her isabetle skor topluyorsun.
- Tüccardan tılsım alıp kombinasyon kuruyorsun.
- Oynadıkça yeni kartların kilidini açıyorsun.

Şu an tarayıcıda çalışan bir prototip. İleride iOS'a taşınacak.

## Çalıştırma

Oyun birden fazla dosyadan oluştuğu için en sorunsuz yol yerel bir sunucuyla açmak:

- **Mac / Linux:** proje klasöründe `python3 -m http.server 8766`, ardından tarayıcıda `http://localhost:8766`
- **Windows:** `powershell -ExecutionPolicy Bypass -File tools/serve.ps1`, ardından `http://localhost:8766`

İlerleme (açılan kartlar, başarımlar, desteler, rekor) tarayıcının yerel deposunda tutulur.

## Oyun döngüsü

1. **Öğretici:** ilk açılışta "Öğreticiyle Başla" adım adım temel mekanikleri gösterir. Menüden tekrar açılabilir.
2. **İsabet:** seçilen kartların sonucu hedefe tam eşitse isabettir ve skor verir:
   - **Puan** = hedef sayı + kart başına 5 + sayı kartlarının değeri
   - **Çarpan** = 1 + renk serisi (+2) + tılsım bonusları
   - **Skor** = Puan × Çarpan. Puan kart kart sayılır ve animasyonla gösterilir.
3. **Turlar:** her kat 3 turdur: Küçük Sınav, Büyük Sınav ve özel kurallı **Bekçi**. Tur hedef skoru katlarla hızla büyür.
4. **Canlar:** oynama hakları bitince tur hedefine ulaşılamamışsa 1 can gider ve tur yeniden başlar. 2 canla başlanır, en fazla 4 olur.
5. **Ganimet ve Tüccar:** tur sonunda altın kazanılır (tur ödülü + kalan oynama hakları + faiz). Tüccarda:
   - kart, tılsım ve güçlendirme alınabilir,
   - mağaza yenilenebilir,
   - desteden kart çıkarılabilir.
6. **Tılsımlar:** en fazla 5 tane taşınabilir ve kalıcı bonus verir (22 tılsım). Örnekler: Kızıl Mühür, Seri Avcısı, İlk Darbe, Sonsuz Halka.
7. **Olaylar:** her 3 isabette (Kâhin Gözü ile 2) sıradaki olay gerçekleşir.

## İlerleme ve kilitler

- Başlangıçta açık olanlar: sayı kartları, birkaç temel kart, 4 tılsım ve 2 sınıf (Muhafız, Simyacı).
- **Her geçilen tur** sıradaki kilitli kartı veya tılsımı açar. Açılma sırası nadirliğe göre basitten nadire.
- **14 başarım** var ve her biri belirli kartları, tılsımları veya sınıfları açar. Örneğin Kor Büyücüsü "bir oyunda 3. turu geç", Kâhin "6. turu geç" ile açılır.
- Açılan her şey ekranın altında "Başarım açıldı / Yeni kart açıldı" bildirimiyle gösterilir.

## Nadirlik

Basitten nadire, kartın çerçeve rengi:

| Nadirlik | Renk | Destede en fazla | Tüccar fiyatı |
|---|---|---|---|
| Sıradan | beyaz | 2 | 3 |
| Nadir | mavi | 2 | 5 |
| Ender | mor | 2 | 7 |
| Efsanevi | sarı | 1 | 9 |
| Epik | kırmızı | 1 | 12 |

Koleksiyon, deste listesi, deste görünümü ve kart çıkarma ekranları nadirliğe göre sıralıdır.

## Kartlar

84 kart: 36 sayı kartı (4 renk × 1–9) + 48 özel kart (24 nötr, her sınıfa 6). Türler: `num` (renkli sayı), `add` (renksiz değer), `op` (işlem), `wild` (joker), `spell` (büyü, tek başına kullanılır), `curse` (Taş).

Hesaplama sırası: sayılar ve eklemeler → kare → çarpanlar → bölücüler → ayna.

## Kod yapısı

```
index.html        ekranların iskeleti
css/style.css     görünüm: nadirlik çerçeveleri, arena, skor paneli, tüccar, bildirimler, öğretici
js/data.js        renkler, NADİRLİK, ikonlar, sınıflar, KARTLAR, TILSIMLAR, BEKÇİLER,
                  önerilen desteler, kilit sırası, BAŞARIMLAR, olaylar
js/fx.js          efektler: parçacıklar, halkalar, uçan kartlar, skor sahnesi, banner
js/game.js        oyun mantığı, skor, tüccar, ilerleme, öğretici, ekran çizimi
tools/serve.ps1   Windows için yerel sunucu
```

- **Yeni kart:** `js/data.js` → `SPECIAL_CARDS`. Büyüyse etkisini `js/game.js` → `SPELLS` içine yaz.
- **Yeni tılsım:** `js/data.js` → `CHARMS`. Skor etkisi `score(ctx)` ile yazılır: `ctx.chips(n)`, `ctx.mult(n)`, `ctx.x(n)`.
- **Yeni başarım:** `ACHIEVEMENTS` listesine ekle. Koşulu `js/game.js` içinde `achieve('id')` ile tetikle.
- **Denge:** `goalFor()` (tur hedefleri), `newTarget()` (hedef sayı aralığı), `RARITY` fiyat/ağırlıkları, `startRun()` başlangıç değerleri (altın, oynama, el boyutu).

## Sonraki adımlar (iOS)

- Mac'te SwiftUI + SpriteKit ile ya da Godot/Unity ile taşıma. Oyun mantığı (`evaluate`, `scorePlay`, `play`, `SPELLS`, `EVENTS`, `CHARMS`) arayüzden ayrık olduğu için doğrudan çevrilebilir.
- Kart illüstrasyonları, ses efektleri, dokunma titreşimi, Game Center.
