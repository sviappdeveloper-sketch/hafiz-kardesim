# Model yoklama: dosya düzeni, belirteçler, fonem verilerinin yapısı ve sherpa-onnx ile deneme çözümü.
import json, os, sys, glob, subprocess, wave, numpy as np
from huggingface_hub import list_repo_files, hf_hub_download
tok = os.environ["HF_TOKEN"]
out = open("/tmp/o/rapor.txt", "w")
def p(*a):
    print(*a); print(*a, file=out); out.flush()
R = {"v3": "Quran-Lab/zipformer_p-arabic-v3", "q": "Muno459/zipformer_p-quran"}
for k, r in R.items():
    try:
        fs = list_repo_files(r, token=tok)
        p(f"== {r}: {len(fs)} dosya"); [p("  ", f) for f in fs if "mlpackage" not in f or f.endswith("Manifest.json")]
    except Exception as e:
        p(r, "HATA", e)
D = "/tmp/m"; os.makedirs(D, exist_ok=True)
def al(r, f):
    return hf_hub_download(r, f, token=tok, local_dir=D + "/" + r.split("/")[0])
r = R["v3"]
small = ["tokens.txt", "phoneme_units.json", "config.json", "ordered_quran_phonemes.json", "quran_text2phoneme.json", "packing_front.json"]
for f in small:
    try:
        x = al(r, f); p(f"--- {f} ({os.path.getsize(x)} B)")
        if f == "tokens.txt":
            L = open(x, encoding="utf8").read().splitlines(); p(len(L), "satır"); p(" | ".join(L))
        elif f.endswith(".json"):
            j = json.load(open(x, encoding="utf8"))
            def ozet(j, d=0):
                if isinstance(j, dict):
                    ks = list(j.keys()); p("  " * d + f"dict {len(ks)} anahtar: {ks[:12]}")
                    for kk in ks[:3]: p("  " * d + f"[{kk!r}] ->"); ozet(j[kk], d + 1)
                elif isinstance(j, list):
                    p("  " * d + f"list {len(j)}");
                    for e in j[:3]: ozet(e, d + 1)
                else:
                    p("  " * d + repr(j)[:400])
            ozet(j)
    except Exception as e:
        p(f, "HATA", e)
# Fâtiha ve Bakara başı için tam fonemler
try:
    j = json.load(open(D + "/Quran-Lab/ordered_quran_phonemes.json", encoding="utf8"))
    s = json.dumps(j if not isinstance(j, list) else j[:9], ensure_ascii=False)
    p("ordered ilk:", s[:3000])
    if isinstance(j, dict):
        for kk in list(j.keys())[:9]: p(kk, json.dumps(j[kk], ensure_ascii=False)[:600])
except Exception as e: p("ordered HATA", e)
try:
    j = json.load(open(D + "/Quran-Lab/quran_text2phoneme.json", encoding="utf8"))
    if isinstance(j, dict):
        for kk in list(j.keys())[:12]: p("t2p", kk, json.dumps(j[kk], ensure_ascii=False)[:600])
    else:
        p("t2p", json.dumps(j[:12], ensure_ascii=False)[:3000])
except Exception as e: p("t2p HATA", e)
# ONNX meta
import onnx
for f in ["zipformer_p_arabic_v3.int8.onnx", "zipformer_p_arabic_v3.1.int8.onnx"]:
    try:
        x = al(r, f); p(f"--- {f} {os.path.getsize(x)} B")
        m = onnx.load(x, load_external_data=False)
        p({e.key: e.value[:200] for e in m.metadata_props})
        p("girdiler:", [(i.name, [d.dim_value or d.dim_param for d in i.type.tensor_type.shape.dim]) for i in m.graph.input][:6], "...", len(m.graph.input))
        p("çıktılar:", [o.name for o in m.graph.output][:4], len(m.graph.output))
    except Exception as e: p(f, "HATA", e)
# sherpa-onnx deneme
import sherpa_onnx
wavs = sorted(glob.glob("/tmp/ses/*.wav"))
for f in ["zipformer_p_arabic_v3.int8.onnx", "zipformer_p_arabic_v3.1.int8.onnx"]:
    try:
        rec = sherpa_onnx.OnlineRecognizer.from_zipformer2_ctc(tokens=D + "/Quran-Lab/tokens.txt", model=D + "/Quran-Lab/" + f, num_threads=2, sample_rate=16000, feature_dim=80, decoding_method="greedy_search")
        p("=== sherpa", f)
        for w in wavs:
            wf = wave.open(w); a = np.frombuffer(wf.readframes(wf.getnframes()), dtype=np.int16).astype(np.float32) / 32768
            s = rec.create_stream(); import time; t0 = time.time()
            ara = []
            for i in range(0, len(a), 1600):
                s.accept_waveform(16000, a[i:i + 1600])
                while rec.is_ready(s): rec.decode_stream(s)
                if i % 16000 == 0: ara.append(rec.get_result(s))
            s.accept_waveform(16000, np.zeros(8000, np.float32)); s.input_finished()
            while rec.is_ready(s): rec.decode_stream(s)
            res = rec.get_result_all(s)
            p(os.path.basename(w), f"{len(a)/16000:.1f}s işlem {time.time()-t0:.2f}s")
            p("  metin:", res.text)
            p("  belirteç:", " ".join(res.tokens)[:800])
            p("  zaman:", [round(t, 2) for t in res.timestamps][:40])
            p("  ara(her sn):", ara[:6])
    except Exception as e:
        import traceback; p(f, "sherpa HATA", traceback.format_exc()[-1500:])
p("bitti")
