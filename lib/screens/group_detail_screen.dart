import 'dart:async';
import 'package:flutter/material.dart';

import '../models/constants.dart';
import '../models/models.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/hatim_service.dart';
import '../services/social_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/invite_sheet.dart';
import '../widgets/ornaments.dart';
import '../widgets/reaction_bar.dart';
import 'dua_screen.dart';
import 'juz_reader_screen.dart';
import '../l10n/l10n.dart';

class GroupDetailScreen extends StatefulWidget {
  const GroupDetailScreen({super.key, required this.groupId, required this.me});
  final String groupId;
  final AppUser me;
  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

/// Bu oturumda okunan hatim duaları (grupId → hatim sayısı); grup sayfası eski kullanıcı bilgisini taşır.
final Map<String, int> _duaReadNow = {};
bool _duaPending(AppUser me, HatimGroup g) => me.duaPending(g) && (_duaReadNow[g.id] ?? 0) < g.hatimCount;

Future<void> _openDuaFor(BuildContext context, HatimGroup g, AppUser me) async {
  final done = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => DuaScreen(groupName: g.name, groupId: g.id, hatimCount: g.hatimCount, uid: me.id),
    ),
  );
  if (done == true) _duaReadNow[g.id] = g.hatimCount;
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  bool _askedDua = false;

  /// Yeni hatim açılmış ama önceki hatmin duası okunmamışsa bir kez sor.
  void _maybeAskDua(HatimGroup g) {
    if (_askedDua || g.isCompleted || !_duaPending(widget.me, g)) return;
    _askedDua = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final read = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(lt('Önceki hatmin duası'), style: AppText.display(24)),
          content: Text(
            lt('"{0}" grubunda biten hatmin duasını henüz okumadınız. Yeni hatme geçmeden okumak ister misiniz?', [g.name]),
            style: AppText.body(14),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(lt('Daha sonra'))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(lt('Duayı oku'))),
          ],
        ),
      );
      if (read == true && mounted) {
        await _openDuaFor(context, g, widget.me);
        if (mounted) setState(() {});
      }
    });
  }

  late final Stream<HatimGroup?> _group = HatimService.group(widget.groupId);
  late final Stream<List<Juz>> _juz = HatimService.juzList(widget.groupId);

  Future<void> _adminDelete(HatimGroup g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lt('Grubu sil'), style: AppText.display(24)),
        content: Text(
          lt('"{0}" grubu ve 30 cüz kaydı kalıcı olarak silinecek. Bu işlem geri alınamaz. Üyelerin okuma sayıları (istatistikleri) silinmez.', [g.name]),
          style: AppText.body(14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(lt('Vazgeç'))),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(lt('Sil')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final nav = Navigator.of(context);
    final done = await runGuarded(context, () => AdminService.deleteGroup(g.id), success: lt('Grup silindi.'));
    if (done && mounted) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    return StreamBuilder<HatimGroup?>(
      stream: _group,
      builder: (context, gSnap) {
        final g = gSnap.data;
        if (g != null) _maybeAskDua(g);
        return Scaffold(
          appBar: AppBar(
            title: Text(g?.name ?? lt('Hatim Grubu'), overflow: TextOverflow.ellipsis),
            actions: [
              if (g != null)
                IconButton(
                  tooltip: lt('Grubu paylaş'),
                  onPressed: () => SocialService.shareGroup(g),
                  icon: const Icon(Icons.ios_share),
                ),
              if (g != null && AuthService.isAdmin)
                IconButton(
                  tooltip: lt('Grubu sil (yönetici)'),
                  onPressed: () => _adminDelete(g),
                  icon: Icon(Icons.delete_outline, color: AppColors.danger),
                ),
            ],
          ),
          body: PatternBackground(
            child: () {
              if (gSnap.hasError) return Center(child: Text(errorText(gSnap.error!)));
              if (gSnap.connectionState == ConnectionState.waiting && g == null) return const LoadingView();
              if (g == null) {
                return EmptyState(title: lt('Grup bulunamadı'), message: lt('Bu grup silinmiş ya da bağlantı hatalı olabilir.'));
              }
              return StreamBuilder<List<Juz>>(
                stream: _juz,
                builder: (context, jSnap) {
                  if (!jSnap.hasData) return const LoadingView();
                  return _DetailBody(group: g, juz: jSnap.data!, me: me);
                },
              );
            }(),
          ),
        );
      },
    );
  }
}

