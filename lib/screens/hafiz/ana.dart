import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../hafiz/hoca_service.dart';
import '../../hafiz/kayit.dart';
import '../../hafiz/kuran.dart';
import '../../hafiz/odev_ses.dart';
import '../../hafiz/ses.dart';
import '../../hafiz/yedek.dart';
import '../../l10n/l10n.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/social_service.dart';
import '../../services/support_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/guest.dart';
import '../../widgets/ornaments.dart';
import '../../widgets/prayer_card.dart';
import '../../widgets/sekme_geri.dart';
import '../admin_screen.dart';
import '../audio_quran_screen.dart';
import '../friends_screen.dart';
import '../profile_screen.dart';
import '../qibla_screen.dart';
import '../settings_screen.dart';
import '../support_screen.dart';
import 'bul.dart';
import 'canli.dart';
import 'dinle.dart';
import 'hoca.dart';
import 'ilerleme.dart';
import 'oku.dart';
import 'ortak.dart';
import 'sec.dart';

/// Hafız Kardeşim ana iskeleti: Ana Sayfa, Hoca–Öğrenci, ortada Dinlet, Arkadaşlar, Daha fazla.
/// Telefonun geri hareketi her zaman bir adım geri gider; alt sekmedeyken önce Ana Sayfa'ya döner.
class HafizAna extends StatefulWidget {
  const HafizAna({super.key, required this.me});
  final AppUser me;
  @override
  State<HafizAna> createState() => _HafizAnaState();
}

class _HafizAnaState extends State<HafizAna> {
  int _tab = 0;
  bool _hazir = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void didUpdateWidget(HafizAna old) {
    super.didUpdateWidget(old);
    if (old.me.id != widget.me.id) _yukle();
  }

  /// Açılış takılırsa (bir adım bitmezse ya da hata verirse) sonsuz dönen çark yerine
  /// hangi adımda kaldığı ve "Tekrar dene" gösterilir.
  String? _yukHata;

  Future<void> _yukle() async {
    if (mounted && _yukHata != null) setState(() => _yukHata = null);
    var adim = 'Kur\'an metni';
    try {
      await Kuran.yukle().timeout(const Duration(seconds: 25));
      adim = 'çalışma geçmişi';
      await Kayit.i.ac(widget.me.id).timeout(const Duration(seconds: 25));
      if (mounted) setState(() => _hazir = true);
    } catch (e) {
      debugPrint('HafizAna açılış ($adim): $e');
      if (mounted) setState(() => _yukHata = '$adim yüklenemedi: ${e is TimeoutException ? 'zaman aşımı' : e}');
    }
  }

