import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/support_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/ornaments.dart';
import 'admin_members.dart';
import 'support_screen.dart';
import '../l10n/l10n.dart';

/// Yalnızca yönetici hesabında görünür: üyeler, gruplar, mesajlar, reklam talepleri, katkı sunanlar, ayarlar.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key, required this.me});
  final AppUser me;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: Text(lt('Yönetim')),
          bottom: TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [
            const Tab(child: _SuistimalSekmeBasligi()),
            Tab(text: lt('Üyeler')),
            Tab(text: lt('Gruplar')),
            Tab(text: lt('Mesajlar')),
            Tab(text: lt('İşbirliği talepleri')),
            Tab(text: lt('Katkı sunanlar')),
            Tab(text: lt('Ayarlar')),
          ]),
        ),
        body: PatternBackground(
          child: Column(children: [
            const _VerifyBanner(),
            Expanded(
              child: TabBarView(children: [
                const _Suistimaller(),
                AdminMembers(me: me),
                AdminGroups(me: me),
                const _Threads(),
                const _AdRequests(),
                const _SponsorsAdmin(),
                const _Settings(),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Yönetici yetkileri, e-postası doğrulanmış hesapta çalışır.
class _VerifyBanner extends StatefulWidget {
  const _VerifyBanner();
  @override
  State<_VerifyBanner> createState() => _VerifyBannerState();
}

class _VerifyBannerState extends State<_VerifyBanner> {
  bool _verified = AuthService.emailVerified;

  @override
  Widget build(BuildContext context) {
    if (_verified) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: OrnateCard(
        highlight: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(lt('Yönetici işlemleri için e-posta adresinizi doğrulamanız gerekiyor.'), style: AppText.body(14)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: GoldButton(
                label: lt('Doğrulama e-postası gönder'),
                outlined: true,
                onPressed: () => runGuarded(context, AuthService.sendVerification,
                    success: lt('Doğrulama bağlantısı e-postanıza gönderildi.')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GoldButton(
                label: lt('Doğruladım'),
                onPressed: () async {
                  final ok = await AuthService.refreshVerification();
                  if (!context.mounted) return;
                  setState(() => _verified = ok);
                  showSnack(context, ok ? lt('E-posta doğrulandı.') : lt('Henüz doğrulanmamış görünüyor.'));
                },
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _Threads extends StatelessWidget {
  const _Threads();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SupportThread>>(
      stream: SupportService.allThreads(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(errorText(snap.error!))));
        if (!snap.hasData) return const LoadingView();
        final list = snap.data!;
        if (list.isEmpty) {
          return SingleChildScrollView(child: EmptyState(title: lt('Mesaj yok'), message: lt('Üyelerin destek, şikâyet ve önerileri burada görünür.')));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final t = list[i];
            final last = t.messages.isNotEmpty ? t.messages.last : null;
            return OrnateCard(
              highlight: t.unreadForAdmin,
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SupportThreadScreen(threadId: t.id, asAdmin: true)),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      StatusPill(SupportService.categories[t.category] ?? t.category,
                          color: t.category == 'sikayet' ? AppColors.danger : AppColors.gold),
                      const SizedBox(width: 8),
                      Expanded(child: Text(t.name, overflow: TextOverflow.ellipsis, style: AppText.body(14, weight: FontWeight.w600))),
                    ]),
                    const SizedBox(height: 6),
                    Text(last?.text ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.body(13)),
                    Text(
                      '${formatDateTime(t.updatedAt)}${t.unreadForAdmin ? ' · cevap bekliyor' : ''}',
                      style: AppText.body(11, color: t.unreadForAdmin ? AppColors.gold : AppColors.muted),
                    ),
                  ]),
                ),
                Icon(Icons.chevron_right, color: AppColors.muted),
              ]),
            );
          },
        );
      },
    );
  }
}

class _AdRequests extends StatelessWidget {
  const _AdRequests();

  static Map<String, String> get _statusLabels => {'yeni': lt('Yeni'), 'gorusuldu': lt('Görüşüldü'), 'yayinda': lt('Yayında'), 'reddedildi': lt('Reddedildi')};

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdRequest>>(
      stream: SupportService.allAdRequests(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(errorText(snap.error!))));
        if (!snap.hasData) return const LoadingView();
        final list = snap.data!;
        if (list.isEmpty) {
          return SingleChildScrollView(child: EmptyState(title: lt('Talep yok'), message: lt('"İşbirliği kur / katkı sun" formundan gelen talepler burada görünür.')));
        }
        // İnce liste: tarih, isim, durum. Dokununca ayrıntı açılır.
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          itemCount: list.length,
          separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.inkLine),
          itemBuilder: (context, i) {
            final r = list[i];
            final color = r.status == 'yayinda' ? AppColors.done : (r.status == 'reddedildi' ? AppColors.danger : AppColors.gold);
            return ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: Text(
                  '${r.createdAt.day.toString().padLeft(2, '0')}.${r.createdAt.month.toString().padLeft(2, '0')}.${r.createdAt.year}',
                  style: AppText.number(12, color: AppColors.muted)),
              title: Text(r.company,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: AppText.body(15, weight: r.status == 'yeni' ? FontWeight.w800 : FontWeight.w600)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                StatusPill(_statusLabels[r.status] ?? r.status, color: color),
                if (r.status == 'reddedildi')
                  IconButton(
                    tooltip: lt('Sil'),
                    icon: Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                    onPressed: () => _confirmDelete(context, r),
                  ),
              ]),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _AdRequestDetail(id: r.id))),
            );
          },
        );
      },
    );
  }
}


