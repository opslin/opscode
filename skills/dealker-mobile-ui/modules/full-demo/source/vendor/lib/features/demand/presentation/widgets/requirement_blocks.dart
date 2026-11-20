import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/demand/data/demand_models.dart';
import 'package:dealker_vendor/features/demand/presentation/widgets/demand_common.dart';

/// Product photo, tags, name and "50 pcs required" — the top of every requirement screen.
class RequirementHeader extends StatelessWidget {
  const RequirementHeader(this.r, {super.key, this.showStatus = false});
  final Requirement r;
  final bool showStatus;

  @override
  Widget build(BuildContext context) => Section(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ProductThumb(r.thumbnail, size: 92, radius: 16),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final t in r.tags) TagChip(t),
                if (showStatus) ReqStatusPill(r.status),
              ]),
              if (r.tags.isNotEmpty || showStatus) const SizedBox(height: 7),
              Text(requirementTitle(r), style: heading(size: 21)),
              const SizedBox(height: 5),
              Text('${pcs(r.quantityNeeded)} required',
                  style: heading(
                      size: 16.5, color: kDemandBlue, w: FontWeight.w800)),
              if (r.quantityAwarded > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                      '${r.quantityAwarded} already awarded · ${r.remaining} still needed',
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.mint)),
                ),
              const SizedBox(height: 4),
              Text(r.number,
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textMuted)),
            ]),
          ),
        ]),
      );
}

/// The buyer's spec sheet: price, battery, display, condition, location, timing.
class RequirementSpecs extends StatelessWidget {
  const RequirementSpecs(this.r, {super.key});
  final Requirement r;

  @override
  Widget build(BuildContext context) {
    final price = priceRange(r);
    final place = r.deliveryCity ?? r.deliveryPincode ?? '—';
    final tiles = <Widget>[
      SpecTile(
          icon: PhosphorIconsRegular.tag,
          label: 'Target price (per pc)',
          value: price ?? 'Open to offers',
          accent: kDemandBlue),
      SpecTile(
          icon: PhosphorIconsRegular.batteryFull,
          label: 'Battery health',
          value: r.minBattery == null ? 'Not specified' : '${r.minBattery}%+'),
      SpecTile(
          icon: PhosphorIconsRegular.deviceMobile,
          label: 'Display',
          value: displayPrefLabel(r.displayPref)),
      SpecTile(
          icon: PhosphorIconsRegular.sealCheck,
          label: 'Condition',
          value: conditionPrefLabel(r.conditionPref)),
      SpecTile(
          icon: PhosphorIconsRegular.mapPin, label: 'Location', value: place),
      SpecTile(
          icon: PhosphorIconsRegular.truck,
          label: 'Handover',
          value: fulfilmentPrefLabel(r.fulfilmentPref)),
      SpecTile(
          icon: PhosphorIconsRegular.clock,
          label: 'Posted',
          value: timeAgo(r.createdAt)),
      SpecTile(
          icon: PhosphorIconsRegular.hourglassMedium,
          label: r.requiredBy != null ? 'Needed by' : 'Offers',
          value: r.requiredBy != null
              ? formatDay(r.requiredBy, year: false)
              : closesIn(r.responseDeadline)
                  .replaceFirst('Closes in ', 'Close in ')),
    ];
    return Section(
      title: 'Requirement details',
      child: Column(children: [
        for (var i = 0; i < tiles.length; i += 2)
          Padding(
            padding: EdgeInsets.only(bottom: i + 2 < tiles.length ? 14 : 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: tiles[i]),
              const SizedBox(width: 10),
              Expanded(
                  child:
                      i + 1 < tiles.length ? tiles[i + 1] : const SizedBox()),
            ]),
          ),
      ]),
    );
  }
}

class RequirementNotes extends StatelessWidget {
  const RequirementNotes(this.r, {super.key});
  final Requirement r;

  @override
  Widget build(BuildContext context) {
    final text = r.description;
    if (text == null || text.trim().isEmpty) return const SizedBox.shrink();
    return Section(
      title: 'Additional notes',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: const Color(0xFFF6F8FE),
            borderRadius: BorderRadius.circular(12)),
        child: Text('“${text.trim()}”',
            style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary)),
      ),
    );
  }
}

class BuyerCard extends StatelessWidget {
  const BuyerCard(this.r, {super.key});
  final Requirement r;

  @override
  Widget build(BuildContext context) => Section(
        child: Row(children: [
          Initials(r.buyerName, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.buyerName.isEmpty ? 'Buyer' : r.buyerName,
                  style: heading(size: 15.5)),
              const SizedBox(height: 2),
              const Row(children: [
                Icon(PhosphorIconsFill.sealCheck,
                    size: 14, color: AppColors.mint),
                SizedBox(width: 4),
                Text('Verified Dealkr vendor',
                    style: TextStyle(
                        fontSize: 12.5, color: AppColors.textSecondary)),
              ]),
            ]),
          ),
          const Icon(PhosphorIconsRegular.shieldCheck,
              color: kDemandBlue, size: 24),
        ]),
      );
}
