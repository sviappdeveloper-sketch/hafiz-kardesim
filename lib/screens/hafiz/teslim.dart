import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../hafiz/hoca_service.dart';
import '../../hafiz/odev_ses.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';

String _sure(int sn) => sn >= 60 ? '${sn ~/ 60} dk ${sn % 60} sn' : '$sn sn';

/// Ödevin teslim durumu: öğrenci "Dersi bitirdim" deyince sonuç ve okuma sesi burada görünür.
/// Hoca sesi dinleyip silebilir; öğrenci kendi gönderdiği sesi dinleyebilir.
class TeslimKarti extends StatelessWidget {
  const TeslimKarti({super.key, required this.bag, required this.hocayim});
  final Bag bag;
  final bool hocayim;

  @override
  Widget build(BuildContext context) => StreamBuilder<Teslim?>(
        stream: OdevSes.teslim(bag.id),
        builder: (context, s) {
          final t = s.data;
          if (t == null) {
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(hocayim ? '⏳ Öğrenci henüz bitirmedi' : 'Ödevi okuyup "Dersi bitirdim"e basınca sonucun ve okuma sesin hocana gider.',
                  style: AppText.body(12.5, color: AppColors.muted)),
            );
          }
          if (t.m['durum'] == 'yukleniyor') {
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('⏳ Okuma sesi gönderiliyor…', style: AppText.body(12.5, color: AppColors.muted)),
            );
          }
          final eski = t.odevTs != 0 && t.odevTs != OdevSes.odevTs(bag);
          final tarih = t.ts == null ? '' : ' · ${formatDateTime(t.ts!)}';
          final sy = t.sayilar;
          final ayrinti = sy.length >= 4 ? ' · ${sy[0]} doğru, ${sy[1]} hatalı, ${sy[2]} atlanan' : '';
          return Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.fromLTRB(10, 8, 6, 6),
            decoration: BoxDecoration(
              color: AppColors.done.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.done.withValues(alpha: .45)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(
                '${eski ? '✓ Önceki ödev bitirildi' : (hocayim ? '✓ Öğrencin dersi bitirdi' : '✓ Dersi bitirdin, hocana gönderildi')} · %${t.puan}',
                style: AppText.body(14, weight: FontWeight.w700),
              ),
              Text('${t.etiket} · ${_sure(t.sure)}$ayrinti$tarih', style: AppText.body(12, color: AppColors.muted)),
              if (hocayim && t.sesVar && !t.dinlendi)
                Text('🔴 Yeni: okuma sesi dinlenmedi', style: AppText.body(12, color: AppColors.goldLight, weight: FontWeight.w600)),
              Row(children: [
                if (t.sesVar) Expanded(child: TeslimOynatici(teslim: t, hocayim: hocayim)),
                if (!t.sesVar) Expanded(child: Text('Ses kaydı yok', style: AppText.body(12, color: AppColors.muted))),
                if (hocayim)
                  IconButton(
                    tooltip: 'Sil',
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Teslim ve ses silinsin mi?'),
                          content: const Text('Öğrencinin bu ödev için gönderdiği okuma sesi ve sonuç silinir.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
                            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sil')),
                          ],
                        ),
                      );
                      if (ok == true && context.mounted) await runGuarded(context, () => OdevSes.sil(t.id));
                    },
                    icon: Icon(Icons.delete_outline, color: AppColors.muted),
                  ),
              ]),
            ]),
          );
        },
      );
}

/// Ödev sesini indirip çalar (ilerleme çubuğu ve ileri/geri sarma ile).
class TeslimOynatici extends StatefulWidget {
  const TeslimOynatici({super.key, required this.teslim, required this.hocayim});
  final Teslim teslim;
  final bool hocayim;
  @override
  State<TeslimOynatici> createState() => _TeslimOynaticiState();
}

class _TeslimOynaticiState extends State<TeslimOynatici> {
  final _p = AudioPlayer();
  bool _yukleniyor = false, _hazir = false;
  StreamSubscription<PlayerState>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _p.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) {
        _p.pause();
        _p.seek(Duration.zero);
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _p.dispose();
    super.dispose();
  }

  Future<void> _oynat() async {
    if (_p.playing) {
      await _p.pause();
      return;
    }
    if (!_hazir) {
      setState(() => _yukleniyor = true);
      try {
        final f = await OdevSes.indir(widget.teslim);
        await _p.setFilePath(f.path);
        _hazir = true;
        if (widget.hocayim && !widget.teslim.dinlendi) OdevSes.dinlendi(widget.teslim.id).catchError((_) {});
      } catch (e) {
        if (mounted) showSnack(context, 'Ses açılamadı: ${errorText(e)}');
      }
      if (mounted) setState(() => _yukleniyor = false);
      if (!_hazir) return;
    }
    await _p.play();
  }

  @override
  Widget build(BuildContext context) {
    final top = Duration(milliseconds: widget.teslim.ornek * 1000 ~/ widget.teslim.hz);
    return Row(children: [
      IconButton(
        onPressed: _yukleniyor ? null : _oynat,
        icon: _yukleniyor
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(_p.playing ? Icons.pause_circle_filled : Icons.play_circle_fill, size: 34, color: AppColors.goldLight),
      ),
      Expanded(
        child: StreamBuilder<Duration>(
          stream: _p.positionStream,
          builder: (_, s) {
            final p = s.data ?? Duration.zero;
            final oran = top.inMilliseconds == 0 ? 0.0 : (p.inMilliseconds / top.inMilliseconds).clamp(0.0, 1.0);
            return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6)),
                child: Slider(
                  value: oran,
                  onChanged: _hazir ? (v) => _p.seek(Duration(milliseconds: (v * top.inMilliseconds).round())) : null,
                ),
              ),
              Text('${_sure(p.inSeconds)} / ${_sure(top.inSeconds)}', textAlign: TextAlign.right, style: AppText.body(11, color: AppColors.muted)),
            ]);
          },
        ),
      ),
    ]);
  }
}
