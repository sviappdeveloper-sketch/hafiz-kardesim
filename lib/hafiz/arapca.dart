/// Arapça metin karşılaştırma ve ezber eşleştirme motoru.
///
/// Ses tanıma normal (imlâî) yazımla, mushaf metni Osmanlı hattıyla gelir; ikisini
/// karşılaştırabilmek için hareke ve işaretler atılır, harf biçimleri birleştirilir.
library;

import 'dart:math' as math;

final _harake = RegExp('[ؐ-ًؚ-ٰٟۖ-ۭـ‌‍‏﻿]');
final _elif = RegExp('[ٱأإآٲٳ]');
final _arapDisi = RegExp('[^ء-ي]');
final _sesliHarf = RegExp('[اويى]');

/// Harekesiz, harf biçimleri birleştirilmiş yazım.
String nrm(String w) => w
    .replaceAll(_harake, '')
    .replaceAll(_elif, 'ا')
    .replaceAll('ة', 'ه')
    .replaceAll(RegExp('[ىی]'), 'ي')
    .replaceAll('ؤ', 'و')
    .replaceAll('ئ', 'ي')
    .replaceAll('ء', '')
    .replaceAll('ک', 'ك')
    .replaceAll(_arapDisi, '');

/// Uzatma harfleri (ا و ي) atılmış iskelet: Osmanlı hattı ile imlâ farklarını tolere eder.
String skel(String n) => n.replaceAll(_sesliHarf, '');

int lev(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var p = List<int>.generate(b.length + 1, (j) => j);
  for (var i = 1; i <= a.length; i++) {
    final q = List<int>.filled(b.length + 1, 0);
    q[0] = i;
    for (var j = 1; j <= b.length; j++) {
      q[j] = math.min(math.min(p[j] + 1, q[j - 1] + 1), p[j - 1] + (a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1));
    }
    p = q;
  }
  return p[b.length];
}

double rat(String a, String b) {
  final l = math.max(a.length, b.length);
  return l == 0 ? 0 : 1 - lev(a, b) / l;
}

/// Duyulan (normalize edilmiş) [h] ile beklenen kelimenin benzerliği (0–1).
double sim(String h, Kelime w) {
  var r = rat(h, w.n);
  if (w.k.length >= 2) {
    final k = skel(h);
    if (k.length >= 2) r = math.max(r, rat(k, w.k) * .97);
  }
  return r;
}

const muqattaat = {'الم', 'المص', 'الر', 'المر', 'كهيعص', 'طه', 'طسم', 'طس', 'يس', 'ص', 'حم', 'عسق', 'ق', 'ن'};
const harfAdlari = {
  'الف', 'لام', 'ميم', 'صاد', 'را', 'راء', 'كاف', 'ها', 'هاء', 'يا', 'ياء', 'عين', 'طا', 'طاء', 'سين', 'حا', 'حاء',
  'قاف', 'نون', 'ر', 'م', 'ل'
};
const girisKelimeleri = {'اعوذ', 'بالله', 'من', 'الشيطان', 'الرجيم', 'بسم', 'الله', 'الرحمن', 'الرحيم'};

/// Kelime durumu: 0 gizli, 1 doğru, 2 hatalı, 3 atlandı, 4 ipucu.
class KD {
  static const gizli = 0, dogru = 1, hata = 2, atla = 3, ipucu = 4;
}

class Kelime {
  Kelime({required this.li, required this.ai, required this.t, required this.n, this.muq = false, this.sureBasi = false}) : k = skel(n);
  /// Oturumdaki ayet sırası, genel ayet numarası (0–6235), mushaf yazımı, normalize yazım.
  final int li, ai;
  final String t, n;
  final String k;
  final bool muq;
  /// Surenin ilk ayetinin ilk kelimesi (öncesinde besmele okunabilir).
  final bool sureBasi;
  String pm = '';
  bool end = false;
  int st = KD.gizli;
  String h = '';
}

