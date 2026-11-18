import 'dart:async';

import 'package:flutter/material.dart';

import '../../hafiz/arapca.dart';
import '../../hafiz/hoca_service.dart';
import '../../hafiz/kayit.dart';
import '../../hafiz/kuran.dart';
import '../../hafiz/ses.dart';
import '../../hafiz/yedek.dart';
import '../../models/models.dart';
import '../../services/settings_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/ornaments.dart';
import 'bildir.dart';
import 'ortak.dart';
import 'sonuc.dart';

/// Gelen ve süren canlı dinletme davetleri (ana sayfada ve hoca ekranında görünür).
class CanliDavetler extends StatelessWidget {
  const CanliDavetler({super.key, required this.me});
  final AppUser me;

  @override
  Widget build(BuildContext context) {
    if (me.isGuest) return const SizedBox();
    return StreamBuilder<List<Canli>>(
      stream: HocaService.canlilarim(me.id),
      builder: (context, s) {
        final l = s.data ?? const <Canli>[];
        if (l.isEmpty) return const SizedBox();
        return Column(children: [
          for (final c in l)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OrnateCard(
                highlight: true,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(_baslik(c), style: AppText.body(15, weight: FontWeight.w700, color: AppColors.goldLight)),
                  Text(Kuran.hazir ? Kuran.etiketListe(c.ayetler) : '', style: AppText.body(13, color: AppColors.muted)),
                  const SizedBox(height: 8),
                  if (c.durum == 'davet' && c.baslatan != me.id)
                    Row(children: [
                      Expanded(
                        child: GoldButton(
                          label: 'Katıl',
                          icon: Icons.login,
                          onPressed: () async {
                            final ok = await runGuarded(context, () => HocaService.katil(c.id));
                            if (ok && context.mounted) {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => CanliEkrani(id: c.id, me: me)));
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                          child: GoldButton(
                              label: 'Şimdi değil', outlined: true, onPressed: () => runGuarded(context, () => HocaService.reddet(c.id)))),
                    ])
                  else
                    GoldButton(
                      label: c.durum == 'aktif' ? 'Derse dön' : 'Aç',
                      icon: Icons.open_in_new,
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CanliEkrani(id: c.id, me: me))),
                    ),
                ]),
              ),
            ),
        ]);
      },
    );
  }

  String _baslik(Canli c) {
    final karsi = c.hoca == me.id ? c.ogrenci : c.hoca;
    final ad = c.ad(karsi);
    if (c.durum == 'aktif') return '🔴 $ad ile canlı ders sürüyor';
    if (c.baslatan == me.id) return '⏳ $ad\'ın katılması bekleniyor';
    return c.hoca == me.id ? '🎙️ $ad sana ezber dinletmek istiyor' : '🎙️ Hocan $ad seni dinlemek istiyor';
  }
}

/// Canlı dinletme: öğrenci ezberden okur (ayetler gizli), hoca kendi telefonunda metni görür ve işaretler.
/// Ses telefon ya da WhatsApp aramasıyla duyulur; uygulama işaretleri iki telefona anında taşır.
class CanliEkrani extends StatefulWidget {
  const CanliEkrani({super.key, required this.id, required this.me});
  final String id;
  final AppUser me;
  @override
  State<CanliEkrani> createState() => _CanliEkraniState();
}

class _CanliEkraniState extends State<CanliEkrani> {
  StreamSubscription<Canli?>? _sub;
  Canli? _c;
  List<Kelime>? _w;
  Eslestirici? _e;
  List<GlobalKey> _keys = [];
  bool _kaydedildi = false;
  final _not = TextEditingController();
  final _duyulanN = ValueNotifier<String>('');
  String get _duyulan => _duyulanN.value;
  Timer? _canliT;
  final Map<int, int> _bekleyenM = {};
  final Map<int, String> _bekleyenH = {};
  Timer? _yazT;
  int _sonCur = 0;

  bool get _hocayim => _c != null && _c!.hoca == widget.me.id;

  @override
  void initState() {
    super.initState();
    Ses.acik.addListener(_yenile);
    _sub = HocaService.canli(widget.id).listen(_geldi, onError: (e) {
      if (mounted) showSnack(context, errorText(e));
    });
  }

  @override
  void dispose() {
    Ses.acik.removeListener(_yenile);
    Ses.durdur(bosalt: false);
    _sub?.cancel();
    _canliT?.cancel();
    _yazT?.cancel();
    _not.dispose();
    super.dispose();
  }

