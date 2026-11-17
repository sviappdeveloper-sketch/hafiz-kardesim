import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../services/settings_service.dart';
import 'arapca.dart';
import 'kuran.dart';

/// Bir ayetin ezber durumu (tekrar takvimi).
class AyKayit {
  AyKayit({this.r = 0, this.ok = 0, this.h = 0, this.lv = 0, this.t = 0, this.due = 0});
  int r, ok, h, lv, t, due;
  Map<String, dynamic> toJson() => {'r': r, 'ok': ok, 'h': h, 'lv': lv, 't': t, 'due': due};
  factory AyKayit.fromJson(Map m) => AyKayit(
      r: (m['r'] ?? 0) as int, ok: (m['ok'] ?? 0) as int, h: (m['h'] ?? 0) as int, lv: (m['lv'] ?? 0) as int,
      t: (m['t'] ?? 0) as int, due: (m['due'] ?? 0) as int);
}

/// Hata defterindeki bir kelime.
class HataKaydi {
  HataKaydi({required this.ai, required this.t, required this.h, required this.k, required this.ts});
  final int ai, k, ts;
  final String t, h;
  Map<String, dynamic> toJson() => {'ai': ai, 't': t, 'h': h, 'k': k, 'ts': ts};
  factory HataKaydi.fromJson(Map m) =>
      HataKaydi(ai: m['ai'] as int, t: m['t'] as String, h: (m['h'] ?? '') as String, k: m['k'] as int, ts: m['ts'] as int);
}

/// Geçmişteki bir ders çalışması.
/// tur: ses (sesli ezber), kardes (kardeşime dinlet), hocaya (hocaya dinlettim), ogrenci (öğrencimi dinledim), dinle.
class Oturum {
  Oturum({
    required this.ts,
    required this.tur,
    required this.ayetler,
    required this.sure,
    required this.puan,
    required this.sayilar,
    this.hatalar = const [],
    this.kisi = '',
    this.kisiUid = '',
    this.not = '',
  });
  final int ts, sure, puan;
  final String tur, kisi, kisiUid, not;
  final List<int> ayetler;
  /// doğru, hatalı, atlanan, ipucu
  final List<int> sayilar;
  final List<HataKaydi> hatalar;

  String get etiket => Kuran.etiketListe(ayetler);
  String get turAdi => switch (tur) {
        'ses' => 'Sesli ezber',
        'kardes' => 'Kardeşime dinlettim',
        'hocaya' => 'Hocama dinlettim',
        'ogrenci' => 'Öğrencimi dinledim',
        'dinle' => 'Dinledim',
        _ => tur,
      };

  Map<String, dynamic> toJson() => {
        'ts': ts,
        'tur': tur,
        'p': _sikistir(ayetler),
        'sure': sure,
        'puan': puan,
        'say': sayilar,
        if (hatalar.isNotEmpty) 'hata': [for (final h in hatalar) h.toJson()],
        if (kisi.isNotEmpty) 'kisi': kisi,
        if (kisiUid.isNotEmpty) 'kuid': kisiUid,
        if (not.isNotEmpty) 'not': not,
      };
  factory Oturum.fromJson(Map m) => Oturum(
        ts: m['ts'] as int,
        tur: m['tur'] as String,
        ayetler: _ac(m['p'] as List),
        sure: (m['sure'] ?? 0) as int,
        puan: (m['puan'] ?? 0) as int,
        sayilar: [for (final x in (m['say'] ?? const [0, 0, 0, 0]) as List) x as int],
        hatalar: [for (final h in (m['hata'] ?? const []) as List) HataKaydi.fromJson(h as Map)],
        kisi: (m['kisi'] ?? '') as String,
        kisiUid: (m['kuid'] ?? '') as String,
        not: (m['not'] ?? '') as String,
      );
}

/// Ayet listesini [başlangıç, bitiş] çiftlerine sıkıştırır.
List<int> _sikistir(List<int> l) => [for (final p in Kuran.parcalarHam(l)) ...[p.$1, p.$2]];
List<int> _ac(List p) => [
      for (var i = 0; i + 1 < p.length; i += 2)
        for (var k = p[i] as int; k <= (p[i + 1] as int); k++) k
    ];

