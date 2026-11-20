import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;

import 'hoca_service.dart';

/// Canlı derste uygulama içi sesli bağlantı (WebRTC, eşler arası).
///
/// Telefon ya da WhatsApp araması sürerken telefon mikrofonu aramaya ayrılır ve uygulama
/// öğrenciyi duyamaz. Bu yüzden hoca ile öğrenci uygulamanın içinden konuşur; öğrencinin
/// mikrofon sesi hem hocaya gider hem de (Android'de) uygulamanın Kur'an ses tanımasına (Kulak).
///
/// Bağlantı bilgisi (teklif / cevap) canlı ders belgesinin "ses" alanından geçer; ses sunucuya
/// uğramaz, iki telefon arasında doğrudan akar. Teklifi hoca verir, öğrenci cevaplar.
class SesliBaglanti {
  SesliBaglanti({required this.canliId, required this.hocayim});
  final String canliId;
  final bool hocayim;

  /// kapali · baglaniyor · bagli · koptu · hata
  final durum = ValueNotifier<String>('kapali');
  /// Kendi mikrofonum kapalı mı (hoca dinlerken kapatabilir).
  final sessiz = ValueNotifier<bool>(false);
  /// Öğrenci: mikrofon sesi ses tanımaya aktarılabiliyor mu (yalnız Android).
  final tanimayaAkar = ValueNotifier<bool>(false);

  RTCPeerConnection? _pc;
  MediaStream? _yerel;
  String _benimTeklif = '', _islenenTeklif = '', _islenenCevap = '';
  bool _kapandi = false;
  Timer? _kopmaT;

  static const _kanal = MethodChannel('hafiz/webrtc');
  static const _sesKanal = EventChannel('hafiz/webrtc_ses');
  static Stream<Uint8List>? _sesAkisi;

  /// Öğrencinin mikrofon sesi (16 kHz, 16 bit PCM): Kulak bunu dinler.
  static Stream<Uint8List> get mikrofonSesi =>
      _sesAkisi ??= _sesKanal.receiveBroadcastStream().map((e) => e as Uint8List).asBroadcastStream();

  static const _ayar = <String, dynamic>{
    'iceServers': [
      {
        'urls': ['stun:stun.l.google.com:19302', 'stun:stun1.l.google.com:19302', 'stun:stun2.l.google.com:19302']
      },
    ],
    'sdpSemantics': 'unified-plan',
  };

  bool get bagli => durum.value == 'bagli';

  /// STUN + (varsa) aktarma (TURN) sunucuları. TURN bilgisi Firestore app/ses belgesindeki
  /// "turnUrl"den (Metered) alınır; operatör doğrudan bağlantıya izin vermezse ses oradan geçer.
  static List<Map<String, dynamic>>? _turn;
  static const _varsayilanTurn =
      'https://hafizkardesim.metered.live/api/v1/turn/credentials?apiKey=58b851ae348822a7579277687d4eed5243e9';
  static Future<Map<String, dynamic>> _ayarlar() async {
    if (_turn == null) {
      final l = <Map<String, dynamic>>[];
      try {
        final d = await FirebaseFirestore.instance.collection('app').doc('ses').get();
        // Yönetim › Ayarlar'da başka bir adres girilmediyse uygulamanın kendi Metered TURN kimliği
        // (ücretsiz plan, ayda 500 MB; ön yüzde kullanılmak üzere verilen anahtar).
        var url = (d.data()?['turnUrl'] ?? '') as String;
        if (url.trim().isEmpty) url = _varsayilanTurn;
        if (url.startsWith('https://')) {
          final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
          final j = jsonDecode(r.body);
          if (j is List) {
            for (final x in j) {
              if (x is Map) l.add(x.cast<String, dynamic>());
            }
          }
        }
        _turn = l;
      } catch (e) {
        // Ulaşılamazsa bu bağlantı yalnız STUN ile kurulur; bir sonrakinde yeniden denenir.
        debugPrint('SesliBaglanti TURN: $e');
      }
    }
    return {
      ..._ayar,
      'iceServers': [...(_ayar['iceServers'] as List), ...?_turn],
    };
  }

  /// Hoca: yeni bir bağlantı teklifi verir (ilk açılışta ve "yeniden bağlan"da).
  Future<void> teklifVer() async {
    if (!hocayim || _kapandi) return;
    durum.value = 'baglaniyor';
    try {
      final pc = await _kur();
      final t = await pc.createOffer({'offerToReceiveAudio': true, 'offerToReceiveVideo': false});
      await pc.setLocalDescription(t);
      await _toplamayiBekle(pc);
      final d = await pc.getLocalDescription();
      if (d == null || _kapandi) return;
      _benimTeklif = '${DateTime.now().millisecondsSinceEpoch}${Random().nextInt(9999)}';
      _islenenCevap = '';
      await HocaService.sesYaz(canliId, {
        'ses.teklif': d.sdp,
        'ses.tTur': d.type,
        'ses.n': _benimTeklif,
        'ses.cevap': null,
        'ses.cn': null,
      });
    } catch (e) {
      debugPrint('SesliBaglanti teklif: $e');
      durum.value = 'hata';
    }
  }

