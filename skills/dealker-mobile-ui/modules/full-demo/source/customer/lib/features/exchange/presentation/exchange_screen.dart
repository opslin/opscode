import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:dealker_app/core/theme/repair_tokens.dart';
import 'package:dealker_app/core/utils/app_toast.dart';
import 'package:dealker_app/features/exchange/data/exchange_models.dart';
import 'package:dealker_app/features/exchange/data/exchange_repository.dart';
import 'package:dealker_app/features/exchange/presentation/exchange_art.dart';
import 'package:dealker_app/features/exchange/presentation/exchange_providers.dart';
import 'package:dealker_app/shared/widgets/app_image.dart';
import 'package:dealker_app/shared/widgets/loading/dealker_loading_button.dart';
import 'package:dealker_app/shared/widgets/loading/dealker_page_loader.dart';
import 'package:dealker_app/shared/widgets/marketplace_product_box.dart';

String _inr(num v) => MarketplaceProductBox.inr(v);

TextStyle _head(double size, {Color color = RT.ink, FontWeight w = FontWeight.w800}) =>
    TextStyle(fontFamily: RT.head, fontSize: size.sp, fontWeight: w, color: color, height: 1.2);
TextStyle _body(double size, {Color color = RT.grey, FontWeight w = FontWeight.w500}) =>
    TextStyle(fontFamily: RT.body, fontSize: size.sp, fontWeight: w, color: color, height: 1.3);

enum _Cond { likeNew, good, worn, damaged }

enum _Issue { notOn, screen, battery, body, camera }

/// Exchange (trade-in) for ANY product: pick what you are trading in, which one it is, how it is,
/// and see the credit taken off the new product. Which old devices count — and for which products —
/// is decided in the dashboard (Exchange programmes), never here.
class ExchangeScreen extends ConsumerStatefulWidget {
  const ExchangeScreen({required this.target, this.initialTypeKey, super.key});
  final ExchangeTarget target;
  final String? initialTypeKey;

  @override
  ConsumerState<ExchangeScreen> createState() => _ExchangeScreenState();
}

class _ExchangeScreenState extends ConsumerState<ExchangeScreen> {
  int _step = 0; // 0 type · 1 which one · 2 how is it · 3 offer · 4 saved
  ExchangeType? _type;
  String? _brand;
  ExchangeModel? _model;
  String? _variant;
  String? _color;
  _Cond _cond = _Cond.likeNew;
  final Set<_Issue> _issues = <_Issue>{};
  bool _box = true;
  bool _bill = true;
  bool _charger = true;
  int _age = 3;
  final TextEditingController _imei = TextEditingController();
  final TextEditingController _search = TextEditingController();

  ExchangeQuote? _quote;
  String? _code;
  bool _busy = false;
  bool _skippedTypeStep = false;
  final GlobalKey _modelKey = GlobalKey();
  final GlobalKey _optionsKey = GlobalKey();

  @override
  void dispose() {
    _imei.dispose();
    _search.dispose();
    super.dispose();
  }

  ExchangeQa _qa() {
    final ExchangeType t = _type!;
    final bool worn = _cond == _Cond.worn || _cond == _Cond.damaged;
    final String scratches = !t.hasScreen
        ? 'NONE'
        : _issues.contains(_Issue.screen) || worn
            ? 'MAJOR'
            : _cond == _Cond.good
                ? 'MINOR'
                : 'NONE';
    return ExchangeQa(
      ageMonths: _age,
      screenScratches: scratches,
      bodyDents: _issues.contains(_Issue.body) ||
          _cond == _Cond.damaged ||
          (!t.hasScreen && worn),
      screenReplaced: false,
      billAvailable: _bill,
      boxAvailable: _box,
      chargerAvailable: _charger,
      batteryHealth: !t.hasBattery ? 100 : (_issues.contains(_Issue.battery) ? 70 : 95),
      faceIdIssue: t.hasCamera && _issues.contains(_Issue.camera),
      cameraIssue: t.hasCamera && _issues.contains(_Issue.camera),
      powersOn: !_issues.contains(_Issue.notOn),
    );
  }

