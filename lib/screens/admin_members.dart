import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/constants.dart';
import '../models/models.dart';
import '../services/admin_service.dart';
import '../services/hatim_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/ornaments.dart';
import 'group_detail_screen.dart';
import '../l10n/l10n.dart';

/// Yönetim > Üyeler: toplam ve yeni üyeler, arama, üye ayrıntısı, engelleme.
class AdminMembers extends StatefulWidget {
  const AdminMembers({super.key, required this.me});
  final AppUser me;
  @override
  State<AdminMembers> createState() => _AdminMembersState();
}

class _AdminMembersState extends State<AdminMembers> {
  String _q = '';
  bool _onlyNew = false, _onlyBlocked = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppUser>>(
      stream: AdminService.members(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(errorText(snap.error!))));
        if (!snap.hasData) return const LoadingView();
        final all = snap.data!;
        final weekAgo = DateTime.now().subtract(const Duration(days: 7));
        bool isNew(AppUser u) => u.createdAt != null && u.createdAt!.isAfter(weekAgo);
        final newCount = all.where(isNew).length;
        final blockedCount = all.where((u) => u.blocked).length;
        var list = all;
        if (_onlyNew) list = list.where(isNew).toList();
        if (_onlyBlocked) list = list.where((u) => u.blocked).toList();
        if (_q.isNotEmpty) list = list.where((u) => u.name.toLowerCase().contains(_q)).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            Row(children: [
              _Stat('${all.length}', lt('üye')),
              const SizedBox(width: 10),
              _Stat('$newCount', lt('son 7 günde yeni')),
              const SizedBox(width: 10),
              _Stat('$blockedCount', 'engelli'),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _Stat('${all.fold<int>(0, (a, u) => a + u.totalJuzRead)}', lt('toplam okunan cüz')),
              const SizedBox(width: 10),
              _Stat('${all.fold<int>(0, (a, u) => a + u.readsIn(HatimService.monthKey()))}', lt('bu ay okunan cüz')),
            ]),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(hintText: lt('İsimle ara'), prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              FilterChip(
                label: Text(lt('Yeni gelenler')),
                selected: _onlyNew,
                onSelected: (v) => setState(() => _onlyNew = v),
              ),
              FilterChip(
                label: Text(lt('Engelliler')),
                selected: _onlyBlocked,
                onSelected: (v) => setState(() => _onlyBlocked = v),
              ),
            ]),
            const SizedBox(height: 10),
            if (list.any((u) => u.totalJuzRead > 0 || u.monthReads.isNotEmpty)) ...[
              GoldButton(
                label: lt('Görünen {0} üyenin okuma istatistiklerini sıfırla', [list.length]),
                icon: Icons.restart_alt,
                outlined: true,
                onPressed: () => _resetMany(context, list),
              ),
              const SizedBox(height: 10),
            ],
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(lt('Bu ölçüte uyan üye yok.'), textAlign: TextAlign.center, style: AppText.body(14, color: AppColors.muted)),
              ),
            for (final u in list) ...[
              OrnateCard(
                highlight: u.blocked,
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                onTap: () => _showMember(context, u),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Flexible(child: Text(u.name.isEmpty ? lt('(adsız)') : u.name, overflow: TextOverflow.ellipsis, style: AppText.body(15, weight: FontWeight.w700))),
                        if (isNew(u)) ...[const SizedBox(width: 8), StatusPill(lt('Yeni'), color: AppColors.done)],
                        if (u.blocked) ...[const SizedBox(width: 8), StatusPill(lt('Engelli'), color: AppColors.danger)],
                      ]),
                      const SizedBox(height: 2),
                      Text(
                        lt('{0} · {1} cüz okudu{2}', [Gender.label(u.gender), u.totalJuzRead, u.createdAt != null ? ' · ${formatDate(u.createdAt!)}' : '']),
                        style: AppText.body(12, color: AppColors.muted),
                      ),
                    ]),
                  ),
                  Icon(Icons.chevron_right, color: AppColors.gold),
                ]),
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }

  Future<void> _resetMany(BuildContext context, List<AppUser> list) async {
    final ok = await confirmStatsReset(context, lt('{0} üyenin', [list.length]));
    if (ok != true || !context.mounted) return;
    await runGuarded(context, () => AdminService.resetReadingStatsMany(list.map((u) => u.id)),
        success: lt('{0} üyenin okuma istatistikleri sıfırlandı.', [list.length]));
  }

  void _showMember(BuildContext context, AppUser u) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MemberSheet(user: u, parentContext: context),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value, label;
  @override
  Widget build(BuildContext context) => Expanded(
        child: OrnateCard(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          child: Column(children: [
            Text(value, style: AppText.number(24, color: AppColors.goldLight)),
            Text(label, textAlign: TextAlign.center, style: AppText.body(11, color: AppColors.muted)),
          ]),
        ),
      );
}

