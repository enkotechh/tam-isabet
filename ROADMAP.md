# Tam İsabet — Yol Haritası

Son güncelleme: 4 Kasım 2026

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

## 📋 Yapılacaklar

### Ses
- [ ] **Arka plan müziği:** menü, oyun ve bekçi turu için ayrı parçalar, ses ayarı
- [ ] **Girişte "elf" ses efekti:** açılış ekranı için büyülü/elf temalı karşılama sesi

### Kartlar ve görseller
- [ ] **Resimli kartlar:** her kart için illüstrasyon (şu an ikon var). Görsellerin kaynağı ve lisansı netleştirilecek.
- [ ] **Kart ırkları/sınıfları:** Demon, Human, Elf, Oz (Oz ile ne kastedildiği netleştirilecek) ve diğerleri. Mevcut 4 sınıfla (Muhafız, Simyacı, Kor Büyücüsü, Kâhin) nasıl birleşeceğine karar verilecek: ırk mı olacak, sınıfların yerine mi geçecek?
- [ ] **Ana oynanış ekranının grafik yenilemesi**

### Oyun tasarımı
- [ ] **Balatro tarzı çarpan sisteminden çıkılacak.** Puan × Çarpan skoru, tılsımlar ve tur hedef skoru yeniden tasarlanacak. Neyin kalacağı (tüccar, altın, tılsımlar, bekçiler) karara bağlanacak.
- [ ] **Yeni mekanikler** (sonradan belirlenecek)

### İçerik ve ticari
- [ ] **2 ek paket (DLC):** içerikleri belirlenecek
- [ ] **"Under Market":** oyun içi satın alımların yapılacağı market. iOS'ta App Store uygulama içi satın alma (StoreKit) entegrasyonu gerekecek. Godot için iOS satın alma eklentisi seçilecek.

### iOS'a çıkış (Mac'te)
- [ ] Godot iOS dışa aktarma şablonları, Apple Developer hesabı, Xcode ile cihazda deneme
- [ ] Uygulama ikonu, açılış ekranı, App Store görselleri
- [ ] Yazı tiplerini projeye gömmek (şu an sistem fontu, Cinzel / Alegreya Sans hedefleniyor)

## ❓ Açık sorular
- "Oz" ırkı ne olacak?
- Çarpansız yeni skor sistemi nasıl olacak?
- Kart illüstrasyonları kim tarafından, hangi stilde hazırlanacak?
- DLC ve Under Market içerikleri, fiyatlandırma
