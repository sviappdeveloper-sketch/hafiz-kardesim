import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../hafiz/arapca.dart';
import '../../hafiz/kuran.dart';
import '../../services/settings_service.dart';
import '../../theme/app_theme.dart';

/// Hafız ekranlarının ortak ayarları ve parçaları.
class HfAyar {
  static double get yazi => SettingsService.prefs.getDouble('hfYazi') ?? 28;
  static Future<void> setYazi(double v) => SettingsService.prefs.setDouble('hfYazi', v.clamp(18, 48));
  static String get gizle => SettingsService.prefs.getString('hfGizle') ?? 'gizli';
  static Future<void> setGizle(String v) => SettingsService.prefs.setString('hfGizle', v);
  static bool get besmele => SettingsService.prefs.getBool('hfBesmele') ?? true;
  static Future<void> setBesmele(bool v) => SettingsService.prefs.setBool('hfBesmele', v);
  static String get font => SettingsService.prefs.getString('hfFont') ?? 'Amiri Quran';
  static Future<void> setFont(String v) => SettingsService.prefs.setString('hfFont', v);
  static bool get meal => SettingsService.prefs.getBool('hfMeal') ?? true;
  static Future<void> setMeal(bool v) => SettingsService.prefs.setBool('hfMeal', v);
}

/// Ayet yazı tipleri: (Google Fonts adı, ekranda görünen ad, satır yüksekliği).
const arapYaziTipleri = [
  ('Amiri Quran', 'Mushaf (Amiri Kur\'an)', 2.05),
  ('Scheherazade New', 'Şehrazat (iri, okunaklı)', 1.9),
  ('Noto Naskh Arabic', 'Nesih (sade)', 1.95),
  ('Amiri', 'Amiri (klasik nesih)', 2.0),
  ('Lateef', 'Latif (yumuşak)', 1.85),
  ('Markazi Text', 'Merkezî (ince)', 1.9),
];

final _yaziOnbellek = <String, TextStyle>{};

/// Ayet yazısı. Her kelime için yeniden yazı tipi aranmasın diye stiller önbellekte tutulur
/// (uzun bölümlerde ekranın kasmasını önler).
TextStyle arapYazi(double size, {Color? color}) {
  final c = color ?? AppColors.ivory;
  final ad = HfAyar.font;
  final anahtar = '$ad|$size';
  final hazir = _yaziOnbellek[anahtar];
  if (hazir != null) return hazir.copyWith(color: c);
  final tip = arapYaziTipleri.firstWhere((t) => t.$1 == ad, orElse: () => arapYaziTipleri.first);
  TextStyle st;
  try {
    st = GoogleFonts.getFont(tip.$1, fontSize: size, height: tip.$3);
  } catch (_) {
    st = GoogleFonts.amiri(fontSize: size, height: 2.0);
  }
  _yaziOnbellek[anahtar] = st;
  return st.copyWith(color: c);
}

/// Ayet yazı tipi seçici.
class YaziTipiSecici extends StatefulWidget {
  const YaziTipiSecici({super.key, this.onChanged});
  final VoidCallback? onChanged;
  @override
  State<YaziTipiSecici> createState() => _YaziTipiSeciciState();
}

class _YaziTipiSeciciState extends State<YaziTipiSecici> {
  @override
  Widget build(BuildContext context) {
    final sec = HfAyar.font;
    return SizedBox(
      height: 92,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        for (final t in arapYaziTipleri)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                await HfAyar.setFont(t.$1);
                setState(() {});
                widget.onChanged?.call();
              },
              child: Container(
                width: 118,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.inkDeep.withValues(alpha: .45),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: sec == t.$1 ? AppColors.gold : AppColors.inkLine, width: sec == t.$1 ? 2 : 1),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('بِسْمِ ٱللَّهِ', maxLines: 1, textDirection: TextDirection.rtl, style: _onizleme(t.$1)),
                  Text(t.$2, maxLines: 2, textAlign: TextAlign.center, style: AppText.body(11, color: AppColors.muted, height: 1.15)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }

  TextStyle _onizleme(String ad) {
    try {
      return GoogleFonts.getFont(ad, fontSize: 20, color: AppColors.ivory, height: 1.5);
    } catch (_) {
      return GoogleFonts.amiri(fontSize: 20, color: AppColors.ivory, height: 1.5);
    }
  }
}

Color durumRengi(int st) => switch (st) {
      KD.hata => AppColors.danger,
      KD.atla => const Color(0xFFE0A030),
      KD.ipucu => AppColors.reading,
      _ => AppColors.ivory,
    };

/// Gizli/açık kelimelerden oluşan mushaf görünümü (sağdan sola).
/// [hepsiAcik]: hoca görünümü — bütün kelimeler görünür, durumlar renkle gösterilir.
class MushafGorunum extends StatelessWidget {
  const MushafGorunum({
    super.key,
    required this.w,
    required this.ayetler,
    required this.cur,
    required this.gizle,
    required this.anahtarlar,
    this.hepsiAcik = false,
    this.onTap,
  });
  final List<Kelime> w;
  final List<int> ayetler;
  final int cur;
  final String gizle;
  final List<GlobalKey> anahtarlar;
  final bool hepsiAcik;
  final void Function(int i)? onTap;

