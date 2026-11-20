import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart';
import 'package:dealker_vendor/features/orders/presentation/widgets/order_art.dart';

typedef ShipInfo = ({String courier, String awb, String trackingUrl});

class _Courier {
  const _Courier(this.name, this.icon, this.color, this.tokenLabel,
      {this.needsToken = true});
  final String name;
  final IconData icon;
  final Color color;
  final String tokenLabel;
  final bool needsToken;
}

const _couriers = <_Courier>[
  _Courier('Porter', PhosphorIconsFill.truck, Color(0xFF1F6FEB),
      'Porter booking token / order ID'),
  _Courier('Shiprocket', PhosphorIconsFill.rocketLaunch, Color(0xFF7C3AED),
      'Shiprocket AWB number'),
  _Courier('Delhivery', PhosphorIconsFill.package, Color(0xFFE5484D),
      'Delhivery waybill number'),
  _Courier('Blue Dart', PhosphorIconsFill.airplaneTilt, Color(0xFF0E7490),
      'Blue Dart AWB number'),
  _Courier('DTDC', PhosphorIconsFill.boxArrowUp, Color(0xFFD97706),
      'DTDC consignment number'),
  _Courier('Self delivery', PhosphorIconsFill.motorcycle, Color(0xFF16A34A),
      'Delivery person name or note (optional)',
      needsToken: false),
  _Courier('Other', PhosphorIconsFill.dotsThreeCircle, Color(0xFF4B5563),
      'Tracking number'),
];

/// Bottom sheet asking how the parcel is sent: pick the courier (Porter, Shiprocket, ...) with a tap,
/// paste its tracking token, optionally a tracking link. Returns the choice or null if dismissed.
Future<ShipInfo?> showShipSheet(BuildContext context) {
  return showModalBottomSheet<ShipInfo>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (c) => const _ShipSheet(),
  );
}

class _ShipSheet extends StatefulWidget {
  const _ShipSheet();

  @override
  State<_ShipSheet> createState() => _ShipSheetState();
}

class _ShipSheetState extends State<_ShipSheet> {
  _Courier _courier = _couriers.first;
  final _other = TextEditingController();
  final _token = TextEditingController();
  final _link = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _other.dispose();
    _token.dispose();
    _link.dispose();
    super.dispose();
  }

  InputDecoration _dec(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13.5, color: AppColors.textMuted),
        prefixIcon: Icon(icon, size: 20, color: _courier.color),
        filled: true,
        fillColor: const Color(0xFFF7F9FD),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _courier.color, width: 1.5)),
      );

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final t = d?.text?.trim();
    if (t != null && t.isNotEmpty) setState(() => _token.text = t);
  }

  void _submit() {
    final name = _courier.name == 'Other' ? _other.text.trim() : _courier.name;
    if (name.length < 2) {
      setState(() => _error = 'Type the courier name');
      return;
    }
    if (_courier.needsToken && _token.text.trim().length < 3) {
      setState(() => _error = 'Enter the ${_courier.name} tracking token');
      return;
    }
    Navigator.pop(context, (
      courier: name,
      awb: _token.text.trim(),
      trackingUrl: _link.text.trim()
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            18, 10, 18, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                          color: const Color(0xFFD9DEEA),
                          borderRadius: BorderRadius.circular(4)))),
              const SizedBox(height: 14),
              Row(children: [
                const OrderArtImage(OrderArt.truck, size: 58),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ship this order', style: heading(size: 20)),
                        const SizedBox(height: 2),
                        const Text(
                            'Pick who is delivering it and paste the tracking token. The buyer sees it live.',
                            style: TextStyle(
                                fontSize: 12.5,
                                height: 1.35,
                                color: AppColors.textMuted)),
                      ]),
                ),
              ]),
              const SizedBox(height: 16),
              const Text('1  Who is delivering?',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final c in _couriers)
                  GestureDetector(
                    onTap: () => setState(() {
                      _courier = c;
                      _error = null;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: _courier == c
                            ? c.color.withValues(alpha: 0.12)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: _courier == c
                                ? c.color
                                : AppColors.cardBorder,
                            width: _courier == c ? 1.8 : 1),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(c.icon, size: 20, color: c.color),
                        const SizedBox(width: 7),
                        Text(c.name,
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: _courier == c
                                    ? c.color
                                    : AppColors.navy)),
                        if (_courier == c) ...[
                          const SizedBox(width: 6),
                          Icon(PhosphorIconsFill.checkCircle,
                              size: 16, color: c.color),
                        ],
                      ]),
                    ),
                  ),
              ]),
              if (_courier.name == 'Other') ...[
                const SizedBox(height: 12),
                TextField(
                    controller: _other,
                    textCapitalization: TextCapitalization.words,
                    decoration:
                        _dec('Courier name', PhosphorIconsRegular.buildings)),
              ],
              const SizedBox(height: 16),
              Text(
                  _courier.needsToken
                      ? '2  Tracking token'
                      : '2  Delivery note (optional)',
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy)),
              const SizedBox(height: 10),
              TextField(
                controller: _token,
                onChanged: (_) => setState(() => _error = null),
                textCapitalization: TextCapitalization.characters,
                decoration: _dec(_courier.tokenLabel, PhosphorIconsRegular.hash)
                    .copyWith(
                        suffixIcon: TextButton.icon(
                  onPressed: _paste,
                  icon: const Icon(PhosphorIconsRegular.clipboardText, size: 18),
                  label: const Text('Paste'),
                )),
              ),
              const SizedBox(height: 10),
              TextField(
                  controller: _link,
                  keyboardType: TextInputType.url,
                  decoration: _dec('Tracking link (optional)',
                      PhosphorIconsRegular.link)),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Row(children: [
                  const Icon(PhosphorIconsFill.warningCircle,
                      size: 16, color: AppColors.rose),
                  const SizedBox(width: 6),
                  Text(_error!,
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.rose)),
                ]),
              ],
              const SizedBox(height: 18),
              AuctionButton(
                  label: 'Mark as shipped',
                  icon: PhosphorIconsFill.paperPlaneTilt,
                  onPressed: _submit),
            ]),
      ),
    );
  }
}
