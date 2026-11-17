import 'dart:convert';

import 'package:flutter/services.dart';

/// Bir ayet: sure, ayet no, cüz, Medine mushafı sayfası ve (sure başı besmelesi ayrılmış) metin.
class Ayet {
  const Ayet(this.s, this.n, this.cuz, this.sayfa, this.metin);
  final int s, n, cuz, sayfa;
  final String metin;
}

/// Kur'an metni (Tanzil, Osmanlı hattı) — uygulamanın içinde, internet gerekmez.
class Kuran {
  Kuran._();
  static List<Ayet> a = const [];
  static List<String> _arap = const [];
  static final List<int> _say = List.filled(115, 0);
  static final List<int> _bas = List.filled(116, 0);
  static List<String>? _meal;
  static bool get hazir => a.isNotEmpty;
  static const besmele = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';

  static Future<void> yukle() async {
    if (hazir) return;
    final d = jsonDecode(await rootBundle.loadString('assets/quran/quran.json')) as Map<String, dynamic>;
    _arap = [for (final s in d['surahs'] as List) ((s as List)[1] as String).replaceFirst(RegExp(r'^سُورَةُ\s*'), '')];
    final bare = RegExp('[ً-ٰٟۖ-ۭ]');
    String b(String w) => w.replaceAll(bare, '').replaceAll('ٱ', 'ا');
    const bsm = ['بسم', 'الله', 'الرحمن', 'الرحيم'];
    final list = <Ayet>[];
    for (final x in d['ayahs'] as List) {
      final l = x as List;
      final s = l[0] as int, n = l[1] as int;
      var t = (l[4] as String).replaceAll('﻿', '');
      if (n == 1 && s != 1 && s != 9) {
        final w = t.split(' ');
        if (w.length > 4 && [for (var i = 0; i < 4; i++) b(w[i])].join(' ') == bsm.join(' ')) t = w.skip(4).join(' ');
      }
      list.add(Ayet(s, n, l[2] as int, l[3] as int, t));
      _say[s] = n;
    }
    for (var s = 1; s <= 114; s++) {
      _bas[s + 1] = _bas[s] + _say[s];
    }
    a = list;
  }

  static int ayetSayisi(int s) => _say[s];
  static int ix(int s, int n) => _bas[s] + n - 1;
  static String arapAd(int s) => _arap[s - 1];
  static String ad(int s) => sureAdlari[s - 1];
  static String etiket(int ai) => '${ad(a[ai].s)} ${a[ai].n}';

  static List<int> aralik(int i, int j) => [for (var k = i; k <= j; k++) k];
  static List<int> cuz(int c) => [for (var i = 0; i < a.length; i++) if (a[i].cuz == c) i];
  static List<int> sayfalar(int p1, int p2) => [for (var i = 0; i < a.length; i++) if (a[i].sayfa >= p1 && a[i].sayfa <= p2) i];

  static Future<List<String>> meal() async {
    if (_meal != null) return _meal!;
    final d = jsonDecode(await rootBundle.loadString('assets/quran/meal_diyanet.json')) as Map<String, dynamic>;
    _meal = [for (final x in d['ayahs'] as List) (x as List)[2] as String];
    return _meal!;
  }

  /// "Bakara 1–5", "Bakara 285 – Âl-i İmrân 3" ya da parça parça liste.
  static String etiketListe(List<int> l) {
    if (l.isEmpty) return '';
    final f = a[l.first], s = a[l.last];
    final bitisik = l.length == l.last - l.first + 1;
    if (!bitisik) {
      final p = parcalar(l);
      final ilk = p.take(3).map((c) => '${ad(a[c.$1].s)} ${a[c.$1].n}${c.$2 > c.$1 ? '–${a[c.$2].n}' : ''}').join(', ');
      return p.length > 3 ? '$ilk …' : ilk;
    }
    if (f.s == s.s) return '${ad(f.s)} ${f.n == s.n ? f.n : '${f.n}–${s.n}'}';
    return '${ad(f.s)} ${f.n} – ${ad(s.s)} ${s.n}';
  }

