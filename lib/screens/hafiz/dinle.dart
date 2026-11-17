import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../hafiz/arapca.dart';
import '../../hafiz/kayit.dart';
import '../../hafiz/kuran.dart';
import '../../services/settings_service.dart';
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
  ('Abdurrahmaan_As-Sudais_192kbps', 'Abdurrahman es-Sudeys'),
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

  String get _kari => SettingsService.prefs.getString('hfKari') ?? kariler.first.$1;

  @override
  void initState() {
    super.initState();
    _sub = _p.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) _bitti();
    });
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

  String _url(int ai, {bool besmele = false}) {
    final a = besmele ? (1, 1) : (Kuran.a[ai].s, Kuran.a[ai].n);
    String u(int n) => n.toString().padLeft(3, '0');
    return 'https://everyayah.com/data/$_kari/${u(a.$1)}${u(a.$2)}.mp3';
  }

  Future<void> _cal() async {
    _t?.cancel();
    setState(() => _bekleMetin = '');
    final ai = widget.ayetler[_i];
    final a = Kuran.a[ai];
    _besmeleCaliyor = _r == 0 && a.n == 1 && a.s != 1 && a.s != 9 && !_besmeleBitti;
    try {
      await _p.setUrl(_url(ai, besmele: _besmeleCaliyor));
      await _p.setSpeed(_hiz);
      setState(() => _calar = true);
      _kaydir();
      await _p.play();
    } catch (_) {
      if (mounted) {
        setState(() => _calar = false);
        showSnack(context, 'Ses yüklenemedi. İnternet bağlantını kontrol et.');
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
                      setState(() {});
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
              for (var i = 0; i < widget.ayetler.length; i++) _ayet(i),
              const SizedBox(height: 8),
              Text('Sesler everyayah.com\'dan çalınır; internet gerekir.',
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
