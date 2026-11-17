import 'package:flutter/material.dart';

import '../data/daily_content.dart';
import '../data/meal.dart';
import '../data/quran.dart';
import '../models/constants.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/hatim_service.dart';
import '../services/social_service.dart';
import '../services/support_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/crown.dart';
import '../widgets/ornaments.dart';
import '../widgets/prayer_card.dart';
import 'create_group_screen.dart';
import 'dua_screen.dart';
import 'friends_screen.dart';
import 'groups_screen.dart';
import 'juz_reader_screen.dart';
import 'admin_screen.dart';
import 'profile_screen.dart';
import 'audio_quran_screen.dart';
import 'qibla_screen.dart';
import 'quran_screen.dart';
import '../widgets/guest.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';
import 'support_screen.dart';
import 'top_readers_screen.dart';
import '../l10n/l10n.dart';

/// Ana iskelet: alt sekme çubuğu (Ana Sayfa, Kur'an Oku, ortada Cüz Oku, Arkadaşlar, Daha fazla).
/// Ana sayfa kaydırmadan tek ekrana sığacak şekilde düzenlenmiştir.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.me});
  final AppUser me;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  void _open(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  /// Ortadaki düğme: elindeki okunmamış cüzü açar.
  Future<void> _readJuz() async {
    final me = widget.me;
    List<Juz> list;
    try {
      list = (await HatimService.juzOf(me.id).first).where((j) => !j.isDone && !j.isEmpty).toList()
        ..sort((a, b) => (a.endAt ?? DateTime(2100)).compareTo(b.endAt ?? DateTime(2100)));
    } catch (e) {
      if (mounted) showSnack(context, errorText(e));
      return;
    }
    if (!mounted) return;
    if (list.isEmpty) {
      showSnack(context, lt('Okunacak cüzünüz yok. Bir gruptan cüz alarak başlayabilirsiniz.'));
      _open(GroupsScreen(me: me));
      return;
    }
    Juz? pick = list.length == 1 ? list.first : null;
    pick ??= await showModalBottomSheet<Juz>(
      context: context,
      backgroundColor: AppColors.ink,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
            child: Text(lt('Hangi cüzü okuyacaksınız?'), style: AppText.display(22)),
          ),
          Flexible(
            child: ListView(shrinkWrap: true, children: [
              for (final j in list)
                ListTile(
                  leading: Text('${j.number}', style: AppText.number(24, color: AppColors.goldLight)),
                  title: Text(j.groupName, style: AppText.body(15, weight: FontWeight.w600)),
                  subtitle: Text(
                    j.endAt != null ? remainingText(j.endAt!) : JuzStatus.label(j.status),
                    style: AppText.body(12, color: j.isOverdue ? AppColors.danger : AppColors.muted),
                  ),
                  trailing: Icon(Icons.menu_book_rounded, color: AppColors.gold),
                  onTap: () => Navigator.pop(ctx, j),
                ),
            ]),
          ),
          const SizedBox(height: 12),
        ]),
      ),
    );
    if (pick == null || !mounted) return;
    final g = await HatimService.group(pick.groupId).first;
    if (!mounted) return;
    if (g == null) {
      showSnack(context, lt('Grup bulunamadı'));
      return;
    }
    _open(JuzReaderScreen(group: g, juz: pick, me: me));
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _tab = 0);
      },
      child: StreamBuilder<List<FriendRequest>>(
        stream: SocialService.incomingRequests(me.id),
        builder: (context, reqSnap) => StreamBuilder<List<SupportThread>>(
          stream: SupportService.myThreads(me.id),
          builder: (context, supSnap) {
            final requests = reqSnap.data?.length ?? 0;
            final supportUnread = (supSnap.data ?? const <SupportThread>[]).where((t) => t.unreadForUser).length;
            return Scaffold(
              body: IndexedStack(index: _tab, children: [
                _HomeTab(me: me, open: _open, supportUnread: supportUnread),
                const QuranScreen(),
                me.isGuest ? GuestOnlyView(title: lt('Arkadaşlar')) : FriendsScreen(me: me),
                _MoreTab(me: me, open: _open, supportUnread: supportUnread),
              ]),
              bottomNavigationBar: _BottomBar(
                index: _tab,
                friendBadge: requests,
                moreBadge: supportUnread,
                onTab: (i) => setState(() => _tab = i),
                onRead: _readJuz,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Ana sayfa sekmesi: selamlama, ezan vakitleri, günün ayeti/hadisi, ayın okuyanı ve hızlı işlemler.
class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.me, required this.open, required this.supportUnread});
  final AppUser me;
  final void Function(Widget) open;
  final int supportUnread;

  @override
  Widget build(BuildContext context) {
    return PatternBackground(
      child: SafeArea(
        bottom: false,
        // Ekrana sabit oturur; dörtlü menü kalan alanı doldurur. Küçük ekranda kaydırılabilir.
        // Ekrana sabit oturur: ayet ve hadis kutuları kalan alanı paylaşır, alttaki dört kutu alçaktır.
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _Header(me: me, onProfile: () => me.isGuest ? open(GuestOnlyView(title: lt('Profilim'))) : open(ProfileScreen(me: me))),
            const SizedBox(height: 10),
            _FinishedHatims(me: me),
            // Günün ayeti ve hadisi tek kutuda; yana kaydırınca biri ötekine geçer.
            const Expanded(flex: 8, child: _DailyPager()),
            const SizedBox(height: 12),
            const PrayerCard(),
            const SizedBox(height: 12),
            _TopReaderCard(me: me),
            const SizedBox(height: 12),
            Expanded(flex: 10, child: _QuickActions(me: me, open: open, supportUnread: supportUnread)),
          ]),
        ),
      ),
    );
  }
}

