import 'package:flutter/material.dart';

import '../models/constants.dart';
import '../models/models.dart';
import '../services/hatim_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/ornaments.dart';
import '../widgets/reaction_bar.dart';
import '../widgets/hafiz_rol.dart';
import 'group_detail_screen.dart';
import '../l10n/l10n.dart';

/// Arkadaşın katıldığı gruplar ve okuduğu cüzler; okunan cüzlere hazır tebrik bırakılabilir.
class FriendProfileScreen extends StatelessWidget {
  const FriendProfileScreen({super.key, required this.me, required this.friendUid, required this.friendName});
  final AppUser me;
  final String friendUid, friendName;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(friendName, overflow: TextOverflow.ellipsis),
            HafizRolEtiketi(uid: friendUid, size: 12),
          ]),
          bottom: TabBar(tabs: [Tab(text: lt('Cüzleri')), Tab(text: lt('Grupları'))]),
        ),
        body: PatternBackground(
          child: TabBarView(children: [
            _FriendJuz(me: me, friendUid: friendUid),
            _FriendGroups(me: me, friendUid: friendUid),
          ]),
        ),
      ),
    );
  }
}

class _FriendJuz extends StatelessWidget {
  const _FriendJuz({required this.me, required this.friendUid});
  final AppUser me;
  final String friendUid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Juz>>(
      stream: HatimService.juzOf(friendUid),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text(errorText(snap.error!)));
        if (!snap.hasData) return const LoadingView();
        final list = snap.data!;
        if (list.isEmpty) {
          return SingleChildScrollView(
            child: EmptyState(title: lt('Henüz cüzü yok'), message: lt('Arkadaşınız bir gruptan cüz aldığında burada görünecek.')),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final j = list[i];
            return OrnateCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  SizedBox(width: 48, child: Text('${j.number}', style: AppText.number(26, color: AppColors.goldLight))),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(lt('{0}. Cüz · {1}', [j.number, juzPages(j.number)]), style: AppText.body(14, weight: FontWeight.w600)),
                      Text(j.groupName, style: AppText.body(12, color: AppColors.muted)),
                    ]),
                  ),
                  StatusPill(JuzStatus.label(j.status), color: JuzStatus.color(j.status)),
                ]),
                if (j.isDone) ...[
                  const SizedBox(height: 12),
                  ReactionBar(me: me, juz: j, toUid: friendUid, canSend: true),
                ],
              ]),
            );
          },
        );
      },
    );
  }
}

class _FriendGroups extends StatelessWidget {
  const _FriendGroups({required this.me, required this.friendUid});
  final AppUser me;
  final String friendUid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<HatimGroup>>(
      stream: HatimService.myGroups(friendUid),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text(errorText(snap.error!)));
        if (!snap.hasData) return const LoadingView();
        final list = snap.data!;
        if (list.isEmpty) {
          return SingleChildScrollView(
            child: EmptyState(title: lt('Henüz grubu yok'), message: lt('Arkadaşınız bir hatim grubuna katıldığında burada görünecek.')),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final g = list[i];
            return OrnateCard(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: g.id, me: me))),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(g.name, style: AppText.display(22)),
                    Text(lt('{0} · {1}/30 alındı · {2}/30 okundu', [GenderType.label(g.genderType), g.takenCount, g.doneCount]),
                        style: AppText.body(12, color: AppColors.muted)),
                  ]),
                ),
                StatusPill(GroupStatus.label(g.status), color: GroupStatus.color(g.status)),
              ]),
            );
          },
        );
      },
    );
  }
}
