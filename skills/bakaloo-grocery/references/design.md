# Grocery storefront design

Start from the pinned Flutter theme and selected home sections. Default to the source layout where the user asks for Bakaloo parity, and use their approved brand and artwork for a new brand. Compare against captured source screenshots when exact visual parity is requested.

| Scope | Reference paths |
|---|---|
| Theme tokens | Flutter `lib/core/theme/app_colors.dart`, `app_dimensions.dart`, `app_text_styles.dart`, `app_shadows.dart` and `app_theme.dart` |
| Storefront composition | Flutter `lib/features/home/presentation/screens/home_screen.dart` and `lib/features/home/presentation/widgets/` |
| Cards and media | Flutter `lib/shared/widgets/product_card.dart` and `app_image.dart` |
| Dashboard design and phone preview | Dashboard `src/components/ui/`, `src/components/builder/MobilePreviewFrame.tsx` and `src/components/builder/previews/` |
| Asset registration | Flutter `pubspec.yaml` and `assets/`, dashboard `public/preview-assets/` |

## Design and asset decisions

- Build one brand token map for color roles, headings, body text, price typography, shapes, spacing and shadows. The source declares DM Sans and Plus Jakarta Sans among its fonts. Check font and image reuse rights, including for any trial fonts, before bundling them in the finished app.
- Preserve the role of primary shopping actions, readable product size, unit and price, availability, cart quantity and location. Retain app-safe area behavior, accessible labels, focus order, usable tap targets and legibility with larger text.
- For a standalone home port, back the selected sections with fixtures for store, category, price, stock and media. Factor the source's provider dependencies behind a destination adapter when connecting it to real catalog or theme endpoints.
- Store the asset inventory with an asset key, source and ownership, editable master if available, export path, dimensions, intended surface and fallback. The pinned Flutter `assets/3d_icons/` contains only `.gitkeep`. Use the user's approved icon files, or create a cohesive new set to match the approved art direction.
- For new 3D category icons, use the same camera angle, scale, lighting and material family across categories. Use still exports with transparent backgrounds and enough padding to avoid clipping. Size exports for their actual placement, and use accessible text labels. Preview in a grid at real phone size before approving the full set. Reserve separate templates for banners and motion assets as their aspect ratios and performance constraints differ.

Check a real small and large phone, accessibility text scaling, long product names, unavailable items, missing images and absent or malformed remote sections. When improving the reference, record the user-facing change and compare both versions with the same content.
