import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/constants.dart';
import '../models/models.dart';
import '../utils/format.dart';
import 'auth_service.dart';
import '../l10n/l10n.dart';

/// Hatim gruplarının bütün kuralları burada uygulanır.
///
/// Akış:
/// - Grup kurulunca cüzler dağıtılmaya başlar; cüzünü alan hemen okumaya başlayabilir.
/// - Her cüzün süresi, alındığı andan itibaren grubun süresi kadardır.
/// - Süresi dolduğu hâlde okunmayan cüz, başka biri tarafından yeniden alınabilir.
/// - 30 cüzün tamamı okununca grubu kuran hatmi bitirir ve hatim duası açılır.
class HatimService {
  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get groups => _db.collection('groups');
  static DocumentReference<Map<String, dynamic>> get statsRef => _db.collection('stats').doc('global');

  /// Cüzler tek bir koleksiyonda tutulur (belge kimliği: grupId_cüzNo).
  static CollectionReference<Map<String, dynamic>> get juzCol => _db.collection('juz');
  static DocumentReference<Map<String, dynamic>> _juzRef(String gid, int n) => juzCol.doc('${gid}_$n');

  /// Ayın en çok okuyanı için ay anahtarı, ör. m202611.
  static String monthKey([DateTime? d]) {
    final t = d ?? DateTime.now();
    return 'm${t.year}${t.month.toString().padLeft(2, '0')}';
  }

  // ---------- Okuma ----------

  static Stream<List<HatimGroup>> myGroups(String uid) =>
      groups.where('memberIds', arrayContains: uid).snapshots().map((s) {
        final list = s.docs.map(HatimGroup.fromDoc).toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });

  /// Katılınabilecek gruplar: tamamlanmamış ve üye yeri boş olanlar (en yeni 300 grup içinden).
  /// Sıralama ve isimle arama ekranda yapılır.
  static Future<List<HatimGroup>> joinableGroups() async {
    final s = await groups.orderBy('createdAt', descending: true).limit(300).get();
    return s.docs.map(HatimGroup.fromDoc).where((g) => !g.isCompleted && !g.membersFull).toList();
  }

  static Stream<HatimGroup?> group(String id) =>
      groups.doc(id).snapshots().map((d) => d.exists ? HatimGroup.fromDoc(d) : null);

  static Stream<List<Juz>> juzList(String id) => juzCol.where('groupId', isEqualTo: id).snapshots().map((s) {
        final list = s.docs.map(Juz.fromDoc).toList();
        list.sort((a, b) => a.number.compareTo(b.number));
        return list;
      });

  /// Bir kişinin bütün gruplardaki cüzleri (arkadaş profili için).
  static Stream<List<Juz>> juzOf(String uid) => juzCol.where('uid', isEqualTo: uid).snapshots().map((s) {
        final list = s.docs.map(Juz.fromDoc).toList();
        list.sort((a, b) => (b.updatedAt ?? DateTime(2000)).compareTo(a.updatedAt ?? DateTime(2000)));
        return list;
      });

  static Future<String?> findByCode(String code) async {
    final q = await groups.where('code', isEqualTo: code.trim().toUpperCase()).limit(1).get();
    return q.docs.isEmpty ? null : q.docs.first.id;
  }

  /// Kullanıcının süresi geçmiş ve henüz okunmamış cüzleri (tüm gruplarda).
  static Future<List<Juz>> overdueJuzOf(String uid) async {
    final q = await juzCol.where('uid', isEqualTo: uid).get();
    return q.docs.map(Juz.fromDoc).where((j) => j.isOverdue).toList();
  }

  /// Ayın en çok cüz okuyanı.
  /// Bir ayın en çok cüz okuyanları. Eşit sayıda okuyanlardan o sayıya önce ulaşan üstte yer alır.
  static Stream<List<AppUser>> topReaders(String key, {int count = 10}) => _db
      .collection('users')
      .orderBy('monthReads.$key', descending: true)
      .limit(count + 20)
      .snapshots()
      .map((s) {
        final list = s.docs.map(AppUser.fromDoc).where((u) => u.readsIn(key) > 0).toList();
        list.sort((a, b) {
          final c = b.readsIn(key).compareTo(a.readsIn(key));
          if (c != 0) return c;
          final ta = a.lastReadIn(key), tb = b.lastReadIn(key);
          if (ta == null && tb == null) return 0;
          if (ta == null) return 1;
          if (tb == null) return -1;
          return ta.compareTo(tb);
        });
        return list.take(count).toList();
      });

