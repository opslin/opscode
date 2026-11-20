import assert from 'node:assert/strict';
import { MobileWorkspace } from '../dist/main/mobileWorkspace.js';
let creates=0, attempts=0; const calls=[];
const client={call:async(method,p)=>{calls.push([method,p]);if(method==='chief.list')return {chiefs:[]};if(method==='chat.create'){creates++;return {chat:{id:'created-chat'}};}if(method==='turn.submit'){if(++attempts===1)throw Error('temporarily unavailable');return {turn_id:'turn-1'};}throw Error(method)}};
const ws=new MobileWorkspace(()=>client);
try {
 const action={op:'submit',id:'request-1',workspace:'project',text:'Start task',engine:'claude-code',model:'sonnet',effort:'high',mode:'supervised'};
 await assert.rejects(ws.request('phone',action),/temporarily unavailable/);
 assert.deepEqual(await ws.request('phone',action),{chat:'created-chat',turn:'turn-1'});
 assert.equal(creates,1,'retry must use the same created conversation');
 const create=calls.find(([m])=>m==='chat.create')[1]; assert.equal(create.model,'sonnet');assert.equal(create.effort,'high');
 console.log('PASS new chat retries preserve selected model without duplicate conversations');
} finally {ws.stop()}
