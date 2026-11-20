import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart'
    show errorText;
import 'package:dealker_vendor/features/subscription/application/subscription_providers.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

/// Ask camera or gallery, upload the photo and make it the shop's profile photo.
Future<void> changeShopPhoto(BuildContext context, WidgetRef ref) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(PhosphorIconsFill.camera),
          title: const Text('Take a photo'),
          onTap: () => Navigator.pop(c, ImageSource.camera),
        ),
        ListTile(
          leading: const Icon(PhosphorIconsFill.image),
          title: const Text('Choose from gallery'),
          onTap: () => Navigator.pop(c, ImageSource.gallery),
        ),
        const SizedBox(height: 8),
      ]),
    ),
  );
  if (source == null) return;
  try {
    final f = await ImagePicker()
        .pickImage(source: source, imageQuality: 85, maxWidth: 1200);
    if (f == null) return;
    await ref.read(subscriptionRepositoryProvider).setShopPhoto(f);
    ref.invalidate(growthProvider);
    if (context.mounted) showAppToast(context, 'Shop photo updated.');
  } catch (e) {
    if (context.mounted) {
      showAppToast(context, errorText(e, 'Could not update the photo.'), error: true);
    }
  }
}
