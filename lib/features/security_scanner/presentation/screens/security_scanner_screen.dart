import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../../core/localization/locale.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

// ---------------------------------------------------------------------------
// Thresholds (all tunable)
// ---------------------------------------------------------------------------

/// Magnetometer magnitude (µT). Earth's field is ~25–65 µT normally.
/// A camera or transmitting bug near the phone typically causes spikes >80 µT.
const _kCamSuspicious = 75.0;
const _kCamAlert = 105.0;
const _kBugSuspicious = 80.0;
const _kBugAlert = 115.0;

/// Speech-to-text sound level (dBFS) thresholds for gas/alarm detector.
/// -50 = silence, 0 = maximum. A fire/CO alarm typically exceeds -10.
const _kGasSuspicious = -15.0;
const _kGasAlert = -5.0;

enum _Status { idle, scanning, suspicious, alert }

// ---------------------------------------------------------------------------
// Page metadata
// ---------------------------------------------------------------------------

class _Page {
  final IconData icon;
  final Color color;
  final String titleTr;
  final String titleEn;
  final String subtitleTr;
  final String subtitleEn;
  final String howTr;
  final String howEn;
  final String tipsTr;
  final String tipsEn;
  final String disclaimerTr;
  final String disclaimerEn;
  final String startLabelTr;
  final String startLabelEn;
  final String stopLabelTr;
  final String stopLabelEn;

  const _Page({
    required this.icon,
    required this.color,
    required this.titleTr,
    required this.titleEn,
    required this.subtitleTr,
    required this.subtitleEn,
    required this.howTr,
    required this.howEn,
    required this.tipsTr,
    required this.tipsEn,
    required this.disclaimerTr,
    required this.disclaimerEn,
    this.startLabelTr = 'Taramayı Başlat',
    this.startLabelEn = 'Start Scan',
    this.stopLabelTr = 'Durdur',
    this.stopLabelEn = 'Stop',
  });
}

