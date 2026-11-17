import 'package:cloud_firestore/cloud_firestore.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../utils/format.dart';

/// Yalnızca bu emojiler ve hazır cümleler kullanılabilir; serbest yazı yoktur.
/// Aynı liste firestore.rules içinde de denetlenir.
const reactionEmojis = ['🙂', '🤲'];
const reactionPhrases = [
  'Maşallah',
  'Allah kabul etsin',
  'Tebrik ederim',
  'Rabbim zihin açıklığı versin',
  'Teşekkür ederim',
  'Allah razı olsun',
  "Allah'a hamd olsun",
  'Rica ederim',
];
const allowedReactions = [...reactionEmojis, ...reactionPhrases];

/// Hazır tebrikler veritabanında Türkçe saklanır; ekranda seçili dilde gösterilir.
String reactionLabel(String text) => reactionPhrases.contains(text) ? lt(text) : text;

class ReactionService {
  static final _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get col => _db.collection('reactions');

  /// Arkadaşın cüzüne tebrik bırakır. Aynı kişi aynı cüze aynı tebriki bir kez bırakabilir.
  static Future<void> send({
    required AppUser me,
    required String toUid,
    required Juz juz,
    required String text,
  }) async {
    if (!allowedReactions.contains(text)) throw HatimException(lt('Yalnızca hazır tebrikler gönderilebilir.'));
    if (toUid == me.id) throw HatimException(lt('Kendinize tebrik bırakamazsınız.'));
    final idx = allowedReactions.indexOf(text);
    await col.doc('${juz.id}_${me.id}_${toUid}_$idx').set({
      'juzId': juz.id,
      'juzNumber': juz.number,
      'groupId': juz.groupId,
      'groupName': juz.groupName,
      'fromUid': me.id,
      'fromName': me.name,
      'toUid': toUid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Gelen bir tebriğe hazır cümleyle karşılık verir (ör. "Teşekkür ederim").
  static Future<void> reply({required AppUser me, required Reaction to, required String text}) async {
    if (!allowedReactions.contains(text)) throw HatimException('Yalnızca hazır cümleler gönderilebilir.');
    final idx = allowedReactions.indexOf(text);
    await col.doc('${to.juzId}_${me.id}_${to.fromUid}_$idx').set({
      'juzId': to.juzId,
      'juzNumber': to.juzNumber,
      'groupName': to.groupName,
      'fromUid': me.id,
      'fromName': me.name,
      'toUid': to.fromUid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Gelen tebrikler (en yeni üstte).
  static Stream<List<Reaction>> received(String uid) =>
      col.where('toUid', isEqualTo: uid).limit(200).snapshots().map((s) {
        final l = s.docs.map(Reaction.fromDoc).toList();
        l.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return l;
      });

  /// Bir cüze bırakılan tebrikler.
  static Stream<List<Reaction>> forJuz(String juzId) =>
      col.where('juzId', isEqualTo: juzId).snapshots().map((s) {
        final l = s.docs.map(Reaction.fromDoc).toList();
        l.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        return l;
      });
}
