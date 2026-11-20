import assert from 'node:assert/strict';
import { MobileWorkspace } from '../dist/main/mobileWorkspace.js';
const text='Long history '.repeat(2400)+'हिन्दी🙂';
const messages=[{role:'user',text,turn_id:'turn1',status:'complete'}];
const client={call:async(method)=>{ if(method==='chief.list')return {chiefs:[]}; if(method==='turn.history')return {messages,settings:{title:'A chat',mode:'supervised',engine:'api'}}; throw Error(method); }};
const ws=new MobileWorkspace(()=>client);
try {
 const page=await ws.request('phone',{op:'history',workspace:'project',chat:'chat'});
 const m=page.messages[0];
 assert.equal(m.index,0); assert.equal(m.text_length,text.length); assert.ok(m.revision);
 let result=m.text;
 while(result.length<text.length){const p=await ws.request('phone',{op:'history.text',workspace:'project',chat:'chat',index:0,turn:'turn1',role:'user',revision:m.revision,offset:result.length}); assert.equal(p.offset,result.length); result+=p.text;}
 assert.equal(result,text);
 messages[0].text='changed';
 await assert.rejects(ws.request('phone',{op:'history.text',workspace:'project',chat:'chat',index:0,turn:'turn1',role:'user',revision:m.revision,offset:10000}),/changed/i);
 messages[0].text='\u0000'.repeat(10000);
 const escapedPage=await ws.request('phone',{op:'history',workspace:'project',chat:'chat'});
 assert.equal(escapedPage.messages.length,1,'heavily escaped text must not stall pagination');
 assert.equal(escapedPage.before,0);
 assert.ok(escapedPage.messages[0].revision,'remaining text must remain available');
 console.log('PASS long history can be reconstructed and rejects changed messages');
} finally {ws.stop()}
