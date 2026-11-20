import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:dealker_app/shared/widgets/loading/dealker_page_loader.dart';
import 'package:dealker_app/core/utils/app_toast.dart';
import 'package:dealker_app/features/addresses/domain/entities/address_entity.dart';
import 'package:dealker_app/features/addresses/presentation/providers/address_provider.dart';
import 'package:dealker_app/features/sell_phone/data/sell_models.dart';
import 'package:dealker_app/features/sell_phone/data/sell_repository.dart';
import 'package:dealker_app/features/sell_phone/presentation/sell_providers.dart';
import 'package:dealker_app/core/theme/repair_tokens.dart';
import 'package:dealker_app/features/sell_phone/presentation/sell_ui.dart';

/// After accepting an offer: home pickup (address, day, time window) or drop-off at the buyer's store.
class SellBookingScreen extends ConsumerStatefulWidget {
  const SellBookingScreen({required this.requestId, super.key});
  final String requestId;

  @override
  ConsumerState<SellBookingScreen> createState() => _SellBookingScreenState();
}

class _SellBookingScreenState extends ConsumerState<SellBookingScreen> {
  String _mode = 'PICKUP';
  String? _addressId;
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  String? _window;
  final TextEditingController _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: now,
      lastDate: now.add(const Duration(days: 14)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _confirm(SellConfig cfg) async {
    if (_mode == 'PICKUP') {
      if (_addressId == null) {
        AppToast.show(
          context,
          'Choose the address we should collect the phone from',
        );
        return;
      }
      if (_window == null) {
        AppToast.show(context, 'Choose a pickup time');
        return;
      }
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(sellRepositoryProvider)
          .bookFulfilment(widget.requestId, <String, dynamic>{
        'fulfilment': _mode,
        if (_mode == 'PICKUP') ...<String, dynamic>{
          'addressId': _addressId,
          'date': DateFormat('yyyy-MM-dd').format(_date),
          'window': _window,
        } else
          'date': DateFormat('yyyy-MM-dd').format(_date),
        if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
      });
      ref.invalidate(sellJourneyProvider(widget.requestId));
      ref.invalidate(mySalesProvider);
      if (mounted) context.go('/sell/${widget.requestId}');
    } catch (e) {
      if (mounted) AppToast.show(context, sellErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<SellConfig> cfg = ref.watch(sellConfigProvider);
    final AsyncValue<SellJourney> j =
        ref.watch(sellJourneyProvider(widget.requestId));
    final AsyncValue<List<AddressEntity>> addresses =
        ref.watch(addressProvider);
    return SellScaffold(
      title: 'Pickup & delivery',
      onBack: () => context.go('/sell/${widget.requestId}'),
      bottom: SellButton(
        _mode == 'PICKUP' ? 'Request pickup' : 'Confirm drop-off',
        busy: _busy,
        onPressed: cfg.hasValue ? () => _confirm(cfg.requireValue) : null,
      ),
      child: cfg.when(
        loading: () => const DealkerPageLoader(),
        error: (Object e, _) => Center(child: Text(sellErrorMessage(e))),
        data: (SellConfig c) {
          final SellJourney? jr = j.asData?.value;
          if (_mode == 'PICKUP' && !c.pickupEnabled && c.dropoffEnabled) {
            _mode = 'DROP_OFF';
          }
          return ListView(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 28.h),
            children: <Widget>[
              SellCard(
                tint: ReturnColors.greenSoft,
                border: ReturnColors.green.withValues(alpha: 0.35),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.check_circle_rounded,
                      color: ReturnColors.green,
                      size: 26.sp,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Offer accepted',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontFamily: RT.head,
                              fontWeight: FontWeight.w800,
                              color: ReturnColors.green,
                            ),
                          ),
                          if (jr?.agreedPrice != null)
                            Text(
                              '${inr(jr!.agreedPrice!)}${jr.buyerName != null ? ' from ${jr.buyerName}' : ''}',
                              style: TextStyle(
                                fontSize: 12.5.sp,
                                color: ReturnColors.ink,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              const SellHeading('How should we get your phone?'),
              if (c.pickupEnabled)
                _modeTile(
                  'PICKUP',
                  Icons.local_shipping_rounded,
                  'Home pickup',
                  'A courier collects it from your address.',
                ),
              if (c.dropoffEnabled)
                _modeTile(
                  'DROP_OFF',
                  Icons.storefront_rounded,
                  'Drop at the buyer\'s store',
                  'Bring it to the buyer\'s shop when you are ready.',
                ),
              SizedBox(height: 14.h),
              if (_mode == 'PICKUP') ...<Widget>[
                Text(
                  'Pickup address',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontFamily: RT.head,
                    fontWeight: FontWeight.w800,
                    color: ReturnColors.ink,
                  ),
                ),
                SizedBox(height: 8.h),
                addresses.when(
                  loading: () => const LinearProgressIndicator(
                    color: ReturnColors.indigo,
                  ),
                  error: (Object e, _) => const SellInlineMessage(
                    'Could not load your saved addresses.',
                    tone: SellTone.bad,
                  ),
                  data: (List<AddressEntity> list) {
                    if (list.isEmpty) {
                      return Column(
                        children: <Widget>[
                          const SellInlineMessage(
                            'Add an address so we know where to collect the phone.',
                            tone: SellTone.warn,
                          ),
                          SizedBox(height: 8.h),
                          SellButton(
                            'Add an address',
                            outlined: true,
                            onPressed: () =>
                                context.push('/profile/addresses/add'),
                          ),
                        ],
                      );
                    }
                    _addressId ??= (list.firstWhere(
                      (AddressEntity a) => a.isDefault,
                      orElse: () => list.first,
                    )).id;
                    return Column(
                      children: list.map((AddressEntity a) {
                        final bool sel = a.id == _addressId;
                        return Padding(
                          padding: EdgeInsets.only(bottom: 8.h),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12.r),
                            onTap: () => setState(() => _addressId = a.id),
                            child: Container(
                              padding: EdgeInsets.all(12.w),
                              decoration: BoxDecoration(
                                color: sel
                                    ? ReturnColors.indigoSoft
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(
                                  color: sel
                                      ? ReturnColors.indigo
                                      : ReturnColors.line,
                                  width: sel ? 1.6 : 1,
                                ),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Icon(
                                    sel
                                        ? Icons.radio_button_checked_rounded
                                        : Icons.radio_button_off_rounded,
                                    color: sel
                                        ? ReturnColors.indigo
                                        : ReturnColors.muted,
                                  ),
                                  SizedBox(width: 10.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          a.label,
                                          style: TextStyle(
                                            fontSize: 13.sp,
                                            fontFamily: RT.head,
                                            fontWeight: FontWeight.w800,
                                            color: ReturnColors.ink,
                                          ),
                                        ),
                                        Text(
                                          '${a.addressLine1}${a.addressLine2 != null && a.addressLine2!.isNotEmpty ? ', ${a.addressLine2}' : ''}, ${a.city} - ${a.pincode}',
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                            height: 1.3,
                                            color: ReturnColors.muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                SizedBox(height: 10.h),
                Text(
                  'Pickup date & time',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontFamily: RT.head,
                    fontWeight: FontWeight.w800,
                    color: ReturnColors.ink,
                  ),
                ),
                SizedBox(height: 8.h),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12.r),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 13.h,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: ReturnColors.line),
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.calendar_today_rounded,
                          color: ReturnColors.indigo,
                          size: 20,
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(
                            DateFormat('EEE, d MMM yyyy').format(_date),
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.expand_more_rounded,
                          color: ReturnColors.muted,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 10.h),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: c.pickupWindows
                      .map(
                        (String w) => SellChoice(
                          label: w,
                          selected: _window == w,
                          onTap: () => setState(() => _window = w),
                        ),
                      )
                      .toList(),
                ),
                SizedBox(height: 12.h),
                TextField(
                  controller: _note,
                  maxLength: 300,
                  decoration: InputDecoration(
                    labelText: 'Note for the pickup (optional)',
                    hintText: 'Please call before coming',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                ),
              ] else
                const SellInlineMessage(
                  'Once the buyer has paid you will see their store address here. Bring the phone, charger and ID.',
                  icon: Icons.storefront_rounded,
                ),
              SizedBox(height: 14.h),
              const SellInlineMessage(
                'The buyer pays Dealkr before the pickup, so your money is safe. You are paid after the phone is checked.',
                tone: SellTone.good,
                icon: Icons.shield_rounded,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _modeTile(String mode, IconData icon, String title, String sub) {
    final bool sel = _mode == mode;
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: InkWell(
        borderRadius: BorderRadius.circular(14.r),
        onTap: () => setState(() => _mode = mode),
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: sel ? ReturnColors.indigoSoft : Colors.white,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: sel ? ReturnColors.indigo : ReturnColors.line,
              width: sel ? 1.8 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                icon,
                color: sel ? ReturnColors.indigo : ReturnColors.muted,
                size: 26.sp,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.5.sp,
                        fontFamily: RT.head,
                        fontWeight: FontWeight.w800,
                        color: ReturnColors.ink,
                      ),
                    ),
                    Text(
                      sub,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: ReturnColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                sel
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: sel ? ReturnColors.indigo : ReturnColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
