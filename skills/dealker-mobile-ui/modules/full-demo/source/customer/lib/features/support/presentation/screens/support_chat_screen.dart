import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_app/core/theme/app_colors.dart';
import 'package:dealker_app/core/theme/app_text_styles.dart';
import 'package:dealker_app/core/utils/app_toast.dart';
import 'package:dealker_app/features/refund_requests/data/return_chat_repository.dart';
import 'package:dealker_app/features/refund_requests/presentation/providers/return_providers.dart';
import 'package:dealker_app/routing/route_names.dart';

/// General "Chat with Support" conversation, opened from the Account screen.
/// Continues the customer's latest open general ticket, or starts one with
/// the first message. Replies arrive by polling while the screen is open.
class SupportChatScreen extends ConsumerStatefulWidget {
  const SupportChatScreen({this.orderNumber, this.topic, super.key});

  /// Order the customer is asking about (from Order Details); goes into the ticket subject.
  final String? orderNumber;

  /// Pre-filled first message, e.g. "Where is my order?".
  final String? topic;

  @override
  ConsumerState<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends ConsumerState<SupportChatScreen> {
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
    final String? t = widget.topic;
    if (t != null && t.isNotEmpty) {
      _text.text =
          widget.orderNumber != null ? '$t (Order ${widget.orderNumber})' : t;
    }
    unawaited(_load());
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
      final ReturnChatThread? t = await _repo.findGeneral();
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
        unawaited(
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          ),
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
        next = await _repo.startGeneral(body, orderNumber: widget.orderNumber);
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
    return Scaffold(
      backgroundColor: AppColors.bgCard,
      appBar: AppBar(
        backgroundColor: AppColors.bgCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: PhosphorIcon(
            PhosphorIcons.caretLeft,
            size: 20.sp,
            color: AppColors.textPrimary,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(RouteNames.profile);
            }
          },
        ),
        title:
            Text('Support', style: AppTextStyles.h2.copyWith(fontSize: 18.sp)),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(child: _content()),
            _composer(),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.orderViolet),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              ReturnChatRepository.errorMessage(_error!),
              style: AppTextStyles.bodyMedium,
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                unawaited(_load());
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    final ReturnChatThread? t = _thread;
    if (t == null || t.messages.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              PhosphorIcon(
                PhosphorIcons.chatCircleDotsLight,
                size: 44.sp,
                color: AppColors.orderViolet,
              ),
              SizedBox(height: 12.h),
              Text(
                'How can we help?',
                style: AppTextStyles.h2.copyWith(fontSize: 17.sp),
              ),
              SizedBox(height: 6.h),
              Text(
                'Send us a message about an order, payment or anything else. '
                'Our team will reply here.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontSize: 13.sp,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
      itemCount: t.messages.length,
      itemBuilder: (BuildContext c, int i) => _Bubble(message: t.messages[i]),
    );
  }

  Widget _composer() {
    if (_thread?.isClosed == true) {
      return Padding(
        padding: EdgeInsets.all(16.w),
        child: Text(
          'This conversation is closed.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall,
        ),
      );
    }
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 10.h),
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _text,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              style: AppTextStyles.bodyMedium.copyWith(fontSize: 14.sp),
              decoration: InputDecoration(
                hintText: 'Type your message',
                filled: true,
                fillColor: AppColors.bgInput,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24.r),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24.r),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24.r),
                  borderSide: const BorderSide(color: AppColors.orderViolet),
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
                backgroundColor: AppColors.orderViolet,
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
                  : PhosphorIcon(
                      PhosphorIcons.paperPlaneTiltFill,
                      size: 18.sp,
                      color: Colors.white,
                    ),
            ),
          ),
        ],
      ),
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
          color: mine ? AppColors.orderViolet : AppColors.orderCanvas,
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
                    color: AppColors.orderViolet,
                  ),
                ),
              ),
            Text(
              message.body,
              style: TextStyle(
                fontSize: 13.sp,
                height: 1.35,
                color: mine ? Colors.white : AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 3.h),
            Text(
              DateFormat('dd MMM, hh:mm a').format(message.at),
              style: TextStyle(
                fontSize: 9.5.sp,
                color: mine ? Colors.white70 : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
