import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/teacher_identity.dart';
import '../models/lesson_mode.dart';
import '../services/storage_service.dart';
import '../services/long_term_memory.dart';
import '../services/short_term_memory.dart';
import 'privacy_settings_screen.dart';

// ── Colours ───────────────────────────────────────────────────────────────────

const _kBg = Color(0xFF050510);
const _kSurface = Color(0xFF0A0A18);
const _kAccent = Color(0xFF7C6BF8);
const _kHeaderText = Color(0xFF9B8FFA);
const _kMuted = Color(0xFF4B5563);
const _kCard = Color(0xFF0F0F1E);
const _kRed = Color(0xFFEF4444);

// ── SettingsScreen ────────────────────────────────────────────────────────────

class SettingsScreen extends StatefulWidget {
  final StorageService storage;
  final LongTermMemory longTermMemory;
  final ShortTermMemory shortTermMemory;
  final VoidCallback onClearHistory;
  final VoidCallback onResetMemory;

  const SettingsScreen({
    super.key,
    required this.storage,
    required this.longTermMemory,
    required this.shortTermMemory,
    required this.onClearHistory,
    required this.onResetMemory,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ── Voice settings ──────────────────────────────────────────────────────────
  bool _voiceEnabled = true;
  double _lessonSpeed = 1.0;

  // ── Teacher / student ───────────────────────────────────────────────────────
  TeacherPersonalityType _personality = TeacherPersonalityType.sakinOgretmen;
  StudentLevel _studentLevel = StudentLevel.values.first;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final voiceRaw = widget.storage.loadSetting('voice_enabled');
    if (voiceRaw != null) {
      _voiceEnabled = voiceRaw == 'true';
    }

    final speedRaw = widget.storage.loadSetting('lesson_speed');
    if (speedRaw != null) {
      _lessonSpeed = double.tryParse(speedRaw) ?? 1.0;
    }

    final personalityRaw = widget.storage.loadSetting('teacher_personality');
    if (personalityRaw != null) {
      _personality = TeacherPersonalityType.values.firstWhere(
        (v) => v.name == personalityRaw,
        orElse: () => TeacherPersonalityType.sakinOgretmen,
      );
    }

    final levelRaw = widget.storage.loadSetting('student_level');
    if (levelRaw != null) {
      _studentLevel = StudentLevel.values.firstWhere(
        (v) => v.name == levelRaw,
        orElse: () => StudentLevel.values.first,
      );
    }
  }

  // ── API key status ──────────────────────────────────────────────────────────

  bool get _apiKeyValid {
    try {
      final key = dotenv.env['ANTHROPIC_API_KEY'] ?? '';
      return key.isNotEmpty && key != 'your_api_key_here';
    } catch (_) {
      return false;
    }
  }

  // ── Speed label ─────────────────────────────────────────────────────────────

  String get _speedLabel {
    if (_lessonSpeed < 0.85) return 'Yavaş';
    if (_lessonSpeed <= 1.25) return 'Normal';
    return 'Hızlı';
  }

  // ── Dialogs ─────────────────────────────────────────────────────────────────

  Future<void> _confirmClearHistory() async {
    final confirmed = await _showConfirmDialog(
      title: 'Sohbet Geçmişini Sil',
      body: 'Tüm sohbet geçmişi silinecek. Emin misiniz?',
      actionLabel: 'Sil',
    );
    if (confirmed == true) {
      widget.onClearHistory();
      if (mounted) {
        _showSnack('Sohbet geçmişi silindi.');
      }
    }
  }

  Future<void> _confirmResetMemory() async {
    final confirmed = await _showConfirmDialog(
      title: 'Öğrenci Belleğini Sıfırla',
      body:
          'Tüm öğrenme verileri sıfırlanacak. Bu işlem geri alınamaz.',
      actionLabel: 'Sıfırla',
    );
    if (confirmed == true) {
      widget.onResetMemory();
      if (mounted) {
        _showSnack('Öğrenci belleği sıfırlandı.');
      }
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String body,
    required String actionLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: Text(
          body,
          style: const TextStyle(color: Color(0xFFCBD5E1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              actionLabel,
              style: const TextStyle(
                color: _kRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PrivacySettingsScreen(storage: widget.storage),
      ),
    );
  }

  void _showPrivacyDialogLegacy() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Gizlilik Politikası',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: const SingleChildScrollView(
          child: Text(
            'LiseAI, kullanıcı verilerini yalnızca cihaz üzerinde saklar. '
            'Hiçbir kişisel veri üçüncü taraflarla paylaşılmaz. '
            'Yapay zeka sorguları Anthropic Claude API üzerinden iletilir; '
            'bu sorgular Anthropic\'in gizlilik politikasına tabidir. '
            'Daha fazla bilgi için anthropic.com adresini ziyaret edebilirsiniz.\n\n'
            'Cihazınızda saklanan öğrenme verileri, uygulamayı sildiğinizde '
            'otomatik olarak kaldırılır. Ayarlar ekranındaki "Öğrenci Belleğini '
            'Sıfırla" seçeneği ile istediğiniz zaman verilerinizi temizleyebilirsiniz.',
            style: TextStyle(color: Color(0xFFCBD5E1), height: 1.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kapat', style: TextStyle(color: _kAccent)),
          ),
        ],
      ),
    );
  }

  void _showPersonalityPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'Öğretmen Kişiliği',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...TeacherPersonalityType.values.map((type) {
              final selected = type == _personality;
              return ListTile(
                tileColor: selected ? _kAccent.withValues(alpha: 0.12) : null,
                leading: Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: selected ? _kAccent : const Color(0xFF64748B),
                  size: 20,
                ),
                title: Text(
                  type.label,
                  style: TextStyle(
                    color: selected ? _kAccent : Colors.white,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                onTap: () {
                  setState(() => _personality = type);
                  widget.storage.saveSetting(
                      'teacher_personality', type.name);
                  Navigator.pop(ctx);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showLevelPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'Sınıf Seviyesi',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...StudentLevel.values.map((level) {
              final selected = level == _studentLevel;
              return ListTile(
                tileColor: selected ? _kAccent.withValues(alpha: 0.12) : null,
                leading: Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: selected ? _kAccent : const Color(0xFF64748B),
                  size: 20,
                ),
                title: Text(
                  level.label,
                  style: TextStyle(
                    color: selected ? _kAccent : Colors.white,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                onTap: () {
                  setState(() => _studentLevel = level);
                  widget.storage.saveSetting('student_level', level.name);
                  Navigator.pop(ctx);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _kCard,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Ayarlar',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ── 1. Durum ──────────────────────────────────────────────────────
          _SectionHeader(label: 'DURUM'),
          _SectionCard(
            children: [
              _StatusTile(
                title: 'API Bağlantısı',
                connected: _apiKeyValid,
                activeLabel: 'Aktif',
                inactiveLabel: 'API Anahtarı Eksik',
              ),
              _Divider(),
              ListTile(
                dense: true,
                tileColor: Colors.transparent,
                title: const Text(
                  'Uygulama Sürümü',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                trailing: const Text(
                  '1.0.0 (Yapım 1)',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── 2. Ses Ayarları ───────────────────────────────────────────────
          _SectionHeader(label: 'SES AYARLARI'),
          _SectionCard(
            children: [
              SwitchListTile(
                dense: true,
                tileColor: Colors.transparent,
                title: const Text(
                  'Sesli Yanıt',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: const Text(
                  'Öğretmenin sesli konuşmasını etkinleştirir',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
                value: _voiceEnabled,
                activeThumbColor: _kAccent,
                activeTrackColor: _kAccent.withValues(alpha: 0.5),
                onChanged: (val) {
                  setState(() => _voiceEnabled = val);
                  widget.storage.saveSetting('voice_enabled', val.toString());
                },
              ),
              _Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Ders Hızı',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: _kAccent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _speedLabel,
                        style: const TextStyle(
                          color: _kAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: _kAccent,
                    inactiveTrackColor: _kAccent.withValues(alpha: 0.22),
                    thumbColor: _kAccent,
                    overlayColor: _kAccent.withValues(alpha: 0.16),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: _lessonSpeed,
                    min: 0.5,
                    max: 2.0,
                    divisions: 30,
                    onChanged: (val) {
                      setState(() => _lessonSpeed = val);
                    },
                    onChangeEnd: (val) {
                      widget.storage.saveSetting(
                          'lesson_speed', val.toStringAsFixed(2));
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('Yavaş',
                        style: TextStyle(
                            color: Color(0xFF64748B), fontSize: 11)),
                    Text('Normal',
                        style: TextStyle(
                            color: Color(0xFF64748B), fontSize: 11)),
                    Text('Hızlı',
                        style: TextStyle(
                            color: Color(0xFF64748B), fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── 3. Öğretmen ───────────────────────────────────────────────────
          _SectionHeader(label: 'ÖĞRETMEN'),
          _SectionCard(
            children: [
              ListTile(
                dense: true,
                tileColor: Colors.transparent,
                title: const Text(
                  'Kişilik',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: Text(
                  _personality.label,
                  style: const TextStyle(
                      color: Color(0xFF94A3B8), fontSize: 12),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF64748B),
                  size: 20,
                ),
                onTap: _showPersonalityPicker,
              ),
              _Divider(),
              ListTile(
                dense: true,
                tileColor: Colors.transparent,
                title: const Text(
                  'Sınıf Seviyesi',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: Text(
                  _studentLevel.label,
                  style: const TextStyle(
                      color: Color(0xFF94A3B8), fontSize: 12),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF64748B),
                  size: 20,
                ),
                onTap: _showLevelPicker,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── 4. Bellek ve Veri ─────────────────────────────────────────────
          _SectionHeader(label: 'BELLEK VE VERİ'),
          _SectionCard(
            children: [
              ListTile(
                dense: true,
                tileColor: Colors.transparent,
                title: const Text(
                  'Sohbet Geçmişini Sil',
                  style: TextStyle(
                    color: _kRed,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: const Text(
                  'Tüm mesaj geçmişi kalıcı olarak silinir',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: _kRed,
                  size: 20,
                ),
                onTap: _confirmClearHistory,
              ),
              _Divider(),
              ListTile(
                dense: true,
                tileColor: Colors.transparent,
                title: const Text(
                  'Öğrenci Belleğini Sıfırla',
                  style: TextStyle(
                    color: _kRed,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: const Text(
                  'Tüm öğrenme verileri ve hafıza sıfırlanır',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
                leading: const Icon(
                  Icons.restart_alt_rounded,
                  color: _kRed,
                  size: 20,
                ),
                onTap: _confirmResetMemory,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── 5. Gizlilik ───────────────────────────────────────────────────
          _SectionHeader(label: 'GİZLİLİK'),
          _SectionCard(
            children: [
              _StaticInfoTile(
                icon: Icons.phone_android_rounded,
                title: 'Veri Depolama',
                value: 'Yalnızca bu cihazda',
              ),
              _Divider(),
              _StaticInfoTile(
                icon: Icons.share_outlined,
                title: 'Üçüncü Taraf Paylaşım',
                value: 'Yok',
              ),
              _Divider(),
              _StaticInfoTile(
                icon: Icons.cloud_outlined,
                title: 'API İstekleri',
                value: 'Anthropic Claude — anthropic.com',
              ),
              _Divider(),
              ListTile(
                dense: true,
                tileColor: Colors.transparent,
                leading: const Icon(
                  Icons.policy_outlined,
                  color: _kAccent,
                  size: 20,
                ),
                title: const Text(
                  'Gizlilik Politikası',
                  style: TextStyle(color: _kAccent, fontSize: 14),
                ),
                trailing: const Icon(
                  Icons.open_in_new_rounded,
                  color: _kAccent,
                  size: 16,
                ),
                onTap: _showPrivacyDialog,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── 6. Yapay Zeka Bildirimi ───────────────────────────────────────
          _DisclaimerCard(),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: _kHeaderText,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.white.withValues(alpha: 0.05),
      indent: 16,
      endIndent: 0,
    );
  }
}

class _StatusTile extends StatelessWidget {
  final String title;
  final bool connected;
  final String activeLabel;
  final String inactiveLabel;

  const _StatusTile({
    required this.title,
    required this.connected,
    required this.activeLabel,
    required this.inactiveLabel,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = connected ? const Color(0xFF22C55E) : _kRed;
    final statusText = connected ? activeLabel : inactiveLabel;

    return ListTile(
      dense: true,
      tileColor: Colors.transparent,
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: dotColor.withValues(alpha: 0.6),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(
              color: dotColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StaticInfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _StaticInfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      tileColor: Colors.transparent,
      leading: Icon(icon, color: const Color(0xFF64748B), size: 20),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
      ),
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.info_outline_rounded,
                color: _kMuted,
                size: 15,
              ),
              SizedBox(width: 6),
              Text(
                'YAPAY ZEKA BİLDİRİMİ',
                style: TextStyle(
                  color: _kMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'LiseAI bir yapay zeka eğitim asistanıdır. Gerçek bir öğretmenin, '
            'uzmanın veya danışmanın yerini alamaz. Kritik akademik kararlar '
            'için lütfen bir uzmana başvurunuz. Cihazınızda saklanan veriler '
            'yalnızca öğrenme deneyiminizi kişiselleştirmek için kullanılır.',
            style: TextStyle(
              color: _kMuted,
              fontSize: 12,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
