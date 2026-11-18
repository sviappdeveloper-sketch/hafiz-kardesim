# Kulak için kelime fonemleri: uygulamanın mushaf metnindeki her kelimeye, Quran-Lab'ın
# ordered_quran_phonemes.json dosyasındaki (tecvidli) fonem yazımını eşler.
#
# Fonem listesi bazen iki-üç kelimeyi tek parça yazar (idğam: "هُدًى لِّلْمُتَّقِينَ" → tek parça),
# bazen bir kelimeyi ikiye böler (mukattaa: "الٓمٓ" → "ءَلِف" + "لَااممِيم"). Kelimeler ünsüz iskeletleriyle
# hizalanır; birleşik parça, kelimelerin iskelet uzunluğu oranında bölünür.
#
# Kullanım: python3 tool/fonem_hazirla.py <quran.json> <ordered_quran_phonemes.json> <çıktı.json>
# Çıktı: 6236 ayetin her biri için kelime kelime fonem listesi (uygulamanın kelime bölmesiyle aynı sırada).
# Lisans gereği (Quran-Lab NPL-1.2) bu dosya depoya konmaz; derleme sırasında üretilir.
import json
import re
import sys

HAREKE = re.compile('[ؐ-ًؚ-ٰٟۖ-ۭـ‌‍‏﻿]')
ELIF = re.compile('[ٱأإآٲٳ]')
ARAP_DISI = re.compile('[^ء-ي]')


def nrm(w):
    """lib/hafiz/arapca.dart nrm() ile aynı."""
    w = HAREKE.sub('', w)
    w = ELIF.sub('ا', w).replace('ة', 'ه')
    w = re.sub('[ىی]', 'ي', w).replace('ؤ', 'و').replace('ئ', 'ي').replace('ء', '').replace('ک', 'ك')
    return ARAP_DISI.sub('', w)


def skel_w(w):
    return re.sub('[اويى]', '', nrm(w))


FON_AT = re.compile('[ؙـڇَُِ۪ۜاۦۥويء]')


def skel_p(p):
    p = p.replace('ں', 'ن').replace('۾', 'م')
    p = FON_AT.sub('', p)
    return re.sub(r'(.)\1+', r'\1', p)


def skel_w2(w):
    return re.sub(r'(.)\1+', r'\1', skel_w(w))


def lev(a, b):
    if a == b:
        return 0
    p = list(range(len(b) + 1))
    for i in range(1, len(a) + 1):
        q = [i] + [0] * len(b)
        for j in range(1, len(b) + 1):
            q[j] = min(p[j] + 1, q[j - 1] + 1, p[j - 1] + (a[i - 1] != b[j - 1]))
        p = q
    return p[len(b)]


def rat(a, b):
    m = max(len(a), len(b))
    return 1.0 if m == 0 else 1 - lev(a, b) / m


ADIM = [(a, 1) for a in range(1, 8)] + [(1, b) for b in range(2, 6)] + [(2, 2)]


def bol(p, parcalar):
    """Fonem dizisini [parcalar] iskelet uzunlukları oranında böler (hareke ünsüzüyle kalır).
    Her parça boş olmayan bir dizi alır."""
    k = len(parcalar)
    if k == 1:
        return [p]
    sessiz = [i for i, c in enumerate(p) if skel_p(c)]
    if len(sessiz) < k:
        sessiz = list(range(len(p)))  # ünsüz az: harf harf bölünür
    n, toplam = len(sessiz), max(1, sum(parcalar))
    if n < k:
        return [p] + [p[-1:] or p] * (k - 1)
    kes, birikim, onceki = [], 0, 0
    for z, x in enumerate(parcalar[:-1]):
        birikim += x
        h = round(n * birikim / toplam)
        h = max(h, onceki + 1)
        h = min(h, n - (k - 1 - z))
        kes.append(sessiz[h])
        onceki = h
    sonuc, bas = [], 0
    for poz in kes:
        sonuc.append(p[bas:poz])
        bas = poz
    sonuc.append(p[bas:])
    return sonuc


