"""CI: flutter create sonrası Android projesini yayına hazırlar.
- Uygulama adı ve internet izni
- minSdk 23
- android-keys/ içindeki yükleme anahtarıyla release imzası
"""
import pathlib, re, shutil, sys

root = pathlib.Path('.')
manifest = root / 'android/app/src/main/AndroidManifest.xml'
m = manifest.read_text()
if 'android.permission.INTERNET' not in m:
    m = m.replace('<application', '<uses-permission android:name="android.permission.INTERNET"/>\n    <application', 1)
m = re.sub(r'android:label="[^"]*"', 'android:label="Hafız Kardeşim"', m, count=1)
# Bildirimler (flutter_local_notifications): izinler ve zamanlanmış bildirim alıcıları.
perms = ['android.permission.POST_NOTIFICATIONS', 'android.permission.RECEIVE_BOOT_COMPLETED',
         'android.permission.VIBRATE', 'android.permission.SCHEDULE_EXACT_ALARM']
for p_ in perms:
    if p_ not in m:
        m = m.replace('<application', f'<uses-permission android:name="{p_}"/>\n    <application', 1)
if 'ScheduledNotificationReceiver' not in m:
    receivers = (
        '        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver" />\n'
        '        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />\n'
        '        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">\n'
        '            <intent-filter>\n'
        '                <action android:name="android.intent.action.BOOT_COMPLETED"/>\n'
        '                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>\n'
        '                <action android:name="android.intent.action.QUICKBOOT_POWERON" />\n'
        '                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>\n'
        '            </intent-filter>\n'
        '        </receiver>\n'
    )
    m = m.replace('    </application>', receivers + '    </application>', 1)
# Sesli Kur'an (audio_service): ekran kilitliyken çalmayı sürdüren ön plan hizmeti ve izinleri.
for p_ in ['android.permission.WAKE_LOCK', 'android.permission.FOREGROUND_SERVICE',
           'android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK']:
    if p_ not in m:
        m = m.replace('<application', f'<uses-permission android:name="{p_}"/>\n    <application', 1)
if 'com.ryanheise.audioservice.AudioService' not in m:
    ses = (
        '        <service android:name="com.ryanheise.audioservice.AudioService" android:foregroundServiceType="mediaPlayback" android:exported="true">\n'
        '            <intent-filter>\n'
        '                <action android:name="android.media.browse.MediaBrowserService"/>\n'
        '            </intent-filter>\n'
        '        </service>\n'
        '        <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver" android:exported="true">\n'
        '            <intent-filter>\n'
        '                <action android:name="android.intent.action.MEDIA_BUTTON"/>\n'
        '            </intent-filter>\n'
        '        </receiver>\n'
    )
    m = m.replace('    </application>', ses + '    </application>', 1)
# Hafız Kardeşim: sesli ezber için mikrofon; Android 11+ ses tanıma hizmetini görebilmek için <queries>;
# telefonun geri kaydırma hareketi (predictive back) uygulamanın kendi geri adımlarıyla çalışsın.
if 'android.permission.RECORD_AUDIO' not in m:
    m = m.replace('<application', '<uses-permission android:name="android.permission.RECORD_AUDIO"/>\n    <application', 1)
if 'android.speech.RecognitionService' not in m:
    niyet = '        <intent>\n            <action android:name="android.speech.RecognitionService" />\n        </intent>\n'
    if '<queries>' in m:
        m = m.replace('<queries>', '<queries>\n' + niyet, 1)
    else:
        m = m.replace('<application', '<queries>\n' + niyet + '    </queries>\n    <application', 1)
if 'enableOnBackInvokedCallback' not in m:
    m = m.replace('<application', '<application\n        android:enableOnBackInvokedCallback="true"', 1)
manifest.write_text(m)

# audio_service, ana etkinliğin AudioServiceActivity'den türemesini ister.
aktiviteler = list((root / 'android/app/src/main').rglob('MainActivity.kt'))
if not aktiviteler:
    sys.exit('MainActivity.kt bulunamadı (audio_service için gerekli)')
for kt in aktiviteler:
    t = kt.read_text()
    if 'AudioServiceActivity' not in t:
        t = t.replace('import io.flutter.embedding.android.FlutterActivity', 'import com.ryanheise.audioservice.AudioServiceActivity')
        t = re.sub(r':\s*FlutterActivity\(\)', ': AudioServiceActivity()', t)
        if 'AudioServiceActivity()' not in t:
            sys.exit('MainActivity.kt beklenen biçimde değil: ' + str(kt))
        kt.write_text(t)

