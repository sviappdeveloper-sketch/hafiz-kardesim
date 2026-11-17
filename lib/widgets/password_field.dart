import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../l10n/l10n.dart';

/// Göz simgesiyle yazılan şifreyi gösterip gizleyebilen alan.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.label,
    this.onSubmitted,
    this.newPassword = false,
  });
  final TextEditingController controller;
  final String? label;
  final ValueChanged<String>? onSubmitted;
  final bool newPassword;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: !_visible,
      enableSuggestions: false,
      autocorrect: false,
      autofillHints: [widget.newPassword ? AutofillHints.newPassword : AutofillHints.password],
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: widget.label ?? lt('Şifre'),
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: _visible ? lt('Şifreyi gizle') : lt('Şifreyi göster'),
          icon: Icon(_visible ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.gold),
          onPressed: () => setState(() => _visible = !_visible),
        ),
      ),
    );
  }
}
