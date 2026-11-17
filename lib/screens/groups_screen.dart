import 'dart:math';

import 'package:flutter/material.dart';

import '../models/constants.dart';
import '../models/models.dart';
import '../services/hatim_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/ornaments.dart';
import 'create_group_screen.dart';
import 'group_detail_screen.dart';
import '../l10n/l10n.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key, required this.me});
  final AppUser me;

  Future<void> _joinByCode(BuildContext context) async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lt('Kodla katıl'), style: AppText.display(26)),
        content: TextField(
          key: const Key('join_code'),
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(hintText: lt('Örn. K7M2QX')),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(lt('Vazgeç'))),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: Text(lt('Grubu bul'))),
        ],
      ),
    );
    if (code == null || code.trim().isEmpty || !context.mounted) return;
    try {
      final id = await HatimService.findByCode(code);
      if (!context.mounted) return;
      if (id == null) { showSnack(context, lt('Bu koda ait bir grup bulunamadı.')); return; }
      Navigator.push(context, MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: id, me: me)));
    } catch (e) {
      if (context.mounted) showSnack(context, errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(lt('Hatim Grupları')),
          actions: [
            if (!me.isGuest)
              IconButton(tooltip: lt('Kodla katıl'), onPressed: () => _joinByCode(context), icon: const Icon(Icons.vpn_key_outlined)),
          ],
          bottom: TabBar(tabs: [Tab(text: lt('Gruba katıl')), Tab(text: lt('Gruplarım'))]),
        ),
        floatingActionButton: me.isGuest ? null : FloatingActionButton.extended(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.inkDeep,
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateGroupScreen(me: me))),
          icon: const Icon(Icons.add),
          label: Text(lt('Grup kur')),
        ),
        body: PatternBackground(
          child: TabBarView(children: [
            _OpenGroupList(me: me),
            _GroupList(
              stream: HatimService.myGroups(me.id),
              me: me,
              empty: EmptyState(
                title: lt('Henüz bir grubunuz yok'),
                message: lt('Cüz aldığınız ya da kurduğunuz gruplar burada görünür. "Gruba katıl" sekmesinden bir gruba katılabilirsiniz.'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _GroupList extends StatelessWidget {
  const _GroupList({required this.stream, required this.me, required this.empty});
  final Stream<List<HatimGroup>> stream;
  final AppUser me;
  final Widget empty;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<HatimGroup>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(errorText(snap.error!))));
        if (!snap.hasData) return const LoadingView();
        final list = snap.data!;
        if (list.isEmpty) return SingleChildScrollView(child: empty);
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) => GroupCard(
            group: list[i],
            me: me,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: list[i].id, me: me)),
            ),
          ),
        );
      },
    );
  }
}

/// Henüz cüz almadığın, cüz alınabilen bütün gruplar. En az cüzü kalan en üstte;
/// listenin sonuna gelince 20 grup daha yüklenir.
class _OpenGroupList extends StatefulWidget {
  const _OpenGroupList({required this.me});
  final AppUser me;

  @override
  State<_OpenGroupList> createState() => _OpenGroupListState();
}

enum _Sort { fewestLeft, newest }

