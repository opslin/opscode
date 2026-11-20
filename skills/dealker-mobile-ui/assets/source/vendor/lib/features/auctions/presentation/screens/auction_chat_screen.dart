import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_vendor/features/auctions/application/auction_providers.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart'
    show ErrorState, errorText, kAuctionBlue;
import 'package:dealker_vendor/shared/widgets/app_toast.dart';
import 'package:dealker_vendor/shared/widgets/chat_ui.dart';
import 'package:dealker_vendor/core/utils/polling.dart';

const _quick = <String>[
  'Congratulations on winning! Please complete the payment.',
  'Your order is packed and will ship soon.',
  'Can you confirm your delivery address?'
];

/// Chat between the selling vendor and the winning buyer of one auction.
class AuctionChatScreen extends ConsumerStatefulWidget {
  const AuctionChatScreen({super.key, required this.id, this.title});
  final String id;
  final String? title;

  @override
  ConsumerState<AuctionChatScreen> createState() => _AuctionChatScreenState();
}

class _AuctionChatScreenState extends ConsumerState<AuctionChatScreen> {
  Timer? _poll;
  List<ChatEntry>? _msgs;
  Object? _error;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
    _poll =
        Timer.periodic(const Duration(seconds: 4), (_) {
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
      final m = await ref.read(auctionRepositoryProvider).chat(widget.id);
      if (!mounted) return;
      if (_msgs == null || _msgs!.length != m.length || _error != null) {
        setState(() {
          _msgs = m;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && !quiet && _msgs == null) setState(() => _error = e);
    }
  }

  Future<bool> _send(String body) async {
    setState(() => _sending = true);
    try {
      await ref.read(auctionRepositoryProvider).sendChat(widget.id, body);
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
        title: 'Buyer',
        subtitle: widget.title ?? 'Chat about this auction',
        accent: kAuctionBlue,
        initial: 'B',
      ),
      body: m == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : ErrorState(
                      message: errorText(_error!, 'Could not open this chat.'),
                      onRetry: _load))
          : ChatView(
              accent: kAuctionBlue,
              messages: m,
              sending: _sending,
              quickReplies: _quick,
              showQuickAlways: true,
              hint: 'Type a message',
              emptyText:
                  'Say hello. Tell the buyer about payment, packing and delivery.',
              onSend: _send,
            ),
    );
  }
}
