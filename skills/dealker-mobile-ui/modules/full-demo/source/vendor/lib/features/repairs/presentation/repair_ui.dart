import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:dealker_vendor/core/maps/ola_maps.dart';
import 'package:dealker_vendor/shared/widgets/dm_logo.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dealker_vendor/core/constants/api_constants.dart';
import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/home/presentation/widgets/home_common.dart';
import 'package:dealker_vendor/features/repairs/application/repairs_providers.dart';
import 'package:dealker_vendor/features/repairs/data/repair_models.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';
import 'package:dealker_vendor/shared/widgets/premium_ui.dart' show A3, Art3D;

/// Repair colours — the DEALKR blue of the approved Repair Service Flow mockups.
class RC {
  RC._();
  static const blue = Color(0xFF1558E8);
  static const blueDark = Color(0xFF0B2E7A);
  static const tint = Color(0xFFEAF1FF);
  static const green = Color(0xFF15803D);
  static const greenTint = Color(0xFFDDF5E4);
  static const amber = Color(0xFF9A5B00);
  static const amberTint = Color(0xFFFFF0C2);
  static const red = Color(0xFFE5232E);
  static const redTint = Color(0xFFFDECEE);
  static const grey = Color(0xFF6B7390);
  static const line = Color(0xFFE3EAF7);
  static const canvas = Color(0xFFF5F8FF);
}

/// "https://host/api/v1" → "https://host" (signed media links are relative to the host).
String apiOrigin() => Uri.parse(ApiConstants.baseUrl).origin;
String absoluteUrl(String u) => u.startsWith('http') ? u : '${apiOrigin()}$u';

/// Plain-language name + a clear icon for every kind of repair (kids and grandparents should get it).
class IssueMeta {
  const IssueMeta(this.label, this.icon, this.color, this.bg);
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
}

IssueMeta issueMeta(String key) => switch (key) {
      'SCREEN' => const IssueMeta('Broken screen',
          PhosphorIconsFill.deviceMobile, Color(0xFF1558E8), Color(0xFFEAF1FF)),
      'BATTERY' => const IssueMeta(
          'Battery problem',
          PhosphorIconsFill.batteryWarning,
          Color(0xFF15803D),
          Color(0xFFDDF5E4)),
      'CHARGING' => const IssueMeta('Charging problem',
          PhosphorIconsFill.plugCharging, Color(0xFFD97706), Color(0xFFFFF0C2)),
      'WATER_DAMAGE' => const IssueMeta('Water damage', PhosphorIconsFill.drop,
          Color(0xFF0891B2), Color(0xFFD9F4FA)),
      'SOFTWARE' => const IssueMeta('Phone software', PhosphorIconsFill.gear,
          Color(0xFF6D28D9), Color(0xFFEDE5FF)),
      'CAMERA' => const IssueMeta('Camera', PhosphorIconsFill.camera,
          Color(0xFFDB2777), Color(0xFFFFE3F0)),
      'AUDIO' => const IssueMeta('Speaker / mic', PhosphorIconsFill.speakerHigh,
          Color(0xFF0F766E), Color(0xFFD7F5F0)),
      'BODY' => const IssueMeta(
          'Back glass / body',
          PhosphorIconsFill.deviceMobileCamera,
          Color(0xFF475569),
          Color(0xFFE8EDF4)),
      'BOARD' => const IssueMeta('Motherboard', PhosphorIconsFill.cpu,
          Color(0xFF7C3AED), Color(0xFFEFE7FF)),
      'BIOMETRIC' => const IssueMeta('Face ID / fingerprint',
          PhosphorIconsFill.fingerprint, Color(0xFF1558E8), Color(0xFFEAF1FF)),
      'DATA' => const IssueMeta('Data recovery', PhosphorIconsFill.database,
          Color(0xFF475569), Color(0xFFE8EDF4)),
      'TOUCH' => const IssueMeta('Touch not working', PhosphorIconsFill.handTap,
          Color(0xFFEA580C), Color(0xFFFFE9DB)),
      'NETWORK' => const IssueMeta(
          'Network / SIM',
          PhosphorIconsFill.cellSignalFull,
          Color(0xFF0369A1),
          Color(0xFFDDEFFB)),
      _ => const IssueMeta('Other problem', PhosphorIconsFill.wrench,
          Color(0xFF475569), Color(0xFFE8EDF4)),
    };