# Derleme sunucusunda 7 GB bellek var; Flutter'ın varsayılan -Xmx8G ayarı sunucuyu boğuyor.
props = root / 'android/gradle.properties'
pt = props.read_text() if props.exists() else ''
pt = re.sub(r'(?m)^org\.gradle\.jvmargs=.*$', '', pt)
pt = re.sub(r'(?m)^(kotlin\.daemon\.jvmargs|org\.gradle\.workers\.max|org\.gradle\.parallel)=.*$', '', pt)
pt = pt.strip() + (
    '\norg.gradle.jvmargs=-Xmx3g -XX:MaxMetaspaceSize=1g -XX:+HeapDumpOnOutOfMemoryError -Dfile.encoding=UTF-8'
    '\nkotlin.daemon.jvmargs=-Xmx1g'
    '\norg.gradle.workers.max=2'
    '\norg.gradle.parallel=false\n'
)
props.write_text(pt)

# Gradle'ı resmî adresten indir (yeni şablondaki GitHub adresi zaman zaman yanıt vermiyor).
wrapper = root / 'android/gradle/wrapper/gradle-wrapper.properties'
if wrapper.exists():
    w = wrapper.read_text()
    w = re.sub(r'distributionUrl=.*/(gradle-[0-9.]+-(?:all|bin)\.zip)',
               r'distributionUrl=https\\://services.gradle.org/distributions/\1', w)
    wrapper.write_text(w)
    print('gradle:', [l for l in w.splitlines() if l.startswith('distributionUrl')])

# Ana ekran namaz vakti widget'ı: yerel dosyaları kopyala, alıcıyı manifeste ekle.
extra = root / 'tool/android'
kt = root / 'android/app/src/main/kotlin/com/sviapp/hafiz_kardesim'
kt.mkdir(parents=True, exist_ok=True)
for k in (extra / 'kotlin').glob('*.kt'):
    (kt / k.name).write_text(k.read_text().replace('com.hatimkardesim.hatim_kardesim', 'com.sviapp.hafiz_kardesim'))
for f in [p for p in (extra / 'res').rglob('*') if p.is_file()]:
    dst = root / 'android/app/src/main/res' / f.relative_to(extra / 'res')
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy(f, dst)
m = manifest.read_text()
if 'PrayerWidgetProvider' not in m:
    widget = (
        '        <receiver android:name=".PrayerWidgetProvider" android:exported="true">\n'
        '            <intent-filter>\n'
        '                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />\n'
        '            </intent-filter>\n'
        '            <meta-data android:name="android.appwidget.provider" android:resource="@xml/prayer_widget_info" />\n'
        '        </receiver>\n'
    )
    m = m.replace('    </application>', widget + '    </application>', 1)
    manifest.write_text(m)

# Bildirim çubuğunda vakitler: alarm ve açılışta kendini yeniden kuran alıcı.
m = manifest.read_text()
if 'PrayerBarReceiver' not in m:
    bar = (
        '        <receiver android:name=".PrayerBarReceiver" android:exported="false">\n'
        '            <intent-filter>\n'
        '                <action android:name="android.intent.action.BOOT_COMPLETED" />\n'
        '                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />\n'
        '                <action android:name="android.intent.action.TIME_SET" />\n'
        '                <action android:name="android.intent.action.TIMEZONE_CHANGED" />\n'
        '            </intent-filter>\n'
        '        </receiver>\n'
    )
    m = m.replace('    </application>', bar + '    </application>', 1)
    manifest.write_text(m)

gradle = root / 'android/app/build.gradle.kts'
if not gradle.exists():
    sys.exit('build.gradle.kts bulunamadı')
