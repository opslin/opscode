String _s(dynamic v) => (v ?? '').toString().trim();

class KycDocument {
  const KycDocument(
      {this.id = '',
      required this.type,
      required this.status,
      this.number,
      this.reason,
      this.viewable = false});
  factory KycDocument.fromJson(Map<String, dynamic> j) => KycDocument(
        id: _s(j['id']),
        viewable: RegExp(r'^[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|png|webp|pdf)$')
            .hasMatch(_s(j['file_key'])),
        type: _s(j['document_type']),
        number:
            _s(j['document_number']).isEmpty ? null : _s(j['document_number']),
        status: _s(j['status']).toUpperCase(),
        reason: _s(j['rejection_reason']).isEmpty
            ? null
            : _s(j['rejection_reason']),
      );

  final String id;

  /// Stored privately by us (uploaded from the app), so a signed link can be minted. Older/demo documents are not.
  final bool viewable;
  final String type;
  final String? number;
  final String status; // PENDING | VERIFIED | REJECTED
  final String? reason;

  /// Documents every vendor must have on file before KYC can be reviewed.
  static const required = ['PAN_CARD', 'GSTIN_CERTIFICATE'];
  static const optional = [
    'TRADE_LICENSE',
    'FSSAI_LICENSE',
    'BANK_CANCELLED_CHEQUE'
  ];

  static String labelOf(String type) =>
      KycDocument(type: type, status: '').label;

  String get label => switch (type) {
        'GSTIN_CERTIFICATE' => 'GSTIN certificate',
        'PAN_CARD' => 'PAN card',
        'TRADE_LICENSE' => 'Trade licence',
        'FSSAI_LICENSE' => 'FSSAI licence',
        'BANK_CANCELLED_CHEQUE' => 'Cancelled cheque',
        _ => type.isEmpty
            ? 'Document'
            : type[0] + type.substring(1).toLowerCase().replaceAll('_', ' '),
      };
}

/// The vendor's business details as the server holds them.
class BusinessProfile {
  const BusinessProfile({
    required this.name,
    required this.status,
    this.email = '',
    this.phone = '',
    this.legalName = '',
    this.gstin = '',
    this.pan = '',
    this.tradeLicense = '',
    this.fssai = '',
    this.address1 = '',
    this.address2 = '',
    this.city = '',
    this.state = '',
    this.pincode = '',
    this.latitude,
    this.longitude,
    this.documents = const [],
  });

  factory BusinessProfile.fromJson(
      Map<String, dynamic> vendor, List<KycDocument> docs) {
    final p = (vendor['profile'] as Map?)?.cast<String, dynamic>() ?? const {};
    return BusinessProfile(
      name: _s(vendor['name']),
      status: _s(vendor['status']),
      email: _s(vendor['email']),
      phone: _s(vendor['phone']),
      legalName: _s(p['legal_name']),
      gstin: _s(p['gstin']),
      pan: _s(p['pan_number']),
      tradeLicense: _s(p['trade_license_number']),
      fssai: _s(p['fssai_license']),
      address1: _s(p['address_line1']),
      address2: _s(p['address_line2']),
      city: _s(p['city']),
      state: _s(p['state']),
      pincode: _s(p['pincode']),
      latitude: double.tryParse('${p['latitude'] ?? ''}'),
      longitude: double.tryParse('${p['longitude'] ?? ''}'),
      documents: docs,
    );
  }

  final String name;
  final String status;
  final String email;
  final String phone;
  final String legalName;
  final String gstin;
  final String pan;
  final String tradeLicense;
  final String fssai;
  final String address1;
  final String address2;
  final String city;
  final String state;
  final String pincode;
  final double? latitude;
  final double? longitude;
  bool get hasLocation => latitude != null && longitude != null;
  final List<KycDocument> documents;

  /// Vendors who may still submit (or re-submit) their application for review.
  bool get canSubmit =>
      status == 'PENDING_ONBOARDING' || status == 'CORRECTION_REQUIRED';

  /// Identity details KYC verified can't be changed from the app.
  bool get verified => status == 'VERIFIED' || status == 'ACTIVE';

  String get addressLine => [address1, address2, city, state, pincode]
      .where((e) => e.isNotEmpty)
      .join(', ');
}
