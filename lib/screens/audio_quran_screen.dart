import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../data/quran.dart';
import '../l10n/l10n.dart';
import '../services/audio_quran_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/ornaments.dart';

/// Sesli Kur'an: okuyucu seçilir, sureler dinlenir ve istenirse telefona indirilir.
class AudioQuranScreen extends StatefulWidget {
  const AudioQuranScreen({super.key, this.startSurah});

  /// Verilirse ekran açılınca bu sure çalınır (okuyucudan "Dinle").
  final int? startSurah;

  @override
  State<AudioQuranScreen> createState() => _AudioQuranScreenState();
}

class _AudioQuranScreenState extends State<AudioQuranScreen> {
  final svc = AudioQuranService.instance;
  Set<int> _have = {};
  int _bytes = 0;

  @override
  void initState() {
    super.initState();
    svc.addListener(_changed);
    _refresh();
    final s = widget.startSurah;
    if (s != null) WidgetsBinding.instance.addPostFrameCallback((_) => _play(s));
  }

  @override
  void dispose() {
    svc.removeListener(_changed);
    super.dispose();
  }

  bool _refreshing = false;
  void _changed() {
    if (!mounted) return;
    setState(() {});
    if (!_refreshing) _refresh();
  }

  Future<void> _refresh() async {
    _refreshing = true;
    final r = svc.selectedReciter;
    final have = await svc.downloaded(r);
    final bytes = await svc.usedBytes(r);
    _refreshing = false;
    if (mounted) {
      setState(() {
        _have = have;
        _bytes = bytes;
      });
    }
  }

  Future<void> _play(int s) async {
    try {
      final online = await svc.play(svc.selectedReciter, s);
      if (online && mounted) {
        showSnack(context, lt('İnternetten çalınıyor. Sureyi indirirseniz internetsiz dinleyebilirsiniz.'));
      }
    } catch (_) {
      if (mounted) showSnack(context, lt('Ses açılamadı. İnternet bağlantınızı kontrol edin.'));
    }
  }

  Future<void> _download(int s) async {
    final err = await svc.download(svc.selectedReciter, s);
    if (err != null && mounted) showSnack(context, lt('İndirilemedi: {0}', [err]));
  }

