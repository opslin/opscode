// Featured MCP servers: well-known public servers Opscode's MCP client can run
// as they are (a local command through npx, or an HTTP URL). Each lists the keys
// it needs; adding one asks for them and keeps them only in mcp.json (0600).
// Servers behind a browser sign-in (auth: "oauth") are signed in to from the Plugins page (src/runtime/mcpOAuth.ts).
// Their addresses and sign-in settings were read from each server's own metadata on 2026-11-17 (RFC 9728 and 8414).

export interface CatalogInput {
  key: string;
  label: string;
  help: string;
  /** Where the value goes: an environment variable, or an HTTP header (template uses {value}). */
  as: "env" | "header";
  header?: string;
  template?: string;
  /** Not needed to connect; with it the server gives more (Firecrawl works without a key, rate-limited). */
  optional?: boolean;
}
export type CatalogCategory = "Developer tools" | "Productivity" | "Data and analytics" | "Payments and cloud" | "Communication" | "Web" | "Email and marketing";
export interface CatalogEntry {
  id: string;
  name: string;
  description: string;
  category: CatalogCategory;
  /** Shown in the Recommended row at the top of the Plugins page. */
  featured?: boolean;
  /** "oauth": the person signs in in their browser; nothing is typed in. */
  auth?: "oauth";
  /** Scopes to ask for when the server's own list is too long or too wide. */
  oauthScope?: string;
  /** Why Add is off for now (the service only lets apps it has registered sign in). */
  unavailable?: string;
  /** One or two letters, shown only if the logo file is missing. */
  mark: string;
  /** The file in assets/brand/integrations (the service's own logo). */
  logo: string;
  transport: "stdio" | "http";
  command?: string;
  args?: string[];
  url?: string;
  inputs: CatalogInput[];
  /** Shown before adding: what it needs on this computer. */
  needs?: string;
  /** For services where each person has their own server address (Zoho MCP, Hostinger Mail): the address is pasted in and is kept as a secret. */
  urlInput?: { key: string; label: string; help: string; placeholder: string };
  /** An honest note shown in the add dialog (for example, a sign-in step Opscode cannot show yet). */
  note?: string;
  docs: string;
}

