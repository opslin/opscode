import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/core/utils/polling.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart'
    show ErrorState, errorText;
import 'package:dealker_vendor/features/returns/application/returns_providers.dart';
import 'package:dealker_vendor/features/support/application/support_providers.dart';
import 'package:dealker_vendor/features/support/data/support_repository.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';
import 'package:dealker_vendor/shared/widgets/chat_ui.dart';

/// Chat with Dealkr Support about one return. The conversation is created with the first message
/// (same as the customer app's return chat); replies from the team arrive here and as a notification.
class ReturnChatScreen extends ConsumerStatefulWidget {
  const ReturnChatScreen({super.key, required this.returnId});
  final String returnId;

  @override
  ConsumerState<ReturnChatScreen> createState() => _ReturnChatScreenState();
}

class _ReturnChatScreenState extends ConsumerState<ReturnChatScreen> {
  Timer? _poll;
  String? _ticketId;
  String _subtitle = 'Opening…';
  bool _closed = false;
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
      if (_ticketId == null) {
        final d = await ref.read(returnsRepositoryProvider).detail(widget.returnId);
        if (!mounted) return;
        final chat = d.chat;
        if (chat == null) {
          setState(() {
            _msgs = const [];
            _subtitle = '${d.row.returnNumber} · Order ${d.row.orderNumber}';
            _error = null;
          });
          return;
        }
        _ticketId = chat.ticketId;
      }
      final r = await ref.read(supportRepositoryProvider).ticket(_ticketId!);
      if (!mounted) return;
      final changed = _msgs == null || _msgs!.length != r.messages.length || _closed != r.ticket.closed || _error != null;
      if (changed) {
        setState(() {
          _msgs = r.messages;
          _closed = r.ticket.closed;
          _subtitle = '${r.ticket.number} · ${r.ticket.statusLabel}';
          _error = null;
        });
        ref.invalidate(returnsSummaryProvider);
        ref.invalidate(supportTicketsProvider);
      }
    } catch (e) {
      if (mounted && !quiet && _msgs == null) setState(() => _error = e);
    }
  }

  Future<bool> _send(String body) async {
    setState(() => _sending = true);
    try {
      if (_ticketId == null) {
        final ref0 = await ref.read(returnsRepositoryProvider).openChat(widget.returnId, message: body);
        _ticketId = ref0.ticketId;
      } else {
        await ref.read(supportRepositoryProvider).sendMessage(_ticketId!, body);
      }
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
    final m = _msgs;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: ChatHeader(
        title: 'Dealkr Support',
        subtitle: _subtitle,
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
                for (var i = 0; i < m.length; i++) ChatEntry(id: i, mine: m[i].mine, body: m[i].body, at: m[i].at),
              ],
              sending: _sending,
              canReply: !_closed,
              lockedReason: 'This conversation is closed. Open the return and start a new chat.',
              hint: 'Message Dealkr about this return',
              emptyText: 'Ask Dealkr anything about this return — what the customer said, the pickup, or your proof.',
              quickReplies: _ticketId == null
                  ? const [
                      'I want to share my packing proof.',
                      'The customer’s claim does not match what I shipped.',
                      'When will the item come back to me?',
                    ]
                  : const [],
              onSend: _send,
            ),
    );
  }
}
