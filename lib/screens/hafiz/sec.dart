import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../hafiz/kayit.dart';
import '../../hafiz/kuran.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ornaments.dart';
import 'ortak.dart';

/// Ezberlenecek / dinlenecek bölümü seçme: sure (ayet aralığı), cüz ya da sayfa.
class SecEkrani extends StatefulWidget {
  const SecEkrani({super.key, required this.baslik, required this.onSec, this.gizlemeSor = true, this.dugme = 'Başla'});
  final String baslik;
  final bool gizlemeSor;
  final String dugme;
  final void Function(BuildContext context, List<int> ayetler) onSec;

  @override
  State<SecEkrani> createState() => _SecEkraniState();
}

class _SecEkraniState extends State<SecEkrani> {
  int _sekme = 0;
  String _ara = '';
  /// Son açılan sure / cüz (listede işaretli görünür).
  int? _s;
  int? _cuz;
  int _p1 = 1, _p2 = 1;

  /// Sure ya da cüz seçilince doğrudan ayrıntı sayfasına geçilir: aralık, gizleme ve "Başla" orada.
  /// (Eskiden seçim kartı listenin en üstünde kalıyordu; aşağıda seçen kişi yukarı çıkmak zorundaydı.)
  void _sure(int s) {
    setState(() => _s = s);
    _detay(_SureDetay(sure: s, ust: widget));
  }

  void _cuzAc(int c) {
    setState(() => _cuz = c);
    _detay(_CuzDetay(cuz: c, ust: widget));
  }

  void _detay(Widget w) => Navigator.push(
      context, MaterialPageRoute(settings: const RouteSettings(name: secDetayRota), builder: (_) => w));

  void _git(List<int> l) {
    if (l.isEmpty) return;
    widget.onSec(context, l);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.baslik)),
      body: PatternBackground(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Sure')),
                ButtonSegment(value: 1, label: Text('Cüz')),
                ButtonSegment(value: 2, label: Text('Sayfa')),
              ],
              selected: {_sekme},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _sekme = s.first),
            ),
          ),
          Expanded(child: [_sureSekme, _cuzSekme, _sayfaSekme][_sekme]()),
        ]),
      ),
    );
  }

  Widget _sureSekme() {
    final q = trSade(_ara);
    final k = Kayit.i;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 30), children: [
      TextField(
        decoration: const InputDecoration(hintText: 'Sure ara (ör. yasin, mülk, 36) · dokununca ayrıntılar açılır', prefixIcon: Icon(Icons.search)),
        onChanged: (v) => setState(() => _ara = v),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 4, children: [
        for (final x in const [(1, 'Fâtiha'), (36, 'Yâsîn'), (67, 'Mülk'), (18, 'Kehf'), (55, 'Rahmân'), (78, "Nebe'")])
          ActionChip(label: Text(x.$2), onPressed: () => _sure(x.$1)),
        ActionChip(label: const Text('Âyete\'l-Kürsî'), onPressed: () => _git([Kuran.ix(2, 255)])),
        ActionChip(label: const Text('Âmenerrasûlü'), onPressed: () => _git(Kuran.aralik(Kuran.ix(2, 285), Kuran.ix(2, 286)))),
      ]),
      const SizedBox(height: 8),
      for (var s = 1; s <= 114; s++)
        if (q.isEmpty || trSade(Kuran.ad(s)).contains(q) || '$s' == q) _sureSatir(s),
    ]);
  }

  Widget _sureSatir(int s) {
    final p = Kayit.i.sureOrani(s);
    return InkWell(
      onTap: () => _sure(s),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: _s == s ? AppColors.gold.withValues(alpha: .12) : null,
          borderRadius: BorderRadius.circular(12),
          border: Border(bottom: BorderSide(color: AppColors.inkLine)),
        ),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.gold.withValues(alpha: .5))),
            child: Text('$s', style: AppText.number(13, color: AppColors.goldLight)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(Kuran.ad(s), style: AppText.body(15, weight: FontWeight.w700)),
              Text('${Kuran.ayetSayisi(s)} ayet${p > 0 ? ' · %${(p * 100).round()} ezber' : ''}',
                  style: AppText.body(12, color: AppColors.muted)),
              if (p > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4, right: 30),
                  child: LinearProgressIndicator(value: p, minHeight: 4, color: AppColors.gold, backgroundColor: AppColors.inkLine),
                ),
            ]),
          ),
          Text(Kuran.arapAd(s), style: arapYazi(20, color: AppColors.gold)),
        ]),
      ),
    );
  }

  Widget _cuzSekme() {
    final k = Kayit.i;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 30), children: [
      Text('Altındaki çizgi o cüzdeki ezber oranını gösterir.', style: AppText.body(13, color: AppColors.muted)),
      const SizedBox(height: 8),
      GridView.count(
        crossAxisCount: 5,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: [
          for (var c = 1; c <= 30; c++)
            Builder(builder: (_) {
              final l = Kuran.cuz(c);
              final p = l.where(k.ezber).length / l.length;
              return InkWell(
                onTap: () => _cuzAc(c),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: _cuz == c ? AppColors.gold.withValues(alpha: .25) : AppColors.inkDeep.withValues(alpha: .45),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.inkLine),
                  ),
                  child: Stack(children: [
                    Center(child: Text('$c', style: AppText.number(18))),
                    Positioned(
                        left: 0, right: 0, bottom: 0,
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: p,
                          child: Container(height: 4, color: AppColors.gold),
                        )),
                  ]),
                ),
              );
            }),
        ],
      ),
    ]);
  }

  Widget _sayfaSekme() {
    final l = _p2 >= _p1 ? Kuran.sayfalar(_p1, _p2) : <int>[];
    return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 30), children: [
      Text('Medine mushafı sayfa numarası (1–604). Hafızlar genelde sayfa sayfa ezberler.',
          style: AppText.body(13, color: AppColors.muted)),
      const SizedBox(height: 12),
      baslaKarti(
        widget,
        context,
        _p1 == _p2 ? '$_p1. sayfa' : '$_p1–$_p2. sayfalar',
        l.isEmpty ? 'Geçersiz aralık' : '${l.length} ayet · ${Kuran.etiketListe(l)}',
        l,
        ek: Row(children: [
          Expanded(child: _sayfaAlan(_p1, (v) => setState(() {
                _p1 = v;
                if (_p2 < v) _p2 = v;
              }))),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('–')),
          Expanded(child: _sayfaAlan(_p2, (v) => setState(() => _p2 = v < _p1 ? _p1 : v))),
        ]),
      ),
    ]);
  }

  Widget _sayfaAlan(int v, ValueChanged<int> f) => Row(children: [
        IconButton(onPressed: v > 1 ? () => f(v - 1) : null, icon: const Icon(Icons.remove_circle_outline)),
        Expanded(child: Text('$v', textAlign: TextAlign.center, style: AppText.number(20))),
        IconButton(onPressed: v < 604 ? () => f(v + 1) : null, icon: const Icon(Icons.add_circle_outline)),
      ]);
}