/// 3D picture for each kind of repair (falls back to the toolbox).
String issueArt(String key) => switch (key) {
      'SCREEN' => A3.repair('screen'),
      'BATTERY' => A3.repair('battery'),
      'CHARGING' => A3.repair('charging'),
      'WATER_DAMAGE' => A3.repair('water'),
      'SOFTWARE' => A3.repair('software'),
      'CAMERA' => A3.repair('camera'),
      'AUDIO' => A3.repair('audio'),
      'BODY' => A3.repair('body'),
      'BOARD' => A3.repair('board'),
      'BIOMETRIC' => A3.profile('fingerprint'),
      'DATA' => A3.repair('data'),
      'TOUCH' => A3.repair('touch'),
      'NETWORK' => A3.repair('network'),
      _ => A3.repair('toolbox'),
    };

/// Soft glossy tile with the 3D picture of the problem — one clear picture per problem.
class IssueBadge extends StatelessWidget {
  const IssueBadge(this.issue, {super.key, this.size = 40});
  final String issue;
  final double size;

  @override
  Widget build(BuildContext context) {
    final m = issueMeta(issue);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, m.bg]),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: m.color.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
              color: m.color.withValues(alpha: 0.16),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      alignment: Alignment.center,
      child: Image.asset(issueArt(issue),
          width: size * 0.78,
          height: size * 0.78,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              Icon(m.icon, color: m.color, size: size * 0.5)),
    );
  }
}

/// Small tinted pill, e.g. "Screen broken".
class IssueChip extends StatelessWidget {
  const IssueChip(this.issue, {super.key});
  final String issue;

  @override
  Widget build(BuildContext context) {
    final m = issueMeta(issue);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: RC.tint, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(m.icon, size: 13, color: RC.blue),
        const SizedBox(width: 5),
        Text(m.label,
            style: const TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w700, color: RC.blue)),
      ]),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.label,
      {super.key, this.kind = ChipKind.blue, this.icon});
  final String label;
  final ChipKind kind;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (kind) {
      ChipKind.green => (RC.green, RC.greenTint),
      ChipKind.amber => (RC.amber, RC.amberTint),
      ChipKind.red => (RC.red, RC.redTint),
      ChipKind.grey => (RC.grey, const Color(0xFFEFF1F6)),
      ChipKind.blue => (RC.blue, RC.tint),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: fg.withValues(alpha: 0.18))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4)
        ] else ...[
          Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
          const SizedBox(width: 6)
        ],
        Text(label,
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w800, color: fg)),
      ]),
    );
  }
}

enum ChipKind { blue, green, amber, red, grey }

/// Job status in plain words, with its colour.
({String label, ChipKind kind}) jobStatus(String s, {bool pickup = false}) =>
    switch (s) {
      'ACCEPTED' => (
          label: pickup ? 'Pick up phone' : 'Phone coming',
          kind: ChipKind.blue
        ),
      'INSPECTION' => (label: 'Checking phone', kind: ChipKind.blue),
      'ESTIMATE_SENT' => (label: 'Waiting for customer', kind: ChipKind.amber),
      'ESTIMATE_APPROVED' => (label: 'Ready to repair', kind: ChipKind.blue),
      'IN_REPAIR' => (label: 'Repairing', kind: ChipKind.blue),
      'QC_PENDING' => (label: 'Final check', kind: ChipKind.amber),
      'REPAIRED' || 'READY_FOR_DELIVERY' => (
          label: 'Ready',
          kind: ChipKind.green
        ),
      'COMPLETED' => (label: 'Completed', kind: ChipKind.green),
      'CANCELLED' || 'REJECTED' => (label: 'Cancelled', kind: ChipKind.red),
      'FAILED' => (label: 'Could not repair', kind: ChipKind.red),
      _ => (label: s, kind: ChipKind.grey),
    };

