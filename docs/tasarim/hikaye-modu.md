# Hikâye Modu ve Yeni Tema — Tasarım Önerisi

Durum: **uygulandı** (9 Kasım 2026). Menü, yeni adlar, ara sahne sistemi, Prolog ve 8 bölümlük ilerleme çalışıyor. Ara sahne çizimleri geçici (kodla çizilen siluetler), grafik aşamasında yenilenecek.
Kaynak: `docs/hikaye/kumar-babasi.pdf`, görsel örnekler: `docs/referans/`

## 0. Ana menü ✅ (yapıldı)
- **Devam Et:** yalnızca yarım kalmış bir oyun varsa görünür
- **Hikâyeye Başla:** prolog ara sahnesi gelene kadar doğrudan masaya geçer. İlk seferde öğretici masa açılır.
- **Öğretici**
- **Ayarlar:** ses aç/kapa, Nasıl Oynanır
- Altta küçük düğmeler: **Koleksiyon** ve **Başarımlar**
- Slogan: "Sıfırdan gelen adam, her şeyini sıfıra oynar."

## 1. Hikâyeye Başla → Prolog
"Hikâyeye Başla"ya basınca **Prolog** oynar: hikâyenin 1. bölümü "Sıfır Numaralı Adam".

- 6 sahne, toplam yaklaşık 60 saniye. Sahneler hikâye belgesindeki storyboard'dan alınıyor:
  1. rulet çarkına kuşbakışı, top dönüyor
  2. kızıl gökyüzü, projektörler, bordo sedan Hotel Meridian'in önüne yanaşıyor
  3. alçak açıdan Silas'ın silueti, sigarasının ucu yanıyor
  4. eldivenli parmak asansörün 9. düğmesine basıyor, ardından The Gilded Zero
  5. Silas fişlerini sıfıra koyuyor, spot ışığı yeni şarkıcıya dönüyor
  6. panjurdan sızan ışıkta Silas'ın gözleri
- **Animasyon:** sahneler kodla çizilmiş Dark Deco siluetleri. Hepsinde yavaş yakınlaşma, yağmur katmanı, film greni ve titreyen ışık var.
- **Altyazı:** dış ses metni sahnelerin altında harf harf belirir. Yazılar Poiret One, sahne başlıkları Limelight ile yazılır.
- **Atla** düğmesi her an görünür.
- Prolog, kanca cümlesiyle biter: "Bu şarkıyı bilen iki kişi vardı. Biri on beş yıl önce ölmüştü." Ardından top cebe düşer, ekran kararır.
- Sonra kumarhaneye geçilir ve ilk masa (öğretici) başlar.

İleride illüstrasyonlar gelince kodla çizilen sahnelerin yerini resimler alır. Animasyon sistemi aynı kalır.

## 2. Hikâye modunun yapısı
Oyunda zaten her **kat 3 turdan** oluşuyor ve 3. tur bekçi turu. Bu yapı hikâyeye birebir oturuyor:

**1 kat = 1 bölüm.** Bir katın 3 turunu kazanınca:
- bölümün ara sahnesi oynar (animasyonlu, altyazılı)
- yeni kartların kilidi açılır
- hikâye bir sonraki bölüme geçer

Hikâyede 8 bölüm var, yani tam bir hikâye 24 tur sürüyor.

| Kat | Bölüm | Bekçi (3. tur) | Açılanlar |
|---|---|---|---|
| Prolog | Sıfır Numaralı Adam | — (öğretici masa) | başlangıç destesi |
| 1 | Kara Bankacı | Cornelius Black'in teklifi | Silas kartları |
| 2 | Kayıp Kız | Polis Baskını | Vivienne kartları + Vivienne karakteri |
| 3 | Kasa Her Zaman Kazanır | 1914 Gecesi (geri dönüş) | Eddie kartları + Eddie karakteri |
| 4 | Dedektif | Sızıntı | Harlow kartları + Harlow karakteri |
| 5 | Defter | Black'in Adamları | efsanevi kartlar |
| 6 | Son Masa | Hileli Çark | epik kartlar |
| 7 | Kara Salı | Borsa Çöküşü | "Kara Salı" kartı |
| 8 | Final | Cornelius Black | Serbest Oyun modu tamamen açılır |