  void _ac(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));

  void _ezber(String mod) => _ac(SecEkrani(
        baslik: mod == 'kardes' ? 'Kardeşime Dinlet' : 'Ezber Oku',
        onSec: (c, l) => Navigator.push(c, MaterialPageRoute(builder: (_) => OkuEkrani(ayetler: l, mod: mod))),
      ));

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    if (!_hazir) {
      final h = _yukHata;
      return Scaffold(
        backgroundColor: AppColors.inkDeep,
        body: PatternBackground(
          child: h == null
              ? const LoadingView()
              : SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(h, textAlign: TextAlign.center, style: AppText.body(14, color: AppColors.muted)),
                        const SizedBox(height: 16),
                        GoldButton(label: 'Tekrar dene', icon: Icons.refresh, onPressed: _yukle),
                      ]),
                    ),
                  ),
                ),
        ),
      );
    }
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _tab = 0);
      },
      child: StreamBuilder<List<Bag>>(
        stream: me.isGuest ? const Stream.empty() : HocaService.baglarim(me.id),
        builder: (context, bagSnap) => StreamBuilder<List<FriendRequest>>(
          stream: me.isGuest ? const Stream.empty() : SocialService.incomingRequests(me.id),
          builder: (context, reqSnap) => StreamBuilder<List<SupportThread>>(
            stream: SupportService.myThreads(me.id),
            builder: (context, supSnap) {
              final baglar = bagSnap.data ?? const <Bag>[];
              final bagIstek = baglar.where((b) => b.durum == 'bekliyor' && b.isteyen != me.id).length;
              final destek = (supSnap.data ?? const <SupportThread>[]).where((t) => t.unreadForUser).length;
              return Scaffold(
                body: IndexedStack(index: _tab, children: [
                  _AnaSekme(me: me, baglar: baglar, bagIstek: bagIstek, ac: _ac, ezber: _ezber, sekme: (i) => setState(() => _tab = i)),
                  SekmeGeri(
                      anaya: () => setState(() => _tab = 0),
                      child: me.isGuest ? GuestOnlyView(title: 'Hoca – Öğrenci') : HocaEkrani(me: me)),
                  SekmeGeri(
                      anaya: () => setState(() => _tab = 0),
                      child: me.isGuest ? GuestOnlyView(title: lt('Arkadaşlar')) : FriendsScreen(me: me)),
                  SekmeGeri(anaya: () => setState(() => _tab = 0), child: _DahaSekme(me: me, ac: _ac, destek: destek)),
                ]),
                bottomNavigationBar: _AltCubuk(
                  index: _tab,
                  rozet: {1: bagIstek, 2: reqSnap.data?.length ?? 0, 3: destek},
                  onTab: (i) => setState(() => _tab = i),
                  onDinlet: () => _ezber('ses'),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AnaSekme extends StatelessWidget {
  const _AnaSekme({required this.me, required this.baglar, required this.bagIstek, required this.ac, required this.ezber, required this.sekme});
  final AppUser me;
  final List<Bag> baglar;
  final int bagIstek;
  final void Function(Widget) ac;
  final void Function(String) ezber;
  final ValueChanged<int> sekme;

  void _hocama(BuildContext context) {
    if (me.isGuest) {
      showSnack(context, 'Hocaya dinletmek için üye girişi gerekir.');
      return;
    }
    final hocalar = baglar.where((b) => b.durum == 'kabul' && b.ogrenci == me.id).toList();
    if (hocalar.isEmpty) {
      showSnack(context, 'Önce bir hoca ekle: Hoca – Öğrenci sekmesinde + düğmesi.');
      sekme(1);
      return;
    }
    void sec(Bag b) => ac(SecEkrani(
          baslik: 'Hocama dinlet · ${b.karsiAd(me.id)}',
          dugme: 'Hocama davet gönder',
          onSec: (c, l) async {
            try {
              final id = await HocaService.canliBaslat(me, b, l, HfAyar.gizle);
              if (c.mounted) Navigator.pushReplacement(c, MaterialPageRoute(builder: (_) => CanliEkrani(id: id, me: me)));
            } catch (e) {
              if (c.mounted) showSnack(c, errorText(e));
            }
          },
        ));
    if (hocalar.length == 1) {
      sec(hocalar.first);
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.ink,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.all(16), child: Text('Hangi hocana?', style: AppText.display(20))),
          for (final b in hocalar)
            ListTile(
              leading: const Icon(Icons.school_outlined),
              title: Text(b.karsiAd(me.id)),
              onTap: () {
                Navigator.pop(c);
                sec(b);
              },
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Kayit.i,
      builder: (context, _) {
        final k = Kayit.i;
        final hedef = Kayit.hedef;
        final bugun = k.bugunAyet;
        final tekrar = k.tekrarListesi;
        final son = k.gecmis.where((o) => o.tur == 'ses' || o.tur == 'kardes').firstOrNull;
        final odevler = baglar.where((b) => b.durum == 'kabul' && b.ogrenci == me.id && b.odev != null).toList();
        final tiles = <(IconData, String, String, VoidCallback)>[
          (Icons.mic_rounded, 'Ezber Oku', 'Uygulama dinler', () => ezber('ses')),
          (Icons.handshake_outlined, 'Kardeşime Dinlet', 'Yanındaki işaretler', () => ezber('kardes')),
          (Icons.record_voice_over_outlined, 'Hocama Dinlet', 'Uzaktan, canlı', () => _hocama(context)),
          (Icons.headphones_rounded, 'Dinle & Tekrarla', 'Ayet ayet', () => ac(SecEkrani(
                baslik: 'Dinle & Tekrarla',
                gizlemeSor: false,
                dugme: 'Dinlemeye başla',
                onSec: (c, l) => Navigator.push(c, MaterialPageRoute(builder: (_) => DinleEkrani(ayetler: l))),
              ))),
          (Icons.manage_search_rounded, 'Sesle Bul', 'Oku, ayeti bulsun', () => ac(const BulEkrani())),
          (Icons.menu_book_rounded, 'Hata Defteri', '${k.hatalar.length} kayıt', () => ac(const HatalarEkrani())),
          (Icons.insights_rounded, 'İlerlemem', 'Seri, cüz haritası', () => ac(const IlerlemeEkrani())),
          (Icons.history_rounded, 'Ders Geçmişim', '${k.gecmis.length} ders', () => ac(const GecmisEkrani())),
        ];
        return PatternBackground(
          child: SafeArea(
            bottom: false,
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
              Row(children: [
                const AppLogo(size: 44, glow: .4),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Esselâmü aleyküm,', style: AppText.body(13, color: AppColors.muted)),
                    Text(me.firstName, overflow: TextOverflow.ellipsis, style: AppText.display(26)),
                    Text(formatToday(DateTime.now()), style: AppText.body(12, color: AppColors.gold)),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              CanliDavetler(me: me),
              if (bagIstek > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: OrnateCard(
                    highlight: true,
                    onTap: () => sekme(1),
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Icon(Icons.how_to_reg_outlined, color: AppColors.goldLight),
                      const SizedBox(width: 10),
                      Expanded(child: Text('$bagIstek yeni hoca/öğrenci isteği var', style: AppText.body(15, weight: FontWeight.w700))),
                      Icon(Icons.chevron_right, color: AppColors.muted),
                    ]),
                  ),
                ),
              OrnateCard(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  SizedBox(
                    width: 84,
                    height: 84,
                    child: CustomPaint(
                      painter: _Halka(math.min(1, bugun / hedef)),
                      child: Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text('$bugun', style: AppText.number(22)),
                          Text('/ $hedef ayet', style: AppText.body(10.5, color: AppColors.muted, height: 1)),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SayiKutu('🔥 ${k.seri}', 'gün seri'),
                  const SizedBox(width: 6),
                  SayiKutu('${k.ezberSayisi}', 'ezber ayet'),
                  const SizedBox(width: 6),
                  SayiKutu('${tekrar.length}', 'tekrar'),
                ]),
              ),
              const SizedBox(height: 10),
              if (tekrar.isNotEmpty) ...[
                _genis(Icons.replay_circle_filled_outlined, 'Bugünün tekrarı · ${tekrar.length} ayet', Kuran.etiketListe(tekrar),
                    () => ac(OkuEkrani(ayetler: tekrar.take(60).toList(), mod: 'ses')), vurgu: true),
                const SizedBox(height: 10),
              ],
              for (final b in odevler) ...[
                _genis(Icons.assignment_outlined, 'Ödev · ${b.karsiAd(me.id)}', '${b.odev!['etiket'] ?? ''}', () => sekme(1)),
                const SizedBox(height: 10),
              ],
              // Hoca: öğrencisi ödevini bitirdi, okuma sesi dinlenmeyi bekliyor.
              if (!me.isGuest)
                StreamBuilder<List<Teslim>>(
                  stream: OdevSes.yeniTeslimler(me.id),
                  builder: (context, s) => Column(children: [
                    for (final t in s.data ?? const <Teslim>[]) ...[
                      _genis(Icons.task_alt, '📥 ${baglar.where((b) => b.id == t.id).firstOrNull?.karsiAd(me.id) ?? 'Öğrencin'} ödevini bitirdi',
                          '${t.etiket} · %${t.puan} · okuma sesini dinle', () => sekme(1), vurgu: true),
                      const SizedBox(height: 10),
                    ],
                  ]),
                ),
              if (son != null) ...[
                _genis(Icons.play_arrow_rounded, 'Devam et', '${son.etiket} · ${son.turAdi}',
                    () => ac(OkuEkrani(ayetler: son.ayetler, mod: son.tur == 'kardes' ? 'kardes' : 'ses'))),
                const SizedBox(height: 10),
              ],
              if (k.bos && DriveYedek.destek) ...[
                const _GeriYukleKarti(),
                const SizedBox(height: 10),
              ],
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.75,
                children: [
                  for (var i = 0; i < tiles.length; i++)
                    Material(
                      color: i < 3 ? AppColors.gold.withValues(alpha: .14) : AppColors.inkDeep.withValues(alpha: .45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: AppColors.gold.withValues(alpha: i < 3 ? .6 : .35)),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: tiles[i].$4,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(tiles[i].$1, color: AppColors.goldLight, size: 26),
                            const SizedBox(height: 6),
                            Text(tiles[i].$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(15, weight: FontWeight.w700, height: 1.1)),
                            Text(tiles[i].$3, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(12, color: AppColors.muted)),
                          ]),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const PrayerCard(),
            ]),
          ),
        );
      },
    );
  }

  Widget _genis(IconData ic, String t, String alt, VoidCallback f, {bool vurgu = false}) => OrnateCard(
        highlight: vurgu,
        onTap: f,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Icon(ic, color: AppColors.goldLight, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t, style: AppText.body(15, weight: FontWeight.w700)),
              Text(alt, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(12.5, color: AppColors.muted)),
            ]),
          ),
          Icon(Icons.chevron_right, color: AppColors.muted),
        ]),
      );
}

