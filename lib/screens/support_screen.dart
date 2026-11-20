import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../services/support_service.dart';
import '../utils/ad_image.dart';
import 'ad_crop_screen.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/ornaments.dart';
import 'sources_screen.dart';
import '../l10n/l10n.dart';

/// Destek ve iletişim: bize yazın (destek / şikâyet / öneri), iletişim e-postası,
/// reklam talebi, katkı sunanlar ve destek bilgileri.
/// katkı sunanların görselleri yalnızca burada, yöneticinin onayıyla yayınlanır.
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key, required this.me});
  final AppUser me;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(lt('Destek ve İletişim'))),
      body: PatternBackground(
        child: StreamBuilder<Map<String, dynamic>>(
          stream: SupportService.supportSettings(),
          builder: (context, setSnap) {
            final settings = setSnap.data ?? const <String, dynamic>{};
            final email = ((settings['contact'] as String?) ?? '').trim().isNotEmpty
                ? (settings['contact'] as String).trim()
                : SupportService.defaultContactEmail;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                GoldButton(
                  label: lt('İşbirliği kur / katkı sun'),
                  icon: Icons.campaign_outlined,
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdRequestScreen(me: me))),
                ),
                const SizedBox(height: 24),
                SectionTitle(lt('Katkı sunanlar')),
                const SizedBox(height: 10),
                const _Sponsors(),
                if (((settings['iban'] as String?) ?? '').isNotEmpty || ((settings['text'] as String?) ?? '').isNotEmpty) ...[
                  const SizedBox(height: 24),
                  SectionTitle(lt('Destek ol')),
                  const SizedBox(height: 10),
                  _DonateCard(settings: settings),
                ],
                const SizedBox(height: 24),
                SectionTitle(lt('İletişim')),
                const SizedBox(height: 10),
                _EmailCard(email: email),
                const SizedBox(height: 24),
                SectionTitle(lt('Bize yazın')),
                const SizedBox(height: 10),
                _NewMessageCard(me: me),
                const SizedBox(height: 12),
                _MyThreads(me: me),
                const SizedBox(height: 28),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SourcesScreen())),
                    child: Text(lt('Kaynakça'),
                        style: AppText.body(13, color: AppColors.muted, weight: FontWeight.w600)
                            .copyWith(decoration: TextDecoration.underline, decorationColor: AppColors.muted)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EmailCard extends StatelessWidget {
  const _EmailCard({required this.email});
  final String email;

  @override
  Widget build(BuildContext context) {
    return OrnateCard(
      child: Row(children: [
        Icon(Icons.mail_outline, color: AppColors.gold),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('E-POSTA', style: AppText.label()),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: SelectableText(email, maxLines: 1, style: AppText.body(15, weight: FontWeight.w600)),
            ),
          ]),
        ),
        IconButton(
          tooltip: lt('Kopyala'),
          icon: Icon(Icons.copy, color: AppColors.gold),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: email));
            if (context.mounted) showSnack(context, lt('E-posta adresi kopyalandı.'));
          },
        ),
        IconButton(
          tooltip: lt('E-posta gönder'),
          icon: Icon(Icons.send_outlined, color: AppColors.gold),
          onPressed: () => launchUrl(Uri(scheme: 'mailto', path: email, query: lt('subject=Hafız Kardeşim'))),
        ),
      ]),
    );
  }
}

class _NewMessageCard extends StatefulWidget {
  const _NewMessageCard({required this.me});
  final AppUser me;
  @override
  State<_NewMessageCard> createState() => _NewMessageCardState();
}

class _NewMessageCardState extends State<_NewMessageCard> {
  String _category = 'destek';
  final _text = TextEditingController();
  bool _busy = false;