const _pages = <_Page>[
  // ── 0: Hidden Camera ──────────────────────────────────────────────────────
  _Page(
    icon: Icons.camera_indoor_outlined,
    color: Color(0xFF6366F1),
    titleTr: 'Gizli Kamera',
    titleEn: 'Hidden Camera',
    subtitleTr: 'Manyetik alan anomalisiyle gizlenmiş kameraları tespit eder',
    subtitleEn: 'Detects concealed cameras via magnetic field anomalies',
    howTr:
        'Kameralar metal parçalar, motor ve elektronik devreler içerir. Bu bileşenler yakın çevrede manyetik alan bozulması yaratır. '
        'Telefonu yavaşça şüpheli nesnelere (duman dedektörü, ayna, klima ızgarası, TV, tablo, çerçeve) yaklaştırın. '
        'Manyetik alan normalin üzerine çıktığında uygulama sizi sesli ve görsel olarak uyarır.',
    howEn:
        'Cameras contain metal parts, motors and electronic circuits that distort the local magnetic field. '
        'Move your phone slowly toward suspicious objects (smoke detectors, mirrors, air vents, TVs, frames). '
        'When the magnetic field exceeds the normal range the app alerts you audibly and visually.',
    tipsTr:
        '• Telefonu 5–10 cm mesafede yavaşça gezdirin\n'
        '• Duman dedektörü, klima, ayna arkası, TV ve tabloları öncelikle kontrol edin\n'
        '• Aynı noktada 2–3 kez geçin — ani okumaları karşılaştırın\n'
        '• Tavan köşeleri ve mobilya arkalarına dikkat edin\n'
        '• Gece görüşlü kameralar IR LED içerir — telefon kameranız ile kontrol edin (karanlıkta parlayan mor ışık)',
    tipsEn:
        '• Move the phone 5–10 cm away, scan slowly\n'
        '• Prioritise smoke detectors, AC units, mirror backs, TVs and picture frames\n'
        '• Pass the same spot 2–3 times and compare readings\n'
        '• Check ceiling corners and behind furniture\n'
        '• Night-vision cameras have IR LEDs — check with your phone camera in the dark (purple glow)',
    disclaimerTr:
        'ℹ️ Manyetik tabanlı algılama her kamerayı tespit edemez. Pil, metal aksesuar gibi masum nesneler de tetikleyebilir. '
        'Görsel incelemeyle birlikte kullanın.',
    disclaimerEn:
        'ℹ️ Magnetic detection cannot find every camera. Batteries and metallic objects may also trigger it. '
        'Use alongside a thorough visual inspection.',
  ),

  // ── 1: Audio Bug ─────────────────────────────────────────────────────────
  _Page(
    icon: Icons.mic_external_on,
    color: Color(0xFFEF4444),
    titleTr: 'Ses Dinleme Cihazı',
    titleEn: 'Audio Surveillance Bug',
    subtitleTr: 'RF yayan gizli mikrofon ve dinleme aygıtlarını saptar',
    subtitleEn: 'Detects RF-emitting hidden microphones and listening devices',
    howTr:
        'Aktif dinleme böcekleri (bug), ses sinyalini RF dalgaları üzerinden iletir. '
        'Bu iletim sırasında çevredeki manyetik alanı bozar. '
        'Elektrik prizleri, lamba gövdeleri, mobilya altları ve köşelere yaklaştırarak tarayın — bunlar sık kullanılan gizleme noktalarıdır.',
    howEn:
        'Active listening bugs transmit audio via RF waves, which distort the surrounding magnetic field. '
        'Scan power outlets, lamp bases, furniture undersides and corners — these are the most common hiding spots.',
    tipsTr:
        '• Telefonu elektrik prizine yaklaştırın — gizlenmiş bug\'lar bu noktada güçlü etki yaratır\n'
        '• Priz bloklarını, şarj kafalarını ve USB adaptörleri kontrol edin\n'
        '• Lamba gövdeleri, süs eşyaları ve kitap aralarına bakın\n'
        '• Hafif nemli ortamda manyetik hassasiyet artar\n'
        '• Radyo, TV veya hoparlör gibi RF kaynakları yakındaysa yanlış alarm verebilir — bu cihazlardan uzaklaşın',
    tipsEn:
        '• Hold the phone near power outlets — bugs hidden inside cause strong readings\n'
        '• Check power strips, charger heads and USB adapters\n'
        '• Inspect lamp bases, decorative objects and books\n'
        '• Slightly humid environments increase magnetic sensitivity\n'
        '• Radios, TVs and speakers emit RF — move away from them to avoid false positives',
    disclaimerTr:
        'ℹ️ Pasif kayıt cihazları (kayıt yapan ama iletmeyen) RF yaymaz; manyetik sensör bunları tespit edemez. '
        'Kapsamlı tarama için profesyonel RF analiz ekipmanı kullanın.',
    disclaimerEn:
        'ℹ️ Passive recorders that store but do not transmit do not emit RF and cannot be detected magnetically. '
        'Use professional RF-sweeping equipment for a comprehensive sweep.',
  ),

  // ── 2: Gas / Alarm ───────────────────────────────────────────────────────
  _Page(
    icon: Icons.air,
    color: Color(0xFFF59E0B),
    titleTr: 'Gaz / Alarm Dedektörü',
    titleEn: 'Gas / Alarm Detector',
    subtitleTr: 'Yüksek sesli CO, gaz ve yangın alarmlarını mikrofonla algılar',
    subtitleEn: 'Detects loud CO, gas and fire alarms via the microphone',
    howTr:
        'Telefon kimyasal gaz tespit edemez — bunu yalnızca fiziksel sensörler yapabilir. '
        'Bu özellik, ortamınızdaki ani yüksek ses patlamalarını (CO dedektörü sireni, yangın alarmı, gaz sızıntısı alarm sesi) '
        'mikrofon yoluyla sürekli izler ve sizi anında uyarır. '
        'Otel odanızda veya konakladığınız herhangi bir yerde CO dedektörü yoksa arka planda açık bırakın.',
    howEn:
        'A phone cannot detect chemical gases — only physical sensors can. '
        'This feature continuously monitors for sudden loud sounds (CO detector siren, fire alarm, gas leak alarm) '
        'via the microphone and alerts you immediately. '
        'Leave it running in the background if your hotel room or accommodation lacks a CO detector.',
    tipsTr:
        '• Gaz kokusu veya duman görüyorsanız HEMEN binayı boşaltın\n'
        '• Elektrik düğmelerine dokunmayın, çakmak ve sigara yaklamayın\n'
        '• Acil: 112 (genel) · Gaz arıza: 187 · İGDAŞ: 444 4628 · BOTAŞ: 444 4187\n'
        '• Otel odası: CO ve duman dedektörü var mı kontrol edin\n'
        '• Taşınabilir CO dedektörü seyahat ekipmanınızın bir parçası olmalı',
    tipsEn:
        '• If you smell gas or see smoke, EVACUATE IMMEDIATELY\n'
        '• Do not touch switches, lighters or create any sparks\n'
        '• Emergency: 112 · Gas fault TR: 187\n'
        '• Hotel rooms: check for CO and smoke detectors on arrival\n'
        '• A portable CO detector should be part of every traveller\'s kit',
    disclaimerTr:
        '⚠️ Bu uygulama KİMYASAL GAZ TESPİT ETMEZ. Yalnızca alarm seslerini dinler. '
        'Gerçek güvenlik için onaylı CO / gaz dedektörü satın alın.',
    disclaimerEn:
        '⚠️ This app CANNOT DETECT CHEMICAL GASES. It only listens for alarm sounds. '
        'Purchase a certified CO / gas detector for real safety.',
    startLabelTr: 'Dinlemeyi Başlat',
    startLabelEn: 'Start Listening',
    stopLabelTr: 'Durdur',
    stopLabelEn: 'Stop',
  ),
];

