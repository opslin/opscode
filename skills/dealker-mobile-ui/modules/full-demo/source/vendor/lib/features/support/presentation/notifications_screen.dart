import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart'
    show heading, errorText;
import 'package:dealker_vendor/features/support/application/support_providers.dart';
import 'package:dealker_vendor/features/support/data/support_repository.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

String _when(DateTime? t) {
  if (t == null) return '';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'Just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  if (d.inDays < 7) return '${d.inDays} d ago';
  return '${t.day}/${t.month}/${t.year}';
}

IconData _icon(String type) => switch (type) {
      'SUPPORT' => PhosphorIconsFill.headset,
      'RETURN' => PhosphorIconsFill.arrowUUpLeft,
      'AUCTION' => PhosphorIconsFill.gavel,
      'ORDER' || 'ORDER_UPDATE' => PhosphorIconsFill.package,
      'PAYMENT' || 'WALLET' => PhosphorIconsFill.wallet,
      _ => PhosphorIconsFill.bell,
    };

/// Profile → Notifications: everything the app told the vendor, newest first. Support replies open the chat.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, AppNotification n) async {
    final repo = ref.read(supportRepositoryProvider);
    if (!n.read) {
      try {
        await repo.markRead(n.id);
      } catch (_) {}
      ref.invalidate(notificationsProvider);
    }
    if (!context.mounted) return;
    if (n.returnId != null) {
      context.push(Routes.returnDetail(n.returnId!));
    } else if (n.ticketId != null) {
      context.push(Routes.helpChat(n.ticketId!));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(notificationsProvider);
    final unread = data.asData?.value.unread ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FB),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
            icon: const Icon(PhosphorIconsRegular.arrowLeft, color: AppColors.navy),
            onPressed: () => context.pop()),
        title: Text('Notifications', style: heading(size: 20)),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () async {
                try {
                  await ref.read(supportRepositoryProvider).markAllRead();
                  ref.invalidate(notificationsProvider);
                } catch (e) {
                  if (context.mounted) showAppToast(context, errorText(e), error: true);
                }
              },
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(notificationsProvider),
        child: data.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(children: [
                Text(errorText(e, 'Could not load notifications.'), textAlign: TextAlign.center),
                TextButton(onPressed: () => ref.invalidate(notificationsProvider), child: const Text('Retry')),
              ]),
            ),
          ]),
          data: (d) => d.items.isEmpty
              ? ListView(children: [
                  const SizedBox(height: 90),
                  Center(child: Image.asset('assets/3d/help/bell.png', width: 130, height: 130)),
                  const SizedBox(height: 12),
                  Center(child: Text('You are all caught up', style: heading(size: 18))),
                  const SizedBox(height: 4),
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40),
                      child: Text('Order updates, payments, auctions and support replies appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textMuted)),
                    ),
                  ),
                ])
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: d.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final n = d.items[i];
                    return GestureDetector(
                      onTap: () => _open(context, ref, n),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: n.read ? Colors.white : const Color(0xFFEEF4FF),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: n.read ? AppColors.cardBorder : AppColors.primary.withValues(alpha: 0.4)),
                        ),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(color: const Color(0xFFE5EEFF), borderRadius: BorderRadius.circular(12)),
                            child: Icon(_icon(n.type), color: AppColors.primary, size: 21),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.w700 : FontWeight.w800, color: AppColors.navy, fontSize: 14)),
                              if (n.body.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(n.body, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, height: 1.35, color: AppColors.textSecondary)),
                              ],
                              const SizedBox(height: 6),
                              Text(_when(n.at), style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                            ]),
                          ),
                          if (!n.read)
                            Container(
                                margin: const EdgeInsets.only(top: 6, left: 6),
                                width: 9,
                                height: 9,
                                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
