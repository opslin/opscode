/// Maps a category name to one of the bundled 3D icons.
///
/// Names come from the real category list; the artwork is purely decorative
/// and chosen by keyword so every category gets a consistent premium icon.
/// Returns null when nothing matches (the caller falls back to the category's
/// own uploaded image, then to a generic icon).
String? categoryArtFor(String rawName) {
  final String n = rawName.toLowerCase();
  bool has(List<String> keys) => keys.any(n.contains);

  if (has(<String>['headphone', 'earbud', 'earphone', 'neckband', 'audio'])) {
    return 'assets/loading/headphones.png';
  }

  if (has(<String>['accessor', 'storage', 'case', 'cover', 'memory'])) {
    return 'assets/loading/accessories.png';
  }
  if (has(<String>[
    'phone',
    'mobile',
    'iphone',
    'galaxy',
    'oneplus',
    'xiaomi',
    'redmi',
    'realme',
    'vivo',
    'iqoo',
    'android',
    'smartphone',
    'pixel',
    'oppo',
    'motorola',
    'nothing',
  ])) {
    return 'assets/loading/mobile.png';
  }
  if (has(<String>['tablet', 'ipad'])) return 'assets/loading/tablet.png';
  if (has(<String>['watch', 'band', 'wearable'])) {
    return 'assets/loading/smartwatch.png';
  }
  if (has(<String>['speaker', 'soundbar'])) return 'assets/loading/speaker.png';
  if (has(<String>['power bank', 'powerbank', 'charger', 'adapter', 'cable'])) {
    return 'assets/loading/powerbank.png';
  }
  if (has(<String>['laptop', 'computer', 'notebook'])) {
    return 'assets/nav/laptop.png';
  }
  if (has(<String>['television', ' tv', 'tv ', 'smart tv', 'monitor'])) {
    return 'assets/nav/tv.png';
  }
  if (has(<String>['game', 'gaming', 'console'])) return 'assets/nav/gamepad.png';
  if (has(<String>['router', 'network', 'wifi', 'wi-fi'])) {
    return 'assets/nav/router.png';
  }
  if (has(<String>['bulb', 'lighting', 'light'])) return 'assets/nav/bulb.png';
  if (has(<String>['mouse'])) return 'assets/nav/mouse.png';
  if (has(<String>['keyboard'])) return 'assets/nav/keyboard.png';
  if (has(<String>['electronic', 'appliance', 'gadget'])) {
    return 'assets/loading/electronics.png';
  }
  return null;
}
