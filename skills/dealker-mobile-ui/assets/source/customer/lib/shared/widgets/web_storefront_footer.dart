import 'package:flutter/material.dart';

import 'package:dealker_app/core/theme/app_colors.dart';
import 'package:dealker_app/routing/route_names.dart';

/// The footer lives in the page scroll, never over the page content.
class WebStorefrontFooter extends StatelessWidget {
  const WebStorefrontFooter({required this.onNavigate, super.key});

  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF17213A),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 56,
                  runSpacing: 28,
                  children: [
                    const SizedBox(
                      width: 240,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dealkr',
                              style: TextStyle(
                                  color: AppColors.bgCard,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800)),
                          SizedBox(height: 8),
                          Text('Mobiles, electronics and more',
                              style: TextStyle(
                                  color: Colors.white70, height: 1.5)),
                        ],
                      ),
                    ),
                    _FooterGroup(
                        title: 'Explore',
                        onNavigate: onNavigate,
                        links: const [
                          ('Home', RouteNames.home),
                          ('Categories', RouteNames.categories),
                          ('Shops', RouteNames.shops),
                          ('Auctions', RouteNames.auctions),
                        ]),
                    _FooterGroup(
                        title: 'Your account',
                        onNavigate: onNavigate,
                        links: const [
                          ('Orders', RouteNames.orders),
                          ('Wishlist', RouteNames.wishlist),
                          ('Cart', RouteNames.cart),
                        ]),
                    _FooterGroup(
                        title: 'Services & help',
                        onNavigate: onNavigate,
                        links: const [
                          ('Repair', '/repair'),
                          ('Sell your phone', '/sell'),
                          ('Returns policy', '/returns/policy'),
                          ('Contact support', RouteNames.supportChat),
                        ]),
                  ],
                ),
                const SizedBox(height: 28),
                const Divider(color: Colors.white24),
                const SizedBox(height: 12),
                Text('© ${DateTime.now().year} Dealkr',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterGroup extends StatelessWidget {
  const _FooterGroup(
      {required this.title, required this.links, required this.onNavigate});
  final String title;
  final List<(String, String)> links;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
            const SizedBox(height: 8),
            for (final link in links)
              TextButton(
                onPressed: () => onNavigate(link.$2),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(link.$1),
              ),
          ],
        ),
      );
}
