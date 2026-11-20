import 'package:flutter/material.dart';

Color _parseColor(String? hex, Color fallback) {
  if (hex == null || hex.isEmpty) {
    return fallback;
  }

  final cleaned = hex.replaceFirst('#', '');
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) {
    return fallback;
  }

  return Color(0xFF000000 | value);
}

List<Color> _parseGradient(List<dynamic>? values, List<Color> fallback) {
  if (values == null || values.length < 2) {
    return fallback;
  }

  return <Color>[
    _parseColor(_parseNullableString(values[0]), fallback[0]),
    _parseColor(_parseNullableString(values[1]), fallback[1]),
  ];
}

String _colorToHex(Color color) {
  final hex = color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);
  return '#${hex.toUpperCase()}';
}

List<String> _parseStringList(dynamic value, List<String> fallback) {
  if (value is! List) {
    return List<String>.from(fallback);
  }

  final parsed = value
      .whereType<String>()
      .map((String item) => item.trim())
      .where((String item) => item.isNotEmpty)
      .toList();
  if (parsed.isEmpty) {
    return List<String>.from(fallback);
  }

  return parsed;
}

String? _parseNullableString(dynamic value) {
  if (value is! String) {
    return null;
  }

  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

List<dynamic>? _asList(dynamic value) {
  return value is List ? value.cast<dynamic>() : null;
}

bool _parseBool(dynamic value, bool fallback) {
  return value is bool ? value : fallback;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return <String, dynamic>{};
}

List<String> _gradientToHex(List<Color> colors) {
  return colors.map(_colorToHex).toList();
}

class TopBarTheme {
  const TopBarTheme({required this.backgroundColor, required this.textColor});

  final Color backgroundColor;
  final Color textColor;

  factory TopBarTheme.fromJson(Map<String, dynamic> json) {
    final defaults = TopBarTheme.defaults();
    return TopBarTheme(
      backgroundColor: _parseColor(
        _parseNullableString(json['backgroundColor']),
        defaults.backgroundColor,
      ),
      textColor: _parseColor(
        _parseNullableString(json['textColor']),
        defaults.textColor,
      ),
    );
  }

  factory TopBarTheme.defaults() => const TopBarTheme(
        backgroundColor: Color(0xFF88D4FE),
        textColor: Color(0xFF000000),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'backgroundColor': _colorToHex(backgroundColor),
        'textColor': _colorToHex(textColor),
      };
}

class StoreSelectorTheme {
  const StoreSelectorTheme({
    required this.backgroundColor,
    required this.activeChipColor,
  });

  final Color backgroundColor;
  final Color activeChipColor;

  factory StoreSelectorTheme.fromJson(Map<String, dynamic> json) {
    final defaults = StoreSelectorTheme.defaults();
    return StoreSelectorTheme(
      backgroundColor: _parseColor(
        _parseNullableString(json['backgroundColor']),
        defaults.backgroundColor,
      ),
      activeChipColor: _parseColor(
        _parseNullableString(json['activeChipColor']),
        defaults.activeChipColor,
      ),
    );
  }

  factory StoreSelectorTheme.defaults() => const StoreSelectorTheme(
        backgroundColor: Color(0xFF88D4FE),
        activeChipColor: Color(0xFFB1EAFF),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'backgroundColor': _colorToHex(backgroundColor),
        'activeChipColor': _colorToHex(activeChipColor),
      };
}

class CategoryTabsTheme {
  const CategoryTabsTheme({
    required this.visible,
    required this.textColor,
    required this.indicatorColor,
    this.backgroundColor,
  });

  final bool visible;
  final Color textColor;
  final Color indicatorColor;

  /// Optional independent background for the category-tabs container row.
  /// When null, the parent [SearchZoneTheme.backgroundColor] is used (legacy behavior).
  final Color? backgroundColor;

  factory CategoryTabsTheme.fromJson(Map<String, dynamic> json) {
    final defaults = CategoryTabsTheme.defaults();
    return CategoryTabsTheme(
      visible: _parseBool(json['visible'], defaults.visible),
      textColor: _parseColor(
        _parseNullableString(json['textColor']),
        defaults.textColor,
      ),
      indicatorColor: _parseColor(
        _parseNullableString(json['indicatorColor']),
        defaults.indicatorColor,
      ),
      // backgroundColor is additive — null means "inherit from search zone" (backward compat)
      backgroundColor: json['backgroundColor'] != null
          ? _parseColor(
              _parseNullableString(json['backgroundColor']),
              defaults
                  .textColor, // dummy fallback — null is returned when key absent
            )
          : null,
    );
  }

  factory CategoryTabsTheme.defaults() => const CategoryTabsTheme(
        visible: true,
        textColor: Color(0xFF111827),
        indicatorColor: Color(0xFF111827),
        backgroundColor: null,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'visible': visible,
        'textColor': _colorToHex(textColor),
        'indicatorColor': _colorToHex(indicatorColor),
        if (backgroundColor != null)
          'backgroundColor': _colorToHex(backgroundColor!),
      };
}

class SearchZoneTheme {
  SearchZoneTheme({
    required this.backgroundColor,
    required this.waveColor,
    required this.searchHints,
    required this.promoBoxImageUrl,
    this.sellBoxImageUrl,
  });

  final Color backgroundColor;
  final Color waveColor;
  final List<String> searchHints;
  final String? promoBoxImageUrl;

  /// Image-only "Mobile Sell" box next to the search bar (no text/icon is
  /// drawn by the app — whatever is in the image is what shows).
  final String? sellBoxImageUrl;

  static const List<String> _defaultSearchHints = <String>[
    'iPhone 15',
    'Samsung Galaxy',
    'wireless earbuds',
    'power bank',
    'smart watch',
    'phone cover',
  ];

  factory SearchZoneTheme.fromJson(Map<String, dynamic> json) {
    final defaults = SearchZoneTheme.defaults();
    return SearchZoneTheme(
      backgroundColor: _parseColor(
        _parseNullableString(json['backgroundColor']),
        defaults.backgroundColor,
      ),
      waveColor: _parseColor(
        _parseNullableString(json['waveColor']),
        defaults.waveColor,
      ),
      searchHints: _parseStringList(json['searchHints'], defaults.searchHints),
      promoBoxImageUrl: _parseNullableString(json['promoBoxImageUrl']),
      sellBoxImageUrl: _parseNullableString(json['sellBoxImageUrl']),
    );
  }

  factory SearchZoneTheme.defaults() => SearchZoneTheme(
        backgroundColor: const Color(0xFFB1EAFF),
        waveColor: const Color(0xFF88D4FE),
        searchHints: List<String>.from(_defaultSearchHints),
        promoBoxImageUrl: null,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'backgroundColor': _colorToHex(backgroundColor),
        'waveColor': _colorToHex(waveColor),
        'searchHints': List<String>.from(searchHints),
        'promoBoxImageUrl': promoBoxImageUrl,
        'sellBoxImageUrl': sellBoxImageUrl,
      };
}

class BannerAnimationTheme {
  BannerAnimationTheme({
    required this.imageUrl,
    required this.lottieUrl,
    required this.backgroundGradient,
    required this.containerColor,
  });

  final String? imageUrl;
  final String? lottieUrl;
  final List<Color> backgroundGradient;
  final Color containerColor;

  factory BannerAnimationTheme.fromJson(Map<String, dynamic> json) {
    final defaults = BannerAnimationTheme.defaults();
    return BannerAnimationTheme(
      imageUrl: _parseNullableString(json['imageUrl']),
      lottieUrl: _parseNullableString(json['lottieUrl']),
      backgroundGradient: _parseGradient(
        _asList(json['backgroundGradient']),
        defaults.backgroundGradient,
      ),
      containerColor: _parseColor(
        _parseNullableString(json['containerColor']),
        defaults.containerColor,
      ),
    );
  }

  factory BannerAnimationTheme.defaults() => BannerAnimationTheme(
        imageUrl: null,
        lottieUrl: null,
        backgroundGradient: <Color>[
          const Color(0xFFB1EAFF),
          const Color(0xFFA8E6FF),
        ],
        containerColor: const Color(0xFFD8F4FF),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'imageUrl': imageUrl,
        'lottieUrl': lottieUrl,
        'backgroundGradient': _gradientToHex(backgroundGradient),
        'containerColor': _colorToHex(containerColor),
      };
}

class FeeStripTheme {
  const FeeStripTheme({required this.imageUrl, required this.visible});

  final String? imageUrl;
  final bool visible;

  factory FeeStripTheme.fromJson(Map<String, dynamic> json) {
    final defaults = FeeStripTheme.defaults();
    return FeeStripTheme(
      imageUrl: _parseNullableString(json['imageUrl']),
      visible: _parseBool(json['visible'], defaults.visible),
    );
  }

  factory FeeStripTheme.defaults() =>
      const FeeStripTheme(imageUrl: null, visible: true);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'imageUrl': imageUrl,
        'visible': visible,
      };
}

