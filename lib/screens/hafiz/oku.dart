import 'package:flutter/material.dart';

import '../../hafiz/adpcm.dart';
import '../../hafiz/arapca.dart';
import '../../hafiz/fonem.dart';
import '../../hafiz/hata_sesi.dart';
import '../../hafiz/hoca_service.dart';
import '../../hafiz/kayit.dart';
import '../../hafiz/kulak.dart';
import '../../hafiz/kuran.dart';
import '../../hafiz/odev_ses.dart';
import '../../hafiz/ses.dart';
import '../../hafiz/yedek.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/ornaments.dart';
import 'ortak.dart';
import 'sonuc.dart';

/// Ezber dinletme: [mod] "ses" (uygulama dinler) ya da "kardes" (yanındaki arkadaş işaretler).
class OkuEkrani extends StatefulWidget {
  const OkuEkrani({super.key, required this.ayetler, required this.mod, this.odev});
  final List<int> ayetler;
  final String mod;
  /// Hocanın verdiği ödev: okuma kaydedilir, "Dersi bitirdim" ile sonuç ve ses hocaya gider.
  final Bag? odev;

  @override
  State<OkuEkrani> createState() => _OkuEkraniState();
}

class _OkuEkraniState extends State<OkuEkrani> {
  late final List<Kelime> _w;
  late final Eslestirici _e;
  late final List<GlobalKey> _keys;
  final _t0 = DateTime.now();
  final _duyulan = ValueNotifier<String>('');
  bool _bitti = false;
  final List<(int, int, int)> _gecmis = []; // geri almak için: (dizin, eski durum, eski cur)

  bool get _ses => widget.mod == 'ses';
  Bag? get _odev => widget.odev;
  /// Ödev okumasının sıkıştırılmış kaydı (yalnız uygulamanın kendi ses tanımasıyla dinlerken).
  final _kayit = AdpcmKodlayici();
  static const _enCokOrnek = 16000 * 60 * 25; // 25 dakika

  /// Oturumdaki ayetler: seçilen bölüm + okumaya devam edilirse sıradaki ayetler (sonraki sure dahil).
  late final List<int> _ayetler = List.of(widget.ayetler);
  late final int _secimSonu = widget.ayetler.length;

  /// Seçilen bölüm bitti mi (sonrası "devam" ayetleri).
  bool get _secimBitti => _e.cur >= _w.length || _w[_e.cur].li >= _secimSonu;

  @override
  void initState() {
    super.initState();
    _w = kelimeler(_ayetler, (ai) => Kuran.a[ai].metin, (ai) => Kuran.a[ai].n);
    _e = Eslestirici(_w);
    _keys = List.generate(_w.length, (_) => GlobalKey());
    Ses.acik.addListener(_yenile);
    _uzatGerekirse();
    // Ses modeli ekran açılırken hazırlanır: "başla"ya basınca bekleme olmasın.
    if (_ses) Kulak.hazirla();
  }

  /// Okuma sona yaklaşınca sıradaki ayetleri gizli olarak ekler: kişi sure geçişinde de okumaya
  /// devam ederse elle sure seçmesi beklenmez, takip kesintisiz sürer.
  void _uzatGerekirse() {
    if (_ayetler.isEmpty || _w.length - _e.cur > 12) return;
    final son = _ayetler.last;
    if (son + 1 >= Kuran.a.length) return;
    final s = Kuran.a[son].s;
    final yeni = <int>[];
    var i = son + 1;
    // Önce bu surenin kalanı, sure bittiyse sonraki sure (en çok 30 ayet; gerekince yine eklenir).
    final hedefSure = Kuran.a[son].n >= Kuran.ayetSayisi(s) ? s + 1 : s;
    while (i < Kuran.a.length && Kuran.a[i].s == hedefSure && yeni.length < 30) {
      yeni.add(i++);
    }
    if (yeni.isEmpty) return;
    final ek = kelimeler(yeni, (ai) => Kuran.a[ai].metin, (ai) => Kuran.a[ai].n, liBas: _ayetler.length);
    _ayetler.addAll(yeni);
    _w.addAll(ek);
    _keys.addAll(List.generate(ek.length, (_) => GlobalKey()));
  }