class _DetailBody extends StatefulWidget {
  const _DetailBody({required this.group, required this.juz, required this.me});
  final HatimGroup group;
  final List<Juz> juz;
  final AppUser me;
  @override
  State<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends State<_DetailBody> {
  bool _selecting = false;
  final Set<int> _selected = {};
  bool _busy = false;
  /// Seçim sınırı uyarısı: butonu kapatmasın diye butonun üstünde kısa süre gösterilir.
  String? _warning;
  Timer? _warnTimer;

  @override
  void dispose() {
    _warnTimer?.cancel();
    super.dispose();
  }

  void _warn(String msg) {
    _warnTimer?.cancel();
    _warning = msg;
    _warnTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _warning = null);
    });
  }

  int get _myCount => widget.group.juzCounts[widget.me.id] ?? 0;
  int get _room => maxJuzPerPerson - _myCount;

  void _toggle(Juz j) {
    if (!j.isEmpty) return;
    setState(() {
      if (_selected.contains(j.number)) {
        _selected.remove(j.number);
      } else if (_selected.length >= _room) {
        _warn(lt('{0} Bu gruptan {1} cüz daha seçebilirsiniz.', [juzLimitText, _room]));
      } else {
        _selected.add(j.number);
      }
    });
  }

  Future<void> _takeSelected() async {
    final nums = _selected.toList()..sort();
    setState(() => _busy = true);
    final ok = await runGuarded(context, () => HatimService.takeJuzMany(widget.group.id, nums, widget.me),
        success: lt('{0}. cüz{1} sizde. Allah kabul etsin.', [nums.join(', '), nums.length > 1 ? 'ler' : '']));
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) {
        _selected.clear();
        _selecting = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.group, juz = widget.juz, me = widget.me;
    final myJuz = juz.where((j) => j.isMine(me.id)).toList();
    final overdueOthers = g.isCompleted ? 0 : juz.where((j) => j.isOverdue && !j.isMine(me.id)).length;
    final canPick = !g.isCompleted && GenderType.allows(g.genderType, me.gender) && !(me.isGuest && g.locked) && _room > 0 && juz.any((j) => j.isEmpty)
        && (g.isMember(me.id) || (!g.locked && !g.membersFull));
    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, _selecting ? 120 : 40),
          children: [
            _Summary(group: g, me: me),
            const SizedBox(height: 14),
            if (!me.isGuest) ...[
              _Membership(group: g, me: me),
              const SizedBox(height: 14),
            ],
            _Actions(group: g, me: me),
            if (myJuz.isNotEmpty) ...[
              const SizedBox(height: 22),
              SectionTitle(lt('Cüzlerim'),
                  trailing: Text('${myJuz.length}/$maxJuzPerPerson', style: AppText.number(13, color: AppColors.muted))),
              const SizedBox(height: 10),
              for (final j in myJuz) ...[
                _MyJuzRow(group: g, juz: j, me: me),
                const SizedBox(height: 8),
              ],
            ],
            if (overdueOthers > 0) ...[
              const SizedBox(height: 14),
              OrnateCard(
                highlight: true,
                child: Row(children: [
                  Icon(Icons.autorenew, color: AppColors.danger),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      lt('Süresi dolduğu hâlde okunmamış {0} cüz yeniden alınabilir. Kırmızı çerçeveli bir cüze dokunup üstlenebilirsiniz.', [overdueOthers]),
                      style: AppText.body(13),
                    ),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 22),
            SectionTitle(
              lt('Cüzler'),
              trailing: canPick
                  ? TextButton.icon(
                      onPressed: () => setState(() {
                        _selecting = !_selecting;
                        _selected.clear();
                        _warning = null;
                      }),
                      icon: Icon(_selecting ? Icons.close : Icons.checklist_rounded, size: 18),
                      label: Text(_selecting ? lt('Vazgeç') : lt('Çoklu seç')),
                    )
                  : null,
            ),
            const SizedBox(height: 6),
            if (_selecting)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(lt('Almak istediğiniz boş cüzlere dokunun (en fazla {0} cüz).', [_room]),
                    style: AppText.body(13, color: AppColors.gold)),
              )
            else
              const _Legend(),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: juz.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.8,
              ),
              itemBuilder: (context, i) => _JuzCell(
                juz: juz[i],
                me: me,
                selected: _selected.contains(juz[i].number),
                dimmed: _selecting && !juz[i].isEmpty,
                onTap: () => _selecting ? _toggle(juz[i]) : _showJuzSheet(context, g, juz[i], me),
                onLongPress: canPick && juz[i].isEmpty
                    ? () => setState(() {
                          _selecting = true;
                          _toggle(juz[i]);
                        })
                    : null,
              ),
            ),
            const SizedBox(height: 26),
            SectionTitle(lt('Üyeler'),
                trailing: Text(lt('{0}/{1} kişi', [g.memberCount, maxMembers]), style: AppText.number(13, color: AppColors.muted))),
            const SizedBox(height: 10),
            _Members(group: g, me: me),
          ],
        ),
        if (_selecting)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16 + MediaQuery.of(context).padding.bottom,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _warning == null
                    ? const SizedBox.shrink()
                    : Container(
                        key: ValueKey(_warning),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.inkSoft,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.danger.withValues(alpha: 0.7)),
                        ),
                        child: Row(children: [
                          Icon(Icons.info_outline, size: 18, color: AppColors.danger),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_warning!, style: AppText.body(13))),
                        ]),
                      ),
              ),
              GoldButton(
                label: _selected.isEmpty ? lt('Cüz seç') : lt('İşaretli olanları seç'),
                icon: Icons.bookmark_add_outlined,
                busy: _busy,
                onPressed: _selected.isEmpty ? null : _takeSelected,
              ),
            ]),
          ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.group, required this.me});
  final HatimGroup group;
  final AppUser me;

  @override
  Widget build(BuildContext context) {
    final g = group;
    Widget stat(int v, String label, Color c) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$v', style: AppText.number(40, color: c)),
            Text(label, style: AppText.body(12, color: AppColors.muted)),
          ]),
        );
    return OrnateCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            StatusPill(GroupStatus.label(g.status), color: GroupStatus.color(g.status)),
            StatusPill(GenderType.label(g.genderType), color: AppColors.goldLight),
            if (g.hatimCount > 0) StatusPill(lt('{0}. hatim tamamlandı', [g.hatimCount]), color: AppColors.done),
            if (g.locked) StatusPill(lt('Kilitli'), color: AppColors.danger),
            if (g.membersFull) StatusPill(lt('Üyelik dolu'), color: AppColors.muted),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            stat(g.takenCount, lt('/ 30 cüz alındı'), AppColors.goldLight),
            stat(g.doneCount, lt('/ 30 cüz okundu'), AppColors.done),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(children: [
              LinearProgressIndicator(
                value: g.takenCount / totalJuz,
                minHeight: 8,
                backgroundColor: AppColors.inkDeep,
                color: AppColors.gold.withValues(alpha: 0.45),
              ),
              LinearProgressIndicator(
                value: g.doneCount / totalJuz,
                minHeight: 8,
                backgroundColor: Colors.transparent,
                color: AppColors.done,
              ),
            ]),
          ),
          const SizedBox(height: 14),
          if (g.description.isNotEmpty) ...[
            Text(g.description, style: AppText.display(18, style: FontStyle.italic, color: AppColors.ivory)),
            const SizedBox(height: 12),
          ],
          _InfoLine(Icons.person_outline, lt('Kuran: {0}', [g.creatorName])),
          _InfoLine(Icons.groups_outlined, lt('Üyeler: {0}/{1} kişi', [g.memberCount, maxMembers])),
          _InfoLine(Icons.schedule, g.endAt != null
              ? lt('Hatim bitiş tarihi: {0} (bütün cüzler bu tarihe kadar okunur)', [formatDate(g.endAt!)])
              : lt('Hatim süresi: {0} gün', [g.durationDays])),
          if (g.isCompleted && g.finishedAt != null) _InfoLine(Icons.check_circle_outline, lt('Tamamlandı: {0}', [formatDate(g.finishedAt!)])),
          _InfoLine(Icons.vpn_key_outlined, lt('Grup kodu: {0}', [g.code])),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.icon, this.text, {this.color});
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(children: [
          Icon(icon, size: 16, color: color ?? AppColors.gold),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppText.body(13, color: color ?? AppColors.ivory))),
        ]),
      );
}

