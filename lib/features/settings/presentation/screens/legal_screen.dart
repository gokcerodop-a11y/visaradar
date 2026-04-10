import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
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
              tooltip: 'View online',
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
                  ? 'Version ${AppConstants.appVersion}'
                  : 'Last updated: March 2026',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            _LegalSection(
              heading: type == 'about' ? 'What is VisaRadar?' : 'Overview',
              body: type == 'privacy'
                  ? 'VisaRadar respects your privacy. All travel data is stored locally on your device and is never shared with third parties without your explicit consent.'
                  : type == 'terms'
                      ? 'By using VisaRadar you agree to use the application for lawful purposes only. VisaRadar provides travel tracking tools for informational purposes and is not a substitute for official legal or immigration advice.'
                      : 'VisaRadar is a travel stay tracker that helps you monitor your Schengen zone usage, log border crossings, and stay aware of your travel limits. Built for frequent travellers who need clarity, not guesswork.',
            ),
            const SizedBox(height: 20),
            _LegalSection(
              heading: 'Data Storage',
              body:
                  'All your profile and travel data is stored locally on your device. No data is transmitted to remote servers in this version of the app.',
            ),
            const SizedBox(height: 20),
            _LegalSection(
              heading: 'Disclaimer',
              body:
                  'VisaRadar is designed to help you track your travel history and Schengen zone usage. It does not provide legal advice. Always verify current visa rules with official government sources before travelling.',
            ),
            const SizedBox(height: 20),
            _LegalSection(
              heading: 'Contact',
              body:
                  'For privacy concerns or legal enquiries, contact: contact@visaradar.app\n\nFull legal documents will be published at visaradar.app before public launch.',
            ),
            // Link row — shown when a live URL is configured.
            if (webUrl != null) ...[
              const SizedBox(height: 24),
              _WebLinkRow(url: webUrl, label: 'View full document online'),
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
