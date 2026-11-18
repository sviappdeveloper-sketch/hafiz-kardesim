import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as so;

import 'fonem.dart';
import 'ses.dart';

/// Kulak: Hafız Kardeşim'in kendi ses tanıması.
///
/// Telefonun genel ses tanıması (Google) yerine mikrofondaki ham ses, Kur'an tilâvetiyle eğitilmiş
/// akan (streaming) bir modelle (Quran-Lab zipformer_p-arabic-v3) telefonda, internetsiz çözülür.
/// Model harf değil tecvidli ses birimleri (fonem) duyar ve sesi geldikçe ~0,5 saniyelik parçalar
/// hâlinde işler: duyulanlar [sonuc] ile bölüm başından itibaren gönderilir. Okuyucu durunca
/// (nefes) bölüm kesinleşir (`kesin: true`) ve yeni bölüm başlar.
class Kulak {
  Kulak._();

  static const _hz = 16000;
  static final _kayit = AudioRecorder();
  static StreamSubscription<Uint8List>? _akis;

  static Isolate? _isci;
  static SendPort? _isciPort;
  static ReceivePort? _cevapPort;
  static Completer<bool>? _yukleniyor;
  static bool _hazir = false;
  static bool _bozuk = false;

  /// Model yüklenip çalışıyor mu (yüklenemezse eski ses tanımaya dönülür).
  static bool get kullanilabilir => !_bozuk;

  static void Function(String duyulan, bool kesin)? _sonuc;
  static void Function(String duyulan, bool kesin)? _bitis; // durdururken son sonucu alacak
  static void Function(String hata)? _hata;

  /// Bu numaradan önceki bölümlere ait sonuçlar yok sayılır (elle işaretleme / geri almada).
  static int _enAzBolum = 0;
  /// Gönderilen ve işçinin yanıtladığı son "sifirla" isteği: yanıt gelene kadar sonuçlar atılır.
  static int _istek = 0, _yanit = 0;

  /// Modeli hazırlar (ilk seferde dosyaları kopyalar ve arka planda yükler).
  static Future<bool> hazirla() async {
    if (_hazir) return true;
    if (_bozuk) return false;
    if (_yukleniyor != null) return _yukleniyor!.future;
    final c = _yukleniyor = Completer<bool>();
    try {
      if (!await Fonem.yukle()) throw Exception('fonem verisi yok');
      final model = await _kopyala('assets/asr/model.int8.onnx');
      final tokens = await _kopyala('assets/asr/tokens.txt');
      final hazirPort = ReceivePort();
      _cevapPort = ReceivePort();
      _isci = await Isolate.spawn(_isciAna, [hazirPort.sendPort, _cevapPort!.sendPort, model, tokens]);
      final ilk = await hazirPort.first.timeout(const Duration(seconds: 40));
      hazirPort.close();
      if (ilk is! SendPort) throw Exception('model yüklenemedi: $ilk');
      _isciPort = ilk;
      _cevapPort!.listen(_cevap);
      _hazir = true;
      c.complete(true);
    } catch (e) {
      debugPrint('Kulak: $e');
      _bozuk = true;
      _isci?.kill();
      _isci = null;
      c.complete(false);
    }
    return c.future;
  }

  /// Model dosyasını uygulama klasörüne bir kez kopyalar (sonraki açılışlarda yeniden okunmaz).
  static const _surum = 'zipformer-p-arabic-v3';
  static Future<String> _kopyala(String varlik) async {
    final dir = await getApplicationSupportDirectory();
    final ad = varlik.split('/').last;
    final hedef = File('${dir.path}/asr_$ad');
    final isaret = File('${dir.path}/asr_$ad.$_surum');
    if (await isaret.exists() && await hedef.exists()) return hedef.path;
    final veri = await rootBundle.load(varlik);
    await hedef.writeAsBytes(veri.buffer.asUint8List(veri.offsetInBytes, veri.lengthInBytes), flush: true);
    await isaret.writeAsString('ok');
    return hedef.path;
  }