- **Kaybedince:** oyun biter ama hikâye ilerlemesi kaydedilir. Yeni oyun, ulaşılan bölümün başından başlar.
- **Serbest Oyun:** bugünkü sonsuz roguelike mod olarak kalır. Hikâyede açılan kartlar orada da kullanılır.
- Başarımlar da kart açmaya devam eder.

## 3. Sınıflar yerine karakterler
Sınıflar hikâyedeki karakterlere dönüşür. Güçler aynı kalır, yalnızca adları ve görünümleri değişir.

| Eski sınıf | Yeni karakter | Güç |
|---|---|---|
| Muhafız | **Silas Crane, "Mr. Zero"** (başlangıç karakteri) | *Ev Kuralı*: bu tur +1 oynama hakkı |
| Simyacı | **Eddie Finch**, kart sayma dehası | *Kart Sayma*: sonraki oynamada hedefe 1 uzak toplam da isabet sayılır |
| Kor Büyücüsü | **Dedektif Harlow** | *Baskın*: seçili kartları at, 1 fazlasını çek |
| Kâhin | **Vivienne Rook**, caz şarkıcısı | *Sahne*: sıradaki olayı iki seçenekten biriyle değiştir |

## 4. Kartların yeni adları (temaya uygun)
Kuralları aynı, yalnızca adları ve ikonları değişiyor.

