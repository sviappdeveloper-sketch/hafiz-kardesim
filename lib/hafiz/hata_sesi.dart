import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Ezber Oku'da bir kelime hatalı işaretlenince çalan tok, kısık ses ("tık").
/// Art arda hatalarda sık sık çalmasın diye en az ~0,8 saniye arayla çalar.
class HataSesi {
  HataSesi._();
  static AudioPlayer? _p;
  static DateTime _son = DateTime(2000);

  static Future<void> cal() async {
    final s = DateTime.now();
    if (s.difference(_son).inMilliseconds < 800) return;
    _son = s;
    try {
      final p = _p ??= AudioPlayer(handleAudioSessionActivation: false);
      if (p.audioSource == null) {
        await p.setAsset('assets/audio/hata.wav');
        await p.setVolume(.45);
      }
      await p.seek(Duration.zero);
      await p.play();
    } catch (e) {
      debugPrint('HataSesi: $e');
    }
  }
}
