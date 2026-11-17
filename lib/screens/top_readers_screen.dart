import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/hatim_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/crown.dart';
import '../widgets/ornaments.dart';
import '../l10n/l10n.dart';


/// Ayın en çok cüz okuyan ilk 10 kişisi. Geçmiş aylar ayrı ayrı saklanır ve buradan seçilebilir.
class TopReadersScreen extends StatefulWidget {
  const TopReadersScreen({super.key, required this.me});
  final AppUser me;

  @override
  State<TopReadersScreen> createState() => _TopReadersScreenState();
}

class _TopReadersScreenState extends State<TopReadersScreen> {
  late final List<DateTime> _months = _buildMonths();
  late DateTime _selected = _months.first;

  static List<DateTime> _buildMonths() {
    final now = DateTime.now();
    final first = DateTime(2026, 10); // uygulamanın ilk kayıtları
    final list = <DateTime>[];
    for (var d = DateTime(now.year, now.month); !d.isBefore(first); d = DateTime(d.year, d.month - 1)) {
      list.add(d);
    }
    return list;
  }

  String _label(DateTime d) => '${monthName(d.month)} ${d.year}';

  @override
  Widget build(BuildContext context) {
    final key = HatimService.monthKey(_selected);
    final isCurrent = _selected == _months.first;
    return Scaffold(
      appBar: AppBar(title: Text(lt('Ayın En Çok Okuyanları'))),
      body: PatternBackground(
        child: Column(
          children: [
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _months.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final m = _months[i];
                  final sel = m == _selected;
                  return ChoiceChip(
                    label: Text(_label(m)),
                    selected: sel,
                    onSelected: (_) => setState(() => _selected = m),
                    selectedColor: AppColors.gold,
                    labelStyle: AppText.body(13, weight: FontWeight.w600, color: sel ? AppColors.inkDeep : AppColors.ivory),
                    backgroundColor: AppColors.inkSoft,
                    side: BorderSide(color: AppColors.gold.withValues(alpha: 0.4)),
                    showCheckmark: false,
                  );
                },
              ),
            ),
            Expanded(
              child: StreamBuilder<List<AppUser>>(
                stream: HatimService.topReaders(key),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(errorText(snap.error!))));
                  }
                  if (!snap.hasData) return const LoadingView();
                  final list = snap.data!;
                  if (list.isEmpty) {
                    return SingleChildScrollView(
                      child: EmptyState(
                        title: isCurrent ? lt('Bu ay henüz okunan cüz yok') : lt('{0} ayında kayıt yok', [_label(_selected)]),
                        message: isCurrent ? lt('İlk cüzü okuyan siz olun!') : lt('Bu ay için okunmuş cüz bulunmuyor.'),
                      ),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      for (var i = 0; i < list.length; i++) ...[
                        _ReaderRow(rank: i + 1, user: list[i], count: list[i].readsIn(key), isMe: list[i].id == widget.me.id),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        lt('Aynı sayıda cüz okuyanlardan o sayıya daha önce ulaşan üstte yer alır.'),
                        textAlign: TextAlign.center,
                        style: AppText.body(12, color: AppColors.muted),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderRow extends StatelessWidget {
  const _ReaderRow({required this.rank, required this.user, required this.count, required this.isMe});
  final int rank;
  final AppUser user;
  final int count;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final first = rank == 1;
    return OrnateCard(
      highlight: first || isMe,
      padding: const EdgeInsets.fromLTRB(16, 12, 18, 12),
      child: Row(children: [
        SizedBox(
          width: 40,
          height: 40,
          child: first
              ? Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [AppColors.goldLight, AppColors.gold]),
                  ),
                  child: const Center(child: CrownIcon(size: 22)),
                )
              : Center(child: Text('$rank', style: AppText.number(20, color: AppColors.gold))),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(isMe ? lt('{0} (siz)', [user.name]) : user.name,
              overflow: TextOverflow.ellipsis, style: AppText.display(first ? 21 : 19)),
        ),
        Column(children: [
          Text('$count', style: AppText.number(22, color: AppColors.goldLight)),
          Text(lt('cüz'), style: AppText.body(11, color: AppColors.muted)),
        ]),
      ]),
    );
  }
}
