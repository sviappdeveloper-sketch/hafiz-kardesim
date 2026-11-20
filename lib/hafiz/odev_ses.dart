import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';

import 'adpcm.dart';
import 'hoca_service.dart';

/// Ödev teslimi: öğrenci hocanın verdiği ödevi okuyup "Dersi bitirdim"e basınca sonucu ve okuma sesi
/// hocaya gider. Belge kimliği bağın kimliğidir (hocaUid_ogrenciUid): yeni teslim eskisinin yerine geçer.
///
/// Ses sıkıştırılıp (IMA ADPCM, 16 kHz) ~900 KB'lık parçalar hâlinde `parca` alt koleksiyonuna yazılır.
/// Hoca sesi silince ya da yeni ödev verince sunucudan kalkar; uygulama kalıcı ses arşivi tutmaz.
class Teslim {
  Teslim(this.id, this.m);
  final String id;
  final Map<String, dynamic> m;
  String get etiket => (m['etiket'] ?? '') as String;
  int get puan => (m['puan'] as num?)?.toInt() ?? 0;
  int get sure => (m['sure'] as num?)?.toInt() ?? 0;
  int get ornek => (m['ornek'] as num?)?.toInt() ?? 0;
  int get parca => (m['parca'] as num?)?.toInt() ?? 0;
  int get hz => (m['hz'] as num?)?.toInt() ?? 16000;
  bool get sesVar => parca > 0 && ornek > 0;
  bool get dinlendi => (m['dinlendi'] ?? false) as bool;
  List<int> get sayilar => [for (final x in (m['sayilar'] ?? const []) as List) (x as num).toInt()];
  DateTime? get ts => (m['ts'] as Timestamp?)?.toDate();
  /// Teslim edilen ödevin verildiği an (ödev değişince eski teslim "önceki ödev" sayılır).
  int get odevTs => (m['odevTs'] as num?)?.toInt() ?? 0;
}

class OdevSes {
  OdevSes._();
  static final _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get teslimler => _db.collection('hafizTeslim');
  static const _parcaBoyu = 900000;

  /// Hoca: öğrencilerin teslim ettiği, sesi henüz dinlenmemiş ödevler.
  static Stream<List<Teslim>> yeniTeslimler(String me) => teslimler
      .where('uyeler', arrayContains: me)
      .snapshots()
      .map((s) => [
            for (final d in s.docs)
              if (d.data()['hoca'] == me && d.data()['durum'] == 'teslim' && d.data()['dinlendi'] != true) Teslim(d.id, d.data())
          ]);

  static Stream<Teslim?> teslim(String bagId) =>
      teslimler.doc(bagId).snapshots().map((d) => d.exists ? Teslim(d.id, d.data()!) : null);

  /// Ödevin verildiği an (milisaniye): teslimin bu ödeve ait olup olmadığını anlamak için.
  static int odevTs(Bag b) => ((b.odev?['ts']) as Timestamp?)?.millisecondsSinceEpoch ?? 0;

  /// Öğrenci: ödevi teslim eder. [ses] sıkıştırılmış ses ([ornek] örnek), yoksa yalnızca sonuç gider.
  static Future<void> gonder({
    required Bag bag,
    required String etiket,
    required int puan,
    required List<int> sayilar,
    required int sureSn,
    Uint8List? ses,
    int ornek = 0,
    void Function(double)? ilerleme,
  }) async {
    final ref = teslimler.doc(bag.id);
    await _parcalariSil(ref);
    final n = ses == null || ses.isEmpty ? 0 : (ses.length + _parcaBoyu - 1) ~/ _parcaBoyu;
    // Önce parçalar yüklenir (belge "yükleniyor" olarak), en son bilgiler yazılır.
    await ref.set({
      'hoca': bag.hoca,
      'ogrenci': bag.ogrenci,
      'uyeler': [bag.hoca, bag.ogrenci],
      'durum': 'yukleniyor',
      'parca': 0,
      'ts': FieldValue.serverTimestamp(),
    });
    for (var i = 0; i < n; i++) {
      final a = i * _parcaBoyu;
      final b = (a + _parcaBoyu).clamp(0, ses!.length);
      await ref.collection('parca').doc('$i').set({'v': Blob(Uint8List.sublistView(ses, a, b))});
      ilerleme?.call((i + 1) / n);
    }
    await ref.set({
      'hoca': bag.hoca,
      'ogrenci': bag.ogrenci,
      'uyeler': [bag.hoca, bag.ogrenci],
      'durum': 'teslim',
      'etiket': etiket,
      'puan': puan,
      'sayilar': sayilar,
      'sure': sureSn,
      'parca': n,
      'ornek': ornek,
      'hz': 16000,
      'dinlendi': false,
      'odevTs': odevTs(bag),
      'ts': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> _parcalariSil(DocumentReference<Map<String, dynamic>> ref) async {
    try {
      final q = await ref.collection('parca').get();
      for (final d in q.docs) {
        await d.reference.delete();
      }
    } catch (_) {}
  }

  /// Sesi indirir, açar ve çalınabilir bir WAV dosyası olarak telefona yazar.
  static Future<File> indir(Teslim t) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/odev_${t.id}_${t.ts?.millisecondsSinceEpoch ?? 0}.wav');
    if (await f.exists()) return f;
    final b = BytesBuilder(copy: false);
    for (var i = 0; i < t.parca; i++) {
      final d = await teslimler.doc(t.id).collection('parca').doc('$i').get();
      final v = d.data()?['v'];
      if (v is Blob) b.add(v.bytes);
    }
    final pcm = adpcmCoz(b.takeBytes(), t.ornek);
    await f.writeAsBytes(wav(pcm, t.hz), flush: true);
    return f;
  }

  static Future<void> dinlendi(String id) => teslimler.doc(id).update({'dinlendi': true});

  /// Hoca (ya da öğrenci) teslimi ve sesini siler.
  static Future<void> sil(String id) async {
    final ref = teslimler.doc(id);
    await _parcalariSil(ref);
    await ref.delete();
  }
}
