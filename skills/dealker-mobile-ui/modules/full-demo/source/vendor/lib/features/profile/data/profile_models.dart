// Models for the Profile page. Field names follow the real API:
//  GET /vendors/:id            → vendor + `profile` (KYC/address) row
//  GET /subscriptions/me       → { tier, planName, listingLimit, listingsUsed, expiresAt, daysLeft }
//  GET /vendor/listings/stats  → { total, pending, rejected, out_of_stock, … }

num? _n(dynamic v) => v == null ? null : (v is num ? v : num.tryParse('$v'));
int _i(dynamic v) => _n(v)?.toInt() ?? 0;
String _s(dynamic v) => v == null ? '' : '$v';

class VendorProfileInfo {
  const VendorProfileInfo({
    required this.name,
    required this.status,
    required this.profileComplete,
    this.legalName = '',
    this.gstin = '',
    this.addressLine1 = '',
    this.addressLine2 = '',
    this.city = '',
    this.state = '',
    this.pincode = '',
    this.lat,
    this.lng,
  });
  final String name;
  final String status;

  /// Business identity used to bill bulk repairs and to prefill addresses.
  final String legalName;
  final String gstin;
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String state;
  final String pincode;
  final double? lat;
  final double? lng;
  bool get hasBusinessAddress =>
      addressLine1.trim().isNotEmpty && city.trim().isNotEmpty && pincode.trim().length == 6;

  /// Legal name, GSTIN, address line and city all filled in.
  final bool profileComplete;

  bool get verified => status == 'VERIFIED' || status == 'ACTIVE';

  factory VendorProfileInfo.fromJson(Map<String, dynamic> j) {
    final p = (j['profile'] as Map?)?.cast<String, dynamic>() ?? const {};
    bool has(String k) => _s(p[k]).trim().isNotEmpty;
    return VendorProfileInfo(
      name: _s(j['name']),
      status: _s(j['status']),
      profileComplete: has('legal_name') &&
          has('gstin') &&
          has('address_line1') &&
          has('city'),
      legalName: _s(p['legal_name']),
      gstin: _s(p['gstin']).toUpperCase(),
      addressLine1: _s(p['address_line1']),
      addressLine2: _s(p['address_line2']),
      city: _s(p['city']),
      state: _s(p['state']),
      pincode: _s(p['pincode']),
      lat: _n(p['latitude'])?.toDouble(),
      lng: _n(p['longitude'])?.toDouble(),
    );
  }
}

class Membership {
  const Membership({
    required this.tier,
    required this.planName,
    required this.daysLeft,
    this.listingLimit,
    this.listingsUsed,
  });
  final String tier; // FREE | PAID | PREMIUM | UNLIMITED
  final String planName;
  final int? daysLeft;

  /// null limit = unlimited listings.
  final int? listingLimit;
  final int? listingsUsed;

  bool get isFree => tier == 'FREE';

  factory Membership.fromJson(Map<String, dynamic> j) => Membership(
        tier: _s(j['tier']).isEmpty ? 'FREE' : _s(j['tier']),
        planName: _s(j['planName']),
        daysLeft: j['daysLeft'] == null ? null : _i(j['daysLeft']),
        listingLimit: j['listingLimit'] == null ? null : _i(j['listingLimit']),
        listingsUsed: j['listingsUsed'] == null ? null : _i(j['listingsUsed']),
      );
}

class ListingCounts {
  const ListingCounts({required this.live, required this.pending});
  final int live;
  final int pending;

  factory ListingCounts.fromJson(Map<String, dynamic> j) {
    final total = _i(j['total']);
    final pending = _i(j['pending']);
    final rejected = _i(j['rejected']);
    return ListingCounts(
        live: (total - pending - rejected).clamp(0, total), pending: pending);
  }
}
