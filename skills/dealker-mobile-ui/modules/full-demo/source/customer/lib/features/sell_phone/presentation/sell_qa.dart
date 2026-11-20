import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

import 'package:dealker_app/features/sell_phone/presentation/sell_ui.dart';

/// Picture-led condition questions for the sell flow ("QA"): every question has a 3D image, big
/// tap targets and plain words, so anyone can answer without reading a paragraph.
class QaArt {
  QaArt._();
  static const String likeNew = 'assets/exchange/likenew.png';
  static const String good = 'assets/exchange/good.png';
  static const String worn = 'assets/exchange/worn.png';
  static const String damaged = 'assets/exchange/damaged.png';
  static const String screen = 'assets/repair/screen.png';
  static const String body = 'assets/repair/body.png';
  static const String touch = 'assets/repair/touch.png';
  static const String camera = 'assets/repair/camera.png';
  static const String battery = 'assets/repair/battery.png';
  static const String bill = 'assets/exchange/bill.png';
  static const String box = 'assets/exchange/box.png';
  static const String charger = 'assets/exchange/charger.png';
  static const String photo = 'assets/sell/camera.png';
  static const String phone = 'assets/exchange/phone.png';
}

class QaImage extends StatelessWidget {
  const QaImage(this.asset, {required this.size, super.key});
  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => SizedBox(
          width: size,
          height: size,
          child: Icon(Icons.phone_android_rounded,
              color: ReturnColors.muted, size: size * 0.6),
        ),
      );
}

/// Numbered section header: "1  How does it look?".
class QaSection extends StatelessWidget {
  const QaSection(this.number, this.title, {this.subtitle, super.key});
  final int number;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: 22.h, bottom: 10.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 26.w,
              height: 26.w,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                  color: ReturnColors.indigo, shape: BoxShape.circle),
              child: Text('$number',
                  style: sellBody(13, color: Colors.white, w: FontWeight.w800)),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: sellHead(16)),
                  if (subtitle != null) ...<Widget>[
                    SizedBox(height: 2.h),
                    Text(subtitle!, style: sellBody(12)),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
}

/// Big picture card for the overall grade (Like new / Good / Fair / Damaged).
class QaGradeTile extends StatelessWidget {
  const QaGradeTile({
    required this.asset,
    required this.label,
    required this.sub,
    required this.selected,
    required this.onTap,
    this.tint = ReturnColors.indigo,
    super.key,
  });
  final String asset;
  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;
  final Color tint;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: '$label. $sub',
        child: InkWell(
          borderRadius: BorderRadius.circular(18.r),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.fromLTRB(10.w, 12.h, 10.w, 10.h),
            decoration: BoxDecoration(
              color: selected ? tint.withValues(alpha: 0.09) : Colors.white,
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(
                  color: selected ? tint : ReturnColors.line,
                  width: selected ? 2 : 1),
              boxShadow: selected
                  ? <BoxShadow>[
                      BoxShadow(
                          color: tint.withValues(alpha: 0.18),
                          blurRadius: 14,
                          offset: const Offset(0, 6))
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    QaImage(asset, size: 62.w),
                    if (selected)
                      Positioned(
                        right: -6,
                        top: -4,
                        child: Icon(Icons.check_circle_rounded,
                            size: 20.sp, color: tint),
                      ),
                  ],
                ),
                SizedBox(height: 6.h),
                Text(label,
                    style: sellHead(14.5, color: selected ? tint : ReturnColors.ink)),
                SizedBox(height: 2.h),
                Text(sub,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: sellBody(11.2)),
              ],
            ),
          ),
        ),
      );
}