  /// Sonuca girecek kısım: seçilen bölüm + devamda okunmaya başlanan ayetler.
  int get _okunanAyetSayisi {
    var son = _secimSonu - 1;
    for (final k in _w) {
      if (k.st != KD.gizli && k.li > son) son = k.li;
    }
    return son + 1;
  }

  @override
  void dispose() {
    Kulak.kayitci = null;
    Ses.acik.removeListener(_yenile);
    if (_kulak) {
      Kulak.durdur();
    } else {
      Ses.durdur(bosalt: false);
    }
    _duyulan.dispose();
    super.dispose();
  }

  void _yenile() {
    if (mounted) setState(() {});
  }

  /// Sayfa, okunan son kelimeyi takip ederek yumuşakça kayar. Sıradaki (henüz okunmamış) kelimeye
  /// göre kaydırılmaz: sayfanın son kelimesi okununca alttaki sayfa birden gelmez, okumaya
  /// başladıkça yavaşça yukarı akar.
  void _kaydir() {
    if (_e.cur <= 0) return;
    final i = (_e.cur - 1).clamp(0, _w.length - 1);
    final c = _keys[i].currentContext;
    if (c == null) return;
    final ro = c.findRenderObject();
    if (ro is RenderBox && ro.attached) {
      final y = ro.localToGlobal(Offset.zero).dy;
      final h = MediaQuery.sizeOf(context).height;
      // Okunan satır ekranın rahat bölgesindeyse kaydırılmaz.
      if (y > h * .12 && y < h * .58) return;
    }
    Scrollable.ensureVisible(c,
        alignment: .38, duration: const Duration(milliseconds: 900), curve: Curves.easeInOutCubic);
  }

