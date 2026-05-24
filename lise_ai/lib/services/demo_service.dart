/// DemoService — built-in scenarios for App Store review and offline demo.
///
/// When no API key is present, the app shows scenario tiles; tapping one
/// injects a hardcoded student message and streams a pre-written Turkish reply
/// token by token to exercise all UI paths without a live Claude call.
library;

// ── DemoScenario ──────────────────────────────────────────────────────────────

class DemoScenario {
  final String id;
  final String title;
  final String subtitle;
  final String icon;      // emoji icon
  final String studentMessage;
  final String aiReply;

  const DemoScenario({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.studentMessage,
    required this.aiReply,
  });
}

// ── DemoService ───────────────────────────────────────────────────────────────

class DemoService {
  DemoService._();

  static const List<DemoScenario> scenarios = [
    DemoScenario(
      id: 'turev',
      title: 'Türev Nedir?',
      subtitle: 'Matematik · 9-12. Sınıf',
      icon: '∂',
      studentMessage: 'Türev nedir, sıfırdan anlat.',
      aiReply: '''Harika bir soru — türev, bir fonksiyonun herhangi bir noktadaki anlık değişim hızıdır.

Şöyle düşün: araba hız göstergesi anlık hızı gösterir, yani o andaki mesafe değişim hızı. İşte türev tam olarak budur.

**Formül:**
f'(x) = lim[h→0] (f(x+h) − f(x)) / h

**Basit örnek:**
f(x) = x² için türev f'(x) = 2x

x = 3 noktasında eğim 6'dır — grafik o noktada 6 birim yükseliyor.

Bir sonraki adım: türev kurallarını (üs, çarpım, bölüm) pratik yapalım mı?''',
    ),

    DemoScenario(
      id: 'geometri',
      title: 'Çember Alanı',
      subtitle: 'Geometri · 9. Sınıf',
      icon: '○',
      studentMessage: 'Çemberin alanı formülünü açıkla.',
      aiReply: '''Tabii! Çemberin alanı:

**A = π · r²**

Burada:
- **π ≈ 3.14159**
- **r** = yarıçap (merkez ile kenar arası mesafe)

**Sezgi:** Çemberi küçük dilimler hâline getirip düzleştirirsen bir üçgen oluşur. Taban = 2πr (çevre), yükseklik = r. Üçgen alanı = ½ · taban · yükseklik = ½ · 2πr · r = **πr²** ✓

**Örnek:**
r = 5 cm → A = π · 25 ≈ **78.5 cm²**

Çevre ile alanı karıştırmamak için: çevre = 2πr (tek boyutlu), alan = πr² (iki boyutlu).

Sınavda sık çıkan konu: içine çember çizilmiş kare — deneyelim mi?''',
    ),

    DemoScenario(
      id: 'fizik',
      title: 'Newton\'un 2. Yasası',
      subtitle: 'Fizik · 10. Sınıf',
      icon: '⚡',
      studentMessage: 'F=ma formülünü anlamak istiyorum.',
      aiReply: '''Newton'un 2. Yasası — fiziğin en temel denklemlerinden biri:

**F = m · a**

- **F** = net kuvvet (Newton, N)
- **m** = kütle (kilogram, kg)
- **a** = ivme (m/s²)

**Sezgi:** Boş bir alışveriş arabasını itmek kolaydır; dolu arabayı aynı kuvvetle itersen daha yavaş gider. Kütle arttıkça ivme azalır — bu F = ma.

**Örnek:**
5 kg'lık kutuya 20 N kuvvet → a = F/m = 20/5 = **4 m/s²**

**Dikkat edilecek nokta:** F, **net** kuvvettir. Zıt yönlü sürtünme varsa önce vektörleri topla.

Sürtünmeli bir problem çözelim mi?''',
    ),

    DemoScenario(
      id: 'pdf',
      title: 'PDF Ders Notu Analizi',
      subtitle: 'Belge · Her Sınıf',
      icon: '📄',
      studentMessage: 'Bu PDF\'deki konuları özetle.',
      aiReply: '''PDF'yi aldım! İşte temel başlıklar ve önemli noktalar:

**1. Fonksiyonlar**
- Tanım kümesi ve görüntü kümesi kavramları
- Bire-bir ve örten fonksiyon farkı

**2. Limit ve Süreklilik**
- Tek taraflı limitler
- L'Hôpital kuralı örnekleri

**3. Türev Uygulamaları**
- Ekstremum noktaları bulma
- Monotonluk analizi

**Zayıf görünen konu:** İkinci türev testi — bu konuya biraz daha zaman ayıralım mı?

Sormak istediğin belirli bir bölüm var mı?''',
    ),

    DemoScenario(
      id: 'fotograf',
      title: 'Soru Fotoğrafı',
      subtitle: 'Görsel Analiz · Her Sınıf',
      icon: '📷',
      studentMessage: 'Bu soruyu çözmeme yardım et.',
      aiReply: '''Fotoğraftaki soruyu inceliyorum…

**Soru:** ∫(2x + 3) dx = ?

**Çözüm adım adım:**

1. Her terimi ayrı ayrı integral al:
   ∫2x dx + ∫3 dx

2. Üs kuralını uygula (∫xⁿ dx = xⁿ⁺¹ / (n+1)):
   2 · x²/2 + 3x + C

3. Sadeleştir:
   **= x² + 3x + C** ✓

**Kontrol:** Sonucu türeve al → 2x + 3 ✓

Başka bir soru var mı?''',
    ),

    DemoScenario(
      id: 'sesli',
      title: 'Sesli Ders',
      subtitle: 'Konuşma · Eller Serbest',
      icon: '🎙️',
      studentMessage: 'Sesli ders modunu dene.',
      aiReply: '''Sesli ders moduna hoş geldin! 🎙️

Bu modda:
- Konuşarak soru sorabilirsin — mikrofona dokun
- Öğretmen yanıtı sesli okur
- Eller tamamen serbest, not defterine bakabilirsin

**Nasıl başlarım?**
Aşağıdaki mikrofon butonuna dokunup soruyu söyle. Konuşmayı bitirince sus — sistem otomatik algılar.

Şu an **Sınıf modu** aktif. Değiştirmek istersen üstteki mod seçicisini kullan.

Hazır olduğunda başla!''',
    ),

    DemoScenario(
      id: 'sinav_kampi',
      title: 'Sınav Kampı',
      subtitle: 'TYT/AYT · Zamanlı Pratik',
      icon: '⏱',
      studentMessage: 'TYT matematik kampı başlat.',
      aiReply: '''Sınav kampı başlıyor! ⏱

**25 dakika · TYT Matematik**

İlk soru:

---
Bir trende 120 yolcu var. İlk durağa kadar yolcuların 1/3'ü indi, 15 kişi bindi. Son durağa kadar kalanların %25'i daha indi. Trende kaç yolcu kaldı?

**Süre: 90 saniye**

---

Cevabını yaz ve gönder. Doğruysa bir sonraki soruya geçiyoruz, yanlışsa adım adım açıklayacağım.

Hazır mısın?''',
    ),

    DemoScenario(
      id: 'gelisim',
      title: 'Gelişim Paneli',
      subtitle: 'İstatistik · Kişisel Analiz',
      icon: '📊',
      studentMessage: 'Bu hafta nasıl gittiğimi anlat.',
      aiReply: '''Bu haftanın özeти:

**📈 Genel Performans: İyi →**

| Konu | Başarı | Durum |
|------|--------|-------|
| Türev | %82 | ✅ Kuvvetli |
| İntegral | %61 | 🔸 Gelişiyor |
| Geometri | %74 | ✅ İyi |
| Fizik | %55 | ⚠️ Çalış |

**⏱ Bu hafta:** 4 saat 20 dakika çalışma

**🔥 Seri:** 6 gün üst üste giriş

**Öneri:** Fizik konusunda biraz daha zaman harca — özellikle enerji korunumu ve momentum problemleri sınavda sık çıkıyor.

Hangi konuya odaklanalım?''',
    ),
  ];

