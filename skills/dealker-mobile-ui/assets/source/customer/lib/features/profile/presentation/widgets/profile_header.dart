import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:dealker_app/core/theme/app_colors.dart';
import 'package:dealker_app/features/cart/presentation/widgets/cart_ui.dart';

/// Account hero: navy gradient card with the avatar (golden ring + camera
/// badge), name, phone and an "Edit profile" pill.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    required this.name,
    required this.phone,
    this.avatarUrl,
    this.onEditTap,
    super.key,
  });

  final String? name;
  final String phone;
  final String? avatarUrl;
  final VoidCallback? onEditTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26.r),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF001F5F), Color(0xFF14409A)],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF001F5F).withValues(alpha: .28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -30.w,
            top: -40.h,
            child: Container(
              width: 150.w,
              height: 150.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .06),
              ),
            ),
          ),
          Positioned(
            right: 30.w,
            bottom: -50.h,
            child: Container(
              width: 120.w,
              height: 120.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.brandYellow.withValues(alpha: .10),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(18.w),
            child: Row(
              children: <Widget>[
                GestureDetector(
                  onTap: onEditTap,
                  child: SizedBox(
                    width: 82.r,
                    height: 82.r,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        Container(
                          width: 78.r,
                          height: 78.r,
                          padding: EdgeInsets.all(3.r),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: <Color>[
                                AppColors.brandYellow,
                                Color(0xFFFFE27A),
                              ],
                            ),
                          ),
                          child: ClipOval(
                            child: _AvatarImage(
                              avatarUrl: avatarUrl,
                              name: name,
                            ),
                          ),
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 30.r,
                            height: 30.r,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF001F5F),
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: CartArtImage(CartArt.camera, size: 20.r),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Gap(16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: jakarta(21.sp, color: Colors.white),
                      ),
                      Gap(4.h),
                      Text(
                        phone,
                        style: dm(14.sp,
                            color: Colors.white.withValues(alpha: .78),
                            w: FontWeight.w500),
                      ),
                      Gap(12.h),
                      GestureDetector(
                        onTap: onEditTap,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 14.w, vertical: 8.h),
                          decoration: BoxDecoration(
                            color: AppColors.brandYellow,
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text('Edit profile',
                                  style: jakarta(13.sp,
                                      color: AppColors.brandNavy)),
                              Gap(4.w),
                              Icon(Icons.arrow_forward_rounded,
                                  size: 15.sp, color: AppColors.brandNavy),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _displayName {
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return 'Dealkr Customer';
    }
    return trimmed;
  }
}

class _AvatarImage extends StatelessWidget {
  const _AvatarImage({required this.avatarUrl, required this.name});

  final String? avatarUrl;
  final String? name;

  @override
  Widget build(BuildContext context) {
    if (avatarUrl == null || avatarUrl!.trim().isEmpty) {
      return _fallback();
    }
    return CachedNetworkImage(
      imageUrl: avatarUrl!,
      memCacheWidth: 300,
      fit: BoxFit.cover,
      placeholder: (context, url) => const ColoredBox(color: Color(0xFFE8EEFB)),
      errorWidget: (context, url, error) => _fallback(),
    );
  }

  Widget _fallback() {
    return ColoredBox(
      color: const Color(0xFFE8EEFB),
      child: Center(
        child: Text(
          _initials,
          style: jakarta(26.sp, color: AppColors.brandNavy),
        ),
      ),
    );
  }

  String get _initials {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'D';
    }
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }
    return (parts.first.characters.first + parts[1].characters.first)
        .toUpperCase();
  }
}
