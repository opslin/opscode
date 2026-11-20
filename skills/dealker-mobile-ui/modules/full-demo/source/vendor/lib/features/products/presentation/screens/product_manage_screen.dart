import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/products/application/product_providers.dart';
import 'package:dealker_vendor/features/products/data/product_catalog.dart' show ProductCondition;
import 'package:dealker_vendor/features/products/data/product_models.dart';
import 'package:dealker_vendor/features/products/presentation/widgets/edit_sheets.dart';
import 'package:dealker_vendor/features/products/presentation/widgets/product_devices_section.dart';
import 'package:dealker_vendor/features/products/presentation/widgets/product_common.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';
import 'package:dealker_vendor/shared/widgets/fullscreen_image_viewer.dart';

/// One product: its status, what buyers see, and the "Update Anytime" menu.
class ProductManageScreen extends ConsumerStatefulWidget {
  const ProductManageScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<ProductManageScreen> createState() => _State();
}

class _State extends ConsumerState<ProductManageScreen> {
  bool _busy = false;
  final _pageCtl = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageCtl.dispose();
    super.dispose();
  }

  void _reload() {
    ref.invalidate(productDetailProvider(widget.id));
    refreshProducts(ref);
  }

  Future<void> _edit(ListingDetail p, EditKind k) async {
    if (await showEditSheet(context, p, k) && mounted) {
      _reload();
      showAppToast(context, 'Changes saved.');
    }
  }

  Future<void> _toggle(ListingDetail p) async {
    final pause = p.listingStatus != 'PAUSED';
    setState(() => _busy = true);
    try {
      await ref
          .read(productRepositoryProvider)
          .setStatus(p.id, pause ? 'PAUSED' : 'ACTIVE');
      _reload();
      if (mounted) {
        showAppToast(
            context,
            pause
                ? 'Product paused — hidden from buyers.'
                : 'Product is live again.');
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context, explainFailure(e).message, error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(ListingDetail p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete this product?'),
        content: Text(
            '“${p.name}” will be removed from your products and hidden from buyers.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.rose))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(productRepositoryProvider).remove(p.id);
      refreshProducts(ref);
      if (mounted) {
        showAppToast(context, 'Product deleted.');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context, explainFailure(e).message, error: true);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(productDetailProvider(widget.id));
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FE),
      appBar: const AuctionAppBar(title: 'Product'),
      body: async.when(
        skipLoadingOnReload: true,
        skipError: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
            message: errorText(e, 'Could not load this product.'),
            onRetry: _reload),
        data: (p) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(productDetailProvider(widget.id));
            await ref
                .read(productDetailProvider(widget.id).future)
                .catchError((_) => p);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              _Header(
                  p: p,
                  ctl: _pageCtl,
                  page: _page,
                  onPage: (i) => setState(() => _page = i)),
              const SizedBox(height: 14),
              _StatusBanner(
                  p: p,
                  busy: _busy,
                  onResume: () => _toggle(p),
                  onFix: () => context.push('/products/view/${p.id}/media')),
              const SizedBox(height: 18),
              Text('Update Anytime', style: heading(size: 17)),
              const SizedBox(height: 10),
              SectionCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(children: [
                  _MenuRow(PhosphorIconsRegular.currencyInr, 'Update Price',
                      _priceSub(p), () => _edit(p, EditKind.price)),
                  _MenuRow(PhosphorIconsRegular.stack, 'Update Stock',
                      '${p.stock} in stock', () => _edit(p, EditKind.stock)),
                  _MenuRow(
                      PhosphorIconsRegular.buildings,
                      'Update B2B Details',
                      p.sellB2b ? 'MOQ ${p.moq}' : 'Not selling to vendors',
                      () => _edit(p, EditKind.b2b)),
                  _MenuRow(
                      PhosphorIconsRegular.storefront,
                      'Update B2C Details',
                      p.sellB2c
                          ? 'Selling to customers'
                          : 'Not selling to customers',
                      () => _edit(p, EditKind.b2c)),
                  _MenuRow(
                      PhosphorIconsRegular.images,
                      'Update Photos / Video',
                      '${p.images.length} photos${p.videoUrl != null ? ' · 1 video' : ''}',
                      () => context.push('/products/view/${p.id}/media'),
                      last: true),
                ]),
              ),
              const SizedBox(height: 18),
              if (p.condition != ProductCondition.newItem) ProductDevicesSection(listingId: p.id),
              _QualityCard(p: p),
              const SizedBox(height: 18),
              _DetailsCard(p: p),
              const SizedBox(height: 18),
              if (p.approval == 'APPROVED')
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AuctionButton(
                      label: p.listingStatus == 'PAUSED'
                          ? 'Resume Selling'
                          : 'Pause Product',
                      outlined: true,
                      loading: _busy,
                      icon: p.listingStatus == 'PAUSED'
                          ? PhosphorIconsRegular.play
                          : PhosphorIconsRegular.pause,
                      onPressed: () => _toggle(p)),
                ),
              AuctionButton(
                  label: 'Delete Product',
                  outlined: true,
                  danger: true,
                  icon: PhosphorIconsRegular.trash,
                  onPressed: _busy ? null : () => _delete(p)),
            ],
          ),
        ),
      ),
    );
  }

  String _priceSub(ListingDetail p) => [
        if (p.sellB2c) formatInr(p.price),
        if (p.sellB2b && p.wholesalePrice != null)
          '${formatInr(p.wholesalePrice!)} wholesale',
      ].join(' · ');
}