  static bool _imeiOk(String v) {
    if (!RegExp(r'^\d{15}$').hasMatch(v)) return false;
    int sum = 0;
    for (int i = 0; i < 15; i++) {
      int n = int.parse(v[14 - i]);
      if (i.isOdd) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
    }
    return sum % 10 == 0;
  }

  void _back() {
    if (_step == 4) {
      context.canPop() ? context.pop() : context.go('/home');
      return;
    }
    final int floor = _skippedTypeStep ? 1 : 0;
    if (_step > floor) {
      setState(() => _step--);
    } else {
      context.canPop() ? context.pop() : context.go('/home');
    }
  }

  void _pickType(ExchangeType t) => setState(() {
        if (_type?.key != t.key) {
          _brand = null;
          _model = null;
          _variant = null;
          _color = null;
          _issues.clear();
          _search.clear();
        }
        _type = t;
        _step = 1;
      });

  Future<void> _next() async {
    switch (_step) {
      case 1:
        if (_model == null) return _warn('Choose your device first');
        if (_variant == null) return _warn('Choose the version of your device');
        if (_color == null) return _warn('Choose the colour');
        setState(() => _step = 2);
      case 2:
        if (_type!.needsImei && !_imeiOk(_imei.text.trim())) {
          return _warn('Enter the 15-digit IMEI number (dial *#06#)');
        }
        await _getOffer();
      case 3:
        await _save();
    }
  }

  void _warn(String m) => AppToast.show(context, m);

  /// Brings the next question into view (a long brand grid pushes it below the fold).
  void _reveal(GlobalKey k) => WidgetsBinding.instance.addPostFrameCallback((_) {
        final BuildContext? c = k.currentContext;
        if (c != null) {
          Scrollable.ensureVisible(
            c,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            alignment: 0.04,
          );
        }
      });

