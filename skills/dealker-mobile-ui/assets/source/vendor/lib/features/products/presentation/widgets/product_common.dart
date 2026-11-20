import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/products/application/product_providers.dart';
import 'package:dealker_vendor/features/products/data/product_models.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart';

export 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart'
    show
        AuctionAppBar,
        AuctionButton,
        AuctionField,
        BottomActionBar,
        EmptyState,
        ErrorState,
        FieldLabel,
        PickerField,
        ProductThumb,
        Segmented,
        SummaryRow,
        errorText,
        formatDateTime,
        formatInr,
        heading,
        kAuctionBlue,
        kAuctionBlueSoft,
        timeAgo;

const kBlue = kAuctionBlue;
const kBlueSoft = kAuctionBlueSoft;

/// B2B / B2C chip.
class ChannelChip extends StatelessWidget {
  const ChannelChip(this.label, {super.key, required this.b2b});
  final String label;
  final bool b2b;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: b2b ? AppColors.roleB2bBg : AppColors.roleB2cBg,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: b2b ? AppColors.roleB2b : AppColors.roleB2c)),
      );
}

class ChannelChips extends StatelessWidget {
  const ChannelChips({super.key, required this.b2b, required this.b2c});
  final bool b2b;
  final bool b2c;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 6, runSpacing: 4, children: [
        if (b2c) const ChannelChip('B2C', b2b: false),
        if (b2b) const ChannelChip('B2B', b2b: true),
      ]);
}

class StatePill extends StatelessWidget {
  const StatePill(this.state, {super.key});
  final ListingState state;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: state.bg, borderRadius: BorderRadius.circular(8)),
        child: Text(state.label,
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w800, color: state.fg)),
      );
}

class QcPill extends StatelessWidget {
  const QcPill(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final s = qcStyle(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration:
          BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(7)),
      child: Text(s.label,
          style: TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.w800, color: s.fg)),
    );
  }
}

/// White rounded card with the app's border + soft shadow.
class SectionCard extends StatelessWidget {
  const SectionCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(14),
      this.color = Colors.white,
      this.border});
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Color? border;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border ?? AppColors.cardBorder),
          boxShadow: [
            BoxShadow(
                color: AppColors.navy.withValues(alpha: 0.035),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: child,
      );
}

/// Photo that is either a network URL or a local file (demo mode / just picked).
class AnyImage extends StatelessWidget {
  const AnyImage(this.url,
      {super.key, this.fit = BoxFit.cover, this.radius = 12, this.size});
  final String? url;
  final BoxFit fit;
  final double radius;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
        width: size,
        height: size,
        color: const Color(0xFFF1F4FB),
        child:
            const Icon(PhosphorIconsRegular.image, color: AppColors.textMuted));
    final u = url;
    final Widget img = (u == null || u.isEmpty)
        ? fallback
        : u.startsWith('http')
            ? CachedNetworkImage(
                imageUrl: u,
                width: size,
                height: size,
                fit: fit,
                placeholder: (_, __) => fallback,
                errorWidget: (_, __, ___) => fallback)
            : Image.file(File(u),
                width: size,
                height: size,
                fit: fit,
                errorBuilder: (_, __, ___) => fallback);
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: img);
  }
}

/// Info / warning strip.
class NoteBanner extends StatelessWidget {
  const NoteBanner(this.message,
      {super.key,
      this.icon = PhosphorIconsFill.info,
      this.fg = kBlue,
      this.bg = kBlueSoft,
      this.title,
      this.action});
  final String message;
  final String? title;
  final IconData icon;
  final Color fg;
  final Color bg;
  final Widget? action;

  factory NoteBanner.warning(String message, {String? title, Widget? action}) =>
      NoteBanner(message,
          title: title,
          action: action,
          icon: PhosphorIconsFill.warning,
          fg: const Color(0xFFB45309),
          bg: AppColors.amberSoft);

  factory NoteBanner.error(String message, {String? title, Widget? action}) =>
      NoteBanner(message,
          title: title,
          action: action,
          icon: PhosphorIconsFill.warningCircle,
          fg: AppColors.rose,
          bg: AppColors.roseSoft);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 19, color: fg)),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (title != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(title!,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: fg)),
                ),
              Text(message,
                  style: const TextStyle(
                      fontSize: 13, height: 1.38, color: AppColors.navy)),
              if (action != null) ...[const SizedBox(height: 8), action!],
            ]),
          ),
        ]),
      );
}