  static Stream<AppUser?> topReaderOfMonth() =>
      topReaders(monthKey(), count: 1).map((l) => l.isEmpty ? null : l.first);

  // ---------- Kurallar ----------

  static void _checkGender(HatimGroup g, AppUser me) {
    if (!GenderType.allows(g.genderType, me.gender)) {
      throw HatimException(lt('Bu grup "{0}" için açılmış.', [GenderType.label(g.genderType)]));
    }
  }

  /// Süresi dolmuş cüzünü bitirmeyen, başka gruptan cüz alamaz.
  static Future<void> _ensureNotOverdue(String uid, String groupId) async {
    final overdue = (await overdueJuzOf(uid)).where((j) => j.groupId != groupId).toList();
    if (overdue.isNotEmpty) {
      final j = overdue.first;
      throw HatimException(
          lt('"{0}" grubundaki {1}. cüzünüzün süresi doldu. Yeni cüz almadan önce onu tamamlamalısınız.', [j.groupName, j.number]));
    }
  }

  /// Grup kurma şartı: en az 3 cüz okumuş olmak ve okunmayı bekleyen cüzü olmamak.
  /// Yönetici bu şarttan muaftır (ilk grupları açabilmek için).
  static Future<String?> whyCannotCreate(AppUser me) async {
    if (!groupCreationRequirement || AuthService.isAdmin) return null;
    if (me.totalJuzRead < minJuzToCreateGroup) {
      return lt('Grup kurabilmek için önce başka gruplarda en az {0} cüz okumalısınız (şu an {1}).', [minJuzToCreateGroup, me.totalJuzRead]);
    }
    final q = await juzCol.where('uid', isEqualTo: me.id).get();
    final pending = q.docs.map(Juz.fromDoc).where((j) => !j.isDone && !j.isEmpty).toList();
    if (pending.isNotEmpty) {
      final j = pending.first;
      return lt('Grup kurmadan önce aldığınız cüzleri tamamlamalısınız: "{0}" grubunda {1}. cüz{2}.', [j.groupName, j.number, pending.length > 1 ? lt(' ve {0} cüz daha', [pending.length - 1]) : '']);
    }
    return null;
  }

