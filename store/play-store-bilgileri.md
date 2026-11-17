# Hafız Kardeşim — Google Play bilgileri

## Mağaza sayfası

**Uygulama adı (30):** Hafız Kardeşim

**Kısa açıklama (80):** Ezberini dinlet: uygulama dinler, doğruyu açar, hatanı gösterir. Reklamsız.

**Tam açıklama:** `app-store/metadata.json` içindeki `description` metninin aynısı (Play'e olduğu gibi yapıştırılır).

**Kategori:** Eğitim · **Etiketler:** Kur'an, eğitim, din
**İletişim e-postası:** sviapp.developer@gmail.com
**Web sitesi:** https://sviappdeveloper-sketch.github.io/hafiz-kardesim/
**Gizlilik politikası:** https://sviappdeveloper-sketch.github.io/hafiz-kardesim/gizlilik.html
**Hesap silme URL'si:** https://sviappdeveloper-sketch.github.io/hafiz-kardesim/hesap-silme.html

**Görseller (store/ klasöründe):**
- Uygulama simgesi 512×512: `play-icon-512.png`
- Öne çıkan görsel 1024×500: `play-one-cikan-1024x500.png`
- Telefon ekran görüntüleri (1080×2160): `play-ekran/1.png` … `6.png`

## Uygulama içeriği formları — önerilen yanıtlar

**Reklamlar:** Uygulamada reklam yok.

**Uygulama erişimi:** Bazı özellikler giriş gerektirir. İnceleme için: uygulama içinden herhangi bir e-postayla anında üye olunabilir. İstenirse bir test hesabı (e-posta + şifre) verilir.

**İçerik derecelendirmesi (IARC):** Kategori "Referans, Haber veya Eğitim". Şiddet, cinsellik, kumar, uyuşturucu yok. Kullanıcılar etkileşime girer (hoca–öğrenci bağı, canlı ders; serbest sohbet yok). Beklenen: 3+ / Herkes.

**Hedef kitle:** 13 yaş ve üzeri. Çocuklara yönelik değil.

**Veri güvenliği (Data safety):**
- Veri toplanıyor mu: Evet. Üçüncü taraflarla paylaşılıyor mu: Hayır.
- Aktarımda şifreleniyor: Evet. Kullanıcı silme isteyebilir: Evet (uygulama içi + web sayfası).
- Toplanan veri türleri:
  - Kişisel bilgiler → **Ad** (uygulama işlevi, hesap yönetimi; zorunlu)
  - Kişisel bilgiler → **E-posta adresi** (hesap yönetimi; zorunlu)
  - Kişisel bilgiler → **Diğer bilgiler**: Hanım/Bey seçimi, 6 haneli kullanıcı kodu (uygulama işlevi; zorunlu)
  - Uygulama etkinliği → **Diğer kullanıcı tarafından oluşturulan içerik**: hoca–öğrenci bağı, ödev, hoca notu, canlı ders işaretleri (uygulama işlevi; isteğe bağlı)
  - Mesajlar → **Diğer uygulama içi mesajlar**: destek mesajları (müşteri desteği; isteğe bağlı)
- **Ses:** Ses kaydı toplanmaz. Mikrofon yalnızca ezber dinletirken açılır; konuşma telefonun Google ses tanıma hizmetinde metne çevrilir, uygulama sesi saklamaz ve göndermez. Play'in tanımında "toplama" sayılmaz (cihazda / sistem hizmetinde işlenir, geliştiriciye ulaşmaz).
- Konum, finans, sağlık, fotoğraf, rehber, cihaz kimliği, reklam kimliği: Toplanmıyor.

**İzinler:** İnternet, mikrofon (RECORD_AUDIO: ezber dinletme), bildirim (ezan vakti), tam zamanlı alarm (ezan bildirimi).

## Sürüm

- Paket adı: `com.sviapp.hafiz_kardesim` (yüklendikten sonra değiştirilemez)
- Play App Signing: Açık (varsayılan)
- Yükleme anahtarı: `android-keys/upload-keystore.jks` · SHA-1 `2A:99:5F:26:AD:97:1C:7D:B3:A2:2B:8D:6D:9C:20:8F:81:B5:58:63`
- Yüklenecek dosya: `apk` dalındaki `HafizKardesim.aab`
- **Yeni kişisel geliştirici hesaplarında** üretime çıkmadan önce kapalı testte 12 test kullanıcısının 14 gün kalması gerekir (Play Console → Test → Kapalı test).
- Play App Signing açıldıktan sonra Play Console → Test ve yayın → Uygulama bütünlüğü → **Uygulama imzalama anahtarı SHA-1** değeri Firebase'deki Android uygulamasına da eklenmeli (yoksa Play'den inen uygulamada Google ile giriş çalışmaz).
