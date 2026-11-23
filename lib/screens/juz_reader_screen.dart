import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/quran.dart';
import '../models/constants.dart';
import '../models/models.dart';
import '../services/hatim_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/ornaments.dart';
import '../widgets/pinch_resize.dart';
import 'dua_screen.dart';
import '../l10n/l10n.dart';

/// Cüzün uygulama içinde okunduğu sayfa: Medine mushafı sayfa düzeninde, kâğıt zemin üzerinde.
/// Kalınan yer ve yazı boyutu hatırlanır; sonunda "Okudum" ile cüz tamamlanır.
class JuzReaderScreen extends StatefulWidget {
  const JuzReaderScreen({super.key, required this.group, required this.juz, required this.me});
  final HatimGroup group;
  final Juz juz;
  final AppUser me;

  @override
  State<JuzReaderScreen> createState() => _JuzReaderScreenState();
}

class _JuzReaderScreenState extends State<JuzReaderScreen> {
  /// Hat seçenekleri: Osmanlı hattı (Medine), Nesih, Şehrazad, Latif.
  static const fonts = ['Amiri Quran', 'Noto Naskh Arabic', 'Scheherazade New', 'Lateef'];
  static List<String> get fontNames => [lt('Medine hattı'), lt('Nesih'), lt('Şehrazad'), lt('Latif')];

  /// Sayfa renkleri: (zemin, kenar, yazı, süs).
  static const papers = [
    (Color(0xFFF8F0DC), Color(0xFFE2CFA2), Color(0xFF231A0E), Color(0xFF9C6F0E)),
    (Color(0xFFFFFFFF), Color(0xFFDDDDDD), Color(0xFF111111), Color(0xFF8A6A1E)),
    (Color(0xFF14211A), Color(0xFF2F4A3B), Color(0xFFF1E8D2), Color(0xFFE2B64A)),
  ];
  static List<String> get paperNames => [lt('Kâğıt'), lt('Beyaz'), lt('Gece')];

  late int _font = (SettingsService.prefs.getInt('readerFont') ?? 0).clamp(0, fonts.length - 1);
  late int _paperIx = (SettingsService.prefs.getInt('readerPaper') ?? 0).clamp(0, papers.length - 1);
  Color get _paper => papers[_paperIx].$1;
  Color get _paperEdge => papers[_paperIx].$2;
  Color get _ink => papers[_paperIx].$3;
  Color get _ornament => papers[_paperIx].$4;

  late final Future<List<List<Ayah>>> _pages = Quran.juzPages(widget.juz.number);
  PageController? _pc;
  int _pageIx = 0;
  late double _size = SettingsService.prefs.getDouble('readerSize') ?? 26;
  late bool _done = widget.juz.isDone;
  bool _busy = false;

  String get _posKey => 'readPage_${widget.group.id}_${widget.juz.number}';

