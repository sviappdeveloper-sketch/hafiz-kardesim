import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/guest.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ornaments.dart';
import 'auth_screens.dart';
import 'hafiz/ana.dart';
import '../l10n/l10n.dart';

bool _privateSaved = false;
void _savePrivateOnce() {
  if (_privateSaved) return;
  _privateSaved = true;
  AuthService.savePrivate();
}

String? _notifyUid;
void _startNotifications(AppUser me) {
  if (_notifyUid == me.id) return;
  _notifyUid = me.id;
  NotificationService.start(me);
}

/// Oturum durumuna göre giriş ekranını ya da ana sayfayı gösterir.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.authChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return Scaffold(backgroundColor: AppColors.inkDeep, body: PatternBackground(opacity: 0.05, child: SizedBox.expand()));
        }
        final user = authSnap.data;
        if (user == null) {
          if (_notifyUid != null) {
            _notifyUid = null;
            _privateSaved = false;
            NotificationService.stop();
          }
          return const LoginScreen();
        }
        _savePrivateOnce();
        return StreamBuilder<AppUser?>(
          stream: AuthService.userStream(user.uid),
          builder: (context, snap) {
            if (!snap.hasData && snap.connectionState == ConnectionState.waiting) {
              return Scaffold(backgroundColor: AppColors.inkDeep, body: PatternBackground(opacity: 0.05, child: SizedBox.expand()));
            }
            final me = snap.data;
            if (me != null && me.blocked && !AuthService.isAdmin) return const _BlockedScreen();
            if (me == null && user.isAnonymous) {
              // Misafir kaydı yazılıyor.
              return Scaffold(backgroundColor: AppColors.inkDeep, body: PatternBackground(opacity: 0.05, child: SizedBox.expand()));
            }
            if (me == null || me.gender.isEmpty) {
              return CompleteProfileScreen(uid: user.uid, suggestedName: user.displayName ?? '');
            }
            _startNotifications(me);
            return HafizAna(me: me);
          },
        );
      },
    );
  }
}

/// Yönetici tarafından engellenen üyenin gördüğü ekran.
class _BlockedScreen extends StatelessWidget {
  const _BlockedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PatternBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.block, size: 48, color: AppColors.danger),
                const SizedBox(height: 18),
                Text(lt('Hesabınız engellendi'), textAlign: TextAlign.center, style: AppText.display(28)),
                const SizedBox(height: 12),
                Text(
                  lt('Hesabınız yönetici tarafından engellendiği için uygulamayı şu an kullanamazsınız. Bir yanlışlık olduğunu düşünüyorsanız sviapp.developer@gmail.com adresine yazabilirsiniz.'),
                  textAlign: TextAlign.center,
                  style: AppText.body(14, color: AppColors.muted),
                ),
                const SizedBox(height: 24),
                GoldButton(label: lt('Çıkış yap'), icon: Icons.logout, outlined: true, onPressed: () => confirmLogout(context)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
