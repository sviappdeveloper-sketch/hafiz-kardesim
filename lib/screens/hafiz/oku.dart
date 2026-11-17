import 'package:flutter/material.dart';

import '../../hafiz/arapca.dart';
import '../../hafiz/kayit.dart';
import '../../hafiz/kuran.dart';
import '../../hafiz/ses.dart';
import '../../hafiz/yedek.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/ornaments.dart';
import 'ortak.dart';
import 'sonuc.dart';

/// Ezber dinletme: [mod] "ses" (uygulama dinler) ya da "kardes" (yanındaki arkadaş işaretler).
class OkuEkrani extends StatefulWidget {
  const OkuEkrani({super.key, required this.ayetler, required this.mod});
  final List<int> ayetler;
  final String mod;

  @override
  State<OkuEkrani> createState() => _OkuEkraniState();
}

class _OkuEkraniState extends State<OkuEkrani> {
  late final List<Kelime> _w;
  late final Eslestirici _e;
  late final List<GlobalKey> _keys;
  final _t0 = DateTime.now();
  String _duyulan = '';
  bool _bitti = false;
  final List<(int, int, int)> _gecmis = []; // geri almak için: (dizin, eski durum, eski cur)

  bool get _ses => widget.mod == 'ses';

  @override
  void initState() {
    super.initState();
    _w = kelimeler(widget.ayetler, (ai) => Kuran.a[ai].metin, (ai) => Kuran.a[ai].n);
    _e = Eslestirici(_w);
    _keys = List.generate(_w.length, (_) => GlobalKey());
    Ses.acik.addListener(_yenile);
  }

  @override
  void dispose() {
    Ses.acik.removeListener(_yenile);
    Ses.durdur();
    super.dispose();
  }

  void _yenile() {
    if (mounted) setState(() {});
  }

  void _kaydir() {
    if (_e.cur >= _w.length) return;
    final c = _keys[_e.cur].currentContext;
    if (c != null) {
      Scrollable.ensureVisible(c, alignment: .35, duration: const Duration(milliseconds: 250));
    }
  }

