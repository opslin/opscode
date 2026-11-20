import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { createServer } from 'node:http';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { once } from 'node:events';
import { startRuntime, sleep } from './lib/harness.mjs';
import { MainRpcClient } from '../dist/main/rpcClient.js';
import { MobileWorkspace } from '../dist/main/mobileWorkspace.js';
const dir=mkdtempSync(join(tmpdir(),'mobile-voice-test-')); const state=join(dir,'state'); const project=join(dir,'project'); mkdirSync(project);
const model=join(state,'tts','sherpa-onnx-pocket-tts-int8-2026-01-26'); mkdirSync(model,{recursive:true}); writeFileSync(join(model,'a.onnx'),'x');
const events=[{type:'content_block_start',index:0,content_block:{type:'text',text:''}},{type:'content_block_delta',index:0,delta:{type:'text_delta',text:'Hello from the Mac.'}},{type:'content_block_stop',index:0},{type:'message_delta',delta:{stop_reason:'end_turn'}}];
const server=createServer((req,res)=>{req.resume();req.on('end',()=>{res.writeHead(200,{'content-type':'text/event-stream'});res.end(events.map(e=>`event: ${e.type}\ndata: ${JSON.stringify(e)}\n\n`).join(''));});});
server.listen(0,'127.0.0.1'); await once(server,'listening');
const root=process.cwd(); const rt=await startRuntime({stateDir:state,keepState:true,env:{OPSCODE_VOICE_HELPER:join(root,'scripts/lib/fake-voice.mjs'),OPSCODE_TTS_URL:'http://127.0.0.1:1/unused',OPSCODE_TTS_FILES:'a.onnx',OPSCODE_TTS_WORKER:join(root,'scripts/lib/fake-tts-worker.mjs'),OPSCODE_FAKE_TTS_MS:'20'}});
assert.ok(rt.ready); const client=new MainRpcClient(rt); await client.open(); const workspace=new MobileWorkspace(()=>client);
client.on('voiceagent.event',v=>workspace.voiceEvent('agent',v)); client.on('tts.event',v=>workspace.voiceEvent('tts',v));
try {
 const ws=(await client.call('workspace.add',{path:project})).workspace;
 await client.call('provider.set',{id:'anthropic',api_key:'sk-test-local',base_url:`http://127.0.0.1:${server.address().port}`,model:'test'});
 const started=await workspace.request('phone',{op:'voice.start',workspace:ws.id});
 await workspace.request('phone',{op:'voice.audio',pcm:Buffer.alloc(3200).toString('base64')});
 await client.call('voiceagent.say',{session:started.session,text:'hello'});
 let ack=0, sawAudio=false, sawText=false;
 for(let until=Date.now()+10000;Date.now()<until && !sawAudio;) {
   const item=await workspace.request('phone',{op:'voice.poll',ack});
   if(!item.seq){await sleep(40);continue} ack=item.seq;
   if(item.event.ev==='say') sawText=true;
   if(item.event.ev==='audio'){assert.ok(Buffer.from(item.event.pcm,'base64').length>0);sawAudio=true;}
 }
 assert.ok(sawText,'voice reply text reached phone bridge'); assert.ok(sawAudio,'synthesized audio reached phone bridge');
 await workspace.request('phone',{op:'voice.stop'});
 console.log('PASS mobile bridge through real voice runtime with simulated microphone, model, and speaker');
} finally { workspace.stop(); client.close(); await rt.stop(); server.close(); rmSync(dir,{recursive:true,force:true}); }