  /// Returns the scenario matching [id], or null if not found.
  static DemoScenario? byId(String id) {
    try {
      return scenarios.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Returns a simulated AI reply for any free-form input when in demo mode.
  /// Tries to match keywords from built-in scenarios; falls back to a generic reply.
  static String getReplyFor(String input) {
    final lower = input.toLowerCase();
    for (final s in scenarios) {
      if (lower.contains(s.id) ||
          lower.contains(s.title.toLowerCase()) ||
          lower.contains(s.studentMessage.toLowerCase())) {
        return s.aiReply;
      }
    }
    // Generic fallback for unrecognised input
    if (lower.contains('türev') || lower.contains('integral')) {
      return scenarios[0].aiReply;
    }
    if (lower.contains('fizik') || lower.contains('kuvvet')) {
      return scenarios[2].aiReply;
    }
    return '''Demo modundasın — API anahtarı olmadan tam işlevli örnek ders!

Bu uygulama:
✅ Matematik (türev, integral, geometri)
✅ Fizik (mekanik, elektrik)
✅ PDF ve görsel analiz
✅ Sesli ders (eller serbest)
✅ Sınav kampı modu
✅ Kişisel gelişim takibi

Aşağıdaki kartlardan bir konu seç veya kendi soruну yaz.''';
  }
}
