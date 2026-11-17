import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'ornaments.dart';

/// Çıkış yapmadan önce onay sorar. Misafir için hesabın bir daha açılamayacağını da söyler.
Future<void> confirmLogout(BuildContext context) async {
  final guest = AuthService.isGuestSession;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(lt('Çıkış yapılsın mı?'), style: AppText.display(22)),
      content: Text(
        guest
            ? lt('Misafir oturumundan çıkarsanız bu misafir hesabına bir daha giremezsiniz. Aldığınız cüzler grupta adınızla kalır.')
            : lt('Hesabınızdan çıkmak istediğinize emin misiniz?'),
        style: AppText.body(14),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(lt('Vazgeç'))),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(lt('Çıkış yap')),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  Navigator.of(context).popUntil((r) => r.isFirst);
  await AuthService.logout();
}

/// Misafirin üyelere özel bir bölüme girdiğinde gördüğü açıklama.
class GuestOnlyView extends StatelessWidget {
  const GuestOnlyView({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), automaticallyImplyLeading: false),
      body: PatternBackground(child: Center(child: Padding(padding: const EdgeInsets.all(24), child: GuestNotice()))),
    );
  }
}

class GuestNotice extends StatelessWidget {
  const GuestNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return OrnateCard(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Icon(Icons.lock_outline, color: AppColors.goldLight, size: 34),
        const SizedBox(height: 12),
        Text(lt('Bu bölüm üyelere özel'), textAlign: TextAlign.center, style: AppText.display(22)),
        const SizedBox(height: 8),
        Text(
          lt('Misafir olarak herkese açık gruplardan cüz alıp okuyabilirsiniz. Arkadaş ekleme, grup kurma, davet ve istatistikler için üye olun.'),
          textAlign: TextAlign.center,
          style: AppText.body(14, color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        GoldButton(label: lt('Üye ol'), icon: Icons.person_add_alt_1_outlined, onPressed: () => confirmLogout(context)),
      ]),
    );
  }
}
