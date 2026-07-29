// consent_gate_screen.dart — KVKK + 3. taraf AI veri onay kapısı (TR/EN).
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/localization/locale.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

const _consentVersion = 2;
const _consentKey = 'visaradar.consent.version';
const _tipsOptInKey = 'visaradar.consent.tipsOptIn';

class ConsentGateScreen extends StatefulWidget {
  final VoidCallback onAccepted;
  const ConsentGateScreen({super.key, required this.onAccepted});

  @override
  State<ConsentGateScreen> createState() => _ConsentGateScreenState();
}

class _ConsentGateScreenState extends State<ConsentGateScreen> {
  bool _termsAccepted = false; // 1 — zorunlu / required
  bool _aiConsent = false; // 2 — zorunlu / required
  bool _locationConsent = false; // 3 — zorunlu / required
  bool _tipsOptIn = false; // 4 — isteğe bağlı / optional
  bool _busy = false;

  bool get _canAccept =>
      _termsAccepted && _aiConsent && _locationConsent && !_busy;

  Future<void> _accept() async {
    if (!_canAccept) return;
    setState(() => _busy = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_consentKey, _consentVersion);
    await prefs.setBool(_tipsOptInKey, _tipsOptIn);
    widget.onAccepted();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandNavy,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            const Icon(Icons.radar_rounded, color: AppColors.brandTeal, size: 44),
            const SizedBox(height: 12),
            Text(
              L.t('Privacy & Consent', 'Gizlilik ve Onay'),
              style: const TextStyle(
                  color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              L.t('Please read before continuing',
                  'Devam etmeden önce lütfen okuyun'),
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _heading(L.t('Personal Data Protection',
                          'Kişisel Verilerin Korunması (KVKK)')),
                      _body(L.t(
                        'VisaRadar uses artificial intelligence technology to '
                        'answer your travel and visa questions.\n\n'
                        'Data processed: the questions you type, your passport '
                        'details and your travel plans.\n\n'
                        'This content is transmitted over a secure (TLS) '
                        'connection through Anthropic, PBC (USA — the "Claude" '
                        'service) and Cloudflare infrastructure to generate '
                        'responses. This constitutes a cross-border data '
                        'transfer.\n\n'
                        'Your data is not used for advertising and is not '
                        'stored to train AI models. Your chat history is kept '
                        'only on your device.',
                        'VisaRadar, seyahat ve vize sorularınızı yanıtlamak için '
                        'yapay zekâ teknolojisi kullanmaktadır.\n\n'
                        'İşlenen veriler: Yazdığınız sorular, pasaport bilgileriniz ve '
                        'seyahat planlarınız.\n\n'
                        'Bu içerik, yanıt oluşturmak amacıyla güvenli (TLS) bağlantı '
                        'üzerinden Anthropic, PBC (ABD — "Claude" servisi) ve Cloudflare '
                        'altyapısı üzerinden iletilir. Bu, KVKK kapsamında yurt dışına '
                        'veri aktarımı anlamına gelir.\n\n'
                        'Verileriniz reklam için kullanılmaz ve AI modeli eğitimi için '
                        'saklanmaz. Sohbet geçmişiniz yalnızca cihazınızda tutulur.',
                      )),
                      const SizedBox(height: 16),
                      _heading(L.t('Notice', 'Bilgilendirme')),
                      _body(L.t(
                        'VisaRadar is not an official visa advisory service. '
                        'AI responses may be out of date due to changing visa '
                        'regulations. Confirm with official authorities or '
                        'embassies before travelling.',
                        'VisaRadar resmi bir vize danışmanlık hizmeti değildir. '
                        'Yapay zekâ yanıtları değişen vize mevzuatı nedeniyle '
                        'güncel olmayabilir. Seyahat öncesi resmi makamları '
                        'veya büyükelçilikleri teyit edin.',
                      )),
                      const Divider(height: 32, color: AppColors.divider),
                      _checkTile(
                        value: _termsAccepted,
                        onChanged: (v) =>
                            setState(() => _termsAccepted = v ?? false),
                        label: L.t(
                          'I have read and accept the Privacy Policy and Terms of Use.',
                          'Gizlilik Politikası ve Kullanım Koşulları\'nı okudum, kabul ediyorum.',
                        ),
                      ),
                      _checkTile(
                        value: _aiConsent,
                        onChanged: (v) =>
                            setState(() => _aiConsent = v ?? false),
                        label: L.t(
                          'I consent to my personal data being processed by AI.',
                          'Kişisel verilerimin yapay zeka tarafından işlenmesine onay veriyorum.',
                        ),
                      ),
                      _checkTile(
                        value: _locationConsent,
                        onChanged: (v) =>
                            setState(() => _locationConsent = v ?? false),
                        label: L.t(
                          'I consent to my location data being used for Schengen and border tracking.',
                          'Konum verilerimin Schengen ve sınır takibi için kullanılmasına onay veriyorum.',
                        ),
                      ),
                      _checkTile(
                        value: _tipsOptIn,
                        onChanged: (v) =>
                            setState(() => _tipsOptIn = v ?? false),
                        label: L.t(
                          'I want to receive in-app tips and notifications. (optional)',
                          'Uygulama içi ipuçları ve bildirimler almak istiyorum. (isteğe bağlı)',
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canAccept ? _accept : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandTeal,
                    disabledBackgroundColor:
                        AppColors.brandTeal.withValues(alpha: 0.31),
                    foregroundColor: AppColors.brandNavy,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: _busy
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.brandNavy),
                        )
                      : Text(
                          L.t('I accept, continue', 'Kabul ediyorum, devam et'),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: AppTextStyles.titleLarge
                .copyWith(fontSize: 15, color: AppColors.textPrimary)),
      );

  Widget _body(String text) => Text(text,
      style: AppTextStyles.bodySmall
          .copyWith(height: 1.6, color: AppColors.textSecondary));

  Widget _checkTile(
          {required bool value,
          required ValueChanged<bool?> onChanged,
          required String label}) =>
      CheckboxListTile(
        value: value,
        onChanged: onChanged,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: AppColors.brandTeal,
        checkColor: AppColors.brandNavy,
        title: Text(label,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textPrimary)),
      );
}

Future<bool> isConsentGiven() async {
  final prefs = await SharedPreferences.getInstance();
  return (prefs.getInt(_consentKey) ?? 0) >= _consentVersion;
}