  void _sonra() {
    _uzatGerekirse();
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _kaydir());
    if (_e.bitti && !_bitti) {
      _kulak ? Kulak.durdur() : Ses.durdur();
      Future.delayed(const Duration(milliseconds: 600), _bitir);
    }
  }

  int get _hataSayisi => _w.where((k) => k.st == KD.hata).length;

  /// Kendi ses tanımamız (Kulak) kullanılıyor mu; model açılamazsa telefonun ses tanımasına dönülür.
  bool _kulak = false;

  Future<void> _mikrofon() async {
    if (Ses.acik.value) {
      if (_kulak) {
        await Kulak.durdur();
      } else {
        await Ses.durdur();
      }
      return;
    }
    if (Kulak.kullanilabilir) {
      final ok = await Kulak.baslat(
        sonuc: (duyulan, kesin) {
          if (!mounted) return;
          final once = _e.cur;
          final duzOnce = _e.fDuzelen;
          final hataOnce = _hataSayisi;
          final yeni = _e.fonem(duyulan, kesin: kesin);
          // Yeni bir hata işaretlendiyse tok, kısık bir ses çalar.
          if (_hataSayisi > hataOnce) HataSesi.cal();
          for (final i in yeni) {
            _gecmis.add((i, KD.gizli, once));
          }
          // Alttaki satır: son duyulan sesler.
          final d = duyulan.replaceAll(' ', '');
          _duyulan.value = d.length > 40 ? d.substring(d.length - 40) : d;
          if (yeni.isNotEmpty || _e.cur != once || kesin || _e.fDuzelen != duzOnce) _sonra();
        },
        hata: (h) {
          if (mounted) showSnack(context, Ses.hataMetni(h));
        },
      );
      if (ok) {
        _kulak = true;
        if (_odev != null) {
          Kulak.kayitci = (s) {
            if (_kayit.ornek < _enCokOrnek) _kayit.ekle(s);
          };
        }
        if (mounted) showSnack(context, _odev != null ? 'Dinliyorum… okuman hocana gönderilmek üzere kaydediliyor' : 'Dinliyorum… okumaya başla');
        return;
      }
      if (!Kulak.kullanilabilir) _kulak = false;
      if (Ses.acik.value) return;
    }
    _kulak = false;
    final ok = await Ses.baslat(
      kelime: (k) {
        if (!mounted) return;
        final once = _e.cur;
        final d = _e.besle(k);
        if (d.isNotEmpty || _e.cur != once) {
          for (final i in d) {
            _gecmis.add((i, KD.gizli, once));
          }
          _sonra();
        }
      },
      dene: (k) {
        if (!mounted) return false;
        final once = _e.cur;
        final d = _e.dene(k);
        if (d == null) return false;
        for (final i in d) {
          _gecmis.add((i, KD.gizli, once));
        }
        _sonra();
        return true;
      },
      // Yalnızca alttaki "duyulan" satırı yenilenir; bütün sayfa yeniden çizilmez.
      canli: (m) => _duyulan.value = m.split(' ').reversed.take(8).toList().reversed.join(' '),
      hata: (h) {
        if (mounted) showSnack(context, Ses.hataMetni(h));
      },
    );
    if (ok && mounted) showSnack(context, 'Dinliyorum… okumaya başla');
  }

  void _isaretle(int st) {
    if (_e.bitti) return;
    if (_kulak) Kulak.yeniBolum();
    final i = _e.cur;
    _gecmis.add((i, _w[i].st, i));
    _w[i].st = st;
    _e.cur++;
    _e.sifirlaTampon();
    _sonra();
  }

  void _ayetiAc({bool dogru = false}) {
    if (_e.bitti) return;
    if (_kulak) Kulak.yeniBolum();
    final li = _w[_e.cur].li;
    while (!_e.bitti && _w[_e.cur].li == li) {
      _gecmis.add((_e.cur, _w[_e.cur].st, _e.cur));
      _w[_e.cur].st = dogru ? KD.dogru : KD.ipucu;
      _e.cur++;
    }
    _e.sifirlaTampon();
    _sonra();
  }

  void _geriAl() {
    if (_gecmis.isEmpty) return;
    if (_kulak) Kulak.yeniBolum();
    final g = _gecmis.removeLast();
    _w[g.$1].st = g.$2;
    _e.cur = g.$3;
    _e.sifirlaTampon();
    _sonra();
  }

  Future<void> _kelimeDokun(int i) async {
    final k = _w[i];
    if (k.st == KD.gizli) {
      if (i == _e.cur) {
        _isaretle(KD.ipucu);
        return;
      }
      await showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.ink,
        builder: (c) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(k.t, style: arapYazi(36, color: AppColors.goldLight)),
              Text('Bu kelimeye henüz gelmedin. Bakmak ezberin için iyi olmaz 🙂',
                  textAlign: TextAlign.center, style: AppText.body(13, color: AppColors.muted)),
            ]),
          ),
        ),
      );
      return;
    }
    final yeni = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.ink,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(k.t, style: arapYazi(38, color: AppColors.goldLight)),
            Text(Kuran.etiket(k.ai), style: AppText.body(13, color: AppColors.muted)),
            if (k.h.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Duyulan: ${k.h}', textDirection: TextDirection.rtl, style: arapYazi(22, color: AppColors.muted)),
            ],
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: GoldButton(label: 'Doğru', icon: Icons.check, onPressed: () => Navigator.pop(c, KD.dogru))),
              const SizedBox(width: 10),
              Expanded(child: GoldButton(label: 'Hatalı', icon: Icons.close, outlined: true, onPressed: () => Navigator.pop(c, KD.hata))),
            ]),
          ]),
        ),
      ),
    );
    if (yeni != null) setState(() => k.st = yeni);
  }

  /// Ödev: sonuç ve okuma sesi hocaya gönderilir.
  Future<void> _dersiBitirdim() async {
    if (_bitti || !mounted) return;
    if (!_w.any((k) => k.st != KD.gizli)) {
      showSnack(context, 'Henüz okumadın. Mikrofona basıp ödevini oku.');
      return;
    }
    _kulak ? await Kulak.durdur() : await Ses.durdur();
    Kulak.kayitci = null;
    _e.bitisToleransi();
    _bitti = true;
    final sn = DateTime.now().difference(_t0).inSeconds;
    final n = _okunanAyetSayisi;
    final ayetler = _ayetler.sublist(0, n);
    final w = _w.where((k) => k.li < n).toList();
    final b = _odev!;
    final o = Kayit.i.oturumKaydet(tur: widget.mod, ayetler: ayetler, w: w, sureSn: sn, kisi: b.karsiAd(b.ogrenci), kisiUid: b.hoca);
    DriveYedek.otomatikYedekle();
    final ses = _kayit.bitir();
    final ornek = _kayit.ornek;
    final ilerleme = ValueNotifier<double>(0);
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text('Hocana gönderiliyor…'),
        content: ValueListenableBuilder<double>(
          valueListenable: ilerleme,
          builder: (_, v, __) => Column(mainAxisSize: MainAxisSize.min, children: [
            LinearProgressIndicator(value: v == 0 ? null : v),
            const SizedBox(height: 8),
            Text(ornek > 0 ? 'Okuma sesin ve sonucun gönderiliyor (${(ses.length / 1e6).toStringAsFixed(1)} MB)' : 'Sonucun gönderiliyor'),
          ]),
        ),
      ),
    );
    var tamam = false;
    try {
      await OdevSes.gonder(
        bag: b,
        etiket: o.etiket,
        puan: o.puan,
        sayilar: o.sayilar,
        sureSn: sn,
        ses: ornek > 0 ? ses : null,
        ornek: ornek,
        ilerleme: (v) => ilerleme.value = v,
      );
      tamam = true;
    } catch (e) {
      if (mounted) showSnack(context, 'Gönderilemedi: ${errorText(e)}. Sonucun telefonuna kaydedildi.');
    }
    if (!mounted) return;
    Navigator.pop(context); // gönderim penceresi
    if (tamam) showSnack(context, ornek > 0 ? '✓ Ödevin ve okuma sesin hocana gönderildi' : '✓ Ödevin hocana gönderildi');
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SonucEkrani(oturum: o, w: w, mod: widget.mod)));
  }

  void _bitir() {
    if (_bitti || !mounted) return;
    _kulak ? Kulak.durdur() : Ses.durdur(); // bekleyen son kelime de işlenir
    // %10 lafız toleransı: son ayet büyük ölçüde doğru okunduysa kalanı doğru sayılır.
    _e.bitisToleransi();
    if (!_w.any((k) => k.st != KD.gizli)) {
      Navigator.pop(context);
      return;
    }
    _bitti = true;
    final sn = DateTime.now().difference(_t0).inSeconds;
    // Devamda hiç okunmayan ayetler sonuca katılmaz.
    final n = _okunanAyetSayisi;
    final ayetler = _ayetler.sublist(0, n);
    final w = _w.where((k) => k.li < n).toList();
    final o = Kayit.i.oturumKaydet(tur: widget.mod, ayetler: ayetler, w: w, sureSn: sn);
    DriveYedek.otomatikYedekle();
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => SonucEkrani(oturum: o, w: w, mod: widget.mod)));
  }

  Future<void> _ayarlar() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.ink,
      // Ayarların tamamı görünsün (varsayılan yükseklik yarıda kesiyordu); gerekirse kaydırılır.
      isScrollControlled: true,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .88),
      builder: (c) => StatefulBuilder(
        builder: (c, ss) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Görünüm', style: AppText.display(20)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Text('Yazı boyu', style: AppText.body(15))),
                IconButton(
                    onPressed: () async {
                      await HfAyar.setYazi(HfAyar.yazi - 2);
                      ss(() {});
                      _yenile();
                    },
                    icon: const Icon(Icons.text_decrease)),
                Text('${HfAyar.yazi.round()}', style: AppText.number(16)),
                IconButton(
                    onPressed: () async {
                      await HfAyar.setYazi(HfAyar.yazi + 2);
                      ss(() {});
                      _yenile();
                    },
                    icon: const Icon(Icons.text_increase)),
              ]),
              const SizedBox(height: 8),
              GizlemeSecici(onChanged: (_) => _yenile()),
              BeyazSayfaAnahtari(onChanged: _yenile),
              MushafSayfaAnahtari(onChanged: _yenile),
              const SizedBox(height: 14),
              Text('Yazı tipi', style: AppText.body(15)),
              const SizedBox(height: 6),
              YaziTipiSecici(onChanged: _yenile),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final secim = _w.where((k) => k.li < _secimSonu);
    final yuzde = secim.isEmpty ? 0.0 : secim.where((k) => k.st != KD.gizli).length / secim.length;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _bitir();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(Kuran.etiketListe(_ayetler.sublist(0, _okunanAyetSayisi))),
          actions: [IconButton(onPressed: _ayarlar, icon: const Icon(Icons.tune))],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(value: yuzde, minHeight: 4, color: AppColors.gold, backgroundColor: AppColors.inkLine),
          ),
        ),
        body: OkumaZemini(
          child: Column(children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 40),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  MushafGorunum(
                    w: _w,
                    ayetler: _ayetler,
                    ayetSiniri: _secimBitti ? null : _secimSonu,
                    bosCerceve: !_ses,
                    cur: _e.cur,
                    gizle: HfAyar.gizle,
                    anahtarlar: _keys,
                    onTap: _kelimeDokun,
                  ),
                  const SizedBox(height: 12),
                  const DurumAciklama(),
                ]),
              ),
            ),
            _alt(),
          ]),
        ),
      ),
    );
  }

  Widget _alt() {
    Widget kucuk(IconData ic, String t, VoidCallback f) => Expanded(
          child: TextButton(
            onPressed: f,
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(ic, color: AppColors.goldLight),
              const SizedBox(height: 2),
              Text(t, textAlign: TextAlign.center, style: AppText.body(11.5, color: AppColors.ivory, height: 1.1)),
            ]),
          ),
        );
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inkDeep.withValues(alpha: .97),
        border: Border(top: BorderSide(color: AppColors.gold.withValues(alpha: .25))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: _devamBilgisi(_ses
              ? Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                    height: 30,
                    child: ValueListenableBuilder<String>(
                      valueListenable: _duyulan,
                      builder: (_, d, __) => ValueListenableBuilder<double>(
                        valueListenable: Kulak.gecikme,
                        // Telefon modeli yetiştiremezse ne kadar geride kaldığı gösterilir.
                        builder: (_, g, __) => g >= 1.2 && _kulak && Ses.acik.value
                            ? Text('⏳ ${g.toStringAsFixed(1)} sn geride',
                                maxLines: 1, style: AppText.body(13, color: AppColors.muted))
                            : Text(d,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textDirection: TextDirection.rtl,
                                style: arapYazi(17, color: AppColors.muted).copyWith(height: 1.4)),
                      ),
                    ),
                  ),
                  Row(children: [
                    kucuk(Icons.lightbulb_outline, 'İpucu', () => _isaretle(KD.ipucu)),
                    kucuk(Icons.menu_book_outlined, 'Ayeti aç', _ayetiAc),
                    DinlemeDalgasi(
                      acik: Ses.acik.value,
                      renk: Ses.acik.value ? AppColors.danger : AppColors.gold,
                      child: GestureDetector(
                      onTap: _mikrofon,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Ses.acik.value ? AppColors.danger : null,
                          gradient: Ses.acik.value ? null : LinearGradient(colors: [AppColors.goldLight, AppColors.gold]),
                          boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: .35), blurRadius: 14)],
                        ),
                        child: Icon(Ses.acik.value ? Icons.stop_rounded : Icons.mic_rounded, size: 34, color: AppColors.inkDeep),
                      ),
                    ),
                    ),
                    kucuk(Icons.check_circle_outline, 'Doğru say', () => _isaretle(KD.dogru)),
                    kucuk(Icons.undo, 'Geri al', _geriAl),
                  ]),
                  if (_odev != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                      child: GoldButton(label: 'Dersi bitirdim · hocama gönder', icon: Icons.task_alt, onPressed: _dersiBitirdim),
                    )
                  else
                    TextButton.icon(onPressed: _bitir, icon: const Icon(Icons.flag_outlined), label: const Text('Bitir ve sonucu gör')),
                ])
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('Okuyan okusun, sen sıradaki kelimeyi işaretle.', style: AppText.body(12.5, color: AppColors.muted)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: _buyuk('✓ Doğru', AppColors.done, () => _isaretle(KD.dogru))),
                    const SizedBox(width: 8),
                    Expanded(child: _buyuk('✗ Hata', AppColors.danger, () => _isaretle(KD.hata))),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    kucuk(Icons.lightbulb_outline, 'Hatırlat', () => _isaretle(KD.ipucu)),
                    kucuk(Icons.done_all, 'Ayet doğru', () => _ayetiAc(dogru: true)),
                    kucuk(Icons.undo, 'Geri al', _geriAl),
                    kucuk(Icons.flag_outlined, 'Bitir', _bitir),
                  ]),
                ])),
        ),
      ),
    );
  }

  /// Seçilen bölüm bitince üstte kısa bir bilgi: okumaya devam edilebilir.
  Widget _devamBilgisi(Widget alt) {
    if (!_secimBitti || _bitti) return alt;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
        child: Text('✓ Seçtiğin bölüm bitti. Okumaya devam edersen sıradaki ayetlerle (sonraki sure dahil) sürer.',
            textAlign: TextAlign.center, style: AppText.body(12.5, color: AppColors.goldLight, weight: FontWeight.w600)),
      ),
      alt,
    ]);
  }
}

