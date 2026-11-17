import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/reaction_service.dart';
import '../services/social_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/ornaments.dart';
import 'friend_profile_screen.dart';
import 'group_detail_screen.dart';
import '../l10n/l10n.dart';

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key, required this.me, this.initialTab = 0});
  final AppUser me;
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: Text(lt('Arkadaşlarım')),
          actions: [
            IconButton(tooltip: lt('Arkadaşınızı davet edin'), onPressed: SocialService.shareApp, icon: const Icon(Icons.share_outlined)),
          ],
          bottom: TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [
            Tab(text: lt('Arkadaşlar')),
            Tab(text: lt('İstekler')),
            Tab(text: lt('Davetler')),
            Tab(text: lt('Tebrikler')),
          ]),
        ),
        body: PatternBackground(
          child: TabBarView(children: [
            _FriendsTab(me: me),
            _RequestsTab(me: me),
            _InvitesTab(me: me),
            _ReactionsTab(me: me),
          ]),
        ),
      ),
    );
  }
}

class _FriendsTab extends StatelessWidget {
  const _FriendsTab({required this.me});
  final AppUser me;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Friend>>(
      stream: SocialService.friends(me.id),
      builder: (context, snap) {
        if (!snap.hasData) return const LoadingView();
        final list = snap.data!;
        if (list.isEmpty) {
          return SingleChildScrollView(
            child: EmptyState(
              title: lt('Henüz arkadaşınız yok'),
              message: lt('Hatim gruplarındaki okuyucuların yanındaki düğmeyle arkadaşlık isteği gönderebilirsiniz.'),
              action: GoldButton(label: lt('Uygulamayı paylaş'), icon: Icons.share_outlined, onPressed: SocialService.shareApp),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            OrnateCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(children: [
                for (final f in list)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.inkDeep,
                      foregroundColor: AppColors.goldLight,
                      child: Text(f.name.isNotEmpty ? f.name.characters.first.toUpperCase() : '?'),
                    ),
                    title: Text(f.name, style: AppText.body(15)),
                    subtitle: Text(lt('Cüzlerinizi ve gruplarınızı görün'), style: AppText.body(12, color: AppColors.muted)),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => FriendProfileScreen(me: me, friendUid: f.uid, friendName: f.name)),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (_) => runGuarded(context, () => SocialService.removeFriend(f.requestId),
                          success: lt('{0} arkadaş listenizden çıkarıldı.', [f.name])),
                      itemBuilder: (_) => [PopupMenuItem(value: 'remove', child: Text(lt('Arkadaşlıktan çıkar')))],
                    ),
                  ),
              ]),
            ),
          ],
        );
      },
    );
  }
}

class _RequestsTab extends StatelessWidget {
  const _RequestsTab({required this.me});
  final AppUser me;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FriendRequest>>(
      stream: SocialService.incomingRequests(me.id),
      builder: (context, snap) {
        if (!snap.hasData) return const LoadingView();
        final list = snap.data!;
        if (list.isEmpty) {
          return SingleChildScrollView(
            child: EmptyState(title: lt('Bekleyen istek yok'), message: lt('Size gelen arkadaşlık istekleri burada görünür.')),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final r = list[i];
            return OrnateCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.fromName, style: AppText.display(22)),
                Text(lt('sizinle hatim kardeşi olmak istiyor'), style: AppText.body(13, color: AppColors.muted)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: GoldButton(
                      label: lt('Kabul et'),
                      onPressed: () => runGuarded(context, () => SocialService.respond(r.id, true),
                          success: lt('{0} artık arkadaşınız.', [r.fromName])),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GoldButton(
                      label: lt('Reddet'),
                      outlined: true,
                      onPressed: () => runGuarded(context, () => SocialService.respond(r.id, false)),
                    ),
                  ),
                ]),
              ]),
            );
          },
        );
      },
    );
  }
}

class _InvitesTab extends StatelessWidget {
  const _InvitesTab({required this.me});
  final AppUser me;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GroupInvite>>(
      stream: SocialService.incomingInvites(me.id),
      builder: (context, snap) {
        if (!snap.hasData) return const LoadingView();
        final list = snap.data!;
        if (list.isEmpty) {
          return SingleChildScrollView(
            child: EmptyState(title: lt('Davetiniz yok'), message: lt('Arkadaşlarınız sizi bir hatim grubuna davet ettiğinde burada göreceksiniz.')),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final inv = list[i];
            return OrnateCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(inv.groupName, style: AppText.display(22)),
                Text(lt('{0} sizi bu hatme davet etti', [inv.fromName]), style: AppText.body(13, color: AppColors.muted)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: GoldButton(
                      label: lt('Gruba git'),
                      onPressed: () {
                        SocialService.markInviteSeen(inv.id);
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: inv.groupId, me: me)));
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GoldButton(
                      label: lt('Kapat'),
                      outlined: true,
                      onPressed: () => runGuarded(context, () => SocialService.markInviteSeen(inv.id)),
                    ),
                  ),
                ]),
              ]),
            );
          },
        );
      },
    );
  }
}

/// Gelen tebrikler; yalnızca hazır cümlelerle karşılık verilebilir.
class _ReactionsTab extends StatelessWidget {
  const _ReactionsTab({required this.me});
  final AppUser me;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Reaction>>(
      stream: ReactionService.received(me.id),
      builder: (context, snap) {
        if (!snap.hasData) return const LoadingView();
        final list = snap.data!;
        if (list.isEmpty) {
          return SingleChildScrollView(
            child: EmptyState(
              title: lt('Henüz tebrik yok'),
              message: lt('Arkadaşlarınız okuduğunuz cüzlere tebrik bıraktığında burada göreceksiniz.'),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final r = list[i];
            return OrnateCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.text, style: AppText.display(24, color: AppColors.goldLight)),
                const SizedBox(height: 4),
                Text(lt('{0} · {1}, {2}. cüz', [r.fromName, r.groupName, r.juzNumber]), style: AppText.body(12, color: AppColors.muted)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final t in [lt('Teşekkür ederim'), lt('Allah razı olsun'), lt('Amin'), lt('Rica ederim')])
                    if (allowedReactions.contains(t))
                      ActionChip(
                        backgroundColor: AppColors.inkDeep,
                        side: BorderSide(color: AppColors.gold.withValues(alpha: 0.5)),
                        label: Text(t, style: AppText.body(12, color: AppColors.goldLight)),
                        onPressed: () => runGuarded(context, () => ReactionService.reply(me: me, to: r, text: t),
                            success: lt('{0} kişisine "{1}" iletildi.', [r.fromName, t])),
                      ),
                ]),
              ]),
            );
          },
        );
      },
    );
  }
}
