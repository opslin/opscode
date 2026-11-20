// Bakaloo's section dispatch and renderer bindings for the local editor.
import 'package:bakaloo_flutter_app/core/theme/section_manifest_model.dart';
import 'package:bakaloo_flutter_app/core/theme/section_manifest_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'custom_banner_section.dart';
import 'spacer_section.dart';
import 'text_header_section.dart';

typedef SectionBuilder = Widget Function(SectionManifestEntry);

final Map<SectionType, SectionBuilder> sectionRegistry = {
  SectionType.textHeader: (entry) => TextHeaderSection(
    text: _readString(entry.config['text']) ?? entry.title ?? 'Section Title',
    fontSize: (_readDouble(entry.config['font_size']) ?? 18).clamp(12, 40),
    color: _readString(entry.config['color']) ?? '#000000',
    alignment: _readString(entry.config['alignment']) ?? 'left',
  ),
  SectionType.spacer: (entry) =>
      SpacerSection(height: (entry.height ?? 16).clamp(0, 160)),
  SectionType.customBanner: (entry) => CustomBannerSection(
    imageUrl: publishedMediaUrl(entry.imageUrl),
    borderRadius: (_readDouble(entry.config['border_radius']) ?? 12).clamp(
      0,
      32,
    ),
    aspectRatio: _parseAspectRatio(entry.config['aspect_ratio']),
  ),
  SectionType.feeStrip: (entry) {
    if (entry.config['visible'] == false) return const SizedBox.shrink();
    final url = publishedMediaUrl(entry.imageUrl);
    final hex = entry.containerColor?.replaceFirst('#', '') ?? '';
    final color = hex.length == 6 ? int.tryParse(hex, radix: 16) : null;
    final fallback = const Center(child: Text('See local delivery offers'));
    return Container(
      color: color == null
          ? const Color(0xFFBFEFFF)
          : Color(0xFF000000 | color),
      width: double.infinity,
      height: 66.h,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      child: url == null
          ? fallback
          : Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  },
};

String? _readString(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

double? _readDouble(Object? value) {
  final number = value is num
      ? value.toDouble()
      : double.tryParse(_readString(value) ?? '');
  return number != null && number.isFinite ? number : null;
}

// Presets in the Bakaloo section library may use ratios like "16:9".
double? _parseAspectRatio(Object? value) {
  final parts = _readString(value)?.split(':');
  if (parts?.length == 2) {
    final width = _readDouble(parts!.first);
    final height = _readDouble(parts.last);
    if (width == null || height == null || height <= 0) return null;
    return (width / height).clamp(0.33, 5.0);
  }
  return _readDouble(value)?.clamp(0.33, 5.0);
}
