# Hafız Kardeşim — App Store

Paket kimliği: `com.sviapp.hafizKardesim` · SKU: `hafizkardesim` · Birincil dil: Türkçe · Kategori: Eğitim (ikinci: Başvuru)

## Sıra

1. **App Store Connect → Uygulamalar → + → Yeni Uygulama:** iOS · Ad `Hafız Kardeşim` · Türkçe · paket kimliği `com.sviapp.hafizKardesim`
   (listede yoksa önce Codemagic'te **iOS TestFlight** bir kez çalıştırılır; paket kimliğini o oluşturur) · SKU `hafizkardesim`.
2. **Codemagic → iOS TestFlight:** derler, imzalar, yükler.
3. **Codemagic → App Store: sayfayı hazırla:** ad, alt başlık, açıklama, anahtar kelimeler, 6 ekran görüntüsü, kategori,
   yaş derecelendirmesi, inceleme notu yazılır; derleme sürüme bağlanır. Sonunda eksikleri listeler.
4. Elle (bir kez): **Uygulama Gizliliği** formu (aşağıdaki tablo) → Yayımla · **Fiyatlandırma** → Ücretsiz, tüm ülkeler.
5. **Codemagic → App Store: incelemeye gönder.**

## Uygulama Gizliliği yanıtları

Takip (tracking): **Hayır**. Reklam yok.

| Veri türü | Amaç | Kimliğe bağlı | İzleme |
|---|---|---|---|
| İletişim bilgileri → E-posta adresi | Uygulama işlevi | Evet | Hayır |
| İletişim bilgileri → Ad | Uygulama işlevi | Evet | Hayır |
| Kullanıcı içeriği → Diğer kullanıcı içeriği (hoca notu, ödev, canlı ders işaretleri) | Uygulama işlevi | Evet | Hayır |
| Kullanıcı içeriği → Müşteri desteği (destek mesajları) | Uygulama işlevi | Evet | Hayır |
| Tanımlayıcılar → Kullanıcı kimliği (hesap kimliği, 6 haneli kod) | Uygulama işlevi | Evet | Hayır |

Diğer her şey: **Toplanmıyor.** Ses verisi toplanmaz (konuşma Apple'ın konuşma tanıma hizmetinde metne çevrilir; uygulama sesi saklamaz).
Ders geçmişi yalnızca cihazda kalır (sunucuya gönderilmez).

## Firebase (hatim-kardesim projesi)

Apple ile Giriş ve Google ile Giriş'in iPhone'da çalışması için Firebase'e iOS uygulaması eklenmeli:
Proje ayarları → Uygulama ekle → iOS → paket kimliği `com.sviapp.hafizKardesim`. Verilen "Uygulama kimliği" `lib/firebase_options.dart`
içindeki `ios.appId`'ye; Google iOS istemci kimliği (GoogleService-Info.plist'teki CLIENT_ID) `lib/models/constants.dart` içindeki
`googleIosClientId`'ye yazılır. Yazılmadıkça iPhone'da Google ile giriş düğmesi gizli kalır; e-posta ile giriş çalışır.
