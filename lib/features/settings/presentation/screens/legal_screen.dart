import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/locale.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Generic legal content screen.
/// [title] — displayed in the app bar and body heading.
/// [type] — 'privacy' | 'terms' | 'about'
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.title, this.type = 'generic'});

  final String title;
  final String type;

  String? get _webUrl {
    switch (type) {
      case 'privacy':
        return AppConstants.privacyPolicyUrl.isNotEmpty
            ? AppConstants.privacyPolicyUrl
            : null;
      case 'terms':
        return AppConstants.termsUrl.isNotEmpty ? AppConstants.termsUrl : null;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final webUrl = _webUrl;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          // Show "Open in browser" only when a live URL is configured.
          if (webUrl != null)
            IconButton(
              icon: const Icon(Icons.open_in_browser_outlined),
              tooltip: L.t('View online', 'Çevrimiçi görüntüle'),
              onPressed: () async {
                final uri = Uri.parse(webUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.displayMedium),
            const SizedBox(height: 8),
            Text(
              type == 'about'
                  ? L.t('Version ${AppConstants.appVersion}',
                      'Sürüm ${AppConstants.appVersion}')
                  : L.t('Last updated: May 2026',
                      'Son güncelleme: Mayıs 2026'),
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            _LegalSection(
              heading: type == 'about'
                  ? L.t('What is VisaRadar?', 'VisaRadar Travel nedir?')
                  : L.t('Overview', 'Genel Bakış'),
              body: type == 'privacy'
                  ? L.t(
                      'VisaRadar respects your privacy. All travel data is stored locally on your device and is never shared with third parties without your explicit consent.',
                      'VisaRadar Travel gizliliğinize saygı duyar. Tüm seyahat verileri cihazınızda yerel olarak saklanır ve açık rızanız olmadan asla üçüncü taraflarla paylaşılmaz.')
                  : type == 'terms'
                      ? L.t(
                          'By using VisaRadar you agree to use the application for lawful purposes only. VisaRadar provides travel tracking tools for informational purposes and is not a substitute for official legal or immigration advice.',
                          'VisaRadar Travel\'ı kullanarak uygulamayı yalnızca yasal amaçlarla kullanmayı kabul edersiniz. VisaRadar Travel bilgilendirme amaçlı seyahat takip araçları sunar ve resmi hukuki veya göçmenlik tavsiyesinin yerini tutmaz.')
                      : L.t(
                          'VisaRadar is a travel stay tracker that helps you monitor your Schengen zone usage, log border crossings, and stay aware of your travel limits. Built for frequent travellers who need clarity, not guesswork.',
                          'VisaRadar Travel, Schengen bölgesi kullanımınızı izlemenize, sınır geçişlerinizi kaydetmenize ve seyahat limitlerinizden haberdar olmanıza yardımcı olan bir seyahat takip uygulamasıdır. Tahmine değil netliğe ihtiyaç duyan sık seyahat edenler için tasarlanmıştır.'),
            ),
            const SizedBox(height: 20),
            _LegalSection(
              heading: L.t('Data Storage', 'Veri Saklama'),
              body: L.t(
                'All your profile and travel data is stored locally on your device. No data is transmitted to remote servers in this version of the app.',
                'Tüm profil ve seyahat verileriniz cihazınızda yerel olarak saklanır. Uygulamanın bu sürümünde hiçbir veri uzak sunuculara gönderilmez.',
              ),
            ),
            const SizedBox(height: 20),
            _LegalSection(
              heading: L.t('Disclaimer', 'Sorumluluk Reddi'),
              body: L.t(
                'VisaRadar is designed to help you track your travel history and Schengen zone usage. It does not provide legal advice. Always verify current visa rules with official government sources before travelling.',
                'VisaRadar Travel, seyahat geçmişinizi ve Schengen bölgesi kullanımınızı takip etmenize yardımcı olmak için tasarlanmıştır. Hukuki tavsiye vermez. Seyahat etmeden önce güncel vize kurallarını her zaman resmi devlet kaynaklarından doğrulayın.',
              ),
            ),
            const SizedBox(height: 20),
            _LegalSection(
              heading: L.t('Contact', 'İletişim'),
              body: L.t(
                'For privacy or legal enquiries, please use the support contact provided on the App Store listing.',
                'Gizlilik veya hukuki sorularınız için lütfen App Store listelemesinde sağlanan destek iletişim bilgilerini kullanın.',
              ),
            ),
            // Link row — shown when a live URL is configured.
            if (webUrl != null) ...[
              const SizedBox(height: 24),
              _WebLinkRow(
                  url: webUrl,
                  label: L.t('View full document online',
                      'Tam belgeyi çevrimiçi görüntüle')),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Inline web link row
// ---------------------------------------------------------------------------

class _WebLinkRow extends StatelessWidget {
  const _WebLinkRow({required this.url, required this.label});

  final String url;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Row(
        children: [
          const Icon(Icons.open_in_new, size: 14, color: AppColors.brandTeal),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.brandTeal,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.brandTeal,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section widget
// ---------------------------------------------------------------------------

class _LegalSection extends StatelessWidget {
  const _LegalSection({required this.heading, required this.body});

  final String heading;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(heading,
            style: AppTextStyles.bodyLarge
                .copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(body,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary, height: 1.6)),
      ],
    );
  }
}