class _Header extends StatelessWidget {
  const _Header(
      {required this.p,
      required this.ctl,
      required this.page,
      required this.onPage});
  final ListingDetail p;
  final PageController ctl;
  final int page;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final off = discountLabel(p.price, p.mrp);
    return SectionCard(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          height: 230,
          child: Stack(children: [
            PageView(
              controller: ctl,
              onPageChanged: onPage,
              children: [
                for (final u in p.images.isEmpty ? <String?>[null] : p.images)
                  Container(
                    margin: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AppColors.cardBorder),
                        borderRadius: BorderRadius.circular(14)),
                    child: GestureDetector(
                        onTap: () => u == null
                            ? null
                            : FullscreenImageViewer.open(context,
                                images: p.images, initialIndex: p.images.indexOf(u)),
                        child: AnyImage(u, fit: BoxFit.contain, radius: 14)),
                  ),
              ],
            ),
            if (p.images.length > 1)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 0; i < p.images.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: i == page ? 18 : 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      decoration: BoxDecoration(
                          color: i == page ? kBlue : AppColors.borderStrong,
                          borderRadius: BorderRadius.circular(4)),
                    ),
                ]),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              StatePill(p.state),
              const SizedBox(width: 8),
              ChannelChips(b2b: p.sellB2b, b2c: p.sellB2c),
            ]),
            const SizedBox(height: 10),
            Text(p.name, style: heading(size: 18)),
            const SizedBox(height: 4),
            Row(children: [
              Text('${p.brand} · ',
                  style: const TextStyle(
                      fontSize: 13.5, color: AppColors.textSecondary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: switch (p.condition) {
                    ProductCondition.newItem || ProductCondition.openBox => const Color(0xFFE3F7EA),
                    ProductCondition.refurbished => const Color(0xFFE5EEFF),
                    _ => const Color(0xFFFFF1CF),
                  },
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                    p.condition.isUsed ? 'Used · ${p.condition.label}' : p.condition == ProductCondition.newItem ? 'Brand new' : p.condition.label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: switch (p.condition) {
                          ProductCondition.newItem || ProductCondition.openBox => const Color(0xFF14A241),
                          ProductCondition.refurbished => const Color(0xFF1B5BF2),
                          _ => const Color(0xFFD97706),
                        })),
              ),
            ]),
            const SizedBox(height: 10),
            if (p.sellB2c)
              Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 8,
                  children: [
                    Text(formatInr(p.price), style: heading(size: 24)),
                    if (p.mrp != null && p.mrp! > p.price) ...[
                      Text(formatInr(p.mrp!),
                          style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textMuted,
                              decoration: TextDecoration.lineThrough)),
                      Text(off,
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.mint)),
                    ],
                  ]),
            if (p.sellB2b && p.wholesalePrice != null)
              Padding(
                padding: EdgeInsets.only(top: p.sellB2c ? 6 : 0),
                child: Text(
                    '${formatInr(p.wholesalePrice!)} wholesale · MOQ ${p.moq}'
                    '${(p.discountPct ?? 0) > 0 ? ' · ${p.discountPct!.round()}% business discount' : ''}',
                    style: TextStyle(
                        fontSize: p.sellB2c ? 13.5 : 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.roleB2b)),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner(
      {required this.p,
      required this.busy,
      required this.onResume,
      required this.onFix});
  final ListingDetail p;
  final bool busy;
  final VoidCallback onResume;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    switch (p.state) {
      case ListingState.live:
        final who = [
          if (p.sellB2c) 'customers',
          if (p.sellB2b) 'vendors',
        ].join(' and ');
        return NoteBanner('Your product is live. Now $who can see it.',
            title: 'Your Product is Live!',
            icon: PhosphorIconsFill.checkCircle,
            fg: AppColors.mint,
            bg: AppColors.mintSoft);
      case ListingState.pending:
        return NoteBanner.warning(
            'Dealkr is reviewing this product — usually within 24 hours. It will go live once verified.',
            title: 'Waiting for approval');
      case ListingState.rejected:
        return NoteBanner.error(
            p.rejectionReason ??
                'This product didn’t pass review. Update it and it will be checked again.',
            title: 'Rejected',
            action: SizedBox(
              height: 40,
              child: AuctionButton(
                  label: 'Fix photos & resubmit', height: 40, onPressed: onFix),
            ));
      case ListingState.paused:
        return NoteBanner('This product is paused and hidden from buyers.',
            title: 'Paused',
            icon: PhosphorIconsFill.pauseCircle,
            fg: AppColors.textSecondary,
            bg: const Color(0xFFEDF0F6),
            action: SizedBox(
              height: 40,
              child: AuctionButton(
                  label: 'Resume selling',
                  height: 40,
                  loading: busy,
                  onPressed: onResume),
            ));
      case ListingState.outOfStock:
        return NoteBanner.warning(
            'Stock is 0, so buyers can’t order this product. Update the stock to sell again.',
            title: 'Out of stock');
    }
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label, this.sub, this.onTap,
      {this.last = false});
  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) => Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: kBlueSoft, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: 21, color: kBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy)),
                      if (sub.isNotEmpty)
                        Text(sub,
                            style: const TextStyle(
                                fontSize: 12.5, color: AppColors.textMuted)),
                    ]),
              ),
              const Icon(PhosphorIconsRegular.caretRight,
                  size: 17, color: AppColors.textMuted),
            ]),
          ),
        ),
        if (!last)
          const Divider(
              height: 1,
              indent: 66,
              endIndent: 14,
              color: AppColors.cardBorder),
      ]);
}

