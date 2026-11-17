import 'package:flutter/material.dart';

import '../../hafiz/arapca.dart';
import '../../hafiz/kuran.dart';
import '../../hafiz/ses.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/ornaments.dart';
import 'dinle.dart';
import 'oku.dart';
import 'ortak.dart';

/// Ayet arama dizini: her ayetin kelimeleri ve iskelet → ayetler.
class _Dizin {
  static List<List<Kelime>>? tok;
  static Map<String, List<int>> inv = {};
  static void kur() {
    if (tok != null) return;
    final t = <List<Kelime>>[];
    for (var i = 0; i < Kuran.a.length; i++) {
      final ws = <Kelime>[];
      final gor = <String>{};
      for (final x in Kuran.a[i].metin.split(' ')) {
        final n = nrm(x);
        if (n.isEmpty) continue;
        final k = Kelime(li: 0, ai: i, t: x, n: n);
        ws.add(k);
        final key = k.k.isNotEmpty ? k.k : n;
        if (gor.add(key)) (inv[key] ??= []).add(i);
      }
      t.add(ws);
    }
    tok = t;
  }
}

/// Okunan ya da yazılan birkaç kelimeden ayeti bulur.
List<int> ayetAra(String q) {
  _Dizin.kur();
  final ham = q.split(RegExp(r'\s+')).map(nrm).where((x) => x.isNotEmpty).toList();
  final Q = ham.length >= 4 ? ham.where((n) => !girisKelimeleri.contains(n)).toList() : ham;
  if (Q.isEmpty) return [];
  final cnt = <int, int>{};
  for (final n in Q) {
    final s = skel(n);
    final l = _Dizin.inv[s.isNotEmpty ? s : n] ?? const [];
    if (l.length > 1500) continue;
    for (final i in l) {
      cnt[i] = (cnt[i] ?? 0) + 1;
    }
  }
  final aday = cnt.keys.toList()..sort((a, b) => cnt[b]!.compareTo(cnt[a]!));
  final sonuc = <(int, double)>[];
  for (final i in aday.take(80)) {
    final T = _Dizin.tok![i];
    var best = 0;
    for (var s = 0; s < T.length; s++) {
      var run = 0, qi = 0, ti = s, miss = 0;
      while (qi < Q.length && ti < T.length) {
        if (sim(Q[qi], T[ti]) >= .72) {
          run++;
          qi++;
          ti++;
        } else if (miss < 2) {
          miss++;
          qi++;
        } else {
          break;
        }
      }
      if (run > best) best = run;
    }
    final sc = best + cnt[i]! * .1;
    if (sc >= (Q.length < 2 ? Q.length : 2)) sonuc.add((i, sc));
  }
  sonuc.sort((a, b) => b.$2.compareTo(a.$2));
  return sonuc.take(6).map((e) => e.$1).toList();
}

class BulEkrani extends StatefulWidget {
  const BulEkrani({super.key});
  @override
  State<BulEkrani> createState() => _BulEkraniState();
}

class _BulEkraniState extends State<BulEkrani> {
  final _c = TextEditingController();
  String _canli = '';
  List<int>? _r;

  @override
  void initState() {
    super.initState();
    Ses.acik.addListener(_yenile);
  }

  @override
  void dispose() {
    Ses.acik.removeListener(_yenile);
    Ses.durdur();
    _c.dispose();
    super.dispose();
  }

  void _yenile() {
    if (mounted) setState(() {});
  }

  void _ara(String q) {
    if (q.trim().isEmpty) return;
    setState(() => _r = ayetAra(q));
  }

  Future<void> _mik() async {
    if (Ses.acik.value) {
      await Ses.durdur();
      _ara(_canli);
      return;
    }
    _canli = '';
    await Ses.baslat(
      kelime: (_) {},
      canli: (m) {
        if (!mounted) return;
        setState(() => _canli = m);
        _c.text = m;
      },
      hata: (h) {
        if (mounted) showSnack(context, Ses.hataMetni(h));
      },
    );
    // Birkaç saniye sonra kendiliğinden arar.
    Future.delayed(const Duration(seconds: 7), () {
      if (mounted && Ses.acik.value) _mik();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sesle Bul')),
      body: PatternBackground(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
          OrnateCard(
            child: Column(children: [
              Text('Mikrofona dokun ve bir ayetten birkaç kelime oku. Hangi sure ve ayet olduğunu bulayım.',
                  textAlign: TextAlign.center, style: AppText.body(14, color: AppColors.muted)),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _mik,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Ses.acik.value ? AppColors.danger : null,
                    gradient: Ses.acik.value ? null : LinearGradient(colors: [AppColors.goldLight, AppColors.gold]),
                  ),
                  child: Icon(Ses.acik.value ? Icons.stop_rounded : Icons.mic_rounded, size: 36, color: AppColors.inkDeep),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _c,
                textDirection: TextDirection.rtl,
                style: arapYazi(20).copyWith(height: 1.4),
                decoration: InputDecoration(
                  hintText: 'ya da Arapça yaz…',
                  suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: () => _ara(_c.text)),
                ),
                onSubmitted: _ara,
              ),
            ]),
          ),
          if (_r != null && _r!.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text('Eşleşen ayet bulunamadı. Biraz daha uzun okumayı dene.',
                  textAlign: TextAlign.center, style: AppText.body(14, color: AppColors.muted)),
            ),
          if (_r != null && _r!.isNotEmpty) ...[
            const SectionTitle('Bulunanlar'),
            for (final i in _r!) ...[
              OrnateCard(
                highlight: i == _r!.first,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(child: Text('${i == _r!.first ? '🎯 ' : ''}${Kuran.etiket(i)}', style: AppText.body(15, weight: FontWeight.w700))),
                    Text('${Kuran.a[i].cuz}. cüz · s. ${Kuran.a[i].sayfa}', style: AppText.body(12, color: AppColors.muted)),
                  ]),
                  Text(Kuran.a[i].metin, textDirection: TextDirection.rtl, style: arapYazi(22)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    FilledButton.tonalIcon(
                        onPressed: () => ezberAc(context, [i], 'ses'), icon: const Icon(Icons.mic), label: const Text('Ezberle')),
                    FilledButton.tonalIcon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DinleEkrani(ayetler: [i]))),
                        icon: const Icon(Icons.headphones),
                        label: const Text('Dinle')),
                    FilledButton.tonalIcon(
                        onPressed: () {
                          final s = Kuran.a[i].s;
                          ezberAc(context, Kuran.aralik(i, Kuran.ix(s, Kuran.ayetSayisi(s))), 'ses');
                        },
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Buradan devam')),
                  ]),
                ]),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ]),
      ),
    );
  }
}
