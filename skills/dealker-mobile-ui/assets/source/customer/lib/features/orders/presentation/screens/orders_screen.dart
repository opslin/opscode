import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_app/core/utils/app_toast.dart';
import 'package:dealker_app/features/orders/presentation/widgets/order_theme.dart';
import 'package:dealker_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:dealker_app/features/orders/domain/entities/order_entity.dart';
import 'package:dealker_app/features/orders/presentation/providers/active_order_provider.dart';
import 'package:dealker_app/features/orders/presentation/providers/my_orders_provider.dart';
import 'package:dealker_app/features/orders/presentation/providers/order_list_provider.dart';
import 'package:dealker_app/features/orders/presentation/providers/order_live_sync_provider.dart';
import 'package:dealker_app/features/orders/presentation/widgets/order_card.dart';
import 'package:dealker_app/features/orders/presentation/widgets/order_ui.dart';
import 'package:dealker_app/features/refund_requests/presentation/providers/refund_request_provider.dart';
import 'package:dealker_app/features/refund_requests/presentation/screens/return_routes.dart';
import 'package:dealker_app/routing/route_names.dart';
import 'package:dealker_app/shared/widgets/web_storefront_footer.dart';

/// My Orders — design `09-my-orders-list.webp` + the four state tiles of
/// `07-orders-states-sheet.webp` (loading / empty / error / offline).
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  OrdersTab _tab = OrdersTab.all;
  bool _searching = false;
  String _query = '';
  final TextEditingController _search = TextEditingController();
  final Set<String> _reordering = <String>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(activeOrderProvider);
    ref.invalidate(myOrdersProvider);
    try {
      await ref.read(myOrdersProvider.future);
    } catch (_) {}
  }

  /// Return button: continues an existing request, otherwise starts the wizard.
  Future<void> _openReturn(OrderEntity order) async {
    try {
      final request =
          await ref.read(refundRequestByOrderProvider(order.id).future);
      if (!mounted) return;
      final bool existing = request != null && request.blocksNewRequest;
      await context.push(
        existing
            ? ReturnRoutes.tracking(order.id)
            : ReturnRoutes.start(order.id),
      );
      ref
        ..invalidate(refundRequestByOrderProvider(order.id))
        ..invalidate(myOrdersProvider);
    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Could not open the return. Please try again.');
      }
    }
  }

  Future<void> _reorder(OrderEntity order) async {
    if (_reordering.contains(order.id)) return;
    setState(() => _reordering.add(order.id));
    final result =
        await ref.read(orderListControllerProvider).reorder(order.id);
    if (!mounted) return;
    setState(() => _reordering.remove(order.id));
    result.fold(
      (failure) => AppToast.show(context, failure.message),
      (data) {
        ref.invalidate(cartProvider);
        final String warnings =
            data.warnings.isEmpty ? '' : '\n${data.warnings.join('\n')}';
        AppToast.show(
          context,
          'Items added to cart$warnings',
          type: ToastType.success,
        );
        context.push(RouteNames.cart);
      },
    );
  }

  bool _matchesQuery(OrderEntity o) {
    final String q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (o.orderNumber.toLowerCase().contains(q)) return true;
    return o.items.any((i) => i.name.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(orderListRefreshTickProvider, (previous, next) {
      if (previous != next) ref.invalidate(myOrdersProvider);
    });
    final AsyncValue<List<OrderRow>> async = ref.watch(myOrdersProvider);
    final List<OrderRow> all = async.asData?.value ?? const <OrderRow>[];

    return Scaffold(
      backgroundColor: OV.canvas,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: <Widget>[
            _Header(
              searching: _searching,
              controller: _search,
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.go(RouteNames.home),
              onToggleSearch: () => setState(() {
                _searching = !_searching;
                if (!_searching) {
                  _query = '';
                  _search.clear();
                }
              }),
              onChanged: (String v) => setState(() => _query = v),
            ),
            if (async.hasValue && all.isNotEmpty)
              _Tabs(
                selected: _tab,
                counts: <OrdersTab, int>{
                  for (final OrdersTab t in OrdersTab.values)
                    t: all.where((r) => t.matches(r.phase)).length,
                },
                onSelected: (OrdersTab t) => setState(() => _tab = t),
              ),
            Expanded(
              child: async.when(
                loading: () => const _LoadingList(),
                error: (Object e, _) {
                  final bool offline = e is OrdersLoadError && e.offline;
                  return _StateBlock(
                    offline: offline,
                    onRetry: () => ref.invalidate(myOrdersProvider),
                  );
                },
                data: (List<OrderRow> rows) {
                  if (rows.isEmpty) {
                    return _EmptyBlock(
                      onShop: () => context.go(RouteNames.home),
                    );
                  }
                  final List<OrderRow> shown = rows
                      .where(
                        (r) => _tab.matches(r.phase) && _matchesQuery(r.order),
                      )
                      .toList();
                  return RefreshIndicator(
                    color: AU.indigo,
                    onRefresh: _refresh,
                    child: shown.isEmpty
                        ? _NothingHere(
                            searching: _query.trim().isNotEmpty,
                            tab: _tab,
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              12.w,
                              8.h,
                              12.w,
                              28.h,
                            ),
                            itemCount: shown.length +
                                (kIsWeb &&
                                        MediaQuery.sizeOf(context).width >= 700
                                    ? 1
                                    : 0),
                            separatorBuilder: (_, __) => SizedBox(height: 12.h),
                            itemBuilder: (BuildContext context, int i) {
                              if (i == shown.length) {
                                return WebStorefrontFooter(
                                    onNavigate: context.go);
                              }
                              final OrderRow row = shown[i];
                              final OrderEntity o = row.order;
                              final card = RepaintBoundary(
                                child: OrderCard(
                                  row: row,
                                  isReordering: _reordering.contains(o.id),
                                  onOpen: () => context.push('/orders/${o.id}'),
                                  onTrack: () =>
                                      context.push('/orders/${o.id}/track'),
                                  onReorder: () => _reorder(o),
                                  onReturn: () => _openReturn(o),
                                ),
                              );
                              if (!kIsWeb ||
                                  MediaQuery.sizeOf(context).width < 700)
                                return card;
                              return Center(
                                  child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 1000),
                                child: card,
                              ));
                            },
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.searching,
    required this.controller,
    required this.onBack,
    required this.onToggleSearch,
    required this.onChanged,
  });

  final bool searching;
  final TextEditingController controller;
  final VoidCallback onBack;
  final VoidCallback onToggleSearch;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        8.w,
        MediaQuery.of(context).padding.top + 6.h,
        8.w,
        6.h,
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: onBack,
            icon: Icon(
              PhosphorIconsRegular.arrowLeft,
              size: 26.sp,
              color: AU.ink,
            ),
          ),
          Expanded(
            child: searching
                ? TextField(
                    controller: controller,
                    autofocus: true,
                    onChanged: onChanged,
                    style: dm(15.sp, color: AU.ink),
                    decoration: InputDecoration(
                      hintText: 'Search orders',
                      hintStyle: dm(15.sp, color: AU.grey),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  )
                : Row(children: <Widget>[
                    CartArtImage(CartArt.parcels, size: 34.sp, float: true),
                    SizedBox(width: 8.w),
                    Text('My Orders', style: jakarta(22.sp)),
                  ]),
          ),
          IconButton(
            onPressed: onToggleSearch,
            icon: Icon(
              searching
                  ? PhosphorIconsRegular.x
                  : PhosphorIconsRegular.magnifyingGlass,
              size: 26.sp,
              color: AU.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.selected,
    required this.counts,
    required this.onSelected,
  });
  final OrdersTab selected;
  final Map<OrdersTab, int> counts;
  final ValueChanged<OrdersTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      height: 46.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(12.w, 4.h, 12.w, 10.h),
        itemCount: OrdersTab.values.length,
        separatorBuilder: (_, __) => SizedBox(width: 8.w),
        itemBuilder: (BuildContext context, int i) {
          final OrdersTab t = OrdersTab.values[i];
          final bool on = t == selected;
          return GestureDetector(
            onTap: () => onSelected(t),
            child: Container(
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              decoration: BoxDecoration(
                color: on ? AU.indigo : Colors.white,
                borderRadius: BorderRadius.circular(100.r),
                border: Border.all(color: on ? AU.indigo : AU.chipBorder),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                Text(
                  t.label,
                  style: dm(
                    13.sp,
                    w: on ? FontWeight.w700 : FontWeight.w500,
                    color: on ? Colors.white : AU.ink,
                  ),
                ),
                SizedBox(width: 6.w),
                Container(
                  constraints: BoxConstraints(minWidth: 20.w),
                  padding:
                      EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.5.h),
                  decoration: BoxDecoration(
                    color: on ? const Color(0xFFFFC400) : AU.indigoSoft,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    '${counts[t] ?? 0}',
                    textAlign: TextAlign.center,
                    style: dm(11.5.sp,
                        w: FontWeight.w800,
                        color: on ? AU.indigo : AU.muted),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _NothingHere extends StatelessWidget {
  const _NothingHere({required this.searching, required this.tab});
  final bool searching;
  final OrdersTab tab;

  @override
  Widget build(BuildContext context) {
    final String text = searching
        ? 'No orders match your search.'
        : 'No ${tab.label.toLowerCase()} orders.';
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: <Widget>[
        SizedBox(height: 120.h),
        Center(child: Text(text, style: dm(15.sp, color: AU.muted))),
      ],
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.onShop});
  final VoidCallback onShop;

  @override
  Widget build(BuildContext context) => StateView(
        art: CartArtImage(CartArt.parcels, size: 150.w, float: true),
        title: 'No orders yet',
        body: "Looks like you haven't placed any orders.",
        button: StateButton(label: 'Start shopping', onTap: onShop),
      );
}

class _StateBlock extends StatelessWidget {
  const _StateBlock({required this.offline, required this.onRetry});
  final bool offline;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => StateView(
        art: CloudArt(offline: offline),
        title: offline ? "You're offline" : "Couldn't load your orders",
        body: offline
            ? 'Check your internet connection\nto view your orders.'
            : 'Something went wrong. Please try again.',
        button: offline
            ? StateButton(label: 'Try again', onTap: onRetry)
            : OutlinedButton.icon(
                onPressed: onRetry,
                icon: Icon(PhosphorIconsRegular.arrowClockwise, size: 20.sp),
                label: Text(
                  'Retry',
                  style: jakarta(16.sp, color: AU.indigo),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AU.indigo,
                  minimumSize: Size(190.w, 52.h),
                  side: const BorderSide(color: AU.indigo, width: 1.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
      );
}

/// Grey placeholder cards while the orders load.
class _LoadingList extends StatefulWidget {
  const _LoadingList();
  @override
  State<_LoadingList> createState() => _LoadingListState();
}

class _LoadingListState extends State<_LoadingList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (BuildContext context, _) {
        final Color bone = Color.lerp(
          const Color(0xFFE9EBF2),
          const Color(0xFFF3F4F9),
          _c.value,
        )!;
        Widget line(double w, double h) => Container(
              width: w,
              height: h,
              decoration: BoxDecoration(
                color: bone,
                borderRadius: BorderRadius.circular(6.r),
              ),
            );
        return ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(12.w, 14.h, 12.w, 0),
          children: <Widget>[
            for (int i = 0; i < 3; i++)
              Container(
                margin: EdgeInsets.only(bottom: 12.h),
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18.r),
                  border: Border.all(color: OV.border),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 88.w,
                      height: 88.w,
                      decoration: BoxDecoration(
                        color: bone,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          line(double.infinity, 14.h),
                          SizedBox(height: 10.h),
                          line(150.w, 12.h),
                          SizedBox(height: 10.h),
                          line(90.w, 12.h),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
