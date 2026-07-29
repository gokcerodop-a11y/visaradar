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
  // 1 — Schengen 90/180 (core value proposition)
  _Slide(
    icon: Icons.public,
    color: AppColors.brandTeal,
    titleTr: 'Schengen Sayacınız',
    titleEn: 'Your Schengen Counter',
    bodyTr: '90/180 günlük pencerede kalan hakkınızı takip edin. Uygulama açıkken otomatik ülke algılama. Süresi dolmadan uyarı alın.',
    bodyEn: 'Track your remaining days in the 90/180-day rolling window. Auto country detection when the app is open. Get alerted before you run out.',
    bulletsTr: ['30, 15, 7, 3 ve 1 gün kala bildirim', 'Uygulama açıkken otomatik ülke tespiti', 'Tüm Schengen ülkeleri destekleniyor'],
    bulletsEn: ['Alerts at 30, 15, 7, 3 and 1 days left', 'Auto country detection when app is open', 'All Schengen countries supported'],
  ),
  // 2 — AI Seyahat Asistanı (key differentiator)
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
  // 3 — Acil SOS (unique feature)
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
  // 4 — 23+ Ülke Rehberi
  _Slide(
    icon: Icons.map_outlined,
    color: const Color(0xFF6366F1),
    titleTr: '23+ Ülke, Tek Uygulama',
    titleEn: '23+ Countries, One App',
    bodyTr: 'Her ülke için hız limitleri, vize kuralları, acil numaralar, para birimi, kültür ve pratik seyahat bilgisi.',
    bodyEn: 'Speed limits, visa rules, emergency numbers, currency, culture and practical tips for every country.',
    bulletsTr: ['Sürüş kuralları (DRL, kış lastiği, yelek)', 'Şehir rehberi & sokak lezzetleri', 'Acil numaralar ve para birimi'],
    bulletsEn: ['Driving rules (DRL, winter tyres, vest)', 'City guide & street food', 'Emergency numbers and currency'],
  ),
  // 5 — Premium özellikleri (overview)
  _Slide(
    icon: Icons.workspace_premium_outlined,
    color: const Color(0xFF10B981),
    titleTr: 'Premium ile Daha Fazlası',
    titleEn: 'More with Premium',
    bodyTr: 'Premium; Tax-Free Rehberi, AI Tur Rehberi, Belge Tarayıcı ve Güvenlik Tarayıcı gibi güçlü özelliklerin kilidini açar.',
    bodyEn: 'Premium unlocks powerful features like the Tax-Free Guide, AI Tour Guide, Document Scanner and Security Scanner.',
    bulletsTr: ['Tax-Free Rehberi — vergi iadesi adım adım', 'AI Tur Rehberi — fotoğrafla tarihi anlatım', 'Belge Tarayıcı — tüm evraklar tek yerde', 'Güvenlik Tarayıcı — gizli kamera & dinleme tespiti'],
    bulletsEn: ['Tax-Free Guide — VAT refund step by step', 'AI Tour Guide — photo-based narration', 'Document Scanner — all documents in one place', 'Security Scanner — hidden camera & bug detection'],
    premiumNoteTr: 'Ayarlar Sayfası Premium Bölümünde',
    premiumNoteEn: 'Available in Settings › Premium',
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

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
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
    return Semantics(
      label: L.isTr
          ? '${current + 1}. sayfa, toplam $count'
          : 'Page ${current + 1} of $count',
      child: Row(
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
      ),
    );
  }
}
