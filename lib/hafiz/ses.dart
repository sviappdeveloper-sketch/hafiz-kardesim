import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../services/settings_service.dart';

/// Arapça ses tanıma. Kâri nefes alınca tanıma durur; mikrofon açık kaldıkça kendiliğinden yeniden başlar.
/// Duyulan kelimeler [kelime] ile tek tek gönderilir (kısmi sonuçta son kelime kesinleşene kadar beklenir).
class Ses {
  Ses._();
  static final stt.SpeechToText _s = stt.SpeechToText();
  static bool _hazir = false;
  static bool _istek = false;
  static int _off = 0;
  static void Function(String kelime)? _kelime;
  static void Function(String metin)? _canli;
  static void Function(String hata)? _hata;
  static final acik = ValueNotifier<bool>(false);

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
    void Function(String metin)? canli,
    void Function(String hata)? hata,
  }) async {
    _kelime = kelime;
    _canli = canli;
    _hata = hata;
    if (!await hazirla()) {
      hata?.call('yok');
      return false;
    }
    _istek = true;
    acik.value = true;
    await _dinle();
    return true;
  }

  static Future<void> _dinle() async {
    if (!_istek) return;
    _off = 0;
    try {
      await _s.listen(
        onResult: _sonuc,
        localeId: dil,
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 4),
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: stt.ListenMode.dictation,
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

  static void _durum(String d) {
    if ((d == 'done' || d == 'notListening') && _istek) _yeniden(120);
  }

  static void _onHata(SpeechRecognitionError e) {
    final m = e.errorMsg;
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
    _canli?.call(metin);
    final tk = metin.split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
    final kadar = r.finalResult ? tk.length : tk.length - 1;
    for (var i = _off; i < kadar; i++) {
      _kelime?.call(tk[i]);
    }
    if (r.finalResult) {
      _off = 0;
    } else if (kadar > _off) {
      _off = kadar;
    }
  }

  static Future<void> durdur() async {
    _istek = false;
    _t?.cancel();
    acik.value = false;
    try {
      await _s.stop();
    } catch (_) {}
  }

  static String hataMetni(String k) => switch (k) {
        'izin' => 'Mikrofon izni gerekiyor. Telefon ayarlarından izin verebilirsin.',
        'ag' => 'Ses tanıma için internet bağlantısı gerekiyor.',
        'dil' => 'Telefonda Arapça ses tanıma yok. Google uygulaması › Ayarlar › Ses bölümünden Arapça ekleyebilirsin.',
        'yok' => 'Bu telefonda ses tanıma hizmeti bulunamadı. Düğmelerle devam edebilirsin.',
        _ => 'Ses tanıma hatası ($k)',
      };
}
