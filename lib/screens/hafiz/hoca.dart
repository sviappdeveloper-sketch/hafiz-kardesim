import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../hafiz/hoca_service.dart';
import '../../hafiz/kuran.dart';
import '../../models/models.dart';
import '../../services/social_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/ornaments.dart';
import 'bildir.dart';
import 'canli.dart';
import 'ilerleme.dart';
import 'oku.dart';
import 'sec.dart';

/// Hoca–öğrenci çalışma alanı: istekler, hocalarım, öğrencilerim, canlı dinletme, ödevler.
class HocaEkrani extends StatelessWidget {
  const HocaEkrani({super.key, required this.me, this.sekmeli = true});
  final AppUser me;
  final bool sekmeli;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hoca – Öğrenci'),
        automaticallyImplyLeading: !sekmeli,
        actions: [IconButton(onPressed: () => ekleSayfasi(context, me), icon: const Icon(Icons.person_add_alt_1))],
      ),
      body: PatternBackground(
        child: StreamBuilder<List<Bag>>(
          stream: HocaService.baglarim(me.id),
          builder: (context, snap) {
            if (snap.hasError) return Center(child: Text(errorText(snap.error!), style: AppText.body(14)));
            if (!snap.hasData) return const LoadingView();
            final l = snap.data!;
            final gelen = l.where((b) => b.durum == 'bekliyor' && b.isteyen != me.id).toList();
            final giden = l.where((b) => b.durum == 'bekliyor' && b.isteyen == me.id).toList();
            final hocalar = l.where((b) => b.durum == 'kabul' && b.ogrenci == me.id).toList();
            final ogrenciler = l.where((b) => b.durum == 'kabul' && b.hoca == me.id).toList();
            return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
              CanliDavetler(me: me),
              _KodKarti(me: me),
              if (gelen.isNotEmpty) ...[
                const SectionTitle('Gelen istekler'),
                for (final b in gelen) _gelenKart(context, b),
              ],
              const SectionTitle('Hocalarım'),
              if (hocalar.isEmpty)
                _bos('Henüz hocan yok. Sağ üstteki + ile hocana istek gönder ya da hocandan sana istek göndermesini iste.'),
              for (final b in hocalar) _hocaKart(context, b),
              const SectionTitle('Öğrencilerim'),
              if (ogrenciler.isEmpty) _bos('Henüz öğrencin yok. Öğrencine istek gönderebilir ya da kodunu paylaşabilirsin.'),
              for (final b in ogrenciler) _ogrenciKart(context, b),
              if (giden.isNotEmpty) ...[
                const SectionTitle('Gönderdiğim istekler'),
                for (final b in giden)
                  _kart(
                    child: Row(children: [
                      Expanded(
                        child: Text(
                          '${b.karsiAd(me.id)} · ${b.hoca == me.id ? 'öğrencim olması için' : 'hocam olması için'} cevap bekleniyor',
                          style: AppText.body(14),
                        ),
                      ),
                      TextButton(onPressed: () => runGuarded(context, () => HocaService.bagiSil(b)), child: const Text('Geri al')),
                    ]),
                  ),
              ],
            ]);
          },
        ),
      ),
    );
  }

  Widget _bos(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: AppText.body(13, color: AppColors.muted)),
      );

  Widget _kart({required Widget child, bool vurgu = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: OrnateCard(highlight: vurgu, padding: const EdgeInsets.fromLTRB(14, 12, 14, 10), child: child),
      );

  Widget _gelenKart(BuildContext context, Bag b) {
    final ad = b.karsiAd(me.id);
    final soru = b.hoca == me.id
        ? '$ad seni hocası olarak eklemek istiyor.\nHoca olarak kabul ediyor musun?'
        : '$ad seni öğrencisi olarak eklemek istiyor.\nÖğrenci olarak kabul ediyor musun?';
    return _kart(
      vurgu: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(soru, style: AppText.body(15, weight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: GoldButton(
                  label: 'Kabul ediyorum',
                  icon: Icons.check,
                  onPressed: () => runGuarded(context, () => HocaService.cevapla(b, true),
                      success: b.hoca == me.id ? '$ad artık öğrencin' : '$ad artık hocan'))),
          const SizedBox(width: 8),
          Expanded(
              child: GoldButton(
                  label: 'Hayır', outlined: true, onPressed: () => runGuarded(context, () => HocaService.cevapla(b, false)))),
        ]),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => suistimalBildir(context, me, b.karsi(me.id), b.karsiAd(me.id), bag: b),
            icon: Icon(Icons.flag_outlined, size: 18, color: AppColors.muted),
            label: Text('Bildir', style: AppText.body(13, color: AppColors.muted)),
          ),
        ),
      ]),
    );
  }

  Widget _odev(BuildContext context, Bag b, {required bool ogrenciyim}) {
    final o = b.odev;
    if (o == null) return const SizedBox();
    final p = (o['p'] ?? const []) as List;
    final ayetler = [
      for (var i = 0; i + 1 < p.length; i += 2)
        for (var k = p[i] as int; k <= (p[i + 1] as int); k++) k
    ];
    final not = (o['not'] ?? '') as String;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gold.withValues(alpha: .4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('📌 Ödev: ${o['etiket'] ?? ''}', style: AppText.body(14, weight: FontWeight.w700, color: AppColors.goldLight)),
        if (not.isNotEmpty) Text(not, style: AppText.body(13)),
        if (ogrenciyim && ayetler.isNotEmpty)
          Wrap(spacing: 8, children: [
            TextButton.icon(onPressed: () => ezberAc(context, ayetler, 'ses'), icon: const Icon(Icons.mic), label: const Text('Çalış')),
            TextButton.icon(
                onPressed: () => _canliBaslat(context, b, ayetler),
                icon: const Icon(Icons.record_voice_over),
                label: const Text('Hocama dinlet')),
          ]),
        if (!ogrenciyim)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => runGuarded(context, () => HocaService.odevKaldir(b)), child: const Text('Ödevi kaldır')),
          ),
      ]),
    );
  }

  Widget _son(Bag b) {
    final s = b.son;
    if (s == null) return const SizedBox();
    final ts = s['ts'];
    final tarih = ts is Timestamp ? formatDate(ts.toDate()) : '';
    return Text('Son ders: ${s['etiket']} · %${s['puan']} · $tarih', style: AppText.body(12.5, color: AppColors.muted));
  }

  Widget _hocaKart(BuildContext context, Bag b) => _kart(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(Icons.school_outlined, color: AppColors.goldLight),
            const SizedBox(width: 10),
            Expanded(child: Text(b.karsiAd(me.id), style: AppText.body(16, weight: FontWeight.w700))),
            PopupMenuButton<String>(
              onSelected: (v) => _menu(context, b, v),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'gecmis', child: Text('Bu hocayla geçmiş')),
                PopupMenuItem(value: 'sil', child: Text('Bağı kaldır')),
                PopupMenuItem(value: 'bildir', child: Text('Suistimal bildir')),
              ],
            ),
          ]),
          _son(b),
          _odev(context, b, ogrenciyim: true),
          const SizedBox(height: 8),
          GoldButton(
            label: 'Hocama canlı dinlet',
            icon: Icons.record_voice_over,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SecEkrani(
                  baslik: 'Hocama dinlet',
                  dugme: 'Hocama davet gönder',
                  onSec: (c, l) => _canliBaslat(c, b, l, degistir: true),
                ),
              ),
            ),
          ),
        ]),
      );

  Widget _ogrenciKart(BuildContext context, Bag b) => _kart(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(Icons.person_outline, color: AppColors.goldLight),
            const SizedBox(width: 10),
            Expanded(child: Text(b.karsiAd(me.id), style: AppText.body(16, weight: FontWeight.w700))),
            PopupMenuButton<String>(
              onSelected: (v) => _menu(context, b, v),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'odev', child: Text('Ödev ver')),
                PopupMenuItem(value: 'gecmis', child: Text('Bu öğrenciyle geçmiş')),
                PopupMenuItem(value: 'sil', child: Text('Bağı kaldır')),
                PopupMenuItem(value: 'bildir', child: Text('Suistimal bildir')),
              ],
            ),
          ]),
          _son(b),
          _odev(context, b, ogrenciyim: false),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: GoldButton(
                label: 'Canlı dinle',
                icon: Icons.hearing,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SecEkrani(
                      baslik: '${b.karsiAd(me.id)} okusun',
                      dugme: 'Öğrencime davet gönder',
                      onSec: (c, l) => _canliBaslat(c, b, l, degistir: true),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: GoldButton(label: 'Ödev ver', icon: Icons.assignment_outlined, outlined: true, onPressed: () => _menu(context, b, 'odev'))),
          ]),
        ]),
      );

  Future<void> _menu(BuildContext context, Bag b, String v) async {
    if (v == 'bildir') {
      await suistimalBildir(context, me, b.karsi(me.id), b.karsiAd(me.id), bag: b);
    } else if (v == 'gecmis') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => GecmisEkrani(kisiUid: b.karsi(me.id), baslik: b.karsiAd(me.id))));
    } else if (v == 'sil') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('${b.karsiAd(me.id)} ile bağ kaldırılsın mı?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Kaldır')),
          ],
        ),
      );
      if (ok == true && context.mounted) await runGuarded(context, () => HocaService.bagiSil(b));
    } else if (v == 'odev') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SecEkrani(
            baslik: '${b.karsiAd(me.id)} için ödev',
            dugme: 'Ödev olarak ver',
            gizlemeSor: false,
            onSec: (c, l) async {
              final notC = TextEditingController();
              final not = await showDialog<String>(
                context: c,
                builder: (d) => AlertDialog(
                  title: Text('Ödev: ${Kuran.etiketListe(l)}'),
                  content: TextField(controller: notC, maxLines: 3, decoration: const InputDecoration(hintText: 'Not (isteğe bağlı)')),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(d), child: const Text('Vazgeç')),
                    TextButton(onPressed: () => Navigator.pop(d, notC.text.trim()), child: const Text('Gönder')),
                  ],
                ),
              );
              if (not == null || !c.mounted) return;
              final ok = await runGuarded(c, () => HocaService.odevVer(b, l, Kuran.etiketListe(l), not), success: 'Ödev gönderildi');
              if (ok && c.mounted) secimiKapat(c);
            },
          ),
        ),
      );
    }
  }

  Future<void> _canliBaslat(BuildContext context, Bag b, List<int> l, {bool degistir = false}) async {
    try {
      final id = await HocaService.canliBaslat(me, b, l, 'gizli');
      if (!context.mounted) return;
      final r = MaterialPageRoute(builder: (_) => CanliEkrani(id: id, me: me));
      degistir ? Navigator.pushReplacement(context, r) : Navigator.push(context, r);
    } catch (e) {
      if (context.mounted) showSnack(context, errorText(e));
    }
  }
}

