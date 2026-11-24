import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'constants.dart';

DateTime? _ts(dynamic v) => v is Timestamp ? v.toDate() : null;
int _int(dynamic v) => v is num ? v.toInt() : 0;

class AppUser {
  AppUser({required this.id, required this.name, required this.gender, this.totalJuzRead = 0, this.hatimsJoined = 0, this.monthReads = const {}, this.monthLast = const {}, this.blocked = false, this.createdAt, this.duaRead = const {}, this.friendRequestsOpen = true, this.hafizRol = ''});
  final String id;
  final String name;
  final String gender;
  final int totalJuzRead;
  final Map<String, int> monthReads;
  int readsIn(String monthKey) => monthReads[monthKey] ?? 0;
  final Map<String, DateTime> monthLast;
  /// Yönetici tarafından engellenmiş üye.
  final bool blocked;
  /// Başkaları bu kişiye arkadaşlık isteği gönderebilir mi (profil ayarı, varsayılan açık).
  final bool friendRequestsOpen;
  /// Hafız mı (HafizRol.hafiz) talebe mi (HafizRol.talebe); seçilmediyse boş.
  final String hafizRol;
  /// Hangi grubun kaçıncı hatminin duasını okuduğu: grupId → hatim sayısı.
  final Map<String, int> duaRead;
  bool hasReadDua(HatimGroup g) => (duaRead[g.id] ?? 0) >= g.hatimCount;

  /// Son tamamlanan hatmin duası bu kişi için bekliyor mu (yeni hatim açılmış olsa da)?
  bool duaPending(HatimGroup g) => g.duaAvailableFor(id) && !hasReadDua(g);
  final DateTime? createdAt;
  DateTime? lastReadIn(String monthKey) => monthLast[monthKey];
  final int hatimsJoined;

  String get firstName => name.trim().split(' ').first;

  /// Misafir girişiyle gelen kullanıcı: üye özellikleri (arkadaş, grup kurma, davet…) kapalıdır.
  bool get isGuest => gender == Gender.guest;

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return AppUser(
      id: d.id,
      name: (m['name'] ?? '') as String,
      gender: (m['gender'] ?? '') as String,
      totalJuzRead: _int(m['totalJuzRead']),
      monthReads: ((m['monthReads'] ?? const {}) as Map).map((k, v) => MapEntry(k as String, _int(v))),
      monthLast: {
        for (final e in ((m['monthLast'] ?? const {}) as Map).entries)
          if (e.value is Timestamp) e.key as String: (e.value as Timestamp).toDate(),
      },
      hatimsJoined: _int(m['hatimsJoined']),
      blocked: m['blocked'] == true,
      duaRead: ((m['duaRead'] ?? const {}) as Map).map((k, v) => MapEntry(k as String, _int(v))),
      createdAt: _ts(m['createdAt']),
      friendRequestsOpen: m['friendRequestsOpen'] != false,
      hafizRol: (m['hafizRol'] ?? '') is String ? (m['hafizRol'] ?? '') as String : '',
    );
  }
}

