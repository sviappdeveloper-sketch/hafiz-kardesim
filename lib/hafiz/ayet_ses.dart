import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Dinle & Tekrarla'nın ayet ayet sesleri: telefona indirilir, sonra internetsiz çalar.
/// Dosyalar: Belgeler/hafiz_ses/<kâri>/SSSAAA.mp3 (everyayah.com kaynaklı).
class AyetSes {
  AyetSes._();

  static String _nnn(int n) => n.toString().padLeft(3, '0');
  static String url(String kari, int sure, int ayet) => 'https://everyayah.com/data/$kari/${_nnn(sure)}${_nnn(ayet)}.mp3';

  static Future<Directory> _dir(String kari) async {
    final docs = await getApplicationDocumentsDirectory();
    final d = Directory('${docs.path}/hafiz_ses/$kari');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static Future<File> dosya(String kari, int sure, int ayet) async =>
      File('${(await _dir(kari)).path}/${_nnn(sure)}${_nnn(ayet)}.mp3');

  static Future<bool> varMi(String kari, int sure, int ayet) async => (await dosya(kari, sure, ayet)).exists();

  /// Ayetin dosyasını döner; telefonda yoksa önce indirir.
  static Future<File> getir(String kari, int sure, int ayet) async {
    final f = await dosya(kari, sure, ayet);
    if (await f.exists() && await f.length() > 0) return f;
    final part = File('${f.path}.part');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.getUrl(Uri.parse(url(kari, sure, ayet)));
      final res = await req.close();
      if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}');
      final sink = part.openWrite();
      var got = 0;
      try {
        await for (final c in res) {
          sink.add(c);
          got += c.length;
        }
      } finally {
        await sink.close();
      }
      if (got == 0 || (res.contentLength > 0 && got < res.contentLength)) throw const HttpException('Eksik indirildi');
      await part.rename(f.path);
      return f;
    } finally {
      client.close(force: true);
      if (await part.exists()) await part.delete();
    }
  }

  /// Listedeki ayetleri (sure, ayet) sırayla indirir. [ilerleme]: inen sayı. İndirilemeyen sayısını döner.
  static Future<int> indir(String kari, List<(int, int)> ayetler, void Function(int bitti) ilerleme,
      {bool Function()? iptal}) async {
    var hata = 0, bitti = 0;
    for (final a in ayetler) {
      if (iptal?.call() == true) break;
      try {
        await getir(kari, a.$1, a.$2);
      } catch (_) {
        hata++;
      }
      ilerleme(++bitti);
    }
    return hata;
  }

  static Future<int> eksikSayisi(String kari, List<(int, int)> ayetler) async {
    var n = 0;
    for (final a in ayetler) {
      if (!await varMi(kari, a.$1, a.$2)) n++;
    }
    return n;
  }

  /// Bir kârinin telefondaki seslerinin kapladığı yer (bayt).
  static Future<int> boyut(String kari) async {
    final d = await _dir(kari);
    var t = 0;
    await for (final e in d.list()) {
      if (e is File) t += await e.length();
    }
    return t;
  }

  static Future<void> sil(String kari) async {
    final d = await _dir(kari);
    if (await d.exists()) await d.delete(recursive: true);
  }
}