/// Ezber kayıtları ve ders geçmişi. Yalnızca telefonda (üyeye özel dosyada) tutulur;
/// telefonun kendi yedeği (Google Drive / iCloud) ve isteğe bağlı Google Drive yedeği bu dosyayı korur.
class Kayit extends ChangeNotifier {
  Kayit._();
  static final Kayit i = Kayit._();

  String uid = '';
  Map<int, AyKayit> ay = {};
  Map<String, Map<String, int>> gunler = {};
  List<HataKaydi> hatalar = [];
  List<Oturum> gecmis = [];
  int oturumSayisi = 0;
  File? _dosya;
  Timer? _yaz;
  int degisti = 0; // son değişiklik zamanı (yedek için)

  static int get hedef => SettingsService.prefs.getInt('hfHedef') ?? 10;
  static Future<void> setHedef(int v) => SettingsService.prefs.setInt('hfHedef', v);

  Future<void> ac(String uid) async {
    if (this.uid == uid && _dosya != null) return;
    this.uid = uid;
    final d = await getApplicationDocumentsDirectory();
    _dosya = File('${d.path}/hafiz_$uid.json');
    ay = {};
    gunler = {};
    hatalar = [];
    gecmis = [];
    oturumSayisi = 0;
    if (await _dosya!.exists()) {
      try {
        jsondanYukle(jsonDecode(await _dosya!.readAsString()) as Map<String, dynamic>);
      } catch (_) {}
    }
    notifyListeners();
  }

  bool get bos => gecmis.isEmpty && ay.isEmpty;

  void yenile() => notifyListeners();

  void jsondanYukle(Map<String, dynamic> m) {
    ay = {for (final e in ((m['ay'] ?? const {}) as Map).entries) int.parse(e.key as String): AyKayit.fromJson(e.value as Map)};
    gunler = {
      for (final e in ((m['gun'] ?? const {}) as Map).entries)
        e.key as String: {for (final x in (e.value as Map).entries) x.key as String: x.value as int}
    };
    hatalar = [for (final h in (m['hata'] ?? const []) as List) HataKaydi.fromJson(h as Map)];
    gecmis = [for (final o in (m['gecmis'] ?? const []) as List) Oturum.fromJson(o as Map)];
    oturumSayisi = (m['n'] ?? 0) as int;
    degisti = (m['degisti'] ?? 0) as int;
  }

  Map<String, dynamic> json() => {
        'surum': 1,
        'uid': uid,
        'degisti': degisti,
        'n': oturumSayisi,
        'ay': {for (final e in ay.entries) '${e.key}': e.value.toJson()},
        'gun': gunler,
        'hata': [for (final h in hatalar) h.toJson()],
        'gecmis': [for (final o in gecmis) o.toJson()],
      };

  void _kaydet() {
    degisti = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
    _yaz?.cancel();
    _yaz = Timer(const Duration(milliseconds: 400), yazSimdi);
  }

