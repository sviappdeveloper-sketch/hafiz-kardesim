#!/usr/bin/env bash
# Kulak (kendi ses tanımamız) için akan Kur'an modeli: Quran-Lab/zipformer_p-arabic-v3 (~73 MB, int8).
# Model Hugging Face'te kilitli: depo sahibinin hesabıyla şartları kabul edilmiştir; indirme için
# GitHub'da "HF_TOKEN" adlı gizli anahtar (Secret) gerekir.
# Lisans (Quran-Lab NPL-1.2): yalnızca ücretsiz uygulamalarda kullanılabilir; dosyalar depoya konmaz.
set -euo pipefail
d="$(cd "$(dirname "$0")/.." && pwd)"
a="$d/assets/asr"
mkdir -p "$a"
if [ -z "${HF_TOKEN:-}" ]; then
  echo "::error title=HF_TOKEN yok::GitHub > Settings > Secrets and variables > Actions > Secrets bölümüne HF_TOKEN eklenmeli"
  exit 1
fi
u=https://huggingface.co/Quran-Lab/zipformer_p-arabic-v3/resolve/main
al() { # kaynak hedef
  if [ ! -s "$2" ]; then
    curl -fsSL --retry 4 --retry-delay 5 -H "Authorization: Bearer $HF_TOKEN" -o "$2" "$u/$1"
  fi
}
al zipformer_p_arabic_v3.int8.onnx "$a/model.int8.onnx"
al tokens.txt "$a/tokens.txt"
al ordered_quran_phonemes.json /tmp/ordered_quran_phonemes.json
python3 "$d/tool/fonem_hazirla.py" "$d/assets/quran/quran.json" /tmp/ordered_quran_phonemes.json "$a/fonem.json"
ls -la "$a"
test "$(stat -c%s "$a/model.int8.onnx" 2>/dev/null || stat -f%z "$a/model.int8.onnx")" -gt 50000000
echo "tokens: $(wc -l < "$a/tokens.txt")"
