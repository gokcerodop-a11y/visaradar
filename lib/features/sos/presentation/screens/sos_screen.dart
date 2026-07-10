import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/localization/locale.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/services/sos_service.dart';
import '../../domain/models/emergency_contact.dart';
import '../providers/sos_provider.dart';

class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key});

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen>
    with TickerProviderStateMixin {
  bool _sosActive = false;
  bool _torchAvailable = false;
  Position? _position;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;
  int _holdProgress = 0;
  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.93, end: 1.07).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _checkTorch();
    _fetchLocation();
  }

  Future<void> _checkTorch() async {
    final available = await SosService.isTorchAvailable();
    if (mounted) setState(() => _torchAvailable = available);
  }

  Future<void> _fetchLocation() async {
    final pos = await SosService.getCurrentPosition();
    if (mounted) setState(() => _position = pos);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _holdTimer?.cancel();
    if (_sosActive) SosService.stopAll();
    super.dispose();
  }

  void _startHold() {
    _holdProgress = 0;
    _holdTimer =
        Timer.periodic(const Duration(milliseconds: 60), (t) {
      if (_holdProgress >= 50) {
        t.cancel();
        _activateSos();
      } else {
        if (mounted) setState(() => _holdProgress++);
      }
    });
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    if (mounted) setState(() => _holdProgress = 0);
  }

  Future<void> _activateSos() async {
    if (mounted) setState(() { _sosActive = true; _holdProgress = 0; });
    await SosService.startAlarm();
    if (_torchAvailable) await SosService.startSosLight();
  }

  Future<void> _deactivateSos() async {
    await SosService.stopAll();
    if (mounted) setState(() => _sosActive = false);
  }

  @override
  Widget build(BuildContext context) {
    final isTr = ref.watch(isTurkishProvider);
    final contacts = ref.watch(sosContactsProvider);

    return Scaffold(
      backgroundColor:
          _sosActive ? const Color(0xFF1A0000) : AppColors.brandNavy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          isTr ? 'Acil SOS' : 'Emergency SOS',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 8),
              if (_sosActive)
                _ActiveBanner(isTr: isTr)
              else
                _InfoCard(isTr: isTr),
              const SizedBox(height: 16),

              // Big SOS button
              Expanded(
                child: Center(
                  child: _sosActive
                      ? _ActiveSosButton(
                          pulse: _pulse,
                          onStop: _deactivateSos,
                          isTr: isTr,
                        )
                      : _HoldSosButton(
                          progress: _holdProgress / 50.0,
                          onHoldStart: _startHold,
                          onHoldEnd: _cancelHold,
                          isTr: isTr,
                        ),
                ),
              ),

              if (_sosActive && contacts.isNotEmpty) ...[
                Text(
                  isTr ? 'Mesaj Gönder' : 'Send Message',
                  style: AppTextStyles.labelLarge,
                ),
                const SizedBox(height: 12),
                for (final c in contacts) ...[
                  _ContactAction(
                      contact: c, position: _position, isTr: isTr),
                  const SizedBox(height: 8),
                ],
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Info card ────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final bool isTr;
  const _InfoCard({required this.isTr});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.touch_app,
                  color: AppColors.brandTeal, size: 18),
              const SizedBox(width: 8),
              Text(
                isTr ? 'Nasıl Kullanılır' : 'How to Use',
                style: AppTextStyles.labelLarge,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isTr
                ? 'SOS butonunu 3 saniye basılı tutun. Yüksek sesli alarm ve SOS ışık sinyali başlar. '
                    'Ardından acil kişilerinize konum mesajı gönderin.'
                : 'Hold the SOS button for 3 seconds. A loud alarm and SOS torch signal start. '
                    'Then send a location message to your emergency contacts.',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _ActiveBanner extends StatelessWidget {
  final bool isTr;
  const _ActiveBanner({required this.isTr});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFFEF4444).withAlpha(80)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emergency,
              color: Color(0xFFEF4444), size: 18),
          const SizedBox(width: 8),
          Text(
            isTr
                ? 'SOS AKTİF — Alarm çalıyor'
                : 'SOS ACTIVE — Alarm sounding',
            style: const TextStyle(
              color: Color(0xFFEF4444),
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hold button ──────────────────────────────────────────────────────────────

class _HoldSosButton extends StatelessWidget {
  final double progress;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;
  final bool isTr;

  const _HoldSosButton({
    required this.progress,
    required this.onHoldStart,
    required this.onHoldEnd,
    required this.isTr,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => onHoldStart(),
      onLongPressEnd: (_) => onHoldEnd(),
      onLongPressCancel: onHoldEnd,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 210,
            height: 210,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 7,
              backgroundColor:
                  const Color(0xFFEF4444).withAlpha(30),
              valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFFEF4444)),
            ),
          ),
          Container(
            width: 178,
            height: 178,
            decoration: BoxDecoration(
              gradient: const RadialGradient(colors: [
                Color(0xFFEF4444),
                Color(0xFFB91C1C),
              ]),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEF4444).withAlpha(80),
                  blurRadius: 28,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.emergency,
                    color: Colors.white, size: 46),
                const Text(
                  'SOS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 5,
                  ),
                ),
                Text(
                  isTr ? '3 sn basılı tut' : 'Hold 3 sec',
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 11,
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

// ── Active button ────────────────────────────────────────────────────────────

class _ActiveSosButton extends StatelessWidget {
  final Animation<double> pulse;
  final AsyncCallback onStop;
  final bool isTr;

  const _ActiveSosButton({
    required this.pulse,
    required this.onStop,
    required this.isTr,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: pulse,
          child: Container(
            width: 178,
            height: 178,
            decoration: BoxDecoration(
              gradient: const RadialGradient(colors: [
                Color(0xFFEF4444),
                Color(0xFFB91C1C),
              ]),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEF4444).withAlpha(100),
                  blurRadius: 36,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emergency, color: Colors.white, size: 50),
                Text(
                  'SOS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: onStop,
          icon: const Icon(Icons.stop_circle_outlined),
          label: Text(isTr ? 'Durdur' : 'Stop'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white54),
            padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          ),
        ),
      ],
    );
  }
}

// ── Contact action row ───────────────────────────────────────────────────────

class _ContactAction extends StatelessWidget {
  final EmergencyContact contact;
  final Position? position;
  final bool isTr;

  const _ContactAction({
    required this.contact,
    required this.position,
    required this.isTr,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () =>
                SosService.sendSosMessage(contact, position),
            icon: const Icon(Icons.location_on,
                size: 16, color: Color(0xFFEF4444)),
            label: Text(
              isTr
                  ? 'Konum: ${contact.name}'
                  : 'Location: ${contact.name}',
              style: const TextStyle(color: Color(0xFFEF4444)),
              overflow: TextOverflow.ellipsis,
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(
                  color: Color(0xFFEF4444), width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () => SosService.sendOkMessage(contact),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.success,
            side: BorderSide(color: AppColors.success, width: 1.5),
            padding:
                const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          ),
          child: Text(isTr ? 'İyiyim' : "I'm OK"),
        ),
      ],
    );
  }
}
