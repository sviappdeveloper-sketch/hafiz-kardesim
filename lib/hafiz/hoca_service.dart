import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import '../utils/format.dart';

/// Hoca–öğrenci bağı. Belge kimliği: hocaUid_ogrenciUid.
class Bag {
  Bag(this.id, this.m);
  final String id;
  final Map<String, dynamic> m;
  String get hoca => m['hoca'] as String;
  String get ogrenci => m['ogrenci'] as String;
  String get durum => (m['durum'] ?? '') as String;
  String get isteyen => (m['isteyen'] ?? '') as String;
  String ad(String uid) => ((m['adlar'] ?? const {}) as Map)[uid] as String? ?? '';
  bool hocaMi(String me) => hoca == me;
  String karsi(String me) => hoca == me ? ogrenci : hoca;
  String karsiAd(String me) => ad(karsi(me));
  Map<String, dynamic>? get odev => m['odev'] as Map<String, dynamic>?;
  Map<String, dynamic>? get son => m['son'] as Map<String, dynamic>?;
  DateTime? get olusturma => (m['olusturma'] as Timestamp?)?.toDate();
}

/// Canlı dinletme oturumu.
class Canli {
  Canli(this.id, this.m);
  final String id;
  final Map<String, dynamic> m;
  String get hoca => m['hoca'] as String;
  String get ogrenci => m['ogrenci'] as String;
  String get baslatan => m['baslatan'] as String;
  String get durum => m['durum'] as String;
  String ad(String uid) => ((m['adlar'] ?? const {}) as Map)[uid] as String? ?? '';
  List<int> get ayetler {
    final p = (m['p'] ?? const []) as List;
    return [
      for (var i = 0; i + 1 < p.length; i += 2)
        for (var k = p[i] as int; k <= (p[i + 1] as int); k++) k
    ];
  }

  String get gizle => (m['gizle'] ?? 'gizli') as String;
  Map<int, int> get isaret => {for (final e in ((m['m'] ?? const {}) as Map).entries) int.parse(e.key as String): e.value as int};
  Map<int, String> get duyulan => {for (final e in ((m['h'] ?? const {}) as Map).entries) int.parse(e.key as String): e.value as String};
  int get cur => (m['cur'] ?? 0) as int;
  String get canliMetin => (m['canli'] ?? '') as String;
  String get not => (m['not'] ?? '') as String;
  DateTime? get olusturma => (m['olusturma'] as Timestamp?)?.toDate();
  DateTime? get baslangic => (m['baslangic'] as Timestamp?)?.toDate();
}

class HocaService {
  HocaService._();
  static final _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get baglar => _db.collection('hafizBag');
  static CollectionReference<Map<String, dynamic>> get canlilar => _db.collection('hafizCanli');
  static CollectionReference<Map<String, dynamic>> get users => _db.collection('users');

  // ---------------- kişisel kod ----------------
  /// Üyenin paylaşılabilir 6 haneli Hafız Kardeşim kodu (yoksa üretilir).
  static Future<String> kodum(AppUser me) async {
    final d = await users.doc(me.id).get();
    final k = d.data()?['hafizKod'] as String?;
    if (k != null && k.length == 6) return k;
    const harf = 'ABCDEFGHJKLMNPRSTUVYZ23456789';
    final r = Random.secure();
    for (var deneme = 0; deneme < 6; deneme++) {
      final yeni = List.generate(6, (_) => harf[r.nextInt(harf.length)]).join();
      final var_ = await users.where('hafizKod', isEqualTo: yeni).limit(1).get();
      if (var_.docs.isEmpty) {
        await users.doc(me.id).update({'hafizKod': yeni});
        return yeni;
      }
    }
    throw HatimException('Kod üretilemedi, tekrar deneyin.');
  }

  /// Koddan üye bulur: (uid, ad).
  static Future<(String, String)?> koddanBul(String kod) async {
    final q = await users.where('hafizKod', isEqualTo: kod.trim().toUpperCase()).limit(1).get();
    if (q.docs.isEmpty) return null;
    return (q.docs.first.id, (q.docs.first.data()['name'] ?? '') as String);
  }

  // ---------------- hoca–öğrenci bağı ----------------
  static Stream<List<Bag>> baglarim(String me) => baglar
      .where('uyeler', arrayContains: me)
      .snapshots()
      .map((s) => s.docs.map((d) => Bag(d.id, d.data())).toList()
        ..sort((a, b) => a.karsiAd(me).toLowerCase().compareTo(b.karsiAd(me).toLowerCase())));

