#!/usr/bin/env python3
"""iOS projesini yayına hazırlar (flutter create sonrası CI'da çalışır).

- Uygulama adı, izin açıklamaları, şifreleme beyanı (Info.plist)
- En düşük iOS sürümü 15 (güncel Flutter gereği)
- Apple ile Giriş yetkisi (Runner.entitlements)
- iPhone'da Google ile giriş için URL şeması (iOS istemci kimliği girildiyse)
"""
import plistlib
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
IOS = ROOT / "ios"
MIN_IOS = "15.0"

# --- Info.plist ---
info_path = IOS / "Runner" / "Info.plist"
with open(info_path, "rb") as f:
    info = plistlib.load(f)

info["CFBundleDisplayName"] = "Hafız Kardeşim"
info["CFBundleName"] = "Hafız Kardeşim"
info["CFBundleDevelopmentRegion"] = "tr"
info["CFBundleLocalizations"] = ["tr", "en", "ar"]
info["ITSAppUsesNonExemptEncryption"] = False
info["NSPhotoLibraryUsageDescription"] = (
    "Destek mesajınıza görsel eklemek için fotoğraflarınızdan seçim yapabilirsiniz."
)
info["NSCameraUsageDescription"] = "Destek mesajınıza görsel eklemek için kamera kullanılabilir."
info["NSMicrophoneUsageDescription"] = (
    "Ezberinizi dinletirken okuduğunuzu duyup doğru ve hatalı kelimeleri gösterebilmek için mikrofon kullanılır. "
    "Ses kaydedilmez ve saklanmaz."
)
info["NSSpeechRecognitionUsageDescription"] = (
    "Okuduğunuz ayetleri metne çevirip ezberinizle karşılaştırmak için Apple'ın konuşma tanıma hizmeti kullanılır."
)
info["NSPhotoLibraryAddUsageDescription"] = "Görselleri fotoğraflarınıza kaydetmek için izin istenebilir."
info["NSMotionUsageDescription"] = "Kıble pusulasının yönü göstermesi için cihazın pusula sensörü kullanılır."
# Kıble pusulası yönü iOS'un konum servisinden (CLLocationManager yön bilgisi) alır.
info["NSLocationWhenInUseUsageDescription"] = "Kıble pusulasının doğru yönü göstermesi için cihazın pusula bilgisi kullanılır; konumunuz kaydedilmez."
info["UIRequiresFullScreen"] = False
# Hafız Kardeşim arka planda ses çalmaz: arka plan modu istenmez.
info.pop("UIBackgroundModes", None)
info.pop("UISupportedInterfaceOrientations~ipad", None)

# Google ile giriş için ters istemci kimliği URL şeması.
consts = (ROOT / "lib" / "models" / "constants.dart").read_text(encoding="utf-8")
m = re.search(r"googleIosClientId\s*=\s*'([^']*)'", consts)
ios_client = m.group(1) if m else ""
if ios_client.endswith(".apps.googleusercontent.com"):
    reversed_id = "com.googleusercontent.apps." + ios_client.replace(".apps.googleusercontent.com", "")
    info["GIDClientID"] = ios_client
    types = [t for t in info.get("CFBundleURLTypes", []) if reversed_id not in t.get("CFBundleURLSchemes", [])]
    types.append({"CFBundleTypeRole": "Editor", "CFBundleURLSchemes": [reversed_id]})
    info["CFBundleURLTypes"] = types
    print("Google URL şeması eklendi:", reversed_id)
else:
    print("iOS Google istemci kimliği yok; iPhone'da Google ile giriş gizli kalacak.")

with open(info_path, "wb") as f:
    plistlib.dump(info, f)

# --- Apple ile Giriş yetkisi ---
ent_path = IOS / "Runner" / "Runner.entitlements"
with open(ent_path, "wb") as f:
    plistlib.dump({"com.apple.developer.applesignin": ["Default"]}, f)

# --- Xcode projesi: yetki dosyası ve en düşük iOS sürümü ---
pbx_path = IOS / "Runner.xcodeproj" / "project.pbxproj"
pbx = pbx_path.read_text(encoding="utf-8")
# Yalnızca iPhone (iPad ekran görüntüsü ve iPad incelemesi gerekmesin).
pbx = re.sub(r'TARGETED_DEVICE_FAMILY = "?[0-9,]+"?;', 'TARGETED_DEVICE_FAMILY = 1;', pbx)
pbx = re.sub(r"IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;", f"IPHONEOS_DEPLOYMENT_TARGET = {MIN_IOS};", pbx)
if "CODE_SIGN_ENTITLEMENTS" not in pbx:
    # Yalnızca Runner hedefinin yapılandırmaları (test hedefinde ".RunnerTests" geçer).
    pbx = re.sub(
        r"(\n(\s*)PRODUCT_BUNDLE_IDENTIFIER = com\.sviapp\.hafizKardesim;)",
        r"\n\2CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\1",
        pbx,
    )
pbx_path.write_text(pbx, encoding="utf-8")
print("Yetki dosyası bağlandı:", pbx.count("CODE_SIGN_ENTITLEMENTS"), "yapılandırma")

# --- Podfile: en düşük iOS sürümü ---
pod_path = IOS / "Podfile"
pod = pod_path.read_text(encoding="utf-8")
pod = re.sub(r"^#?\s*platform :ios, '[0-9.]+'", f"platform :ios, '{MIN_IOS}'", pod, flags=re.M)
if f"platform :ios, '{MIN_IOS}'" not in pod:
    pod = f"platform :ios, '{MIN_IOS}'\n" + pod
pod_path.write_text(pod, encoding="utf-8")
print("iOS hazırlığı tamam.")
