// Real-model browser test (OPSCODE_REALTEST=1, run by scripts/realtest-browser.mjs).
// Serves a small shop web app with planted bugs, opens a project, and asks a real
// Claude Code chat to test the shop through Opscode's browser tools. Records every
// tool call, the engine's own token usage, time, and whether the order went through,
// into $OPSCODE_REALTEST_OUT/result.json (+ screenshots). Uses the user's real Claude
// Code sign-in, so it spends real usage.

import type { BrowserWindow } from "electron";
import { createServer } from "node:http";
import { existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { join } from "node:path";
import { MainRpcClient } from "./rpcClient";
import type { RuntimeSupervisor } from "./runtime";

const pause = (ms: number) => new Promise((r) => setTimeout(r, ms));

const SHOP = String.raw`<!doctype html><html><head><meta charset=utf-8><title>Tiny Shop</title>
<style>body{font-family:system-ui;margin:0;background:#fafafa}header{display:flex;gap:12px;align-items:center;padding:12px 20px;background:#222;color:#fff}
header .grow{flex:1}main{padding:20px;max-width:900px;margin:auto}.card{background:#fff;border:1px solid #ddd;border-radius:10px;padding:16px;margin:10px 0}
.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:12px}.prod img{width:100%;height:90px;object-fit:cover;background:#eee;border-radius:6px}
.dd{position:relative;display:inline-block}.dd-list{position:absolute;top:100%;left:0;background:#fff;border:1px solid #ccc;border-radius:6px;display:none;z-index:5;min-width:160px}
.dd.open .dd-list{display:block}.dd-item{padding:6px 10px;cursor:pointer}.dd-item:hover{background:#eef}
#drawer{position:fixed;right:0;top:0;bottom:0;width:320px;background:#fff;box-shadow:-4px 0 20px #0003;padding:16px;transform:translateX(110%);transition:transform .2s}#drawer.open{transform:none}
.err{color:#b00}.ok{color:#070}button{padding:6px 12px;border-radius:6px;border:1px solid #888;background:#fff;cursor:pointer}</style></head>
<body><header><b>Tiny Shop</b><span class=grow></span><span id=who>Not signed in</span><button id=cartBtn aria-label="Cart">🛒 <span id=count>0</span></button></header>
<main>
<section id=signup class=card><h2>Create account</h2>
<p><label>Full name <input id=name></label></p>
<p><label>Email <input id=email type=email></label></p>
<p><label>Password <input id=pw type=password></label> <small>8+ characters</small></p>
<p>Country: <span class=dd id=country><button type=button class=dd-btn>Choose…</button><span class=dd-list role=listbox>
<span class=dd-item role=option>India</span><span class=dd-item role=option>Germany</span><span class=dd-item role=option>Brazil</span></span></span></p>
<p><label><input type=checkbox id=terms> I accept the terms</label></p>
<p><button id=create>Create account</button> <span id=signupMsg></span></p></section>
<section id=shop class=card hidden><h2>Products</h2><div class=grid id=grid>Loading…</div></section>
</main>
<aside id=drawer aria-label="Cart drawer"><h3>Your cart</h3><div id=lines></div><p>Total: <b id=total>0</b></p>
<button id=checkout>Check out</button> <button id=closeCart>Close</button><p id=orderMsg></p></aside>
<script>
let user=null,country=null,cart=[],products=[];
const $=(s)=>document.querySelector(s);
$('#country .dd-btn').onclick=()=>$('#country').classList.toggle('open');
document.querySelectorAll('.dd-item').forEach(i=>i.onclick=()=>{country=i.textContent;$('#country .dd-btn').textContent=country;$('#country').classList.remove('open')});
$('#create').onclick=()=>{const n=$('#name').value.trim(),e=$('#email').value.trim(),p=$('#pw').value;
 if(!n||!/^\S+@\S+\.\S+$/.test(e))return $('#signupMsg').innerHTML='<span class=err>Name and a valid email are needed</span>';
 if(p.length<8)return $('#signupMsg').innerHTML='<span class=err>Password too short</span>';
 if(!country)return $('#signupMsg').innerHTML='<span class=err>Pick a country</span>';
 if(!$('#terms').checked)return $('#signupMsg').innerHTML='<span class=err>Accept the terms</span>';
 user={n,e,country};$('#who').textContent='Hi, '+n.split(' ')[0];$('#signup').hidden=true;$('#shop').hidden=false;load()};
async function load(){const r=await fetch('/api/products');products=await r.json();
 $('#grid').innerHTML=products.map((p,i)=>'<div class="card prod"><img src="'+p.img+'" alt="'+p.name+'"><b>'+p.name+'</b><p>₹'+(p.price*1).toFixed(2)+'</p><button data-i='+i+'>Add to cart</button></div>').join('');
 document.querySelectorAll('#grid button').forEach(b=>b.onclick=()=>{cart.push(products[b.dataset.i]);$('#count').textContent=cart.length})}
$('#cartBtn').onclick=()=>{$('#drawer').classList.add('open');
 $('#lines').innerHTML=cart.map(p=>'<div>'+p.name+' — ₹'+p.price+'</div>').join('')||'Empty';
 $('#total').textContent='₹'+cart.reduce((s,p)=>s+p.price,0);
 if(cart.some(p=>p.name==='Mug'))console.error('TypeError: Cannot read properties of undefined (reading \'qty\') at renderLine (shop.js:88)')};
$('#closeCart').onclick=()=>$('#drawer').classList.remove('open');
$('#checkout').onclick=async()=>{if(!cart.length)return;if(!confirm('Place order for '+cart.length+' items?'))return;
 const r=await fetch('/api/orders',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({user,items:cart.map(p=>p.id)})});
 const j=await r.json();$('#orderMsg').innerHTML=r.ok?'<span class=ok>Order #'+j.id+' placed!</span>':'<span class=err>'+j.error+'</span>';if(r.ok){cart=[];$('#count').textContent=0}};
</script></body></html>`;

// Planted bugs: Tea's price is a string ("49" + "" -> total concatenates), Bag's image is a 404,
// opening the cart with a Mug logs a console TypeError, Candle costs NaN on the card.
const PRODUCTS = [
  { id: 1, name: "Mug", price: 199, img: "/img/mug.svg" },
  { id: 2, name: "Tea", price: "49", img: "/img/tea.svg" },
  { id: 3, name: "Bag", price: 899, img: "/img/bag-missing.png" },
  { id: 4, name: "Candle", price: "twelve", img: "/img/candle.svg" },
  { id: 5, name: "Notebook", price: 120, img: "/img/notebook.svg" },
  { id: 6, name: "Pen", price: 35, img: "/img/pen.svg" },
];

export async function runRealTest(win: BrowserWindow, sup: RuntimeSupervisor): Promise<void> {
  const out = process.env.OPSCODE_REALTEST_OUT || mkdtempSync(join(tmpdir(), "opscode-realtest-"));
  mkdirSync(out, { recursive: true });
  const say = (s: string) => console.log(`OPSCODE_REALTEST: ${s}`);
  const orders: unknown[] = [];
  const requests: string[] = [];
  const shop = createServer((req, res) => {
    requests.push(`${req.method} ${req.url}`);
    if (req.url === "/") return res.writeHead(200, { "content-type": "text/html" }).end(SHOP);
    if (req.url === "/api/products") return res.writeHead(200, { "content-type": "application/json" }).end(JSON.stringify(PRODUCTS));
    if (req.url === "/api/orders" && req.method === "POST") {
      let b = "";
      req.on("data", (c) => (b += c));
      req.on("end", () => { orders.push(JSON.parse(b || "{}")); res.writeHead(201, { "content-type": "application/json" }).end(JSON.stringify({ id: 1000 + orders.length })); });
      return;
    }
    if (req.url?.startsWith("/img/") && req.url.endsWith(".svg")) return res.writeHead(200, { "content-type": "image/svg+xml" }).end(`<svg xmlns="http://www.w3.org/2000/svg" width="120" height="90"><rect width="120" height="90" fill="#cde"/><text x="10" y="50">${req.url.slice(5, -4)}</text></svg>`);
    res.writeHead(404).end("not found");
  });
  await new Promise<void>((r) => shop.listen(0, "127.0.0.1", () => r()));
  const port = (shop.address() as { port: number }).port;
  const url = `http://localhost:${port}/`;
  const ev = <T,>(code: string): Promise<T> => win.webContents.executeJavaScript(code) as Promise<T>;
  const shot = async (name: string) => { try { writeFileSync(join(out, `${name}.png`), (await win.webContents.capturePage()).toPNG()); } catch { /* ignore */ } };

  try {
    await sup.waitReady(20_000);
    for (const end = Date.now() + 20_000; Date.now() < end; await pause(200)) if ((await ev<string>("window.__opscodeRpc ? window.__opscodeRpc.state : ''")) === "ready") break;
    const c = new MainRpcClient(sup.endpoint);
    await c.open();
    for (const end = Date.now() + 15_000; Date.now() < end; await pause(300)) if ((await c.call<{ browser: boolean }>("devices.status", {})).browser) break;

    const project = mkdtempSync(join(tmpdir(), "opscode-realtest-project-"));
    writeFileSync(join(project, "README.md"), `# Tiny Shop\n\nThe dev server is already running at ${url}\n`);
    const { workspace } = await c.call<{ workspace: { id: string } }>("workspace.add", { path: project });
    const model = process.env.OPSCODE_REALTEST_MODEL || undefined;
    const mode = (process.env.OPSCODE_REALTEST_MODE || "full") as "full";
    const { chat } = await c.call<{ chat: { id: string } }>("chat.create", { workspace_id: workspace.id, engine: "claude-code", mode, ...(model ? { model } : {}) });
    await pause(800);
    await ev(`document.querySelector('.sidebar-item[data-chat="${chat.id}"]')?.click()`);
    await pause(500);

    const prompt = process.env.OPSCODE_REALTEST_PROMPT || `A small shop web app is running at ${url}. Test it in the browser like a real customer: create an account (make up test details), add the two cheapest products to the cart, check out, and confirm the order went through. Then tell me every bug you noticed (wrong prices or totals, broken images, console errors, failed requests). Don't change any files.`;
    say(`chat ${chat.id}, model ${model ?? "(Claude Code default)"}, mode ${mode}`);
    const started = Date.now();
    await c.call("turn.submit", { workspace_id: workspace.id, chat_id: chat.id, text: prompt });
    let last: { status: string; text: string; error?: string; parts?: { kind: string; tool?: string; summary?: string; status?: string; output?: string; detail?: string }[] } | undefined;
    let shots = 0;
    for (const end = Date.now() + Number(process.env.OPSCODE_REALTEST_TIMEOUT_MS || 900_000); Date.now() < end; await pause(2000)) {
      const hist = await c.call<{ messages: (typeof last & { role: string; turn_id?: string })[] }>("turn.history", { chat_id: chat.id });
      last = hist.messages.filter((m) => m.role === "assistant").at(-1);
      if (Date.now() - started > shots * 30_000) { await shot(`progress-${String(shots).padStart(2, "0")}`); shots++; }
      if (last && last.status !== "streaming") break;
    }
    const secs = Math.round((Date.now() - started) / 1000);
    await shot("final");
    const meta = (await c.call<{ chats: Record<string, unknown>[] }>("chat.list", {})).chats.find((x) => x.id === chat.id) as { usage?: Record<string, unknown>; engine_session?: string; model?: string } | undefined;

    // Claude Code's own transcript has per-request usage (exact tokens per step).
    const steps: { model?: string; input: number; cache_read: number; cache_write: number; output: number; tools: string[] }[] = [];
    const session = meta?.engine_session;
    const projRoot = join(homedir(), ".claude", "projects");
    if (session && existsSync(projRoot)) {
      for (const d of readdirSync(projRoot)) {
        const f = join(projRoot, d, `${session}.jsonl`);
        if (!existsSync(f)) continue;
        const seen = new Set<string>();
        for (const line of readFileSync(f, "utf8").split("\n")) {
          if (!line.trim()) continue;
          let m: Record<string, any>;
          try { m = JSON.parse(line); } catch { continue; }
          if (m.type !== "assistant" || !m.message?.usage) continue;
          const id = m.message.id ?? m.uuid;
          const u = m.message.usage;
          const tools = (m.message.content ?? []).filter((b: Record<string, unknown>) => b.type === "tool_use").map((b: Record<string, unknown>) => String(b.name));
          if (seen.has(id)) { const s = steps.at(-1); if (s) s.tools.push(...tools); continue; }
          seen.add(id);
          steps.push({ model: m.message.model, input: u.input_tokens ?? 0, cache_read: u.cache_read_input_tokens ?? 0, cache_write: u.cache_creation_input_tokens ?? 0, output: u.output_tokens ?? 0, tools });
        }
      }
    }
    const result = {
      url, prompt, model: meta?.model ?? model, mode, seconds: secs, status: last?.status, error: last?.error,
      orders, requests, usage: meta?.usage, steps,
      tools: (last?.parts ?? []).filter((p) => p.kind === "tool").map((p) => ({ tool: p.tool, summary: p.summary, status: p.status, out_chars: p.output?.length ?? 0, output: (p.output ?? "").slice(0, 1500), detail: (p.detail ?? "").slice(0, 600) })),
      reply: last?.text ?? "",
    };
    writeFileSync(join(out, "result.json"), JSON.stringify(result, null, 2));
    say(`done in ${secs}s, status ${last?.status}, ${result.tools.length} tool calls, ${orders.length} order(s); result in ${out}`);
    c.close();
  } catch (e) {
    say(`FAIL ${e instanceof Error ? e.stack ?? e.message : String(e)}`);
  } finally {
    shop.close();
  }
}
