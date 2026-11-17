import 'dart:convert';
import 'dart:io';

import '../data/cities.dart';
import 'settings_service.dart';
import '../l10n/l10n.dart';

/// Bir günün namaz vakitleri.
class PrayerDay {
  PrayerDay(this.date, this.times);
  final DateTime date;

  /// İmsak, Güneş, Öğle, İkindi, Akşam, Yatsı sırasıyla.
  final List<DateTime> times;

  static List<String> get names => [lt('İmsak'), lt('Güneş'), lt('Öğle'), lt('İkindi'), lt('Akşam'), lt('Yatsı')];
}

/// İllere göre ezan vakitleri. Kaynak: AlAdhan API, Diyanet İşleri Başkanlığı hesap yöntemi (method=13).
/// Ay ay indirilir ve cihazda saklanır; internet yokken saklanan vakitler kullanılır.
class PrayerService {
  PrayerService._();

  static const _keys = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

  static String _cacheKey(String city, int y, int m) => 'pt_${city}_${y}_$m';

  /// [city] ilinin [y]/[m] ayı vakitleri (önce cihazdan, yoksa internetten).
  static Future<List<PrayerDay>> month(String city, int y, int m) async {
    final prefs = SettingsService.prefs;
    final key = _cacheKey(city, y, m);
    var raw = prefs.getString(key);
    if (raw == null) {
      raw = await _download(city, y, m);
      await prefs.setString(key, raw);
      // Eski ayları temizle.
      for (final k in prefs.getKeys().where((k) => k.startsWith('pt_') && k != key).toList()) {
        final parts = k.split('_');
        final ky = int.tryParse(parts[parts.length - 2]) ?? 0, km = int.tryParse(parts.last) ?? 0;
        if (ky * 12 + km < y * 12 + m) await prefs.remove(k);
      }
    }
    return _parse(raw);
  }

  static Future<String> _download(String city, int y, int m) async {
    final c = turkishCities[city]!;
    final uri = Uri.https('api.aladhan.com', '/v1/calendar/$y/$m', {
      'latitude': '${c.$1}',
      'longitude': '${c.$2}',
      'method': '13',
      'timezonestring': 'Europe/Istanbul',
    });
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final req = await client.getUrl(uri);
      final res = await req.close().timeout(const Duration(seconds: 20));
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) throw HttpException('Vakitler alınamadı (${res.statusCode})');
      final data = (jsonDecode(body) as Map<String, dynamic>)['data'] as List;
      // Yalnızca gereken kısmı sakla.
      final slim = [
        for (final d in data)
          {
            'd': d['date']['gregorian']['date'],
            't': [for (final k in _keys) (d['timings'][k] as String).substring(0, 5)],
          }
      ];
      return jsonEncode(slim);
    } finally {
      client.close(force: true);
    }
  }

  static List<PrayerDay> _parse(String raw) {
    final list = jsonDecode(raw) as List;
    return [
      for (final d in list)
        () {
          final p = (d['d'] as String).split('-'); // gg-aa-yyyy
          final day = DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
          return PrayerDay(day, [
            for (final t in (d['t'] as List).cast<String>())
              DateTime(day.year, day.month, day.day, int.parse(t.substring(0, 2)), int.parse(t.substring(3, 5))),
          ]);
        }()
    ];
  }

  /// Bugünden başlayarak [days] günlük vakitler (ay geçişlerini de kapsar).
  static Future<List<PrayerDay>> upcoming(String city, {int days = 2}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = today.add(Duration(days: days));
    final result = <PrayerDay>[];
    var y = today.year, m = today.month;
    while (true) {
      final list = await month(city, y, m);
      result.addAll(list.where((d) => !d.date.isBefore(today) && d.date.isBefore(end)));
      final next = DateTime(y, m + 1);
      if (!next.isBefore(end)) break;
      y = next.year;
      m = next.month;
    }
    return result;
  }
}