  /// Ardışık sayıları (başlangıç, bitiş) çiftlerine ayırır (sure sınırına bakmaz).
  static List<(int, int)> parcalarHam(List<int> l) {
    final out = <(int, int)>[];
    for (final i in l) {
      if (out.isNotEmpty && i == out.last.$2 + 1) {
        out[out.length - 1] = (out.last.$1, i);
      } else {
        out.add((i, i));
      }
    }
    return out;
  }

  /// Birbirini izleyen ayetleri (başlangıç, bitiş) parçalarına ayırır.
  static List<(int, int)> parcalar(List<int> l) {
    final out = <(int, int)>[];
    for (final i in l) {
      if (out.isNotEmpty && i == out.last.$2 + 1 && a[i].s == a[out.last.$1].s) {
        out[out.length - 1] = (out.last.$1, i);
      } else {
        out.add((i, i));
      }
    }
    return out;
  }
}

const sureAdlari = [
  'Fâtiha', 'Bakara', 'Âl-i İmrân', 'Nisâ', 'Mâide', "En'âm", "A'râf", 'Enfâl', 'Tevbe', 'Yûnus', 'Hûd', 'Yûsuf',
  "Ra'd", 'İbrâhîm', 'Hicr', 'Nahl', 'İsrâ', 'Kehf', 'Meryem', 'Tâhâ', 'Enbiyâ', 'Hac', "Mü'minûn", 'Nûr', 'Furkân',
  'Şuarâ', 'Neml', 'Kasas', 'Ankebût', 'Rûm', 'Lokmân', 'Secde', 'Ahzâb', "Sebe'", 'Fâtır', 'Yâsîn', 'Sâffât', 'Sâd',
  'Zümer', "Mü'min", 'Fussilet', 'Şûrâ', 'Zuhruf', 'Duhân', 'Câsiye', 'Ahkâf', 'Muhammed', 'Fetih', 'Hucurât', 'Kâf',
  'Zâriyât', 'Tûr', 'Necm', 'Kamer', 'Rahmân', 'Vâkıa', 'Hadîd', 'Mücâdele', 'Haşr', 'Mümtehine', 'Saf', 'Cuma',
  'Münâfikûn', 'Teğâbün', 'Talâk', 'Tahrîm', 'Mülk', 'Kalem', 'Hâkka', 'Meâric', 'Nûh', 'Cin', 'Müzzemmil',
  'Müddessir', 'Kıyâme', 'İnsân', 'Mürselât', "Nebe'", 'Nâziât', 'Abese', 'Tekvîr', 'İnfitâr', 'Mutaffifîn',
  'İnşikâk', 'Bürûc', 'Târık', "A'lâ", 'Gâşiye', 'Fecr', 'Beled', 'Şems', 'Leyl', 'Duhâ', 'İnşirâh', 'Tîn', 'Alak',
  'Kadir', 'Beyyine', 'Zilzâl', 'Âdiyât', 'Kâria', 'Tekâsür', 'Asr', 'Hümeze', 'Fîl', 'Kureyş', 'Mâûn', 'Kevser',
  'Kâfirûn', 'Nasr', 'Tebbet', 'İhlâs', 'Felak', 'Nâs',
];

/// Türkçe arama için sadeleştirme: "Yâsîn" → "yasin".
String trSade(String t) => t
    .replaceAll('İ', 'i')
    .replaceAll('I', 'ı')
    .toLowerCase()
    .replaceAll(RegExp('[âä]'), 'a')
    .replaceAll(RegExp('[îı]'), 'i')
    .replaceAll(RegExp('[ûü]'), 'u')
    .replaceAll('ö', 'o')
    .replaceAll('ç', 'c')
    .replaceAll('ş', 's')
    .replaceAll('ğ', 'g')
    .replaceAll(RegExp('[^a-z0-9]'), '');