Widget _buyuk(String t, Color c, VoidCallback f) => SizedBox(
      height: 54,
      child: FilledButton(
        style: FilledButton.styleFrom(backgroundColor: c, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        onPressed: f,
        child: Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
    );

/// Dışarıdan çağrılan kısa yollar.
void ezberAc(BuildContext context, List<int> ayetler, String mod, {Bag? odev}) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => OkuEkrani(ayetler: ayetler, mod: mod, odev: odev)));

/// Tarteel tarzı dinleme dalgası: mikrofon açıkken düğmenin çevresinde sesle büyüyen halkalar.
class DinlemeDalgasi extends StatefulWidget {
  const DinlemeDalgasi({super.key, required this.acik, required this.renk, required this.child});
  final bool acik;
  final Color renk;
  final Widget child;
  @override
  State<DinlemeDalgasi> createState() => _DinlemeDalgasiState();
}

class _DinlemeDalgasiState extends State<DinlemeDalgasi> with SingleTickerProviderStateMixin {
  late final _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  double _s = 0;

  @override
  void initState() {
    super.initState();
    if (widget.acik) _a.repeat();
  }

  @override
  void didUpdateWidget(DinlemeDalgasi old) {
    super.didUpdateWidget(old);
    if (widget.acik && !_a.isAnimating) _a.repeat();
    if (!widget.acik && _a.isAnimating) {
      _a.stop();
      _a.value = 0;
    }
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 104,
        height: 92,
        child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
          if (widget.acik)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: Listenable.merge([_a, Ses.seviye]),
                builder: (_, __) {
                  // Ses şiddeti yumuşatılır: halkalar titremeden büyüyüp küçülür.
                  _s = _s * .8 + Ses.seviye.value * .2;
                  return CustomPaint(painter: _DalgaBoyasi(_a.value, _s, widget.renk));
                },
              ),
            ),
          widget.child,
        ]),
      );
}

class _DalgaBoyasi extends CustomPainter {
  _DalgaBoyasi(this.t, this.s, this.renk);
  final double t, s;
  final Color renk;

  @override
  void paint(Canvas canvas, Size size) {
    final m = size.center(Offset.zero);
    const r0 = 35.0;
    // Sesle büyüyen yumuşak ışık.
    canvas.drawCircle(
        m,
        r0 + 4 + 14 * s,
        Paint()
          ..color = renk.withValues(alpha: .10 + .18 * s)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    // Dışa doğru yayılan üç halka.
    for (var k = 0; k < 3; k++) {
      final f = (t + k / 3) % 1.0;
      final r = r0 + f * (8 + 16 * s);
      canvas.drawCircle(
          m,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = renk.withValues(alpha: (1 - f) * (.25 + .5 * s)));
    }
  }

  @override
  bool shouldRepaint(_DalgaBoyasi o) => o.t != t || o.s != s || o.renk != renk;
}