  static String _newCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = math.Random.secure();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }

  // ---------- Grup kurma ----------

  static Future<HatimGroup> createGroup({
    required AppUser me,
    required String name,
    required String description,
    required int durationDays,
    required String genderType,
  }) async {
    if (me.isGuest) throw HatimException(lt('Grup kurmak için üye olmanız gerekiyor.'));
    if (name.trim().length < 3) throw HatimException(lt('Grup adı en az 3 harf olmalı.'));
    if (durationDays < minDurationDays) throw HatimException(lt('Hatim süresi en az {0} gün olmalı.', [minDurationDays]));
    if (!GenderType.allows(genderType, me.gender)) {
      throw HatimException(lt('Katılamayacağınız bir grup türü seçtiniz.'));
    }
    final why = await whyCannotCreate(me);
    if (why != null) throw HatimException(why);
    final ref = groups.doc();
    final batch = _db.batch();
    batch.set(ref, {
      'name': name.trim(),
      'description': description.trim(),
      'code': _newCode(),
      'creatorId': me.id,
      'creatorName': me.name,
      'genderType': genderType,
      'durationDays': durationDays,
      'status': GroupStatus.forming,
      'memberIds': [me.id],
      'memberNames': {me.id: me.name},
      'juzCounts': <String, int>{},
      'takenCount': 0,
      'doneCount': 0,
      'hatimCount': 0,
      'locked': false,
      'joinRequests': <String, String>{},
      'startAt': Timestamp.fromDate(DateTime.now()),
      'endAt': Timestamp.fromDate(DateTime.now().add(Duration(days: durationDays))),
      'createdAt': FieldValue.serverTimestamp(),
    });
    for (var n = 1; n <= totalJuz; n++) {
      batch.set(_juzRef(ref.id, n), {
        'number': n,
        'groupId': ref.id,
        'groupName': name.trim(),
        'uid': null,
        'userName': null,
        'status': JuzStatus.empty,
        'endAt': null,
        'volunteer': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    batch.set(statsRef, {'groupsCreated': FieldValue.increment(1)}, SetOptions(merge: true));
    await batch.commit();
    return HatimGroup.fromDoc(await ref.get());
  }

  // ---------- Cüz alma (tek veya çoklu) ----------

  static Future<void> takeJuz(String gid, int n, AppUser me) => takeJuzMany(gid, [n], me);

  /// Seçilen boş cüzleri tek seferde alır. Biri bile alınamazsa hiçbiri alınmaz.
  static Future<void> takeJuzMany(String gid, List<int> numbers, AppUser me) async {
    if (numbers.isEmpty) return;
    await _ensureNotOverdue(me.id, gid);
    final gRef = groups.doc(gid);
    final refs = [for (final n in numbers) _juzRef(gid, n)];
    await _db.runTransaction((tx) async {
      final g = HatimGroup.fromDoc(await tx.get(gRef));
      final juz = [for (final r in refs) Juz.fromDoc(await tx.get(r))];
      if (g.isCompleted) throw HatimException(lt('Bu hatim tamamlandı.'));
      _checkGender(g, me);
      _checkCanJoin(g, me);
      final taken = juz.where((j) => !j.isEmpty).map((j) => j.number).toList();
      if (taken.isNotEmpty) {
        throw HatimException(lt('{0}. cüz{1} az önce başka biri tarafından alındı.', [taken.join(', '), taken.length > 1 ? 'ler' : '']));
      }
      final mine = g.juzCounts[me.id] ?? 0;
      if (mine + numbers.length > maxJuzPerPerson) {
        throw HatimException(lt('{0} Bu gruptan şu ana kadar {1} cüz aldınız; {2} cüz daha alabilirsiniz.', [juzLimitText, mine, maxJuzPerPerson - mine]));
      }
      final now = DateTime.now();
      // Cüzün teslim tarihi = hatmin bitiş tarihi (cüze ayrı süre verilmez).
      final groupEnd = g.endAt ?? now.add(Duration(days: g.durationDays));
      final end = Timestamp.fromDate(_juzEnd(groupEnd, now));
      for (final r in refs) {
        tx.update(r, {
          'uid': me.id,
          'userName': me.name,
          'status': JuzStatus.taken,
          'takenAt': Timestamp.fromDate(now),
          'endAt': end,
          'volunteer': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      final newTaken = g.takenCount + numbers.length;
      tx.update(gRef, {
        'takenCount': FieldValue.increment(numbers.length),
        'juzCounts.${me.id}': FieldValue.increment(numbers.length),
        'memberIds': FieldValue.arrayUnion([me.id]),
        'memberNames.${me.id}': me.name,
        if (g.startAt == null) 'startAt': Timestamp.fromDate(now),
        if (g.endAt == null) 'endAt': Timestamp.fromDate(groupEnd),
        if (newTaken >= totalJuz) 'status': GroupStatus.active,
      });
    });
  }

  /// Henüz okumaya başlanmamış cüz bırakılabilir.
  static Future<void> releaseJuz(String gid, int n, AppUser me) async {
    final gRef = groups.doc(gid);
    final jRef = _juzRef(gid, n);
    await _db.runTransaction((tx) async {
      final g = HatimGroup.fromDoc(await tx.get(gRef));
      final j = Juz.fromDoc(await tx.get(jRef));
      if (!j.isMine(me.id)) throw HatimException(lt('Bu cüz size ait değil.'));
      if (j.status != JuzStatus.taken) throw HatimException(lt('Okumaya başladığınız cüzü bırakamazsınız.'));
      tx.update(jRef, {
        'uid': null,
        'userName': null,
        'status': JuzStatus.empty,
        'endAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.update(gRef, {
        'takenCount': FieldValue.increment(-1),
        'juzCounts.${me.id}': FieldValue.increment(-1),
        if (g.isActive) 'status': GroupStatus.forming,
      });
    });
  }

  // ---------- Okuma durumu ----------

  static Future<void> setJuzStatus(String gid, int n, AppUser me, String status) async {
    final gRef = groups.doc(gid);
    final jRef = _juzRef(gid, n);
    final uRef = _db.collection('users').doc(me.id);
    await _db.runTransaction((tx) async {
      final g = HatimGroup.fromDoc(await tx.get(gRef));
      final j = Juz.fromDoc(await tx.get(jRef));
      if (g.isCompleted) throw HatimException(lt('Bu hatim tamamlandı.'));
      if (!j.isMine(me.id)) throw HatimException(lt('Bu cüz size ait değil.'));
      if (j.isDone) throw HatimException(lt('Bu cüzü zaten okundu olarak işaretlediniz.'));
      tx.update(jRef, {
        'status': status,
        if (status == JuzStatus.done) 'doneAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (status == JuzStatus.done) {
        // Son cüz okununca hatim kendiliğinden tamamlanır; son tarih ya da kurucu beklenmez.
        final allDone = g.doneCount + 1 >= totalJuz;
        tx.update(gRef, {
          'doneCount': FieldValue.increment(1),
          if (allDone) 'status': GroupStatus.completed,
          if (allDone) 'hatimCount': FieldValue.increment(1),
          if (allDone) 'finishedAt': FieldValue.serverTimestamp(),
        });
        if (allDone) tx.set(statsRef, {'hatimsCompleted': FieldValue.increment(1)}, SetOptions(merge: true));
        tx.update(uRef, {
          'totalJuzRead': FieldValue.increment(1),
          'monthReads.${monthKey()}': FieldValue.increment(1),
          // Eşitlikte sıralama için: bu ay son cüzün okunduğu an.
          'monthLast.${monthKey()}': FieldValue.serverTimestamp(),
        });
        tx.set(statsRef, {'juzRead': FieldValue.increment(1)}, SetOptions(merge: true));
      }
    });
  }

  // ---------- Süresi dolan cüzü yeniden alma ----------

  /// Süresi dolduğu hâlde okunmamış bir cüzü, sahibinden farklı biri yeniden alır.
  static Future<void> volunteer(String gid, int n, AppUser me) async {
    await _ensureNotOverdue(me.id, gid);
    final gRef = groups.doc(gid);
    final jRef = _juzRef(gid, n);
    await _db.runTransaction((tx) async {
      final g = HatimGroup.fromDoc(await tx.get(gRef));
      final j = Juz.fromDoc(await tx.get(jRef));
      if (g.isCompleted) throw HatimException(lt('Bu hatim tamamlandı.'));
      if (j.isDone) throw HatimException(lt('Bu cüz zaten okundu.'));
      if (j.isMine(me.id)) throw HatimException(lt('Kendi cüzünüzü yeniden alamazsınız; okumayı tamamlayın.'));
      if (!j.isOverdue) throw HatimException(lt('Bu cüzün süresi henüz dolmadı.'));
      _checkGender(g, me);
      _checkCanJoin(g, me);
      if ((g.juzCounts[me.id] ?? 0) >= maxJuzPerPerson) {
        throw HatimException(juzLimitText);
      }
      final now = DateTime.now();
      final newEnd = Timestamp.fromDate(_juzEnd(g.endAt ?? now.add(Duration(days: g.durationDays)), now));
      tx.update(jRef, {
        'uid': me.id,
        'userName': me.name,
        'status': JuzStatus.taken,
        'volunteer': true,
        'previousUid': j.uid,
        'takenAt': Timestamp.fromDate(now),
        'endAt': newEnd,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.update(gRef, {
        if (j.uid != null) 'juzCounts.${j.uid}': FieldValue.increment(-1),
        'juzCounts.${me.id}': FieldValue.increment(1),
        'memberIds': FieldValue.arrayUnion([me.id]),
        'memberNames.${me.id}': me.name,
      });
    });
  }

  /// Cüzün teslim tarihi hatmin bitiş tarihidir. Hatmin süresi geçmişse (gecikmiş hatim)
  /// cüzü alan kişiye okuyabilmesi için en az [volunteerDays] gün tanınır.
  static DateTime _juzEnd(DateTime groupEnd, DateTime now) {
    final minEnd = now.add(const Duration(days: volunteerDays));
    return groupEnd.isAfter(now) ? groupEnd : minEnd;
  }

  // ---------- Katılma, ayrılma, kilit ----------

  /// Üye değilse gruba girebilir mi? (Cüz alırken kendiliğinden katılınır.)
  static void _checkCanJoin(HatimGroup g, AppUser me) {
    if (me.isGuest && (g.genderType != GenderType.mixed || g.locked)) {
      throw HatimException(lt('Misafir olarak yalnızca herkese açık ve kilitsiz gruplardan cüz alabilirsiniz. Bütün özellikler için üye olun.'));
    }
    if (g.isMember(me.id)) return;
    if (g.locked) {
      throw HatimException(lt('Bu grup kilitli. Cüz alabilmek için önce katılma isteği gönderin; grubu kuran onaylayınca katılırsınız.'));
    }
    if (g.membersFull) throw HatimException(lt('Bu grup dolu. Bir gruba en fazla {0} kişi katılabilir.', [maxMembers]));
  }

  static Future<void> joinGroup(String gid, AppUser me) async {
    final gRef = groups.doc(gid);
    await _db.runTransaction((tx) async {
      final g = HatimGroup.fromDoc(await tx.get(gRef));
      if (g.isMember(me.id)) return;
      _checkGender(g, me);
      _checkCanJoin(g, me);
      tx.update(gRef, {
        'memberIds': FieldValue.arrayUnion([me.id]),
        'memberNames.${me.id}': me.name,
        'joinRequests.${me.id}': FieldValue.delete(),
      });
    });
  }

  /// Kilitli gruba katılma isteği.
  static Future<void> requestJoin(String gid, AppUser me) async {
    final gRef = groups.doc(gid);
    await _db.runTransaction((tx) async {
      final g = HatimGroup.fromDoc(await tx.get(gRef));
      if (g.isMember(me.id)) throw HatimException(lt('Zaten bu grubun üyesisiniz.'));
      _checkGender(g, me);
      if (g.membersFull) throw HatimException(lt('Bu grup dolu. Bir gruba en fazla {0} kişi katılabilir.', [maxMembers]));
      tx.update(gRef, {'joinRequests.${me.id}': me.name});
    });
  }

  static Future<void> cancelRequest(String gid, AppUser me) =>
      groups.doc(gid).update({'joinRequests.${me.id}': FieldValue.delete()});

  /// Grubu kuran, katılma isteğini kabul eder ya da reddeder.
  static Future<void> answerRequest(String gid, String uid, bool accept, AppUser me) async {
    final gRef = groups.doc(gid);
    await _db.runTransaction((tx) async {
      final g = HatimGroup.fromDoc(await tx.get(gRef));
      if (!g.isCreator(me.id)) throw HatimException(lt('İstekleri yalnızca grubu kuran yanıtlayabilir.'));
      final name = g.joinRequests[uid];
      if (name == null) return;
      if (accept && g.membersFull) throw HatimException(lt('Grup dolu (en fazla {0} kişi).', [maxMembers]));
      tx.update(gRef, {
        'joinRequests.$uid': FieldValue.delete(),
        if (accept) 'memberIds': FieldValue.arrayUnion([uid]),
        if (accept) 'memberNames.$uid': name,
      });
    });
  }

  /// Gruptan ayrılma. Elinde okunmamış cüz varsa önce bırakılması ya da okunması gerekir.
  static Future<void> leaveGroup(String gid, AppUser me) async {
    final gRef = groups.doc(gid);
    final mine = await juzCol.where('groupId', isEqualTo: gid).where('uid', isEqualTo: me.id).get();
    final open = mine.docs.map(Juz.fromDoc).where((j) => !j.isDone && !j.isEmpty).toList();
    await _db.runTransaction((tx) async {
      final g = HatimGroup.fromDoc(await tx.get(gRef));
      if (g.isCreator(me.id)) throw HatimException(lt('Grubu kuran gruptan ayrılamaz.'));
      if (!g.isMember(me.id)) return;
      if (open.isNotEmpty && !g.isCompleted) {
        final nums = (open.map((j) => j.number).toList()..sort()).join(', ');
        throw HatimException(lt('Elinizde okunmamış cüz var ({0}). Ayrılmadan önce bu cüzleri bırakın ya da okumayı tamamlayın.', [nums]));
      }
      tx.update(gRef, {
        'memberIds': FieldValue.arrayRemove([me.id]),
        'memberNames.${me.id}': FieldValue.delete(),
      });
    });
  }

  static Future<void> setLocked(String gid, bool locked, AppUser me) async {
    final gRef = groups.doc(gid);
    final g = HatimGroup.fromDoc(await gRef.get());
    if (!g.isCreator(me.id)) throw HatimException(lt('Grubu yalnızca kuran kişi kilitleyebilir.'));
    await gRef.update({'locked': locked});
  }

  // ---------- Bitirme ----------

  /// 30 cüzün tamamı okunmuş ama henüz tamamlanmamış hatmi (eski sürümden kalan) tamamlar.
  /// Grubu gören herkes tetikleyebilir.
  static Future<bool> completeIfAllRead(String gid) async {
    final gRef = groups.doc(gid);
    return _db.runTransaction<bool>((tx) async {
      final g = HatimGroup.fromDoc(await tx.get(gRef));
      if (g.isCompleted || !g.allRead) return false;
      tx.update(gRef, {
        'status': GroupStatus.completed,
        'hatimCount': FieldValue.increment(1),
        'finishedAt': FieldValue.serverTimestamp(),
      });
      tx.set(statsRef, {'hatimsCompleted': FieldValue.increment(1)}, SetOptions(merge: true));
      return true;
    });
  }

  /// Üye, tamamlanan hatmin duasını okudu.
  static Future<void> markDuaRead(String uid, String gid, int hatimCount) =>
      _db.collection('users').doc(uid).set({'duaRead': {gid: hatimCount}}, SetOptions(merge: true));

  /// Tamamlanan grupta aynı kadroyla yeni bir hatim açar.
  static Future<void> restartHatim(String gid, AppUser me) async {
    final gRef = groups.doc(gid);
    final g = HatimGroup.fromDoc(await gRef.get());
    if (!g.isCreator(me.id)) throw HatimException(lt('Yeni hatmi yalnızca grubu kuran açabilir.'));
    if (!g.isCompleted) throw HatimException(lt('Önce mevcut hatim tamamlanmalı.'));
    final batch = _db.batch();
    for (var n = 1; n <= totalJuz; n++) {
      batch.update(_juzRef(gid, n), {
        'uid': null,
        'userName': null,
        'status': JuzStatus.empty,
        'endAt': null,
        'volunteer': false,
        'previousUid': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    final now = DateTime.now();
    // Önceki hatimde okuyanlar: duayı okumadılarsa yeni hatimde de okuyabilsinler.
    final readers = {g.creatorId, ...g.juzCounts.entries.where((e) => e.value > 0).map((e) => e.key)}.toList();
    batch.update(gRef, {
      'prevReaders': readers,
      'status': GroupStatus.forming,
      'takenCount': 0,
      'doneCount': 0,
      'juzCounts': <String, int>{},
      'startAt': Timestamp.fromDate(now),
      'endAt': Timestamp.fromDate(now.add(Duration(days: g.durationDays))),
    });
    await batch.commit();
  }
}

class GroupPage {
  GroupPage(this.groups, this.last, this.hasMore);
  final List<HatimGroup> groups;
  final DocumentSnapshot<Map<String, dynamic>>? last;
  final bool hasMore;
}
