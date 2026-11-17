import 'package:flutter/material.dart';

import '../../hafiz/kayit.dart';
import '../../hafiz/kuran.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/ornaments.dart';
import 'dinle.dart';
import 'oku.dart';
import 'ortak.dart';
import 'sonuc.dart';

/// İlerleme: seri, son 16 hafta, cüz haritası, zayıf ayetler, günlük hedef.
class IlerlemeEkrani extends StatelessWidget {
  const IlerlemeEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Kayit.i,
      builder: (context, _) {
        final k = Kayit.i;
        var tr = 0, sn = 0;
        for (final r in k.ay.values) {
          tr += r.r;
        }
        for (final g in k.gunler.values) {
          sn += g['sec'] ?? 0;
        }
        final hedef = Kayit.hedef;
        final t0 = Kayit.bugun0();
        final wd = DateTime.now().weekday - 1;
        final bas = t0 - (15 * 7 + wd) * 86400000;
        final zayif = (k.ay.entries.where((e) => e.value.ok < 85).toList()..sort((a, b) => a.value.ok.compareTo(b.value.ok)))
            .take(12)
            .map((e) => e.key)
            .toList();
        return Scaffold(
          appBar: AppBar(title: const Text('İlerlemem')),
          body: PatternBackground(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
              Row(children: [
                SayiKutu('🔥 ${k.seri}', 'gün seri'),
                const SizedBox(width: 6),
                SayiKutu('${k.ezberSayisi}', 'ezber ayet'),
                const SizedBox(width: 6),
                SayiKutu('$tr', 'dinletilen ayet'),
                const SizedBox(width: 6),
                SayiKutu('${(sn / 60).round()}', 'dakika'),
              ]),
              SectionTitle('Son 16 hafta',
                  trailing: DropdownButton<int>(
                    value: hedef,
                    underline: const SizedBox(),
                    items: [for (final n in const [3, 5, 10, 15, 20, 30, 50]) DropdownMenuItem(value: n, child: Text('Hedef $n ayet'))],
                    onChanged: (v) async {
                      if (v == null) return;
                      await Kayit.setHedef(v);
                      Kayit.i.yenile();
                    },
                  )),
              OrnateCard(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                    height: 7 * 17,
                    child: Row(children: [
                      for (var h = 0; h < 16; h++)
                        Expanded(
                          child: Column(children: [
                            for (var d = 0; d < 7; d++)
                              Builder(builder: (_) {
                                final ms = bas + (h * 7 + d) * 86400000;
                                final g = k.gun(ms);
                                final n = (g['ay'] ?? 0) + (g['dn'] ?? 0) / 3;
                                final c = ms > t0
                                    ? Colors.transparent
                                    : n >= hedef
                                        ? AppColors.gold
                                        : n > 0
                                            ? AppColors.done.withValues(alpha: (.25 + .6 * (n / hedef)).clamp(.25, .85))
                                            : AppColors.inkLine.withValues(alpha: .6);
                                return Container(
                                  height: 14,
                                  margin: const EdgeInsets.all(1.5),
                                  decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
                                );
                              }),
                          ]),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 6),
                  Text('Altın kare: o gün günlük hedef tamam.', style: AppText.body(12, color: AppColors.muted)),
                ]),
              ),
              const SectionTitle('Cüz haritası'),
              OrnateCard(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  GridView.count(
                    crossAxisCount: 6,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    children: [
                      for (var c = 1; c <= 30; c++)
                        Builder(builder: (_) {
                          final l = Kuran.cuz(c);
                          final p = l.where(k.ezber).length / l.length;
                          return Container(
                            decoration: BoxDecoration(
                              color: p > 0 ? AppColors.done.withValues(alpha: .15 + p * .85) : AppColors.inkDeep.withValues(alpha: .4),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.inkLine),
                            ),
                            alignment: Alignment.center,
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Text('$c', style: AppText.number(14)),
                              Text('%${(p * 100).round()}', style: AppText.body(10, color: AppColors.muted, height: 1)),
                            ]),
                          );
                        }),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Bir ayet en az iki kez %90 üstü okununca "ezber" sayılır.', style: AppText.body(12, color: AppColors.muted)),
                ]),
              ),
              if (zayif.isNotEmpty) ...[
                const SectionTitle('Zayıf ayetler'),
                OrnateCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Column(children: [
                    for (final i in zayif)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(Kuran.etiket(i), style: AppText.body(14, weight: FontWeight.w700)),
                        subtitle: Text('son %${k.ay[i]!.ok} · ${k.ay[i]!.h} hata', style: AppText.body(12, color: AppColors.muted)),
                        trailing: TextButton(onPressed: () => ezberAc(context, [i], 'ses'), child: const Text('Çalış')),
                      ),
                    GoldButton(label: 'Hepsini birden çalış', icon: Icons.mic, onPressed: () => ezberAc(context, [...zayif]..sort(), 'ses')),
                    const SizedBox(height: 8),
                  ]),
                ),
              ],
            ]),
          ),
        );
      },
    );
  }
}