  void _yenile() {
    if (mounted) setState(() {});
  }

  void _geldi(Canli? c) {
    if (!mounted) return;
    if (c == null) {
      if (!_kaydedildi) {
        showSnack(context, 'Ders kapandı');
        Navigator.pop(context);
      }
      return;
    }
    _c = c;
    if (_w == null) {
      _w = kelimeler(c.ayetler, (ai) => Kuran.a[ai].metin, (ai) => Kuran.a[ai].n);
      _e = Eslestirici(_w!);
      _keys = List.generate(_w!.length, (_) => GlobalKey());
      if (_not.text.isEmpty) _not.text = c.not;
    }
    final m = c.isaret, h = c.duyulan;
    for (var i = 0; i < _w!.length; i++) {
      if (_bekleyenM.containsKey(i)) continue;
      _w![i].st = m[i] ?? KD.gizli;
      if (h[i] != null) _w![i].h = h[i]!;
    }
    if (_bekleyenM.isEmpty) _e!.cur = c.cur.clamp(0, _w!.length);
    if (c.durum == 'bitti') _kaydet();
    if (c.durum == 'iptal') {
      showSnack(context, 'Davet kabul edilmedi');
      Navigator.pop(context);
      return;
    }
    setState(() {});
    if (_e!.cur != _sonCur) {
      _sonCur = _e!.cur;
      WidgetsBinding.instance.addPostFrameCallback((_) => _kaydir());
    }
  }

  void _kaydir() {
    if (_e == null || _e!.cur >= _keys.length) return;
    final c = _keys[_e!.cur].currentContext;
    if (c != null) Scrollable.ensureVisible(c, alignment: .35, duration: const Duration(milliseconds: 250));
  }

