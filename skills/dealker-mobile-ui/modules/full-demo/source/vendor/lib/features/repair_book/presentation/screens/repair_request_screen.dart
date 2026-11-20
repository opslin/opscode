import 'package:dealker_vendor/features/repair_book/shims/app_image.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:dealker_vendor/features/profile/application/profile_providers.dart';
import 'package:dealker_vendor/features/repair_book/shims/env.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/features/repair_book/repair_tokens.dart';
import 'package:dealker_vendor/features/repair_book/shims/server_error.dart';
import 'package:dealker_vendor/features/repair_book/presentation/widgets/repair_art.dart';
import 'package:dealker_vendor/features/repair_book/presentation/widgets/repair_ui.dart';
import 'package:dealker_vendor/features/repair_book/repair_models.dart';
import 'package:dealker_vendor/features/repair_book/repair_providers.dart';

/// Issues offered on the problems step, in the design's order.
const List<String> _problemKeys = <String>[
  'SCREEN',
  'BATTERY',
  'TOUCH',
  'CHARGING',
  'WATER_DAMAGE',
  'CAMERA',
  'AUDIO',
  'OTHER',
];

/// Screens 02–04 — one request in three steps: device → problems & photos →
/// location & publish. The draft lives in [repairDraftProvider] so going back
/// never loses anything.
class RepairRequestScreen extends ConsumerStatefulWidget {
  const RepairRequestScreen({super.key});

  @override
  ConsumerState<RepairRequestScreen> createState() =>
      _RepairRequestScreenState();
}

class _RepairRequestScreenState extends ConsumerState<RepairRequestScreen> {
  int _step = 0;
  bool _publishing = false;
  String? _error;

  static const List<String> _titles = <String>[
    'Your phone',
    'What’s wrong?',
    'Where are you?',
  ];

  void _back() {
    if (_step > 0) {
      setState(() {
        _step--;
        _error = null;
      });
    } else {
      context.canPop() ? context.pop() : context.go('/repair');
    }
  }

  Future<void> _publish() async {
    final RepairDraft d = ref.read(repairDraftProvider);
    if (!d.hasDevice || d.issues.isEmpty || d.addressId == null) return;
    setState(() {
      _publishing = true;
      _error = null;
    });
    try {
      final info = ref.read(vendorInfoProvider).asData?.value;
      final String id = await ref.read(repairApiProvider).create(
        brand: d.brand!,
        model: d.model!,
        issues: d.issues,
        addressId: d.addressId!,
        description: d.notes,
        qty: d.qty,
        gstin: info?.gstin,
        businessName: (info?.legalName ?? '').isNotEmpty ? info!.legalName : info?.name,
        contactPerson: ref.read(currentUserProvider)?.name,
        poReference: d.poReference,
        mediaIds: <String>[
          for (final RepairPhoto p in d.photos)
            if (p.mediaId != null) p.mediaId!,
        ],
      );
      ref.invalidate(repairMineProvider);
      ref.read(repairDraftProvider.notifier).reset();
      if (mounted) context.pushReplacement('/repair/$id/quotes');
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = isOfflineError(e)
              ? 'You’re offline. Check your connection and try again.'
              : ServerError.from(e).message,
        );
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final RepairDraft d = ref.watch(repairDraftProvider);
    final bool canNext = switch (_step) {
      0 => d.hasDevice,
      1 => d.issues.isNotEmpty && !d.uploading,
      _ => d.addressId != null &&
          (!d.isBulk || (ref.watch(vendorInfoProvider).asData?.value.gstin.length ?? 0) == 15),
    };
    final String cta = switch (_step) {
      0 => 'Next',
      1 => 'Next',
      _ => 'Show shops near me',
    };

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, void _) {
        if (!didPop) _back();
      },
      child: RepairShell(
        title: _titles[_step],
        onBack: _back,
        body: ListView(
          key: ValueKey<int>(_step),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(RT.gutter, 14, RT.gutter, 24),
          children: <Widget>[
            _StepHeader(step: _step),
            const SizedBox(height: 18),
            switch (_step) {
              0 => const _DeviceStep(),
              1 => const _ProblemsStep(),
              _ => _LocationStep(
                  error: _error,
                  onJump: (int i) => setState(() => _step = i),
                ),
            },
          ],
        ),
        bottom: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            RButton(
              label: cta,
              loading: _publishing,
              onTap: !canNext
                  ? null
                  : () {
                      if (_step < 2) {
                        FocusScope.of(context).unfocus();
                        setState(() => _step++);
                      } else {
                        _publish();
                      }
                    },
            ),
            if (_step == 2) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                'Nothing to pay now · you choose the shop',
                style: rtBody(12, color: RT.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step});

