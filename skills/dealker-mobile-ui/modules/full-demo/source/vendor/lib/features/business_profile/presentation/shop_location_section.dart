import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:dealker_vendor/core/maps/ola_maps.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_theme.dart';
import 'package:dealker_vendor/features/auth/presentation/widgets/brand_ui.dart';
import 'package:dealker_vendor/features/business_profile/application/business_providers.dart';
import 'package:dealker_vendor/features/business_profile/data/business_models.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

final _pinRe = RegExp(r'^[1-9][0-9]{5}$');

/// What the phone's GPS gave us, or why it could not.
class GpsResult {
  const GpsResult.ok(this.position)
      : error = null,
        openSettings = false;
  const GpsResult.fail(this.error, {this.openSettings = false})
      : position = null;
  final Position? position;
  final String? error;
  final bool openSettings;
}

Future<GpsResult> readGps() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const GpsResult.fail(
          'Turn on location (GPS) on your phone and try again.');
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      return const GpsResult.fail(
          'Location permission is needed to find your shop. You can also choose the spot on the map.');
    }
    if (perm == LocationPermission.deniedForever) {
      return const GpsResult.fail(
          'Location is blocked for this app. Allow it in Settings, or choose the spot on the map.',
          openSettings: true);
    }
    try {
      return GpsResult.ok(await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 20))));
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return GpsResult.ok(last);
      return const GpsResult.fail(
          'Could not get a GPS fix. Try near a window or outdoors, or choose the spot on the map.');
    }
  } catch (_) {
    return const GpsResult.fail(
        'Could not read your location. Please try again.');
  }
}

/// A short human line for a coordinate ("Park Street, Kolkata"), or null when the lookup is unavailable.
Future<String?> describePlace(double lat, double lng) async {
  final ola = await OlaMaps.reverse(lat, lng);
  if (ola != null) {
    final parts = <String>[
      if (ola['sub']!.isNotEmpty)
        ola['sub']!
      else if (ola['street']!.isNotEmpty)
        ola['street']!,
      if (ola['city']!.isNotEmpty) ola['city']!,
      if (ola['pin']!.isNotEmpty) ola['pin']!,
    ];
    if (parts.isNotEmpty) return parts.join(', ');
  }
  try {
    final marks = await Geocoding().placemarkFromCoordinates(lat, lng);
    if (marks.isEmpty) return null;
    final m = marks.first;
    final parts = <String>[
      if ((m.subLocality ?? '').trim().isNotEmpty)
        m.subLocality!.trim()
      else if ((m.street ?? '').trim().isNotEmpty)
        m.street!.trim(),
      if ((m.locality ?? '').trim().isNotEmpty) m.locality!.trim(),
      if ((m.postalCode ?? '').trim().isNotEmpty) m.postalCode!.trim(),
    ];
    return parts.isEmpty ? null : parts.join(', ');
  } catch (_) {
    return null;
  }
}

