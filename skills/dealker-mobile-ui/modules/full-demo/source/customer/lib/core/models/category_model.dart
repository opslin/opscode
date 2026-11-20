class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.label,
    required this.iconPath,
  });

  final String id;
  final String label;
  final String iconPath;
}

// Per-store category tabs come from the backend (/theme/tabs); no local fallback.
const Map<String, List<CategoryModel>> storeCategoryMap =
    <String, List<CategoryModel>>{};