  /// [benHocayim]: true → karşı tarafa "öğrencim olur musun", false → "hocam olur musun".
  static Future<void> istekGonder(AppUser me, String uid, String ad, {required bool benHocayim}) async {
    if (uid == me.id) throw HatimException('Kendine istek gönderemezsin.');
    final hoca = benHocayim ? me.id : uid, ogrenci = benHocayim ? uid : me.id;
    final ref = baglar.doc('${hoca}_$ogrenci');
    await _db.runTransaction((tx) async {
      final d = await tx.get(ref);
      if (d.exists) {
        final st = d.data()!['durum'];
        if (st == 'kabul') throw HatimException('Bu kişiyle zaten hoca–öğrenci bağınız var.');
        if (st == 'bekliyor') throw HatimException('Bu kişiye zaten bir istek gönderilmiş, cevap bekleniyor.');
      }
      tx.set(ref, {
        'hoca': hoca,
        'ogrenci': ogrenci,
        'uyeler': [hoca, ogrenci],
        'adlar': {me.id: me.name, uid: ad},
        'isteyen': me.id,
        'durum': 'bekliyor',
        'olusturma': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<void> cevapla(Bag b, bool kabul) =>
      baglar.doc(b.id).update({'durum': kabul ? 'kabul' : 'red', 'cevap': FieldValue.serverTimestamp()});

  static Future<void> bagiSil(Bag b) => baglar.doc(b.id).delete();

  static Future<void> odevVer(Bag b, List<int> ayetler, String etiket, String not) => baglar.doc(b.id).update({
        'odev': {'p': sikistir(ayetler), 'etiket': etiket, 'not': not, 'ts': FieldValue.serverTimestamp()},
      });

  static Future<void> odevKaldir(Bag b) => baglar.doc(b.id).update({'odev': FieldValue.delete()});

  static Future<void> sonuYaz(String hoca, String ogrenci, String etiket, int puan) =>
      baglar.doc('${hoca}_$ogrenci').update({
        'son': {'etiket': etiket, 'puan': puan, 'ts': FieldValue.serverTimestamp()},
      });

  // ---------------- canlı dinletme ----------------
  static Stream<List<Canli>> canlilarim(String me) => canlilar
      .where('uyeler', arrayContains: me)
      .snapshots()
      .map((s) => s.docs.map((d) => Canli(d.id, d.data())).where((c) => c.durum == 'davet' || c.durum == 'aktif').toList());

  static Stream<Canli?> canli(String id) =>
      canlilar.doc(id).snapshots().map((d) => d.exists ? Canli(d.id, d.data()!) : null);

  static Future<String> canliBaslat(AppUser me, Bag b, List<int> ayetler, String gizle) async {
    final ref = canlilar.doc();
    await ref.set({
      'hoca': b.hoca,
      'ogrenci': b.ogrenci,
      'uyeler': [b.hoca, b.ogrenci],
      'adlar': {b.hoca: b.ad(b.hoca), b.ogrenci: b.ad(b.ogrenci), me.id: me.name},
      'baslatan': me.id,
      'durum': 'davet',
      'p': sikistir(ayetler),
      'gizle': gizle,
      'm': <String, int>{},
      'h': <String, String>{},
      'cur': 0,
      'olusturma': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  static Future<void> katil(String id) =>
      canlilar.doc(id).update({'durum': 'aktif', 'baslangic': FieldValue.serverTimestamp()});

  static Future<void> reddet(String id) => canlilar.doc(id).update({'durum': 'iptal'});

  static Future<void> isaretle(String id, Map<int, int> m, Map<int, String> h, int cur, {String? canli}) {
    final u = <String, Object>{'cur': cur};
    m.forEach((k, v) => u['m.$k'] = v);
    h.forEach((k, v) => u['h.$k'] = v);
    if (canli != null) u['canli'] = canli;
    return canlilar.doc(id).update(u);
  }

  static Future<void> notYaz(String id, String not) => canlilar.doc(id).update({'not': not});

  static Future<void> bitir(String id) =>
      canlilar.doc(id).update({'durum': 'bitti', 'bitis': FieldValue.serverTimestamp()});

  /// Biten oturum belgesi silinir; sonuç iki tarafın telefonundaki geçmişte kalır.
  static Future<void> sil(String id) => canlilar.doc(id).delete();

  static List<int> sikistir(List<int> l) {
    final out = <int>[];
    for (final i in l) {
      if (out.isNotEmpty && i == out.last + 1) {
        out[out.length - 1] = i;
      } else {
        out.addAll([i, i]);
      }
    }
    return out;
  }
}