  Future<void> _send() async {
    setState(() => _busy = true);
    final ok = await runGuarded(context, () => SupportService.create(widget.me, _category, _text.text),
        success: lt('Mesajınız bize ulaştı. Cevabımızı buradan görebileceksiniz.'));
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    return OrnateCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            for (final e in SupportService.categories.entries)
              ButtonSegment(value: e.key, label: FittedBox(fit: BoxFit.scaleDown, child: Text(e.value, maxLines: 1, softWrap: false))),
          ],
          selected: {_category},
          onSelectionChanged: (s) => setState(() => _category = s.first),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('support_text'),
          controller: _text,
          maxLines: 4,
          maxLength: 2000,
          decoration: InputDecoration(hintText: lt('Mesajınızı yazın…')),
        ),
        const SizedBox(height: 4),
        GoldButton(label: lt('Gönder'), icon: Icons.send, busy: _busy, onPressed: _send),
      ]),
    );
  }
}

class _MyThreads extends StatelessWidget {
  const _MyThreads({required this.me});
  final AppUser me;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SupportThread>>(
      stream: SupportService.myThreads(me.id),
      builder: (context, snap) {
        final list = snap.data ?? const <SupportThread>[];
        if (list.isEmpty) return const SizedBox.shrink();
        return OrnateCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(children: [
            for (final t in list)
              ListTile(
                leading: Icon(
                  t.unreadForUser ? Icons.mark_email_unread_outlined : Icons.forum_outlined,
                  color: t.unreadForUser ? AppColors.gold : AppColors.muted,
                ),
                title: Text(t.messages.isNotEmpty ? t.messages.first.text : '',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(14)),
                subtitle: Text(
                  '${SupportService.categories[t.category] ?? t.category} · ${formatDateTime(t.updatedAt)}'
                  '${t.unreadForUser ? ' · yeni cevap' : ''}',
                  style: AppText.body(12, color: t.unreadForUser ? AppColors.gold : AppColors.muted),
                ),
                trailing: Icon(Icons.chevron_right, color: AppColors.muted),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SupportThreadScreen(threadId: t.id, asAdmin: false)),
                ),
              ),
          ]),
        );
      },
    );
  }
}

/// Bir yazışmanın ayrıntısı; üye de yönetici de buradan cevap yazar.
class SupportThreadScreen extends StatefulWidget {
  const SupportThreadScreen({super.key, required this.threadId, required this.asAdmin});
  final String threadId;
  final bool asAdmin;
  @override
  State<SupportThreadScreen> createState() => _SupportThreadScreenState();
}

class _SupportThreadScreenState extends State<SupportThreadScreen> {
  late final Stream<SupportThread?> _stream = SupportService.thread(widget.threadId);
  final _text = TextEditingController();
  bool _busy = false;
  bool _marked = false;

  Future<void> _send() async {
    setState(() => _busy = true);
    final ok = await runGuarded(
      context,
      () => widget.asAdmin
          ? SupportService.adminReply(widget.threadId, _text.text)
          : SupportService.userReply(widget.threadId, _text.text),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(lt('Mesajlaşma'))),
      body: PatternBackground(
        child: StreamBuilder<SupportThread?>(
          stream: _stream,
          builder: (context, snap) {
            final t = snap.data;
            if (t == null) return const LoadingView();
            if (!_marked) {
              _marked = true;
              if (widget.asAdmin && t.unreadForAdmin) SupportService.markReadByAdmin(t.id);
              if (!widget.asAdmin && t.unreadForUser) SupportService.markReadByUser(t.id);
            }
            return Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(children: [
                  StatusPill(SupportService.categories[t.category] ?? t.category),
                  const SizedBox(width: 8),
                  if (widget.asAdmin) Expanded(child: Text(t.name, overflow: TextOverflow.ellipsis, style: AppText.body(14))),
                ]),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    for (final m in t.messages)
                      Align(
                        alignment: m.fromAdmin == widget.asAdmin ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: m.fromAdmin ? AppColors.gold.withValues(alpha: 0.16) : AppColors.inkSoft,
                            border: Border.all(color: AppColors.gold.withValues(alpha: m.fromAdmin ? 0.6 : 0.25)),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(m.fromAdmin ? lt('Hafız Kardeşim') : (widget.asAdmin ? t.name : lt('Siz')),
                                style: AppText.label(size: 10, color: m.fromAdmin ? AppColors.gold : AppColors.muted)),
                            const SizedBox(height: 4),
                            SelectableText(m.text, style: AppText.body(14)),
                            const SizedBox(height: 4),
                            Text(formatDateTime(m.at), style: AppText.body(10, color: AppColors.muted)),
                          ]),
                        ),
                      ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        key: const Key('thread_reply'),
                        controller: _text,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(hintText: widget.asAdmin ? lt('Cevabınızı yazın…') : lt('Ek mesaj yazın…')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.inkDeep),
                      onPressed: _busy ? null : _send,
                      icon: const Icon(Icons.send),
                    ),
                  ]),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