def hizala(W, P):
    """W: uygulamanın kelimeleri, P: fonem parçaları → her kelime için fonem."""
    if len(W) == len(P):
        return [list(P)], 0.0, 'esit'
    sw = [skel_w2(w) for w in W]
    sp = [skel_p(p) for p in P]
    INF = 1e9
    n, m = len(W), len(P)
    d = [[INF] * (m + 1) for _ in range(n + 1)]
    g = [[None] * (m + 1) for _ in range(n + 1)]
    d[0][0] = 0
    for i in range(n + 1):
        for j in range(m + 1):
            if d[i][j] >= INF:
                continue
            for a, b in ADIM:
                if i + a > n or j + b > m:
                    continue
                c = 1 - rat(''.join(sw[i:i + a]), ''.join(sp[j:j + b])) + .05 * (a + b - 2)
                if d[i][j] + c < d[i + a][j + b]:
                    d[i + a][j + b] = d[i][j] + c
                    g[i + a][j + b] = (a, b)
    if d[n][m] >= INF:
        return None, INF, 'yok'
    yol = []
    i, j = n, m
    while i or j:
        a, b = g[i][j]
        yol.append((i - a, j - b, a, b))
        i, j = i - a, j - b
    yol.reverse()
    out = []
    for i, j, a, b in yol:
        if a == 1:
            out.append(''.join(P[j:j + b]))
        else:
            out.extend(bol(''.join(P[j:j + b]), [max(1, len(sw[i + z])) for z in range(a)]))
    return [out], d[n][m], 'hiza'


def main():
    quran, ordered, cikti = sys.argv[1:4]
    q = json.load(open(quran, encoding='utf8'))
    o = json.load(open(ordered, encoding='utf8'))
    bsm = ['بسم', 'الله', 'الرحمن', 'الرحيم']
    sonuc = []
    say = {'esit': 0, 'hiza': 0, 'yok': 0}
    kotu = []
    for x in q['ayahs']:
        s, n, t = x[0], x[1], x[4].replace('﻿', '')
        if n == 1 and s not in (1, 9):
            w = t.split(' ')
            if len(w) > 4 and [nrm(k) for k in w[:4]] == bsm:
                t = ' '.join(w[4:])
        W = [k for k in t.split(' ') if k and nrm(k)]
        e = o.get(f'{s}:{n}')
        P = e['aya_phonemes_list'] if e else []
        if not P:
            # Fonem yoksa (olmamalı) kelimenin kendi harfleri kullanılır.
            sonuc.append([nrm(k) for k in W])
            say['yok'] += 1
            print('  fonem yok:', f'{s}:{n}', W[:6])
            continue
        r, c, tur = hizala(W, P)
        say[tur] += 1
        if r is None:
            sonuc.append([nrm(k) for k in W])
            kotu.append((99, f'{s}:{n}', W, P))
            continue
        if len(r[0]) != len(W) or any(not x for x in r[0]):
            print('  uyumsuz:', f'{s}:{n}', len(W), len(r[0]), list(zip(W, r[0]))[:10], P[:8])
        sonuc.append(r[0])
        if tur == 'hiza' and (c / max(1, len(W)) > .35):
            kotu.append((c / len(W), f'{s}:{n}', list(zip(W, r[0]))[:12], P))
    json.dump(sonuc, open(cikti, 'w', encoding='utf8'), ensure_ascii=False, separators=(',', ':'))
    print('ayet:', len(sonuc), say, 'şüpheli:', len(kotu))
    for k in sorted(kotu, key=lambda z: -z[0])[:15]:
        print(' ', round(k[0], 2), k[1], k[2], '|', k[3][:10])
    # Örnekler
    for ref in ['2:1', '2:2', '2:5', '19:1', '36:1']:
        try:
            s, n = map(int, ref.split(':'))
            idx = next(i for i, x in enumerate(q['ayahs']) if x[0] == s and x[1] == n)
            print(' örnek', ref, sonuc[idx])
        except StopIteration:
            pass
    assert len(sonuc) == 6236 and say['yok'] < 10, 'fonem verisi eksik'


if __name__ == '__main__':
    main()
