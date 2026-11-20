/// Basic questions every vendor runs into, grouped by topic. Answers describe how the app works today.
class FaqItem {
  const FaqItem(this.q, this.a);
  final String q;
  final String a;
}

class FaqTopic {
  const FaqTopic(this.title, this.asset, this.items);
  final String title;
  final String asset;
  final List<FaqItem> items;
}

const faqTopics = <FaqTopic>[
  FaqTopic('Orders & shipping', 'assets/icons/orders.png', [
    FaqItem('How do I pack and ship an order?',
        'Open the order and tap Accept. Upload your invoice, tap Mark as packed, then Ship it: pick the courier and paste the tracking token. The buyer sees the tracking live.'),
    FaqItem('Why can’t I mark an order as packed?',
        'Every order needs your own invoice before it is packed. Tap Mark as packed and upload a clear photo of the invoice when asked. The same applies to B2B orders.'),
    FaqItem('The buyer has not paid. Can I ship?',
        'No. Ship only after the payment shows as Paid (or the order is Cash on delivery). For B2B orders the buyer’s money is held safely until delivery.'),
    FaqItem('How do I cancel an order?',
        'Open the order and choose Cancel before it ships, with a reason. A paid order is refunded to the buyer automatically.'),
  ]),
  FaqTopic('Payments & wallet', 'assets/icons/wallet.png', [
    FaqItem('How do I add money to my wallet?',
        'Open Wallet and tap the + button. Pay with UPI, card or netbanking. The money is added instantly, up to the wallet limit set by Dealkr.'),
    FaqItem('What is “Move earnings to wallet”?',
        'Your sales earnings can be moved into your wallet to pay auction fees, wholesale orders and bids without paying again.'),
    FaqItem('Money was deducted but the payment failed',
        'Do not pay again. Start a chat with support and share the payment ID or screenshot. Failed payments are normally refunded to your account in 5–7 working days.'),
  ]),
  FaqTopic('Payouts & earnings', 'assets/icons/payouts.png', [
    FaqItem('When do I get paid for an order?',
        'After delivery is confirmed, the order amount minus Dealkr’s commission is added to your earnings. Open Payouts to see every settlement.'),
    FaqItem('Where can I see my commission?',
        'Each order shows what you receive after commission. Your commission rate depends on your category and plan.'),
  ]),
  FaqTopic('Auctions', 'assets/icons/auction.png', [
    FaqItem('I won an auction. How do I pay?',
        'The won lot appears in your Cart. Pay with Razorpay (UPI, card, netbanking) or your wallet before the payment deadline. Your registration fee is already deducted.'),
    FaqItem('What happens if I miss the payment deadline?',
        'The auction can be cancelled and the lot offered again. Pay on time to keep your win.'),
    FaqItem('How do I create an auction?',
        'Open Auction, tap New Auction, choose B2B (verified vendors) or B2C (customers), add the product, price and schedule, then publish.'),
  ]),
  FaqTopic('Repairs', 'assets/icons/repairs.png', [
    FaqItem('How do repair requests work?',
        'Send a request with the phone, the problem and your location. Nearby shops send their price, you pick one, pay, and follow the repair step by step.'),
    FaqItem('Can I send many phones at once?',
        'Yes. Choose the quantity on the phone step to send a bulk lot. It is billed to your business with a GST invoice.'),
    FaqItem('How do I set my own repair prices?',
        'If you are a repair partner, open Repair → My repair prices, set the price for each part and brand, and switch on the repairs you offer.'),
  ]),
  FaqTopic('Listings & QC', 'assets/icons/add_product.png', [
    FaqItem('Why is my listing still pending?',
        'Every listing is checked by Dealkr QC. It needs at least 3 clear photos, a valid IMEI for phones, and an honest condition note for used items.'),
    FaqItem('I reached my listing limit',
        'Your plan sets how many listings you can have. Open Settings → Subscription to move to a bigger plan.'),
  ]),
  FaqTopic('Account & KYC', 'assets/3d/profile/fingerprint.png', [
    FaqItem('What does the green tick mean?',
        'It means your business is verified (KYC approved). It is not part of a paid plan.'),
    FaqItem('How do I update my business address?',
        'Open Profile → Business profile and edit the address. It is used for deliveries and bulk repair billing.'),
    FaqItem('How do I change my shop photo?',
        'On Profile, tap the small camera on your picture, or open Settings → Shop photo.'),
  ]),
  FaqTopic('Subscription', 'assets/3d/profile/crown.png', [
    FaqItem('How do I upgrade my plan?',
        'Open Settings → Subscription, choose a plan and pay with Razorpay. It switches on right away.'),
    FaqItem('How does monthly renewal work?',
        'A plan lasts 30 days. Pay again from Subscription before it ends and the new month is added on top of your remaining days.'),
  ]),
];

/// Topics a vendor can pick when starting a chat → server category.
class ChatTopic {
  const ChatTopic(this.label, this.category, this.asset);
  final String label;
  final String category;
  final String asset;
}

const chatTopics = <ChatTopic>[
  ChatTopic('Orders', 'ORDER', 'assets/icons/orders.png'),
  ChatTopic('Payments', 'PAYMENT', 'assets/icons/wallet.png'),
  ChatTopic('Delivery', 'DELIVERY', 'assets/icons/wholesale.png'),
  ChatTopic('Listings', 'PRODUCT', 'assets/icons/add_product.png'),
  ChatTopic('Account', 'ACCOUNT', 'assets/3d/profile/fingerprint.png'),
  ChatTopic('Something else', 'SELLER', 'assets/3d/help/faq.png'),
];