  Future<void> _getOffer() async {
    setState(() => _busy = true);
    try {
      final ExchangeQuote q = await ref.read(exchangeRepositoryProvider).quote(
            productId: widget.target.productId,
            model: _model!,
            variant: _variant!,
            color: _color!,
            qa: _qa(),
          );
      if (!mounted) return;
      setState(() {
        _quote = q;
        _step = 3;
      });
    } catch (e) {
      if (mounted) _warn(ExchangeRepository.errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final String code = await ref.read(exchangeRepositoryProvider).submit(
            model: _model!,
            variant: _variant!,
            color: _color!,
            imei: _type!.needsImei ? _imei.text.trim() : null,
            qa: _qa(),
            target: widget.target,
          );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _code = code;
        _step = 4;
      });
    } catch (e) {
      if (mounted) _warn(ExchangeRepository.errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<ExchangeOptions> opts =
        ref.watch(exchangeOptionsProvider(widget.target.productId));
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: opts.when(
            loading: () => const DealkerPageLoader(message: 'Checking what we accept'),
            error: (Object e, StackTrace _) => _Unavailable(
              message: ExchangeRepository.errorMessage(e),
              onBack: _back,
              onRetry: () => ref.invalidate(exchangeOptionsProvider(widget.target.productId)),
            ),
            data: (ExchangeOptions o) {
              // Only honor a product-page selection still accepted by the API.
              final initialTypes = o.types.where(
                (type) => type.key == widget.initialTypeKey,
              );
              final initialType = initialTypes.firstOrNull ??
                  (o.types.length == 1 ? o.types.first : null);
              if (_type == null && initialType != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _type == null) {
                    setState(() {
                      _type = initialType;
                      _step = 1;
                      _skippedTypeStep = o.types.length == 1;
                    });
                  }
                });
              }
              return Column(
                children: <Widget>[
                  _header(),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      transitionBuilder: (Widget c, Animation<double> a) => FadeTransition(
                        opacity: a,
                        child: SlideTransition(
                          position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(a),
                          child: c,
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey<int>(_step),
                        child: switch (_step) {
                          0 => _typeStep(o),
                          1 => _modelStep(o),
                          2 => _conditionStep(),
                          3 => _offerStep(),
                          _ => _savedStep(),
                        },
                      ),
                    ),
                  ),
                  if (_step >= 1 && _step <= 3) _bottomBar(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ── header ───────────────────────────────────────────────────────────────

  Widget _header() {
    const List<String> titles = <String>[
      'What are you exchanging?',
      'Which one is yours?',
      'How is it?',
      'Your exchange offer',
      'All done!',
    ];
    final int shown = _step.clamp(0, 3);
    return Padding(
      padding: EdgeInsets.fromLTRB(8.w, 6.h, 16.w, 4.h),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton(
                onPressed: _back,
                icon: const Icon(Icons.arrow_back_rounded, color: RT.ink),
              ),
              Expanded(child: Text(titles[_step], style: _head(19))),
            ],
          ),
          if (_step < 4)
            Padding(
              padding: EdgeInsets.fromLTRB(8.w, 2.h, 0, 6.h),
              child: Row(
                children: <Widget>[
                  for (int i = 0; i < 4; i++) ...<Widget>[
                    if (i > 0) SizedBox(width: 6.w),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 5.h,
                        decoration: BoxDecoration(
                          color: i <= shown ? RT.gold : RT.border,
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _productStrip() => Container(
        margin: EdgeInsets.only(bottom: 14.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: RT.tint,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Row(
          children: <Widget>[
            ExArt(kExSwap, size: 38.w),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('You are buying', style: _body(11)),
                  Text(
                    widget.target.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _head(13.5),
                  ),
                ],
              ),
            ),
            Text(_inr(widget.target.price), style: _head(14.5)),
          ],
        ),
      );

  // ── step 0: what are you exchanging ──────────────────────────────────────

  Widget _typeStep(ExchangeOptions o) => ListView(
        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
        children: <Widget>[
          _productStrip(),
          Text('Tap the kind of device you want to trade in.', style: _body(13.5)),
          SizedBox(height: 12.h),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12.h,
            crossAxisSpacing: 12.w,
            childAspectRatio: 0.92,
            children: <Widget>[
              for (final ExchangeType t in o.types)
                _TypeTile(type: t, onTap: () => _pickType(t)),
            ],
          ),
          SizedBox(height: 18.h),
          _note('We check your device after you hand it over. Nothing is paid now.'),
        ],
      );

  // ── step 1: which one is it ──────────────────────────────────────────────

  Widget _modelStep(ExchangeOptions o) {
    final ExchangeType t = _type!;
    final List<ExchangeModel> ofType =
        o.models.where((ExchangeModel m) => m.category == t.key).toList();
    final Map<String, String?> brands = <String, String?>{};
    final Map<String, int> count = <String, int>{};
    for (final ExchangeModel m in ofType) {
      final String b = m.brand ?? 'Other';
      brands[b] = brands[b] ?? m.brandLogoUrl;
      count[b] = (count[b] ?? 0) + 1;
    }
    final List<String> brandOrder = brands.keys.toList()
      ..sort((String a, String b) => count[b]!.compareTo(count[a]!));
    final String q = _search.text.trim().toLowerCase();
    final List<ExchangeModel> models = ofType
        .where((ExchangeModel m) =>
            (q.isNotEmpty || (m.brand ?? 'Other') == _brand) &&
            (q.isEmpty || m.name.toLowerCase().contains(q)))
        .toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
      children: <Widget>[
        Row(
          children: <Widget>[
            ExArt(exchangeTypeArt(t.icon), size: 30.w),
            SizedBox(width: 8.w),
            Text(t.label, style: _head(14.5)),
            const Spacer(),
            if (!_skippedTypeStep)
              TextButton(
                onPressed: () => setState(() => _step = 0),
                child: Text('Change', style: _body(12.5, color: RT.blue, w: FontWeight.w700)),
              ),
          ],
        ),
        SizedBox(height: 8.h),
        _label('1', 'Pick the brand'),
        SizedBox(height: 10.h),
        Wrap(
          spacing: 10.w,
          runSpacing: 10.h,
          children: <Widget>[
            for (final String b in brandOrder)
              _BrandChip(
                name: b,
                logoUrl: brands[b],
                selected: _brand == b,
                onTap: () => setState(() {
                  _search.clear();
                  if (_brand != b) {
                    _brand = b;
                    _model = null;
                    _variant = null;
                    _color = null;
                  }
                  _reveal(_modelKey);
                }),
              ),
          ],
        ),
        if (ofType.length > 10) ...<Widget>[
          SizedBox(height: 12.h),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            style: _body(14, color: RT.ink),
            decoration: InputDecoration(
              hintText: 'Search the model',
              hintStyle: _body(14, color: RT.muted),
              prefixIcon: const Icon(Icons.search_rounded, color: RT.muted),
              filled: true,
              fillColor: RT.field,
              contentPadding: EdgeInsets.symmetric(vertical: 12.h),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
                borderSide: const BorderSide(color: RT.blue, width: 1.6),
              ),
            ),
          ),
        ],
        if (_brand != null || q.isNotEmpty) ...<Widget>[
          SizedBox(height: 18.h),
          KeyedSubtree(key: _modelKey, child: _label('2', 'Pick the model')),
          SizedBox(height: 10.h),
          if (models.isEmpty)
            Text('No match. Try another name.', style: _body(13))
          else
            for (final ExchangeModel m in models)
              _ModelTile(
                model: m,
                selected: _model?.id == m.id,
                onTap: () => setState(() {
                  _model = m;
                  _brand = m.brand ?? 'Other';
                  _variant = m.variants.length == 1 ? m.variants.first : null;
                  _color = m.colors.length == 1 ? m.colors.first : null;
                  _reveal(_optionsKey);
                }),
              ),
        ],
        if (_model != null) ...<Widget>[
          SizedBox(key: _optionsKey, height: 1),
          if (_model!.variants.length > 1) ...<Widget>[
            SizedBox(height: 18.h),
            _label('3', 'Which version?'),
            SizedBox(height: 10.h),
            _chips(_model!.variants, _variant, (String v) => setState(() => _variant = v)),
          ],
          if (_model!.colors.length > 1) ...<Widget>[
            SizedBox(height: 18.h),
            _label(_model!.variants.length > 1 ? '4' : '3', 'What colour is it?'),
            SizedBox(height: 10.h),
            _chips(_model!.colors, _color, (String v) => setState(() => _color = v)),
          ],
        ],
      ],
    );
  }

  // ── step 2: how is it ────────────────────────────────────────────────────

  Widget _conditionStep() {
    final ExchangeType t = _type!;
    final List<(_Issue, String, IconData)> issues = <(_Issue, String, IconData)>[
      (_Issue.notOn, 'Does not switch on', Icons.power_settings_new_rounded),
      if (t.hasScreen) (_Issue.screen, 'Screen is cracked', Icons.broken_image_outlined),
      if (t.hasBattery) (_Issue.battery, 'Battery drains fast', Icons.battery_alert_rounded),
      (_Issue.body, 'Dents or broken parts', Icons.build_circle_outlined),
      if (t.hasCamera) (_Issue.camera, 'Camera or Face ID problem', Icons.camera_alt_outlined),
    ];
    final bool screenDevice = t.hasScreen && (t.icon == 'phone' || t.icon == 'tablet');
    final String own = exchangeTypeArt(t.icon);
    // Phones and tablets show the phone pictures; every other device shows itself with a state badge.
    final List<(_Cond, String, String, String, IconData?, Color)> conds = <(_Cond, String, String, String, IconData?, Color)>[
      (_Cond.likeNew, 'Like new', 'No marks at all', screenDevice ? kExLikeNew : own, screenDevice ? null : Icons.auto_awesome_rounded, RT.gold),
      (_Cond.good, 'Good', 'Tiny marks only', screenDevice ? kExGood : own, screenDevice ? null : Icons.thumb_up_alt_rounded, RT.green),
      (_Cond.worn, 'Worn', 'Visible scratches', screenDevice ? kExWorn : own, screenDevice ? null : Icons.texture_rounded, RT.amber),
      (_Cond.damaged, 'Damaged', 'Cracked or broken', screenDevice ? kExDamaged : own, screenDevice ? null : Icons.heart_broken_rounded, RT.red),
    ];
    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
      children: <Widget>[
        _SelectedDevice(model: _model!, variant: _variant!, color: _color!, type: t),
        SizedBox(height: 18.h),
        _label('1', 'What does it look like?'),
        SizedBox(height: 10.h),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10.h,
          crossAxisSpacing: 10.w,
          childAspectRatio: 1.12,
          children: <Widget>[
            for (final (_Cond, String, String, String, IconData?, Color) c in conds)
              _ArtChoice(
                art: c.$4,
                badge: c.$5,
                badgeColor: c.$6,
                title: c.$2,
                sub: c.$3,
                selected: _cond == c.$1,
                onTap: () => setState(() => _cond = c.$1),
              ),
          ],
        ),
        SizedBox(height: 20.h),
        _label('2', 'Is anything wrong? (tap all that apply)'),
        SizedBox(height: 10.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: <Widget>[
            for (final (_Issue, String, IconData) i in issues)
              _IssueChip(
                icon: i.$3,
                label: i.$2,
                selected: _issues.contains(i.$1),
                onTap: () => setState(() {
                  _issues.contains(i.$1) ? _issues.remove(i.$1) : _issues.add(i.$1);
                }),
              ),
          ],
        ),
        SizedBox(height: 20.h),
        _label('3', 'What do you still have?'),
        SizedBox(height: 10.h),
        Row(
          children: <Widget>[
            Expanded(child: _HaveTile(art: kExBox, label: 'Box', on: _box, onTap: () => setState(() => _box = !_box))),
            SizedBox(width: 10.w),
            Expanded(child: _HaveTile(art: kExBill, label: 'Bill', on: _bill, onTap: () => setState(() => _bill = !_bill))),
            SizedBox(width: 10.w),
            Expanded(
              child: _HaveTile(
                art: kExCharger,
                label: t.hasBattery ? 'Charger' : 'Cable',
                on: _charger,
                onTap: () => setState(() => _charger = !_charger),
              ),
            ),
          ],
        ),
        SizedBox(height: 20.h),
        _label('4', 'How old is it?'),
        SizedBox(height: 10.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: <Widget>[
            for (final (String, int) a in const <(String, int)>[
              ('Under 6 months', 3),
              ('6 to 12 months', 9),
              ('1 to 2 years', 18),
              ('Over 2 years', 30),
            ])
              _Pill(label: a.$1, selected: _age == a.$2, onTap: () => setState(() => _age = a.$2)),
          ],
        ),
        if (t.needsImei) ...<Widget>[
          SizedBox(height: 20.h),
          _label('5', 'IMEI number'),
          SizedBox(height: 4.h),
          Text('Dial *#06# on the phone to see it. It is 15 digits.', style: _body(12)),
          SizedBox(height: 10.h),
          TextField(
            controller: _imei,
            keyboardType: TextInputType.number,
            maxLength: 15,
            inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
            style: _head(16, w: FontWeight.w700),
            decoration: InputDecoration(
              counterText: '',
              hintText: '15 digit IMEI',
              hintStyle: _body(14, color: RT.muted),
              filled: true,
              fillColor: RT.field,
              contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
                borderSide: const BorderSide(color: RT.blue, width: 1.6),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── step 3: the offer ────────────────────────────────────────────────────

  Widget _offerStep() {
    final ExchangeQuote q = _quote!;
    final double price = widget.target.price;
    final double credit = q.credit;
    final double pay = (price - credit).clamp(0, double.infinity).toDouble();
    final bool capped = credit < q.value;
    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
      children: <Widget>[
        Container(
          padding: EdgeInsets.all(18.w),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFF001F5F), Color(0xFF0B3A8C)],
            ),
            borderRadius: BorderRadius.circular(22.r),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Your ${_model!.name} gets you', style: _body(12.5, color: Colors.white70)),
                    SizedBox(height: 4.h),
                    Text(_inr(credit), style: _head(34, color: RT.gold)),
                    Text('off ${widget.target.name}', maxLines: 2, overflow: TextOverflow.ellipsis, style: _body(12.5, color: Colors.white70)),
                    SizedBox(height: 10.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text('Condition: ${q.conditionLabel}', style: _body(11.5, color: Colors.white, w: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              ExArt(kExMoney, size: 92.w),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(color: RT.border),
          ),
          child: Column(
            children: <Widget>[
              _row('New product', _inr(price)),
              _row('Exchange value', '− ${_inr(credit)}', color: RT.green),
              Divider(color: RT.border, height: 20.h),
              _row('You pay', _inr(pay), big: true),
            ],
          ),
        ),
        if (capped) ...<Widget>[
          SizedBox(height: 10.h),
          _note('Your device is worth ${_inr(q.value)}, but the most we can take off this product is ${_inr(credit)}.'),
        ],
        if (q.deductions.isNotEmpty) ...<Widget>[
          SizedBox(height: 16.h),
          Text('Why this value?', style: _head(14)),
          SizedBox(height: 8.h),
          for (final String d in q.deductions)
            Padding(
              padding: EdgeInsets.only(bottom: 6.h),
              child: Row(
                children: <Widget>[
                  Icon(Icons.remove_circle_outline_rounded, size: 16.sp, color: RT.muted),
                  SizedBox(width: 8.w),
                  Expanded(child: Text(d, style: _body(12.5))),
                ],
              ),
            ),
        ],
        SizedBox(height: 14.h),
        _note('This is an estimate. We confirm the final value when we check your device, and nothing is paid before that.'),
      ],
    );
  }

  // ── step 4: saved ────────────────────────────────────────────────────────

  Widget _savedStep() => Padding(
        padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 24.h),
        child: Column(
          children: <Widget>[
            const Spacer(),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.6, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.elasticOut,
              builder: (BuildContext c, double v, Widget? _) =>
                  Transform.scale(scale: v, child: ExArt(kExSwap, size: 170.w)),
            ),
            SizedBox(height: 18.h),
            Text('Your exchange is saved', textAlign: TextAlign.center, style: _head(22)),
            SizedBox(height: 8.h),
            Text(
              'Your offer is ${_inr(_quote?.credit ?? 0)} off. Our team will check your device and connect it to your order.',
              textAlign: TextAlign.center,
              style: _body(13.5),
            ),
            if ((_code ?? '').isNotEmpty) ...<Widget>[
              SizedBox(height: 14.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                decoration: BoxDecoration(color: RT.tint, borderRadius: BorderRadius.circular(12.r)),
                child: Text('Exchange number  $_code', style: _head(13, color: RT.blue, w: FontWeight.w700)),
              ),
            ],
            const Spacer(),
            DealkerLoadingButton(
              label: 'Back to the product',
              yellow: true,
              onPressed: _back,
            ),
            SizedBox(height: 8.h),
            TextButton(
              onPressed: () => context.go('/home'),
              child: Text('Keep shopping', style: _body(13.5, color: RT.blue, w: FontWeight.w700)),
            ),
          ],
        ),
      );

  // ── pieces ───────────────────────────────────────────────────────────────

  Widget _bottomBar() {
    final String label = switch (_step) {
      1 => 'Next',
      2 => 'See my offer',
      _ => 'Save my exchange',
    };
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 12.h),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: RT.border)),
      ),
      child: DealkerLoadingButton(
        label: label,
        yellow: true,
        status: _busy ? DealkerButtonStatus.loading : DealkerButtonStatus.idle,
        onPressed: _next,
      ),
    );
  }

  Widget _label(String n, String text) => Row(
        children: <Widget>[
          Container(
            width: 22.w,
            height: 22.w,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: RT.blue, shape: BoxShape.circle),
            child: Text(n, style: _head(11.5, color: Colors.white)),
          ),
          SizedBox(width: 8.w),
          Expanded(child: Text(text, style: _head(14.5))),
        ],
      );

  Widget _chips(List<String> items, String? sel, ValueChanged<String> on) => Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        children: <Widget>[
          for (final String s in items) _Pill(label: s, selected: s == sel, onTap: () => on(s)),
        ],
      );

  Widget _row(String k, String v, {bool big = false, Color color = RT.ink}) => Padding(
        padding: EdgeInsets.symmetric(vertical: 4.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(k, style: big ? _head(15) : _body(13.5)),
            Text(v, style: big ? _head(19) : _head(14, color: color, w: FontWeight.w700)),
          ],
        ),
      );

  Widget _note(String t) => Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: RT.amberTint.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.info_outline_rounded, size: 17.sp, color: RT.amber),
            SizedBox(width: 8.w),
            Expanded(child: Text(t, style: _body(12, color: RT.amber, w: FontWeight.w600))),
          ],
        ),
      );
}