class _Actions extends StatefulWidget {
  const _Actions({required this.group, required this.me});
  final HatimGroup group;
  final AppUser me;
  @override
  State<_Actions> createState() => _ActionsState();
}

class _ActionsState extends State<_Actions> {
  bool _busy = false;
  bool _completing = false;

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    setState(() => _busy = true);
    await runGuarded(context, action, success: success);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _openDua() async {
    await _openDuaFor(context, widget.group, widget.me);
    if (mounted) setState(() {});
  }

  Future<void> _invite() async {
    final picked = await showInviteSheet(context, me: widget.me, group: widget.group);
    if (picked == null || picked.isEmpty || !mounted) return;
    await runGuarded(context, () => SocialService.sendGroupInvites(widget.me, widget.group, picked),
        success: lt('{0} kardeşinize davet gönderildi.', [picked.length]));
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final children = <Widget>[];

    if (!g.isCompleted && _duaPending(widget.me, g)) {
      children.add(OrnateCard(
        highlight: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(lt('Önceki hatim tamamlandı'), textAlign: TextAlign.center, style: AppText.display(20, color: AppColors.goldLight)),
          const SizedBox(height: 6),
          Text(lt('Biten hatmin duasını henüz okumadınız. Yeni hatimde cüz alırken de okuyabilirsiniz.'),
              textAlign: TextAlign.center, style: AppText.body(13, color: AppColors.muted)),
          const SizedBox(height: 12),
          GoldButton(label: lt('Hatim bitti, duanızı okuyun'), icon: Icons.auto_awesome, onPressed: _openDua),
        ]),
      ));
    }
    if (!g.isCompleted) {
      if (g.allRead) {
        // Eski sürümden kalan, tamamı okunmuş ama tamamlanmamış hatim: hemen tamamla.
        if (!_completing) {
          _completing = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => HatimService.completeIfAllRead(g.id).catchError((_) => false));
        }
        children.add(Text(lt('Bütün cüzler okundu, hatim tamamlanıyor…'), style: AppText.body(13, color: AppColors.muted)));
      } else {
        children.add(Text(
            lt('Cüzünüzü alır almaz okumaya başlayabilirsiniz. 30 cüzün tamamı okununca hatim kendiliğinden tamamlanır ve hatim duası herkese açılır ({0}/30).', [g.doneCount]),
            style: AppText.body(13, color: AppColors.muted)));
      }
      if (!widget.me.isGuest) {
        children.add(GoldButton(label: lt('Arkadaşlarınızı davet edin'), icon: Icons.group_add_outlined, outlined: true, onPressed: _invite));
      }
    } else {
      final read = widget.me.hasReadDua(g) || (_duaReadNow[g.id] ?? 0) >= g.hatimCount;
      children.add(OrnateCard(
        highlight: !read,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(lt('Hatim bitti, Allah kabul etsin'), textAlign: TextAlign.center, style: AppText.display(22, color: AppColors.goldLight)),
          const SizedBox(height: 6),
          Text(
            read ? lt('Duanızı okudunuz. Dilerseniz tekrar okuyabilir ya da dinleyebilirsiniz.') : lt('Bu hatme katılan herkes hatim duasını okuyabilir ya da dinleyebilir.'),
            textAlign: TextAlign.center,
            style: AppText.body(13, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          GoldButton(
            label: read ? lt('Duayı tekrar oku') : lt('Hatim bitti, duanızı okuyun'),
            icon: Icons.auto_awesome,
            outlined: read,
            onPressed: _openDua,
          ),
        ]),
      ));
      if (g.isCreator(widget.me.id)) {
        children.add(GoldButton(
          label: lt('Aynı grupla yeni hatim aç'),
          icon: Icons.refresh,
          outlined: true,
          busy: _busy,
          onPressed: () => _run(() => HatimService.restartHatim(g.id, widget.me), success: lt('Yeni hatim açıldı. Cüzler yeniden alınabilir.')),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          children[i],
        ],
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();
  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                  color: c, borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.inkLine))),
          const SizedBox(width: 6),
          Text(t, style: AppText.body(12, color: AppColors.muted)),
        ]);
    return Wrap(spacing: 14, runSpacing: 6, children: [
      dot(AppColors.inkDeep, lt('Boş')),
      dot(AppColors.gold, lt('Alındı')),
      dot(AppColors.reading, lt('Okunuyor')),
      dot(AppColors.done, lt('Okundu')),
      dot(AppColors.danger, lt('Süresi doldu')),
    ]);
  }
}