class _MemberSheet extends StatefulWidget {
  const _MemberSheet({required this.user, required this.parentContext});
  final AppUser user;
  final BuildContext parentContext;
  @override
  State<_MemberSheet> createState() => _MemberSheetState();
}

class _MemberSheetState extends State<_MemberSheet> {
  String? _email;
  int? _groups;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    AdminService.emailOf(widget.user.id).then((e) {
      if (mounted) setState(() => _email = e ?? '');
    }).catchError((_) {
      if (mounted) setState(() => _email = '');
    });
    AdminService.groupCountOf(widget.user.id).then((n) {
      if (mounted) setState(() => _groups = n);
    }).catchError((_) {});
  }

  Future<void> _toggleBlock() async {
    final u = widget.user;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(u.blocked ? lt('Engeli kaldır') : lt('Üyeyi engelle'), style: AppText.display(24)),
        content: Text(
          u.blocked
              ? lt('{0} yeniden uygulamayı kullanabilecek.', [u.name])
              : lt('{0} uygulamaya girdiğinde "hesabınız engellendi" uyarısı görecek; cüz alamayacak, grup kuramayacak, arkadaşlık isteği ve tebrik gönderemeyecek. İstediğiniz zaman engeli kaldırabilirsiniz.', [u.name]),
          style: AppText.body(14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(lt('Vazgeç'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(u.blocked ? lt('Engeli kaldır') : lt('Engelle'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final done = await runGuarded(widget.parentContext, () => AdminService.setBlocked(u.id, !u.blocked),
        success: u.blocked ? lt('Engel kaldırıldı.') : lt('{0} engellendi.', [u.name]));
    if (!mounted) return;
    setState(() => _busy = false);
    if (done) Navigator.pop(context);
  }

  Future<void> _resetStats() async {
    final u = widget.user;
    final ok = await confirmStatsReset(context, lt('{0} adlı üyenin', [u.name.isEmpty ? lt('(adsız)') : u.name]));
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final done = await runGuarded(widget.parentContext, () => AdminService.resetReadingStats(u.id),
        success: lt('{0} adlı üyenin okuma istatistikleri sıfırlandı.', [u.name]));
    if (!mounted) return;
    setState(() => _busy = false);
    if (done) Navigator.pop(context);
  }

  Future<void> _editCounts() async {
    final u = widget.user;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EditCountsDialog(user: u),
    );
    if (saved == true && mounted) {
      showSnack(widget.parentContext, lt('{0} adlı üyenin cüz sayıları güncellendi.', [u.name]));
      Navigator.pop(context);
    }
  }

  Future<void> _reset() async {
    final e = _email;
    if (e == null || e.isEmpty) return;
    await runGuarded(widget.parentContext, () => AdminService.sendPasswordReset(e),
        success: lt('{0} adresine şifre yenileme bağlantısı gönderildi.', [e]));
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    Widget line(IconData i, String t, {Widget? trailing}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Icon(i, size: 18, color: AppColors.gold),
            const SizedBox(width: 12),
            Expanded(child: Text(t, style: AppText.body(14))),
            if (trailing != null) trailing,
          ]),
        );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(u.name, style: AppText.display(26)),
          const SizedBox(height: 10),
          line(Icons.mail_outline, _email == null ? lt('E-posta yükleniyor…') : (_email!.isEmpty ? lt('E-posta kaydı yok (üye yeni sürümle giriş yapınca görünür)') : _email!),
              trailing: (_email ?? '').isEmpty
                  ? null
                  : IconButton(
                      tooltip: lt('Kopyala'),
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _email!));
                        showSnack(widget.parentContext, lt('E-posta kopyalandı.'));
                      },
                    )),
          line(Icons.person_outline, Gender.label(u.gender)),
          line(Icons.event_outlined, u.createdAt == null ? lt('Kayıt tarihi bilinmiyor') : lt('Kayıt: {0}', [formatDateTime(u.createdAt!)])),
          line(Icons.menu_book_outlined, lt('Toplam {0} cüz okudu', [u.totalJuzRead])),
          line(Icons.groups_outlined, _groups == null ? lt('Gruplar yükleniyor…') : lt('{0} gruba üye', [_groups])),
          const SizedBox(height: 14),
          if ((_email ?? '').isNotEmpty) ...[
            GoldButton(label: lt('Şifre yenileme e-postası gönder'), icon: Icons.lock_reset, outlined: true, onPressed: _reset),
            const SizedBox(height: 10),
          ],
          GoldButton(label: lt('Cüz sayılarını düzenle'), icon: Icons.edit_outlined, outlined: true, busy: _busy, onPressed: _editCounts),
          const SizedBox(height: 10),
          if (u.totalJuzRead > 0 || u.monthReads.isNotEmpty) ...[
            GoldButton(label: lt('Okuma istatistiklerini sıfırla'), icon: Icons.restart_alt, outlined: true, busy: _busy, onPressed: _resetStats),
            const SizedBox(height: 10),
          ],
          GoldButton(
            label: u.blocked ? lt('Engeli kaldır') : lt('Üyeyi engelle'),
            icon: u.blocked ? Icons.lock_open : Icons.block,
            busy: _busy,
            onPressed: _toggleBlock,
          ),
          const SizedBox(height: 10),
          Text(
            lt('Şifreler hiçbir yerde açık olarak saklanmaz; yönetici dahil kimse göremez. Şifresini unutan üyeye yukarıdaki düğmeyle yenileme bağlantısı gönderebilirsiniz.'),
            style: AppText.body(12, color: AppColors.muted),
          ),
        ]),
      ),
    );
  }
}

