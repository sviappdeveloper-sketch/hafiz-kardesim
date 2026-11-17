import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';

import '../data/cities.dart';
import '../l10n/l10n.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/ornaments.dart';

/// Kıble pusulası: seçilen ilin konumuna göre Kâbe yönü.
///
/// Yön kaynağı:
/// - Android: uygulamanın kendi yerel kodu (MainActivity.kt, "hatim/kible"): işletim sisteminin
///   birleştirilmiş döndürme vektörü; telefon dik tutulunca arka kameranın yönü; manyetik sapma
///   ilin koordinatına göre hesaplanır. Gelen yön gerçek kuzeye göredir.
/// - iPhone: flutter_compass (CLLocationManager'ın kalibre manyetik yönü) + yaklaşık sapma.
/// Ekrandaki ibre, gelen yöne her karede yumuşakça yaklaşır; titreme ve sıçrama görünmez.
class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> with SingleTickerProviderStateMixin {
  static const _kaabaLat = 21.4225, _kaabaLon = 39.8262;
  static const _channel = EventChannel('hatim/kible');

  /// iPhone için Türkiye'de manyetik sapma (yaklaşık +5..+7°).
  static const _iosDeclination = 6.0;

  StreamSubscription<dynamic>? _sub;
  Ticker? _ticker;
  Duration _lastTick = Duration.zero;