class _Sponsors extends StatelessWidget {
  const _Sponsors();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Sponsor>>(
      stream: SupportService.activeSponsors(),
      builder: (context, snap) {
        if (snap.hasError) return OrnateCard(child: Text(errorText(snap.error!)));
        if (!snap.hasData) return const SizedBox(height: 80, child: LoadingView());
        final list = snap.data!;
        if (list.isEmpty) {
          return OrnateCard(
            child: Text(lt('Katkı sunanlar burada yer alacak. Siz de "İşbirliği kur / katkı sun" ile talep oluşturabilirsiniz.'),
                style: AppText.body(14, color: AppColors.muted)),
          );
        }
        return Column(children: [
          for (final s in list) ...[SponsorCard(s), const SizedBox(height: 12)],
        ]);
      },
    );
  }
}

/// Katkı sunan kartı: görsele dokununca web sayfası açılır; köşedeki "Detay" düğmesi
/// büyük görsel ve açıklamanın olduğu sayfayı açar.
class SponsorCard extends StatelessWidget {
  const SponsorCard(this.s, {super.key});
  final Sponsor s;

  static Future<void> openLink(BuildContext context, Sponsor s) async {
    final uri = Uri.tryParse(s.link.startsWith('http') ? s.link : 'https://${s.link}');
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) showSnack(context, lt('Bağlantı açılamadı: {0}', [s.link]));
    }
  }

  void _detail(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => SponsorDetailScreen(s: s)));

  bool get _hasImage => s.image != null || s.imageUrl.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return OrnateCard(
      padding: const EdgeInsets.all(12),
      onTap: () => s.link.isNotEmpty ? openLink(context, s) : _detail(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_hasImage)
          Stack(children: [
            Semantics(
              button: true,
              label: s.link.isNotEmpty ? lt('{0} bağlantısını aç', [s.name]) : s.name,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(aspectRatio: 16 / 9, child: SponsorImage(s, fit: BoxFit.cover)),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.black.withValues(alpha: 0.55),
                shape: const StadiumBorder(),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => _detail(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.info_outline, size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(lt('Detay'), style: AppText.body(12, color: Colors.white, weight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
            ),
          ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 12, 6, 4),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.name, style: AppText.display(22)),
                if (s.note.isNotEmpty) Text(s.note, style: AppText.body(13, color: AppColors.muted)),
              ]),
            ),
            if (!_hasImage)
              IconButton(tooltip: lt('Detay'), onPressed: () => _detail(context), icon: Icon(Icons.info_outline, color: AppColors.gold)),
            if (s.link.isNotEmpty) Icon(Icons.open_in_new, color: AppColors.gold, size: 20),
          ]),
        ),
      ]),
    );
  }
}

/// Katkı sunanın görseli: yüklenen resim/GIF ya da (eski kayıtlarda) bağlantı.
class SponsorImage extends StatelessWidget {
  const SponsorImage(this.s, {super.key, this.fit = BoxFit.cover});
  final Sponsor s;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(color: AppColors.inkDeep);
    if (s.image != null) {
      return Image.memory(s.image!, fit: fit, gaplessPlayback: true, errorBuilder: (_, __, ___) => fallback);
    }
    if (s.imageUrl.isNotEmpty) {
      return Image.network(s.imageUrl, fit: fit, errorBuilder: (_, __, ___) => fallback);
    }
    return fallback;
  }
}