  @override
  Widget build(BuildContext context) {
    final fs = HfAyar.yazi;
    final bloklar = <Widget>[];
    var parca = <Widget>[];
    void kapat() {
      if (parca.isEmpty) return;
      bloklar.add(Directionality(
        textDirection: TextDirection.rtl,
        child: Wrap(spacing: 6, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: parca),
      ));
      parca = <Widget>[];
    }

    var li = -1;
    for (var i = 0; i < w.length; i++) {
      final k = w[i];
      if (k.li != li) {
        li = k.li;
        final a = Kuran.a[k.ai];
        final onceki = li > 0 ? ayetler[li - 1] : -2;
        if (li == 0 || onceki != k.ai - 1 || a.n == 1) {
          kapat();
          bloklar.add(Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 2),
            child: Text(
              a.n == 1 ? Kuran.ad(a.s).toUpperCase() : '${Kuran.ad(a.s).toUpperCase()} · ${a.n}. AYETTEN',
              textAlign: TextAlign.center,
              style: AppText.label(color: AppColors.muted),
            ),
          ));
          if (a.n == 1) {
            bloklar.add(Text(Kuran.arapAd(a.s), textAlign: TextAlign.center, style: arapYazi(fs * .8, color: AppColors.gold)));
            if (a.s != 1 && a.s != 9 && HfAyar.besmele) {
              bloklar.add(Text(Kuran.besmele, textAlign: TextAlign.center, style: arapYazi(fs * .8, color: AppColors.muted)));
            }
          }
        }
      }
      parca.add(KeyedSubtree(key: anahtarlar[i], child: _kelime(i, k, fs)));
      if (k.end) {
        parca.add(Text('﴿${arapRakam(Kuran.a[k.ai].n)}﴾', style: arapYazi(fs * .8, color: AppColors.gold)));
      }
    }
    kapat();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: bloklar);
  }

  Widget _kelime(int i, Kelime k, double fs) {
    final gizli = k.st == KD.gizli && !hepsiAcik;
    final simdiki = i == cur;
    final renk = k.st == KD.gizli ? (hepsiAcik ? AppColors.ivory.withValues(alpha: .55) : AppColors.ivory) : durumRengi(k.st);
    final st = arapYazi(fs, color: renk);
    Widget metin;
    if (gizli && gizle == 'harf') {
      final m = RegExp('^.[ً-ٰٟٓ-ٕۡ]*').firstMatch(k.t);
      final ilk = m?.group(0) ?? '';
      metin = Text.rich(TextSpan(children: [
        TextSpan(text: ilk, style: st.copyWith(color: AppColors.muted)),
        TextSpan(text: k.t.substring(ilk.length), style: st.copyWith(color: Colors.transparent)),
      ]));
    } else if (gizli && gizle == 'silik') {
      metin = Text(k.t, style: st.copyWith(color: AppColors.ivory.withValues(alpha: .13)));
    } else if (gizli) {
      metin = Text(k.t, style: st.copyWith(color: Colors.transparent));
    } else {
      metin = Text.rich(TextSpan(children: [
        TextSpan(
          text: k.t,
          style: st.copyWith(
            decoration: k.st == KD.hata || k.st == KD.atla ? TextDecoration.underline : null,
            decorationColor: renk,
            decorationStyle: k.st == KD.hata ? TextDecorationStyle.wavy : TextDecorationStyle.dotted,
          ),
        ),
        if (k.pm.isNotEmpty) TextSpan(text: ' ${k.pm}', style: st.copyWith(color: AppColors.gold, fontSize: fs * .7)),
      ]));
    }
    return GestureDetector(
      onTap: onTap == null ? null : () => onTap!(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: gizli && gizle == 'gizli' ? AppColors.inkLine.withValues(alpha: .9) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: simdiki ? Border.all(color: AppColors.gold, width: 2) : null,
        ),
        child: metin,
      ),
    );
  }
}

/// Renklerin anlamı.
class DurumAciklama extends StatelessWidget {
  const DurumAciklama({super.key});
  @override
  Widget build(BuildContext context) {
    Widget n(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 4),
          Text(t, style: AppText.body(11.5, color: AppColors.muted)),
        ]);
    return Wrap(spacing: 12, runSpacing: 4, children: [
      n(AppColors.ivory, 'doğru'),
      n(AppColors.danger, 'hatalı'),
      n(const Color(0xFFE0A030), 'atlandı'),
      n(AppColors.reading, 'ipucu'),
    ]);
  }
}

/// Gizleme türü seçici.
class GizlemeSecici extends StatefulWidget {
  const GizlemeSecici({super.key, this.onChanged});
  final ValueChanged<String>? onChanged;
  @override
  State<GizlemeSecici> createState() => _GizlemeSeciciState();
}

class _GizlemeSeciciState extends State<GizlemeSecici> {
  @override
  Widget build(BuildContext context) {
    final g = HfAyar.gizle;
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'gizli', label: Text('Tam gizli')),
        ButtonSegment(value: 'harf', label: Text('İlk harf')),
        ButtonSegment(value: 'silik', label: Text('Silik')),
      ],
      selected: {g},
      showSelectedIcon: false,
      onSelectionChanged: (s) async {
        await HfAyar.setGizle(s.first);
        setState(() {});
        widget.onChanged?.call(s.first);
      },
    );
  }
}

/// Küçük istatistik kutusu.
class SayiKutu extends StatelessWidget {
  const SayiKutu(this.sayi, this.etiket, {super.key, this.renk});
  final String sayi, etiket;
  final Color? renk;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: AppColors.inkDeep.withValues(alpha: .45),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.inkLine),
          ),
          child: Column(children: [
            Text(sayi, style: AppText.number(20, color: renk ?? AppColors.goldLight)),
            const SizedBox(height: 2),
            Text(etiket, textAlign: TextAlign.center, style: AppText.body(11, color: AppColors.muted, height: 1.2)),
          ]),
        ),
      );
}

String sureMetni(int sn) => sn < 60 ? '$sn sn' : '${sn ~/ 60} dk ${sn % 60} sn';