/// Kişisel kod kartı.
class _KodKarti extends StatefulWidget {
  const _KodKarti({required this.me});
  final AppUser me;
  @override
  State<_KodKarti> createState() => _KodKartiState();
}

class _KodKartiState extends State<_KodKarti> {
  String? _kod;
  @override
  void initState() {
    super.initState();
    if (!widget.me.isGuest) {
      HocaService.kodum(widget.me).then((k) {
        if (mounted) setState(() => _kod = k);
      }).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.me.isGuest) {
      return Text('Hoca–öğrenci çalışma alanı için üye girişi gerekir.', style: AppText.body(14, color: AppColors.muted));
    }
    return OrnateCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('HAFIZ KARDEŞİM KODUM', style: AppText.label()),
            Text(_kod ?? '……', style: AppText.number(26, color: AppColors.goldLight)),
            Text('Hocan ya da öğrencin bu kodla seni ekleyebilir.', style: AppText.body(12, color: AppColors.muted)),
          ]),
        ),
        IconButton(
          onPressed: _kod == null
              ? null
              : () {
                  Clipboard.setData(ClipboardData(text: _kod!));
                  showSnack(context, 'Kod kopyalandı');
                },
          icon: const Icon(Icons.copy),
        ),
        IconButton(
          onPressed: _kod == null
              ? null
              : () => Share.share('Hafız Kardeşim\'de beni hoca/öğrenci olarak ekle. Kodum: $_kod'),
          icon: const Icon(Icons.share),
        ),
      ]),
    );
  }
}

