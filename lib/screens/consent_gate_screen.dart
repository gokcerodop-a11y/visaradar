// consent_gate_screen.dart — KVKK + 3. taraf AI veri onay kapısı.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/app_colors.dart';

const _consentVersion = 1;
const _consentKey = 'visaradar.consent.version';

class ConsentGateScreen extends StatefulWidget {
  final VoidCallback onAccepted;
  const ConsentGateScreen({super.key, required this.onAccepted});

  @override
  State<ConsentGateScreen> createState() => _ConsentGateScreenState();
}

class _ConsentGateScreenState extends State<ConsentGateScreen> {
  bool _read = false;
  bool _aiConsent = false;
  bool _busy = false;

  bool get _canAccept => _read && _aiConsent && !_busy;

  Future<void> _accept() async {
    if (!_canAccept) return;
    setState(() => _busy = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_consentKey, _consentVersion);
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
            const Text(
              'VisaRadar',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Devam etmeden önce lütfen okuyun',
              style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 13),
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
                      _heading('Kişisel Verilerin Korunması (KVKK)'),
                      _body(
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
                      ),
                      const SizedBox(height: 16),
                      _heading('Bilgilendirme'),
                      _body(
                        'VisaRadar resmi bir vize danışmanlık hizmeti değildir. '
                        'Yapay zekâ yanıtları değişen vize mevzuatı nedeniyle '
                        'güncel olmayabilir. Seyahat öncesi resmi makamları '
                        'veya büyükelçilikleri teyit edin.',
                      ),
                      const Divider(height: 32, color: AppColors.divider),
                      _checkTile(
                        value: _read,
                        onChanged: (v) => setState(() => _read = v ?? false),
                        label: 'Yukarıdaki bildirimi okudum, uygulamanın yanılabileceğini biliyorum.',
                      ),
                      _checkTile(
                        value: _aiConsent,
                        onChanged: (v) => setState(() => _aiConsent = v ?? false),
                        label: 'Sorularımın yanıt üretmek için Anthropic, PBC\'ye (ABD) güvenli şekilde '
                            'iletilmesini ve yurt dışına aktarılmasını açıkça kabul ediyorum.',
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
                    disabledBackgroundColor: AppColors.brandTeal.withAlpha(80),
                    foregroundColor: AppColors.brandNavy,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: _busy
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brandNavy),
                        )
                      : const Text(
                          'Kabul ediyorum, devam et',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
        child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      );

  Widget _body(String text) => Text(text,
        style: const TextStyle(fontSize: 13, height: 1.6, color: AppColors.textSecondary));

  Widget _checkTile({required bool value, required ValueChanged<bool?> onChanged, required String label}) =>
      CheckboxListTile(
        value: value,
        onChanged: onChanged,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: AppColors.brandTeal,
        checkColor: AppColors.brandNavy,
        title: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
      );
}

Future<bool> isConsentGiven() async {
  final prefs = await SharedPreferences.getInstance();
  return (prefs.getInt(_consentKey) ?? 0) >= _consentVersion;
}
