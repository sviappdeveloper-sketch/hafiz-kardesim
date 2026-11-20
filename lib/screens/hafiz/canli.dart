import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import '../../hafiz/arapca.dart';
import '../../hafiz/fonem.dart';
import '../../hafiz/hoca_service.dart';
import '../../hafiz/kayit.dart';
import '../../hafiz/kulak.dart';
import '../../hafiz/kuran.dart';
import '../../hafiz/ses.dart';
import '../../hafiz/sesli_baglanti.dart';
import '../../hafiz/yedek.dart';
import '../../models/models.dart';
import '../../services/settings_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/ornaments.dart';
import 'bildir.dart';
import 'ortak.dart';
import 'sonuc.dart';

/// Gelen ve süren canlı dinletme davetleri (ana sayfada ve hoca ekranında görünür).
class CanliDavetler extends StatelessWidget {
  const CanliDavetler({super.key, required this.me});
  final AppUser me;

  @override
  Widget build(BuildContext context) {
    if (me.isGuest) return const SizedBox();
    return StreamBuilder<List<Canli>>(
      stream: HocaService.canlilarim(me.id),
      builder: (context, s) {
        final l = s.data ?? const <Canli>[];
        if (l.isEmpty) return const SizedBox();
        return Column(children: [
          for (final c in l)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OrnateCard(
                highlight: true,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(_baslik(c), style: AppText.body(15, weight: FontWeight.w700, color: AppColors.goldLight)),
                  Text(Kuran.hazir ? Kuran.etiketListe(c.ayetler) : '', style: AppText.body(13, color: AppColors.muted)),
                  const SizedBox(height: 8),
                  if (c.durum == 'davet' && c.baslatan != me.id)
                    Row(children: [
                      Expanded(
                        child: GoldButton(
                          label: 'Katıl',
                          icon: Icons.login,
                          onPressed: () async {
                            final ok = await runGuarded(context, () => HocaService.katil(c.id));
                            if (ok && context.mounted) {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => CanliEkrani(id: c.id, me: me)));
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                          child: GoldButton(
                              label: 'Şimdi değil', outlined: true, onPressed: () => runGuarded(context, () => HocaService.reddet(c.id)))),
                    ])
                  else
                    GoldButton(
                      label: c.durum == 'aktif' ? 'Derse dön' : 'Aç',
                      icon: Icons.open_in_new,
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CanliEkrani(id: c.id, me: me))),
                    ),
                ]),
              ),
            ),
        ]);
      },
    );
  }

  String _baslik(Canli c) {
    final karsi = c.hoca == me.id ? c.ogrenci : c.hoca;
    final ad = c.ad(karsi);
    if (c.durum == 'aktif') return '🔴 $ad ile canlı ders sürüyor';
    if (c.baslatan == me.id) return '⏳ $ad\'ın katılması bekleniyor';
    return c.hoca == me.id ? '🎙️ $ad sana ezber dinletmek istiyor' : '🎙️ Hocan $ad seni dinlemek istiyor';
  }
}

/// Canlı dinletme: öğrenci ezberden okur (ayetler gizli), hoca kendi telefonunda metni görür ve işaretler.
/// Ses telefon ya da WhatsApp aramasıyla duyulur; uygulama işaretleri iki telefona anında taşır.
class CanliEkrani extends StatefulWidget {
  const CanliEkrani({super.key, required this.id, required this.me});
  final String id;
  final AppUser me;
  @override
  State<CanliEkrani> createState() => _CanliEkraniState();
}

