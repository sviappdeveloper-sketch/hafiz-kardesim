import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../hafiz/arapca.dart';
import '../../hafiz/kuran.dart';
import '../../services/settings_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ornaments.dart';

/// Hafız ekranlarının ortak ayarları ve parçaları.
class HfAyar {
  static double get yazi => SettingsService.prefs.getDouble('hfYazi') ?? 28;
  static Future<void> setYazi(double v) => SettingsService.prefs.setDouble('hfYazi', v.clamp(18, 48));
  static String get gizle {
    final p = SettingsService.prefs;
    // Bir kez: yeni varsayılan "boş sayfa" (okudukça beliren yazı).
    if (p.getBool('hfBosGecis') != true) {
      p.setBool('hfBosGecis', true);
      p.setString('hfGizle', 'bos');
    }
    // Bir kez: Tarteel tarzı denensin diye "kelime izleri" (okunmamış kelimenin yerinde silik iz).
    if (p.getBool('hfIzGecis') != true) {
      p.setBool('hfIzGecis', true);
      p.setString('hfGizle', 'iz');
    }
    return p.getString('hfGizle') ?? 'iz';
  }

  /// Tarteel tarzı mushaf sayfası: Medine mushafının sayfaları, çerçeve, sure başlığı, iki yana yaslı satırlar.
  static bool get mushaf => SettingsService.prefs.getBool('hfMushaf') ?? true;
  static Future<void> setMushaf(bool v) => SettingsService.prefs.setBool('hfMushaf', v);

