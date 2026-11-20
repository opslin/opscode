import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_app/core/theme/repair_tokens.dart';
import 'package:dealker_app/core/utils/server_error.dart';
import 'package:dealker_app/features/repair/presentation/widgets/repair_helpers.dart';
import 'package:dealker_app/features/repair/presentation/widgets/repair_ui.dart';
import 'package:dealker_app/features/repair/repair_providers.dart';

/// Chat with the shop that was chosen for this repair.
class RepairChatScreen extends ConsumerStatefulWidget {
  const RepairChatScreen({required this.repairId, super.key});

  final String repairId;

  @override
  ConsumerState<RepairChatScreen> createState() => _RepairChatScreenState();
}

class _RepairChatScreenState extends ConsumerState<RepairChatScreen> {
  final TextEditingController _text = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Timer? _poll;
  List<RepairMessage>? _msgs;
  Object? _error;
  bool _sending = false;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(
        const Duration(seconds: 5), (Timer _) => _load(quiet: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    try {
      final List<RepairMessage> m =
          await ref.read(repairApiProvider).messages(widget.repairId);
      if (!mounted) return;
      setState(() {
        _msgs = m;
        _error = null;
      });
      if (m.length != _count) {
        _count = m.length;
        WidgetsBinding.instance.addPostFrameCallback((Duration _) {
          if (_scroll.hasClients) {
            _scroll.animateTo(_scroll.position.maxScrollExtent,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut);
          }
        });
      }
      ref.invalidate(repairRequestProvider(widget.repairId));
    } catch (e) {
      if (mounted && !quiet) setState(() => _error = e);
    }
  }

  Future<void> _send([String? preset]) async {
    final String body = (preset ?? _text.text).trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(repairApiProvider).sendMessage(widget.repairId, body);
      _text.clear();
      await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ServerError.from(e).message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String shop = ref
            .watch(repairRequestProvider(widget.repairId))
            .asData
            ?.value
            .serviceCenter ??
        'Repair shop';
    final List<RepairMessage>? m = _msgs;
    return RepairShell(
      title: shop,
      showSupport: false,
      onBack: () => context.canPop()
          ? context.pop()
          : context.go('/repair/${widget.repairId}'),
      body: m == null
          ? (_error == null
              ? const RSkeletonCards()
              : RErrorView(offline: isOfflineError(_error!), onRetry: _load))
          : Column(
              children: <Widget>[
                Expanded(
                  child: m.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                                'Ask the shop anything about your repair. They reply here.',
                                textAlign: TextAlign.center,
                                style: rtBody(14.5)),
                          ),
                        )
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(
                              RT.gutter, 12, RT.gutter, 12),
                          itemCount: m.length,
                          itemBuilder: (BuildContext _, int i) => Align(
                            alignment: m[i].mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.sizeOf(context).width * 0.74),
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                  color: m[i].mine ? RT.blue : RT.field,
                                  borderRadius: BorderRadius.circular(14)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: <Widget>[
                                  Text(m[i].body,
                                      style: rtBody(14.5,
                                          color: m[i].mine
                                              ? Colors.white
                                              : RT.ink)),
                                  if (m[i].at != null)
                                    Text(fmtTime(m[i].at!),
                                        style: rtBody(10.5,
                                            color: m[i].mine
                                                ? Colors.white70
                                                : RT.muted)),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _text,
                            minLines: 1,
                            maxLines: 3,
                            maxLength: 1000,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: 'Type a message',
                              counterText: '',
                              filled: true,
                              fillColor: RT.field,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _sending ? null : _send,
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: const BoxDecoration(
                                color: RT.blue, shape: BoxShape.circle),
                            child: const PhosphorIcon(
                                PhosphorIconsFill.paperPlaneTilt,
                                color: Colors.white,
                                size: 22),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
