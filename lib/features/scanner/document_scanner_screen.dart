import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/localization/locale.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/ai/ai_message.dart';
import '../../services/ai/anthropic_proxy.dart';
import '../../services/premium_providers.dart';
import '../paywall/paywall_screen.dart';

/// Premium document scanner — capture/pick a passport, visa or residence permit
/// and let Claude Vision (via the proxy) extract key details (type, expiry,
/// entry limits). Results are informational; the user reviews before saving.
class DocumentScannerScreen extends ConsumerStatefulWidget {
  const DocumentScannerScreen({super.key});

  @override
  ConsumerState<DocumentScannerScreen> createState() =>
      _DocumentScannerScreenState();
}

class _DocumentScannerScreenState
    extends ConsumerState<DocumentScannerScreen> {
  final _picker = ImagePicker();
  bool _busy = false;
  String? _result;
  String? _error;

  Future<void> _scan(ImageSource source) async {
    final isTr = ref.read(isTurkishProvider);
    final bearer = ref.read(premiumBearerProvider);
    if (bearer == null || bearer.isEmpty) {
      setState(() => _error = 'no-subscription');
      return;
    }
    final XFile? file =
        await _picker.pickImage(source: source, maxWidth: 2000, imageQuality: 85);
    if (file == null) return;

    setState(() {
      _busy = true;
      _result = null;
      _error = null;
    });

    final bytes = await file.readAsBytes();
    final mediaType =
        file.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
    final proxy =
        AnthropicProxy(originalTransactionId: bearer, language: isTr ? 'tr' : 'en');
    try {
      final prompt = isTr
          ? 'Bu seyahat belgesini incele. Belge türünü, son geçerlilik tarihini '
              've varsa giriş/kalış sınırlarını madde madde çıkar. Kısa ve net ol.'
          : 'Analyse this travel document. Extract the document type, expiry date '
              'and any entry/stay limits as short bullet points. Be concise.';
      final text = await proxy.vision(
        image: AIImageAttachment(bytes: bytes, mediaType: mediaType),
        userPrompt: prompt,
        systemPrompt: isTr
            ? 'Sen bir seyahat belgesi okuma asistanısın. Sadece görseldeki '
                'bilgilere dayan, uydurma. Türkçe yanıtla.'
            : 'You read travel documents. Rely only on what is visible; do not '
                'invent. Reply in English.',
      );
      setState(() => _result = text);
    } on ProxySubscriptionRequiredException {
      setState(() => _error = 'no-subscription');
    } on ProxyRateLimitException {
      setState(() => _error = 'rate-limit');
    } catch (_) {
      setState(() => _error = 'generic');
    } finally {
      proxy.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTr = ref.watch(isTurkishProvider);
    final isPremium = ref.watch(isPremiumProvider);

    return Scaffold(
      appBar: AppBar(title: Text(isTr ? 'Belge Tarayıcı' : 'Document Scanner')),
      body: isPremium ? _scanner(isTr) : _locked(isTr),
    );
  }

  Widget _locked(bool isTr) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.document_scanner_outlined,
                size: 56, color: AppColors.brandTeal),
            const SizedBox(height: 16),
            Text(
              isTr
                  ? 'Pasaport, vize ve izin belgelerini tara, önemli tarihleri '
                      'otomatik çıkar.'
                  : 'Scan passports, visas and permits to auto-extract key dates.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.lock_open),
              label: Text(isTr ? 'Premium ile Aç' : 'Unlock with Premium'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PaywallScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scanner(bool isTr) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : () => _scan(ImageSource.camera),
                icon: const Icon(Icons.photo_camera),
                label: Text(isTr ? 'Kamera' : 'Camera'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: _busy ? null : () => _scan(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: Text(isTr ? 'Galeri' : 'Gallery'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_error != null) _errorBox(_error!, isTr),
        if (_result != null) ...[
          Text(isTr ? 'Sonuç' : 'Result', style: AppTextStyles.labelLarge),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(_result!, style: AppTextStyles.bodyMedium),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          isTr
              ? 'Belgeler cihazında işlenir ve saklanmaz; sonuçları kendin '
                  'doğrula.'
              : 'Documents are processed on the fly and not stored; verify '
                  'results yourself.',
          style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _errorBox(String code, bool isTr) {
    final msg = switch (code) {
      'no-subscription' =>
        isTr ? 'Premium gerekiyor.' : 'Premium required.',
      'rate-limit' => isTr
          ? 'Günlük tarama limitine ulaştın.'
          : 'Daily scan limit reached.',
      _ => isTr ? 'Tarama başarısız. Tekrar dene.' : 'Scan failed. Try again.',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
              child: Text(msg,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.danger))),
        ],
      ),
    );
  }
}