/// Hoca ya da öğrenci ekleme: arkadaşlardan ya da kodla.
Future<void> ekleSayfasi(BuildContext context, AppUser me) async {
  if (me.isGuest) {
    showSnack(context, 'Bunun için üye girişi gerekir.');
    return;
  }
  final benHocayim = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.ink,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Kimi ekliyorsun?', style: AppText.display(22)),
          const SizedBox(height: 4),
          Text('Hoca–öğrenci eşleşmesi hanım–hanım ya da bey–bey olarak yapılır.', style: AppText.body(12.5, color: AppColors.muted)),
          const SizedBox(height: 14),
          GoldButton(label: 'Hocamı ekle', icon: Icons.school_outlined, onPressed: () => Navigator.pop(c, false)),
          const SizedBox(height: 10),
          GoldButton(label: 'Öğrencimi ekle', icon: Icons.person_outline, outlined: true, onPressed: () => Navigator.pop(c, true)),
        ]),
      ),
    ),
  );
  if (benHocayim == null || !context.mounted) return;
  await Navigator.push(context, MaterialPageRoute(builder: (_) => _KisiSec(me: me, benHocayim: benHocayim)));
}

class _KisiSec extends StatefulWidget {
  const _KisiSec({required this.me, required this.benHocayim});
  final AppUser me;
  final bool benHocayim;
  @override
  State<_KisiSec> createState() => _KisiSecState();
}

