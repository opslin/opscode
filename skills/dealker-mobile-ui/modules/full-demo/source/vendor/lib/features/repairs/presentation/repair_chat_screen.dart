import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart'
    show ErrorState, errorText;
import 'package:dealker_vendor/features/repairs/application/repairs_providers.dart';
import 'package:dealker_vendor/features/repairs/data/repair_models.dart';
import 'package:dealker_vendor/features/repairs/presentation/repair_ui.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';
import 'package:dealker_vendor/shared/widgets/chat_ui.dart';
import 'package:dealker_vendor/core/utils/polling.dart';

const _quick = <String>[
  'Your phone is ready for pickup.',
  'We need your approval to continue.',
  'Can you share more details?'
];

/// Chat with the customer of one repair (opens once the customer has chosen this shop).
class RepairChatScreen extends ConsumerStatefulWidget {
  const RepairChatScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<RepairChatScreen> createState() => _RepairChatScreenState();
}

class _RepairChatScreenState extends ConsumerState<RepairChatScreen> {
  Timer? _poll;
  List<ChatMessage>? _msgs;
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
      final m = await ref.read(repairsRepositoryProvider).messages(widget.id);
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
      await ref.read(repairsRepositoryProvider).sendMessage(widget.id, body);
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
    final job = ref.watch(jobProvider(widget.id)).value;
    final m = _msgs;
    final name = job?.customerName.isEmpty ?? true ? 'Customer' : job!.customerName;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: ChatHeader(
        title: name,
        subtitle: job == null ? 'Chat about this repair' : 'Repair #${job.code}',
        accent: RC.blue,
        initial: name.substring(0, 1),
        actions: [
          if (job != null && job.customerPhone.isNotEmpty)
            IconButton(
                onPressed: () => callPhone(context, job.customerPhone),
                icon: const Icon(PhosphorIconsFill.phone, color: Colors.white)),
        ],
      ),
      body: m == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : ErrorState(message: errorText(_error!, 'Could not open this chat.'), onRetry: _load))
          : ChatView(
              accent: RC.blue,
              messages: [for (final x in m) ChatEntry(id: x.id, mine: x.mine, body: x.body, at: x.at)],
              sending: _sending,
              quickReplies: _quick,
              showQuickAlways: true,
              hint: 'Type a message',
              emptyText: 'Say hello. Tell the customer how their repair is going.',
              onSend: _send,
            ),
    );
  }
}
