import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:dealker_app/core/utils/app_toast.dart';
import 'package:dealker_app/features/sell_phone/data/sell_models.dart';
import 'package:dealker_app/features/sell_phone/data/sell_repository.dart';
import 'package:dealker_app/features/sell_phone/presentation/sell_providers.dart';
import 'package:dealker_app/core/theme/repair_tokens.dart';
import 'package:dealker_app/features/sell_phone/presentation/sell_ui.dart';

/// Conversation with one buyer about their offer. Phone numbers are blocked by the server until an offer is accepted.
class SellChatScreen extends ConsumerStatefulWidget {
  const SellChatScreen({
    required this.requestId,
    required this.vendorId,
    super.key,
  });
  final String requestId;
  final String vendorId;

  @override
  ConsumerState<SellChatScreen> createState() => _SellChatScreenState();
}

class _SellChatScreenState extends ConsumerState<SellChatScreen> {
  final TextEditingController _text = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Timer? _poll;
  SellThread? _thread;
  Object? _error;
  bool _sending = false;
  bool _emoji = false;
  final FocusNode _focus = FocusNode();
  int _lastCount = 0;

  static const List<String> _emojis = <String>[
    '😀', '😁', '😂', '🙂', '😊', '😍', '🤝', '🙏', '👍', '👌', '🔥', '🎉',
    '💰', '💸', '📱', '✅', '❌', '🤔', '😅', '😉', '🙌', '👏', '⏰', '📍',
    '🚚', '🔋', '📦', '💯', '❤️', '😢', '😎', '🤗',
  ];

  void _insertEmoji(String e) {
    final TextSelection sel = _text.selection;
    final String t = _text.text;
    final int start = sel.isValid ? sel.start : t.length;
    final int end = sel.isValid ? sel.end : t.length;
    _text.value = TextEditingValue(
      text: t.replaceRange(start, end, e),
      selection: TextSelection.collapsed(offset: start + e.length),
    );
    setState(() {});
  }

  static const List<String> _quick = <String>[
    'Can you improve your offer?',
    'When can you pick it up?',
    'Is the price final after inspection?',
  ];

