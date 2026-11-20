/// IMA ADPCM: 16 bitlik sesi 4 bite sıkıştırır (16 kHz konuşma: saniyede 8 KB).
///
/// Ödev okumasının sesi hocaya bu biçimde gider: ek paket gerektirmez, Kur'an tilâvetini
/// anlaşılır tutar ve Firestore'un ücretsiz kotasında küçük kalır.
library;

import 'dart:typed_data';

const _adim = [
  7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45, 50, 55, 60, 66, 73, 80, 88, 97, 107, 118,
  130, 143, 157, 173, 190, 209, 230, 253, 279, 307, 337, 371, 408, 449, 494, 544, 598, 658, 724, 796, 876, 963, 1060,
  1166, 1282, 1411, 1552, 1707, 1878, 2066, 2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358, 5894, 6484,
  7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899, 15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767
];
const _indeks = [-1, -1, -1, -1, 2, 4, 6, 8, -1, -1, -1, -1, 2, 4, 6, 8];

class _Durum {
  int tahmin = 0, indeks = 0;

  int kodla(int ornek) {
    final adim = _adim[indeks];
    var fark = ornek - tahmin;
    var kod = 0;
    if (fark < 0) {
      kod = 8;
      fark = -fark;
    }
    var d = adim >> 3;
    if (fark >= adim) {
      kod |= 4;
      fark -= adim;
      d += adim;
    }
    if (fark >= adim >> 1) {
      kod |= 2;
      fark -= adim >> 1;
      d += adim >> 1;
    }
    if (fark >= adim >> 2) {
      kod |= 1;
      d += adim >> 2;
    }
    tahmin += (kod & 8) != 0 ? -d : d;
    if (tahmin > 32767) tahmin = 32767;
    if (tahmin < -32768) tahmin = -32768;
    indeks += _indeks[kod];
    if (indeks < 0) indeks = 0;
    if (indeks > 88) indeks = 88;
    return kod;
  }

  int coz(int kod) {
    final adim = _adim[indeks];
    var d = adim >> 3;
    if ((kod & 4) != 0) d += adim;
    if ((kod & 2) != 0) d += adim >> 1;
    if ((kod & 1) != 0) d += adim >> 2;
    tahmin += (kod & 8) != 0 ? -d : d;
    if (tahmin > 32767) tahmin = 32767;
    if (tahmin < -32768) tahmin = -32768;
    indeks += _indeks[kod];
    if (indeks < 0) indeks = 0;
    if (indeks > 88) indeks = 88;
    return tahmin;
  }
}

/// Akan sesi parça parça sıkıştırır.
class AdpcmKodlayici {
  final _d = _Durum();
  final _b = BytesBuilder(copy: false);
  int _yarim = -1;
  int ornek = 0;

  void ekle(Int16List s) {
    final out = Uint8List((s.length + 1) >> 1);
    var o = 0;
    for (var i = 0; i < s.length; i++) {
      final k = _d.kodla(s[i]);
      if (_yarim < 0) {
        _yarim = k;
      } else {
        out[o++] = _yarim | (k << 4);
        _yarim = -1;
      }
    }
    ornek += s.length;
    if (o > 0) _b.add(Uint8List.sublistView(out, 0, o));
  }

  /// Bütün sıkıştırılmış ses (tek kalan yarım bayt da eklenir).
  Uint8List bitir() {
    if (_yarim >= 0) {
      _b.addByte(_yarim);
      _yarim = -1;
    }
    return _b.takeBytes();
  }
}

/// Sıkıştırılmış sesi açar.
Int16List adpcmCoz(Uint8List v, int ornek) {
  final d = _Durum();
  final out = Int16List(ornek);
  var o = 0;
  for (var i = 0; i < v.length && o < ornek; i++) {
    out[o++] = d.coz(v[i] & 15);
    if (o < ornek) out[o++] = d.coz(v[i] >> 4);
  }
  return out;
}

/// 16 bit tek kanallı WAV dosyası.
Uint8List wav(Int16List s, int hz) {
  final n = s.length * 2;
  final b = ByteData(44 + n);
  void yaz(int o, String t) {
    for (var i = 0; i < t.length; i++) {
      b.setUint8(o + i, t.codeUnitAt(i));
    }
  }

  yaz(0, 'RIFF');
  b.setUint32(4, 36 + n, Endian.little);
  yaz(8, 'WAVE');
  yaz(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little);
  b.setUint16(22, 1, Endian.little);
  b.setUint32(24, hz, Endian.little);
  b.setUint32(28, hz * 2, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  yaz(36, 'data');
  b.setUint32(40, n, Endian.little);
  for (var i = 0; i < s.length; i++) {
    b.setInt16(44 + i * 2, s[i], Endian.little);
  }
  return b.buffer.asUint8List();
}
