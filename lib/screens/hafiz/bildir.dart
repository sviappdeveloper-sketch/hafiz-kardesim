import 'package:flutter/material.dart';

import '../../hafiz/hoca_service.dart';
import '../../models/models.dart';
import '../../services/support_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';

const _nedenler = [
  'Uygunsuz söz ya da davranış',
  'Taciz / rahatsız etme',
  'Karşı cinsten olduğu hâlde eşleşme',
  'Para isteme / dolandırıcılık',
  'Sahte hesap',
  'Diğer',
];

/// Suistimal bildirimi: yönetime "Şikâyet" olarak gider (Destek ve İletişim › mesajlarım'da görünür).
/// İstenirse hoca–öğrenci bağı da hemen kaldırılır.
Future<void> suistimalBildir(BuildContext context, AppUser me, String uid, String ad, {Bag? bag}) async {
  var neden = _nedenler.first;
  var kopar = bag != null;
  final aciklama = TextEditingController();
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.ink,
    builder: (c) => StatefulBuilder(
      builder: (c, ss) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('$ad kişisini bildir', style: AppText.display(20)),
              const SizedBox(height: 4),
              Text('Bildirimin yönetime gider ve gizli tutulur. Karşı tarafa bildirilmez.',
                  style: AppText.body(13, color: AppColors.muted)),
              const SizedBox(height: 8),
              for (final n in _nedenler)
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: n,
                  groupValue: neden,
                  onChanged: (v) => ss(() => neden = v!),
                  title: Text(n, style: AppText.body(14)),
                ),
              TextField(
                controller: aciklama,
                maxLines: 3,
                maxLength: 1500,
                decoration: const InputDecoration(hintText: 'Ne oldu? (isteğe bağlı)'),
              ),
              if (bag != null)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: kopar,
                  onChanged: (v) => ss(() => kopar = v ?? false),
                  title: Text('Bu kişiyle hoca–öğrenci bağımı da kaldır', style: AppText.body(14)),
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(50)),
                onPressed: () => Navigator.pop(c, true),
                icon: const Icon(Icons.flag),
                label: const Text('Bildir'),
              ),
            ]),
          ),
        ),
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  final metin = StringBuffer()
    ..writeln('[Hafız Kardeşim · Suistimal bildirimi]')
    ..writeln('Bildirilen: $ad (uid: $uid)')
    ..writeln('Neden: $neden');
  if (bag != null) metin.writeln('İlişki: ${bag.hoca == me.id ? 'öğrencim' : 'hocam'}');
  if (aciklama.text.trim().isNotEmpty) metin.writeln('Açıklama: ${aciklama.text.trim()}');
  await runGuarded(context, () async {
    await SupportService.create(me, 'sikayet', metin.toString());
    if (kopar && bag != null) await HocaService.bagiSil(bag);
  }, success: 'Bildirimin alındı. Teşekkürler, inceleyeceğiz.');
}
