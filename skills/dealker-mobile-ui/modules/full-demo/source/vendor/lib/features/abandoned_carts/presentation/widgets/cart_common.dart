import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/core/theme/app_theme.dart';
import 'package:dealker_vendor/features/abandoned_carts/data/cart_models.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart';

export 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart'
    show
        AuctionAppBar,
        BottomActionBar,
        EmptyState,
        ErrorState,
        HomeCard,
        ProductThumb,
        SummaryRow,
        errorText,
        formatInr,
        heading,
        timeAgo;
export 'package:dealker_vendor/features/campaigns/presentation/widgets/campaign_common.dart'
    show AdNotice, StatTile, compact, percent;

/// Accent of the abandoned-cart screens (the mockup's violet).
const kCartViolet = AppColors.violet;

/// Violet primary action.
class CartButton extends StatelessWidget {
  const CartButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.outlined = false,
    this.height = 54,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool outlined;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final fg = outlined ? kCartViolet : Colors.white;
    return Opacity(
      opacity: onPressed == null && !loading ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: outlined ? null : AppColors.violetGradient,
            color: outlined ? Colors.white : null,
            borderRadius: BorderRadius.circular(14),
            border:
                outlined ? Border.all(color: kCartViolet, width: 1.4) : null,
            boxShadow: outlined
                ? null
                : [
                    BoxShadow(
                        color: kCartViolet.withValues(alpha: 0.25),
                        blurRadius: 14,
                        offset: const Offset(0, 6))
                  ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              height: height,
              child: Center(
                child: loading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: fg))
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        if (icon != null) ...[
                          Icon(icon, size: 19, color: fg),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontFamily: AppTheme.headingFont,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16.5,
                                  color: fg)),
                        ),
                      ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Initials in a soft gradient circle (the mockup's RS / PK / AK avatars).
class CartAvatar extends StatelessWidget {
  const CartAvatar(this.name, {super.key, this.size = 46});
  final String name;
  final double size;

  static const _palettes = [
    [Color(0xFF6D5BEA), Color(0xFF9B7CF4)],
    [Color(0xFFC04FE0), Color(0xFFE97CC8)],
    [Color(0xFF3B6FE0), Color(0xFF5B9DFF)],
    [Color(0xFF0FA67E), Color(0xFF47C9A2)],
    [Color(0xFFE5733A), Color(0xFFF2A65A)],
  ];

  String get _initials {
    final p =
        name.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
    if (p.isEmpty) return '?';
    final a = p.first[0];
    final b = p.length > 1 ? p.last.replaceAll('.', '')[0] : '';
    return (a + b).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final pal = _palettes[name.hashCode.abs() % _palettes.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight, colors: pal),
      ),
      child: Text(_initials,
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: size * 0.34)),
    );
  }
}

/// B2B / B2C tag.
class ChannelChip extends StatelessWidget {
  const ChannelChip(this.channel, {super.key});
  final CartChannel channel;

  @override
  Widget build(BuildContext context) {
    final b2b = channel == CartChannel.b2b;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: b2b ? AppColors.roleB2bBg : AppColors.roleB2cBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(channel.label,
          style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: b2b ? AppColors.roleB2b : AppColors.roleB2c)),
    );
  }
}

/// One line of status under a cart: icon + words, coloured by meaning.
class CartStateLine extends StatelessWidget {
  const CartStateLine(this.row, {super.key});
  final CartRow row;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String text, Color color) = switch (row.state) {
      CartState.ordered => (
          PhosphorIconsFill.checkCircle,
          'Order placed',
          AppColors.mint
        ),
      CartState.backInCart => (
          PhosphorIconsFill.arrowUUpLeft,
          'Back in cart',
          const Color(0xFFB45309)
        ),
      CartState.closed => (
          PhosphorIconsFill.minusCircle,
          'Closed',
          AppColors.textMuted
        ),
      _ when row.myReminders > 0 => (
          PhosphorIconsFill.bellRinging,
          'Reminder sent · ${timeAgo(row.lastReminderAt)}',
          kCartViolet
        ),
      _ => (PhosphorIconsFill.warningCircle, 'Cart abandoned', AppColors.rose),
    };
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 15, color: color),
      const SizedBox(width: 5),
      Flexible(
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
      ),
    ]);
  }
}

/// ↑18% / ↓5% against the previous period. [goodWhenUp] flips the colour meaning
/// (more abandoned carts is not good news; more recovered orders is).
class ChangeBadge extends StatelessWidget {
  const ChangeBadge(this.pct, {super.key, this.goodWhenUp = true});
  final double? pct;
  final bool goodWhenUp;

  @override
  Widget build(BuildContext context) {
    if (pct == null) return const SizedBox(height: 16);
    final up = pct! >= 0;
    final good = up == goodWhenUp;
    final color = pct == 0
        ? AppColors.textMuted
        : (good ? AppColors.mint : AppColors.rose);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(up ? PhosphorIconsBold.arrowUp : PhosphorIconsBold.arrowDown,
          size: 12, color: color),
      const SizedBox(width: 2),
      Text('${pct!.abs().toStringAsFixed(pct!.abs() < 10 ? 1 : 0)}%',
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    ]);
  }
}

String humanIdle(DateTime? t) {
  if (t == null) return '';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'Just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}
