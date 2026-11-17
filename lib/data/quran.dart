import 'dart:convert';

import 'package:flutter/services.dart';

/// Bir ayet: sure, ayet no, cüz, mushaf sayfası (Medine mushafı) ve metin.
class Ayah {
  const Ayah(this.surah, this.number, this.juz, this.page, this.text);
  final int surah, number, juz, page;
  final String text;
}

/// Kur'ân-ı Kerîm metni (Tanzil Osmanlı hattı, uygulamanın içinde; internet gerekmez).
class Quran {
  Quran._();

  static List<Ayah>? _ayahs;
  static List<String>? _surahNames;

  /// Başlıkta gösterilen besmele: kaynak metnin kendisinden alınır (Bakara 1. ayetin başı).
  static String _basmala = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';

  /// Harekesiz yazım (karşılaştırma için): hareke ve işaretler atılır, ٱ → ا.
  static String _bare(String w) =>
      w.replaceAll(RegExp('[\u064B-\u065F\u0670\u06D6-\u06ED]'), '').replaceAll('\u0671', '\u0627');

  static const _basmalaBare = ['بسم', 'الله', 'الرحمن', 'الرحيم'];

  /// Ayet besmeleyle başlıyorsa (ilk dört kelime) besmele kısmını ve kalanını ayırır.
  static (String, String)? _splitBasmala(String t) {
    final w = t.split(' ');
    if (w.length < 4) return null;
    for (var i = 0; i < 4; i++) {
      if (_bare(w[i]) != _basmalaBare[i]) return null;
    }
    return (w.take(4).join(' '), w.skip(4).join(' '));
  }

  static Future<void> _load() async {
    if (_ayahs != null) return;
    final raw = await rootBundle.loadString('assets/quran/quran.json');
    final d = jsonDecode(raw) as Map<String, dynamic>;
    _surahNames = [for (final s in d['surahs'] as List) (s as List)[1] as String];
    String? header;
    _ayahs = [
      for (final a in d['ayahs'] as List)
        () {
          final l = a as List;
          var t = (l[4] as String).replaceAll('\uFEFF', '');
          final s = l[0] as int, n = l[1] as int;
          // Surelerin başındaki besmele mushafta olduğu gibi ayrı başlık olarak gösterilir;
          // metnin kendisine dokunulmaz, yalnızca ayetten ayrılır (Fâtiha'da besmele 1. ayettir).
          if (n == 1 && s != 1 && s != 9) {
            final sp = _splitBasmala(t);
            if (sp != null) {
              header ??= sp.$1;
              t = sp.$2;
            }
          }
          return Ayah(s, n, l[2] as int, l[3] as int, t);
        }()
    ];
    if (header != null) _basmala = header!;
  }

  static String surahName(int s) => _surahNames![s - 1];

  /// Cüzün ayetleri, mushaf sayfalarına göre gruplanmış.
  static Future<List<List<Ayah>>> juzPages(int juz) async {
    await _load();
    final pages = <List<Ayah>>[];
    for (final a in _ayahs!.where((a) => a.juz == juz)) {
      if (pages.isEmpty || pages.last.first.page != a.page) pages.add([]);
      pages.last.add(a);
    }
    return pages;
  }

  static String get basmala => _basmala;

  /// Bir surenin bütün ayetleri.
  static Future<List<Ayah>> surahAyahs(int surah) async {
    await _load();
    return _ayahs!.where((a) => a.surah == surah).toList();
  }

  /// Bir cüzün bütün ayetleri.
  static Future<List<Ayah>> juzAyahs(int juz) async {
    await _load();
    return _ayahs!.where((a) => a.juz == juz).toList();
  }

  /// Ayetleri mushaf sayfalarına göre gruplar.
  static List<List<Ayah>> toPages(List<Ayah> ayahs) {
    final pages = <List<Ayah>>[];
    for (final a in ayahs) {
      if (pages.isEmpty || pages.last.first.page != a.page) pages.add([]);
      pages.last.add(a);
    }
    return pages;
  }