class _CanliEkraniState extends State<CanliEkrani> {
  StreamSubscription<Canli?>? _sub;
  Canli? _c;
  List<Kelime>? _w;
  Eslestirici? _e;
  List<GlobalKey> _keys = [];
  bool _kaydedildi = false;
  final _not = TextEditingController();
  final _duyulanN = ValueNotifier<String>('');
  String get _duyulan => _duyulanN.value;
  Timer? _canliT;
  final Map<int, int> _bekleyenM = {};
  final Map<int, String> _bekleyenH = {};
  Timer? _yazT;
  int _sonCur = 0;
  /// Öğrencinin mikrofonu uygulamanın kendi Kur'an ses tanımasıyla (Kulak, internetsiz) mı dinliyor.
  bool _kulak = false;
  /// Hocanın son işlenen komutu ve öğrencide gösterilen uyarı.
  int _komutNo = -1;
  String _uyari = '';
  Timer? _uyariT;
  /// Hoca "Dur" dedi: öğrencinin mikrofonu duraklatıldı; "Devam"da yeniden açılır.
  bool _durdu = false, _mikAcikti = false;
  /// Uygulama içi sesli bağlantı (ders aktif olunca kurulur).
  SesliBaglanti? _ses;
  String _sesDurum = 'kapali';
  /// Kulak, sesi sesli bağlantıdan mı alıyor.
  bool _kulakBaglantidan = false;

  bool get _hocayim => _c != null && _c!.hoca == widget.me.id;

  @override
  void initState() {
    super.initState();
    Ses.acik.addListener(_yenile);
    // Ses modeli ekran açılırken hazırlanır: mikrofona basınca bekleme olmasın.
    Kulak.hazirla();
    _sub = HocaService.canli(widget.id).listen(_geldi, onError: (e) {
      if (mounted) showSnack(context, errorText(e));
    });
  }

  @override
  void dispose() {
    Ses.acik.removeListener(_yenile);
    _mikKapat(bosalt: false);
    _ses?.durum.removeListener(_sesDegisti);
    _ses?.kapat();
    _uyariT?.cancel();
    _sub?.cancel();
    _canliT?.cancel();
    _yazT?.cancel();
    _not.dispose();
    super.dispose();
  }

  void _yenile() {
    if (mounted) setState(() {});
  }

  void _geldi(Canli? c) {
    if (!mounted) return;
    if (c == null) {
      if (!_kaydedildi) {
        showSnack(context, 'Ders kapandı');
        Navigator.pop(context);
      }
      return;
    }
    _c = c;
    if (_w == null) {
      _w = kelimeler(c.ayetler, (ai) => Kuran.a[ai].metin, (ai) => Kuran.a[ai].n);
      _e = Eslestirici(_w!);
      _keys = List.generate(_w!.length, (_) => GlobalKey());
      if (_not.text.isEmpty) _not.text = c.not;
    }
    final m = c.isaret, h = c.duyulan;
    for (var i = 0; i < _w!.length; i++) {
      if (_bekleyenM.containsKey(i)) continue;
      _w![i].st = m[i] ?? KD.gizli;
      if (h[i] != null) _w![i].h = h[i]!;
    }
    // Sıra (cur) yalnızca karşı taraf yazdıysa uygulanır. Eskiden kendi yazdığımız eski "cur"
    // geri gelince öğrencinin yeri geriye kayıyor, ses tanıma takılıyordu.
    final yeniCur = c.cur.clamp(0, _w!.length);
    if (_bekleyenM.isEmpty && c.yazan != widget.me.id && yeniCur != _e!.cur) {
      _e!.cur = yeniCur;
      _e!.sifirlaTampon();
      if (_kulak) Kulak.yeniBolum();
    } else if (c.yazan.isEmpty && _bekleyenM.isEmpty) {
      _e!.cur = yeniCur;
    }
    if (c.durum == 'aktif' && _ses == null) {
      final b = SesliBaglanti(canliId: c.id, hocayim: _hocayim);
      _ses = b;
      b.durum.addListener(_sesDegisti);
      if (_hocayim) b.teklifVer();
    }
    _ses?.guncelle(c);
    if (c.komutNo != _komutNo) {
      final ilk = _komutNo < 0;
      _komutNo = c.komutNo;
      if (!ilk || c.komut == 'dur') _komutGeldi(c.komut, ilk: ilk);
    }
    if (c.durum == 'bitti') _kaydet();
    if (c.durum == 'iptal') {
      showSnack(context, 'Davet kabul edilmedi');
      Navigator.pop(context);
      return;
    }
    setState(() {});
    if (_e!.cur != _sonCur) {
      _sonCur = _e!.cur;
      WidgetsBinding.instance.addPostFrameCallback((_) => _kaydir());
    }
  }