/// Phone picture from the shared device catalogue, or a clear phone icon.
class DeviceThumb extends ConsumerWidget {
  const DeviceThumb(
      {super.key, required this.brand, required this.model, this.size = 56});
  final String brand;
  final String model;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          color: RC.canvas,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: RC.line)),
      child: Icon(PhosphorIconsFill.deviceMobile,
          size: size * 0.5, color: RC.blue),
    );
    if (brand.isEmpty) return holder;
    final url = ref.watch(deviceImageProvider((brand: brand, model: model)));
    return url.maybeWhen(
      data: (u) => u == null || u.isEmpty
          ? holder
          : ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: size,
                height: size,
                color: RC.canvas,
                padding: const EdgeInsets.all(4),
                child: CachedNetworkImage(
                  imageUrl: absoluteUrl(u),
                  fit: BoxFit.contain,
                  placeholder: (_, __) => holder,
                  errorWidget: (_, __, ___) => holder,
                ),
              ),
            ),
      orElse: () => holder,
    );
  }
}

/// Initials circle — customers have no profile photo in our data, so no fake faces.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar(this.name, {super.key, this.size = 44});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    final t = parts.isEmpty
        ? '?'
        : (parts.first[0] + (parts.length > 1 ? parts.last[0] : ''))
            .toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: RC.tint, shape: BoxShape.circle),
      child: Text(t,
          style: TextStyle(
              fontSize: size * 0.36,
              fontWeight: FontWeight.w800,
              color: RC.blue)),
    );
  }
}

/// Section card: glossy icon tile + heading, soft shadow and a blue accent edge.
class RepairSection extends StatelessWidget {
  const RepairSection(
      {super.key,
      required this.title,
      required this.child,
      this.icon,
      this.art,
      this.trailing});
  final String title;
  final Widget child;
  final IconData? icon;

  /// A 3D picture (see [A3]) shown instead of [icon].
  final String? art;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: RC.line),
            boxShadow: [
              BoxShadow(
                  color: RC.blue.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8))
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              height: 4,
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Color(0xFF3B82F6), RC.blue, Color(0xFF7C5CFF)])),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      if (art != null || icon != null) ...[
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Colors.white, RC.tint]),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: RC.blue.withValues(alpha: 0.14)),
                          ),
                          alignment: Alignment.center,
                          child: art != null
                              ? Image.asset(art!, width: 30, height: 30)
                              : Icon(icon, size: 20, color: RC.blue),
                        ),
                        const SizedBox(width: 10)
                      ],
                      Expanded(child: Text(title, style: heading(size: 16))),
                      if (trailing != null) trailing!,
                    ]),
                    const SizedBox(height: 12),
                    child,
                  ]),
            ),
          ]),
        ),
      );
}

/// Label ↔ value line.
class KV extends StatelessWidget {
  const KV(this.k, this.v, {super.key, this.bold = false, this.color});
  final String k;
  final String v;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              flex: 5,
              child: Text(k,
                  style: const TextStyle(
                      fontSize: 13.5, color: AppColors.textSecondary))),
          const SizedBox(width: 10),
          Expanded(
              flex: 6,
              child: Text(v,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
                      color: color ?? AppColors.navy))),
        ]),
      );
}

String shortDate(DateTime? t) {
  if (t == null) return '—';
  const m = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '${t.day} ${m[t.month - 1]}, $h:${t.minute.toString().padLeft(2, '0')} ${t.hour >= 12 ? 'PM' : 'AM'}';
}

/// "2027-01-18" → "18 Jan 2027".
String isoDay(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  const m = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

String clock(DateTime? t) {
  if (t == null) return '';
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour >= 12 ? 'PM' : 'AM'}';
}