  final int step;

  static const List<(String, String)> _steps = <(String, String)>[
    ('assets/3d/exchange/phone.png', 'Phone'),
    ('assets/3d/repair/screen.png', 'Problem'),
    ('assets/3d/cart/pin.png', 'Place'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int i = 0; i < 3; i++) ...<Widget>[
          if (i > 0)
            Expanded(
              child: Container(
                height: 3,
                margin: const EdgeInsets.only(bottom: 22),
                decoration: BoxDecoration(
                  color: i <= step ? RT.indigo : RT.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          Column(
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: i == step ? RT.tint : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: i <= step ? RT.indigo : RT.border,
                    width: i == step ? 2 : 1.4,
                  ),
                ),
                padding: const EdgeInsets.all(8),
                child: Opacity(
                  opacity: i <= step ? 1 : .45,
                  child: Image.asset(_steps[i].$1, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _steps[i].$2,
                style: rtHead(
                  11.5,
                  color: i <= step ? RT.indigo : RT.muted,
                  w: i == step ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ── step 1: device ─────────────────────────────────────────────────────────

class _DeviceStep extends ConsumerStatefulWidget {
  const _DeviceStep();

  @override
  ConsumerState<_DeviceStep> createState() => _DeviceStepState();
}

class _DeviceStepState extends ConsumerState<_DeviceStep> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _typeModel() async {
    final String? v = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => const _ModelDialog(),
    );
    if (v != null && v.length >= 2) {
      final String? brand = ref.read(repairDraftProvider).brand;
      if (brand != null) {
        ref.read(repairDraftProvider.notifier).setDevice(brand, v, null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final RepairDraft d = ref.watch(repairDraftProvider);
    final AsyncValue<List<RepairBrand>> brands =
        ref.watch(repairBrandsProvider);
    final AsyncValue<List<RecentDevice>> recent =
        ref.watch(repairRecentDevicesProvider);
    final String q = _search.text.trim().toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Which phone is it?', style: rtHead(22, h: 1.2)),
        const SizedBox(height: 6),
        Text(
          'Pick the brand, then the model.',
          style: rtBody(14, h: 1.35),
        ),
        const SizedBox(height: 16),
        _SearchField(
          controller: _search,
          hint: 'Search brand or model',
          onChanged: (_) => setState(() {}),
        ),
        if ((recent.asData?.value ?? const <RecentDevice>[]).isNotEmpty &&
            q.isEmpty) ...<Widget>[
          const SizedBox(height: 22),
          Text('Recent devices', style: rtHead(16)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final RecentDevice r in recent.asData!.value.take(4))
                RChip(
                  r.name,
                  icon: PhosphorIconsRegular.deviceMobile,
                  height: 36,
                  selected: d.brand == r.brand && d.model == r.model,
                  onTap: () => ref
                      .read(repairDraftProvider.notifier)
                      .setDevice(r.brand, r.model, null),
                ),
            ],
          ),
        ],
        const SizedBox(height: 22),
        Text('Choose a brand', style: rtHead(16)),
        const SizedBox(height: 10),
        brands.when(
          loading: () => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (int i = 0; i < 8; i++)
                const RSkeleton(width: 80, height: 78, radius: 14),
            ],
          ),
          error: (Object e, StackTrace _) => RErrorView(
            offline: isOfflineError(e),
            onRetry: () => ref.invalidate(repairBrandsProvider),
          ),
          data: (List<RepairBrand> list) {
            final List<RepairBrand> shown = list
                .where(
                  (RepairBrand b) =>
                      q.isEmpty ||
                      b.name.toLowerCase().contains(q) ||
                      d.brand == b.name,
                )
                .toList();
            // A brand typed under "Other" stays visible and selected; "Other" itself is always last.
            final String? picked = d.brand;
            if (picked != null &&
                picked.isNotEmpty &&
                !list.any((RepairBrand b) => b.name == picked)) {
              shown.insert(0, RepairBrand(picked, null));
            }
            shown.add(const RepairBrand('Other', null));
            return _BrandGrid(
              brands: shown,
              selected: d.brand,
              onTap: (RepairBrand b) async {
                if (b.name == 'Other') {
                  final String? typed = await showDialog<String>(
                    context: context,
                    builder: (BuildContext ctx) =>
                        const _ModelDialog(title: 'Brand name', hint: 'e.g. Nothing, Motorola, Lava'),
                  );
                  if (typed != null && typed.trim().length >= 2) {
                    ref.read(repairDraftProvider.notifier).setBrand(typed.trim());
                  }
                } else {
                  ref.read(repairDraftProvider.notifier).setBrand(b.name);
                }
                _search.clear();
                setState(() {});
              },
            );
          },
        ),
        if ((d.brand ?? '').isNotEmpty) ...<Widget>[
          const SizedBox(height: 22),
          Text('Choose model', style: rtHead(16)),
          const SizedBox(height: 10),
          ref.watch(repairModelsProvider(d.brand!)).when(
                loading: () => const Column(
                  children: <Widget>[
                    RSkeleton(height: 64, radius: 14),
                    SizedBox(height: 8),
                    RSkeleton(height: 64, radius: 14),
                  ],
                ),
                error: (Object e, StackTrace _) => RErrorView(
                  offline: isOfflineError(e),
                  onRetry: () => ref.invalidate(repairModelsProvider(d.brand!)),
                ),
                data: (List<RepairModel> models) {
                  final List<RepairModel> shown = models
                      .where(
                        (RepairModel m) =>
                            q.isEmpty || m.name.toLowerCase().contains(q),
                      )
                      .toList();
                  // A model the customer typed that is not in the catalogue.
                  final bool customChosen = (d.model ?? '').isNotEmpty &&
                      !models.any((RepairModel m) => m.name == d.model);
                  return Column(
                    children: <Widget>[
                      if (customChosen)
                        _ModelRow(
                          model: RepairModel(d.model!, null, null),
                          selected: true,
                          onTap: () {},
                        ),
                      for (final RepairModel m in shown)
                        _ModelRow(
                          model: m,
                          selected: d.model == m.name,
                          onTap: () => ref
                              .read(repairDraftProvider.notifier)
                              .setDevice(d.brand!, m.name, m.imageUrl),
                        ),
                      if (shown.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            _search.text.trim().isEmpty
                                ? 'We don’t have models for this brand yet. Tap “My model isn’t listed” and type yours.'
                                : 'No model matches “${_search.text.trim()}”.',
                            style: rtBody(13.5),
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: RLink(
                          'My model isn’t listed',
                          onTap: _typeModel,
                          icon: PhosphorIconsRegular.pencilSimple,
                        ),
                      ),
                    ],
                  );
                },
              ),
        ],
        if (d.hasDevice) ...<Widget>[
          const SizedBox(height: 22),
          const _QtyCard(),
        ],
      ],
    );
  }
}

/// Asks for a model that is not in the catalogue. It owns its controller, so the
/// controller is only disposed after the dialog's exit animation has finished.
class _ModelDialog extends StatefulWidget {
  const _ModelDialog({this.title = 'Model name or number', this.hint = 'e.g. Galaxy A54  /  SM-A546E'});
  final String title;
  final String hint;

  @override
  State<_ModelDialog> createState() => _ModelDialogState();
}

class _ModelDialogState extends State<_ModelDialog> {
  final TextEditingController _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    final String v = _c.text.trim();
    if (v.length >= 2) Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(widget.title, style: rtHead(18)),
      content: TextField(
        controller: _c,
        autofocus: true,
        cursorColor: RT.indigo,
        maxLength: 60,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: rtBody(15, color: RT.muted),
          counterText: '',
          filled: true,
          fillColor: RT.field,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: RT.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: RT.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: RT.indigo, width: 1.6),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: rtHead(14.5, color: RT.grey)),
        ),
        TextButton(
          onPressed: _submit,
          child: Text('Use this', style: rtHead(14.5, color: RT.indigo)),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: RT.field,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RT.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: <Widget>[
          const PhosphorIcon(
            PhosphorIconsRegular.magnifyingGlass,
            size: 20,
            color: RT.muted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              cursorColor: RT.indigo,
              style: rtBody(15, color: RT.ink, w: FontWeight.w500),
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: hint,
                hintStyle: rtBody(15, color: RT.muted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandGrid extends StatelessWidget {
  const _BrandGrid({
    required this.brands,
    required this.selected,
    required this.onTap,
  });

  final List<RepairBrand> brands;
  final String? selected;
  final ValueChanged<RepairBrand> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        const double gap = 8;
        final double w = (c.maxWidth - gap * 3) / 4;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final RepairBrand b in brands)
              GestureDetector(
                onTap: () => onTap(b),
                child: Container(
                  width: w,
                  height: 80,
                  decoration: BoxDecoration(
                    color: selected == b.name ? RT.tint : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected == b.name ? RT.indigo : RT.border,
                      width: selected == b.name ? 1.6 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Container(
                        width: 38,
                        height: 34,
                        decoration: BoxDecoration(
                          color: RT.field,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        clipBehavior: Clip.antiAlias,
                        padding: const EdgeInsets.all(5),
                        child: (b.logoUrl ?? '').isEmpty
                            ? Center(child: _fallback(b.name))
                            : Image.network(
                                webImageSource(b.logoUrl!),
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                    Center(child: _fallback(b.name)),
                              ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        b.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: rtHead(12, w: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  static String _initials(String n) => n.length <= 2 ? n : n.substring(0, 2);

  static Widget _fallback(String name) => name.toLowerCase() == 'other'
      ? const Icon(Icons.more_horiz_rounded, color: RT.indigo, size: 22)
      : Text(_initials(name), style: rtHead(14));
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({
    required this.model,
    required this.selected,
    required this.onTap,
  });

  final RepairModel model;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? RT.tint : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? RT.indigo : RT.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              RPhoneThumb(url: model.imageUrl, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  model.name,
                  style: rtHead(15.5, w: FontWeight.w700),
                ),
              ),
              if (selected)
                const PhosphorIcon(
                  PhosphorIconsFill.checkCircle,
                  size: 24,
                  color: RT.indigo,
                )
              else
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: RT.border, width: 1.6),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── step 2: problems & photos ──────────────────────────────────────────────

class _ProblemsStep extends ConsumerStatefulWidget {
  const _ProblemsStep();

  @override
  ConsumerState<_ProblemsStep> createState() => _ProblemsStepState();
}

class _ProblemsStepState extends ConsumerState<_ProblemsStep> {
  late final TextEditingController _notes =
      TextEditingController(text: ref.read(repairDraftProvider).notes);

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _add(RepairConfig cfg) async {
    final RepairDraft d = ref.read(repairDraftProvider);
    final int videos = d.photos.where((RepairPhoto p) => p.isVideo).length;
    final int images = d.photos.length - videos;
    final String? choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => _SourceSheet(
        canImage: images < cfg.maxImages,
        canVideo: videos < cfg.maxVideos,
      ),
    );
    if (choice == null || !mounted) return;
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> files = <XFile>[];
      switch (choice) {
        case 'camera':
          final XFile? f = await picker.pickImage(
            source: ImageSource.camera,
            imageQuality: 82,
            maxWidth: 1800,
          );
          if (f != null) files.add(f);
        case 'gallery':
          files.addAll(
            await picker.pickMultiImage(
              imageQuality: 82,
              maxWidth: 1800,
              limit: cfg.maxImages - images < 2 ? 2 : cfg.maxImages - images,
            ),
          );
        case 'video':
          final XFile? v = await picker.pickVideo(
            source: ImageSource.gallery,
            maxDuration: const Duration(minutes: 2),
          );
          if (v != null) files.add(v);
      }
      int room = cfg.maxImages - images;
      for (final XFile f in files) {
        if (!RepairPhoto(file: f).isVideo) {
          if (room <= 0) continue;
          room--;
        }
        ref.read(repairDraftProvider.notifier).addPhoto(f);
      }
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Allow camera or photo access in Settings to add photos.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final RepairDraft d = ref.watch(repairDraftProvider);
    final AsyncValue<RepairConfig> cfgAsync = ref.watch(repairConfigProvider);
    final RepairConfig? cfg = cfgAsync.asData?.value;
    final List<String> keys = <String>[
      for (final String k in _problemKeys)
        if (cfg == null || cfg.issues.any((RepairIssue i) => i.key == k)) k,
    ];
    final int maxImg = cfg?.maxImages ?? 6;
    final int maxVid = cfg?.maxVideos ?? 1;
    final int videos = d.photos.where((RepairPhoto p) => p.isVideo).length;
    final bool canAdd =
        cfg != null && (d.photos.length - videos < maxImg || videos < maxVid);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('What is wrong with it?', style: rtHead(22, h: 1.2)),
        const SizedBox(height: 6),
        Text('Tap every problem you see. You can pick more than one.',
            style: rtBody(14)),
        const SizedBox(height: 16),
        if (cfgAsync.hasError && cfg == null)
          RErrorView(
            offline: isOfflineError(cfgAsync.error!),
            onRetry: () => ref.invalidate(repairConfigProvider),
          )
        else
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              const double gap = 10;
              final double w = (c.maxWidth - gap * 2) / 3;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: <Widget>[
                  for (final String k in keys)
                    GestureDetector(
                      onTap: () =>
                          ref.read(repairDraftProvider.notifier).toggleIssue(k),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: w,
                        height: 112,
                        decoration: BoxDecoration(
                          color: d.issues.contains(k) ? RT.tint : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: d.issues.contains(k) ? RT.indigo : RT.border,
                            width: d.issues.contains(k) ? 2 : 1,
                          ),
                        ),
                        child: Stack(
                          children: <Widget>[
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 22),
                                child: RArt(repairIssueArt(k), size: 62),
                              ),
                            ),
                            Positioned(
                              left: 4,
                              right: 4,
                              bottom: 9,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  issueProblemName(k),
                                  maxLines: 1,
                                  textAlign: TextAlign.center,
                                  style: rtHead(12, w: FontWeight.w800),
                                ),
                              ),
                            ),
                            if (d.issues.contains(k))
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: const BoxDecoration(
                                    color: RT.indigo,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check_rounded,
                                      size: 15, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        const SizedBox(height: 24),
        Row(
          children: <Widget>[
            Text('Tell us more ', style: rtHead(16)),
            Text(
              '(optional)',
              style: rtBody(12.5, color: RT.grey, w: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: RT.field,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: RT.border),
          ),
          padding: const EdgeInsets.all(14),
          child: TextField(
            controller: _notes,
            maxLines: 4,
            minLines: 3,
            maxLength: 300,
            onChanged: ref.read(repairDraftProvider.notifier).setNotes,
            cursorColor: RT.indigo,
            style: rtBody(14.5, color: RT.ink),
            buildCounter: (
              BuildContext _, {
              required int currentLength,
              required bool isFocused,
              int? maxLength,
            }) =>
                null,
            decoration: InputDecoration(
              isCollapsed: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText:
                  'e.g. Screen cracked after a fall. Touch still works, but battery drains quickly.',
              hintStyle: rtBody(14.5, color: RT.muted, h: 1.35),
            ),
          ),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _notes,
          builder: (BuildContext _, TextEditingValue v, Widget? __) => Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'More detail helps shops price your repair accurately',
                  style: rtBody(12.5, color: RT.grey),
                ),
              ),
              Text(
                '${v.text.length} / 300',
                style: rtBody(12.5, color: RT.grey),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(children: <Widget>[
          Text('Add photos ', style: rtHead(16)),
          Text('(optional)',
              style: rtBody(12.5, color: RT.grey, w: FontWeight.w600)),
        ]),
        const SizedBox(height: 6),
        Text(
          'A photo helps the shop give you the right price.',
          style: rtBody(13.5),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 78,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: <Widget>[
              _AddTile(
                label: 'Add photo',
                icon: PhosphorIconsRegular.uploadSimple,
                onTap: canAdd ? () => _add(cfg) : null,
              ),
              for (final RepairPhoto p in d.photos)
                _Thumb(
                  photo: p,
                  video: p.isVideo,
                  onRemove: () => ref
                      .read(repairDraftProvider.notifier)
                      .removePhoto(p.path),
                  onRetry: () =>
                      ref.read(repairDraftProvider.notifier).retryPhoto(p.path),
                ),
              if (d.photos.isNotEmpty && canAdd)
                _AddTile(
                  label: 'More',
                  icon: PhosphorIconsRegular.plus,
                  onTap: () => _add(cfg),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Up to $maxImg photos + $maxVid video${maxVid == 1 ? '' : 's'}',
                style: rtBody(12.5, color: RT.grey),
              ),
            ),
            if (d.photos.isNotEmpty)
              Text(
                '${d.photos.length} added',
                style: rtBody(12.5, color: RT.grey, w: FontWeight.w600),
              ),
          ],
        ),
        const SizedBox(height: 14),
        const RBand(
          'Tip: save your photos and contacts first. The shop may need to reset your phone.',
          kind: BandKind.warn,
        ),
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final PhosphorIconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 84,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: onTap == null ? RT.field : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: RT.indigo.withValues(alpha: onTap == null ? 0.2 : 0.55),
            width: 1.4,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            PhosphorIcon(
              icon,
              size: 22,
              color: onTap == null ? RT.muted : RT.indigo,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: rtHead(
                12,
                color: onTap == null ? RT.muted : RT.indigo,
                w: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.photo,
    required this.video,
    required this.onRemove,
    required this.onRetry,
  });

  final RepairPhoto photo;
  final bool video;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      margin: const EdgeInsets.only(right: 10),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: video
                ? Container(
                    color: RT.ink,
                    child: const Center(
                      child: PhosphorIcon(
                        PhosphorIconsFill.playCircle,
                        size: 30,
                        color: Colors.white,
                      ),
                    ),
                  )
                : kIsWeb
                    ? Image.network(photo.path,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: RT.field))
                    : Image.file(File(photo.path),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: RT.field)),
          ),
          if (photo.uploading)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.35),
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          if (photo.failed)
            GestureDetector(
              onTap: onRetry,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: ColoredBox(
                  color: RT.red.withValues(alpha: 0.78),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const PhosphorIcon(
                        PhosphorIconsRegular.arrowsClockwise,
                        size: 22,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 4),
                      Text('Retry', style: rtHead(12, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Color(0xCC0B1033),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: PhosphorIcon(
                    PhosphorIconsBold.x,
                    size: 11,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceSheet extends StatelessWidget {
  const _SourceSheet({required this.canImage, required this.canVideo});

  final bool canImage;
  final bool canVideo;

  @override
  Widget build(BuildContext context) {
    Widget row(
      PhosphorIconData icon,
      String title,
      String sub,
      String value,
      bool enabled,
    ) =>
        ListTile(
          enabled: enabled,
          leading: RIconTile(icon, size: 42),
          title: Text(title, style: rtHead(15.5, w: FontWeight.w700)),
          subtitle: Text(sub, style: rtBody(12.5, color: RT.muted)),
          onTap: () => Navigator.pop(context, value),
        );
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: RT.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 10),
              row(
                PhosphorIconsRegular.camera,
                'Camera',
                'Take a photo now',
                'camera',
                canImage,
              ),
              row(
                PhosphorIconsRegular.imageSquare,
                'Choose photos',
                'From your gallery',
                'gallery',
                canImage,
              ),
              row(
                PhosphorIconsRegular.videoCamera,
                'Choose a video',
                'Show the problem in action',
                'video',
                canVideo,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── step 3: location & publish ─────────────────────────────────────────────

class _LocationStep extends ConsumerWidget {
  const _LocationStep({required this.onJump, this.error});

  final ValueChanged<int> onJump;
  final String? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RepairDraft d = ref.watch(repairDraftProvider);
    final AsyncValue<List<SavedAddress>> addrs =
        ref.watch(repairAddressesProvider);
    final List<SavedAddress> list =
        addrs.asData?.value ?? const <SavedAddress>[];
    SavedAddress? chosen;
    if (list.isNotEmpty) {
      chosen =
          list.where((SavedAddress a) => a.id == d.addressId).firstOrNull ??
              list.where((SavedAddress a) => a.isDefault).firstOrNull ??
              list.first;
      if (d.addressId != chosen.id) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => ref.read(repairDraftProvider.notifier).setAddress(chosen!.id),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Where are you?', style: rtHead(22, h: 1.2)),
        const SizedBox(height: 6),
        Text(
          'We use your address to find repair shops near you.',
          style: rtBody(14, h: 1.35),
        ),
        const SizedBox(height: 16),
        if (addrs.isLoading && list.isEmpty)
          const RSkeleton(height: 96, radius: 16)
        else if (addrs.hasError && list.isEmpty)
          RErrorView(
            offline: isOfflineError(addrs.error!),
            onRetry: () => ref.invalidate(repairAddressesProvider),
          )
        else if (chosen == null)
          RCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('No saved address', style: rtHead(16)),
                const SizedBox(height: 6),
                Text(
                  'Add the address where shops should pick up or find you.',
                  style: rtBody(13.5),
                ),
                const SizedBox(height: 12),
                RButton(
                  label: 'Add address',
                  outline: true,
                  onTap: () async {
                    await context.push('/profile/addresses/add');
                    ref.invalidate(repairAddressesProvider);
                  },
                ),
              ],
            ),
          )
        else
          RCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: PhosphorIcon(
                    PhosphorIconsRegular.mapPin,
                    size: 22,
                    color: RT.indigo,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(chosen.label, style: rtHead(16)),
                      const SizedBox(height: 3),
                      Text(
                        chosen.full,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: rtBody(13.5, h: 1.3),
                      ),
                      if (chosen.area.isNotEmpty)
                        Text(chosen.area, style: rtBody(13.5)),
                    ],
                  ),
                ),
                RLink(
                  'Change',
                  onTap: () => _changeAddress(context, ref, list, chosen!.id),
                ),
              ],
            ),
          ),
        if (d.isBulk) ...<Widget>[
          const SizedBox(height: 14),
          const _BulkBillCard(),
        ],
        const SizedBox(height: 22),
        Text('Review your request', style: rtHead(18)),
        const SizedBox(height: 12),
        _ReviewCard(draft: d, onJump: onJump),
        const SizedBox(height: RT.gap),
        const RBand(
          'Your full phone number and address are only shared after you choose a shop.',
          kind: BandKind.success,
        ),
        if (error != null) ...<Widget>[
          const SizedBox(height: RT.gap),
          RBand(error!, kind: BandKind.danger),
        ],
      ],
    );
  }

  Future<void> _changeAddress(
    BuildContext context,
    WidgetRef ref,
    List<SavedAddress> list,
    String current,
  ) async {
    final String? id = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: RT.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Choose address', style: rtHead(18)),
                const SizedBox(height: 10),
                for (final SavedAddress a in list)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: PhosphorIcon(
                      PhosphorIconsRegular.mapPin,
                      size: 22,
                      color: a.id == current ? RT.indigo : RT.muted,
                    ),
                    title: Text(a.label, style: rtHead(15, w: FontWeight.w700)),
                    subtitle: Text(
                      a.full,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: rtBody(12.5),
                    ),
                    trailing: a.id == current
                        ? const PhosphorIcon(
                            PhosphorIconsFill.checkCircle,
                            color: RT.indigo,
                          )
                        : null,
                    onTap: () => Navigator.pop(ctx, a.id),
                  ),
                RLink(
                  'Add new address',
                  icon: PhosphorIconsRegular.plus,
                  onTap: () => Navigator.pop(ctx, '__new'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (id == null) return;
    if (id == '__new') {
      if (!context.mounted) return;
      await context.push('/profile/addresses/add');
      ref.invalidate(repairAddressesProvider);
    } else {
      ref.read(repairDraftProvider.notifier).setAddress(id);
    }
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.draft, required this.onJump});

  final RepairDraft draft;
  final ValueChanged<int> onJump;

  @override
  Widget build(BuildContext context) {
    final List<RepairPhoto> photos = draft.photos;
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Your device',
                  style: rtHead(14.5, w: FontWeight.w700),
                ),
              ),
              RLink('Edit', onTap: () => onJump(0)),
            ],
          ),
          Row(
            children: <Widget>[
              RPhoneThumb(url: draft.modelImage, size: 60),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(draft.isBulk ? '${draft.deviceName}  ×${draft.qty}' : draft.deviceName,
                        style: rtHead(16)),
                    if (draft.isBulk)
                      Text('Bulk lot · ${draft.qty} phones · billed to your business',
                          style: rtBody(12.5, color: RT.indigo)),
                    if (draft.notes.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 3),
                      Text(
                        draft.notes.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: rtBody(13.5, h: 1.3),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 26, color: RT.border),
          Row(
            children: <Widget>[
              Expanded(
                child: Text('Problems', style: rtBody(14, w: FontWeight.w600)),
              ),
              RLink('Edit', onTap: () => onJump(1)),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final String k in draft.issues)
                RChip(issueProblemName(k), selected: true, height: 32),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: Text('Photos', style: rtBody(14, w: FontWeight.w600)),
              ),
              Text(
                photos.isEmpty ? 'None added' : '${photos.length} added',
                style: rtBody(13),
              ),
            ],
          ),
          if (photos.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: <Widget>[
                  for (final RepairPhoto p in photos)
                    Container(
                      width: 52,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: RT.field,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: p.isVideo
                          ? const Icon(Icons.play_circle_outline)
                          : kIsWeb
                              ? Image.network(p.path,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox.shrink())
                              : Image.file(File(p.path),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox.shrink()),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── bulk (business) lot ────────────────────────────────────────────────────

/// "How many phones?" — one phone, or a bulk lot of the same model for a business.
class _QtyCard extends ConsumerWidget {
  const _QtyCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RepairDraft d = ref.watch(repairDraftProvider);
    final int max = ref.watch(repairConfigProvider).asData?.value.maxB2bDevices ?? 50;
    final n = ref.read(repairDraftProvider.notifier);
    Widget round(IconData i, VoidCallback? t) => GestureDetector(
          onTap: t,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: t == null ? RT.field : RT.tint,
                shape: BoxShape.circle,
                border: Border.all(color: t == null ? RT.border : RT.indigo)),
            child: Icon(i, size: 20, color: t == null ? RT.muted : RT.indigo),
          ),
        );
    return RCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Row(children: <Widget>[
          Image.asset('assets/3d/new/cartons.png', height: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text('How many phones?', style: rtHead(16)),
              const SizedBox(height: 2),
              Text(
                d.isBulk
                    ? 'Bulk lot · billed to your business with a GST invoice'
                    : 'Just this one phone',
                style: rtBody(12.5, h: 1.3),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
          round(PhosphorIconsBold.minus, d.qty > 1 ? () => n.setQty(d.qty - 1) : null),
          SizedBox(
            width: 96,
            child: Center(child: Text('${d.qty}', style: rtHead(30))),
          ),
          round(PhosphorIconsBold.plus, d.qty < max ? () => n.setQty(d.qty + 1) : null),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
          for (final int v in const <int>[1, 5, 10, 20, 50])
            if (v <= max)
              RChip('$v', height: 34, selected: d.qty == v, onTap: () => n.setQty(v)),
        ]),
        if (d.isBulk) ...<Widget>[
          const SizedBox(height: 10),
          Text('Up to $max phones per request. All phones in a lot share the same model and problems.',
              style: rtBody(12, h: 1.35, color: RT.muted)),
        ],
      ]),
    );
  }
}

/// Who a bulk repair is billed to: the vendor's business (GSTIN) — plus an optional PO reference.
class _BulkBillCard extends ConsumerWidget {
  const _BulkBillCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(vendorInfoProvider).asData?.value;
    final bool ok = (info?.gstin.length ?? 0) == 15;
    final String name = (info?.legalName ?? '').isNotEmpty ? info!.legalName : (info?.name ?? '');
    return RCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Row(children: <Widget>[
          Image.asset('assets/3d/cart/receipt.png', height: 40),
          const SizedBox(width: 10),
          Expanded(child: Text('Billed to your business', style: rtHead(16))),
        ]),
        const SizedBox(height: 10),
        Text(name.isEmpty ? '—' : name, style: rtHead(15, w: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(ok ? 'GSTIN ${info!.gstin}' : 'GSTIN missing', style: rtBody(13)),
        if (!ok) ...<Widget>[
          const SizedBox(height: 8),
          const RBand('A bulk repair needs your 15-character GSTIN. Add it in Business profile, then come back.', kind: BandKind.danger),
        ],
        const SizedBox(height: 10),
        TextField(
          onChanged: ref.read(repairDraftProvider.notifier).setPo,
          decoration: InputDecoration(
            hintText: 'PO / reference (optional)',
            filled: true,
            fillColor: RT.field,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ]),
    );
  }
}
