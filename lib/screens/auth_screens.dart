import 'package:flutter/material.dart';

import '../widgets/guest.dart';
import '../models/constants.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/ornaments.dart';
import '../widgets/password_field.dart';
import '../l10n/l10n.dart';

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({required this.title, required this.subtitle, required this.children, this.showBack = false});
  final String title, subtitle;
  final List<Widget> children;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showBack ? AppBar() : null,
      extendBodyBehindAppBar: true,
      body: PatternBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: AppLogo(size: 64, glow: 0.6)),
                    const SizedBox(height: 18),
                    Text(title, textAlign: TextAlign.center, style: AppText.display(36)),
                    const SizedBox(height: 6),
                    Text(subtitle, textAlign: TextAlign.center, style: AppText.body(14, color: AppColors.muted)),
                    const SizedBox(height: 18),
                    const GoldDivider(),
                    const SizedBox(height: 26),
                    ...children,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false, _gBusy = false, _aBusy = false, _guestBusy = false;

  Future<void> _login() async {
    setState(() => _busy = true);
    await runGuarded(context, () => AuthService.login(_email.text, _pass.text));
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _google() async {
    setState(() => _gBusy = true);
    await runGuarded(context, AuthService.signInWithGoogle);
    if (mounted) setState(() => _gBusy = false);
  }

  Future<void> _apple() async {
    setState(() => _aBusy = true);
    await runGuarded(context, AuthService.signInWithApple);
    if (mounted) setState(() => _aBusy = false);
  }

  // ignore: unused_element
  Future<void> _guest() async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lt('Misafir girişi'), style: AppText.display(22)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            lt('Misafir olarak yalnızca herkese açık ve kilitsiz gruplardan cüz alıp okuyabilirsiniz. Arkadaş ekleme, grup kurma ve davet gibi üye özellikleri kapalıdır.'),
            style: AppText.body(14, color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: lt('Adınız (gruplarda görünür)'), prefixIcon: const Icon(Icons.person_outline)),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(lt('Vazgeç'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(lt('Devam et'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _guestBusy = true);
    await runGuarded(context, () => AuthService.signInAsGuest(name.text));
    if (mounted) setState(() => _guestBusy = false);
  }

  Future<void> _reset() async {
    if (_email.text.trim().isEmpty) {
      showSnack(context, lt('Önce e-posta adresinizi yazın.'));
      return;
    }
    final ok = await runGuarded(context, () => AuthService.resetPassword(_email.text));
    if (!ok || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lt('E-postanızı kontrol edin'), style: AppText.display(24)),
        content: Text(
          lt('{0} adresine şifre yenileme bağlantısı gönderildi.\n\n• E-posta birkaç dakika içinde gelir.\n• Gelen kutunuzda yoksa "Spam / Gereksiz" ve "Promosyonlar" klasörlerine bakın.\n• Gönderen: noreply@hatim-kardesim.firebaseapp.com\n• Bu adresle açılmış bir hesap yoksa e-posta gönderilmez; adresi doğru yazdığınızdan emin olun.', [_email.text.trim()]),
          style: AppText.body(14),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(lt('Tamam')))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: lt('Hoş geldiniz'),
      subtitle: lt('Hatim Kardeşim ya da Hafız Kardeşim hesabınızla giriş yapın'),
      children: [
        TextField(
          key: const Key('login_email'),
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: 'E-posta', prefixIcon: Icon(Icons.mail_outline)),
        ),
        const SizedBox(height: 14),
        PasswordField(key: const Key('login_pass'), controller: _pass, onSubmitted: (_) => _login()),
        Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _reset, child: Text(lt('Şifremi unuttum')))),
        const SizedBox(height: 8),
        GoldButton(label: lt('Giriş yap'), busy: _busy, onPressed: _login),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: Divider(color: AppColors.inkLine)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('veya', style: AppText.body(12, color: AppColors.muted)),
          ),
          Expanded(child: Divider(color: AppColors.inkLine)),
        ]),
        const SizedBox(height: 14),
        if (AuthService.appleAvailable) ...[
          AppleButton(busy: _aBusy, onPressed: _apple),
          const SizedBox(height: 14),
        ],
        if (AuthService.googleAvailable) ...[
          GoogleButton(busy: _gBusy, onPressed: _google),
          const SizedBox(height: 14),
        ],
        GoldButton(
          label: lt('Yeni hesap oluştur'),
          outlined: true,
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
        ),
        // Misafir girişi şimdilik kapalı; açmak için buraya _guest düğmesi geri eklenir.
      ],
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  String? _gender;
  bool _busy = false;

  Future<void> _submit() async {
    if (_name.text.trim().length < 2) { showSnack(context, lt('Adınızı ve soyadınızı yazın.')); return; }
    if (_gender == null) { showSnack(context, lt('Hanım ya da Bey seçimini yapın.')); return; }
    setState(() => _busy = true);
    final ok = await runGuarded(context, () => AuthService.register(
          name: _name.text,
          email: _email.text,
          password: _pass.text,
          gender: _gender!,
        ));
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: lt('Aramıza katılın'),
      subtitle: lt('Hesabınızı oluşturun, ilk cüzünüzü alın'),
      showBack: true,
      children: [
        TextField(
          key: const Key('reg_name'),
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: lt('Ad Soyad'), prefixIcon: Icon(Icons.person_outline)),
        ),
        const SizedBox(height: 14),
        TextField(
          key: const Key('reg_email'),
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'E-posta', prefixIcon: Icon(Icons.mail_outline)),
        ),
        const SizedBox(height: 14),
        PasswordField(
          key: const Key('reg_pass'),
          controller: _pass,
          label: lt('Şifre (en az 6 karakter)'),
          newPassword: true,
        ),
        const SizedBox(height: 20),
        GenderPicker(value: _gender, onChanged: (g) => setState(() => _gender = g)),
        const SizedBox(height: 8),
        Text(lt('Sadece hanımlar veya sadece beyler için açılan gruplara katılım bu seçime göre yapılır.'),
            style: AppText.body(12, color: AppColors.muted)),
        const SizedBox(height: 22),
        GoldButton(label: lt('Hesabımı oluştur'), busy: _busy, onPressed: _submit),
      ],
    );
  }
}

