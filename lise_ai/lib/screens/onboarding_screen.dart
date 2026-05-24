import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/lesson_mode.dart';
import '../services/storage_service.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const _kBg = Color(0xFF050510);
const _kAccent = Color(0xFF7C6BF8);
const _kAccentDim = Color(0x337C6BF8);
const _kCard = Color(0xFF0E0E1E);
const _kCardBorder = Color(0xFF1E1E3A);
const _kText = Color(0xFFE8E8FF);
const _kSubText = Color(0xFF8888AA);

// ── Public widget ─────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  final StorageService storage;
  final VoidCallback onComplete;

  const OnboardingScreen({
    super.key,
    required this.storage,
    required this.onComplete,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Selections
  StudentLevel? _selectedLevel;
  String? _selectedExam;
  int _selectedStyle = -1; // -1 = nothing selected yet
  int _selectedGoalMinutes = 30;

  // Orb pulse animation
  late AnimationController _orbController;
  late Animation<double> _orbPulse;

  // Page slide animation
  late AnimationController _pageAnimController;
  late Animation<double> _pageAnim;

  static const int _totalPages = 6;

  static const List<String> _examOptions = [
    'TYT',
    'AYT',
    'LGS',
    'Ödev Yardımı',
    'Genel Çalışma',
  ];

  static const List<Map<String, dynamic>> _styleOptions = [
    {
      'title': 'Sıcak ve Destekleyici',
      'desc': 'Sabırlı, motive edici, her öğrenciye uyumlu',
      'icon': Icons.favorite_rounded,
    },
    {
      'title': 'Direkt ve Odaklı',
      'desc': 'Hızlı, net, sınav odaklı, zaman kaybetmez',
      'icon': Icons.gps_fixed_rounded,
    },
    {
      'title': 'Enerjik ve Motive Edici',
      'desc': 'Coşkulu, ödüllendirici, hedef koyar ve kutlar',
      'icon': Icons.bolt_rounded,
    },
  ];

  // Grade grid levels (exclude lgs from the primary onboarding grid)
  static const List<StudentLevel> _levelGrid = [
    StudentLevel.sinif9,
    StudentLevel.sinif10,
    StudentLevel.sinif11,
    StudentLevel.sinif12,
    StudentLevel.tyt,
    StudentLevel.ayt,
  ];

  @override
  void initState() {
    super.initState();

    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _orbPulse = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _orbController, curve: Curves.easeInOut),
    );

    _pageAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 1.0,
    );
    _pageAnim = CurvedAnimation(
      parent: _pageAnimController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _orbController.dispose();
    _pageAnimController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ── Navigation ───────────────────────────────────────────────────────────

  Future<void> _animateToPage(int page) async {
    await _pageAnimController.reverse();
    _pageController.jumpToPage(page);
    setState(() => _currentPage = page);
    await _pageAnimController.forward();
  }

  void _next() {
    if (_currentPage < _totalPages - 1) {
      _animateToPage(_currentPage + 1);
    } else {
      _finish();
    }
  }

  void _prev() {
    if (_currentPage > 0) {
      _animateToPage(_currentPage - 1);
    }
  }

  bool get _canProceed {
    switch (_currentPage) {
      case 1:
        return _selectedLevel != null;
      case 2:
        return _selectedExam != null;
      case 3:
        return _selectedStyle >= 0;
      case 4:
        return true;
      default:
        return true;
    }
  }

  Future<void> _finish() async {
    await widget.storage.saveSetting('onboarding_done', 'true');
    if (_selectedLevel != null) {
      await widget.storage.saveSetting('student_level', _selectedLevel!.name);
    }
    if (_selectedExam != null) {
      await widget.storage.saveSetting('target_exam', _selectedExam!);
    }
    if (_selectedStyle >= 0) {
      await widget.storage.saveSetting(
          'teacher_style', _selectedStyle.toString());
    }
    await widget.storage.saveSetting('daily_goal_minutes', _selectedGoalMinutes.toString());
    widget.onComplete();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            // Page content
            Expanded(
              child: FadeTransition(
                opacity: _pageAnim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.04, 0),
                    end: Offset.zero,
                  ).animate(_pageAnim),
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildWelcomePage(),
                      _buildLevelPage(),
                      _buildExamPage(),
                      _buildStylePage(),
                      _buildStudyGoalPage(),   // page index 4
                      _buildPermissionsPage(), // page index 5
                    ],
                  ),
                ),
              ),
            ),
            // Bottom navigation bar
            _buildNavBar(),
          ],
        ),
      ),
    );
  }

  // ── Page 1: Welcome ───────────────────────────────────────────────────────

  Widget _buildWelcomePage() {
    return _OnboardingPage(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated orb
          AnimatedBuilder(
            animation: _orbPulse,
            builder: (context, child) {
              return Transform.scale(
                scale: _orbPulse.value,
                child: child,
              );
            },
            child: _OrbWidget(size: 120),
          ),
          const SizedBox(height: 36),
          Text(
            'LiseAI',
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w700,
              color: _kText,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Zeka ile öğren. Öğretmenle büyü.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: _kAccent,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Yapay zeka destekli kişisel Türk lise öğretmeniniz.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: _kSubText,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Page 2: Level selection ───────────────────────────────────────────────

  Widget _buildLevelPage() {
    return _OnboardingPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _PageHeader(
            title: 'Hangi sınıftasın?',
            subtitle: 'Seviyene uygun içerik ve anlatım için sınıfını seç.',
          ),
          const SizedBox(height: 28),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: _levelGrid.map((level) {
                final selected = _selectedLevel == level;
                return _SelectionCard(
                  label: level.label,
                  selected: selected,
                  onTap: () => setState(() => _selectedLevel = level),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Page 3: Target exam ───────────────────────────────────────────────────

  Widget _buildExamPage() {
    return _OnboardingPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _PageHeader(
            title: 'Hedef sınavın hangisi?',
            subtitle:
                'Sana en uygun hazırlık planı ve konu öncelikleri için seç.',
          ),
          const SizedBox(height: 28),
          ..._examOptions.map((exam) {
            final selected = _selectedExam == exam;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SelectionCard(
                label: exam,
                selected: selected,
                onTap: () => setState(() => _selectedExam = exam),
                fullWidth: true,
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Page 4: Teacher style ─────────────────────────────────────────────────

  Widget _buildStylePage() {
    return _OnboardingPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _PageHeader(
            title: 'Nasıl bir öğretmen istersin?',
            subtitle:
                'Yapay zeka öğretmeninin kişiliğini şekillendirmek için birini seç.',
          ),
          const SizedBox(height: 28),
          ..._styleOptions.asMap().entries.map((entry) {
            final i = entry.key;
            final style = entry.value;
            final selected = _selectedStyle == i;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _StyleCard(
                title: style['title'] as String,
                desc: style['desc'] as String,
                icon: style['icon'] as IconData,
                selected: selected,
                onTap: () => setState(() => _selectedStyle = i),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Page 5: Study goal ────────────────────────────────────────────────────

  Widget _buildStudyGoalPage() {
    const goals = [15, 30, 45, 60];
    const goalLabels = {
      15: 'Hızlı Başlangıç',
      30: 'Dengeli Tempo',
      45: 'Ciddi Hazırlık',
      60: 'Tam Odak',
    };
    const goalDescs = {
      15: '15 dakika / gün',
      30: '30 dakika / gün',
      45: '45 dakika / gün',
      60: '1 saat / gün',
    };

    return _OnboardingPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const _PageHeader(
            title: 'Günlük hedefin ne?',
            subtitle: 'Günlük çalışma hedefinle seni hatırlatmalı yapay öğretmenin sana eşlik edecek.',
          ),
          const SizedBox(height: 28),
          ...goals.map((g) {
            final selected = _selectedGoalMinutes == g;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => setState(() => _selectedGoalMinutes = g),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: selected ? _kAccent.withOpacity(0.15) : _kCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? _kAccent : _kCardBorder,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: selected
                              ? _kAccent.withOpacity(0.22)
                              : _kCardBorder.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '$g',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: selected ? _kAccent : _kSubText,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              goalLabels[g]!,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: selected ? _kText : _kText.withOpacity(0.85),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              goalDescs[g]!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: _kSubText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (selected)
                        Icon(Icons.check_circle_rounded,
                            color: _kAccent, size: 20),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kAccentDim,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: _kAccent, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'İstediğin zaman ayarlardan değiştirebilirsin.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: _kSubText,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Page 6: Permissions & privacy ────────────────────────────────────────

  Widget _buildPermissionsPage() {
    return _OnboardingPage(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            // Cinematic motivational header
            Center(
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _orbPulse,
                    builder: (_, child) => Transform.scale(
                      scale: 0.9 + _orbPulse.value * 0.1,
                      child: child,
                    ),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          colors: [Color(0xFF9D8FFB), Color(0xFF3A2E8F)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _kAccent.withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text('✦',
                            style: TextStyle(
                                fontSize: 28, color: Colors.white)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Harika seçimler!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _kText,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Yapay zeka öğretmenin hazır.\nSadece bir adım kaldı.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: _kSubText,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            _PageHeader(
              title: 'Son adım',
              subtitle: 'LiseAI\'ın tüm özelliklerinden faydalanmak için.',
            ),
            const SizedBox(height: 24),
            // Permissions section
            _SectionLabel(label: 'İzinler'),
            const SizedBox(height: 12),
            _PermissionItem(
              icon: Icons.mic_rounded,
              title: 'Mikrofon İzni',
              description: 'Sesli soru sormak için kullanılır. '
                  'İstediğin zaman sesli öğrenme moduna geçebilirsin.',
            ),
            const SizedBox(height: 10),
            _PermissionItem(
              icon: Icons.camera_alt_rounded,
              title: 'Kamera / Fotoğraf İzni',
              description: 'Ödev fotoğrafı göndermek için kullanılır. '
                  'Kağıttaki soruları fotoğraflayarak çözdürebilirsin.',
            ),
            const SizedBox(height: 24),
            // Privacy note
            _SectionLabel(label: 'Gizlilik'),
            const SizedBox(height: 12),
            _InfoBox(
              icon: Icons.lock_rounded,
              color: const Color(0xFF3BE8B0),
              text:
                  'Tüm verileriniz yalnızca cihazınızda saklanır. Hiçbir kişisel veri üçüncü taraflarla paylaşılmaz.',
            ),
            const SizedBox(height: 10),
            // AI disclaimer
            _InfoBox(
              icon: Icons.info_outline_rounded,
              color: _kAccent,
              text:
                  'LiseAI bir yapay zeka asistanıdır ve gerçek bir öğretmenin yerine geçemez. Kritik sınav kararları için uzman görüşü alınız.',
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Bottom navigation bar ─────────────────────────────────────────────────

  Widget _buildNavBar() {
    final isLast = _currentPage == _totalPages - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: _kBg,
        border: Border(
          top: BorderSide(color: _kCardBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Back button
          AnimatedOpacity(
            opacity: _currentPage > 0 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: _currentPage == 0,
              child: _NavIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: _prev,
              ),
            ),
          ),
          const Spacer(),
          // Page dots
          Row(
            children: List.generate(_totalPages, (i) {
              final active = i == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? _kAccent : _kCardBorder,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
          const Spacer(),
          // Next / Start button
          AnimatedOpacity(
            opacity: _canProceed ? 1.0 : 0.45,
            duration: const Duration(milliseconds: 200),
            child: _NavButton(
              label: isLast ? 'Başla' : 'İleri',
              icon: isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
              onTap: _canProceed ? _next : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _OnboardingPage extends StatelessWidget {
  final Widget child;

  const _OnboardingPage({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: child,
    );
  }
}

// ── Orb widget ────────────────────────────────────────────────────────────────

class _OrbWidget extends StatelessWidget {
  final double size;

  const _OrbWidget({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _OrbPainter(),
        child: Center(
          child: Text(
            '✦',
            style: TextStyle(
              fontSize: size * 0.38,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: _kAccent,
                  blurRadius: 12,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          _kAccent.withOpacity(0.35),
          _kAccent.withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, glowPaint);

    // Core orb
    final orbPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        colors: [
          const Color(0xFFA08DF8),
          _kAccent,
          const Color(0xFF3A2E8F),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.72));
    canvas.drawCircle(center, radius * 0.72, orbPaint);

    // Inner highlight
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.45),
        radius: 0.6,
        colors: [
          Colors.white.withOpacity(0.35),
          Colors.white.withOpacity(0.0),
        ],
      ).createShader(
          Rect.fromCircle(center: center, radius: radius * 0.72));
    canvas.drawCircle(center, radius * 0.72, highlightPaint);

    // Ring
    final ringPaint = Paint()
      ..color = _kAccent.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius * 0.85, ringPaint);

    // Outer ring dots
    final dotPaint = Paint()..color = _kAccent.withOpacity(0.6);
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * math.pi - math.pi / 2;
      final dotCenter = Offset(
        center.dx + math.cos(angle) * radius * 0.85,
        center.dy + math.sin(angle) * radius * 0.85,
      );
      canvas.drawCircle(dotCenter, 2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Page header ───────────────────────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _PageHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: _kText,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 14,
            color: _kSubText,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: _kAccent,
        letterSpacing: 1.5,
      ),
    );
  }
}

// ── Selection card ────────────────────────────────────────────────────────────

class _SelectionCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool fullWidth;

  const _SelectionCard({
    required this.label,
    required this.selected,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? _kAccent.withOpacity(0.15) : _kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _kAccent : _kCardBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: fullWidth
              ? MainAxisAlignment.spaceBetween
              : MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? _kAccent : _kText,
              ),
            ),
            if (fullWidth && selected)
              Icon(
                Icons.check_circle_rounded,
                color: _kAccent,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Style card ────────────────────────────────────────────────────────────────

class _StyleCard extends StatelessWidget {
  final String title;
  final String desc;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _StyleCard({
    required this.title,
    required this.desc,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? _kAccent.withOpacity(0.12) : _kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _kAccent : _kCardBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected
                    ? _kAccent.withOpacity(0.25)
                    : _kCardBorder.withOpacity(0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: selected ? _kAccent : _kSubText,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: selected ? _kText : _kText.withOpacity(0.85),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 12,
                      color: _kSubText,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: _kAccent,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Permission item ───────────────────────────────────────────────────────────

class _PermissionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _PermissionItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kCardBorder, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _kAccentDim,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _kAccent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _kText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _kSubText,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info box (privacy / disclaimer) ──────────────────────────────────────────

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _InfoBox({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: _kSubText,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Nav icon button ───────────────────────────────────────────────────────────

class _NavIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kCardBorder, width: 1),
        ),
        child: Icon(icon, color: _kSubText, size: 20),
      ),
    );
  }
}

// ── Nav button ────────────────────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _NavButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient: onTap != null
              ? const LinearGradient(
                  colors: [Color(0xFF9D8FFB), _kAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: onTap == null ? _kCardBorder : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: onTap != null
              ? [
                  BoxShadow(
                    color: _kAccent.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 6),
            Icon(icon, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}
