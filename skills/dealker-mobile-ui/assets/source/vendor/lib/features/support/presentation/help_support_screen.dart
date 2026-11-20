import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart'
    show heading, errorText;
import 'package:dealker_vendor/features/support/application/support_providers.dart';
import 'package:dealker_vendor/features/support/data/support_repository.dart';
import 'package:dealker_vendor/features/support/presentation/faq_data.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

String _ago(DateTime? t) {
  if (t == null) return '';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  return '${d.inDays}d';
}

/// Profile → Help & support: talk to support (chat room with a ticket number), call, email, and answers
/// to the questions every vendor asks.
class HelpSupportScreen extends ConsumerWidget {
  const HelpSupportScreen({super.key});

  Future<void> _launch(BuildContext context, Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
        showAppToast(context, 'Could not open this on your device.', error: true);
      }
    } catch (_) {
      if (context.mounted) showAppToast(context, 'Could not open this on your device.', error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contact = ref.watch(supportContactProvider);
    final tickets = ref.watch(supportTicketsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FB),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
            icon: const Icon(PhosphorIconsRegular.arrowLeft, color: AppColors.navy),
            onPressed: () => context.pop()),
        title: Text('Help & support', style: heading(size: 20)),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(supportContactProvider);
          ref.invalidate(supportTicketsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            _Hero(onChat: () => context.push(Routes.helpNew)),
            const SizedBox(height: 14),
            contact.when(
              loading: () => const SizedBox(height: 90, child: Center(child: CircularProgressIndicator())),
              // contact details are a bonus: if they cannot load, chat and the FAQ still work
              error: (_, __) => const SizedBox.shrink(),
              data: (c) => _ContactRow(
                contact: c,
                onCall: c.phone == null ? null : () => _launch(context, Uri(scheme: 'tel', path: c.phone)),
                onMail: c.email == null ? null : () => _launch(context, Uri(scheme: 'mailto', path: c.email)),
              ),
            ),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(child: Text('Your conversations', style: heading(size: 18))),
              TextButton(onPressed: () => context.push(Routes.helpNew), child: const Text('New chat')),
            ]),
            const SizedBox(height: 6),
            tickets.when(
              loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
              error: (e, _) => _Soft(errorText(e, 'Could not load your conversations.')),
              data: (list) => list.isEmpty
                  ? const _Soft('No conversations yet. Start a chat and we will reply here, with a ticket number you can quote.')
                  : Column(children: [for (final t in list.take(6)) _TicketTile(t: t)]),
            ),
            const SizedBox(height: 22),
            Text('Quick answers', style: heading(size: 18)),
            const SizedBox(height: 10),
            for (final topic in faqTopics) _FaqCard(topic: topic),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onChat});
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 10, 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF5B4BEA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('How can we help?',
                  style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Chat with our team. Tell us the problem and we will reply here.',
                  style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.35)),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onChat,
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                icon: const Icon(PhosphorIconsFill.chatCircleDots, size: 19),
                label: const Text('Chat with support', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
          Image.asset('assets/3d/help/headset.png', width: 108, height: 108),
        ]),
      );
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.contact, this.onCall, this.onMail});
  final SupportContact contact;
  final VoidCallback? onCall;
  final VoidCallback? onMail;

  @override
  Widget build(BuildContext context) {
    Widget card(String asset, String title, String sub, VoidCallback? tap) => Expanded(
          child: GestureDetector(
            onTap: tap,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.cardBorder)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Image.asset(asset, width: 44, height: 44),
                const SizedBox(height: 6),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy, fontSize: 14)),
                const SizedBox(height: 2),
                Text(sub,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.3)),
              ]),
            ),
          ),
        );

    return Column(children: [
      Row(children: [
        if (contact.phone != null) card('assets/3d/help/call.png', 'Call us', contact.phone!, onCall),
        if (contact.phone != null && contact.email != null) const SizedBox(width: 10),
        if (contact.email != null) card('assets/3d/help/mail.png', 'Email us', contact.email!, onMail),
      ]),
      if (contact.hours != null) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder)),
          child: Row(children: [
            Image.asset('assets/3d/help/hours.png', width: 34, height: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Support hours: ${contact.hours}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.navy)),
            ),
          ]),
        ),
      ],
    ]);
  }
}

class _TicketTile extends StatelessWidget {
  const _TicketTile({required this.t});
  final SupportTicket t;

  @override
  Widget build(BuildContext context) {
    final color = t.resolved ? AppColors.mint : (t.status == 'OPEN' ? AppColors.amber : AppColors.primary);
    return GestureDetector(
      onTap: () => context.push(Routes.helpChat(t.id)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.unread > 0 ? AppColors.primary : AppColors.cardBorder)),
        child: Row(children: [
          Image.asset('assets/3d/help/ticket.png', width: 42, height: 42),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(t.number, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                  child: Text(t.statusLabel, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color)),
                ),
              ]),
              const SizedBox(height: 3),
              Text(t.subject, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy)),
              if (t.preview != null)
                Text(t.preview!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_ago(t.lastAt ?? t.createdAt), style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
            if (t.unread > 0) ...[
              const SizedBox(height: 4),
              CircleAvatar(radius: 10, backgroundColor: AppColors.primary, child: Text('${t.unread}', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w800))),
            ],
          ]),
        ]),
      ),
    );
  }
}

class _FaqCard extends StatelessWidget {
  const _FaqCard({required this.topic});
  final FaqTopic topic;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.cardBorder)),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            leading: Image.asset(topic.asset, width: 38, height: 38),
            title: Text(topic.title, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy)),
            children: [
              for (final f in topic.items) _Qa(item: f),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => context.push(Routes.helpNew),
                  icon: const Icon(PhosphorIconsRegular.chatCircleDots, size: 18),
                  label: const Text('Still stuck? Chat with us'),
                ),
              ),
            ],
          ),
        ),
      );
}

class _Qa extends StatelessWidget {
  const _Qa({required this.item});
  final FaqItem item;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.q, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.navy)),
          const SizedBox(height: 3),
          Text(item.a, style: const TextStyle(fontSize: 13, height: 1.45, color: AppColors.textSecondary)),
        ]),
      );
}

class _Soft extends StatelessWidget {
  const _Soft(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder)),
        child: Row(children: [
          Image.asset('assets/3d/help/chat.png', width: 40, height: 40),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary))),
        ]),
      );
}
