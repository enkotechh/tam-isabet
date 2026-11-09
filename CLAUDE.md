# Port Halloway — Claude için proje notu

Oyunun eski adı "Tam İsabet" (depo ve klasör adı hâlâ öyle). Hikâye: `docs/hikaye/kumar-babasi.pdf`, tasarım: `docs/tasarim/hikaye-modu.md`.

Kartlarla hedef sayıya **tam** ulaşmaya dayalı, 1929 noir kumarhane temalı (Dark Deco) roguelike bulmaca kart oyunu. Hedef platform **iOS**. Asıl geliştirme **Godot 4.7** sürümünde (`godot/`). Web sürümü (`index.html`, `js/`, `css/`) kuralların ilk prototipi ve referansı.

Durum ve yapılacaklar: **ROADMAP.md**. Yeni bir oturuma başlarken önce onu oku.

## Kullanıcıyla çalışma
- Kullanıcıyla **Türkçe** konuş. Oyundaki tüm metinler Türkçe.
- Kullanıcı yazılımcı değil, oyun tasarımcısı gibi düşünüyor. Teknik ayrıntıyı sade anlat, kararları öneriyle sun.
- Bir oyunu birebir kopyalama (Balatro, Hearthstone vb.). Tür ve mekanik ilhamı olur, ad, görsel ve logo olmaz.
- Telif ve lisans: yalnızca MIT/OFL/CC0 gibi uygun lisanslı varlık ve kod kullan, lisans notunu ekle. Lisanssız repodan kod alma.

## Godot projesi (`godot/`)
```
scripts/data/game_data.gd   autoload "Data": kartlar, tılsımlar, sınıflar, bekçiler, olaylar, başarımlar, nadirlikler
scripts/core/run_state.gd   RunState: bir oyunun tüm kuralları (arayüzden bağımsız, testler bunu kullanır)
scripts/core/progress.gd    autoload "Progress": kilitler, başarımlar, rekor, desteler, ses tercihi (user://progress.json)
scripts/core/sfx.gd         autoload "Sfx": kodla sentezlenen ses efektleri
scripts/ui/main.gd          ekranlar, pencereler, animasyonlar, öğretici balonu, bildirimler, deste oluşturucu
scripts/ui/card_view.gd     kart çizimi (3 katman: çerçeve/gövde → ikon TextureRect → yazılar)
scripts/ui/hand_view.gd     yelpaze el
scripts/ui/cutscene.gd      hikâye ara sahneleri (altyazı, atla, kodla çizilen sahneler)
scripts/ui/ui_kit.gd        renkler, yazı tipleri, düğme/panel üreticileri
tests/test_runner.tscn      kural testleri + bot simülasyonu
tests/shots.tscn            arayüz turu, ekran görüntüsü alır
```

Kurallar:
- **Oyun kuralları yalnızca `run_state.gd` içinde.** Arayüz eylemleri çağırır, sonra durumu ve `run.fx` kuyruğunu okuyup çizer.
- Yeni kart/tılsım/olay eklerken verisi `game_data.gd`'ye, etkisi `run_state.gd`'ye gider, testi `test_runner.gd`'ye eklenir.
- Arayüz kodla kuruluyor (elle .tscn yazılmıyor). GDScript'te Variant değerlerden `:=` ile tür çıkarımı yapma, açık tür yaz (`var x: int = ...`).
- Kartın içine `draw_texture_rect` ile ikon çizme: bazı sürücülerde kare çiziliyor. İkonlar TextureRect katmanında.
- Yelpaze eldeki kartların `z_index` değeri var. Pencereler ve efektler daha yüksek `z_index` ile çiziliyor.

Görsel stil: **Art Deco** (siyah + altın + fildişi).
- Renkler ve yazı tipleri `ui_kit.gd`'de: `title_font()` Limelight, `deco_font()` Poiret One, `body_font()`/`bold_font()`/`caps_font()` Josefin Sans.
- Kutular `DecoBox` ile çiziliyor (`scripts/ui/deco_box.gd`: köşeleri kesik, çift çizgi, köşe elmasları). Yeni panel için `UIKit.panel/box/frame`, düğme için `UIKit.button` kullan. StyleBoxFlat ve yuvarlak köşe kullanma.
- Türkçe büyük harf için `to_upper()` değil `UIKit.upper()` kullan (i→İ, ı→I).
- Label'larda `clip_text` kullanma: Josefin Sans'ın büyük harf işaretleri (Ö, Ğ) kırpılıyor. Taşan yazı için `text_overrun_behavior` kullan.
- Nadirlik kartın dış çizgi renginden okunur (beyaz/mavi/mor/sarı/kırmızı). Bu kural korunmalı.

## Komutlar (proje kökünden)
```bash
godot --headless --path godot --import
godot --headless --path godot res://tests/test_runner.tscn
godot --path godot --resolution 390x844 res://tests/shots.tscn -- .shots
```
- Test çıkış kodu 0 ise hepsi geçti. Her değişiklikten sonra testleri çalıştır.
- Ekran görüntüleri `.shots/` klasörüne düşer (git'e girmez). Görsel değişikliklerden sonra bakılır.
- Windows'ta `godot` komutu PATH'te değilse winget kurulum yolundaki `Godot_v4.7.2-stable_win64_console.exe` kullanılır. Mac'te `/Applications/Godot.app/Contents/MacOS/Godot`.
- Web sürümü: `python3 -m http.server 8766` (Windows: `powershell -ExecutionPolicy Bypass -File tools/serve.ps1`).

## Git
- Depo: https://github.com/enkotechh/tam-isabet (dal: `main`). Değişiklikleri anlamlı Türkçe commit mesajlarıyla gönder.