  double? _raw; // algılayıcıdan gelen yön (gerçek kuzey, düzeltmesiz)
  double? _target; // düzeltme eklenmiş yön
  double? _shown; // ekranda gösterilen, yumuşatılmış yön
  int _accuracy = 3; // 0: güvenilmez … 3: yüksek
  String? _source; // 'google' | 'sensor' | 'ios'
  double? _errDeg; // tahmini hata payı (derece)
  bool _noSensor = false;
  bool _wasAligned = false;
  Timer? _sensorWait;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _start();
  }

  void _start() {
    _sub?.cancel();
    final city = SettingsService.city.value;
    final c = city == null ? null : turkishCities[city];
    if (!kIsWeb && Platform.isAndroid) {
      _sub = _channel
          .receiveBroadcastStream(c == null ? null : {'lat': c.$1, 'lon': c.$2})
          .listen(_onAndroid, onError: (_) => _markNoSensor());
    } else {
      final events = FlutterCompass.events;
      if (events == null) {
        _noSensor = true;
      } else {
        _sub = events.listen(_onIos, onError: (_) => _markNoSensor());
      }
    }
    _sensorWait?.cancel();
    _sensorWait = Timer(const Duration(seconds: 3), () {
      if (mounted && _target == null) setState(() => _noSensor = true);
    });
  }

  void _markNoSensor() {
    if (mounted) setState(() => _noSensor = true);
  }

  void _onAndroid(dynamic e) {
    if (e is! List || e.isEmpty) return;
    final h = (e[0] as num).toDouble();
    final acc = e.length > 1 ? (e[1] as num).toInt() : 3;
    final src = e.length > 3 ? e[3] as String? : null;
    final err = e.length > 4 ? (e[4] as num).toDouble() : -1.0;
    _setRaw(h);
    if (src != _source || ((err - (_errDeg ?? -1)).abs() >= 1)) {
      setState(() {
        _source = src;
        _errDeg = err >= 0 && err < 179 ? err : null;
      });
    }
    if (acc != _accuracy || _noSensor) {
      setState(() {
        _accuracy = acc;
        _noSensor = false;
      });
    }
  }

  void _onIos(CompassEvent e) {
    final raw = e.heading;
    if (raw == null) {
      if (_target == null) _markNoSensor();
      return;
    }
    _setRaw(raw + _iosDeclination);
    _source ??= 'ios';
    final acc = e.accuracy;
    // iPhone'da doğruluk derece cinsinden (küçük = iyi).
    final level = acc == null || acc < 0 ? 0 : (acc <= 15 ? 3 : (acc <= 30 ? 2 : 1));
    if (level != _accuracy || _noSensor) {
      setState(() {
        _accuracy = level;
        _noSensor = false;
      });
    }
  }

  void _setRaw(double h) {
    _raw = (h % 360 + 360) % 360;
    _target = (_raw! + SettingsService.qiblaCorrection + 720) % 360;
  }

  /// Güneşin yönü (azimut, kuzeyden saat yönünde) ve yüksekliği; NOAA yaklaşık formülü.
  static (double, double) sunPosition(double lat, double lon, DateTime t) {
    final u = t.toUtc();
    final doy = u.difference(DateTime.utc(u.year)).inDays + 1;
    final hour = u.hour + u.minute / 60 + u.second / 3600;
    final g = 2 * math.pi / 365 * (doy - 1 + (hour - 12) / 24);
    final eqt = 229.18 *
        (0.000075 + 0.001868 * math.cos(g) - 0.032077 * math.sin(g) - 0.014615 * math.cos(2 * g) -
            0.040849 * math.sin(2 * g));
    final decl = 0.006918 - 0.399912 * math.cos(g) + 0.070257 * math.sin(g) - 0.006758 * math.cos(2 * g) +
        0.000907 * math.sin(2 * g) - 0.002697 * math.cos(3 * g) + 0.00148 * math.sin(3 * g);
    final tst = hour * 60 + eqt + 4 * lon;
    final ha = (tst / 4 - 180) * math.pi / 180;
    final la = lat * math.pi / 180;
    final cosZ = math.sin(la) * math.sin(decl) + math.cos(la) * math.cos(decl) * math.cos(ha);
    final elev = 90 - math.acos(cosZ.clamp(-1.0, 1.0)) * 180 / math.pi;
    final az = (math.atan2(math.sin(ha), math.cos(ha) * math.sin(la) - math.tan(decl) * math.cos(la)) * 180 / math.pi +
            180) %
        360;
    return (az, elev);
  }

  Future<void> _sunCalibrate((double, double) c) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.ink,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        final (az, elev) = sunPosition(c.$1, c.$2, DateTime.now());
        final up = elev > 3;
        final raw = _raw;
        // Telefonu güneşe tutarken ekranda canlı yön görünsün.
        Future.delayed(const Duration(milliseconds: 200), () {
          if (ctx.mounted) setS(() {});
        });
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.wb_sunny_outlined, color: AppColors.goldLight),
                const SizedBox(width: 10),
                Text(lt('Güneşle ayarla'), style: AppText.display(20)),
              ]),
              const SizedBox(height: 12),
              if (!up)
                Text(lt('Güneş şu an ufkun altında. Bu ayar gündüz, güneş görünürken yapılabilir.'),
                    style: AppText.body(14, color: AppColors.muted))
              else ...[
                Text(
                    lt('Güneşe dönün ve telefonu dik tutarak (fotoğrafını çeker gibi) arkasını güneşe doğrultun. Güneşe doğrudan bakmayın; telefonun gölgesi tam arkanıza düşsün. Sonra "Şimdi ayarla"ya basın.'),
                    style: AppText.body(14, color: AppColors.ivory)),
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _Info(label: lt('Güneşin yönü'), value: '${az.toStringAsFixed(0)}°'),
                  _Info(
                      label: lt('Pusulanın gösterdiği'),
                      value: raw == null
                          ? '—'
                          : '${((raw + SettingsService.qiblaCorrection) % 360).toStringAsFixed(0)}°'),
                ]),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: GoldButton(
                    label: lt('Şimdi ayarla'),
                    icon: Icons.check,
                    onPressed: raw == null
                        ? null
                        : () async {
                            final corr = _diff(az, raw);
                            await SettingsService.setQiblaCorrection(corr);
                            if (_raw != null) _setRaw(_raw!);
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              showSnack(context, lt('Pusula güneşe göre ayarlandı ({0}° düzeltme).', [corr.toStringAsFixed(0)]));
                            }
                          },
                  ),
                ),
              ],
              if (SettingsService.qiblaCorrection != 0) ...[
                const SizedBox(height: 10),
                Center(
                  child: TextButton(
                    onPressed: () async {
                      await SettingsService.setQiblaCorrection(0);
                      if (_raw != null) _setRaw(_raw!);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: Text(lt('Ayarı sıfırla ({0}°)', [SettingsService.qiblaCorrection.toStringAsFixed(0)]),
                        style: AppText.body(13, color: AppColors.muted)),
                  ),
                ),
              ],
            ]),
          ),
        );
      }),
    );
    if (mounted) setState(() {});
  }

  static double _diff(double a, double b) => ((a - b + 540) % 360) - 180;

  void _onTick(Duration now) {
    final dt = ((now - _lastTick).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _lastTick = now;
    final t = _target;
    if (t == null) return;
    final s = _shown;
    if (s == null) {
      setState(() => _shown = t);
      return;
    }
    final d = _diff(t, s);
    if (d.abs() < 0.05) return;
    // Kritik sönümlü yaklaşma: büyük dönüşlerde hızlı, küçük titreşimlerde sakin.
    final k = 1 - math.exp(-dt * 9);
    setState(() => _shown = (s + d * k + 360) % 360);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sensorWait?.cancel();
    _ticker?.dispose();
    super.dispose();
  }

  static double qiblaBearing(double lat, double lon) {
    final p1 = lat * math.pi / 180, p2 = _kaabaLat * math.pi / 180;
    final dl = (_kaabaLon - lon) * math.pi / 180;
    final y = math.sin(dl) * math.cos(p2);
    final x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  static double distanceKm(double lat, double lon) {
    const r = 6371.0;
    final p1 = lat * math.pi / 180, p2 = _kaabaLat * math.pi / 180;
    final dp = p2 - p1, dl = (_kaabaLon - lon) * math.pi / 180;
    final a = math.pow(math.sin(dp / 2), 2) + math.cos(p1) * math.cos(p2) * math.pow(math.sin(dl / 2), 2);
    return 2 * r * math.asin(math.sqrt(a.toDouble()));
  }

  @override
  Widget build(BuildContext context) {
    final city = SettingsService.city.value;
    final c = city == null ? null : turkishCities[city];
    return Scaffold(
      appBar: AppBar(title: Text(lt('Kıble pusulası'))),
      body: PatternBackground(
        child: c == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(lt('Kıble yönü için önce ana sayfadan ilinizi seçin.'),
                      textAlign: TextAlign.center, style: AppText.body(15, color: AppColors.muted)),
                ),
              )
            : _body(city!, c),
      ),
    );
  }

  Widget _body(String city, (double, double) c) {
    final qibla = qiblaBearing(c.$1, c.$2);
    final h = _shown;
    final diff = h == null ? 0.0 : _diff(qibla, h);
    final aligned = h != null && diff.abs() <= 3;
    if (aligned && !_wasAligned) HapticFeedback.mediumImpact();
    _wasAligned = aligned;
    final size = math.min(MediaQuery.sizeOf(context).width - 24, 380.0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 40),
      children: [
        Center(
          child: SizedBox(
            width: size,
            height: size,
            child: _noSensor && h == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                          lt('Bu telefonda pusula algılayıcısı bulunamadı. Kıble açısını kuzeye göre {0}° olarak kullanabilirsiniz.',
                              [qibla.toStringAsFixed(0)]),
                          textAlign: TextAlign.center,
                          style: AppText.body(14, color: AppColors.muted)),
                    ),
                  )
                : TweenAnimationBuilder<double>(
                    tween: Tween(end: aligned ? 1 : 0),
                    duration: const Duration(milliseconds: 350),
                    builder: (_, glow, __) => CustomPaint(
                      painter: _ArrowCompassPainter(
                        heading: h ?? 0,
                        qibla: qibla,
                        glow: glow,
                        gold: AppColors.gold,
                        goldLight: AppColors.goldLight,
                        ink: AppColors.inkDeep,
                        ivory: AppColors.ivory,
                        labels: [lt('K'), lt('D'), lt('G'), lt('B')],
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        if (h != null) ...[
          Text('${h.toStringAsFixed(0)}°', textAlign: TextAlign.center, style: AppText.number(40, color: AppColors.ivory)),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: aligned
                ? Row(
                    key: const ValueKey('ok'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: AppColors.goldLight, size: 22),
                      const SizedBox(width: 8),
                      Text(lt('Kıble yönündesiniz'), style: AppText.display(21, color: AppColors.goldLight)),
                    ],
                  )
                : Text(
                    key: ValueKey(diff > 0),
                    diff > 0
                        ? lt('Sağa dönün: {0}°', [diff.abs().toStringAsFixed(0)])
                        : lt('Sola dönün: {0}°', [diff.abs().toStringAsFixed(0)]),
                    textAlign: TextAlign.center,
                    style: AppText.display(21, color: AppColors.ivory),
                  ),
          ),
        ],
        const SizedBox(height: 16),
        Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
          _Chip(icon: Icons.explore_outlined, text: lt('{0} için kıble açısı', [city]) + ': ${qibla.toStringAsFixed(0)}°'),
          _Chip(icon: Icons.place_outlined, text: lt('Kâbe\'ye uzaklık: {0} km', [distanceKm(c.$1, c.$2).toStringAsFixed(0)])),
        ]),
        if (_source != null) ...[
          const SizedBox(height: 10),
          Text(
            (_source == 'google'
                    ? lt('Yön kaynağı: Google yön servisi')
                    : _source == 'sensor'
                        ? lt('Yön kaynağı: telefonun algılayıcıları')
                        : lt('Yön kaynağı: iPhone pusulası')) +
                (_errDeg != null ? ' · ±${_errDeg!.toStringAsFixed(0)}°' : ''),
            textAlign: TextAlign.center,
            style: AppText.body(12, color: AppColors.muted),
          ),
        ],
        const SizedBox(height: 14),
        Center(
          child: OutlinedButton.icon(
            onPressed: () => _sunCalibrate(c),
            icon: Icon(Icons.wb_sunny_outlined, color: AppColors.goldLight, size: 20),
            label: Text(
                SettingsService.qiblaCorrection == 0
                    ? lt('Yön yanlışsa: Güneşle ayarla')
                    : lt('Güneşle ayarlı ({0}°) · yeniden ayarla', [SettingsService.qiblaCorrection.toStringAsFixed(0)]),
                style: AppText.body(13.5, weight: FontWeight.w700, color: AppColors.ivory)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.gold.withValues(alpha: 0.5)),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
          ),
        ),
        if (h != null && _accuracy <= 1) ...[
          const SizedBox(height: 16),
          OrnateCard(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.all_inclusive, color: AppColors.goldLight),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  lt('Pusula ayarı gerekli: telefonu havada birkaç kez 8 çizerek çevirin, sonra yere paralel tutun.'),
                  style: AppText.body(13.5, color: AppColors.ivory),
                ),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 16),
        OrnateCard(
          child: Text(
            lt('Telefonu yere paralel tutun, mıknatıs ve metal eşyalardan uzak durun. Yön şaşıyorsa telefonu havada birkaç kez 8 çizerek döndürün. Hesap ilin merkezine göredir.'),
            style: AppText.body(13, color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value, style: AppText.number(26, color: AppColors.goldLight)),
        const SizedBox(height: 2),
        Text(label, style: AppText.body(12, color: AppColors.muted)),
      ]);
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.ivory.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: AppColors.goldLight),
          const SizedBox(width: 6),
          Text(text, style: AppText.body(13, color: AppColors.ivory)),
        ]),
      );
}