/// Saves a chosen point to the vendor profile (and fills the address from it). The server copies the pin
/// onto the shop, which is what customers' "nearby" search reads. Returns an error message or null.
Future<String?> saveShopLocation(
    WidgetRef ref, BusinessProfile current, double lat, double lng) async {
  final id = ref.read(businessVendorIdProvider);
  if (id == null) return 'No vendor linked to this account.';
  final body = <String, dynamic>{
    'latitude': double.parse(lat.toStringAsFixed(7)),
    'longitude': double.parse(lng.toStringAsFixed(7)),
  };
  var filledFromOla = false;
  final ola = await OlaMaps.reverse(lat, lng);
  if (ola != null && (ola['city']!.isNotEmpty || ola['pin']!.isNotEmpty)) {
    filledFromOla = true;
    if (_pinRe.hasMatch(ola['pin']!)) body['pincode'] = ola['pin'];
    if (ola['city']!.isNotEmpty) body['city'] = ola['city'];
    if (ola['state']!.isNotEmpty) body['state'] = ola['state'];
    if (current.address1.isEmpty) {
      final street = [ola['street'], ola['sub']]
          .where((e) => e != null && e.isNotEmpty)
          .join(', ');
      if (street.isNotEmpty) body['address_line1'] = street;
    }
  }
  try {
    final marks = filledFromOla
        ? const <Placemark>[]
        : await Geocoding().placemarkFromCoordinates(lat, lng);
    if (marks.isNotEmpty) {
      final m = marks.first;
      final pin = (m.postalCode ?? '').trim();
      if (_pinRe.hasMatch(pin)) body['pincode'] = pin;
      final city = ((m.locality ?? '').isNotEmpty
              ? m.locality
              : m.subAdministrativeArea) ??
          '';
      if (city.trim().isNotEmpty) body['city'] = city.trim();
      final state = (m.administrativeArea ?? '').trim();
      if (state.isNotEmpty) body['state'] = state;
      if (current.address1.isEmpty) {
        final street = <String?>[m.name, m.subLocality]
            .where((e) => e != null && e.trim().isNotEmpty)
            .join(', ');
        if (street.isNotEmpty) body['address_line1'] = street;
      }
    }
  } catch (_) {
    // Address lookup is best-effort; the coordinates are what matter.
  }
  try {
    await ref.read(businessRepositoryProvider).saveProfile(id, body);
    refreshBusinessProfile(ref);
    return null;
  } catch (_) {
    return 'Could not save your location. Check your connection and try again.';
  }
}

/// GPS → save, in one go.
Future<String?> captureShopLocation(
    WidgetRef ref, BusinessProfile current) async {
  final gps = await readGps();
  if (gps.position == null) return gps.error;
  return saveShopLocation(
      ref, current, gps.position!.latitude, gps.position!.longitude);
}

/// Opens the "Pin your shop" bottom sheet (GPS, or pick on the map). Returns true when a location was saved.
Future<bool> showShopLocationSheet(
    BuildContext context, BusinessProfile profile) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LocationSheet(profile: profile),
  );
  return saved == true;
}

/// Full-screen map picker: drag the map under the pin, then confirm.
Future<bool> openShopLocationPicker(
    BuildContext context, BusinessProfile profile) async {
  final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ShopLocationPickerScreen(profile: profile)));
  return saved == true;
}

enum _Phase { idle, locating, saved, failed }

class _LocationSheet extends ConsumerStatefulWidget {
  const _LocationSheet({required this.profile});
  final BusinessProfile profile;