// ── widgets ────────────────────────────────────────────────────────────────

class _TypeTile extends StatelessWidget {
  const _TypeTile({required this.type, required this.onTap});
  final ExchangeType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: RT.border, width: 1.4),
            boxShadow: <BoxShadow>[
              BoxShadow(color: RT.blue.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 6)),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Expanded(child: ExArt(exchangeTypeArt(type.icon), size: 96.w)),
              SizedBox(height: 6.h),
              Text(type.label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: _head(13.5)),
              SizedBox(height: 4.h),
              if (type.upTo > 0)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 3.h),
                  decoration: BoxDecoration(color: RT.greenTint, borderRadius: BorderRadius.circular(20.r)),
                  child: Text('Up to ${_inr(type.upTo)}', style: _body(11, color: RT.green, w: FontWeight.w800)),
                ),
            ],
          ),
        ),
      );
}

class _BrandChip extends StatelessWidget {
  const _BrandChip({required this.name, required this.logoUrl, required this.selected, required this.onTap});
  final String name;
  final String? logoUrl;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: (1.sw - 32.w - 30.w) / 4,
          height: 84.h,
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: selected ? RT.tint : Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: selected ? RT.blue : RT.border, width: selected ? 2 : 1.2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                height: 36.h,
                width: 46.w,
                child: (logoUrl ?? '').isNotEmpty
                    ? AppImage(
                        imageUrl: logoUrl!,
                        memCacheWidth: 160,
                        memCacheHeight: 120,
                        fit: BoxFit.contain,
                        placeholder: const SizedBox.shrink(),
                        errorWidget: _letter(),
                      )
                    : _letter(),
              ),
              SizedBox(height: 4.h),
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _body(11.5, color: RT.ink, w: FontWeight.w700)),
            ],
          ),
        ),
      );

  Widget _letter() => Center(
        child: Text(
          name.isEmpty ? '?' : name.characters.first.toUpperCase(),
          style: _head(24, color: RT.blue),
        ),
      );
}