/// Eski hesaplarda ya da yarım kalan kayıtlarda profil tamamlama.
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key, required this.uid, required this.suggestedName});
  final String uid, suggestedName;
  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  late final _name = TextEditingController(text: widget.suggestedName);
  String? _gender;
  bool _busy = false;

  Future<void> _save() async {
    if (_name.text.trim().length < 2) { showSnack(context, lt('Adınızı ve soyadınızı yazın.')); return; }
    if (_gender == null) { showSnack(context, lt('Hanım ya da Bey seçimini yapın.')); return; }
    setState(() => _busy = true);
    await runGuarded(context, () => AuthService.saveProfile(widget.uid, name: _name.text, gender: _gender!));
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: lt('Profilinizi tamamlayın'),
      subtitle: lt('Gruplara katılabilmeniz için iki bilgi eksik'),
      children: [
        TextField(
          key: const Key('cp_name'),
          controller: _name,
          decoration: InputDecoration(labelText: lt('Ad Soyad'), prefixIcon: Icon(Icons.person_outline)),
        ),
        const SizedBox(height: 20),
        GenderPicker(value: _gender, onChanged: (g) => setState(() => _gender = g)),
        const SizedBox(height: 22),
        GoldButton(label: lt('Kaydet'), busy: _busy, onPressed: _save),
        TextButton(onPressed: () => confirmLogout(context), child: Text(lt('Çıkış yap'))),
      ],
    );
  }
}

class GenderPicker extends StatelessWidget {
  const GenderPicker({super.key, required this.value, required this.onChanged});
  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget option(String g, IconData icon) {
      final selected = value == g;
      return Expanded(
        child: OrnateCard(
          highlight: selected,
          padding: const EdgeInsets.symmetric(vertical: 16),
          onTap: () => onChanged(g),
          child: Column(
            children: [
              Icon(icon, color: selected ? AppColors.goldLight : AppColors.muted),
              const SizedBox(height: 6),
              Text(Gender.label(g),
                  style: AppText.display(20, color: selected ? AppColors.goldLight : AppColors.ivory)),
            ],
          ),
        ),
      );
    }

    return Row(children: [
      option(Gender.female, Icons.face_3_outlined),
      const SizedBox(width: 12),
      option(Gender.male, Icons.face_outlined),
    ]);
  }
}


/// "Google ile devam et" düğmesi.
/// Apple'ın tasarım kurallarına uygun "Apple ile devam et" düğmesi (siyah zemin, beyaz Apple simgesi).
class AppleButton extends StatelessWidget {
  const AppleButton({super.key, required this.onPressed, this.busy = false});
  final VoidCallback onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 52,
        child: FilledButton(
          onPressed: busy ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.black54,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.apple, size: 26, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(lt('Apple ile devam et'),
                      style: AppText.body(15, color: Colors.white, weight: FontWeight.w600)),
                ]),
        ),
      );
}

class GoogleButton extends StatelessWidget {
  const GoogleButton({super.key, required this.onPressed, this.busy = false});
  final VoidCallback onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 52,
        child: OutlinedButton(
          onPressed: busy ? null : onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF1F1F1F),
            side: const BorderSide(color: Color(0xFFDADCE0)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('G',
                      style: AppText.display(26, color: const Color(0xFF4285F4), weight: FontWeight.w700)),
                  const SizedBox(width: 12),
                  Text(lt('Google ile devam et'),
                      style: AppText.body(15, color: const Color(0xFF1F1F1F), weight: FontWeight.w600)),
                ]),
        ),
      );
}
