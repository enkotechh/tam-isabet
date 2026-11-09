# Port Halloway — Yol Haritası

(Eski adı: Tam İsabet)

Son güncelleme: 9 Kasım 2026

## 📍 Kaldığımız yer
- **Asıl sürüm:** `godot/` (Godot 4.7, iOS hedefli). Oynanabilir, 47 testin hepsi geçiyor. Görünüm Dark Deco'ya geçiyor.
- **Oyunun adı:** **Port Halloway** (9 Kasım 2026). "Tam İsabet" adı tamamen bırakıldı.
- **Yapıldı (9 Kasım 2026):**
  - ana menü: Devam Et, Hikâyeye Başla, Öğretici, Ayarlar
  - temaya uygun kart, karakter, eşya, engel ve olay adları
  - Dark Deco palet ve gece şehri zemini
  - oyun ekranı oyuncunun gözünden (POV) kumar masası:
    - yeşil çuha, lamba ışığı, "The Gilded Zero" arması, bordo deri kenar
    - oynanan kartlar masanın ortasına atılıyor
    - masada yanan puro ve dumanı, viski kadehi, fiş kulesi
  - **hikâye modu çalışıyor** (tasarım: `docs/tasarim/hikaye-modu.md`):
    - "Hikâyeye Başla" önce Prolog'u oynatır (7 sahne, altyazılı, Atla düğmesi), sonra masaya geçilir
    - her kat bir bölüm: katın başında bölümün sahneleri oynar, 3 tur kazanınca kapanış cümlesi gelir ve yeni kartlar açılır
    - 8 bölüm, her bölümün kendi engeli var
    - Vivienne 2., Eddie 3., Harlow 4. bölümde açılır; başta yalnızca Silas var
    - kaybedince yeni oyun kalınan bölümden başlar; Koleksiyon'dan "Oyna" hikâyesiz serbest oyundur
  - **yeni skor sistemi: Bahis ve Oran** (`docs/tasarim/bahis-sistemi.md`):
    - Puan × Çarpan kalktı
    - fiş hem para hem skor
    - her oynamada bahis seçilir (minimumun 1/2/4 katı)
    - isabet bahis × oran öder (1 kart 4:1 … 4+ kart 1:1), ıskada bahis gider
    - fiş biterse kasa borç verir, destene Senet girer
  - 71 test geçiyor
- **Sıradaki iş:** grafiklerden önce kalkacak/eklenecek/değişecek şeyler. Grafikler (kartlar, ikonlar, ara sahne çizimleri) en sonda topluca gözden geçirilecek. Ardından:
  - kartların Dark Deco çizimi ve temaya uygun ikonlar
  - dark noir caz fon müzikleri
  - atmosfere uygun açılış sesi Ardından dark noir caz fon müzikleri ve atmosfere uygun açılış sesi.
- **Yeni yön (9 Kasım 2026):** oyun, "Kumar Babası" hikâyesinin dünyasına taşınıyor: 1929, hayali liman şehri Port Halloway, gizli kumarhane The Gilded Zero. Hikâye: `docs/hikaye/kumar-babasi.pdf`. Görsel örnekler: `docs/referans/`.
- **Bekleyen büyük kararlar** (aşağıda "Açık sorular"):
  - ırkların/sınıfların hikâyeye göre yeniden belirlenmesi
  - hikâye modunun oynanışa nasıl bağlanacağı
  - kart illüstrasyonları
  - DLC ve Black Market
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

### Görsel stil
- [ ] **Dark Deco'ya geçiş (ilk iş):** mevcut Art Deco görünümü noir bir Dark Deco havasına çevrilecek. Örnek resimler `docs/referans/` klasöründe.
  - **Palet (hikâye belgesinden):** siyah `#07080C`, altın `#C9A24A`, bordo `#5A141C`, sis grisi `#3B4252`. Kırmızı çok az, yalnızca vurgu olarak kullanılacak.
  - **Örneklerden gelen hava:** gece şehri, ışıklı pencereli gökdelen siluetleri, mor/kızıl gökyüzü, bordo kadife, sıcak lamba ışığı, panjurdan sızan çizgili ışık, yüzler yarı gölgede.
  - **Dokular:** hafif film greni, yağmur, titreyen ışık.
  - **Kalanlar:** Limelight ve Poiret One yazı tipleri, köşeleri kesik altın çizgiler.
  - **Değişecekler:** zemin, kartlar, paneller. Masa, rulet ve kumarhane öğeleri öne çıkacak.

### Hikâye modu
- [ ] **Hikâye modu:** "Kumar Babası" hikâyesi (Silas Crane, 1929, Port Halloway) oyuna bölüm bölüm eklenecek. Dört perde: Kral, Çatlaklar, Hesaplaşma, Sıfır. Tema "sıfır", oyunun "tam isabet" fikriyle bağlanabilir. Bölümlerin oynanışa nasıl bağlanacağı (ara sahneler, bekçi turları, karakterler) birlikte belirlenecek.

### Ses
- [ ] **Fon müzikleri:** birkaç parça (menü, oyun, bekçi turu), dark noir caz. Saksafon önde, piyano ve çello arkada. Black'in sahnelerinde aynı tema daha alçak ve yavaş çalacak. Sesi ayarlanabilir olacak.
- [ ] **Açılış sesi:** "elf" sesi yerine atmosfere uygun bir ses gelecek. Öneri: dönen rulet topu ve cebe düşüşü (hikâyenin her bölümü bu sesle açılıyor).

### Kartlar ve görseller
- [ ] **Resimli kartlar:** her kart için illüstrasyon (şu an ikon var). Görsellerin kaynağı ve lisansı netleştirilecek.
- [ ] **Kart ırkları/sınıfları:** önceki Demon/Human/Elf/Oz fikri bırakıldı. Irklar ve sınıflar hikâyeye göre yeniden belirlenecek. Mevcut 4 sınıfın (Muhafız, Simyacı, Kor Büyücüsü, Kâhin) ne olacağına da karar verilecek.
- [x] ~~Ana oynanış ekranının grafik yenilemesi~~ → Art Deco stiline geçildi (yukarıda)

### Oyun tasarımı
- [x] ~~**Balatro tarzı çarpan sisteminden çıkılacak.**~~ → Bahis ve Oran sistemi geldi (`docs/tasarim/bahis-sistemi.md`).
- [ ] **Yeni mekanikler** (sonradan belirlenecek)

### İçerik ve ticari
- [ ] **2 ek paket (DLC):** içerikleri belirlenecek
- [ ] **"Black Market"** (eski adı Under Market): oyun içi satın alımların yapılacağı market. iOS'ta App Store uygulama içi satın alma (StoreKit) entegrasyonu gerekecek. Godot için iOS satın alma eklentisi seçilecek.

### iOS'a çıkış (Mac'te)
- [ ] Godot iOS dışa aktarma şablonları, Apple Developer hesabı, Xcode ile cihazda deneme
- [ ] Uygulama ikonu, açılış ekranı, App Store görselleri
- [x] ~~Yazı tiplerini projeye gömmek~~ → Limelight, Poiret One, Josefin Sans eklendi

## ❓ Açık sorular
- Irklar ve sınıflar hikâyeye göre ne olacak?
- Fantastik öğeler (büyüler, bekçiler, tılsımlar) 1929 noir dünyasında kalacak mı, yoksa kumarhane karşılıkları mı olacak?
- Hikâye modu oynanışa nasıl bağlanacak?
- Kart illüstrasyonları kim tarafından hazırlanacak? Stil Dark Deco örneklerindeki gibi olacak.
- DLC ve Black Market içerikleri, fiyatlandırma
