package com.sviapp.hafizkardesim;

import android.Manifest;
import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.media.AudioManager;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.speech.RecognitionListener;
import android.speech.RecognizerIntent;
import android.speech.SpeechRecognizer;
import android.view.WindowInsets;
import android.view.WindowManager;
import android.webkit.JavascriptInterface;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;
import com.google.android.gms.ads.AdError;
import com.google.android.gms.ads.AdRequest;
import com.google.android.gms.ads.FullScreenContentCallback;
import com.google.android.gms.ads.LoadAdError;
import com.google.android.gms.ads.MobileAds;
import com.google.android.gms.ads.interstitial.InterstitialAd;
import com.google.android.gms.ads.interstitial.InterstitialAdLoadCallback;
import com.google.android.ump.ConsentInformation;
import com.google.android.ump.ConsentRequestParameters;
import com.google.android.ump.UserMessagingPlatform;
import java.util.ArrayList;
import java.util.concurrent.atomic.AtomicBoolean;
import org.json.JSONObject;

// Hafız Kardeşim Android kabuğu: public/index.html telefonun içinden açılır.
// Sayfa, ezber dinletirken window.HKSes üzerinden Android'in Arapça ses tanımasını kullanır;
// duyulan metin window.hkSes(tür, metin) ile sayfaya geri gönderilir.
// Tür: basladi, kismi (okurken), son (bir cümle bitti), bitti, hata, izin-yok.
public class MainActivity extends Activity {
    private static final int IZIN_MIKROFON = 41;
    private WebView web;
    private final Handler main = new Handler(Looper.getMainLooper());
    private final AtomicBoolean adsStarted = new AtomicBoolean(false);
    private ConsentInformation consent;
    private InterstitialAd inter;
    private boolean interLoading;

    // ses tanıma
    private SpeechRecognizer rec;
    private boolean aktif;          // kullanıcı mikrofonu açık tuttuğu sürece true
    private boolean basladiDendi;
    private String dil = "ar-SA";
    private String sonKismi = "";
    private boolean sesKapali;
    private final Runnable dinleR = this::dinle;