/// Reklam detayı: büyük görsel, açıklama ve web sayfası düğmesi.
class SponsorDetailScreen extends StatelessWidget {
  const SponsorDetailScreen({super.key, required this.s});
  final Sponsor s;

  @override
  Widget build(BuildContext context) {
    final text = s.detail.isNotEmpty ? s.detail : s.note;
    return Scaffold(
      appBar: AppBar(title: Text(s.name)),
      body: PatternBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            if (s.image != null || s.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: InteractiveViewer(maxScale: 4, child: SponsorImage(s, fit: BoxFit.contain)),
              ),
            const SizedBox(height: 18),
            Text(s.name, style: AppText.display(26, color: AppColors.goldLight)),
            if (text.isNotEmpty) ...[
              const SizedBox(height: 10),
              SelectableText(text, style: AppText.body(15)),
            ],
            if (s.link.isNotEmpty) ...[
              const SizedBox(height: 22),
              GoldButton(label: lt('Web sayfasına git'), icon: Icons.open_in_new, onPressed: () => SponsorCard.openLink(context, s)),
            ],
          ],
        ),
      ),
    );
  }
}

class _DonateCard extends StatelessWidget {
  const _DonateCard({required this.settings});
  final Map<String, dynamic> settings;

  @override
  Widget build(BuildContext context) {
    final iban = (settings['iban'] ?? '') as String;
    return OrnateCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (((settings['text'] as String?) ?? '').isNotEmpty) Text(settings['text'] as String, style: AppText.body(14)),
        if (iban.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('IBAN', style: AppText.label()),
          if ((settings['accountName'] ?? '').toString().isNotEmpty)
            Text(settings['accountName'] as String, style: AppText.body(13, color: AppColors.muted)),
          Row(children: [
            Expanded(child: SelectableText(iban, style: AppText.number(15))),
            IconButton(
              tooltip: lt('Kopyala'),
              icon: Icon(Icons.copy, color: AppColors.gold),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: iban));
                if (context.mounted) showSnack(context, lt('IBAN kopyalandı.'));
              },
            ),
          ]),
        ],
      ]),
    );
  }
}

/// Reklam / katkı talebi formu. Yayınlama kararı yalnızca yöneticidedir;
/// telefon numarası yalnızca yönetici tarafından görülür.
class AdRequestScreen extends StatefulWidget {
  const AdRequestScreen({super.key, required this.me});
  final AppUser me;
  @override
  State<AdRequestScreen> createState() => _AdRequestScreenState();
}

class _AdRequestScreenState extends State<AdRequestScreen> {
  final _company = TextEditingController();
  final _detail = TextEditingController();
  final _link = TextEditingController();
  Uint8List? _image;
  String _imageType = '';
  int? _days; // 0 = özel süre
  bool _picking = false;

  Future<void> _pick() async {
    setState(() => _picking = true);
    try {
      final r = await pickAdImageRaw();
      if (r != null && mounted) {
        if (r.$2) {
          // GIF hareketli kalsın diye kırpılmaz.
          setState(() {
            _image = r.$1;
            _imageType = 'image/gif';
          });
        } else {
          final cropped = await Navigator.push<Uint8List>(
              context, MaterialPageRoute(builder: (_) => AdCropScreen(bytes: r.$1)));
          if (cropped != null && mounted) {
            setState(() {
              _image = cropped;
              _imageType = 'image/jpeg';
            });
          }
        }
      }
    } catch (e) {
      if (mounted) showSnack(context, errorText(e));
    }
    if (mounted) setState(() => _picking = false);
  }
  final _phone = TextEditingController();
  bool _busy = false;

