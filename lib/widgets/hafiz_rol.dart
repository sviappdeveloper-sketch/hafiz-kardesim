import 'package:flutter/material.dart';

import '../models/constants.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Üyenin adının altında görünen "Hafız" / "Talebe" etiketi.
/// [rol] verilirse doğrudan gösterilir; verilmezse [uid] üyesinin profilinden okunur.
/// Seçilmemişse hiçbir şey göstermez.
class HafizRolEtiketi extends StatelessWidget {
  const HafizRolEtiketi({super.key, this.uid, this.rol, this.size = 12.5});
  final String? uid;
  final String? rol;
  final double size;

  Widget _yaz(String r) {
    final t = HafizRol.label(r);
    if (t.isEmpty) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(r == HafizRol.hafiz ? Icons.menu_book_rounded : Icons.school_outlined, size: size + 2, color: AppColors.gold),
      const SizedBox(width: 4),
      Text(t, style: AppText.body(size, weight: FontWeight.w600, color: AppColors.gold)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (rol != null) return _yaz(rol!);
    if (uid == null || uid!.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<AppUser?>(
      stream: AuthService.userStream(uid!),
      builder: (context, snap) => _yaz(snap.data?.hafizRol ?? ''),
    );
  }
}