class _Halka extends CustomPainter {
  _Halka(this.p);
  final double p;
  @override
  void paint(Canvas c, Size s) {
    final r = Rect.fromLTWH(5, 5, s.width - 10, s.height - 10);
    c.drawArc(r, 0, math.pi * 2, false, Paint()
      ..color = AppColors.inkLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8);
    c.drawArc(r, -math.pi / 2, math.pi * 2 * p, false, Paint()
      ..color = p >= 1 ? AppColors.gold : AppColors.done
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8);
  }

  @override
  bool shouldRepaint(_Halka o) => o.p != p;
}

/// Yeni telefonda / yeniden kurulumda Google Drive'daki yedeği geri yükleme.
class _GeriYukleKarti extends StatefulWidget {
  const _GeriYukleKarti();
  @override
  State<_GeriYukleKarti> createState() => _GeriYukleKartiState();
}

class _GeriYukleKartiState extends State<_GeriYukleKarti> {
  bool _mesgul = false;
  @override
  Widget build(BuildContext context) {
    return OrnateCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Ders geçmişin başka telefonda mı kaldı?', style: AppText.body(15, weight: FontWeight.w700)),
        Text('Daha önce Google Drive\'a yedeklediysen aynı Google hesabıyla geri yükleyebilirsin.',
            style: AppText.body(13, color: AppColors.muted)),
        const SizedBox(height: 10),
        GoldButton(
          label: 'Drive\'dan geri yükle',
          icon: Icons.cloud_download_outlined,
          outlined: true,
          busy: _mesgul,
          onPressed: () async {
            setState(() => _mesgul = true);
            try {
              final m = await DriveYedek.oku();
              if (!context.mounted) return;
              if (m == null) {
                showSnack(context, 'Bu Google hesabında yedek bulunamadı.');
              } else {
                await Kayit.i.yedektenAl(m);
                if (context.mounted) showSnack(context, 'Ders geçmişin geri yüklendi');
              }
            } catch (e) {
              if (context.mounted) showSnack(context, errorText(e));
            } finally {
              if (mounted) setState(() => _mesgul = false);
            }
          },
        ),
      ]),
    );
  }
}

