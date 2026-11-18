/// Kulak'ın fonem (ses birimi) tabanlı eşleştiricisi.
///
/// Kur'an modeli (Quran-Lab zipformer_p-arabic-v3) harf değil, tecvidli ses birimleri duyar:
/// "بِسمِ للَااهِ ررَحمَاانِ…". Her mushaf kelimesinin beklenen fonem yazımı derleme sırasında
/// üretilen `assets/asr/fonem.json` dosyasındadır. Duyulan fonemler harf harf metne hizalanır;
/// kelime ancak sesleri (neredeyse) tamamen duyulunca açılır.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'arapca.dart';

class Fonem {
  Fonem._();
  static List<List<String>>? _k;
  static Future<bool>? _yukleniyor;

  static bool get hazir => _k != null;

  /// Kelime fonemlerini yükler (yoksa false: eski ses tanımaya dönülür).
  static Future<bool> yukle() => _yukleniyor ??= _yukle();

  static Future<bool> _yukle() async {
    try {
      final s = await rootBundle.loadString('assets/asr/fonem.json');
      _k = await compute(_coz, s);
      return _k!.length > 6000;
    } catch (e) {
      debugPrint('Fonem: $e');
      _k = null;
      return false;
    }
  }

  /// Testler için: veriyi doğrudan metinden yükler.
  @visibleForTesting
  static void yukleMetin(String s) {
    _k = _coz(s);
    _yukleniyor = Future.value(true);
  }

  static List<List<String>> _coz(String s) => [
        for (final a in jsonDecode(s) as List) [for (final k in a as List) sade(k as String)]
      ];

  /// [ai] ayetinin [wi]. kelimesinin (sade) fonemleri.
  static String kelime(int ai, int wi) {
    final k = _k;
    if (k == null || ai < 0 || ai >= k.length) return '';
    final a = k[ai];
    return wi >= 0 && wi < a.length ? a[wi] : '';
  }

  static final _at = RegExp('[ؙـڇ۪ۜ ]');

  /// Karşılaştırma için sade yazım: tecvid işaretleri atılır, med uzunlukları ve şeddeler
  /// (art arda aynı ses) teke indirilir. Duyulan ile beklenen aynı biçime getirilir.
  static String sade(String p) {
    final s = p
        .replaceAll(_at, '')
        .replaceAll('ں', 'ن')
        .replaceAll('۾', 'م')
        .replaceAll('ۦ', 'ي')
        .replaceAll('ۥ', 'و')
        .replaceAll('ٲ', 'ا');
    final b = StringBuffer();
    var once = -1;
    for (final c in s.codeUnits) {
      if (c != once) b.writeCharCode(c);
      once = c;
    }
    return b.toString();
  }
}

/// Hareke (fetha, damme, kesra): birbirine karışması ucuz sayılır.
bool _hareke(int c) => c == 0x64E || c == 0x64F || c == 0x650;

extension FonemEslestir on Eslestirici {
  /// Bölümün o ana kadar duyulan fonemlerini ([duyulan], bölüm başından) metne hizalar.
  /// [kesin]: okuyucu durdu (nefes) — bölüm kapanır, kararlar kesinleşir.
  /// Yeni açılan (önceden gizli olan) kelimelerin dizinleri döner.
  List<int> fonem(String duyulan, {required bool kesin}) {
    final yeni = <int>[];
    if (fKok > cur) fKok = cur;
    final tum = Fonem.sade(duyulan);
    if (fOff > tum.length) fOff = tum.length;
    final r = tum.substring(fOff);
    if (r.isEmpty || fKok >= w.length) {
      if (kesin) {
        fKok = cur;
        fOff = 0;
      }
      return yeni;
    }
    final y = fonemHizala(r, w, fKok, kesin: kesin);
    if (y.son > fKok) {
      for (var i = fKok; i < y.son; i++) {
        final k = w[i];
        if (k.st == KD.ipucu) continue;
        if (k.st == KD.gizli) yeni.add(i);
        k.st = y.durum[i - fKok];
        k.h = y.duyulan[i - fKok];
      }
      if (y.son > cur) cur = y.son;
      for (var i = fKok; i < cur && i < w.length; i++) {
        if (w[i].end) lafizToleransi(w, w[i].li);
      }
    }
    if (kesin) {
      fKok = cur;
      fOff = 0;
    } else if (y.sabitKelime > fKok && y.sabitR > 0) {
      // Bölüm uzadı (nefes alınmadan okunuyor): baştaki kesinleşmiş kısım bırakılır, hizalama
      // oradan sürer. Böylece hesap kısa kalır, eski kararlar yeniden bozulmaz.
      fKok = y.sabitKelime;
      fOff += y.sabitR;
    }
    return yeni;
  }
}