  /// Okurken beyaz kâğıt sayfa (varsayılan) ya da temanın koyu zemini.
  static bool get beyaz => SettingsService.prefs.getBool('hfBeyaz') ?? true;
  static Future<void> setBeyaz(bool v) => SettingsService.prefs.setBool('hfBeyaz', v);
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
    this.bosCerceve = false,
    this.ayetSiniri,
  });
  /// Bu sıradan sonraki ayetler (okumaya devam için eklenenler) henüz gösterilmez.
  final int? ayetSiniri;
  /// Boş sayfada da sıradaki kelimenin çerçevesi gösterilsin mi (Kardeşime Dinlet'te işaretleyen için).
  final bool bosCerceve;
  final List<Kelime> w;
  final List<int> ayetler;
  final int cur;
  final String gizle;
  final List<GlobalKey> anahtarlar;
  final bool hepsiAcik;
  final void Function(int i)? onTap;

  /// Beyaz sayfa renkleri (kâğıt üstüne koyu mürekkep) ya da temanın renkleri.
  static bool get _b => HfAyar.beyaz;
  static Color get yazi => _b ? const Color(0xFF15181E) : AppColors.ivory;
  static Color get vurgu => _b ? const Color(0xFF8A6A1E) : AppColors.gold;
  static Color get soluk => _b ? const Color(0xFF7A808A) : AppColors.muted;
  static Color get kutu => _b ? const Color(0xFFE6E8EC) : AppColors.inkLine;
  static Color renk(int st) => !_b
      ? durumRengi(st)
      : switch (st) {
          KD.hata => const Color(0xFFC62828),
          KD.atla => const Color(0xFFD27A00),
          KD.ipucu => const Color(0xFF1E63B8),
          _ => yazi,
        };

  /// Kelime listesine bağlı önbellek: dizin → (imza, hazır widget).
  static final _onbellekler = Expando<Map<int, (int, Widget)>>();

  @override
  Widget build(BuildContext context) {
    final fs = HfAyar.yazi;
    final onbellek = _onbellekler[w] ??= {};
    final mushaf = HfAyar.mushaf;
    // Bütün kelimeleri etkileyen ayarlar: biri değişince hepsi yeniden çizilir.
    final ortak = Object.hash(fs, gizle, _b, hepsiAcik, bosCerceve, HfAyar.font, onTap == null, mushaf);

    // Değişmeyen kelimeler yeniden çizilmez/ölçülmez: uzun bölümlerde (cüz) de yazı sesle anında gelir.
    Widget kelimeW(int i) {
      final k = w[i];
      final imza = Object.hash(k.st, i == cur, ortak, k.pm);
      final o = onbellek[i];
      if (o != null && o.$1 == imza) return o.$2;
      final y = KeyedSubtree(key: anahtarlar[i], child: _kelime(i, k, fs, mushaf));
      onbellek[i] = (imza, y);
      return y;
    }

    Widget ayetNoW(int i) {
      final k = w[i];
      // Boş sayfada ayet numarası da ayet okununca belirir.
      final gorunur = hepsiAcik || (gizle != 'bos' && gizle != 'iz') || k.st != KD.gizli;
      final imzaN = Object.hash(gorunur, ortak);
      final on = onbellek[-1 - i];
      if (on != null && on.$1 == imzaN) return on.$2;
      final n = Kuran.a[k.ai].n;
      final Widget y = mushaf
          ? _ayetGulu(n, fs, gorunur ? vurgu : (gizle == 'iz' ? kutu : Colors.transparent), gorunur)
          : Text('﴿${arapRakam(n)}﴾', style: arapYazi(fs * .8, color: gorunur ? vurgu : Colors.transparent));
      onbellek[-1 - i] = (imzaN, y);
      return y;
    }

    if (mushaf) {
      return LayoutBuilder(builder: (context, c) => _sayfalar(context, c.maxWidth, fs, kelimeW, ayetNoW));
    }

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
      if (ayetSiniri != null && k.li >= ayetSiniri!) break;
      if (k.li != li) {
        li = k.li;
        final a = Kuran.a[k.ai];
        final onceki = li > 0 ? ayetler[li - 1] : -2;
        if (li == 0 || onceki != k.ai - 1 || a.n == 1) {
          kapat();
          bloklar.add(_bolumEtiketi(a));
          if (a.n == 1) {
            bloklar.add(Text(Kuran.arapAd(a.s), textAlign: TextAlign.center, style: arapYazi(fs * .8, color: vurgu)));
            if (a.s != 1 && a.s != 9 && HfAyar.besmele) {
              bloklar.add(Text(Kuran.besmele, textAlign: TextAlign.center, style: arapYazi(fs * .8, color: soluk)));
            }
          }
        }
      }
      parca.add(kelimeW(i));
      if (k.end) parca.add(ayetNoW(i));
    }
    kapat();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: bloklar);
  }

  Widget _bolumEtiketi(Ayet a) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 2),
        child: Text(
          a.n == 1 ? Kuran.ad(a.s).toUpperCase() : '${Kuran.ad(a.s).toUpperCase()} · ${a.n}. AYETTEN',
          textAlign: TextAlign.center,
          style: AppText.label(color: soluk),
        ),
      );

  // ───────────── Mushaf sayfası (Tarteel tarzı) ─────────────

  /// Ölçülen kelime genişlikleri ve hazır sayfa düzeni (kelime listesine bağlı).
  static final _genislik = <String, double>{};
  static final _duzenler = Expando<(int, List<_Sayfa>)>();

  /// Çerçevenin iç boşlukları toplamı (iki yan): dış çizgi + aralık + iç çizgi + kenar boşluğu.
  static const _cerceve = 2 * (1.6 + 3 + .8 + 10);
  static const _bosluk = 5.0;

  TextSpan _kelimeSpan(Kelime k, TextStyle st, double fs) => TextSpan(children: [
        TextSpan(text: k.t, style: st),
        if (k.pm.isNotEmpty) TextSpan(text: ' ${k.pm}', style: st.copyWith(fontSize: fs * .7)),
      ]);

  double _olc(Kelime k, double fs, TextScaler ts) {
    final anahtar = '${HfAyar.font}|$fs|${ts.scale(10)}|${k.t}|${k.pm}';
    final h = _genislik[anahtar];
    if (h != null) return h;
    final tp = TextPainter(
      text: _kelimeSpan(k, arapYazi(fs), fs),
      textDirection: TextDirection.rtl,
      textScaler: ts,
      maxLines: 1,
    )..layout();
    final g = tp.width + 4; // kelimenin iki yanındaki 2'şer boşluk
    tp.dispose();
    _genislik[anahtar] = g;
    return g;
  }

  /// Kelimeleri Medine mushafı sayfalarına, sayfaları başlıklara ve iki yana yaslı satırlara böler.
  List<_Sayfa> _duzen(double genislik, double fs, TextScaler ts) {
    final ic = genislik - _cerceve - 6; // küçük pay: satır asla taşmasın
    final imza = Object.hash(ic.round(), fs, HfAyar.font, ts.scale(10), ayetSiniri, w.length, HfAyar.besmele);
    final hazir = _duzenler[w];
    if (hazir != null && hazir.$1 == imza) return hazir.$2;

    final ayetGenislik = fs * 1.15;
    final sayfalar = <_Sayfa>[];
    _Sayfa? sayfa;
    var satirlar = <List<_Oge>>[];
    var satir = <_Oge>[];
    var dolu = 0.0;
    void satirBitir() {
      if (satir.isEmpty) return;
      satirlar.add(satir);
      satir = <_Oge>[];
      dolu = 0;
    }

    void paragrafBitir() {
      satirBitir();
      if (satirlar.isNotEmpty) sayfa!.parcalar.add(_Parca.satirlar(satirlar));
      satirlar = <List<_Oge>>[];
    }

    void ekle(_Oge o, double g) {
      final gerek = satir.isEmpty ? g : dolu + _bosluk + g;
      if (gerek > ic && satir.isNotEmpty) {
        satirBitir();
        satir.add(o);
        dolu = g;
      } else {
        satir.add(o);
        dolu = gerek;
      }
    }

    var li = -1;
    for (var i = 0; i < w.length; i++) {
      final k = w[i];
      if (ayetSiniri != null && k.li >= ayetSiniri!) break;
      final a = Kuran.a[k.ai];
      if (sayfa == null || a.sayfa != sayfa.no) {
        if (sayfa != null) paragrafBitir();
        sayfa = _Sayfa(a.sayfa, a.cuz, a.s);
        sayfalar.add(sayfa);
      }
      if (k.li != li) {
        li = k.li;
        final onceki = li > 0 ? ayetler[li - 1] : -2;
        if (a.n == 1) {
          paragrafBitir();
          sayfa!.parcalar.add(_Parca.sure(a.s));
        } else if (li == 0 || onceki != k.ai - 1) {
          paragrafBitir();
          sayfa!.parcalar.add(_Parca.etiket(k.ai));
        }
      }
      ekle(_Oge(i, false), _olc(k, fs, ts));
      if (k.end) ekle(_Oge(i, true), ayetGenislik);
    }
    if (sayfa != null) paragrafBitir();
    _duzenler[w] = (imza, sayfalar);
    return sayfalar;
  }

  Widget _sayfalar(BuildContext context, double genislik, double fs, Widget Function(int) kelimeW, Widget Function(int) ayetNoW) {
    final sayfalar = _duzen(genislik, fs, MediaQuery.textScalerOf(context));
    final cizgi = vurgu.withValues(alpha: .55);
    final kagit = _b ? Colors.white : AppColors.inkDeep.withValues(alpha: .35);
    Widget sayfaW(_Sayfa s) {
      final ic = <Widget>[
        // Üst bilgi: sure adı ve cüz (basılı mushaftaki gibi).
        Directionality(
          textDirection: TextDirection.rtl,
          child: Row(children: [
            Text(Kuran.arapAd(s.sure), style: arapYazi(fs * .5, color: soluk)),
            const Spacer(),
            Text('الجزء ${arapRakam(s.cuz)}', style: arapYazi(fs * .5, color: soluk)),
          ]),
        ),
      ];
      for (final p in s.parcalar) {
        switch (p.tur) {
          case 0:
            ic.add(_sureBasligi(p.deger, fs));
            if (p.deger != 1 && p.deger != 9 && HfAyar.besmele) {
              ic.add(Text(Kuran.besmele, textAlign: TextAlign.center, style: arapYazi(fs * .85, color: yazi)));
            }
          case 1:
            ic.add(_bolumEtiketi(Kuran.a[p.deger]));
          default:
            for (var j = 0; j < p.satirlar.length; j++) {
              final satir = p.satirlar[j];
              // Paragrafın son satırı kısaysa yaslanmaz (sağdan başlar), diğerleri iki yana yaslanır.
              final yasla = j < p.satirlar.length - 1 || satir.length > 5;
              ic.add(Directionality(
                textDirection: TextDirection.rtl,
                child: Row(
                  mainAxisAlignment: yasla ? MainAxisAlignment.spaceBetween : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    for (var m = 0; m < satir.length; m++) ...[
                      if (!yasla && m > 0) const SizedBox(width: _bosluk),
                      satir[m].ayetNo ? ayetNoW(satir[m].i) : kelimeW(satir[m].i),
                    ],
                  ],
                ),
              ));
            }
        }
      }
      ic.add(Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(arapRakam(s.no), textAlign: TextAlign.center, style: arapYazi(fs * .5, color: soluk)),
      ));
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: kagit,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: cizgi, width: 1.6),
          boxShadow: _b ? [BoxShadow(color: Colors.black.withValues(alpha: .07), blurRadius: 10, offset: const Offset(0, 3))] : null,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: cizgi, width: .8),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: ic),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final s in sayfalar) sayfaW(s)]);
  }

  /// Sure başlığı: çift çizgili çerçeve içinde sure adı (Tarteel / basılı mushaf gibi).
  Widget _sureBasligi(int s, double fs) {
    Widget elmas() => Transform.rotate(
          angle: .785398,
          child: Container(width: 7, height: 7, decoration: BoxDecoration(color: vurgu.withValues(alpha: .8))),
        );
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 4),
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        border: Border.all(color: vurgu, width: 1.4),
        borderRadius: BorderRadius.circular(8),
        color: vurgu.withValues(alpha: .07),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(color: vurgu.withValues(alpha: .6), width: .7),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(children: [
          elmas(),
          Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('سُورَةُ ${Kuran.arapAd(s)}', textAlign: TextAlign.center, textDirection: TextDirection.rtl,
                  style: arapYazi(fs * .8, color: yazi).copyWith(height: 1.7)),
              Text(Kuran.ad(s).toUpperCase(), style: AppText.label(color: soluk, size: 9.5)),
            ]),
          ),
          elmas(),
        ]),
      ),
    );
  }

  /// Ayet sonu gülü: halka içinde ayet numarası.
  Widget _ayetGulu(int n, double fs, Color c, bool rakam) {
    final r = fs * 1.15;
    return SizedBox(
      width: r,
      height: r,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: c, width: 1.3),
        ),
        child: Container(
          margin: const EdgeInsets.all(2),
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.withValues(alpha: .5), width: .6)),
          child: Text(rakam ? arapRakam(n) : '',
              textScaler: TextScaler.noScaling,
              style: AppText.body(fs * (n > 99 ? .32 : .4), color: yazi, weight: FontWeight.w700, height: 1)),
        ),
      ),
    );
  }

  /// Tarteel tarzı hata işaretleri: yazı mürekkep renginde kalır, altı/arkası renkli vurgulanır.
  static Color? vurguRengi(int st) => switch (st) {
        KD.hata => const Color(0xFFE53935),
        KD.atla => const Color(0xFFF29900),
        KD.ipucu => const Color(0xFF1E88E5),
        _ => null,
      };

  Widget _kelime(int i, Kelime k, double fs, bool mushaf) {
    final gizli = k.st == KD.gizli && !hepsiAcik;
    final simdiki = i == cur;
    final isaret = mushaf && !gizli ? vurguRengi(k.st) : null;
    final renk = k.st == KD.gizli
        ? (hepsiAcik ? yazi.withValues(alpha: .55) : yazi)
        : (mushaf ? yazi : MushafGorunum.renk(k.st));
    final st = arapYazi(fs, color: renk);
    Widget metin;
    if (gizli && gizle == 'harf') {
      final m = RegExp('^.[ً-ٰٟٓ-ٕۡ]*').firstMatch(k.t);
      final ilk = m?.group(0) ?? '';
      metin = Text.rich(TextSpan(children: [
        TextSpan(text: ilk, style: st.copyWith(color: soluk)),
        TextSpan(text: k.t.substring(ilk.length), style: st.copyWith(color: Colors.transparent)),
        if (k.pm.isNotEmpty) TextSpan(text: ' ${k.pm}', style: st.copyWith(color: Colors.transparent, fontSize: fs * .7)),
      ]));
    } else if (gizli && gizle == 'silik') {
      metin = Text.rich(_kelimeSpan(k, st.copyWith(color: yazi.withValues(alpha: .13)), fs));
    } else if (gizli && gizle == 'iz') {
      // Kelime izi: yazının yerinde silik, yuvarlak bir iz (harflerin üstüne bir şey çizilmez).
      metin = Stack(children: [
        Text.rich(_kelimeSpan(k, st.copyWith(color: Colors.transparent), fs)),
        Positioned.fill(
          child: Center(
            child: Container(
              height: fs * .36,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: simdiki && !hepsiAcik ? vurgu.withValues(alpha: .30) : kutu,
                borderRadius: BorderRadius.circular(fs),
              ),
            ),
          ),
        ),
      ]);
    } else if (gizli) {
      metin = Text.rich(_kelimeSpan(k, st.copyWith(color: Colors.transparent), fs));
    } else if (isaret != null) {
      metin = Text.rich(TextSpan(children: [
        TextSpan(text: k.t, style: st),
        if (k.pm.isNotEmpty) TextSpan(text: ' ${k.pm}', style: st.copyWith(color: vurgu, fontSize: fs * .7)),
      ]));
    } else {
      metin = Text.rich(TextSpan(children: [
        TextSpan(
          text: k.t,
          style: st.copyWith(
            decoration: !mushaf && (k.st == KD.hata || k.st == KD.atla) ? TextDecoration.underline : null,
            decorationColor: renk,
            decorationStyle: k.st == KD.hata ? TextDecorationStyle.wavy : TextDecorationStyle.dotted,
          ),
        ),
        if (k.pm.isNotEmpty) TextSpan(text: ' ${k.pm}', style: st.copyWith(color: vurgu, fontSize: fs * .7)),
      ]));
    }
    final cerceve = simdiki && (bosCerceve || !(gizli && (gizle == 'bos' || gizle == 'iz')));
    return GestureDetector(
      onTap: onTap == null ? null : () => onTap!(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isaret != null
              ? isaret.withValues(alpha: .14)
              : (gizli && gizle == 'gizli' ? kutu.withValues(alpha: .9) : Colors.transparent),
          borderRadius: BorderRadius.circular(isaret != null ? 4 : 7),
          // Boş sayfada harflerin üstüne hiçbir şey çizilmez (sıradaki kelime çerçevesi de yok).
          border: cerceve
              ? Border.all(color: vurgu, width: 2)
              : (isaret != null ? Border(bottom: BorderSide(color: isaret, width: 2.2)) : null),
        ),
        child: metin,
      ),
    );
  }
}