class _DahaSekme extends StatelessWidget {
  const _DahaSekme({required this.me, required this.ac, required this.destek});
  final AppUser me;
  final void Function(Widget) ac;
  final int destek;

  @override
  Widget build(BuildContext context) {
    if (!AuthService.isAdmin) return _icerik(context, 0);
    // Yönetici: yeni suistimal bildirimleri "Yönetim" satırında kırmızı sayı olarak görünür.
    return StreamBuilder<List<SupportThread>>(
      stream: SupportService.allThreads(),
      builder: (context, s) => _icerik(context, (s.data ?? const <SupportThread>[]).where((t) => suistimalMi(t) && t.unreadForAdmin).length),
    );
  }

  Widget _icerik(BuildContext context, int yonetim) {
    // Konulara göre gruplanmış sade liste. Kaynakça, Destek ve İletişim sayfasının en altında.
    final gruplar = <(String, List<(IconData, String, VoidCallback, int)>)>[
      ('HESABIM', [
        if (!me.isGuest) (Icons.person_outline, 'Profilim', () => ac(ProfileScreen(me: me)), 0),
        (Icons.cloud_outlined, 'Yedekleme', () => ac(const YedekEkrani()), 0),
      ]),
      ('AYARLAR', [
        (Icons.tune, 'Ezber ayarları (yazı tipi, gizleme)', () => ac(const HafizAyarEkrani()), 0),
        (Icons.settings_outlined, 'Uygulama ayarları (tema, dil, ezan)', () => ac(const SettingsScreen()), 0),
      ]),
      ('KUR\'AN VE NAMAZ', [
        (Icons.headphones_outlined, 'Sesli Kur\'an (sure sure, mealli)', () => ac(const AudioQuranScreen()), 0),
        (Icons.explore_outlined, 'Kıble pusulası', () => ac(const QiblaScreen()), 0),
      ]),
      ('YARDIM', [
        (Icons.help_outline, 'Nasıl kullanılır', () => ac(const YardimEkrani()), 0),
        (Icons.volunteer_activism_outlined, 'Destek ve İletişim', () => ac(SupportScreen(me: me)), destek),
        if (AuthService.isAdmin) (Icons.admin_panel_settings_outlined, 'Yönetim', () => ac(AdminScreen(me: me)), yonetim),
      ]),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Daha fazla'), automaticallyImplyLeading: false, leading: SekmeGeri.dugme(context)),
      body: PatternBackground(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
          for (final g in gruplar)
            if (g.$2.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                child: Text(g.$1, style: AppText.label(color: AppColors.muted)),
              ),
              OrnateCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(children: [
                  for (var k = 0; k < g.$2.length; k++) ...[
                    if (k > 0) Divider(height: 1, indent: 52, color: AppColors.inkLine),
                    _satir(g.$2[k]),
                  ],
                ]),
              ),
            ],
          const SizedBox(height: 18),
          TextButton.icon(
            onPressed: () => confirmLogout(context),
            icon: Icon(Icons.logout, color: AppColors.muted),
            label: Text(me.isGuest ? 'Üye ol / giriş yap' : 'Çıkış yap', style: AppText.body(14, color: AppColors.muted)),
          ),
        ]),
      ),
    );
  }

  Widget _satir((IconData, String, VoidCallback, int) i) => InkWell(
        onTap: i.$3,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(children: [
            Icon(i.$1, color: AppColors.goldLight, size: 22),
            const SizedBox(width: 14),
            Expanded(child: Text(i.$2, style: AppText.body(15, weight: FontWeight.w600))),
            if (i.$4 > 0) _Rozet(i.$4),
            Icon(Icons.chevron_right, color: AppColors.muted),
          ]),
        ),
      );
}