class FonemYolu {
  FonemYolu(this.son, this.durum, this.duyulan, this.sabitKelime, this.sabitR);
  /// Bu kelimeye kadar (hariç) açılır.
  final int son;
  final List<int> durum;
  final List<String> duyulan;
  /// Uzun bölümde kesinleşen kısım: bu kelimeden ve duyulanın bu harfinden devam edilebilir (0: yok).
  final int sabitKelime, sabitR;
}

/// Duyulan sade fonemleri ([r]) [kok] kelimesinden başlayan metne hizalar (düzenleme uzaklığı).
FonemYolu fonemHizala(String r, List<Kelime> w, int kok, {required bool kesin}) {
  // Hedef metin: kökten itibaren kelimelerin fonemleri art arda (sınırdaki aynı ses teke iner).
  final n = r.length;
  final hedefUzun = n * 2 + 140;
  final t = StringBuffer();
  final kBas = <int>[], kSon = <int>[];
  var sonHarf = -1;
  for (var i = kok; i < w.length && t.length < hedefUzun && i - kok < 300; i++) {
    var f = w[i].f;
    if (f.isEmpty) f = w[i].f = Fonem.kelime(w[i].ai, w[i].wi);
    if (f.isEmpty) f = w[i].n; // fonem yoksa (olmamalı) harfli yazım
    if (f.isNotEmpty && f.codeUnitAt(0) == sonHarf) f = f.substring(1);
    kBas.add(t.length);
    t.write(f);
    kSon.add(t.length);
    if (f.isNotEmpty) sonHarf = f.codeUnitAt(f.length - 1);
  }
  final ts = t.toString();
  final m = ts.length;
  final rc = r.codeUnits, tc = ts.codeUnits;
  // Sure başında (ya da oturum başında) okunan eûzü-besmele: baştaki ~70 ses neredeyse bedava.
  final girisSerbest = kok == 0 || w[kok].sureBasi;
  const ekle = 1.0, sil = 1.0;
  final cols = m + 1;
  final d = Float32List((n + 1) * cols);
  final g = Uint8List((n + 1) * cols); // 0 köşegen, 1 ekle (fazla duyulan), 2 sil (duyulmayan)
  // Hiçbir şey eşleşmeden önceki atlama: okuyucu biraz ileriden başladı.
  for (var j = 1; j <= m; j++) {
    d[j] = j * .3;
    g[j] = 2;
  }
  for (var i = 1; i <= n; i++) {
    final ri = rc[i - 1];
    final row = i * cols, prev = (i - 1) * cols;
    d[row] = d[prev] + (girisSerbest && i <= 70 ? .12 : ekle);
    g[row] = 1;
    for (var j = 1; j <= m; j++) {
      final tj = tc[j - 1];
      final deg = ri == tj ? 0.0 : (_hareke(ri) && _hareke(tj) ? .5 : 1.0);
      var en = d[prev + j - 1] + deg, yon = 0;
      final a = d[prev + j] + ekle;
      if (a < en) {
        en = a;
        yon = 1;
      }
      final b = d[row + j - 1] + (_hareke(tj) ? .5 : sil);
      if (b < en) {
        en = b;
        yon = 2;
      }
      d[row + j] = en;
      g[row + j] = yon;
    }
  }
  // Sonda kalan metin bedava: en düşük maliyetli bitiş (eşitlikte en yakın).
  var bj = 0;
  final son = n * cols;
  for (var j = 1; j <= m; j++) {
    if (d[son + j] < d[son + bj] - 1e-6) bj = j;
  }
  // Geri izleme: her hedef sesin eşleşip eşleşmediği ve karşısındaki duyulan ses.
  final esles = Float32List(m); // 1 tam, .5 hareke karışması
  final karsi = Int32List(m)..fillRange(0, m, -1);
  final ekRaw = Int32List(m + 1); // hedefin j. sesinden önce araya giren fazla duyulan sayısı
  var i = n, j = bj;
  while (i > 0 || j > 0) {
    final yn = i == 0 ? 2 : (j == 0 ? 1 : g[i * cols + j]);
    if (yn == 0) {
      karsi[j - 1] = i - 1;
      if (rc[i - 1] == tc[j - 1]) {
        esles[j - 1] = 1;
      } else if (_hareke(rc[i - 1]) && _hareke(tc[j - 1])) {
        esles[j - 1] = .5;
      }
      i--;
      j--;
    } else if (yn == 1) {
      ekRaw[j]++;
      i--;
    } else {
      j--;
    }
  }
  // Kelime kelime değerlendirme.
  final kac = kBas.length;
  final durum = <int>[], duyulan = <String>[];
  final oran = <double>[];
  final duydu = <bool>[];
  var ulasilan = 0; // tamamen geçilen kelime sayısı
  for (var k = 0; k < kac; k++) {
    final a = kBas[k], b = kSon[k];
    if (b > bj) break;
    var s = 0.0, rMin = 1 << 30, rMax = -1, ek = 0;
    for (var z = a; z < b; z++) {
      s += esles[z];
      if (karsi[z] >= 0) {
        rMin = math.min(rMin, karsi[z]);
        rMax = math.max(rMax, karsi[z]);
      }
      ek += ekRaw[z];
    }
    ek += ekRaw[b];
    final uz = math.max(1, b - a);
    oran.add(s / uz);
    duydu.add(rMax >= 0 || ek > 0);
    duyulan.add(rMax >= 0 ? r.substring(rMin, rMax + 1) : '');
    ulasilan = k + 1;
  }
  // Söylenmekte olan kelime: sesleri (sondaki bir-iki ses hariç) duyulduysa açılır.
  if (ulasilan < kac) {
    final k = ulasilan, a = kBas[k], b = kSon[k];
    final uz = b - a;
    if (bj > a && uz > 0) {
      var s = 0.0, rMin = 1 << 30, rMax = -1;
      for (var z = a; z < bj; z++) {
        s += esles[z];
        if (karsi[z] >= 0) {
          rMin = math.min(rMin, karsi[z]);
          rMax = math.max(rMax, karsi[z]);
        }
      }
      // Vakıfta son hareke okunmaz; kelime biterken son ses gecikebilir.
      final pay = (uz <= 3 ? 0 : (uz <= 8 ? 1 : 2)) + (kesin ? 1 : 0);
      if (bj >= b - pay && s / uz >= (kesin ? .6 : .72) && rMax >= 0) {
        oran.add(s / uz);
        duydu.add(true);
        duyulan.add(r.substring(rMin, rMax + 1));
        ulasilan = k + 1;
      }
    }
  }
  for (var k = 0; k < ulasilan; k++) {
    durum.add(oran[k] >= .6 ? KD.dogru : (duydu[k] ? KD.hata : KD.atla));
  }
  // Duyulmayan boşluklar: tek ve kısa bir kelime ses tanımanın kaçırmasıdır (doğru), daha uzunu atlanmıştır.
  var k = 0;
  while (k < ulasilan) {
    if (durum[k] != KD.atla) {
      k++;
      continue;
    }
    var e = k;
    while (e < ulasilan && durum[e] == KD.atla) {
      e++;
    }
    var harf = 0;
    for (var z = k; z < e; z++) {
      harf += kSon[z] - kBas[z];
    }
    if (e - k == 1 && harf <= 4 && e < ulasilan) durum[k] = KD.dogru;
    k = e;
  }
  // Temkin: ara sonuçta hatalı/atlandı görünen kelimede durulur; ardından en az iki kelime
  // sağlam duyulmadıkça karar verilmez (okuyucu cümleyi bitirince ya da devam edince verilir).
  var acik = ulasilan;
  if (!kesin) {
    for (var z = 0; z < ulasilan; z++) {
      if (durum[z] == KD.dogru) continue;
      var saglam = 0;
      for (var q = z + 1; q < ulasilan && durum[q] == KD.dogru; q++) {
        saglam++;
      }
      if (saglam < 2) {
        acik = z;
        break;
      }
    }
  }
  // Uzun bölüm: açılan kısmın sonundan en az ~40 ses geride kalan kelimeye kadar kesinleşir.
  var sabitKelime = 0, sabitR = 0;
  if (!kesin && n > 160 && acik > 2) {
    for (var z = acik - 2; z >= 0; z--) {
      var rSon = -1;
      for (var q = kBas[z]; q < kSon[z]; q++) {
        if (karsi[q] > rSon) rSon = karsi[q];
      }
      if (rSon >= 0 && n - (rSon + 1) >= 40) {
        sabitKelime = kok + z + 1;
        sabitR = rSon + 1;
        break;
      }
    }
  }
  return FonemYolu(kok + acik, durum.sublist(0, acik), duyulan.sublist(0, acik), sabitKelime, sabitR);
}
