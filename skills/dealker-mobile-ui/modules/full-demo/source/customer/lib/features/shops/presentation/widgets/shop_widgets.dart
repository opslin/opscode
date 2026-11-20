import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_app/features/shops/data/shop_summary.dart';
import 'package:dealker_app/features/shops/presentation/providers/shops_provider.dart';
import 'package:dealker_app/shared/widgets/app_image.dart';

const Color kShopBlue = Color(0xFF1D4ED8);
const Color kShopInk = Color(0xFF0F1E4D);
const Color kShopMuted = Color(0xFF6B7280);

const List<List<Color>> _palette = <List<Color>>[
  <Color>[Color(0xFF1D4ED8), Color(0xFF60A5FA)],
  <Color>[Color(0xFF0E9F6E), Color(0xFF6EE7B7)],
  <Color>[Color(0xFFE11D48), Color(0xFFFDA4AF)],
  <Color>[Color(0xFF7C3AED), Color(0xFFC4B5FD)],
  <Color>[Color(0xFFF59E0B), Color(0xFFFDE68A)],
  <Color>[Color(0xFF0891B2), Color(0xFF67E8F9)],
];

/// Stable colour pair per shop (same shop = same colours everywhere).
List<Color> shopColors(ShopSummary s) => _palette[
    s.id.codeUnits.fold<int>(0, (int a, int b) => a + b) % _palette.length];

/// "CityMobiles — Siliguri" reads better as "CityMobiles"; the city is shown separately.
String shopTitle(ShopSummary s) => s.vendorName.isNotEmpty &&
        s.name.toLowerCase().startsWith(s.vendorName.toLowerCase())
    ? s.vendorName
    : s.name;

String shopInitials(String name) {
  final List<String> parts = name
      .replaceAll(RegExp(r'[^A-Za-z0-9 ]'), ' ')
      .split(' ')
      .where((String e) => e.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first
        .substring(0, parts.first.length > 1 ? 2 : 1)
        .toUpperCase();
  }
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

class ShopAvatar extends StatelessWidget {
  const ShopAvatar(
      {required this.shop, this.size = 48, this.ring = 3, super.key});

  final ShopSummary shop;
  final double size;
  final double ring;

  /// One of nine 3D storefronts, picked by a stable hash of the shop id.
  Widget _art() {
    int h = 0;
    for (final int c in shop.id.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return Image.asset(
      'assets/shops/shop${h % 9 + 1}.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
  }

  @override
  Widget build(BuildContext context) {
    // No logo uploaded: show the 3D storefront on its own (no gradient disc,
    // no glow). With a logo: a clean white-ringed circle.
    if (shop.logoUrl == null) {
      return SizedBox(width: size, height: size, child: _art());
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE3E8F3), width: 1.4),
      ),
      clipBehavior: Clip.antiAlias,
      child: AppImage(
        imageUrl: shop.logoUrl!,
        memCacheWidth: 240,
        memCacheHeight: 240,
        fit: BoxFit.cover,
        placeholder: const SizedBox.shrink(),
        errorWidget: _art(),
      ),
    );
  }
}

class VerifiedTick extends StatelessWidget {
  const VerifiedTick({this.size = 16, super.key});

  final double size;

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.verified_rounded, size: size, color: kShopBlue);
}

/// Follow / Following pill (one tap; login-gated for guests).
class ShopFollowButton extends ConsumerWidget {
  const ShopFollowButton({
    required this.shop,
    this.height = 36,
    this.minWidth = 108,
    this.fontSize = 13,
    super.key,
  });

  final ShopSummary shop;
  final double height;
  final double minWidth;
  final double fontSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool following = ref.watch(
      shopFollowProvider
          .select((Map<String, bool> m) => m[shop.id] ?? shop.isFollowing),
    );
    return GestureDetector(
      onTap: () => ref.read(shopFollowProvider.notifier).toggle(context, shop),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: height,
        constraints: BoxConstraints(minWidth: minWidth),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: following ? const Color(0xFFF1F3F8) : Colors.white,
          border: Border.all(
            color: following ? const Color(0xFFF1F3F8) : kShopBlue,
            width: 1.4,
          ),
          borderRadius: BorderRadius.circular(height / 2),
        ),
        child: Text(
          following ? 'Following' : 'Follow',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: following ? kShopMuted : kShopBlue,
          ),
        ),
      ),
    );
  }
}
