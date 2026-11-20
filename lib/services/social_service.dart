import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../utils/format.dart';
import '../l10n/l10n.dart';

enum Relation { none, sent, received, friends }

/// Arkadaşlık istekleri, grup davetleri ve paylaşım.
class SocialService {
  static final _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get requests => _db.collection('friendRequests');
  static CollectionReference<Map<String, dynamic>> get invites => _db.collection('invites');

  /// Mağaza bağlantıları (paylaşım mesajlarına ikisi birden eklenir).
  static const playLink = 'https://play.google.com/store/apps/details?id=com.hatimkardesim.hatim_kardesim';
  static const appStoreLink = 'https://apps.apple.com/app/id6832353298';
  /// Paylaşılan tek bağlantı: önizlemede logo görünür, açan kişiyi telefonuna göre
  /// Google Play'e ya da App Store'a yönlendirir.
  static const appLink = 'https://sviappdeveloper-sketch.github.io/hatim-kardesim-site/indir.html';

  static String _pairId(String a, String b) => a.compareTo(b) < 0 ? '${a}_$b' : '${b}_$a';

  // ---------- Arkadaşlık ----------

  static Stream<Relation> relation(String me, String other) =>
      requests.doc(_pairId(me, other)).snapshots().map((d) {
        if (!d.exists) return Relation.none;
        final m = d.data()!;
        if (m['status'] == 'kabul') return Relation.friends;
        if (m['status'] == 'bekliyor') return m['fromUid'] == me ? Relation.sent : Relation.received;
        return Relation.none;
      });