  @override
  void initState() {
    super.initState();
    // Cüzü açınca "okunuyor" durumuna geçer.
    if (widget.juz.status == JuzStatus.taken && widget.juz.isMine(widget.me.id) && !widget.group.isCompleted) {
      HatimService.setJuzStatus(widget.group.id, widget.juz.number, widget.me, JuzStatus.reading).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _pc?.dispose();
    super.dispose();
  }

  void _setSize(double s) {
    setState(() => _size = s.clamp(18, 40));
    SettingsService.prefs.setDouble('readerSize', _size);
  }

  Future<void> _finish() async {
    setState(() => _busy = true);
    final ok = await runGuarded(
      context,
      () => HatimService.setJuzStatus(widget.group.id, widget.juz.number, widget.me, JuzStatus.done),
      success: lt('Allah kabul etsin.'),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) _done = true;
    });
    if (ok) {
      SettingsService.prefs.remove(_posKey);
      final nav = Navigator.of(context);
      final g = await HatimService.group(widget.group.id).first.catchError((_) => null);
      if (!mounted) return;
      if (g != null && g.isCompleted) {
        // Son cüz buydu: hatim tamamlandı, hatim duasına geç.
        nav.pushReplacement(MaterialPageRoute(
          builder: (_) => DuaScreen(groupName: g.name, groupId: g.id, hatimCount: g.hatimCount, uid: widget.me.id),
        ));
      } else {
        nav.pop();
      }
    }
  }

  TextStyle _quranStyle(double size, {Color? color}) {
    final c = color ?? _ink;
    final height = _font == 0 ? 2.05 : (_font == 3 ? 1.75 : 1.9);
    try {
      return GoogleFonts.getFont(fonts[_font], fontSize: _font == 3 ? size * 1.15 : size, color: c, height: height);
    } catch (_) {
      return GoogleFonts.amiri(fontSize: size, color: c, height: 2.0);
    }
  }

  void _options() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.inkDeep,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          void pick(VoidCallback f) {
            setState(f);
            setSheet(() {});
          }

          Widget chips(List<String> names, int selected, void Function(int) onPick) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < names.length; i++)
                    ChoiceChip(
                      label: Text(names[i]),
                      selected: selected == i,
                      showCheckmark: false,
                      selectedColor: AppColors.gold,
                      labelStyle: AppText.body(13,
                          weight: FontWeight.w700, color: selected == i ? AppColors.inkDeep : AppColors.ivory),
                      side: BorderSide(color: AppColors.gold.withValues(alpha: 0.5)),
                      onSelected: (_) => onPick(i),
                    ),
                ],
              );

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
                      textAlign: TextAlign.center, textDirection: TextDirection.rtl, style: _quranStyle(24)),
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
                  value: _size,
                  min: 18,
                  max: 40,
                  divisions: 11,
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
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final j = widget.juz;
    final canFinish = j.isMine(widget.me.id) && !_done && !widget.group.isCompleted;
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(lt('{0}. Cüz', [j.number])),
          Text(juzPages(j.number), style: AppText.body(12, color: AppColors.muted)),
        ]),
        actions: [
          IconButton(tooltip: lt('Yazıyı küçült'), onPressed: () => _setSize(_size - 2), icon: const Icon(Icons.text_decrease)),
          IconButton(tooltip: lt('Yazıyı büyüt'), onPressed: () => _setSize(_size + 2), icon: const Icon(Icons.text_increase)),
          IconButton(tooltip: lt('Okuma seçenekleri'), onPressed: _options, icon: const Icon(Icons.tune)),
        ],
      ),
      body: PatternBackground(
        child: FutureBuilder<List<List<Ayah>>>(
          future: _pages,
          builder: (context, snap) {
            if (snap.hasError) return Center(child: Text(lt('Metin açılamadı: {0}', [snap.error])));
            if (!snap.hasData) return const LoadingView();
            final pages = snap.data!;
            if (_pc == null) {
              final saved = (SettingsService.prefs.getInt(_posKey) ?? 0).clamp(0, pages.length);
              _pageIx = saved;
              _pc = PageController(initialPage: saved);
              if (saved > 0) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) showSnack(context, lt('Kaldığınız yerden devam ediyorsunuz.'));
                });
              }
            }
            return Column(children: [
              Expanded(
                child: PinchResize(
                  size: _size,
                  min: 18,
                  max: 40,
                  onChanged: _setSize,
                  // Kitap gibi: sonraki sayfa soldan gelir (sağdan sola okuma).
                  child: PageView.builder(
                    controller: _pc,
                    reverse: true,
                    itemCount: pages.length + 1,
                    onPageChanged: (i) {
                      setState(() => _pageIx = i);
                      SettingsService.prefs.setInt(_posKey, i);
                    },
                    itemBuilder: (context, i) => SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                      child: i == pages.length ? _end(canFinish) : _page(pages[i]),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: 6 + MediaQuery.paddingOf(context).bottom, top: 2),
                child: Text(
                  _pageIx < pages.length ? lt('Sayfa {0} / {1}', [_pageIx + 1, pages.length]) : lt('Cüzün sonu'),
                  style: AppText.body(12, color: AppColors.muted),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }

  Widget _page(List<Ayah> ayahs) {
    final pageNo = ayahs.first.page;
    // Sayfayı sure başlarına göre bölümlere ayır.
    final blocks = <Widget>[];
    final run = <InlineSpan>[];
    void flush() {
      if (run.isEmpty) return;
      blocks.add(Text.rich(
        TextSpan(children: List.of(run)),
        textAlign: TextAlign.justify,
        textDirection: TextDirection.rtl,
      ));
      run.clear();
    }

    for (final a in ayahs) {
      if (a.number == 1) {
        flush();
        blocks.add(_surahHeader(a.surah));
        if (a.surah != 1 && a.surah != 9) {
          blocks.add(Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(Quran.basmala, textAlign: TextAlign.center, textDirection: TextDirection.rtl,
                style: _quranStyle(_size * 0.95)),
          ));
        }
      }
      run.add(TextSpan(text: '${a.text} ', style: _quranStyle(_size)));
      run.add(ayahMarkerSpan(a.number, _size, _ornament));
      run.add(TextSpan(text: ' ', style: _quranStyle(_size)));
    }
    flush();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _paperEdge, width: 1.2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Container(
        margin: const EdgeInsets.all(6),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(border: Border.all(color: _ornament.withValues(alpha: 0.45), width: 0.8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ...blocks,
          const SizedBox(height: 6),
          Center(
            child: Text('— $pageNo —',
                style: AppText.number(12, color: _ornament.withValues(alpha: 0.8), weight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }

  Widget _surahHeader(int surah) => Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        decoration: BoxDecoration(
          color: _ornament.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: _ornament.withValues(alpha: 0.7), width: 1),
        ),
        child: Text(Quran.surahName(surah),
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: GoogleFonts.amiri(fontSize: _size * 0.85, color: _ornament, fontWeight: FontWeight.w700, height: 1.6)),
      );

  Widget _end(bool canFinish) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Column(children: [
          Text('صَدَقَ ٱللَّهُ ٱلْعَظِيمُ', textDirection: TextDirection.rtl, style: AppText.arabic(26)),
          const SizedBox(height: 6),
          Text(lt('{0}. cüzün sonu', [widget.juz.number]), style: AppText.body(13, color: AppColors.muted)),
          const SizedBox(height: 16),
          if (canFinish)
            GoldButton(label: lt('Okudum, cüzü tamamla'), icon: Icons.check_rounded, busy: _busy, onPressed: _finish)
          else if (_done)
            Text(lt('Bu cüzü okudunuz. Allah kabul etsin.'), style: AppText.body(14, color: AppColors.done)),
        ]),
      );
}