class HatimGroup {
  HatimGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.code,
    required this.creatorId,
    required this.creatorName,
    required this.genderType,
    required this.durationDays,
    required this.status,
    required this.memberIds,
    required this.memberNames,
    required this.juzCounts,
    required this.takenCount,
    required this.doneCount,
    required this.hatimCount,
    required this.createdAt,
    this.startAt,
    this.endAt,
    this.finishedAt,
    this.locked = false,
    this.joinRequests = const {},
    this.prevReaders = const [],
  });

  /// Yeni hatim açılmadan önceki (tamamlanan) hatimde cüz okuyanlar ve grubu kuran.
  /// Yeni hatme geçilse de bu kişiler önceki hatmin duasını okuyabilir.
  final List<String> prevReaders;

  /// Bu kişi son tamamlanan hatmin duasını okuyabilir mi?
  bool duaAvailableFor(String uid) =>
      hatimCount > 0 && (isCompleted ? memberIds.contains(uid) : prevReaders.contains(uid));

  final String id, name, description, code, creatorId, creatorName, genderType, status;

  /// Kilitli grup: yalnızca grubu kuranın onayıyla katılınır.
  final bool locked;

  /// Kilitli gruba katılma istekleri (uid → ad).
  final Map<String, String> joinRequests;
  final int durationDays, takenCount, doneCount, hatimCount;
  final List<String> memberIds;
  final Map<String, String> memberNames;
  final Map<String, int> juzCounts;
  final DateTime createdAt;
  final DateTime? startAt, endAt, finishedAt;

  bool get isForming => status == GroupStatus.forming;
  bool get isActive => status == GroupStatus.active;
  bool get isCompleted => status == GroupStatus.completed;
  bool get isFull => takenCount >= totalJuz;
  bool get allRead => doneCount >= totalJuz;
  int get readerCount => juzCounts.values.where((v) => v > 0).length;
  bool get isPastDeadline => endAt != null && DateTime.now().isAfter(endAt!);
  bool isCreator(String uid) => uid == creatorId;
  bool isMember(String uid) => memberIds.contains(uid);
  bool hasRequested(String uid) => joinRequests.containsKey(uid);
  int get memberCount => memberIds.length;
  bool get membersFull => memberIds.length >= maxMembers;

  factory HatimGroup.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return HatimGroup(
      id: d.id,
      name: (m['name'] ?? '') as String,
      description: (m['description'] ?? '') as String,
      code: (m['code'] ?? '') as String,
      creatorId: (m['creatorId'] ?? '') as String,
      creatorName: (m['creatorName'] ?? '') as String,
      genderType: (m['genderType'] ?? GenderType.mixed) as String,
      durationDays: _int(m['durationDays']),
      status: (m['status'] ?? GroupStatus.forming) as String,
      memberIds: List<String>.from((m['memberIds'] ?? const []) as List),
      memberNames: Map<String, String>.from((m['memberNames'] ?? const {}) as Map),
      juzCounts: ((m['juzCounts'] ?? const {}) as Map).map((k, v) => MapEntry(k as String, _int(v))),
      takenCount: _int(m['takenCount']),
      doneCount: _int(m['doneCount']),
      hatimCount: _int(m['hatimCount']),
      createdAt: _ts(m['createdAt']) ?? DateTime.now(),
      startAt: _ts(m['startAt']),
      endAt: _ts(m['endAt']),
      finishedAt: _ts(m['finishedAt']),
      locked: (m['locked'] ?? false) as bool,
      joinRequests: Map<String, String>.from((m['joinRequests'] ?? const {}) as Map),
      prevReaders: List<String>.from((m['prevReaders'] ?? const []) as List),
    );
  }
}

class Juz {
  Juz({
    required this.number,
    required this.status,
    required this.groupId,
    required this.groupName,
    this.uid,
    this.userName,
    this.endAt,
    this.takenAt,
    this.updatedAt,
    this.volunteer = false,
  });

  final int number;
  final String status, groupId, groupName;
  final String? uid, userName;
  final DateTime? endAt, takenAt, updatedAt;
  final bool volunteer;
  String get id => '${groupId}_$number';

  bool get isEmpty => status == JuzStatus.empty;
  bool get isDone => status == JuzStatus.done;
  bool isMine(String me) => uid == me;
  bool get isOverdue => endAt != null && !isDone && !isEmpty && DateTime.now().isAfter(endAt!);

  factory Juz.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Juz(
      number: _int(m['number']),
      status: (m['status'] ?? JuzStatus.empty) as String,
      groupId: (m['groupId'] ?? '') as String,
      groupName: (m['groupName'] ?? '') as String,
      uid: m['uid'] as String?,
      userName: m['userName'] as String?,
      endAt: _ts(m['endAt']),
      takenAt: _ts(m['takenAt']),
      updatedAt: _ts(m['updatedAt']),
      volunteer: (m['volunteer'] ?? false) as bool,
    );
  }
}

class Friend {
  Friend({required this.uid, required this.name, required this.requestId});
  final String uid, name, requestId;
}

class FriendRequest {
  FriendRequest({required this.id, required this.fromUid, required this.fromName});
  final String id, fromUid, fromName;
}

/// Benim gönderdiğim, henüz yanıtlanmamış arkadaşlık isteği.
class SentFriendRequest {
  SentFriendRequest({required this.id, required this.toUid, required this.toName});
  final String id, toUid, toName;
}

class GroupInvite {
  GroupInvite({required this.id, required this.groupId, required this.groupName, required this.fromName});
  final String id, groupId, groupName, fromName;
}