class _OpenGroupListState extends State<_OpenGroupList> {
  List<HatimGroup> _all = [];
  final Map<String, int> _shuffle = {};
  bool _loading = true;
  Object? _error;
  _Sort _sort = _Sort.fewestLeft;
  String _query = '';
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _fits(HatimGroup g) =>
      !g.isMember(widget.me.id) && GenderType.allows(g.genderType, widget.me.gender) && !(widget.me.isGuest && g.locked);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await HatimService.joinableGroups();
      final rnd = Random();
      _shuffle
        ..clear()
        ..addAll({for (final g in list) g.id: rnd.nextInt(1 << 30)});
      _all = list.where(_fits).toList();
    } catch (e) {
      _error = e;
    }
    if (mounted) setState(() => _loading = false);
  }

  static String _norm(String s) => s
      .replaceAll('I', 'ı')
      .replaceAll('İ', 'i')
      .toLowerCase()
      .replaceAll('â', 'a')
      .replaceAll('î', 'i')
      .replaceAll('û', 'u')
      .trim();

  List<HatimGroup> get _visible {
    final q = _norm(_query);
    final list = _all.where((g) => q.isEmpty || _norm(g.name).contains(q)).toList();
    if (_sort == _Sort.newest) {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else {
      // Cüzü kalanlar önce, en az kalan en başta; eşitler karışık sırada.
      int left(HatimGroup g) => totalJuz - g.takenCount;
      list.sort((a, b) {
        final la = left(a), lb = left(b);
        if ((la == 0) != (lb == 0)) return la == 0 ? 1 : -1;
        if (la != lb) return la.compareTo(lb);
        return (_shuffle[a.id] ?? 0).compareTo(_shuffle[b.id] ?? 0);
      });
    }
    return list;
  }

  Widget _controls() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          controller: _search,
          onChanged: (v) => setState(() => _query = v),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: lt('Grup adıyla ara'),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: lt('Temizle'),
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _search.clear();
                      _query = '';
                    }),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [
          for (final (s, label) in [(_Sort.fewestLeft, lt('En az cüzü kalan')), (_Sort.newest, lt('En yeni gruplar'))])
            ChoiceChip(
              label: Text(label),
              selected: _sort == s,
              showCheckmark: false,
              selectedColor: AppColors.gold,
              labelStyle: AppText.body(13,
                  weight: FontWeight.w700, color: _sort == s ? AppColors.inkDeep : AppColors.muted),
              side: BorderSide(color: AppColors.gold.withValues(alpha: 0.5)),
              onSelected: (_) => setState(() => _sort = s),
            ),
        ]),
      ]);

  @override
  Widget build(BuildContext context) {
    if (_loading && _all.isEmpty) return const LoadingView();
    final items = _visible;
    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: items.length + 2,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          if (i == 0) return _controls();
          if (items.isEmpty) {
            if (_error != null) {
              return Column(children: [
                Padding(padding: const EdgeInsets.all(24), child: Text(errorText(_error!))),
                TextButton(onPressed: _load, child: Text(lt('Tekrar dene'))),
              ]);
            }
            return _query.isNotEmpty
                ? EmptyState(title: lt('Aramana uyan grup yok'), message: lt('Başka bir isimle aramayı deneyin.'))
                : EmptyState(
                    title: lt('Şu an katılabileceğiniz grup yok'),
                    message: lt('Cüz alınabilen yeni gruplar burada görünür. İlk grubu siz kurabilirsiniz.'),
                  );
          }
          if (i == items.length + 1) return const SizedBox.shrink();
          final g = items[i - 1];
          return GroupCard(
            group: g,
            me: widget.me,
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: g.id, me: widget.me)));
              if (mounted) _load();
            },
          );
        },
      ),
    );
  }
}

class GroupCard extends StatelessWidget {
  const GroupCard({super.key, required this.group, required this.me, required this.onTap});
  final HatimGroup group;
  final AppUser me;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = group;
    final progress = g.isCompleted ? 1.0 : g.doneCount / totalJuz;
    final progressText = g.isCompleted
        ? lt('{0}. hatim tamamlandı', [g.hatimCount])
        : g.takenCount < totalJuz
            ? lt('{0} cüz kaldı · {1}/30 okundu', [totalJuz - g.takenCount, g.doneCount])
            : lt('Tüm cüzler alındı · {0}/30 okundu', [g.doneCount]);
    final mine = g.juzCounts[me.id] ?? 0;
    return OrnateCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(g.name, style: AppText.display(24))),
              if (g.locked) ...[
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Icon(Icons.lock_outline, size: 18, color: AppColors.muted),
                ),
              ],
              const SizedBox(width: 8),
              StatusPill(GroupStatus.label(g.status), color: GroupStatus.color(g.status)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            lt('{0} · {1} gün · {2}/{3} üye{4}', [GenderType.label(g.genderType), g.durationDays, g.memberCount, maxMembers, g.locked ? lt(' · kilitli') : '']),
            style: AppText.body(13, color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.inkDeep,
              color: GroupStatus.color(g.status),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text(progressText, style: AppText.body(12, color: AppColors.ivory))),
              if (mine > 0)
                Text(lt('Sizde {0} cüz', [mine]), style: AppText.body(12, color: AppColors.gold))
              else if (g.isCreator(me.id) && g.joinRequests.isNotEmpty)
                Text(lt('{0} katılma isteği', [g.joinRequests.length]), style: AppText.body(12, color: AppColors.gold)),
            ],
          ),
        ],
      ),
    );
  }
}
