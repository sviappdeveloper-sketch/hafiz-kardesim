import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart' show AudioService, AudioServiceConfig;
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../data/quran.dart';
import '../l10n/l10n.dart';
import 'quran_audio_handler.dart';
import 'settings_service.dart';

/// Sesli Kur'an okuyucusu (kâri).
class Reciter {
  const Reciter(this.id, this.name, this.server);
  final String id;
  final String name;
  final String server; // sure dosyaları: <server>001.mp3 … 114.mp3

  /// Ekranda gösterilen ad (seçili dile çevrilir; özel adlar olduğu gibi kalır).
  String get displayName => lt(name);
}

/// Sesli Kur'an: sure sure dinleme ve telefona indirme.
///
/// Ses dosyaları mp3quran.net'in açık dağıtım ağından (cdn.mp3quran.net), Türkçe mealli okuyuş
/// islamhouse.com'dan (d1.islamhouse.com) gelir; uygulamanın
/// sunucusu ya da veritabanı kullanılmaz. İndirilen sureler telefonun kendi depolamasında,
/// uygulamanın belgeler klasöründe (kuran_ses/<okuyucu>/NNN.mp3) durur ve internetsiz çalınır.
/// İndirilmemiş sure dinlenirse internetten akış olarak çalınır.
class AudioQuranService extends ChangeNotifier {
  AudioQuranService._() {
    unawaited(_cleanupRemoved());
    player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) {
        // Sure bitince sıradakine geç.
        final c = current;
        if (c != null && c.$2 < 114) {
          unawaited(play(c.$1, c.$2 + 1));
        } else {
          // Son sure de bitti: Android'de bildirim ve arka plan hizmeti kapansın.
          if (_handler != null) unawaited(player.stop());
          notifyListeners();
        }
      } else {
        notifyListeners();
      }
    });
  }

  static final instance = AudioQuranService._();

  /// Android arka plan hizmeti (ekran kilitliyken ses kesilmesin). Yalnızca Android'de kurulur.
  static QuranAudioHandler? _handler;

  /// Uygulama açılırken bir kez çağrılır. Kurulamazsa çalma eskisi gibi (hizmetsiz) sürer.
  static Future<void> initBackground() async {
    if (kIsWeb) return;
    await _configureSession();
    if (!Platform.isAndroid || _handler != null) return;
    try {
      final svc = instance;
      _handler = await AudioService.init(
        builder: () => QuranAudioHandler(
          player: svc.player,
          onNext: svc.next,
          onPrevious: svc.previous,
          onStop: svc.stop,
        ),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.sviapp.hafiz_kardesim.sesli_kuran',
          androidNotificationChannelName: "Sesli Kur'an",
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
        ),
      );
    } catch (e) {
      debugPrint('Arka plan ses hizmeti kurulamadı: $e');
    }
  }

  static bool _sessionReady = false;

  /// Telefonun ses sistemine "bu uygulama ses/müzik çalıyor" bildirilir.
  ///
  /// Bu yapılmazsa iPhone uygulamayı "arka plan sesi" sayar: sessiz düğmesi açıkken ya da ekran
  /// kilitlenince ses kesilir ama çalar ilerlemeye devam eder (saniyeler sayar, ses gelmez).
  /// Android'de de ses odağı (arama, bildirim, başka uygulama) ve kulaklık çıkarma düzgün yönetilir.
  /// Arama gibi bir kesinti bitince okuma kaldığı yerden kendiliğinden sürer (just_audio yapar).
  static Future<void> _configureSession() async {
    if (_sessionReady) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        // iPhone: "çalma" kategorisi — sessiz düğmesinden etkilenmez, kilit ekranında sürer.
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
        // Android: medya sesi; bildirim gelince ses kısılır (durmaz), arama/başka uygulama gelince durur.
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ));
      // Kulaklık/Bluetooth bağlantısı koparsa okuma hoparlörden devam etmesin, dursun.
      session.becomingNoisyEventStream.listen((_) {
        if (instance.player.playing) unawaited(instance.player.pause());
      });
      _sessionReady = true;
    } catch (e) {
      debugPrint('Ses oturumu ayarlanamadı: $e');
    }
  }

  /// Bütün okuyucular (dile bağlı mealliler dahil). Ekranda [reciters] gösterilir.
  static const allReciters = [
    Reciter('alafasy', 'Mişari Raşid el-Afasi', 'https://cdn.mp3quran.net/audio/mishary-alafasy/r1/'),
    Reciter('husary', 'Mahmud Halil el-Husari', 'https://cdn.mp3quran.net/audio/mahmoud-husary/r1/'),
    Reciter('minshawi', 'Muhammed Sıddık el-Minşavi', 'https://cdn.mp3quran.net/audio/muhammad-minshawi/r1/'),
    Reciter('abdulbasit', 'Abdulbasıt Abdussamed', 'https://cdn.mp3quran.net/audio/abdulbasit-abdulsamad/r3/'),
    Reciter('maher', 'Mahir el-Muaykıli', 'https://cdn.mp3quran.net/audio/maher-muaiqly/r1/'),
    Reciter('faqih', 'Muhammed el-Fakih', 'https://cdn.mp3quran.net/audio/muhammad-faqih/r1/'),
    Reciter('ghamdi', 'Saad el-Gamidi', 'https://cdn.mp3quran.net/audio/saad-ghamdi/r1/'),
    Reciter('dosari', 'Yasir ed-Devseri', 'https://cdn.mp3quran.net/audio/yasser-dosari/r1/'),
    // Mealliler (islamhouse.com) — uygulama dili hangisiyse o dildeki meal gösterilir.
    // Türkçe: Arapça okuyuş Saad el-Gamidi, meal okuyan Hayrettin Küçükdeniz.
    Reciter('meal_tr', 'Türkçe Mealli (Okuyan: Saad el-Gamidi, Meal: Hayrettin Küçükdeniz)',
        'https://d1.islamhouse.com/data/ar/ih_quran/ar_SaadAlGhamidi_With_Turkish_Trans/ar_SaadAlGhamidi_With_Turkish_Trans_'),
    // İngilizce: Arapça okuyuş Mişari Raşid el-Afasi, Sahih International meali (okuyan İbrahim Walk).
    Reciter('meal_en', 'İngilizce Mealli (Okuyan: Mişari Raşid el-Afasi, Meal: İbrahim Walk)',
        'https://d1.islamhouse.com/data/ar/ih_quran/ar_Mashari_With_English/Mashari_with_English_'),
  ];

  /// Mealli okuyuşların dili: kimlik → dil kodu.
  static const _mealLang = {'meal_tr': 'tr', 'meal_en': 'en'};

  /// Seçili uygulama diline göre gösterilen okuyucular: yalnız o dilin meali listede durur
  /// (Arapçada meal gerekmediğinden mealli seçenek yoktur).
  static List<Reciter> get reciters =>
      [for (final r in allReciters) if (!_mealLang.containsKey(r.id) || _mealLang[r.id] == Lang.code) r];

  /// Listeden kaldırılan okuyucuların (ör. Südeys) telefonda kalmış indirmeleri.
  static const _removedReciters = ['sudais'];

  static Reciter reciterById(String id) =>
      allReciters.firstWhere((r) => r.id == id, orElse: () => allReciters.first);

  final player = AudioPlayer();

  /// Çalan: (okuyucu kimliği, sure no)
  (String, int)? current;

  /// Süren indirmeler: "okuyucu/sure" → ilerleme (0..1; boyut bilinmiyorsa -1)
  final Map<String, double> downloads = {};
  final Map<String, HttpClientRequest> _requests = {};
  final Map<String, bool> _cancelled = {};

  Set<int>? _downloadedCache;
  String? _cacheFor;

  /// Seçili okuyucu. Mealli seçiliyken dil değişirse o dilin mealine geçer (yoksa ilk okuyucuya).
  String get selectedReciter {
    final id = SettingsService.prefs.getString('sesliKuranKari') ?? reciters.first.id;
    final list = reciters;
    if (list.any((r) => r.id == id)) return id;
    if (_mealLang.containsKey(id)) {
      for (final r in list) {
        if (_mealLang.containsKey(r.id)) return r.id;
      }
    }
    return list.first.id;
  }

  /// Okuma hızı kademeleri.
  static const speeds = [0.5, 1.0, 1.5, 2.0];
  double get speed => SettingsService.prefs.getDouble('sesliKuranHiz') ?? 1.0;

  /// Sıradaki hız kademesine geçer (0.5 → 1 → 1.5 → 2 → 0.5).
  Future<void> cycleSpeed() async {
    final i = speeds.indexOf(speed);
    final next = speeds[(i < 0 ? 1 : i + 1) % speeds.length];
    await SettingsService.prefs.setDouble('sesliKuranHiz', next);
    await player.setSpeed(next);
    notifyListeners();
  }
  Future<void> selectReciter(String id) async {
    await SettingsService.prefs.setString('sesliKuranKari', id);
    notifyListeners();
  }

  static String _nnn(int s) => s.toString().padLeft(3, '0');
  static String _key(String reciter, int surah) => '$reciter/$surah';

  String url(String reciter, int surah) => '${reciterById(reciter).server}${_nnn(surah)}.mp3';

  Future<Directory> _dir(String reciter) async {
    final docs = await getApplicationDocumentsDirectory();
    final d = Directory('${docs.path}/kuran_ses/$reciter');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// Kaldırılan okuyucuların indirilmiş sure klasörlerini siler (yer kaplamasın).
  Future<void> _cleanupRemoved() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      for (final id in _removedReciters) {
        final d = Directory('${docs.path}/kuran_ses/$id');
        if (await d.exists()) await d.delete(recursive: true);
      }
    } catch (_) {}
  }

  Future<File> _file(String reciter, int surah) async => File('${(await _dir(reciter)).path}/${_nnn(surah)}.mp3');

  /// Okuyucunun indirilmiş sureleri.
  Future<Set<int>> downloaded(String reciter) async {
    if (_cacheFor == reciter && _downloadedCache != null) return _downloadedCache!;
    final d = await _dir(reciter);
    final set = <int>{};
    await for (final f in d.list()) {
      final name = f.uri.pathSegments.last;
      final m = RegExp(r'^(\d{3})\.mp3$').firstMatch(name);
      if (m != null) set.add(int.parse(m.group(1)!));
    }
    _downloadedCache = set;
    _cacheFor = reciter;
    return set;
  }

  void _invalidate() {
    _downloadedCache = null;
    _cacheFor = null;
  }

  /// Okuyucu için telefonda kullanılan alan (bayt).
  Future<int> usedBytes(String reciter) async {
    final d = await _dir(reciter);
    var total = 0;
    await for (final f in d.list()) {
      if (f is File && f.path.endsWith('.mp3')) total += await f.length();
    }
    return total;
  }

  bool isDownloading(String reciter, int surah) => downloads.containsKey(_key(reciter, surah));

  /// Sureyi telefona indirir. Hata olursa açıklamasını döndürür; iptal ya da başarıda null.
  Future<String?> download(String reciter, int surah) async {
    final k = _key(reciter, surah);
    if (downloads.containsKey(k)) return null;
    downloads[k] = 0;
    _cancelled.remove(k);
    notifyListeners();
    final target = await _file(reciter, surah);
    final part = File('${target.path}.part');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      final req = await client.getUrl(Uri.parse(url(reciter, surah)));
      _requests[k] = req;
      final res = await req.close();
      if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}');
      final total = res.contentLength;
      final sink = part.openWrite();
      var got = 0;
      var lastNotify = DateTime.now();
      try {
        await for (final chunk in res) {
          if (_cancelled[k] == true) throw const _Cancelled();
          sink.add(chunk);
          got += chunk.length;
          if (DateTime.now().difference(lastNotify).inMilliseconds > 200) {
            downloads[k] = total > 0 ? got / total : -1;
            lastNotify = DateTime.now();
            notifyListeners();
          }
        }
      } finally {
        await sink.close();
      }
      if (total > 0 && got < total) throw const HttpException('Eksik indirildi');
      await part.rename(target.path);
      return null;
    } on _Cancelled {
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      client.close(force: true);
      if (await part.exists()) await part.delete();
      downloads.remove(k);
      _requests.remove(k);
      _cancelled.remove(k);
      _invalidate();
      notifyListeners();
    }
  }

  void cancelDownload(String reciter, int surah) {
    final k = _key(reciter, surah);
    _cancelled[k] = true;
    try {
      _requests[k]?.abort();
    } catch (_) {}
  }

  Future<void> delete(String reciter, int surah) async {
    final f = await _file(reciter, surah);
    if (await f.exists()) await f.delete();
    _invalidate();
    notifyListeners();
  }

  Future<void> deleteAll(String reciter) async {
    final d = await _dir(reciter);
    if (await d.exists()) await d.delete(recursive: true);
    _invalidate();
    notifyListeners();
  }

  /// Sureyi çalar: indirilmişse telefondaki dosyadan, değilse internetten.
  /// İnternetten çalınıyorsa true döner.
  Future<bool> play(String reciter, int surah) async {
    await _configureSession(); // açılışta kurulamadıysa (ör. çok erken çağrı) burada tamamlanır
    current = (reciter, surah);
    notifyListeners();
    _handler?.show('$reciter/$surah', surahTitle(surah), reciterById(reciter).displayName);
    final f = await _file(reciter, surah);
    final local = await f.exists();
    try {
      if (local) {
        await player.setFilePath(f.path);
      } else {
        await player.setUrl(url(reciter, surah));
      }
      await player.setSpeed(speed);
      unawaited(player.play());
    } catch (e) {
      debugPrint('Ses çalınamadı: $e');
      rethrow;
    } finally {
      notifyListeners();
    }
    return !local;
  }

  Future<void> toggle() async {
    if (player.playing) {
      await player.pause();
    } else {
      await _configureSession();
      unawaited(player.play());
    }
    notifyListeners();
  }

  Future<void> next() async {
    final c = current;
    if (c != null && c.$2 < 114) await play(c.$1, c.$2 + 1);
  }

  Future<void> previous() async {
    final c = current;
    if (c == null) return;
    if (player.position > const Duration(seconds: 5) || c.$2 == 1) {
      await player.seek(Duration.zero);
    } else {
      await play(c.$1, c.$2 - 1);
    }
  }

  Future<void> stop() async {
    await player.stop();
    current = null;
    notifyListeners();
  }

  static String surahTitle(int s) => Quran.surahNamesTr[s - 1];
}

class _Cancelled implements Exception {
  const _Cancelled();
}
