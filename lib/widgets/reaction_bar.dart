import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/reaction_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../l10n/l10n.dart';

/// Bir cüze bırakılan tebrikleri gösterir; [canSend] ise hazır tebrik seçtirir.
class ReactionBar extends StatelessWidget {
  const ReactionBar({super.key, required this.me, required this.juz, required this.toUid, required this.canSend});
  final AppUser me;
  final Juz juz;
  final String toUid;
  final bool canSend;

  Future<void> _send(BuildContext context, String text) =>
      runGuarded(context, () => ReactionService.send(me: me, toUid: toUid, juz: juz, text: text),
          success: lt('Tebrikiniz iletildi.'));

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Reaction>>(
      stream: ReactionService.forJuz(juz.id),
      builder: (context, snap) {
        final list = snap.data ?? const <Reaction>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (list.isNotEmpty) ...[
              Text(lt('TEBRİKLER'), style: AppText.label()),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final r in list)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: AppColors.inkDeep,
                      side: BorderSide(color: AppColors.gold.withValues(alpha: 0.35)),
                      label: Text('${reactionLabel(r.text)} · ${r.fromUid == me.id ? lt('siz') : r.fromName.split(' ').first}',
                          style: AppText.body(12)),
                    ),
                ],
              ),
            ],
            if (canSend) ...[
              const SizedBox(height: 12),
              Text(lt('TEBRİK BIRAK'), style: AppText.label()),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in reactionEmojis)
                    ActionChip(
                      backgroundColor: AppColors.inkDeep,
                      side: BorderSide(color: AppColors.gold.withValues(alpha: 0.5)),
                      label: Text(e, style: const TextStyle(fontSize: 22)),
                      onPressed: () => _send(context, e),
                    ),
                  for (final p in reactionPhrases)
                    ActionChip(
                      backgroundColor: AppColors.inkDeep,
                      side: BorderSide(color: AppColors.gold.withValues(alpha: 0.5)),
                      label: Text(reactionLabel(p), style: AppText.body(13, color: AppColors.goldLight)),
                      onPressed: () => _send(context, p),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
