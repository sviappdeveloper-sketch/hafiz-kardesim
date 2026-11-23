import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/meal.dart';
import '../data/quran.dart';
import '../l10n/l10n.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/ornaments.dart';
import '../widgets/pinch_resize.dart';
import 'audio_quran_screen.dart';

/// Kur'an Oku: sure ya da cüz seçilip serbestçe okunur; istenirse meal gösterilir.
/// Okuyucu bütün mushaftır: seçilen yerden açılır, sayfa çevrildikçe sonraki sureye geçer.
class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  static const lastKey = 'quranLastPage';

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  Future<void> _openAt(BuildContext context, Future<int> start) async {
    final i = await start;
    if (!context.mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => QuranReaderScreen(startIndex: i)));
    if (mounted) setState(() {}); // "Kaldığım yer" güncellensin
  }

  @override
  Widget build(BuildContext context) {
    final last = SettingsService.prefs.getInt(QuranScreen.lastKey);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(lt('Kur\'an-ı Kerîm')),
          actions: [
            IconButton(
              tooltip: lt('Sesli Kur\'an'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AudioQuranScreen())),
              icon: const Icon(Icons.headphones_outlined),
            ),
            if (last != null)
              TextButton.icon(
                onPressed: () => _openAt(context, Future.value(last)),
                icon: const Icon(Icons.bookmark_outline, size: 18),
                label: Text(lt('Kaldığım yer')),
              ),
          ],
          bottom: TabBar(tabs: [Tab(text: lt('Sureler')), Tab(text: lt('Cüzler'))]),
        ),
        body: PatternBackground(
          child: TabBarView(children: [
            ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 96),
              itemCount: 114,
              separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.inkLine),
              itemBuilder: (context, i) {
                final s = i + 1;
                final name = Quran.surahNamesTr[i];
                return ListTile(
                  leading: _Num(s),
                  title: Text(lt('{0} Suresi', [name]), style: AppText.body(15, weight: FontWeight.w600)),
                  trailing: Icon(Icons.chevron_right, color: AppColors.muted),
                  onTap: () => _openAt(context, Quran.surahStartIndex(s)),
                );
              },
            ),
            GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5, mainAxisSpacing: 10, crossAxisSpacing: 10),
              itemCount: 30,
              itemBuilder: (context, i) {
                final j = i + 1;
                return Material(
                  color: AppColors.inkDeep.withValues(alpha: 0.45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: AppColors.gold.withValues(alpha: 0.4)),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _openAt(context, Quran.juzStartIndex(j)),
                    child: Center(child: Text('$j', style: AppText.number(20, color: AppColors.goldLight))),
                  ),
                );
              },
            ),
          ]),
        ),
      ),
    );
  }
}

class _Num extends StatelessWidget {
  const _Num(this.n);
  final int n;
  @override
  Widget build(BuildContext context) => Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.gold.withValues(alpha: 0.6))),
        child: Text('$n', style: AppText.number(14, color: AppColors.goldLight)),
      );
}

/// Mushaf okuyucu: kitap gibi sayfa çevrilir (sonraki sayfa soldan gelir). Meal açıkken
/// sayfadaki her ayetin altında meali görünür. Hat, sayfa rengi ve yazı boyutu seçilebilir;
/// iki parmakla yazı büyütülüp küçültülür.
class QuranReaderScreen extends StatefulWidget {
  const QuranReaderScreen({super.key, required this.startIndex});
  final int startIndex;