// ---------------------------------------------------------------------------
// Status helpers
// ---------------------------------------------------------------------------

Color _statusColor(_Status s, Color accentColor) => switch (s) {
      _Status.idle => AppColors.textMuted,
      _Status.scanning => accentColor,
      _Status.suspicious => const Color(0xFFF59E0B),
      _Status.alert => const Color(0xFFEF4444),
    };

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class SecurityScannerScreen extends StatefulWidget {
  const SecurityScannerScreen({super.key});

  @override
  State<SecurityScannerScreen> createState() => _SecurityScannerScreenState();
}

class _SecurityScannerScreenState extends State<SecurityScannerScreen>
    with TickerProviderStateMixin {
  final _pageCtrl = PageController();
  int _page = 0;

  // --- Magnetometer (pages 0 & 1) ---
  StreamSubscription<MagnetometerEvent>? _magnetSub;
  double _magnitude = 0;
  bool _magnetScanning = false;

  // --- Audio (page 2) ---
  final _stt = stt.SpeechToText();
  bool _sttReady = false;
  bool _audioScanning = false;
  double _audioLevel = -60.0;

  // --- Alert state ---
  bool _alertFired = false;

  // --- Pulsing ring animation ---
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // --- Info card expanded state per page ---
  final _infoExpanded = [false, false, false];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _initStt();
  }

  Future<void> _initStt() async {
    final ready = await _stt.initialize(
      onError: (_) {
        if (mounted) setState(() => _audioScanning = false);
      },
    );
    if (mounted) setState(() => _sttReady = ready);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _stopMagnet();
    _stopAudio();
    super.dispose();
  }

  // ── Magnetometer ──────────────────────────────────────────────────────────

  void _startMagnet() {
    setState(() {
      _magnetScanning = true;
      _alertFired = false;
      _magnitude = 0;
    });
    _magnetSub = magnetometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen((event) {
      final mag = sqrt(
          event.x * event.x + event.y * event.y + event.z * event.z);
      setState(() => _magnitude = mag);
      _checkMagnetAlert(mag);
    }, onError: (_) {
      if (mounted) setState(() => _magnetScanning = false);
    });
  }

  void _stopMagnet() {
    _magnetSub?.cancel();
    _magnetSub = null;
    FlutterRingtonePlayer().stop();
    if (mounted) {
      setState(() {
        _magnetScanning = false;
        _magnitude = 0;
        _alertFired = false;
      });
    }
  }

  void _checkMagnetAlert(double mag) {
    final suspTh = _page == 0 ? _kCamSuspicious : _kBugSuspicious;
    final alertTh = _page == 0 ? _kCamAlert : _kBugAlert;
    if (mag >= alertTh && !_alertFired) {
      _alertFired = true;
      FlutterRingtonePlayer().play(
        android: AndroidSounds.alarm,
        ios: IosSounds.alarm,
        looping: false,
        volume: 1.0,
        asAlarm: true,
      );
    } else if (mag < suspTh) {
      if (_alertFired) {
        _alertFired = false;
        FlutterRingtonePlayer().stop();
      }
    }
  }

  // ── Audio ─────────────────────────────────────────────────────────────────

  Future<void> _startAudio() async {
    if (!_sttReady) return;
    setState(() {
      _audioScanning = true;
      _alertFired = false;
      _audioLevel = -60.0;
    });
    await _stt.listen(
      onResult: (_) {},
      onSoundLevelChange: _onAudioLevel,
      listenOptions: stt.SpeechListenOptions(
        listenFor: const Duration(hours: 1),
        pauseFor: const Duration(minutes: 30),
        cancelOnError: false,
      ),
    );
  }

  void _stopAudio() {
    _stt.stop();
    FlutterRingtonePlayer().stop();
    if (mounted) {
      setState(() {
        _audioScanning = false;
        _audioLevel = -60.0;
        _alertFired = false;
      });
    }
  }

  void _onAudioLevel(double level) {
    if (!mounted) return;
    setState(() => _audioLevel = level);
    if (level >= _kGasAlert && !_alertFired) {
      _alertFired = true;
      FlutterRingtonePlayer().play(
        android: AndroidSounds.alarm,
        ios: IosSounds.alarm,
        looping: false,
        volume: 1.0,
        asAlarm: true,
      );
    } else if (level < _kGasSuspicious && _alertFired) {
      _alertFired = false;
      FlutterRingtonePlayer().stop();
    }
  }

  // ── Status computation ────────────────────────────────────────────────────

  _Status _status() {
    if (_page < 2) {
      if (!_magnetScanning) return _Status.idle;
      final suspTh = _page == 0 ? _kCamSuspicious : _kBugSuspicious;
      final alertTh = _page == 0 ? _kCamAlert : _kBugAlert;
      if (_magnitude >= alertTh) return _Status.alert;
      if (_magnitude >= suspTh) return _Status.suspicious;
      return _Status.scanning;
    } else {
      if (!_audioScanning) return _Status.idle;
      if (_audioLevel >= _kGasAlert) return _Status.alert;
      if (_audioLevel >= _kGasSuspicious) return _Status.suspicious;
      return _Status.scanning;
    }
  }

  // ── Page switch ───────────────────────────────────────────────────────────

  void _onPageChanged(int index) {
    // Stop current sensor before switching.
    if (_page < 2) {
      _stopMagnet();
    } else {
      _stopAudio();
    }
    setState(() {
      _page = index;
      _alertFired = false;
    });
  }

  // ── Reading value for display ─────────────────────────────────────────────

  String _readingLabel(bool isTr) {
    if (_page < 2) {
      if (!_magnetScanning) return isTr ? 'Bekleniyor' : 'Idle';
      return '${_magnitude.toStringAsFixed(1)} µT';
    } else {
      if (!_audioScanning) return isTr ? 'Bekleniyor' : 'Idle';
      // Map audio level from [-60, 0] to [0, 100] for display.
      final pct = ((_audioLevel + 60) / 60 * 100).clamp(0, 100).toInt();
      return '$pct dB';
    }
  }

  /// Fraction 0..1 for the gauge fill.
  double _fraction() {
    if (_page < 2) {
      if (!_magnetScanning) return 0;
      final alertTh = _page == 0 ? _kCamAlert : _kBugAlert;
      return (_magnitude / alertTh).clamp(0.0, 1.0);
    } else {
      if (!_audioScanning) return 0;
      return ((_audioLevel + 60) / 60).clamp(0.0, 1.0);
    }
  }

  bool _isScanning() => _page < 2 ? _magnetScanning : _audioScanning;

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isTr = L.isTr;
    return Scaffold(
      backgroundColor: AppColors.brandNavy,
      appBar: AppBar(
        backgroundColor: AppColors.brandNavy,
        title: Text(
          isTr ? 'Güvenlik Tarayıcı' : 'Security Scanner',
          style: AppTextStyles.titleLarge,
        ),
      ),
      body: Column(
        children: [
          // ── Page indicator ───────────────────────────────────────────────
          _PageDots(current: _page, count: _pages.length, pages: _pages),
          const SizedBox(height: 4),

          // ── PageView ─────────────────────────────────────────────────────
          Expanded(
            child: PageView.builder(
              controller: _pageCtrl,
              onPageChanged: _onPageChanged,
              itemCount: _pages.length,
              itemBuilder: (context, idx) =>
                  _buildPage(context, idx, isTr),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(BuildContext context, int idx, bool isTr) {
    final page = _pages[idx];
    final status = idx == _page ? _status() : _Status.idle;
    final accentColor = page.color;
    final statusColor = _statusColor(status, accentColor);
    final isThisScanning = idx == _page && _isScanning();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        children: [
          // ── Header ───────────────────────────────────────────────────────
          Text(
            isTr ? page.titleTr : page.titleEn,
            style: AppTextStyles.headlineMedium
                .copyWith(color: accentColor, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            isTr ? page.subtitleTr : page.subtitleEn,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // ── Gauge ────────────────────────────────────────────────────────
          if (idx == _page)
            _Gauge(
              fraction: _fraction(),
              statusColor: statusColor,
              accentColor: accentColor,
              icon: page.icon,
              readingLabel: _readingLabel(isTr),
              status: status,
              pulseAnim: _pulseAnim,
              isTr: isTr,
            )
          else
            _Gauge(
              fraction: 0,
              statusColor: AppColors.textMuted,
              accentColor: accentColor,
              icon: page.icon,
              readingLabel: isTr ? 'Bekleniyor' : 'Idle',
              status: _Status.idle,
              pulseAnim: _pulseAnim,
              isTr: isTr,
            ),
          const SizedBox(height: 20),

          // ── Alert banner ─────────────────────────────────────────────────
          if (status == _Status.alert)
            _AlertBanner(isTr: isTr, accentColor: accentColor),
          if (status == _Status.suspicious)
            _SuspiciousBanner(isTr: isTr, accentColor: accentColor),
          if (status == _Status.scanning)
            _ScanningBanner(isTr: isTr, accentColor: accentColor),
          const SizedBox(height: 16),

          // ── Start / Stop button ──────────────────────────────────────────
          _ScanButton(
            scanning: isThisScanning,
            accentColor: accentColor,
            startLabel: isTr ? page.startLabelTr : page.startLabelEn,
            stopLabel: isTr ? page.stopLabelTr : page.stopLabelEn,
            enabled: idx == _page,
            onTap: () {
              if (idx == _page) {
                if (_page < 2) {
                  isThisScanning ? _stopMagnet() : _startMagnet();
                } else {
                  isThisScanning ? _stopAudio() : _startAudio();
                }
              }
            },
          ),
          const SizedBox(height: 24),

          // ── Info accordion ───────────────────────────────────────────────
          _InfoCard(
            title: isTr ? 'Nasıl Çalışır?' : 'How does it work?',
            body: isTr ? page.howTr : page.howEn,
            expanded: _infoExpanded[idx],
            onToggle: () =>
                setState(() => _infoExpanded[idx] = !_infoExpanded[idx]),
            accentColor: accentColor,
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: isTr ? 'Tarama İpuçları' : 'Scanning Tips',
            body: isTr ? page.tipsTr : page.tipsEn,
            expanded: true,
            onToggle: null,
            accentColor: accentColor,
          ),
          const SizedBox(height: 12),

          // ── Disclaimer ───────────────────────────────────────────────────
          _DisclaimerCard(
            text: isTr ? page.disclaimerTr : page.disclaimerEn,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Gauge widget
// ---------------------------------------------------------------------------

class _Gauge extends StatelessWidget {
  const _Gauge({
    required this.fraction,
    required this.statusColor,
    required this.accentColor,
    required this.icon,
    required this.readingLabel,
    required this.status,
    required this.pulseAnim,
    required this.isTr,
  });

  final double fraction;
  final Color statusColor;
  final Color accentColor;
  final IconData icon;
  final String readingLabel;
  final _Status status;
  final Animation<double> pulseAnim;
  final bool isTr;

  @override
  Widget build(BuildContext context) {
    final isAlert = status == _Status.alert;
    final isSuspicious = status == _Status.suspicious;
    final isScanning = status == _Status.scanning;

    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (context, _) {
        final scale = (isAlert || isSuspicious) ? pulseAnim.value : 1.0;
        return Transform.scale(
          scale: scale,
          child: SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer ring — fills based on fraction
                CustomPaint(
                  size: const Size(200, 200),
                  painter: _GaugePainter(
                    fraction: fraction,
                    color: statusColor,
                    isScanning: isScanning || isSuspicious || isAlert,
                  ),
                ),
                // Inner circle
                Container(
                  width: 152,
                  height: 152,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor.withValues(alpha: 0.12),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: statusColor, size: 36),
                      const SizedBox(height: 6),
                      Text(
                        readingLabel,
                        style: AppTextStyles.titleLarge
                            .copyWith(color: statusColor),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        _statusText(status, isTr),
                        style: AppTextStyles.caption
                            .copyWith(color: statusColor.withValues(alpha: 0.8)),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _statusText(_Status s, bool isTr) => switch (s) {
        _Status.idle => isTr ? 'Hazır' : 'Ready',
        _Status.scanning => isTr ? 'Taranıyor…' : 'Scanning…',
        _Status.suspicious => isTr ? 'Şüpheli!' : 'Suspicious!',
        _Status.alert => isTr ? 'UYARI!' : 'ALERT!',
      };
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({
    required this.fraction,
    required this.color,
    required this.isScanning,
  });

  final double fraction;
  final Color color;
  final bool isScanning;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Background ring
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = color.withValues(alpha: 0.15)
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    if (!isScanning) return;

    // Progress arc
    final fgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, // start at top
      2 * pi * fraction,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.fraction != fraction || old.color != color;
}

// ---------------------------------------------------------------------------
// Page indicator dots
// ---------------------------------------------------------------------------

class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.current,
    required this.count,
    required this.pages,
  });

  final int current;
  final int count;
  final List<_Page> pages;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return GestureDetector(
          onTap: () {},
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
            width: active ? 28 : 10,
            height: 10,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: active
                  ? pages[i].color
                  : AppColors.textMuted.withValues(alpha: 0.4),
            ),
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Banners
// ---------------------------------------------------------------------------

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({required this.isTr, required this.accentColor});
  final bool isTr;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFEF4444), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isTr
                  ? '🚨 Şüpheli nesne tespit edildi! Lütfen bölgeyi görsel olarak kontrol edin.'
                  : '🚨 Suspicious object detected! Please visually inspect the area.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: const Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuspiciousBanner extends StatelessWidget {
  const _SuspiciousBanner({required this.isTr, required this.accentColor});
  final bool isTr;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline,
              color: Color(0xFFF59E0B), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isTr
                  ? 'Yüksek okuma — bu bölgeyi daha dikkatli tarayın.'
                  : 'Elevated reading — scan this area more carefully.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: const Color(0xFFF59E0B)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanningBanner extends StatelessWidget {
  const _ScanningBanner({required this.isTr, required this.accentColor});
  final bool isTr;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.radar, color: accentColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isTr
                  ? 'Normal seviye — taramayı sürdürün. Şüpheli nesnelere yaklaşın.'
                  : 'Normal level — keep scanning. Move closer to suspicious objects.',
              style: AppTextStyles.bodySmall.copyWith(color: accentColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Scan button
// ---------------------------------------------------------------------------

class _ScanButton extends StatelessWidget {
  const _ScanButton({
    required this.scanning,
    required this.accentColor,
    required this.startLabel,
    required this.stopLabel,
    required this.enabled,
    required this.onTap,
  });

  final bool scanning;
  final Color accentColor;
  final String startLabel;
  final String stopLabel;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: enabled ? onTap : null,
        icon: Icon(
          scanning ? Icons.stop_circle_outlined : Icons.play_circle_outline,
          color: Colors.white,
        ),
        label: Text(
          scanning ? stopLabel : startLabel,
          style: AppTextStyles.bodyLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: scanning ? const Color(0xFFEF4444) : accentColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info accordion card
// ---------------------------------------------------------------------------

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.body,
    required this.expanded,
    required this.onToggle,
    required this.accentColor,
  });

  final String title;
  final String body;
  final bool expanded;
  final VoidCallback? onToggle;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onToggle,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: accentColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title,
                        style: AppTextStyles.bodyLarge
                            .copyWith(fontWeight: FontWeight.w600)),
                  ),
                  if (onToggle != null)
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppColors.textMuted,
                    ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                body,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary, height: 1.55),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Disclaimer card
// ---------------------------------------------------------------------------

class _DisclaimerCard extends StatelessWidget {
  const _DisclaimerCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.textMuted.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.textMuted,
          height: 1.5,
        ),
      ),
    );
  }
}
