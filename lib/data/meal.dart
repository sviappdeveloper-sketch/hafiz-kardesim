import 'dart:convert';

import 'package:flutter/services.dart';

/// Kur'ân-ı Kerîm meali. Metin uygulamanın içinde, kaynağından harfiyen (noktalama dahil)
/// alınmış olarak durur: assets/quran/meal_diyanet.json
/// Biçim: {"name": "...", "source": "...", "ayahs": [[sure, ayet, "metin"], ...]}
class Meal {
  Meal._();

  static Map<int, String>? _texts;
  static String name = 'Diyanet İşleri Meali';
  static String source = '';
  static bool _tried = false;

  static int _key(int surah, int ayah) => surah * 1000 + ayah;

  /// Meal metni uygulamada var mı? (yoksa false)
  static Future<bool> available() async {
    await _load();
    return _texts != null && _texts!.isNotEmpty;
  }

  static Future<void> _load() async {
    if (_tried) return;
    _tried = true;
    try {
      final raw = await rootBundle.loadString('assets/quran/meal_diyanet.json');
      final d = jsonDecode(raw) as Map<String, dynamic>;
      name = (d['name'] ?? name) as String;
      source = (d['source'] ?? '') as String;
      _texts = {
        for (final a in d['ayahs'] as List) _key((a as List)[0] as int, a[1] as int): a[2] as String,
      };
    } catch (_) {
      _texts = null;
    }
  }

  static Future<String?> of(int surah, int ayah) async {
    await _load();
    return _texts?[_key(surah, ayah)];
  }

  static String? ofSync(int surah, int ayah) => _texts?[_key(surah, ayah)];

  /// Kaynakta birlikte çevrilen ayetler: ortak meal, gruptaki her ayette aynen tekrar eder
  /// (ör. Nâs 1-6). Ayetin ait olduğu grubun (ilk, son) ayet numarası; grup yoksa (ayet, ayet).
  /// Yalnızca aynı suredeki ardışık ayetlere bakılır.
  static (int, int) groupOf(int surah, int ayah) {
    final texts = _texts;
    final t = texts?[_key(surah, ayah)];
    if (texts == null || t == null) return (ayah, ayah);
    var from = ayah, to = ayah;
    while (from > 1 && texts[_key(surah, from - 1)] == t) {
      from--;
    }
    while (texts[_key(surah, to + 1)] == t) {
      to++;
    }
    return (from, to);
  }

  /// Ayet aralığının meali, ayetler arasında boşlukla (metne dokunulmaz). Meal yoksa null.
  /// Birlikte çevrilen ayetlerin ortak meali bir kez yazılır.
  static Future<String?> range(int surah, int from, int to) async {
    await _load();
    if (_texts == null) return null;
    final parts = <String>[];
    for (var a = from; a <= to; a++) {
      final t = _texts![_key(surah, a)];
      if (t == null) return null;
      if (parts.isEmpty || parts.last != t) parts.add(t);
    }
    return parts.join(' ');
  }
}
