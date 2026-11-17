import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// Sesli Kur'an'ın Android'deki arka plan hizmeti.
///
/// Android, ekran kilitliyken ya da uygulama arka plandayken "ön plan hizmeti" olmayan
/// uygulamaların sesini bir süre sonra keser (çalar ilerlemeye devam eder ama ses gelmez).
/// Bu sınıf çaları bildirim çubuğundaki medya denetimine bağlar; çalma sürdükçe hizmet ayakta kalır.
class QuranAudioHandler extends BaseAudioHandler with SeekHandler {
  QuranAudioHandler({
    required this.player,
    required this.onNext,
    required this.onPrevious,
    required this.onStop,
  }) {
    player.playbackEventStream.listen((_) => _push(), onError: (Object _, StackTrace __) {});
    player.playerStateStream.listen((_) => _push());
    player.durationStream.listen((d) {
      final item = mediaItem.value;
      if (item != null && d != null && item.duration != d) mediaItem.add(item.copyWith(duration: d));
    });
  }

  final AudioPlayer player;
  final Future<void> Function() onNext;
  final Future<void> Function() onPrevious;
  final Future<void> Function() onStop;

  /// Bildirimde görünen başlık (sure) ve alt başlık (okuyucu).
  void show(String id, String title, String artist) {
    mediaItem.add(MediaItem(id: id, title: title, artist: artist, album: "Sesli Kur'an"));
    _push();
  }

  void _push() {
    final playing = player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: switch (player.processingState) {
        ProcessingState.idle => AudioProcessingState.idle,
        ProcessingState.loading => AudioProcessingState.loading,
        ProcessingState.buffering => AudioProcessingState.buffering,
        ProcessingState.ready => AudioProcessingState.ready,
        // Sure bitince sıradaki yüklenir; hizmet kapanmasın diye "yükleniyor" bildirilir.
        ProcessingState.completed => AudioProcessingState.loading,
      },
      playing: playing,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
    ));
  }

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> skipToNext() => onNext();

  @override
  Future<void> skipToPrevious() => onPrevious();

  @override
  Future<void> stop() async {
    await onStop();
    playbackState.add(playbackState.value.copyWith(processingState: AudioProcessingState.idle, playing: false));
    await super.stop();
  }
}