class _JuzCell extends StatelessWidget {
  const _JuzCell({required this.juz, required this.me, required this.onTap, this.onLongPress, this.selected = false, this.dimmed = false});
  final Juz juz;
  final AppUser me;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool selected, dimmed;

  @override
  Widget build(BuildContext context) {
    final j = juz;
    final c = j.isEmpty ? AppColors.inkLine : JuzStatus.color(j.status);
    final mine = j.isMine(me.id);
    // Durumlar dolu renkle ayrışır: alındı = altın, okunuyor = mavi, okundu = yeşil, boş = koyu.
    final filled = !j.isEmpty && !selected;
    final bg = selected
        ? AppColors.gold.withValues(alpha: 0.35)
        : j.isEmpty
            ? AppColors.inkDeep.withValues(alpha: 0.55)
            : (j.isOverdue ? AppColors.danger.withValues(alpha: 0.85) : c.withValues(alpha: 0.92));
    final fg = !filled
        ? (j.isEmpty && !selected ? AppColors.muted : AppColors.ivory)
        : (j.status == JuzStatus.taken && !j.isOverdue ? const Color(0xFF1B1405) : Colors.white);
    final icon = selected
        ? Icons.check_circle
        : j.isOverdue
            ? Icons.schedule
            : j.isDone
                ? Icons.check_circle
                : j.status == JuzStatus.reading
                    ? Icons.menu_book_rounded
                    : j.status == JuzStatus.taken
                        ? Icons.bookmark
                        : null;
    final borderColor = selected
        ? AppColors.gold
        : j.isOverdue
            ? AppColors.danger
            : (mine ? AppColors.ivory : (j.isEmpty ? AppColors.inkLine : c));
    return Opacity(
      opacity: dimmed ? 0.35 : 1,
      child: Semantics(
        button: true,
        selected: selected,
        label: lt('{0}. cüz, {1}{2}', [j.number, JuzStatus.label(j.status), j.userName != null ? ', ${j.userName}' : '']),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            onLongPress: onLongPress,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: bg,
                border: Border.all(color: borderColor, width: selected || mine || j.isOverdue ? 2.2 : 1),
                boxShadow: filled ? [BoxShadow(color: c.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 2))] : null,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null)
                      Icon(icon, size: 14, color: selected ? AppColors.goldLight : fg)
                    else
                      const SizedBox(height: 14),
                    Text('${j.number}', style: AppText.number(22, color: fg, weight: FontWeight.w700)),
                    Text(
                      selected ? lt('seçildi') : (j.isEmpty ? lt('boş') : (mine ? lt('siz') : (j.userName ?? '').split(' ').first)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(10,
                          color: filled ? fg.withValues(alpha: 0.9) : (selected ? AppColors.goldLight : AppColors.muted),
                          weight: mine ? FontWeight.w800 : FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MyJuzRow extends StatelessWidget {
  const _MyJuzRow({required this.group, required this.juz, required this.me});
  final HatimGroup group;
  final Juz juz;
  final AppUser me;

  @override
  Widget build(BuildContext context) {
    final j = juz;
    return OrnateCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      highlight: j.isOverdue,
      onTap: () => _showJuzSheet(context, group, j, me),
      child: Row(
        children: [
          SizedBox(width: 44, child: Text('${j.number}', style: AppText.number(26, color: AppColors.goldLight))),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(lt('{0}. Cüz · {1}', [j.number, juzPages(j.number)]), style: AppText.body(14, weight: FontWeight.w600)),
              Text(
                j.endAt != null && !j.isDone ? remainingText(j.endAt!) : JuzStatus.label(j.status),
                style: AppText.body(12, color: j.isOverdue ? AppColors.danger : AppColors.muted),
              ),
            ]),
          ),
          StatusPill(JuzStatus.label(j.status), color: JuzStatus.color(j.status)),
          IconButton(
            tooltip: lt('Cüzü oku'),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => JuzReaderScreen(group: group, juz: j, me: me))),
            icon: Icon(Icons.menu_book_rounded, color: AppColors.gold),
          ),
        ],
      ),
    );
  }
}