  Future<void> _confirmDeleteAll() async {
    final r = AudioQuranService.reciterById(svc.selectedReciter);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lt('İndirilenleri sil')),
        content: Text(lt('{0} için telefona indirilen bütün sureler silinsin mi?', [r.displayName])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(lt('Vazgeç'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(lt('Sil'))),
        ],
      ),
    );
    if (ok == true) {
      await svc.deleteAll(r.id);
      await _refresh();
    }
  }

  static String _mb(int b) => (b / (1024 * 1024)).toStringAsFixed(b < 10 * 1024 * 1024 ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    final rid = svc.selectedReciter;
    final cur = svc.current;
    return Scaffold(
      appBar: AppBar(
        title: Text(lt('Sesli Kur\'an')),
        actions: [
          if (_have.isNotEmpty)
            IconButton(
              tooltip: lt('İndirilenleri sil'),
              onPressed: _confirmDeleteAll,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: PatternBackground(
        child: Column(children: [
          // Okuyucu seçimi
          SizedBox(
            height: 54,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              children: [
                for (final r in AudioQuranService.reciters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(r.displayName,
                          style: AppText.body(13,
                              weight: FontWeight.w700,
                              color: rid == r.id
                                  ? (AppColors.isLight ? const Color(0xFFFFF8E8) : AppColors.inkDeep)
                                  : AppColors.ivory)),
                      selected: rid == r.id,
                      onSelected: (_) async {
                        await svc.selectReciter(r.id);
                        await _refresh();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Row(children: [
              Icon(Icons.phone_android, size: 16, color: AppColors.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _have.isEmpty
                      ? lt('İndirilen sure yok. İndirdiğiniz sureler telefonunuzda saklanır ve internetsiz çalınır.')
                      : lt('{0} sure indirildi · telefonda {1} MB', [_have.length, _mb(_bytes)]),
                  style: AppText.body(12, color: AppColors.muted),
                ),
              ),
            ]),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              itemCount: 114,
              separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.inkLine),
              itemBuilder: (context, i) {
                final s = i + 1;
                final playingThis = cur != null && cur.$1 == rid && cur.$2 == s;
                final have = _have.contains(s);
                final dl = svc.downloads['$rid/$s'];
                return ListTile(
                  dense: true,
                  leading: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: playingThis ? AppColors.gold.withValues(alpha: 0.25) : null,
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
                    ),
                    child: Text('$s', style: AppText.number(13, color: AppColors.goldLight)),
                  ),
                  title: Text(lt('{0} Suresi', [Quran.surahNamesTr[i]]),
                      style: AppText.body(15,
                          weight: FontWeight.w600, color: playingThis ? AppColors.goldLight : AppColors.ivory)),
                  subtitle: have
                      ? Text(lt('Telefonda'), style: AppText.body(11.5, color: AppColors.goldLight))
                      : null,
                  onTap: () => playingThis ? svc.toggle() : _play(s),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (dl != null)
                      IconButton(
                        tooltip: lt('İndirmeyi durdur'),
                        onPressed: () => svc.cancelDownload(rid, s),
                        icon: SizedBox(
                          width: 26,
                          height: 26,
                          child: Stack(alignment: Alignment.center, children: [
                            CircularProgressIndicator(
                                value: dl < 0 ? null : dl, strokeWidth: 2.5, color: AppColors.goldLight),
                            Icon(Icons.close, size: 14, color: AppColors.ivory),
                          ]),
                        ),
                      )
                    else if (have)
                      IconButton(
                        tooltip: lt('Telefondan sil'),
                        onPressed: () async {
                          await svc.delete(rid, s);
                          await _refresh();
                        },
                        icon: Icon(Icons.download_done, color: AppColors.goldLight),
                      )
                    else
                      IconButton(
                        tooltip: lt('İndir'),
                        onPressed: () => _download(s),
                        icon: Icon(Icons.download_outlined, color: AppColors.ivory),
                      ),
                    IconButton(
                      tooltip: playingThis && svc.player.playing ? lt('Duraklat') : lt('Dinle'),
                      onPressed: () => playingThis ? svc.toggle() : _play(s),
                      icon: Icon(
                        playingThis && svc.player.playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                        color: AppColors.goldLight,
                        size: 30,
                      ),
                    ),
                  ]),
                );
              },
            ),
          ),
          if (cur != null) _MiniPlayer(svc: svc),
        ]),
      ),
    );
  }
}

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer({required this.svc});
  final AudioQuranService svc;

  static String _speedLabel(double v) =>
      '${v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString()}x';

  static String _t(Duration d) {
    final m = d.inMinutes, s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cur = svc.current!;
    final p = svc.player;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inkDeep,
        border: Border(top: BorderSide(color: AppColors.gold.withValues(alpha: 0.4))),
      ),
      padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + MediaQuery.paddingOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(lt('{0} Suresi', [Quran.surahNamesTr[cur.$2 - 1]]),
                  style: AppText.body(15, weight: FontWeight.w700, color: AppColors.goldLight)),
              Text(AudioQuranService.reciterById(cur.$1).displayName, style: AppText.body(12, color: AppColors.muted)),
            ]),
          ),
          IconButton(onPressed: svc.previous, icon: Icon(Icons.skip_previous, color: AppColors.ivory)),
          StreamBuilder<PlayerState>(
            stream: p.playerStateStream,
            builder: (_, snap) {
              final st = snap.data;
              final loading = st?.processingState == ProcessingState.loading ||
                  st?.processingState == ProcessingState.buffering;
              if (loading) {
                return const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5)));
              }
              return IconButton(
                iconSize: 40,
                onPressed: svc.toggle,
                icon: Icon(p.playing ? Icons.pause_circle_filled : Icons.play_circle_fill, color: AppColors.goldLight),
              );
            },
          ),
          IconButton(onPressed: svc.next, icon: Icon(Icons.skip_next, color: AppColors.ivory)),
          IconButton(onPressed: svc.stop, icon: Icon(Icons.close, color: AppColors.muted)),
        ]),
        StreamBuilder<Duration>(
          stream: p.positionStream,
          builder: (_, snap) {
            final pos = snap.data ?? Duration.zero;
            final dur = p.duration ?? Duration.zero;
            final max = dur.inMilliseconds.toDouble();
            return Row(children: [
              Text(_t(pos), style: AppText.body(11, color: AppColors.muted)),
              Expanded(
                child: Slider(
                  value: max <= 0 ? 0 : pos.inMilliseconds.clamp(0, dur.inMilliseconds).toDouble(),
                  max: max <= 0 ? 1 : max,
                  activeColor: AppColors.gold,
                  onChanged: max <= 0 ? null : (v) => p.seek(Duration(milliseconds: v.round())),
                ),
              ),
              Text(_t(dur), style: AppText.body(11, color: AppColors.muted)),
              const SizedBox(width: 6),
              // Hız: 0.5x → 1x → 1.5x → 2x
              Tooltip(
                message: lt('Okuma hızı'),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: svc.cycleSpeed,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
                    ),
                    child: Text(_speedLabel(svc.speed),
                        style: AppText.body(12, weight: FontWeight.w700, color: AppColors.goldLight)),
                  ),
                ),
              ),
            ]);
          },
        ),
      ]),
    );
  }
}