  /// Canlı ders belgesi her değiştiğinde çağrılır.
  Future<void> guncelle(Canli c) async {
    if (_kapandi) return;
    final s = c.ses;
    if (hocayim) {
      final cevap = s['cevap'] as String?;
      final cn = s['cn'] as String?;
      if (cevap != null && cn == _benimTeklif && cn != _islenenCevap && _pc != null) {
        _islenenCevap = cn!;
        try {
          await _pc!.setRemoteDescription(RTCSessionDescription(cevap, (s['cTur'] as String?) ?? 'answer'));
        } catch (e) {
          debugPrint('SesliBaglanti cevap: $e');
          durum.value = 'hata';
        }
      }
      return;
    }
    final teklif = s['teklif'] as String?;
    final n = s['n'] as String?;
    if (teklif == null || n == null || n == _islenenTeklif) return;
    _islenenTeklif = n;
    durum.value = 'baglaniyor';
    try {
      final pc = await _kur();
      await pc.setRemoteDescription(RTCSessionDescription(teklif, (s['tTur'] as String?) ?? 'offer'));
      final a = await pc.createAnswer({'offerToReceiveAudio': true, 'offerToReceiveVideo': false});
      await pc.setLocalDescription(a);
      await _toplamayiBekle(pc);
      final d = await pc.getLocalDescription();
      if (d == null || _kapandi) return;
      await HocaService.sesYaz(canliId, {'ses.cevap': d.sdp, 'ses.cTur': d.type, 'ses.cn': n});
    } catch (e) {
      debugPrint('SesliBaglanti cevapla: $e');
      durum.value = 'hata';
    }
  }

  Future<RTCPeerConnection> _kur() async {
    await _pcKapat();
    final pc = await createPeerConnection(await _ayarlar());
    _pc = pc;
    pc.onConnectionState = (st) {
      switch (st) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          _kopmaT?.cancel();
          durum.value = 'bagli';
          _hoparlor();
          _tanimayaBagla();
        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
          // Kısa kopmalar kendiliğinden düzelir; uzun sürerse "koptu" gösterilir.
          _kopmaT?.cancel();
          _kopmaT = Timer(const Duration(seconds: 5), () {
            if (durum.value != 'bagli' || _pc != pc) return;
            durum.value = 'koptu';
          });
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          durum.value = 'hata';
        default:
          break;
      }
    };
    _yerel ??= await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': false,
    });
    for (final t in _yerel!.getAudioTracks()) {
      t.enabled = !sessiz.value;
      await pc.addTrack(t, _yerel!);
    }
    return pc;
  }

  Future<void> _toplamayiBekle(RTCPeerConnection pc) async {
    if (pc.iceGatheringState == RTCIceGatheringState.RTCIceGatheringStateComplete) return;
    final c = Completer<void>();
    pc.onIceGatheringState = (s) {
      if (s == RTCIceGatheringState.RTCIceGatheringStateComplete && !c.isCompleted) c.complete();
    };
    await c.future.timeout(const Duration(seconds: 4), onTimeout: () {});
  }

  Future<void> _hoparlor() async {
    try {
      await Helper.setSpeakerphoneOn(true);
    } catch (_) {}
  }

  /// Öğrenci: mikrofon izinin sesi Kulak'a akıtılır (Android). Olmazsa hoca işaretlemeye devam eder.
  Future<void> _tanimayaBagla() async {
    if (hocayim || _yerel == null) return;
    final iz = _yerel!.getAudioTracks().firstOrNull;
    if (iz?.id == null) return;
    try {
      final ok = await _kanal.invokeMethod<bool>('dinle', {'iz': iz!.id});
      tanimayaAkar.value = ok == true;
    } catch (_) {
      tanimayaAkar.value = false;
    }
  }

  void sessizYap(bool v) {
    sessiz.value = v;
    for (final t in _yerel?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
      t.enabled = !v;
    }
  }

  Future<void> _pcKapat() async {
    final pc = _pc;
    _pc = null;
    try {
      await pc?.close();
    } catch (_) {}
  }

  Future<void> kapat() async {
    _kapandi = true;
    _kopmaT?.cancel();
    try {
      await _kanal.invokeMethod('birak');
    } catch (_) {}
    await _pcKapat();
    for (final t in _yerel?.getTracks() ?? const <MediaStreamTrack>[]) {
      try {
        await t.stop();
      } catch (_) {}
    }
    try {
      await _yerel?.dispose();
    } catch (_) {}
    _yerel = null;
    durum.value = 'kapali';
    tanimayaAkar.value = false;
  }
}
