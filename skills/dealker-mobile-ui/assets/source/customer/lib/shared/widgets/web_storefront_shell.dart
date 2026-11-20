import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:dealker_app/core/theme/app_colors.dart';
import 'package:dealker_app/shared/widgets/wide_storefront_scope.dart';

/// Navigation chrome for a wide browser viewport. The route content keeps its
/// own scrolling and state; the shell only supplies browser navigation.
class WebStorefrontShell extends StatelessWidget {
  const WebStorefrontShell({
    required this.child,
    required this.selectedIndex,
    required this.onSelect,
    required this.onSearch,
    required this.onCart,
    required this.onNavigate,
    super.key,
  });

  final Widget child;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<String> onSearch;
  final VoidCallback onCart;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 1000;
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Column(
        children: [
          Material(
            color: AppColors.accentYellow,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: compact ? 16 : 32, vertical: 12),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => onSelect(0),
                      child: Image.asset(
                        'assets/branding/dealker-logo.png',
                        width: compact ? 120 : 164,
                        height: 52,
                        fit: BoxFit.contain,
                        semanticLabel: 'Dealkr home',
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _SearchBox(onSearch: onSearch),
                    ),
                    const SizedBox(width: 16),
                    IconButton.filledTonal(
                      tooltip: 'Cart',
                      onPressed: onCart,
                      icon: const Icon(Icons.shopping_bag_outlined),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _StorefrontNavigation(
            compact: compact,
            selectedIndex: selectedIndex,
            onSelect: onSelect,
            onNavigate: onNavigate,
          ),
          Expanded(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  ...ScrollConfiguration.of(context).dragDevices,
                  PointerDeviceKind.mouse,
                },
              ),
              child: WideStorefrontScope(child: child),
            ),
          ),
        ],
      ),
    );
  }
}

class _StorefrontNavigation extends StatefulWidget {
  const _StorefrontNavigation({
    required this.compact,
    required this.selectedIndex,
    required this.onSelect,
    required this.onNavigate,
  });

  final bool compact;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<String> onNavigate;

  @override
  State<_StorefrontNavigation> createState() => _StorefrontNavigationState();
}

class _StorefrontNavigationState extends State<_StorefrontNavigation> {
  final ScrollController controller = ScrollController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void scrollBy(double amount) {
    if (!controller.hasClients) return;
    final position = controller.position;
    controller.animateTo(
      (position.pixels + amount).clamp(0.0, position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact;
    final links = <Widget>[
      for (final item in const [
        (0, 'Home'),
        (2, 'Categories'),
        (1, 'Orders'),
        (3, 'Account'),
      ])
        Padding(
          padding: EdgeInsets.only(right: compact ? 2 : 8),
          child: TextButton(
            onPressed: () => widget.onSelect(item.$1),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              padding:
                  compact ? const EdgeInsets.symmetric(horizontal: 4) : null,
              minimumSize: compact ? const Size(0, 48) : null,
            ),
            child: Text(item.$2,
                style: TextStyle(
                  fontWeight: widget.selectedIndex == item.$1
                      ? FontWeight.w800
                      : FontWeight.w500,
                )),
          ),
        ),
      for (final item in const [
        ('Shops', '/shops'),
        ('Auctions', '/auctions'),
        ('Repair', '/repair'),
        ('Sell phone', '/sell'),
      ])
        Padding(
          padding: EdgeInsets.only(right: compact ? 2 : 8),
          child: TextButton(
            onPressed: () => widget.onNavigate(item.$2),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              padding:
                  compact ? const EdgeInsets.symmetric(horizontal: 4) : null,
              minimumSize: compact ? const Size(0, 48) : null,
            ),
            child: Text(item.$1,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ),
    ];
    return Material(
      color: AppColors.bgCard,
      child: Padding(
        padding:
            EdgeInsets.symmetric(horizontal: compact ? 8 : 32, vertical: 6),
        child: compact
            ? Row(children: [
                IconButton(
                  tooltip: 'Scroll navigation left',
                  onPressed: () => scrollBy(-300),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                    child: SingleChildScrollView(
                  controller: controller,
                  scrollDirection: Axis.horizontal,
                  child: Row(children: links),
                )),
                IconButton(
                  tooltip: 'Scroll navigation right',
                  onPressed: () => scrollBy(300),
                  icon: const Icon(Icons.chevron_right),
                ),
              ])
            : Wrap(children: links),
      ),
    );
  }
}

class _SearchBox extends StatefulWidget {
  const _SearchBox({required this.onSearch});
  final ValueChanged<String> onSearch;

  @override
  State<_SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<_SearchBox> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onSubmitted: widget.onSearch,
        decoration: InputDecoration(
          hintText: 'Search products',
          suffixIcon: IconButton(
            tooltip: 'Search',
            onPressed: () => widget.onSearch(controller.text),
            icon: const Icon(Icons.search),
          ),
          filled: true,
          fillColor: AppColors.bgCard,
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      );
}