/// Yönetim > Gruplar: bütün gruplar, açma ve silme.
class AdminGroups extends StatefulWidget {
  const AdminGroups({super.key, required this.me});
  final AppUser me;
  @override
  State<AdminGroups> createState() => _AdminGroupsState();
}

class _AdminGroupsState extends State<AdminGroups> {
  String _q = '';

  Future<void> _delete(HatimGroup g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lt('Grubu sil'), style: AppText.display(24)),
        content: Text(
          lt('"{0}" grubu ve içindeki 30 cüz kaydı kalıcı olarak silinecek. Bu işlem geri alınamaz. Üyelerin okuma sayıları (istatistikleri) silinmez.', [g.name]),
          style: AppText.body(14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(lt('Vazgeç'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(lt('Sil'), style: AppText.body(14, weight: FontWeight.w700, color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await runGuarded(context, () => AdminService.deleteGroup(g.id), success: lt('"{0}" silindi.', [g.name]));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<HatimGroup>>(
      stream: AdminService.allGroups(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(errorText(snap.error!))));
        if (!snap.hasData) return const LoadingView();
        var list = snap.data!;
        if (_q.isNotEmpty) {
          list = list.where((g) => g.name.toLowerCase().contains(_q) || g.creatorName.toLowerCase().contains(_q) || g.code.toLowerCase() == _q).toList();
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            Row(children: [
              _Stat('${snap.data!.length}', 'grup'),
              const SizedBox(width: 10),
              _Stat('${snap.data!.where((g) => g.status != GroupStatus.completed).length}', lt('devam eden')),
              const SizedBox(width: 10),
              _Stat('${snap.data!.fold<int>(0, (a, g) => a + g.hatimCount)}', lt('tamamlanan hatim')),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _Stat('${snap.data!.fold<int>(0, (a, g) => a + g.doneCount)}', lt('gruplarda şu an okunmuş cüz')),
              const SizedBox(width: 10),
              _Stat('${snap.data!.fold<int>(0, (a, g) => a + g.takenCount - g.doneCount)}', lt('okunmakta olan cüz')),
            ]),
            const SizedBox(height: 10),
            TextField(
              decoration: InputDecoration(hintText: lt('Grup adı, kuran kişi veya kod'), prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            ),
            const SizedBox(height: 12),
            for (final g in list) ...[
              OrnateCard(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: g.id, me: widget.me))),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(g.name, style: AppText.body(15, weight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        lt('Kuran: {0} · {1} · {2}\n{3}/30 alındı · {4}/30 okundu · {5}', [g.creatorName, GenderType.label(g.genderType), formatDate(g.createdAt), g.takenCount, g.doneCount, GroupStatus.label(g.status)]),
                        style: AppText.body(12, color: AppColors.muted),
                      ),
                    ]),
                  ),
                  IconButton(
                    tooltip: lt('Grubu sil'),
                    icon: Icon(Icons.delete_outline, color: AppColors.danger),
                    onPressed: () => _delete(g),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

/// İstatistik sıfırlama onayı. [who]: "Ali adlı üyenin" / "9 üyenin".
Future<bool?> confirmStatsReset(BuildContext context, String who) => showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lt('İstatistikleri sıfırla'), style: AppText.display(24)),
        content: Text(
          lt('{0} toplam ve aylık okunan cüz sayıları 0 olacak; "Ayın En Çok Okuyanları" listesinden (geçmiş aylar dahil) çıkacak. Hesap, gruplar ve gruplardaki cüz kayıtları silinmez. Bu işlem geri alınamaz.', [who]),
          style: AppText.body(14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(lt('Vazgeç'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(lt('Sıfırla'), style: AppText.body(14, weight: FontWeight.w700, color: AppColors.danger)),
          ),
        ],
      ),
    );

/// Yönetici: üyenin toplam ve aylık cüz sayısını +/- ile ayarlama.
class _EditCountsDialog extends StatefulWidget {
  const _EditCountsDialog({required this.user});
  final AppUser user;
  @override
  State<_EditCountsDialog> createState() => _EditCountsDialogState();
}

class _EditCountsDialogState extends State<_EditCountsDialog> {
  late final List<DateTime> _months = () {
    final now = DateTime.now();
    final list = <DateTime>[];
    for (var d = DateTime(now.year, now.month); !d.isBefore(DateTime(2026, 10)); d = DateTime(d.year, d.month - 1)) {
      list.add(d);
    }
    return list;
  }();
  late DateTime _sel = _months.first;
  late int _total = widget.user.totalJuzRead;
  late int _month = widget.user.readsIn(HatimService.monthKey(_sel));
  bool _busy = false;

  String get _key => HatimService.monthKey(_sel);

  void _changeMonth(int delta) {
    final next = _month + delta;
    if (next < 0) return;
    setState(() {
      _month = next;
      _total = (_total + delta) < 0 ? 0 : _total + delta; // ay değişince toplam da aynı miktarda değişir
    });
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final u = widget.user;
    final ok = await runGuarded(context, () => AdminService.setReadCounts(u.id,
        total: _total, monthKey: _key, month: _month, monthHadValue: u.lastReadIn(_key) != null));
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context, true);
  }

  Widget _stepper(String label, int value, void Function(int) onDelta) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(child: Text(label, style: AppText.body(14, weight: FontWeight.w600))),
          IconButton(onPressed: value > 0 ? () => onDelta(-1) : null, icon: const Icon(Icons.remove_circle_outline), color: AppColors.gold),
          SizedBox(width: 44, child: Text('$value', textAlign: TextAlign.center, style: AppText.display(22))),
          IconButton(onPressed: () => onDelta(1), icon: const Icon(Icons.add_circle_outline), color: AppColors.gold),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(lt('Cüz sayılarını düzenle'), style: AppText.display(24)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.user.name, style: AppText.body(14, color: AppColors.muted)),
        const SizedBox(height: 8),
        DropdownButton<DateTime>(
          value: _sel,
          isExpanded: true,
          items: [for (final m in _months) DropdownMenuItem(value: m, child: Text('${monthName(m.month)} ${m.year}'))],
          onChanged: (m) {
            if (m == null) return;
            setState(() {
              _sel = m;
              _month = widget.user.readsIn(HatimService.monthKey(m));
              _total = widget.user.totalJuzRead;
            });
          },
        ),
        _stepper(lt('Bu aydaki cüz'), _month, _changeMonth),
        _stepper(lt('Toplam cüz'), _total, (d) => setState(() => _total = (_total + d) < 0 ? 0 : _total + d)),
        const SizedBox(height: 6),
        Text(lt('Aydaki sayıyı değiştirince toplam da aynı miktarda değişir. Toplamı ayrıca düzeltebilirsiniz.'),
            style: AppText.body(12, color: AppColors.muted)),
      ]),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: Text(lt('Vazgeç'))),
        TextButton(onPressed: _busy ? null : _save, child: Text(lt('Kaydet'), style: AppText.body(14, weight: FontWeight.w700))),
      ],
    );
  }
}
