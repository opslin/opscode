import 'package:bakaloo_flutter_app/demo/storefront.dart';
import 'package:flutter/material.dart';

class CategoryArtwork extends StatelessWidget {
  const CategoryArtwork({super.key, required this.category});

  final DemoCategory category;

  @override
  Widget build(BuildContext context) {
    final file = switch (category.id) {
      'produce' => 'category-0.webp',
      'dairy' => 'category-1.webp',
      'pantry' => 'category-2.webp',
      'snacks' => 'category-3.webp',
      _ => null,
    };
    if (file == null) {
      return const ExcludeSemantics(
        child: Icon(Icons.shopping_basket_outlined, color: Color(0xFF702EA3)),
      );
    }
    return Image.asset(
      'assets/commerce/$file',
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      cacheWidth: 128,
    );
  }
}
