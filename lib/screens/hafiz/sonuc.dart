import 'package:flutter/material.dart';

import '../../hafiz/arapca.dart';
import '../../hafiz/kayit.dart';
import '../../hafiz/kuran.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/ornaments.dart';
import 'dinle.dart';
import 'oku.dart';
import 'ortak.dart';

/// Bir ders çalışmasının sonucu. Hem oturum bitince hem de geçmişten açılınca kullanılır.
class SonucEkrani extends StatelessWidget {
  const SonucEkrani({super.key, required this.oturum, this.w, this.mod, this.gecmistenMi = false});
  final Oturum oturum;
  final List<Kelime>? w;
  final String? mod;
  final bool gecmistenMi;

  @override
  Widget build(BuildContext context) {
    final o = oturum;
    final sc = o.puan;
    final msg = sc >= 95
        ? 'Mâşallah! Neredeyse kusursuz 🌟'
        : sc >= 85
            ? 'Çok iyi, birkaç küçük hata var 👏'
            : sc >= 70
                ? 'İyi gidiyor, hatalı yerleri tekrar et 💪'
                : 'Bu kısmı biraz daha çalışmak lazım 📖';
    final kendi = o.tur == 'ses' || o.tur == 'kardes' || o.tur == 'hocaya';
    final hataliAyetler = <int>{for (final h in o.hatalar) h.ai}.toList()..sort();
    final son = o.ayetler.last;
    List<int>? sonraki;
    if (son + 1 < Kuran.a.length && Kuran.a[son + 1].s == Kuran.a[son].s) {
      final s = Kuran.a[son].s;
      final bitis = Kuran.ix(s, Kuran.ayetSayisi(s));
      sonraki = Kuran.aralik(son + 1, (son + o.ayetler.length).clamp(son + 1, bitis));
    }
    final gun = Kayit.i.sonrakiTekrar(o.ayetler);
    final m = mod ?? (o.tur == 'kardes' ? 'kardes' : 'ses');
    return Scaffold(
      appBar: AppBar(title: Text(gecmistenMi ? 'Ders kaydı' : 'Sonuç')),
      body: PatternBackground(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
          OrnateCard(
            highlight: true,
            child: Column(children: [
              Text('${o.etiket} · ${o.turAdi}', textAlign: TextAlign.center, style: AppText.body(13, color: AppColors.muted)),
              if (o.kisi.isNotEmpty)
                Text(o.tur == 'ogrenci' ? 'Öğrenci: ${o.kisi}' : 'Hoca: ${o.kisi}',
                    style: AppText.body(13, color: AppColors.goldLight, weight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('%$sc', style: AppText.number(56, color: AppColors.goldLight)),
              Text(msg, textAlign: TextAlign.center, style: AppText.body(15, weight: FontWeight.w700)),
              const SizedBox(height: 12),
              Row(children: [
                SayiKutu('${o.sayilar[0]}', 'doğru', renk: AppColors.done),
                const SizedBox(width: 6),
                SayiKutu('${o.sayilar[1]}', 'hatalı', renk: AppColors.danger),
                const SizedBox(width: 6),
                SayiKutu('${o.sayilar[2]}', 'atlanan', renk: const Color(0xFFE0A030)),
                const SizedBox(width: 6),
                SayiKutu('${o.sayilar[3]}', 'ipucu', renk: AppColors.reading),
              ]),
              const SizedBox(height: 10),
              Text(
                '${formatDateTime(DateTime.fromMillisecondsSinceEpoch(o.ts))} · ${sureMetni(o.sure)}'
                '${kendi && gun >= 0 ? ' · Sonraki tekrar: ${gun <= 1 ? 'yarın' : '$gun gün sonra'}' : ''}',
                textAlign: TextAlign.center,
                style: AppText.body(12.5, color: AppColors.muted),
              ),
            ]),
          ),
          if (o.not.isNotEmpty) ...[
            const SizedBox(height: 12),
            OrnateCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('HOCANIN NOTU', style: AppText.label()),
                const SizedBox(height: 6),
                Text(o.not, style: AppText.body(15)),
              ]),
            ),
          ],
          if (o.hatalar.isNotEmpty) ...[
            const SectionTitle('Hatalı kelimeler'),
            OrnateCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(children: [
                for (final h in o.hatalar.take(60))
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.inkLine))),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(Kuran.etiket(h.ai), style: AppText.body(14, weight: FontWeight.w700)),
                          Text(h.k == KD.atla ? 'atlandı' : (h.h.isNotEmpty ? 'duyulan: ${h.h}' : 'hatalı'),
                              style: AppText.body(12, color: AppColors.muted)),
                        ]),
                      ),
                      Text(h.t, style: arapYazi(26, color: h.k == KD.atla ? const Color(0xFFE0A030) : AppColors.danger)),
                    ]),
                  ),
              ]),
            ),
          ],
          const SizedBox(height: 16),
          if (o.tur != 'ogrenci') ...[
            GoldButton(
              label: 'Tekrar dene',
              icon: Icons.refresh,
              onPressed: () => Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (_) => OkuEkrani(ayetler: o.ayetler, mod: m))),
            ),
            const SizedBox(height: 10),
            if (hataliAyetler.isNotEmpty) ...[
              GoldButton(
                label: 'Sadece hatalı ayetleri çalış (${hataliAyetler.length})',
                icon: Icons.priority_high,
                outlined: true,
                onPressed: () => Navigator.pushReplacement(
                    context, MaterialPageRoute(builder: (_) => OkuEkrani(ayetler: hataliAyetler, mod: m))),
              ),
              const SizedBox(height: 10),
            ],
            if (sonraki != null) ...[
              GoldButton(
                label: 'Sonraki ${sonraki.length} ayete geç',
                icon: Icons.arrow_forward,
                outlined: true,
                onPressed: () => Navigator.pushReplacement(
                    context, MaterialPageRoute(builder: (_) => OkuEkrani(ayetler: sonraki!, mod: m))),
              ),
              const SizedBox(height: 10),
            ],
            GoldButton(
              label: 'Bu kısmı dinle',
              icon: Icons.headphones,
              outlined: true,
              onPressed: () =>
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DinleEkrani(ayetler: o.ayetler))),
            ),
          ],
          if (gecmistenMi) ...[
            const SizedBox(height: 18),
            TextButton.icon(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Bu kayıt silinsin mi?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
                      TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sil')),
                    ],
                  ),
                );
                if (ok == true && context.mounted) {
                  Kayit.i.gecmisSil(o);
                  Navigator.pop(context);
                  showSnack(context, 'Kayıt silindi');
                }
              },
              icon: Icon(Icons.delete_outline, color: AppColors.danger),
              label: Text('Kaydı sil', style: TextStyle(color: AppColors.danger)),
            ),
          ],
        ]),
      ),
    );
  }
}