class _Members extends StatelessWidget {
  const _Members({required this.group, required this.me});
  final HatimGroup group;
  final AppUser me;

  @override
  Widget build(BuildContext context) {
    final entries = group.memberNames.entries
        .where((e) => group.memberIds.contains(e.key))
        .toList()
      ..sort((a, b) => (group.juzCounts[b.key] ?? 0).compareTo(group.juzCounts[a.key] ?? 0));
    return OrnateCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          for (final e in entries)
            ListTile(
              dense: true,
              leading: CircleAvatar(
                backgroundColor: AppColors.inkDeep,
                foregroundColor: AppColors.goldLight,
                child: Text(e.value.isNotEmpty ? e.value.characters.first.toUpperCase() : '?'),
              ),
              title: Text(e.key == me.id ? lt('{0} (siz)', [e.value]) : e.value, style: AppText.body(14)),
              subtitle: Text(
                lt('{0} cüz{1}', [group.juzCounts[e.key] ?? 0, e.key == group.creatorId ? lt(' · grubu kuran') : '']),
                style: AppText.body(12, color: AppColors.muted),
              ),
              trailing: e.key == me.id ? null : _FriendButton(me: me, otherId: e.key, otherName: e.value),
            ),
        ],
      ),
    );
  }
}

class _FriendButton extends StatelessWidget {
  const _FriendButton({required this.me, required this.otherId, required this.otherName});
  final AppUser me;
  final String otherId, otherName;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Relation>(
      stream: SocialService.relation(me.id, otherId),
      builder: (context, snap) {
        switch (snap.data) {
          case Relation.friends:
            return Tooltip(message: lt('Arkadaşınız'), child: Icon(Icons.people, color: AppColors.done, size: 20));
          case Relation.sent:
            return Row(mainAxisSize: MainAxisSize.min, children: [
              Text(lt('İstek gitti'), style: AppText.body(12, color: AppColors.muted)),
              IconButton(
                tooltip: lt('İsteği iptal et'),
                icon: Icon(Icons.close, color: AppColors.muted, size: 18),
                onPressed: () => runGuarded(
                  context,
                  () => SocialService.cancelFriendRequest(me.id, otherId),
                  success: lt('{0} kişisine gönderilen istek iptal edildi.', [otherName]),
                ),
              ),
            ]);
          case Relation.received:
            return Text(lt('Size istek gönderdi'), style: AppText.body(12, color: AppColors.gold));
          default:
            return StreamBuilder<AppUser?>(
              stream: AuthService.userStream(otherId),
              builder: (context, userSnap) {
                if (userSnap.data?.friendRequestsOpen == false) {
                  return Tooltip(
                    message: lt('Bu kişi arkadaşlık isteklerini kapatmış.'),
                    child: Icon(Icons.person_off_outlined, color: AppColors.muted, size: 20),
                  );
                }
                return IconButton(
                  tooltip: lt('Arkadaşlık isteği gönder'),
                  icon: Icon(Icons.person_add_alt_1_outlined, color: AppColors.gold),
                  onPressed: () => runGuarded(
                    context,
                    () => SocialService.sendFriendRequest(me, otherId, otherName),
                    success: lt('{0} kişisine arkadaşlık isteği gönderildi.', [otherName]),
                  ),
                );
              },
            );
        }
      },
    );
  }
}

