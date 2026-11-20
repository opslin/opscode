import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:dealker_app/shared/widgets/loading/dealker_page_loader.dart';
import 'package:dealker_app/core/utils/app_toast.dart';
import 'package:dealker_app/features/orders/domain/entities/order_entity.dart';
import 'package:dealker_app/features/refund_requests/data/return_chat_repository.dart';
import 'package:dealker_app/features/refund_requests/domain/entities/refund_request_status_entity.dart';
import 'package:dealker_app/features/refund_requests/presentation/providers/return_providers.dart';
import 'package:dealker_app/features/refund_requests/presentation/widgets/return_ui.dart';

/// Chat with the Dealkr team about one return (the support conversation linked to the refund request).
/// The conversation is created with the first message; new replies arrive by polling while the screen is open.
class ReturnChatScreen extends ConsumerStatefulWidget {
  const ReturnChatScreen({
    required this.request,
    required this.order,
    super.key,
  });

  final RefundRequestStatusEntity request;
  final OrderEntity order;

  @override
  ConsumerState<ReturnChatScreen> createState() => _ReturnChatScreenState();
}

class _ReturnChatScreenState extends ConsumerState<ReturnChatScreen> {
  final TextEditingController _text = TextEditingController();
  final ScrollController _scroll = ScrollController();
  ReturnChatThread? _thread;
  Object? _error;
  bool _loading = true;
  bool _sending = false;
  Timer? _poll;
  int _lastCount = 0;

  ReturnChatRepository get _repo => ref.read(returnChatRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 8), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final ReturnChatThread? t = await _repo.find(widget.request.id);
      if (!mounted) return;
      setState(() {
        _thread = t;
        _loading = false;
        _error = null;
      });
      _scrollIfNew();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    final ReturnChatThread? cur = _thread;
    if (cur == null || _sending) return;
    try {
      final ReturnChatThread t = await _repo.open(cur.ticketId);
      if (!mounted) return;
      setState(() => _thread = t);
      _scrollIfNew();
    } catch (_) {
      // Transient — the next tick retries.
    }
  }

  void _scrollIfNew() {
    final int n = _thread?.messages.length ?? 0;
    if (n == _lastCount) return;
    _lastCount = n;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final String body = _text.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final ReturnChatThread? cur = _thread;
      ReturnChatThread next;
      if (cur == null) {
        next = await _repo.start(
          orderId: widget.order.id,
          refundRequestId: widget.request.id,
          returnNumber: widget.request.returnNumber ?? widget.order.orderNumber,
          message: body,
        );
      } else {
        await _repo.send(cur.ticketId, body);
        next = await _repo.open(cur.ticketId);
      }
      _text.clear();
      if (mounted) setState(() => _thread = next);
      _scrollIfNew();
    } catch (e) {
      if (mounted) AppToast.show(context, ReturnChatRepository.errorMessage(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ReturnChatThread? t = _thread;
    return ReturnScaffold(
      title: 'Chat with Support',
      bottom: t?.isClosed == true
          ? Text(
              'This conversation is closed.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.sp, color: ReturnColors.muted),
            )
          : Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _text,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    style: TextStyle(fontSize: 13.sp),
                    decoration: InputDecoration(
                      hintText: 'Type your message',
                      filled: true,
                      fillColor: ReturnColors.indigoSoft.withValues(alpha: 0.5),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 10.h,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22.r),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22.r),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22.r),
                        borderSide: const BorderSide(
                          color: ReturnColors.indigoLine,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                SizedBox(
                  width: 44.w,
                  height: 44.w,
                  child: ElevatedButton(
                    onPressed: _sending ? null : _send,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: ReturnColors.indigo,
                      foregroundColor: Colors.white,
                      shape: const CircleBorder(),
                      elevation: 0,
                    ),
                    child: _sending
                        ? SizedBox(
                            width: 18.w,
                            height: 18.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(Icons.send_rounded, size: 20.sp),
                  ),
                ),
              ],
            ),
      child: _loading
          ? const DealkerPageLoader()
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(ReturnChatRepository.errorMessage(_error!)),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _error = null;
                          });
                          _load();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _body(t),
    );
  }

  Widget _body(ReturnChatThread? t) {
    if (t == null || t.messages.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.forum_outlined,
                size: 44.sp,
                color: ReturnColors.indigoLine,
              ),
              SizedBox(height: 12.h),
              Text(
                'Talk to the Dealkr team',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  color: ReturnColors.ink,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                'Ask about your return ${widget.request.returnNumber ?? ''}. Your message goes straight to the team reviewing it.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.sp,
                  height: 1.4,
                  color: ReturnColors.muted,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: EdgeInsets.fromLTRB(14.w, 16.h, 14.w, 16.h),
      itemCount: t.messages.length,
      itemBuilder: (BuildContext c, int i) => _Bubble(message: t.messages[i]),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ReturnChatMessage message;

  @override
  Widget build(BuildContext context) {
    final bool mine = message.fromCustomer;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        constraints: BoxConstraints(maxWidth: 0.78.sw),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: mine ? ReturnColors.indigo : const Color(0xFFF1F2F8),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(14.r),
            topRight: Radius.circular(14.r),
            bottomLeft: Radius.circular(mine ? 14.r : 4.r),
            bottomRight: Radius.circular(mine ? 4.r : 14.r),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (!mine)
              Padding(
                padding: EdgeInsets.only(bottom: 2.h),
                child: Text(
                  message.senderName ?? 'Dealkr Support',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: ReturnColors.indigo,
                  ),
                ),
              ),
            Text(
              message.body,
              style: TextStyle(
                fontSize: 12.5.sp,
                height: 1.35,
                color: mine ? Colors.white : ReturnColors.ink,
              ),
            ),
            SizedBox(height: 3.h),
            Text(
              DateFormat('dd MMM, hh:mm a').format(message.at),
              style: TextStyle(
                fontSize: 9.sp,
                color: mine ? Colors.white70 : ReturnColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
