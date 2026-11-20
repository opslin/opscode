import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:dealker_app/core/di/providers.dart';
import 'package:dealker_app/core/utils/app_toast.dart';
import 'package:dealker_app/core/utils/server_error.dart';
import 'package:dealker_app/core/theme/app_colors.dart';

const Color _ink = AppColors.brandNavy;
const Color _blue = Color(0xFF1558E8);
const Color _bg = Color(0xFFF3F6FF);

class _Msg {
  const _Msg(this.id, this.mine, this.body, this.at);
  final int id;
  final bool mine;
  final String body;
  final DateTime? at;
}

/// Chat with the seller of an auction you won (payment, packing, delivery questions).
class AuctionChatScreen extends ConsumerStatefulWidget {
  const AuctionChatScreen({required this.auctionId, this.title, super.key});

  final String auctionId;
  final String? title;

  @override
  ConsumerState<AuctionChatScreen> createState() => _AuctionChatScreenState();
}

class _AuctionChatScreenState extends ConsumerState<AuctionChatScreen> {
  final TextEditingController _text = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Timer? _poll;
  List<_Msg>? _msgs;
  String? _error;
  bool _sending = false;
  int _count = 0;

  static const List<String> _quick = <String>[
    'When will you ship it?',
    'I have paid. Please confirm.',
    'Can I get a GST invoice?',
  ];

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
      final r = await ref
          .read(dioClientProvider)
          .get<dynamic>('/auctions/${widget.auctionId}/chat');
      final dynamic d = r.data is Map ? (r.data as Map)['data'] : null;
      final List<_Msg> m = <_Msg>[
        if (d is Map && d['messages'] is List)
          for (final dynamic x in d['messages'] as List)
            if (x is Map)
              _Msg(int.tryParse('${x['id']}') ?? 0, x['mine'] == true,
                  '${x['body']}', DateTime.tryParse('${x['at']}')?.toLocal()),
      ];
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
    } catch (e) {
      if (mounted && !quiet && _msgs == null) {
        setState(() => _error = ServerError.from(e).message);
      }
    }
  }

  Future<void> _send([String? preset]) async {
    final String body = (preset ?? _text.text).trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(dioClientProvider).post<dynamic>(
        '/auctions/${widget.auctionId}/chat',
        data: <String, dynamic>{'body': body},
      );
      _text.clear();
      await _load();
    } catch (e) {
      if (mounted) AppToast.show(context, ServerError.from(e).message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _time(DateTime t) {
    final int h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour >= 12 ? 'pm' : 'am'}';
  }

  @override
  Widget build(BuildContext context) {
    final List<_Msg>? m = _msgs;
    return Scaffold(
      backgroundColor: _bg,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(74.h),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[AppColors.brandNavy, _blue]),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(children: <Widget>[
              SizedBox(width: 6.w),
              IconButton(
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go('/auctions/${widget.auctionId}'),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              Image.asset('assets/profile/chat.png', width: 40.w, height: 40.w),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Chat with the seller',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w800)),
                    Text(widget.title ?? 'About your auction win',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white70, fontSize: 12.sp)),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
            ]),
          ),
        ),
      ),
      body: m == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: EdgeInsets.all(24.w),
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(_error!, textAlign: TextAlign.center),
                            SizedBox(height: 10.h),
                            OutlinedButton(
                                onPressed: _load, child: const Text('Retry')),
                          ]),
                    ),
            )
          : Column(children: <Widget>[
              Expanded(
                child: m.isEmpty
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32.w),
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Image.asset('assets/sell/chat.png',
                                    width: 110.w, height: 110.w),
                                SizedBox(height: 8.h),
                                Text('Say hello to the seller',
                                    style: TextStyle(
                                        color: _ink,
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w800)),
                                SizedBox(height: 4.h),
                                Text(
                                    'Ask about payment, packing or delivery of your win. The seller replies here.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Colors.black54,
                                        fontSize: 13.sp,
                                        height: 1.4)),
                              ]),
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 10.h),
                        itemCount: m.length,
                        itemBuilder: (BuildContext _, int i) => Align(
                          alignment: m[i].mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(
                                maxWidth: MediaQuery.sizeOf(context).width * 0.76),
                            margin: EdgeInsets.only(bottom: 8.h),
                            padding: EdgeInsets.symmetric(
                                horizontal: 13.w, vertical: 9.h),
                            decoration: BoxDecoration(
                              gradient: m[i].mine
                                  ? const LinearGradient(
                                      colors: <Color>[Color(0xFF3B82F6), _blue])
                                  : null,
                              color: m[i].mine ? null : Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(16.r),
                                topRight: Radius.circular(16.r),
                                bottomLeft: Radius.circular(m[i].mine ? 16.r : 4.r),
                                bottomRight: Radius.circular(m[i].mine ? 4.r : 16.r),
                              ),
                              boxShadow: const <BoxShadow>[
                                BoxShadow(
                                    color: Color(0x12000000),
                                    blurRadius: 6,
                                    offset: Offset(0, 2))
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: <Widget>[
                                Text(m[i].body,
                                    style: TextStyle(
                                        color: m[i].mine ? Colors.white : _ink,
                                        fontSize: 14.5.sp,
                                        height: 1.3)),
                                if (m[i].at != null)
                                  Text(_time(m[i].at!),
                                      style: TextStyle(
                                          color: m[i].mine
                                              ? Colors.white70
                                              : Colors.black45,
                                          fontSize: 10.5.sp)),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
              SizedBox(
                height: 38.h,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  children: <Widget>[
                    for (final String q in _quick)
                      Padding(
                        padding: EdgeInsets.only(right: 8.w),
                        child: ActionChip(
                          label: Text(q, style: TextStyle(fontSize: 12.sp)),
                          backgroundColor: Colors.white,
                          side: BorderSide(color: _blue.withValues(alpha: 0.3)),
                          onPressed: () => _send(q),
                        ),
                      ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(12.w, 6.h, 12.w, 8.h),
                  child: Row(children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _text,
                        minLines: 1,
                        maxLines: 3,
                        maxLength: 1000,
                        textCapitalization: TextCapitalization.sentences,
                        inputFormatters: <TextInputFormatter>[
                          LengthLimitingTextInputFormatter(1000)
                        ],
                        decoration: InputDecoration(
                          hintText: 'Type a message',
                          counterText: '',
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16.w, vertical: 11.h),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(26.r),
                              borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    GestureDetector(
                      onTap: _sending ? null : _send,
                      child: Container(
                        width: 48.w,
                        height: 48.w,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                              colors: <Color>[Color(0xFF3B82F6), _blue]),
                          shape: BoxShape.circle,
                        ),
                        child: _sending
                            ? const Padding(
                                padding: EdgeInsets.all(13),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.4, color: Colors.white))
                            : const Icon(Icons.send_rounded,
                                color: Colors.white, size: 22),
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
    );
  }
}
