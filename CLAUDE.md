# Hafız Kardeşim — Claude devir notu

Bu dosya, uygulamada hangi Claude hesabı veya oturumu çalışırsa çalışsın kaldığı yerden devam edebilmesi için tutulur.
GitHub: `sviappdeveloper-sketch/hafiz-kardesim` (şimdilik herkese açık depo)

## Çalışma kuralları (her oturumda uy)
- Kullanıcı kodlama bilmiyor ve Türkçe yazıyor. Türkçe ve sade cevap ver.
- Kullanıcı açıkça istemedikçe son kayıtlı sürümdeki hiçbir özelliği silme veya kaybetme. Değiştirmeden önce mevcut olanı diğer dallar dahil kontrol et.
- Uygulamaları birbirine karıştırma. Bir uygulamanın Firebase, giriş veya mağaza ayarı değişirken diğerlerinin ayarına dokunma.
- Geliştirici adını her yerde tam olarak **Svi App Developer** diye yaz. Site sviapp.com, iletişim adresi iletisim@sviapp.com, e-postaların gönderen adresi noreply@sviapp.com.
- Derlemeyi teslim ederken yalnızca APK dosyasının kendisini gönder. Zip, rar veya yanında başka dosya olmasın.
- Tüm testlerde (TestFlight ve Play) sitaresivi@icloud.com test kullanıcısı olarak ekli olsun.
- Mağaza ve konsol adımlarını (AdMob, Play Console, App Store Connect, Firebase) mümkün olduğunca kendin yap.
- Derlemeler ücretsiz yoldan, GitHub Actions ile yapılıyor. Codemagic dakikaları bitti.
- **Bu dosyayı güncel tut:** Her oturumun sonunda yaptığın işi tarihiyle "Son işlemler" bölümünün en üstüne ekle, "Bekleyen işler" bölümünü güncelle, sonra commit'leyip push'la.

## Uygulama durumu
- Tarteel tarzı ezber dinletme uygulaması. Flutter + Firebase, sürüm **1.0.1**.
- App Store'da yayında. Google Play'de kapalı testte; kullanıcı Android test kullanıcısı topluyor.
- Üyelik hesapları Hatim Kardeşim ile ortak. Giriş ve kayıt metinleri Hafız Kardeşim'e özel olmalı.
- Ortak Firestore kuralları bu depodaki `firebase/` klasöründe. Kurallar değişince Firebase'e otomatik yükleniyor (`kurallar.yml`) ve yayından önce test ediliyor.
- Derlemeler ayın 1'inde ve 15'inde yapılıyor. Commit mesajında `[derle]` geçerse de derleme başlıyor. Kullanıcı her değişiklikte değil, 1–2 haftada bir derleme istiyor. GitHub depolama kotası için derleme çıktıları küçük tutulmalı.
- Depo ücretsiz Actions için şimdilik açık. Kota yenilenince özel yapılacak.
- Lisans: Hugging Face'teki Quran-Lab/zipformer_p-arabic-v3 ve Muno459/zipformer_p-quran modelleri ticari olmayan lisanslı. Uygulama **ücretsiz kalmalı**: satış, abonelik, reklam veya gelir olmayacak. HF erişim anahtarı `HF_TOKEN` adıyla GitHub Actions secret'larında kayıtlı.
- Logo koyu lacivert zemin üzerinde gümüş "حافظ" hattı. Tasarım lacivert ve gümüş renklerde.
- Dallar: main, aab, apk, asc-gonder, ekran, ios-dene, ios-yayin, log, log-asc, log-ios, log-model, model-yokla, web-surumu.

## Kullanıcının önemli istekleri (kalıcı)
- Ezber Oku hızlı ve gerçek zamanlı olmalı. Okunmamış kelimeler asla gösterilmemeli. Doğru okunan kelime hata sayılmamalı. Seri (hadr) okuma hata üretmemeli. Tekrar okuma ve kendini düzeltme takip edilmeli.
- Okuma sayfası düz beyaz olmalı, harflerin üstüne bir şey çizilmemeli. Besmele her zaman açık görünmeli. Sayfa yumuşak kaymalı, okuma sureden sureye kendiliğinden geçmeli.
- Hoca ve öğrenci eşleşmesi yalnızca kadın–kadın veya erkek–erkek olabilir. Suistimal bildirimi var ve yönetici bunları görebiliyor.
- Telefonun geri hareketi ana menüye doğru adım adım geri götürmeli. iPhone'da üstte geri oku olmalı.
- Kurrâlar arasında Sudais olmayacak.

## Son işlemler (en yeni en üstte)
- 2026-11-27: Kurallar güncellendi: yönetici gruptan cüz silebiliyor (Hatim Kardeşim 1.1.10 için).
- 2026-11-24: Google Play'e yükleme iş akışı eklendi (anahtarsız, github-deploy hizmet hesabıyla).
- 2026-11-24: Hatim Kardeşim'deki yönetici duyuruları için kural eklendi.
- 2026-11-24: Kayıtta "Hafız mısın? Talebe misin?" sorusu soruluyor. Cevap Profilim'den değiştirilebiliyor ve adın altında görünüyor.
- 2026-11-24: Firebase yayını anahtarsız yapılıyor (Workload Identity Federation). Hosting'e assetlinks.json eklendi.
- 2026-11-24: Ayet numarası her yazı tipinde halkanın içinde görünüyor. Arkadaş mesajları için kural eklendi. Play için AAB `aab` dalına konuyor.
- 2026-11-23: Güvenlik: arkadaşlık ve hoca–öğrenci kuralları sıkılaştırıldı.
- 2026-11-20: 1.0.1 sürümü çıktı: canlı derste uygulama içi sesli bağlantı (WebRTC ve TURN sunucusu), hoca komutları, ödev teslimi ("Dersi bitirdim"), Dinle & Tekrarla iyileştirmeleri, Suistimal sekmesi, "Reklam ver" düğmesinin adı "İşbirliği kur / katkı sun" oldu, arkadaşlık isteği iptali. Ayrıca yeni Play yükleme anahtarı alındı.

## Bekleyen işler / kontrol edilecekler
- Ezber Oku'yu akışlı (streaming) Kur'an ses modeline (zipformer) geçirme kararı verildi. `model-yokla` ve `log-model` dallarındaki durumu kontrol et.
- Play'de kapalı testten üretime (production) geçiş, test kullanıcıları tamamlanınca yapılacak.
- Kota yenilenince depoyu özele çevir.