/// "same day" · "1 day" · "1–2 days".
String daysLabel(int min, int max) => max == 0
    ? 'same day'
    : (min == max ? '$min day${max == 1 ? '' : 's'}' : '$min–$max days');

String kmLabel(num? km) =>
    km == null ? '' : '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';

Future<void> callPhone(BuildContext context, String phone) async {
  final ok =
      phone.isNotEmpty && await launchUrl(Uri(scheme: 'tel', path: phone));
  if (!ok && context.mounted)
    showAppToast(context, 'Could not open the phone app.', error: true);
}

Future<void> openMaps(BuildContext context,
    {num? lat, num? lng, String? query}) async {
  final uri = lat != null && lng != null
      ? Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng')
      : Uri.https('www.google.com', '/maps/search/',
          {'api': '1', 'query': query ?? ''});
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted)
    showAppToast(context, 'Could not open maps.', error: true);
}

/// Camera / gallery picker used for repair photos.
Future<List<String>> pickPhotos(BuildContext context,
    {bool multi = true}) async {
  final src = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(PhosphorIconsFill.camera, color: RC.blue),
          title: const Text('Take a photo',
              style: TextStyle(fontWeight: FontWeight.w700)),
          onTap: () => Navigator.pop(c, ImageSource.camera),
        ),
        ListTile(
          leading: const Icon(PhosphorIconsFill.images, color: RC.blue),
          title: const Text('Choose from gallery',
              style: TextStyle(fontWeight: FontWeight.w700)),
          onTap: () => Navigator.pop(c, ImageSource.gallery),
        ),
        const SizedBox(height: 8),
      ]),
    ),
  );
  if (src == null) return const [];
  final picker = ImagePicker();
  if (src == ImageSource.camera || !multi) {
    final f =
        await picker.pickImage(source: src, imageQuality: 85, maxWidth: 2000);
    return f == null ? const [] : [f.path];
  }
  final fs =
      await picker.pickMultiImage(imageQuality: 85, maxWidth: 2000, limit: 6);
  return [for (final f in fs) f.path];
}

/// The 8-step status strip from the mockup ("Price Accept → … → Completed"), with a tick for finished steps.
class RepairFlowStrip extends StatelessWidget {
  const RepairFlowStrip({super.key, required this.step});

  /// 0 = request … 7 = completed.
  final int step;

  static const _steps = [
    ('Request', PhosphorIconsFill.fileText),
    ('Offer', PhosphorIconsFill.paperPlaneTilt),
    ('Accepted', PhosphorIconsFill.handshake),
    ('Pickup', PhosphorIconsFill.mapPin),
    ('Repair', PhosphorIconsFill.wrench),
    ('Ready', PhosphorIconsFill.package),
    ('Payment', PhosphorIconsFill.money),
    ('Done', PhosphorIconsFill.checkCircle),
  ];

  @override
  Widget build(BuildContext context) => Row(children: [
        for (final (i, st) in _steps.indexed)
          Expanded(
            child: Column(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: i < step
                      ? RC.green
                      : (i == step ? RC.blue : const Color(0xFFEFF1F6)),
                  shape: BoxShape.circle,
                ),
                child: Icon(i < step ? PhosphorIconsBold.check : st.$2,
                    size: 16,
                    color: i <= step ? Colors.white : AppColors.textMuted),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(st.$1,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            i == step ? FontWeight.w800 : FontWeight.w600,
                        color:
                            i <= step ? AppColors.navy : AppColors.textMuted)),
              ),
            ]),
          ),
      ]);
}

/// Index into [RepairFlowStrip] for a job status.
int flowStep(RepairJob j) => switch (j.status) {
      'ACCEPTED' => j.isPickup ? 3 : 2,
      'INSPECTION' => 3,
      'ESTIMATE_APPROVED' || 'IN_REPAIR' || 'QC_PENDING' => 4,
      'REPAIRED' || 'READY_FOR_DELIVERY' => j.amountDue > 0 ? 6 : 5,
      'COMPLETED' => 7,
      _ => 2,
    };

