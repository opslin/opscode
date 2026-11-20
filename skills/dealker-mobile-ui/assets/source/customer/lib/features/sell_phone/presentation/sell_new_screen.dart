import 'package:dealker_app/shared/widgets/loading/dealker_page_loader.dart';
import 'package:dealker_app/shared/widgets/app_image.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:dealker_app/core/constants/api_constants.dart';
import 'package:dealker_app/core/utils/app_toast.dart';
import 'package:dealker_app/features/addresses/domain/entities/address_entity.dart';
import 'package:dealker_app/features/addresses/presentation/providers/address_provider.dart';
import 'package:dealker_app/features/exchange/data/exchange_models.dart';
import 'package:dealker_app/features/sell_phone/data/sell_models.dart';
import 'package:dealker_app/features/sell_phone/data/sell_repository.dart';
import 'package:dealker_app/features/sell_phone/presentation/imei_scanner_screen.dart';
import 'package:dealker_app/features/sell_phone/presentation/sell_providers.dart';
import 'package:dealker_app/core/theme/repair_tokens.dart';
import 'package:dealker_app/features/sell_phone/presentation/sell_qa.dart';
import 'package:dealker_app/features/sell_phone/presentation/sell_ui.dart';

enum _Cond { excellent, good, fair, damaged }