/// Reddedilen talebi siler (geri alınamaz).
Future<void> _confirmDelete(BuildContext context, AdRequest r) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(lt('Talep silinsin mi?'), style: AppText.display(22)),
      content: Text(lt('{0} talebi kalıcı olarak silinecek.', [r.company]), style: AppText.body(14)),
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
  if (ok != true || !context.mounted) return;
  await runGuarded(context, () => SupportService.deleteAdRequest(r.id), success: lt('Talep silindi.'));
}

/// Reklam talebinin ayrıntısı: görsel, açıklama, telefon ve işlemler.
class _AdRequestDetail extends StatelessWidget {
  const _AdRequestDetail({required this.id});
  final String id;

  static Map<String, String> get _statusLabels => _AdRequests._statusLabels;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(lt('İşbirliği talebi'))),
      body: PatternBackground(
        child: StreamBuilder<List<AdRequest>>(
          stream: SupportService.allAdRequests(),
          builder: (context, snap) {
            if (!snap.hasData) return const LoadingView();
            final found = snap.data!.where((x) => x.id == id);
            if (found.isEmpty) {
              return Center(child: Text(lt('Talep silindi.'), style: AppText.body(14, color: AppColors.muted)));
            }
            final r = found.first;
            return ListView(padding: const EdgeInsets.all(16), children: [
              OrnateCard(
              highlight: r.status == 'yeni',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: Text(r.company, style: AppText.display(22))),
                  StatusPill(_statusLabels[r.status] ?? r.status,
                      color: r.status == 'yayinda' ? AppColors.done : (r.status == 'reddedildi' ? AppColors.danger : AppColors.gold)),
                ]),
                Text(formatDateTime(r.createdAt), style: AppText.body(11, color: AppColors.muted)),
                Text(r.durationDays > 0 ? lt('Süre: {0} gün', [r.durationDays]) : lt('Süre: özel (görüşülecek)'),
                    style: AppText.body(13, color: AppColors.goldLight, weight: FontWeight.w700)),
                const SizedBox(height: 8),
                SelectableText(r.detail, style: AppText.body(14)),
                if (r.image != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(r.image!, fit: BoxFit.contain, gaplessPlayback: true),
                  ),
                ] else if (r.imageUrl.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(r.imageUrl, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(child: Text(lt('Görsel açılamadı'), style: AppText.body(12, color: AppColors.muted)))),
                    ),
                  ),
                ],
                if (r.link.isNotEmpty) Text(lt('Bağlantı: {0}', [r.link]), style: AppText.body(12, color: AppColors.muted)),
                const SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.phone_outlined, color: AppColors.gold, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: SelectableText(r.phone, style: AppText.number(16))),
                  IconButton(
                    tooltip: lt('Kopyala'),
                    icon: Icon(Icons.copy, color: AppColors.gold, size: 20),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: r.phone));
                      if (context.mounted) showSnack(context, lt('Telefon numarası kopyalandı.'));
                    },
                  ),
                  IconButton(
                    tooltip: lt('Ara'),
                    icon: Icon(Icons.call_outlined, color: AppColors.gold, size: 20),
                    onPressed: () => launchUrl(Uri(scheme: 'tel', path: r.phone)),
                  ),
                ]),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if (r.status != 'yayinda')
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.inkDeep),
                      onPressed: () async {
                        int? days;
                        if (r.durationDays == 0) {
                          final c = TextEditingController();
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(lt('Özel süre'), style: AppText.display(22)),
                              content: TextField(
                                controller: c,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                    labelText: lt('Yayın süresi (gün)'), helperText: lt('Boş bırakılırsa süresiz yayınlanır.')),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(lt('Vazgeç'))),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(lt('Yayınla'))),
                              ],
                            ),
                          );
                          if (ok != true) return;
                          days = int.tryParse(c.text.trim());
                        }
                        if (!context.mounted) return;
                        await runGuarded(context, () => SupportService.publishFromRequest(r, days: days),
                            success: lt('{0} katkı sunanlar listesinde yayınlandı.', [r.company]));
                      },
                      icon: const Icon(Icons.publish, size: 18),
                      label: Text(lt('Onayla ve yayınla')),
                    ),
                  OutlinedButton(
                    onPressed: () => runGuarded(context, () => SupportService.setAdStatus(r.id, 'gorusuldu')),
                    child: Text(lt('Görüşüldü')),
                  ),
                  OutlinedButton(
                    onPressed: () => runGuarded(context, () => SupportService.setAdStatus(r.id, 'reddedildi')),
                    child: Text(lt('Reddet')),
                  ),
                ]),
              ]),
              ),
              if (r.status == 'reddedildi') ...[
                const SizedBox(height: 14),
                GoldButton(
                  label: lt('Talebi sil'),
                  icon: Icons.delete_outline,
                  outlined: true,
                  onPressed: () async {
                    await _confirmDelete(context, r);
                    if (context.mounted && Navigator.canPop(context)) Navigator.pop(context);
                  },
                ),
              ],
            ]);
          },
        ),
      ),
    );
  }
}