/// Ayetleri kelimelere böler. [metin]: ai → mushaf metni.
/// [liBas]: oturuma sonradan eklenen ayetler için ayet sırasının başlangıcı.
List<Kelime> kelimeler(List<int> ayetler, String Function(int ai) metin, int Function(int ai) ayetNo, {int liBas = 0}) {
  final w = <Kelime>[];
  for (var lj = 0; lj < ayetler.length; lj++) {
    final li = liBas + lj;
    final ai = ayetler[lj];
    final parca = metin(ai).split(' ');
    for (var wi = 0; wi < parca.length; wi++) {
      final x = parca[wi];
      if (x.isEmpty) continue;
      final n = nrm(x);
      if (n.isEmpty) {
        // durak işareti: önceki kelimeye eklenir
        if (w.isNotEmpty && w.last.li == li) w.last.pm = '${w.last.pm} $x'.trim();
        continue;
      }
      final muq = wi == 0 && ayetNo(ai) <= 2 && muqattaat.contains(n) && (x.contains('ٓ') || n == 'طه' || n == 'يس');
      final ilk = w.isEmpty || w.last.li != li;
      w.add(Kelime(li: li, ai: ai, t: x, n: n, muq: muq, sureBasi: ilk && ayetNo(ai) == 1));
    }
  }
  for (var i = 0; i < w.length; i++) {
    if (i == w.length - 1 || w[i + 1].li != w[i].li) w[i].end = true;
  }
  return w;
}

/// Duyulan kelimeleri sıradaki beklenen kelimelerle eşleştirir.
class Eslestirici {
  Eslestirici(this.w);
  final List<Kelime> w;
  int cur = 0;
  String _buf = '', _lh = '';
  int _miss = 0, _mq = 0;

  bool get bitti => cur >= w.length;

  /// Duyulan kelimeyi işler; değişen kelimelerin dizinleri döner.
  /// Bir ayetin sonu geçilince o ayete %10 lafız toleransı uygulanır.
  List<int> besle(String raw) {
    final once = cur;
    final d = _besle(raw);
    for (var i = once; i < cur && i < w.length; i++) {
      if (w[i].end) d.addAll(lafizToleransi(w, w[i].li));
    }
    return d;
  }

  /// Henüz kesinleşmemiş (kısmi sonuçtaki son) kelimeyi dener: sıradaki kelimeye çok benziyorsa
  /// hemen doğru sayar, böylece ses tanımanın kelimeyi kesinleştirmesi beklenmez. Değişen dizinler
  /// ya da eşleşme yoksa null döner.
  List<int>? dene(String raw) {
    if (bitti) return null;
    final x = w[cur];
    if (x.muq) return null;
    final h = nrm(raw);
    if (h.length < 2) return null;
    final son = cur == w.length - 1;
    final esik = son ? .72 : .85;
    final aday = [h, if (_buf.isNotEmpty) _buf + h];
    if (!aday.any((a) => sim(a, x) >= esik)) return null;
    final once = cur;
    final d = <int>[];
    if (x.st == KD.gizli) {
      x.st = KD.dogru;
      x.h = raw;
      d.add(cur);
    }
    _buf = '';
    _miss = 0;
    _lh = '';
    cur++;
    for (var i = once; i < cur; i++) {
      if (w[i].end) d.addAll(lafizToleransi(w, w[i].li));
    }
    return d;
  }

  /// Okuma bitince (Bitir ya da son kelime): başlanmış her ayete toleransı uygular.
  /// Son ayette duyulmadan kalan kelimeler de tolerans içindeyse doğru sayılır.
  List<int> bitisToleransi() {
    final d = <int>[];
    final lis = <int>{for (final k in w) if (k.st != KD.gizli) k.li};
    for (final li in lis) {
      d.addAll(lafizToleransi(w, li));
    }
    if (d.isNotEmpty) {
      while (cur < w.length && w[cur].st != KD.gizli) {
        cur++;
      }
    }
    return d;
  }

