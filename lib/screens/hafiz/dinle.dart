import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../hafiz/arapca.dart';
import '../../hafiz/ayet_ses.dart';
import '../../hafiz/kayit.dart';
import '../../hafiz/kuran.dart';
import '../../services/settings_service.dart';
import '../audio_quran_screen.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/ornaments.dart';
import 'ortak.dart';

const kariler = [
  ('Husary_Muallim_128kbps', 'Husarî – öğretici (muallim)'),
  ('Husary_128kbps', 'Mahmud Halil el-Husarî'),
  ('Minshawy_Murattal_128kbps', 'Muhammed Sıddık el-Minşâvî'),
  ('Alafasy_128kbps', 'Mişari Raşid el-Afâsî'),
  ('Abdul_Basit_Murattal_192kbps', 'Abdulbasıt Abdussamed'),
  ('MaherAlMuaiqly128kbps', 'Mâhir el-Muaykılî'),
  ('Ghamadi_40kbps', 'Saad el-Gâmidî'),
];

/// Ayet ayet dinleme: tekrar sayısı, bölüm tekrarı, hız, "ardından ben tekrar edeyim" beklemesi.
class DinleEkrani extends StatefulWidget {
  const DinleEkrani({super.key, required this.ayetler});
  final List<int> ayetler;
  @override
  State<DinleEkrani> createState() => _DinleEkraniState();
}

class _DinleEkraniState extends State<DinleEkrani> {
  final _p = AudioPlayer();
  StreamSubscription<PlayerState>? _sub;
  int _i = 0, _r = 0, _lp = 0;
  int _tekrar = 1, _bolum = 1;
  double _hiz = 1;
  bool _bekle = false, _gizle = false, _calar = false, _besmeleCaliyor = false, _besmeleBitti = false;
  String _bekleMetin = '';
  Timer? _t;
  List<String>? _meal;
  final _t0 = DateTime.now();
  final _keys = <int, GlobalKey>{};

  String get _kari {
    final k = SettingsService.prefs.getString('hfKari');
    return kariler.any((x) => x.$1 == k) ? k! : kariler.first.$1;
  }

  /// İndirme durumu: telefonda olmayan ayet sayısı, süren indirme ilerlemesi.
  int? _eksik;
  int? _iniyor;
  bool _iptal = false;

  List<(int, int)> get _liste => [
        for (final ai in widget.ayetler) (Kuran.a[ai].s, Kuran.a[ai].n),
        if (widget.ayetler.any((ai) => Kuran.a[ai].n == 1 && Kuran.a[ai].s != 1 && Kuran.a[ai].s != 9)) (1, 1),
      ];

  Future<void> _eksikHesapla() async {
    final n = await AyetSes.eksikSayisi(_kari, _liste);
    if (mounted) setState(() => _eksik = n);
  }

  Future<void> _indir() async {
    final l = _liste;
    _iptal = false;
    setState(() => _iniyor = 0);
    final hata = await AyetSes.indir(_kari, l, (n) {
      if (mounted) setState(() => _iniyor = n);
    }, iptal: () => _iptal || !mounted);
    if (!mounted) return;
    setState(() => _iniyor = null);
    await _eksikHesapla();
    if (!mounted) return;
    showSnack(context, hata == 0 ? 'Bu bölümün sesleri telefona indirildi, artık internetsiz çalar' : '$hata ayet indirilemedi. İnternet bağlantını kontrol et.');
  }