    @Override
    protected void onCreate(Bundle saved) {
        super.onCreate(saved);
        web = new WebView(this);
        web.setBackgroundColor(getResources().getColor(R.color.bg, getTheme()));
        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);                 // ilerleme localStorage'da kalıcı
        s.setAllowFileAccess(true);
        s.setMediaPlaybackRequiresUserGesture(false); // ayet ayet arka arkaya çalabilsin
        s.setTextZoom(100);
        web.setOverScrollMode(WebView.OVER_SCROLL_NEVER);
        web.addJavascriptInterface(new Reklam(), "HKReklam");
        web.addJavascriptInterface(new Ses(), "HKSes");
        web.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView v, WebResourceRequest r) {
                Uri u = r.getUrl();
                String sc = u.getScheme();
                if ("file".equals(sc) || "about".equals(sc) || "data".equals(sc)) return false;
                try { startActivity(new Intent(Intent.ACTION_VIEW, u)); } catch (Exception ignored) {}
                return true;
            }
        });
        FrameLayout kok = new FrameLayout(this);
        kok.setBackgroundColor(getResources().getColor(R.color.bg, getTheme()));
        kok.addView(web, new FrameLayout.LayoutParams(-1, -1));
        if (android.os.Build.VERSION.SDK_INT >= 35) kok.setOnApplyWindowInsetsListener((v, ins) -> {
            int t = WindowInsets.Type.systemBars() | WindowInsets.Type.displayCutout() | WindowInsets.Type.ime();
            android.graphics.Insets i = ins.getInsets(t);
            v.setPadding(i.left, i.top, i.right, i.bottom);
            return WindowInsets.CONSUMED;
        });
        setContentView(kok);
        if (saved != null) web.restoreState(saved);
        else web.loadUrl("file:///android_asset/public/index.html");
        setupAds();
    }

    // ---------------- ses tanıma ----------------
    private class Ses {
        @JavascriptInterface public String var() {
            return SpeechRecognizer.isRecognitionAvailable(MainActivity.this) ? "1" : "0";
        }
        @JavascriptInterface public void basla(String lang) {
            main.post(() -> {
                if (lang != null && !lang.isEmpty()) dil = lang;
                if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                    requestPermissions(new String[]{Manifest.permission.RECORD_AUDIO}, IZIN_MIKROFON);
                    return;
                }
                baslat();
            });
        }
        @JavascriptInterface public void dur() { main.post(MainActivity.this::durdur); }
    }

    @Override
    public void onRequestPermissionsResult(int code, String[] p, int[] r) {
        super.onRequestPermissionsResult(code, p, r);
        if (code != IZIN_MIKROFON) return;
        if (r.length > 0 && r[0] == PackageManager.PERMISSION_GRANTED) baslat();
        else gonder("izin-yok", "");
    }

    private void baslat() {
        if (!SpeechRecognizer.isRecognitionAvailable(this)) { gonder("hata", "yok"); return; }
        aktif = true;
        basladiDendi = false;
        sonKismi = "";
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        sesiKis(true);
        dinle();
    }

    private void dinle() {
        if (!aktif) return;
        if (rec == null) {
            rec = SpeechRecognizer.createSpeechRecognizer(this);
            rec.setRecognitionListener(new Dinleyici());
        }
        Intent i = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
        i.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
        i.putExtra(RecognizerIntent.EXTRA_LANGUAGE, dil);
        i.putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, dil);
        i.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true);
        i.putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1);
        i.putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, getPackageName());
        // kâriler ayet sonunda nefes alır: sessizliği biraz uzun bekle
        i.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 2500);
        i.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 2000);
        i.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 15000);
        sonKismi = "";
        try { rec.startListening(i); } catch (Exception e) { yenidenDene(400); }
    }

    private void yenidenDene(long ms) {
        if (!aktif) return;
        main.removeCallbacks(dinleR);
        main.postDelayed(dinleR, ms);
    }

    private void durdur() {
        boolean vardi = aktif;
        aktif = false;
        main.removeCallbacks(dinleR);
        if (rec != null) {
            try { rec.cancel(); } catch (Exception ignored) {}
            try { rec.destroy(); } catch (Exception ignored) {}
            rec = null;
        }
        if (!sonKismi.isEmpty()) { gonder("son", sonKismi); sonKismi = ""; }
        getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        sesiKis(false);
        if (vardi) gonder("bitti", "");
    }

    // Google ses tanıma her yeniden başlamada "bip" çalar; dinlerken bu sesleri kıs.
    private void sesiKis(boolean kis) {
        if (kis == sesKapali) return;
        sesKapali = kis;
        try {
            AudioManager am = (AudioManager) getSystemService(AUDIO_SERVICE);
            int y = kis ? AudioManager.ADJUST_MUTE : AudioManager.ADJUST_UNMUTE;
            am.adjustStreamVolume(AudioManager.STREAM_MUSIC, y, 0);
            am.adjustStreamVolume(AudioManager.STREAM_SYSTEM, y, 0);
        } catch (Exception ignored) {}
    }

    private class Dinleyici implements RecognitionListener {
        @Override public void onReadyForSpeech(Bundle b) {
            if (!basladiDendi) { basladiDendi = true; gonder("basladi", ""); }
        }
        @Override public void onBeginningOfSpeech() {}
        @Override public void onRmsChanged(float v) {}
        @Override public void onBufferReceived(byte[] b) {}
        @Override public void onEndOfSpeech() {}
        @Override public void onEvent(int t, Bundle b) {}
        @Override public void onPartialResults(Bundle b) {
            String t = ilk(b);
            if (t != null && !t.isEmpty()) { sonKismi = t; gonder("kismi", t); }
        }
        @Override public void onResults(Bundle b) {
            String t = ilk(b);
            if (t == null || t.isEmpty()) t = sonKismi;
            sonKismi = "";
            if (t != null && !t.isEmpty()) gonder("son", t);
            yenidenDene(60);
        }
        @Override public void onError(int e) {
            if (!aktif) return;
            switch (e) {
                case SpeechRecognizer.ERROR_NO_MATCH:
                case SpeechRecognizer.ERROR_SPEECH_TIMEOUT:
                    if (!sonKismi.isEmpty()) { gonder("son", sonKismi); sonKismi = ""; }
                    yenidenDene(60);
                    break;
                case SpeechRecognizer.ERROR_RECOGNIZER_BUSY:
                case SpeechRecognizer.ERROR_CLIENT:
                    try { if (rec != null) rec.cancel(); } catch (Exception ignored) {}
                    yenidenDene(350);
                    break;
                case SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS:
                    durdur(); gonder("izin-yok", ""); break;
                case SpeechRecognizer.ERROR_NETWORK:
                case SpeechRecognizer.ERROR_NETWORK_TIMEOUT:
                case SpeechRecognizer.ERROR_SERVER:
                    durdur(); gonder("hata", "ag"); break;
                case 12: // ERROR_LANGUAGE_NOT_SUPPORTED
                case 13: // ERROR_LANGUAGE_UNAVAILABLE
                    durdur(); gonder("hata", "dil"); break;
                default:
                    yenidenDene(500);
            }
        }
    }

    private static String ilk(Bundle b) {
        if (b == null) return null;
        ArrayList<String> l = b.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
        return (l == null || l.isEmpty()) ? null : l.get(0);
    }

    private void gonder(String tur, String metin) {
        main.post(() -> web.evaluateJavascript("window.hkSes&&window.hkSes(" + JSONObject.quote(tur) + "," + JSONObject.quote(metin) + ")", null));
    }

    @Override
    protected void onPause() {
        super.onPause();
        if (aktif) durdur();
    }

    @Override
    protected void onDestroy() {
        aktif = false;
        if (rec != null) try { rec.destroy(); } catch (Exception ignored) {}
        sesiKis(false);
        super.onDestroy();
    }

    // ---------------- reklam ----------------
    // AEA/BK kullanıcıları için izin formu (UMP), ardından AdMob başlatılır
    private void setupAds() {
        consent = UserMessagingPlatform.getConsentInformation(this);
        consent.requestConsentInfoUpdate(this, new ConsentRequestParameters.Builder().build(),
            () -> UserMessagingPlatform.loadAndShowConsentFormIfRequired(this, err -> { if (consent.canRequestAds()) startAds(); }),
            err -> { if (consent.canRequestAds()) startAds(); });
        if (consent.canRequestAds()) startAds();
    }

    private void startAds() {
        if (!adsStarted.compareAndSet(false, true)) return;
        new Thread(() -> {
            MobileAds.initialize(this, st -> {});
            main.post(this::loadInter);
        }).start();
    }

    private void loadInter() {
        if (!adsStarted.get() || inter != null || interLoading) return;
        interLoading = true;
        InterstitialAd.load(this, getString(R.string.ad_interstitial), new AdRequest.Builder().build(), new InterstitialAdLoadCallback() {
            @Override public void onAdLoaded(InterstitialAd ad) { interLoading = false; inter = ad; }
            @Override public void onAdFailedToLoad(LoadAdError e) { interLoading = false; inter = null; main.postDelayed(MainActivity.this::loadInter, 30000); }
        });
    }

    private void showInterstitial() {
        if (aktif) return;   // ezber dinletirken reklam açılmaz
        final InterstitialAd ad = inter;
        if (ad == null) { loadInter(); return; }
        inter = null;
        ad.setFullScreenContentCallback(new FullScreenContentCallback() {
            @Override public void onAdDismissedFullScreenContent() { loadInter(); }
            @Override public void onAdFailedToShowFullScreenContent(AdError e) { loadInter(); }
        });
        ad.show(this);
    }

    private class Reklam {
        @JavascriptInterface public void goster() { main.post(MainActivity.this::showInterstitial); }
    }

    @Override
    protected void onSaveInstanceState(Bundle out) {
        super.onSaveInstanceState(out);
        web.saveState(out);
    }

    // Geri tuşu: alt ekrandaysa bir önceki ekrana döner, ana menüdeyse uygulamadan çıkar.
    @Override
    @SuppressWarnings("deprecation")
    public void onBackPressed() {
        web.evaluateJavascript("(function(){try{return back()}catch(e){return 'exit'}})()", val -> {
            if (val == null || val.contains("exit")) finish();
        });
    }
}