class _Rozet extends StatelessWidget {
  const _Rozet(this.n);
  final int n;
  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 18),
        height: 18,
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(9)),
        alignment: Alignment.center,
        child: Text('$n', style: AppText.body(11, color: AppColors.inkDeep, weight: FontWeight.w700, height: 1)),
      );
}

class _AltCubuk extends StatelessWidget {
  const _AltCubuk({required this.index, required this.rozet, required this.onTab, required this.onDinlet});
  final int index;
  final Map<int, int> rozet;
  final ValueChanged<int> onTab;
  final VoidCallback onDinlet;

  @override
  Widget build(BuildContext context) {
    Widget tab(int i, IconData icon, IconData on, String label) {
      final secili = index == i;
      final c = secili ? AppColors.gold : AppColors.muted;
      final b = rozet[i] ?? 0;
      return Expanded(
        child: InkWell(
          onTap: () => onTab(i),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Stack(clipBehavior: Clip.none, children: [
              Icon(secili ? on : icon, color: c, size: 24),
              if (b > 0) Positioned(right: -12, top: -6, child: _Rozet(b)),
            ]),
            const SizedBox(height: 3),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(10.5, color: c, weight: FontWeight.w600, height: 1.1)),
          ]),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.inkDeep.withValues(alpha: .97),
        border: Border(top: BorderSide(color: AppColors.gold.withValues(alpha: .25))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(children: [
            tab(0, Icons.home_outlined, Icons.home_rounded, 'Ana Sayfa'),
            tab(1, Icons.school_outlined, Icons.school, 'Hoca–Öğrenci'),
            Expanded(
              child: GestureDetector(
                onTap: onDinlet,
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Transform.translate(
                    offset: const Offset(0, -10),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [AppColors.goldLight, AppColors.gold]),
                        boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: .35), blurRadius: 14, offset: const Offset(0, 4))],
                      ),
                      child: Icon(Icons.mic_rounded, color: AppColors.isLight ? const Color(0xFFFFF8E8) : AppColors.inkDeep, size: 28),
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -6),
                    child: Text('Dinlet', style: AppText.body(10.5, color: AppColors.goldLight, weight: FontWeight.w700, height: 1.1)),
                  ),
                ]),
              ),
            ),
            tab(2, Icons.people_alt_outlined, Icons.people_alt_rounded, 'Arkadaşlar'),
            tab(3, Icons.menu_rounded, Icons.menu_open_rounded, 'Daha fazla'),
          ]),
        ),
      ),
    );
  }
}

