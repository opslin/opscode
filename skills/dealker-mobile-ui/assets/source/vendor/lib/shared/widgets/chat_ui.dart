import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/shared/widgets/emoji_panel.dart';

/// One message in a [ChatView], whatever feature it came from.
class ChatEntry {
  const ChatEntry({required this.id, required this.mine, required this.body, this.at});
  final int id;
  final bool mine;
  final String body;
  final DateTime? at;
}

String _clock(DateTime? t) {
  if (t == null) return '';
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour >= 12 ? 'pm' : 'am'}';
}

String _dayLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

/// Soft tinted wallpaper with faint phone / tag / wrench doodles, like a messaging app.
class ChatWallpaper extends StatelessWidget {
  const ChatWallpaper({super.key, required this.tint, required this.child});
  final Color tint;
  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Color.alphaBlend(tint.withValues(alpha: 0.10), const Color(0xFFF6F4EF)),
        child: CustomPaint(
          painter: _DoodlePainter(tint.withValues(alpha: 0.13)),
          child: child,
        ),
      );
}

class _DoodlePainter extends CustomPainter {
  _DoodlePainter(this.color);
  final Color color;

  static final _icons = <IconData>[
    PhosphorIconsRegular.deviceMobile,
    PhosphorIconsRegular.tag,
    PhosphorIconsRegular.wrench,
    PhosphorIconsRegular.shieldCheck,
    PhosphorIconsRegular.currencyInr,
    PhosphorIconsRegular.chatCircle,
    PhosphorIconsRegular.batteryFull,
    PhosphorIconsRegular.package,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const step = 74.0;
    var n = 0;
    for (double y = 12; y < size.height; y += step) {
      final odd = (y ~/ step).isOdd;
      for (double x = odd ? step / 2 : 6; x < size.width; x += step) {
        final icon = _icons[n++ % _icons.length];
        final tp = TextPainter(
          text: TextSpan(
              text: String.fromCharCode(icon.codePoint),
              style: TextStyle(
                  fontSize: 26,
                  fontFamily: icon.fontFamily,
                  package: icon.fontPackage,
                  color: color)),
          textDirection: TextDirection.ltr,
        )..layout();
        canvas.save();
        canvas.translate(x + 13, y + 13);
        canvas.rotate(((n % 5) - 2) * 0.18);
        tp.paint(canvas, const Offset(-13, -13));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_DoodlePainter old) => old.color != color;
}

/// A full chat page body: wallpaper, bubbles, date chips, quick replies and a pill composer.
class ChatView extends StatefulWidget {
  const ChatView({
    super.key,
    required this.messages,
    required this.accent,
    required this.onSend,
    this.sending = false,
    this.canReply = true,
    this.lockedReason,
    this.quickReplies = const [],
    this.hint = 'Type a message',
    this.emptyText = 'No messages yet. Say hello.',
    this.showQuickAlways = false,
  });

  final List<ChatEntry> messages;
  final Color accent;
  final Future<bool> Function(String body) onSend;
  final bool sending;
  final bool canReply;
  final String? lockedReason;
  final List<String> quickReplies;
  final String hint;
  final String emptyText;
  final bool showQuickAlways;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  bool _emoji = false;
  bool _hasText = false;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _text.addListener(() {
      final has = _text.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
    _focus.addListener(() {
      if (_focus.hasFocus && _emoji) setState(() => _emoji = false);
    });
    _count = widget.messages.length;
    WidgetsBinding.instance.addPostFrameCallback((_) => _toEnd(animate: false));
  }

  @override
  void didUpdateWidget(ChatView old) {
    super.didUpdateWidget(old);
    if (widget.messages.length != _count) {
      _count = widget.messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _toEnd());
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _toEnd({bool animate = true}) {
    if (!_scroll.hasClients) return;
    final to = _scroll.position.maxScrollExtent;
    if (animate) {
      _scroll.animateTo(to, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    } else {
      _scroll.jumpTo(to);
    }
  }

  Future<void> _send([String? preset]) async {
    final body = (preset ?? _text.text).trim();
    if (body.isEmpty || widget.sending) return;
    final ok = await widget.onSend(body);
    if (ok && preset == null) _text.clear();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Expanded(
          child: ChatWallpaper(
            tint: widget.accent,
            child: widget.messages.isEmpty ? _empty() : _list(),
          ),
        ),
        _composer(),
      ]);

  Widget _empty() => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 36),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(14)),
          child: Text(widget.emptyText,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary)),
        ),
      );

  Widget _list() {
    final msgs = widget.messages;
    final children = <Widget>[];
    DateTime? lastDay;
    for (var i = 0; i < msgs.length; i++) {
      final m = msgs[i];
      final at = m.at;
      if (at != null) {
        final day = DateTime(at.year, at.month, at.day);
        if (lastDay != day) {
          lastDay = day;
          children.add(_DayChip(_dayLabel(day)));
        }
      }
      final prev = i > 0 ? msgs[i - 1] : null;
      children.add(_Bubble(m, accent: widget.accent, firstInGroup: prev == null || prev.mine != m.mine));
    }
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      children: children,
    );
  }

  Widget _composer() {
    final bottom = MediaQuery.paddingOf(context).bottom;
    if (!widget.canReply) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + bottom),
        color: Colors.white,
        child: Row(children: [
          const Icon(PhosphorIconsFill.lockSimple, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
              child: Text(widget.lockedReason ?? 'This conversation is closed.',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
        ]),
      );
    }
    final showQuick = widget.quickReplies.isNotEmpty && (widget.showQuickAlways || widget.messages.isEmpty);
    return Container(
      color: const Color(0xFFF6F4EF),
      padding: EdgeInsets.fromLTRB(8, 6, 8, 8 + (_emoji ? 0 : bottom)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (showQuick)
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: 6),
              itemCount: widget.quickReplies.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => _send(widget.quickReplies[i]),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: widget.accent.withValues(alpha: 0.35))),
                  child: Text(widget.quickReplies[i],
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: widget.accent)),
                ),
              ),
            ),
          ),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 1))]),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                EmojiToggle(
                    open: _emoji,
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      setState(() => _emoji = !_emoji);
                    }),
                Expanded(
                  child: TextField(
                    controller: _text,
                    focusNode: _focus,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: 1000,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      counterText: '',
                      isDense: true,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 13),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: (_hasText && !widget.sending) ? _send : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: _hasText ? widget.accent : widget.accent.withValues(alpha: 0.45),
                  shape: BoxShape.circle),
              child: widget.sending
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                  : const Icon(PhosphorIconsFill.paperPlaneRight, color: Colors.white, size: 22),
            ),
          ),
        ]),
        if (_emoji)
          EmojiPanel(onPick: (e) {
            insertEmoji(_text, e);
            setState(() {});
          }),
      ]),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 2)]),
          child: Text(label,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        ),
      );
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.m, {required this.accent, required this.firstInGroup});
  final ChatEntry m;
  final Color accent;
  final bool firstInGroup;

  @override
  Widget build(BuildContext context) {
    final mine = m.mine;
    final bg = mine ? Color.alphaBlend(Colors.white.withValues(alpha: 0.0), accent) : Colors.white;
    final fg = mine ? Colors.white : AppColors.textPrimary;
    final sub = mine ? Colors.white.withValues(alpha: 0.78) : AppColors.textMuted;
    const r = Radius.circular(16);
    const tail = Radius.circular(4);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        margin: EdgeInsets.only(top: firstInGroup ? 6 : 0, bottom: 2),
        padding: const EdgeInsets.fromLTRB(12, 7, 10, 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: r,
            topRight: r,
            bottomLeft: mine ? r : (firstInGroup ? tail : r),
            bottomRight: mine ? (firstInGroup ? tail : r) : r,
          ),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 2, offset: Offset(0, 1))],
        ),
        child: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 8,
          children: [
            Text(m.body, style: TextStyle(fontSize: 14.5, height: 1.3, color: fg)),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_clock(m.at), style: TextStyle(fontSize: 10.5, color: sub)),
              if (mine) ...[
                const SizedBox(width: 3),
                Icon(PhosphorIconsBold.checks, size: 14, color: sub),
              ],
            ]),
          ],
        ),
      ),
    );
  }
}

/// Header for chat pages: back, avatar, name + sub line, optional actions.
class ChatHeader extends StatelessWidget implements PreferredSizeWidget {
  const ChatHeader({
    super.key,
    required this.title,
    required this.accent,
    this.subtitle,
    this.avatarIcon,
    this.initial,
    this.actions = const [],
  });
  final String title;
  final String? subtitle;
  final Color accent;
  final IconData? avatarIcon;
  final String? initial;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [accent, Color.lerp(accent, Colors.black, 0.18)!]),
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 64,
            child: Row(children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(PhosphorIconsBold.arrowLeft, color: Colors.white, size: 22),
              ),
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.5))),
                child: initial != null
                    ? Text(initial!.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17))
                    : Icon(avatarIcon ?? PhosphorIconsFill.user, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.w800)),
                  if (subtitle != null)
                    Text(subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
                ]),
              ),
              ...actions,
              const SizedBox(width: 4),
            ]),
          ),
        ),
      );
}