/// 2×2 hızlı işlemler.
class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.me, required this.open, required this.supportUnread});
  final AppUser me;
  final void Function(Widget) open;
  final int supportUnread;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GroupInvite>>(
      stream: SocialService.incomingInvites(me.id),
      builder: (context, invSnap) {
        final items = me.isGuest
            ? <(IconData, String, VoidCallback, int)>[
                (Icons.explore_outlined, lt('Kıble pusulası'), () => open(const QiblaScreen()), 0),
                (Icons.settings_outlined, lt('Ayarlar'), () => open(const SettingsScreen()), 0),
                (Icons.volunteer_activism_outlined, lt('Destek ve İletişim'), () => open(SupportScreen(me: me)), supportUnread),
                (Icons.person_add_alt_1_outlined, lt('Üye ol'), () => confirmLogout(context), 0),
              ]
            : <(IconData, String, VoidCallback, int)>[
          (Icons.group_add_outlined, lt('Gruba katıl'), () => open(GroupsScreen(me: me)), 0),
          (Icons.add_circle_outline, lt('Hatim Grubu Kur'), () => open(CreateGroupScreen(me: me)), 0),
          (Icons.volunteer_activism_outlined, lt('Destek ve İletişim'), () => open(SupportScreen(me: me)), supportUnread),
          (Icons.insights_outlined, lt('İstatistikler'), () => open(StatsScreen(me: me)), 0),
        ];
        Widget cell((IconData, String, VoidCallback, int) i) => Material(
              color: AppColors.inkDeep.withValues(alpha: 0.45),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.gold.withValues(alpha: 0.35)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: i.$3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(children: [
                    Icon(i.$1, size: 26, color: AppColors.goldLight),
                    const SizedBox(width: 10),
                    Expanded(
                      // Ad kesilmez: gerekirse iki satıra iner, yine sığmazsa hafifçe küçülür.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 120),
                          child: Text(i.$2, maxLines: 2, softWrap: true,
                              style: AppText.body(15, weight: FontWeight.w700, height: 1.2)),
                        ),
                      ),
                    ),
                    if (i.$4 > 0) _Badge(i.$4),
                  ]),
                ),
              ),
            );
        Widget row(int k) => Expanded(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: cell(items[k])),
                const SizedBox(width: 8),
                Expanded(child: cell(items[k + 1])),
              ]),
            );
        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 120),
          child: Column(children: [row(0), const SizedBox(height: 10), row(2)]),
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.count);
  final int count;
  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 18),
        height: 18,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(9)),
        alignment: Alignment.center,
        child: Text('$count', style: AppText.body(11, color: AppColors.inkDeep, weight: FontWeight.w700, height: 1)),
      );
}