/// Ezbere özel ayarlar.
class HafizAyarEkrani extends StatefulWidget {
  const HafizAyarEkrani({super.key});
  @override
  State<HafizAyarEkrani> createState() => _HafizAyarEkraniState();
}

class _HafizAyarEkraniState extends State<HafizAyarEkrani> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ezber ayarları')),
      body: PatternBackground(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
          OrnateCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Günlük hedef'),
                trailing: DropdownButton<int>(
                  value: Kayit.hedef,
                  underline: const SizedBox(),
                  items: [for (final n in const [3, 5, 10, 15, 20, 30, 50]) DropdownMenuItem(value: n, child: Text('$n ayet'))],
                  onChanged: (v) async {
                    if (v == null) return;
                    await Kayit.setHedef(v);
                    Kayit.i.yenile();
                    setState(() {});
                  },
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Arapça yazı boyu'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                      onPressed: () async {
                        await HfAyar.setYazi(HfAyar.yazi - 2);
                        setState(() {});
                      },
                      icon: const Icon(Icons.text_decrease)),
                  Text('${HfAyar.yazi.round()}'),
                  IconButton(
                      onPressed: () async {
                        await HfAyar.setYazi(HfAyar.yazi + 2);
                        setState(() {});
                      },
                      icon: const Icon(Icons.text_increase)),
                ]),
              ),
              Text(Kuran.hazir ? Kuran.a[0].metin : '', textDirection: TextDirection.rtl, style: arapYazi(HfAyar.yazi)),
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerLeft, child: Text('AYET YAZI TİPİ', style: AppText.label())),
              const SizedBox(height: 6),
              YaziTipiSecici(onChanged: () => setState(() {})),
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: Text('VARSAYILAN GİZLEME', style: AppText.label())),
              const SizedBox(height: 6),
              const GizlemeSecici(),
              const BeyazSayfaAnahtari(),
              const MushafSayfaAnahtari(),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: HfAyar.besmele,
                onChanged: (v) async {
                  await HfAyar.setBesmele(v);
                  setState(() {});
                },
                title: const Text('Sure başında besmele göster'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: HfAyar.meal,
                onChanged: (v) async {
                  await HfAyar.setMeal(v);
                  setState(() {});
                },
                title: const Text('Dinlerken Türkçe meal'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ses tanıma lehçesi'),
                trailing: DropdownButton<String>(
                  value: Ses.dil,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'ar_SA', child: Text('Arapça (Suudi)')),
                    DropdownMenuItem(value: 'ar_EG', child: Text('Arapça (Mısır)')),
                    DropdownMenuItem(value: 'ar_AE', child: Text('Arapça (BAE)')),
                    DropdownMenuItem(value: 'ar_JO', child: Text('Arapça (Ürdün)')),
                  ],
                  onChanged: (v) async {
                    if (v == null) return;
                    await Ses.setDil(v);
                    setState(() {});
                  },
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Yedekleme: geçmiş telefonda durur; Google Drive (Android) / iCloud (iPhone) yedeği.
class YedekEkrani extends StatefulWidget {
  const YedekEkrani({super.key});
  @override
  State<YedekEkrani> createState() => _YedekEkraniState();
}

class _YedekEkraniState extends State<YedekEkrani> {
  bool _mesgul = false;

  Future<void> _is(Future<void> Function() f) async {
    setState(() => _mesgul = true);
    try {
      await f();
    } catch (e) {
      if (mounted) showSnack(context, errorText(e));
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final son = DriveYedek.sonYedek;
    final google = FirebaseAuth.instance.currentUser?.providerData.any((p) => p.providerId == 'google.com') ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Yedekleme')),
      body: PatternBackground(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
          OrnateCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ders geçmişin nerede?', style: AppText.display(20)),
              const SizedBox(height: 6),
              Text(
                'Bütün ders çalışmaların, ezber durumun ve hata defterin yalnızca bu telefonda, '
                'senin hesabına ait bir dosyada durur. Hafız Kardeşim bunları kendi sunucusunda saklamaz.\n\n'
                '• Telefonun kendi yedeği (Android: Google Drive yedeği, iPhone: iCloud yedeği) bu dosyayı da yedekler.\n'
                '• Aşağıdan ayrıca kendi Google Drive\'ına yedekleyebilirsin; yeni telefonda aynı hesapla girince geri yüklersin.',
                style: AppText.body(14, color: AppColors.muted),
              ),
              const SizedBox(height: 8),
              Text('${Kayit.i.gecmis.length} ders · ${Kayit.i.ay.length} ayet kaydı', style: AppText.body(13, color: AppColors.goldLight)),
            ]),
          ),
          const SizedBox(height: 12),
          if (DriveYedek.destek)
            OrnateCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('GOOGLE DRIVE', style: AppText.label()),
                const SizedBox(height: 6),
                Text(
                  DriveYedek.hesap == null
                      ? 'Henüz bağlanmadı.${google ? '' : ' (Google hesabını ilk yedeklemede seçeceksin.)'}'
                      : 'Hesap: ${DriveYedek.hesap}\nSon yedek: ${son == 0 ? '—' : formatDateTime(DateTime.fromMillisecondsSinceEpoch(son))}',
                  style: AppText.body(14),
                ),
                const SizedBox(height: 10),
                GoldButton(
                  label: 'Şimdi yedekle',
                  icon: Icons.cloud_upload_outlined,
                  busy: _mesgul,
                  onPressed: () => _is(() async {
                    final ok = await DriveYedek.yedekle();
                    if (mounted) showSnack(context, ok ? 'Google Drive\'a yedeklendi' : 'Yedekleme yapılmadı');
                  }),
                ),
                const SizedBox(height: 10),
                GoldButton(
                  label: 'Drive\'dan geri yükle',
                  icon: Icons.cloud_download_outlined,
                  outlined: true,
                  busy: _mesgul,
                  onPressed: () => _is(() async {
                    final m = await DriveYedek.oku();
                    if (!mounted) return;
                    if (m == null) {
                      showSnack(context, 'Bu Google hesabında yedek bulunamadı.');
                      return;
                    }
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Geri yüklensin mi?'),
                        content: Text('Yedekteki ${(m['gecmis'] as List?)?.length ?? 0} ders bu telefondakinin yerine konacak.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
                          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Geri yükle')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await Kayit.i.yedektenAl(m);
                      if (mounted) showSnack(context, 'Geri yüklendi');
                    }
                  }),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: DriveYedek.otomatik,
                  onChanged: (v) async {
                    await DriveYedek.setOtomatik(v);
                    setState(() {});
                  },
                  title: const Text('Her dersten sonra kendiliğinden yedekle'),
                ),
              ]),
            )
          else
            OrnateCard(
              child: Text(
                'iPhone\'da ders geçmişin telefonun iCloud yedeğiyle korunur (Ayarlar › Adın › iCloud › iCloud Yedekleme açık olmalı). '
                'Yeni iPhone\'u bu yedekten kurunca geçmişin geri gelir.',
                style: AppText.body(14),
              ),
            ),
        ]),
      ),
    );
  }
}

