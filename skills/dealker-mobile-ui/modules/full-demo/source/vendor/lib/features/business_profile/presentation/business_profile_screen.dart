import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart';
import 'package:dealker_vendor/features/business_profile/application/business_providers.dart';
import 'package:dealker_vendor/features/business_profile/data/business_models.dart';
import 'package:dealker_vendor/features/business_profile/presentation/kyc_documents_section.dart';
import 'package:dealker_vendor/features/business_profile/presentation/shop_location_section.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

final _gstin = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$');
final _pan = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');
final _pin = RegExp(r'^[1-9][0-9]{5}$');
final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// One editable field in a section sheet.
class _Spec {
  const _Spec(this.key, this.label, this.value,
      {this.locked = false,
      this.hint,
      this.digits = false,
      this.upper = false,
      this.max,
      this.validate});
  final String key; // API field name
  final String label;
  final String value;
  final bool locked;
  final String? hint;
  final bool digits;
  final bool upper;
  final int? max;
  final String? Function(String v)? validate;
}

/// Who you are as a seller: store contact, KYC identity, address and documents.
class BusinessProfileScreen extends ConsumerWidget {
  const BusinessProfileScreen({super.key});

  Future<void> _edit(
      BuildContext context,
      WidgetRef ref,
      String title,
      List<_Spec> specs,
      Future<void> Function(Map<String, dynamic>) save) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _EditSheet(title: title, specs: specs, save: save),
    );
    if (saved == true) {
      refreshBusinessProfile(ref);
      if (context.mounted) showAppToast(context, 'Saved.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(businessProfileProvider);
    final repo = ref.read(businessRepositoryProvider);
    final id = ref.watch(businessVendorIdProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AuctionAppBar(
          title: 'Business Profile', subtitle: 'Your store and KYC details'),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(businessProfileProvider);
          await ref
              .read(businessProfileProvider.future)
              .catchError((_) => const BusinessProfile(name: '', status: ''));
        },
        child: async.when(skipLoadingOnReload: true, skipError: true, 
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            SizedBox(
                height: 420,
                child: ErrorState(
                    message:
                        errorText(e, 'Could not load your business profile.'),
                    onRetry: () => ref.invalidate(businessProfileProvider))),
          ]),
          data: (b) {
            final lockNote = b.verified
                ? 'Verified during KYC — to change these, contact support. Empty fields can still be filled in.'
                : null;
            bool lock(String v) => b.verified && v.isNotEmpty;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              children: [
                _Header(b),
                const SizedBox(height: 14),
                _Section(
                  icon: PhosphorIconsFill.storefront,
                  title: 'Store details',
                  onEdit: id == null
                      ? null
                      : () => _edit(
                            context,
                            ref,
                            'Store details',
                            [
                              _Spec('name', 'Store name', b.name,
                                  max: 100,
                                  validate: (v) => v.trim().length < 2
                                      ? 'At least 2 characters.'
                                      : null),
                              _Spec('email', 'Contact email', b.email,
                                  validate: (v) => _email.hasMatch(v.trim())
                                      ? null
                                      : 'Enter a valid email.'),
                              _Spec('phone', 'Business phone', b.phone,
                                  digits: true,
                                  max: 15,
                                  validate: (v) => v.length < 8
                                      ? 'Enter a valid phone number.'
                                      : null),
                            ],
                            (c) => repo.saveStore(id, c),
                          ),
                  rows: [
                    ('Store name', b.name),
                    ('Email', b.email),
                    ('Phone', b.phone)
                  ],
                ),
                const SizedBox(height: 12),
                _Section(
                  icon: PhosphorIconsFill.identificationCard,
                  title: 'Business identity',
                  note: lockNote,
                  onEdit: id == null
                      ? null
                      : () => _edit(
                            context,
                            ref,
                            'Business identity',
                            [
                              _Spec('legal_name', 'Legal business name',
                                  b.legalName,
                                  locked: lock(b.legalName), max: 150),
                              _Spec('gstin', 'GSTIN', b.gstin,
                                  locked: lock(b.gstin),
                                  upper: true,
                                  max: 15,
                                  hint: '29ABCDE1234F1Z5',
                                  validate: (v) => v.isEmpty ||
                                          _gstin.hasMatch(v)
                                      ? null
                                      : 'GSTIN is 15 characters, like 29ABCDE1234F1Z5.'),
                              _Spec('pan_number', 'PAN', b.pan,
                                  locked: lock(b.pan),
                                  upper: true,
                                  max: 10,
                                  hint: 'ABCDE1234F',
                                  validate: (v) => v.isEmpty || _pan.hasMatch(v)
                                      ? null
                                      : 'PAN looks like ABCDE1234F.'),
                              _Spec('trade_license_number', 'Trade licence no.',
                                  b.tradeLicense,
                                  locked: lock(b.tradeLicense), max: 60),
                              _Spec(
                                  'fssai_license', 'FSSAI licence no.', b.fssai,
                                  locked: lock(b.fssai), max: 60),
                            ],
                            (c) => repo.saveProfile(id, c),
                          ),
                  rows: [
                    ('Legal name', b.legalName),
                    ('GSTIN', b.gstin),
                    ('PAN', b.pan),
                    ('Trade licence', b.tradeLicense),
                    ('FSSAI', b.fssai),
                  ],
                  locked: b.verified,
                ),
                const SizedBox(height: 12),
                _Section(
                  icon: PhosphorIconsFill.mapPin,
                  title: 'Pickup & business address',
                  onEdit: id == null
                      ? null
                      : () => _edit(
                            context,
                            ref,
                            'Address',
                            [
                              _Spec(
                                  'address_line1', 'Address line 1', b.address1,
                                  max: 200,
                                  validate: (v) => v.trim().isEmpty
                                      ? 'Enter your address.'
                                      : null),
                              _Spec('address_line2',
                                  'Address line 2 (optional)', b.address2,
                                  max: 200),
                              _Spec('city', 'City', b.city,
                                  max: 80,
                                  validate: (v) => v.trim().isEmpty
                                      ? 'Enter your city.'
                                      : null),
                              _Spec('state', 'State', b.state, max: 80),
                              _Spec('pincode', 'Pincode', b.pincode,
                                  digits: true,
                                  max: 6,
                                  validate: (v) => _pin.hasMatch(v)
                                      ? null
                                      : 'Pincode is 6 digits.'),
                            ],
                            (c) => repo.saveProfile(id, c),
                          ),
                  rows: [('Address', b.addressLine)],
                ),
                const SizedBox(height: 12),
                ShopLocationSection(profile: b),
                const SizedBox(height: 12),
                KycDocumentsSection(profile: b),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.b);
  final BusinessProfile b;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (b.status) {
      'ACTIVE' || 'VERIFIED' => ('Verified partner', AppColors.success),
      'KYC_SUBMITTED' || 'UNDER_REVIEW' => (
          'KYC under review',
          const Color(0xFFB45309)
        ),
      'CORRECTION_REQUIRED' => ('Correction needed', AppColors.rose),
      'SUSPENDED' => ('Suspended', AppColors.rose),
      _ => ('Complete your KYC', const Color(0xFFB45309)),
    };
    return HomeCard(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        CircleAvatar(
            radius: 28,
            backgroundColor: kAuctionBlueSoft,
            child: Text(b.name.isEmpty ? '?' : b.name.trim()[0].toUpperCase(),
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: kAuctionBlue))),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(b.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: heading(size: 18)),
          const SizedBox(height: 4),
          Row(children: [
            Icon(
                b.verified
                    ? PhosphorIconsFill.sealCheck
                    : PhosphorIconsFill.clock,
                size: 16,
                color: color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13, color: color)),
          ]),
        ])),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(
      {required this.icon,
      required this.title,
      required this.rows,
      this.onEdit,
      this.note,
      this.locked = false});
  final IconData icon;
  final String title;
  final List<(String, String)> rows;
  final VoidCallback? onEdit;
  final String? note;
  final bool locked;

  @override
  Widget build(BuildContext context) => HomeCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 20, color: kAuctionBlue),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: heading(size: 15.5))),
            if (onEdit != null)
              TextButton.icon(
                  onPressed: onEdit,
                  icon: Icon(
                      locked
                          ? PhosphorIconsBold.lockSimple
                          : PhosphorIconsBold.pencilSimple,
                      size: 15),
                  label: Text(locked ? 'View / fill' : 'Edit')),
          ]),
          for (final (k, v) in rows)
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 8),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                    width: 110,
                    child: Text(k,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textMuted))),
                Expanded(
                    child: Text(v.isEmpty ? 'Not added' : v,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: v.isEmpty
                                ? AppColors.textMuted
                                : AppColors.navy))),
              ]),
            ),
          if (note != null) ...[
            const SizedBox(height: 10),
            Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(note!,
                    style: const TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: AppColors.textMuted))),
          ],
        ]),
      );
}