/// Network photo from a signed relative URL.
class EvidenceImage extends StatelessWidget {
  const EvidenceImage(this.url, {super.key, this.size = 76, this.onTap});
  final String url;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap ??
            () => showDialog<void>(
                  context: context,
                  builder: (c) => Dialog(
                      backgroundColor: Colors.black,
                      insetPadding: const EdgeInsets.all(12),
                      child: InteractiveViewer(
                          child: CachedNetworkImage(
                              imageUrl: absoluteUrl(url),
                              fit: BoxFit.contain))),
                ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: absoluteUrl(url),
            width: size,
            height: size,
            fit: BoxFit.cover,
            placeholder: (_, __) =>
                Container(width: size, height: size, color: RC.canvas),
            errorWidget: (_, __, ___) => Container(
                width: size,
                height: size,
                color: RC.canvas,
                child: const Icon(PhosphorIconsRegular.image,
                    color: AppColors.textMuted)),
          ),
        ),
      );
}

/// Warm paragraph used for empty states and short guidance.
class HintBox extends StatelessWidget {
  const HintBox(this.text,
      {super.key,
      this.icon = PhosphorIconsFill.info,
      this.kind = ChipKind.blue});
  final String text;
  final IconData icon;
  final ChipKind kind;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (kind) {
      ChipKind.green => (RC.green, RC.greenTint),
      ChipKind.amber => (RC.amber, RC.amberTint),
      ChipKind.red => (RC.red, RC.redTint),
      _ => (RC.blue, RC.tint),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: fg.withValues(alpha: 0.16))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          child: Icon(icon, size: 14, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: fg,
                    fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

/// "DEALKR Vendor App" wordmark (blue D tile + name) with an optional bell — the header of the mockups.
class DealkrHeader extends StatelessWidget {
  const DealkrHeader({super.key, this.bellCount = 0, this.onBell, this.onBack});
  final int bellCount;
  final VoidCallback? onBell;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.white,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
            child: Row(children: [
              if (onBack != null)
                IconButton(
                    onPressed: onBack,
                    icon: const Icon(PhosphorIconsRegular.arrowLeft,
                        color: AppColors.navy))
              else
                const SizedBox(width: 8),
              // Same logo mark as the Home header, with the wordmark as live text
              // (the old wordmark PNG had a solid black background).
              const DmLogo(size: 38),
              const SizedBox(width: 8),
              Text('Dealkr',
                  style: heading(
                      size: 20, color: AppColors.navy, w: FontWeight.w800)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                    color: RC.tint, borderRadius: BorderRadius.circular(12)),
                child: const Text('VENDOR',
                    style: TextStyle(
                        fontSize: 10.5,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w800,
                        color: RC.blue)),
              ),
              const Spacer(),
              if (onBell != null)
                GestureDetector(
                  onTap: onBell,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Stack(alignment: Alignment.center, children: [
                      const Icon(PhosphorIconsRegular.bell,
                          size: 26, color: AppColors.navy),
                      if (bellCount > 0)
                        Positioned(
                          right: 5,
                          top: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                                color: RC.red,
                                borderRadius: BorderRadius.circular(10)),
                            child: Text('$bellCount',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ),
                    ]),
                  ),
                ),
            ]),
          ),
        ),
      );
}

enum RepairTab { home, requests, products, market, wallet }

/// The repair partner's bottom tabs: Home · Repair Requests · My Product · Marketplace · Wallet.
class RepairBottomNav extends StatelessWidget {
  const RepairBottomNav({super.key, this.current = RepairTab.requests});
  final RepairTab current;

