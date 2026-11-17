import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n.dart';
import '../theme/app_theme.dart';

/// Cihazda saklanan kullanıcı tercihleri.
class SettingsService {
  SettingsService._();

  static late SharedPreferences _p;

  /// Tema değişince uygulama yeniden çizilir.
  static final themeId = ValueNotifier<String>(AppPalette.night.id);

  /// İl değişince ezan vakti kartı yenilenir.
  static final city = ValueNotifier<String?>(null);

  /// Uygulamadaki bütün yazıların boyutu (1.0 = normal).
  static final textScale = ValueNotifier<double>(1.0);
  static Future<void> setTextScale(double v) async {
    textScale.value = v;
    await _p.setDouble('textScale', v);
  }

  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    var id = _p.getString('theme') ?? AppPalette.night.id;
    // Yeni logo ile tasarım lacivert + gümüşe geçti: eski varsayılan (zümrüt) bir kez yeni temaya taşınır.
    // Sonradan Ayarlar'dan zümrüt seçen kişinin seçimi korunur.
    if (_p.getBool('temaGeceGecis') != true) {
      if (id == AppPalette.emerald.id) {
        id = AppPalette.night.id;
        await _p.setString('theme', id);
      }
      await _p.setBool('temaGeceGecis', true);
    }
    AppColors.use(AppPalette.byId(id));
    themeId.value = AppColors.palette.id;
    city.value = _p.getString('city');
    textScale.value = _p.getDouble('textScale') ?? 1.0;
    var lang = _p.getString('lang');
    if (lang == null) {
      final dev = PlatformDispatcher.instance.locale.languageCode;
      lang = Lang.all.contains(dev) ? dev : 'tr';
    }
    Lang.code = lang;
    langCode.value = lang;
  }

  /// Dil değişince uygulama yeniden çizilir.
  static final langCode = ValueNotifier<String>('tr');

  static Future<void> setLang(String code) async {
    await _p.setString('lang', code);
    Lang.code = code;
    langCode.value = code;
  }

  static SharedPreferences get prefs => _p;

  // Tema
  static Future<void> setTheme(String id) async {
    await _p.setString('theme', id);
    AppColors.use(AppPalette.byId(id));
    themeId.value = id;
  }

  // İl
  static Future<void> setCity(String? name) async {
    if (name == null) {
      await _p.remove('city');
    } else {
      await _p.setString('city', name);
    }
    city.value = name;
  }

  // Bildirimler
  static bool get notifyJuz => _p.getBool('notifyJuz') ?? true;
  static Future<void> setNotifyJuz(bool v) => _p.setBool('notifyJuz', v);

  static bool get notifyEzan => _p.getBool('notifyEzan') ?? false;
  static Future<void> setNotifyEzan(bool v) => _p.setBool('notifyEzan', v);

  /// Ezan bildirimi zamanı: 0 = vaktinde, 1 = 15 dakika önce, 2 = ikisi de.
  static int get ezanMode => _p.getInt('ezanMode') ?? 0;
  static Future<void> setEzanMode(int v) => _p.setInt('ezanMode', v);

  /// Ezan bildirim sesi: 'mekke', 'medine', 'halep' (ezan okuyuşları) veya 'can' (kısa çan sesi).
  static String get ezanSound => _p.getString('ezanSound') ?? 'mekke';
  static Future<void> setEzanSound(String v) => _p.setString('ezanSound', v);

  /// Kıble pusulası düzeltmesi (derece): "Güneşle ayarla" ile bulunur, ölçülen yöne eklenir.
  static double get qiblaCorrection => _p.getDouble('kibleDuzeltme') ?? 0;
  static Future<void> setQiblaCorrection(double v) => _p.setDouble('kibleDuzeltme', v);

  static bool get notifySocial => _p.getBool('notifySocial') ?? true;
  static Future<void> setNotifySocial(bool v) => _p.setBool('notifySocial', v);
}