  List<int> _besle(String raw) {
    final degisen = <int>[];
    if (bitti) return degisen;
    final h = nrm(raw);
    if (h.isEmpty) return degisen;
    final c = cur, x = w[c];
    void isaret(int i, int st, [String? duyulan]) {
      w[i].st = st;
      if (duyulan != null) w[i].h = duyulan;
      degisen.add(i);
    }

    void ilerle(int n) {
      cur = math.min(w.length, cur + n);
    }

    if (x.muq) {
      if (harfAdlari.contains(h) || sim(h, x) >= .7) {
        _mq++;
        if (sim(h, x) >= .7 || _mq >= x.n.length) {
          isaret(c, x.st == KD.ipucu ? KD.ipucu : KD.dogru, raw);
          _mq = 0;
          ilerle(1);
        }
        return degisen;
      }
      if (_mq > 0) {
        isaret(c, KD.dogru);
        _mq = 0;
        ilerle(1);
        degisen.addAll(besle(raw));
        return degisen;
      }
    }
    final aday = [h, if (_buf.isNotEmpty) _buf + h];
    // Son kelimede ses tanıma çoğu zaman kelimeyi yarım ya da vakıfla duyar: biraz daha hoşgörülü ol.
    final sonKelime = c == w.length - 1;
    for (final a in aday) {
      if (sim(a, x) >= (sonKelime ? .6 : .7) || (sonKelime && a.length >= 2 && x.n.startsWith(a) && a.length * 10 >= x.n.length * 6)) {
        if (x.st == KD.gizli) isaret(c, KD.dogru, raw);
        _buf = '';
        _miss = 0;
        _lh = '';
        ilerle(1);
        return degisen;
      }
    }
    // başta (ya da yeni sure başında) eûzü-besmele: yok say
    if ((c == 0 || x.sureBasi) && girisKelimeleri.contains(h)) return degisen;
    // atlanan kelimeler: ileride (en çok 3) eşleşme var mı
    for (var j = 1; j <= 3 && c + j < w.length; j++) {
      final y = w[c + j];
      if (y.n.length >= 2 && sim(h, y) >= .84) {
        for (var z = c; z < c + j; z++) {
          if (w[z].st == KD.gizli) {
            final yanlis = z == c && _miss > 0;
            isaret(z, yanlis ? KD.hata : KD.atla, yanlis ? _lh : '');
          }
        }
        isaret(c + j, KD.dogru, raw);
        _buf = '';
        _miss = 0;
        _lh = '';
        ilerle(j + 1);
        return degisen;
      }
    }
    // tekrar edilen önceki kelime: yok say
    if (c > 0 && sim(h, w[c - 1]) >= .8) {
      _buf = '';
      return degisen;
    }
    // kelimenin ilk parçası olabilir (ör. يا + ايها)
    if (_buf.isEmpty && x.n.startsWith(h) && h.length < x.n.length) {
      _buf = h;
      return degisen;
    }
    _buf = h;
    _miss++;
    if (_miss >= 2) {
      isaret(c, KD.hata, _lh.isNotEmpty ? '$_lh $raw' : raw);
      _miss = 0;
      _buf = '';
      _lh = '';
      ilerle(1);
    } else {
      _lh = raw;
    }
    return degisen;
  }

  void sifirlaTampon() {
    _buf = '';
    _miss = 0;
    _lh = '';
  }
}

/// Lafız toleransı oranı: ayetin harflerinin %10'una kadar hata, ayeti doğru saydırır.
const lafizTolerans = .10;

/// [li] sıradaki ayette hatalı / atlanan / duyulmayan harfler ayet harflerinin %10'unu
/// geçmiyorsa bu kelimeleri doğru sayar. İpucu alınan kelimeler olduğu gibi kalır.
/// Değişen dizinler döner.
List<int> lafizToleransi(List<Kelime> w, int li, {double oran = lafizTolerans}) {
  final ayet = [for (var i = 0; i < w.length; i++) if (w[i].li == li) i];
  if (ayet.isEmpty) return const [];
  var toplam = 0, yanlis = 0;
  final duzelecek = <int>[];
  for (final i in ayet) {
    final k = w[i];
    toplam += k.n.length;
    if (k.st == KD.dogru || k.st == KD.ipucu) continue;
    duzelecek.add(i);
    if (k.st == KD.hata && k.h.isNotEmpty) {
      // duyulana göre kaç harf yanlış
      var en = k.n.length;
      for (final p in k.h.split(' ')) {
        final hn = nrm(p);
        if (hn.isNotEmpty) en = math.min(en, lev(hn, k.n));
      }
      yanlis += en;
    } else {
      yanlis += k.n.length;
    }
  }
  if (duzelecek.isEmpty || toplam == 0 || yanlis > toplam * oran) return const [];
  for (final i in duzelecek) {
    w[i].st = KD.dogru;
  }
  return duzelecek;
}

/// Puan (0–100): ipucu yarım sayılır, gizli kalanlar sayılmaz.
int puan(Iterable<Kelime> ws) {
  var t = 0;
  var ok = 0.0;
  for (final w in ws) {
    if (w.st == KD.gizli) continue;
    t++;
    if (w.st == KD.dogru) ok += 1;
    if (w.st == KD.ipucu) ok += .5;
  }
  return t == 0 ? 0 : (ok / t * 100).round();
}

String arapRakam(int n) => n.toString().split('').map((d) => '٠١٢٣٤٥٦٧٨٩'[int.parse(d)]).join();
