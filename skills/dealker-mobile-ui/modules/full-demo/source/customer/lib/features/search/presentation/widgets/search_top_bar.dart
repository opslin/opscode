import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_app/core/theme/search_tokens.dart';

/// Back arrow + search field (+ cart with badge on the results page).
///
///   [←]  [🔍  iphone 15                  ✕ / 🎤]  [🛒³]
class SearchTopBar extends StatelessWidget {
  const SearchTopBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onBack,
    required this.onClear,
    required this.onMic,
    required this.listening,
    this.onTap,
    this.cartCount,
    this.onCart,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onBack;
  final VoidCallback onClear;
  final VoidCallback onMic;
  final bool listening;

  /// Tapping the field (e.g. to edit the query from the results page).
  final VoidCallback? onTap;

  /// null = no cart button (entry / suggestions); a number shows the badge.
  final int? cartCount;
  final VoidCallback? onCart;

  @override
  Widget build(BuildContext context) {
    final bool hasText = controller.text.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 14, 8),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: onBack,
            tooltip: 'Back',
            icon: const PhosphorIcon(
              PhosphorIconsRegular.arrowLeft,
              size: 24,
              color: SearchTokens.ink,
            ),
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: focusNode,
              builder: (BuildContext context, Widget? child) {
                return Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: SearchTokens.fieldBg,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: focusNode.hasFocus
                          ? SearchTokens.accent
                          : SearchTokens.fieldBorder,
                      width: 1.5,
                    ),
                  ),
                  child: child,
                );
              },
              child: Row(
                children: <Widget>[
                  const SizedBox(width: 12),
                  const PhosphorIcon(
                    PhosphorIconsRegular.magnifyingGlass,
                    size: 21,
                    color: SearchTokens.ink,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: onChanged,
                      onSubmitted: onSubmitted,
                      onTap: onTap,
                      textInputAction: TextInputAction.search,
                      cursorColor: SearchTokens.accent,
                      autocorrect: false,
                      maxLines: 1,
                      inputFormatters: <TextInputFormatter>[
                        LengthLimitingTextInputFormatter(100),
                      ],
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: SearchTokens.ink,
                      ),
                      decoration: const InputDecoration(
                        isCollapsed: true,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'Search for phones, accessories…',
                        hintMaxLines: 1,
                        hintStyle: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14.5,
                          fontWeight: FontWeight.w400,
                          color: SearchTokens.greyLight,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  if (hasText)
                    _FieldButton(
                      icon: PhosphorIconsFill.xCircle,
                      color: SearchTokens.greyLight,
                      semantic: 'Clear search',
                      onTap: onClear,
                    )
                  else
                    _FieldButton(
                      icon: listening
                          ? PhosphorIconsFill.stopCircle
                          : PhosphorIconsRegular.microphone,
                      color: listening
                          ? const Color(0xFFD93025)
                          : SearchTokens.accent,
                      semantic:
                          listening ? 'Stop voice search' : 'Voice search',
                      onTap: onMic,
                    ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
          if (cartCount != null) ...<Widget>[
            const SizedBox(width: 6),
            _CartButton(count: cartCount!, onTap: onCart),
          ],
        ],
      ),
    );
  }
}

class _FieldButton extends StatelessWidget {
  const _FieldButton({
    required this.icon,
    required this.color,
    required this.semantic,
    required this.onTap,
  });

  final PhosphorIconData icon;
  final Color color;
  final String semantic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semantic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 46,
          child: Center(child: PhosphorIcon(icon, size: 22, color: color)),
        ),
      ),
    );
  }
}

class _CartButton extends StatelessWidget {
  const _CartButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Cart, $count items',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 46,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: <Widget>[
              const PhosphorIcon(
                PhosphorIconsRegular.shoppingCart,
                size: 26,
                color: SearchTokens.ink,
              ),
              if (count > 0)
                Positioned(
                  right: -1,
                  top: 1,
                  child: Container(
                    constraints:
                        const BoxConstraints(minWidth: 18, minHeight: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5224F),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