/// "Ok ve Kâbe" pusulası: koyu yeşil kadran (derece çizgileri ve yön harfleri kuzeye göre
/// döner), ortadan çıkan büyük altın ok doğrudan kıbleyi gösterir, okun ucunda kadranın
/// dışında Kâbe durur. Üstteki küçük işaret telefonun baktığı yöndür. Kıbleye gelince ok ve
/// çerçeve parlar.
class _ArrowCompassPainter extends CustomPainter {
  _ArrowCompassPainter({
    required this.heading,
    required this.qibla,
    required this.glow,
    required this.gold,
    required this.goldLight,
    required this.ink,
    required this.ivory,
    required this.labels,
  });
  final double heading, qibla, glow;
  final Color gold, goldLight, ink, ivory;
  final List<String> labels;

  static const _north = Color(0xFFE07A5F);

  static Offset _polar(double deg, double r) {
    final a = deg * math.pi / 180;
    return Offset(math.sin(a) * r, -math.cos(a) * r);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final c = Offset(w / 2, w / 2);
    final outer = w / 2 - 4; // ince dış halka (Kâbe bunun üzerinde dolaşır)
    final R = outer - 40; // kadran

    // Parlama
    if (glow > 0) {
      canvas.drawCircle(
          c,
          R + 6,
          Paint()
            ..color = goldLight.withValues(alpha: 0.35 * glow)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 22 * glow));
    }