class YardimEkrani extends StatelessWidget {
  const YardimEkrani({super.key});
  @override
  Widget build(BuildContext context) {
    final b = <(String, String)>[
      ('🎙️ Ezber Oku', 'Sure, cüz ya da sayfa seç. Ayetler gizli gelir. Mikrofona dokun ve ezberden oku: doğru okuduğun kelimeler açılır, yanlışlar kırmızı, atladıkların turuncu olur. Takılırsan İpucu ile sıradaki kelimeyi gör. Tanıma bir kelimeyi kaçırırsa "Doğru say"a bas. Açılmış bir kelimeye dokunarak düzeltebilirsin.'),
      ('🤝 Kardeşime Dinlet', 'Telefonu yanındaki arkadaşın tutar, sen ezberden okursun; o her kelimede Doğru ya da Hata\'ya basar. İnternet ve mikrofon gerekmez.'),
      ('🎓 Hocama Dinlet', 'Hoca – Öğrenci sekmesinde hocanı ekle (arkadaş listenden ya da 6 haneli kodla). Hocana "Hoca olarak kabul ediyor musun?" diye sorulur. Kabul edince hocana canlı ders daveti gönderebilirsin: sen kendi telefonunda gizli ayetlerle okursun, hocan kendi telefonunda metni açık görür ve işaretler. Sesi duymak için birbirinizi telefonla ya da WhatsApp\'tan arayın. Eşleşme yalnızca hanım–hanım ya da bey–bey olur. Uygunsuz bir durum olursa kişinin menüsünden ya da canlı derste bayrak simgesinden “Suistimal bildir”e dokun.'),
      ('👨‍🏫 Hocaysan', 'Öğrencilerini ekle, "Canlı dinle" ile derse çağır, ödev ver, not yaz. Her ders iki tarafın ders geçmişine kaydedilir.'),
      ('🔁 Tekrar takvimi', 'İyi okuduğun ayetler 1, 3, 7, 14, 30, 60 gün arayla tekrar karşına çıkar; zorlandıkların ertesi gün gelir. Ana sayfadaki "Bugünün tekrarı" bunları toplar.'),
      ('🎧 Dinle & Tekrarla', 'Kâri seç, her ayeti istediğin kadar tekrarlat. "Ardından ben tekrar edeyim" açıksa her ayetten sonra senin okuman için bekler.'),
      ('☁️ Geçmiş ve yedek', 'Bütün dersler telefonunda ve kendi Google Drive / iCloud yedeğinde durur. Aynı hesapla girince uygulama seni tanır ve geçmişini gösterir.'),
      ('💡 İpucu', 'Sesli tanıma için Android\'de Google uygulaması ve internet gerekir. Tane tane, net okumak tanımayı iyileştirir.'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Nasıl kullanılır')),
      body: PatternBackground(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
          for (final x in b) ...[
            OrnateCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(x.$1, style: AppText.body(16, weight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(x.$2, style: AppText.body(14, color: AppColors.muted)),
              ]),
            ),
            const SizedBox(height: 10),
          ],
        ]),
      ),
    );
  }
}
