# Bundled Bakaloo Flutter homepage

The homepage is an assemble-ready Flutter app. The skill carries the Dart source, pubspec and lockfile, Flutter web host, fonts, artwork, demo data, and smoke tests. Python 3 copies it to a new directory and sets the display brand. Flutter resolves dependencies through Pub or a populated offline cache.

Run from the skill folder:

```bash
python3 scripts/assemble.py /path/to/new/freshbasket-home --brand FreshBasket
cd /path/to/new/freshbasket-home
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
flutter run -d chrome --no-pub --no-web-resources-cdn
```

With dependencies in the local Pub cache, use `flutter pub get --offline`. To make a locally hosted release preview, use `flutter build web --no-pub --no-web-resources-cdn` and serve `build/web` over HTTP. The web host ships with the bundle. To run on Android or iOS, generate the runner directories in the assembled app using your Flutter SDK and select a device. The bundle was verified using Flutter 3.47.5.

## Source and adaptation

All app code and assets used by the assembler live in [the bundled source](../modules/mobile-home/source/).

| Bundle file | Origin or adaptation |
|---|---|
| `lib/features/home/presentation/screens/home_sections.dart` | Bakaloo `home_screen.dart` carousel, heading and three-column product grid, adapted for local product and media fixtures |
| `lib/shared/widgets/home_header.dart` and `home_search_bar.dart` | Bakaloo header and animated search bar with injected brand, address and actions |
| `lib/shared/widgets/product_card.dart` | Bakaloo product card layouts, sale, unit, stock, rating and add/quantity controls, with a local Riverpod cart and wishlist |
| `lib/shared/widgets/app_image.dart` | Bakaloo scroll-aware image component adapted to load bundled assets |
| `lib/core/theme/` | Bakaloo Flutter design tokens and theme |
| `assets/icon/`, `assets/fonts/` | Bakaloo Flutter icons and fonts. Font licenses ship under `licenses/` |
| `assets/images/` | Bakaloo dashboard preview artwork used as banners and sample product imagery |
| `assets/demo/storefront.json` | Synthetic categories, address, offers and retail products with prices, stock and images |
| `lib/demo/storefront.dart` | Reads the demo JSON and provides local cart quantities and wishlist state |
| `lib/features/home/presentation/screens/home_screen.dart` | Standalone composition for the bundled widgets, category filter, search, product preview and cart |

The upstream code and artwork are recorded by commit in [sources.json](sources.json). The original home screen relies on sockets, location, authentication, active store and remote theme services. The standalone app uses demo state and bundled media for its home flow. Default Bakaloo uses the bundled logo, and a custom brand uses a text wordmark. Category icons use bundled Material glyphs. The upstream 3D assets directory contains a placeholder.

## Verification

The smoke tests exercise actual homepage widgets and image assets at phone widths, category filtering, demo search and empty state, add-to-cart, total and removal. Use the live theme-builder and commerce recipes when the brief additionally calls for a backend, admin editor, or order placement.