/// Bütün ders çalışmaları (sesli ezber, kardeşime/hocama dinlettiklerim, öğrencilerim, dinlemeler).
class GecmisEkrani extends StatefulWidget {
  const GecmisEkrani({super.key, this.kisiUid, this.baslik = 'Ders geçmişim'});
  final String? kisiUid;
  final String baslik;
  @override
  State<GecmisEkrani> createState() => _GecmisEkraniState();
}

class _GecmisEkraniState extends State<GecmisEkrani> {
  String _tur = '';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Kayit.i,
      builder: (context, _) {
        var l = Kayit.i.gecmis;
        if (widget.kisiUid != null) l = l.where((o) => o.kisiUid == widget.kisiUid).toList();
        if (_tur.isNotEmpty) l = l.where((o) => o.tur == _tur).toList();
        String? gunBasligi;
        final cocuklar = <Widget>[];
        for (final o in l) {
          final d = DateTime.fromMillisecondsSinceEpoch(o.ts);
          final g = formatDate(d);
          if (g != gunBasligi) {
            gunBasligi = g;
            cocuklar.add(Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
              child: Text(g.toUpperCase(), style: AppText.label()),
            ));
          }
          cocuklar.add(_satir(o, d));
        }
        return Scaffold(
          appBar: AppBar(title: Text(widget.baslik)),
          body: PatternBackground(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
              if (widget.kisiUid == null)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final t in const [('', 'Hepsi'), ('ses', 'Sesli ezber'), ('kardes', 'Kardeşime'), ('hocaya', 'Hocama'), ('ogrenci', 'Öğrencilerim'), ('dinle', 'Dinleme')])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(label: Text(t.$2), selected: _tur == t.$1, onSelected: (_) => setState(() => _tur = t.$1)),
                      ),
                  ]),
                ),
              if (l.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: EmptyState(title: 'Henüz kayıt yok', message: 'Ezber dinlettikçe her ders burada tarih tarih birikir.'),
                ),
              ...cocuklar,
              const SizedBox(height: 16),
              Text('Geçmiş yalnızca bu telefonda ve senin Google Drive / iCloud yedeğinde durur.',
                  textAlign: TextAlign.center, style: AppText.body(12, color: AppColors.muted)),
            ]),
          ),
        );
      },
    );
  }

  Widget _satir(Oturum o, DateTime d) {
    final ic = switch (o.tur) {
      'ses' => Icons.mic_rounded,
      'kardes' => Icons.handshake_outlined,
      'hocaya' => Icons.school_outlined,
      'ogrenci' => Icons.co_present_outlined,
      _ => Icons.headphones,
    };
    final saat = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OrnateCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: () => o.tur == 'dinle'
            ? Navigator.push(context, MaterialPageRoute(builder: (_) => DinleEkrani(ayetler: o.ayetler)))
            : Navigator.push(context, MaterialPageRoute(builder: (_) => SonucEkrani(oturum: o, gecmistenMi: true))),
        child: Row(children: [
          Icon(ic, color: AppColors.goldLight),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(o.etiket, style: AppText.body(14.5, weight: FontWeight.w700)),
              Text('$saat · ${o.turAdi}${o.kisi.isNotEmpty ? ' · ${o.kisi}' : ''} · ${sureMetni(o.sure)}',
                  style: AppText.body(12, color: AppColors.muted)),
              if (o.not.isNotEmpty)
                Text('📝 ${o.not}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(12, color: AppColors.goldLight)),
            ]),
          ),
          if (o.tur != 'dinle')
            Text('%${o.puan}', style: AppText.number(18, color: o.puan >= 85 ? AppColors.done : AppColors.danger)),
        ]),
      ),
    );
  }
}