  static Future<void> sendFriendRequest(AppUser me, String toUid, String toName) async {
    if (toUid == me.id) throw HatimException(lt('Kendinize arkadaşlık isteği gönderemezsiniz.'));
    final ref = requests.doc(_pairId(me.id, toUid));
    await _db.runTransaction((tx) async {
      final target = await tx.get(_db.collection('users').doc(toUid));
      if (target.data()?['friendRequestsOpen'] == false) {
        throw HatimException(lt('Bu kişi arkadaşlık isteklerini kapatmış.'));
      }
      final d = await tx.get(ref);
      if (d.exists && d.data()!['status'] != 'red') {
        throw HatimException(lt('Bu kişiyle zaten bir istek ya da arkadaşlık var.'));
      }
      tx.set(ref, {
        'fromUid': me.id,
        'fromName': me.name,
        'toUid': toUid,
        'toName': toName,
        'members': [me.id, toUid],
        'status': 'bekliyor',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Stream<List<FriendRequest>> incomingRequests(String me) => requests
      .where('toUid', isEqualTo: me)
      .snapshots()
      .map((s) => s.docs
          .where((d) => d.data()['status'] == 'bekliyor')
          .map((d) => FriendRequest(id: d.id, fromUid: d['fromUid'] as String, fromName: d['fromName'] as String))
          .toList());

  /// Gönderdiğim ve hâlâ bekleyen istekler.
  static Stream<List<SentFriendRequest>> outgoingRequests(String me) => requests
      .where('fromUid', isEqualTo: me)
      .snapshots()
      .map((s) => s.docs
          .where((d) => d.data()['status'] == 'bekliyor')
          .map((d) => SentFriendRequest(id: d.id, toUid: d['toUid'] as String, toName: (d.data()['toName'] ?? '') as String))
          .toList());

  /// Gönderdiğim arkadaşlık isteğini geri çeker. Karşı taraf bu arada kabul
  /// ettiyse arkadaşlığı silmez, hata verir.
  static Future<void> cancelFriendRequest(String me, String otherUid) async {
    final ref = requests.doc(_pairId(me, otherUid));
    await _db.runTransaction((tx) async {
      final d = await tx.get(ref);
      final m = d.data();
      if (!d.exists || m == null || m['status'] != 'bekliyor' || m['fromUid'] != me) {
        throw HatimException(lt('Bu istek artık beklemede değil.'));
      }
      tx.delete(ref);
    });
  }

  static Future<void> respond(String requestId, bool accept) =>
      requests.doc(requestId).update({'status': accept ? 'kabul' : 'red', 'respondedAt': FieldValue.serverTimestamp()});

  static Stream<List<Friend>> friends(String me) => requests
      .where('members', arrayContains: me)
      .snapshots()
      .map((s) => s.docs.where((d) => d.data()['status'] == 'kabul').map((d) {
            final m = d.data();
            final iSent = m['fromUid'] == me;
            return Friend(
              uid: (iSent ? m['toUid'] : m['fromUid']) as String,
              name: (iSent ? m['toName'] : m['fromName']) as String,
              requestId: d.id,
            );
          }).toList()
            ..sort((a, b) => a.name.compareTo(b.name)));

  static Future<void> removeFriend(String requestId) => requests.doc(requestId).delete();

  // ---------- Grup davetleri ----------

  static Future<void> sendGroupInvites(AppUser me, HatimGroup g, Iterable<Friend> to) async {
    if (to.isEmpty) return;
    final batch = _db.batch();
    for (final f in to) {
      batch.set(invites.doc('${g.id}_${f.uid}'), {
        'groupId': g.id,
        'groupName': g.name,
        'fromUid': me.id,
        'fromName': me.name,
        'toUid': f.uid,
        'status': 'bekliyor',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  static Stream<List<GroupInvite>> incomingInvites(String me) => invites
      .where('toUid', isEqualTo: me)
      .snapshots()
      .map((s) => s.docs
          .where((d) => d.data()['status'] == 'bekliyor')
          .map((d) => GroupInvite(
                id: d.id,
                groupId: d['groupId'] as String,
                groupName: d['groupName'] as String,
                fromName: d['fromName'] as String,
              ))
          .toList());

  static Future<void> markInviteSeen(String id) => invites.doc(id).update({'status': 'goruldu'});

  // ---------- Paylaşım ----------

  static Future<void> shareApp() => _share(
        lt('Hafız Kardeşim ile birlikte hatim okuyalım. Cüzünüzü alın, birlikte tamamlayalım.\n{0}', [appLink]),
        lt('Hafız Kardeşim'),
      );

  static Future<void> shareGroup(HatimGroup g) => _share(
        lt('"{0}" hatim grubuna sizi de bekliyoruz.\nHafız Kardeşim uygulamasında "Kodla katıl" bölümüne şu kodu yazın: {1}\n{2}', [g.name, g.code, appLink]),
        lt('Hatim davetiyesi'),
      );

  /// Paylaşım penceresi. iPhone/iPad'de pencerenin bağlanacağı bir konum (sharePositionOrigin)
  /// verilmezse "argument must be set" hatası çıkar. [context] verilirse basılan düğmenin yeri,
  /// verilmezse ekranın ortası kullanılır.
  static Future<void> paylas(String text, {String subject = '', BuildContext? context}) =>
      _share(text, subject, context: context);

  static Future<void> _share(String text, String subject, {BuildContext? context}) async {
    Rect? origin;
    try {
      final ro = context?.findRenderObject();
      if (ro is RenderBox && ro.hasSize && ro.attached) {
        final p = ro.localToGlobal(Offset.zero);
        if (ro.size.width > 0 && ro.size.height > 0) origin = p & ro.size;
      }
    } catch (_) {}
    if (origin == null) {
      final view = WidgetsBinding.instance.platformDispatcher.views.first;
      final size = view.physicalSize / view.devicePixelRatio;
      origin = Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: 2, height: 2);
    }
    try {
      await Share.share(text, subject: subject.isEmpty ? null : subject, sharePositionOrigin: origin);
    } catch (_) {
      // Paylaşım penceresi açılamazsa metni panoya kopyala.
      await Clipboard.setData(ClipboardData(text: text));
    }
  }
}
