import 'ar.dart';
import 'en.dart';

/// Uygulama dili: Türkçe (kaynak), English, العربية.
class Lang {
  Lang._();
  static String code = 'tr';
  static const all = ['tr', 'en', 'ar'];
  static const names = {'tr': 'Türkçe', 'en': 'English', 'ar': 'العربية'};
  static bool get isAr => code == 'ar';
  static bool get isEn => code == 'en';
  static bool get isTr => code == 'tr';
}

/// Türkçe kaynak metni seçili dile çevirir. {0}, {1}… yerlerine [args] konur.
String lt(String tr, [List<Object?> args = const []]) {
  var s = tr;
  if (Lang.code == 'en') {
    s = enStrings[tr] ?? tr;
  } else if (Lang.code == 'ar') {
    s = arStrings[tr] ?? enStrings[tr] ?? tr;
  }
  for (var i = 0; i < args.length; i++) {
    s = s.replaceAll('{$i}', '${args[i]}');
  }
  return s;
}