class _EditSheet extends StatefulWidget {
  const _EditSheet(
      {required this.title, required this.specs, required this.save});
  final String title;
  final List<_Spec> specs;
  final Future<void> Function(Map<String, dynamic>) save;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final Map<String, TextEditingController> _c = {
    for (final s in widget.specs) s.key: TextEditingController(text: s.value),
  };
  final _form = GlobalKey<FormState>();
  bool _busy = false;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _go() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final changes = <String, dynamic>{};
    for (final s in widget.specs) {
      if (s.locked) continue;
      final v = _c[s.key]!.text.trim();
      if (v != s.value.trim()) changes[s.key] = v;
    }
    if (changes.isEmpty) {
      Navigator.pop(context, false);
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.save(changes);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showAppToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Form(
            key: _form,
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                      child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                              color: AppColors.border,
                              borderRadius: BorderRadius.circular(4)))),
                  const SizedBox(height: 14),
                  Text(widget.title, style: heading(size: 20)),
                  const SizedBox(height: 14),
                  for (final s in widget.specs) ...[
                    FieldLabel(s.label),
                    TextFormField(
                      controller: _c[s.key],
                      enabled: !s.locked,
                      maxLength: s.max,
                      textCapitalization: s.upper
                          ? TextCapitalization.characters
                          : TextCapitalization.none,
                      keyboardType:
                          s.digits ? TextInputType.number : TextInputType.text,
                      inputFormatters: [
                        if (s.digits) FilteringTextInputFormatter.digitsOnly,
                        if (s.upper) _UpperCase(),
                      ],
                      validator: s.locked
                          ? null
                          : (v) => s.validate?.call((v ?? '').trim()),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: s.hint,
                        isDense: true,
                        filled: true,
                        fillColor:
                            s.locked ? const Color(0xFFF4F6FC) : Colors.white,
                        suffixIcon: s.locked
                            ? const Icon(PhosphorIconsFill.lockSimple,
                                size: 18, color: AppColors.textMuted)
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 15),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: AppColors.border)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: kAuctionBlue, width: 1.6)),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  AuctionButton(label: 'Save', loading: _busy, onPressed: _go),
                ]),
          ),
        ),
      );
}

class _UpperCase extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue v) =>
      v.copyWith(text: v.text.toUpperCase());
}
