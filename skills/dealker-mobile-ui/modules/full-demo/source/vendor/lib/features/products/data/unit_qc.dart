/// QC of ONE physical device (a listing of N used / refurbished / open-box units has N of these).
/// The server validates it, computes the score and renders the report buyers see.
const kLcdOptions = [
  ('WORKING', 'Working fine'),
  ('MINOR_DEFECT', 'Minor defect'),
  ('DEFECTIVE', 'Defective'),
];
const kScreenOptions = [
  ('FLAWLESS', 'Flawless'),
  ('MINOR_SCRATCHES', 'Minor scratches'),
  ('VISIBLE_SCRATCHES', 'Visible scratches'),
  ('CRACKED', 'Cracked'),
];
const kBodyOptions = [
  ('LIKE_NEW', 'Like new'),
  ('GOOD', 'Good'),
  ('FAIR', 'Fair'),
  ('DENTED', 'Dents'),
];
const kFrameOptions = [
  ('STRAIGHT', 'Straight'),
  ('SCUFFED', 'Scuffed'),
  ('BENT', 'Bent'),
];

/// Functional checks, in the order buyers see them.
const kFunctions = [
  ('touch', 'Touch'),
  ('wifi', 'Wi-Fi'),
  ('bluetooth', 'Bluetooth'),
  ('gps', 'GPS'),
  ('cameras', 'Cameras'),
  ('speaker', 'Speaker'),
  ('microphone', 'Microphone'),
  ('biometric', 'Face ID / Fingerprint'),
  ('volume_buttons', 'Volume buttons'),
  ('power_button', 'Power button'),
  ('charging_port', 'Charging port'),
  ('vibrator', 'Vibrator'),
  ('proximity_sensor', 'Proximity sensor'),
  ('sim_tray', 'SIM tray'),
  ('audio_jack', 'Audio jack'),
];

class UnitQc {
  const UnitQc({
    this.battery = 90,
    this.lcd = 'WORKING',
    this.screen = 'FLAWLESS',
    this.body = 'LIKE_NEW',
    this.back = 'LIKE_NEW',
    this.frame = 'STRAIGHT',
    this.functional = const {},
    this.notes = '',
  });

  final int battery;
  final String lcd;
  final String screen;
  final String body;
  final String back;
  final String frame;
  final Map<String, String> functional; // key -> PASS | FAIL | NA
  final String notes;

  /// Everything working and in good shape: the vendor then changes only what is different on this device.
  factory UnitQc.allGood({int battery = 90}) => UnitQc(
        battery: battery,
        functional: {for (final f in kFunctions) f.$1: f.$1 == 'audio_jack' ? 'NA' : 'PASS'},
      );

  UnitQc copyWith({
    int? battery,
    String? lcd,
    String? screen,
    String? body,
    String? back,
    String? frame,
    Map<String, String>? functional,
    String? notes,
  }) =>
      UnitQc(
        battery: battery ?? this.battery,
        lcd: lcd ?? this.lcd,
        screen: screen ?? this.screen,
        body: body ?? this.body,
        back: back ?? this.back,
        frame: frame ?? this.frame,
        functional: functional ?? this.functional,
        notes: notes ?? this.notes,
      );

  int get failedFunctions => functional.values.where((v) => v == 'FAIL').length;

  /// Number of things that are not perfect (shown on the device card).
  int get defects =>
      (lcd != 'WORKING' ? 1 : 0) +
      (screen != 'FLAWLESS' ? 1 : 0) +
      (body != 'LIKE_NEW' ? 1 : 0) +
      (back != 'LIKE_NEW' ? 1 : 0) +
      (frame != 'STRAIGHT' ? 1 : 0) +
      (battery < 80 ? 1 : 0) +
      failedFunctions;

  Map<String, dynamic> toJson() => {
        'battery': {'health': battery},
        'screen': {'lcd': lcd, 'condition': screen},
        'physical': {'body': body, 'back': back, 'frame': frame},
        'functional': {for (final f in kFunctions) f.$1: functional[f.$1] ?? 'NA'},
        if (notes.trim().isNotEmpty) 'notes': notes.trim(),
      };

  factory UnitQc.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> m(dynamic v) => (v as Map?)?.cast<String, dynamic>() ?? const {};
    final s = m(j['screen']), p = m(j['physical']);
    return UnitQc(
      battery: (m(j['battery'])['health'] as num?)?.toInt() ?? 90,
      lcd: '${s['lcd'] ?? 'WORKING'}',
      screen: '${s['condition'] ?? 'FLAWLESS'}',
      body: '${p['body'] ?? 'LIKE_NEW'}',
      back: '${p['back'] ?? 'LIKE_NEW'}',
      frame: '${p['frame'] ?? 'STRAIGHT'}',
      functional: {for (final e in m(j['functional']).entries) e.key: '${e.value}'},
      notes: '${j['notes'] ?? ''}',
    );
  }
}
