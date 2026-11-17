// Builds design/mode-cards/characters.html: a stand-alone page that shows the three
// mode characters (the same art module the app uses), animated, plus their emblems.
import { readFileSync, writeFileSync } from "node:fs";
const art = readFileSync("src/renderer/conductorart.js", "utf8").replace(/^export /gm, "");
const html = `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Mode characters</title>
<style>
:root{color-scheme:dark}*{box-sizing:border-box;margin:0}
body{background:#0e0f12;color:#eef0f4;font:14px/1.45 -apple-system,BlinkMacSystemFont,"Segoe UI",system-ui,sans-serif;padding:28px 16px;display:grid;justify-items:center;gap:24px}
.row{display:flex;gap:20px;flex-wrap:wrap;justify-content:center}
.card{width:250px;padding:18px 14px 20px;border:1px solid #262a33;border-radius:18px;background:#14161c;text-align:center}
canvas{image-rendering:pixelated;display:block;margin:0 auto 12px}
h2{font-size:20px;letter-spacing:.14em}p{margin-top:6px;font-size:13px;color:#9aa1ad}
.em{display:flex;gap:16px;align-items:center}.em img{image-rendering:pixelated;border-radius:6px}
</style></head><body>
<div class="row" id="row"></div><div class="em" id="em"></div>
<script>
${art}
const INFO={shinobi:["SHINOBI","Stealthy, efficient, low cost, fast."],warlord:["WARLORD","Strong development. Balanced intelligence."],godmode:["GODMODE","Ultimate multi-agent. Full power."]};
const row=document.getElementById("row");const SC=5;
(async()=>{
 const items=[];
 for(const id of ["godmode","warlord","shinobi"]){
  const c=document.createElement("canvas");c.width=ART_SIZE.w*SC;c.height=(ART_SIZE.h+2)*SC;
  const d=document.createElement("div");d.className="card";d.append(c);
  d.insertAdjacentHTML("beforeend","<h2 style='color:"+MODE_COLORS[id][0]+"'>"+INFO[id][0]+"</h2><p>"+INFO[id][1]+"</p>");row.append(d);
  items.push([c.getContext("2d"),await loadArt(id)]);
  const im=new Image();im.src=await emblemUrl(id,24);im.width=24;im.height=24;document.getElementById("em").append(im);
  const im2=new Image();im2.src=await emblemUrl(id,40);im2.width=40;im2.height=40;document.getElementById("em").append(im2);
 }
 const t0=performance.now();
 const loop=(n)=>{for(const[x,l]of items)drawArt(x,l,(n-t0)/1000,SC);requestAnimationFrame(loop)};requestAnimationFrame(loop);
})();
</script></body></html>`;
writeFileSync("design/mode-cards/characters.html", html);
console.log("wrote design/mode-cards/characters.html");
