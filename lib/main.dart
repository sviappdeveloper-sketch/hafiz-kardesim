import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'services/update_service.dart';
import 'services/widget_service.dart';
import 'theme/app_theme.dart';
import 'l10n/l10n.dart';

/// Yakalanan son hatalar: ekranın altında gösterilir (boş ekranda kalınca sebebi görünsün).
final hataGunlugu = ValueNotifier<List<String>>(const []);

void _hataKaydet(Object e, StackTrace? st) {
  final satir = st?.toString().split('\n').where((l) => l.contains('package:hafiz_kardesim')).take(3).join('\n') ?? '';
  final yeni = [...hataGunlugu.value, '$e${satir.isEmpty ? '' : '\n$satir'}'];
  hataGunlugu.value = yeni.length > 3 ? yeni.sublist(yeni.length - 3) : yeni;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (d) {
    FlutterError.presentError(d);
    _hataKaydet(d.exception, d.stack);
  };
  PlatformDispatcher.instance.onError = (e, st) {
    _hataKaydet(e, st);
    return true;
  };
  // Çizim hatası olan bölüm gri kutu yerine hatanın kendisini gösterir.
  ErrorWidget.builder = (d) => Material(
        color: const Color(0xFF3A0D12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('Hata: ${d.exceptionAsString()}', style: const TextStyle(color: Colors.white, fontSize: 12)),
        ),
      );
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SettingsService.init();
  _applySystemBars();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  NotificationService.init();
  // Ana ekran widget'ı: açılışta ve il değişince güncellenir.
  WidgetService.refresh();
  SettingsService.city.addListener(WidgetService.refresh);
  SettingsService.langCode.addListener(WidgetService.refresh);
  runApp(const HatimKardesimApp());
  // Play'de yeni sürüm varsa güncelleme ekranı hemen açılır.
  UpdateService.check();
}

void _applySystemBars() {
  final light = AppColors.isLight;
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: light ? Brightness.dark : Brightness.light,
    statusBarBrightness: light ? Brightness.light : Brightness.dark,
    systemNavigationBarColor: AppColors.inkDeep,
    systemNavigationBarIconBrightness: light ? Brightness.dark : Brightness.light,
  ));
}

class HatimKardesimApp extends StatefulWidget {
  const HatimKardesimApp({super.key});

  @override
  State<HatimKardesimApp> createState() => _HatimKardesimAppState();
}

class _HatimKardesimAppState extends State<HatimKardesimApp> {
  @override
  void initState() {
    super.initState();
    SettingsService.themeId.addListener(_onTheme);
    SettingsService.langCode.addListener(_onTheme);
  }

  @override
  void dispose() {
    SettingsService.themeId.removeListener(_onTheme);
    SettingsService.langCode.removeListener(_onTheme);
    super.dispose();
  }

  /// Tema ya da dil değişince uygulama sıfırdan kurulmaz (açık sayfalar kapanmasın diye);
  /// renkler ve metinler doğrudan okunduğu için bütün ekranlar yerinde yeniden çizilir.
  void _onTheme() {
    _applySystemBars();
    setState(() {});
    void rebuild(Element e) {
      e.markNeedsBuild();
      e.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hafız Kardeşim',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      locale: Locale(Lang.code),
      supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Ayarlardaki "Yazı boyutu" bütün ekranlara uygulanır (telefonun kendi ayarıyla çarpılır).
      builder: (context, child) => ValueListenableBuilder<double>(
        valueListenable: SettingsService.textScale,
        builder: (context, scale, _) {
          final mq = MediaQuery.of(context);
          final sys = mq.textScaler.scale(1);
          return MediaQuery(
            data: mq.copyWith(textScaler: TextScaler.linear((sys * scale).clamp(0.8, 2.0))),
            child: Stack(children: [
              child!,
              // Yakalanan hata varsa altta küçük bir şerit: dokununca kapanır.
              ValueListenableBuilder<List<String>>(
                valueListenable: hataGunlugu,
                builder: (_, l, __) => l.isEmpty
                    ? const SizedBox.shrink()
                    : Positioned(
                        left: 8,
                        right: 8,
                        bottom: 24,
                        child: GestureDetector(
                          onTap: () => hataGunlugu.value = const [],
                          child: Material(
                            color: const Color(0xEE3A0D12),
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Text(l.join('\n—\n'),
                                  maxLines: 14,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 11)),
                            ),
                          ),
                        ),
                      ),
              ),
            ]),
          );
        },
      ),
      home: const SplashScreen(),
    );
  }
}