/// A tap action attached to a mosaic tile. Additive + nullable so legacy
/// themes (which never stored an action) keep their original behaviour of
/// navigating to the resolved product.
class MosaicTileAction {
  const MosaicTileAction({required this.type, this.value});

  /// none | product | category | tab | app_page | external_url
  final String type;
  final String? value;

  bool get isNone => type == 'none' || type.isEmpty;

  bool get isActionable {
    if (isNone) return false;
    if (type == 'tab' || type == 'app_page') {
      return value != null && value!.isNotEmpty;
    }
    if (type == 'product' || type == 'category' || type == 'external_url') {
      return value != null && value!.isNotEmpty;
    }
    return false;
  }

  static MosaicTileAction? fromJson(dynamic json) {
    if (json is! Map) return null;
    final map = Map<String, dynamic>.from(json);
    final type = _parseNullableString(map['type']);
    if (type == null || type == 'none') return null;
    return MosaicTileAction(
      type: type,
      value: _parseNullableString(map['value']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type,
        'value': value,
      };
}

class HeroTileTheme {
  HeroTileTheme({
    required this.title,
    required this.gradient,
    required this.badgeText,
    required this.badgeGradient,
    this.imageUrl,
    this.action,
  });

  final String title;
  final List<Color> gradient;
  final String badgeText;
  final List<Color> badgeGradient;
  final String? imageUrl;
  final MosaicTileAction? action;

  factory HeroTileTheme.fromJson(Map<String, dynamic> json) {
    final defaults = HeroTileTheme.defaults();
    return HeroTileTheme(
      title: _parseNullableString(json['title']) ?? defaults.title,
      gradient: _parseGradient(_asList(json['gradient']), defaults.gradient),
      badgeText: _parseNullableString(json['badgeText']) ?? defaults.badgeText,
      badgeGradient: _parseGradient(
        _asList(json['badgeGradient']),
        defaults.badgeGradient,
      ),
      imageUrl: _parseNullableString(json['imageUrl']),
      action: MosaicTileAction.fromJson(json['action']),
    );
  }

  factory HeroTileTheme.defaults() => HeroTileTheme(
        title: 'Summer\nCool Deals',
        gradient: <Color>[const Color(0xFF3F99FE), const Color(0xFF55C5FD)],
        badgeText: 'BUY 2\nGET 1',
        badgeGradient: <Color>[
          const Color(0xFFFF4CB7),
          const Color(0xFFD91B83)
        ],
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'gradient': _gradientToHex(gradient),
        'badgeText': badgeText,
        'badgeGradient': _gradientToHex(badgeGradient),
        'imageUrl': imageUrl,
        if (action != null) 'action': action!.toJson(),
      };
}

class MiniTileTheme {
  MiniTileTheme({
    required this.title,
    required this.gradient,
    required this.imageUrl,
    this.action,
  });

  final String title;
  final List<Color> gradient;
  final String? imageUrl;
  final MosaicTileAction? action;

  factory MiniTileTheme.fromJson(
    Map<String, dynamic> json, {
    required MiniTileTheme fallback,
  }) {
    return MiniTileTheme(
      title: _parseNullableString(json['title']) ?? fallback.title,
      gradient: _parseGradient(_asList(json['gradient']), fallback.gradient),
      imageUrl: _parseNullableString(json['imageUrl']),
      action: MosaicTileAction.fromJson(json['action']),
    );
  }

  factory MiniTileTheme.defaults([int index = 0]) {
    final defaults = SeasonalMosaicTheme.defaultMiniTiles;
    final safeIndex = index >= 0 && index < defaults.length ? index : 0;
    final tile = defaults[safeIndex];
    return MiniTileTheme(
      title: tile.title,
      gradient: List<Color>.from(tile.gradient),
      imageUrl: tile.imageUrl,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'gradient': _gradientToHex(gradient),
        'imageUrl': imageUrl,
        if (action != null) 'action': action!.toJson(),
      };
}

class SeasonalMosaicTheme {
  SeasonalMosaicTheme({
    required this.containerColor,
    required this.heroTile,
    required this.miniTiles,
  });

  final Color containerColor;
  final HeroTileTheme heroTile;
  final List<MiniTileTheme> miniTiles;

  static final List<MiniTileTheme> _defaultMiniTiles = <MiniTileTheme>[
    MiniTileTheme(
      title: 'Frozen\nFizz',
      gradient: <Color>[const Color(0xFF3F99FE), const Color(0xFF55C5FD)],
      imageUrl: null,
    ),
    MiniTileTheme(
      title: 'Scoop\nMagic',
      gradient: <Color>[const Color(0xFF4F97FF), const Color(0xFF397BF1)],
      imageUrl: null,
    ),
    MiniTileTheme(
      title: 'Crunch\nBreak',
      gradient: <Color>[const Color(0xFF43A5FF), const Color(0xFF2E83F3)],
      imageUrl: null,
    ),
    MiniTileTheme(
      title: 'Dairy\nDaily',
      gradient: <Color>[const Color(0xFF5AA8FF), const Color(0xFF4283F3)],
      imageUrl: null,
    ),
  ];

  static List<MiniTileTheme> get defaultMiniTiles => _defaultMiniTiles
      .map(
        (MiniTileTheme tile) => MiniTileTheme(
          title: tile.title,
          gradient: List<Color>.from(tile.gradient),
          imageUrl: tile.imageUrl,
        ),
      )
      .toList();

  factory SeasonalMosaicTheme.fromJson(Map<String, dynamic> json) {
    final defaults = SeasonalMosaicTheme.defaults();
    final miniTilesValue = json['miniTiles'];

    final parsedMiniTiles = miniTilesValue is List
        ? List<MiniTileTheme>.generate(defaults.miniTiles.length, (int index) {
            final item = index < miniTilesValue.length
                ? _asMap(miniTilesValue[index])
                : <String, dynamic>{};
            return MiniTileTheme.fromJson(
              item,
              fallback: defaults.miniTiles[index],
            );
          })
        : defaults.miniTiles;

    return SeasonalMosaicTheme(
      containerColor: _parseColor(
        _parseNullableString(json['containerColor']),
        defaults.containerColor,
      ),
      heroTile: HeroTileTheme.fromJson(_asMap(json['heroTile'])),
      miniTiles: parsedMiniTiles,
    );
  }

  factory SeasonalMosaicTheme.defaults() => SeasonalMosaicTheme(
        containerColor: const Color(0xFFD8F4FF),
        heroTile: HeroTileTheme.defaults(),
        miniTiles: defaultMiniTiles,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'containerColor': _colorToHex(containerColor),
        'heroTile': heroTile.toJson(),
        'miniTiles':
            miniTiles.map((MiniTileTheme tile) => tile.toJson()).toList(),
      };
}

class BankOffersTheme {
  BankOffersTheme({required this.visible, required this.bannerImageUrls});

  final bool visible;
  final List<String> bannerImageUrls;

  factory BankOffersTheme.fromJson(Map<String, dynamic> json) {
    final defaults = BankOffersTheme.defaults();
    return BankOffersTheme(
      visible: _parseBool(json['visible'], defaults.visible),
      bannerImageUrls: _parseStringList(
        json['bannerImageUrls'],
        defaults.bannerImageUrls,
      ),
    );
  }

  factory BankOffersTheme.defaults() =>
      BankOffersTheme(visible: true, bannerImageUrls: const <String>[]);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'visible': visible,
        'bannerImageUrls': List<String>.from(bannerImageUrls),
      };
}

class ThemeMeta {
  const ThemeMeta({
    required this.seasonLabel,
    required this.statusBarBrightness,
  });

  final String seasonLabel;
  final String statusBarBrightness;

  factory ThemeMeta.fromJson(Map<String, dynamic> json) {
    final defaults = ThemeMeta.defaults();
    final brightness = _parseNullableString(json['statusBarBrightness']);
    return ThemeMeta(
      seasonLabel:
          _parseNullableString(json['seasonLabel']) ?? defaults.seasonLabel,
      statusBarBrightness:
          brightness == 'dark' ? 'dark' : defaults.statusBarBrightness,
    );
  }

  factory ThemeMeta.defaults() => const ThemeMeta(
        seasonLabel: 'Summer Sip & Scoop',
        statusBarBrightness: 'light',
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'seasonLabel': seasonLabel,
        'statusBarBrightness': statusBarBrightness,
      };
}

/// Colours for the Dealkr home look (store tiles, search row, hero frame,
/// fee card, profile button, page canvas). Every field is optional in the
/// stored JSON and falls back to the design's colours, so the dashboard theme
/// builder can restyle each element after release (`theme_data.sections.homeLook`).
class HomeLookTheme {
  const HomeLookTheme({
    this.canvasColor,
    this.avatarColor = const Color(0xFF111111),
    this.storeTileColor = const Color(0xFFFFFFFF),
    this.storeTileActiveColor = const Color(0xFFFCE8B0),
    this.storeTileLabelColor = const Color(0xFF111111),
    this.searchPillColor = const Color(0xFFFFFFFF),
    this.searchPillTextColor = const Color(0xFF111111),
    this.searchPillBorderColor = const Color(0xFF222222),
    this.sellChipStartColor = const Color(0xFFFBE36B),
    this.sellChipEndColor = const Color(0xFFF6D23A),
    this.sellChipTextColor = const Color(0xFF111111),
    this.heroFrameColor = const Color(0xFF000000),
    this.heroDotColor = const Color(0xFFFFFFFF),
    this.feeCardColor = const Color(0xFFFFFFFF),
    this.feeCardTextColor = const Color(0xFF111111),
    this.feeCardCheckColor = const Color(0xFF111111),
    this.navBackgroundColor = const Color(0xFFFFFFFF),
    this.navActiveColor = const Color(0xFFF0245F),
    this.navLabelColor = const Color(0xFF1A1A1A),
    this.repairPillColor = const Color(0xFFFBE36B),
    this.repairPillTextColor = const Color(0xFF111111),
    this.repairLabel = 'Repair\nMobile etc.',
    this.repairBannerUrl = '',
    this.productBoxColor = const Color(0xFFFFFFFF),
    this.productBoxBorderColor = const Color(0xFFEFE3B5),
    this.productTextColor = const Color(0xFF111111),
    this.productBadgeColor = const Color(0xFF1FB454),
    this.productStockColor = const Color(0xFF1FB454),
    this.storePalette1Background = const Color(0xFF0A0115),
    this.storePalette1TabFill = const Color(0xFF1C0442),
    this.storePalette1TabEdge = const Color(0xFFF2E8FF),
    this.storePalette1Text = const Color(0xFFFFFFFF),
    this.storePalette2Background = const Color(0xFFDFE8FE),
    this.storePalette2TabFill = const Color(0xFFE8F0FE),
    this.storePalette2TabEdge = const Color(0xFF505A7A),
    this.storePalette2Text = const Color(0xFF1B1E2B),
    this.storePalette3Background = const Color(0xFFFEFCF8),
    this.storePalette3TabFill = const Color(0xFFFCF6EC),
    this.storePalette3TabEdge = const Color(0xFF5A5552),
    this.storePalette3Text = const Color(0xFF2B2622),
    this.storePalette4Background = const Color(0xFF000000),
    this.storePalette4TabFill = const Color(0xFF02060C),
    this.storePalette4TabEdge = const Color(0xFFFFFFFF),
    this.storePalette4Text = const Color(0xFFFFFFFF),
  });

  /// Page background below the top chrome; null = use the top bar colour.
  final Color? canvasColor;
  final Color avatarColor;
  final Color storeTileColor;
  final Color storeTileActiveColor;
  final Color storeTileLabelColor;
  final Color searchPillColor;
  final Color searchPillTextColor;
  final Color searchPillBorderColor;
  final Color sellChipStartColor;
  final Color sellChipEndColor;
  final Color sellChipTextColor;
  final Color heroFrameColor;
  final Color heroDotColor;
  final Color feeCardColor;
  final Color feeCardTextColor;
  final Color feeCardCheckColor;
  final Color navBackgroundColor;
  final Color navActiveColor;
  final Color navLabelColor;
  final Color repairPillColor;
  final Color repairPillTextColor;

  /// Text of the footer's repair pill; empty hides the pill.
  final String repairLabel;

  /// Picture shown as the footer's repair button (empty = the bundled banner).
  final String repairBannerUrl;
  final Color productBoxColor;
  final Color productBoxBorderColor;
  final Color productTextColor;
  final Color productBadgeColor;
  final Color productStockColor;

  /// Store tab palettes 1-4 (by tab position): header band, raised tab, tab
  /// outline, header text.
  final Color storePalette1Background;
  final Color storePalette1TabFill;
  final Color storePalette1TabEdge;
  final Color storePalette1Text;
  final Color storePalette2Background;
  final Color storePalette2TabFill;
  final Color storePalette2TabEdge;
  final Color storePalette2Text;
  final Color storePalette3Background;
  final Color storePalette3TabFill;
  final Color storePalette3TabEdge;
  final Color storePalette3Text;
  final Color storePalette4Background;
  final Color storePalette4TabFill;
  final Color storePalette4TabEdge;
  final Color storePalette4Text;

  factory HomeLookTheme.fromJson(Map<String, dynamic> json) {
    const HomeLookTheme d = HomeLookTheme();
    Color c(String key, Color fallback) =>
        _parseColor(_parseNullableString(json[key]), fallback);
    final String? canvas = _parseNullableString(json['canvasColor']);
    return HomeLookTheme(
      canvasColor:
          canvas == null ? null : _parseColor(canvas, const Color(0xFFFFFFFF)),
      avatarColor: c('avatarColor', d.avatarColor),
      storeTileColor: c('storeTileColor', d.storeTileColor),
      storeTileActiveColor: c('storeTileActiveColor', d.storeTileActiveColor),
      storeTileLabelColor: c('storeTileLabelColor', d.storeTileLabelColor),
      searchPillColor: c('searchPillColor', d.searchPillColor),
      searchPillTextColor: c('searchPillTextColor', d.searchPillTextColor),
      searchPillBorderColor: c(
        'searchPillBorderColor',
        d.searchPillBorderColor,
      ),
      sellChipStartColor: c('sellChipStartColor', d.sellChipStartColor),
      sellChipEndColor: c('sellChipEndColor', d.sellChipEndColor),
      sellChipTextColor: c('sellChipTextColor', d.sellChipTextColor),
      heroFrameColor: c('heroFrameColor', d.heroFrameColor),
      heroDotColor: c('heroDotColor', d.heroDotColor),
      feeCardColor: c('feeCardColor', d.feeCardColor),
      feeCardTextColor: c('feeCardTextColor', d.feeCardTextColor),
      feeCardCheckColor: c('feeCardCheckColor', d.feeCardCheckColor),
      navBackgroundColor: c('navBackgroundColor', d.navBackgroundColor),
      navActiveColor: c('navActiveColor', d.navActiveColor),
      navLabelColor: c('navLabelColor', d.navLabelColor),
      repairPillColor: c('repairPillColor', d.repairPillColor),
      repairPillTextColor: c('repairPillTextColor', d.repairPillTextColor),
      repairLabel: json['repairLabel'] is String
          ? (json['repairLabel'] as String)
          : d.repairLabel,
      repairBannerUrl: json['repairBannerUrl'] is String
          ? (json['repairBannerUrl'] as String).trim()
          : d.repairBannerUrl,
      productBoxColor: c('productBoxColor', d.productBoxColor),
      productBoxBorderColor: c(
        'productBoxBorderColor',
        d.productBoxBorderColor,
      ),
      productTextColor: c('productTextColor', d.productTextColor),
      productBadgeColor: c('productBadgeColor', d.productBadgeColor),
      productStockColor: c('productStockColor', d.productStockColor),
      storePalette1Background: c(
        'storePalette1Background',
        d.storePalette1Background,
      ),
      storePalette1TabFill: c('storePalette1TabFill', d.storePalette1TabFill),
      storePalette1TabEdge: c('storePalette1TabEdge', d.storePalette1TabEdge),
      storePalette1Text: c('storePalette1Text', d.storePalette1Text),
      storePalette2Background: c(
        'storePalette2Background',
        d.storePalette2Background,
      ),
      storePalette2TabFill: c('storePalette2TabFill', d.storePalette2TabFill),
      storePalette2TabEdge: c('storePalette2TabEdge', d.storePalette2TabEdge),
      storePalette2Text: c('storePalette2Text', d.storePalette2Text),
      storePalette3Background: c(
        'storePalette3Background',
        d.storePalette3Background,
      ),
      storePalette3TabFill: c('storePalette3TabFill', d.storePalette3TabFill),
      storePalette3TabEdge: c('storePalette3TabEdge', d.storePalette3TabEdge),
      storePalette3Text: c('storePalette3Text', d.storePalette3Text),
      storePalette4Background: c(
        'storePalette4Background',
        d.storePalette4Background,
      ),
      storePalette4TabFill: c('storePalette4TabFill', d.storePalette4TabFill),
      storePalette4TabEdge: c('storePalette4TabEdge', d.storePalette4TabEdge),
      storePalette4Text: c('storePalette4Text', d.storePalette4Text),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (canvasColor != null) 'canvasColor': _colorToHex(canvasColor!),
        'avatarColor': _colorToHex(avatarColor),
        'storeTileColor': _colorToHex(storeTileColor),
        'storeTileActiveColor': _colorToHex(storeTileActiveColor),
        'storeTileLabelColor': _colorToHex(storeTileLabelColor),
        'searchPillColor': _colorToHex(searchPillColor),
        'searchPillTextColor': _colorToHex(searchPillTextColor),
        'searchPillBorderColor': _colorToHex(searchPillBorderColor),
        'sellChipStartColor': _colorToHex(sellChipStartColor),
        'sellChipEndColor': _colorToHex(sellChipEndColor),
        'sellChipTextColor': _colorToHex(sellChipTextColor),
        'heroFrameColor': _colorToHex(heroFrameColor),
        'heroDotColor': _colorToHex(heroDotColor),
        'feeCardColor': _colorToHex(feeCardColor),
        'feeCardTextColor': _colorToHex(feeCardTextColor),
        'feeCardCheckColor': _colorToHex(feeCardCheckColor),
        'navBackgroundColor': _colorToHex(navBackgroundColor),
        'navActiveColor': _colorToHex(navActiveColor),
        'navLabelColor': _colorToHex(navLabelColor),
        'repairPillColor': _colorToHex(repairPillColor),
        'repairPillTextColor': _colorToHex(repairPillTextColor),
        'repairLabel': repairLabel,
        'repairBannerUrl': repairBannerUrl,
        'productBoxColor': _colorToHex(productBoxColor),
        'productBoxBorderColor': _colorToHex(productBoxBorderColor),
        'productTextColor': _colorToHex(productTextColor),
        'productBadgeColor': _colorToHex(productBadgeColor),
        'productStockColor': _colorToHex(productStockColor),
        'storePalette1Background': _colorToHex(storePalette1Background),
        'storePalette1TabFill': _colorToHex(storePalette1TabFill),
        'storePalette1TabEdge': _colorToHex(storePalette1TabEdge),
        'storePalette1Text': _colorToHex(storePalette1Text),
        'storePalette2Background': _colorToHex(storePalette2Background),
        'storePalette2TabFill': _colorToHex(storePalette2TabFill),
        'storePalette2TabEdge': _colorToHex(storePalette2TabEdge),
        'storePalette2Text': _colorToHex(storePalette2Text),
        'storePalette3Background': _colorToHex(storePalette3Background),
        'storePalette3TabFill': _colorToHex(storePalette3TabFill),
        'storePalette3TabEdge': _colorToHex(storePalette3TabEdge),
        'storePalette3Text': _colorToHex(storePalette3Text),
        'storePalette4Background': _colorToHex(storePalette4Background),
        'storePalette4TabFill': _colorToHex(storePalette4TabFill),
        'storePalette4TabEdge': _colorToHex(storePalette4TabEdge),
        'storePalette4Text': _colorToHex(storePalette4Text),
      };
}

class ThemeSections {
  ThemeSections({
    required this.topBar,
    required this.storeSelector,
    required this.categoryTabs,
    required this.searchZone,
    required this.bannerAnimation,
    required this.feeStrip,
    required this.seasonalMosaic,
    required this.bankOffers,
    this.homeLook = const HomeLookTheme(),
  });

  final TopBarTheme topBar;
  final StoreSelectorTheme storeSelector;
  final CategoryTabsTheme categoryTabs;
  final SearchZoneTheme searchZone;
  final BannerAnimationTheme bannerAnimation;
  final FeeStripTheme feeStrip;
  final SeasonalMosaicTheme seasonalMosaic;
  final BankOffersTheme bankOffers;
  final HomeLookTheme homeLook;

  factory ThemeSections.fromJson(Map<String, dynamic> json) => ThemeSections(
        topBar: TopBarTheme.fromJson(_asMap(json['topBar'])),
        storeSelector:
            StoreSelectorTheme.fromJson(_asMap(json['storeSelector'])),
        categoryTabs: CategoryTabsTheme.fromJson(_asMap(json['categoryTabs'])),
        searchZone: SearchZoneTheme.fromJson(_asMap(json['searchZone'])),
        bannerAnimation: BannerAnimationTheme.fromJson(
          _asMap(json['bannerAnimation']),
        ),
        feeStrip: FeeStripTheme.fromJson(_asMap(json['feeStrip'])),
        seasonalMosaic: SeasonalMosaicTheme.fromJson(
          _asMap(json['seasonalMosaic']),
        ),
        bankOffers: BankOffersTheme.fromJson(_asMap(json['bankOffers'])),
        homeLook: HomeLookTheme.fromJson(_asMap(json['homeLook'])),
      );

  factory ThemeSections.defaults() => ThemeSections(
        topBar: TopBarTheme.defaults(),
        storeSelector: StoreSelectorTheme.defaults(),
        categoryTabs: CategoryTabsTheme.defaults(),
        searchZone: SearchZoneTheme.defaults(),
        bannerAnimation: BannerAnimationTheme.defaults(),
        feeStrip: FeeStripTheme.defaults(),
        seasonalMosaic: SeasonalMosaicTheme.defaults(),
        bankOffers: BankOffersTheme.defaults(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'topBar': topBar.toJson(),
        'storeSelector': storeSelector.toJson(),
        'categoryTabs': categoryTabs.toJson(),
        'searchZone': searchZone.toJson(),
        'bannerAnimation': bannerAnimation.toJson(),
        'feeStrip': feeStrip.toJson(),
        'seasonalMosaic': seasonalMosaic.toJson(),
        'bankOffers': bankOffers.toJson(),
        'homeLook': homeLook.toJson(),
      };
}

class RemoteTheme {
  const RemoteTheme({required this.sections, required this.meta});

  final ThemeSections sections;
  final ThemeMeta meta;

  factory RemoteTheme.fromJson(Map<String, dynamic> json) => RemoteTheme(
        sections: ThemeSections.fromJson(_asMap(json['sections'])),
        meta: ThemeMeta.fromJson(_asMap(json['meta'])),
      );

  factory RemoteTheme.defaults() => RemoteTheme(
        sections: ThemeSections.defaults(),
        meta: ThemeMeta.defaults(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'sections': sections.toJson(),
        'meta': meta.toJson(),
      };
}

/// ── TAB THEME CLASSES ──────────────────────────

/// A/B test data for a tab theme
class TabABTest {
  const TabABTest({required this.variantBData, required this.splitPercent});

  final RemoteTheme variantBData;
  final int splitPercent;

  factory TabABTest.fromJson(Map<String, dynamic> json) => TabABTest(
        variantBData: RemoteTheme.fromJson(_asMap(json['variant_b_data'])),
        splitPercent: (json['split_percent'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'variant_b_data': variantBData.toJson(),
        'split_percent': splitPercent,
      };
}

/// A single tab's theme entry from the /theme/tabs API
class TabThemeEntry {
  const TabThemeEntry({
    required this.storeKey,
    required this.tabId,
    required this.themeId,
    required this.tabKey,
    required this.tabLabel,
    required this.tabIconUrl,
    required this.tabTextColor,
    required this.tabOrder,
    required this.variant,
    required this.themeData,
    this.isDefault = false,
    this.abTest,
  });

  final String storeKey;
  final String? tabId;
  final String? themeId;
  final String tabKey;
  final String tabLabel;
  final String? tabIconUrl;
  final Color tabTextColor;
  final int tabOrder;

  /// Admin-set flag (dashboard "Set as default") marking this tab as the one
  /// customers should land on when the app opens for this store.
  final bool isDefault;
  final String variant;
  final RemoteTheme themeData;
  final TabABTest? abTest;

  factory TabThemeEntry.fromJson(Map<String, dynamic> json) {
    final dynamic abTestRaw = json['ab_test'];
    return TabThemeEntry(
      storeKey: (json['store_key'] as String?) ?? 'mobile',
      tabId: _parseNullableString(json['tab_id']),
      themeId: _parseNullableString(json['theme_id']),
      tabKey: (json['tab_key'] as String?) ?? 'all',
      tabLabel: (json['tab_label'] as String?) ?? 'All',
      tabIconUrl: _parseNullableString(json['tab_icon_url']),
      tabTextColor: _parseColor(
        _parseNullableString(json['tab_text_color']),
        Colors.black,
      ),
      tabOrder: (json['tab_order'] as num?)?.toInt() ?? 0,
      isDefault: json['is_default'] == true,
      variant: (json['variant'] as String?) ?? 'A',
      themeData: RemoteTheme.fromJson(_asMap(json['theme_data'])),
      abTest: abTestRaw is Map<String, dynamic>
          ? TabABTest.fromJson(abTestRaw)
          : abTestRaw is Map
              ? TabABTest.fromJson(Map<String, dynamic>.from(abTestRaw))
              : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'store_key': storeKey,
        'tab_id': tabId,
        'theme_id': themeId,
        'tab_key': tabKey,
        'tab_label': tabLabel,
        'tab_icon_url': tabIconUrl,
        'tab_text_color': _colorToHex(tabTextColor),
        'tab_order': tabOrder,
        'is_default': isDefault,
        'variant': variant,
        'theme_data': themeData.toJson(),
        if (abTest != null) 'ab_test': abTest!.toJson(),
      };

  /// Resolve A/B variant: pick variant A or B based on userId hash
  RemoteTheme resolveForUser(String? userId) {
    if (abTest == null || userId == null) return themeData;
    final int bucket = userId.hashCode.abs() % 100;
    return bucket < abTest!.splitPercent ? abTest!.variantBData : themeData;
  }
}

/// Resolves which tab a store should land on when no explicit tab is
/// selected: the admin-flagged default tab, else the legacy 'all' tab, else
/// the first tab. [tabs] must be non-empty.
TabThemeEntry resolveDefaultTab(List<TabThemeEntry> tabs) {
  for (final TabThemeEntry tab in tabs) {
    if (tab.isDefault) return tab;
  }
  return tabs.firstWhere(
    (TabThemeEntry tab) => tab.tabKey == 'all',
    orElse: () => tabs.first,
  );
}

/// Full API response from GET /theme/tabs
class TabThemesResponse {
  const TabThemesResponse({
    required this.storeKey,
    required this.etag,
    required this.tabs,
    required this.tabMap,
    this.deliveryEtaMinutes,
  });

  final String storeKey;
  final String? etag;
  final List<TabThemeEntry> tabs;
  final Map<String, TabThemeEntry> tabMap;

  /// Admin-set delivery-time badge shown on the home screen header (e.g.
  /// "⚡ 45 mins delivery"). Plain display value, not a computed ETA.
  final int? deliveryEtaMinutes;

  /// The tab this store should land on when no tab is explicitly selected.
  TabThemeEntry? get defaultTabEntry =>
      tabs.isEmpty ? null : resolveDefaultTab(tabs);

  factory TabThemesResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> tabsRaw = json['tabs'] as List<dynamic>? ?? <dynamic>[];
    final List<TabThemeEntry> tabsList = tabsRaw
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (dynamic item) => TabThemeEntry.fromJson(
            Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
          ),
        )
        .toList()
      ..sort(
        (TabThemeEntry a, TabThemeEntry b) => a.tabOrder.compareTo(b.tabOrder),
      );

    final Map<String, TabThemeEntry> tabMap = <String, TabThemeEntry>{
      for (final TabThemeEntry tab in tabsList) tab.tabKey: tab,
    };

    return TabThemesResponse(
      storeKey: (json['store_key'] as String?) ?? 'mobile',
      etag: _parseNullableString(json['etag']),
      tabs: tabsList,
      tabMap: tabMap,
      deliveryEtaMinutes: (json['delivery_eta_minutes'] as num?)?.toInt(),
    );
  }

  factory TabThemesResponse.defaults({String storeKey = 'mobile'}) {
    final TabThemeEntry defaultEntry = TabThemeEntry(
      storeKey: storeKey,
      tabId: null,
      themeId: null,
      tabKey: 'all',
      tabLabel: 'All',
      tabIconUrl: null,
      tabTextColor: Colors.black,
      tabOrder: 0,
      variant: 'A',
      themeData: RemoteTheme.defaults(),
    );
    return TabThemesResponse(
      storeKey: storeKey,
      etag: null,
      tabs: <TabThemeEntry>[defaultEntry],
      tabMap: <String, TabThemeEntry>{'all': defaultEntry},
    );
  }

  factory TabThemesResponse.empty({String storeKey = 'mobile'}) {
    return TabThemesResponse(
      storeKey: storeKey,
      etag: null,
      tabs: const <TabThemeEntry>[],
      tabMap: const <String, TabThemeEntry>{},
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'store_key': storeKey,
        'etag': etag,
        'tabs': tabs.map((TabThemeEntry tab) => tab.toJson()).toList(),
        'delivery_eta_minutes': deliveryEtaMinutes,
      };
}
