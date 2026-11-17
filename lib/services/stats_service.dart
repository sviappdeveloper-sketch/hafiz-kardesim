import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/constants.dart';
import '../models/models.dart';

class StatsSnapshot {
  StatsSnapshot({
    required this.groupsByStatus,
    required this.juzByStatus,
    required this.totals,
    required this.myJuz,
    required this.topGroups,
    required this.topReaders,
  });
  final Map<String, int> groupsByStatus;
  final Map<String, int> juzByStatus;
  final Map<String, int> totals;
  final Map<String, int> myJuz;
  final List<HatimGroup> topGroups;
  final List<AppUser> topReaders;
}

class StatsService {
  static final _db = FirebaseFirestore.instance;

  static Future<int> _count(Query<Map<String, dynamic>> q) async => (await q.count().get()).count ?? 0;

  static Future<StatsSnapshot> load(String uid) async {
    final groups = _db.collection('groups');
    final juz = _db.collection('juz');
    const gStatuses = [GroupStatus.forming, GroupStatus.active, GroupStatus.completed];
    const jStatuses = [JuzStatus.empty, JuzStatus.taken, JuzStatus.reading, JuzStatus.done];

    final groupCounts = Future.wait(gStatuses.map((s) => _count(groups.where('status', isEqualTo: s))));
    final juzCounts = Future.wait(jStatuses.map((s) => _count(juz.where('status', isEqualTo: s))));
    final totalsF = _db.collection('stats').doc('global').get();
    final mineF = juz.where('uid', isEqualTo: uid).get();
    final topGroupsF = groups.where('hatimCount', isGreaterThan: 0).orderBy('hatimCount', descending: true).limit(10).get();
    final topReadersF = _db.collection('users').where('totalJuzRead', isGreaterThan: 0).orderBy('totalJuzRead', descending: true).limit(10).get();

    final g = await groupCounts;
    final j = await juzCounts;
    final totalsDoc = await totalsF;
    final mine = await mineF;

    final my = <String, int>{for (final s in jStatuses) s: 0};
    for (final d in mine.docs) {
      final s = (d.data()['status'] ?? '') as String;
      my[s] = (my[s] ?? 0) + 1;
    }
    final t = totalsDoc.data() ?? {};

    return StatsSnapshot(
      groupsByStatus: {for (var i = 0; i < gStatuses.length; i++) gStatuses[i]: g[i]},
      juzByStatus: {for (var i = 0; i < jStatuses.length; i++) jStatuses[i]: j[i]},
      totals: {
        'groupsCreated': (t['groupsCreated'] as num?)?.toInt() ?? 0,
        'hatimsCompleted': (t['hatimsCompleted'] as num?)?.toInt() ?? 0,
        'juzRead': (t['juzRead'] as num?)?.toInt() ?? 0,
      },
      myJuz: my,
      topGroups: (await topGroupsF).docs.map(HatimGroup.fromDoc).toList(),
      topReaders: (await topReadersF).docs.map(AppUser.fromDoc).toList(),
    );
  }
}
