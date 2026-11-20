import 'package:dealker_vendor/features/repair_book/shims/app_image.dart';
import 'package:flutter/material.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:shimmer/shimmer.dart';

import 'package:dealker_vendor/features/repair_book/repair_tokens.dart';
import 'package:dealker_vendor/features/repair_book/shims/double_extensions.dart';
import 'package:dealker_vendor/features/repair_book/repair_models.dart';
import 'package:dealker_vendor/features/repair_book/repair_providers.dart';
import 'package:dealker_vendor/features/repair_book/shims/web_service_frame.dart';

/// ₹10,499 — whole rupees with Indian grouping; paise only when there are some.
String rupees(num v) => v.toInrCurrency;

TextStyle rtHead(
  double size, {
  Color color = RT.ink,
  FontWeight w = FontWeight.w800,
  double? h,
}) =>
    TextStyle(
      fontFamily: RT.head,
      fontSize: size,
      fontWeight: w,
      color: color,
      height: h,
    );

TextStyle rtBody(
  double size, {
  Color color = RT.grey,
  FontWeight w = FontWeight.w400,
  double? h,
}) =>
    TextStyle(
      fontFamily: RT.body,
      fontSize: size,
      fontWeight: w,
      color: color,
      height: h,
    );

/// Yellow status + app bar, white rounded sheet, optional journey stepper and a
/// pinned bottom bar. Every Repair Mobile screen is built in this shell.
class RepairShell extends StatelessWidget {
  const RepairShell({
    required this.title,
    required this.body,
    this.step,
    this.bottom,
    this.onBack,
    this.showSupport = true,
    this.sheetColor = RT.canvas,
    super.key,
  });

  final String title;
  final Widget body;

  /// Current step of the journey; null hides the stepper.
  final RepairStep? step;
  final Widget? bottom;
  final VoidCallback? onBack;
  final bool showSupport;
  final Color sheetColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RT.yellow,
      resizeToAvoidBottomInset: true,
      body: WebServiceFrame(
          panelColor: RT.yellow,
          child: Column(
            children: <Widget>[
              SafeArea(
                bottom: false,
                child: SizedBox(
                  height: 56,
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: onBack ??
                            () => context.canPop()
                                ? context.pop()
                                : context.go(Routes.home),
                        tooltip: 'Back',
                        icon: const PhosphorIcon(
                          PhosphorIconsBold.arrowLeft,
                          size: 24,
                          color: RT.blue,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: rtHead(20),
                        ),
                      ),
                      if (showSupport) const _SupportPill(),
                      const SizedBox(width: 16),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: sheetColor,
                    border: const Border(
                      top: BorderSide(color: RT.border),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: <Widget>[
                      if (step != null) ...<Widget>[
                        RepairStepper(current: step!),
                        const Divider(
                            height: 1, thickness: 1, color: RT.border),
                      ],
                      Expanded(child: body),
                      if (bottom != null) RepairBottomBar(child: bottom!),
                    ],
                  ),
                ),
              ),
            ],
          )),
    );
  }
}