  @override
  State<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends State<QuranReaderScreen> {
  static const fonts = ['Amiri Quran', 'Noto Naskh Arabic', 'Scheherazade New', 'Lateef'];
  static List<String> get fontNames => [lt('Medine hattı'), lt('Nesih'), lt('Şehrazad'), lt('Latif')];
  static const papers = [
    (Color(0xFFF8F0DC), Color(0xFFE2CFA2), Color(0xFF231A0E), Color(0xFF9C6F0E)),
    (Color(0xFFFFFFFF), Color(0xFFDDDDDD), Color(0xFF111111), Color(0xFF8A6A1E)),
    (Color(0xFF14211A), Color(0xFF2F4A3B), Color(0xFFF1E8D2), Color(0xFFE2B64A)),
  ];
  static List<String> get paperNames => [lt('Kâğıt'), lt('Beyaz'), lt('Gece')];

  late final Future<(List<List<Ayah>>, bool)> _data = () async {
    final p = await Quran.allPages();
    final m = await Meal.available();
    return (p, m);
  }();
  late final PageController _pc = PageController(initialPage: widget.startIndex);
  bool _full = false;

  /// Tam ekran: uygulama çubuğu ve telefonun durum/gezinme çubukları gizlenir, ekranda
  /// yalnızca Kur'an sayfası kalır. Köşedeki simgeyle ya da geri tuşuyla çıkılır.
  void _setFull(bool v) {
    setState(() => _full = v);
    SystemChrome.setEnabledSystemUIMode(v ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
  }
  late int _ix = widget.startIndex;
  late double _size = SettingsService.prefs.getDouble('readerSize') ?? 26;
  late bool _meal = SettingsService.prefs.getBool('readerMeal') ?? false;
  late int _font = (SettingsService.prefs.getInt('readerFont') ?? 0).clamp(0, fonts.length - 1);
  late int _paperIx = (SettingsService.prefs.getInt('readerPaper') ?? 0).clamp(0, papers.length - 1);

  Color get _paper => papers[_paperIx].$1;
  Color get _edge => papers[_paperIx].$2;
  Color get _ink => papers[_paperIx].$3;
  Color get _orn => papers[_paperIx].$4;

  @override
  void initState() {
    super.initState();
    SettingsService.prefs.setInt(QuranScreen.lastKey, widget.startIndex);
  }

  @override
  void dispose() {
    if (_full) SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pc.dispose();
    super.dispose();
  }

  void _setSize(double s) {
    setState(() => _size = s.clamp(16, 48));
    SettingsService.prefs.setDouble('readerSize', _size);
  }

  TextStyle _q(double size, {Color? color}) {
    final c = color ?? _ink;
    try {
      return GoogleFonts.getFont(fonts[_font], fontSize: _font == 3 ? size * 1.15 : size, color: c, height: _font == 0 ? 2.05 : 1.9);
    } catch (_) {
      return GoogleFonts.amiri(fontSize: size, color: c, height: 2.0);
    }
  }

  void _toggleMeal(bool available) {
    if (!available) {
      showSnack(context, lt('Meal metni bir sonraki sürümde eklenecek.'));
      return;
    }
    setState(() => _meal = !_meal);
    SettingsService.prefs.setBool('readerMeal', _meal);
  }

  void _options() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.inkDeep,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        void pick(VoidCallback f) {
          setState(f);
          setSheet(() {});
        }

        Widget chips(List<String> names, int selected, void Function(int) onPick) => Wrap(spacing: 8, runSpacing: 8, children: [
              for (var i = 0; i < names.length; i++)
                ChoiceChip(
                  label: Text(names[i],
                      style: AppText.body(13,
                          weight: FontWeight.w700, color: selected == i ? AppColors.inkDeep : AppColors.ivory)),
                  selected: selected == i,
                  onSelected: (_) => onPick(i),
                ),
            ]);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(lt('Hat'), style: AppText.label()),
              const SizedBox(height: 10),
              chips(fontNames, _font, (i) => pick(() {
                    _font = i;
                    SettingsService.prefs.setInt('readerFont', i);
                  })),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(color: _paper, borderRadius: BorderRadius.circular(10)),
                child: Text('بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
                    textAlign: TextAlign.center, textDirection: TextDirection.rtl, style: _q(24)),
              ),
              const SizedBox(height: 20),
              Text(lt('Sayfa rengi'), style: AppText.label()),
              const SizedBox(height: 10),
              chips(paperNames, _paperIx, (i) => pick(() {
                    _paperIx = i;
                    SettingsService.prefs.setInt('readerPaper', i);
                  })),
              const SizedBox(height: 20),
              Text(lt('Yazı boyutu'), style: AppText.label()),
              Slider(
                value: _size.clamp(16.0, 48.0).toDouble(),
                min: 16,
                max: 48,
                divisions: 16,
                activeColor: AppColors.gold,
                label: _size.toStringAsFixed(0),
                onChanged: (v) {
                  _setSize(v);
                  setSheet(() {});
                },
              ),
            ]),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(List<List<Ayah>>, bool)>(
      future: _data,
      builder: (context, snap) {
        final pages = snap.data?.$1;
        final mealOk = snap.data?.$2 ?? false;
        final cur = pages == null ? null : pages[_ix.clamp(0, pages.length - 1)];
        final title = cur == null
            ? lt('Kur\'an-ı Kerîm')
            : lt('{0} Suresi', [Quran.surahNamesTr[cur.first.surah - 1]]);
        final body = snap.hasError
            ? Center(child: Text(lt('Metin açılamadı: {0}', [snap.error])))
            : pages == null
                ? const LoadingView()
                : PinchResize(
                    size: _size,
                    onChanged: _setSize,
                    child: PageView.builder(
                      controller: _pc,
                      reverse: true,
                      itemCount: pages.length,
                      onPageChanged: (i) {
                        setState(() => _ix = i);
                        SettingsService.prefs.setInt(QuranScreen.lastKey, i);
                      },
                      itemBuilder: (context, i) => SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                            12, _full ? 12 + MediaQuery.paddingOf(context).top : 8, 12, 16 + MediaQuery.paddingOf(context).bottom),
                        child: _meal && mealOk ? _mealPage(pages[i]) : _page(pages[i]),
                      ),
                    ),
                  );
        return PopScope(
          canPop: !_full,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && _full) _setFull(false);
          },
          child: Scaffold(
            appBar: _full
                ? null
                : AppBar(
                    title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title),
                      if (cur != null)
                        Text(lt('Sayfa {0} · {1}. Cüz', [cur.first.page, cur.first.juz]),
                            style: AppText.body(12, color: AppColors.muted)),
                    ]),
                    actions: [
                      if (cur != null)
                        IconButton(
                          tooltip: lt('Dinle'),
                          onPressed: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => AudioQuranScreen(startSurah: cur.first.surah))),
                          icon: const Icon(Icons.headphones_outlined),
                        ),
                      IconButton(
                        tooltip: lt('Meal'),
                        onPressed: () => _toggleMeal(mealOk),
                        icon: Icon(_meal && mealOk ? Icons.translate : Icons.translate_outlined,
                            color: _meal && mealOk ? AppColors.goldLight : null),
                      ),
                      IconButton(tooltip: lt('Okuma seçenekleri'), onPressed: _options, icon: const Icon(Icons.tune)),
                      IconButton(
                        tooltip: lt('Tam ekran'),
                        onPressed: () => _setFull(true),
                        icon: const Icon(Icons.fullscreen),
                      ),
                    ],
                  ),
            body: PatternBackground(
              child: Stack(children: [
                Positioned.fill(child: body),
                if (_full)
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 8,
                    right: 10,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: lt('Tam ekrandan çık'),
                        onPressed: () => _setFull(false),
                        icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _frame(Widget child) => Container(
        decoration: BoxDecoration(
          color: _paper,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _edge, width: 1.2),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Container(
          margin: const EdgeInsets.all(6),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(border: Border.all(color: _orn.withValues(alpha: 0.45), width: 0.8)),
          child: child,
        ),
      );

  Widget _surahHeader(int s) => Column(children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          decoration: BoxDecoration(
            color: _orn.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: _orn.withValues(alpha: 0.7)),
          ),
          child: Text(Quran.surahName(s),
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: GoogleFonts.amiri(fontSize: _size * 0.85, color: _orn, fontWeight: FontWeight.w700, height: 1.6)),
        ),
        if (s != 1 && s != 9)
          Text(Quran.basmala, textAlign: TextAlign.center, textDirection: TextDirection.rtl, style: _q(_size * 0.95)),
      ]);

  Widget _pageNo(List<Ayah> page) =>
      Center(child: Text('— ${page.first.page} —', style: AppText.number(12, color: _orn.withValues(alpha: 0.8))));

  Widget _page(List<Ayah> page) {
    final blocks = <Widget>[];
    final run = <InlineSpan>[];
    void flush() {
      if (run.isEmpty) return;
      blocks.add(Text.rich(TextSpan(children: List.of(run)), textAlign: TextAlign.justify, textDirection: TextDirection.rtl));
      run.clear();
    }

    for (final a in page) {
      if (a.number == 1) {
        flush();
        blocks.add(_surahHeader(a.surah));
      }
      run.add(TextSpan(text: '${a.text} ', style: _q(_size)));
      run.add(ayahMarkerSpan(a.number, _size, _orn));
      run.add(TextSpan(text: ' ', style: _q(_size)));
    }
    flush();
    return _frame(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ...blocks,
      const SizedBox(height: 6),
      _pageNo(page),
    ]));
  }

  Widget _mealPage(List<Ayah> page) {
    final mealSize = (_size * 0.62).clamp(13.0, 28.0).toDouble();
    final rows = <Widget>[];
    var i = 0;
    while (i < page.length) {
      final a = page[i];
      // Kaynakta birlikte çevrilen ayetler: her birinin Arapçası kendi numarasıyla yazılır,
      // ortak meal altlarında bir kez ve ayet aralığıyla (ör. "9-10.") gösterilir.
      final (from, to) = Meal.groupOf(a.surah, a.number);
      var j = i;
      while (j + 1 < page.length && page[j + 1].surah == a.surah && page[j + 1].number <= to) {
        j++;
      }
      for (final g in page.sublist(i, j + 1)) {
        if (g.number == 1) rows.add(_surahHeader(g.surah));
        rows.add(Text.rich(
          TextSpan(children: [
            TextSpan(text: '${g.text} ', style: _q(_size)),
            ayahMarkerSpan(g.number, _size, _orn),
          ]),
          textAlign: TextAlign.justify,
          textDirection: TextDirection.rtl,
        ));
        rows.add(const SizedBox(height: 4));
      }
      final label = from == to ? '$from' : '$from-$to';
      rows.add(Text('$label. ${Meal.ofSync(a.surah, a.number) ?? ''}', style: AppText.body(mealSize, color: _ink, height: 1.5)));
      rows.add(Divider(color: _orn.withValues(alpha: 0.3), height: 18));
      i = j + 1;
    }
    return _frame(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Icon(Icons.translate, size: 14, color: _orn),
        const SizedBox(width: 6),
        Expanded(child: Text(lt('Meal: {0}', [Meal.name]), style: AppText.body(12, color: _orn, weight: FontWeight.w600))),
      ]),
      const SizedBox(height: 6),
      ...rows,
      _pageNo(page),
    ]));
  }
}
