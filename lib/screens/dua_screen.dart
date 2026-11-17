import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../data/daily_l10n.dart';
import '../data/hatim_duasi.dart';
import '../services/hatim_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/ornaments.dart';
import '../l10n/l10n.dart';

/// Hatim duası: sesli dinleyerek ya da okuyarak tamamlanır.
class DuaScreen extends StatefulWidget {
  const DuaScreen({super.key, required this.groupName, this.groupId, this.hatimCount = 0, this.uid});
  final String groupName;
  final String? groupId;
  final int hatimCount;
  final String? uid;
  @override
  State<DuaScreen> createState() => _DuaScreenState();
}

class _DuaScreenState extends State<DuaScreen> {
  final _player = AudioPlayer();
  bool _audioReady = false;
  bool _audioMissing = false;
  String? _audioError;

  @override
  void initState() {
    super.initState();
    _loadAudio();
  }

  Future<void> _loadAudio() async {
    setState(() {
      _audioError = null;
      _audioReady = false;
    });
    try {
      await _player.setAsset('assets/audio/hatim_duasi.mp3');
      await _player.setVolume(1.0);
      if (mounted) setState(() => _audioReady = true);
    } catch (e) {
      if (mounted) setState(() => _audioError = '$e');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _complete() {
    _player.stop();
    if (widget.groupId != null && widget.uid != null) {
      HatimService.markDuaRead(widget.uid!, widget.groupId!, widget.hatimCount).catchError((_) {});
    }
    showSnack(context, lt('Allah kabul etsin. Âmin.'));
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(lt('Hatim Duası'))),
      body: PatternBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            const Center(child: AppLogo(size: 56, glow: 0.8)),
            const SizedBox(height: 14),
            Text(lt('"{0}" hatmi tamamlandı', [widget.groupName]),
                textAlign: TextAlign.center, style: AppText.display(26, color: AppColors.goldLight)),
            const SizedBox(height: 6),
            Text(lt('Bu güzel buluşmaya vesile olan herkesten Allah razı olsun.'),
                textAlign: TextAlign.center, style: AppText.body(13, color: AppColors.muted)),
            const SizedBox(height: 20),
            // Sesli hatim duası her zaman en üstte: ▶ ile dinlenir, okurken de çalabilir.
            if (_audioError != null) ...[
              OrnateCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(lt('Sesli hatim duası açılamadı.'), style: AppText.body(14, weight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(_audioError!, maxLines: 3, overflow: TextOverflow.ellipsis, style: AppText.body(11, color: AppColors.muted)),
                  TextButton(onPressed: _loadAudio, child: Text(lt('Tekrar dene'))),
                ]),
              ),
              const SizedBox(height: 18),
            ] else if (!_audioMissing) ...[
              _AudioPanel(player: _player, ready: _audioReady, missing: _audioMissing),
              const SizedBox(height: 18),
            ],
            OrnateCard(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
              child: Column(
                children: [
                  for (var i = 0; i < hatimDuasiArabic.length; i++) ...[
                    if (i > 0) const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: GoldDivider(width: 120)),
                    Text(hatimDuasiArabic[i],
                        textAlign: i == 0 ? TextAlign.center : TextAlign.justify,
                        textDirection: TextDirection.rtl,
                        style: AppText.arabic(i == 0 ? 26 : 22)),
                    if (!Lang.isAr) ...[
                      const SizedBox(height: 10),
                      Text(Lang.isEn ? hatimDuasiMeaningEn[i] : hatimDuasiMeaning[i],
                          textAlign: i == 0 ? TextAlign.center : TextAlign.justify,
                          style: AppText.body(14, color: AppColors.ivory, height: 1.55)),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            OrnateCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(lt('NİYET VE HEDİYE'), style: AppText.label()),
                const SizedBox(height: 8),
                Text(Lang.isAr ? hatimDuasiNiyetAr : Lang.isEn ? hatimDuasiNiyetEn : hatimDuasiNiyet,
                    textDirection: Lang.isAr ? TextDirection.rtl : null,
                    style: Lang.isAr ? AppText.arabic(19, color: AppColors.ivory) : AppText.body(14)),
              ]),
            ),
            const SizedBox(height: 22),
            GoldButton(label: lt('Duayı tamamladım · Âmin'), icon: Icons.favorite_outline, onPressed: _complete),
          ],
        ),
      ),
    );
  }
}

class _AudioPanel extends StatelessWidget {
  const _AudioPanel({required this.player, required this.ready, required this.missing});
  final AudioPlayer player;
  final bool ready, missing;

  @override
  Widget build(BuildContext context) {
    if (missing) {
      return OrnateCard(
        child: Text(lt('Sesli hatim duası dosyası henüz eklenmemiş. Duayı okuyarak tamamlayabilirsiniz.'),
            style: AppText.body(13, color: AppColors.muted)),
      );
    }
    if (!ready) return const OrnateCard(child: SizedBox(height: 48, child: LoadingView()));
    return OrnateCard(
      child: StreamBuilder<PlayerState>(
        stream: player.playerStateStream,
        builder: (context, s) {
          final playing = s.data?.playing ?? false;
          final completed = s.data?.processingState == ProcessingState.completed;
          return Column(children: [
            Row(children: [
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.inkDeep),
                iconSize: 32,
                onPressed: () async {
                  if (completed) await player.seek(Duration.zero);
                  playing ? player.pause() : player.play();
                },
                icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(playing ? lt('Hatim duası okunuyor…') : lt('Sesli hatim duasını dinle'),
                    style: AppText.body(14)),
              ),
            ]),
            const SizedBox(height: 10),
            StreamBuilder<Duration>(
              stream: player.positionStream,
              builder: (context, p) {
                final total = player.duration ?? Duration.zero;
                final pos = p.data ?? Duration.zero;
                final v = total.inMilliseconds == 0 ? 0.0 : (pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
                return LinearProgressIndicator(value: v, backgroundColor: AppColors.inkDeep, minHeight: 4);
              },
            ),
          ]);
        },
      ),
    );
  }
}