  void _kaydir() {
    if (_e == null || _e!.cur >= _keys.length) return;
    final c = _keys[_e!.cur].currentContext;
    if (c != null) Scrollable.ensureVisible(c, alignment: .35, duration: const Duration(milliseconds: 250));
  }

  /// İşaretleri Firestore'a toplu yazar. Elle işaretler ([hizli]) hemen (~0,25 sn) gider; ses
  /// tanımanın açtığı kelimeler en çok 1,5 saniyede bir tek yazımda toplanır. Böylece bir ders
  /// yüzlerce yerine birkaç yüz yazımda kalır (Firebase'in ücretsiz günlük kotası için).
  void _yaz(Iterable<int> degisen, {bool hizli = false}) {
    for (final i in degisen) {
      _bekleyenM[i] = _w![i].st;
      if (_w![i].h.isNotEmpty) _bekleyenH[i] = _w![i].h;
    }
    setState(() {});
    if (hizli || _yazT == null) {
      _yazT?.cancel();
      _yazT = Timer(Duration(milliseconds: hizli ? 250 : 1500), _gonder);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _kaydir());
  }

  /// Ekranda gösterilmek üzere hocaya giden "telefon duydu" metni (bir sonraki yazımla gider).
  String? _bekleyenCanli;

  Future<void> _gonder() async {
    _yazT = null;
    if (_e == null) return;
    final m = Map<int, int>.from(_bekleyenM), h = Map<int, String>.from(_bekleyenH);
    _bekleyenM.clear();
    _bekleyenH.clear();
    final canli = _bekleyenCanli;
    _bekleyenCanli = null;
    try {
      await HocaService.isaretle(widget.id, m, h, _e!.cur, canli: canli, yazan: widget.me.id);
    } catch (e) {
      if (mounted) showSnack(context, errorText(e));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _kaydir());
  }

  // ---------- hoca işlemleri ----------
  void _isaretle(int st) {
    final e = _e!;
    if (e.bitti) return;
    final i = e.cur;
    _w![i].st = st;
    e.cur++;
    e.sifirlaTampon();
    if (_kulak && Ses.acik.value) Kulak.yeniBolum();
    _yaz([i], hizli: true);
  }

  void _ayetDogru() {
    final e = _e!;
    if (e.bitti) return;
    final li = _w![e.cur].li, d = <int>[];
    while (!e.bitti && _w![e.cur].li == li) {
      _w![e.cur].st = KD.dogru;
      d.add(e.cur);
      e.cur++;
    }
    e.sifirlaTampon();
    if (_kulak && Ses.acik.value) Kulak.yeniBolum();
    _yaz(d, hizli: true);
  }

  void _geriAl() {
    final e = _e!;
    if (e.cur <= 0) return;
    e.cur--;
    _w![e.cur].st = KD.gizli;
    e.sifirlaTampon();
    if (_kulak && Ses.acik.value) Kulak.yeniBolum();
    _yaz([e.cur], hizli: true);
  }

