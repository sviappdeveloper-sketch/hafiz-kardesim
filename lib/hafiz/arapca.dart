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

/// İskelet (uzatma harfleri atılmış) karşılaştırmasının ağırlığı. Kısa iskeletlerin uzunluğu farklıysa
/// aradaki fark bir ünsüz demektir (ör. والله / الصلوة): o zaman benzerlik daha az sayılır.
double _iskeletKatsayi(String a, String b) => a.length != b.length && math.min(a.length, b.length) <= 4 ? .97 * .9 : .97;

/// Duyulan (normalize edilmiş) [h] ile beklenen kelimenin benzerliği (0–1).
double sim(String h, Kelime w) {
  var r = rat(h, w.n);
  if (w.k.length >= 2) {
    final k = skel(h);
    if (k.length >= 2) r = math.max(r, rat(k, w.k) * _iskeletKatsayi(k, w.k));
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

/// Hafız Kardeşim eşleştiricisi: "onaylı ilerleme".
///
/// Duyulan kelime sıradaki kelimeyse hemen doğru sayılır. Değilse hiçbir kelime açılmaz, hata da
/// sayılmaz: duyulan kelime bekletilir. Okuyucunun ileride nerede olduğu ancak güçlü bir "çapa"
/// ile kesinleşince (art arda iki kelime ya da uzun, ayırt edici bir kelime) aradaki kelimeler
/// işlenir: bekleyenlerde karşılığı olan doğru, olmayan atlandı/hatalı sayılır.
/// Böylece ses tanımanın uydurduğu ya da yanlış duyduğu kelimeler okunmamış yeri açmaz,
/// okuyucu doğru okuduğu hâlde art arda hata yazılmaz.
class Eslestirici {
  Eslestirici(this.w);
  final List<Kelime> w;
  int cur = 0;
  String _buf = '';
  int _mq = 0;
  /// Yeri henüz bulunamayan duyulan kelimeler (normalize ve ham hâli).
  final List<String> _bek = [], _bekHam = [];

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
  /// hemen doğru sayar. Ses tanıma kısmi sonuçta kelimeyi tahminle tamamlayabildiği için yalnızca
  /// okuyucunun yeri kesinken ve benzerlik yüksekken kabul edilir. Eşleşme yoksa null döner.
  List<int>? dene(String raw) {
    if (bitti) return null;
    final x = w[cur];
    if (x.muq || _bek.isNotEmpty) return null;
    final h = nrm(raw);
    if (h.isEmpty) return null;
    final aday = [h, if (_buf.isNotEmpty) _buf + h];
    if (!aday.any((a) => _hemenUyar(a, x, cur == w.length - 1))) return null;
    final once = cur;
    final d = <int>[];
    if (x.st == KD.gizli) {
      x.st = KD.dogru;
      x.h = raw;
      d.add(cur);
    }
    sifirlaTampon();
    cur++;
    for (var i = once; i < cur; i++) {
      if (w[i].end) d.addAll(lafizToleransi(w, w[i].li));
    }
    return d;
  }

  /// Kısmi sonuçtaki kelime sıradaki kelime sayılabilir mi? Tarteel gibi, kelime söylenirken
  /// (ses tanıma onu daha yazarken) açılsın diye: kısa kelimeler tam, uzunlar yüksek benzerlik
  /// ya da kelimenin büyük bir baş kısmı duyulunca kabul edilir.
  static bool _hemenUyar(String a, Kelime x, bool son) {
    if (a.length < 3 || x.n.length < 3) return a == x.n || (a.length >= 2 && skel(a) == x.k && x.k.length >= 2);
    if (sim(a, x) >= (son ? .72 : .78)) return true;
    return a.length >= 3 && x.n.startsWith(a) && a.length * 10 >= x.n.length * 7;
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
          sifirlaTampon();
          ilerle(1);
        }
        return degisen;
      }
      if (_mq > 0) {
        isaret(c, KD.dogru);
        _mq = 0;
        sifirlaTampon();
        ilerle(1);
        degisen.addAll(besle(raw));
        return degisen;
      }
    }
    // 1) Sıradaki kelime.
    final aday = [h, if (_buf.isNotEmpty) _buf + h];
    // Son kelimede ses tanıma çoğu zaman kelimeyi yarım ya da vakıfla duyar: biraz daha hoşgörülü ol.
    final sonKelime = c == w.length - 1;
    for (final a in aday) {
      if (sim(a, x) >= (sonKelime ? .6 : .7) || (sonKelime && a.length >= 2 && x.n.startsWith(a) && a.length * 10 >= x.n.length * 6)) {
        if (x.st == KD.gizli) isaret(c, KD.dogru, raw);
        sifirlaTampon();
        ilerle(1);
        return degisen;
      }
    }
    // 2) İki kelime bitişik duyuldu (ör. "لله رب" → "للهرب").
    if (c + 1 < w.length && h.length >= 4 && simMetin(h, x.n + w[c + 1].n) >= .8) {
      if (x.st == KD.gizli) isaret(c, KD.dogru, raw);
      if (w[c + 1].st == KD.gizli) isaret(c + 1, KD.dogru, raw);
      sifirlaTampon();
      ilerle(2);
      return degisen;
    }
    // 3) Başta (ya da yeni sure başında) eûzü-besmele: yok say.
    if ((c == 0 || x.sureBasi) && girisKelimeleri.contains(h)) return degisen;
    // 4) Tekrar edilen önceki kelime (ileride de geçmiyorsa): yok say.
    var ileride = false;
    for (var j = 1; j <= 3 && c + j < w.length; j++) {
      if (sim(h, w[c + j]) >= .8) ileride = true;
    }
    if (!ileride) {
      for (var j = 1; j <= 3 && c - j >= 0; j++) {
        if (w[c - j].n.length >= 2 && sim(h, w[c - j]) >= .8) {
          _buf = '';
          return degisen;
        }
      }
    }
    // 5) Kelimenin ilk parçası olabilir (ör. يا + ايها).
    if (_buf.isEmpty && x.n.startsWith(h) && h.length < x.n.length) {
      _buf = h;
      return degisen;
    }
    // 6) Bekletilir; ileride güçlü bir çapa aranır.
    _buf = '';
    _bek.add(h);
    _bekHam.add(raw);
    if (_bek.length > 8) {
      _bek.removeAt(0);
      _bekHam.removeAt(0);
    }

    /// [bas, bit) arası kelimeler: çapadan önce duyulup karşılığı bulunanlar doğru,
    /// kalanların ilki (fazladan duyulan varsa) hatalı, diğerleri atlandı.
    void aradakiler(int bas, int bit, List<String> once) {
      final kalanDuyulan = List<String>.of(once);
      final kalan = <int>[];
      for (var z = bas; z < bit; z++) {
        var en = -1;
        var ep = 0.0;
        for (var m = 0; m < kalanDuyulan.length; m++) {
          final p = sim(nrm(kalanDuyulan[m]), w[z]);
          if (p > ep) {
            ep = p;
            en = m;
          }
        }
        if (en >= 0 && ep >= .7) {
          if (w[z].st == KD.gizli) isaret(z, KD.dogru, kalanDuyulan[en]);
          kalanDuyulan.removeAt(en);
        } else {
          kalan.add(z);
        }
      }
      for (var m = 0; m < kalan.length; m++) {
        final z = kalan[m];
        if (w[z].st != KD.gizli) continue;
        if (m == 0 && kalanDuyulan.isNotEmpty) {
          isaret(z, KD.hata, kalanDuyulan.join(' '));
        } else {
          isaret(z, KD.atla, '');
        }
      }
    }

    for (var j = 1; j <= 6 && c + j < w.length; j++) {
      final y = w[c + j];
      // Tek kelimelik çapa: yakında, uzun ve neredeyse aynı duyulmuş kelime.
      if (j <= 2 && y.n.length >= 5 && sim(h, y) >= .9) {
        aradakiler(c, c + j, _bekHam.sublist(0, _bekHam.length - 1));
        isaret(c + j, KD.dogru, raw);
        sifirlaTampon();
        cur = c + j + 1;
        return degisen;
      }
      // İki kelimelik çapa: son iki duyulan, art arda iki kelimeye uyuyor.
      if (_bek.length >= 2 && j >= 2) {
        final p = w[c + j - 1];
        if (sim(_bek[_bek.length - 2], p) >= .75 && sim(h, y) >= .75 && p.n.length + y.n.length >= 6) {
          final onceki = _bekHam[_bekHam.length - 2];
          aradakiler(c, c + j - 1, _bekHam.sublist(0, _bekHam.length - 2));
          isaret(c + j - 1, KD.dogru, onceki);
          isaret(c + j, KD.dogru, raw);
          sifirlaTampon();
          cur = c + j + 1;
          return degisen;
        }
      }
    }
    // 7) Yeniden yakalama: ses tanıma bir ayeti tümden kaçırdıysa ya da yanlış duyup takıldıysa
    // okuyucu çoktan ilerlemiştir. Daha ileride (birkaç ayet) art arda duyulan kelimeler metinde
    // aynı sırayla bulunursa oraya atlanır; yakın yerde iki, uzakta üç kelime uyması gerekir.
    final n = _bek.length;
    for (var j = 7; j <= 80 && c + j < w.length; j++) {
      final kac = j <= 30 ? 2 : 3;
      if (n < kac) break;
      var uyar = true, uzunluk = 0;
      for (var m = 0; m < kac; m++) {
        final y = w[c + j - m];
        final hm = _bek[n - 1 - m];
        if (hm.length < 2 || sim(hm, y) < .8) {
          uyar = false;
          break;
        }
        uzunluk += y.n.length;
      }
      if (!uyar || uzunluk < (kac == 2 ? 7 : 9)) continue;
      final bas = c + j - kac + 1;
      aradakiler(c, bas, _bekHam.sublist(0, n - kac));
      for (var m = 0; m < kac; m++) {
        isaret(bas + m, KD.dogru, _bekHam[n - kac + m]);
      }
      sifirlaTampon();
      cur = c + j + 1;
      return degisen;
    }
    return degisen;
  }

  void sifirlaTampon() {
    _buf = '';
    _bek.clear();
    _bekHam.clear();
    _kok = cur;
  }

  // ───────────── Kendi ses tanımamız (Kulak) için: bölüm hizalama ─────────────

  /// Dinlenen ses bölümünün başladığı kelime. Bölüm boyunca her çözümde duyulanların tamamı
  /// buradan itibaren metne yeniden hizalanır; bölüm bitince (nefes / durak) buraya [cur] yazılır.
  int _kok = 0;

  /// Bölümün o ana kadar duyulan kelimelerini ([duyulan], baştan sona) metne hizalar.
  ///
  /// * Okunmamış yer açılmaz: yalnızca güvenle eşleşen son kelimeye kadar ilerlenir.
  ///   Henüz söylenmekte olan son kelime ([kesin] değilse) ancak çok benzerse sayılır.
  /// * Son söylenene odaklanılır: geride duyulmadan kalan kelimeler, sonrası duyulunca tamamlanır
  ///   (kısa boşluk doğru sayılır, uzun bir atlama "atlandı" olur).
  /// * Bölüm içindeki kelimelerin durumu her çözümde yeniden değerlendirilir, böylece ses tanıma
  ///   sonradan düzeltirse ekrandaki işaret de düzelir.
  ///
  /// Yeni açılan (önceden gizli olan) kelimelerin dizinleri döner.
  List<int> bolum(List<String> duyulan, {required bool kesin}) {
    final yeni = <int>[];
    if (_kok > cur) _kok = cur;
    final h = _hazirla(duyulan);
    if (h.isEmpty || _kok >= w.length) {
      if (kesin) _kok = cur;
      return yeni;
    }
    final yol = hizalaBolum(h, w, _kok, sonKesin: kesin);
    if (yol.son > _kok) {
      for (var i = _kok; i < yol.son; i++) {
        final st = yol.durum[i - _kok];
        final k = w[i];
        if (k.st == KD.ipucu) continue;
        if (k.st == KD.gizli) yeni.add(i);
        k.st = st;
        k.h = yol.duyulan[i - _kok];
      }
      if (yol.son > cur) cur = yol.son;
      // Bölümde yeniden değerlendirilen ayetlere de lafız toleransı yeniden uygulanır.
      for (var i = _kok; i < cur && i < w.length; i++) {
        if (w[i].end) lafizToleransi(w, w[i].li);
      }
    }
    if (kesin) {
      _kok = cur;
      _buf = '';
      _bek.clear();
      _bekHam.clear();
    }
    return yeni;
  }

  /// Duyulanları normalleştirir; art arda harf adlarını (الف لام ميم) tek kelimeye toplar.
  List<String> _hazirla(List<String> d) {
    final h = <String>[];
    final ham = [for (final x in d) nrm(x)]..removeWhere((x) => x.isEmpty);
    var i = 0;
    while (i < ham.length) {
      if (harfAdlari.contains(ham[i])) {
        var j = i;
        while (j < ham.length && harfAdlari.contains(ham[j])) {
          j++;
        }
        if (j - i >= 2) {
          // Yakındaki mukattaa kelimesine çevrilir.
          final m = w.skip(_kok).take(12).where((k) => k.muq).firstOrNull;
          if (m != null) {
            h.add(m.n);
            i = j;
            continue;
          }
        }
      }
      h.add(ham[i]);
      i++;
    }
    return h;
  }
}