  void _yaz(Iterable<int> degisen, {String? duyulan}) {
    for (final i in degisen) {
      _bekleyenM[i] = _w![i].st;
      if (_w![i].h.isNotEmpty) _bekleyenH[i] = _w![i].h;
    }
    setState(() {});
    _yazT?.cancel();
    _yazT = Timer(const Duration(milliseconds: 250), () async {
      final m = Map<int, int>.from(_bekleyenM), h = Map<int, String>.from(_bekleyenH);
      _bekleyenM.clear();
      _bekleyenH.clear();
      try {
        await HocaService.isaretle(widget.id, m, h, _e!.cur);
      } catch (e) {
        if (mounted) showSnack(context, errorText(e));
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _kaydir());
  }

  // ---------- hoca işlemleri ----------
  void _isaretle(int st) {
    final e = _e!;
    if (e.bitti) return;
    final i = e.cur;
    _w![i].st = st;
    e.cur++;
    e.sifirlaTampon();
    _yaz([i]);
  }

  void _ayetDogru() {
    final e = _e!;
    if (e.bitti) return;
    final li = _w![e.cur].li, d = <int>[];
    while (!e.bitti && _w![e.cur].li == li) {
      _w![e.cur].st = KD.dogru;
      d.add(e.cur);
      e.cur++;
    }
    _yaz(d);
  }

  void _geriAl() {
    final e = _e!;
    if (e.cur <= 0) return;
    e.cur--;
    _w![e.cur].st = KD.gizli;
    _yaz([e.cur]);
  }

  Future<void> _dokun(int i) async {
    final k = _w![i];
    if (!_hocayim) {
      if (k.st == KD.gizli && i == _e!.cur) _isaretle(KD.ipucu);
      return;
    }
    final st = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.ink,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(k.t, style: arapYazi(36, color: AppColors.goldLight)),
            if (k.h.isNotEmpty) Text('Duyulan: ${k.h}', textDirection: TextDirection.rtl, style: arapYazi(20, color: AppColors.muted)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
              for (final x in const [(KD.dogru, 'Doğru'), (KD.hata, 'Hatalı'), (KD.ipucu, 'Hatırlattım'), (KD.atla, 'Atladı'), (KD.gizli, 'Okunmadı')])
                ChoiceChip(label: Text(x.$2), selected: k.st == x.$1, onSelected: (_) => Navigator.pop(c, x.$1)),
            ]),
          ]),
        ),
      ),
    );
    if (st == null) return;
    k.st = st;
    _yaz([i]);
  }

  // ---------- öğrenci: sesli tanıma ----------
  Future<void> _mikrofon() async {
    if (Ses.acik.value) {
      await Ses.durdur();
      return;
    }
    await Ses.baslat(
      kelime: (k) {
        if (!mounted || _e == null) return;
        final d = _e!.besle(k);
        if (d.isNotEmpty) _yaz(d);
      },
      dene: (k) {
        if (!mounted || _e == null) return false;
        final d = _e!.dene(k);
        if (d == null) return false;
        _yaz(d);
        return true;
      },
      canli: (m) {
        if (!mounted) return;
        _duyulanN.value = m.split(' ').reversed.take(8).toList().reversed.join(' ');
        _canliT ??= Timer(const Duration(milliseconds: 1500), () {
          _canliT = null;
          HocaService.isaretle(widget.id, const {}, const {}, _e!.cur, canli: _duyulan).catchError((_) {});
        });
      },
      hata: (h) {
        if (mounted) showSnack(context, Ses.hataMetni(h));
      },
    );
  }

  Future<void> _bitir() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Ders bitirilsin mi?'),
        content: const Text('Sonuç iki tarafın telefonundaki ders geçmişine kaydedilir.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Devam et')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Bitir')),
        ],
      ),
    );
    if (ok != true) return;
    await Ses.durdur();
    if (_hocayim && _not.text.trim() != _c!.not) await HocaService.notYaz(widget.id, _not.text.trim());
    if (!mounted) return;
    await runGuarded(context, () => HocaService.bitir(widget.id));
  }

  /// Ders bitince her iki telefon kendi geçmişine bir kez kaydeder.
  void _kaydet() {
    if (_kaydedildi || _w == null) return;
    _kaydedildi = true;
    final c = _c!;
    final anahtar = 'hfCanli_${c.id}';
    final p = SettingsService.prefs;
    final karsi = _hocayim ? c.ogrenci : c.hoca;
    final sure = c.baslangic == null ? 0 : DateTime.now().difference(c.baslangic!).inSeconds;
    Oturum? o;
    if (p.getBool(anahtar) != true) {
      p.setBool(anahtar, true);
      o = Kayit.i.oturumKaydet(
        tur: _hocayim ? 'ogrenci' : 'hocaya',
        ayetler: c.ayetler,
        w: _w!,
        sureSn: sure,
        srs: !_hocayim,
        kisi: c.ad(karsi),
        kisiUid: karsi,
        not: c.not,
      );
      DriveYedek.otomatikYedekle();
      if (_hocayim) HocaService.sonuYaz(c.hoca, c.ogrenci, Kuran.etiketListe(c.ayetler), o.puan).catchError((_) {});
    }
    // İki taraf da kaydettiyse oturum belgesi silinir (sunucuda ders kaydı tutulmaz).
    HocaService.canlilar.doc(c.id).update({'kaydetti.${widget.me.id}': true}).then((_) async {
      final d = await HocaService.canlilar.doc(c.id).get();
      final k = (d.data()?['kaydetti'] ?? const {}) as Map;
      if (k.length >= 2) await HocaService.sil(c.id);
    }).catchError((_) {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (o != null) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SonucEkrani(oturum: o!, gecmistenMi: true)));
      } else {
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null || _w == null) {
      return Scaffold(appBar: AppBar(title: const Text('Canlı ders')), body: const PatternBackground(child: LoadingView()));
    }
    final karsi = _hocayim ? c.ogrenci : c.hoca;
    if (c.durum == 'davet') {
      return Scaffold(
        appBar: AppBar(title: const Text('Canlı ders')),
        body: PatternBackground(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(
                  c.baslatan == widget.me.id ? '${c.ad(karsi)} davetini bekliyor…' : '${c.ad(karsi)} seni derse çağırıyor',
                  textAlign: TextAlign.center,
                  style: AppText.display(20),
                ),
                const SizedBox(height: 8),
                Text('${Kuran.etiketListe(c.ayetler)}\n\nSesi duymak için birbirinizi telefonla ya da WhatsApp\'tan arayın.',
                    textAlign: TextAlign.center, style: AppText.body(14, color: AppColors.muted)),
                const SizedBox(height: 20),
                if (c.baslatan == widget.me.id)
                  GoldButton(
                    label: 'Daveti geri al',
                    outlined: true,
                    onPressed: () async {
                      await runGuarded(context, () => HocaService.sil(c.id));
                    },
                  )
                else
                  GoldButton(label: 'Katıl', icon: Icons.login, onPressed: () => runGuarded(context, () => HocaService.katil(c.id))),
              ]),
            ),
          ),
        ),
      );
    }
    final yuzde = _w!.where((k) => k.st != KD.gizli).length / (_w!.isEmpty ? 1 : _w!.length);
    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_hocayim ? 'Öğrencim: ${c.ad(karsi)}' : 'Hocam: ${c.ad(karsi)}'),
          actions: [
            IconButton(
              tooltip: 'Suistimal bildir',
              onPressed: () => suistimalBildir(context, widget.me, karsi, c.ad(karsi)),
              icon: const Icon(Icons.flag_outlined),
            ),
            TextButton(onPressed: _bitir, child: const Text('Bitir')),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(value: yuzde, minHeight: 4, color: AppColors.gold, backgroundColor: AppColors.inkLine),
          ),
        ),
        body: PatternBackground(
          child: Column(children: [
            Container(
              width: double.infinity,
              color: AppColors.danger.withValues(alpha: .15),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Text(
                _hocayim
                    ? '🔴 Canlı · Metin sende açık, öğrencide gizli. Okudukça işaretle.'
                    : '🔴 Canlı · Hocan seni dinliyor ve işaretliyor.',
                style: AppText.body(12.5),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 30),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  MushafGorunum(
                    w: _w!,
                    ayetler: c.ayetler,
                    cur: _e!.cur,
                    gizle: c.gizle,
                    anahtarlar: _keys,
                    hepsiAcik: _hocayim,
                    onTap: _dokun,
                  ),
                  const SizedBox(height: 10),
                  const DurumAciklama(),
                  if (_hocayim) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: _not,
                      maxLines: 3,
                      decoration: const InputDecoration(hintText: 'Öğrencine not (ders bitince geçmişine yazılır)'),
                      onEditingComplete: () => HocaService.notYaz(widget.id, _not.text.trim()),
                    ),
                  ],
                ]),
              ),
            ),
            _hocayim ? _hocaAlt(c) : _ogrenciAlt(),
          ]),
        ),
      ),
    );
  }

  Widget _altKutu(Widget child) => Container(
        decoration: BoxDecoration(
          color: AppColors.inkDeep.withValues(alpha: .97),
          border: Border(top: BorderSide(color: AppColors.gold.withValues(alpha: .25))),
        ),
        child: SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(10, 8, 10, 8), child: child)),
      );

  Widget _hocaAlt(Canli c) => _altKutu(Column(mainAxisSize: MainAxisSize.min, children: [
        if (c.canliMetin.isNotEmpty)
          Text('Telefon duydu: ${c.canliMetin}',
              maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: TextDirection.rtl, style: arapYazi(16, color: AppColors.muted).copyWith(height: 1.4)),
        Row(children: [
          Expanded(child: _buyuk('✓ Doğru', AppColors.done, () => _isaretle(KD.dogru))),
          const SizedBox(width: 8),
          Expanded(child: _buyuk('✗ Hata', AppColors.danger, () => _isaretle(KD.hata))),
        ]),
        Row(children: [
          Expanded(child: TextButton.icon(onPressed: () => _isaretle(KD.ipucu), icon: const Icon(Icons.lightbulb_outline), label: const Text('Hatırlattım'))),
          Expanded(child: TextButton.icon(onPressed: _ayetDogru, icon: const Icon(Icons.done_all), label: const Text('Ayet doğru'))),
          IconButton(onPressed: _geriAl, icon: const Icon(Icons.undo)),
        ]),
      ]));

  Widget _ogrenciAlt() => _altKutu(Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          height: 28,
          child: ValueListenableBuilder<String>(
            valueListenable: _duyulanN,
            builder: (_, d, __) => Text(d,
                maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: TextDirection.rtl, style: arapYazi(16, color: AppColors.muted).copyWith(height: 1.4)),
          ),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextButton.icon(onPressed: () => _isaretle(KD.ipucu), icon: const Icon(Icons.lightbulb_outline), label: const Text('İpucu')),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _mikrofon,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Ses.acik.value ? AppColors.danger : null,
                gradient: Ses.acik.value ? null : LinearGradient(colors: [AppColors.goldLight, AppColors.gold]),
              ),
              child: Icon(Ses.acik.value ? Icons.stop_rounded : Icons.mic_rounded, size: 30, color: AppColors.inkDeep),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Mikrofon isteğe bağlı: açarsan telefonun da dinler, hocana yardımcı olur.',
                style: AppText.body(11.5, color: AppColors.muted)),
          ),
        ]),
      ]));
}

Widget _buyuk(String t, Color c, VoidCallback f) => SizedBox(
      height: 54,
      child: FilledButton(
        style: FilledButton.styleFrom(
            backgroundColor: c, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        onPressed: f,
        child: Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
    );