g = gradle.read_text()
g = re.sub(r'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 23', g)
# Bildirim kütüphanesi için Java kütüphane desteği (desugaring).
if 'isCoreLibraryDesugaringEnabled' not in g:
    g = re.sub(r'compileOptions\s*\{', 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true', g, count=1)
if 'desugar_jdk_libs' not in g:
    g += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
# Kıble pusulası: Google'ın birleşik yön servisi (Fused Orientation Provider, 21.2+).
if 'play-services-location' not in g:
    g += '\ndependencies {\n    implementation("com.google.android.gms:play-services-location:21.3.0")\n}\n'

keys = root / 'android-keys'
if (keys / 'key.properties').exists():
    shutil.copy(keys / 'upload-keystore.jks', root / 'android/app/upload-keystore.jks')
    shutil.copy(keys / 'key.properties', root / 'android/key.properties')
    if 'import java.util.Properties' not in g:
        g = 'import java.util.Properties\nimport java.io.FileInputStream\n\n' + g
    loader = (
        '\nval keystoreProperties = Properties()\n'
        'val keystorePropertiesFile = rootProject.file("key.properties")\n'
        'if (keystorePropertiesFile.exists()) {\n'
        '    keystoreProperties.load(FileInputStream(keystorePropertiesFile))\n'
        '}\n'
    )
    g = g.replace('\nandroid {', loader + '\nandroid {', 1)
    signing = (
        '    signingConfigs {\n'
        '        create("release") {\n'
        '            keyAlias = keystoreProperties["keyAlias"] as String\n'
        '            keyPassword = keystoreProperties["keyPassword"] as String\n'
        '            storeFile = file(keystoreProperties["storeFile"] as String)\n'
        '            storePassword = keystoreProperties["storePassword"] as String\n'
        '        }\n'
        '    }\n\n'
        '    buildTypes {'
    )
    g = g.replace('    buildTypes {', signing, 1)
    g = re.sub(r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)',
               'signingConfig = signingConfigs.getByName("release")', g)
gradle.write_text(g)

# Yayın derlemesindeki "lintVital" denetimi bazı eklentilerde (google_sign_in_android) Android
# lint aracının kendi hatasıyla çöküyor (List.removeLast / JDK uyumsuzluğu); uygulama koduyla
# ilgisi yok. Bu denetim tüm alt projelerde kapatılır.
root_gradle = root / 'android/build.gradle.kts'
rg = root_gradle.read_text()
if 'lintVital' not in rg:
    rg += ('\nsubprojects {\n'
           '    tasks.matching { it.name.startsWith("lintVital") }.configureEach { enabled = false }\n'
           '}\n')
    root_gradle.write_text(rg)

# R8 kuralları: WorkManager/Room sınıfları korunur (aksi hâlde uygulama açılışta çöker).
shutil.copy(root / 'tool/android/proguard-rules.pro', root / 'android/app/proguard-rules.pro')
if 'proguard-rules.pro' not in g:
    g, n = re.subn(r'(buildTypes\s*\{\s*(?:release|getByName\("release"\))\s*\{)',
                   r'\1\n            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")',
                   g, count=1)
    if n == 0:
        sys.exit('release derleme türü bulunamadı (proguard)')
gradle.write_text(g)

# Açılış: Android'in kendi açılış ekranı da uygulamanın koyu zümrüt zemini olsun ki
# beyaz ekran / farklı arayüz geçişi görünmesin.
res = root / 'android/app/src/main/res'
(res / 'values').mkdir(parents=True, exist_ok=True)
(res / 'values/splash_colors.xml').write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
    '    <color name="hk_splash">#FF001A0D</color>\n</resources>\n')
bg = ('<?xml version="1.0" encoding="utf-8"?>\n'
      '<layer-list xmlns:android="http://schemas.android.com/apk/res/android">\n'
      '    <item android:drawable="@color/hk_splash" />\n</layer-list>\n')
for d in ('drawable', 'drawable-v21'):
    (res / d).mkdir(parents=True, exist_ok=True)
    (res / d / 'launch_background.xml').write_text(bg)
for d in ('values', 'values-night'):
    f = res / d / 'styles.xml'
    if f.exists():
        t = f.read_text()
        t = t.replace('?android:colorBackground', '@color/hk_splash')
        f.write_text(t)
(res / 'values-v31').mkdir(parents=True, exist_ok=True)
(res / 'values-v31/styles.xml').write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
    '    <style name="LaunchTheme" parent="@android:style/Theme.Black.NoTitleBar">\n'
    '        <item name="android:windowBackground">@drawable/launch_background</item>\n'
    '        <item name="android:windowSplashScreenBackground">@color/hk_splash</item>\n'
    '        <item name="android:windowSplashScreenAnimatedIcon">@android:color/transparent</item>\n'
    '    </style>\n'
    '    <style name="NormalTheme" parent="@android:style/Theme.Black.NoTitleBar">\n'
    '        <item name="android:windowBackground">@color/hk_splash</item>\n'
    '    </style>\n</resources>\n')
print(g)
