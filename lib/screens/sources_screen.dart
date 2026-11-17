import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/ornaments.dart';
import '../l10n/l10n.dart';

/// Kaynakça: uygulamada kullanılan metin, ses, yazı tipi, veri ve yazılımların kaynakları ve lisansları.
class SourcesScreen extends StatelessWidget {
  const SourcesScreen({super.key});

  static List<(String, List<(String, String)>)> get _sections => [
    (lt('Metinler'), [
      (lt('Kur\'ân-ı Kerîm metni'),
          lt('Tanzil Projesi Osmanlı hattı metni (tanzil.net), Medine mushafı sayfa düzeni. Metin değiştirilmeden, Tanzil kullanım şartlarına uygun olarak kullanılmıştır. Lisans: Creative Commons Atıf-Türetilemez 3.0. Metin, AlAdhan/AlQuran Cloud aracılığıyla alınmıştır.')),
      (lt('Hatim duası'),
          lt('Mushafların sonunda yer alan geleneksel Duâ-i Hatm-i Kur\'ân metni. Türkçe anlamı uygulama için sade bir dille hazırlanmıştır.')),
      (lt('Kur\'ân-ı Kerîm meali'),
          lt('Diyanet İşleri meali, Tanzil Projesi aracılığıyla (tanzil.net, tr.diyanet, son güncelleme 27 Aralık 2011). Meal metni değiştirilmeden, noktalaması dahil olduğu gibi kullanılır; Tanzil kullanım şartları gereği yalnızca ticari olmayan amaçla.')),
      (lt('Günün ayeti'),
          lt('Ayetlerin Türkçesi uygulamadaki Diyanet İşleri mealinden harfiyen alınır; suresi ve ayet numarası kartın altında belirtilir.')),
      (lt('Günün hadisi'), lt('Hadis metinlerinin sade Türkçe anlamları; kaynak eserleri kartın altında belirtilmiştir.')),
    ]),
    (lt('Sesler'), [
      (lt('Sesli hatim duası'),
          lt('Hafız Kardeşim için hazırlanmış özgün kayıttır; arka plan müziği ayrılarak yalnızca okuyuş bırakılmıştır.')),
      (lt('Sesli Kur\'an'),
          lt('Sure kayıtları mp3quran.net\'in açık dağıtım ağından (cdn.mp3quran.net) dinlenir ve indirilir; uygulamanın sunucusunda saklanmaz. Okuyucular: Mişari Raşid el-Afasi, Mahmud Halil el-Husari, Muhammed Sıddık el-Minşavi, Abdulbasıt Abdussamed, Mahir el-Muaykıli, Muhammed el-Fakih, Saad el-Gamidi, Yasir ed-Devseri (Hafs rivayeti, murattal). Mealli okuyuşlar islamhouse.com\'dan (d1.islamhouse.com) gelir ve uygulama diline göre gösterilir: Türkçe (Okuyan: Saad el-Gamidi, Meal: Hayrettin Küçükdeniz), İngilizce (Okuyan: Mişari Raşid el-Afasi, Sahih International meali, okuyan: İbrahim Walk).')),
      (lt('Ezan bildirim sesleri'),
          lt('Kayıtların ilk tekbirleri kısaltılıp ses düzeyi dengelenerek kullanılmıştır. Mekke: "Adhan, Great Mosque of Mecca - Jan 21, 2013", Seyfula Islam, CC BY 3.0. Medine: "Call to prayer from the Prophet\'s Mosque", ejaz215 (freesound.org), CC BY 3.0. Sabah Fahri: "Call to prayer by Sabah Fakhry", kamu malı. Kaynak: Wikimedia Commons.')),
    ]),
    (lt('Ezan vakitleri'), [
      (lt('Vakit hesabı'),
          lt('AlAdhan Namaz Vakitleri API\'si (aladhan.com), Diyanet İşleri Başkanlığı hesap yöntemi. Vakitler il merkezinin koordinatlarına göre hesaplanır; ilçelerde birkaç dakikalık fark olabilir. Kesin vakitler için Diyanet İşleri Başkanlığı\'nın resmî vakitleri esas alınmalıdır.')),
    ]),
    (lt('Görseller'), [
      (lt('Logo ve simge'), lt('Hafız Kardeşim için kullanılan altın "القرآن" (el-Kur\'ân) hat logosu.')),
      (lt('Desenler'), lt('Uygulama için özgün olarak üretilmiştir.')),
    ]),
    (lt('Yazı tipleri'), [
      ('Sora', lt('Jonathan Barnbrook ve Julián Moncada. SIL Open Font License 1.1.')),
      ('Manrope', lt('Mikhail Sharanda. SIL Open Font License 1.1.')),
      ('Amiri', lt('Khaled Hosny. SIL Open Font License 1.1.')),
      (lt('Dağıtım'), lt('Yazı tipleri Google Fonts üzerinden kullanılır.')),
    ]),
    (lt('Yazılım ve hizmetler'), [
      ('Flutter', lt('Google. BSD 3-Clause lisansı.')),
      ('Firebase', lt('Google. Hesap (Authentication) ve veri (Cloud Firestore) hizmetleri.')),
      (lt('Diğer kütüphaneler'),
          lt('just_audio, flutter_local_notifications, google_sign_in, shared_preferences, share_plus, url_launcher, timezone ve diğerleri. Ayrıntılı lisans metinleri aşağıdaki "Yazılım lisansları" bölümündedir.')),
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(lt('Kaynakça'))),
      body: PatternBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Text(
              lt('Hafız Kardeşim\'de kullanılan metin, ses, görsel, veri ve yazılımların kaynakları ile lisansları.'),
              style: AppText.body(14, color: AppColors.muted),
            ),
            for (final (title, items) in _sections) ...[
              const SizedBox(height: 24),
              SectionTitle(title),
              const SizedBox(height: 10),
              OrnateCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) Divider(height: 22, color: AppColors.inkLine),
                    Text(items[i].$1, style: AppText.body(14.5, weight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(items[i].$2, style: AppText.body(13, color: AppColors.muted)),
                  ],
                ]),
              ),
            ],
            const SizedBox(height: 24),
            GoldButton(
              label: lt('Yazılım lisansları'),
              icon: Icons.description_outlined,
              outlined: true,
              onPressed: () => showLicensePage(
                context: context,
                applicationName: lt('Hafız Kardeşim'),
                applicationIcon: const Padding(padding: EdgeInsets.all(8), child: AppLogo(size: 56)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
