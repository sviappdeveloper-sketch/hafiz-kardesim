import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Rub'ül-hizb yıldızı: iç içe geçmiş iki kare.
Path starPath(Offset c, double r) {
  final p = Path();
  for (final rot in [0.0, math.pi / 4]) {
    for (var i = 0; i < 4; i++) {
      final a = rot + i * math.pi / 2 - math.pi / 4;
      final pt = c + Offset(math.cos(a), math.sin(a)) * r;
      if (i == 0) {
        p.moveTo(pt.dx, pt.dy);
      } else {
        p.lineTo(pt.dx, pt.dy);
      }
    }
    p.close();
  }
  return p;
}

/// Zemine işlenen çok hafif nokta deseni (yıldız şekli kullanılmaz).
class StarPatternPainter extends CustomPainter {
  StarPatternPainter({this.opacity = 0.07});
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    const step = 36.0;
    final dot = Paint()..color = AppColors.gold.withValues(alpha: opacity * 1.2);
    for (double y = 0; y < size.height + step; y += step) {
      final offsetX = ((y / step).round().isOdd) ? step / 2 : 0.0;
      for (double x = -step; x < size.width + step; x += step) {
        canvas.drawCircle(Offset(x + offsetX, y), 1.1, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant StarPatternPainter old) => old.opacity != opacity;
}

class PatternBackground extends StatelessWidget {
  const PatternBackground({super.key, required this.child, this.opacity = 0.06});
  final Widget child;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.9),
                radius: 1.4,
                colors: [AppColors.inkSoft, AppColors.ink, AppColors.inkDeep],
                stops: [0, 0.55, 1],
              ),
            ),
          ),
        ),
        Positioned.fill(child: CustomPaint(painter: StarPatternPainter(opacity: opacity))),
        child,
      ],
    );
  }
}

/// Uygulamanın logosu: altın halka içinde Kûfi "el-Kur'ân".
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 48, this.glow = 0, this.opacity = 1});
  final double size;
  final double glow;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    Widget logo = Image.asset('assets/logo/logo.png', width: size, height: size, filterQuality: FilterQuality.medium);
    if (opacity < 1) logo = Opacity(opacity: opacity, child: logo);
    if (glow <= 0) return logo;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.28 * glow), blurRadius: size * 0.45)],
      ),
      child: logo,
    );
  }
}

class GoldDivider extends StatelessWidget {
  const GoldDivider({super.key, this.width});
  final double? width;

  @override
  Widget build(BuildContext context) {
    Widget line(bool left) => Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: left
                    ? [AppColors.gold.withValues(alpha: 0), AppColors.gold]
                    : [AppColors.gold, AppColors.gold.withValues(alpha: 0)],
              ),
            ),
          ),
        );
    return SizedBox(
      width: width,
      child: Row(
        children: [
          line(true),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Transform.rotate(
              angle: math.pi / 4,
              child: Container(width: 7, height: 7, color: AppColors.gold),
            ),
          ),
          line(false),
        ],
      ),
    );
  }
}

class OrnateCard extends StatelessWidget {
  const OrnateCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.onTap, this.highlight = false});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Ink(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: radius,
            color: AppColors.inkSoft.withValues(alpha: 0.82),
            border: Border.all(color: AppColors.gold.withValues(alpha: highlight ? 0.7 : 0.26)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Mihrap kemeri şeklinde yol (sivri kemer).
Path mihrabPath(Size s) {
  final w = s.width, h = s.height;
  final archH = w * 0.46;
  return Path()
    ..moveTo(0, h)
    ..lineTo(0, archH)
    ..cubicTo(0, archH * 0.45, w * 0.32, archH * 0.14, w / 2, 0)
    ..cubicTo(w * 0.68, archH * 0.14, w, archH * 0.45, w, archH)
    ..lineTo(w, h)
    ..close();
}

class _MihrabPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final outer = mihrabPath(size);
    canvas.drawPath(
      outer,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.palette.id == 'gece' ? const Color(0xFF15386E) : const Color(0xFF1A4A3F), AppColors.inkSoft, AppColors.inkDeep],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      outer,
      Paint()
        ..color = AppColors.gold.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    // İç çizgi
    const inset = 6.0;
    final inner = mihrabPath(Size(size.width - inset * 2, size.height - inset * 2)).shift(const Offset(inset, inset));
    canvas.drawPath(
      inner,
      Paint()
        ..color = AppColors.gold.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Ana menünün mihrap biçimli düğmesi.
class MihrabTile extends StatelessWidget {
  const MihrabTile({super.key, required this.icon, required this.label, required this.onTap, this.badge = 0});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: LayoutBuilder(builder: (context, c) {
          final size = Size(c.maxWidth, c.maxHeight);
          return CustomPaint(
            painter: _MihrabPainter(),
            child: ClipPath(
              clipper: _MihrabClipper(),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  splashColor: AppColors.gold.withValues(alpha: 0.15),
                  child: SizedBox.fromSize(
                    size: size,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                                  color: AppColors.inkDeep.withValues(alpha: 0.5),
                                ),
                                child: Icon(icon, color: AppColors.goldLight, size: 26),
                              ),
                              if (badge > 0)
                                Positioned(
                                  right: -4,
                                  top: -4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.gold,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text('$badge',
                                        style: AppText.body(11, color: AppColors.inkDeep, weight: FontWeight.w800)),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: AppText.display(19, color: AppColors.ivory),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _MihrabClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => mihrabPath(size);
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class GoldButton extends StatelessWidget {
  const GoldButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.outlined = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final fg = outlined ? AppColors.goldLight : AppColors.inkDeep;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? onPressed : null,
          child: Ink(
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: outlined
                  ? null
                  : LinearGradient(colors: [AppColors.gold, AppColors.goldLight, AppColors.gold]),
              border: outlined ? Border.all(color: AppColors.gold.withValues(alpha: 0.7)) : null,
            ),
            child: Center(
              child: busy
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[Icon(icon, color: fg, size: 20), const SizedBox(width: 8)],
                        Flexible(
                          child: Text(label,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.body(15, color: fg, weight: FontWeight.w700)),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? AppColors.gold;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Text(text, style: AppText.body(12, color: color, weight: FontWeight.w700)),
      );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.gold.withValues(alpha: 0.85),
              border: Border.all(color: AppColors.goldLight.withValues(alpha: 0.6)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppText.display(22, color: AppColors.goldLight))),
          if (trailing != null) trailing!,
        ],
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, required this.message, this.action});
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(size: 64, opacity: 0.6),
            const SizedBox(height: 18),
            Text(title, textAlign: TextAlign.center, style: AppText.display(24)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: AppText.body(14, color: AppColors.muted)),
            if (action != null) ...[const SizedBox(height: 22), action!],
          ],
        ),
      );
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}