class _ModelTile extends StatelessWidget {
  const _ModelTile({required this.model, required this.selected, required this.onTap});
  final ExchangeModel model;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: EdgeInsets.only(bottom: 8.h),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
          decoration: BoxDecoration(
            color: selected ? RT.tint : Colors.white,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: selected ? RT.blue : RT.border, width: selected ? 2 : 1.2),
          ),
          child: Row(
            children: <Widget>[
              Expanded(child: Text(model.name, style: _head(13.5, w: FontWeight.w700))),
              if (selected) Icon(Icons.check_circle_rounded, color: RT.blue, size: 20.sp),
            ],
          ),
        ),
      );
}

class _SelectedDevice extends StatelessWidget {
  const _SelectedDevice({required this.model, required this.variant, required this.color, required this.type});
  final ExchangeModel model;
  final String variant;
  final String color;
  final ExchangeType type;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(color: RT.tint, borderRadius: BorderRadius.circular(16.r)),
        child: Row(
          children: <Widget>[
            ExArt(exchangeTypeArt(type.icon), size: 44.w),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(model.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _head(14)),
                  Text(
                    <String>[if (variant != 'Standard') variant, color].join(' · '),
                    style: _body(12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ArtChoice extends StatelessWidget {
  const _ArtChoice({
    required this.art,
    required this.title,
    required this.sub,
    required this.selected,
    required this.onTap,
    this.badge,
    this.badgeColor = RT.blue,
  });
  final String art;
  final IconData? badge;
  final Color badgeColor;
  final String title;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: selected ? RT.tint : Colors.white,
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(color: selected ? RT.blue : RT.border, width: selected ? 2 : 1.2),
          ),
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                      child: Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          ExArt(art, size: 78.w),
                          if (badge != null)
                            Positioned(
                              right: 34.w,
                              bottom: 4.h,
                              child: Container(
                                padding: EdgeInsets.all(6.w),
                                decoration: BoxDecoration(
                                  color: badgeColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: Icon(badge, size: 15.sp, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(title, style: _head(13.5)),
                    Text(sub, style: _body(11)),
                  ],
                ),
              ),
              if (selected)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Icon(Icons.check_circle_rounded, color: RT.blue, size: 20.sp),
                ),
            ],
          ),
        ),
      );
}

