# Hafız Kardeşim

Kur'an ezberini dinleten uygulama. Ayetler gizli gelir; sen ezberden okursun, uygulama Arapça ses tanımayla dinler, doğru okunan kelimeleri açar, hatalı ve atlanan kelimeleri işaretler.

## Bölümler

- **🎙️ Ezber Dinlet** — sure / cüz / sayfa seç; tam gizli, ilk harf ya da silik görünüm. İpucu, ayeti aç, doğru say, geri al.
- **🤝 Kardeşime Dinlet** — mikrofonsuz: telefonu tutan arkadaş her kelimede Doğru / Hata / Hatırlat'a basar.
- **🔁 Tekrar takvimi** — her ayet puanlanır; 1-3-7-14-30-60 gün arayla "Bugünün tekrarı"na düşer.
- **🎧 Dinle & Tekrarla** — 8 kâri (Husarî muallim dahil), ayet başına tekrar, bölüm tekrarı, hız, "ardından ben tekrar edeyim" beklemesi, metni gizleme, Türkçe meal.
- **🔍 Sesle Bul** — birkaç kelime oku, sure ve ayeti bulsun.
- **📈 İlerlemem** — günlük hedef, seri, 16 haftalık takvim, cüz haritası, zayıf ayetler, son oturumlar.
- **📕 Hata Defteri** — yanlış okunan kelimeler ayet ayet; tek dokunuşla çalış.

## Yapı

```
public/          ← uygulamanın kendisi (index.html, quran.js, meal.js, logo.png)
android/         ← Android kabuğu (WebView + Arapça ses tanıma köprüsü + AdMob)
store/           ← mağaza görselleri
.github/workflows/android.yml  ← her main gönderiminde APK + AAB derler, "apk" dalına koyar
```

- Ses tanıma: Android'in `SpeechRecognizer`'ı (`ar-SA`), sayfaya `window.HKSes` / `window.hkSes(tür, metin)` ile bağlı. Telefonda Google uygulaması ve internet gerekir.
- Veriler yalnızca telefonda, localStorage anahtarı `hk1`.
- Kur'an metni ve Diyanet meali: Tanzil (Hatim Kardeşim'deki dosyalardan). Sesler: everyayah.com.
- Reklam: her 3 bitmiş oturumda bir geçiş reklamı. `android/app/src/main/res/values/ads.xml` içinde şimdilik **Google test kimlikleri** var; AdMob'da gerçek kimlikleri açınca oraya yaz.
- `android/test.keystore` yalnızca elle kurulan test APK'sı içindir; Play Store için ayrı yükleme anahtarı gerekir.

## APK'yı indirme

Actions → "Android APK" bitince APK, deponun **apk** dalında: `hafiz-kardesim.apk`.
