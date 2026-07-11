import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/localization/locale.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

const _tourSeenKey = 'visaradar.tour.seen.v1';

Future<bool> isTourSeen() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_tourSeenKey) ?? false;
}

Future<void> markTourSeen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_tourSeenKey, true);
}

class _Slide {
  final IconData icon;
  final Color color;
  final String titleTr;
  final String titleEn;
  final String bodyTr;
  final String bodyEn;
  final List<String> bulletsTr;
  final List<String> bulletsEn;
  final String? premiumNoteTr;
  final String? premiumNoteEn;

  const _Slide({
    required this.icon,
    required this.color,
    required this.titleTr,
    required this.titleEn,
    required this.bodyTr,
    required this.bodyEn,
    this.bulletsTr = const [],
    this.bulletsEn = const [],
    this.premiumNoteTr,
    this.premiumNoteEn,
  });
}

final _slides = <_Slide>[
  // 1 — Schengen
  _Slide(
    icon: Icons.public,
    color: AppColors.brandTeal,
    titleTr: 'Schengen Sayacınız',
    titleEn: 'Your Schengen Counter',
    bodyTr: '90/180 günlük pencerede kalan hakkınızı gerçek zamanlı takip edin. Süresi dolmadan uyarı alın.',
    bodyEn: 'Track your remaining days in the 90/180-day rolling window in real time.',
    bulletsTr: ['30, 15, 7, 3 ve 1 gün kala bildirim', 'Otomatik sınır geçişi tespiti', 'Tüm Schengen ülkeleri destekleniyor'],
    bulletsEn: ['Alerts at 30, 15, 7, 3 and 1 days left', 'Automatic border crossing detection', 'All Schengen countries supported'],
  ),
  // 2 — 42 Ülke
  _Slide(
    icon: Icons.map_outlined,
    color: const Color(0xFF6366F1),
    titleTr: '42 Ülke, Tek Uygulama',
    titleEn: '42 Countries, One App',
    bodyTr: 'Her ülke için hız limitleri, vize kuralları, acil numaralar, para birimi, kültür ve pratik seyahat bilgisi.',
    bodyEn: 'Speed limits, visa rules, emergency numbers, currency, culture and practical tips for every country.',
    bulletsTr: ['Sürüş kuralları (DRL, kış lastiği, yelek)', 'Şehir rehberi & sokak lezzetleri', 'Anlık hava ve UV endeksi'],
    bulletsEn: ['Driving rules (DRL, winter tyres, vest)', 'City guide & street food', 'Live weather and UV index'],
  ),
  // 3 — AI Seyahat Asistanı
  _Slide(
    icon: Icons.bolt,
    color: const Color(0xFFF59E0B),
    titleTr: 'AI Seyahat Asistanı',
    titleEn: 'AI Travel Assistant',
    bodyTr: 'Aklınıza gelen her soruyu sorun. Vize, gümrük, döviz, vergi iadesi, yerel lezzetler…',
    bodyEn: 'Ask anything. Visas, customs, currency, tax-free, local food — Claude answers instantly.',
    bulletsTr: ['"Change office bul"', '"Aldığım bilgisayarı ülkeme götürebilir miyim?"', '"Romada nerede kalayım?"', '"E-sim nereden bulabilirim?"'],
    bulletsEn: ['"Find a change office nearby"', '"Can I bring the laptop I bought home?"', '"Where to stay in Rome?"', '"Where can I get an eSIM?"'],
  ),
  // 4 — Acil SOS
  _Slide(
    icon: Icons.emergency,
    color: const Color(0xFFEF4444),
    titleTr: 'Acil SOS',
    titleEn: 'Emergency SOS',
    bodyTr: 'Tehlike anında güçlü siren sesi ve SOS ışık sinyali. 2 acil kişinize anında konum mesajı gönderin.',
    bodyEn: 'In danger: loud siren alarm and SOS torch signal. Instantly message your 2 emergency contacts with GPS location.',
    bulletsTr: ['Yüksek sesli alarm sireni', 'SOS Mors kodu ışık sinyali', '2 kişiye konum/güvende mesajı', 'Ayarlar sayfası Acil Kişilerden belirleyin'],
    bulletsEn: ['Loud alarm siren', 'SOS Morse code torch signal', 'Location/safe message to 2 contacts', 'Set contacts in Settings › Emergency Contacts'],
  ),
  // 5 — Tax-Free
  _Slide(
    icon: Icons.receipt_long,
    color: const Color(0xFF10B981),
    titleTr: 'Tax-Free Rehberi',
    titleEn: 'Tax-Free Guide',
    bodyTr: "Avrupa'da alışveriş yapın, vergi iadesi kazanın. Hangi form, nasıl doldurulur, nereye teslim edilir — adım adım.",
    bodyEn: 'Shop in Europe, claim your VAT back. Which form, how to fill it, where to submit — step by step.',
    bulletsTr: ['Global Blue & Planet adımları', 'Ülke bazlı minimum tutar', 'Havalimanı iade noktaları'],
    bulletsEn: ['Global Blue & Planet steps', 'Country minimum amounts', 'Airport refund desk locator'],
    premiumNoteTr: 'Ayarlar Sayfası Premium Bölümünde',
    premiumNoteEn: 'Available in Settings › Premium',
  ),
  // 6 — AI Tur Rehberi
  _Slide(
    icon: Icons.camera_alt_outlined,
    color: const Color(0xFF8B5CF6),
    titleTr: 'AI Tur Rehberi',
    titleEn: 'AI Tour Guide',
    bodyTr: "Kameranızı tarihi yapıya, müzeye veya heykele tutun. Fotoğrafı çekin ve AI'nın tur rehberi gibi anlatmasını izleyin.",
    bodyEn: 'Point your camera at a monument, museum or artwork. Take a photo and let the AI narrate like a tour guide.',
    bulletsTr: ['Anında tarihi bilgi', 'Fotoğrafla tanımlama', 'Türkçe ve İngilizce'],
    bulletsEn: ['Instant historical info', 'Photo-based identification', 'Turkish and English'],
    premiumNoteTr: 'Ayarlar Sayfası Premium Bölümünde',
    premiumNoteEn: 'Available in Settings › Premium',
  ),
  // 7 — Hava & Konum
  _Slide(
    icon: Icons.cloud_outlined,
    color: const Color(0xFF0EA5E9),
    titleTr: 'Hava & Konum',
    titleEn: 'Weather & Location',
    bodyTr: 'Bulunduğunuz yerde anlık hava durumu. UV endeksi, nem, hava kalitesi ve yağmur tahmini.',
    bodyEn: 'Real-time weather at your location. UV index, humidity, air quality and precipitation forecast.',
    bulletsTr: ['UV endeksi ve güneş kremi uyarısı', 'Hava kalitesi (AQI)', 'Konumu kaydet (favori yerler)'],
    bulletsEn: ['UV index and sunscreen alert', 'Air quality index (AQI)', 'Save location (favourite places)'],
  ),
  // 8 — Sınır Geçiş
  _Slide(
    icon: Icons.swap_horiz,
    color: AppColors.brandTeal,
    titleTr: 'Sınır Geçiş Asistanı',
    titleEn: 'Border Crossing Assistant',
    bodyTr: 'Bir Schengen sınırına yaklaşınca uygulama sizi uyarır, geçişi akıllıca kaydeder ve Schengen hesabınızı günceller.',
    bodyEn: 'When you approach a Schengen border, the app alerts you, smartly logs the crossing and updates your Schengen count.',
    bulletsTr: ['GPS tabanlı sınır tespiti', 'Otomatik veya manuel kayıt', 'Anlık bildirim'],
    bulletsEn: ['GPS-based border detection', 'Automatic or manual logging', 'Instant notification'],
  ),
  // 9 — Kayıtlı Yerler
  _Slide(
    icon: Icons.bookmark_added,
    color: const Color(0xFFF59E0B),
    titleTr: 'Yıllar Sonra Bile Aynı Sokak',
    titleEn: 'That Street, Years Later',
    bodyTr: 'Seneler sonra unutamadığın o sokağa nokta atışı geri dön. Bulunduğun yeri hafızaya al — navigasyon seni tam o noktaya ulaştırır.',
    bodyEn: 'Return precisely to that street you could never forget — years later. Save your location and navigation brings you back to the exact spot.',
    bulletsTr: ['Bir dokunuşla kaydet', 'Harita uygulamasına aktar ve yönlendir', 'Ayarlar › Kayıtlı Yerlerim'],
    bulletsEn: ['Save with one tap', 'Open in maps app and navigate', 'Settings › Saved Places'],
  ),
  // 10 — Belge Tarayıcı
  _Slide(
    icon: Icons.document_scanner_outlined,
    color: const Color(0xFF6366F1),
    titleTr: 'Belge Tarayıcı',
    titleEn: 'Document Scanner',
    bodyTr: 'Pasaportunuzu, sağlık sigortanızı, yeşil sigortanızı, ehliyetinizi, biletinizi, bütün seyahat evraklarınızı yükleyin ve bir arada tutun.',
    bodyEn: 'Upload your passport, health insurance, green card, driving licence, flight tickets — all your travel documents stored in one place.',
    bulletsTr: ['Tüm belgeler tek yerde', 'İnternetsiz erişim', 'Güvenli ve şifreli'],
    bulletsEn: ['All documents in one place', 'Access offline', 'Secure and encrypted'],
    premiumNoteTr: 'Ayarlar Sayfası Premium Bölümünde',
    premiumNoteEn: 'Available in Settings › Premium',
  ),
  // 11 — Seyahat Profili
  _Slide(
    icon: Icons.manage_accounts_outlined,
    color: AppColors.brandTeal,
    titleTr: 'Seyahat Profilin',
    titleEn: 'Your Travel Profile',
    bodyTr: 'Ayarlar sayfasında Seyahat Profili bölümüne git. Pasaport türünü, ikametgah durumunu, seyahat yöntemini seç.',
    bodyEn: 'Go to Travel Profile in Settings. Choose your passport type, residence status and preferred travel method.',
    bulletsTr: ['Pasaport türü', 'İkametgah durumu', 'Seyahat yöntemi'],
    bulletsEn: ['Passport type', 'Residence status', 'Travel method'],
  ),
  // 12 — Seyahat Takvimi
  _Slide(
    icon: Icons.calendar_month_outlined,
    color: const Color(0xFF0EA5E9),
    titleTr: 'Seyahat Takvimi',
    titleEn: 'Travel Calendar',
    bodyTr: 'Her gün gittiğin şehirler, kat ettiğin km, yürüdüğün mesafe ve attığın adımlar otomatik kaydedilir.',
    bodyEn: 'Every day, the cities you visited, km travelled, walking distance and steps are recorded automatically.',
    bulletsTr: ['Günlük şehir ve ülke kaydı', 'Adım sayacı & yürüyüş km', 'Not ekle, günü sil'],
    bulletsEn: ['Daily city and country log', 'Step counter & walking km', 'Add notes, delete a day'],
  ),
  // 13 — Güvenlik Tarayıcı
  _Slide(
    icon: Icons.security_outlined,
    color: const Color(0xFF6366F1),
    titleTr: 'Güvenlik Tarayıcı',
    titleEn: 'Security Scanner',
    bodyTr: 'Gizli kamera, ses dinleme cihazı ve yüksek sesli alarm tehditlerini tespit etmek için 3 farklı tarayıcı tek ekranda.',
    bodyEn: '3 detectors in one screen: hidden cameras, audio bugs and loud alarm threats — swipe to switch.',
    bulletsTr: ['Gizli kamera — manyetik alan', 'Ses böceği — RF anomali', 'Gaz/alarm — mikrofon ile ses izleme'],
    bulletsEn: ['Hidden camera — magnetic field', 'Audio bug — RF anomaly', 'Gas/alarm — microphone sound monitoring'],
  ),
  // 14 — Derin Bilgi
  _Slide(
    icon: Icons.verified_outlined,
    color: const Color(0xFF6366F1),
    titleTr: 'Derin Bilgi — Konum Kanıtı',
    titleEn: 'Deep Intel — Location Proof',
    bodyTr: 'SHA-256 zinciriyle birbirine bağlı konum kayıtları. Seyahat ettiğinizi hukuki düzeyde kanıtlayan, değiştirilemez dijital iz.',
    bodyEn: 'Location records chained with SHA-256. An immutable digital trail that proves your travel at legal-grade quality.',
    bulletsTr: ['Blockchain tarzı değiştirilemezlik', 'Zinciri doğrula & dışa aktar', 'Vize / sigorta anlaşmazlıklarında kanıt'],
    bulletsEn: ['Blockchain-style tamper-proof chain', 'Verify chain & export', 'Evidence for visa / insurance disputes'],
  ),
];