// ---------- Cüz işlemleri penceresi ----------

void _showJuzSheet(BuildContext context, HatimGroup g, Juz j, AppUser me) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetCtx) => _JuzSheet(group: g, juz: j, me: me, parentContext: context),
  );
}

class _JuzSheet extends StatefulWidget {
  const _JuzSheet({required this.group, required this.juz, required this.me, required this.parentContext});
  final HatimGroup group;
  final Juz juz;
  final AppUser me;
  final BuildContext parentContext;
  @override
  State<_JuzSheet> createState() => _JuzSheetState();
}

class _JuzSheetState extends State<_JuzSheet> {
  bool _busy = false;

  Future<void> _do(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) Navigator.pop(context);
      if (widget.parentContext.mounted) showSnack(widget.parentContext, success);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(widget.parentContext, errorText(e));
      }
    }
  }

  void _openReader(HatimGroup g, Juz j, AppUser me) {
    Navigator.pop(context);
    Navigator.push(widget.parentContext,
        MaterialPageRoute(builder: (_) => JuzReaderScreen(group: g, juz: j, me: me)));
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.group, j = widget.juz, me = widget.me;
    final mine = j.isMine(me.id);
    final buttons = <Widget>[];
    String? note;

    if (g.isCompleted) {
      note = lt('Bu hatim tamamlandı. Allah kabul etsin.');
    } else if (j.isEmpty) {
      final count = g.juzCounts[me.id] ?? 0;
      if (!GenderType.allows(g.genderType, me.gender)) {
        note = lt('Bu grup "{0}" için açılmış.', [GenderType.label(g.genderType)]);
      } else if (count >= maxJuzPerPerson) {
        note = lt('{0} Bu gruptan aldığınız cüzler sınıra ulaştı.', [juzLimitText]);
      } else {
        note = g.endAt != null && g.endAt!.isAfter(DateTime.now())
            ? lt('Cüzü alınca hemen okumaya başlayabilirsiniz. Hatmin bitiş tarihine ({0}) kadar okumanız gerekir. Birden fazla cüz almak için "Çoklu seç"i kullanın.', [formatDate(g.endAt!)])
            : lt('Cüzü alınca hemen okumaya başlayabilirsiniz. Hatmin süresi geçtiği için size {0} gün tanınır.', [volunteerDays]);
        buttons.add(GoldButton(
          label: lt('Bu cüzü al'),
          icon: Icons.bookmark_add_outlined,
          busy: _busy,
          onPressed: () => _do(() => HatimService.takeJuz(g.id, j.number, me), lt('{0}. cüz sizde. Allah kabul etsin.', [j.number])),
        ));
      }
    } else if (mine && !j.isDone) {
      buttons.add(GoldButton(
        label: lt('Cüzü oku'),
        icon: Icons.menu_book_outlined,
        busy: _busy,
        onPressed: () => _openReader(g, j, me),
      ));
      buttons.add(GoldButton(
        label: lt('Okudum'),
        icon: Icons.check_rounded,
        outlined: true,
        busy: _busy,
        onPressed: () => _do(() => HatimService.setJuzStatus(g.id, j.number, me, JuzStatus.done), lt('Allah kabul etsin.')),
      ));
      if (j.status == JuzStatus.taken) {
        buttons.add(TextButton(
          onPressed: _busy ? null : () => _do(() => HatimService.releaseJuz(g.id, j.number, me), lt('{0}. cüz bırakıldı.', [j.number])),
          child: Text(lt('Cüzü bırak')),
        ));
      }
    } else if (!mine && j.isOverdue) {
      note = g.endAt != null && g.endAt!.isAfter(DateTime.now())
          ? lt('Süresi dolduğu hâlde bu cüz okunmadı. Yeniden alırsanız hatmin bitiş tarihine ({0}) kadar okumanız gerekir.', [formatDate(g.endAt!)])
          : lt('Süresi dolduğu hâlde bu cüz okunmadı. Yeniden alırsanız size {0} gün tanınır.', [volunteerDays]);
      buttons.add(GoldButton(
        label: lt('Bu cüzü yeniden al'),
        icon: Icons.autorenew,
        busy: _busy,
        onPressed: () => _do(() => HatimService.volunteer(g.id, j.number, me), lt('{0}. cüzü üstlendiniz. Allah razı olsun.', [j.number])),
      ));
    } else if (j.isDone) {
      note = lt('{0}. Allah kabul etsin.', [mine ? lt('Bu cüzü okudunuz') : lt('{0} bu cüzü okudu', [j.userName])]);
      if (mine) {
        buttons.add(GoldButton(
          label: lt('Cüzü tekrar oku'),
          icon: Icons.menu_book_outlined,
          outlined: true,
          onPressed: () => _openReader(g, j, me),
        ));
      }
    } else {
      note = lt('{0} okuyor. Süresi dolar da okunmazsa yeniden alınabilir.', [j.userName]);
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(lt('{0}. Cüz', [j.number]), style: AppText.number(28))),
                StatusPill(j.isOverdue ? lt('Süresi doldu') : JuzStatus.label(j.status),
                    color: j.isOverdue ? AppColors.danger : JuzStatus.color(j.status)),
              ],
            ),
            Text(juzPages(j.number), style: AppText.body(13, color: AppColors.gold)),
            const SizedBox(height: 10),
            if (!j.isEmpty) Text(lt('Okuyan: {0}{1}', [mine ? lt('Siz') : j.userName, j.volunteer ? lt(' (gönüllü)') : '']), style: AppText.body(14)),
            if (j.endAt != null && !j.isDone)
              Text(lt('Son gün: {0}', [formatDateTime(j.endAt!)]), style: AppText.body(13, color: AppColors.muted)),
            if (note != null) ...[
              const SizedBox(height: 12),
              Text(note, style: AppText.body(14, color: AppColors.muted)),
            ],
            for (final b in buttons) ...[const SizedBox(height: 12), b],
            if (j.isDone && j.uid != null) ...[
              const SizedBox(height: 16),
              ReactionBar(me: me, juz: j, toUid: j.uid!, canSend: !mine && !me.isGuest),
            ],
          ],
        ),
      ),
    );
  }
}


