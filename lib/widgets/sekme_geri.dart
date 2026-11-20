import 'package:flutter/material.dart';

/// Alt sekmelerin (Hoca–Öğrenci, Arkadaşlar, Daha fazla) üstündeki geri oku.
///
/// Android'de geri hareketi bu sekmelerden ana sayfaya döner; iPhone'da kenardan kaydırma
/// sekmelerde çalışmadığı için üst çubukta ok işaretli bir geri düğmesi gösterilir.
class SekmeGeri extends InheritedWidget {
  const SekmeGeri({super.key, required this.anaya, required super.child});

  /// Ana sayfa sekmesine döner.
  final VoidCallback anaya;

  static VoidCallback? _bul(BuildContext context) => context.dependOnInheritedWidgetOfExactType<SekmeGeri>()?.anaya;

  /// Sekmenin içindeyse geri oku, değilse null (sayfa açılmış bir ekransa Flutter kendi okunu koyar).
  static Widget? dugme(BuildContext context) {
    final f = _bul(context);
    if (f == null) return null;
    return IconButton(tooltip: 'Geri', icon: const Icon(Icons.arrow_back), onPressed: f);
  }

  @override
  bool updateShouldNotify(SekmeGeri old) => false;
}
