import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/features/profile/application/profile_providers.dart';
import 'package:dealker_vendor/features/repair_book/presentation/widgets/repair_ui.dart';
import 'package:dealker_vendor/features/repair_book/repair_providers.dart';
import 'package:dealker_vendor/features/repair_book/repair_tokens.dart';
import 'package:dealker_vendor/features/repair_book/shims/env.dart';
import 'package:dealker_vendor/features/repair_book/shims/server_error.dart';

/// Where should shops pick the device up / find you? One tap uses the business address from the
/// vendor profile; otherwise type it and pin the spot with the phone's location.
class RepairAddAddressScreen extends ConsumerStatefulWidget {
  const RepairAddAddressScreen({super.key});

  @override
  ConsumerState<RepairAddAddressScreen> createState() => _RepairAddAddressScreenState();
}

class _RepairAddAddressScreenState extends ConsumerState<RepairAddAddressScreen> {
  final _line1 = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _pin = TextEditingController();
  String _label = 'Shop';
  double? _lat;
  double? _lng;
  bool _busy = false;
  bool _locating = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_line1, _city, _state, _pin]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        throw 'Location permission is off. Allow it in Settings, or use your business address.';
      }
      final p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      setState(() {
        _lat = p.latitude;
        _lng = p.longitude;
      });
    } catch (e) {
      setState(() => _error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _useBusiness() {
    final i = ref.read(vendorInfoProvider).asData?.value;
    if (i == null || !i.hasBusinessAddress) {
      setState(() => _error = 'Add your business address in Business profile first, or type the address below.');
      return;
    }
    setState(() {
      _label = 'Shop';
      _line1.text = [i.addressLine1, i.addressLine2].where((e) => e.trim().isNotEmpty).join(', ');
      _city.text = i.city;
      _state.text = i.state;
      _pin.text = i.pincode;
      _lat = i.lat ?? _lat;
      _lng = i.lng ?? _lng;
      _error = null;
    });
  }

  Future<void> _save() async {
    final line = _line1.text.trim(), city = _city.text.trim(), pin = _pin.text.trim();
    if (line.length < 3 || city.length < 2 || !RegExp(r'^[1-9][0-9]{5}$').hasMatch(pin)) {
      setState(() => _error = 'Fill the address, city and a 6-digit pincode.');
      return;
    }
    if (_lat == null || _lng == null) {
      setState(() => _error = 'Tap “Use my current location” so nearby shops can be found.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(dioClientProvider).post<dynamic>('/addresses', data: {
        'label': _label,
        'addressLine1': line,
        'city': city,
        if (_state.text.trim().isNotEmpty) 'state': _state.text.trim(),
        'pincode': pin,
        'lat': _lat,
        'lng': _lng,
        'isDefault': true,
      });
      ref.invalidate(repairAddressesProvider);
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = e is DioException ? ServerError.from(e).message : '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = ref.watch(vendorInfoProvider).asData?.value;
    InputDecoration dec(String hint, {IconData? icon}) => InputDecoration(
          hintText: hint,
          prefixIcon: icon == null ? null : Icon(icon, size: 20, color: RT.muted),
          filled: true,
          fillColor: const Color(0xFFF4F6FB),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        );
    return RepairShell(
      title: 'Add address',
      onBack: () => context.pop(),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 120), children: [
        Text('Where should shops come to?', style: rtHead(22, h: 1.2)),
        const SizedBox(height: 6),
        Text('We use this to find repair shops near you.', style: rtBody(14, h: 1.35)),
        const SizedBox(height: 16),
        if (info != null && info.hasBusinessAddress)
          RCard(
            child: Row(children: [
              const Icon(PhosphorIconsFill.storefront, color: RT.indigo, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Use my business address', style: rtHead(15.5)),
                  Text('${info.addressLine1}, ${info.city} ${info.pincode}',
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: rtBody(12.5)),
                ]),
              ),
              TextButton(onPressed: _useBusiness, child: const Text('Use')),
            ]),
          ),
        const SizedBox(height: 14),
        Wrap(spacing: 8, children: [
          for (final l in const ['Shop', 'Office', 'Home'])
            ChoiceChip(label: Text(l), selected: _label == l, onSelected: (_) => setState(() => _label = l)),
        ]),
        const SizedBox(height: 12),
        TextField(controller: _line1, decoration: dec('Shop / building, street, area', icon: PhosphorIconsRegular.mapPin)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(controller: _city, decoration: dec('City'))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: _state, decoration: dec('State'))),
        ]),
        const SizedBox(height: 10),
        TextField(
          controller: _pin,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          decoration: dec('Pincode (6 digits)'),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _locating ? null : _locate,
          icon: _locating
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(_lat == null ? PhosphorIconsRegular.crosshair : PhosphorIconsFill.checkCircle, size: 18),
          label: Text(_lat == null ? 'Use my current location' : 'Location pinned'),
          style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: _lat == null ? RT.indigo : const Color(0xFF15803D),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          RBand(_error!, kind: BandKind.danger),
        ],
        const SizedBox(height: 18),
        RButton(label: _busy ? 'Saving…' : 'Save address', onTap: _busy ? null : _save),
      ]),
    );
  }
}