bool _imeiOk(String v) {
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

/// List a phone for sale: Device → IMEI → Condition → Estimate. The price band is the server's; real offers come from buyers.
class SellNewScreen extends ConsumerStatefulWidget {
  const SellNewScreen({super.key});

  @override
  ConsumerState<SellNewScreen> createState() => _SellNewScreenState();
}

class _SellNewScreenState extends ConsumerState<SellNewScreen> {
  static const List<String> _labels = <String>[
    'Phone',
    'Phone ID',
    'Condition',
    'Price',
  ];
  int _step = 0;

  // 1 · device
  final GlobalKey _modelsKey = GlobalKey();
  String? _brand;
  ExchangeModel? _model;
  String? _variant;
  String? _color;
  // phone / storage / colour that is not in our list: the customer types it
  bool _brandOther = false;
  bool _modelOther = false;
  bool _storageOther = false;
  bool _colorOther = false;
  final TextEditingController _customBrand = TextEditingController();
  final TextEditingController _customModel = TextEditingController();
  final TextEditingController _customPrice = TextEditingController();
  final TextEditingController _search = TextEditingController();
  String get _q => _search.text.trim();
  final TextEditingController _storageText = TextEditingController();
  final TextEditingController _colorText = TextEditingController();

  bool get _isCustomModel => _brandOther || _modelOther;
  String get _variantValue => _storageOther || _isCustomModel
      ? _storageText.text.trim()
      : (_variant ?? '');
  String get _colorValue =>
      _colorOther || _isCustomModel ? _colorText.text.trim() : (_color ?? '');
  String get _modelLabel => _isCustomModel
      ? '${_brandOther ? _customBrand.text.trim() : (_brand ?? '')} ${_customModel.text.trim()}'
          .trim()
      : (_model?.name ?? '');
  double get _customPriceValue =>
      double.tryParse(_customPrice.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  /// What the server needs to know about anything typed by hand (null when everything was picked).
  Map<String, dynamic>? get _custom {
    if (_isCustomModel) {
      return <String, dynamic>{
        'brand': _brandOther ? _customBrand.text.trim() : (_brand ?? ''),
        'model': _customModel.text.trim(),
        'expectedPrice': _customPriceValue.round(),
        'storage': true,
        'colour': true,
      };
    }
    if (_model != null && !_model!.hasPrice) {
      return <String, dynamic>{
        'storage': _storageOther,
        'colour': _colorOther,
        'expectedPrice': _customPriceValue.round(),
      };
    }
    if (_storageOther || _colorOther) {
      return <String, dynamic>{'storage': _storageOther, 'colour': _colorOther};
    }
    return null;
  }

  // 2 · IMEI
  final TextEditingController _imei = TextEditingController();
  ImeiCheck? _check;
  bool _checking = false;

  // 3 · condition
  _Cond _cond = _Cond.excellent;
  bool _screenCracked = false;
  bool _bodyDamage = false;
  bool _faceIdIssue = false;
  bool _cameraIssue = false;
  bool _bill = true;
  bool _box = true;
  bool _charger = true;
  int _age = 12;
  int _battery = 90;
  // guided photo slots (key -> photo); order of insertion is the upload order
  final Map<String, XFile> _slots = <String, XFile>{};
  List<XFile> get _photos => _slots.values.toList();
  final TextEditingController _note = TextEditingController();

  // 4 · estimate
  SellEstimate? _estimate;
  bool _busy = false;
  final TextEditingController _ask = TextEditingController();

  /// The price the customer typed (₹), 0 when empty.
  double get _askValue =>
      double.tryParse(_ask.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  @override
  void dispose() {
    _ask.dispose();
    _customBrand.dispose();
    _search.dispose();
    _customModel.dispose();
    _customPrice.dispose();
    _storageText.dispose();
    _colorText.dispose();
    _imei.dispose();
    _note.dispose();
    super.dispose();
  }

  ExchangeQa _qa() {
    final bool cracked =
        _screenCracked || _cond == _Cond.fair || _cond == _Cond.damaged;
    return ExchangeQa(
      ageMonths: _age,
      screenScratches: cracked
          ? 'MAJOR'
          : _cond == _Cond.good
              ? 'MINOR'
              : 'NONE',
      bodyDents: _bodyDamage || _cond == _Cond.damaged,
      screenReplaced: false,
      billAvailable: _bill,
      boxAvailable: _box,
      chargerAvailable: _charger,
      batteryHealth: _battery,
      faceIdIssue: _faceIdIssue,
      cameraIssue: _cameraIssue,
    );
  }

  /// Where the customer is, for "nearest buyer" distances. Comes from their default saved address.
  Future<({Map<String, dynamic>? loc, String? city})> _where() async {
    try {
      final List<AddressEntity> list = await ref.read(addressProvider.future);
      if (list.isEmpty) return (loc: null, city: null);
      final AddressEntity a = list.firstWhere(
        (AddressEntity e) => e.isDefault,
        orElse: () => list.first,
      );
      return (
        loc: <String, dynamic>{
          if (a.latitude != 0) 'lat': a.latitude,
          if (a.longitude != 0) 'lng': a.longitude,
          'pincode': a.pincode,
        },
        city: a.city,
      );
    } catch (_) {
      return (loc: null, city: null);
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      context.canPop() ? context.pop() : context.go('/home');
    }
  }

  Future<void> _verify() async {
    final String v = _imei.text.replaceAll(RegExp(r'\s'), '');
    if (!_imeiOk(v)) {
      AppToast.show(context, 'Enter the 15-digit IMEI (dial *#06# to see it)');
      return;
    }
    setState(() => _checking = true);
    try {
      final ImeiCheck c = await ref
          .read(sellRepositoryProvider)
          .verifyImei(v, modelId: _model?.id);
      if (!mounted) return;
      setState(() => _check = c);
    } catch (e) {
      if (mounted) AppToast.show(context, sellErrorMessage(e));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _pasteImei() async {
    final ClipboardData? d = await Clipboard.getData(Clipboard.kTextPlain);
    final String digits = (d?.text ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 15) {
      if (mounted) AppToast.show(context, 'Copy your 15-digit IMEI first');
      return;
    }
    setState(() {
      _imei.text = digits.substring(0, 15);
      _check = null;
    });
    await _verify();
  }

  Future<void> _scan() async {
    final String? code = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => const ImeiScannerScreen(),
        fullscreenDialog: true,
      ),
    );
    if (code == null || !mounted) return;
    setState(() {
      _imei.text = code;
      _check = null;
    });
    await _verify();
  }

  Future<void> _pickSlot(String key) async {
    final ImageSource? src = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22.r))),
      builder: (BuildContext c) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('Add photo', style: sellHead(17)),
              SizedBox(height: 12.h),
              Row(
                children: <Widget>[
                  Expanded(
                      child: SellButton('Camera',
                          icon: Icons.photo_camera_rounded,
                          onPressed: () =>
                              Navigator.pop(c, ImageSource.camera))),
                  SizedBox(width: 10.w),
                  Expanded(
                      child: SellButton('Gallery',
                          icon: Icons.photo_library_rounded,
                          outlined: true,
                          onPressed: () =>
                              Navigator.pop(c, ImageSource.gallery))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (src == null) return;
    try {
      final XFile? f = await ImagePicker()
          .pickImage(source: src, imageQuality: 82, maxWidth: 1800);
      if (f != null && mounted) setState(() => _slots[key] = f);
    } catch (_) {
      if (mounted) {
        AppToast.show(
          context,
          'Could not open the ${src == ImageSource.camera ? 'camera' : 'gallery'}',
        );
      }
    }
  }

  Future<void> _next() async {
    switch (_step) {
      case 0:
        if (_isCustomModel) {
          if ((_brandOther && _customBrand.text.trim().length < 2) ||
              _customModel.text.trim().length < 2) {
            AppToast.show(context, 'Type the brand and model of your phone');
            return;
          }
          if (_customPriceValue < 1000) {
            AppToast.show(
                context, 'Enter the price you expect (at least ₹1,000)');
            return;
          }
        } else if (_model == null) {
          AppToast.show(context, 'Choose the brand and model');
          return;
        }
        if (_variantValue.isEmpty || _colorValue.isEmpty) {
          AppToast.show(context, 'Choose or type the storage and colour');
          return;
        }
        if (!_isCustomModel &&
            _model != null &&
            !_model!.hasPrice &&
            _customPriceValue < 1000) {
          AppToast.show(
              context, 'Enter the price you expect (at least ₹1,000)');
          return;
        }
        setState(() => _step = 1);
      case 1:
        if (_check == null ||
            _check!.imei != _imei.text.replaceAll(RegExp(r'\s'), '')) {
          await _verify();
          return;
        }
        if (!_check!.eligible) return;
        setState(() => _step = 2);
      case 2:
        if (!_slots.containsKey('front') || !_slots.containsKey('back')) {
          AppToast.show(context, 'Please add the front and back photos');
          return;
        }
        await _getEstimate();
      default:
        await _list();
    }
  }

  Future<void> _getEstimate() async {
    setState(() => _busy = true);
    try {
      final ({Map<String, dynamic>? loc, String? city}) w = await _where();
      final SellEstimate e = await ref.read(sellRepositoryProvider).estimate(
            model: _isCustomModel ? null : _model,
            variant: _variantValue,
            color: _colorValue,
            imei: _imei.text.trim(),
            qa: _qa(),
            custom: _custom,
            location: w.loc,
            city: w.city,
          );
      if (!mounted) return;
      setState(() {
        _estimate = e;
        // Starting point only — the customer sets their own price.
        if (_askValue == 0) _ask.text = e.quote.round().toString();
        _step = 3;
      });
    } catch (e) {
      if (mounted) AppToast.show(context, sellErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _list() async {
    if (_askValue < 100) {
      AppToast.show(context, 'Enter the price you want for your phone.');
      return;
    }
    setState(() => _busy = true);
    try {
      final SellRepository repo = ref.read(sellRepositoryProvider);
      final List<String> ids = <String>[];
      for (final XFile p in _photos) {
        ids.add(await repo.uploadPhoto(p));
      }
      final ({Map<String, dynamic>? loc, String? city}) w = await _where();
      final String id = await repo.submit(
        model: _isCustomModel ? null : _model,
        variant: _variantValue,
        color: _colorValue,
        imei: _imei.text.trim(),
        qa: _qa(),
        custom: _custom,
        imeiCheckId: _check!.checkId,
        askingPrice: _askValue,
        mediaIds: ids,
        description: _note.text.trim(),
        location: w.loc,
        city: w.city,
      );
      ref.invalidate(mySalesProvider);
      if (!mounted) return;
      context.go('/sell/$id/offers');
    } catch (e) {
      if (mounted) AppToast.show(context, sellErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String cta = switch (_step) {
      0 => 'Continue',
      1 => _check != null &&
              _check!.eligible &&
              _check!.imei == _imei.text.replaceAll(RegExp(r'\s'), '')
          ? 'Continue'
          : 'Check IMEI',
      2 => 'See my price',
      _ => 'List my phone',
    };
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) _back();
      },
      child: SellScaffold(
        title: 'Sell your phone',
        onBack: _back,
        bottom: SellButton(cta, busy: _busy || _checking, onPressed: _next),
        child: Column(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 6.h),
              child: ReturnStepper(labels: _labels, current: _step),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
                child: switch (_step) {
                  0 => _deviceStep(),
                  1 => _imeiStep(),
                  2 => _conditionStep(),
                  _ => _estimateStep(),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 1 · device ──────────────────────────────────────────────────────────

  Widget _deviceStep() {
    final AsyncValue<List<ExchangeModel>> cat = ref.watch(sellCatalogProvider);
    return cat.when(
      loading: () => Padding(
        padding: EdgeInsets.only(top: 80.h),
        child: const DealkerPageLoader(),
      ),
      error: (Object e, _) => Padding(
        padding: EdgeInsets.only(top: 60.h),
        child: Column(
          children: <Widget>[
            Text(
              'We could not load the phone list.',
              style: TextStyle(fontSize: 14.sp, color: ReturnColors.muted),
            ),
            TextButton(
              onPressed: () => ref.invalidate(sellCatalogProvider),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
      data: (List<ExchangeModel> all) {
        final List<ExchangeModel> phones =
            all.where((ExchangeModel m) => m.category == 'Smartphone').toList();
        final Map<String, String?> brands = <String, String?>{};
        for (final ExchangeModel m in phones) {
          final String b = m.brand ?? 'Other';
          brands.putIfAbsent(b, () => m.brandLogoUrl);
          if (brands[b] == null && m.brandLogoUrl != null) {
            brands[b] = m.brandLogoUrl;
          }
        }
        final List<ExchangeModel> models = phones
            .where((ExchangeModel m) => (m.brand ?? 'Other') == _brand)
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SellHeading(
              'Which phone do you have?',
              subtitle: 'Tap the brand first, then tap the model.',
            ),
            if (brands.isEmpty)
              const SellInlineMessage(
                'No phones can be sold right now. Please check back soon.',
                tone: SellTone.warn,
              ),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search brand or model (e.g. Galaxy S24)',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _q.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(_search.clear),
                      ),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.r),
                  borderSide: const BorderSide(color: ReturnColors.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.r),
                  borderSide: const BorderSide(color: ReturnColors.line),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            if (_q.length >= 2)
              ..._searchResults(phones)
            else ...<Widget>[
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10.h,
                crossAxisSpacing: 10.w,
                childAspectRatio: 1.15,
                children: <Widget>[
                  ...brands.entries.map((MapEntry<String, String?> e) {
                    final bool sel = e.key == _brand;
                    final String? logo = ApiConstants.resolveMediaUrl(e.value);
                    return Semantics(
                      button: true,
                      selected: sel,
                      label: e.key,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14.r),
                        onTap: () {
                          setState(() {
                            _brand = e.key;
                            _brandOther = false;
                            _modelOther = false;
                            _storageOther = false;
                            _colorOther = false;
                            _model = null;
                            _variant = null;
                            _color = null;
                          });
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            final BuildContext? c = _modelsKey.currentContext;
                            if (c != null) {
                              Scrollable.ensureVisible(
                                c,
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeOut,
                              );
                            }
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: sel ? ReturnColors.indigoSoft : Colors.white,
                            borderRadius: BorderRadius.circular(14.r),
                            border: Border.all(
                              color:
                                  sel ? ReturnColors.indigo : ReturnColors.line,
                              width: sel ? 1.8 : 1,
                            ),
                          ),
                          padding: EdgeInsets.all(8.w),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              if (logo != null)
                                SizedBox(
                                  height: 34.h,
                                  child: CachedNetworkImage(
                                    imageUrl: webImageSource(logo),
                                    fit: BoxFit.contain,
                                    errorWidget: (_, __, ___) =>
                                        const SizedBox.shrink(),
                                  ),
                                )
                              else
                                Icon(
                                  Icons.smartphone_rounded,
                                  size: 28.sp,
                                  color: ReturnColors.muted,
                                ),
                              SizedBox(height: 6.h),
                              Text(
                                e.key,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                  color: ReturnColors.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  _otherTile(
                    label: 'Other brand',
                    selected: _brandOther,
                    onTap: () => setState(() {
                      _brandOther = true;
                      _modelOther = true;
                      _brand = null;
                      _model = null;
                      _variant = null;
                      _color = null;
                    }),
                  ),
                ],
              ),
              if (_brandOther || _modelOther) ...<Widget>[
                SizedBox(height: 16.h),
                _customPhoneCard(),
              ],
              if (_brand != null && !_brandOther) ...<Widget>[
                SizedBox(height: 18.h),
                Text(
                  'Model',
                  key: _modelsKey,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontFamily: RT.head,
                    fontWeight: FontWeight.w800,
                    color: ReturnColors.ink,
                  ),
                ),
                SizedBox(height: 8.h),
                ..._seriesGrouped(models).map((Object item) {
                  if (item is String) {
                    return Padding(
                      padding: EdgeInsets.only(top: 6.h, bottom: 6.h),
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w800,
                          color: ReturnColors.muted,
                          letterSpacing: 0.3,
                        ),
                      ),
                    );
                  }
                  final ExchangeModel m = item as ExchangeModel;
                  final bool sel = !_modelOther && _model?.id == m.id;
                  return Padding(
                    padding: EdgeInsets.only(bottom: 8.h),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12.r),
                      onTap: () => setState(() {
                        _model = m;
                        _modelOther = false;
                        _storageOther = false;
                        _colorOther = false;
                        _variant =
                            m.variants.isNotEmpty ? m.variants.last : null;
                        _color = m.colors.isNotEmpty ? m.colors.first : null;
                      }),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 12.h,
                        ),
                        decoration: BoxDecoration(
                          color: sel ? ReturnColors.indigoSoft : Colors.white,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color:
                                sel ? ReturnColors.indigo : ReturnColors.line,
                            width: sel ? 1.8 : 1,
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                m.name,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w700,
                                  color: ReturnColors.ink,
                                ),
                              ),
                            ),
                            if (sel)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: ReturnColors.indigo,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                _otherModelRow(),
              ],
            ],
            if (_model != null && !_modelOther) ...<Widget>[
              SizedBox(height: 14.h),
              Text(
                'Storage',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontFamily: RT.head,
                  fontWeight: FontWeight.w800,
                  color: ReturnColors.ink,
                ),
              ),
              SizedBox(height: 8.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: <Widget>[
                  ..._model!.variants.map(
                    (String v) => SellChoice(
                      label: v,
                      selected: !_storageOther && _variant == v,
                      onTap: () => setState(() {
                        _variant = v;
                        _storageOther = false;
                      }),
                    ),
                  ),
                  SellChoice(
                    label: 'Other',
                    sub: 'Type it',
                    selected: _storageOther,
                    onTap: () => setState(() => _storageOther = true),
                  ),
                ],
              ),
              if (_storageOther) ...<Widget>[
                SizedBox(height: 10.h),
                QaTypeBox(
                  controller: _storageText,
                  label: 'Storage (e.g. 512 GB)',
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) => setState(() {}),
                ),
              ],
              SizedBox(height: 14.h),
              Text(
                'Colour',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontFamily: RT.head,
                  fontWeight: FontWeight.w800,
                  color: ReturnColors.ink,
                ),
              ),
              SizedBox(height: 8.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: <Widget>[
                  ..._model!.colors.map(
                    (String v) => SellChoice(
                      label: v,
                      selected: !_colorOther && _color == v,
                      onTap: () => setState(() {
                        _color = v;
                        _colorOther = false;
                      }),
                    ),
                  ),
                  SellChoice(
                    label: 'Other',
                    sub: 'Type it',
                    selected: _colorOther,
                    onTap: () => setState(() => _colorOther = true),
                  ),
                ],
              ),
              if (_colorOther) ...<Widget>[
                SizedBox(height: 10.h),
                QaTypeBox(
                  controller: _colorText,
                  label: 'Colour (e.g. Sunset Gold)',
                  onChanged: (_) => setState(() {}),
                ),
              ],
              if (!_model!.hasPrice) ...<Widget>[
                SizedBox(height: 16.h),
                Text(
                  'Price you expect',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontFamily: RT.head,
                    fontWeight: FontWeight.w800,
                    color: ReturnColors.ink,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'We have no fixed price for this model. Tell us what you expect and buyers will send offers.',
                  style: TextStyle(fontSize: 12.sp, color: ReturnColors.muted),
                ),
                SizedBox(height: 8.h),
                QaTypeBox(
                  controller: _customPrice,
                  label: 'Expected price in ₹ (e.g. 18000)',
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ],
          ],
        );
      },
    );
  }

  /// Models of one brand, with the series name as a heading before each group (iPhone 17 Series, Galaxy S Series ...).
  List<Object> _seriesGrouped(List<ExchangeModel> models) {
    final List<Object> out = <Object>[];
    String? last;
    for (final ExchangeModel m in models) {
      final String? s = m.series;
      if (s != null && s != last) {
        out.add(s);
        last = s;
      }
      out.add(m);
    }
    return out;
  }

  /// Search across every brand and model: the customer types "s24" or "redmi note" and taps the phone.
  List<Widget> _searchResults(List<ExchangeModel> phones) {
    final List<String> tokens = _q
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((String t) => t.isNotEmpty)
        .toList();
    final List<ExchangeModel> hits = phones
        .where((ExchangeModel m) {
          final String hay =
              '${m.brand ?? ''} ${m.name} ${m.series ?? ''}'.toLowerCase();
          return tokens.every(hay.contains);
        })
        .take(40)
        .toList();
    if (hits.isEmpty) {
      return <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(vertical: 18.h),
          child: Text(
            'No phone found. Clear the search and tap "Other brand" to type yours.',
            style: TextStyle(fontSize: 13.sp, color: ReturnColors.muted),
          ),
        ),
      ];
    }
    return hits.map((ExchangeModel m) {
      final bool sel = !_modelOther && _model?.id == m.id;
      final String? logo = ApiConstants.resolveMediaUrl(m.brandLogoUrl);
      return Padding(
        padding: EdgeInsets.only(bottom: 8.h),
        child: InkWell(
          borderRadius: BorderRadius.circular(12.r),
          onTap: () => setState(() {
            _brand = m.brand ?? 'Other';
            _brandOther = false;
            _modelOther = false;
            _storageOther = false;
            _colorOther = false;
            _model = m;
            _variant = m.variants.isNotEmpty ? m.variants.last : null;
            _color = m.colors.isNotEmpty ? m.colors.first : null;
            _search.clear();
          }),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: sel ? ReturnColors.indigoSoft : Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: sel ? ReturnColors.indigo : ReturnColors.line,
                width: sel ? 1.8 : 1,
              ),
            ),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 46.w,
                  height: 26.h,
                  child: logo == null
                      ? const SizedBox.shrink()
                      : CachedNetworkImage(
                          imageUrl: webImageSource(logo),
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) => const SizedBox.shrink(),
                        ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        m.name,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: ReturnColors.ink,
                        ),
                      ),
                      Text(
                        <String>[
                          if (m.brand != null) m.brand!,
                          if (m.series != null) m.series!,
                        ].join(' · '),
                        style: TextStyle(
                            fontSize: 11.sp, color: ReturnColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _otherTile({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) =>
      InkWell(
        borderRadius: BorderRadius.circular(14.r),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: selected ? ReturnColors.indigoSoft : Colors.white,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: selected ? ReturnColors.indigo : ReturnColors.line,
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.edit_rounded, size: 26.sp, color: ReturnColors.indigo),
              SizedBox(height: 6.h),
              Text(label,
                  style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: ReturnColors.ink)),
            ],
          ),
        ),
      );

  Widget _otherModelRow() {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: () => setState(() {
          _modelOther = true;
          _model = null;
          _variant = null;
          _color = null;
        }),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: _modelOther ? ReturnColors.indigoSoft : Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: _modelOther ? ReturnColors.indigo : ReturnColors.line,
              style: BorderStyle.solid,
              width: _modelOther ? 1.8 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(Icons.edit_rounded, size: 18.sp, color: ReturnColors.indigo),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  'My model is not in this list',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: ReturnColors.indigo,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Everything the customer types when their phone is not listed: name, price they expect, storage, colour.
  Widget _customPhoneCard() {
    return SellCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Tell us about your phone', style: sellHead(15)),
          SizedBox(height: 4.h),
          Text('We do not have it in our list, so type the details.',
              style: sellBody(12)),
          SizedBox(height: 12.h),
          if (_brandOther) ...<Widget>[
            QaTypeBox(
              controller: _customBrand,
              label: 'Brand (e.g. Nothing)',
              onChanged: (_) => setState(() {}),
            ),
            SizedBox(height: 10.h),
          ],
          QaTypeBox(
            controller: _customModel,
            label: 'Model name (e.g. Phone 2a)',
            onChanged: (_) => setState(() {}),
          ),
          SizedBox(height: 10.h),
          Row(
            children: <Widget>[
              Expanded(
                child: QaTypeBox(
                  controller: _storageText,
                  label: 'Storage',
                  hint: '128 GB',
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: QaTypeBox(
                  controller: _colorText,
                  label: 'Colour',
                  hint: 'Black',
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          QaTypeBox(
            controller: _customPrice,
            label: 'Price you expect (₹)',
            prefix: '₹ ',
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  // ── 2 · IMEI ────────────────────────────────────────────────────────────

  Widget _imeiStep() {
    final String typed = _imei.text.replaceAll(RegExp(r'\s'), '');
    final ImeiCheck? c =
        _check != null && _check!.imei == typed ? _check : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SellHeading(
          'Your phone ID (IMEI)',
          subtitle:
              'Every phone has a 15-number ID. Dial *#06# on your phone to see it, then type it here or scan it.',
        ),
        SellCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '$_modelLabel · $_variantValue · $_colorValue',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: ReturnColors.ink,
                ),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: _imei,
                keyboardType: TextInputType.number,
                maxLength: 15,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                onChanged: (_) => setState(() {}),
                style: TextStyle(
                  fontSize: 16.sp,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  labelText: '15-digit IMEI',
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              Row(
                children: <Widget>[
                  Expanded(
                    child: SellButton(
                      'Paste',
                      icon: Icons.content_paste_rounded,
                      outlined: true,
                      onPressed: _pasteImei,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: SellButton(
                      'Scan',
                      icon: Icons.qr_code_scanner_rounded,
                      outlined: true,
                      onPressed: _scan,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (c != null) ...<Widget>[
          SizedBox(height: 14.h),
          SellCard(
            border: c.eligible
                ? ReturnColors.green.withValues(alpha: 0.4)
                : ReturnColors.red.withValues(alpha: 0.4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      c.eligible ? Icons.verified_rounded : Icons.block_rounded,
                      color: c.eligible ? ReturnColors.green : ReturnColors.red,
                      size: 26.sp,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        c.eligible
                            ? 'This phone can be sold'
                            : 'This phone cannot be sold',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontFamily: RT.head,
                          fontWeight: FontWeight.w800,
                          color: c.eligible
                              ? ReturnColors.green
                              : ReturnColors.red,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                ...c.checks.map(
                  (ImeiCheckItem i) => Padding(
                    padding: EdgeInsets.only(bottom: 8.h),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          switch (i.status) {
                            'PASS' => Icons.check_circle_rounded,
                            'FAIL' => Icons.cancel_rounded,
                            'WARN' => Icons.warning_amber_rounded,
                            _ => Icons.info_outline_rounded
                          },
                          size: 18.sp,
                          color: switch (i.status) {
                            'PASS' => ReturnColors.green,
                            'FAIL' => ReturnColors.red,
                            'WARN' => ReturnColors.amber,
                            _ => ReturnColors.muted
                          },
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                i.label,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                  color: ReturnColors.ink,
                                ),
                              ),
                              if (i.message != null)
                                Text(
                                  i.message!,
                                  style: TextStyle(
                                    fontSize: 11.5.sp,
                                    height: 1.3,
                                    color: ReturnColors.muted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── 3 · condition ───────────────────────────────────────────────────────

  Widget _conditionStep() {
    final int maxPhotos =
        ref.watch(sellConfigProvider).asData?.value.maxImages ?? 8;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SellHeading(
          'Check your phone',
          subtitle:
              'Answer with a tap. Be honest - the buyer checks the phone and the price follows what they find.',
        ),
        const QaSection(1, 'How does it look overall?'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10.h,
          crossAxisSpacing: 10.w,
          childAspectRatio: 1.12,
          children: <Widget>[
            QaGradeTile(
              asset: QaArt.likeNew,
              label: 'Like new',
              sub: 'No marks at all',
              tint: ReturnColors.green,
              selected: _cond == _Cond.excellent,
              onTap: () => setState(() => _cond = _Cond.excellent),
            ),
            QaGradeTile(
              asset: QaArt.good,
              label: 'Good',
              sub: 'Light use, tiny marks',
              selected: _cond == _Cond.good,
              onTap: () => setState(() => _cond = _Cond.good),
            ),
            QaGradeTile(
              asset: QaArt.worn,
              label: 'Fair',
              sub: 'Clear scratches or wear',
              tint: ReturnColors.amber,
              selected: _cond == _Cond.fair,
              onTap: () => setState(() => _cond = _Cond.fair),
            ),
            QaGradeTile(
              asset: QaArt.damaged,
              label: 'Damaged',
              sub: 'Cracks or dents',
              tint: ReturnColors.red,
              selected: _cond == _Cond.damaged,
              onTap: () => setState(() => _cond = _Cond.damaged),
            ),
          ],
        ),
        const QaSection(2, 'Does everything work?',
            subtitle: 'Tap the one that matches your phone.'),
        QaCheckCard(
          asset: QaArt.screen,
          question: 'Screen',
          goodLabel: 'No cracks',
          badLabel: 'Cracked',
          hasIssue: _screenCracked,
          onChanged: (bool v) => setState(() => _screenCracked = v),
        ),
        QaCheckCard(
          asset: QaArt.body,
          question: 'Body and frame',
          goodLabel: 'No dents',
          badLabel: 'Dented',
          hasIssue: _bodyDamage,
          onChanged: (bool v) => setState(() => _bodyDamage = v),
        ),
        QaCheckCard(
          asset: QaArt.touch,
          question: 'Face ID / fingerprint',
          goodLabel: 'Works',
          badLabel: 'Not working',
          hasIssue: _faceIdIssue,
          onChanged: (bool v) => setState(() => _faceIdIssue = v),
        ),
        QaCheckCard(
          asset: QaArt.camera,
          question: 'Cameras',
          goodLabel: 'Work well',
          badLabel: 'Problem',
          hasIssue: _cameraIssue,
          onChanged: (bool v) => setState(() => _cameraIssue = v),
        ),
        const QaSection(3, 'How old is it?'),
        QaChoiceStrip<int>(
          value: _age,
          onChanged: (int v) => setState(() => _age = v),
          options: const <({int value, String label, String sub})>[
            (value: 3, label: 'Under 6', sub: 'months'),
            (value: 9, label: '6 - 12', sub: 'months'),
            (value: 18, label: '1 - 2', sub: 'years'),
            (value: 30, label: '2 - 3', sub: 'years'),
            (value: 48, label: '3 - 4', sub: 'years'),
            (value: 60, label: 'Over 4', sub: 'years'),
          ],
        ),
        const QaSection(4, 'Battery health',
            subtitle: 'Settings > Battery shows this on most phones.'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            QaImage(QaArt.battery, size: 54.w),
            SizedBox(width: 10.w),
            Expanded(
              child: QaChoiceStrip<int>(
                value: _battery,
                onChanged: (int v) => setState(() => _battery = v),
                options: const <({int value, String label, String sub})>[
                  (value: 97, label: '95%+', sub: 'Excellent'),
                  (value: 90, label: '85 - 94%', sub: 'Good'),
                  (value: 80, label: '75 - 84%', sub: 'Average'),
                  (value: 65, label: 'Below 75%', sub: 'Weak'),
                ],
              ),
            ),
          ],
        ),
        const QaSection(5, 'What comes with it?',
            subtitle: 'Tap to include. Having these gets you a better offer.'),
        Row(
          children: <Widget>[
            Expanded(
              child: QaAccessoryTile(
                asset: QaArt.bill,
                label: 'Bill',
                value: _bill,
                onChanged: (bool v) => setState(() => _bill = v),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: QaAccessoryTile(
                asset: QaArt.box,
                label: 'Box',
                value: _box,
                onChanged: (bool v) => setState(() => _box = v),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: QaAccessoryTile(
                asset: QaArt.charger,
                label: 'Charger',
                value: _charger,
                onChanged: (bool v) => setState(() => _charger = v),
              ),
            ),
          ],
        ),
        QaSection(6, 'Add photos',
            subtitle:
                'Front and back are needed. ${_slots.length} of ${maxPhotos < 6 ? maxPhotos : 6} added. Only buyers who make an offer can see them.'),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10.h,
          crossAxisSpacing: 10.w,
          childAspectRatio: 0.92,
          children: <Widget>[
            for (final ({
              String key,
              String label,
              String hint,
              IconData icon,
              bool req
            }) t in <({
              String key,
              String label,
              String hint,
              IconData icon,
              bool req
            })>[
              (
                key: 'front',
                label: 'Front',
                hint: 'Whole screen, screen off',
                icon: Icons.smartphone_rounded,
                req: true
              ),
              (
                key: 'back',
                label: 'Back',
                hint: 'Back panel and camera',
                icon: Icons.flip_camera_android_rounded,
                req: true
              ),
              (
                key: 'screenOn',
                label: 'Screen on',
                hint: 'Shows any dead spots',
                icon: Icons.light_mode_rounded,
                req: false
              ),
              (
                key: 'sides',
                label: 'Sides',
                hint: 'Frame, buttons, corners',
                icon: Icons.crop_portrait_rounded,
                req: false
              ),
              (
                key: 'about',
                label: 'Settings page',
                hint: 'About phone / IMEI',
                icon: Icons.info_outline_rounded,
                req: false
              ),
              (
                key: 'damage',
                label: 'Damage',
                hint: 'Close-up of any crack',
                icon: Icons.zoom_in_rounded,
                req: false
              ),
            ])
              QaPhotoSlot(
                label: t.label,
                hint: t.hint,
                icon: t.icon,
                required: t.req,
                file: _slots[t.key],
                onTap: () => _pickSlot(t.key),
                onRemove: () => setState(() => _slots.remove(t.key)),
              ),
          ],
        ),
        SizedBox(height: 16.h),
        TextField(
          controller: _note,
          maxLines: 2,
          maxLength: 300,
          decoration: InputDecoration(
            labelText: 'Anything else the buyer should know? (optional)',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
        ),
      ],
    );
  }

  // ── 4 · estimate ────────────────────────────────────────────────────────

  Widget _estimateStep() {
    final SellEstimate e = _estimate!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SellHeading(
          'Set your price',
          subtitle:
              'You decide the price you want. Buyers will send offers. You can chat with them, and you only accept the one you like.',
        ),
        SellCard(
          tint: ReturnColors.indigoSoft,
          border: ReturnColors.indigoLine,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                deviceTitle(_modelLabel, _variantValue),
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: ReturnColors.muted,
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                'Your asking price',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: ReturnColors.ink,
                ),
              ),
              SizedBox(height: 6.h),
              TextField(
                controller: _ask,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(7),
                ],
                onChanged: (_) => setState(() {}),
                style: TextStyle(
                  fontSize: 24.sp,
                  fontFamily: RT.head,
                  fontWeight: FontWeight.w900,
                  color: ReturnColors.ink,
                ),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  prefixStyle: TextStyle(
                    fontSize: 24.sp,
                    fontFamily: RT.head,
                    fontWeight: FontWeight.w900,
                    color: ReturnColors.ink,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide:
                        const BorderSide(color: ReturnColors.indigoLine),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: const BorderSide(
                        color: ReturnColors.indigo, width: 1.6),
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              _askHint(e),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        SellCard(
          child: Row(
            children: <Widget>[
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 20.sp,
                color: ReturnColors.indigo,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Dealkr suggests ${inrRange(e.estimateMin, e.estimateMax)}',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontFamily: RT.head,
                        fontWeight: FontWeight.w800,
                        color: ReturnColors.ink,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'For a phone in ${e.conditionLabel.toLowerCase()} condition. Just a guide — your price is the one buyers see.',
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        height: 1.35,
                        color: ReturnColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        SellInlineMessage(
          e.vendorsNearby > 0
              ? '${e.vendorsNearby} verified buyer${e.vendorsNearby == 1 ? '' : 's'} nearby can offer on your phone. Offers stay open for ${_window(e.offerWindowMinutes)}; you can refresh them.'
              : 'No verified buyers are in your area yet. You can still list it and buyers will be able to offer.',
          tone: e.vendorsNearby > 0 ? SellTone.info : SellTone.warn,
          icon: Icons.storefront_rounded,
        ),
        if (e.deductions.isNotEmpty) ...<Widget>[
          SizedBox(height: 14.h),
          SellCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'What affects the price',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontFamily: RT.head,
                    fontWeight: FontWeight.w800,
                    color: ReturnColors.ink,
                  ),
                ),
                SizedBox(height: 6.h),
                ...e.deductions.map(
                  (String d) => Padding(
                    padding: EdgeInsets.only(bottom: 4.h),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.remove_circle_outline_rounded,
                          size: 15.sp,
                          color: ReturnColors.muted,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            d,
                            style: TextStyle(
                              fontSize: 12.5.sp,
                              color: ReturnColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        SizedBox(height: 12.h),
        Text(
          'Buyers may offer more or less than your price. The amount you are paid is the offer you accept, confirmed again when the buyer inspects your phone.',
          style: TextStyle(
            fontSize: 11.5.sp,
            height: 1.4,
            color: ReturnColors.muted,
          ),
        ),
      ],
    );
  }

  /// Plain guidance next to the price box — never blocks the customer.
  Widget _askHint(SellEstimate e) {
    final double v = _askValue;
    String text;
    Color color = ReturnColors.muted;
    if (v < 100) {
      text = 'Enter the price you want.';
    } else if (v > e.estimateMax * 1.1) {
      text = 'Above the suggested range — fewer buyers may offer.';
      color = const Color(0xFFB45309);
    } else if (v < e.estimateMin) {
      text = 'Below the suggested range — you will likely get offers quickly.';
    } else {
      text = 'Within the suggested range.';
      color = ReturnColors.green;
    }
    return Text(
      text,
      style: TextStyle(
        fontSize: 11.5.sp,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }

  String _window(int minutes) => minutes % 60 == 0
      ? '${minutes ~/ 60} hour${minutes == 60 ? '' : 's'}'
      : '$minutes minutes';
}
