import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/ornaments.dart';
import 'auth_gate.dart';

/// Hafif açılış: noktalı yeşil zeminde logonun merkezinden açılan altın el-Kur'ân logosu,
/// ardından uygulama yumuşakça açılır. Ekrana dokununca hemen geçilir.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  static const _logoAsset = AssetImage('assets/logo/logo.png');

  late final AnimationController _logo =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  late final AnimationController _out =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  Timer? _fallback;
  bool _started = false, _left = false;

  @override
  void initState() {
    super.initState();
    _fallback = Timer(const Duration(seconds: 10), _go);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _begin();
    }
  }

  Future<void> _begin() async {
    await Future.wait<void>([
      precacheImage(_logoAsset, context),
      Future<void>.delayed(const Duration(milliseconds: 300)),
    ]);
    if (!mounted || _left) return;
    await _logo.forward();
    if (!mounted || _left) return;
    _fallback?.cancel();
    // Toplam ≈5 sn: 300 bekleme + 2400 logo + 1700 duruş + 600 çıkış.
    _fallback = Timer(const Duration(milliseconds: 1700), _go);
  }

  Future<void> _go() async {
    if (_left || !mounted) return;
    _left = true;
    _fallback?.cancel();
    await _out.forward();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (_, __, ___) => const AuthGate(),
      transitionsBuilder: (_, a, __, child) =>
          FadeTransition(opacity: CurvedAnimation(parent: a, curve: Curves.easeInOut), child: child),
    ));
  }

  @override
  void dispose() {
    _fallback?.cancel();
    _logo.dispose();
    _out.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final logoSize = math.min(170.0, width * 0.42);
    final fade = ReverseAnimation(CurvedAnimation(parent: _out, curve: Curves.easeInOut));
    return Scaffold(
      backgroundColor: AppColors.inkDeep,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _go,
        child: Stack(children: [
          const Positioned.fill(child: RepaintBoundary(child: PatternBackground(opacity: 0.06, child: SizedBox.expand()))),
          Positioned.fill(
            child: FadeTransition(
              opacity: fade,
              child: Center(child: RepaintBoundary(child: _LogoReveal(animation: _logo, size: logoSize, image: _logoAsset))),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Logonun merkezinde bir nokta belirir ve daire biçiminde açılarak logoyu ortaya çıkarır.
class _LogoReveal extends AnimatedWidget {
  const _LogoReveal({required Animation<double> animation, required this.size, required this.image})
      : super(listenable: animation);
  final double size;
  final ImageProvider image;

  @override
  Widget build(BuildContext context) {
    final t = (listenable as Animation<double>).value;
    final open = Curves.easeInOutCubic.transform(t);
    // İlk anda görünen nokta: logonun tam merkezinde, altın renkli.
    final dotOpacity = t == 0 ? 0.0 : (1 - open * 1.6).clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (t > 0)
            ClipPath(
              clipper: _CircleClip(math.max(1.5, open * size * 0.72)),
              child: Image(image: image, width: size, height: size, filterQuality: FilterQuality.medium),
            ),
          if (dotOpacity > 0)
            Container(
              width: 6 + 6 * open,
              height: 6 + 6 * open,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.goldLight.withValues(alpha: dotOpacity),
              ),
            ),
        ],
      ),
    );
  }
}

class _CircleClip extends CustomClipper<Path> {
  _CircleClip(this.radius);
  final double radius;

  @override
  Path getClip(Size size) => Path()..addOval(Rect.fromCircle(center: size.center(Offset.zero), radius: radius));

  @override
  bool shouldReclip(covariant _CircleClip old) => old.radius != radius;
}