  Future<void> _submit() async {
    setState(() => _busy = true);
    final ok = await runGuarded(
      context,
      () => SupportService.sendAdRequest(
        me: widget.me,
        company: _company.text,
        detail: _detail.text,
        image: _image,
        imageType: _imageType,
        link: _link.text,
        phone: _phone.text,
        durationDays: _days,
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(lt('Teşekkür ederiz'), style: AppText.display(26)),
          content: Text(lt('Katkı ve destek talebinizden dolayı teşekkür ederiz. İşbirliği talebinizi inceleyip en kısa sürede size dönüş sağlayacağız.'),
              style: AppText.body(14)),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(lt('Tamam')))],
        ),
      );
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(lt('İşbirliği Kur · Katkı Sun'))),
      body: PatternBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            OrnateCard(
              child: Text(
                lt('Katkı sunanlar yalnızca "Destek ve İletişim" sayfasında yer alır. Talebinizi aldıktan sonra inceleyip sizinle iletişime geçeceğiz.'),
                style: AppText.body(13, color: AppColors.muted),
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              key: const Key('ad_company'),
              controller: _company,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: lt('Firma / kişi adı')),
            ),
            const SizedBox(height: 14),
            Text(lt('Tanıtım görseli'), style: AppText.label()),
            const SizedBox(height: 8),
            InkWell(
              onTap: _picking ? null : _pick,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.55)),
                  color: AppColors.inkDeep.withValues(alpha: 0.4),
                ),
                clipBehavior: Clip.antiAlias,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _picking
                      ? const Center(child: CircularProgressIndicator())
                      : _image == null
                          ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.add_photo_alternate_outlined, color: AppColors.gold, size: 38),
                              const SizedBox(height: 8),
                              Text(lt('Resim ya da GIF seçin'), style: AppText.body(14, weight: FontWeight.w600)),
                              Text(lt('Yatay (16:9) görsel önerilir · GIF en fazla 700 KB'),
                                  style: AppText.body(12, color: AppColors.muted)),
                            ])
                          : Stack(fit: StackFit.expand, children: [
                              Image.memory(_image!, fit: BoxFit.cover, gaplessPlayback: true),
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: Material(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  shape: const StadiumBorder(),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    child: Text(lt('Değiştir'), style: AppText.body(12, color: Colors.white, weight: FontWeight.w700)),
                                  ),
                                ),
                              ),
                            ]),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('ad_detail'),
              controller: _detail,
              maxLines: 4,
              maxLength: 1000,
              decoration: InputDecoration(
                labelText: lt('Açıklama'),
                hintText: lt('"Detay" düğmesine dokunanlar bu açıklamayı büyük görselle birlikte görür.'),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              key: const Key('ad_link'),
              controller: _link,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: lt('Görsele dokununca açılacak web sayfası (isteğe bağlı)'),
                hintText: 'https://…',
              ),
            ),
            const SizedBox(height: 14),
            Text(lt('Yayın süresi'), style: AppText.label()),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final (d, label) in [(3, lt('3 gün')), (7, lt('1 hafta')), (15, lt('15 gün')), (30, lt('1 ay')), (0, lt('Özel süre'))])
                ChoiceChip(
                  label: Text(label,
                      style: AppText.body(13,
                          weight: FontWeight.w700,
                          color: _days == d ? (AppColors.isLight ? const Color(0xFFFFF8E8) : AppColors.inkDeep) : AppColors.ivory)),
                  selected: _days == d,
                  onSelected: (_) => setState(() => _days = d),
                ),
            ]),
            const SizedBox(height: 6),
            Text(
              _days == 0
                  ? lt('Özel süreyi sizinle görüşerek birlikte belirleyeceğiz.')
                  : lt('Katkı sunan tanıtımı, onaylandığı günden başlayarak seçilen süre sonunda kendiliğinden kaldırılır.'),
              style: AppText.body(12, color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('ad_phone'),
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: lt('İletişim telefonu (zorunlu)'),
                hintText: lt('05xx xxx xx xx'),
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.lock_outline, size: 14, color: AppColors.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(lt('Numaranız sadece yönetim tarafından görünür.'),
                    style: AppText.body(12, color: AppColors.muted)),
              ),
            ]),
            const SizedBox(height: 22),
            GoldButton(label: lt('Talebimi gönder'), icon: Icons.send, busy: _busy, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