  void _sonra() {
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _kaydir());
    if (_e.bitti && !_bitti) {
      Ses.durdur();
      Future.delayed(const Duration(milliseconds: 600), _bitir);
    }
  }

  Future<void> _mikrofon() async {
    if (Ses.acik.value) {
      await Ses.durdur();
      return;
    }
    final ok = await Ses.baslat(
      kelime: (k) {
        if (!mounted) return;
        final once = _e.cur;
        final d = _e.besle(k);
        if (d.isNotEmpty || _e.cur != once) {
          for (final i in d) {
            _gecmis.add((i, KD.gizli, once));
          }
          _sonra();
        }
      },
      canli: (m) {
        if (mounted) setState(() => _duyulan = m.split(' ').reversed.take(8).toList().reversed.join(' '));
      },
      hata: (h) {
        if (mounted) showSnack(context, Ses.hataMetni(h));
      },
    );
    if (ok && mounted) showSnack(context, 'Dinliyorum… okumaya başla');
  }

  void _isaretle(int st) {
    if (_e.bitti) return;
    final i = _e.cur;
    _gecmis.add((i, _w[i].st, i));
    _w[i].st = st;
    _e.cur++;
    _e.sifirlaTampon();
    _sonra();
  }

  void _ayetiAc({bool dogru = false}) {
    if (_e.bitti) return;
    final li = _w[_e.cur].li;
    while (!_e.bitti && _w[_e.cur].li == li) {
      _gecmis.add((_e.cur, _w[_e.cur].st, _e.cur));
      _w[_e.cur].st = dogru ? KD.dogru : KD.ipucu;
      _e.cur++;
    }
    _e.sifirlaTampon();
    _sonra();
  }

  void _geriAl() {
    if (_gecmis.isEmpty) return;
    final g = _gecmis.removeLast();
    _w[g.$1].st = g.$2;
    _e.cur = g.$3;
    _e.sifirlaTampon();
    _sonra();
  }

  Future<void> _kelimeDokun(int i) async {
    final k = _w[i];
    if (k.st == KD.gizli) {
      if (i == _e.cur) {
        _isaretle(KD.ipucu);
        return;
      }
      await showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.ink,
        builder: (c) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(k.t, style: arapYazi(36, color: AppColors.goldLight)),
              Text('Bu kelimeye henüz gelmedin. Bakmak ezberin için iyi olmaz 🙂',
                  textAlign: TextAlign.center, style: AppText.body(13, color: AppColors.muted)),
            ]),
          ),
        ),
      );
      return;
    }
    final yeni = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.ink,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(k.t, style: arapYazi(38, color: AppColors.goldLight)),
            Text(Kuran.etiket(k.ai), style: AppText.body(13, color: AppColors.muted)),
            if (k.h.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Duyulan: ${k.h}', textDirection: TextDirection.rtl, style: arapYazi(22, color: AppColors.muted)),
            ],
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: GoldButton(label: 'Doğru', icon: Icons.check, onPressed: () => Navigator.pop(c, KD.dogru))),
              const SizedBox(width: 10),
              Expanded(child: GoldButton(label: 'Hatalı', icon: Icons.close, outlined: true, onPressed: () => Navigator.pop(c, KD.hata))),
            ]),
          ]),
        ),
      ),
    );
    if (yeni != null) setState(() => k.st = yeni);
  }

  void _bitir() {
    if (_bitti || !mounted) return;
    Ses.durdur();
    if (!_w.any((k) => k.st != KD.gizli)) {
      Navigator.pop(context);
      return;
    }
    _bitti = true;
    final sn = DateTime.now().difference(_t0).inSeconds;
    final o = Kayit.i.oturumKaydet(tur: widget.mod, ayetler: widget.ayetler, w: _w, sureSn: sn);
    DriveYedek.otomatikYedekle();
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => SonucEkrani(oturum: o, w: _w, mod: widget.mod)));
  }

  Future<void> _ayarlar() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.ink,
      builder: (c) => StatefulBuilder(
        builder: (c, ss) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Görünüm', style: AppText.display(20)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Text('Yazı boyu', style: AppText.body(15))),
                IconButton(
                    onPressed: () async {
                      await HfAyar.setYazi(HfAyar.yazi - 2);
                      ss(() {});
                      _yenile();
                    },
                    icon: const Icon(Icons.text_decrease)),
                Text('${HfAyar.yazi.round()}', style: AppText.number(16)),
                IconButton(
                    onPressed: () async {
                      await HfAyar.setYazi(HfAyar.yazi + 2);
                      ss(() {});
                      _yenile();
                    },
                    icon: const Icon(Icons.text_increase)),
              ]),
              const SizedBox(height: 8),
              GizlemeSecici(onChanged: (_) => _yenile()),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final yuzde = _w.isEmpty ? 0.0 : _w.where((k) => k.st != KD.gizli).length / _w.length;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _bitir();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(Kuran.etiketListe(widget.ayetler)),
          actions: [IconButton(onPressed: _ayarlar, icon: const Icon(Icons.tune))],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(value: yuzde, minHeight: 4, color: AppColors.gold, backgroundColor: AppColors.inkLine),
          ),
        ),
        body: PatternBackground(
          child: Column(children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 40),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  MushafGorunum(
                    w: _w,
                    ayetler: widget.ayetler,
                    cur: _e.cur,
                    gizle: HfAyar.gizle,
                    anahtarlar: _keys,
                    onTap: _kelimeDokun,
                  ),
                  const SizedBox(height: 12),
                  const DurumAciklama(),
                ]),
              ),
            ),
            _alt(),
          ]),
        ),
      ),
    );
  }

  Widget _alt() {
    Widget kucuk(IconData ic, String t, VoidCallback f) => Expanded(
          child: TextButton(
            onPressed: f,
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(ic, color: AppColors.goldLight),
              const SizedBox(height: 2),
              Text(t, textAlign: TextAlign.center, style: AppText.body(11.5, color: AppColors.ivory, height: 1.1)),
            ]),
          ),
        );
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inkDeep.withValues(alpha: .97),
        border: Border(top: BorderSide(color: AppColors.gold.withValues(alpha: .25))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: _ses
              ? Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                    height: 30,
                    child: Text(_duyulan,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.rtl,
                        style: arapYazi(17, color: AppColors.muted).copyWith(height: 1.4)),
                  ),
                  Row(children: [
                    kucuk(Icons.lightbulb_outline, 'İpucu', () => _isaretle(KD.ipucu)),
                    kucuk(Icons.menu_book_outlined, 'Ayeti aç', _ayetiAc),
                    GestureDetector(
                      onTap: _mikrofon,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Ses.acik.value ? AppColors.danger : null,
                          gradient: Ses.acik.value ? null : LinearGradient(colors: [AppColors.goldLight, AppColors.gold]),
                          boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: .35), blurRadius: 14)],
                        ),
                        child: Icon(Ses.acik.value ? Icons.stop_rounded : Icons.mic_rounded, size: 34, color: AppColors.inkDeep),
                      ),
                    ),
                    kucuk(Icons.check_circle_outline, 'Doğru say', () => _isaretle(KD.dogru)),
                    kucuk(Icons.undo, 'Geri al', _geriAl),
                  ]),
                  TextButton.icon(onPressed: _bitir, icon: const Icon(Icons.flag_outlined), label: const Text('Bitir ve sonucu gör')),
                ])
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('Okuyan okusun, sen sıradaki kelimeyi işaretle.', style: AppText.body(12.5, color: AppColors.muted)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: _buyuk('✓ Doğru', AppColors.done, () => _isaretle(KD.dogru))),
                    const SizedBox(width: 8),
                    Expanded(child: _buyuk('✗ Hata', AppColors.danger, () => _isaretle(KD.hata))),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    kucuk(Icons.lightbulb_outline, 'Hatırlat', () => _isaretle(KD.ipucu)),
                    kucuk(Icons.done_all, 'Ayet doğru', () => _ayetiAc(dogru: true)),
                    kucuk(Icons.undo, 'Geri al', _geriAl),
                    kucuk(Icons.flag_outlined, 'Bitir', _bitir),
                  ]),
                ]),
        ),
      ),
    );
  }
}

Widget _buyuk(String t, Color c, VoidCallback f) => SizedBox(
      height: 54,
      child: FilledButton(
        style: FilledButton.styleFrom(backgroundColor: c, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        onPressed: f,
        child: Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
    );

/// Dışarıdan çağrılan kısa yollar.
void ezberAc(BuildContext context, List<int> ayetler, String mod) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => OkuEkrani(ayetler: ayetler, mod: mod)));