  @override
  Widget build(BuildContext context) {
    const tabs = [
      (
        RepairTab.home,
        PhosphorIconsRegular.house,
        PhosphorIconsFill.house,
        'Home',
        Routes.home
      ),
      (
        RepairTab.requests,
        PhosphorIconsRegular.wrench,
        PhosphorIconsFill.wrench,
        'Repair Requests',
        Routes.repairs
      ),
      (
        RepairTab.products,
        PhosphorIconsRegular.cube,
        PhosphorIconsFill.cube,
        'My Product',
        Routes.products
      ),
      (
        RepairTab.market,
        PhosphorIconsRegular.storefront,
        PhosphorIconsFill.storefront,
        'Marketplace',
        Routes.wholesale
      ),
      (
        RepairTab.wallet,
        PhosphorIconsRegular.wallet,
        PhosphorIconsFill.wallet,
        'Wallet',
        Routes.wallet
      ),
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.cardBorder)),
        boxShadow: [
          BoxShadow(
              color: AppColors.navy.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, -4))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
          child: Row(children: [
            for (final (t, off, on, label, route) in tabs)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => t == current ? null : context.go(route),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(t == current ? on : off,
                        size: 25,
                        color:
                            t == current ? RC.blue : AppColors.textSecondary),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(label,
                          maxLines: 1,
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: t == current
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: t == current
                                  ? RC.blue
                                  : AppColors.textSecondary)),
                    ),
                    const SizedBox(height: 3),
                    Container(
                        width: 34,
                        height: 2.5,
                        color: t == current ? RC.blue : Colors.transparent),
                  ]),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// Small street map with the customer's pin (OpenStreetMap tiles), like the Location screen of the mockup.
class CustomerMap extends StatelessWidget {
  const CustomerMap(
      {super.key, required this.lat, required this.lng, this.height = 170});
  final num lat;
  final num lng;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = LatLng(lat.toDouble(), lng.toDouble());
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          options: MapOptions(
              initialCenter: c,
              initialZoom: 15,
              interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom)),
          children: [
            TileLayer(
                urlTemplate: OlaMaps.tileUrl,
                userAgentPackageName: 'com.dealker.vendor'),
            MarkerLayer(markers: [
              Marker(
                  point: c,
                  width: 44,
                  height: 44,
                  child: const Icon(PhosphorIconsFill.mapPin,
                      color: RC.red, size: 40)),
            ]),
          ],
        ),
      ),
    );
  }
}

/// Download an invoice PDF with the vendor's session and open it in the phone's viewer.
Future<void> openPdf(BuildContext context, Future<List<int>> Function() fetch,
    String name) async {
  try {
    final bytes = await fetch();
    if (bytes.isEmpty) throw StateError('empty');
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$name.pdf');
    await f.writeAsBytes(bytes, flush: true);
    final r = await OpenFile.open(f.path);
    if (r.type != ResultType.done && context.mounted)
      showAppToast(context, 'Could not open the invoice.', error: true);
  } catch (_) {
    if (context.mounted)
      showAppToast(context, 'Could not load the invoice.', error: true);
  }
}

/// Gradient app bar for every repair screen: back button, title, subtitle, optional 3D art on the right.
class RepairAppBar extends StatelessWidget implements PreferredSizeWidget {
  const RepairAppBar(
      {super.key,
      required this.title,
      this.subtitle,
      this.onBack,
      this.actions,
      this.art});
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final String? art;

  @override
  Size get preferredSize => const Size.fromHeight(78);

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0B2E7A), RC.blue, Color(0xFF3B82F6)]),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
          boxShadow: [
            BoxShadow(
                color: Color(0x401558E8), blurRadius: 16, offset: Offset(0, 6))
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 78,
            child: Row(children: [
              const SizedBox(width: 6),
              IconButton(
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.18)),
                icon: const Icon(PhosphorIconsBold.arrowLeft,
                    color: Colors.white, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: heading(size: 19, color: Colors.white)),
                      if (subtitle != null)
                        Text(subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12.5,
                                color: Colors.white.withValues(alpha: 0.82))),
                    ]),
              ),
              ...?actions,
              if (art != null)
                Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Art3D(art!, size: 60, float: true)),
              const SizedBox(width: 6),
            ]),
          ),
        ),
      );
}
