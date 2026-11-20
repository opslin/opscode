/// A vendor shop as listed by `GET /discovery/shops` (Home "Shops" section,
/// All-shops page). Plain class: the API returns exactly these fields.
class ShopSummary {
  const ShopSummary({
    required this.id,
    required this.name,
    required this.vendorName,
    required this.city,
    required this.rating,
    required this.ratingCount,
    required this.productCount,
    required this.followerCount,
    required this.isFollowing,
    required this.isVerified,
    this.logoUrl,
    this.bannerUrl,
    this.distanceKm,
    this.distanceMinutes,
    this.addressLine,
  });

  factory ShopSummary.fromJson(Map<String, dynamic> j) => ShopSummary(
        id: '${j['id']}',
        name: '${j['name'] ?? ''}'.trim(),
        vendorName: '${j['vendor_name'] ?? ''}'.trim(),
        city: '${j['city'] ?? ''}'.trim(),
        rating: (j['rating'] as num?)?.toDouble() ?? 0,
        ratingCount: (j['rating_count'] as num?)?.toInt() ?? 0,
        productCount: (j['product_count'] as num?)?.toInt() ?? 0,
        followerCount: (j['follower_count'] as num?)?.toInt() ?? 0,
        isFollowing: j['is_following'] == true,
        isVerified: j['is_verified'] == true,
        logoUrl: _nonEmpty(j['logo_url']),
        bannerUrl: _nonEmpty(j['banner_url']),
        distanceKm: (j['distance_km'] as num?)?.toDouble(),
        distanceMinutes: (j['distance_minutes'] as num?)?.toInt(),
        addressLine: _nonEmpty(j['address_line1']),
      );

  final String id;
  final String name;
  final String vendorName;
  final String city;
  final double rating;
  final int ratingCount;
  final int productCount;
  final int followerCount;
  final bool isFollowing;
  final bool isVerified;
  final String? logoUrl;
  final String? bannerUrl;
  final double? distanceKm;
  final int? distanceMinutes;
  final String? addressLine;

  static String? _nonEmpty(Object? v) {
    final String s = '${v ?? ''}'.trim();
    return s.isEmpty || s == 'null' ? null : s;
  }
}

/// 1.2k / 980 style count for reviews and followers.
String compactCount(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) {
    final String v = (n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1);
    return '${v.endsWith('.0') ? v.substring(0, v.length - 2) : v}k';
  }
  return '$n';
}

/// A category chip on a shop profile ("Mobiles 46").
class ShopCategory {
  const ShopCategory({
    required this.id,
    required this.name,
    required this.count,
    this.imageUrl,
  });

  factory ShopCategory.fromJson(Map<String, dynamic> j) => ShopCategory(
        id: '${j['id']}',
        name: '${j['name'] ?? ''}',
        count: (j['count'] as num?)?.toInt() ?? 0,
        imageUrl: ShopSummary._nonEmpty(j['image_url']),
      );

  final String id;
  final String name;
  final int count;
  final String? imageUrl;
}

/// `GET /discovery/shops/:id` — the summary plus what the profile page shows.
class ShopProfile {
  const ShopProfile({
    required this.summary,
    required this.address,
    required this.dealCount,
    required this.categories,
    this.description,
    this.memberSince,
  });

  factory ShopProfile.fromJson(Map<String, dynamic> j) {
    final String line = <String>[
      '${j['address_line1'] ?? ''}',
      '${j['address_line2'] ?? ''}',
      '${j['city'] ?? ''}',
      '${j['state'] ?? ''}',
      '${j['pincode'] ?? ''}',
    ]
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty && e != 'null')
        .join(', ');
    return ShopProfile(
      summary: ShopSummary.fromJson(j),
      address: line,
      dealCount: (j['deal_count'] as num?)?.toInt() ?? 0,
      description: ShopSummary._nonEmpty(j['description']),
      memberSince: DateTime.tryParse('${j['created_at']}')?.year,
      categories: <ShopCategory>[
        for (final dynamic c in (j['categories'] as List? ?? const <dynamic>[]))
          if (c is Map) ShopCategory.fromJson(Map<String, dynamic>.from(c)),
      ],
    );
  }

  final ShopSummary summary;
  final String address;
  final int dealCount;
  final String? description;
  final int? memberSince;
  final List<ShopCategory> categories;
}