    // Dış ince halka
    canvas.drawCircle(
        c,
        outer - 18,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = goldLight.withValues(alpha: 0.22 + 0.4 * glow));

    // Kadran yüzü
    final face = Color.lerp(ink, const Color(0xFF1B6B4A), 0.55)!;
    canvas.drawCircle(
        c,
        R,
        Paint()
          ..shader = RadialGradient(colors: [face, Color.lerp(ink, Colors.black, 0.25)!], stops: const [0, 1])
              .createShader(Rect.fromCircle(center: c, radius: R)));
    canvas.drawCircle(
        c,
        R,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Color.lerp(gold.withValues(alpha: 0.35), goldLight, glow)!);

    // Derece çizgileri (kuzeye göre döner)
    for (var d = 0; d < 360; d += 5) {
      final major = d % 30 == 0;
      final a = d - heading;
      final len = major ? 15.0 : 7.0;
      canvas.drawLine(
          c + _polar(a, R - 6),
          c + _polar(a, R - 6 - len),
          Paint()
            ..strokeCap = StrokeCap.round
            ..strokeWidth = major ? 2.6 : 1.2
            ..color = d == 0 ? _north : (major ? ivory : ivory.withValues(alpha: 0.45)));
    }
    // Derece sayıları (her 30°, yön harfleri hariç; dik durur)
    for (var d = 30; d < 360; d += 30) {
      if (d % 90 == 0) continue;
      final tp = TextPainter(
        text: TextSpan(
            text: '$d',
            style: TextStyle(color: ivory.withValues(alpha: 0.75), fontSize: 12.5, fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr,
      )..layout();
      final p = c + _polar(d - heading, R - 38);
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
    // Yön harfleri (dik durur, konumları döner)
    for (var i = 0; i < 4; i++) {
      final tp = TextPainter(
        text: TextSpan(
            text: labels[i],
            style: TextStyle(color: i == 0 ? _north : ivory, fontSize: 19, fontWeight: FontWeight.w800)),
        textDirection: TextDirection.ltr,
      )..layout();
      final p = c + _polar(i * 90 - heading, R - 40);
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }

    // Telefonun baktığı yön: üstte küçük sabit işaret
    final mark = Path()
      ..moveTo(c.dx, c.dy - R + 2)
      ..lineTo(c.dx - 7, c.dy - R - 11)
      ..lineTo(c.dx + 7, c.dy - R - 11)
      ..close();
    canvas.drawPath(mark, Paint()..color = Color.lerp(ivory.withValues(alpha: 0.8), goldLight, glow)!);

    // Kıble oku
    final q = qibla - heading;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(q * math.pi / 180);
    final tipY = -(R - 26);
    final head = Path()
      ..moveTo(0, tipY)
      ..lineTo(17, -12)
      ..lineTo(0, 4)
      ..lineTo(-17, -12)
      ..close();
    canvas.drawPath(
        head.shift(const Offset(0, 3)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawPath(
        head,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [const Color(0xFFA9802F), Color.lerp(goldLight, Colors.white, 0.25 * glow)!],
          ).createShader(Rect.fromLTRB(-17, tipY, 17, 4)));
    // Okun ortasındaki ışık çizgisi
    canvas.drawLine(Offset(0, tipY + 6), const Offset(0, -6),
        Paint()
          ..strokeWidth = 1.2
          ..color = Colors.white.withValues(alpha: 0.35));
    final tail = Path()
      ..moveTo(0, 4)
      ..lineTo(10, 62)
      ..lineTo(0, 52)
      ..lineTo(-10, 62)
      ..close();
    canvas.drawPath(tail, Paint()..color = gold.withValues(alpha: 0.35));
    canvas.restore();

    // Kâbe: okun doğrultusunda, kadranın dışında (dik durur)
    final kp = c + _polar(q, outer - 18);
    final cube = Rect.fromCenter(center: kp, width: 30, height: 30);
    if (glow > 0) {
      canvas.drawCircle(
          kp,
          26,
          Paint()
            ..color = goldLight.withValues(alpha: 0.5 * glow)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    }
    canvas.drawRRect(RRect.fromRectAndRadius(cube.shift(const Offset(0, 2)), const Radius.circular(4)),
        Paint()..color = Colors.black.withValues(alpha: 0.4));
    canvas.drawRRect(RRect.fromRectAndRadius(cube, const Radius.circular(4)), Paint()..color = const Color(0xFF121212));
    canvas.drawRect(Rect.fromLTWH(cube.left, cube.top + 8, cube.width, 4), Paint()..color = goldLight);
    canvas.drawRRect(
        RRect.fromRectAndRadius(cube, const Radius.circular(4)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = goldLight);

    // Merkez
    canvas.drawCircle(c, 9, Paint()..color = Color.lerp(ink, Colors.black, 0.3)!);
    canvas.drawCircle(
        c,
        9,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..color = goldLight);
  }

  @override
  bool shouldRepaint(covariant _ArrowCompassPainter old) =>
      old.heading != heading || old.glow != glow || old.qibla != qibla;
}