/// Ayrıntı sayfasının yol adı: seçimden sonra listeyle birlikte kapatmak için.
const secDetayRota = 'secDetay';

/// Seçim tamamlanınca ayrıntı sayfasını ve seçim ekranını birlikte kapatır.
void secimiKapat(BuildContext c) {
  final n = Navigator.of(c);
  n.popUntil((r) => r.settings.name != secDetayRota);
  n.pop();
}

/// Seçilen bölümün kartı: başlık, ek ayarlar, gizleme ve başlat düğmesi.
Widget baslaKarti(SecEkrani ust, BuildContext context, String baslik, String alt, List<int> l, {Widget? ek}) => OrnateCard(
      highlight: true,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(baslik, style: AppText.display(20)),
        Text(alt, style: AppText.body(13, color: AppColors.muted)),
        if (ek != null) ...[const SizedBox(height: 10), ek],
        if (ust.gizlemeSor) ...[
          const SizedBox(height: 12),
          Text('AYETLER NASIL GİZLENSİN?', style: AppText.label()),
          const SizedBox(height: 6),
          const GizlemeSecici(),
        ],
        const SizedBox(height: 12),
        GoldButton(label: ust.dugme, icon: Icons.play_arrow_rounded, onPressed: l.isEmpty ? null : () => ust.onSec(context, l)),
      ]),
    );

/// Sure ayrıntıları: ayet aralığı seçilip başlatılır.
class _SureDetay extends StatefulWidget {
  const _SureDetay({required this.sure, required this.ust});
  final int sure;
  final SecEkrani ust;

  @override
  State<_SureDetay> createState() => _SureDetayState();
}

class _SureDetayState extends State<_SureDetay> {
  int get _s => widget.sure;
  late int _a1 = 1, _a2 = Kuran.ayetSayisi(_s);
  void _bas(int v) => setState(() => _a1 = v);
  void _son(int v) => setState(() => _a2 = v);