  @override
  ConsumerState<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends ConsumerState<_LocationSheet> {
  _Phase _phase = _Phase.idle;
  String? _error;
  bool _settings = false;
  String? _place;

  Future<void> _useGps() async {
    setState(() {
      _phase = _Phase.locating;
      _error = null;
    });
    final gps = await readGps();
    if (!mounted) return;
    if (gps.position == null) {
      setState(() {
        _phase = _Phase.failed;
        _error = gps.error;
        _settings = gps.openSettings;
      });
      return;
    }
    final p = gps.position!;
    final err =
        await saveShopLocation(ref, widget.profile, p.latitude, p.longitude);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _phase = _Phase.failed;
        _error = err;
        _settings = false;
      });
      return;
    }
    final place = await describePlace(p.latitude, p.longitude);
    if (!mounted) return;
    setState(() {
      _phase = _Phase.saved;
      _place = place;
    });
  }

  Future<void> _pickOnMap() async {
    final saved = await openShopLocationPicker(context, widget.profile);
    if (saved && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            22, 12, 22, 22 + MediaQuery.paddingOf(context).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                  color: Brand.line, borderRadius: BorderRadius.circular(3))),
          const SizedBox(height: 10),
          const Align(
              alignment: Alignment.centerLeft,
              child: OnboardingSteps(current: 1)),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: switch (_phase) {
              _Phase.saved => _body(
                    key: const ValueKey('saved'),
                    image: 'assets/auth/location_done.jpg',
                    title: 'Shop location saved',
                    text: _place != null
                        ? 'Your shop is pinned near $_place. Nearby customers can now find you.'
                        : 'Your shop is pinned. Nearby customers can now find you.',
                    actions: [
                      BrandButton(
                          label: 'Done',
                          onPressed: () => Navigator.pop(context, true)),
                      const SizedBox(height: 10),
                      BrandButton(
                          label: 'Fine-tune on the map',
                          outlined: true,
                          icon: PhosphorIconsRegular.mapTrifold,
                          onPressed: _pickOnMap),
                    ]),
              _Phase.locating => _body(
                    key: const ValueKey('locating'),
                    image: 'assets/auth/location_pin.jpg',
                    title: 'Finding your shop…',
                    text:
                        'Hold on while we read your GPS. Stay at your shop for the best result.',
                    actions: const [
                      SizedBox(height: 4),
                      SizedBox(
                          width: 30,
                          height: 30,
                          child: CircularProgressIndicator(
                              strokeWidth: 3, color: Brand.yellow)),
                      SizedBox(height: 10),
                    ]),
              _Phase.failed => _body(
                    key: const ValueKey('failed'),
                    image: 'assets/auth/location_pin.jpg',
                    title: 'We could not get your location',
                    text: _error ?? 'Please try again.',
                    error: true,
                    actions: [
                      if (_settings) ...[
                        BrandButton(
                            label: 'Open settings',
                            icon: PhosphorIconsRegular.gearSix,
                            onPressed: Geolocator.openAppSettings),
                        const SizedBox(height: 10),
                      ] else ...[
                        BrandButton(
                            label: 'Try again',
                            icon: PhosphorIconsBold.crosshair,
                            onPressed: _useGps),
                        const SizedBox(height: 10),
                      ],
                      BrandButton(
                          label: 'Choose on the map',
                          outlined: true,
                          icon: PhosphorIconsRegular.mapTrifold,
                          onPressed: _pickOnMap),
                    ]),
              _Phase.idle => _body(
                    key: const ValueKey('idle'),
                    image: 'assets/auth/location_pin.jpg',
                    title: 'Pin your shop on the map',
                    text:
                        'Customers near you see your shop first. Stand at your shop and let us read your location.',
                    actions: [
                      BrandButton(
                          label: 'Use my current location',
                          icon: PhosphorIconsBold.crosshair,
                          onPressed: _useGps),
                      const SizedBox(height: 10),
                      BrandButton(
                          label: 'Choose on the map',
                          outlined: true,
                          icon: PhosphorIconsRegular.mapTrifold,
                          onPressed: _pickOnMap),
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Maybe later',
                              style: TextStyle(
                                  color: Brand.muted,
                                  fontWeight: FontWeight.w700))),
                    ]),
            },
          ),
        ]),
      ),
    );
  }

  Widget _body(
      {required Key key,
      required String image,
      required String title,
      required String text,
      required List<Widget> actions,
      bool error = false}) {
    return Column(key: key, mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        height: 190,
        child: ShaderMask(
          // Fades the artwork's off-white backdrop into the white sheet.
          shaderCallback: (r) => const RadialGradient(
              radius: 0.62,
              colors: [Colors.white, Colors.white, Color(0x00FFFFFF)],
              stops: [0, 0.72, 1]).createShader(r),
          blendMode: BlendMode.dstIn,
          child: Image.asset(image, fit: BoxFit.contain),
        ),
      ),
      Text(title,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontFamily: AppTheme.headingFont,
              fontWeight: FontWeight.w800,
              fontSize: 23,
              color: Brand.navy)),
      const SizedBox(height: 8),
      Text(text,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: error ? Brand.rose : Brand.muted)),
      const SizedBox(height: 18),
      ...actions,
    ]);
  }
}

/// Drag the map under a fixed pin to place the shop exactly, then confirm.
class ShopLocationPickerScreen extends ConsumerStatefulWidget {
  const ShopLocationPickerScreen({super.key, required this.profile});
  final BusinessProfile profile;

  @override
  ConsumerState<ShopLocationPickerScreen> createState() => _PickerState();
}

class _PickerState extends ConsumerState<ShopLocationPickerScreen> {
  final _map = MapController();
  late LatLng _center = widget.profile.hasLocation
      ? LatLng(widget.profile.latitude!, widget.profile.longitude!)
      : const LatLng(22.5726, 88.3639);
  bool _dragging = false;
  bool _saving = false;
  bool _locating = false;
  String? _place;
  int _lookupId = 0;