/// Alt sekme çubuğu; ortada altın "Cüz Oku" düğmesi.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.index, required this.friendBadge, required this.moreBadge, required this.onTab, required this.onRead});
  final int index, friendBadge, moreBadge;
  final ValueChanged<int> onTab;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) {
    Widget tab(int i, IconData icon, IconData activeIcon, String label, int badge) {
      final on = index == i;
      final c = on ? AppColors.gold : AppColors.muted;
      return Expanded(
        child: InkWell(
          onTap: () => onTab(i),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Stack(clipBehavior: Clip.none, children: [
              Icon(on ? activeIcon : icon, color: c, size: 24),
              if (badge > 0) Positioned(right: -10, top: -6, child: _Badge(badge)),
            ]),
            const SizedBox(height: 3),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: AppText.body(10.5, color: c, weight: FontWeight.w600, height: 1.1)),
          ]),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.inkDeep.withValues(alpha: 0.97),
        border: Border(top: BorderSide(color: AppColors.gold.withValues(alpha: 0.25))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(children: [
            tab(0, Icons.home_outlined, Icons.home_rounded, lt('Ana Sayfa'), 0),
            tab(1, Icons.auto_stories_outlined, Icons.auto_stories, lt('Kur\'an Oku'), 0),
            Expanded(
              child: GestureDetector(
                onTap: onRead,
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Transform.translate(
                    offset: const Offset(0, -10),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [AppColors.goldLight, AppColors.gold]),
                        boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 4))],
                      ),
                      child: Icon(Icons.auto_stories_rounded, color: AppColors.isLight ? const Color(0xFFFFF8E8) : AppColors.inkDeep, size: 26),
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -6),
                    child: Text(lt('Cüz Oku'), maxLines: 1,
                        style: AppText.body(10.5, color: AppColors.goldLight, weight: FontWeight.w700, height: 1.1)),
                  ),
                ]),
              ),
            ),
            tab(2, Icons.people_alt_outlined, Icons.people_alt_rounded, lt('Arkadaşlar'), friendBadge),
            tab(3, Icons.menu_rounded, Icons.menu_open_rounded, lt('Daha fazla'), moreBadge),
          ]),
        ),
      ),
    );
  }
}

/// "Daha fazla" sekmesi: profil, ayarlar, destek, davet, istatistik ve yönetim.
class _MoreTab extends StatelessWidget {
  const _MoreTab({required this.me, required this.open, required this.supportUnread});
  final AppUser me;
  final void Function(Widget) open;
  final int supportUnread;

  @override
  Widget build(BuildContext context) {
    final items = me.isGuest
        ? <(IconData, String, VoidCallback, int)>[
            (Icons.settings_outlined, lt('Ayarlar'), () => open(const SettingsScreen()), 0),
            (Icons.volunteer_activism_outlined, lt('Destek ve İletişim'), () => open(SupportScreen(me: me)), supportUnread),
            (Icons.explore_outlined, lt('Kıble pusulası'), () => open(const QiblaScreen()), 0),
            (Icons.headphones_outlined, lt('Sesli Kur\'an'), () => open(const AudioQuranScreen()), 0),
            (Icons.person_add_alt_1_outlined, lt('Üye ol'), () => confirmLogout(context), 0),
            (Icons.logout, lt('Çıkış yap'), () => confirmLogout(context), 0),
          ]
        : <(IconData, String, VoidCallback, int)>[
      // Ana sayfada bulunanlar (Gruba katıl, Grup kur, Destek, İstatistikler, Ayın okuyanları) burada tekrarlanmaz.
      (Icons.person_outline, lt('Profilim'), () => open(ProfileScreen(me: me)), 0),
      (Icons.mail_outline, lt('Davetlerim'), () => open(FriendsScreen(me: me, initialTab: 2)), 0),
      (Icons.explore_outlined, lt('Kıble pusulası'), () => open(const QiblaScreen()), 0),
      (Icons.headphones_outlined, lt('Sesli Kur\'an'), () => open(const AudioQuranScreen()), 0),
      (Icons.settings_outlined, lt('Ayarlar'), () => open(const SettingsScreen()), 0),
      (Icons.share_outlined, lt('Arkadaşınızı Davet Edin'), () => SocialService.shareApp(), 0),
      if (AuthService.isAdmin) (Icons.admin_panel_settings_outlined, lt('Yönetim'), () => open(AdminScreen(me: me)), 0),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(lt('Daha fazla')), automaticallyImplyLeading: false),
      body: PatternBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            for (final i in items) ...[
              OrnateCard(
                onTap: i.$3,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  Icon(i.$1, color: AppColors.goldLight),
                  const SizedBox(width: 14),
                  Expanded(child: Text(i.$2, style: AppText.body(15, weight: FontWeight.w600))),
                  if (i.$4 > 0) ...[_Badge(i.$4), const SizedBox(width: 8)],
                  Icon(Icons.chevron_right, color: AppColors.muted),
                ]),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.me, required this.onProfile});
  final AppUser me;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const AppLogo(size: 40, glow: 0.4),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lt('Esselâmü aleyküm,'), style: AppText.body(13, color: AppColors.muted)),
              Text(me.firstName, overflow: TextOverflow.ellipsis, style: AppText.display(26)),
              Text(formatToday(DateTime.now()), style: AppText.body(12, color: AppColors.gold)),
            ],
          ),
        ),
        IconButton(
          tooltip: lt('Profilim'),
          onPressed: onProfile,
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
            ),
            child: Icon(Icons.person_outline, color: AppColors.goldLight),
          ),
        ),
      ],
    );
  }
}

