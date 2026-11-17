import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:google_sign_in/google_sign_in.dart';

import '../models/constants.dart';
import '../models/models.dart';
import '../utils/format.dart';
import '../l10n/l10n.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get users => _db.collection('users');

  static Stream<User?> authChanges() => _auth.authStateChanges();

  /// Yönetici: kayıtlı e-postası yönetici listesinde olan ve e-postasını doğrulamış hesap.
  static bool get isAdmin {
    final email = _auth.currentUser?.email?.toLowerCase();
    return email != null && adminEmails.contains(email);
  }

  static bool get emailVerified => _auth.currentUser?.emailVerified ?? false;

  static Future<void> sendVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw HatimException(_authMessage(e));
    }
  }

  /// Doğrulama sonrası yeni durumu almak için oturumu yeniler.
  static Future<bool> refreshVerification() async {
    await _auth.currentUser?.reload();
    await _auth.currentUser?.getIdToken(true);
    return _auth.currentUser?.emailVerified ?? false;
  }

  static Stream<AppUser?> userStream(String uid) =>
      users.doc(uid).snapshots().map((d) => d.exists ? AppUser.fromDoc(d) : null);

  static Future<void> register({
    required String name,
    required String email,
    required String password,
    required String gender,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      await cred.user!.updateDisplayName(name.trim());
      await saveProfile(cred.user!.uid, name: name, gender: gender);
      await savePrivate();
    } on FirebaseAuthException catch (e) {
      throw HatimException(_authMessage(e));
    }
  }

  static Future<void> saveProfile(String uid, {required String name, required String gender}) => users.doc(uid).set({
        'name': name.trim(),
        'gender': gender,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  /// Üyenin e-posta adresi herkese açık profilde değil, yalnızca kendisinin ve yöneticinin
  /// okuyabildiği ayrı bir kayıtta tutulur (Yönetim > Üyeler için).
  static Future<void> savePrivate() async {
    final u = _auth.currentUser;
    if (u == null || u.email == null) return;
    try {
      await _db.collection('userPrivate').doc(u.uid).set({
        'email': u.email!.toLowerCase(),
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Kurallar henüz yüklenmemişse girişi engellemesin.
    }
  }

  static Future<void> updateName(String uid, String name) => users.doc(uid).update({'name': name.trim()});

  static Future<void> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      await savePrivate();
    } on FirebaseAuthException catch (e) {
      throw HatimException(_authMessage(e));
    }
  }

  /// Google ile giriş / kayıt. Kullanıcı vazgeçerse false döner.
  /// İlk girişte cinsiyet bilgisi olmadığı için profil tamamlama ekranı açılır.
  static Future<bool> signInWithGoogle() async {
    try {
      await _google.signOut(); // Her seferinde hesap seçtirilsin.
      final acc = await _google.signIn();
      if (acc == null) return false;
      final a = await acc.authentication;
      await _auth.signInWithCredential(GoogleAuthProvider.credential(idToken: a.idToken, accessToken: a.accessToken));
      await savePrivate();
      return true;
    } on FirebaseAuthException catch (e) {
      throw HatimException(_authMessage(e));
    } catch (e) {
      final t = '$e';
      if (t.contains('network')) throw HatimException(lt('İnternet bağlantınızı kontrol edin.'));
      if (t.contains('sign_in_canceled')) return false;
      if (t.contains('ApiException: 10') || t.contains('sign_in_failed')) {
        throw HatimException(lt('Google ile giriş henüz hazır değil. Şimdilik e-posta ve şifreyle giriş yapabilirsiniz.'));
      }
      throw HatimException(lt('Google ile giriş şu an yapılamadı. E-posta ile giriş yapabilirsiniz. ({0})', [t]));
    }
  }

  /// Bu cihazda Google ile giriş kullanılabilir mi? (iPhone'da iOS istemci kimliği gerekir.)
  static bool get googleAvailable => !_isIOS || googleIosClientId.endsWith('.apps.googleusercontent.com');

  /// Apple ile giriş yalnızca iPhone/iPad'de sunulur.
  static bool get appleAvailable => _isIOS;

  static bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Apple ile giriş / kayıt. Kullanıcı vazgeçerse false döner.
  static Future<bool> signInWithApple() async {
    try {
      final provider = AppleAuthProvider()
        ..addScope('email')
        ..addScope('name');
      await _auth.signInWithProvider(provider);
      await savePrivate();
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'canceled' || e.code == 'web-context-canceled' || '${e.message}'.contains('1001')) return false;
      throw HatimException(_authMessage(e));
    } catch (e) {
      final t = '$e';
      if (t.contains('1001') || t.contains('cancel')) return false;
      throw HatimException(lt('Apple ile giriş şu an yapılamadı. E-posta ile giriş yapabilirsiniz. ({0})', [t]));
    }
  }

  /// Hesap Apple ile mi açılmış?
  static bool get isAppleUser =>
      _auth.currentUser?.providerData.any((p) => p.providerId == 'apple.com') == true &&
      _auth.currentUser?.providerData.any((p) => p.providerId == 'password') != true;

  static final _google = GoogleSignIn(
    clientId: _isIOS && googleIosClientId.isNotEmpty ? googleIosClientId : null,
    // Web istemci kimliği girilmişse kimlik belirteci (idToken) da alınır; girilmemişse erişim belirteci yeterlidir.
    serverClientId: googleWebClientId.endsWith('.apps.googleusercontent.com') ? googleWebClientId : null,
    scopes: const ['email'],
  );

  /// Hesap Google ile mi açılmış?
  static bool get isGoogleUser =>
      _auth.currentUser?.providerData.any((p) => p.providerId == 'google.com') == true &&
      _auth.currentUser?.providerData.any((p) => p.providerId == 'password') != true;

  static Future<void> resetPassword(String email) async {
    try {
      // E-posta Türkçe gelsin.
      await _auth.setLanguageCode(Lang.code);
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw HatimException(_authMessage(e));
    }
  }

  /// Misafir girişi (Firebase anonim hesap). Üye özellikleri kapalıdır; yalnızca açık gruplardan cüz alınır.
  static Future<void> signInAsGuest(String name) async {
    try {
      final cred = await _auth.signInAnonymously();
      final n = name.trim().isEmpty ? lt('Misafir') : name.trim();
      await saveProfile(cred.user!.uid, name: n, gender: Gender.guest);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'operation-not-allowed' || e.code == 'admin-restricted-operation') {
        throw HatimException(lt('Misafir girişi şu an kapalı. E-posta ya da Google ile giriş yapabilirsiniz.'));
      }
      throw HatimException(_authMessage(e));
    }
  }

  static bool get isGuestSession => _auth.currentUser?.isAnonymous == true;

  static Future<void> logout() async {
    try {
      await _google.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  /// Hesabı ve kişisel verileri siler (Google Play hesap silme şartı).
  /// Cüz dağıtımı süren gruplardaki cüzler boşa çıkarılır, arkadaşlık kayıtları silinir.
  static Future<void> deleteAccount(String password) async {
    final user = _auth.currentUser;
    if (user == null || (user.email == null && !isAppleUser)) {
      throw HatimException(lt('Oturum bulunamadı. Yeniden giriş yapın.'));
    }
    try {
      if (isAppleUser) {
        await user.reauthenticateWithProvider(AppleAuthProvider());
      } else if (isGoogleUser) {
        final acc = await _google.signIn();
        if (acc == null) throw HatimException(lt('Hesap silme için Google hesabınızı onaylamanız gerekiyor.'));
        final a = await acc.authentication;
        await user.reauthenticateWithCredential(
            GoogleAuthProvider.credential(idToken: a.idToken, accessToken: a.accessToken));
      } else {
        await user.reauthenticateWithCredential(EmailAuthProvider.credential(email: user.email!, password: password));
      }
    } on FirebaseAuthException catch (e) {
      throw HatimException(_authMessage(e));
    }
    final uid = user.uid;

    // Dağıtımı süren gruplardaki cüzleri bırak.
    final myJuz = await _db.collection('juz').where('uid', isEqualTo: uid).get();
    for (final d in myJuz.docs) {
      final gid = d.data()['groupId'] as String?;
      if (gid == null) continue;
      final g = await _db.collection('groups').doc(gid).get();
      // Okunmuş cüzün kaydı her durumda kalır; yalnızca ad anonimleştirilir.
      if (g.data()?['status'] != GroupStatus.forming || d.data()['status'] == JuzStatus.done) {
        // Başlamış/tamamlanmış hatimlerde okuma kaydı kalır, ad anonimleştirilir.
        final batch = _db.batch();
        batch.update(d.reference, {'userName': lt('Silinmiş kullanıcı')});
        batch.update(g.reference, {'memberNames.$uid': lt('Silinmiş kullanıcı')});
        await batch.commit();
        continue;
      }
      final batch = _db.batch();
      batch.update(d.reference, {'uid': null, 'userName': null, 'status': JuzStatus.empty});
      batch.update(g.reference, {
        'takenCount': FieldValue.increment(-1),
        'juzCounts.$uid': FieldValue.increment(-1),
        'memberIds': FieldValue.arrayRemove([uid]),
        'memberNames.$uid': FieldValue.delete(),
      });
      await batch.commit();
    }

    // Arkadaşlık kayıtları.
    final reqs = await _db.collection('friendRequests').where('members', arrayContains: uid).get();
    for (final d in reqs.docs) {
      await d.reference.delete();
    }

    try {
      await _db.collection('userPrivate').doc(uid).delete();
    } catch (_) {}
    await users.doc(uid).delete();
    await user.delete();
  }

  static String _authMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return lt('E-posta adresi geçerli değil.');
      case 'email-already-in-use':
        return lt('Bu e-posta ile zaten bir hesap var. Giriş yapmayı deneyin.');
      case 'weak-password':
        return lt('Şifre en az 6 karakter olmalı.');
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return lt('E-posta veya şifre hatalı.');
      case 'too-many-requests':
        return lt('Çok fazla deneme yapıldı. Biraz bekleyip tekrar deneyin.');
      case 'account-exists-with-different-credential':
        return lt('Bu e-posta ile daha önce şifreyle kayıt olunmuş. E-posta ve şifrenizle giriş yapın.');
      case 'operation-not-allowed':
        return lt('Google ile giriş henüz etkin değil.');
      case 'network-request-failed':
        return lt('İnternet bağlantınızı kontrol edin.');
      default:
        return e.message ?? lt('Giriş sırasında bir sorun oluştu.');
    }
  }
}
