import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:dealker_app/shared/widgets/web_service_frame.dart';

/// Design tokens of the return flow (`docs/design/02-return-flow.jpg`): yellow canvas, white sheet, indigo actions.
class ReturnColors {
  ReturnColors._();

  static const Color canvas = Color(0xFFF7DC4E);
  static const Color indigo = Color(0xFF001F5F);
  static const Color indigoSoft = Color(0xFFE8EEFB);
  static const Color indigoLine = Color(0xFFC9D6F2);
  static const Color ink = Color(0xFF0A1B4D);
  static const Color muted = Color(0xFF5A6A8E);
  static const Color line = Color(0xFFE4E6F2);
  static const Color green = Color(0xFF1FA463);
  static const Color greenSoft = Color(0xFFE8F7EF);
  static const Color amber = Color(0xFFF5A623);
  static const Color red = Color(0xFFE5484D);
  static const Color redSoft = Color(0xFFFDECEC);
}

String returnDate(DateTime? d) =>
    d == null ? '' : DateFormat('dd MMM yyyy, hh:mm a').format(d.toLocal());

/// Yellow canvas + app bar + rounded white sheet — the frame every return screen sits in.
class ReturnScaffold extends StatelessWidget {
  const ReturnScaffold({
    required this.title,
    required this.child,
    this.onBack,
    this.bottom,
    this.actions,
    super.key,
  });

  final String title;
  final Widget child;
  final VoidCallback? onBack;
  final Widget? bottom;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ReturnColors.canvas,
      body: WebServiceFrame(
          panelColor: ReturnColors.canvas,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.fromLTRB(4.w, 6.h, 8.w, 6.h),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: ReturnColors.ink,
                        ),
                        onPressed:
                            onBack ?? () => Navigator.of(context).maybePop(),
                      ),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w700,
                            color: ReturnColors.ink,
                          ),
                        ),
                      ),
                      ...?actions,
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24.r)),
                    ),
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24.r)),
                      child: child,
                    ),
                  ),
                ),
                if (bottom != null)
                  Container(
                    color: Colors.white,
                    padding: EdgeInsets.fromLTRB(
                      16.w,
                      8.h,
                      16.w,
                      MediaQuery.of(context).padding.bottom + 12.h,
                    ),
                    child: bottom,
                  ),
              ],
            ),
          )),
    );
  }
}

/// Numbered step dots joined by a line. `done` shows a green tick (tracking), otherwise the number.
class ReturnStepper extends StatelessWidget {
  const ReturnStepper({
    required this.labels,
    required this.current,
    this.allDoneUpTo = -1,
    this.useTicks = false,
    super.key,
  });

  final List<String> labels;

  /// Index of the highlighted step.
  final int current;

  /// Steps with index <= this are finished.
  final int allDoneUpTo;

  /// Tracking style: finished steps show a green tick instead of the step number.
  final bool useTicks;

