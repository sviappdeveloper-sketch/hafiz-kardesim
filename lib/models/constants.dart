import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_theme.dart';

const int totalJuz = 30;
const int maxJuzPerPerson = 10;

/// Bir gruba en fazla kaç kişi katılabilir (grubu kuran dahil).
const int maxMembers = 30;
const int minDurationDays = 3;
const int maxDurationDays = 60;
const int minMembers = 3;

/// "Katılabileceklerim" listesinde her seferinde yüklenen grup sayısı.
const int groupPageSize = 20;

/// Cüz sınırını herkesin anlayacağı dille anlatan metin.
String get juzLimitText => lt('Bir kişi aynı gruptan en fazla {0} cüz alabilir.', [maxJuzPerPerson]);

/// Grup kurma şartı (en az 3 cüz okumuş, bekleyen cüzü olmamak).
/// Şimdilik kapalı: herkes grup kurabilir. Açmak için true yapın
/// ve firestore.rules içindeki ilgili satırı da etkinleştirin.
const bool groupCreationRequirement = false;

/// Grup kurabilmek için okunmuş olması gereken en az cüz sayısı.
const int minJuzToCreateGroup = 3;

/// Yönetici hesap(lar)ı: reklam talepleri, destek mesajları ve katkı sunanlar.
const adminEmails = ['sviapp.developer@gmail.com'];

/// Hatmin süresi geçmişken boş ya da süresi dolmuş bir cüzü alan kişiye tanınan süre.
const int volunteerDays = 1;

class Gender {
  static const female = 'kadin';
  static const male = 'erkek';
  /// Misafir girişi: yalnızca "Herkese Açık" ve kilitsiz gruplardan cüz alabilir.
  static const guest = 'misafir';
  static String label(String g) =>
      g == female ? lt('Hanım') : (g == male ? lt('Bey') : (g == guest ? lt('Misafir') : '—'));
}

class GenderType {
  static const mixed = 'karma';
  static const women = 'kadin';
  static const men = 'erkek';
  static const _labels = {mixed: 'Herkese Açık', women: 'Sadece Hanımlar', men: 'Sadece Beyler'};
  static String label(String t) => lt(_labels[t] ?? 'Herkese Açık');
  static bool allows(String type, String userGender) => type == mixed || type == userGender;
}

class GroupStatus {
  static const forming = 'toplaniyor';
  static const active = 'okunuyor';
  static const completed = 'tamamlandi';
  static const _labels = {forming: 'Cüz alınabilir', active: 'Tüm cüzler alındı', completed: 'Hatim tamamlandı'};
  static String label(String s) => _labels[s] == null ? s : lt(_labels[s]!);
  static Color color(String s) =>
      s == active ? AppColors.reading : (s == completed ? AppColors.done : AppColors.gold);
}

class JuzStatus {
  static const empty = 'bos';
  static const taken = 'alindi';
  static const reading = 'okunuyor';
  static const done = 'okundu';
  static const _labels = {empty: 'Boş', taken: 'Alındı', reading: 'Okunuyor', done: 'Okundu'};
  static String label(String s) => _labels[s] == null ? s : lt(_labels[s]!);
  static Color color(String s) {
    switch (s) {
      case taken:
        return AppColors.gold;
      case reading:
        return AppColors.reading;
      case done:
        return AppColors.done;
      default:
        return AppColors.muted;
    }
  }
}

/// Medine mushafına (604 sayfa) göre cüzün sayfa aralığı.
String juzPages(int n) {
  if (n == 1) return lt('Sayfa {0}–{1}', [1, 21]);
  if (n == 30) return lt('Sayfa {0}–{1}', [582, 604]);
  final start = (n - 1) * 20 + 2;
  return lt('Sayfa {0}–{1}', [start, start + 19]);
}

/// Firebase > Authentication > Google sağlayıcısındaki Web istemci kimliği (Google ile giriş için).
/// iOS için Google OAuth istemci kimliği (Firebase iOS uygulamasının GoogleService-Info.plist'indeki CLIENT_ID).
/// Boşsa iPhone'da Google ile giriş düğmesi gizlenir; Apple ile giriş kullanılır.
const googleIosClientId = ''; // Hafız Kardeşim'in iOS istemcisi Firebase'de açılınca yazılır (Hatim'inki başka paket kimliğine bağlı)

const googleWebClientId = '668036405824-9g55rfqdnqhli95h6t3gs103q66jrucs.apps.googleusercontent.com';