  static List<List<Ayah>>? _allPages;

  /// Mushafın bütün sayfaları (604).
  static Future<List<List<Ayah>>> allPages() async {
    await _load();
    return _allPages ??= toPages(_ayahs!);
  }

  /// Surenin başladığı sayfanın sıra numarası (0'dan).
  static Future<int> surahStartIndex(int surah) async {
    final pages = await allPages();
    return pages.indexWhere((p) => p.any((a) => a.surah == surah && a.number == 1)).clamp(0, pages.length - 1);
  }

  /// Cüzün başladığı sayfanın sıra numarası (0'dan).
  static Future<int> juzStartIndex(int juz) async {
    final pages = await allPages();
    return pages.indexWhere((p) => p.any((a) => a.juz == juz)).clamp(0, pages.length - 1);
  }

  static Future<int> ayahCount(int surah) async {
    await _load();
    return _ayahs!.where((a) => a.surah == surah).length;
  }

  /// Surelerin Türkçe adları (Diyanet yazımı).
  static const surahNamesTr = [
    'Fâtiha', 'Bakara', 'Âl-i İmrân', 'Nisâ', 'Mâide', 'En\'âm', 'A\'râf', 'Enfâl', 'Tevbe', 'Yûnus',
    'Hûd', 'Yûsuf', 'Ra\'d', 'İbrâhîm', 'Hicr', 'Nahl', 'İsrâ', 'Kehf', 'Meryem', 'Tâhâ',
    'Enbiyâ', 'Hac', 'Mü\'minûn', 'Nûr', 'Furkān', 'Şuarâ', 'Neml', 'Kasas', 'Ankebût', 'Rûm',
    'Lokmân', 'Secde', 'Ahzâb', 'Sebe\'', 'Fâtır', 'Yâsîn', 'Sâffât', 'Sâd', 'Zümer', 'Mü\'min',
    'Fussilet', 'Şûrâ', 'Zuhruf', 'Duhân', 'Câsiye', 'Ahkāf', 'Muhammed', 'Fetih', 'Hucurât', 'Kāf',
    'Zâriyât', 'Tûr', 'Necm', 'Kamer', 'Rahmân', 'Vâkıa', 'Hadîd', 'Mücâdele', 'Haşr', 'Mümtehine',
    'Saf', 'Cuma', 'Münâfikūn', 'Teğābün', 'Talâk', 'Tahrîm', 'Mülk', 'Kalem', 'Hâkka', 'Meâric',
    'Nûh', 'Cin', 'Müzzemmil', 'Müddessir', 'Kıyâme', 'İnsan', 'Mürselât', 'Nebe\'', 'Nâziât', 'Abese',
    'Tekvîr', 'İnfitâr', 'Mutaffifîn', 'İnşikāk', 'Bürûc', 'Târık', 'A\'lâ', 'Gāşiye', 'Fecr', 'Beled',
    'Şems', 'Leyl', 'Duhâ', 'İnşirâh', 'Tîn', 'Alak', 'Kadr', 'Beyyine', 'Zilzâl', 'Âdiyât',
    'Kāria', 'Tekâsür', 'Asr', 'Hümeze', 'Fîl', 'Kureyş', 'Mâûn', 'Kevser', 'Kâfirûn', 'Nasr',
    'Tebbet', 'İhlâs', 'Felak', 'Nâs',
  ];

  /// Bir sure içindeki ayet aralığının metni (ayet sonu işaretleriyle).
  static Future<String> ayahRange(int surah, int from, int to) async {
    await _load();
    return _ayahs!
        .where((a) => a.surah == surah && a.number >= from && a.number <= to)
        .map((a) => '${a.text} \u06DD${arabicDigits(a.number)}')
        .join(' ');
  }

  static String arabicDigits(int n) {
    const d = '٠١٢٣٤٥٦٧٨٩';
    return n.toString().split('').map((c) => d[int.parse(c)]).join();
  }
}
