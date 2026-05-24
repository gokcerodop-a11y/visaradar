import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/storage_service.dart';
import '../services/haptics_service.dart';
import '../services/app_version_service.dart';

// ── Colours ───────────────────────────────────────────────────────────────────

const _kBg      = Color(0xFF050510);
const _kSurface = Color(0xFF0A0A18);
const _kCard    = Color(0xFF0F0F1E);
const _kBorder  = Color(0xFF1F2937);
const _kAccent  = Color(0xFF7C6BF8);
const _kMuted   = Color(0xFF4B5563);
const _kText    = Color(0xFFE8E8FF);
const _kSub     = Color(0xFF8888AA);
const _kRed     = Color(0xFFEF4444);
const _kGreen   = Color(0xFF4ADE80);

// ── PrivacySettingsScreen ─────────────────────────────────────────────────────

class PrivacySettingsScreen extends StatefulWidget {
  final StorageService storage;

  const PrivacySettingsScreen({super.key, required this.storage});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _localAnalyticsEnabled = true;
  bool _hapticsEnabled        = true;
  bool _sessionRecoveryEnabled = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final analytics = widget.storage.loadSetting('privacy_local_analytics');
    final haptics   = widget.storage.loadSetting('privacy_haptics');
    final recovery  = widget.storage.loadSetting('privacy_session_recovery');
    setState(() {
      _localAnalyticsEnabled  = analytics != 'false';
      _hapticsEnabled         = haptics   != 'false';
      _sessionRecoveryEnabled = recovery  != 'false';
    });
    HapticsService.setEnabled(_hapticsEnabled);
  }

  Future<void> _toggle(String key, bool value, void Function(bool) setter) async {
    await HapticsService.light();
    await widget.storage.saveSetting(key, value.toString());
    if (mounted) setState(() => setter(value));
    if (key == 'privacy_haptics') HapticsService.setEnabled(value);
  }

  Future<void> _exportData() async {
    await HapticsService.medium();
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (_) => _InfoDialog(
        icon: Icons.download_rounded,
        title: 'Veri Dışa Aktarma',
        body: 'Tüm öğrenme verileriniz (sohbet geçmişi, ilerleme, '
            'başarımlar) yakında JSON formatında dışa aktarılabilecek.\n\n'
            'Bu özellik bir sonraki güncellemede eklenecektir.',
        actionLabel: 'Tamam',
      ),
    );
  }

  Future<void> _deleteAccount() async {
    await HapticsService.heavy();
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hesabı Sil',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        content: const Text(
          'Tüm yerel verileriniz silinecek. Bu işlem geri alınamaz.\n\n'
          'Silmek istediğinizden emin misiniz?',
          style: TextStyle(color: _kSub, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal', style: TextStyle(color: _kMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil', style: TextStyle(color: _kRed,
                fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      // TODO: wire to AuthService.signOut + clear all local data
      _showSnack('Hesap silme özelliği yakında eklenecek.');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 13)),
        backgroundColor: _kSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Gizlilik & Veri',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Data control toggles ────────────────────────────────────────────
          _SectionHeader(label: 'Veri Kontrolü'),
          const SizedBox(height: 10),
          _ToggleTile(
            icon: Icons.bar_chart_rounded,
            iconColor: _kAccent,
            title: 'Yerel Analitik',
            subtitle: 'Konu başarı oranları ve çalışma süreleri hesaplanır. '
                'Hiçbir veri cihazı terk etmez.',
            value: _localAnalyticsEnabled,
            onChanged: (v) => _toggle(
                'privacy_local_analytics', v,
                (b) => _localAnalyticsEnabled = b),
          ),
          const SizedBox(height: 8),
          _ToggleTile(
            icon: Icons.vibration_rounded,
            iconColor: const Color(0xFF60A5FA),
            title: 'Titreşim (Dokunsal Geri Bildirim)',
            subtitle: 'Başarım bildirimleri ve etkileşimlerde hafif titreşim.',
            value: _hapticsEnabled,
            onChanged: (v) => _toggle(
                'privacy_haptics', v,
                (b) => _hapticsEnabled = b),
          ),
          const SizedBox(height: 8),
          _ToggleTile(
            icon: Icons.restore_rounded,
            iconColor: const Color(0xFF4ADE80),
            title: 'Oturum Kurtarma',
            subtitle: 'Uygulama beklenmedik şekilde kapanırsa '
                'yarıda kalan dersinizi kurtarır.',
            value: _sessionRecoveryEnabled,
            onChanged: (v) => _toggle(
                'privacy_session_recovery', v,
                (b) => _sessionRecoveryEnabled = b),
          ),

          const SizedBox(height: 24),

          // ── AI disclaimer ───────────────────────────────────────────────────
          _SectionHeader(label: 'Yapay Zeka Bildirimi'),
          const SizedBox(height: 10),
          _InfoCard(
            icon: Icons.smart_toy_outlined,
            color: _kAccent,
            title: 'LiseAI Bir Yapay Zekadır',
            body: 'LiseAI, Anthropic Claude modeli tarafından desteklenmektedir '
                've gerçek bir öğretmenin yerini alamaz. Verdiği bilgiler '
                'doğruluk garantisi taşımaz. Kritik sınav kararları için '
                'lütfen bir uzman öğretmene danışınız.\n\n'
                'Yapay zeka sorguları Anthropic\'in sunucularına iletilir ve '
                'Anthropic\'in gizlilik politikasına tabidir.',
          ),

          const SizedBox(height: 24),

          // ── Data & account actions ──────────────────────────────────────────
          _SectionHeader(label: 'Verilerim'),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.download_rounded,
            iconColor: const Color(0xFF60A5FA),
            title: 'Verilerimi Dışa Aktar',
            subtitle: 'Tüm öğrenme verilerini JSON olarak indir.',
            onTap: _exportData,
          ),
          const SizedBox(height: 8),
          _ActionTile(
            icon: Icons.family_restroom_rounded,
            iconColor: const Color(0xFF4ADE80),
            title: 'Ebeveyn Bildirimi',
            subtitle: '13 yaş altı kullanıcılar için veli onayı gereklidir.',
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => _InfoDialog(
                icon: Icons.family_restroom_rounded,
                title: 'Ebeveyn Bildirimi',
                body: 'LiseAI, 13 yaş ve üzeri kullanıcılar için '
                    'tasarlanmıştır. 13 yaş altı kullanıcıların uygulamayı '
                    'kullanabilmesi için ebeveyn veya veli onayı gerekmektedir.\n\n'
                    'Ebeveynler, uygulamayı cihaz düzeyindeki ebeveyn denetimi '
                    'araçlarıyla yönetebilir.',
                actionLabel: 'Anladım',
              ),
            ),
          ),
          const SizedBox(height: 8),
          _ActionTile(
            icon: Icons.delete_forever_rounded,
            iconColor: _kRed,
            title: 'Hesabımı Sil',
            subtitle: 'Tüm yerel verileriniz kalıcı olarak silinir.',
            onTap: _deleteAccount,
            destructive: true,
          ),

          const SizedBox(height: 24),

          // ── App version footer ──────────────────────────────────────────────
          Center(
            child: Text(
              'Lise AI ${AppVersionService.releaseLabel}',
              style: const TextStyle(color: _kMuted, fontSize: 11),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) => Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: _kAccent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      );
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: _kText,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        color: _kSub, fontSize: 11, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: _kAccent,
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: destructive
                  ? _kRed.withValues(alpha: 0.25)
                  : _kBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: destructive ? _kRed : _kText,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: _kSub, fontSize: 11, height: 1.4)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: _kMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _InfoCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Text(body,
              style: const TextStyle(
                  color: _kSub, fontSize: 12, height: 1.55)),
        ],
      ),
    );
  }
}

class _InfoDialog extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;

  const _InfoDialog({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _kSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(icon, color: _kAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16)),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Text(body,
            style: const TextStyle(
                color: _kSub, height: 1.6, fontSize: 13)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(actionLabel,
              style: const TextStyle(
                  color: _kAccent, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