/// Günün ayeti ve günün hadisi tek kartta; üstteki iki düğmeyle geçilir.
/// Tek kutu: sola/sağa kaydırınca günün ayeti ile günün hadisi arasında geçilir.
class _DailyPager extends StatefulWidget {
  const _DailyPager();

  @override
  State<_DailyPager> createState() => _DailyPagerState();
}

class _DailyPagerState extends State<_DailyPager> {
  final _pc = PageController();
  int _i = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Widget _dot(int i) => GestureDetector(
        onTap: () => _pc.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: _i == i ? 18 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: _i == i ? AppColors.goldLight : AppColors.gold.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return OrnateCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: PageView(
            controller: _pc,
            onPageChanged: (i) => setState(() => _i = i),
            children: const [_DailyBox(hadith: false), _DailyBox(hadith: true)],
          ),
        ),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [_dot(0), _dot(1)]),
      ]),
    );
  }
}

/// Günün ayeti ya da günün hadisi kutusu. Metin küçültülmez; sığmazsa "Devamı" ile
/// ana sayfanın üstünde açılan pencerede tamamı okunur (dışına dokununca kapanır).
/// "Devamını oku" düğmesi: ince altın çerçeveli, küçük bir hap.
class _MorePill extends StatelessWidget {
  const _MorePill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.gold.withValues(alpha: 0.10),
      shape: StadiumBorder(side: BorderSide(color: AppColors.gold.withValues(alpha: 0.55), width: 0.8)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 5, 8, 5),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(lt('Devamını oku'),
                style: AppText.body(12, color: AppColors.goldLight, weight: FontWeight.w700).copyWith(letterSpacing: 0.3)),
            const SizedBox(width: 3),
            Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.goldLight),
          ]),
        ),
      ),
    );
  }
}

class _DailyBox extends StatefulWidget {
  const _DailyBox({required this.hadith});
  final bool hadith;

  @override
  State<_DailyBox> createState() => _DailyBoxState();
}

class _DailyBoxState extends State<_DailyBox> {
  bool get hadith => widget.hadith;
  late final DailyItem _item = hadith ? hadithOfDay() : ayahOfDay();
  late final Future<(String, String, bool)> _future = _resolve(_item);

  static const _maxLines = 3;

  /// (metin, kaynak, Arapça mı)
  static Future<(String, String, bool)> _resolve(DailyItem item) async {
    if (item.ref != null && item.arabic) {
      final r = item.ref!;
      final t = await Quran.ayahRange(r.$1, r.$2, r.$3);
      final src = '${Quran.surahName(r.$1)}، ${Quran.arabicDigits(r.$2)}${r.$3 != r.$2 ? '-${Quran.arabicDigits(r.$3)}' : ''}';
      return (t, src, true);
    }
    if (item.ref != null) {
      final r = item.ref!;
      final m = await Meal.range(r.$1, r.$2, r.$3);
      return (m ?? item.text, m != null ? '${item.source} · ${Meal.name}' : item.source, false);
    }
    return (item.text, item.source, item.arabic);
  }

  TextStyle _style(bool arabic) =>
      arabic ? AppText.arabic(22, color: AppColors.ivory) : AppText.display(23, weight: FontWeight.w500).copyWith(height: 1.3);