  Future<void> yazSimdi() async {
    final f = _dosya;
    if (f == null) return;
    try {
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode(json()));
      await tmp.rename(f.path);
    } catch (_) {}
  }

  /// Yedekten gelen veriyi yerine koyar.
  Future<void> yedektenAl(Map<String, dynamic> m) async {
    jsondanYukle(m);
    await yazSimdi();
    notifyListeners();
  }

  // ---------------- hesaplar ----------------
  static const _gun = 86400000;
  static int bugun0() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day).millisecondsSinceEpoch;
  }

  static String gunAnahtar(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}-${d.month}-${d.day}';
  }

  Map<String, int> gun(int ms) => gunler[gunAnahtar(ms)] ?? const {};
  int get bugunAyet => gun(DateTime.now().millisecondsSinceEpoch)['ay'] ?? 0;

  int get seri {
    var t = bugun0(), n = 0;
    if ((gun(t)['ss'] ?? 0) == 0) t -= _gun;
    while ((gun(t)['ss'] ?? 0) > 0) {
      n++;
      t -= _gun;
    }
    return n;
  }

  bool ezber(int ai) => (ay[ai]?.lv ?? 0) >= 2;
  int get ezberSayisi => ay.values.where((r) => r.lv >= 2).length;

  List<int> get tekrarListesi {
    final e = bugun0() + _gun;
    return (ay.entries.where((x) => x.value.due > 0 && x.value.due < e).map((x) => x.key).toList())..sort();
  }

  double sureOrani(int s) {
    final n = Kuran.ayetSayisi(s);
    var k = 0;
    for (var a = 1; a <= n; a++) {
      if (ezber(Kuran.ix(s, a))) k++;
    }
    return n == 0 ? 0 : k / n;
  }

  // ---------------- kayıt ----------------
  static const _aralik = [1, 1, 3, 7, 14, 30, 60];

  /// Bir ezber oturumunu kaydeder. [srs]: tekrar takvimini günceller (kendi ezberim ise true).
  Oturum oturumKaydet({
    required String tur,
    required List<int> ayetler,
    required List<Kelime> w,
    required int sureSn,
    bool srs = true,
    String kisi = '',
    String kisiUid = '',
    String not = '',
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final byA = <int, List<Kelime>>{};
    for (final k in w) {
      (byA[k.ai] ??= []).add(k);
    }
    var nA = 0;
    final yeniHatalar = <HataKaydi>[];
    for (final e in byA.entries) {
      final ws = e.value;
      if (!ws.any((k) => k.st != KD.gizli)) continue;
      nA++;
      for (final k in ws) {
        if (k.st == KD.hata || k.st == KD.atla) yeniHatalar.add(HataKaydi(ai: e.key, t: k.t, h: k.h, k: k.st, ts: now));
      }
      if (!srs) continue;
      final sc = puan(ws);
      final ne = ws.where((k) => k.st == KD.hata || k.st == KD.atla).length;
      final r = ay[e.key] ?? AyKayit();
      r.r++;
      r.ok = sc;
      r.h += ne;
      r.t = now;
      r.lv = sc >= 90 ? (r.lv + 1).clamp(0, 6) : (sc < 70 ? 0 : r.lv);
      r.due = bugun0() + _aralik[r.lv] * _gun;
      ay[e.key] = r;
    }
    if (srs) {
      hatalar.insertAll(0, yeniHatalar);
      if (hatalar.length > 600) hatalar = hatalar.sublist(0, 600);
      final g = gunler[gunAnahtar(now)] ??= {'ay': 0, 'ss': 0, 'sec': 0};
      g['ay'] = (g['ay'] ?? 0) + nA;
      g['ss'] = (g['ss'] ?? 0) + 1;
      g['sec'] = (g['sec'] ?? 0) + sureSn;
    }
    final say = [0, 0, 0, 0];
    for (final k in w) {
      if (k.st >= 1) say[k.st - 1]++;
    }
    final o = Oturum(
      ts: now,
      tur: tur,
      ayetler: ayetler,
      sure: sureSn,
      puan: puan(w),
      sayilar: say,
      hatalar: yeniHatalar.take(120).toList(),
      kisi: kisi,
      kisiUid: kisiUid,
      not: not,
    );
    gecmis.insert(0, o);
    if (gecmis.length > 3000) gecmis = gecmis.sublist(0, 3000);
    oturumSayisi++;
    _kaydet();
    return o;
  }

  void dinlemeKaydet(List<int> ayetler, int sureSn) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final g = gunler[gunAnahtar(now)] ??= {'ay': 0, 'ss': 0, 'sec': 0};
    g['dn'] = (g['dn'] ?? 0) + ayetler.length;
    gecmis.insert(0, Oturum(ts: now, tur: 'dinle', ayetler: ayetler, sure: sureSn, puan: 0, sayilar: const [0, 0, 0, 0]));
    _kaydet();
  }

  void hataSil(int ai) {
    hatalar = hatalar.where((h) => h.ai != ai).toList();
    _kaydet();
  }

  void hatalariTemizle() {
    hatalar = [];
    _kaydet();
  }

  void gecmisSil(Oturum o) {
    gecmis.remove(o);
    _kaydet();
  }

  int sonrakiTekrar(List<int> l) {
    var m = 1 << 62;
    for (final i in l) {
      final r = ay[i];
      if (r != null && r.due < m) m = r.due;
    }
    if (m == 1 << 62) return -1;
    return ((m - bugun0()) / _gun).round();
  }
}
