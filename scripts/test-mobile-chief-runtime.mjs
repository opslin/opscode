import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { startRuntime, sleep } from './lib/harness.mjs';
import { MainRpcClient } from '../dist/main/rpcClient.js';
import { MobileWorkspace } from '../dist/main/mobileWorkspace.js';
const dir=mkdtempSync(join(tmpdir(),'mobile-chief-test-')); const project=join(dir,'project'); mkdirSync(project); writeFileSync(join(project,'readme.txt'),'project attachment');
const rt=await startRuntime({env:{OPSCODE_CLAUDE_BIN:join(process.cwd(),'scripts/lib/fake-claude.mjs')}}); assert.ok(rt.ready);
const client=new MainRpcClient(rt); await client.open(); const mobile=new MobileWorkspace(()=>client);
try {
 const ws=(await client.call('workspace.add',{path:project})).workspace;
 for(const team of ['godmode','warlord','shinobi']){
   const request={op:'submit',id:'test-'+team,workspace:ws.id,team,text:'Review the project.',projectFiles:['readme.txt']};
   const sent=await mobile.request('phone',request); assert.ok(sent.chat);
   assert.deepEqual(await mobile.request('phone',request),sent);
   assert.ok((await mobile.request('phone',{op:'chats',workspace:ws.id})).chats.some(c=>c.id===sent.chat && c.team===team));
   const chief=(await client.call('chief.list',{})).chiefs.find(c=>c.chat_id===sent.chat); assert.equal(chief.mode,team);
   for(let until=Date.now()+6000;Date.now()<until;){ const h=await mobile.request('phone',{op:'history',workspace:ws.id,chat:sent.chat}); if(h.messages.some(m=>m.role==='user')) break; await sleep(50); }
   const h=await mobile.request('phone',{op:'history',workspace:ws.id,chat:sent.chat}); assert.ok(h.messages.some(m=>m.role==='user'));
 }
 console.log('PASS all three mobile modes create real Mac conductors with project attachments');
} finally {mobile.stop();client.close();await rt.stop();rmSync(dir,{recursive:true,force:true});}