  void _more(BuildContext context, String title, (String, String, bool) d) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.inkDeep,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.gold.withValues(alpha: 0.5)),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: AppText.label()),
              const SizedBox(height: 10),
              Text(d.$1,
                  textDirection: d.$3 ? TextDirection.rtl : null,
                  textAlign: d.$3 ? TextAlign.justify : TextAlign.start,
                  style: d.$3 ? AppText.arabic(24, color: AppColors.ivory) : AppText.display(24, weight: FontWeight.w500).copyWith(height: 1.35)),
              const SizedBox(height: 10),
              Text('— ${d.$2}', style: AppText.body(12.5, color: AppColors.muted)),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final title = hadith ? lt('Günün hadisi') : lt('Günün ayeti');
    return FutureBuilder<(String, String, bool)>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData && item.ref != null) return const SizedBox.expand();
        final d = snap.data ?? (item.text, item.source, item.arabic);
        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _more(context, title, d),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: AppText.label(size: 12)),
            const SizedBox(height: 4),
            Expanded(
              child: LayoutBuilder(builder: (context, c) {
                final style = _style(d.$3);
                final scaler = MediaQuery.textScalerOf(context);
                final lineH = scaler.scale(style.fontSize ?? 19) * (style.height ?? 1.3);
                final lines = (c.maxHeight / lineH).floor().clamp(1, 20);
                final tp = TextPainter(
                  text: TextSpan(text: d.$1, style: style),
                  textDirection: d.$3 ? TextDirection.rtl : TextDirection.ltr,
                  maxLines: lines,
                  textScaler: scaler,
                )..layout(maxWidth: c.maxWidth);
                final long = tp.didExceedMaxLines;
                final text = Text(d.$1,
                    maxLines: lines,
                    overflow: TextOverflow.clip,
                    textDirection: d.$3 ? TextDirection.rtl : null,
                    style: style);
                // Uzun metin: son satır yumuşakça silikleşir.
                final body = !long
                    ? text
                    : ShaderMask(
                        blendMode: BlendMode.dstIn,
                        // Yalnızca son satır silikleşir.
                        shaderCallback: (r) => LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: const [Colors.white, Colors.white, Color(0x00FFFFFF)],
                          stops: [0, r.height > lineH ? (r.height - lineH) / r.height : 0, 1],
                        ).createShader(r),
                        child: text,
                      );
                return Align(alignment: Alignment.topLeft, child: body);
              }),
            ),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(
                child: Text('— ${d.$2}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(12.5, color: AppColors.muted)),
              ),
              const SizedBox(width: 8),
              _MorePill(onTap: () => _more(context, title, d)),
            ]),
          ]),
        );
      },
    );
  }
}

/// Katıldığın bir hatim bittiyse ve duasını henüz okumadıysan: "Hatim bitti, duanı oku".
class _FinishedHatims extends StatelessWidget {
  const _FinishedHatims({required this.me});
  final AppUser me;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<HatimGroup>>(
      stream: HatimService.myGroups(me.id),
      builder: (context, snap) {
        final pending = (snap.data ?? const <HatimGroup>[]).where((g) => me.duaPending(g)).toList();
        if (pending.isEmpty) return const SizedBox.shrink();
        return Column(children: [
          for (final g in pending) ...[
            OrnateCard(
              highlight: true,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  const AppLogo(size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(lt('HATİM BİTTİ'), style: AppText.label()),
                      const SizedBox(height: 2),
                      Text(lt('"{0}" hatmi tamamlandı', [g.name]), style: AppText.display(19)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 12),
                GoldButton(
                  label: lt('Duanızı okuyun'),
                  icon: Icons.auto_awesome,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DuaScreen(groupName: g.name, groupId: g.id, hatimCount: g.hatimCount, uid: me.id),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 10),
          ],
        ]);
      },
    );
  }
}


/// Ayın en çok cüz okuyan kardeşi.
class _TopReaderCard extends StatelessWidget {
  const _TopReaderCard({required this.me});
  final AppUser me;

  @override
  Widget build(BuildContext context) {
    final key = HatimService.monthKey();
    return StreamBuilder<AppUser?>(
      stream: HatimService.topReaderOfMonth(),
      builder: (context, snap) {
        final top = snap.data;
        final count = top?.readsIn(key) ?? 0;
        return OrnateCard(
          highlight: true,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TopReadersScreen(me: me))),
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [AppColors.goldLight, AppColors.gold]),
                border: Border.all(color: AppColors.goldLight),
              ),
              child: const Center(child: CrownIcon(size: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(lt('AYIN EN ÇOK OKUYANI'), style: AppText.label(size: 11)),
                const SizedBox(height: 2),
                if (top == null || count == 0)
                  Text(lt('Bu ay henüz okunan cüz yok. İlk siz olun!'), style: AppText.body(14))
                else
                  Text(top.id == me.id ? lt('{0} (siz)', [top.name]) : top.name,
                      overflow: TextOverflow.ellipsis, style: AppText.display(18)),
              ]),
            ),
            if (top != null && count > 0)
              Column(children: [
                Text('$count', style: AppText.number(22, color: AppColors.goldLight)),
                Text(lt('cüz'), style: AppText.body(11, color: AppColors.muted)),
              ]),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, color: AppColors.gold),
          ]),
        );
      },
    );
  }
}