class _SupportPill extends StatelessWidget {
  const _SupportPill();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Open your request and tap Chat to talk to the service centre.'))),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: RT.tint,
          borderRadius: BorderRadius.circular(19),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const PhosphorIcon(
              PhosphorIconsBold.headset,
              size: 18,
              color: RT.blue,
            ),
            const SizedBox(width: 6),
            Text('Help', style: rtHead(14, color: RT.blue, w: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

/// Request · Shops · Book · Repair · Done. Finished steps carry a tick, the
/// current one a number and a halo.
class RepairStepper extends StatelessWidget {
  const RepairStepper({required this.current, super.key});

  final RepairStep current;

  static const List<String> _labels = <String>[
    'Request',
    'Shops',
    'Book',
    'Repair',
    'Done',
  ];

  @override
  Widget build(BuildContext context) {
    final int cur = current.index;
    return SizedBox(
      height: 58,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          const double side = 10;
          final double colW = (c.maxWidth - side * 2) / 5;
          double cx(int i) => side + colW * (i + 0.5);
          return Stack(
            children: <Widget>[
              // Track and the finished part of it, behind the dots.
              Positioned(
                left: cx(0),
                right: c.maxWidth - cx(4),
                top: 21,
                height: 2,
                child: const ColoredBox(color: RT.border),
              ),
              if (cur > 0)
                Positioned(
                  left: cx(0),
                  right: c.maxWidth - cx(cur),
                  top: 21,
                  height: 2,
                  child: const ColoredBox(color: Color(0xFFBBD0F7)),
                ),
              for (int i = 0; i < 5; i++) ...<Widget>[
                Positioned(
                  left: cx(i) - 14,
                  top: 8,
                  width: 28,
                  height: 28,
                  child: Center(child: _dot(i, cur)),
                ),
                Positioned(
                  left: cx(i) - colW / 2,
                  width: colW,
                  top: 38,
                  child: Text(
                    _labels[i],
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: rtBody(
                      12,
                      color: i <= cur ? RT.indigo : RT.muted,
                      w: i == cur ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _dot(int i, int cur) {
    if (i < cur) {
      return Container(
        width: 24,
        height: 24,
        decoration:
            const BoxDecoration(color: RT.indigo, shape: BoxShape.circle),
        child: const Center(
          child: PhosphorIcon(
            PhosphorIconsBold.check,
            size: 13,
            color: Colors.white,
          ),
        ),
      );
    }
    if (i == cur) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: RT.indigo.withValues(alpha: 0.18),
        ),
        child: Center(
          child: Container(
            width: 22,
            height: 22,
            decoration:
                const BoxDecoration(color: RT.indigo, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('${i + 1}', style: rtHead(12, color: Colors.white)),
          ),
        ),
      );
    }
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: RT.border, width: 1.5),
      ),
    );
  }
}

/// White pinned bar with a soft top shadow that holds the screen's one main action.
class RepairBottomBar extends StatelessWidget {
  const RepairBottomBar({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x14101840),
            blurRadius: 14,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(RT.gutter, 12, RT.gutter, 10),
      child: SafeArea(top: false, child: child),
    );
  }
}

/// Solid indigo (primary) or outlined (secondary) action button.
class RButton extends StatelessWidget {
  const RButton({
    required this.label,
    required this.onTap,
    this.outline = false,
    this.danger = false,
    this.loading = false,
    this.icon,
    this.height,
    this.expand = true,
    this.maxLines = 1,
    super.key,
  });

  final int maxLines;
  final String label;
  final VoidCallback? onTap;
  final bool outline;
  final bool danger;
  final bool loading;
  final PhosphorIconData? icon;
  final double? height;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final bool disabled = onTap == null && !loading;
    final Color accent = danger ? RT.red : RT.indigo;
    final Color bg =
        outline ? Colors.white : (disabled ? const Color(0xFFC9CCE0) : accent);
    final Color fg = outline ? (disabled ? RT.muted : accent) : Colors.white;
    final double h = height ?? (outline ? 46 : RT.buttonHeight);
    return SizedBox(
      width: expand ? double.infinity : null,
      height: h,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(outline ? 12 : RT.buttonRadius),
          side: outline
              ? BorderSide(color: disabled ? RT.border : accent, width: 1.5)
              : BorderSide.none,
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RT.buttonRadius),
          ),
          onTap: loading ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Center(
              child: loading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: fg,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (icon != null) ...<Widget>[
                          PhosphorIcon(icon!, size: 19, color: fg),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: rtHead(
                              outline ? 14.5 : 16,
                              color: fg,
                              w: outline ? FontWeight.w700 : FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Edit", "Change", "See all ›" — small indigo text action.
class RLink extends StatelessWidget {
  const RLink(
    this.label, {
    required this.onTap,
    this.icon,
    this.trailingChevron = false,
    this.color = RT.indigo,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final PhosphorIconData? icon;
  final bool trailingChevron;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              PhosphorIcon(icon!, size: 17, color: color),
              const SizedBox(width: 6),
            ],
            Text(label, style: rtHead(14, color: color, w: FontWeight.w700)),
            if (trailingChevron) ...<Widget>[
              const SizedBox(width: 2),
              PhosphorIcon(
                PhosphorIconsRegular.caretRight,
                size: 14,
                color: color,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// White card, 16 radius, 1 px hairline, minimal shadow.
class RCard extends StatelessWidget {
  const RCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = Colors.white,
    this.borderColor = RT.border,
    this.borderWidth = 1,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final double borderWidth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget box = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(RT.cardRadius),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
    return onTap == null ? box : GestureDetector(onTap: onTap, child: box);
  }
}

/// Section heading with an optional right-hand link.
class RHeading extends StatelessWidget {
  const RHeading(
    this.text, {
    this.action,
    this.onAction,
    this.size = 18,
    super.key,
  });

  final String text;
  final String? action;
  final VoidCallback? onAction;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Text(text, style: rtHead(size))),
        if (action != null && onAction != null)
          RLink(action!, onTap: onAction!, trailingChevron: true),
      ],
    );
  }
}

enum PillKind { live, indigo, green, amber, red, grey }

/// Status pill with a 6 px dot: "In repair", "3 quotes received", "Cancelled".
class RPill extends StatelessWidget {
  const RPill(
    this.label, {
    this.kind = PillKind.indigo,
    this.dot = true,
    super.key,
  });

  final String label;
  final PillKind kind;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color bg) = switch (kind) {
      PillKind.live || PillKind.green => (RT.green, RT.greenTint),
      PillKind.indigo => (RT.indigo, RT.tint),
      PillKind.amber => (RT.amber, RT.amberTint),
      PillKind.red => (RT.red, RT.redTint),
      PillKind.grey => (RT.grey, RT.field),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (dot) ...<Widget>[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: rtHead(12, color: fg, w: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Outlined chip used for issues, services, filters and slots.
class RChip extends StatelessWidget {
  const RChip(
    this.label, {
    this.selected = false,
    this.onTap,
    this.icon,
    this.height = 32,
    this.disabled = false,
    this.compact = false,
    super.key,
  });

  /// Smaller text and padding, for rows of several chips on one line.
  final bool compact;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final PhosphorIconData? icon;
  final double height;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final Color fg = disabled ? RT.muted : (selected ? RT.indigo : RT.ink);
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 13),
        decoration: BoxDecoration(
          color: selected ? RT.tint : (disabled ? RT.field : Colors.white),
          borderRadius: BorderRadius.circular(height / 2),
          border: Border.all(
            color: selected ? RT.indigo.withValues(alpha: 0.55) : RT.border,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              PhosphorIcon(icon!, size: compact ? 14 : 15, color: fg),
              SizedBox(width: compact ? 5 : 6),
            ],
            Text(
              label,
              style: rtHead(
                compact ? 12 : 13,
                color: fg,
                w: selected ? FontWeight.w800 : FontWeight.w600,
              ).copyWith(
                decoration: disabled ? TextDecoration.lineThrough : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum BandKind { info, success, warn, danger }

/// Coloured info band: privacy note, price-changed warning, "phone is ready".
class RBand extends StatelessWidget {
  const RBand(
    this.text, {
    this.kind = BandKind.info,
    this.icon,
    this.bold,
    super.key,
  });

  final String text;
  final BandKind kind;
  final PhosphorIconData? icon;

  /// Optional bold lead-in before [text].
  final String? bold;

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color bg, PhosphorIconData ic) = switch (kind) {
      BandKind.info => (RT.indigo, RT.tint, PhosphorIconsRegular.info),
      BandKind.success => (
          RT.green,
          RT.greenTint,
          PhosphorIconsRegular.lockKey
        ),
      BandKind.warn => (RT.amber, RT.amberTint, PhosphorIconsRegular.warning),
      BandKind.danger => (
          RT.red,
          RT.redTint,
          PhosphorIconsRegular.warningCircle
        ),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PhosphorIcon(icon ?? ic, size: 19, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  if (bold != null)
                    TextSpan(
                      text: '$bold ',
                      style: rtBody(
                        13.5,
                        color: fg,
                        w: FontWeight.w700,
                        h: 1.35,
                      ),
                    ),
                  TextSpan(
                    text: text,
                    style: rtBody(13.5, color: fg, w: FontWeight.w500, h: 1.35),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft indigo circle with an icon, used by states and fulfilment cards.
class RIconTile extends StatelessWidget {
  const RIconTile(
    this.icon, {
    this.size = 44,
    this.iconSize = 22,
    this.circle = false,
    this.color = RT.indigo,
    this.bg = RT.tint,
    super.key,
  });

  final PhosphorIconData icon;
  final double size;
  final double iconSize;
  final bool circle;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(12),
      ),
      child: Center(child: PhosphorIcon(icon, size: iconSize, color: color)),
    );
  }
}

/// Centred state: icon, title, text and up to two actions.
class RStateView extends StatelessWidget {
  const RStateView({
    required this.icon,
    required this.title,
    required this.message,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    super.key,
  });

  final PhosphorIconData icon;
  final String title;
  final String message;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            RIconTile(icon, size: 92, iconSize: 42, circle: true),
            const SizedBox(height: 22),
            Text(title, textAlign: TextAlign.center, style: rtHead(18)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: rtBody(14, h: 1.4),
            ),
            if (primaryLabel != null && onPrimary != null) ...<Widget>[
              const SizedBox(height: 24),
              RButton(
                label: primaryLabel!,
                onTap: onPrimary,
                outline: true,
                expand: false,
                height: 48,
              ),
            ],
            if (secondaryLabel != null && onSecondary != null) ...<Widget>[
              const SizedBox(height: 10),
              RLink(secondaryLabel!, onTap: onSecondary!),
            ],
          ],
        ),
      ),
    );
  }
}

/// Couldn't load / offline, with Retry.
class RErrorView extends StatelessWidget {
  const RErrorView({required this.onRetry, this.offline = false, super.key});

  final VoidCallback onRetry;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    return RStateView(
      icon: offline
          ? PhosphorIconsRegular.wifiSlash
          : PhosphorIconsRegular.warning,
      title: offline ? 'You’re offline' : 'Couldn’t load repairs',
      message: offline
          ? 'Check your internet connection and try again.'
          : 'Your request is safe. Retry.',
      primaryLabel: 'Retry',
      onPrimary: onRetry,
    );
  }
}

/// Shimmering block sized like real content (never a full-screen spinner).
class RSkeleton extends StatelessWidget {
  const RSkeleton({this.width, this.height = 16, this.radius = 8, super.key});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFEBEDF4),
      highlightColor: const Color(0xFFF8F9FC),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// A few card-shaped placeholders for list screens.
class RSkeletonCards extends StatelessWidget {
  const RSkeletonCards({this.count = 3, this.cardHeight = 150, super.key});

  final int count;
  final double cardHeight;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(RT.gutter),
      children: <Widget>[
        for (int i = 0; i < count; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: RT.gap),
            child: RCard(
              child: SizedBox(
                height: cardHeight - 32,
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    RSkeleton(width: 64, height: 64, radius: 12),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          RSkeleton(height: 16),
                          SizedBox(height: 10),
                          RSkeleton(width: 120, height: 12),
                          SizedBox(height: 10),
                          RSkeleton(width: 90, height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Phone thumbnail placeholder (the catalogue has images for models only).
class RPhoneThumb extends StatelessWidget {
  const RPhoneThumb({this.url, this.size = 64, super.key});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: RT.field,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(4),
      child: (url ?? '').isEmpty
          ? PhosphorIcon(
              PhosphorIconsRegular.deviceMobile,
              size: size * 0.5,
              color: RT.muted,
            )
          : Image.network(
              webImageSource(url!),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => PhosphorIcon(
                PhosphorIconsRegular.deviceMobile,
                size: size * 0.5,
                color: RT.muted,
              ),
            ),
    );
  }
}

/// Phone picture for a repair's first device, from the shared device catalogue (falls back to a phone icon).
class RDeviceThumb extends ConsumerWidget {
  const RDeviceThumb(this.device, {this.size = 62, super.key});

  final RepairDevice? device;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RepairDevice? d = device;
    if (d == null || d.brand.isEmpty) return RPhoneThumb(size: size);
    final AsyncValue<List<RepairModel>> models =
        ref.watch(repairModelsProvider(d.brand));
    final String? url = models.maybeWhen(
      data: (List<RepairModel> list) {
        for (final RepairModel m in list) {
          if (m.name.toLowerCase() == d.model.toLowerCase()) return m.imageUrl;
        }
        return null;
      },
      orElse: () => null,
    );
    return RPhoneThumb(url: url, size: size);
  }
}