  @override
  void initState() {
    super.initState();
    if (!widget.profile.hasLocation) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _toGps(silent: true));
    } else {
      _lookup();
    }
  }

  Future<void> _lookup() async {
    final id = ++_lookupId;
    final place = await describePlace(_center.latitude, _center.longitude);
    if (mounted && id == _lookupId) setState(() => _place = place);
  }

  Future<void> _toGps({bool silent = false}) async {
    setState(() => _locating = true);
    final gps = await readGps();
    if (!mounted) return;
    setState(() => _locating = false);
    if (gps.position == null) {
      if (!silent)
        showAppToast(context, gps.error ?? 'No location.', error: true);
      return;
    }
    final p = LatLng(gps.position!.latitude, gps.position!.longitude);
    _map.move(p, 17);
    setState(() => _center = p);
    _lookup();
  }

  Future<void> _confirm() async {
    setState(() => _saving = true);
    final err = await saveShopLocation(
        ref, widget.profile, _center.latitude, _center.longitude);
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      showAppToast(context, err, error: true);
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: widget.profile.hasLocation ? 17 : 14,
              minZoom: 4,
              maxZoom: 19,
              onPositionChanged: (cam, hasGesture) {
                _center = cam.center;
                if (hasGesture && !_dragging) setState(() => _dragging = true);
              },
              onMapEvent: (e) {
                if (e is MapEventMoveEnd ||
                    e is MapEventFlingAnimationEnd ||
                    e is MapEventDoubleTapZoomEnd ||
                    e is MapEventScrollWheelZoom) {
                  if (_dragging) setState(() => _dragging = false);
                  _lookup();
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: OlaMaps.tileUrl,
                userAgentPackageName: 'in.dealker.vendor',
              ),
            ],
          ),
          // Fixed centre pin (its tip sits on the map centre).
          IgnorePointer(
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: EdgeInsets.only(bottom: _dragging ? 84 : 52),
                child: const Icon(Icons.location_on,
                    size: 56,
                    color: Brand.rose,
                    shadows: [Shadow(color: Colors.black38, blurRadius: 10)]),
              ),
            ),
          ),
          Positioned(
            top: top + 8,
            left: 14,
            right: 14,
            child: Row(children: [
              Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 3,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.pop(context, false),
                  child: const SizedBox(
                      width: 46,
                      height: 46,
                      child: Icon(Icons.close_rounded, color: Brand.navy)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(23),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 12,
                          offset: Offset(0, 3))
                    ],
                  ),
                  child: const Text('Move the map to your shop',
                      style: TextStyle(
                          fontFamily: AppTheme.headingFont,
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          color: Brand.navy)),
                ),
              ),
            ]),
          ),
          Positioned(
            right: 14,
            bottom: 214 + MediaQuery.paddingOf(context).bottom,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 4,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _locating ? null : _toGps,
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: _locating
                      ? const Padding(
                          padding: EdgeInsets.all(15),
                          child: CircularProgressIndicator(
                              strokeWidth: 2.6, color: Brand.navy))
                      : const Icon(Icons.my_location, color: Brand.navy),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  20, 18, 20, 18 + MediaQuery.paddingOf(context).bottom),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                      color: Color(0x26001F5F),
                      blurRadius: 24,
                      offset: Offset(0, -6))
                ],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: Brand.cream,
                        borderRadius: BorderRadius.circular(14)),
                    child: const Icon(PhosphorIconsFill.mapPinLine,
                        color: Brand.rose, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Shop location',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Brand.muted)),
                          const SizedBox(height: 2),
                          Text(
                              _place ??
                                  '${_center.latitude.toStringAsFixed(5)}, ${_center.longitude.toStringAsFixed(5)}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontFamily: AppTheme.headingFont,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: Brand.navy)),
                        ]),
                  ),
                ]),
                const SizedBox(height: 16),
                BrandButton(
                    label: 'Confirm shop location',
                    loading: _saving,
                    onPressed: _confirm),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Business Profile card: current pin on a map + ways to update it.
