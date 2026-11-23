// Güvenlik kuralı testleri: kurallar Firebase'e yüklenmeden önce GitHub Actions'ta çalışır.
// Bir test bile başarısız olursa kurallar yayınlanmaz.
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, getDoc, deleteDoc, serverTimestamp } from 'firebase/firestore';
import { readFileSync } from 'fs';

const env = await initializeTestEnvironment({ projectId: 'hatim-test', firestore: { rules: readFileSync('../firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080 } });
const ctx = uid => env.authenticatedContext(uid, { email: uid.toLowerCase() + '@x.com', email_verified: true, firebase: { sign_in_provider: 'password' } }).firestore();
const pair = (a, b) => (a < b ? `${a}_${b}` : `${b}_${a}`);
let ok = 0, bad = 0;
async function t(name, should, fn) {
  try { await (should ? assertSucceeds(fn()) : assertFails(fn())); ok++; console.log('OK   ', name); }
  catch (e) { bad++; console.log(`::error title=kural::${name} (${should ? 'izin verilmeliydi' : 'engellenmeliydi'}) ${String(e.message || e).slice(0, 200)}`); }
}

// Profiller: A, B, X (saldırgan), Y (saldırganın ikinci hesabı) bey; K1, K2 hanım
await env.withSecurityRulesDisabled(async c => {
  const db = c.firestore();
  for (const [u, g] of [['A', 'erkek'], ['B', 'erkek'], ['X', 'erkek'], ['Y', 'erkek'], ['K1', 'kadin'], ['K2', 'kadin'], ['N', '']])
    await setDoc(doc(db, 'users', u), { name: u, gender: g });
});
const A = ctx('A'), B = ctx('B'), X = ctx('X'), Y = ctx('Y'), K1 = ctx('K1'), K2 = ctx('K2'), N = ctx('N');

// ---------- Arkadaşlık ----------
const req = (from, to, extra = {}) => ({ fromUid: from, fromName: from, toUid: to, toName: to, members: [from, to], status: 'bekliyor', createdAt: serverTimestamp(), ...extra });
await t('normal arkadaşlık isteği', true, () => setDoc(doc(A, 'friendRequests', pair('A', 'B')), req('A', 'B')));
await t('istek kabul', true, () => updateDoc(doc(B, 'friendRequests', pair('A', 'B')), { status: 'kabul', respondedAt: serverTimestamp() }));
await t('başkasını habersiz arkadaş yapma (members içine kurban)', false,
  () => setDoc(doc(X, 'friendRequests', pair('X', 'Y')), req('X', 'Y', { members: ['X', 'A'] })));
await t('yanlış belge kimliği', false, () => setDoc(doc(X, 'friendRequests', 'X_sahte'), req('X', 'Y')));
await t('kendine istek', false, () => setDoc(doc(X, 'friendRequests', pair('X', 'X')), req('X', 'X')));
await t('3 kişilik members', false, () => setDoc(doc(X, 'friendRequests', pair('X', 'Y')), req('X', 'Y', { members: ['X', 'Y', 'A'] })));
await t('X→Y normal istek', true, () => setDoc(doc(X, 'friendRequests', pair('X', 'Y')), req('X', 'Y')));
await t('Y reddeder', true, () => updateDoc(doc(Y, 'friendRequests', pair('X', 'Y')), { status: 'red', respondedAt: serverTimestamp() }));
await t('reddedilen isteği başka kişiye çevirme', false,
  () => setDoc(doc(X, 'friendRequests', pair('X', 'Y')), req('X', 'A', { members: ['X', 'A'] })));
await t('reddedilen isteği yeniden gönderme', true, () => setDoc(doc(X, 'friendRequests', pair('X', 'Y')), req('X', 'Y')));
await t('istek okuma (taraf)', true, () => getDoc(doc(Y, 'friendRequests', pair('X', 'Y'))));
await t('istek okuma (yabancı)', false, () => getDoc(doc(A, 'friendRequests', pair('X', 'Y'))));
await t('istek geri çekme', true, () => deleteDoc(doc(X, 'friendRequests', pair('X', 'Y'))));

// ---------- Hoca–öğrenci ----------
const bag = (hoca, ogr, isteyen) => ({ hoca, ogrenci: ogr, uyeler: [hoca, ogr], adlar: { [hoca]: hoca, [ogr]: ogr }, isteyen, durum: 'bekliyor', olusturma: serverTimestamp() });
await t('bey–bey hoca isteği', true, () => setDoc(doc(A, 'hafizBag', 'A_B'), bag('A', 'B', 'A')));
await t('hanım–hanım hoca isteği', true, () => setDoc(doc(K1, 'hafizBag', 'K1_K2'), bag('K1', 'K2', 'K1')));
await t('bey→hanım hoca isteği', false, () => setDoc(doc(A, 'hafizBag', 'A_K1'), bag('A', 'K1', 'A')));
await t('hanım→bey öğrenci isteği', false, () => setDoc(doc(K1, 'hafizBag', 'X_K1'), bag('X', 'K1', 'K1')));
await t('cinsiyeti seçilmemiş üye', false, () => setDoc(doc(N, 'hafizBag', 'N_B'), bag('N', 'B', 'N')));
await t('bey–bey kabul', true, () => updateDoc(doc(B, 'hafizBag', 'A_B'), { durum: 'kabul', cevap: serverTimestamp() }));
await t('hoca ödev verir', true, () => updateDoc(doc(A, 'hafizBag', 'A_B'), { odev: { p: '1-7', etiket: 'Fatiha', not: '' } }));
await t('canlı ders bey–bey', true, () => setDoc(doc(A, 'hafizCanli', 'c1'), { hoca: 'A', ogrenci: 'B', uyeler: ['A', 'B'], baslatan: 'A', durum: 'davet' }));
// Kurallar eklenmeden önce kurulmuş karışık bir bağ: yeniden gönderme ve canlı ders engellenir
await env.withSecurityRulesDisabled(c => setDoc(doc(c.firestore(), 'hafizBag', 'A_K2'), { ...bag('A', 'K2', 'A'), durum: 'kabul' }));
await t('eski karışık bağda canlı ders', false, () => setDoc(doc(A, 'hafizCanli', 'c2'), { hoca: 'A', ogrenci: 'K2', uyeler: ['A', 'K2'], baslatan: 'A', durum: 'davet' }));

await env.cleanup();
console.log(`\n${ok} geçti, ${bad} başarısız`);
process.exit(bad ? 1 : 0);
