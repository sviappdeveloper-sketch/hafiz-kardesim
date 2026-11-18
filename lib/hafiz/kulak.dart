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

import 'ses.dart';

/// Kulak: Hafız Kardeşim'in kendi ses tanıması.
///
/// Telefonun genel ses tanıması (Google) yerine mikrofondaki ham ses kaydedilir ve Kur'an
/// tilâvetiyle eğitilmiş küçük bir model (quran-asr-tiny, MIT lisanslı, ~19 MB) ile telefonda,
/// internetsiz çözülür. Ses bölüm bölüm tutulur: okuyucu nefes alana kadar bölümün tamamı
/// ~0,3 saniyede bir yeniden çözülür ve duyulanlar [sonuc] ile (bölümün başından) gönderilir.
/// Nefeste bölüm kesinleşir (`kesin: true`) ve yeni bölüm başlar.
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

  static void Function(List<String> kelimeler, bool kesin)? _sonuc;
  static void Function(String hata)? _hata;

  // Bölüm sesi (16 kHz, -1…1).
  static Float32List _ses = Float32List(_hz * 20);
  static int _uzun = 0;
  static int _cozulen = 0;
  static bool _konustu = false;
  static int _sessiz = 0; // bölüm sonundaki sessiz örnek sayısı
  /// Bölümün başındaki "bağlam" sesi: önceki bölümden kalan, zaten işlenmiş son ~3 sn.
  /// Model kelimeyi önceki sesle birlikte daha doğru duyar; bu kısımdan çıkan kelimeler atılır.
  static int _bag = 0;
  static const _bagSure = _hz * 3;
  static bool _mesgul = false;
  static int _sira = 0;
  static int _taban = 0; // bu dizine kadarki çözümler eski bölüme ait: yok sayılır
  static double _gurultu = .004; // ortam gürültüsü (yavaşça öğrenilir)

  /// Modeli hazırlar (ilk seferde dosyaları kopyalar ve arka planda yükler).
  static Future<bool> hazirla() async {
    if (_hazir) return true;
    if (_bozuk) return false;
    if (_yukleniyor != null) return _yukleniyor!.future;
    final c = _yukleniyor = Completer<bool>();
    try {
      final model = await _kopyala('assets/asr/model.int8.onnx');
      final tokens = await _kopyala('assets/asr/tokens.txt');
      final hazirPort = ReceivePort();
      _cevapPort = ReceivePort();
      _isci = await Isolate.spawn(_isciAna, [hazirPort.sendPort, _cevapPort!.sendPort, model, tokens]);
      final ilk = await hazirPort.first.timeout(const Duration(seconds: 30));
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

  /// Model dosyasını uygulama klasörüne bir kez kopyalar (sonraki açılışlarda 19 MB yeniden okunmaz).
  static const _surum = 'quran-asr-tiny-1';
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

  /// Dinlemeyi başlatır. [sonuc]: bölümün o ana kadar duyulan kelimeleri, [kesin]: bölüm bitti.
  static Future<bool> baslat({
    required void Function(List<String> kelimeler, bool kesin) sonuc,
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
    _uzun = 0;
    _bag = 0;
    _cozulen = 0;
    _konustu = false;
    _sessiz = 0;
    _taban = _sira; // yoldaki eski çözümler yok sayılır
    _mesgul = false;
  }

  static Future<void> durdur() async {
    final a = _akis;
    _akis = null;
    await a?.cancel();
    try {
      await _kayit.stop();
    } catch (_) {}
    // Son bölüm de işlensin.
    final son = _sonuc;
    final bag = _bag;
    final kalan = son != null && _konustu && _uzun - _bag > _hz ~/ 4
        ? TransferableTypedData.fromList([Float32List.sublistView(_ses, 0, _uzun)])
        : null;
    _sonuc = null;
    _hata = null;
    Ses.acik.value = false;
    Ses.seviye.value = 0;
    yeniBolum();
    if (kalan != null && _isciPort != null) {
      final id = ++_sira;
      _bekleyen[id] = (kesin: true, zorla: false, uzun: 0, bag: bag, son: son);
      _isciPort!.send([id, kalan]);
    }
  }

  static final Map<int, ({bool kesin, bool zorla, int uzun, int bag, void Function(List<String>, bool)? son})>
      _bekleyen = {};

  static void _geldi(Uint8List b) {
    if (_sonuc == null) return;
    final bd = ByteData.sublistView(b);
    final n = b.length ~/ 2;
    if (_uzun + n > _ses.length) {
      final y = Float32List(math.max(_ses.length * 2, _uzun + n));
      y.setRange(0, _uzun, _ses);
      _ses = y;
    }
    var kare = 0.0;
    for (var i = 0; i < n; i++) {
      final v = bd.getInt16(i * 2, Endian.little) / 32768.0;
      _ses[_uzun + i] = v;
      kare += v * v;
    }
    _uzun += n;
    final rms = n == 0 ? 0.0 : math.sqrt(kare / n);
    // Ses şiddeti: dinleme dalgası için.
    Ses.seviye.value = Ses.seviye.value * .5 + (rms * 12).clamp(0.0, 1.0) * .5;
    // Konuşma / sessizlik ayrımı: ortam gürültüsünün birkaç katı.
    final esik = math.max(.012, _gurultu * 3);
    if (rms > esik) {
      _konustu = true;
      _sessiz = 0;
    } else {
      _sessiz += n;
      _gurultu = _gurultu * .97 + rms * .03;
    }
    if (!_konustu) {
      // Konuşma yok: sessizlik biriktirilmez, yalnızca son ~3 sn (bağlam) tutulur.
      if (_uzun > _bagSure + _hz) {
        final bas = _uzun - _bagSure;
        _ses.setRange(0, _bagSure, _ses, bas);
        _uzun = _bagSure;
        _bag = math.max(0, _bag - bas);
        _cozulen = 0;
      }
      return;
    }
    _isle();
  }

  /// Sıradaki çözümü gönderir: nefeste kesin, bölüm çok uzarsa zorla kesin, yoksa ara sonuç.
  static void _isle() {
    if (_mesgul || _isciPort == null || _sonuc == null) return;
    final nefes = _sessiz >= _hz ~/ 2;
    final yeni = _uzun - _bag;
    final cokUzun = yeni >= _hz * 12;
    // Çok kısa ses modele gönderilmez (boş ses modeli çökertir).
    if (yeni - math.min(_sessiz, yeni) < _hz * 3 ~/ 10) {
      if (nefes) _konustu = false;
      return;
    }
    if (!nefes && !cokUzun && _uzun - _cozulen < _hz * 25 ~/ 100) return;
    if (!nefes && !cokUzun && _uzun - _sessiz <= _cozulen) return; // yeni ses yok
    final id = ++_sira;
    _bekleyen[id] = (kesin: nefes || cokUzun, zorla: cokUzun && !nefes, uzun: _uzun, bag: _bag, son: _sonuc);
    _mesgul = true;
    _cozulen = _uzun;
    final s = Float32List.sublistView(_ses, 0, _uzun);
    _isciPort!.send([id, TransferableTypedData.fromList([s])]);
  }

  static void _cevap(dynamic m) {
    if (m is! List || m.length < 4) return;
    final id = m[0] as int;
    final metin = m[1] as String;
    final tokens = (m[2] as List).cast<String>();
    final zaman = (m[3] as List).cast<double>();
    final b = _bekleyen.remove(id);
    if (b == null || id <= _taban || b.son == null) return;
    final guncel = id == _sira && _sonuc != null;
    _mesgul = false;
    var kelimeler = metin.split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
    var baslar = _kelimeBaslari(tokens, zaman);
    if (baslar.length != kelimeler.length) baslar = const [];
    // Bağlam sesinden çıkan (zaten işlenmiş) kelimeler atılır.
    if (b.bag > 0 && baslar.isNotEmpty) {
      final sinir = b.bag / _hz - .08;
      var k = 0;
      while (k < baslar.length && baslar[k] < sinir) {
        k++;
      }
      kelimeler = kelimeler.sublist(k);
      baslar = baslar.sublist(k);
    } else if (b.bag > 0 && b.uzun > 0) {
      // Zaman bilgisi yoksa bağlamın payı kadar baştaki kelime atılır.
      final k = (kelimeler.length * b.bag / b.uzun).round().clamp(0, kelimeler.length);
      kelimeler = kelimeler.sublist(k);
    }
    if (!b.kesin) {
      b.son!(kelimeler, false);
      _isle();
      return;
    }
    if (!b.zorla) {
      b.son!(kelimeler, true);
      if (guncel) _bolumKes(b.uzun);
      _isle();
      return;
    }
    // Bölüm çok uzadı (nefes alınmadan okunuyor): son iki kelime hariç kesinleşir, ses o
    // kelimelerin başından kesilip yeni bölüm oradan sürer.
    if (kelimeler.length < 3 || baslar.length != kelimeler.length) {
      b.son!(kelimeler, true);
      if (guncel) _bolumKes(b.uzun);
    } else {
      b.son!(kelimeler.sublist(0, kelimeler.length - 2), true);
      if (guncel) _bolumKes(math.min(b.uzun, (baslar[kelimeler.length - 2] * _hz).round() - _hz ~/ 20));
    }
    _isle();
  }

  /// [kadar] örneğe kadarki ses işlendi: yeni bölüm oradan başlar, öncesinin son ~3 sn'si bağlam kalır.
  static void _bolumKes(int kadar) {
    kadar = kadar.clamp(0, _uzun);
    final bas = math.max(0, kadar - _bagSure);
    _ses.setRange(0, _uzun - bas, _ses, bas);
    _uzun -= bas;
    _bag = kadar - bas;
    _cozulen = 0;
    final yeni = _uzun - _bag;
    _sessiz = math.min(_sessiz, yeni);
    if (_sessiz >= yeni) {
      _konustu = false;
    }
  }

  /// Her kelimenin başladığı saniye. Harf olmayan belirteç (boşluk, ▁, |) kelime ayırıcıdır;
  /// "▁" ile başlayan harf belirteci de yeni kelimeyi başlatır.
  static List<double> _kelimeBaslari(List<String> tokens, List<double> zaman) {
    final r = <double>[];
    if (tokens.length != zaman.length) return r;
    final harf = RegExp('[ء-ي]');
    var ayrac = true;
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      if (!harf.hasMatch(t)) {
        ayrac = true;
        continue;
      }
      if (ayrac || t.startsWith('▁') || t.startsWith(' ')) r.add(zaman[i]);
      ayrac = false;
    }
    return r;
  }
}

/// Arka plan işçisi: modeli bir kez yükler, gelen her sesi çözer.
void _isciAna(List<dynamic> a) {
  final hazir = a[0] as SendPort;
  final cevap = a[1] as SendPort;
  final model = a[2] as String;
  final tokens = a[3] as String;
  late final so.OfflineRecognizer tanima;
  try {
    so.initBindings();
    tanima = so.OfflineRecognizer(so.OfflineRecognizerConfig(
      model: so.OfflineModelConfig(
        zipformerCtc: so.OfflineZipformerCtcModelConfig(model: model),
        tokens: tokens,
        numThreads: 2,
        debug: false,
      ),
    ));
  } catch (e) {
    hazir.send('$e');
    return;
  }
  final gelen = ReceivePort();
  hazir.send(gelen.sendPort);
  gelen.listen((m) {
    final l = m as List;
    final id = l[0] as int;
    final ham = (l[1] as TransferableTypedData).materialize().asFloat32List();
    // Boş ya da çok kısa ses modeli (yerel kodda) çökertir: gönderilmez. Kısa ses sessizlikle
    // uzatılır; sona eklenen sessizlik son kelimenin de tam çözülmesini sağlar.
    if (ham.length < 1600) {
      cevap.send([id, '', <String>[], <double>[]]);
      return;
    }
    const bas = 4000, son = 8000;
    final ses = Float32List(math.max(16000, bas + ham.length + son));
    ses.setRange(bas, bas + ham.length, ham);
    try {
      final s = tanima.createStream();
      s.acceptWaveform(samples: ses, sampleRate: 16000);
      tanima.decode(s);
      final r = tanima.getResult(s);
      s.free();
      // Zamanlar baştaki eklenen sessizlik kadar geri alınır.
      cevap.send([id, r.text, r.tokens, [for (final t in r.timestamps) t - bas / 16000]]);
    } catch (e) {
      cevap.send([id, '', <String>[], <double>[]]);
    }
  });
}
