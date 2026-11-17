import '../l10n/l10n.dart';
import 'daily_l10n.dart';

/// Günün ayeti ve günün hadisi. Liste her gün sırayla döner
/// (yılın kaçıncı günü olduğuna göre). İsterseniz Firestore'daki
/// `daily` koleksiyonuna taşıyarak uzaktan da yönetebilirsiniz.
///
/// Ayetler: Türkçe metin, uygulamadaki Diyanet İşleri Başkanlığı Mealinden (assets/quran/meal_diyanet.json)
/// [DailyItem.ref] ile harfiyen alınır; aşağıdaki metin yalnızca meal dosyası yoksa gösterilir.
/// Hadisler: Kütüb-i Sitte kaynaklarından, kitap/bab ve numarasıyla.
class DailyItem {
  const DailyItem(this.text, this.source, {this.ref, this.arabic = false});
  final String text;
  final String source;

  /// Arapça arayüzde ayet metni Kur'an'dan bu kaynakla alınır: (sure, ilk ayet, son ayet).
  final (int, int, int)? ref;

  /// Metin Arapça mı (sağdan sola, Arapça yazı tipiyle gösterilir)?
  final bool arabic;
}

const dailyAyahs = <DailyItem>[
  DailyItem('Siz beni anın ki ben de sizi anayım. Bana şükredin, nankörlük etmeyin.', 'Bakara Suresi, 152', ref: (2, 152, 152)),
  DailyItem('Ey iman edenler! Sabır ve namazla Allah\'tan yardım isteyin. Şüphesiz Allah sabredenlerle beraberdir.', 'Bakara Suresi, 153', ref: (2, 153, 153)),
  DailyItem('Kullarım sana beni sorduğunda bilsinler ki ben onlara çok yakınım. Bana dua edenin duasına karşılık veririm.', 'Bakara Suresi, 186', ref: (2, 186, 186)),
  DailyItem('Allah hiç kimseye gücünün yetmediği bir yük yüklemez.', 'Bakara Suresi, 286', ref: (2, 286, 286)),
  DailyItem('Hep birlikte Allah\'ın ipine sımsıkı sarılın; ayrılığa düşmeyin.', 'Âl-i İmrân Suresi, 103', ref: (3, 103, 103)),
  DailyItem('Gevşemeyin, üzülmeyin. Eğer gerçekten iman ediyorsanız üstün olan sizsiniz.', 'Âl-i İmrân Suresi, 139', ref: (3, 139, 139)),
  DailyItem('İyilik ve takva üzerine yardımlaşın; günah ve düşmanlık üzerine yardımlaşmayın.', 'Mâide Suresi, 2', ref: (5, 2, 2)),
  DailyItem('Kur\'an okunduğu zaman onu dinleyin ve susun ki size merhamet edilsin.', 'A\'râf Suresi, 204', ref: (7, 204, 204)),
  DailyItem('Müminler o kimselerdir ki Allah anıldığında kalpleri ürperir, ayetleri okunduğunda imanları artar.', 'Enfâl Suresi, 2', ref: (8, 2, 2)),
  DailyItem('Ey insanlar! Size Rabbinizden bir öğüt, gönüllere şifa, müminlere yol gösterici ve rahmet gelmiştir.', 'Yûnus Suresi, 57', ref: (10, 57, 57)),
  DailyItem('Bilesiniz ki kalpler ancak Allah\'ı anmakla huzur bulur.', 'Ra\'d Suresi, 28', ref: (13, 28, 28)),
  DailyItem('Eğer şükrederseniz elbette size nimetimi artırırım.', 'İbrâhîm Suresi, 7', ref: (14, 7, 7)),
  DailyItem('Erkek olsun kadın olsun, mümin olarak kim salih amel işlerse ona güzel bir hayat yaşatacağız.', 'Nahl Suresi, 97', ref: (16, 97, 97)),
  DailyItem('Şüphesiz bu Kur\'an, en doğru olan yola iletir.', 'İsrâ Suresi, 9', ref: (17, 9, 9)),
  DailyItem('Kur\'an\'dan, müminler için şifa ve rahmet olan şeyler indiriyoruz.', 'İsrâ Suresi, 82', ref: (17, 82, 82)),
  DailyItem('"Rabbim, ilmimi artır" de.', 'Tâhâ Suresi, 114', ref: (20, 114, 114)),
  DailyItem('Rahmân\'ın kulları yeryüzünde tevazu ile yürüyen kimselerdir.', 'Furkân Suresi, 63', ref: (25, 63, 63)),
  DailyItem('Sana vahyedilen kitabı oku ve namazı kıl. Namaz, hayâsızlıktan ve kötülükten alıkoyar.', 'Ankebût Suresi, 45', ref: (29, 45, 45)),
  DailyItem('İnsanlara yüzünü ekşitip çevirme, yeryüzünde böbürlenerek yürüme.', 'Lokmân Suresi, 18', ref: (31, 18, 18)),
  DailyItem('Allah\'ın kitabını okuyanlar ve namazı kılanlar, asla zarar etmeyecek bir kazanç umarlar.', 'Fâtır Suresi, 29', ref: (35, 29, 29)),
  DailyItem('Allah\'ın rahmetinden ümidinizi kesmeyin. Allah bütün günahları bağışlar.', 'Zümer Suresi, 53', ref: (39, 53, 53)),
  DailyItem('İyilikle kötülük bir olmaz. Sen kötülüğü en güzel olanla sav.', 'Fussilet Suresi, 34', ref: (41, 34, 34)),
  DailyItem('Müminler ancak kardeştir. Öyleyse kardeşlerinizin arasını düzeltin.', 'Hucurât Suresi, 10', ref: (49, 10, 10)),
  DailyItem('Allah katında en değerliniz, O\'na karşı gelmekten en çok sakınanınızdır.', 'Hucurât Suresi, 13', ref: (49, 13, 13)),
  DailyItem('Andolsun, Kur\'an\'ı öğüt almak için kolaylaştırdık. Öğüt alan yok mu?', 'Kamer Suresi, 17', ref: (54, 17, 17)),
  DailyItem('İman edenlerin, Allah\'ı anarken kalplerinin yumuşama vakti gelmedi mi?', 'Hadîd Suresi, 16', ref: (57, 16, 16)),
  DailyItem('Kim Allah\'a karşı gelmekten sakınırsa Allah ona bir çıkış yolu açar.', 'Talâk Suresi, 2', ref: (65, 2, 2)),
  DailyItem('Kim Allah\'a tevekkül ederse O, ona yeter.', 'Talâk Suresi, 3', ref: (65, 3, 3)),
  DailyItem('Kur\'an\'ı ağır ağır, tane tane oku.', 'Müzzemmil Suresi, 4', ref: (73, 4, 4)),
  DailyItem('Rabbin sana verecek, sen de hoşnut olacaksın.', 'Duhâ Suresi, 5', ref: (93, 5, 5)),
  DailyItem('Şüphesiz güçlükle beraber bir kolaylık vardır. Evet, güçlükle beraber bir kolaylık vardır.', 'İnşirâh Suresi, 5-6', ref: (94, 5, 6)),
];

