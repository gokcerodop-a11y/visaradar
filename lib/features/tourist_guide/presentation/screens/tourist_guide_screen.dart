import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/localization/locale.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../services/ai/ai_message.dart' show AIImageAttachment;
import '../../../../services/ai/anthropic_proxy.dart';
import '../../../../services/premium_providers.dart';
import '../../../paywall/paywall_screen.dart';

/// AI Tur Rehberi — kullanıcı bir anıt/müze/eser fotoğrafı çeker,
/// Claude vision ile tur rehberi bilgisi alır. (Premium özellik)
class TouristGuideScreen extends ConsumerStatefulWidget {
  const TouristGuideScreen({super.key});

  @override
  ConsumerState<TouristGuideScreen> createState() =>
      _TouristGuideScreenState();
}

class _TouristGuideScreenState extends ConsumerState<TouristGuideScreen> {
  Uint8List? _imageBytes;
  String? _guideText;
  String? _errorText;
  bool _isLoading = false;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _guideText = null;
        _errorText = null;
      });
    } catch (_) {
      if (!mounted) return;
      final isTr = ref.read(isTurkishProvider);
      setState(() {
        _errorText = isTr
            ? 'Fotoğraf seçilemedi. Lütfen tekrar deneyin.'
            : 'Could not pick the photo. Please try again.';
      });
    }
  }

  Future<void> _analyze() async {
    final bytes = _imageBytes;
    if (bytes == null || _isLoading) return;

    final isTr = ref.read(isTurkishProvider);
    final bearer = ref.read(premiumBearerProvider);

    if (bearer == null || bearer.isEmpty) {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _guideText = null;
      _errorText = null;
    });

    try {
      final proxy = AnthropicProxy(
        originalTransactionId: bearer,
        language: isTr ? 'tr' : 'en',
      );

      final systemPrompt = isTr
          ? 'Sen uzman bir yapay zeka tur rehberisin. Fotoğraftaki anıtı, '
              'yapıyı, müzeyi veya sanat eserini tanımla. Şunları sun: adı, '
              'konumu, tarihçesi, mimari/sanat üslubu, büyüleyici gerçekler '
              've ziyaretçi ipuçları. Sürükleyici bir hikaye anlatımı kullan.'
          : 'You are an expert AI tour guide. Identify the landmark, '
              'monument, museum, or artwork in the image. Provide: name, '
              'location, history, architecture/art style, fascinating facts, '
              'and visitor tips. Use engaging storytelling.';

      final userPrompt = isTr
          ? 'Bu fotograftaki mekani tanimla ve tur rehberi bilgisi ver.'
          : 'Identify the site in this photo and provide tour guide information.';

      final result = await proxy.vision(
        image: AIImageAttachment(
          bytes: bytes,
          mediaType: 'image/jpeg',
        ),
        userPrompt: userPrompt,
        systemPrompt: systemPrompt,
      );

      if (!mounted) return;
      setState(() {
        _guideText = result;
        _isLoading = false;
      });
    } on ProxySubscriptionRequiredException {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorText = isTr
            ? 'Bu özellik için Premium abonelik gerekiyor.'
            : 'A Premium subscription is required for this feature.';
      });
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorText = isTr
            ? 'Bir hata oluştu. Lütfen tekrar deneyin.'
            : 'Something went wrong. Please try again.';
      });
    }
  }

  void _reset() {
    setState(() {
      _imageBytes = null;
      _guideText = null;
      _errorText = null;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTr = ref.watch(isTurkishProvider);
    final hasContent = _imageBytes != null || _guideText != null;

    return Scaffold(
      backgroundColor: AppColors.brandNavy,
      appBar: AppBar(
        backgroundColor: AppColors.brandNavy,
        elevation: 0,
        title: Text(
          isTr ? 'AI Tur Rehberi' : 'AI Tour Guide',
          style: AppTextStyles.titleLarge,
        ),
        actions: [
          if (hasContent)
            IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
              tooltip: isTr ? 'Sıfırla' : 'Reset',
              onPressed: _isLoading ? null : _reset,
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _imageBytes == null
              ? _buildEmptyState(isTr)
              : _buildImageState(isTr),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- empty

  Widget _buildEmptyState(bool isTr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.photo_camera_outlined,
              size: 44,
              color: AppColors.info,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            isTr ? 'AI Tur Rehberi' : 'AI Tour Guide',
            style: AppTextStyles.titleLarge,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          isTr
              ? 'Bir anıtın, müzenin veya sanat eserinin fotoğrafını çekin; '
                  'yapay zeka size özel tur rehberi bilgisi versin.'
              : 'Take a photo of a monument, museum, or artwork and get '
                  'personal tour guide information from AI.',
          style: AppTextStyles.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isTr
                ? 'Örnekler: Kolezyum, Eyfel Kulesi, Akropolis, Ayasofya, '
                    'müzeler, kiliseler...'
                : 'Examples: Colosseum, Eiffel Tower, Acropolis, Hagia '
                    'Sophia, museums, churches...',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 28),
        ElevatedButton.icon(
          onPressed: () => _pickImage(ImageSource.camera),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandTeal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.photo_camera),
          label: Text(isTr ? 'Fotoğraf Çek' : 'Take Photo'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _pickImage(ImageSource.gallery),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.divider),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(isTr ? 'Galeriden Seç' : 'From Gallery'),
        ),
        const SizedBox(height: 16),
        Text(
          isTr
              ? '* Premium abonelik gereklidir'
              : '* Premium subscription required',
          style: AppTextStyles.caption,
          textAlign: TextAlign.center,
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 16),
          _buildError(_errorText!),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------- image

  Widget _buildImageState(bool isTr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(
            _imageBytes!,
            height: 240,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () => _pickImage(ImageSource.camera),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.divider),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.replay, size: 18),
                label: Text(isTr ? 'Yeniden çek' : 'Retake'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _analyze,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(isTr ? 'Rehber Bilgisi Al' : 'Get Guide Info'),
              ),
            ),
          ],
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 16),
          _buildError(_errorText!),
        ],
        if (_guideText != null) ...[
          const SizedBox(height: 20),
          _buildGuideCard(isTr, _guideText!),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------- result

  Widget _buildGuideCard(bool isTr, String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandTeal.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.brandTeal, size: 20),
              const SizedBox(width: 8),
              Text(
                isTr ? 'AI Tur Rehberi' : 'AI Tour Guide',
                style: AppTextStyles.labelLarge,
              ),
            ],
          ),
          const Divider(height: 24, color: AppColors.divider),
          Text(
            text,
            style: AppTextStyles.bodyLarge.copyWith(height: 1.7),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.caption.copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}
