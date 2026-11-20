import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart'
    show heading, errorText;
import 'package:dealker_vendor/features/support/application/support_providers.dart';
import 'package:dealker_vendor/features/support/presentation/faq_data.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

/// Start a support conversation: pick a topic, describe the problem. The server gives it a ticket number
/// and opens a chat room where the support team replies.
class NewTicketScreen extends ConsumerStatefulWidget {
  const NewTicketScreen({super.key});

  @override
  ConsumerState<NewTicketScreen> createState() => _NewTicketScreenState();
}

class _NewTicketScreenState extends ConsumerState<NewTicketScreen> {
  ChatTopic? _topic;
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final subject = _subject.text.trim();
    final message = _message.text.trim();
    if (_topic == null) {
      setState(() => _error = 'Choose what this is about');
      return;
    }
    if (subject.length < 3) {
      setState(() => _error = 'Add a short title (at least 3 letters)');
      return;
    }
    if (message.length < 10) {
      setState(() => _error = 'Tell us a little more about the problem');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final t = await ref.read(supportRepositoryProvider).createTicket(
          subject: subject, message: message, category: _topic!.category);
      ref.invalidate(supportTicketsProvider);
      if (!mounted) return;
      showAppToast(context, 'Ticket ${t.number} created. We will reply here.');
      context.pushReplacement(Routes.helpChat(t.id));
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = errorText(e, 'Could not send your message. Please try again.');
        });
      }
    }
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13.5, color: AppColors.textMuted),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.cardBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.cardBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.6)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FB),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
            icon: const Icon(PhosphorIconsRegular.arrowLeft, color: AppColors.navy),
            onPressed: () => context.pop()),
        title: Text('Chat with support', style: heading(size: 20)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + MediaQuery.viewInsetsOf(context).bottom),
        children: [
          Row(children: [
            Image.asset('assets/3d/help/chat.png', width: 56, height: 56),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Tell us what happened. We will open a chat room with a ticket number so you can follow the reply.',
                  style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary)),
            ),
          ]),
          const SizedBox(height: 16),
          Text('What is it about?', style: heading(size: 16)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in chatTopics)
              GestureDetector(
                onTap: () => setState(() {
                  _topic = t;
                  _error = null;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
                  decoration: BoxDecoration(
                    color: _topic == t ? const Color(0xFFE5EEFF) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _topic == t ? AppColors.primary : AppColors.cardBorder, width: _topic == t ? 1.8 : 1),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Image.asset(t.asset, width: 30, height: 30),
                    const SizedBox(width: 6),
                    Text(t.label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: _topic == t ? AppColors.primary : AppColors.navy)),
                  ]),
                ),
              ),
          ]),
          const SizedBox(height: 18),
          Text('Title', style: heading(size: 16)),
          const SizedBox(height: 8),
          TextField(
              controller: _subject,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() => _error = null),
              decoration: _dec('e.g. Payment deducted but order not placed').copyWith(counterText: '')),
          const SizedBox(height: 14),
          Text('Describe the problem', style: heading(size: 16)),
          const SizedBox(height: 8),
          TextField(
              controller: _message,
              minLines: 5,
              maxLines: 8,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() => _error = null),
              decoration: _dec('Include the order number, amount or any error you saw.')),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(PhosphorIconsFill.warningCircle, size: 16, color: AppColors.rose),
              const SizedBox(width: 6),
              Expanded(child: Text(_error!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.rose))),
            ]),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              icon: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : const Icon(PhosphorIconsFill.paperPlaneTilt, size: 20),
              label: const Text('Start chat', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}
