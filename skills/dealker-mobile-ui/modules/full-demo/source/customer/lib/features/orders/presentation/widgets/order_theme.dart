/// Orders screens share the brand palette + fonts defined with the cart
/// (`AU`, `jakarta`, `dm`) and every other helper from the auction widgets.
export 'package:dealker_app/features/auctions/presentation/widgets/auction_ui.dart'
    hide AU, jakarta, dm;
export 'package:dealker_app/features/cart/presentation/widgets/cart_ui.dart'
    show AU, jakarta, dm, CartArt, CartArtImage;
