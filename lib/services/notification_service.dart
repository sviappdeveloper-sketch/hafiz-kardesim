import 'dart:async';

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/models.dart';
import 'hatim_service.dart';
import '../hafiz/hoca_service.dart';
import 'prayer_service.dart';
import 'settings_service.dart';
import 'social_service.dart';
import 'support_service.dart';
import '../l10n/l10n.dart';

/// Cihaz içi bildirimler:
/// - Cüz teslim tarihi hatırlatması (1 gün kala ve son gün)
/// - Ezan vakti bildirimi (seçilen ile göre, önümüzdeki 5 gün)
/// - Uygulama açıkken gelen arkadaşlık isteği, grup daveti ve destek yanıtı
///
/// Not: Uygulama tamamen kapalıyken sunucudan anlık bildirim göndermek Firebase'in ücretli
/// planını (Cloud Functions) gerektirir; bu sürümde bildirimler cihazda planlanır.
class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _ezanBase = 1000, _juzBase = 2000, _socialBase = 3000;
  static int _socialId = 0;

  /// Ezan bildirim sesleri: kimlik, ad. Ses bir Android kanalına bağlı olduğundan her ses
  /// kendi kanalını kullanır. Ses dosyaları: Android'de res/raw/ezan_<kimlik>.ogg,
  /// iPhone'da Library/Sounds/ezan_<kimlik>.caf (assets/audio'dan kopyalanır), ön dinleme için
  /// assets/audio/ezan_<kimlik>.m4a. iPhone bildirim sesi en fazla 30 saniye olabildiğinden
  /// okuyuşların ilk tekbirleri kullanılır.
  static List<(String, String)> get ezanSounds => [
        ('mekke', lt('Ezan — Mekke')),
        ('medine', lt('Ezan — Medine')),
        ('halep', lt('Ezan — Sabah Fahri')),
        ('can', lt('Kısa çan sesi')),
      ];

  static String _soundFile(String id) => id == 'can' ? 'ezan_bildirim' : 'ezan_$id';

  static AndroidNotificationDetails _ezanChannel(String id) => id == 'can'
      // Eski kanal kimliği korunur (çan sesi).
      ? AndroidNotificationDetails('ezan_ses', lt('Ezan vakitleri (çan)'),
          channelDescription: lt('Seçtiğiniz ilin ezan vakitleri'),
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('ezan_bildirim'))
      : AndroidNotificationDetails('ezan_$id', lt('Ezan vakitleri ({0})', [ezanSounds.firstWhere((e) => e.$1 == id, orElse: () => ezanSounds.first).$2]),
          channelDescription: lt('Seçtiğiniz ilin ezan vakitleri'),
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
          sound: RawResourceAndroidNotificationSound(_soundFile(id)));

  static DarwinNotificationDetails _ezanIos(String id) => DarwinNotificationDetails(sound: '${_soundFile(id)}.caf');

  /// iPhone özel bildirim seslerini uygulamanın Library/Sounds klasöründe arar.
  static Future<void> _installIosSounds() async {
    if (kIsWeb || !Platform.isIOS) return;
    try {
      final lib = await getLibraryDirectory();
      final dir = Directory('${lib.path}/Sounds');
      await dir.create(recursive: true);
      for (final (id, _) in ezanSounds) {
        final name = '${_soundFile(id)}.caf';
        final f = File('${dir.path}/$name');
        final data = await rootBundle.load('assets/audio/$name');
        if (await f.exists() && await f.length() == data.lengthInBytes) continue;
        await f.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), flush: true);
      }
    } catch (e) {
      debugPrint('Bildirim sesleri kopyalanamadı: $e');
    }
  }

  static final _juzChannel = AndroidNotificationDetails('cuz', lt('Cüz hatırlatmaları'),
      channelDescription: lt('Aldığınız cüzlerin teslim tarihi'), importance: Importance.high, priority: Priority.high);
  static final _socialChannel = AndroidNotificationDetails('sosyal', lt('Davet ve mesajlar'),
      channelDescription: lt('Arkadaşlık istekleri, grup davetleri ve destek yanıtları'),
      importance: Importance.defaultImportance);

  static Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
      await _plugin.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
            requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
      ));
      _ready = true;
      await _installIosSounds();
    } catch (e) {
      debugPrint('Bildirim başlatılamadı: $e');
    }
  }

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// Bildirim izni ister (Android 13+ ve iOS). İzin verildiyse true.
  static Future<bool> requestPermission() async {
    await init();
    final a = _android;
    if (a != null) return await a.requestNotificationsPermission() ?? false;
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
  }

  static Future<bool> enabled() async {
    await init();
    return await _android?.areNotificationsEnabled() ?? true;
  }

  /// Ezanın tam dakikasında bildirim için "alarm ve hatırlatıcı" izni.
  static Future<bool> canExact() async => await _android?.canScheduleExactNotifications() ?? true;
  static Future<void> requestExact() async => _android?.requestExactAlarmsPermission();

  /// alarm: true ise "alarm saati" modu (setAlarmClock): ekran kapalı ve telefon derin
  /// uykudayken (Doze) bile tam dakikasında çalar; ezan vakti bildirimleri bununla planlanır.
  static Future<AndroidScheduleMode> _mode({bool alarm = false}) async => await canExact()
      ? (alarm ? AndroidScheduleMode.alarmClock : AndroidScheduleMode.exactAllowWhileIdle)
      : AndroidScheduleMode.inexactAllowWhileIdle;

  static const _pil = MethodChannel('hatim/pil');

  /// Uygulama pil kısıtlamasından muaf mı (Android)? Diğer platformlarda true.
  static Future<bool> batteryUnrestricted() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      return await _pil.invokeMethod<bool>('kisitsizMi') ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> openBatterySettings() async {
    try {
      await _pil.invokeMethod('ayariAc');
    } catch (_) {}
  }

  static Future<void> openAppSettings() async {
    try {
      await _pil.invokeMethod('uygulamaAyari');
    } catch (_) {}
  }

  static Future<void> _schedule(int id, String title, String body, DateTime at, AndroidNotificationDetails ch,
      {DarwinNotificationDetails ios = const DarwinNotificationDetails(), bool alarm = false}) async {
    if (at.isBefore(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(at, tz.local),
      NotificationDetails(android: ch, iOS: ios),
      androidScheduleMode: await _mode(alarm: alarm),
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ---------------- Ezan ----------------

  static Future<void> _cancelRange(int base, int count) async {
    for (var i = 0; i < count; i++) {
      await _plugin.cancel(base + i);
    }
  }

  /// Seçilen il için önümüzdeki 5 günün ezan bildirimlerini yeniden planlar.
  /// Son planlama hatası (ayarlar ekranında gösterilir).
  static String? lastEzanError;

  static Future<void> rescheduleEzan() async {
    lastEzanError = null;
    await init();
    if (!_ready) return;
    await _cancelRange(_ezanBase, 60);
    final city = SettingsService.city.value;
    if (!SettingsService.notifyEzan || city == null) return;
    try {
      final days = await PrayerService.upcoming(city, days: 5);
      final sound = SettingsService.ezanSound;
      final ch = _ezanChannel(sound), ios = _ezanIos(sound);
      // 15 dakika kala hatırlatması ezan değil, kısa çan sesiyle gelir.
      final chPre = _ezanChannel('can'), iosPre = _ezanIos('can');
      var id = _ezanBase;
      for (final d in days) {
        for (var i = 0; i < 6; i++) {
          if (i == 1) continue; // Güneş: ezan okunmaz.
          final name = PrayerDay.names[i];
          final mode = SettingsService.ezanMode;
          if (mode == 1 || mode == 2) {
            await _schedule(id++, lt('{0} vaktine 15 dakika', [name]),
                lt('{0} için {1} vaktine 15 dakika kaldı.', [city, name]),
                d.times[i].subtract(const Duration(minutes: 15)), chPre, ios: iosPre);
          }
          if (mode == 0 || mode == 2) {
            await _schedule(id++, lt('{0} vakti', [name]), lt('{0} için {1} vakti girdi.', [city, name]), d.times[i], ch, ios: ios, alarm: true);
          }
        }
      }
    } catch (e) {
      lastEzanError = e.toString();
      debugPrint('Ezan bildirimleri planlanamadı: $e');
    }
  }

  /// Seçili ezan sesiyle 10 saniye sonra deneme bildirimi (planlama yolunu da sınar).
  /// Hata olursa açıklamasını döndürür, sorun yoksa null.
  static Future<String?> testEzan() async {
    await init();
    if (!_ready) return lt('Bildirimler başlatılamadı.');
    final sound = SettingsService.ezanSound;
    try {
      await _plugin.zonedSchedule(
        _ezanBase + 99,
        lt('Deneme: ezan bildirimi'),
        lt('Ezan vakitlerinde bildirim bu sesle gelecek.'),
        tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10)),
        NotificationDetails(android: _ezanChannel(sound), iOS: _ezanIos(sound)),
        androidScheduleMode: await _mode(alarm: true),
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Planlanmış ezan bildirimi sayısı (ayarlarda bilgi için).
  static Future<int> pendingEzanCount() async {
    await init();
    if (!_ready) return 0;
    final list = await _plugin.pendingNotificationRequests();
    return list.where((p) => p.id >= _ezanBase && p.id < _ezanBase + 60).length;
  }

  // ---------------- Cüz ----------------

  static StreamSubscription<List<Juz>>? _juzSub;
  static final List<StreamSubscription<dynamic>> _socialSubs = [];

  /// Oturum açan üyenin cüzlerini ve davetlerini izler.
  static Future<void> start(AppUser me) async {
    await init();
    if (!_ready) return;
    await stop();
    _watchSocial(me);
    unawaited(rescheduleEzan());
  }

  static Future<void> stop() async {
    await _juzSub?.cancel();
    _juzSub = null;
    for (final s in _socialSubs) {
      await s.cancel();
    }
    _socialSubs.clear();
  }

  static Future<void> _planJuz(List<Juz> list) async {
    await _cancelRange(_juzBase, 200);
    if (!SettingsService.notifyJuz) return;
    final open = list.where((j) => !j.isDone && !j.isEmpty && j.endAt != null).toList()
      ..sort((a, b) => a.endAt!.compareTo(b.endAt!));
    var id = _juzBase;
    for (final j in open.take(100)) {
      final end = j.endAt!;
      final dayBefore = DateTime(end.year, end.month, end.day - 1, 20);
      final sameDay = DateTime(end.year, end.month, end.day, 10);
      await _schedule(id++, lt('Cüzünüz yarın tamamlanmalı'),
          lt('{0} grubundaki {1}. cüzünüzün teslimine 1 gün kaldı.', [j.groupName, j.number]), dayBefore, _juzChannel);
      await _schedule(id++, lt('Bugün cüz teslim günü'),
          lt('{0} grubundaki {1}. cüzü bugün tamamlamayı unutmayın.', [j.groupName, j.number]), sameDay, _juzChannel);
    }
  }

  // ---------------- Davet / destek ----------------

  static void _watchSocial(AppUser me) {
    Set<String>? reqs;
    Map<String, int>? sup;

    _socialSubs.add(SocialService.incomingRequests(me.id).listen((list) {
      final ids = list.map((e) => e.id).toSet();
      if (reqs != null) {
        for (final r in list.where((r) => !reqs!.contains(r.id))) {
          _social(lt('Yeni arkadaşlık isteği'), lt('{0} size arkadaşlık isteği gönderdi.', [r.fromName]));
        }
      }
      reqs = ids;
    }, onError: (_) {}));

    // Hafız Kardeşim: hoca/öğrenci istekleri ve canlı ders davetleri.
    Set<String>? baglar, canlilar;
    _socialSubs.add(HocaService.baglarim(me.id).listen((list) {
      final gelen = list.where((b) => b.durum == 'bekliyor' && b.isteyen != me.id).toList();
      if (baglar != null) {
        for (final b in gelen.where((b) => !baglar!.contains(b.id))) {
          _social(b.hoca == me.id ? 'Hocalık isteği' : 'Öğrencilik isteği',
              b.hoca == me.id
                  ? '${b.karsiAd(me.id)} seni hocası olarak eklemek istiyor. Hoca olarak kabul ediyor musun?'
                  : '${b.karsiAd(me.id)} seni öğrencisi olarak eklemek istiyor. Öğrenci olarak kabul ediyor musun?');
        }
      }
      baglar = gelen.map((b) => b.id).toSet();
    }, onError: (_) {}));

    _socialSubs.add(HocaService.canlilarim(me.id).listen((list) {
      final davet = list.where((c) => c.durum == 'davet' && c.baslatan != me.id).toList();
      if (canlilar != null) {
        for (final c in davet.where((c) => !canlilar!.contains(c.id))) {
          final karsi = c.hoca == me.id ? c.ogrenci : c.hoca;
          _social('Canlı ders daveti',
              c.hoca == me.id ? '${c.ad(karsi)} sana ezber dinletmek istiyor.' : 'Hocan ${c.ad(karsi)} seni dinlemek istiyor.');
        }
      }
      canlilar = davet.map((c) => c.id).toSet();
    }, onError: (_) {}));

    _socialSubs.add(SupportService.myThreads(me.id).listen((list) {
      final now = {for (final t in list) t.id: t.messages.where((m) => m.fromAdmin).length};
      if (sup != null) {
        for (final t in list) {
          if ((now[t.id] ?? 0) > (sup![t.id] ?? 0) && t.unreadForUser) {
            _social(lt('Destek yanıtı'), lt('Mesajınıza yanıt verildi. Destek ve İletişim bölümünden okuyabilirsiniz.'));
          }
        }
      }
      sup = now;
    }, onError: (_) {}));
  }

  /// Hatim tamamlanınca o hatimde cüz okuyanlara (ve grubu kurana) bildirim.
  /// Görülen hatim sayısı cihazda saklanır; uygulama kapalıyken biten hatim de bir sonraki açılışta bildirilir.
  static Future<void> _checkCompleted(AppUser me, List<HatimGroup> list) async {
    final prefs = SettingsService.prefs;
    for (final g in list) {
      final key = 'hatimSeen_${g.id}';
      final seen = prefs.getInt(key);
      if (!g.isCompleted || g.hatimCount <= (seen ?? 0)) {
        if (seen == null) await prefs.setInt(key, g.isCompleted ? g.hatimCount : g.hatimCount);
        continue;
      }
      await prefs.setInt(key, g.hatimCount);
      final reader = (g.juzCounts[me.id] ?? 0) > 0 || g.isCreator(me.id);
      final recent = g.finishedAt == null || DateTime.now().difference(g.finishedAt!) < const Duration(days: 3);
      // İlk kez görülen grupta yalnızca yeni biten hatim bildirilir.
      if (!reader || (seen == null && !recent) || me.hasReadDua(g)) continue;
      if (!SettingsService.notifyJuz) continue;
      try {
        await _plugin.show(_socialBase + 200 + (_socialId++ % 50), lt('Hatim tamamlandı 🤲'),
            lt('"{0}" hatmi tamamlandı. Allah kabul etsin. Hatim duasını okuyabilirsiniz.', [g.name]),
            NotificationDetails(android: _juzChannel, iOS: const DarwinNotificationDetails()));
      } catch (_) {}
    }
  }

  static Future<void> _social(String title, String body) async {
    if (!SettingsService.notifySocial) return;
    try {
      await _plugin.show(_socialBase + (_socialId++ % 100), title, body,
          NotificationDetails(android: _socialChannel, iOS: const DarwinNotificationDetails()));
    } catch (_) {}
  }
}
