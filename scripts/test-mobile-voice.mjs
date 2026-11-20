import assert from 'node:assert/strict';
import { MobileWorkspace } from '../dist/main/mobileWorkspace.js';
const calls=[];
const client={call:async(method,p)=>{calls.push([method,p]); if(method==='voiceagent.start')return {session:'voice1'}; return {ok:true}}};
const ws=new MobileWorkspace(()=>client);
try {
 await ws.request('phone1',{op:'voice.start',workspace:'project1'});
 ws.voiceEvent('agent',{session:'voice1',ev:'say_start',tts:'tts1'});
 ws.voiceEvent('tts',{session:'tts1',ev:'audio',i:0,rate:24000,pcm:Buffer.alloc(22000).toString('base64')});
 const first=await ws.request('phone1',{op:'voice.poll',ack:0});
 assert.equal(first.event.ev,'say_start');
 const second=await ws.request('phone1',{op:'voice.poll',ack:first.seq});
 assert.equal(second.event.ev,'audio');
 assert.ok(second.event.pcm.length < 30000);
 const retry=await ws.request('phone1',{op:'voice.poll',ack:first.seq});
 assert.equal(retry.seq,second.seq);
 await assert.rejects(ws.request('phone2',{op:'voice.poll',ack:0}),/voice session/i);
 await ws.request('phone1',{op:'voice.stop'});
 assert.equal(calls.at(-1)[0],'voiceagent.stop');
 console.log('PASS mobile voice ownership, audio chunking and retry');
} finally {ws.stop()}
