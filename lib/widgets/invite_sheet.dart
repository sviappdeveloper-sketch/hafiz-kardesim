import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/social_service.dart';
import '../theme/app_theme.dart';
import 'ornaments.dart';
import '../l10n/l10n.dart';

/// Arkadaş seçme penceresi. Seçilenleri döndürür; vazgeçilirse null.
Future<Set<Friend>?> showInviteSheet(BuildContext context,
    {required AppUser me, Set<Friend> initial = const {}, HatimGroup? group}) {
  return showModalBottomSheet<Set<Friend>>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _InviteSheet(me: me, initial: initial, group: group),
  );
}

class _InviteSheet extends StatefulWidget {
  const _InviteSheet({required this.me, required this.initial, this.group});
  final AppUser me;
  final Set<Friend> initial;
  final HatimGroup? group;
  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  late final Set<String> _selected = widget.initial.map((f) => f.uid).toSet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (context, scroll) => StreamBuilder<List<Friend>>(
        stream: SocialService.friends(widget.me.id),
        builder: (context, snap) {
          final friends = (snap.data ?? const <Friend>[])
              .where((f) => widget.group == null || !widget.group!.memberIds.contains(f.uid))
              .toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(lt('Arkadaşlarınızı davet edin'), style: AppText.display(26)),
              ),
              Expanded(
                child: !snap.hasData
                    ? const LoadingView()
                    : friends.isEmpty
                        ? EmptyState(
                            title: lt('Davet edilecek arkadaş yok'),
                            message: lt('Gruplardaki kardeşlerinize arkadaşlık isteği gönderebilir ya da bağlantıyı paylaşabilirsiniz.'),
                          )
                        : ListView(
                            controller: scroll,
                            children: [
                              for (final f in friends)
                                CheckboxListTile(
                                  value: _selected.contains(f.uid),
                                  activeColor: AppColors.gold,
                                  checkColor: AppColors.inkDeep,
                                  title: Text(f.name, style: AppText.body(15)),
                                  onChanged: (v) => setState(() => v == true ? _selected.add(f.uid) : _selected.remove(f.uid)),
                                ),
                            ],
                          ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + MediaQuery.of(context).padding.bottom),
                child: Column(
                  children: [
                    GoldButton(
                      label: _selected.isEmpty ? 'Tamam' : lt('{0} kişiyi davet et', [_selected.length]),
                      onPressed: () => Navigator.pop(context, friends.where((f) => _selected.contains(f.uid)).toSet()),
                    ),
                    const SizedBox(height: 10),
                    GoldButton(
                      label: lt('Bağlantı ile paylaş'),
                      icon: Icons.share_outlined,
                      outlined: true,
                      onPressed: () => widget.group != null
                          ? SocialService.shareGroup(widget.group!)
                          : SocialService.shareApp(),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