class _QualityCard extends StatelessWidget {
  const _QualityCard({required this.p});
  final ListingDetail p;

  @override
  Widget build(BuildContext context) {
    final cl =
        (p.vendorQc['checklist'] as Map?)?.cast<String, dynamic>() ?? const {};
    final angles = (p.vendorQc['photoAngles'] as List?)?.length ?? 0;
    final vchecks = (p.vendorQc['videoChecks'] as Map?)
            ?.values
            .where((v) => v == true)
            .length ??
        0;
    return SectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Quality check', style: heading(size: 16))),
          QcPill(p.qcStatus),
        ]),
        const SizedBox(height: 10),
        if (p.qcScore != null)
          SummaryRow('Dealkr QC score', '${p.qcScore}/100'),
        if (p.qcNotes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(p.qcNotes,
                style: const TextStyle(
                    fontSize: 13, height: 1.4, color: AppColors.textSecondary)),
          ),
        if (cl.isNotEmpty)
          SummaryRow('Your physical check', '${cl.length} items checked'),
        if (angles > 0) SummaryRow('Photo QC', '$angles sides marked'),
        if (p.videoUrl != null)
          SummaryRow('Video QC',
              vchecks > 0 ? '$vchecks checks ticked' : 'Video added'),
        if (p.qcStatus == 'QC_PENDING' || p.qcStatus.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
                'Dealkr’s own check runs automatically and after review.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
          ),
      ]),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.p});
  final ListingDetail p;

  @override
  Widget build(BuildContext context) => SectionCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Product details', style: heading(size: 16)),
          const SizedBox(height: 8),
          SummaryRow('Type', p.type.label),
          if (p.model.isNotEmpty) SummaryRow('Model', p.model),
          if (p.storage.isNotEmpty) SummaryRow('Storage', p.storage),
          SummaryRow('Condition', p.condition.label),
          if (p.conditionNotes.isNotEmpty)
            SummaryRow('Condition notes', p.conditionNotes),
          if (p.sellB2c && p.warranty.isNotEmpty)
            SummaryRow('Warranty', p.warranty),
          if (p.accessories.isNotEmpty)
            SummaryRow('Accessories', p.accessories),
          if (p.sellB2c)
            SummaryRow('Returns',
                p.returnDays == 0 ? 'No returns' : '${p.returnDays} days'),
          if (p.sellB2b && p.b2bNotes.isNotEmpty)
            SummaryRow('B2B notes', p.b2bNotes),
          SummaryRow('Added', formatDateTime(p.createdAt)),
        ]),
      );
}
