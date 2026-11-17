import 'package:flutter/material.dart';

import '../widgets/guest.dart';
import '../models/constants.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/social_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/ornaments.dart';
import '../widgets/password_field.dart';
import '../l10n/l10n.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.me});
  final AppUser me;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final _name = TextEditingController(text: widget.me.name);
  bool _busy = false;

  Future<void> _save() async {
    if (_name.text.trim().length < 2) {
      showSnack(context, lt('Adınızı ve soyadınızı yazın.'));
      return;
    }
    setState(() => _busy = true);
    await runGuarded(context, () => AuthService.updateName(widget.me.id, _name.text), success: lt('Profil güncellendi.'));
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _confirmDelete() async {
    final pass = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lt('Hesabınızı silin'), style: AppText.display(26)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
              AuthService.isAppleUser
                  ? lt('Onaylamak için bir sonraki adımda Apple hesabınızla doğrulayın. Bu işlem geri alınamaz.')
                  : AuthService.isGoogleUser
                  ? lt('Onaylamak için bir sonraki adımda Google hesabınızı seçin. Bu işlem geri alınamaz.')
                  : lt('Onaylamak için şifrenizi yazın. Bu işlem geri alınamaz.'),
              style: AppText.body(14)),
          const SizedBox(height: 10),
          Text(
              'Hafız Kardeşim ve Hatim Kardeşim aynı üyeliği kullanır: hesabınız iki uygulamadan da silinir. '
              'Hoca–öğrenci bağlarınız ve bu telefondaki ders geçmişiniz de silinir.',
              style: AppText.body(13, color: AppColors.danger)),
          if (!AuthService.isGoogleUser && !AuthService.isAppleUser) ...[
            const SizedBox(height: 12),
            PasswordField(key: const Key('delete_pass'), controller: pass),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(lt('Vazgeç'))),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(lt('Kalıcı olarak sil')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    final done = await runGuarded(context, () => AuthService.deleteAccount(pass.text));
    if (!mounted) return;
    setState(() => _busy = false);
    if (done) navigator.popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    return Scaffold(
      appBar: AppBar(title: Text(lt('Profilim'))),
      body: PatternBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            OrnateCard(
              child: Row(children: [
                const AppLogo(size: 48),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(me.name, style: AppText.display(26)),
                    Text(lt('{0} · {1} cüz okudu', [Gender.label(me.gender), me.totalJuzRead]),
                        style: AppText.body(13, color: AppColors.muted)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 22),
            TextField(
              key: const Key('profile_name'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: lt('Ad Soyad')),
            ),
            const SizedBox(height: 8),
            Text(lt('Hanım / Bey bilgisi grup kuralları gereği sonradan değiştirilemez.'),
                style: AppText.body(12, color: AppColors.muted)),
            const SizedBox(height: 18),
            GoldButton(label: lt('Kaydet'), busy: _busy, onPressed: _save),
            const SizedBox(height: 12),
            GoldButton(label: lt('Arkadaşınızı davet edin'), icon: Icons.share_outlined, outlined: true, onPressed: SocialService.shareApp),
            const SizedBox(height: 12),
            GoldButton(
              label: lt('Çıkış yap'),
              icon: Icons.logout,
              outlined: true,
              onPressed: () => confirmLogout(context),
            ),
            const SizedBox(height: 36),
            const GoldDivider(),
            const SizedBox(height: 18),
            Text(lt('Hesabınızı silerseniz adınız, Hanım/Bey bilginiz ve okuma sayılarınız silinir. Cüz dağıtımı süren gruplardaki cüzleriniz boşa çıkarılır. Bu işlem geri alınamaz.'),
                style: AppText.body(12, color: AppColors.muted)),
            const SizedBox(height: 10),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              onPressed: _confirmDelete,
              icon: const Icon(Icons.delete_outline),
              label: Text(lt('Hesabımı sil')),
            ),
          ],
        ),
      ),
    );
  }
}