/// Bölüm hizalamasının sonucu: [son] kelimeye kadar (hariç) açılır; [durum] ve [duyulan]
/// kökten itibaren her kelimenin durumu ve karşısında duyulan.
class BolumYolu {
  BolumYolu(this.son, this.durum, this.duyulan);
  final int son;
  final List<int> durum;
  final List<String> duyulan;
}

/// Duyulan kelimeleri ([h], normalize) [kok]'ten başlayan metne hizalar (düzenleme uzaklığı).
/// Okuyucunun atladığı yerler ucuz, uydurulan kelimeler pahalıdır; sonda kalan metin bedavadır.
BolumYolu hizalaBolum(List<String> h, List<Kelime> w, int kok, {required bool sonKesin}) {
  final n = h.length;
  final l = math.min(w.length - kok, n * 2 + 40);
  const ekle = 1.0, silBas = .3, sil = .55;
  // Bölüm başında (sure başı) okunan eûzü-besmele neredeyse bedava atlanır.
  final girisSerbest = kok == 0 || w[kok].sureBasi;
  double degis(int i, int j) {
    final s = sim(h[i], w[kok + j]);
    if (s >= .75) return (1 - s) * .5;
    if (s >= .45) return .9;
    return 1.4;
  }

  final d = List.generate(n + 1, (_) => List<double>.filled(l + 1, 0));
  final g = List.generate(n + 1, (_) => List<int>.filled(l + 1, 0)); // 0 köşegen, 1 ekle, 2 sil
  // Hiçbir şey duyulmadan önceki atlama (okuyucu ileriden başladı) daha ucuz.
  for (var j = 1; j <= l; j++) {
    d[0][j] = j * silBas;
    g[0][j] = 2;
  }
  var girisBitti = !girisSerbest;
  for (var i = 1; i <= n; i++) {
    if (!girisKelimeleri.contains(h[i - 1])) girisBitti = true;
    final ek = girisBitti ? ekle : .1;
    d[i][0] = d[i - 1][0] + ek;
    g[i][0] = 1;
    for (var j = 1; j <= l; j++) {
      var en = d[i - 1][j - 1] + degis(i - 1, j - 1), yon = 0;
      final a = d[i - 1][j] + ek;
      if (a < en) {
        en = a;
        yon = 1;
      }
      final b = d[i][j - 1] + sil;
      if (b < en) {
        en = b;
        yon = 2;
      }
      d[i][j] = en;
      g[i][j] = yon;
    }
  }
  // Sonda kalan metin bedava: en düşük maliyetli bitiş (eşitlikte en yakın).
  var bj = 0;
  for (var j = 1; j <= l; j++) {
    if (d[n][j] < d[n][bj] - 1e-9) bj = j;
  }
  // Yolu geri izle.
  final esle = List<int>.filled(l, -1); // metin kelimesi → duyulan dizini
  var i = n, j = bj;
  while (i > 0 || j > 0) {
    final y = i == 0 ? 2 : (j == 0 ? 1 : g[i][j]);
    if (y == 0) {
      esle[j - 1] = i - 1;
      i--;
      j--;
    } else if (y == 1) {
      i--;
    } else {
      j--;
    }
  }
  // Güvenle eşleşen son kelime: açılacak yerin sonu. Söylenmekte olan son kelime daha sıkı.
  var son = 0;
  for (var k = 0; k < bj; k++) {
    final hi = esle[k];
    if (hi < 0) continue;
    final s = sim(h[hi], w[kok + k]);
    final esik = (!sonKesin && hi == n - 1) ? .85 : .75;
    if (s >= esik) son = k + 1;
  }
  // Son söylenene odaklan: duyulanların sonu hâlâ yerleşmediyse (ör. ses tanıma bir ayeti
  // kaçırdı, okuyucu ilerledi) son 2–3 duyulan kelime ileride art arda aranır ve oraya atlanır.
  var sonHi = -1;
  for (var k = 0; k < son; k++) {
    if (esle[k] > sonHi) sonHi = esle[k];
  }
  final kalanDuyulan = n - 1 - sonHi;
  int? atlaBas, atlaSon;
  for (final kac in const [3, 2]) {
    if (kalanDuyulan < 2 || kalanDuyulan < kac || atlaBas != null) continue;
    final sinir = math.min(w.length - kok, son + (kac == 2 ? 40 : 80));
    for (var p = son + kac - 1; p < sinir; p++) {
      var uyar = true, uzunluk = 0;
      for (var m = 0; m < kac; m++) {
        final hi = n - 1 - m;
        final esik = (!sonKesin && hi == n - 1) ? .85 : .8;
        if (h[hi].length < 2 || sim(h[hi], w[kok + p - m]) < esik) {
          uyar = false;
          break;
        }
        uzunluk += w[kok + p - m].n.length;
      }
      if (uyar && uzunluk >= (kac == 2 ? 7 : 9)) {
        atlaBas = p - kac + 1;
        atlaSon = p + 1;
        break;
      }
    }
  }
  final toplam = atlaSon ?? son;
  final durum = List<int>.filled(toplam, KD.dogru);
  final duyulan = List<String>.filled(toplam, '');
  var k = 0;
  while (k < son) {
    final hi = esle[k];
    if (hi >= 0) {
      final s = sim(h[hi], w[kok + k]);
      duyulan[k] = h[hi];
      durum[k] = s >= .75 ? KD.dogru : KD.hata;
      k++;
      continue;
    }
    // Duyulmayan kelimeler: kısa boşluk ses tanımanın kaçırmasıdır, tamamlanır; uzunsa atlanmıştır.
    // Bölümün başındaki boşluk (önceki bölümden geride kalan) bir ayet kadarsa tamamlanır.
    var e = k;
    while (e < son && esle[e] < 0) {
      e++;
    }
    final st = e - k <= (k == 0 ? 15 : 6) ? KD.dogru : KD.atla;
    for (var z = k; z < e; z++) {
      durum[z] = st;
    }
    k = e;
  }
  if (atlaBas != null && atlaSon != null) {
    // Aradaki kısım: bir ayet kadarsa ses tanımanın kaçırdığı sayılır (tamamlanır), daha uzunsa atlanmıştır.
    final a = atlaBas, b = atlaSon;
    for (var z = son; z < a; z++) {
      durum[z] = a - son <= 15 ? KD.dogru : KD.atla;
    }
    for (var m = 0; m < b - a; m++) {
      duyulan[a + m] = h[n - (b - a) + m];
    }
  }
  return BolumYolu(kok + toplam, durum, duyulan);
}

/// İki normalize yazımın benzerliği (iskelet karşılaştırması dahil).
double simMetin(String h, String n) {
  var r = rat(h, n);
  final k = skel(n), hk = skel(h);
  if (k.length >= 2 && hk.length >= 2) r = math.max(r, rat(hk, k) * _iskeletKatsayi(hk, k));
  return r;
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