class Sponsor {
  Sponsor({this.id = '', required this.name, required this.imageUrl, required this.note, required this.link,
      this.active = true, this.order = 0, this.image, this.detail = '', this.endAt});
  final String id, name, imageUrl, note, link;
  final bool active;
  final int order;
  /// Yüklenen reklam görseli (JPEG ya da GIF); yoksa [imageUrl] kullanılır.
  final Uint8List? image;
  /// Detay sayfasında görünen açıklama.
  final String detail;
  /// Yayın bitişi; geçince reklam listede gösterilmez. Boşsa süresiz.
  final DateTime? endAt;
  bool get expired => endAt != null && endAt!.isBefore(DateTime.now());
  factory Sponsor.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Sponsor(
      id: d.id,
      name: (m['name'] ?? '') as String,
      imageUrl: (m['imageUrl'] ?? '') as String,
      note: (m['note'] ?? '') as String,
      link: (m['link'] ?? '') as String,
      active: (m['active'] ?? false) as bool,
      order: _int(m['order']),
      image: m['image'] is Blob ? (m['image'] as Blob).bytes : null,
      detail: (m['detail'] ?? '') as String,
      endAt: _ts(m['endAt']),
    );
  }
}

/// Arkadaşın cüzüne bırakılan tebrik: yalnızca hazır emoji veya hazır cümle.
class Reaction {
  Reaction({required this.id, required this.juzId, required this.juzNumber, required this.groupName,
      required this.fromUid, required this.fromName, required this.toUid, required this.text, required this.createdAt});
  final String id, juzId, groupName, fromUid, fromName, toUid, text;
  final int juzNumber;
  final DateTime createdAt;
  factory Reaction.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Reaction(
      id: d.id,
      juzId: (m['juzId'] ?? '') as String,
      juzNumber: _int(m['juzNumber']),
      groupName: (m['groupName'] ?? '') as String,
      fromUid: (m['fromUid'] ?? '') as String,
      fromName: (m['fromName'] ?? '') as String,
      toUid: (m['toUid'] ?? '') as String,
      text: (m['text'] ?? '') as String,
      createdAt: _ts(m['createdAt']) ?? DateTime.now(),
    );
  }
}

class SupportMessage {
  SupportMessage({required this.fromAdmin, required this.text, required this.at});
  final bool fromAdmin;
  final String text;
  final DateTime at;
}

/// Üyenin bize ilettiği destek / şikâyet / öneri yazışması.
class SupportThread {
  SupportThread({required this.id, required this.uid, required this.name, required this.category,
      required this.messages, required this.updatedAt, required this.unreadForUser, required this.unreadForAdmin});
  final String id, uid, name, category;
  final List<SupportMessage> messages;
  final DateTime updatedAt;
  final bool unreadForUser, unreadForAdmin;
  factory SupportThread.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return SupportThread(
      id: d.id,
      uid: (m['uid'] ?? '') as String,
      name: (m['name'] ?? '') as String,
      category: (m['category'] ?? 'destek') as String,
      messages: [
        for (final x in (m['messages'] ?? const []) as List)
          SupportMessage(
            fromAdmin: (x['fromAdmin'] ?? false) as bool,
            text: (x['text'] ?? '') as String,
            at: _ts(x['at']) ?? DateTime.now(),
          )
      ],
      updatedAt: _ts(m['updatedAt']) ?? DateTime.now(),
      unreadForUser: (m['unreadForUser'] ?? false) as bool,
      unreadForAdmin: (m['unreadForAdmin'] ?? false) as bool,
    );
  }
}

/// Reklam / katkı talebi. Telefon numarasını yalnızca yönetici görür.
class AdRequest {
  AdRequest({required this.id, required this.uid, required this.company, required this.detail,
      required this.imageUrl, required this.link, required this.phone, required this.status, required this.createdAt,
      this.image, this.imageType = '', this.durationDays = 0});
  final String id, uid, company, detail, imageUrl, link, phone, status, imageType;
  /// İstenen yayın süresi (gün); 0 = özel süre (reklam verenle görüşülür).
  final int durationDays;
  final DateTime createdAt;
  final Uint8List? image;
  factory AdRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return AdRequest(
      id: d.id,
      uid: (m['uid'] ?? '') as String,
      company: (m['company'] ?? '') as String,
      detail: (m['detail'] ?? '') as String,
      imageUrl: (m['imageUrl'] ?? '') as String,
      link: (m['link'] ?? '') as String,
      phone: (m['phone'] ?? '') as String,
      status: (m['status'] ?? 'yeni') as String,
      createdAt: _ts(m['createdAt']) ?? DateTime.now(),
      image: m['image'] is Blob ? (m['image'] as Blob).bytes : null,
      imageType: (m['imageType'] ?? '') as String,
      durationDays: _int(m['durationDays']),
    );
  }
}