/// Mushaf sayfası düzeni: bir sayfa ve içindeki parçalar.
class _Sayfa {
  _Sayfa(this.no, this.cuz, this.sure);
  final int no, cuz, sure;
  final parcalar = <_Parca>[];
}

/// tur 0: sure başlığı (deger = sure), 1: bölüm etiketi (deger = ayet dizini), 2: satırlar.
class _Parca {
  _Parca.sure(this.deger)
      : tur = 0,
        satirlar = const [];
  _Parca.etiket(this.deger)
      : tur = 1,
        satirlar = const [];
  _Parca.satirlar(this.satirlar)
      : tur = 2,
        deger = 0;
  final int tur, deger;
  final List<List<_Oge>> satirlar;
}

/// Satırdaki öğe: [i]. kelime ya da (ayetNo) o kelimeden sonraki ayet sonu gülü.
class _Oge {
  const _Oge(this.i, this.ayetNo);
  final int i;
  final bool ayetNo;
}

/// Renklerin anlamı.
class DurumAciklama extends StatelessWidget {
  const DurumAciklama({super.key});
  @override
  Widget build(BuildContext context) {
    Widget n(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 4),
          Text(t, style: AppText.body(11.5, color: MushafGorunum.soluk)),
        ]);
    return Wrap(spacing: 12, runSpacing: 4, children: [
      n(MushafGorunum.renk(KD.dogru), 'doğru'),
      n(MushafGorunum.renk(KD.hata), 'hatalı'),
      n(MushafGorunum.renk(KD.atla), 'atlandı'),
      n(MushafGorunum.renk(KD.ipucu), 'ipucu'),
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
        ButtonSegment(value: 'iz', label: Text('İz')),
        ButtonSegment(value: 'bos', label: Text('Boş')),
        ButtonSegment(value: 'gizli', label: Text('Kutulu')),
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

/// "Beyaz sayfa" anahtarı.
class BeyazSayfaAnahtari extends StatefulWidget {
  const BeyazSayfaAnahtari({super.key, this.onChanged});
  final VoidCallback? onChanged;
  @override
  State<BeyazSayfaAnahtari> createState() => _BeyazSayfaAnahtariState();
}

class _BeyazSayfaAnahtariState extends State<BeyazSayfaAnahtari> {
  @override
  Widget build(BuildContext context) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: HfAyar.beyaz,
        onChanged: (v) async {
          await HfAyar.setBeyaz(v);
          setState(() {});
          widget.onChanged?.call();
        },
        title: Text('Beyaz sayfa', style: AppText.body(15)),
        subtitle: Text('Okurken bembeyaz kâğıt; yazı okudukça belirir', style: AppText.body(12, color: AppColors.muted)),
      );
}

/// Okuma sayfasının zemini: beyaz kâğıt ya da temanın desenli zemini.
class OkumaZemini extends StatelessWidget {
  const OkumaZemini({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      HfAyar.beyaz ? ColoredBox(color: Colors.white, child: child) : PatternBackground(child: child);
}

/// "Mushaf sayfası" anahtarı (Tarteel tarzı sayfa görünümü).
class MushafSayfaAnahtari extends StatefulWidget {
  const MushafSayfaAnahtari({super.key, this.onChanged});
  final VoidCallback? onChanged;
  @override
  State<MushafSayfaAnahtari> createState() => _MushafSayfaAnahtariState();
}

class _MushafSayfaAnahtariState extends State<MushafSayfaAnahtari> {
  @override
  Widget build(BuildContext context) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: HfAyar.mushaf,
        onChanged: (v) async {
          await HfAyar.setMushaf(v);
          setState(() {});
          widget.onChanged?.call();
        },
        title: Text('Mushaf sayfası', style: AppText.body(15)),
        subtitle: Text('Basılı mushaf gibi sayfa sayfa, çerçeveli, iki yana yaslı satırlar',
            style: AppText.body(12, color: AppColors.muted)),
      );
}
