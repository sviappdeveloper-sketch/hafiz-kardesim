import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:hafiz_kardesim/hafiz/arapca.dart';
import 'package:hafiz_kardesim/hafiz/fonem.dart';
import 'package:hafiz_kardesim/hafiz/kuran.dart';

String _durum(List<Kelime> w) => w.map((k) => '.OEKH'[k.st]).join();

/// Modelin duyacağı (boşluksuz) fonem dizisi: kelimelerin ham fonemleri art arda.
late List<List<String>> _ham;

String _ses(int ai, {int bas = 0, int? son}) {
  final a = _ham[ai];
  return a.sublist(bas, son ?? a.length).join();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final dosya = File('assets/asr/fonem.json');
  final veriVar = dosya.existsSync();

  setUpAll(() async {
    if (!veriVar) return;
    await Kuran.yukle();
    final m = dosya.readAsStringSync();
    Fonem.yukleMetin(m);
    // Ham (sadeleştirilmemiş) fonemler: test için ayrıca tutulur.
    _ham = [
      for (final a in jsonDecode(m) as List) [for (final k in a as List) k as String]
    ];
  });

  List<Kelime> oturum(List<int> ayetler) =>
      kelimeler(ayetler, (ai) => Kuran.a[ai].metin, (ai) => Kuran.a[ai].n);

  /// Sesi akan model gibi parça parça (3'er ses) verir; her adımda okunmamış kelime açılmamalı.
  void oku(Eslestirici e, List<Kelime> w, String ses) {
    for (var i = 3; i < ses.length; i += 3) {
      e.fonem(ses.substring(0, i), kesin: false);
    }
    e.fonem(ses, kesin: true);
  }

  test('Fonem verisi: her ayetin kelime sayısı uygulamanınkiyle aynı', () {
    expect(_ham.length, 6236);
    var farkli = 0;
    for (var ai = 0; ai < 6236; ai++) {
      final w = oturum([ai]);
      if (w.length != _ham[ai].length) farkli++;
      if (w.any((k) => Fonem.kelime(ai, k.wi).isEmpty)) farkli++;
    }
    expect(farkli, 0);
  }, skip: !veriVar);

  test('Fâtiha akan sesle doğru okunur, okunmamış yer açılmaz', () {
    final w = oturum(Kuran.aralik(0, 6));
    final e = Eslestirici(w);
    final ayetler = [for (var ai = 0; ai <= 6; ai++) _ses(ai)];
    // Her ayet ayrı nefes.
    var acikSiniri = 0;
    for (var ai = 0; ai <= 6; ai++) {
      final s = ayetler[ai];
      for (var i = 3; i < s.length; i += 3) {
        e.fonem(s.substring(0, i), kesin: false);
        // Açılan kelime sayısı, sesi tamamen geçilen kelimelerden fazla olamaz (+1 söylenen kelime).
        expect(e.cur <= acikSiniri + _gecilen(ai, i) + 1, isTrue, reason: 'ayet $ai, $i. ses: ileri atladı');
      }
      e.fonem(s, kesin: true);
      acikSiniri += _ham[ai].length;
      expect(e.cur, acikSiniri, reason: 'ayet $ai bitti: ${_durum(w)}');
    }
    expect(_durum(w), 'O' * w.length);
  }, skip: !veriVar);

  test('Sure başında eûzü-besmele okunması sorun olmaz (Bakara 1-5)', () {
    final b = Kuran.ix(2, 1);
    final w = oturum(Kuran.aralik(b, b + 4));
    final e = Eslestirici(w);
    const euzu = 'ءَعُوذُبِللَااهِمِنَششَيطَاانِررَجِيم';
    oku(e, w, euzu + _ses(0) + _ses(b));
    for (var ai = b + 1; ai <= b + 4; ai++) {
      oku(e, w, _ses(ai));
    }
    expect(_durum(w), 'O' * w.length);
  }, skip: !veriVar);

  test('Atlanan ayet "atlandı", yanlış okunan kelime "hatalı" olur', () {
    final w = oturum(Kuran.aralik(0, 6));
    final e = Eslestirici(w);
    oku(e, w, _ses(0) + _ses(1));
    oku(e, w, _ses(2));
    // 4. ayet (مالك يوم الدين) atlanır.
    oku(e, w, _ses(4));
    final d = _durum(w);
    final b3 = _ham[0].length + _ham[1].length + _ham[2].length;
    expect(d.substring(b3, b3 + 3), 'KKK', reason: d);
    expect(d.substring(b3 + 3, b3 + 3 + _ham[4].length), 'O' * _ham[4].length, reason: d);
    // 6. ayette ikinci kelime yerine başka bir kelime.
    oku(e, w, _ham[5][0] + 'سَمَااءَ' + _ham[5].sublist(2).join());
    final d2 = _durum(w);
    final b5 = b3 + 3 + _ham[4].length;
    expect(d2.substring(b5, b5 + 3), 'OEO', reason: d2);
  }, skip: !veriVar);

  test('Gürültülü (%4 ses hatası) okumada yanlış hata yazılmaz', () {
    final b = Kuran.ix(36, 1);
    final w = oturum(Kuran.aralik(b, b + 11));
    final e = Eslestirici(w);
    final r = math.Random(7);
    const harfler = 'بتثجحخدذرزسشصضطظعغفقكلمنهوي';
    for (var ai = b; ai <= b + 11; ai++) {
      final s = _ses(ai).split('').map((c) => r.nextDouble() < .04 ? harfler[r.nextInt(harfler.length)] : c).join();
      oku(e, w, s);
    }
    final d = _durum(w);
    expect('E'.allMatches(d).length + 'K'.allMatches(d).length <= 1, isTrue, reason: d);
    expect(e.bitti, isTrue, reason: d);
  }, skip: !veriVar);

  test('Ayet tekrar edilince ileri atlanmaz; tekrarla hata düzelir', () {
    final w = oturum(Kuran.aralik(0, 6));
    final e = Eslestirici(w);
    for (var ai = 0; ai <= 2; ai++) {
      oku(e, w, _ses(ai));
    }
    final n3 = _ham[0].length + _ham[1].length + _ham[2].length;
    // Aynı ayeti yeniden okumak yeni yer açmaz.
    oku(e, w, _ses(2));
    expect(e.cur, n3, reason: _durum(w));
    // Tekrar edip devam etmek: kaldığı yerden sürer.
    oku(e, w, _ses(2) + _ses(3));
    expect(e.cur, n3 + _ham[3].length, reason: _durum(w));
    // 5. ayette ikinci kelime yanlış okunur, sonra ayet doğru tekrar edilir: hata silinir.
    final b5 = e.cur;
    oku(e, w, _ham[4][0] + 'قَالُوا' + _ham[4].sublist(2).join());
    expect(w[b5 + 1].st, KD.hata, reason: _durum(w));
    oku(e, w, _ses(4));
    expect(w[b5 + 1].st, KD.dogru, reason: _durum(w));
    oku(e, w, _ses(5));
    expect(_durum(w).substring(0, e.cur), 'O' * e.cur);
  }, skip: !veriVar);

  test('Başka bir yerden okunan ayet okunmamış yeri açmaz', () {
    final b = Kuran.ix(2, 1);
    final w = oturum(Kuran.aralik(b, b + 4));
    final e = Eslestirici(w);
    oku(e, w, _ses(b));
    final c = e.cur;
    oku(e, w, _ses(Kuran.ix(1, 2))); // Fâtiha 2 okunuyor
    expect(e.cur, c, reason: _durum(w));
  }, skip: !veriVar);

  test('Seri (hadr) okuma: nefes almadan, yutulan harekeler ve kısa kelimelerle hata yazılmaz', () {
    final b = Kuran.ix(36, 1);
    final w = oturum(Kuran.aralik(b, b + 11));
    final e = Eslestirici(w);
    final r = math.Random(11);
    const hareke = 'َُِ';
    // Üçer ayet tek nefeste; harekelerin %25'i yutulur, her ayette kısa bir kelime hiç duyulmaz.
    for (var ai = b; ai <= b + 11; ai += 3) {
      final buf = StringBuffer();
      for (var a = ai; a < ai + 3 && a <= b + 11; a++) {
        final kel = _ham[a];
        final kisa = [for (var k = 1; k < kel.length - 1; k++) if (Fonem.sade(kel[k]).length <= 4) k];
        final yut = kisa.isEmpty ? -1 : kisa[r.nextInt(kisa.length)];
        for (var k = 0; k < kel.length; k++) {
          if (k == yut) continue;
          buf.write(kel[k].split('').where((c) => !(hareke.contains(c) && r.nextDouble() < .25)).join());
        }
      }
      oku(e, w, buf.toString());
    }
    final d = _durum(w);
    expect('E'.allMatches(d).length + 'K'.allMatches(d).length <= 1, isTrue, reason: d);
    expect(e.bitti, isTrue, reason: d);
  }, skip: !veriVar);

  test('Bozuk duyulan bölümden sonra takılmadan devam edilir (kuyruktan yakalama)', () {
    final b = Kuran.ix(2, 1);
    final w = oturum(Kuran.aralik(b, b + 6));
    final e = Eslestirici(w);
    oku(e, w, _ses(b) + _ses(b + 1));
    final r = math.Random(3);
    const harfler = 'بتثجحخدذرزسشصضطظعغفقكلمنهوي';
    final cop = List.generate(70, (_) => harfler[r.nextInt(harfler.length)]).join();
    final ses = cop + _ses(b + 2) + _ses(b + 3) + _ses(b + 4);
    // Nefes yok: hepsi ara sonuç. Sonda 4. ayet bitmiş olmalı (okunmamış yer açılmadan).
    for (var i = 3; i <= ses.length; i += 3) {
      e.fonem(ses.substring(0, i), kesin: false);
    }
    e.fonem(ses, kesin: false);
    final n4 = [for (var a = b; a <= b + 3; a++) _ham[a].length].reduce((x, y) => x + y);
    final n5 = n4 + _ham[b + 4].length;
    expect(e.cur >= n4, isTrue, reason: _durum(w));
    expect(e.cur <= n5, isTrue, reason: _durum(w));
  }, skip: !veriVar);
}

int _gecilen(int ai, int i) {
  var t = 0, k = 0;
  for (final x in _ham[ai]) {
    t += x.length;
    if (t <= i) k++;
  }
  return k;
}
