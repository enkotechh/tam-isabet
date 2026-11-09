# Tam İsabet — Yol Haritası

Son güncelleme: 9 Kasım 2026

## 📍 Kaldığımız yer
- **Asıl sürüm:** `godot/` (Godot 4.7, iOS hedefli). Oynanabilir, 47 testin hepsi geçiyor, görünüm Art Deco (siyah, altın, fildişi).
- **Sıradaki iş:** fon müzikleri. Birkaç parça olacak (menü, oyun, bekçi turu), Art Deco temasına uygun caz/swing havasında, sesi ayarlanabilir. Ardından açılışta "elf" karşılama sesi.
- **Bekleyen büyük kararlar** (aşağıda "Açık sorular"):
  - çarpansız yeni skor sistemi
  - Demon/Human/Elf/Oz ırklarının mevcut sınıflarla ilişkisi
  - kart illüstrasyonları
  - DLC ve Under Market
- **Çalışma düzeni:**
  - Windows bilgisayarda Godot, git ve GitHub CLI kurulu. GitHub hesabı `enkotechh`, depo herkese açık.
  - Mac'e geçince `git clone` ile devam edilecek. iOS'a çıkış Mac'te yapılacak.
- **Yeni oturumda:** önce bu dosyayı ve CLAUDE.md'yi oku, testleri çalıştır, sonra sıradaki işe geç.

## ✅ Yapılanlar

### Web prototipi (`index.html`, `css/`, `js/`)
- Çekirdek oyun: kartlarla hedef sayıya **tam** ulaşma
- 84 kart: 36 sayı kartı + 48 özel kart (işlemler, joker, büyüler)
- 4 sınıf, her birinin tur başına bir kez kullanılan gücü ve 6 sınıf kartı: Muhafız, Simyacı, Kor Büyücüsü, Kâhin
- 5 nadirlik: beyaz Sıradan, mavi Nadir, mor Ender, sarı Efsanevi, kırmızı Epik
- Canlar (2 ile başlar, en fazla 4), her 3 isabette gerçekleşen olaylar (13 tür)
- Balatro tarzı katman: Puan × Çarpan skoru, tur hedef skoru, katlar ve bekçi turları (6 bekçi), altın, tüccar, 22 tılsım
- Kilit sistemi: geçilen her tur bir kart veya tılsım açar, 14 başarım, ekranın altında başarım bildirimleri
- 11 adımlık öğretici, deste oluşturucu, açılış menüsü, fantastik meyhane görünümü ve efektler

### Godot 4.7 sürümü (`godot/`, iOS hedefi)
- Tüm veriler ve kurallar web sürümünden birebir taşındı (`run_state.gd`, arayüzden bağımsız)
- 47 otomatik test: kurallar, skor, öğretici, tüccar, desteler, sesler ve 48 oyunluk bot simülasyonu
- Arayüz:
  - açılış menüsü, sınıf seçimi, oyun masası (yelpaze el, kart kart puan sayımı)
  - olay, ganimet, tüccar, can ve oyun sonu pencereleri
  - öğretici balonu, başarım bildirimleri
  - deste oluşturucu (koleksiyon)
- 22 ses efekti, dosya kullanmadan kodla üretiliyor; menüden açılıp kapatılabiliyor
- Ekran görüntüsü turu testi (`tests/shots.tscn`)

### Art Deco görsel yenileme (9 Kasım 2026)
- **Palet:** oniks siyahı zemin, parlak altın çizgiler, fildişi yazı alanları. Puan kutusu lacivert, Çarpan kutusu yakut.
- **Yazı tipleri (OFL, `godot/assets/fonts/`):** Limelight başlıklarda ve düğmelerde, Poiret One süslü alt yazılarda, Josefin Sans gövde metninde ve aralıklı büyük harf etiketlerde.
- **Kartlar:**
  - köşeleri kesik oniks gövde, dış çizgi nadirlik renginde, iç çizgi altın
  - kemerli resim penceresi, arkasında güneş ışınları, altında basamaklı süs
  - elmas değer taşı, altın çizgili isim bandı, fildişi açıklama kutusu
  - alt köşelerde yelpazeler, efsanevi ve epik kartlarda yarım güneş arması
- **Arayüz:**
  - güneş ışınlı ve yelpaze sıralı zemin
  - tüm panel ve düğmelerde köşeleri kesik çift altın çizgi (`DecoBox`)
  - sekizgen hedef kadranı, elmaslı süs çizgileri
- Fon müziği bu yenilemenin devamında eklenecek.

## 📋 Yapılacaklar

### Ses
- [ ] **Fon müzikleri (sıradaki adım):** birkaç parça (menü, oyun, bekçi turu), Art Deco temasına uygun (caz/swing havası), ses ayarı
- [ ] **Girişte "elf" ses efekti:** açılış ekranı için büyülü/elf temalı karşılama sesi

### Kartlar ve görseller
- [ ] **Resimli kartlar:** her kart için illüstrasyon (şu an ikon var). Görsellerin kaynağı ve lisansı netleştirilecek.
- [ ] **Kart ırkları/sınıfları:** Demon, Human, Elf, Oz (Oz ile ne kastedildiği netleştirilecek) ve diğerleri. Mevcut 4 sınıfla (Muhafız, Simyacı, Kor Büyücüsü, Kâhin) nasıl birleşeceğine karar verilecek: ırk mı olacak, sınıfların yerine mi geçecek?
- [x] ~~Ana oynanış ekranının grafik yenilemesi~~ → Art Deco stiline geçildi (yukarıda)

### Oyun tasarımı
- [ ] **Balatro tarzı çarpan sisteminden çıkılacak.** Puan × Çarpan skoru, tılsımlar ve tur hedef skoru yeniden tasarlanacak. Neyin kalacağı (tüccar, altın, tılsımlar, bekçiler) karara bağlanacak.
- [ ] **Yeni mekanikler** (sonradan belirlenecek)

### İçerik ve ticari
- [ ] **2 ek paket (DLC):** içerikleri belirlenecek
- [ ] **"Under Market":** oyun içi satın alımların yapılacağı market. iOS'ta App Store uygulama içi satın alma (StoreKit) entegrasyonu gerekecek. Godot için iOS satın alma eklentisi seçilecek.

### iOS'a çıkış (Mac'te)
- [ ] Godot iOS dışa aktarma şablonları, Apple Developer hesabı, Xcode ile cihazda deneme
- [ ] Uygulama ikonu, açılış ekranı, App Store görselleri
- [x] ~~Yazı tiplerini projeye gömmek~~ → Limelight, Poiret One, Josefin Sans eklendi

## ❓ Açık sorular
- "Oz" ırkı ne olacak?
- Çarpansız yeni skor sistemi nasıl olacak?
- Kart illüstrasyonları kim tarafından, hangi stilde hazırlanacak?
- DLC ve Under Market içerikleri, fiyatlandırma