  /// Dinlemeyi başlatır. [sonuc]: bölümün o ana kadar duyulan fonemleri, [kesin]: bölüm bitti.
  static Future<bool> baslat({
    required void Function(String duyulan, bool kesin) sonuc,
    void Function(String hata)? hata,
  }) async {
    if (!await hazirla()) return false;
    if (!await _kayit.hasPermission()) {
      hata?.call('izin');
      return false;
    }
    _sonuc = sonuc;
    _hata = hata;
    yeniBolum();
    try {
      final akis = await _kayit.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _hz,
        numChannels: 1,
        // Telefonun ses işleme (otomatik kazanç / gürültü bastırma) tilâvet sesini bozar: kapalı.
        autoGain: false,
        noiseSuppress: false,
        echoCancel: false,
      ));
      _akis = akis.listen(_geldi, onError: (Object e) {
        debugPrint('Kulak kayıt: $e');
        durdur();
        _hata?.call('kayit');
      });
    } catch (e) {
      debugPrint('Kulak kayıt: $e');
      hata?.call('kayit');
      return false;
    }
    Ses.acik.value = true;
    return true;
  }

  /// Bekleyen sesi atar ve yeni bir bölüm başlatır (elle işaretleme ya da geri almada).
  static void yeniBolum() {
    if (_isciPort == null) return;
    _isciPort!.send(['sifirla', ++_istek]);
  }

  static Future<void> durdur() async {
    final a = _akis;
    _akis = null;
    await a?.cancel();
    try {
      await _kayit.stop();
    } catch (_) {}
    // Son bölüm de işlensin: sona biraz sessizlik eklenip kesin sonuç istenir.
    _bitis = _sonuc;
    _sonuc = null;
    _hata = null;
    Ses.acik.value = false;
    Ses.seviye.value = 0;
    _isciPort?.send(['bitir']);
  }

  static void _geldi(Uint8List b) {
    if (_sonuc == null) return;
    final bd = ByteData.sublistView(b);
    final n = b.length ~/ 2;
    if (n == 0) return;
    final ses = Float32List(n);
    var kare = 0.0;
    for (var i = 0; i < n; i++) {
      final v = bd.getInt16(i * 2, Endian.little) / 32768.0;
      ses[i] = v;
      kare += v * v;
    }
    final rms = math.sqrt(kare / n);
    // Ses şiddeti: dinleme dalgası için.
    Ses.seviye.value = Ses.seviye.value * .5 + (rms * 12).clamp(0.0, 1.0) * .5;
    _isciPort?.send(TransferableTypedData.fromList([ses]));
  }

  static void _cevap(dynamic m) {
    if (m is! List || m.isEmpty) return;
    if (m[0] == 'bolum') {
      // İşçi "sifirla" isteğini işledi: bundan önceki bölümlerin sonuçları yok sayılır.
      _enAzBolum = m[1] as int;
      _yanit = m[2] as int;
      return;
    }
    if (m.length < 4) return;
    final bolum = m[0] as int;
    final metin = m[1] as String;
    final kesin = m[2] as bool;
    final son = m[3] as bool;
    if (son) {
      final f = _bitis;
      _bitis = null;
      if (f != null && bolum >= _enAzBolum) f(metin, true);
      return;
    }
    if (bolum < _enAzBolum || _yanit < _istek) return;
    _sonuc?.call(metin, kesin);
  }
}

/// Arka plan işçisi: akan modeli bir kez yükler, gelen sesi parça parça çözer.
void _isciAna(List<dynamic> a) {
  final hazir = a[0] as SendPort;
  final cevap = a[1] as SendPort;
  final model = a[2] as String;
  final tokens = a[3] as String;
  late final so.OnlineRecognizer tanima;
  late so.OnlineStream akis;
  try {
    so.initBindings();
    tanima = so.OnlineRecognizer(so.OnlineRecognizerConfig(
      feat: const so.FeatureConfig(sampleRate: 16000, featureDim: 80),
      model: so.OnlineModelConfig(
        zipformer2Ctc: so.OnlineZipformer2CtcModelConfig(model: model),
        tokens: tokens,
        numThreads: 2,
        debug: false,
      ),
      decodingMethod: 'greedy_search',
      enableEndpoint: true,
      // Konuşmadan sonra ~0,6 sn sessizlik (nefes) bölümü bitirir.
      rule1MinTrailingSilence: 2.4,
      rule2MinTrailingSilence: .6,
      rule3MinUtteranceLength: 60,
    ));
    akis = tanima.createStream();
  } catch (e) {
    hazir.send('$e');
    return;
  }
  final gelen = ReceivePort();
  hazir.send(gelen.sendPort);
  var bolum = 0;
  var onceki = '';
  void coz({required bool son}) {
    while (tanima.isReady(akis)) {
      tanima.decode(akis);
    }
    final metin = tanima.getResult(akis).text;
    final bitti = !son && tanima.isEndpoint(akis);
    if (son) {
      cevap.send([bolum, metin, true, true]);
    } else if (bitti) {
      // Nefes: bölüm kesinleşir, yeni bölüm başlar.
      if (metin.isNotEmpty) cevap.send([bolum, metin, true, false]);
    } else if (metin != onceki) {
      cevap.send([bolum, metin, false, false]);
    }
    onceki = metin;
    if (son || bitti) {
      tanima.reset(akis);
      bolum++;
      onceki = '';
    }
  }

  gelen.listen((m) {
    try {
      if (m is TransferableTypedData) {
        akis.acceptWaveform(samples: m.materialize().asFloat32List(), sampleRate: 16000);
        coz(son: false);
      } else if (m is List && m.isNotEmpty && m[0] == 'sifirla') {
        tanima.reset(akis);
        bolum++;
        onceki = '';
        cevap.send(['bolum', bolum, m[1]]);
      } else if (m is List && m.isNotEmpty && m[0] == 'bitir') {
        // Son kelimenin de çözülmesi için sona ~0,8 sn sessizlik eklenir.
        akis.acceptWaveform(samples: Float32List(12800), sampleRate: 16000);
        coz(son: true);
      }
    } catch (e) {
      // Bozuk ses parçası: akış baştan kurulur.
      try {
        akis.free();
      } catch (_) {}
      akis = tanima.createStream();
      bolum++;
      onceki = '';
    }
  });
}
