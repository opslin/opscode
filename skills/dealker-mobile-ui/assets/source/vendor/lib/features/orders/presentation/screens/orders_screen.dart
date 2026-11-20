import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart'
    show EmptyState, ErrorState, errorText;
import 'package:dealker_vendor/features/orders/application/orders_providers.dart';
import 'package:dealker_vendor/features/orders/data/order_models.dart';
import 'package:dealker_vendor/features/orders/presentation/widgets/order_card.dart';
import 'package:dealker_vendor/core/utils/polling.dart';

const _tabs = [
  ('all', 'All'),
  ('new', 'New'),
  ('active', 'In progress'),
  ('shipped', 'Shipped'),
  ('done', 'Done'),
  ('cancelled', 'Cancelled'),
];

const _types = [
  ('all', 'All orders'),
  ('product', 'Products'),
  ('auction', 'Auctions'),
  ('repair', 'Repairs'),
];

/// Everything the vendor sells in one inbox: product orders, auction sales and repair jobs.
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen(
      {super.key, this.initialType = 'all', this.initialTab = 'all'});
  final String initialType;
  final String initialTab;

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  late OrdersQuery _q =
      OrdersQuery(type: widget.initialType, tab: widget.initialTab);
  final _search = TextEditingController();
  Timer? _debounce;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    // New orders arrive from customers: refresh quietly while the screen is open.
    _poll = Timer.periodic(const Duration(seconds: 25), (_) {
      if (mounted && screenActive(context)) ref.invalidate(ordersProvider(_q));
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _poll?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400),
        () => setState(() => _q = _q.copyWith(q: v.trim())));
  }

  Future<void> _refresh() async {
    ref.invalidate(ordersProvider(_q));
    await ref.read(ordersProvider(_q).future);
  }

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(ordersProvider(_q));
    final data = page.value;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FE),
      body: SafeArea(
        child: Column(children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(4, 4, 16, 10),
            child: Column(children: [
              Row(children: [
                IconButton(
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/home'),
                  icon: const Icon(PhosphorIconsRegular.arrowLeft,
                      color: AppColors.navy),
                ),
                const Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Orders',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy)),
                        Text('Products · Auctions · Repairs',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textMuted)),
                      ]),
                ),
                if ((data?.needsAction ?? 0) > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: AppColors.amberSoft,
                        borderRadius: BorderRadius.circular(20)),
                    child: Text('${data!.needsAction} need you',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB45309))),
                  ),
              ]),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: TextField(
                  controller: _search,
                  onChanged: _onSearch,
                  decoration: InputDecoration(
                    hintText: 'Search order no., customer or product',
                    prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass,
                        size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF1F4FB),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 36,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  const SizedBox(width: 12),
                  for (final (key, label) in _types)
                    _Chip(
                      label: label,
                      count: data?.types[key],
                      on: _q.type == key,
                      onTap: () => setState(() => _q = _q.copyWith(type: key)),
                    ),
                ]),
              ),
            ]),
          ),
          Container(
            decoration: const BoxDecoration(
                color: Colors.white,
                border:
                    Border(bottom: BorderSide(color: AppColors.cardBorder))),
            height: 44,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              const SizedBox(width: 12),
              for (final (key, label) in _tabs)
                _TabItem(
                  label: label,
                  count: data?.counts[key],
                  on: _q.tab == key,
                  hot: key == 'new' && (data?.counts['new'] ?? 0) > 0,
                  onTap: () => setState(() => _q = _q.copyWith(tab: key)),
                ),
            ]),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: page.when(skipLoadingOnReload: true, skipError: true, 
                loading: () => data == null
                    ? const Center(child: CircularProgressIndicator())
                    : _list(data),
                error: (e, _) => ListView(children: [
                  ErrorState(
                      message: errorText(e, 'Could not load your orders.'),
                      onRetry: () => ref.invalidate(ordersProvider(_q)))
                ]),
                data: _list,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _list(OrdersPage d) {
    if (d.rows.isEmpty) {
      return ListView(children: [
        EmptyState(
          icon: PhosphorIconsRegular.package,
          title: _q.q.isNotEmpty
              ? 'No orders match "${_q.q}"'
              : _q.tab == 'all'
                  ? 'No orders yet'
                  : 'Nothing here',
          message: _q.tab == 'all' && _q.q.isEmpty
              ? 'Product orders, auction sales and repair jobs appear here as soon as they come in.'
              : 'Try another tab or filter.',
        )
      ]);
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      itemCount: d.rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => OrderCard(d.rows[i], key: ValueKey(d.rows[i].id)),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.label,
      required this.count,
      required this.on,
      required this.onTap});
  final String label;
  final int? count;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? AppColors.navy : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: on ? AppColors.navy : AppColors.cardBorder),
            ),
            child: Text(count == null ? label : '$label  $count',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: on ? Colors.white : AppColors.textSecondary)),
          ),
        ),
      );
}

class _TabItem extends StatelessWidget {
  const _TabItem(
      {required this.label,
      required this.count,
      required this.on,
      required this.hot,
      required this.onTap});
  final String label;
  final int? count;
  final bool on;
  final bool hot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: on ? const Color(0xFF1F6FEB) : Colors.transparent,
                      width: 2.5))),
          child: Row(children: [
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: on ? const Color(0xFF1F6FEB) : AppColors.textMuted)),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                    color:
                        hot ? const Color(0xFFE5232E) : const Color(0xFFEFF1F6),
                    borderRadius: BorderRadius.circular(9)),
                child: Text('$count',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: hot ? Colors.white : AppColors.textSecondary)),
              ),
            ],
          ]),
        ),
      );
}
