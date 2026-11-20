class Routes {
  Routes._();

  static const splash = '/';
  static const welcome = '/welcome';
  static const login = '/login';
  static const register = '/register';
  static const otp = '/otp';
  static const home = '/home';
  static const profile = '/profile';
  static const wallet = '/wallet';
  static const businessProfile = '/business-profile';
  static const settings = '/settings';
  static const help = '/help';
  static const helpNew = '/help/new';
  static String helpChat(String id) => '/help/chat/$id';
  static const notifications = '/notifications';
  static const storeSettings = '/store-settings';
  static const subscription = '/subscription';
  static const payouts = '/payouts';

  // Customer returns on the vendor's own orders (static path before the parameterised ones)
  static const returns = '/returns';
  static String returnDetail(String id) => '/returns/view/$id';
  static String returnChat(String id) => '/returns/view/$id/chat';
  static const myOrders = '/my-orders'; // what the vendor bought / sent for repair
  static const wholesale = '/wholesale';
  static const wholesaleCart = '/wholesale/cart';
  static const wholesaleOrders = '/wholesale/orders';
  static String wholesaleView(String id) => '/wholesale/view/$id';

  // Products (static paths must be registered before the parameterised ones)
  static const products = '/products';
  static const productAdd = '/products/add';
  static const productBulk = '/products/bulk';
  static const productSubmitted = '/products/submitted';
  static String productDetail(String id) => '/products/view/$id';

  // Orders — products + auctions + repairs (static path before the parameterised ones)
  static const orders = '/orders';
  static String orderDetail(String id) => '/orders/view/$id';
  static String repairDetail(String id) => '/orders/repair/$id';

  // Repair marketplace (static paths before the parameterised ones)
  static const repairs = '/repairs';
  static const repairPrices = '/repairs/prices';
  static const repairPriceAdd = '/repairs/prices/add';
  static String repairRequest(String id) => '/repairs/request/$id';
  static String repairPrice(String id) => '/repairs/request/$id/price';
  static String repairOffer(String id) => '/repairs/request/$id/offer';
  static String repairJob(String id) => '/repairs/job/$id';
  static String repairCheck(String id) => '/repairs/job/$id/check';
  static String repairQuote(String id) => '/repairs/job/$id/quote';
  static String repairProgress(String id) => '/repairs/job/$id/progress';
  static String repairHandover(String id) => '/repairs/job/$id/handover';
  static String repairChat(String id) => '/repairs/job/$id/chat';
  static String repairReady(String id) => '/repairs/job/$id/ready';

  // Auctions (static paths must be registered before the parameterised ones)
  static const auctions = '/auctions';
  static const auctionCreate = '/auctions/create';
  static const auctionCreated = '/auctions/created';
  static String auctionDetail(String id) => '/auctions/view/$id';
  static String auctionChat(String id) => '/auctions/view/$id/chat';
  static String lotDetail(String id) => '/auctions/lot/$id';

  // Campaigns (sponsored ads) — static paths before the parameterised one
  static const campaigns = '/campaigns';
  static const campaignCreate = '/campaigns/create';
  static const campaignCreated = '/campaigns/created';
  static const adWallet = '/campaigns/wallet';
  static String campaignDetail(String id) => '/campaigns/view/$id';

  // Deals opened to vendors (static path before the parameterised one)
  static const deals = '/deals';
  static String dealView(String id) => '/deals/view/$id';

  // Abandoned carts (static path before the parameterised ones)
  static const abandonedCarts = '/abandoned-carts';
  static String abandonedCartDetail(String id) => '/abandoned-carts/view/$id';
  static String abandonedCartRemind(String id) =>
      '/abandoned-carts/view/$id/remind';

  // Sell-phone requests from customers (static path before the parameterised ones)
  static const sellLeads = '/sell-leads';
  static String sellLeadView(String id) => '/sell-leads/view/$id';
  static String sellLeadChat(String id) => '/sell-leads/view/$id/chat';

  // Demand (buyers' requirements → offers → orders). Static paths before the parameterised ones.
  static const demand = '/demand';
  static String demandTab(String tab) => '/demand?tab=$tab';
  static const demandPost = '/demand/post';
  static String demandView(String id) => '/demand/view/$id';
  static String demandOffer(String id) => '/demand/view/$id/offer';
  static String demandPay(String id) => '/demand/view/$id/pay';
  static String demandOrder(String id) => '/demand/orders/$id';
}
