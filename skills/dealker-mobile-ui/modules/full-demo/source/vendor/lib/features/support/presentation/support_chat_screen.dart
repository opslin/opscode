import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart'
    show ErrorState, errorText;
import 'package:dealker_vendor/features/support/application/support_providers.dart';
import 'package:dealker_vendor/features/support/data/support_repository.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';
import 'package:dealker_vendor/shared/widgets/chat_ui.dart';
import 'package:dealker_vendor/core/utils/polling.dart';

/// The chat room for one support ticket. Replies from the support team arrive here (and as a notification).
class SupportChatScreen extends ConsumerStatefulWidget {
  const SupportChatScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends ConsumerState<SupportChatScreen> {
  Timer? _poll;
  SupportTicket? _ticket;
  List<SupportMessage>? _msgs;
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
      final r = await ref.read(supportRepositoryProvider).ticket(widget.id);
      if (!mounted) return;
      final changed = _msgs == null ||
          _msgs!.length != r.messages.length ||
          _ticket?.status != r.ticket.status ||
          _error != null;
      if (changed) {
        setState(() {
          _ticket = r.ticket;
          _msgs = r.messages;
          _error = null;
        });
        ref.invalidate(supportTicketsProvider); // the unread badge on the list
      }
    } catch (e) {
      if (mounted && !quiet && _msgs == null) setState(() => _error = e);
    }
  }

  Future<bool> _send(String body) async {
    setState(() => _sending = true);
    try {
      await ref.read(supportRepositoryProvider).sendMessage(widget.id, body);
      await _load();
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
    final t = _ticket;
    final m = _msgs;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: ChatHeader(
        title: 'Dealkr Support',
        subtitle: t == null ? 'Opening…' : '${t.number} · ${t.statusLabel}',
        accent: AppColors.primary,
        avatarIcon: Icons.support_agent_rounded,
      ),
      body: m == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : ErrorState(message: errorText(_error!, 'Could not open this chat.'), onRetry: _load))
          : ChatView(
              accent: AppColors.primary,
              messages: [
                for (var i = 0; i < m.length; i++)
                  ChatEntry(id: i, mine: m[i].mine, body: m[i].body, at: m[i].at),
              ],
              sending: _sending,
              canReply: !(t?.closed ?? false),
              lockedReason: 'This conversation is closed. Start a new chat from Help & support.',
              hint: 'Type a message',
              emptyText: 'Our team will reply here soon.',
              onSend: _send,
            ),
    );
  }
}
