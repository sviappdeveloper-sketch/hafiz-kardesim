import 'package:flutter/material.dart';

import '../models/constants.dart';
import '../models/models.dart';
import '../services/stats_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/ornaments.dart';
import '../l10n/l10n.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, required this.me});
  final AppUser me;
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late Future<StatsSnapshot> _future = StatsService.load(widget.me.id);

  Future<void> _refresh() async {
    final f = StatsService.load(widget.me.id);
    setState(() => _future = f);
    await f;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(lt('İstatistikler'))),
      body: PatternBackground(
        child: FutureBuilder<StatsSnapshot>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) {
              return EmptyState(
                title: lt('İstatistikler yüklenemedi'),
                message: errorText(snap.error!),
                action: GoldButton(label: lt('Tekrar dene'), onPressed: _refresh),
              );
            }
            if (!snap.hasData) return const LoadingView();
            final s = snap.data!;
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                children: [
                  _MyCard(s: s, me: widget.me),
                  const SizedBox(height: 24),
                  SectionTitle(lt('Genel')),
                  const SizedBox(height: 10),
                  _BigNumbers(s: s),
                  const SizedBox(height: 14),
                  _Breakdown(title: lt('Gruplar'), items: [
                    (lt('Cüz alınabilen'), s.groupsByStatus[GroupStatus.forming] ?? 0, AppColors.gold),
                    (lt('Tüm cüzleri alınan'), s.groupsByStatus[GroupStatus.active] ?? 0, AppColors.reading),
                    (lt('Hatmi tamamlanan'), s.groupsByStatus[GroupStatus.completed] ?? 0, AppColors.done),
                  ]),
                  const SizedBox(height: 14),
                  _Breakdown(title: lt('Cüzler (şu an)'), items: [
                    (lt('Boşta'), s.juzByStatus[JuzStatus.empty] ?? 0, AppColors.muted),
                    (lt('Alınan'), s.juzByStatus[JuzStatus.taken] ?? 0, AppColors.gold),
                    (lt('Okunuyor'), s.juzByStatus[JuzStatus.reading] ?? 0, AppColors.reading),
                    (lt('Okunan'), s.juzByStatus[JuzStatus.done] ?? 0, AppColors.done),
                  ]),
                  const SizedBox(height: 24),
                  SectionTitle(lt('Sıralamalar')),
                  const SizedBox(height: 10),
                  _Leaderboard(
                    title: lt('En çok hatim çıkaran gruplar'),
                    icon: Icons.groups_2_outlined,
                    empty: lt('Henüz tamamlanan hatim yok.'),
                    rows: [for (final g in s.topGroups) (g.name, '${g.hatimCount}', lt('hatim'))],
                  ),
                  const SizedBox(height: 14),
                  _Leaderboard(
                    title: lt('En çok cüz okuyanlar'),
                    icon: Icons.menu_book_outlined,
                    empty: lt('Henüz okunan cüz yok.'),
                    rows: [for (final u in s.topReaders) (u.name, '${u.totalJuzRead}', lt('cüz'))],
                    highlight: widget.me.name,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Kişisel özet: toplam okunan cüz büyük, şu anki cüzlerin durumu çubukla.
class _MyCard extends StatelessWidget {
  const _MyCard({required this.s, required this.me});
  final StatsSnapshot s;
  final AppUser me;

  @override
  Widget build(BuildContext context) {
    final items = [
      (lt('Aldım'), s.myJuz[JuzStatus.taken] ?? 0, AppColors.gold),
      (lt('Okuyorum'), s.myJuz[JuzStatus.reading] ?? 0, AppColors.reading),
      (lt('Okudum'), s.myJuz[JuzStatus.done] ?? 0, AppColors.done),
    ];
    return OrnateCard(
      highlight: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(lt('Benim'), style: AppText.label()),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${me.totalJuzRead}', style: AppText.number(46, color: AppColors.goldLight)),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(lt('bugüne kadar okuduğum cüz'), style: AppText.body(14, color: AppColors.muted)),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        Text(lt('Şu anki hatimlerimde'), style: AppText.body(13, color: AppColors.muted, weight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: _MiniTile(label: items[i].$1, value: items[i].$2, color: items[i].$3)),
          ],
        ]),
      ]),
    );
  }
}

