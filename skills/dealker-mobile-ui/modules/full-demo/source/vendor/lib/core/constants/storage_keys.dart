class StorageKeys {
  StorageKeys._();

  // Distinct from the customer app's keys so a device running both apps never mixes sessions.
  static const accessToken = 'vendor_access_token';
  static const refreshToken = 'vendor_refresh_token';
  static const userId = 'vendor_user_id';
  static const vendorId = 'vendor_vendor_id';
  static const displayName = 'vendor_display_name';
}