/// One working-or-not question with its picture: [good] pill vs [bad] pill.
class QaCheckCard extends StatelessWidget {
  const QaCheckCard({
    required this.asset,
    required this.question,
    required this.goodLabel,
    required this.badLabel,
    required this.hasIssue,
    required this.onChanged,
    super.key,
  });
  final String asset;
  final String question;
  final String goodLabel;
  final String badLabel;
  final bool hasIssue;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
              color: hasIssue
                  ? ReturnColors.red.withValues(alpha: 0.45)
                  : ReturnColors.line),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 58.w,
              height: 58.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: hasIssue
                      ? ReturnColors.red.withValues(alpha: 0.08)
                      : kSellCanvas,
                  borderRadius: BorderRadius.circular(16.r)),
              child: QaImage(asset, size: 44.w),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(question, style: sellHead(14)),
                  SizedBox(height: 8.h),
                  Row(
                    children: <Widget>[
                      Expanded(
                          child: _Pill(
                              label: goodLabel,
                              icon: Icons.check_circle_rounded,
                              color: ReturnColors.green,
                              active: !hasIssue,
                              onTap: () => onChanged(false))),
                      SizedBox(width: 8.w),
                      Expanded(
                          child: _Pill(
                              label: badLabel,
                              icon: Icons.error_rounded,
                              color: ReturnColors.red,
                              active: hasIssue,
                              onTap: () => onChanged(true))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.icon,
    required this.color,
    required this.active,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: active,
        child: InkWell(
          borderRadius: BorderRadius.circular(12.r),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 38.h,
            padding: EdgeInsets.symmetric(horizontal: 6.w),
            decoration: BoxDecoration(
              color: active ? color.withValues(alpha: 0.12) : kSellCanvas,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                  color: active ? color : Colors.transparent, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon,
                    size: 15.sp, color: active ? color : ReturnColors.muted),
                SizedBox(width: 4.w),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: sellBody(11.8,
                          color: active ? color : ReturnColors.muted,
                          w: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      );
}

/// A row of picture chips for a single choice (phone age, battery health).
class QaChoiceStrip<T> extends StatelessWidget {
  const QaChoiceStrip({
    required this.options,
    required this.value,
    required this.onChanged,
    this.asset,
    super.key,
  });
  final List<({T value, String label, String sub})> options;
  final T value;
  final ValueChanged<T> onChanged;
  final String? asset;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        children: <Widget>[
          for (final ({T value, String label, String sub}) o in options)
            InkWell(
              borderRadius: BorderRadius.circular(14.r),
              onTap: () => onChanged(o.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: o.value == value ? ReturnColors.indigo : Colors.white,
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                      color: o.value == value
                          ? ReturnColors.indigo
                          : ReturnColors.line,
                      width: 1.3),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(o.label,
                        style: sellBody(13.5,
                            color: o.value == value
                                ? Colors.white
                                : ReturnColors.ink,
                            w: FontWeight.w800)),
                    Text(o.sub,
                        style: sellBody(10.8,
                            color: o.value == value
                                ? Colors.white70
                                : ReturnColors.muted)),
                  ],
                ),
              ),
            ),
        ],
      );
}

/// "What comes with it": tap to include / leave out.
class QaAccessoryTile extends StatelessWidget {
  const QaAccessoryTile({
    required this.asset,
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });
  final String asset;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(16.r),
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 6.w),
          decoration: BoxDecoration(
            color: value ? ReturnColors.green.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
                color: value ? ReturnColors.green : ReturnColors.line,
                width: value ? 1.8 : 1),
          ),
          child: Column(
            children: <Widget>[
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Opacity(
                      opacity: value ? 1 : 0.45,
                      child: QaImage(asset, size: 46.w)),
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Icon(
                      value ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      size: 18.sp,
                      color: value ? ReturnColors.green : ReturnColors.muted,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6.h),
              Text(label,
                  textAlign: TextAlign.center,
                  style: sellBody(12, color: ReturnColors.ink, w: FontWeight.w700)),
              Text(value ? 'Included' : 'Not included',
                  style: sellBody(10.5,
                      color: value ? ReturnColors.green : ReturnColors.muted)),
            ],
          ),
        ),
      );
}

/// Guided photo slot ("Front", "Back", ...) - tap to add, tap the cross to remove.
class QaPhotoSlot extends StatelessWidget {
  const QaPhotoSlot({
    required this.label,
    required this.hint,
    required this.icon,
    required this.file,
    required this.required,
    required this.onTap,
    required this.onRemove,
    super.key,
  });
  final String label;
  final String hint;
  final IconData icon;
  final XFile? file;
  final bool required;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final bool has = file != null;
    return InkWell(
      borderRadius: BorderRadius.circular(16.r),
      onTap: has ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          color: has ? Colors.white : ReturnColors.indigoSoft,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
              color: has ? ReturnColors.green : ReturnColors.indigoLine,
              width: has ? 1.8 : 1.2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (has)
              kIsWeb
                  ? Image.network(file!.path, fit: BoxFit.cover)
                  : Image.file(File(file!.path), fit: BoxFit.cover)
            else
              Padding(
                padding: EdgeInsets.all(8.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(icon, size: 26.sp, color: ReturnColors.indigo),
                    SizedBox(height: 6.h),
                    Text(label,
                        textAlign: TextAlign.center,
                        style: sellBody(12.5,
                            color: ReturnColors.ink, w: FontWeight.w800)),
                    SizedBox(height: 2.h),
                    Text(hint,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: sellBody(10.2)),
                  ],
                ),
              ),
            if (has)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 8.w),
                  color: Colors.black54,
                  child: Text(label,
                      style: sellBody(11.5,
                          color: Colors.white, w: FontWeight.w700)),
                ),
              ),
            if (has)
              Positioned(
                top: 4,
                right: 4,
                child: InkWell(
                  onTap: onRemove,
                  child: Container(
                    decoration: const BoxDecoration(
                        color: Colors.black54, shape: BoxShape.circle),
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded,
                        size: 14.sp, color: Colors.white),
                  ),
                ),
              ),
            if (!has && required)
              Positioned(
                top: 6,
                right: 8,
                child: Text('Required',
                    style: sellBody(9.5,
                        color: ReturnColors.red, w: FontWeight.w800)),
              ),
          ],
        ),
      ),
    );
  }
}

/// A plain labelled text box for typing something that is not in our list.
class QaTypeBox extends StatelessWidget {
  const QaTypeBox({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.prefix,
    this.onChanged,
    this.textCapitalization = TextCapitalization.words,
    super.key,
  });
  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final String? prefix;
  final ValueChanged<String>? onChanged;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixText: prefix,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
        ),
      );
}