/// Why this vendor can or can't list right now (KYC, plan limit …).
class ReadinessBanner extends StatelessWidget {
  const ReadinessBanner(this.r, {super.key});
  final Readiness r;

  @override
  Widget build(BuildContext context) => switch (r.issue) {
        ReadinessIssue.nearLimit => NoteBanner(r.message,
            icon: PhosphorIconsFill.chartBar, title: 'Listing quota'),
        ReadinessIssue.limitReached =>
          NoteBanner.error(r.message, title: 'Listing limit reached'),
        ReadinessIssue.suspended =>
          NoteBanner.error(r.message, title: 'Account not active'),
        ReadinessIssue.kycPending =>
          NoteBanner.warning(r.message, title: 'KYC required'),
      };
}

/// Bottom-sheet list picker. Returns the chosen value, or a typed one when
/// [allowCustom] is on. Null = dismissed.
Future<String?> pickOption(
  BuildContext context, {
  required String title,
  required List<String> options,
  String? selected,
  bool allowCustom = false,
  bool searchable = false,
  String customLabel = 'Other',
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (c) => _PickerSheet(
        title: title,
        options: options,
        selected: selected,
        allowCustom: allowCustom,
        searchable: searchable,
        customLabel: customLabel),
  );
}

class _PickerSheet extends StatefulWidget {
  const _PickerSheet(
      {required this.title,
      required this.options,
      required this.selected,
      required this.allowCustom,
      required this.searchable,
      required this.customLabel});
  final String title;
  final List<String> options;
  final String? selected;
  final bool allowCustom;
  final bool searchable;
  final String customLabel;

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  String _q = '';
  late bool _typing = widget.options.isEmpty && widget.allowCustom;
  final _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = widget.options
        .where((o) => o.toLowerCase().contains(_q.toLowerCase()))
        .toList();
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.78),
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 10),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(4))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(children: [
                Expanded(child: Text(widget.title, style: heading(size: 18))),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(PhosphorIconsRegular.x, size: 22)),
              ]),
            ),
            if (widget.searchable && !_typing)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _q = v),
                  decoration: InputDecoration(
                    hintText: 'Search',
                    prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass,
                        size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF3F6FC),
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
            if (_typing)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(children: [
                  TextField(
                    controller: _ctl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'Type here',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 15),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AuctionButton(
                      label: 'Use this',
                      onPressed: () {
                        final v = _ctl.text.trim();
                        if (v.isNotEmpty) Navigator.pop(context, v);
                      }),
                ]),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  children: [
                    for (final o in shown)
                      ListTile(
                        minVerticalPadding: 0,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 14),
                        title: Text(o,
                            style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: o == widget.selected
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: o == widget.selected
                                    ? kBlue
                                    : AppColors.navy)),
                        trailing: o == widget.selected
                            ? const Icon(PhosphorIconsBold.check,
                                color: kBlue, size: 20)
                            : null,
                        onTap: () => Navigator.pop(context, o),
                      ),
                    if (widget.allowCustom)
                      ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 14),
                        leading: const Icon(PhosphorIconsRegular.pencilSimple,
                            color: kBlue),
                        title: Text('${widget.customLabel} — type it',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, color: kBlue)),
                        onTap: () => setState(() => _typing = true),
                      ),
                    if (shown.isEmpty && !widget.allowCustom)
                      const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: Text('No matches'))),
                  ],
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// Failure dialog with a plain-language title.
Future<void> showFailureDialog(
    BuildContext context, ({String title, String message}) f) {
  return showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(f.title, style: heading(size: 18)),
      content: Text(f.message,
          style: const TextStyle(height: 1.4, color: AppColors.textSecondary)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('OK',
                style: TextStyle(fontWeight: FontWeight.w800, color: kBlue))),
      ],
    ),
  );
}

String discountLabel(num? price, num? mrp) {
  if (price == null || mrp == null || mrp <= price) return '';
  return '${(((mrp - price) / mrp) * 100).round()}% OFF';
}
