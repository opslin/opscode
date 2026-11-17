// Featured MCP servers: well-known public servers Opscode's MCP client can run
// as they are (a local command through npx, or an HTTP URL). Each lists the keys
// it needs; adding one asks for them and keeps them only in mcp.json (0600).
// Servers that need a browser sign-in (OAuth) are not listed: Opscode can't do that yet.

export interface CatalogInput {
  key: string;
  label: string;
  help: string;
  /** Where the value goes: an environment variable, or an HTTP header (template uses {value}). */
  as: "env" | "header";
  header?: string;
  template?: string;
}
export interface CatalogEntry {
  id: string;
  name: string;
  description: string;
  /** One or two letters for the tile (no brand logos). */
  mark: string;
  transport: "stdio" | "http";
  command?: string;
  args?: string[];
  url?: string;
  inputs: CatalogInput[];
  /** Shown before adding: what it needs on this computer. */
  needs?: string;
  docs: string;
}

export const MCP_CATALOG: CatalogEntry[] = [
  {
    id: "github", name: "GitHub", mark: "GH", description: "Pull requests, issues and code search",
    transport: "http", url: "https://api.githubcopilot.com/mcp/",
    inputs: [{ key: "GITHUB_TOKEN", label: "Personal access token", help: "github.com → Settings → Developer settings → Personal access tokens.", as: "header", header: "Authorization", template: "Bearer {value}" }],
    docs: "https://github.com/github/github-mcp-server",
  },
  {
    id: "playwright", name: "Playwright", mark: "Pw", description: "Drive a browser to check your app",
    transport: "stdio", command: "npx", args: ["-y", "@playwright/mcp@latest"], inputs: [], needs: "Node.js (npx)",
    docs: "https://github.com/microsoft/playwright-mcp",
  },
  {
    id: "context7", name: "Context7", mark: "C7", description: "Current docs for any library",
    transport: "http", url: "https://mcp.context7.com/mcp", inputs: [],
    docs: "https://github.com/upstash/context7",
  },
  {
    id: "chrome-devtools", name: "Chrome DevTools", mark: "Cd", description: "Inspect, debug and profile pages in Chrome",
    transport: "stdio", command: "npx", args: ["-y", "chrome-devtools-mcp@latest"], inputs: [], needs: "Node.js (npx) and Chrome",
    docs: "https://github.com/ChromeDevTools/chrome-devtools-mcp",
  },
  {
    id: "supabase", name: "Supabase", mark: "Sb", description: "Postgres, auth and edge functions",
    transport: "stdio", command: "npx", args: ["-y", "@supabase/mcp-server-supabase@latest"], needs: "Node.js (npx)",
    inputs: [{ key: "SUPABASE_ACCESS_TOKEN", label: "Access token", help: "supabase.com → Account → Access tokens.", as: "env" }],
    docs: "https://github.com/supabase-community/supabase-mcp",
  },
  {
    id: "notion", name: "Notion", mark: "N", description: "Specs, docs and databases",
    transport: "stdio", command: "npx", args: ["-y", "@notionhq/notion-mcp-server"], needs: "Node.js (npx)",
    inputs: [{ key: "NOTION_TOKEN", label: "Integration token", help: "notion.so/my-integrations → New integration, then share pages with it.", as: "env" }],
    docs: "https://github.com/makenotion/notion-mcp-server",
  },
  {
    id: "sentry", name: "Sentry", mark: "Se", description: "Errors, stack traces and releases",
    transport: "stdio", command: "npx", args: ["-y", "@sentry/mcp-server@latest"], needs: "Node.js (npx)",
    inputs: [{ key: "SENTRY_ACCESS_TOKEN", label: "User auth token", help: "sentry.io → Settings → Auth tokens.", as: "env" }],
    docs: "https://github.com/getsentry/sentry-mcp",
  },
  {
    id: "figma", name: "Figma", mark: "F", description: "Build UI from Figma frames",
    transport: "http", url: "http://127.0.0.1:3845/mcp", inputs: [], needs: "The Figma desktop app with its Dev Mode MCP server turned on",
    docs: "https://help.figma.com/hc/en-us/articles/32132100833559",
  },
  {
    id: "huggingface", name: "Hugging Face", mark: "HF", description: "Models, datasets and papers",
    transport: "http", url: "https://huggingface.co/mcp",
    inputs: [{ key: "HF_TOKEN", label: "Access token", help: "huggingface.co → Settings → Access tokens (read).", as: "header", header: "Authorization", template: "Bearer {value}" }],
    docs: "https://huggingface.co/settings/mcp",
  },
  {
    id: "memory", name: "Knowledge graph", mark: "Kg", description: "A local memory the agent can read and update",
    transport: "stdio", command: "npx", args: ["-y", "@modelcontextprotocol/server-memory"], inputs: [], needs: "Node.js (npx)",
    docs: "https://github.com/modelcontextprotocol/servers/tree/main/src/memory",
  },
  {
    id: "sequential-thinking", name: "Sequential thinking", mark: "St", description: "Step-by-step reasoning for hard problems",
    transport: "stdio", command: "npx", args: ["-y", "@modelcontextprotocol/server-sequential-thinking"], inputs: [], needs: "Node.js (npx)",
    docs: "https://github.com/modelcontextprotocol/servers/tree/main/src/sequentialthinking",
  },
];

/** Turns the values the person typed into env/headers for the server. Throws when one is missing. */
export function catalogSecrets(entry: CatalogEntry, values: Record<string, string>): { env?: Record<string, string>; headers?: Record<string, string> } {
  const env: Record<string, string> = {};
  const headers: Record<string, string> = {};
  for (const i of entry.inputs) {
    const v = (values[i.key] ?? "").trim();
    if (!v) throw new Error(`${entry.name} needs its ${i.label.toLowerCase()}`);
    if (i.as === "env") env[i.key] = v;
    else headers[i.header ?? i.key] = (i.template ?? "{value}").replace("{value}", v);
  }
  for (const k of Object.keys(values)) if (!entry.inputs.some((i) => i.key === k)) throw new Error(`${entry.name} has no setting ${k}`);
  return { ...(Object.keys(env).length ? { env } : {}), ...(Object.keys(headers).length ? { headers } : {}) };
}