class WelcomeTourScreen extends StatefulWidget {
  final bool showDismiss;
  const WelcomeTourScreen({super.key, this.showDismiss = false});

  @override
  State<WelcomeTourScreen> createState() => _WelcomeTourScreenState();
}

class _WelcomeTourScreenState extends State<WelcomeTourScreen>
    with SingleTickerProviderStateMixin {
  final _controller = PageController();
  late final AnimationController _anim;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _anim.dispose();
    super.dispose();
  }

  Future<void> _done() async {
    if (!widget.showDismiss) await markTourSeen();
    if (mounted) context.go(AppRoutes.radar);
  }

  Future<void> _neverShow() async {
    await markTourSeen();
    if (mounted) context.go(AppRoutes.radar);
  }

  void _next() {
    if (_current < _slides.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _done();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTr = L.isTr;
    final isLast = _current == _slides.length - 1;

    return Scaffold(
      backgroundColor: AppColors.brandNavy,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (!widget.showDismiss)
                    TextButton(
                      onPressed: _neverShow,
                      child: Text(
                        isTr ? 'Bir daha gösterme' : "Don't show again",
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 8),
                  TextButton(
                    onPressed: _done,
                    child: Text(
                      isTr ? 'Atla' : 'Skip',
                      style: TextStyle(
                        color: AppColors.brandTeal,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Page view
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _current = i),
                itemCount: _slides.length,
                itemBuilder: (ctx, i) =>
                    _SlidePage(slide: _slides[i], isTr: isTr),
              ),
            ),

            // Dots
            _PageDots(count: _slides.length, current: _current),
            const SizedBox(height: 16),

            // Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandTeal,
                    foregroundColor: AppColors.brandNavy,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    isLast
                        ? (isTr ? 'Hadi Başlayalım!' : "Let's Go!")
                        : (isTr ? 'İleri' : 'Next'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlidePage extends StatelessWidget {
  final _Slide slide;
  final bool isTr;
  const _SlidePage({required this.slide, required this.isTr});

  @override
  Widget build(BuildContext context) {
    final title = isTr ? slide.titleTr : slide.titleEn;
    final body = isTr ? slide.bodyTr : slide.bodyEn;
    final bullets = isTr ? slide.bulletsTr : slide.bulletsEn;
    final premiumNote = isTr ? slide.premiumNoteTr : slide.premiumNoteEn;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  slide.color.withAlpha(60),
                  slide.color.withAlpha(20),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: slide.color.withAlpha(80),
                width: 1.5,
              ),
            ),
            child: Icon(slide.icon, color: slide.color, size: 48),
          ),
          const SizedBox(height: 32),
          Text(
            title,
            style: AppTextStyles.headlineMedium.copyWith(
              fontSize: 22,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Text(
            body,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          if (bullets.isNotEmpty) ...[
            const SizedBox(height: 20),
            ...bullets.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: slide.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        b,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (premiumNote != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: slide.color.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: slide.color.withAlpha(70)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.settings_outlined, size: 13, color: slide.color),
                  const SizedBox(width: 6),
                  Text(
                    premiumNote,
                    style: AppTextStyles.caption.copyWith(
                      color: slide.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  final int count;
  final int current;
  const _PageDots({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 20 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: active
                ? AppColors.brandTeal
                : AppColors.brandTeal.withAlpha(50),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
