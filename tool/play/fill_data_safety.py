#!/usr/bin/env python3
"""Play Veri Güvenliği CSV'sini VisaRadar beyanıyla doldurur.

Şablon konsoldan "CSV'ye aktar" ile indirilir; kolon düzeni uydurulamaz.
Biçim (Google dokümanı): "Response value" kolonuna TRUE/FALSE yazılır;
seçilmeyen seçenekler ve isteğe bağlı sorular boş bırakılır.

NOT: tool/play/data_safety_template.csv, hiz_radar için indirilen şablonun bir
kopyasıdır — soru/cevap ID'leri (PSL_*) Google'ın genel taksonomisi, uygulamaya
özgü değil. Play Console'da VisaRadar için app oluşturulduktan sonra kendi
şablonunu indirip bu dosyanın üzerine yazman ÖNERİLİR (şema değişmiş olabilir),
ama aynı kalması muhtemel.

Kullanım: python3 tool/play/fill_data_safety.py [sablon.csv] [cikti.csv]
"""
import csv, io, sys, os

VARSAYILAN_SABLON = os.path.dirname(__file__) + "/data_safety_template.csv"
SABLON = sys.argv[1] if len(sys.argv) > 1 else VARSAYILAN_SABLON
CIKTI  = sys.argv[2] if len(sys.argv) > 2 else os.path.dirname(__file__) + "/data_safety_dolu.csv"

QID, RID, VAL = ('Question ID (machine readable)',
                 'Response ID (machine readable)', 'Response value')

# VisaRadar: hesap oluşturma YOK (tercihler cihazda SharedPrefs, giriş ekranı yok).
# Consent gate metni (bkz. consent_gate_screen.dart): yazılan sorular, belge tarama
# fotoğrafları, TTS metni, Open-Meteo'ya iletilen anonim konum, pasaport/seyahat
# bilgileri Anthropic (Claude) + Cloudflare altyapısı üzerinden işleniyor — kendi AI
# arka ucumuz (uygulama fonksiyonu için servis sağlayıcı), 3. tarafa satış/reklam
# paylaşımı yok → tüm türler "paylaşıldı=false".
TEKIL = {
    'PSL_DATA_COLLECTION_COLLECTS_PERSONAL_DATA': 'TRUE',  # konum + fotoğraf + ses + cihaz kimliği
    'PSL_DATA_COLLECTION_ENCRYPTED_IN_TRANSIT': 'TRUE',    # tüm trafik HTTPS (Worker + Anthropic)
}
SECIM = {
    # Uygulamada hesap oluşturma yok — bu seçilince Google, veri silme sorusunu
    # (PSL_SUPPORT_DATA_DELETION_BY_USER) otomatik kilitliyor ("You cannot answer"
    # 400 hatası, hiz_radar'da keşfedildi), o yüzden o soruya HİÇ cevap verilmiyor.
    'PSL_SUPPORTED_ACCOUNT_CREATION_METHODS': ['PSL_ACM_NONE'],
}

A_ISLEV, A_ANALIZ = 'PSL_APP_FUNCTIONALITY', 'PSL_ANALYTICS'

# tür: (toplandı, paylaşıldı, zorunlu_mu, toplama_amaçları, paylaşma_amaçları)
TURLER = {
    # Radar/Schengen ülke algılama + sınır modu — çekirdek özellik, zorunlu.
    'PSL_PRECISE_LOCATION':        (True, False, True,  [A_ISLEV], []),
    # AI asistan soruları + Güvenlik Tarayıcı/AI Tur Rehberi TTS metni.
    'PSL_USER_GENERATED_CONTENT':  (True, False, False, [A_ISLEV], []),
    # Belge Tarayıcı (pasaport/vize fotoğrafı) → AI vision endpoint'ine gider.
    'PSL_PHOTOS':                  (True, False, False, [A_ISLEV], []),
    # STT (AI asistan sesli soru) + Güvenlik Tarayıcı mikrofon seviyesi ölçümü.
    'PSL_AUDIO':                   (True, False, False, [A_ISLEV], []),
    'PSL_DEVICE_ID':               (True, False, True,  [A_ISLEV, A_ANALIZ], []),
    'PSL_CRASH_LOGS':              (True, False, False, [A_ANALIZ, A_ISLEV], []),
    'PSL_PERFORMANCE_DIAGNOSTICS': (True, False, False, [A_ANALIZ, A_ISLEV], []),
}

rd = csv.DictReader(io.StringIO(open(SABLON, encoding='utf-8-sig').read()))
cols, rows = rd.fieldnames, list(rd)
idx = {}
for r in rows:
    idx.setdefault(r[QID], []).append(r)


def sec(qid, secilenler):
    assert qid in idx, f'soru yok: {qid}'
    mevcut = {r[RID] for r in idx[qid]}
    for s in secilenler:
        assert s in mevcut, f'{qid}: seçenek yok {s} (mevcut: {sorted(mevcut)})'
    for r in idx[qid]:
        if r[RID] in secilenler:
            r[VAL] = 'TRUE'


def tekil(qid, deger):
    assert qid in idx and len(idx[qid]) == 1, qid
    idx[qid][0][VAL] = deger


for q, v in TEKIL.items():
    tekil(q, v)
for q, ops in SECIM.items():
    sec(q, ops)

for tur, (topla, paylas, zorunlu, ta, pa) in TURLER.items():
    kat = [q for q in idx if q.startswith('PSL_DATA_TYPES_')
           and any(r[RID] == tur for r in idx[q])]
    assert len(kat) == 1, f'{tur} kategorisi: {kat}'
    sec(kat[0], [tur])
    on = f'PSL_DATA_USAGE_RESPONSES:{tur}:'
    cs = []
    if topla:
        cs.append('PSL_DATA_USAGE_ONLY_COLLECTED')
    if paylas:
        cs.append('PSL_DATA_USAGE_ONLY_SHARED')
    sec(on + 'PSL_DATA_USAGE_COLLECTION_AND_SHARING', cs)
    tekil(on + 'PSL_DATA_USAGE_EPHEMERAL', 'FALSE')
    sec(on + 'DATA_USAGE_USER_CONTROL',
        ['PSL_DATA_USAGE_USER_CONTROL_REQUIRED' if zorunlu
         else 'PSL_DATA_USAGE_USER_CONTROL_OPTIONAL'])
    if ta:
        sec(on + 'DATA_USAGE_COLLECTION_PURPOSE', ta)
    if pa:
        sec(on + 'DATA_USAGE_SHARING_PURPOSE', pa)

out = io.StringIO()
w = csv.DictWriter(out, fieldnames=cols)
w.writeheader()
for qid_rows in idx.values():
    for r in qid_rows:
        w.writerow(r)

with open(CIKTI, 'w', encoding='utf-8') as f:
    f.write(out.getvalue())
print(f'{CIKTI} yazıldı ({len(rows)} satır)')