export const MCP_CATALOG: CatalogEntry[] = [
  {
    id: "firecrawl", category: "Web", name: "Firecrawl", mark: "Fc", logo: "firecrawl.svg", description: "Search, scrape and read any web page. Works without a key (rate-limited)",
    transport: "http", url: "https://mcp.firecrawl.dev/v2/mcp",
    inputs: [{ key: "FIRECRAWL_API_KEY", label: "API key (optional)", help: "Optional. Without it, scrape, search and parse work with limits. firecrawl.dev gives 1,000 free credits a month and no card, and a key unlocks every tool.", as: "header", header: "Authorization", template: "Bearer {value}", optional: true }],
    docs: "https://docs.firecrawl.dev/mcp-server",
  },
  {
    id: "tinyfish", category: "Web", name: "TinyFish", mark: "Tf", logo: "tinyfish.svg", description: "TinySearch and TinyFetch: web search and page reading (free), plus agent and browser tools (billed)",
    transport: "http", url: "https://agent.tinyfish.ai/mcp",
    inputs: [{ key: "TINYFISH_API_KEY", label: "API key", help: "agent.tinyfish.ai → API keys. Sign-up is free, and TinyFish says Search and Fetch are free; the Agent and Browser tools are metered.", as: "header", header: "Authorization", template: "Bearer {value}" }],
    docs: "https://docs.tinyfish.ai/mcp-integration",
  },
  {
    id: "zoho-campaigns", category: "Email and marketing", name: "Zoho Campaigns", mark: "Zc", logo: "zoho.svg", description: "Email marketing: campaigns, contacts, segments and reports (80+ tools)",
    transport: "http", inputs: [],
    urlInput: { key: "ZOHO_MCP_URL", label: "Your Zoho MCP server URL", help: "zoho.com/mcp → create a server → add the Zoho Campaigns tools → copy the URL under Connect. Treat it like a password.", placeholder: "https://…zohomcp.com/mcp/message?key=…" },
    needs: "A Zoho Campaigns account",
    note: "Zoho may ask you to approve access the first time a client connects. If it does, the server shows \"Needs a sign-in\" and Opscode opens your browser for it. Not yet tested against a real Zoho account.",
    docs: "https://help.zoho.com/portal/en/kb/campaigns-3-0/user-guide/mcp/articles/set-up-zoho-campaigns-mcp-server",
  },
  {
    id: "zoho-mail", category: "Email and marketing", name: "Zoho Mail", mark: "Zm", logo: "zoho.svg", description: "Read, search, draft and send mail from your Zoho Mail account",
    transport: "http", inputs: [],
    urlInput: { key: "ZOHO_MCP_URL", label: "Your Zoho MCP server URL", help: "zoho.com/mcp → create a server → add the Zoho Mail tools → copy the URL under Connect. Treat it like a password.", placeholder: "https://…zohomcp.com/mcp/message?key=…" },
    needs: "A Zoho Mail account (free or paid)",
    note: "Zoho may ask you to approve access the first time a client connects. If it does, the server shows \"Needs a sign-in\" and Opscode opens your browser for it. Not yet tested against a real Zoho account.",
    docs: "https://www.zoho.com/mail/help/mcp/getting-started.html",
  },
  {
    id: "hostinger-mail", category: "Email and marketing", name: "Hostinger Mail", mark: "Hm", logo: "hostinger.svg", description: "Read, search, draft and send from a Hostinger mailbox (not for bulk campaigns)",
    transport: "http", inputs: [],
    urlInput: { key: "HOSTINGER_MAIL_MCP_URL", label: "Your Hostinger Mail MCP server URL", help: "hPanel → Emails → your domain → Agentic mail → MCP Server.", placeholder: "https://…" },
    needs: "A Hostinger Business Email plan (paid)",
    note: "Hostinger's MCP server is for mailboxes. Its email marketing product (Hostinger Reach) has no MCP server yet. If Hostinger asks you to sign in, the server shows \"Needs a sign-in\" and Opscode opens your browser for it. This entry has not been tested against a real Hostinger account.",
    docs: "https://www.hostinger.com/support/how-to-use-agentic-mail-in-hostinger/",
  },
  {
    id: "github", category: "Developer tools", featured: true, name: "GitHub", mark: "GH", logo: "github.svg", description: "Pull requests, issues and code search",
    transport: "http", url: "https://api.githubcopilot.com/mcp/",
    inputs: [{ key: "GITHUB_TOKEN", label: "Personal access token", help: "github.com → Settings → Developer settings → Personal access tokens.", as: "header", header: "Authorization", template: "Bearer {value}" }],
    docs: "https://github.com/github/github-mcp-server",
  },
  {
    id: "playwright", category: "Developer tools", name: "Playwright", mark: "Pw", logo: "playwright.svg", description: "Drive a browser to check your app",
    transport: "stdio", command: "npx", args: ["-y", "@playwright/mcp@latest"], inputs: [], needs: "Node.js (npx)",
    docs: "https://github.com/microsoft/playwright-mcp",
  },
  {
    id: "context7", category: "Developer tools", name: "Context7", mark: "C7", logo: "context7.svg", description: "Current docs for any library",
    transport: "http", url: "https://mcp.context7.com/mcp", inputs: [],
    docs: "https://github.com/upstash/context7",
  },
  {
    id: "chrome-devtools", category: "Developer tools", name: "Chrome DevTools", mark: "Cd", logo: "chrome-devtools.svg", description: "Inspect, debug and profile pages in Chrome",
    transport: "stdio", command: "npx", args: ["-y", "chrome-devtools-mcp@latest"], inputs: [], needs: "Node.js (npx) and Chrome",
    docs: "https://github.com/ChromeDevTools/chrome-devtools-mcp",
  },
  {
    id: "supabase", category: "Developer tools", name: "Supabase (token)", mark: "Sb", logo: "supabase.svg", description: "Postgres, auth and edge functions",
    transport: "stdio", command: "npx", args: ["-y", "@supabase/mcp-server-supabase@latest"], needs: "Node.js (npx)",
    inputs: [{ key: "SUPABASE_ACCESS_TOKEN", label: "Access token", help: "supabase.com → Account → Access tokens.", as: "env" }],
    docs: "https://github.com/supabase-community/supabase-mcp",
  },
  {
    id: "notion", category: "Productivity", name: "Notion (token)", mark: "N", logo: "notion.svg", description: "Specs, docs and databases",
    transport: "stdio", command: "npx", args: ["-y", "@notionhq/notion-mcp-server"], needs: "Node.js (npx)",
    inputs: [{ key: "NOTION_TOKEN", label: "Integration token", help: "notion.so/my-integrations → New integration, then share pages with it.", as: "env" }],
    docs: "https://github.com/makenotion/notion-mcp-server",
  },
  {
    id: "sentry", category: "Developer tools", name: "Sentry (token)", mark: "Se", logo: "sentry.svg", description: "Errors, stack traces and releases",
    transport: "stdio", command: "npx", args: ["-y", "@sentry/mcp-server@latest"], needs: "Node.js (npx)",
    inputs: [{ key: "SENTRY_ACCESS_TOKEN", label: "User auth token", help: "sentry.io → Settings → Auth tokens.", as: "env" }],
    docs: "https://github.com/getsentry/sentry-mcp",
  },
  {
    id: "figma", category: "Productivity", name: "Figma (desktop app)", mark: "F", logo: "figma.svg", description: "Build UI from Figma frames",
    transport: "http", url: "http://127.0.0.1:3845/mcp", inputs: [], needs: "The Figma desktop app with its Dev Mode MCP server turned on",
    docs: "https://help.figma.com/hc/en-us/articles/32132100833559",
  },
  {
    id: "huggingface", category: "Web", name: "Hugging Face", mark: "HF", logo: "huggingface.svg", description: "Models, datasets and papers",
    transport: "http", url: "https://huggingface.co/mcp",
    inputs: [{ key: "HF_TOKEN", label: "Access token", help: "huggingface.co → Settings → Access tokens (read).", as: "header", header: "Authorization", template: "Bearer {value}" }],
    docs: "https://huggingface.co/settings/mcp",
  },
  {
    id: "memory", category: "Developer tools", name: "Knowledge graph", mark: "Kg", logo: "mcp.svg", description: "A local memory the agent can read and update",
    transport: "stdio", command: "npx", args: ["-y", "@modelcontextprotocol/server-memory"], inputs: [], needs: "Node.js (npx)",
    docs: "https://github.com/modelcontextprotocol/servers/tree/main/src/memory",
  },
  {
    id: "sequential-thinking", category: "Developer tools", name: "Sequential thinking", mark: "St", logo: "mcp.svg", description: "Step-by-step reasoning for hard problems",
    transport: "stdio", command: "npx", args: ["-y", "@modelcontextprotocol/server-sequential-thinking"], inputs: [], needs: "Node.js (npx)",
    docs: "https://github.com/modelcontextprotocol/servers/tree/main/src/sequentialthinking",
  },
  // ---- servers behind a browser sign-in ----------------------------------------------------------------------------------
  {
    id: "linear", category: "Productivity", featured: true, name: "Linear", mark: "Li", logo: "linear.svg", description: "Pick up an issue, work on it, and keep its status and comments current",
    transport: "http", url: "https://mcp.linear.app/mcp", auth: "oauth", inputs: [],
    docs: "https://linear.app/docs/mcp",
  },
  {
    id: "notion-hosted", category: "Productivity", featured: true, name: "Notion", mark: "N", logo: "notion.svg", description: "Search and edit your pages and databases, signed in with your own Notion account",
    transport: "http", url: "https://mcp.notion.com/mcp", auth: "oauth", inputs: [],
    docs: "https://developers.notion.com/docs/mcp",
  },
  {
    id: "sentry-hosted", category: "Developer tools", featured: true, name: "Sentry", mark: "Se", logo: "sentry.svg", description: "Errors, stack traces and releases, signed in with your Sentry account",
    transport: "http", url: "https://mcp.sentry.dev/mcp", auth: "oauth", inputs: [],
    docs: "https://docs.sentry.io/product/sentry-mcp/",
  },
  {
    id: "supabase-hosted", category: "Developer tools", name: "Supabase", mark: "Sb", logo: "supabase.svg", description: "Postgres, auth and edge functions, signed in with your Supabase account",
    transport: "http", url: "https://mcp.supabase.com/mcp", auth: "oauth", inputs: [],
    docs: "https://supabase.com/docs/guides/getting-started/mcp",
  },
  {
    id: "neon", category: "Developer tools", name: "Neon", mark: "Ne", logo: "neon.svg", description: "Branch, query and migrate serverless Postgres",
    transport: "http", url: "https://mcp.neon.tech/mcp", auth: "oauth", inputs: [],
    docs: "https://neon.com/docs/ai/neon-mcp-server",
  },
  {
    id: "vercel", category: "Developer tools", name: "Vercel", mark: "V", logo: "vercel.svg", description: "Deployments, build logs and project settings",
    transport: "http", url: "https://mcp.vercel.com", auth: "oauth", inputs: [],
    note: "Vercel lets only apps it has reviewed sign in. The sign-in may be refused until Opscode is approved.",
    docs: "https://vercel.com/docs/mcp/vercel-mcp",
  },
  {
    id: "atlassian", category: "Productivity", name: "Atlassian", mark: "At", logo: "atlassian.svg", description: "Jira and Confluence: issues, pages and search",
    transport: "http", url: "https://mcp.atlassian.com/v2/mcp", auth: "oauth", inputs: [],
    docs: "https://www.atlassian.com/platform/remote-mcp-server",
  },
  {
    id: "monday", category: "Productivity", name: "monday.com", mark: "Mo", logo: "monday.svg", description: "Boards, items and updates",
    transport: "http", url: "https://mcp.monday.com/mcp", auth: "oauth", inputs: [],
    docs: "https://developer.monday.com/apps/docs/mondaycom-mcp-integration",
  },
  {
    id: "figma-hosted", category: "Productivity", name: "Figma", mark: "F", logo: "figma.svg", description: "Read frames and design context from your Figma files",
    transport: "http", url: "https://mcp.figma.com/mcp", auth: "oauth", inputs: [],
    note: "Figma may admit only apps it has approved. If the sign-in is refused, use \"Figma (desktop app)\" instead.",
    docs: "https://developers.figma.com/docs/figma-mcp-server/",
  },
  {
    id: "stripe", category: "Payments and cloud", name: "Stripe", mark: "S", logo: "stripe.svg", description: "Payments, billing and Stripe docs",
    transport: "http", url: "https://mcp.stripe.com", auth: "oauth", inputs: [],
    docs: "https://docs.stripe.com/mcp",
  },
  {
    id: "cloudflare", category: "Payments and cloud", name: "Cloudflare", mark: "Cf", logo: "cloudflare.svg", description: "Workers, DNS and the Cloudflare API",
    transport: "http", url: "https://mcp.cloudflare.com/mcp", auth: "oauth", inputs: [],
    docs: "https://developers.cloudflare.com/agents/model-context-protocol/mcp-servers-for-cloudflare/",
  },
  {
    id: "posthog", category: "Data and analytics", name: "PostHog", mark: "Ph", logo: "posthog.svg", description: "Product analytics, feature flags and experiments",
    transport: "http", url: "https://mcp.posthog.com/mcp", auth: "oauth", inputs: [],
    docs: "https://posthog.com/docs/model-context-protocol",
  },
  {
    id: "firecrawl-signin", category: "Web", name: "Firecrawl (sign in)", mark: "Fc", logo: "firecrawl.svg", description: "Every Firecrawl tool, signed in with your Firecrawl account instead of a key",
    transport: "http", url: "https://mcp.firecrawl.dev/v2/mcp-oauth", auth: "oauth", inputs: [],
    docs: "https://docs.firecrawl.dev/mcp-server",
  },
  {
    id: "slack", category: "Communication", name: "Slack", mark: "Sl", logo: "", description: "Catch up on channels and threads, and draft updates",
    transport: "http", url: "https://mcp.slack.com/mcp", auth: "oauth", inputs: [],
    unavailable: "Slack lets only apps that are registered with it sign in, and Opscode has no Slack app yet.",
    docs: "https://docs.slack.dev/ai/mcp-server",
  },
  {
    id: "asana", category: "Productivity", name: "Asana", mark: "As", logo: "", description: "Tasks, projects and goals",
    transport: "http", url: "https://mcp.asana.com/v2/mcp", auth: "oauth", inputs: [],
    unavailable: "Asana lets only apps that are registered in its developer console sign in, and Opscode has no Asana app yet.",
    docs: "https://developers.asana.com/docs/using-asanas-mcp-server",
  },
];

