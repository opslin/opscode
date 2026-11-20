// Tool fingerprints: which shop, ordering, booking, payment or analytics tools a site shows. Each hit keeps the
// exact markup string that proved it, so the observation's quote can be checked against the stored markup document.
// Detection only; the absence of a tool is never reported as a fact (a site can use one we do not know).

export type TechCategory = "platform" | "ordering" | "booking" | "payments" | "analytics" | "marketing" | "chat" | "hosting";
export interface TechHit { tech: string; category: TechCategory; evidence: string }

const RULES: { tech: string; category: TechCategory; re: RegExp }[] = [
  { tech: "Shopify", category: "platform", re: /cdn\.shopify\.com|myshopify\.com|shopify-buy/i },
  { tech: "WooCommerce", category: "platform", re: /woocommerce|wc-ajax/i },
  { tech: "WordPress", category: "platform", re: /wp-content|wp-includes|generator: wordpress/i },
  { tech: "Wix", category: "platform", re: /static\.parastorage\.com|wixstatic\.com|generator: wix/i },
  { tech: "Squarespace", category: "platform", re: /static1\.squarespace\.com|squarespace-cdn|generator: squarespace/i },
  { tech: "Webflow", category: "platform", re: /assets\.website-files\.com|webflow\.com|generator: webflow/i },
  { tech: "GoDaddy site builder", category: "platform", re: /img1\.wsimg\.com|godaddy/i },
  { tech: "BigCommerce", category: "platform", re: /bigcommerce\.com/i },
  { tech: "Toast", category: "ordering", re: /toasttab\.com/i },
  { tech: "ChowNow", category: "ordering", re: /chownow\.com/i },
  { tech: "Square Online", category: "ordering", re: /squareup\.com|square\.site/i },
  { tech: "Olo", category: "ordering", re: /olo\.com|ordering\.olo/i },
  { tech: "DoorDash", category: "ordering", re: /doordash\.com/i },
  { tech: "UberEats", category: "ordering", re: /ubereats\.com/i },
  { tech: "SkipTheDishes", category: "ordering", re: /skipthedishes\.com/i },
  { tech: "OpenTable", category: "booking", re: /opentable\.(com|ca)/i },
  { tech: "Resy", category: "booking", re: /resy\.com/i },
  { tech: "Calendly", category: "booking", re: /calendly\.com/i },
  { tech: "Mindbody", category: "booking", re: /mindbodyonline\.com|mindbody\.io/i },
  { tech: "Acuity", category: "booking", re: /acuityscheduling\.com/i },
  { tech: "Stripe", category: "payments", re: /js\.stripe\.com|stripe\.com\/v3/i },
  { tech: "PayPal", category: "payments", re: /paypal\.com\/sdk|paypalobjects\.com/i },
  { tech: "Razorpay", category: "payments", re: /checkout\.razorpay\.com/i },
  { tech: "Google Analytics", category: "analytics", re: /googletagmanager\.com|google-analytics\.com/i },
  { tech: "Meta Pixel", category: "analytics", re: /connect\.facebook\.net|facebook\.com\/tr/i },
  { tech: "Hotjar", category: "analytics", re: /static\.hotjar\.com/i },
  { tech: "Mailchimp", category: "marketing", re: /mailchimp\.com|chimpstatic\.com/i },
  { tech: "Klaviyo", category: "marketing", re: /klaviyo\.com/i },
  { tech: "HubSpot", category: "marketing", re: /hs-scripts\.com|hubspot\.com|hsforms/i },
  { tech: "Intercom", category: "chat", re: /intercomcdn\.com|widget\.intercom\.io/i },
  { tech: "Tawk.to", category: "chat", re: /embed\.tawk\.to/i },
  { tech: "WhatsApp link", category: "chat", re: /wa\.me\/|api\.whatsapp\.com|wa\.link/i },
  { tech: "Cloudflare", category: "hosting", re: /cdnjs\.cloudflare\.com|cloudflare/i },
];

/** The first markup string matching each tool (a tool is reported once). */
export function fingerprint(markup: string[]): TechHit[] {
  const out: TechHit[] = [];
  for (const rule of RULES) {
    const hit = markup.find((m) => rule.re.test(m));
    if (hit) out.push({ tech: rule.tech, category: rule.category, evidence: hit });
  }
  return out;
}
