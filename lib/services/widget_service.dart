import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../l10n/l10n.dart';
import 'prayer_service.dart';
import 'settings_service.dart';

/// Ana ekran namaz vakti widget'ı (Android). Vakitler birkaç günlük olarak widget'a yazılır;
/// widget sıradaki vakti kendisi seçer, uygulama açılmasa da günler boyunca doğru gösterir.
class WidgetService {
  WidgetService._();

  static const androidName = 'PrayerWidgetProvider';
  static const qualifiedName = 'com.sviapp.hafiz_kardesim.PrayerWidgetProvider';
  static const barName = 'PrayerBarReceiver';
  static const barQualifiedName = 'com.sviapp.hafiz_kardesim.PrayerBarReceiver';

  static bool get enabled => SettingsService.prefs.getBool('widgetOn') ?? true;
  static Future<void> setEnabled(bool v) async {
    await SettingsService.prefs.setBool('widgetOn', v);
    await refresh();
  }

  /// Bildirim çubuğunda sürekli duran namaz vakti bildirimi.
  static bool get barEnabled => SettingsService.prefs.getBool('barOn') ?? false;
  static Future<void> setBarEnabled(bool v) async {
    await SettingsService.prefs.setBool('barOn', v);
    await refresh();
  }

  /// Bu cihazda widget ve kalıcı bildirim var mı? (Yalnızca Android.)
  static bool get supported => _android;

  static bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Widget verisini günceller (uygulama açılışında, il değişince ve ayar değişince).
  static Future<void> refresh() async {
    if (!_android) return;
    try {
      final city = SettingsService.city.value;
      await HomeWidget.saveWidgetData<bool>('pw_enabled', enabled);
      await HomeWidget.saveWidgetData<String>('pw_names', PrayerDay.names.join('|'));
      await HomeWidget.saveWidgetData<String>('pw_next', lt('Sıradaki'));
      await HomeWidget.saveWidgetData<String>(
          'pw_empty', enabled ? lt('İl seçmek için dokunun') : lt('Widget ayarlardan kapatıldı'));
      await HomeWidget.saveWidgetData<String>('pw_city', city ?? '');
      await HomeWidget.saveWidgetData<bool>('pb_enabled', barEnabled);
      await HomeWidget.saveWidgetData<String>('pb_channel', lt('Bildirim çubuğunda vakitler'));
      await HomeWidget.saveWidgetData<String>('pb_left', lt('kalan'));
      if ((enabled || barEnabled) && city != null) {
        final days = await PrayerService.upcoming(city, days: 7);
        final data = [
          for (final d in days) [for (final t in d.times) t.millisecondsSinceEpoch]
        ];
        await HomeWidget.saveWidgetData<String>('pw_times', jsonEncode(data));
      } else {
        await HomeWidget.saveWidgetData<String>('pw_times', '[]');
      }
      await HomeWidget.updateWidget(androidName: androidName, qualifiedAndroidName: qualifiedName);
      await HomeWidget.updateWidget(androidName: barName, qualifiedAndroidName: barQualifiedName);
    } catch (e) {
      debugPrint('Widget güncellenemedi: $e');
    }
  }

  /// Telefon destekliyorsa widget'ı ana ekrana ekleme penceresini açar. Desteklemiyorsa false.
  static Future<bool> pin() async {
    if (!_android) return false;
    try {
      if (await HomeWidget.isRequestPinWidgetSupported() != true) return false;
      await HomeWidget.requestPinWidget(androidName: androidName, qualifiedAndroidName: qualifiedName);
      return true;
    } catch (_) {
      return false;
    }
  }
}