/// Katılma / ayrılma / kilit ve katılma istekleri.
class _Membership extends StatefulWidget {
  const _Membership({required this.group, required this.me});
  final HatimGroup group;
  final AppUser me;
  @override
  State<_Membership> createState() => _MembershipState();
}

class _MembershipState extends State<_Membership> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    setState(() => _busy = true);
    await runGuarded(context, action, success: success);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _leave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lt('Gruptan ayrıl'), style: AppText.display(24)),
        content: Text(
          lt('Gruptan ayrılmak istediğinize emin misiniz? Okuduğunuz cüzler kayıtlı kalır.{0}', [widget.group.locked ? lt(' Grup kilitli olduğundan yeniden katılmak için onay gerekir.') : '']),
          style: AppText.body(14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(lt('Vazgeç'))),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(lt('Ayrıl')),
          ),
        ],
      ),
    );
    if (ok == true) await _run(() => HatimService.leaveGroup(widget.group.id, widget.me), success: lt('Gruptan ayrıldınız.'));
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.group, me = widget.me;
    final creator = g.isCreator(me.id);
    final member = g.isMember(me.id);
    final genderOk = GenderType.allows(g.genderType, me.gender);

    if (creator) {
      final reqs = g.joinRequests.entries.toList();
      return OrnateCard(
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SwitchListTile(
            value: g.locked,
            onChanged: _busy ? null : (v) => _run(() => HatimService.setLocked(g.id, v, me),
                success: v ? lt('Grup kilitlendi. Yeni üyeler ancak sizin onayınızla katılabilir.') : lt('Grubun kilidi açıldı.')),
            secondary: Icon(g.locked ? Icons.lock_outline : Icons.lock_open_outlined, color: AppColors.gold),
            activeThumbColor: AppColors.inkDeep,
            activeTrackColor: AppColors.gold,
            title: Text(lt('Grubu kilitle'), style: AppText.body(15, weight: FontWeight.w600)),
            subtitle: Text(
              g.locked
                  ? lt('Kilitli: katılmak isteyenler istek gönderir, siz onaylarsınız.')
                  : lt('Açık: herkes katılabilir (en fazla {0} kişi).', [maxMembers]),
              style: AppText.body(12.5, color: AppColors.muted),
            ),
          ),
          if (reqs.isNotEmpty) ...[
            Divider(height: 1, color: AppColors.inkLine),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Text(lt('KATILMA İSTEKLERİ ({0})', [reqs.length]), style: AppText.label()),
            ),
            for (final r in reqs)
              ListTile(
                dense: true,
                leading: CircleAvatar(
                  backgroundColor: AppColors.inkDeep,
                  foregroundColor: AppColors.goldLight,
                  child: Text(r.value.isNotEmpty ? r.value.characters.first.toUpperCase() : '?'),
                ),
                title: Text(r.value, style: AppText.body(14, weight: FontWeight.w600)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    tooltip: lt('Reddet'),
                    onPressed: _busy ? null : () => _run(() => HatimService.answerRequest(g.id, r.key, false, me)),
                    icon: Icon(Icons.close, color: AppColors.danger),
                  ),
                  IconButton(
                    tooltip: lt('Kabul et'),
                    onPressed: _busy
                        ? null
                        : () => _run(() => HatimService.answerRequest(g.id, r.key, true, me),
                            success: lt('{0} gruba katıldı.', [r.value])),
                    icon: Icon(Icons.check, color: AppColors.done),
                  ),
                ]),
              ),
          ],
        ]),
      );
    }

    if (member) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _busy ? null : _leave,
          icon: Icon(Icons.logout, size: 18, color: AppColors.muted),
          label: Text(lt('Gruptan ayrıl'), style: AppText.body(13, color: AppColors.muted, weight: FontWeight.w600)),
        ),
      );
    }

    // Üye değil.
    String? note;
    Widget? button;
    if (!genderOk) {
      note = lt('Bu grup {0} için kurulmuş.', [GenderType.label(g.genderType).toLowerCase()]);
    } else if (g.isCompleted) {
      note = lt('Bu hatim tamamlandı.');
    } else if (g.hasRequested(me.id)) {
      note = lt('Katılma isteğiniz gönderildi. Grubu kuran onaylayınca üye olursunuz.');
      button = GoldButton(
        label: lt('İsteği geri çek'),
        outlined: true,
        busy: _busy,
        onPressed: () => _run(() => HatimService.cancelRequest(g.id, me)),
      );
    } else if (g.membersFull) {
      note = lt('Bu grup dolu. Bir gruba en fazla {0} kişi katılabilir.', [maxMembers]);
    } else if (g.locked) {
      note = lt('Bu grup kilitli. Katılmak için istek gönderebilirsiniz; grubu kuran onaylarsa üye olursunuz.');
      button = GoldButton(
        label: lt('Katılma isteği gönder'),
        icon: Icons.send_outlined,
        busy: _busy,
        onPressed: () => _run(() => HatimService.requestJoin(g.id, me), success: lt('İsteğiniz gönderildi.')),
      );
    } else {
      note = lt('Gruba katılarak cüz alabilir, hatmi birlikte takip edebilirsiniz. ({0}/{1} kişi)', [g.memberCount, maxMembers]);
      button = GoldButton(
        label: lt('Gruba katıl'),
        icon: Icons.group_add_outlined,
        busy: _busy,
        onPressed: () => _run(() => HatimService.joinGroup(g.id, me), success: lt('Gruba katıldınız. Hayırlı olsun.')),
      );
    }
    return OrnateCard(
      highlight: button != null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(g.locked ? Icons.lock_outline : Icons.group_outlined, color: AppColors.gold),
          const SizedBox(width: 10),
          Expanded(child: Text(note, style: AppText.body(13.5))),
        ]),
        if (button != null) ...[const SizedBox(height: 12), button],
      ]),
    );
  }
}