  @override
  Widget build(BuildContext context) {
    final double dot = 26.w;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List<Widget>.generate(labels.length * 2 - 1, (int i) {
        if (i.isOdd) {
          final int left = i ~/ 2;
          final bool filled = useTicks ? left < allDoneUpTo : left < current;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: dot / 2 - 1),
              child: Container(
                height: 2,
                color: filled
                    ? (useTicks ? ReturnColors.green : ReturnColors.indigo)
                    : ReturnColors.line,
              ),
            ),
          );
        }
        final int idx = i ~/ 2;
        final bool done = useTicks ? idx <= allDoneUpTo : idx < current;
        final bool active = idx == current && !(useTicks && done);
        final Color fill = useTicks
            ? (done
                ? ReturnColors.green
                : active
                    ? ReturnColors.amber
                    : Colors.white)
            : (active ? ReturnColors.indigo : Colors.white);
        final bool hollow = fill == Colors.white;
        return SizedBox(
          width: 66.w,
          child: Column(
            children: <Widget>[
              Container(
                width: dot,
                height: dot,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fill,
                  border: Border.all(
                    color: hollow
                        ? (!useTicks && done
                            ? ReturnColors.indigoLine
                            : ReturnColors.line)
                        : fill,
                    width: 1.5,
                  ),
                  boxShadow: !useTicks && active
                      ? <BoxShadow>[
                          BoxShadow(
                            color: ReturnColors.indigo.withValues(alpha: 0.25),
                            blurRadius: 0,
                            spreadRadius: 3,
                          ),
                        ]
                      : null,
                ),
                child: useTicks
                    ? (done
                        ? Icon(
                            Icons.check_rounded,
                            size: 16.sp,
                            color: Colors.white,
                          )
                        : active
                            ? Icon(
                                Icons.circle,
                                size: 8.sp,
                                color: Colors.white,
                              )
                            : null)
                    : Text(
                        '${idx + 1}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: active
                              ? Colors.white
                              : done
                                  ? ReturnColors.indigo
                                  : ReturnColors.muted,
                        ),
                      ),
              ),
              SizedBox(height: 5.h),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  labels[idx],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9.5.sp,
                    height: 1.15,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: useTicks
                        ? (active || done
                            ? ReturnColors.ink
                            : ReturnColors.muted)
                        : (active || done
                            ? ReturnColors.indigo
                            : ReturnColors.muted),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class ReturnPrimaryButton extends StatelessWidget {
  const ReturnPrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.outlined = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final Widget content = busy
        ? SizedBox(
            width: 20.h,
            height: 20.h,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: outlined ? ReturnColors.indigo : Colors.white,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
              ),
              if (icon != null) ...<Widget>[
                SizedBox(width: 6.w),
                Icon(icon, size: 18.sp),
              ],
            ],
          );
    final RoundedRectangleBorder shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r));
    return SizedBox(
      width: double.infinity,
      height: 48.h,
      child: outlined
          ? OutlinedButton(
              onPressed: busy ? null : onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: ReturnColors.indigo,
                side: const BorderSide(color: ReturnColors.indigo, width: 1.2),
                shape: shape,
              ),
              child: content,
            )
          : ElevatedButton(
              onPressed: busy ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: ReturnColors.indigo,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    ReturnColors.indigo.withValues(alpha: 0.45),
                disabledForegroundColor: Colors.white,
                elevation: 0,
                shape: shape,
              ),
              child: content,
            ),
    );
  }
}

/// Soft lavender note with a leading icon ("Make sure your images…").
class ReturnNote extends StatelessWidget {
  const ReturnNote({
    required this.icon,
    required this.text,
    this.color = ReturnColors.indigo,
    this.background = ReturnColors.indigoSoft,
    super.key,
  });

  final IconData icon;
  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18.sp, color: color),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.sp,
                height: 1.4,
                color: ReturnColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bordered white card used for each block inside the sheet.
class ReturnCard extends StatelessWidget {
  const ReturnCard({required this.child, this.padding, this.color, super.key});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: ReturnColors.line),
      ),
      child: child,
    );
  }
}

/// The reasons offered on step 1: server code, title, one-line hint.
class ReturnReason {
  const ReturnReason(this.code, this.title, this.hint);

  final String code;
  final String title;
  final String hint;

  static const List<ReturnReason> all = <ReturnReason>[
    ReturnReason(
      'PRODUCT_NOT_WORKING',
      'Product Not Working',
      'Device not turning on / not working properly',
    ),
    ReturnReason(
      'SCREEN_DISPLAY',
      'Screen / Display Issue',
      'Cracked, dead pixels, display problem',
    ),
    ReturnReason(
      'BATTERY',
      'Battery Issue',
      'Battery drains fast / not charging',
    ),
    ReturnReason('CAMERA', 'Camera Issue', 'Camera not working / blurry'),
    ReturnReason(
      'WRONG_PRODUCT',
      'Wrong Product',
      'Received different product',
    ),
    ReturnReason(
      'DEFECTIVE_DAMAGED',
      'Defective / Damaged',
      'Physical damage or manufacturing defect',
    ),
    ReturnReason('OTHER', 'Other Reason', 'Please specify'),
  ];

  static ReturnReason? byCode(String? code) {
    for (final ReturnReason r in all) {
      if (r.code == code) return r;
    }
    return null;
  }
}
