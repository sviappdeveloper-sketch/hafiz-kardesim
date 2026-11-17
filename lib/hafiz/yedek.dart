import 'dart:convert';
import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../services/settings_service.dart';
import 'kayit.dart';

/// Ders geçmişinin kullanıcının KENDİ Google Drive'ına yedeklenmesi.
/// Dosya Drive'ın uygulamaya özel gizli klasöründe (appDataFolder) durur; uygulamanın
/// sunucusuna hiçbir şey gönderilmez. Aynı Google hesabıyla girince geri yüklenebilir.
/// iPhone'da geçmiş dosyası telefonun iCloud yedeğine kendiliğinden dahildir.
class DriveYedek {
  DriveYedek._();
  static const _kapsam = 'https://www.googleapis.com/auth/drive.appdata';
  static final _g = GoogleSignIn(scopes: const [_kapsam]);
  static const _ad = 'hafiz-kardesim-yedek.json';

  static bool get destek => Platform.isAndroid;
  static bool get otomatik => SettingsService.prefs.getBool('hfDriveOto') ?? false;
  static Future<void> setOtomatik(bool v) => SettingsService.prefs.setBool('hfDriveOto', v);
  static String? get hesap => SettingsService.prefs.getString('hfDriveHesap');
  static int get sonYedek => SettingsService.prefs.getInt('hfDriveSon') ?? 0;

  static Future<Map<String, String>?> _baslik({bool sessiz = false}) async {
    GoogleSignInAccount? a = _g.currentUser ?? await _g.signInSilently();
    if (a == null && !sessiz) a = await _g.signIn();
    if (a == null) return null;
    await SettingsService.prefs.setString('hfDriveHesap', a.email);
    return a.authHeaders;
  }

  static Future<String?> _dosyaId(Map<String, String> h) async {
    final u = Uri.parse("https://www.googleapis.com/drive/v3/files?spaces=appDataFolder&q=name%3D'$_ad'&fields=files(id,modifiedTime)");
    final r = await http.get(u, headers: h);
    if (r.statusCode != 200) throw Exception('Drive (${r.statusCode})');
    final f = (jsonDecode(r.body)['files'] as List);
    return f.isEmpty ? null : f.first['id'] as String;
  }

  /// Yedekle. Sessiz modda hesap seçtirmez (otomatik yedek için).
  static Future<bool> yedekle({bool sessiz = false}) async {
    if (!destek) return false;
    final h = await _baslik(sessiz: sessiz);
    if (h == null) return false;
    final veri = utf8.encode(jsonEncode(Kayit.i.json()));
    final id = await _dosyaId(h);
    http.Response r;
    if (id == null) {
      const sinir = 'hafizkardesimsinir';
      final govde = <int>[
        ...utf8.encode('--$sinir\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n'),
        ...utf8.encode(jsonEncode({'name': _ad, 'parents': ['appDataFolder']})),
        ...utf8.encode('\r\n--$sinir\r\nContent-Type: application/json\r\n\r\n'),
        ...veri,
        ...utf8.encode('\r\n--$sinir--'),
      ];
      r = await http.post(Uri.parse('https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart'),
          headers: {...h, 'Content-Type': 'multipart/related; boundary=$sinir'}, body: govde);
    } else {
      r = await http.patch(Uri.parse('https://www.googleapis.com/upload/drive/v3/files/$id?uploadType=media'),
          headers: {...h, 'Content-Type': 'application/json'}, body: veri);
    }
    if (r.statusCode >= 300) throw Exception('Drive yükleme hatası (${r.statusCode})');
    await SettingsService.prefs.setInt('hfDriveSon', DateTime.now().millisecondsSinceEpoch);
    return true;
  }

  /// Drive'daki yedeği okur (yoksa null).
  static Future<Map<String, dynamic>?> oku({bool sessiz = false}) async {
    if (!destek) return null;
    final h = await _baslik(sessiz: sessiz);
    if (h == null) return null;
    final id = await _dosyaId(h);
    if (id == null) return null;
    final r = await http.get(Uri.parse('https://www.googleapis.com/drive/v3/files/$id?alt=media'), headers: h);
    if (r.statusCode != 200) throw Exception('Drive okuma hatası (${r.statusCode})');
    return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
  }

  /// Oturum sonrası otomatik yedek (açıksa, sessizce).
  static Future<void> otomatikYedekle() async {
    if (!destek || !otomatik) return;
    try {
      await yedekle(sessiz: true);
    } catch (_) {}
  }
}
