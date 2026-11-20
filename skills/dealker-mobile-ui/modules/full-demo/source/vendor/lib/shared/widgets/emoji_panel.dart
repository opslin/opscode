import 'package:flutter/material.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';

const _emojis = <String>[
  '😀', '😁', '😂', '🙂', '😊', '😍', '🤝', '🙏', '👍', '👌', '🔥', '🎉',
  '💰', '💸', '📱', '✅', '❌', '🤔', '😅', '😉', '🙌', '👏', '⏰', '📍',
  '🚚', '🔋', '📦', '💯', '❤️', '😢', '😎', '🤗',
];

/// Put [emoji] where the cursor is in [c].
void insertEmoji(TextEditingController c, String emoji) {
  final t = c.text;
  final s = c.selection;
  final start = s.isValid ? s.start : t.length;
  final end = s.isValid ? s.end : t.length;
  c.value = TextEditingValue(
    text: t.replaceRange(start, end, emoji),
    selection: TextSelection.collapsed(offset: start + emoji.length),
  );
}

/// Smiley / keyboard toggle for the chat composer.
class EmojiToggle extends StatelessWidget {
  const EmojiToggle({super.key, required this.open, required this.onTap});
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Emoji',
        onPressed: onTap,
        icon: Icon(open ? Icons.keyboard_rounded : Icons.emoji_emotions_outlined,
            color: AppColors.violet, size: 26),
      );
}

class EmojiPanel extends StatelessWidget {
  const EmojiPanel({super.key, required this.onPick});
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 190,
        child: GridView.count(
          crossAxisCount: 8,
          padding: const EdgeInsets.only(top: 8),
          children: [
            for (final e in _emojis)
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onPick(e),
                child: Center(child: Text(e, style: const TextStyle(fontSize: 24))),
              ),
          ],
        ),
      );
}