  Future<void> _dokun(int i) async {
    final k = _w![i];
    if (!_hocayim) {
      if (k.st == KD.gizli && i == _e!.cur) _isaretle(KD.ipucu);
      return;
    }
    final st = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.ink,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(k.t, style: arapYazi(36, color: AppColors.goldLight)),
            if (k.h.isNotEmpty) Text('Duyulan: ${k.h}', textDirection: TextDirection.rtl, style: arapYazi(20, color: AppColors.muted)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
              for (final x in const [(KD.dogru, 'Doğru'), (KD.hata, 'Hatalı'), (KD.ipucu, 'Hatırlattım'), (KD.atla, 'Atladı'), (KD.gizli, 'Okunmadı')])
                ChoiceChip(label: Text(x.$2), selected: k.st == x.$1, onSelected: (_) => Navigator.pop(c, x.$1)),
            ]),
          ]),
        ),
      ),
    );
    if (st == null) return;
    k.st = st;
    _yaz([i], hizli: true);
  }

  // ---------- hoca komutları: dur / yeniden oku / baştan al / devam ----------
  Future<void> _komut(String t) async {
    final e = _e!;
    final m = <int, int>{};
    int? cur;
    if (t == 'bastan') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Baştan alınsın mı?'),
          content: const Text('Öğrenci bölümü baştan okur. Şimdiye kadarki işaretler silinir.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Baştan al')),
          ],
        ),
      );
      if (ok != true) return;
      for (var i = 0; i < _w!.length; i++) {
        if (_w![i].st != KD.gizli) m[i] = KD.gizli;
        _w![i].st = KD.gizli;
      }
      cur = 0;
    } else if (t == 'tekrar') {
      // Okunmakta olan ayet; ayetin başındaysa az önce biten ayet yeniden okunur.
      var i = e.cur.clamp(0, _w!.length);
      if (i >= _w!.length || (i > 0 && _w![i].li != _w![i - 1].li)) i--;
      if (i < 0) return;
      final li = _w![i].li;
      var bas = i;
      while (bas > 0 && _w![bas - 1].li == li) {
        bas--;
      }
      for (var z = bas; z < _w!.length && (_w![z].li == li || z < e.cur); z++) {
        if (_w![z].st != KD.gizli) m[z] = KD.gizli;
        _w![z].st = KD.gizli;
      }
      cur = bas;
    }
    if (cur != null) {
      e.cur = cur;
      e.sifirlaTampon();
    }
    _bekleyenM.clear();
    _bekleyenH.clear();
    _yazT?.cancel();
    setState(() {});
    try {
      await HocaService.komutGonder(widget.id, t, widget.me.id, m: m, cur: cur);
    } catch (err) {
      if (mounted) showSnack(context, errorText(err));
    }
    if (t == 'dur' || t == 'devam') {
      _durdu = t == 'dur';
      if (mounted) setState(() {});
    }
    if (cur != null) WidgetsBinding.instance.addPostFrameCallback((_) => _kaydir());
  }

  /// Öğrencinin telefonunda: hocanın komutu büyük bir uyarıyla gösterilir, telefon titrer.
  void _komutGeldi(String t, {bool ilk = false}) {
    if (_hocayim) {
      _durdu = t == 'dur';
      return;
    }
    final metin = switch (t) {
      'dur' => '✋ Hocan: Dur',
      'tekrar' => '↺ Hocan: Bu ayeti yeniden oku',
      'bastan' => '⏮ Hocan: Baştan al',
      'devam' => '▶ Hocan: Devam et',
      _ => '',
    };
    if (metin.isEmpty) return;
    if (!ilk) HapticFeedback.heavyImpact();
    _uyariT?.cancel();
    _uyari = metin;
    if (t == 'dur') {
      _durdu = true;
      // Dinleme duraklatılır: hoca konuşurken onun sesi okuma sanılmasın.
      if (Ses.acik.value) {
        _mikAcikti = true;
        _mikKapat();
      }
    } else {
      _durdu = false;
      _uyariT = Timer(const Duration(milliseconds: 2800), () {
        if (mounted) setState(() => _uyari = '');
      });
      if (_kulak && Ses.acik.value) Kulak.yeniBolum();
      _e?.sifirlaTampon();
      if (_mikAcikti && !Ses.acik.value) {
        _mikAcikti = false;
        _mikrofon();
      }
    }
    setState(() {});
  }

  /// Sesli bağlantı durumu değişti. Öğrencide mikrofon tek yerde olabilir: bağlantı kurulurken
  /// telefonun kendi mikrofon dinlemesi bırakılır, bağlanınca ses tanıma sesi bağlantıdan alır.
  Future<void> _sesDegisti() async {
    final b = _ses;
    if (b == null || !mounted) return;
    final d = b.durum.value;
    final once = _sesDurum;
    _sesDurum = d;
    setState(() {});
    if (_hocayim) return;
    if (d == 'baglaniyor' && Ses.acik.value && !_kulakBaglantidan) {
      _mikAcikti = true;
      await _mikKapat();
    }
    if (d == 'bagli' && once != 'bagli') {
      // Ses köprüsünün hazır olması için kısa bekleme.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted || _durdu) return;
      if (_mikAcikti || !Ses.acik.value) {
        _mikAcikti = false;
        if (Ses.acik.value) await _mikKapat();
        await _mikrofon();
      }
    }
    if ((d == 'hata' || d == 'koptu' || d == 'kapali') && _kulakBaglantidan && Ses.acik.value) {
      await _mikKapat();
    }
  }

  // ---------- öğrenci: sesli tanıma ----------
  Future<void> _mikKapat({bool bosalt = true}) async {
    _kulakBaglantidan = false;
    if (_kulak) {
      await Kulak.durdur();
    } else {
      await Ses.durdur(bosalt: bosalt);
    }
  }

  void _duyulanYaz(String m) {
    _duyulanN.value = m;
    _bekleyenCanli = m;
    // İşaret yazımı yoksa duyulan metin en çok 4 saniyede bir ayrıca gider.
    _canliT ??= Timer(const Duration(seconds: 4), () {
      _canliT = null;
      if (_bekleyenCanli != null && _yazT == null) _gonder();
    });
  }

  void _hataGoster(String h) {
    if (mounted) showSnack(context, Ses.hataMetni(h));
  }

  Future<void> _mikrofon() async {
    if (Ses.acik.value) {
      _mikAcikti = false;
      await _mikKapat();
      return;
    }
    if (_durdu) {
      showSnack(context, 'Hocan "Dur" dedi. Hocan devam deyince mikrofon açılır.');
      _mikAcikti = true;
      return;
    }
    // Uygulama içi sesli bağlantı sürerken mikrofon bağlantıdadır: ses tanıma sesi oradan alır.
    final b = _ses;
    final baglantidan = b != null && (b.bagli || b.durum.value == 'baglaniyor');
    if (b != null && baglantidan) {
      if (!b.bagli) {
        _mikAcikti = true;
        showSnack(context, 'Sesli bağlantı kuruluyor… bağlanınca dinlemeye başlar.');
        return;
      }
      if (!b.tanimayaAkar.value || !Kulak.kullanilabilir) {
        showSnack(context, 'Sesli bağlantı sürerken bu telefonda ses tanıma çalışmıyor. Hocan seni duyuyor ve işaretliyor.');
        return;
      }
    }
    // 1) Uygulamanın kendi Kur'an ses tanıması (Kulak): internetsiz, harf adlarını (الم) ve seri
    // (hadr) okumayı telefonun genel ses tanımasından çok daha iyi duyar.
    if (Kulak.kullanilabilir) {
      final ok = await Kulak.baslat(
        kaynak: baglantidan ? SesliBaglanti.mikrofonSesi : null,
        sonuc: (duyulan, kesin) {
          if (!mounted || _e == null || _durdu) return;
          final e = _e!;
          final eski = [for (final k in _w!) k.st];
          e.fonem(duyulan, kesin: kesin);
          final d = <int>[];
          for (var i = 0; i < _w!.length; i++) {
            if (_w![i].st != eski[i]) d.add(i);
          }
          if (d.isNotEmpty || e.cur != _sonCur) _yaz(d);
          final x = Fonem.sade(duyulan);
          _duyulanYaz(x.length > 40 ? x.substring(x.length - 40) : x);
        },
        hata: _hataGoster,
      );
      if (ok) {
        _kulak = true;
        _kulakBaglantidan = baglantidan;
        return;
      }
      if (Ses.acik.value || baglantidan) return;
    }
    // 2) Model açılamazsa telefonun ses tanıması.
    _kulak = false;
    await Ses.baslat(
      kelime: (k) {
        if (!mounted || _e == null || _durdu) return;
        final d = _e!.besle(k);
        if (d.isNotEmpty) _yaz(d);
      },
      dene: (k) {
        if (!mounted || _e == null || _durdu) return false;
        final d = _e!.dene(k);
        if (d == null) return false;
        _yaz(d);
        return true;
      },
      canli: (m) {
        if (!mounted) return;
        _duyulanYaz(m.split(' ').reversed.take(8).toList().reversed.join(' '));
      },
      hata: _hataGoster,
    );
  }

  Future<void> _bitir() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Ders bitirilsin mi?'),
        content: const Text('Sonuç iki tarafın telefonundaki ders geçmişine kaydedilir.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Devam et')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Bitir')),
        ],
      ),
    );
    if (ok != true) return;
    await _mikKapat();
    // Bekleyen işaretler ders kapanmadan gönderilir.
    if (_yazT != null) {
      _yazT!.cancel();
      await _gonder();
    }
    if (_hocayim && _not.text.trim() != _c!.not) await HocaService.notYaz(widget.id, _not.text.trim());
    if (!mounted) return;
    await runGuarded(context, () => HocaService.bitir(widget.id));
  }

  /// Ders bitince her iki telefon kendi geçmişine bir kez kaydeder.
  void _kaydet() {
    if (_kaydedildi || _w == null) return;
    _kaydedildi = true;
    final c = _c!;
    final anahtar = 'hfCanli_${c.id}';
    final p = SettingsService.prefs;
    final karsi = _hocayim ? c.ogrenci : c.hoca;
    final sure = c.baslangic == null ? 0 : DateTime.now().difference(c.baslangic!).inSeconds;
    Oturum? o;
    if (p.getBool(anahtar) != true) {
      p.setBool(anahtar, true);
      o = Kayit.i.oturumKaydet(
        tur: _hocayim ? 'ogrenci' : 'hocaya',
        ayetler: c.ayetler,
        w: _w!,
        sureSn: sure,
        srs: !_hocayim,
        kisi: c.ad(karsi),
        kisiUid: karsi,
        not: c.not,
      );
      DriveYedek.otomatikYedekle();
      if (_hocayim) HocaService.sonuYaz(c.hoca, c.ogrenci, Kuran.etiketListe(c.ayetler), o.puan).catchError((_) {});
    }
    // İki taraf da kaydettiyse oturum belgesi silinir (sunucuda ders kaydı tutulmaz).
    HocaService.canlilar.doc(c.id).update({'kaydetti.${widget.me.id}': true}).then((_) async {
      final d = await HocaService.canlilar.doc(c.id).get();
      final k = (d.data()?['kaydetti'] ?? const {}) as Map;
      if (k.length >= 2) await HocaService.sil(c.id);
    }).catchError((_) {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (o != null) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SonucEkrani(oturum: o!, gecmistenMi: true)));
      } else {
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null || _w == null) {
      return Scaffold(appBar: AppBar(title: const Text('Canlı ders')), body: const PatternBackground(child: LoadingView()));
    }
    final karsi = _hocayim ? c.ogrenci : c.hoca;
    if (c.durum == 'davet') {
      return Scaffold(
        appBar: AppBar(title: const Text('Canlı ders')),
        body: PatternBackground(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(
                  c.baslatan == widget.me.id ? '${c.ad(karsi)} davetini bekliyor…' : '${c.ad(karsi)} seni derse çağırıyor',
                  textAlign: TextAlign.center,
                  style: AppText.display(20),
                ),
                const SizedBox(height: 8),
                Text('${Kuran.etiketListe(c.ayetler)}\n\nDers başlayınca sesli bağlantı uygulamanın içinden kurulur; ayrıca aramanıza gerek yok.',
                    textAlign: TextAlign.center, style: AppText.body(14, color: AppColors.muted)),
                const SizedBox(height: 20),
                if (c.baslatan == widget.me.id)
                  GoldButton(
                    label: 'Daveti geri al',
                    outlined: true,
                    onPressed: () async {
                      await runGuarded(context, () => HocaService.sil(c.id));
                    },
                  )
                else
                  GoldButton(label: 'Katıl', icon: Icons.login, onPressed: () => runGuarded(context, () => HocaService.katil(c.id))),
              ]),
            ),
          ),
        ),
      );
    }
    final yuzde = _w!.where((k) => k.st != KD.gizli).length / (_w!.isEmpty ? 1 : _w!.length);
    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_hocayim ? 'Öğrencim: ${c.ad(karsi)}' : 'Hocam: ${c.ad(karsi)}'),
          actions: [
            IconButton(
              tooltip: 'Suistimal bildir',
              onPressed: () => suistimalBildir(context, widget.me, karsi, c.ad(karsi)),
              icon: const Icon(Icons.flag_outlined),
            ),
            TextButton(onPressed: _bitir, child: const Text('Bitir')),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(value: yuzde, minHeight: 4, color: AppColors.gold, backgroundColor: AppColors.inkLine),
          ),
        ),
        body: PatternBackground(
          child: Column(children: [
            Container(
              width: double.infinity,
              color: AppColors.danger.withValues(alpha: .15),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Text(
                _hocayim
                    ? '🔴 Canlı · Metin sende açık, öğrencide gizli. Okudukça işaretle.'
                    : '🔴 Canlı · Hocan seni dinliyor ve işaretliyor.',
                style: AppText.body(12.5),
              ),
            ),
            _sesSeridi(),
            Expanded(
              child: OkumaZemini(
                child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 30),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  MushafGorunum(
                    w: _w!,
                    ayetler: c.ayetler,
                    cur: _e!.cur,
                    gizle: c.gizle,
                    anahtarlar: _keys,
                    hepsiAcik: _hocayim,
                    onTap: _dokun,
                  ),
                  const SizedBox(height: 10),
                  const DurumAciklama(),
                  if (_hocayim) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: _not,
                      maxLines: 3,
                      decoration: const InputDecoration(hintText: 'Öğrencine not (ders bitince geçmişine yazılır)'),
                      onEditingComplete: () => HocaService.notYaz(widget.id, _not.text.trim()),
                    ),
                  ],
                ]),
              ),
              ),
            ),
            _hocayim ? _hocaAlt(c) : _ogrenciAlt(),
          ]),
        ).sarUyari(_uyari, _durdu && !_hocayim),
      ),
    );
  }

  /// Sesli bağlantının durumu: bağlı / bağlanıyor / kurulamadı; hocada mikrofon ve yeniden bağlan.
  Widget _sesSeridi() {
    final b = _ses;
    if (b == null) return const SizedBox();
    final d = _sesDurum;
    final (ikon, metin, renk) = switch (d) {
      'bagli' => (Icons.volume_up_rounded, _hocayim ? 'Sesli bağlı · öğrencini duyuyorsun' : 'Sesli bağlı · hocan seni duyuyor', AppColors.done),
      'baglaniyor' => (Icons.sync, 'Sesli bağlantı kuruluyor…', AppColors.goldLight),
      'koptu' => (Icons.portable_wifi_off, 'Ses bağlantısı koptu', AppColors.danger),
      'hata' => (Icons.error_outline, 'Sesli bağlantı kurulamadı. İnterneti kontrol edin ya da telefonla arayın.', AppColors.danger),
      _ => (Icons.volume_off, 'Sesli bağlantı kapalı', AppColors.muted),
    };
    return Container(
      width: double.infinity,
      color: renk.withValues(alpha: .12),
      padding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
      child: Row(children: [
        Icon(ikon, size: 18, color: renk),
        const SizedBox(width: 8),
        Expanded(child: Text(metin, style: AppText.body(12.5, color: renk))),
        if (_hocayim && (d == 'hata' || d == 'koptu' || d == 'kapali'))
          TextButton(onPressed: b.teklifVer, child: const Text('Yeniden bağlan')),
        if (d == 'bagli' || d == 'baglaniyor')
          ValueListenableBuilder<bool>(
            valueListenable: b.sessiz,
            builder: (_, v, __) => IconButton(
              tooltip: v ? 'Mikrofonumu aç' : 'Mikrofonumu kapat',
              visualDensity: VisualDensity.compact,
              onPressed: () => b.sessizYap(!v),
              icon: Icon(v ? Icons.mic_off_rounded : Icons.mic_rounded, color: v ? AppColors.danger : renk),
            ),
          ),
      ]),
    );
  }

  Widget _altKutu(Widget child) => Container(
        decoration: BoxDecoration(
          color: AppColors.inkDeep.withValues(alpha: .97),
          border: Border(top: BorderSide(color: AppColors.gold.withValues(alpha: .25))),
        ),
        child: SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(10, 8, 10, 8), child: child)),
      );

  Widget _hocaAlt(Canli c) => _altKutu(Column(mainAxisSize: MainAxisSize.min, children: [
        if (c.canliMetin.isNotEmpty)
          Text('Telefon duydu: ${c.canliMetin}',
              maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: TextDirection.rtl, style: arapYazi(16, color: AppColors.muted).copyWith(height: 1.4)),
        Row(children: [
          Expanded(child: _buyuk('✓ Doğru', AppColors.done, () => _isaretle(KD.dogru))),
          const SizedBox(width: 8),
          Expanded(child: _buyuk('✗ Hata', AppColors.danger, () => _isaretle(KD.hata))),
        ]),
        // Hocanın komutları: öğrencinin ekranında büyük uyarı olarak çıkar, telefonu titrer.
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Expanded(
                child: _durdu
                    ? _komutDugme('▶', 'Devam', AppColors.done, () => _komut('devam'))
                    : _komutDugme('✋', 'Dur', AppColors.danger, () => _komut('dur'))),
            const SizedBox(width: 6),
            Expanded(child: _komutDugme('↺', 'Yeniden oku', AppColors.gold, () => _komut('tekrar'))),
            const SizedBox(width: 6),
            Expanded(child: _komutDugme('⏮', 'Baştan al', AppColors.gold, () => _komut('bastan'))),
          ]),
        ),
        Row(children: [
          Expanded(child: TextButton.icon(onPressed: () => _isaretle(KD.ipucu), icon: const Icon(Icons.lightbulb_outline), label: const Text('Hatırlattım'))),
          Expanded(child: TextButton.icon(onPressed: _ayetDogru, icon: const Icon(Icons.done_all), label: const Text('Ayet doğru'))),
          IconButton(onPressed: _geriAl, icon: const Icon(Icons.undo)),
        ]),
      ]));

  Widget _ogrenciAlt() => _altKutu(Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          height: 28,
          child: ValueListenableBuilder<String>(
            valueListenable: _duyulanN,
            builder: (_, d, __) => Text(d,
                maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: TextDirection.rtl, style: arapYazi(16, color: AppColors.muted).copyWith(height: 1.4)),
          ),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextButton.icon(onPressed: () => _isaretle(KD.ipucu), icon: const Icon(Icons.lightbulb_outline), label: const Text('İpucu')),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _mikrofon,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Ses.acik.value ? AppColors.danger : null,
                gradient: Ses.acik.value ? null : LinearGradient(colors: [AppColors.goldLight, AppColors.gold]),
              ),
              child: Icon(Ses.acik.value ? Icons.stop_rounded : Icons.mic_rounded, size: 30, color: AppColors.inkDeep),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Mikrofon isteğe bağlı: açarsan telefonun da dinler, hocana yardımcı olur.',
                style: AppText.body(11.5, color: AppColors.muted)),
          ),
        ]),
      ]));
}

