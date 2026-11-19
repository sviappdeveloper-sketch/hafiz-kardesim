#!/usr/bin/env python3
"""GitHub Actions iPhone yayını: Runner hedefini elle imzaya (App Store profili) çevirir.
Kullanım: python3 tool/ios_elle_imza.py PROFIL_ADI TAKIM_KIMLIGI"""
import re
import sys
from pathlib import Path

profil, takim = sys.argv[1], sys.argv[2]
pbx = Path("ios/Runner.xcodeproj/project.pbxproj")
s = pbx.read_text(encoding="utf-8")
ek = (f'CODE_SIGN_STYLE = Manual; DEVELOPMENT_TEAM = {takim}; '
      f'"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "Apple Distribution"; '
      f'PROVISIONING_PROFILE_SPECIFIER = "{profil}"; ')
n = 0


def degistir(m):
    global n
    blok = m.group(0)
    if "PRODUCT_BUNDLE_IDENTIFIER = com.sviapp.hafizKardesim;" not in blok:
        return blok
    blok = re.sub(r'\s*(CODE_SIGN_STYLE|DEVELOPMENT_TEAM|PROVISIONING_PROFILE_SPECIFIER|"CODE_SIGN_IDENTITY\[sdk=iphoneos\*\]"|CODE_SIGN_IDENTITY) = [^;]*;', "", blok)
    n += 1
    return blok.replace("buildSettings = {", "buildSettings = {\n\t\t\t\t" + ek, 1)


s = re.sub(r"buildSettings = \{.*?\n\t\t\t\};", degistir, s, flags=re.S)
pbx.write_text(s, encoding="utf-8")
print("Elle imza ayarlandı:", n, "yapılandırma")
if n == 0:
    sys.exit(1)
