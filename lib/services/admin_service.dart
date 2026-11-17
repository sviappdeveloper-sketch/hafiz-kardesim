import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/models.dart';
import '../utils/format.dart';
import '../l10n/l10n.dart';

/// Yönetici işlemleri: üyeler, engelleme, gruplar. Sunucu kuralları bu işlemlere
/// yalnızca e-postası doğrulanmış yönetici hesabında izin verir.
class AdminService {
  static final _db = FirebaseFirestore.instance;

  /// Üyeler, en yeni kayıt en üstte.
  static Stream<List<AppUser>> members({int limit = 500}) => _db
      .collection('users')
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(AppUser.fromDoc).toList());

  /// Üyenin e-posta adresi (yalnızca yönetici okuyabilir).
  static Future<String?> emailOf(String uid) async {
    final d = await _db.collection('userPrivate').doc(uid).get();
    return d.data()?['email'] as String?;
  }

  static Future<int> groupCountOf(String uid) async {
    final s = await _db.collection('groups').where('memberIds', arrayContains: uid).count().get();
    return s.count ?? 0;
  }

  static Future<void> setBlocked(String uid, bool blocked) => _db.collection('users').doc(uid).update({
        'blocked': blocked,
        'blockedAt': blocked ? FieldValue.serverTimestamp() : FieldValue.delete(),
      });

  static const Map<String, Object> _zeroStats = {'totalJuzRead': 0, 'monthReads': <String, Object>{}, 'monthLast': <String, Object>{}};

  /// Üyenin okuma istatistiklerini (toplam ve aylık cüz sayıları) sıfırlar. Hesap ve gruplar kalır.
  static Future<void> resetReadingStats(String uid) => _db.collection('users').doc(uid).update(_zeroStats);

  /// Yönetici, üyenin toplam ve belirli bir aydaki cüz sayısını elle ayarlar.
  static Future<void> setReadCounts(String uid, {required int total, required String monthKey, required int month, required bool monthHadValue}) {
    final data = <String, Object>{'totalJuzRead': total < 0 ? 0 : total};
    if (month <= 0) {
      data['monthReads.$monthKey'] = FieldValue.delete();
      data['monthLast.$monthKey'] = FieldValue.delete();
    } else {
      data['monthReads.$monthKey'] = month;
      // Sıralamada eşitlik bozucu tarih yoksa şimdiki zamanı yaz.
      if (!monthHadValue) data['monthLast.$monthKey'] = FieldValue.serverTimestamp();
    }
    return _db.collection('users').doc(uid).update(data);
  }

  /// Birden çok üyenin okuma istatistiklerini sıfırlar (450'lik paketlerle).
  static Future<void> resetReadingStatsMany(Iterable<String> uids) async {
    final ids = uids.toList();
    for (var i = 0; i < ids.length; i += 450) {
      final batch = _db.batch();
      for (final id in ids.skip(i).take(450)) {
        batch.update(_db.collection('users').doc(id), _zeroStats);
      }
      await batch.commit();
    }
  }

  /// Üyeye şifre yenileme e-postası gönderir (şifreler hiçbir yerde görülemez).
  static Future<void> sendPasswordReset(String email) async {
    try {
      final auth = FirebaseAuth.instance;
      await auth.setLanguageCode(Lang.code);
      await auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw HatimException(e.message ?? lt('E-posta gönderilemedi.'));
    }
  }

  /// Bütün gruplar, en yenisi en üstte.
  static Stream<List<HatimGroup>> allGroups({int limit = 300}) => _db
      .collection('groups')
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(HatimGroup.fromDoc).toList());

  /// Grubu ve 30 cüz kaydını siler.
  static Future<void> deleteGroup(String gid) async {
    final juz = await _db.collection('juz').where('groupId', isEqualTo: gid).get();
    final batch = _db.batch();
    for (final d in juz.docs) {
      batch.delete(d.reference);
    }
    batch.delete(_db.collection('groups').doc(gid));
    await batch.commit();
  }
}
