# Hafız Kardeşim

Kur'an ezberini dinletme uygulaması. Hatim Kardeşim'in yapısıyla (Flutter + Firebase) yazıldı ve **aynı üyelik hesabını** kullanır: Hatim Kardeşim üyesi aynı e-posta / Google / Apple hesabıyla girer, arkadaş listesi de ortaktır.

İlk (web/WebView) sürüm `web-surumu` dalında duruyor.

## Bölümler

| Bölüm | Ne yapar |
|---|---|
| 🎙️ Ezber Oku | Ayetler gizli; sen okursun, uygulama Arapça ses tanımayla dinler, doğruyu açar, hatalıyı kırmızı, atlananı turuncu işaretler. İpucu, ayeti aç, doğru say, geri al. |
| 🤝 Kardeşime Dinlet | Yanındaki arkadaş her kelimede Doğru / Hata / Hatırlat'a basar. Mikrofon ve internet gerekmez. |
| 🎓 Hocama Dinlet (canlı) | Öğrenci kendi telefonunda gizli ayetlerle okur, hoca kendi telefonunda metni açık görür ve işaretler; işaretler iki telefona anında gider. Ses telefon / WhatsApp aramasıyla duyulur. |
| Hoca – Öğrenci çalışma alanı | Arkadaş listesinden ya da 6 haneli kodla istek: "Hoca olarak kabul ediyor musun?" / "Öğrenci olarak kabul ediyor musun?". Kabul edince: canlı ders, ödev verme, not, son ders bilgisi, kişiye göre geçmiş. |
| 🔁 Tekrar takvimi | Her ayet puanlanır; 1-3-7-14-30-60 gün arayla "Bugünün tekrarı"na düşer. |
| 🎧 Dinle & Tekrarla | 8 kâri, ayet başına tekrar, bölüm tekrarı, hız, "ardından ben tekrar edeyim", metni gizleme, Diyanet meali. |
| 🔍 Sesle Bul | Birkaç kelime oku, sure ve ayeti bulsun. |
| 📈 İlerlemem · 📕 Hata Defteri · 🕘 Ders Geçmişim | Seri, 16 haftalık takvim, cüz haritası, zayıf ayetler; yanlış kelimeler; bütün dersler tarih tarih. |
| Hatim Kardeşim'den | Üyelik, profil, arkadaşlar, destek ve iletişim, namaz vakitleri + ezan bildirimi + ana ekran widget'ı, kıble pusulası, tema ve dil. |

## Ders geçmişi nerede durur?

- Bütün dersler telefonda, üyeye özel `hafiz_<uid>.json` dosyasında. Uygulamanın sunucusunda **ders kaydı tutulmaz**.
- Android'in kendi Google Drive yedeği ve iPhone'un iCloud yedeği bu dosyayı da yedekler.
- Ayrıca Daha fazla › Yedekleme'den kullanıcının **kendi Google Drive'ının** uygulamaya özel gizli klasörüne yedeklenir; yeni telefonda aynı hesapla girince geri yüklenir.
- Canlı ders sırasında işaretler Firestore'daki geçici `hafizCanli` belgesinden geçer; iki taraf sonucu kendi telefonuna kaydedince belge silinir.

## Firebase (Hatim Kardeşim projesi) için yapılacaklar

1. **Firestore kuralları:** `hafizBag` ve `hafizCanli` koleksiyonlarının kuralları Hatim Kardeşim deposundaki `firestore.rules` dosyasına eklendi; Firebase konsolu › Firestore › Kurallar'a yapıştırıp Yayınla.
2. **Android uygulaması ekle:** Firebase konsolu › Proje ayarları › Uygulama ekle › Android › paket adı `com.sviapp.hafiz_kardesim`; SHA-1 değerleri `apk` dalındaki `IMZA.txt` dosyasında. Google ile giriş ve Drive yedeği bunun için gerekli.
3. **Google Drive API:** Google Cloud konsolu (hatim-kardesim projesi) › API'ler › "Google Drive API" › Etkinleştir. OAuth izin ekranına `drive.appdata` kapsamı eklenir.

## Derleme

`main`'e her gönderimde GitHub Actions ("Derle (Android)") çalışır: kod denetimi, testler (ezber eşleştirme testleri dahil), APK ve AAB. Çıktılar **apk** dalında: `HafizKardesim.apk` (telefonların çoğu), `HafizKardesim-armv7.apk` (eski telefonlar), `HafizKardesim.aab` (Play Store). Hata olursa ayrıntı **log** dalına yazılır.