  @override
  void initState() {
    super.initState();
    _load();
    // New replies arrive while the customer has the chat open.
    _poll =
        Timer.periodic(const Duration(seconds: 3), (_) => _load(quiet: true));
    _focus.addListener(() {
      if (_focus.hasFocus && _emoji) setState(() => _emoji = false);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _text.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    try {
      final SellThread t = await ref
          .read(sellRepositoryProvider)
          .thread(widget.requestId, widget.vendorId);
      if (!mounted) return;
      setState(() {
        _thread = t;
        _error = null;
      });
      _afterUpdate(t);
    } catch (e) {
      if (mounted && !quiet) setState(() => _error = e);
    }
  }

  void _afterUpdate(SellThread t) {
    if (t.messages.length != _lastCount) {
      _lastCount = t.messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _send([String? preset]) async {
    final String body = (preset ?? _text.text).trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final SellThread t = await ref
          .read(sellRepositoryProvider)
          .sendMessage(widget.requestId, widget.vendorId, body);
      if (!mounted) return;
      _text.clear();
      setState(() => _thread = t);
      _afterUpdate(t);
      ref.invalidate(sellThreadsProvider(widget.requestId));
      ref.invalidate(sellOffersProvider(widget.requestId));
    } catch (e) {
      if (mounted) AppToast.show(context, sellErrorMessage(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final SellThread? t = _thread;
    return SellScaffold(
      title: t?.vendorName ?? 'Chat',
      onBack: () => context.canPop()
          ? context.pop()
          : context.go('/sell/${widget.requestId}/offers'),
      child: t == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator(color: ReturnColors.indigo)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          sellErrorMessage(
                              _error!, 'Could not open this chat.'),
                          style: TextStyle(fontSize: 14.sp),
                        ),
                        TextButton(
                            onPressed: _load, child: const Text('Try again')),
                      ],
                    ),
            )
          : Column(
              children: <Widget>[
                _offerHeader(t),
                Expanded(child: _messages(t)),
                _composer(t),
              ],
            ),
    );
  }

  Widget _offerHeader(SellThread t) {
    final bool accepted = t.offerStatus == 'ACCEPTED';
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 4.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: ReturnColors.indigoSoft,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: ReturnColors.indigoLine),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.storefront_rounded,
              color: ReturnColors.indigo, size: 22.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(t.offerAmount != null ? 'Their offer' : 'No offer yet',
                    style:
                        TextStyle(fontSize: 11.sp, color: ReturnColors.muted)),
                if (t.offerAmount != null)
                  Text(
                    inr(t.offerAmount!),
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontFamily: RT.head,
                      fontWeight: FontWeight.w900,
                      color: ReturnColors.ink,
                    ),
                  ),
              ],
            ),
          ),
          if (accepted)
            _pill('Accepted', ReturnColors.green, ReturnColors.greenSoft)
          else if (t.offerStatus == 'DECLINED')
            _pill('Not selected', ReturnColors.muted, ReturnColors.line),
        ],
      ),
    );
  }

  Widget _pill(String text, Color fg, Color bg) => Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10.r)),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11.sp,
            fontFamily: RT.head,
            fontWeight: FontWeight.w800,
            color: fg,
          ),
        ),
      );

  Widget _messages(SellThread t) {
    if (t.messages.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 38.sp,
                color: ReturnColors.indigoLine,
              ),
              SizedBox(height: 10.h),
              Text(
                'Start the conversation',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontFamily: RT.head,
                  fontWeight: FontWeight.w800,
                  color: ReturnColors.ink,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'Ask about the offer, pickup or payment. Keep phone numbers out of the chat until you accept an offer.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5.sp,
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
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 10.h),
      itemCount: t.messages.length,
      itemBuilder: (BuildContext _, int i) {
        final SellChatMessage m = t.messages[i];
        final bool newDay = i == 0 || !_sameDay(t.messages[i - 1].at, m.at);
        return Column(
          children: <Widget>[
            if (newDay && m.at != null)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: Text(DateFormat('d MMM').format(m.at!.toLocal()),
                    style:
                        TextStyle(fontSize: 11.sp, color: ReturnColors.muted)),
              ),
            _bubble(m),
          ],
        );
      },
    );
  }

  bool _sameDay(DateTime? a, DateTime? b) =>
      a != null &&
      b != null &&
      a.toLocal().year == b.toLocal().year &&
      a.toLocal().month == b.toLocal().month &&
      a.toLocal().day == b.toLocal().day;

  Widget _bubble(SellChatMessage m) {
    final bool me = m.mine;
    return Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: 270.w),
        margin: EdgeInsets.only(bottom: 6.h),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: me ? ReturnColors.indigo : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(14.r),
            topRight: Radius.circular(14.r),
            bottomLeft: Radius.circular(me ? 14.r : 4.r),
            bottomRight: Radius.circular(me ? 4.r : 14.r),
          ),
          border: me ? null : Border.all(color: ReturnColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                m.body,
                style: TextStyle(
                  fontSize: 13.5.sp,
                  height: 1.35,
                  color: me ? Colors.white : ReturnColors.ink,
                ),
              ),
            ),
            if (m.at != null)
              Padding(
                padding: EdgeInsets.only(top: 3.h),
                child: Text(
                  DateFormat('h:mm a').format(m.at!.toLocal()),
                  style: TextStyle(
                    fontSize: 9.5.sp,
                    color: me ? Colors.white70 : ReturnColors.muted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _composer(SellThread t) {
    final double bottom = MediaQuery.paddingOf(context).bottom;
    if (!t.canReply) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h + bottom),
        color: ReturnColors.indigoSoft,
        child: Text(t.lockedReason ?? 'This conversation is closed.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5.sp, color: ReturnColors.muted)),
      );
    }
    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 8.h + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ReturnColors.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (t.messages.isEmpty)
            SizedBox(
              height: 34.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _quick.length,
                separatorBuilder: (_, __) => SizedBox(width: 8.w),
                itemBuilder: (BuildContext _, int i) => ActionChip(
                  label: Text(_quick[i], style: TextStyle(fontSize: 12.sp)),
                  backgroundColor: ReturnColors.indigoSoft,
                  side: const BorderSide(color: ReturnColors.indigoLine),
                  onPressed: () => _send(_quick[i]),
                ),
              ),
            ),
          if (t.messages.isEmpty) SizedBox(height: 8.h),
          Row(
            children: <Widget>[
              IconButton(
                tooltip: 'Emoji',
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  setState(() => _emoji = !_emoji);
                },
                icon: Icon(
                  _emoji ? Icons.keyboard_rounded : Icons.emoji_emotions_outlined,
                  color: ReturnColors.indigo,
                  size: 26.sp,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _text,
                  focusNode: _focus,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 1000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Message ${t.vendorName}',
                    counterText: '',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22.r),
                      borderSide: const BorderSide(color: ReturnColors.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22.r),
                      borderSide: const BorderSide(color: ReturnColors.indigo),
                    ),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              SizedBox(width: 8.w),
              Material(
                color: ReturnColors.indigo,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _sending ? null : _send,
                  child: SizedBox(
                    width: 44.w,
                    height: 44.w,
                    child: _sending
                        ? Padding(
                            padding: EdgeInsets.all(13.w),
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(Icons.send_rounded,
                            color: Colors.white, size: 20.sp),
                  ),
                ),
              ),
            ],
          ),
          if (_emoji)
            SizedBox(
              height: 190.h,
              child: GridView.count(
                crossAxisCount: 8,
                padding: EdgeInsets.only(top: 8.h),
                children: <Widget>[
                  for (final String e in _emojis)
                    InkWell(
                      borderRadius: BorderRadius.circular(10.r),
                      onTap: () => _insertEmoji(e),
                      child: Center(
                          child: Text(e, style: TextStyle(fontSize: 24.sp))),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