const dailyHadiths = <DailyItem>[
  DailyItem('Sizin en hayırlınız Kur\'an\'ı öğrenen ve öğretendir.', 'Buhârî, Fezâilü\'l-Kur\'ân, 21'),
  DailyItem('Kur\'an okuyun; çünkü o, kıyamet günü kendisini okuyanlara şefaatçi olarak gelecektir.', 'Müslim, Müsâfirîn, 252'),
  DailyItem('Kim Allah\'ın kitabından bir harf okursa ona bir iyilik yazılır; bir iyilik de on katıyla ödüllendirilir.', 'Tirmizî, Fezâilü\'l-Kur\'ân, 16'),
  DailyItem('Kur\'an\'ı güzel okuyan, değerli meleklerle beraberdir. Zorlanarak okuyana ise iki sevap vardır.', 'Buhârî, Tefsîr, 80; Müslim, Müsâfirîn, 244'),
  DailyItem('Bir topluluk Allah\'ın kitabını okuyup aralarında müzakere ederse, üzerlerine huzur iner ve onları rahmet kuşatır.', 'Müslim, Zikir, 38'),
  DailyItem('Ameller niyetlere göredir.', 'Buhârî, Bed\'ü\'l-vahy, 1'),
  DailyItem('Sizden biri, kendisi için istediğini kardeşi için de istemedikçe gerçek anlamda iman etmiş olmaz.', 'Buhârî, Îmân, 7'),
  DailyItem('Kolaylaştırınız, zorlaştırmayınız; müjdeleyiniz, nefret ettirmeyiniz.', 'Buhârî, İlim, 11'),
  DailyItem('Allah katında amellerin en sevimlisi, az da olsa devamlı olanıdır.', 'Buhârî, Rikâk, 18'),
  DailyItem('Müslüman, elinden ve dilinden Müslümanların güvende olduğu kimsedir.', 'Buhârî, Îmân, 4'),
  DailyItem('Kardeşine gülümsemen sadakadır.', 'Tirmizî, Birr, 36'),
  DailyItem('Güzel söz sadakadır.', 'Buhârî, Edeb, 34'),
  DailyItem('Merhamet etmeyene merhamet edilmez.', 'Buhârî, Edeb, 18'),
  DailyItem('Allah\'a ve ahiret gününe iman eden ya hayır söylesin ya da sussun.', 'Buhârî, Edeb, 31'),
  DailyItem('Kur\'an okuyan mümin, kokusu da tadı da güzel olan turunç gibidir.', 'Buhârî, Fezâilü\'l-Kur\'ân, 17'),
  DailyItem('Evlerinizi kabirlere çevirmeyin. Bakara Suresi\'nin okunduğu evden şeytan uzaklaşır.', 'Müslim, Müsâfirîn, 212'),
  DailyItem('İçinde Kur\'an\'dan hiçbir şey bulunmayan kalp, harap olmuş ev gibidir.', 'Tirmizî, Fezâilü\'l-Kur\'ân, 18'),
  DailyItem('Güçlü kişi güreşte rakibini yenen değil, öfkelendiğinde kendine hâkim olandır.', 'Buhârî, Edeb, 76'),
  DailyItem('Hediyeleşin ki birbirinizi sevesiniz.', 'Buhârî, el-Edebü\'l-Müfred, 594'),
  DailyItem('Mümin mümine karşı, parçaları birbirini tutan bir bina gibidir.', 'Buhârî, Salât, 88'),
  DailyItem('Allah sizin dış görünüşünüze ve mallarınıza değil, kalplerinize ve amellerinize bakar.', 'Müslim, Birr, 34'),
  DailyItem('Dua ibadetin ta kendisidir.', 'Tirmizî, Daavât, 1'),
  DailyItem('İnsanların çoğunun kıymetini bilmediği iki nimet vardır: sağlık ve boş vakit.', 'Buhârî, Rikâk, 1'),
  DailyItem('Bir hayra vesile olan, onu yapan gibi sevap kazanır.', 'Müslim, İmâre, 133'),
  DailyItem('Temizlik imanın yarısıdır.', 'Müslim, Tahâret, 1'),
  DailyItem('Hayâ imandandır.', 'Buhârî, Îmân, 16'),
  DailyItem('Allah güzeldir, güzelliği sever.', 'Müslim, Îmân, 147'),
  DailyItem('İnsanlara teşekkür etmeyen, Allah\'a da şükretmiş olmaz.', 'Tirmizî, Birr, 35'),
  DailyItem('Kim bir müminin dünya sıkıntılarından birini giderirse, Allah da onun kıyamet sıkıntılarından birini giderir.', 'Müslim, Zikir, 38'),
  DailyItem('Sadaka malı eksiltmez.', 'Müslim, Birr, 69'),
  DailyItem('Kur\'an ehline "Oku ve yüksel; dünyada nasıl tane tane okuyorsan öyle oku" denir.', 'Tirmizî, Fezâilü\'l-Kur\'ân, 18'),
];

int _dayOfYear(DateTime d) => d.difference(DateTime(d.year, 1, 1)).inDays;

DailyItem ayahOfDay([DateTime? date]) {
  final d = date ?? DateTime.now();
  final i = (_dayOfYear(d) + d.year) % dailyAyahs.length;
  if (Lang.isEn) return DailyItem(dailyAyahsEn[i].$1, dailyAyahsEn[i].$2);
  if (Lang.isAr) return DailyItem('', '', ref: dailyAyahRefs[i], arabic: true);
  return dailyAyahs[i];
}

DailyItem hadithOfDay([DateTime? date]) {
  final d = date ?? DateTime.now();
  final i = (_dayOfYear(d) + d.year * 7) % dailyHadiths.length;
  if (Lang.isEn) return DailyItem(dailyHadithsEn[i].$1, dailyHadithsEn[i].$2);
  if (Lang.isAr) return DailyItem(dailyHadithsAr[i].$1, dailyHadithsAr[i].$2, arabic: true);
  return dailyHadiths[i];
}