**Nötr kartlar**
| Eski | Yeni | Etki |
|---|---|---|
| ×2 Çarpan | **Katla** | ×2 |
| ×3 Çarpan | **Üçe Katla** | ×3 |
| ÷2 Bölücü | **Yarı Yarıya** | ÷2 |
| Joker | **Joker** | 1–9 |
| Gölge | **Komisyon** | −2 |
| Derin Gölge | **Haraç** | −5 |
| Takviye | **Bahşiş** | +5 |
| Kuşatma | **Para Tomarı** | +10 |
| Kare Rünü | **Borsa Rüzgârı** | x² |
| Ayna | **Sahte Defter** | basamakları ters çevirir |
| Eşitleyici | **Ayarlı Masa** | sayılar en yükseğe eşitlenir |
| Yansıma | **Tekrar Bahis** | en yüksek kart bir kez daha |
| Gökkuşağı | **Kaçak İçki** | her rengin yerine geçer |
| Kumarbaz Zarı | **Barbut Zarı** | 1–12 |
| Altın Sikke | **Altın Fiş** | isabette ×3 |
| Lanetli 13 | **Uğursuz 13** | 13 |
| Keşif | **Muhbir** | 2 kart çek |
| Geri Çağır | **Tahsilat** | ıskartadan kart geri al ("Borç her zaman tahsil edilir") |
| Boyacı | **Ayakkabı Boyacısı** | renkleri boyar (Silas'ın geçmişi) |
| Kalkan | **Rüşvet** | can kaybetmezsin |
| Zaman Bükümü | **Gece Uzar** | +2 oynama |
| Pusula | **İçeriden Bilgi** | hedef 1–3 azalır |
| Kurban | **Gözden Çıkar** | kart yok et, +1 oynama |

**Silas** (eski Muhafız): Mızrak → **Sekiz Kat** (8), Nöbet → **Kapı Görevlisi** (+4), Tahkimat → **Ev Kuralı** (+1 oynama), Disiplin → **Masamda Hile Yok** (aynı renk +5), Kalkan Duvarı → **Gizli Kapı**, Sancak → **Bordo Sedan** (isabette can)

**Eddie** (eski Simyacı): Damıtık Öz → **Kart Sayma** (+3), Katalizör → **Ezber** (kart başına +1), Dönüşüm → **İşaretli Deste** (1 ve 2'ler 6 olur), İksir → **Kasadan Sızıntı**, Çözücü → **Pay** (÷3), Filozof Taşı → **Dahi Hesap** (1–20)

**Harlow** (eski Kor Büyücüsü): Kıvılcım → **İhbar** (2, kart çek), Yakıt → **Delil Yak**, Alev Dalgası → **Baskın**, Ateş Topu → **Tek Kurşun** (11, yanar), Kül Yığını → **Rook's Hall Külleri**, Volkan → **Kara Salı** (×4, yanar)

**Vivienne** (eski Kâhin): Ay Işığı → **Hüzünlü Şarkı** (6), Üçüncü Göz → **Sahne Işığı**, Sis → **Sigara Dumanı** (−3, kart çek), Kristal Küre → **Dedikodu**, Yıldız Haritası → **Babamın Defteri**, Kader İpliği → **Rulet Çarkı** (hedefe 3 yakın da isabet)

**Lanet:** Taş → **Senet** (0 değerli borç senedi)

**Sayı kartları:** adları şimdilik aynı (Kızıl, Mavi, Yeşil, Sarı). "Altın" adı para birimiyle karışacağı için kullanılmadı.

**Eşyaların tamamı (eski tılsımlar):** Kızıl Gül, Mavi Mendil, Yeşil Çuha, Sarı Pırlanta, Kalabalık Masa, Altın Çakmak, Yalnız Kurt, Seri Avcısı, Kumbara, Karaborsa Dostu, Çift Zar, Hamle Defteri, Kıl Payı, İlk El, Uğurlu Sayı, Rulet Masası, Borç Defteri, Muhbir Ağı, Büyük Balık, Avukat, Sıfır Cebi, Kumar Babasının Yüzüğü.

**Engellerin tamamı (eski bekçiler):** İçki Yasağı, Kapalı Kapılar, Hileli Çark, Borç Yükü, Polis Baskını, Sabaha Karşı.

**Masa türleri:** Küçük Masa, Büyük Masa, Engel (eski Küçük Sınav, Büyük Sınav, Bekçi).

## 5. Diğerleri de temaya geçer
- **Tılsımlar → Eşyalar.** Örnekler: Altın Diş → **Altın Çakmak**, Kumar Masası → **Rulet Masası**, Hükümdar Tacı → **Kumar Babasının Yüzüğü**, Sonsuz Halka → **Sıfır Cebi**, Kâhin Gözü → **Muhbir Ağı**.
- **Bekçiler → Engeller.** Örnekler: Sessizlik → **Polis Baskını** (büyü yok), Kızıl Yasak → **İçki Yasağı**, Dar Vakit → **Sabaha Karşı**, Ağır El → **Borç Yükü**.
- **Olaylar → Şehir olayları.** Örnekler: Hırsız → **Yankesici**, Taş Düştü → **Senet Geldi**, Hazine Sandığı → **Kasa Payı**, Şifa Kaynağı → **Bir Kadeh Viski**, Fırtına → **Sağanak**.
- **Büyü kartları → "Hamle" kartları.** Fantastik büyü dili kalkar.
- **İkonlar:** önce mevcut ikonlar arasından en uygunları kullanılır. Temaya özel yeni ikonlar (fiş, kadeh, şapka, sedan, rulet) sonra çizilir.

## 6. Uygulama sırası
1. ✅ Kart, karakter, eşya, engel ve olay adlarını değiştir. Testler aynı kurallarla geçmeye devam etmeli. (İkonlar henüz eski.)
2. ✅ Ara sahne sistemini kur: sahne çizimi, yakınlaşma, yağmur, altyazı, atla düğmesi.
3. ✅ Prologu ekle, açılışı Prolog → masa akışına çevir.
4. ✅ Hikâye ilerlemesini ekle: kat = bölüm, bölüm sonunda ara sahne ve kilit açma, ilerlemenin kaydı.
5. ✅ Bölüm 2–8 ara sahnelerini ekle.
6. Ekran görüntüleriyle kontrol et.
