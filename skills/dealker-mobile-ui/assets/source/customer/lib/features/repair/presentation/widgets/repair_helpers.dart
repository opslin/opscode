import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dealker_app/core/theme/repair_tokens.dart';
import 'package:dealker_app/features/repair/presentation/widgets/repair_ui.dart';
import 'package:dealker_app/features/repair/repair_providers.dart';

/// "17 Oct, 12:20 PM"
String fmtDateTime(DateTime d) => DateFormat('d MMM, h:mm a').format(d);

/// "Sat, 17 Oct · 10 AM–1 PM" style pieces.
String fmtDay(DateTime d) => DateFormat('EEE, d MMM').format(d);
String fmtTime(DateTime d) => DateFormat('h:mm a').format(d);
String fmtDate(DateTime d) => DateFormat('d MMM yyyy').format(d);

/// "1h 05m", "23h 41m", "12m"; null when the time has passed.
String? fmtCountdown(DateTime? end, [DateTime? now]) {
  if (end == null) return null;
  final Duration left = end.difference(now ?? DateTime.now());
  if (left.isNegative || left.inMinutes < 1) return null;
  final int h = left.inHours;
  final int m = left.inMinutes % 60;
  return h > 0 ? '${h}h ${m.toString().padLeft(2, '0')}m' : '${m}m';
}

/// "1.2k" for 1200, "892" for 892.
String compactCount(int n) {
  if (n >= 1000) {
    final double k = n / 1000;
    return '${k.toStringAsFixed(k >= 10 ? 0 : 1)}k';
  }
  return '$n';
}

/// The area part of "line1, line2, City, State, 700091" → "City".
String shopArea(String? address) {
  final List<String> parts = (address ?? '')
      .split(',')
      .map((String e) => e.trim())
      .where((String e) => e.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '';
  if (parts.length >= 3) return parts[parts.length - 3];
  return parts.first;
}

Future<void> callPhone(BuildContext context, String? phone) async {
  final String p = (phone ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
  if (p.isEmpty) return;
  final bool ok = await launchUrl(Uri(scheme: 'tel', path: p));
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Couldn’t open the phone app.')),
    );
  }
}

/// Opens Google Maps with driving directions to [query] (no in-app tracking).
Future<void> openMaps(BuildContext context, String query) async {
  final bool ok = await launchUrl(
    Uri.https(
      'www.google.com',
      '/maps/dir/',
      <String, String>{
        'api': '1',
        'destination': query,
        'travelmode': 'driving',
      },
    ),
    mode: LaunchMode.externalApplication,
  );
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Couldn’t open maps.')));
  }
}

/// Bottom sheet that asks why, then returns the reason (or null when dismissed).
Future<String?> askReason(
  BuildContext context, {
  required String title,
  required List<String> reasons,
  required String confirmLabel,
  String? warning,
  bool danger = true,
  String question = 'Why do you want to cancel?',
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext ctx) => _ReasonSheet(
      title: title,
      reasons: reasons,
      confirmLabel: confirmLabel,
      warning: warning,
      danger: danger,
      question: question,
    ),
  );
}

class _ReasonSheet extends StatefulWidget {
  const _ReasonSheet({
    required this.title,
    required this.reasons,
    required this.confirmLabel,
    required this.danger,
    required this.question,
    this.warning,
  });

  final String title;
  final List<String> reasons;
  final String confirmLabel;
  final String? warning;
  final bool danger;
  final String question;

  @override
  State<_ReasonSheet> createState() => _ReasonSheetState();
}

class _ReasonSheetState extends State<_ReasonSheet> {
  String? _picked;
  final TextEditingController _other = TextEditingController();

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  bool get _isOther => _picked == 'Other reason';

  @override
  Widget build(BuildContext context) {
    final bool ready =
        _picked != null && (!_isOther || _other.text.trim().length >= 3);
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: RT.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(widget.title, style: rtHead(18)),
                const SizedBox(height: 6),
                Text(widget.question, style: rtBody(13.5)),
                const SizedBox(height: 8),
                for (final String r in widget.reasons)
                  InkWell(
                    onTap: () => setState(() => _picked = r),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _picked == r ? RT.indigo : RT.border,
                                width: 2,
                              ),
                            ),
                            child: _picked == r
                                ? Center(
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: RT.indigo,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Text(
                            r,
                            style: rtBody(
                              15,
                              color: RT.ink,
                              w: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_isOther) ...<Widget>[
                  TextField(
                    controller: _other,
                    onChanged: (_) => setState(() {}),
                    maxLength: 200,
                    decoration: const InputDecoration(hintText: 'Tell us more'),
                  ),
                ],
                if (widget.warning != null) ...<Widget>[
                  const SizedBox(height: 8),
                  RBand(widget.warning!, kind: BandKind.warn),
                ],
                const SizedBox(height: 14),
                RButton(
                  label: widget.confirmLabel,
                  danger: widget.danger,
                  onTap: ready
                      ? () => Navigator.pop(
                            context,
                            _isOther ? _other.text.trim() : _picked,
                          )
                      : null,
                ),
                const SizedBox(height: 4),
                Center(
                  child: RLink('Keep it', onTap: () => Navigator.pop(context)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Square shop avatar: the shop has no photo in the quote payload, so it shows a
/// storefront tile.
class ShopTile extends StatelessWidget {
  const ShopTile({this.size = 58, this.seed = '', super.key});

  final double size;

  /// Stable text (shop / offer id) that picks one of the nine 3D storefronts.
  final String seed;

  @override
  Widget build(BuildContext context) {
    int h = 0;
    for (final int c in seed.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: RT.tint,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: EdgeInsets.all(size * 0.08),
      child:
          Image.asset('assets/shops/shop${h % 9 + 1}.png', fit: BoxFit.contain),
    );
  }
}

/// Bottom sheet to pick one of the saved addresses. Returns the address id,
/// `'__new'` for "Add new address", or null when dismissed.
Future<String?> pickAddress(
  BuildContext context,
  List<SavedAddress> list,
  String? current,
) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (BuildContext ctx) => Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: RT.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text('Choose address', style: rtHead(18)),
              const SizedBox(height: 10),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: <Widget>[
                    for (final SavedAddress a in list)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: PhosphorIcon(
                          PhosphorIconsRegular.mapPin,
                          size: 22,
                          color: a.id == current ? RT.indigo : RT.muted,
                        ),
                        title: Text(
                          a.label,
                          style: rtHead(15, w: FontWeight.w700),
                        ),
                        subtitle: Text(
                          a.full,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: rtBody(12.5),
                        ),
                        trailing: a.id == current
                            ? const PhosphorIcon(
                                PhosphorIconsFill.checkCircle,
                                color: RT.indigo,
                              )
                            : null,
                        onTap: () => Navigator.pop(ctx, a.id),
                      ),
                  ],
                ),
              ),
              RLink(
                'Add new address',
                icon: PhosphorIconsRegular.plus,
                onTap: () => Navigator.pop(ctx, '__new'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