class _SponsorsAdmin extends StatelessWidget {
  const _SponsorsAdmin();

  Future<void> _edit(BuildContext context, [Sponsor? sp]) async {
    final name = TextEditingController(text: sp?.name);
    final image = TextEditingController(text: sp?.imageUrl);
    final link = TextEditingController(text: sp?.link);
    final note = TextEditingController(text: sp?.note);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(sp == null ? lt('Katkı sunan ekle') : lt('Katkı sunanı düzenle'), style: AppText.display(24)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(key: const Key('sp_name'), controller: name, decoration: InputDecoration(labelText: lt('Ad'))),
            const SizedBox(height: 10),
            TextField(key: const Key('sp_image'), controller: image, decoration: InputDecoration(labelText: lt('Logo / görsel bağlantısı'))),
            const SizedBox(height: 10),
            TextField(key: const Key('sp_link'), controller: link, decoration: InputDecoration(labelText: lt('Dokununca açılacak adres'))),
            const SizedBox(height: 10),
            TextField(key: const Key('sp_note'), controller: note, decoration: InputDecoration(labelText: lt('Kısa not'))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(lt('Vazgeç'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(lt('Kaydet'))),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await runGuarded(
      context,
      () => SupportService.saveSponsor(Sponsor(
        id: sp?.id ?? '',
        name: name.text,
        imageUrl: image.text,
        link: link.text,
        note: note.text,
        active: sp?.active ?? true,
        order: sp?.order ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
        detail: sp?.detail ?? '',
      )),
      success: lt('Kaydedildi.'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Sponsor>>(
      stream: SupportService.allSponsors(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(errorText(snap.error!))));
        if (!snap.hasData) return const LoadingView();
        final list = snap.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GoldButton(label: lt('Katkı sunan ekle'), icon: Icons.add, onPressed: () => _edit(context)),
            const SizedBox(height: 14),
            for (final s in list) ...[
              Opacity(opacity: s.active && !s.expired ? 1 : 0.5, child: SponsorCard(s)),
              if (s.endAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Text(
                    s.expired ? lt('Süresi doldu: {0}', [formatDateTime(s.endAt!)]) : lt('Yayın bitişi: {0}', [formatDateTime(s.endAt!)]),
                    style: AppText.body(12, color: s.expired ? AppColors.danger : AppColors.muted),
                  ),
                ),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text(s.active ? lt('Yayında') : lt('Gizli'), style: AppText.body(12, color: AppColors.muted)),
                Switch(
                  value: s.active,
                  activeThumbColor: AppColors.gold,
                  onChanged: (v) => runGuarded(context, () => SupportService.setSponsorActive(s.id, v)),
                ),
                IconButton(tooltip: lt('Düzenle'), icon: Icon(Icons.edit_outlined, color: AppColors.gold), onPressed: () => _edit(context, s)),
                IconButton(
                  tooltip: lt('Sil'),
                  icon: Icon(Icons.delete_outline, color: AppColors.danger),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(lt('Silinsin mi?'), style: AppText.display(24)),
                        content: Text(lt('{0} listeden kalıcı olarak silinecek.', [s.name]), style: AppText.body(14)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(lt('Vazgeç'))),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(lt('Sil'))),
                        ],
                      ),
                    );
                    if (ok == true && context.mounted) await runGuarded(context, () => SupportService.deleteSponsor(s.id));
                  },
                ),
              ]),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

class _Settings extends StatefulWidget {
  const _Settings();
  @override
  State<_Settings> createState() => _SettingsState();
}

class _SettingsState extends State<_Settings> {
  final _contact = TextEditingController();
  final _text = TextEditingController();
  final _iban = TextEditingController();
  final _account = TextEditingController();
  bool _loaded = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: SupportService.supportSettings(),
      builder: (context, snap) {
        if (!snap.hasData) return const LoadingView();
        if (!_loaded) {
          _loaded = true;
          final m = snap.data!;
          _contact.text = (m['contact'] as String?) ?? SupportService.defaultContactEmail;
          _text.text = (m['text'] as String?) ?? '';
          _iban.text = (m['iban'] as String?) ?? '';
          _account.text = (m['accountName'] as String?) ?? '';
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _SesAyari(),
            const SizedBox(height: 16),
            TextField(key: const Key('set_contact'), controller: _contact, decoration: InputDecoration(labelText: lt('İletişim e-postası'))),
            const SizedBox(height: 12),
            TextField(
              key: const Key('set_text'),
              controller: _text,
              maxLines: 3,
              decoration: InputDecoration(labelText: lt('Destek ol metni (isteğe bağlı)')),
            ),
            const SizedBox(height: 12),
            TextField(key: const Key('set_iban'), controller: _iban, decoration: InputDecoration(labelText: lt('IBAN (isteğe bağlı)'))),
            const SizedBox(height: 12),
            TextField(key: const Key('set_account'), controller: _account, decoration: InputDecoration(labelText: lt('Hesap sahibi'))),
            const SizedBox(height: 18),
            GoldButton(
              label: lt('Kaydet'),
              onPressed: () => runGuarded(
                context,
                () => SupportService.saveSettings({
                  'contact': _contact.text.trim(),
                  'text': _text.text.trim(),
                  'iban': _iban.text.trim(),
                  'accountName': _account.text.trim(),
                }),
                success: lt('Ayarlar kaydedildi.'),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Hafız Kardeşim'deki "Suistimal bildir" kayıtları (şikâyet olarak gelir, metni bu etiketle başlar).
bool suistimalMi(SupportThread t) =>
    t.category == 'sikayet' && t.messages.isNotEmpty && t.messages.first.text.startsWith('[Hafız Kardeşim · Suistimal');

/// Bildirimin metninden bildirilen üyenin uid'i ve adı.
(String, String)? _bildirilen(SupportThread t) {
  final m = RegExp(r'Bildirilen: (.*) \(uid: ([^)]+)\)').firstMatch(t.messages.first.text);
  return m == null ? null : (m.group(2)!, m.group(1)!);
}

class _SuistimalSekmeBasligi extends StatelessWidget {
  const _SuistimalSekmeBasligi();
  @override
  Widget build(BuildContext context) => StreamBuilder<List<SupportThread>>(
        stream: SupportService.allThreads(),
        builder: (context, snap) {
          final n = (snap.data ?? const <SupportThread>[]).where((t) => suistimalMi(t) && t.unreadForAdmin).length;
          return Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('🚩 Suistimal'),
            if (n > 0) ...[
              const SizedBox(width: 6),
              StatusPill('$n', color: AppColors.danger),
            ],
          ]);
        },
      );
}

/// Yönetici: suistimal bildirimleri. Bildirimi açıp cevap yazabilir, bildirilen üyeyi engelleyebilir.
class _Suistimaller extends StatelessWidget {
  const _Suistimaller();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SupportThread>>(
      stream: SupportService.allThreads(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(errorText(snap.error!))));
        if (!snap.hasData) return const LoadingView();
        final list = snap.data!.where(suistimalMi).toList();
        if (list.isEmpty) {
          return SingleChildScrollView(
              child: EmptyState(title: 'Bildirim yok', message: 'Hoca–öğrenci bölümünden yapılan suistimal bildirimleri burada görünür.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final t = list[i];
            final kim = _bildirilen(t);
            final govde = t.messages.first.text.split('\n').skip(1).join('\n').trim();
            return OrnateCard(
              highlight: t.unreadForAdmin,
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  StatusPill(t.unreadForAdmin ? 'Yeni' : 'Görüldü', color: t.unreadForAdmin ? AppColors.danger : AppColors.muted),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text('Bildiren: ${t.name}', overflow: TextOverflow.ellipsis, style: AppText.body(14, weight: FontWeight.w600))),
                ]),
                const SizedBox(height: 6),
                Text(govde, style: AppText.body(13.5)),
                Text(formatDateTime(t.updatedAt), style: AppText.body(11, color: AppColors.muted)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => SupportThreadScreen(threadId: t.id, asAdmin: true))),
                    icon: const Icon(Icons.forum_outlined),
                    label: const Text('Aç / cevap yaz'),
                  ),
                  if (kim != null)
                    TextButton.icon(
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Üye engellensin mi?'),
                            content: Text('${kim.$2} engellenir: hoca–öğrenci isteği gönderemez, canlı ders başlatamaz.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
                              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Engelle')),
                            ],
                          ),
                        );
                        if (ok == true && context.mounted) {
                          await runGuarded(context, () => AdminService.setBlocked(kim.$1, true), success: '${kim.$2} engellendi');
                        }
                      },
                      icon: Icon(Icons.block, color: AppColors.danger),
                      label: Text('${kim.$2} kişisini engelle', style: TextStyle(color: AppColors.danger)),
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

/// Canlı ders sesli bağlantısı için aktarma (TURN) sunucusu. Bazı mobil operatörlerde iki telefon
/// doğrudan bağlanamaz; o zaman ses bu sunucunun üzerinden geçer. Metered.ca'nın ücretsiz planındaki
/// "kimlik adresi" (…metered.live/api/v1/turn/credentials?apiKey=…) yazılır. Firestore app/ses belgesinde durur.
class _SesAyari extends StatefulWidget {
  const _SesAyari();
  @override
  State<_SesAyari> createState() => _SesAyariState();
}

class _SesAyariState extends State<_SesAyari> {
  final _url = TextEditingController();
  bool _yuklendi = false;

  @override
  void initState() {
    super.initState();
    FirebaseFirestore.instance.collection('app').doc('ses').get().then((d) {
      if (!mounted) return;
      _url.text = (d.data()?['turnUrl'] ?? '') as String;
      setState(() => _yuklendi = true);
    }).catchError((_) {
      if (mounted) setState(() => _yuklendi = true);
    });
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OrnateCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Canlı ders sesli bağlantısı (TURN)', style: AppText.body(15, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Bazı mobil operatörlerde telefonlar doğrudan bağlanamaz. Metered.ca ücretsiz hesabındaki TURN kimlik adresini yapıştırın.',
              style: AppText.body(12.5, color: AppColors.muted)),
          const SizedBox(height: 8),
          TextField(
            controller: _url,
            enabled: _yuklendi,
            decoration: const InputDecoration(labelText: 'https://….metered.live/api/v1/turn/credentials?apiKey=…'),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: !_yuklendi
                  ? null
                  : () => runGuarded(
                        context,
                        () => FirebaseFirestore.instance.collection('app').doc('ses').set({'turnUrl': _url.text.trim()}, SetOptions(merge: true)),
                        success: 'Kaydedildi',
                      ),
              child: const Text('Kaydet'),
            ),
          ),
        ]),
      );
}
