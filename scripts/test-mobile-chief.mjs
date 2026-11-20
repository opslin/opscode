import assert from 'node:assert/strict';
import { MobileWorkspace } from '../dist/main/mobileWorkspace.js';
let chiefs=[]; const notes=[];
const client={ call: async (method,p) => {
 if(method==='chat.list') return {chats:[],running:[]};
 if(method==='chief.list') return {chiefs};
 if(method==='chief.create') { const chief={id:'chief1',chat_id:'chat1',mode:p.mode,project_ids:[p.project_id],name:'Conductor'}; chiefs.push(chief); return {chief}; }
 if(method==='chief.note') {notes.push(p); return {turn_id:'turn1',queued:false};}
 if(method==='turn.history') { if(p.workspace_id !== 'chief:chief1') throw Error('no such chat'); return {messages:[],settings:{title:'Conductor',mode:'read',engine:'claude-code'}}; }
 throw Error('unexpected '+method);
}};
const ws=new MobileWorkspace(()=>client);
try {
 const action={op:'submit',id:'one',workspace:'project1',text:'Build it',team:'warlord'};
 assert.deepEqual(await ws.request('phone',action),{chat:'chat1',turn:'turn1'});
 assert.deepEqual(await ws.request('phone',action),{chat:'chat1',turn:'turn1'});
 assert.equal(chiefs.length,1); assert.equal(notes.length,1);
 assert.equal((await ws.request('phone',{op:'chats',workspace:'project1'})).chats[0].team,'warlord');
 await ws.request('phone',{op:'history',workspace:'project1',chat:'chat1'});
 await assert.rejects(ws.request('phone',{op:'history',workspace:'other',chat:'chat1'}));
 console.log('PASS mobile conductor creation, idempotency and project scoping');
} finally {ws.stop()}
