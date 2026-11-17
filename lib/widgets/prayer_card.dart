import 'dart:async';

import 'package:flutter/material.dart';

import '../screens/qibla_screen.dart';
import '../screens/settings_screen.dart';
import '../services/prayer_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import 'ornaments.dart';
import '../l10n/l10n.dart';

/// Ana sayfadaki ezan vakitleri kartı: seçilen ilin bugünkü vakitleri ve sıradaki vakte kalan süre.
class PrayerCard extends StatelessWidget {
  const PrayerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: SettingsService.city,
      builder: (context, city, _) {
        if (city == null) {
          return OrnateCard(
            onTap: () => pickCity(context),
            child: Row(children: [
              Icon(Icons.mosque_outlined, color: AppColors.gold, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(lt('EZAN VAKİTLERİ'), style: AppText.label()),
                  const SizedBox(height: 4),
                  Text(lt('İlinizi seçin, ezan vakitleri burada görünsün.'), style: AppText.body(14)),
                ]),
              ),
              Icon(Icons.chevron_right, color: AppColors.muted),
            ]),
          );
        }
        return _PrayerTimes(key: ValueKey(city), city: city);
      },
    );
  }
}

class _PrayerTimes extends StatefulWidget {
  const _PrayerTimes({super.key, required this.city});
  final String city;

  @override
  State<_PrayerTimes> createState() => _PrayerTimesState();
}

class _PrayerTimesState extends State<_PrayerTimes> {
  List<PrayerDay>? _days;
  Object? _error;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _load();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final d = await PrayerService.upcoming(widget.city, days: 2);
      if (mounted) setState(() => _days = d);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  String _hm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _left(Duration d) {
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final header = Row(children: [
      Icon(Icons.mosque_outlined, size: 16, color: AppColors.gold),
      const SizedBox(width: 8),
      Text(lt('EZAN VAKİTLERİ'), style: AppText.label()),
      const Spacer(),
      InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QiblaScreen())),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Row(children: [
            Icon(Icons.explore_outlined, size: 15, color: AppColors.gold),
            const SizedBox(width: 3),
            Text(lt('Kıble'), style: AppText.body(13, color: AppColors.gold, weight: FontWeight.w700)),
          ]),
        ),
      ),
      const SizedBox(width: 4),
      InkWell(
        onTap: () => pickCity(context),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Row(children: [
            Icon(Icons.location_on_outlined, size: 15, color: AppColors.muted),
            const SizedBox(width: 3),
            Text(widget.city, style: AppText.body(13, color: AppColors.muted, weight: FontWeight.w600)),
          ]),
        ),
      ),
    ]);

    if (_days == null) {
      return OrnateCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          header,
          const SizedBox(height: 14),
          if (_error == null)
            const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)))
          else ...[
            Text(lt('Vakitler alınamadı. İnternet bağlantınızı kontrol edip tekrar deneyin.'),
                style: AppText.body(13, color: AppColors.muted)),
            TextButton(onPressed: _load, child: Text(lt('Tekrar dene'))),
          ],
        ]),
      );
    }

    final now = DateTime.now();
    final today = _days!.firstWhere(
      (d) => d.date.year == now.year && d.date.month == now.month && d.date.day == now.day,
      orElse: () => _days!.first,
    );
    // Sıradaki vakit (yatsıdan sonra yarının imsakı).
    DateTime? next;
    var nextName = '';
    var current = -1;
    for (final d in _days!) {
      for (var i = 0; i < 6; i++) {
        if (d.times[i].isAfter(now)) {
          next = d.times[i];
          nextName = PrayerDay.names[i];
          break;
        }
      }
      if (next != null) break;
    }
    for (var i = 0; i < 6; i++) {
      if (!today.times[i].isAfter(now)) current = i;
    }

    return OrnateCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        header,
        const SizedBox(height: 6),
        if (next != null)
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Text(lt('{0} vaktine', [nextName]), style: AppText.body(13, color: AppColors.muted)),
            const SizedBox(width: 8),
            Expanded(
              child: FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(_left(next.difference(now)), style: AppText.number(24, color: AppColors.goldLight)),
              ),
            ),
            Text(_hm(next), style: AppText.number(15, color: AppColors.ivory)),
          ]),
        const SizedBox(height: 8),
        Row(children: [
          for (var i = 0; i < 6; i++)
            Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i == 5 ? 0 : 5),
                padding: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: i == current ? AppColors.gold.withValues(alpha: 0.16) : AppColors.inkDeep.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: i == current ? AppColors.gold : AppColors.inkLine),
                ),
                child: Column(children: [
                  FittedBox(
                    child: Text(PrayerDay.names[i],
                        style: AppText.body(11, color: i == current ? AppColors.gold : AppColors.muted, weight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 1),
                  FittedBox(child: Text(_hm(today.times[i]), style: AppText.number(13))),
                ]),
              ),
            ),
        ]),
      ]),
    );
  }
}