/// Hata defteri: yanlış okunan / atlanan kelimeler, ayet ayet.
class HatalarEkrani extends StatelessWidget {
  const HatalarEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Kayit.i,
      builder: (context, _) {
        final by = <int, List<HataKaydi>>{};
        for (final h in Kayit.i.hatalar) {
          (by[h.ai] ??= []).add(h);
        }
        final ks = by.keys.toList()..sort((a, b) => by[b]!.length.compareTo(by[a]!.length));
        return Scaffold(
          appBar: AppBar(title: const Text('Hata Defteri')),
          body: PatternBackground(
            child: ks.isEmpty
                ? const EmptyState(
                    title: 'Henüz hata yok', message: 'Ezber dinlettikçe yanlış okunan ve atlanan kelimeler burada birikir.')
                : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
                    Text('${ks.length} ayette ${Kayit.i.hatalar.length} hata. En çok hata yapılan ayetler üstte.',
                        style: AppText.body(13, color: AppColors.muted)),
                    const SizedBox(height: 10),
                    GoldButton(
                      label: 'Hatalı ayetleri çalış (${ks.length.clamp(0, 40)})',
                      icon: Icons.mic,
                      onPressed: () => ezberAc(context, (ks.take(40).toList()..sort()), 'ses'),
                    ),
                    const SizedBox(height: 12),
                    for (final i in ks.take(80)) ...[
                      OrnateCard(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Row(children: [
                            Expanded(child: Text(Kuran.etiket(i), style: AppText.body(15, weight: FontWeight.w700))),
                            Text('${by[i]!.length} hata', style: AppText.body(12, color: AppColors.muted)),
                          ]),
                          const SizedBox(height: 4),
                          Directionality(
                            textDirection: TextDirection.rtl,
                            child: Wrap(spacing: 8, children: [
                              for (final e in <String, int>{for (final h in by[i]!) h.t: by[i]!.where((x) => x.t == h.t).length}.entries)
                                Text('${e.key}${e.value > 1 ? ' ×${e.value}' : ''}', style: arapYazi(22, color: AppColors.danger)),
                            ]),
                          ),
                          Row(children: [
                            TextButton.icon(onPressed: () => ezberAc(context, [i], 'ses'), icon: const Icon(Icons.mic), label: const Text('Çalış')),
                            TextButton.icon(
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DinleEkrani(ayetler: [i]))),
                                icon: const Icon(Icons.headphones),
                                label: const Text('Dinle')),
                            const Spacer(),
                            IconButton(onPressed: () => Kayit.i.hataSil(i), icon: Icon(Icons.delete_outline, color: AppColors.danger)),
                          ]),
                        ]),
                      ),
                      const SizedBox(height: 10),
                    ],
                    TextButton(
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Hata defteri temizlensin mi?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
                              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Temizle')),
                            ],
                          ),
                        );
                        if (ok == true) {
                          Kayit.i.hatalariTemizle();
                          if (context.mounted) showSnack(context, 'Defter temizlendi');
                        }
                      },
                      child: Text('Defteri temizle', style: TextStyle(color: AppColors.danger)),
                    ),
                  ]),
          ),
        );
      },
    );
  }
}
