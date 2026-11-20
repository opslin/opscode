# Customer home section recipes

Use the runtime source in `assets/source/customer/lib/features/home/presentation/`. Read `widgets/section_registry.dart` for the dispatch, default keys, dependencies and routing. Use `core/theme/section_manifest_model.dart` for config names and `widgets/dynamic_home_sections.dart` for placement and visibility. Run `ui_kit.py sections` for the precise registry entries. The shipped source is the reference when an earlier mockup differs.

## Header and store selection

The top row gives the shopper delivery context first, then address and profile. `shared/widgets/home_header.dart` scales its geometry from the 914 px reference. `store_tiles_row.dart` paints a 77 logical px row with 8 px side margins. The resting folders overlap. The raised folder is drawn last, with curved shoulders, a tapered outline and a small foot that joins the panel below. Interpolate from the current animation position when the shopper taps again during a transition. The 460 ms position transition, 420 ms palette tween, icon lift and bold label keep selection legible. Change the store and clear the old category together. Drive the address, bar and search panel from the same `StoreTabPalette`. Check text contrast on all four original palettes.

The search row in `shared/widgets/home_search_bar.dart` carries a search target, Sell action and optional promo image. Keep the hit areas separate, preserve one-line search hints, and disable hint rotation when the user prefers reduced motion. Retain the distinct controls when using the sticky search overlay in `home_screen.dart`.

## Manifest sections

| Section | Choose it for | Preserve in the implementation |
|---|---|---|
| Animated banner | A campaign hero with an approved image or animation | Use the configured height and gradient. Keep the still image and fallback visible while motion loads. |
| Fee strip | Current delivery or fee policy | Keep the promise readable in a shallow strip. Show only current conditions and preserve visibility. |
| Seasonal mosaic | One campaign hero supported by small deal tiles | Keep the chosen layout variant, tile-level art, and tile destinations. Handle an incomplete product set. |
| Round category icons | A compact jump bar to several categories | Preserve icon sizing, scroll rhythm, label toggle and real category context. |
| Category product grid | Comparing several products in a single category | Derive column width from available space. Share card slots across the row to prevent unequal baselines. |
| Product carousel | A small group of products that can be browsed horizontally | Show the next card’s edge. Keep product selection, Add and see-all distinct. |
| Trending products | Ranked products with a reliable trending signal | Preserve ranking order and hide the section when its eligible feed is empty. |
| Promo carousel | Several editorial messages of equal importance | Keep image ratios, page indicator and per-banner routing. Stop autoplay when only one item remains or motion is reduced. |
| Bank offers | A brief strip of applicable offers | Use compact artwork and the real offer conditions. Suppress expired or missing offers. |
| Custom banner | One controlled visual and one destination | Respect image aspect ratio and radius. Keep the destination an explicit action. |
| Text header | Give the next content group a clear name | Preserve alignment, hierarchy and spacing. Avoid a repeated title if the next component already names itself. |
| Arched product showcase | A collection that needs a recognizable silhouette | Reuse the layout variants and shaping from the source. Keep tap targets and product metadata independent of the decorative arch. |
| Spacer | Controlled separation between adjacent sections | Use the configured height. Avoid stacking it with redundant section margins. |
| Live auction | Active lots with deadlines and auction routes | Present the true auction state and countdown. Handle ended or bid-ineligible lots explicitly. |
| Deal of day | One focused product or featured deal | Preserve themed product slots, real price comparisons and the CTA’s destination. |
| Recent recommended | Continue browsing based on actual activity | Preserve ordering and eligibility. Provide the configured fallback for a new shopper. |
| Steal deals | Deal groups with chip filters | Keep the primary tab and its child filter state separate. Re-select or clear the child when a group changes. |
| Collection showcase | Several curated product sets | Keep collection-specific label, cards, imagery and see-all route in the same selected state. |
| Brand spotlight | A visual introduction to a featured brand | Pair brand image and brand-specific product feed. Keep its featured card distinct from the surrounding rail. |
| Price shop | Browse by price band | Use the true selected band, label, feed and route together. Reserve the selected indicator space. |
| Category hub | Browse nested categories visually | Preserve the top tab, tile grid, optional image and category destination. Account for missing artwork. |
| Banner rail | One campaign image leading into shoppable cards | Fade the art into the panel using the same color. Keep headline, product boxes and see-all within one visual group. |
| Top brands | A horizontally browsable set of named brands | Use the original custom-painted arch, themed plate and optional logo. Keep the brand destination with its card. |
| Price sale | A product shelf that changes with a selected price box | Switch hero labels, left and right artwork, indicator and product pool together. Preserve the 380 ms artwork fade and the empty state for missing products. |
| Oval spotlight | Large visual cards for a few standout products | Keep oval silhouette, price and device image inside each card’s constraints. Test small cards and long names. |
| Category deals | Compare deals grouped by category | Keep each tab’s products and see-all category paired. Handle a missing or empty payload. |
| Shops nearby | Seller discovery scoped to the shopper’s location | Render real seller, distance and availability data. Keep location-denied, empty, loading and retry states distinct. |

The original product box uses `DealkerProductCard`, `ProductCardTokens` and `DealkerCardSlots.forProducts`. It sizes the image, floating add control, name, seller, price, ratings and trust row together. Keep a shared measured height for peers. Keep the card tap, wishlist tap and add or stepper taps independent. Use listing identity for cart actions, family identity for option routing, and valid stock for availability. Display original crossed-out price and discount only when the effective price is lower.

The standalone preview exercises the folder bar, search, banner rail, price sale, oval showcase and product cards with local listings. The other registry entries are available as original source with their host dependencies in the catalog.