class _KisiSecState extends State<_KisiSec> {
  final _kod = TextEditingController();
  bool _mesgul = false;

  Future<void> _gonder(String uid, String ad) async {
    final soru = widget.benHocayim ? '$ad öğrencin olsun mu?' : '$ad hocan olsun mu?';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(soru),
        content: Text(widget.benHocayim
            ? '$ad\'a "Öğrenci olarak kabul ediyor musun?" diye sorulacak.'
            : '$ad\'a "Hoca olarak kabul ediyor musun?" diye sorulacak.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('İstek gönder')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final g = await runGuarded(context, () => HocaService.istekGonder(widget.me, uid, ad, benHocayim: widget.benHocayim),
        success: 'İstek gönderildi');
    if (g && mounted) Navigator.pop(context);
  }

  Future<void> _kodla() async {
    final k = _kod.text.trim();
    if (k.length != 6) {
      showSnack(context, 'Kod 6 haneli olmalı');
      return;
    }
    setState(() => _mesgul = true);
    try {
      final r = await HocaService.koddanBul(k);
      if (!mounted) return;
      if (r == null) {
        showSnack(context, 'Bu koda ait üye bulunamadı');
      } else {
        await _gonder(r.$1, r.$2);
      }
    } catch (e) {
      if (mounted) showSnack(context, errorText(e));
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.benHocayim ? 'Öğrencimi ekle' : 'Hocamı ekle')),
      body: PatternBackground(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
          OrnateCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('KOD İLE', style: AppText.label()),
              const SizedBox(height: 6),
              TextField(
                controller: _kod,
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                decoration: const InputDecoration(hintText: '6 haneli Hafız Kardeşim kodu', counterText: ''),
              ),
              const SizedBox(height: 10),
              GoldButton(label: 'Bul ve istek gönder', icon: Icons.search, busy: _mesgul, onPressed: _kodla),
            ]),
          ),
          const SectionTitle('Arkadaşlarımdan seç'),
          StreamBuilder<List<Friend>>(
            stream: SocialService.friends(widget.me.id),
            builder: (context, s) {
              if (!s.hasData) return const LoadingView();
              if (s.data!.isEmpty) {
                return Text('Arkadaş listen boş. Kodla ekleyebilirsin.', style: AppText.body(13, color: AppColors.muted));
              }
              return Column(children: [
                for (final f in s.data!)
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(f.name, style: AppText.body(15)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _gonder(f.uid, f.name),
                  ),
              ]);
            },
          ),
        ]),
      ),
    );
  }
}
