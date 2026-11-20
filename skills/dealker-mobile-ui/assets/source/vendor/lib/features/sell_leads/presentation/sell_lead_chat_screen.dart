import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart';
import 'package:dealker_vendor/features/sell_leads/application/sell_lead_providers.dart';
import 'package:dealker_vendor/features/sell_leads/data/sell_lead_models.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';
import 'package:dealker_vendor/shared/widgets/chat_ui.dart';
import 'package:dealker_vendor/core/utils/polling.dart';

const _quick = <String>[
  'Is the phone still under warranty?',
  'Is the battery health above 85%?',
  'Can you share more photos?',
  'Any scratches or repairs done?',
];

/// Chat with the seller of one phone. The seller shows up only as "Seller" until they accept an offer.
class SellLeadChatScreen extends ConsumerStatefulWidget {
  const SellLeadChatScreen({required this.id, super.key});
  final String id;

  @override
  ConsumerState<SellLeadChatScreen> createState() => _SellLeadChatScreenState();
}

class _SellLeadChatScreenState extends ConsumerState<SellLeadChatScreen> {
  Timer? _poll;
  LeadThread? _thread;
  Object? _error;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted && screenActive(context)) _load(quiet: true);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    try {
      final t = await ref.read(sellLeadRepositoryProvider).thread(widget.id);
      if (!mounted) return;
      // Only rebuild when something changed, so typing and scrolling are never interrupted.
      final old = _thread;
      if (old == null ||
          old.messages.length != t.messages.length ||
          old.canReply != t.canReply ||
          _error != null) {
        setState(() {
          _thread = t;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && !quiet && _thread == null) setState(() => _error = e);
    }
  }

  Future<bool> _send(String body) async {
    setState(() => _sending = true);
    try {
      final t = await ref.read(sellLeadRepositoryProvider).send(widget.id, body);
      if (!mounted) return true;
      setState(() => _thread = t);
      return true;
    } catch (e) {
      if (mounted) showAppToast(context, errorText(e), error: true);
      return false;
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _thread;
    final lead = ref.watch(sellLeadProvider(widget.id)).value;
    final accepted = lead?.deal != null && lead?.myOfferStatus == 'ACCEPTED';
    final name = accepted && lead!.deal!.sellerName.isNotEmpty ? lead.deal!.sellerName : 'Seller';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: ChatHeader(
        title: name,
        subtitle: lead == null ? 'Chat about this phone' : lead.title,
        accent: AppColors.violet,
        avatarIcon: PhosphorIconsFill.user,
        initial: accepted && name != 'Seller' ? name.substring(0, 1) : null,
      ),
      body: t == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : ErrorState(message: errorText(_error!, 'Could not open this chat.'), onRetry: _load))
          : ChatView(
              accent: AppColors.violet,
              messages: [
                for (final m in t.messages) ChatEntry(id: m.id, mine: m.mine, body: m.body, at: m.at)
              ],
              canReply: t.canReply,
              lockedReason: t.lockedReason,
              sending: _sending,
              quickReplies: _quick,
              hint: 'Message the seller',
              emptyText: 'Ask the seller about the phone before you offer.\nThey reply here.',
              onSend: _send,
            ),
    );
  }
}
