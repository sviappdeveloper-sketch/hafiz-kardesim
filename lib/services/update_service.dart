import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

/// Google Play'de yeni sürüm varsa uygulama açılır açılmaz kullanıcıya güncelleme ekranını gösterir.
/// Yalnızca Play'den kurulan uygulamada çalışır; APK ile kurulan uygulamada sessizce geçilir.
class UpdateService {
  UpdateService._();

  static bool _checked = false;

  static Future<void> check() async {
    if (_checked || defaultTargetPlatform != TargetPlatform.android || kIsWeb) return;
    _checked = true;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable &&
          info.updateAvailability != UpdateAvailability.developerTriggeredUpdateInProgress) {
        return;
      }
      if (info.immediateUpdateAllowed) {
        // Tam ekran Play güncelleme ekranı; güncelleme bitince uygulama yeniden açılır.
        await InAppUpdate.performImmediateUpdate();
      } else if (info.flexibleUpdateAllowed) {
        await InAppUpdate.startFlexibleUpdate();
        await InAppUpdate.completeFlexibleUpdate();
      }
    } catch (e) {
      debugPrint('Güncelleme denetimi yapılamadı: $e');
    }
  }
}
