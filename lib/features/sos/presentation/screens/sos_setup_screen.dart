import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/locale.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/models/emergency_contact.dart';
import '../providers/sos_provider.dart';

class SosSetupScreen extends ConsumerWidget {
  const SosSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTr = ref.watch(isTurkishProvider);
    final contacts = ref.watch(sosContactsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isTr ? 'Acil Kişiler' : 'Emergency Contacts'),
        backgroundColor: AppColors.brandNavy,
      ),
      backgroundColor: AppColors.brandNavy,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withAlpha(20),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: const Color(0xFFEF4444).withAlpha(60)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    color: Color(0xFFEF4444), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isTr
                        ? 'SOS butonuna basıldığında bu kişilere GPS konumunuzu içeren mesaj gönderilir.'
                        : 'When SOS is activated, these contacts receive your GPS location via SMS.',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: const Color(0xFFEF4444)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isTr ? 'Acil Kişiler (en fazla 2)' : 'Emergency Contacts (max 2)',
            style: AppTextStyles.labelLarge,
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < 2; i++)
            _ContactTile(
              index: i,
              contact: i < contacts.length ? contacts[i] : null,
              isTr: isTr,
            ),
          const SizedBox(height: 24),
          Text(
            isTr
                ? 'Not: SMS gönderimi için Mesajlar uygulaması açılır. '
                    'Yalnızca güvendiğiniz kişileri ekleyin.'
                : 'Note: The Messages app opens to send the SMS. '
                    'Only add people you fully trust.',
            style:
                AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends ConsumerStatefulWidget {
  final int index;
  final EmergencyContact? contact;
  final bool isTr;

  const _ContactTile({
    required this.index,
    required this.contact,
    required this.isTr,
  });

  @override
  ConsumerState<_ContactTile> createState() => _ContactTileState();
}

class _ContactTileState extends ConsumerState<_ContactTile> {
  bool _editing = false;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.contact != null) {
      _nameCtrl.text = widget.contact!.name;
      _phoneCtrl.text = widget.contact!.phone;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) return;
    await ref.read(sosContactsProvider.notifier).update(
          widget.index,
          EmergencyContact(name: name, phone: phone),
        );
    if (mounted) setState(() => _editing = false);
  }

  Future<void> _delete() async {
    await ref.read(sosContactsProvider.notifier).remove(widget.index);
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.isTr
        ? 'Kişi ${widget.index + 1}'
        : 'Contact ${widget.index + 1}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: _editing || widget.contact == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.labelLarge),
                const SizedBox(height: 10),
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    hintText: widget.isTr ? 'Ad Soyad' : 'Full Name',
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: widget.isTr ? '+90 5xx ...' : '+1 555 ...',
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.brandTeal,
                          foregroundColor: AppColors.brandNavy,
                        ),
                        child: Text(widget.isTr ? 'Kaydet' : 'Save'),
                      ),
                    ),
                    if (_editing) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => setState(() => _editing = false),
                        child: Text(widget.isTr ? 'İptal' : 'Cancel'),
                      ),
                    ],
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person,
                      color: Color(0xFFEF4444)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.contact!.name,
                          style: AppTextStyles.labelLarge),
                      Text(widget.contact!.phone,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      color: AppColors.textSecondary),
                  onPressed: () => setState(() => _editing = true),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Color(0xFFEF4444)),
                  onPressed: _delete,
                ),
              ],
            ),
    );
  }
}
