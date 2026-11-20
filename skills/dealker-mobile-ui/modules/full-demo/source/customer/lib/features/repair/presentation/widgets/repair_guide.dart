import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dealker_app/core/theme/repair_tokens.dart';
import 'package:dealker_app/features/repair/presentation/widgets/repair_art.dart';
import 'package:dealker_app/features/repair/presentation/widgets/repair_ui.dart';

/// First-time walkthrough of Repair: four big pictures, one idea each.
/// Shown once per customer (see [RepairGuide.maybeShow]) and reachable any
/// time from the "How it works" button.
class RepairGuide extends StatefulWidget {
  const RepairGuide({super.key});

  static String _key(String? userId) =>
      'repair_guide_seen_${userId ?? 'guest'}';

  /// Opens the guide the first time this customer opens Repair.
  static Future<void> maybeShow(BuildContext context, String? userId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_key(userId)) == true || !context.mounted) return;
    await prefs.setBool(_key(userId), true);
    if (!context.mounted) return;
    await show(context);
  }

  static Future<void> show(BuildContext context) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'How repair works',
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => const RepairGuide(),
      transitionBuilder: (_, anim, __, child) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, .06),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
  }

  @override
  State<RepairGuide> createState() => _RepairGuideState();
}

class _Slide {
  const _Slide(this.art, this.title, this.body, this.badge);

  final String art;
  final String title;
  final String body;
  final String? badge;
}

class _RepairGuideState extends State<RepairGuide> {
  final PageController _page = PageController();
  int _i = 0;

  static const List<_Slide> _slides = <_Slide>[
    _Slide(
      kRepairTechnician,
      'Fix your phone the easy way',
      'No phone calls. No waiting for replies.\nJust 3 easy steps.',
      null,
    ),
    _Slide(
      'assets/repair/screen.png',
      'Tell us what is wrong',
      'Pick your phone, then tap the problem.\nBroken screen? Battery? Just tap it.',
      'STEP 1',
    ),
    _Slide(
      'assets/shops/shop1.png',
      'Choose a shop near you',
      'You see all the shops near you with their price.\nPick the one you like.',
      'STEP 2',
    ),
    _Slide(
      kRepairHandover,
      'We take care of the rest',
      'The shop picks up your phone or you visit them.\nSee every step, and get it back fixed.',
      'STEP 3',
    ),
  ];

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _next() {
    if (_i == _slides.length - 1) {
      Navigator.of(context).pop();
    } else {
      _page.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool last = _i == _slides.length - 1;
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Skip', style: rtHead(15, color: RT.grey)),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _page,
                itemCount: _slides.length,
                onPageChanged: (int v) => setState(() => _i = v),
                itemBuilder: (BuildContext context, int n) {
                  final _Slide s = _slides[n];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Container(
                          width: 250,
                          height: 250,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: <Color>[
                                Color(0xFFFFF1BF),
                                Color(0xFFFFFFFF),
                              ],
                            ),
                          ),
                          child: Center(
                            child: RArt(s.art, size: 190, float: true),
                          ),
                        ),
                        const SizedBox(height: 28),
                        if (s.badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: RT.gold,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              s.badge!,
                              style: rtHead(12, color: RT.indigo)
                                  .copyWith(letterSpacing: 1),
                            ),
                          ),
                        if (s.badge != null) const SizedBox(height: 12),
                        Text(
                          s.title,
                          textAlign: TextAlign.center,
                          style: rtHead(26, h: 1.2),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          s.body,
                          textAlign: TextAlign.center,
                          style: rtBody(16, h: 1.5),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (int d = 0; d < _slides.length; d++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: d == _i ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: d == _i ? RT.indigo : RT.border,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: RButton(
                label: last ? 'Start repair' : 'Next',
                onTap: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