class ShopLocationSection extends ConsumerWidget {
  const ShopLocationSection({super.key, required this.profile});
  final BusinessProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = profile;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Brand.line),
        boxShadow: [
          BoxShadow(
              color: Brand.navy.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: Brand.cream, borderRadius: BorderRadius.circular(12)),
            child: const Icon(PhosphorIconsFill.mapPinLine,
                size: 21, color: Brand.rose),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Shop location on map',
                style: TextStyle(
                    fontFamily: AppTheme.headingFont,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Brand.navy)),
          ),
          if (b.hasLocation)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                  color: const Color(0xFFE3F7EA),
                  borderRadius: BorderRadius.circular(12)),
              child: const Text('Pinned',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Brand.green)),
            ),
        ]),
        const SizedBox(height: 8),
        Text(
          b.hasLocation
              ? 'Customers nearby find you from this pin.'
              : 'Not set yet — customers cannot find you in "nearby" until you pin your shop.',
          style:
              const TextStyle(fontSize: 13.5, height: 1.35, color: Brand.muted),
        ),
        const SizedBox(height: 12),
        if (b.hasLocation)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 160,
              child: Stack(children: [
                FlutterMap(
                  key: ValueKey('${b.latitude},${b.longitude}'),
                  options: MapOptions(
                    initialCenter: LatLng(b.latitude!, b.longitude!),
                    initialZoom: 15.5,
                    interactionOptions:
                        const InteractionOptions(flags: InteractiveFlag.none),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: OlaMaps.tileUrl,
                      userAgentPackageName: 'in.dealker.vendor',
                    ),
                    MarkerLayer(markers: [
                      Marker(
                        point: LatLng(b.latitude!, b.longitude!),
                        width: 46,
                        height: 46,
                        alignment: Alignment.topCenter,
                        child: const Icon(Icons.location_on,
                            color: Brand.rose,
                            size: 46,
                            shadows: [
                              Shadow(color: Colors.black38, blurRadius: 8)
                            ]),
                      ),
                    ]),
                  ],
                ),
                Positioned.fill(
                    child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () => openShopLocationPicker(context, b))),
              ]),
            ),
          )
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 150,
              width: double.infinity,
              color: const Color(0xFFFBF6E6),
              child: Image.asset('assets/auth/location_pin.jpg',
                  fit: BoxFit.contain),
            ),
          ),
        const SizedBox(height: 12),
        BrandButton(
          label: b.hasLocation
              ? 'Update from my location'
              : 'Use my current location',
          icon: PhosphorIconsBold.crosshair,
          onPressed: () => showShopLocationSheet(context, b),
        ),
        const SizedBox(height: 8),
        BrandButton(
          label: b.hasLocation ? 'Change on the map' : 'Choose on the map',
          outlined: true,
          icon: PhosphorIconsRegular.mapTrifold,
          onPressed: () => openShopLocationPicker(context, b),
        ),
      ]),
    );
  }
}

/// Wrap the home page: right after sign-in, if the shop has no pin yet, opens the "Pin your shop" sheet
/// once per app session (this triggers the permission prompt and the map fetch).
class ShopLocationAutoPrompt extends ConsumerStatefulWidget {
  const ShopLocationAutoPrompt({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<ShopLocationAutoPrompt> createState() => _AutoPromptState();
}

bool _promptedThisSession = false;

class _AutoPromptState extends ConsumerState<ShopLocationAutoPrompt> {
  Future<void> _maybePrompt(BusinessProfile b) async {
    if (_promptedThisSession || b.hasLocation) return;
    _promptedThisSession = true;
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    final saved = await showShopLocationSheet(context, b);
    if (saved && mounted) showAppToast(context, 'Shop location saved.');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<BusinessProfile>>(businessProfileProvider, (_, next) {
      final b = next.asData?.value;
      if (b != null) _maybePrompt(b);
    });
    final loaded = ref.watch(businessProfileProvider).asData?.value;
    if (loaded != null && !_promptedThisSession && !loaded.hasLocation) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybePrompt(loaded));
    }
    return widget.child;
  }
}
