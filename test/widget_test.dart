import 'package:flutter_test/flutter_test.dart';
import 'package:hafiz_kardesim/hafiz/arapca.dart';

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
}