class _MiniTile extends StatelessWidget {
  const _MiniTile({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Column(children: [
          Text('$value', style: AppText.number(22, color: color)),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(12, color: AppColors.ivory)),
        ]),
      );
}

class _BigNumbers extends StatelessWidget {
  const _BigNumbers({required this.s});
  final StatsSnapshot s;

  @override
  Widget build(BuildContext context) {
    Widget cell(int? value, String label) => Expanded(
          child: Column(children: [
            Text('${value ?? 0}', style: AppText.number(30, color: AppColors.goldLight)),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center, style: AppText.body(12, color: AppColors.muted)),
          ]),
        );
    Widget sep() => Container(width: 1, height: 40, color: AppColors.inkLine);
    return OrnateCard(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      child: Row(children: [
        cell(s.totals['hatimsCompleted'], lt('tamamlanan\nhatim')),
        sep(),
        cell(s.totals['juzRead'], lt('okunan\ncüz')),
        sep(),
        cell(s.totals['groupsCreated'], lt('kurulan\ngrup')),
      ]),
    );
  }
}

/// Başlık + toplam, oranları gösteren renkli çubuk ve iki sütunlu açıklama.
class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.title, required this.items});
  final String title;
  final List<(String, int, Color)> items;

  @override
  Widget build(BuildContext context) {
    final total = items.fold<int>(0, (a, e) => a + e.$2);
    return OrnateCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(title, style: AppText.body(15, weight: FontWeight.w700))),
          Text(lt('Toplam {0}', [total]), style: AppText.body(13, color: AppColors.muted, weight: FontWeight.w600)),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: total == 0
                ? Container(color: AppColors.inkLine)
                : Row(children: [
                    for (final e in items)
                      if (e.$2 > 0) Expanded(flex: e.$2, child: Container(color: e.$3)),
                  ]),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, c) {
          final w = (c.maxWidth - 12) / 2;
          return Wrap(spacing: 12, runSpacing: 10, children: [
            for (final e in items)
              SizedBox(
                width: w,
                child: Row(children: [
                  Container(width: 9, height: 9, decoration: BoxDecoration(color: e.$3, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(e.$1, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: AppText.body(13, color: AppColors.muted)),
                  ),
                  Text('${e.$2}', style: AppText.number(15, color: AppColors.ivory)),
                ]),
              ),
          ]);
        }),
      ]),
    );
  }
}

class _Leaderboard extends StatelessWidget {
  const _Leaderboard({required this.title, required this.icon, required this.rows, required this.empty, this.highlight});
  final String title;
  final IconData icon;
  final List<(String, String, String)> rows;
  final String empty;
  final String? highlight;

  @override
  Widget build(BuildContext context) {
    return OrnateCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(icon, size: 20, color: AppColors.gold),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: AppText.body(15, weight: FontWeight.w700))),
        ]),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(empty, style: AppText.body(14, color: AppColors.muted)),
          )
        else
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppColors.inkLine),
            _RankRow(rank: i + 1, row: rows[i], me: rows[i].$1 == highlight),
          ],
      ]),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.rank, required this.row, required this.me});
  final int rank;
  final (String, String, String) row;
  final bool me;

  @override
  Widget build(BuildContext context) {
    final top = rank <= 3;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: me
          ? BoxDecoration(color: AppColors.gold.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10))
          : null,
      child: Row(children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: top ? AppColors.gold.withValues(alpha: rank == 1 ? 1.0 : rank == 2 ? 0.7 : 0.45) : Colors.transparent,
            border: top ? null : Border.all(color: AppColors.inkLine),
          ),
          child: Text('$rank',
              style: AppText.number(13, color: top ? AppColors.inkDeep : AppColors.muted)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(row.$1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(14,
                  weight: me ? FontWeight.w800 : FontWeight.w500,
                  color: me ? AppColors.goldLight : AppColors.ivory)),
        ),
        Text(row.$2, style: AppText.number(16, color: AppColors.gold)),
        const SizedBox(width: 4),
        Text(row.$3, style: AppText.body(12, color: AppColors.muted)),
      ]),
    );
  }
}