  /// Ayet numarası: elle yazılabilir ya da sağdaki oktan listeden seçilebilir.
  Widget _ayetSec(String ad, int v, ValueChanged<int> f) => _AyetAlan(
        key: ValueKey('ayet-$_s-$ad'),
        deger: v,
        enCok: Kuran.ayetSayisi(_s),
        onChanged: (x) {
          f(x);
          if (_a2 < _a1) setState(() => _a2 = _a1);
        },
      );

  @override
  Widget build(BuildContext context) {
    final k = Kayit.i;
    final n = Kuran.ayetSayisi(_s);
    return Scaffold(
      appBar: AppBar(title: Text('${widget.ust.baslik} · Ayrıntılar')),
      body: PatternBackground(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
          Center(child: Text(Kuran.arapAd(_s), style: arapYazi(34, color: AppColors.gold))),
          const SizedBox(height: 8),
          baslaKarti(
            widget.ust,
            context,
            '$_s. ${Kuran.ad(_s)}',
            '$n ayet · %${(k.sureOrani(_s) * 100).round()} ezber',
            Kuran.aralik(Kuran.ix(_s, _a1), Kuran.ix(_s, _a2)),
            ek: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('AYET ARALIĞI', style: AppText.label()),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: _ayetSec('bas', _a1, _bas)),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('–')),
                Expanded(child: _ayetSec('son', _a2, _son)),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 6, children: [
                ActionChip(label: const Text('Tamamı'), onPressed: () => setState(() {
                      _a1 = 1;
                      _a2 = n;
                    })),
                for (final x in [3, 5, 10])
                  if (n > x)
                    ActionChip(label: Text('$x ayet'), onPressed: () => setState(() => _a2 = (_a1 + x - 1).clamp(1, n))),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Cüz ayrıntıları.
class _CuzDetay extends StatelessWidget {
  const _CuzDetay({required this.cuz, required this.ust});
  final int cuz;
  final SecEkrani ust;

  @override
  Widget build(BuildContext context) {
    final l = Kuran.cuz(cuz);
    final p = l.where(Kayit.i.ezber).length / l.length;
    return Scaffold(
      appBar: AppBar(title: Text('${ust.baslik} · Ayrıntılar')),
      body: PatternBackground(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
          baslaKarti(
            ust,
            context,
            '$cuz. cüz',
            '${Kuran.etiketListe([l.first])} → ${Kuran.etiketListe([l.last])} · ${l.length} ayet · %${(p * 100).round()} ezber',
            l,
          ),
        ]),
      ),
    );
  }
}

/// Elle yazılabilen ayet numarası alanı (1–[enCok]); sağdaki oktan listeden de seçilir.
class _AyetAlan extends StatefulWidget {
  const _AyetAlan({super.key, required this.deger, required this.enCok, required this.onChanged});
  final int deger, enCok;
  final ValueChanged<int> onChanged;
  @override
  State<_AyetAlan> createState() => _AyetAlanState();
}

class _AyetAlanState extends State<_AyetAlan> {
  late final _c = TextEditingController(text: '${widget.deger}');
  final _odak = FocusNode();

  @override
  void initState() {
    super.initState();
    // Alandan çıkınca geçersiz/boş yazı son geçerli değere döner.
    _odak.addListener(() {
      if (!_odak.hasFocus) _c.text = '${widget.deger}';
    });
  }

  @override
  void didUpdateWidget(_AyetAlan old) {
    super.didUpdateWidget(old);
    // Değer dışarıdan değiştiyse (Tamamı / 5 ayet düğmeleri) yazı da güncellenir.
    if (!_odak.hasFocus && _c.text != '${widget.deger}') _c.text = '${widget.deger}';
  }

  @override
  void dispose() {
    _c.dispose();
    _odak.dispose();
    super.dispose();
  }

  void _yazildi(String t) {
    final v = int.tryParse(t.trim());
    if (v == null || v < 1) return;
    final x = v > widget.enCok ? widget.enCok : v;
    if (x != v) {
      _c.text = '$x';
      _c.selection = TextSelection.collapsed(offset: _c.text.length);
    }
    widget.onChanged(x);
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _c,
        focusNode: _odak,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
        onChanged: _yazildi,
        onSubmitted: (_) => _odak.unfocus(),
        decoration: InputDecoration(
          isDense: true,
          suffixText: '. ayet',
          suffixIcon: PopupMenuButton<int>(
            tooltip: 'Listeden seç',
            icon: const Icon(Icons.arrow_drop_down),
            itemBuilder: (_) => [for (var i = 1; i <= widget.enCok; i++) PopupMenuItem(value: i, height: 36, child: Text('$i. ayet'))],
            onSelected: (i) {
              _c.text = '$i';
              widget.onChanged(i);
            },
          ),
        ),
      );
}
