import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import '../utils/format.dart';
import '../l10n/l10n.dart';

/// Destek / şikâyet / öneri yazışmaları, reklam talepleri ve katkı sunanlar.
class SupportService {
  static final _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get threads => _db.collection('supportThreads');
  static CollectionReference<Map<String, dynamic>> get adRequests => _db.collection('adRequests');
  static CollectionReference<Map<String, dynamic>> get sponsors => _db.collection('sponsors');
  static DocumentReference<Map<String, dynamic>> get settings => _db.collection('app').doc('support');

  static Map<String, String> get categories => {'destek': lt('Destek'), 'sikayet': lt('Şikâyet'), 'oneri': lt('Öneri')};
  static const defaultContactEmail = 'sviapp.developer@gmail.com';

  static Map<String, dynamic> _msg(String text, bool fromAdmin) =>
      {'text': text.trim(), 'fromAdmin': fromAdmin, 'at': Timestamp.now()};

  static void _checkText(String text) {
    if (text.trim().length < 5) throw HatimException(lt('Lütfen mesajınızı biraz daha açık yazın (en az 5 harf).'));
    if (text.trim().length > 2000) throw HatimException(lt('Mesaj en fazla 2000 karakter olabilir.'));
  }

  // ---------- Üye tarafı ----------

  static Stream<List<SupportThread>> myThreads(String uid) =>
      threads.where('uid', isEqualTo: uid).snapshots().map((s) {
        final l = s.docs.map(SupportThread.fromDoc).toList();
        l.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return l;
      });

  static Stream<SupportThread?> thread(String id) =>
      threads.doc(id).snapshots().map((d) => d.exists ? SupportThread.fromDoc(d) : null);

  static Future<void> create(AppUser me, String category, String text) async {
    _checkText(text);
    if (!categories.containsKey(category)) throw HatimException(lt('Lütfen destek, şikâyet veya öneri seçin.'));
    await threads.add({
      'uid': me.id,
      'name': me.name,
      'category': category,
      'messages': [_msg(text, false)],
      'unreadForAdmin': true,
      'unreadForUser': false,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> userReply(String threadId, String text) async {
    _checkText(text);
    await threads.doc(threadId).update({
      'messages': FieldValue.arrayUnion([_msg(text, false)]),
      'unreadForAdmin': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> markReadByUser(String threadId) => threads.doc(threadId).update({'unreadForUser': false});

  static Future<void> sendAdRequest({
    required AppUser me,
    required String company,
    required String detail,
    required Uint8List? image,
    required String imageType,
    required String link,
    required String phone,
    required int? durationDays,
  }) async {
    if (durationDays == null) throw HatimException(lt('Lütfen reklam süresini seçin.'));
    if (company.trim().length < 2) throw HatimException(lt('Firma / kişi adını yazın.'));
    if (image == null) throw HatimException(lt('Lütfen reklam görselini (resim ya da GIF) seçin.'));
    if (detail.trim().length < 10) throw HatimException(lt('Reklam açıklamasını biraz daha ayrıntılı yazın (en az 10 harf).'));
    final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.length < 10) throw HatimException(lt('Size ulaşabileceğimiz geçerli bir telefon numarası yazın.'));
    await adRequests.add({
      'uid': me.id,
      'name': me.name,
      'company': company.trim(),
      'detail': detail.trim(),
      'image': Blob(image),
      'imageType': imageType,
      'durationDays': durationDays,
      'link': link.trim(),
      'phone': digits,
      'status': 'yeni',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Yayındaki katkı sunanlar; süresi dolan reklamlar listeden kendiliğinden düşer.
  static Stream<List<Sponsor>> activeSponsors() =>
      sponsors.where('active', isEqualTo: true).snapshots().map((s) {
        final l = s.docs.map(Sponsor.fromDoc).where((sp) => !sp.expired).toList();
        l.sort((a, b) => a.order.compareTo(b.order));
        return l;
      });

  static Stream<Map<String, dynamic>> supportSettings() => settings.snapshots().map((d) => d.data() ?? const {});

  // ---------- Yönetici tarafı ----------

  static Stream<List<SupportThread>> allThreads() =>
      threads.orderBy('updatedAt', descending: true).limit(300).snapshots().map((s) => s.docs.map(SupportThread.fromDoc).toList());

  static Future<void> adminReply(String threadId, String text) async {
    _checkText(text);
    await threads.doc(threadId).update({
      'messages': FieldValue.arrayUnion([_msg(text, true)]),
      'unreadForUser': true,
      'unreadForAdmin': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> markReadByAdmin(String threadId) => threads.doc(threadId).update({'unreadForAdmin': false});

  static Stream<List<AdRequest>> allAdRequests() =>
      adRequests.orderBy('createdAt', descending: true).limit(300).snapshots().map((s) => s.docs.map(AdRequest.fromDoc).toList());

  static Future<void> setAdStatus(String id, String status) => adRequests.doc(id).update({'status': status});

  /// Talebi siler (yalnızca yönetici).
  static Future<void> deleteAdRequest(String id) => adRequests.doc(id).delete();

  /// Talebi onaylayıp katkı sunanlar listesinde yayınlar (yayın kararı yalnızca yöneticide).
  /// [days]: yayın süresi; boşsa talepteki süre kullanılır, o da yoksa süresiz yayınlanır.
  static Future<void> publishFromRequest(AdRequest r, {int? days}) async {
    final d = days ?? (r.durationDays > 0 ? r.durationDays : null);
    final batch = _db.batch();
    batch.set(sponsors.doc(), {
      'name': r.company,
      'imageUrl': r.imageUrl,
      if (r.image != null) 'image': Blob(r.image!),
      'detail': r.detail,
      if (d != null && d > 0) 'endAt': Timestamp.fromDate(DateTime.now().add(Duration(days: d))),
      'note': '',
      'link': r.link,
      'active': true,
      'order': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'fromRequest': r.id,
    });
    batch.update(adRequests.doc(r.id), {'status': 'yayinda'});
    await batch.commit();
  }

  static Stream<List<Sponsor>> allSponsors() => sponsors.snapshots().map((s) {
        final l = s.docs.map(Sponsor.fromDoc).toList();
        l.sort((a, b) => a.order.compareTo(b.order));
        return l;
      });

  static Future<void> saveSponsor(Sponsor sp) {
    final data = {
      'name': sp.name.trim(),
      'imageUrl': sp.imageUrl.trim(),
      'note': sp.note.trim(),
      'link': sp.link.trim(),
      'active': sp.active,
      'order': sp.order,
      'detail': sp.detail,
      if (sp.image != null) 'image': Blob(sp.image!),
    };
    return sp.id.isEmpty ? sponsors.add(data) : sponsors.doc(sp.id).set(data, SetOptions(merge: true));
  }

  static Future<void> setSponsorActive(String id, bool active) => sponsors.doc(id).update({'active': active});
  static Future<void> deleteSponsor(String id) => sponsors.doc(id).delete();

  static Future<void> saveSettings(Map<String, dynamic> data) => settings.set(data, SetOptions(merge: true));
}
