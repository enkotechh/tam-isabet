[README.md](https://github.com/user-attachments/files/34368615/README.md)
# tam-isabet# Tam İsabet

Kartlarla hedef sayıya tam ulaşmaya çalıştığın bir bulmaca kart oyunu. Şu an tarayıcıda çalışan bir prototip. İleride iOS'a taşınacak.

## Çalıştırma

`tam-isabet.html` dosyasını bir tarayıcıda açman yeterli. Kurulum veya derleme gerekmiyor. Yazı tipleri Google Fonts'tan yüklendiği için internet bağlantısı varsa daha iyi görünür.

## Kurallar

- Elinden kart seç. Toplamları hedefe **tam eşit** olsun. Her isabetten sonra hedef değişir.
- Turu geçmek için oynama hakların bitmeden gereken isabet sayısına ulaş.
- **Canlar:** 2 canla başlarsın, en fazla 4 cana çıkabilirsin. Turu tamamlayamazsan 1 can gider ve tur yeniden başlar. Can bitince oyun biter.
- **Olaylar:** Her 3 isabette "sıradaki olay" gerçekleşir ve yerine yenisi seçilir. Gelecek olay her zaman ekranda görünür.
- **Renk serisi:** Aynı renkten en az 3 kartla yapılan isabet 2 isabet sayılır.
- **Tur sonu:** Desteye kart ekle, bir güçlendirme al (+1 can, +1 oynama, +1 değiştirme, daha büyük el) ya da desteden bir kart çıkar.

### Kartlar

| Kart | Etki |
|---|---|
| Sayı (1–9, 4 renk) | Değeri toplama eklenir |
| ×2 Çarpan | Seçimin toplamını iki katına çıkarır |
| Joker ★ | 1–9 arasında gereken değeri alır |
| Gölge (−1…−4) | Toplamdan düşer |
| Taş | 0 değerlidir, elinde yer kaplar |

### Olaylar

Hedef Kaydı, Yeni Hedef, Hediye Kart, Taş Düştü, Yangın, Hırsız, Renk Fırtınası, Arka Rüzgâr, Fırtına, Gölge Kart, Takas.

## Kod yapısı

Her şey tek dosyada (`tam-isabet.html`):

- `S`: oyunun tüm durumu (deste, el, hedef, canlar, olay sayacı)
- `play()`, `swapCards()`: oyuncu eylemleri
- `EVENTS`: olay tanımları (ad, ton, açıklama, ikon, etki)
- `rewardOptions()`, `applyReward()`: tur sonu ödülleri
- `render()`, `renderModal()`: arayüz
- `flyCards()`, `burstAtDial()`: animasyonlar

Ayarlanabilir sabitler: `START_LIVES`, `MAX_LIVES`, `EVENT_EVERY`. Hedef aralığı `newTarget()` içinde ayarlanıyor.

## Sonraki adımlar (iOS)

- Mac'te SwiftUI + SpriteKit ile ya da Godot/Unity ile oyun mantığını taşı. Oyun mantığı arayüzden bağımsız olduğu için kurallar doğrudan aktarılabilir.
- Ses efektleri, dokunma titreşimi (haptics), Game Center skor tablosu.
