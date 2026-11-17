// Name handling: splitting identifiers into words, a small singular form, and the
// synonym groups used for SEARCH ONLY (never for deciding that two things are the
// same feature: a wrong merge is worse than a missed one).

export const words = (s: string): string[] => s.replace(/([a-z0-9])([A-Z])/g, "$1 $2").replace(/([A-Z]+)([A-Z][a-z])/g, "$1 $2").toLowerCase().split(/[^a-z0-9]+/).filter(Boolean);

export function singular(w: string): string {
  if (w.length <= 3) return w;
  if (w.endsWith("ies")) return `${w.slice(0, -3)}y`;
  if (w.endsWith("sses")) return w.slice(0, -2);
  if (/(xes|zes|ches|shes)$/.test(w)) return w.slice(0, -2);
  if (w.endsWith("ss") || w.endsWith("us") || w.endsWith("is") || w.endsWith("ics")) return w;
  return w.endsWith("s") ? w.slice(0, -1) : w;
}

/** loyaltyPoints, loyalty_points, Loyalty-Point and loyalty_points all become "loyalty_point". */
export const normalize = (name: string): string => words(name).map(singular).join("_");

/** Words of a text, singular, for the search index. */
export const tokens = (text: string): string[] => words(text).map(singular).filter((t) => t.length > 1);

const GROUPS: string[][] = [
  ["cart", "basket", "bag", "trolley"],
  ["order", "purchase", "checkout"],
  ["vendor", "seller", "merchant", "supplier", "store", "shop"],
  ["loyalty", "point", "reward", "coin", "cashback"],
  ["auction", "bid", "bidding", "bidder"],
  ["payment", "pay", "wallet", "transaction", "billing", "invoice"],
  ["delivery", "shipping", "shipment", "dispatch", "courier", "rider", "driver"],
  ["product", "item", "catalog", "catalogue", "sku", "inventory", "stock"],
  ["user", "customer", "account", "profile", "member"],
  ["auth", "login", "signin", "signup", "register", "otp", "password", "session"],
  ["notification", "push", "alert", "fcm", "sms", "message"],
  ["coupon", "voucher", "promo", "promotion", "discount", "offer"],
  ["address", "location", "map", "geo"],
  ["review", "rating", "feedback"],
  ["subscription", "plan", "membership"],
  ["laundry", "wash", "clean", "garment"],
  ["booking", "appointment", "slot", "schedule"],
  ["admin", "dashboard", "backoffice", "console"],
  ["report", "analytics", "stat", "metric"],
  ["refund", "return", "cancellation"],
];
const synMap = new Map<string, Set<string>>();
for (const g of GROUPS) { const n = g.map(singular); for (const a of n) synMap.set(a, new Set([...(synMap.get(a) ?? []), ...n.filter((b) => b !== a)])); }
export const synonymsOf = (token: string): string[] => [...(synMap.get(token) ?? [])];
