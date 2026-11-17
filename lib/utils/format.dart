import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

const _monthsTr = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
const _monthsEn = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const _monthsAr = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
const _daysTr = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
const _daysEn = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _daysAr = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];

/// Seçili dilde ay adı (1–12).
String monthName(int m) => (Lang.isEn ? _monthsEn : Lang.isAr ? _monthsAr : _monthsTr)[m - 1];
String _dayName(int wd) => (Lang.isEn ? _daysEn : Lang.isAr ? _daysAr : _daysTr)[wd - 1];

String _two(int v) => v.toString().padLeft(2, '0');

String formatDate(DateTime d) =>
    Lang.isEn ? '${monthName(d.month)} ${d.day}, ${d.year}' : '${d.day} ${monthName(d.month)} ${d.year}';
String formatDateTime(DateTime d) => '${formatDate(d)}, ${_two(d.hour)}:${_two(d.minute)}';
String formatToday(DateTime d) => Lang.isEn
    ? '${_dayName(d.weekday)}, ${monthName(d.month)} ${d.day}'
    : '${d.day} ${monthName(d.month)}، ${_dayName(d.weekday)}'.replaceAll('،', Lang.isAr ? '،' : ',');

String remainingText(DateTime end) {
  final diff = end.difference(DateTime.now());
  if (diff.isNegative) return lt('Süre doldu');
  if (diff.inDays >= 1) return lt('{0} gün {1} saat kaldı', [diff.inDays, diff.inHours % 24]);
  if (diff.inHours >= 1) return lt('{0} saat {1} dk kaldı', [diff.inHours, diff.inMinutes % 60]);
  return lt('{0} dk kaldı', [diff.inMinutes]);
}

/// Uygulama içi kural ihlalleri (kullanıcıya gösterilecek mesajla).
class HatimException implements Exception {
  HatimException(this.message);
  final String message;
  @override
  String toString() => message;
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

String errorText(Object e) {
  if (e is HatimException) return e.message;
  if (e is FirebaseException) {
    if (e.code == 'permission-denied') return lt('Bu işlem için yetkiniz yok.');
    if (e.code == 'unavailable') return lt('İnternet bağlantınızı kontrol edip tekrar deneyin.');
    if (e.code == 'failed-precondition') {
      return lt('Veritabanı dizini henüz hazır değil. Birkaç dakika sonra tekrar deneyin.');
    }
    return e.message ?? e.code;
  }
  return e.toString();
}

/// Bir işlemi çalıştırır, hata olursa kullanıcıya anlaşılır mesaj gösterir.
Future<bool> runGuarded(BuildContext context, Future<void> Function() action, {String? success}) async {
  try {
    await action();
    if (success != null && context.mounted) showSnack(context, success);
    return true;
  } catch (e) {
    if (context.mounted) showSnack(context, errorText(e));
    return false;
  }
}