  @override
  void initState() {
    super.initState();
    _sub = _p.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) _bitti();
    });
    _eksikHesapla();
    if (HfAyar.meal) {
      Kuran.meal().then((m) {
        if (mounted) setState(() => _meal = m);
      });
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    _sub?.cancel();
    _p.dispose();
    final sn = DateTime.now().difference(_t0).inSeconds;
    if (sn > 20) {
      final l = widget.ayetler;
      Future.microtask(() => Kayit.i.dinlemeKaydet(l, sn));
    }
    super.dispose();
  }

  /// Ayetin telefondaki ses dosyası (yoksa indirilir, bir dahaki sefere internetsiz çalar).
  Future<String> _yol(int ai, {bool besmele = false}) async {
    final a = besmele ? (1, 1) : (Kuran.a[ai].s, Kuran.a[ai].n);
    final f = await AyetSes.getir(_kari, a.$1, a.$2);
    return f.path;
  }

  Future<void> _cal() async {
    _t?.cancel();
    setState(() => _bekleMetin = '');
    final ai = widget.ayetler[_i];
    final a = Kuran.a[ai];
    _besmeleCaliyor = _r == 0 && a.n == 1 && a.s != 1 && a.s != 9 && !_besmeleBitti;
    try {
      await _p.setFilePath(await _yol(ai, besmele: _besmeleCaliyor));
      if (_eksik != null && _eksik! > 0) _eksikHesapla();
      await _p.setSpeed(_hiz);
      setState(() => _calar = true);
      _kaydir();
      await _p.play();
    } catch (_) {
      if (mounted) {
        setState(() => _calar = false);
        showSnack(context, 'Bu ayetin sesi telefonda yok ve indirilemedi. İnternet bağlantını kontrol et.');
      }
    }
  }

  void _kaydir() {
    final c = _keys[_i]?.currentContext;
    if (c != null) Scrollable.ensureVisible(c, alignment: .3, duration: const Duration(milliseconds: 300));
  }

  void _bitti() {
    if (!_calar) return;
    if (_besmeleCaliyor) {
      _besmeleBitti = true;
      _cal();
      return;
    }
    void sonraki() {
      _r++;
      if (_r < _tekrar) {
        _cal();
        return;
      }
      _r = 0;
      _besmeleBitti = false;
      _i++;
      if (_i >= widget.ayetler.length) {
        _lp++;
        if (_bolum > 0 && _lp >= _bolum) {
          setState(() {
            _calar = false;
            _i = 0;
            _lp = 0;
          });
          showSnack(context, 'Dinleme bitti 🌿');
          return;
        }
        _i = 0;
      }
      _cal();
    }

    if (_bekle) {
      final ms = ((_p.duration?.inMilliseconds ?? 3000) * 1.15 / _hiz).round().clamp(1500, 60000);
      final son = DateTime.now().add(Duration(milliseconds: ms));
      void tik() {
        if (!_calar || !mounted) return;
        final k = son.difference(DateTime.now()).inMilliseconds;
        if (k <= 0) {
          setState(() => _bekleMetin = '');
          sonraki();
        } else {
          setState(() => _bekleMetin = '🗣️ Şimdi sen tekrarla… ${(k / 1000).ceil()}');
          _t = Timer(const Duration(milliseconds: 250), tik);
        }
      }

      tik();
    } else {
      sonraki();
    }
  }

  void _oynatDuraklat() {
    if (_calar) {
      _p.pause();
      _t?.cancel();
      setState(() => _calar = false);
    } else {
      _cal();
    }
  }

  void _git(int i) {
    _i = i.clamp(0, widget.ayetler.length - 1);
    _r = 0;
    _besmeleBitti = false;
    _cal();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dinle & Tekrarla')),
      body: PatternBackground(
        child: Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 30), children: [
              Text('${Kuran.etiketListe(widget.ayetler)} · ${widget.ayetler.length} ayet',
                  style: AppText.body(13, color: AppColors.muted)),
              const SizedBox(height: 8),
              OrnateCard(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                child: Column(children: [
                  _satir('Kâri', DropdownButton<String>(
                    value: _kari,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: [for (final k in kariler) DropdownMenuItem(value: k.$1, child: Text(k.$2, overflow: TextOverflow.ellipsis))],
                    onChanged: (v) async {
                      if (v == null) return;
                      await SettingsService.prefs.setString('hfKari', v);
                      setState(() => _eksik = null);
                      _eksikHesapla();
                      if (_calar) _cal();
                    },
                  )),
                  _satir('Her ayeti', _secim<int>(_tekrar, const [1, 2, 3, 5, 7, 10, 20], (v) => '$v kez', (v) => setState(() => _tekrar = v))),
                  _satir('Bütün bölümü', _secim<int>(_bolum, const [1, 2, 3, 5, 0], (v) => v == 0 ? 'Sürekli' : '$v kez', (v) => setState(() => _bolum = v))),
                  _satir('Okuma hızı', _secim<double>(_hiz, const [.75, 1, 1.25, 1.5], (v) => '${v}x', (v) {
                    setState(() => _hiz = v);
                    _p.setSpeed(v);
                  })),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _bekle,
                    onChanged: (v) => setState(() => _bekle = v),
                    title: Text('🗣️ Ardından ben tekrar edeyim', style: AppText.body(14)),
                    subtitle: Text('Her ayetten sonra senin okuman için bekler', style: AppText.body(12, color: AppColors.muted)),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _gizle,
                    onChanged: (v) => setState(() => _gizle = v),
                    title: Text('🙈 Metni gizle (dinleyerek ezber)', style: AppText.body(14)),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              _indirKarti(),
              const SizedBox(height: 8),
              for (var i = 0; i < widget.ayetler.length; i++) _ayet(i),
              const SizedBox(height: 8),
              OrnateCard(
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => AudioQuranScreen(startSurah: Kuran.a[widget.ayetler.first].s))),
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Icon(Icons.headphones_outlined, color: AppColors.goldLight),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Sure sure dinle', style: AppText.body(15, weight: FontWeight.w700)),
                      Text('Muhammed el-Fakîh, Mâhir el-Muaykılî, Saad el-Gâmidî ve Türkçe mealli (Hayrettin Küçükdeniz). Telefona indirilir.',
                          style: AppText.body(12, color: AppColors.muted)),
                    ]),
                  ),
                  Icon(Icons.chevron_right, color: AppColors.muted),
                ]),
              ),
              const SizedBox(height: 8),
              Text('Ayet sesleri everyayah.com\'dan bir kez indirilir, sonra telefondan çalar.',
                  textAlign: TextAlign.center, style: AppText.body(12, color: AppColors.muted)),
            ]),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.inkDeep.withValues(alpha: .97),
              border: Border(top: BorderSide(color: AppColors.gold.withValues(alpha: .25))),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (_bekleMetin.isNotEmpty)
                    Text(_bekleMetin, style: AppText.body(14, color: AppColors.goldLight, weight: FontWeight.w700)),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    IconButton(iconSize: 32, onPressed: () => _git(_i - 1), icon: const Icon(Icons.skip_previous_rounded)),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _oynatDuraklat,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [AppColors.goldLight, AppColors.gold])),
                        child: Icon(_calar ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 34, color: AppColors.inkDeep),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(iconSize: 32, onPressed: () => _git(_i + 1), icon: const Icon(Icons.skip_next_rounded)),
                  ]),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _indirKarti() {
    final top = _liste.length;
    final e = _eksik;
    final iniyor = _iniyor;
    final String metin;
    if (iniyor != null) {
      metin = 'İndiriliyor… $iniyor / $top';
    } else if (e == null) {
      metin = 'Telefondaki sesler kontrol ediliyor…';
    } else if (e == 0) {
      metin = '✓ Bu bölümün bütün sesleri telefonda (internetsiz çalar)';
    } else {
      metin = 'Telefonda ${top - e} / $top ayet sesi var';
    }
    return OrnateCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(e == 0 ? Icons.offline_pin_rounded : Icons.download_rounded, color: e == 0 ? AppColors.done : AppColors.goldLight),
          const SizedBox(width: 10),
          Expanded(child: Text(metin, style: AppText.body(13.5, weight: FontWeight.w600))),
          if (iniyor != null)
            TextButton(onPressed: () => _iptal = true, child: const Text('Durdur'))
          else if (e != null && e > 0)
            TextButton(onPressed: _indir, child: const Text('Telefona indir')),
        ]),
        if (iniyor != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: LinearProgressIndicator(value: top == 0 ? null : iniyor / top, color: AppColors.gold, backgroundColor: AppColors.inkLine),
          ),
      ]),
    );
  }

  Widget _satir(String t, Widget w) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(width: 110, child: Text(t, style: AppText.body(14))),
          Expanded(child: w),
        ]),
      );

  Widget _secim<T>(T v, List<T> l, String Function(T) ad, ValueChanged<T> f) => DropdownButton<T>(
        value: v,
        isExpanded: true,
        underline: const SizedBox(),
        items: [for (final x in l) DropdownMenuItem(value: x, child: Text(ad(x)))],
        onChanged: (x) {
          if (x != null) f(x);
        },
      );

  Widget _ayet(int i) {
    final ai = widget.ayetler[i];
    final a = Kuran.a[ai];
    final on = i == _i;
    return InkWell(
      key: _keys.putIfAbsent(i, () => GlobalKey()),
      onTap: () => _git(i),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: on ? AppColors.gold.withValues(alpha: .12) : AppColors.inkDeep.withValues(alpha: .3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: on ? AppColors.gold.withValues(alpha: .6) : AppColors.inkLine),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(Kuran.etiket(ai), style: AppText.body(11.5, color: AppColors.muted)),
          _gizle && !on
              ? Container(
                  height: 40,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(color: AppColors.inkLine, borderRadius: BorderRadius.circular(8)),
                  alignment: Alignment.center,
                  child: Text('gizli', style: AppText.body(12, color: AppColors.muted)),
                )
              : Text('${a.metin} ﴿${arapRakam(a.n)}﴾',
                  textDirection: TextDirection.rtl,
                  style: arapYazi(HfAyar.yazi * .9, color: _gizle ? AppColors.ivory.withValues(alpha: .15) : AppColors.ivory)),
          if (_meal != null && HfAyar.meal) Text(_meal![ai], style: AppText.body(13, color: AppColors.muted)),
        ]),
      ),
    );
  }
}