Widget _komutDugme(String ikon, String t, Color c, VoidCallback f) => SizedBox(
      height: 40,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: c,
          side: BorderSide(color: c.withValues(alpha: .7)),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: f,
        child: FittedBox(child: Text('$ikon $t', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
      ),
    );

/// Öğrencinin ekranında hocanın komutu: sayfanın üstünde büyük bir uyarı.
extension _Uyari on Widget {
  Widget sarUyari(String metin, bool kalici) {
    if (metin.isEmpty) return this;
    return Stack(children: [
      Positioned.fill(child: this),
      if (kalici) Positioned.fill(child: ColoredBox(color: Colors.black.withValues(alpha: .35))),
      Positioned(
        left: 16,
        right: 16,
        top: 40,
        child: Material(
          color: kalici ? const Color(0xFFC62828) : const Color(0xFF14284B),
          elevation: 8,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(metin, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
              if (kalici)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Hocanı dinle. Hocan "Devam" deyince mikrofon kendiliğinden açılır.',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 13.5)),
                ),
            ]),
          ),
        ),
      ),
    ]);
  }
}

Widget _buyuk(String t, Color c, VoidCallback f) => SizedBox(
      height: 54,
      child: FilledButton(
        style: FilledButton.styleFrom(
            backgroundColor: c, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        onPressed: f,
        child: Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
    );
