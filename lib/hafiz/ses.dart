import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../services/settings_service.dart';
import 'arapca.dart';

/// Arapça ses tanıma. Kâri nefes alınca tanıma durur; mikrofon açık kaldıkça kendiliğinden yeniden başlar.
/// Duyulan kelimeler [kelime] ile tek tek gönderilir (kısmi sonuçta son kelime kesinleşene kadar beklenir).
class Ses {
  Ses._();
  static final stt.SpeechToText _s = stt.SpeechToText();
  static bool _hazir = false;
  static bool _istek = false;
  /// Bu tanıma parçasında eşleştiriciye gönderilmiş kelimeler (sırasıyla).
  /// Ses tanıma kısmi sonuçlarda önceki kelimeleri sık sık düzeltir, birleştirir ya da böler;
  /// yeni kelimeler sıra numarasına göre değil, gönderilenlerle içerik olarak hizalanarak bulunur.
  /// (Eski yöntemde kelime sayısı değişince yeni kelimeler kayboluyor, yazı geride kalıyordu.)
  static List<String> _giden = const [];
  /// Son kısmi sonucun kelimeleri: tanıma kesin sonuç vermeden durursa son kelime kaybolmasın.
  static List<String> _sonTk = const [];
  static void Function(String kelime)? _kelime;
  static bool Function(String kelime)? _dene;
  static void Function(String metin)? _canli;
  static void Function(String hata)? _hata;
  static final acik = ValueNotifier<bool>(false);
  /// Mikrofona gelen sesin şiddeti (0–1): dinleme dalgası bununla oynar.
  static final seviye = ValueNotifier<double>(0);

