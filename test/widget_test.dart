import 'package:flutter_test/flutter_test.dart';
import 'package:hafiz_kardesim/hafiz/arapca.dart';
import 'package:hafiz_kardesim/hafiz/ses.dart';

List<Kelime> _w(List<String> ayetler) =>
    kelimeler(List.generate(ayetler.length, (i) => i), (i) => ayetler[i], (i) => i + 1);

String _durum(List<Kelime> w) => w.map((k) => '.OEKH'[k.st]).join();

void main() {
  test('Normalleştirme: Osmanlı hattı ile imlâ aynı sayılır', () {
    expect(nrm('ٱلرَّحْمَٰنِ'), 'الرحمن');
    expect(nrm('ٱلصَّلَوٰةَ'), 'الصلوه');
    expect(sim('الصلاه', Kelime(li: 0, ai: 0, t: 'ٱلصَّلَوٰةَ', n: nrm('ٱلصَّلَوٰةَ'))) >= .7, isTrue);
  });

  test('Fâtiha doğru okununca bütün kelimeler doğru', () {
    final w = _w([
      'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
      'ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ',
      'ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
      'مَٰلِكِ يَوْمِ ٱلدِّينِ',
    ]);
    final e = Eslestirici(w);
    for (final k in 'اعوذ بالله من الشيطان الرجيم بسم الله الرحمن الرحيم الحمد لله رب العالمين الرحمن الرحيم مالك يوم الدين'.split(' ')) {
      e.besle(k);
    }
    expect(_durum(w), 'O' * w.length);
    expect(e.bitti, isTrue);
  });

  test('Atlanan ve yanlış kelime işaretlenir', () {
    final w = _w(['مَٰلِكِ يَوْمِ ٱلدِّينِ', 'إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ', 'ٱهْدِنَا ٱلصِّرَٰطَ ٱلْمُسْتَقِيمَ']);
    final e = Eslestirici(w);
    for (final k in 'مالك الدين اياك نعبد واياك نستغفر اهدنا الصراط المستقيم'.split(' ')) {
      e.besle(k);
    }
    expect(_durum(w), 'OKOOOOEOOO');
    expect(w[1].st, KD.atla);
    expect(w[6].st, KD.hata);
  });

  test('Hurûf-u mukattaa harf adlarıyla okunur', () {
    final w = _w(['الٓمٓ', 'ذَٰلِكَ ٱلْكِتَٰبُ لَا رَيْبَ ۛ فِيهِ ۛ هُدًۭى لِّلْمُتَّقِينَ']);
    final e = Eslestirici(w);
    for (final k in 'الف لام ميم ذلك الكتاب لا ريب فيه هدى للمتقين'.split(' ')) {
      e.besle(k);
    }
    expect(_durum(w), 'O' * w.length);
  });

  test('يا + ايها tek kelimeye eşleşir', () {
    final w = _w(['يَٰٓأَيُّهَا ٱلنَّاسُ ٱعْبُدُوا۟ رَبَّكُمُ']);
    final e = Eslestirici(w);
    for (final k in 'يا ايها الناس اعبدوا ربكم'.split(' ')) {
      e.besle(k);
    }
    expect(_durum(w), 'OOOO');
  });

  test('Lafız toleransı: ayetin %10\'u içindeki atlama doğru sayılır', () {
    final w = _w(['صِرَٰطَ ٱلَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ ٱلْمَغْضُوبِ عَلَيْهِمْ وَلَا ٱلضَّآلِّينَ']);
    final e = Eslestirici(w);
    for (final k in 'صراط الذين انعمت عليهم غير المغضوب عليهم الضالين'.split(' ')) {
      e.besle(k);
    }
    expect(_durum(w), 'O' * w.length);
    expect(e.bitti, isTrue);
  });

  test('Son kelime yarım duyulsa da doğru sayılır', () {
    final w = _w(['صِرَٰطَ ٱلَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ ٱلْمَغْضُوبِ عَلَيْهِمْ وَلَا ٱلضَّآلِّينَ']);
    final e = Eslestirici(w);
    for (final k in 'صراط الذين انعمت عليهم غير المغضوب عليهم ولا الضال'.split(' ')) {
      e.besle(k);
    }
    expect(_durum(w), 'O' * w.length);
    expect(e.bitti, isTrue);
  });

  test('Tolerans %10\'u aşan eksikleri doğru saymaz', () {
    final w = _w(['صِرَٰطَ ٱلَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ ٱلْمَغْضُوبِ عَلَيْهِمْ وَلَا ٱلضَّآلِّينَ']);
    final e = Eslestirici(w);
    for (final k in 'صراط الذين انعمت عليهم غير المغضوب عليهم ولا'.split(' ')) {
      e.besle(k);
    }
    e.bitisToleransi();
    expect(_durum(w), '${'O' * (w.length - 1)}.');
    expect(e.bitti, isFalse);
  });

  test('Sure geçişinde okunan besmele hata sayılmaz, sonraki sureyle devam edilir', () {
    final metin = ['وَٱلْعَصْرِ', 'قُلْ هُوَ ٱللَّهُ أَحَدٌ'];
    final w = kelimeler([0, 1], (i) => metin[i], (i) => i == 0 ? 3 : 1);
    final e = Eslestirici(w);
    for (final k in 'والعصر بسم الله الرحمن الرحيم قل هو الله احد'.split(' ')) {
      e.besle(k);
    }
    expect(_durum(w), 'O' * w.length);
    expect(e.bitti, isTrue);
  });

  test('Sonradan eklenen ayetler sırayı sürdürür', () {
    final w = _w(['قُلْ هُوَ ٱللَّهُ أَحَدٌ']);
    final e = Eslestirici(w);
    for (final k in 'قل هو الله'.split(' ')) {
      e.besle(k);
    }
    w.addAll(kelimeler([1], (i) => 'ٱللَّهُ ٱلصَّمَدُ', (i) => 2, liBas: 1));
    for (final k in 'احد الله الصمد'.split(' ')) {
      e.besle(k);
    }
    expect(_durum(w), 'O' * w.length);
    expect(w.last.li, 1);
    expect(e.bitti, isTrue);
  });

  test('Puan: ipucu yarım sayılır', () {
    final w = _w(['قُلْ هُوَ ٱللَّهُ أَحَدٌ']);
    w[0].st = KD.dogru;
    w[1].st = KD.dogru;
    w[2].st = KD.ipucu;
    w[3].st = KD.hata;
    expect(puan(w), 63);
  });

  test('Ses tanıma önceki kelimeleri birleştirse de yeni kelime kaybolmaz', () {
    // Gönderilen: الحمد لله رب ; tanıma "لله رب" yerine "للهرب" yazıp yeni kelimeyi ekledi.
    final g = ['الحمد', 'لله', 'رب'];
    expect(Ses.hizala(g, ['الحمد', 'لله', 'رب', 'العالمين']), 3);
    expect(Ses.hizala(g, ['الحمد', 'للهرب', 'العالمين']), 2);
    expect(Ses.hizala(g, ['الحمد', 'ل', 'له', 'رب', 'العالمين']), 4);
    expect(Ses.hizala(const [], ['بسم']), 0);
  });

  test('Kelime yazılırken baş tarafı duyulunca hemen açılır', () {
    final w = _w(['بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ']);
    final e = Eslestirici(w);
    for (final k in ['بسم', 'الله', 'الرحمن']) {
      e.besle(k);
    }
    expect(e.dene('الرحي'), isNotNull);
    expect(e.bitti, isTrue);
  });

  const bakara = [
    'ٱلَّذِينَ يُؤْمِنُونَ بِٱلْغَيْبِ وَيُقِيمُونَ ٱلصَّلَوٰةَ وَمِمَّا رَزَقْنَٰهُمْ يُنفِقُونَ',
    'وَٱلَّذِينَ يُؤْمِنُونَ بِمَآ أُنزِلَ إِلَيْكَ وَمَآ أُنزِلَ مِن قَبْلِكَ وَبِٱلْءَاخِرَةِ هُمْ يُوقِنُونَ',
  ];

  test('Ses tanımanın uydurduğu kelimeler okunmamış yeri açmaz', () {
    final w = _w(bakara);
    final e = Eslestirici(w);
    for (final k in 'الذين يؤمنون بالغيب ويقيمون كتاب سلام عظيم والله'.split(' ')) {
      e.besle(k);
    }
    expect(e.cur, 4);
    expect(w.skip(4).every((k) => k.st == KD.gizli), isTrue);
  });

  test('Araya karışan gürültü hata saydırmaz', () {
    final w = _w(bakara);
    final e = Eslestirici(w);
    for (final k in 'الذين يؤمنون كتاب بالغيب سلام ويقيمون الصلاه'.split(' ')) {
      e.besle(k);
    }
    expect(_durum(w).substring(0, 5), 'OOOOO');
    expect(w.skip(5).every((k) => k.st == KD.gizli), isTrue);
  });

  test('Yanlış okunan kelime, okumaya devam edilince hatalı sayılır', () {
    final w = _w(bakara);
    final e = Eslestirici(w);
    for (final k in 'الذين يؤمنون بالغيب ويقيمون الزكاه ومما رزقناهم'.split(' ')) {
      e.besle(k);
    }
    expect(_durum(w).substring(0, 7), 'OOOOEOO');
  });

  test('Tekrar okunan kelime ileride de geçiyorsa yer kaymaz', () {
    final w = _w(bakara);
    final e = Eslestirici(w);
    final okunan = 'الذين يؤمنون بالغيب ويقيمون الصلاه ومما رزقناهم ينفقون والذين يؤمنون بما انزل وما انزل من قبلك وبالاخره هم يوقنون';
    for (final k in okunan.split(' ')) {
      e.besle(k);
    }
    expect(w.every((k) => k.st == KD.dogru), isTrue);
    expect(e.bitti, isTrue);
  });

  const bakara1_6 = [
    'الٓمٓ',
    'ذَٰلِكَ ٱلْكِتَٰبُ لَا رَيْبَ ۛ فِيهِ ۛ هُدًۭى لِّلْمُتَّقِينَ',
    'ٱلَّذِينَ يُؤْمِنُونَ بِٱلْغَيْبِ وَيُقِيمُونَ ٱلصَّلَوٰةَ وَمِمَّا رَزَقْنَٰهُمْ يُنفِقُونَ',
    'وَٱلَّذِينَ يُؤْمِنُونَ بِمَآ أُنزِلَ إِلَيْكَ وَمَآ أُنزِلَ مِن قَبْلِكَ وَبِٱلْءَاخِرَةِ هُمْ يُوقِنُونَ',
    'أُو۟لَٰٓئِكَ عَلَىٰ هُدًۭى مِّن رَّبِّهِمْ ۖ وَأُو۟لَٰٓئِكَ هُمُ ٱلْمُفْلِحُونَ',
    'إِنَّ ٱلَّذِينَ كَفَرُوا۟ سَوَآءٌ عَلَيْهِمْ ءَأَنذَرْتَهُمْ أَمْ لَمْ تُنذِرْهُمْ لَا يُؤْمِنُونَ',
  ];

  test('Ses tanıma bir ayeti kaçırıp takılsa da okuyucu yeniden yakalanır (videodaki durum)', () {
    final w = _w(bakara1_6);
    final e = Eslestirici(w);
    // Telefondaki kayıtta duyulanlar: "وبالآخرة هم يوقنون" "قبلها يوم" diye duyuldu, 5. ayet hiç duyulmadı.
    const duyulan = 'الف لام ميم ذلك الكتاب لا ريب فيه هدى للمتقين الذين يؤمنون بالغيب ويقيمون الصلاه ومما رزقناهم '
        'ينفقون والذين يؤمنون بما انزل اليك وما انزل من قبلك قبلها يوم ان الذين كفروا سواء';
    for (final k in duyulan.split(' ')) {
      e.besle(k);
    }
    final kafaruu = w.indexWhere((k) => k.n == 'كفروا');
    expect(e.cur, kafaruu + 2, reason: 'takip "سواء" sonrasına gelmeli');
    expect(w[kafaruu].st, KD.dogru);
    // Takılmadan önce okunanlar doğru kalır.
    final qablik = w.indexWhere((k) => k.n == 'قبلك');
    expect(w.take(qablik + 1).every((k) => k.st == KD.dogru), isTrue);
  });

  test('Kelime söylenirken (yarısı duyulunca) hemen açılır', () {
    final w = _w(bakara);
    final e = Eslestirici(w);
    expect(e.dene('الذين'), isNotNull);
    expect(e.dene('يؤمنو'), isNotNull);
    expect(e.dene('بالغ'), isNull, reason: 'çok kısa parça bekletilir');
    expect(e.dene('بالغيب'), isNotNull);
    expect(e.cur, 3);
  });

  test('Uzaktaki tek benzer kelime yüzünden ileri atlanmaz', () {
    final w = _w(bakara1_6);
    final e = Eslestirici(w);
    for (final k in 'الف لام ميم ذلك الكتاب سلام الذين'.split(' ')) {
      e.besle(k);
    }
    expect(e.cur, 3);
    expect(w.skip(3).every((k) => k.st == KD.gizli), isTrue);
  });

  // ───── Kulak (kendi ses tanımamız): bölüm hizalama ─────
  List<String> _k(String m) => m.split(' ');

  test('Kulak: söylenmekte olan yarım kelime açılmaz, kelime bitince açılır', () {
    final w = _w(bakara1_6);
    final e = Eslestirici(w);
    e.bolum(_k('الم ذلك الكتاب لا ريب في'), kesin: false);
    expect(e.cur, 5);
    expect(w[5].st, KD.gizli);
    e.bolum(_k('الم ذلك الكتاب لا ريب فيه هدى'), kesin: false);
    expect(e.cur, 7);
    expect(_durum(w).substring(0, 7), 'OOOOOOO');
  });

  test('Kulak: bölümler art arda okununca hepsi doğru', () {
    final w = _w(bakara1_6);
    final e = Eslestirici(w);
    e.bolum(_k('بسم الله الرحمن الرحيم الم ذلك الكتب لا ريب فيه هدى للمتقين'), kesin: true);
    expect(e.cur, 8);
    e.bolum(_k('الذين يؤمنون بالغيب'), kesin: false);
    e.bolum(_k('الذين يؤمنون بالغيب ويقيمون الصلوة ومما رزقنهم ينفقون'), kesin: true);
    expect(e.cur, 16);
    expect(w.take(16).every((k) => k.st == KD.dogru), isTrue);
  });

  test('Kulak: gürültü okunmamış yeri açmaz', () {
    final w = _w(bakara1_6);
    final e = Eslestirici(w);
    e.bolum(_k('سلام عليكم ورحمه'), kesin: true);
    expect(e.cur, 0);
    e.bolum(_k('الم ذلك الكتاب سلام عليكم ورحمه الله'), kesin: true);
    expect(e.cur, 3);
    expect(w.skip(3).every((k) => k.st == KD.gizli), isTrue);
  });

  test('Kulak: geride kalan kısım, sonraki cümle söylenince tamamlanır', () {
    final w = _w(bakara1_6);
    final e = Eslestirici(w);
    e.bolum(_k('الم ذلك الكتاب لا ريب فيه هدى للمتقين الذين يؤمنون بالغيب ويقيمون الصلوة ومما رزقنهم ينفقون'), kesin: true);
    e.bolum(_k('والذين يؤمنون بما انزل اليك وما انزل من قبلك'), kesin: true);
    // 4. ayetin sonu ve 5. ayet duyulmadı; okuyucu 6. ayete geçti.
    e.bolum(_k('ان الذين كفروا سواء'), kesin: false);
    final kafaruu = w.indexWhere((k) => k.n == 'كفروا');
    expect(e.cur, kafaruu + 2);
    expect(w.take(kafaruu + 2).every((k) => k.st == KD.dogru), isTrue);
  });

  test('Kulak: kaçırılanları yanlış duyulan sözler arasından da bulur', () {
    final w = _w(bakara1_6);
    final e = Eslestirici(w);
    final bas = w.indexWhere((k) => k.n == 'والذين');
    e.cur = bas;
    e.sifirlaTampon();
    e.bolum(_k('والذين يؤمنون بما انزل اليك وما انزل من قبلك قبلها يوم ان الذين كفروا'), kesin: false);
    final kafaruu = w.indexWhere((k) => k.n == 'كفروا');
    expect(e.cur, kafaruu + 1);
  });

  test('Kulak: yanlış okunan kelime hatalı işaretlenir', () {
    final w = _w(bakara1_6);
    final e = Eslestirici(w);
    final bas = w.indexWhere((k) => k.n == 'الذين');
    e.cur = bas;
    e.sifirlaTampon();
    e.bolum(_k('الذين يؤمنون بالغيب ويقيمون الزكاه ومما رزقناهم'), kesin: true);
    expect(_durum(w).substring(bas, bas + 7), 'OOOOEOO');
  });
}