/** Turns the values the person typed into env/headers (and, for per-person servers, the server address). Throws when a required one is missing. */
export function catalogSecrets(entry: CatalogEntry, values: Record<string, string>): { env?: Record<string, string>; headers?: Record<string, string>; url?: string } {
  const env: Record<string, string> = {};
  const headers: Record<string, string> = {};
  for (const i of entry.inputs) {
    const v = (values[i.key] ?? "").trim();
    if (!v) { if (i.optional) continue; throw new Error(`${entry.name} needs its ${i.label.toLowerCase()}`); }
    if (i.as === "env") env[i.key] = v;
    else headers[i.header ?? i.key] = (i.template ?? "{value}").replace("{value}", v);
  }
  let url: string | undefined;
  if (entry.urlInput) {
    url = (values[entry.urlInput.key] ?? "").trim();
    if (!url) throw new Error(`${entry.name} needs ${entry.urlInput.label.toLowerCase()}`);
    if (!/^https:\/\//i.test(url)) throw new Error(`${entry.urlInput.label} must start with https://`);
  }
  for (const k of Object.keys(values)) if (!entry.inputs.some((i) => i.key === k) && k !== entry.urlInput?.key) throw new Error(`${entry.name} has no setting ${k}`);
  return { ...(Object.keys(env).length ? { env } : {}), ...(Object.keys(headers).length ? { headers } : {}), ...(url ? { url } : {}) };
}
