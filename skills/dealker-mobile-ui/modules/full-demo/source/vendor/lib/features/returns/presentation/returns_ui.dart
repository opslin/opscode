import 'package:flutter/material.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/returns/data/return_models.dart';

({Color fg, Color bg}) stageColors(ReturnStage s) => switch (s) {
      ReturnStage.needsResponse => (fg: const Color(0xFFB45309), bg: AppColors.amberSoft),
      ReturnStage.withTeam => (fg: AppColors.primary, bg: const Color(0xFFE9F1FF)),
      ReturnStage.refunded => (fg: AppColors.mint, bg: AppColors.mintSoft),
      ReturnStage.rejected => (fg: AppColors.rose, bg: AppColors.roseSoft),
      ReturnStage.cancelled => (fg: AppColors.textSecondary, bg: const Color(0xFFEFF1F6)),
    };

class StagePill extends StatelessWidget {
  const StagePill(this.stage, {super.key});
  final ReturnStage stage;

  @override
  Widget build(BuildContext context) {
    final c = stageColors(stage);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(20)),
      child: Text(stage.label, style: TextStyle(color: c.fg, fontSize: 11.5, fontWeight: FontWeight.w800)),
    );
  }
}

String shortDate(DateTime? t) {
  if (t == null) return '';
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${t.day} ${m[t.month - 1]}';
}
