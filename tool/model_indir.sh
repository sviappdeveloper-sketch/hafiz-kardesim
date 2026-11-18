#!/usr/bin/env bash
# Kulak (kendi ses tanımamız) için Kur'an modeli: Abdou/quran-asr-tiny (MIT), ~19 MB.
set -euo pipefail
d="$(dirname "$0")/../assets/asr"
mkdir -p "$d"
u=https://huggingface.co/Abdou/quran-asr-tiny/resolve/main
for f in model.int8.onnx tokens.txt; do
  if [ ! -s "$d/$f" ]; then
    curl -fsSL --retry 4 --retry-delay 5 -o "$d/$f" "$u/$f"
  fi
done
ls -la "$d"
test "$(stat -c%s "$d/model.int8.onnx" 2>/dev/null || stat -f%z "$d/model.int8.onnx")" -gt 5000000
echo "tokens: $(wc -l < "$d/tokens.txt")"; head -40 "$d/tokens.txt" | tr '\n' ' '; echo