  /// Android'in ses tanıması her yeniden açılışta "bip" çalar; dinleme süresince medya sesi kısılır.
  static const _kanal = MethodChannel('hafiz/ses');
  static Timer? _acT;
  static Future<void> _bip(bool sustur) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _kanal.invokeMethod(sustur ? 'sustur' : 'ac');
    } catch (_) {}
  }

  static void _seviye(double l) {
    // Android'de yaklaşık -2…10 arası gelir.
    final v = ((l + 2) / 12).clamp(0.0, 1.0);
    seviye.value = seviye.value * .5 + v * .5;
  }

  static String get dil => SettingsService.prefs.getString('hfDil') ?? 'ar_SA';
  static Future<void> setDil(String v) => SettingsService.prefs.setString('hfDil', v);

  static Future<bool> hazirla() async {
    if (_hazir) return true;
    try {
      _hazir = await _s.initialize(onStatus: _durum, onError: _onHata, debugLogging: false);
    } catch (_) {
      _hazir = false;
    }
    return _hazir;
  }

  /// Dinlemeyi başlatır. [kelime]: kesinleşen her kelime, [canli]: ekranda gösterilecek anlık metin.
  static Future<bool> baslat({
    required void Function(String kelime) kelime,
    bool Function(String kelime)? dene,
    void Function(String metin)? canli,
    void Function(String hata)? hata,
  }) async {
    _kelime = kelime;
    _dene = dene;
    _canli = canli;
    _hata = hata;
    if (!await hazirla()) {
      hata?.call('yok');
      return false;
    }
    _istek = true;
    _sonucsuz = 0;
    _buOturumdaSonuc = true;
    acik.value = true;
    await _dinle();
    return true;
  }

  /// Telefonun kendi (çevrimdışı) tanıması: internete gidip gelmediği için çok daha hızlıdır.
  /// Telefonda Arapça çevrimdışı paket yoksa kendiliğinden internetli tanımaya geçilir.
  static bool _cihazda = true;
  static bool get cihazda => _cihazda && (SettingsService.prefs.getBool('hfCihazda') ?? true);
  static int _sonucsuz = 0;
  static bool _buOturumdaSonuc = false;

  static void _cihazdaKapat() {
    if (!_cihazda) return;
    _cihazda = false;
    debugPrint('Ses: cihaz içi tanıma kullanılamıyor, internetli tanımaya geçildi');
  }

  static Future<void> _dinle() async {
    if (!_istek) return;
    _giden = const [];
    _sonTk = const [];
    if (cihazda && !_buOturumdaSonuc) {
      // Cihaz içi tanıma art arda sonuç vermiyorsa (paket yok) internetli tanımaya geç.
      if (++_sonucsuz >= 3) _cihazdaKapat();
    } else {
      _sonucsuz = 0;
    }
    _buOturumdaSonuc = false;
    _acT?.cancel();
    await _bip(true);
    try {
      await _s.listen(
        onResult: _sonuc,
        onSoundLevelChange: _seviye,
        localeId: dil,
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 6),
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: stt.ListenMode.dictation,
          onDevice: cihazda,
        ),
      );
    } catch (_) {
      _yeniden(600);
    }
  }

  static Timer? _t;
  static void _yeniden(int ms) {
    if (!_istek) return;
    _t?.cancel();
    _t = Timer(Duration(milliseconds: ms), () {
      if (_istek && !_s.isListening) _dinle();
    });
  }

  /// Kısmi sonuçta bekletilen (henüz gönderilmemiş) kelimeleri gönderir.
  static void _bosalt() {
    final tk = _sonTk;
    _sonTk = const [];
    _gonder(tk, tk.length);
  }

  /// [tk] içinde daha önce gönderilmiş kısmın bittiği yer. Kelimeler birleşip bölünebildiği için
  /// son gönderilen kelimelerin bitişik yazımı, adayın sonundaki bitişik yazımla karşılaştırılır.
  static int hizala(List<String> giden, List<String> tk) {
    final c = giden.length;
    if (c == 0) return 0;
    var g = '';
    for (var m = c - 1; m >= 0 && m >= c - 3; m--) {
      g = nrm(giden[m]) + g;
    }
    var enIyi = math.min(c, tk.length), enPuan = -1.0;
    for (var j = math.max(0, c - 4); j <= math.min(tk.length, c + 3); j++) {
      var t = '';
      for (var m = j - 1; m >= 0 && t.length < g.length; m--) {
        t = nrm(tk[m]) + t;
      }
      final p = rat(g, t) + (j == c ? .05 : 0);
      if (p > enPuan) {
        enPuan = p;
        enIyi = j;
      }
    }
    return enIyi;
  }

  /// [tk]'nın ilk [kadar] kelimesinden henüz gönderilmemiş olanları gönderir.
  static void _gonder(List<String> tk, int kadar) {
    final s = hizala(_giden, tk);
    for (var i = s; i < kadar; i++) {
      _kelime?.call(tk[i]);
    }
    if (kadar > s) {
      _giden = tk.sublist(0, kadar);
    } else if (s <= tk.length) {
      _giden = tk.sublist(0, s);
    }
  }

  static void _durum(String d) {
    if (d == 'done' || d == 'notListening') {
      _bosalt();
      // Tanıma nefeste kapanır: hemen yeniden aç ki sonraki kelimeler kaçmasın.
      if (_istek) _yeniden(80);
    }
  }

  static void _onHata(SpeechRecognitionError e) {
    final m = e.errorMsg;
    _bosalt();
    if (cihazda && (m.contains('language') || m.contains('not_supported') || m.contains('unavailable') || m.contains('server'))) {
      _cihazdaKapat();
      _yeniden(150);
      return;
    }
    if (m.contains('no_match') || m.contains('speech_timeout') || m.contains('busy') || m.contains('client')) {
      _yeniden(m.contains('busy') ? 400 : 150);
      return;
    }
    String k = m;
    if (m.contains('permission')) k = 'izin';
    if (m.contains('network') || m.contains('server')) k = 'ag';
    if (m.contains('language')) k = 'dil';
    durdur();
    _hata?.call(k);
  }

  static void _sonuc(SpeechRecognitionResult r) {
    final metin = r.recognizedWords.trim();
    if (metin.isNotEmpty) {
      _buOturumdaSonuc = true;
      _sonucsuz = 0;
    }
    final tk = metin.split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
    // Kısmi sonuçta son kelime hâlâ yazılıyor olabilir: kesinleşene kadar beklenir…
    final kadar = r.finalResult ? tk.length : tk.length - 1;
    _gonder(tk, kadar);
    if (r.finalResult) {
      _giden = const [];
      _sonTk = const [];
    } else {
      _sonTk = tk;
      // …ama sıradaki kelimeye benziyorsa beklenmez, hemen ekrana gelir (Tarteel gibi anında).
      if (_dene != null && tk.isNotEmpty && _giden.length == tk.length - 1 && _dene!(tk.last)) _giden = tk;
    }
    // Kısmi sonuçta son kelime çoğu zaman ses tanımanın tahminidir: okunmamış kelime alttaki
    // satırda görünmesin diye yalnızca kesinleşen kısım gösterilir.
    _canli?.call(r.finalResult ? metin : tk.take(math.max(0, tk.length - 1)).join(' '));
  }

  /// [bosalt]: bekleyen son kelime işlensin mi (ekran kapanırken false).
  /// Durduktan sonra gelen geç sonuçlar kapanmış ekrana gitmesin diye geri çağırmalar silinir.
  static Future<void> durdur({bool bosalt = true}) async {
    if (_istek && bosalt) _bosalt();
    _istek = false;
    _kelime = null;
    _dene = null;
    _canli = null;
    _t?.cancel();
    acik.value = false;
    seviye.value = 0;
    try {
      await _s.stop();
    } catch (_) {}
    // Durma bip'i de duyulmasın: ses biraz sonra geri açılır.
    _acT?.cancel();
    _acT = Timer(const Duration(milliseconds: 700), () {
      if (!_istek) _bip(false);
    });
  }

  static String hataMetni(String k) => switch (k) {
        'izin' => 'Mikrofon izni gerekiyor. Telefon ayarlarından izin verebilirsin.',
        'ag' => 'Ses tanıma için internet bağlantısı gerekiyor.',
        'dil' => 'Telefonda Arapça ses tanıma yok. Google uygulaması › Ayarlar › Ses bölümünden Arapça ekleyebilirsin.',
        'yok' => 'Bu telefonda ses tanıma hizmeti bulunamadı. Düğmelerle devam edebilirsin.',
        _ => 'Ses tanıma hatası ($k)',
      };
}