class _IssueChip extends StatelessWidget {
  const _IssueChip({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: selected ? RT.redTint : Colors.white,
            borderRadius: BorderRadius.circular(30.r),
            border: Border.all(color: selected ? RT.red : RT.border, width: selected ? 1.8 : 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(selected ? Icons.check_rounded : icon, size: 17.sp, color: selected ? RT.red : RT.grey),
              SizedBox(width: 6.w),
              Text(label, style: _body(12.5, color: selected ? RT.red : RT.ink, w: FontWeight.w700)),
            ],
          ),
        ),
      );
}

class _HaveTile extends StatelessWidget {
  const _HaveTile({required this.art, required this.label, required this.on, required this.onTap});
  final String art;
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(vertical: 10.h),
          decoration: BoxDecoration(
            color: on ? RT.greenTint : Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: on ? RT.green : RT.border, width: on ? 1.8 : 1.2),
          ),
          child: Column(
            children: <Widget>[
              Opacity(opacity: on ? 1 : 0.45, child: ExArt(art, size: 46.w)),
              SizedBox(height: 4.h),
              Text(label, style: _head(12.5, w: FontWeight.w700)),
              Text(on ? 'I have it' : 'No', style: _body(10.5, color: on ? RT.green : RT.muted, w: FontWeight.w700)),
            ],
          ),
        ),
      );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: selected ? RT.blue : Colors.white,
            borderRadius: BorderRadius.circular(30.r),
            border: Border.all(color: selected ? RT.blue : RT.border, width: 1.2),
          ),
          child: Text(label, style: _body(12.5, color: selected ? Colors.white : RT.ink, w: FontWeight.w700)),
        ),
      );
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.message, required this.onBack, required this.onRetry});
  final String message;
  final VoidCallback onBack;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.all(28.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ExArt(kExSwap, size: 110.w),
            SizedBox(height: 14.h),
            Text('Exchange is not available here', style: _head(18), textAlign: TextAlign.center),
            SizedBox(height: 8.h),
            Text(message, style: _body(13.5), textAlign: TextAlign.center),
            SizedBox(height: 18.h),
            DealkerLoadingButton(label: 'Try again', onPressed: onRetry),
            TextButton(
              onPressed: onBack,
              child: Text('Go back', style: _body(13.5, color: RT.blue, w: FontWeight.w700)),
            ),
          ],
        ),
      );
}
