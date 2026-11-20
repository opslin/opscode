import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { startRuntime } from './lib/harness.mjs';
import { MainRpcClient } from '../dist/main/rpcClient.js';
const dir=mkdtempSync(join(tmpdir(),'mobile-turn-idempotency-')); const project=join(dir,'project'); mkdirSync(project);
const state=join(dir,'state'); mkdirSync(state);
let rt=await startRuntime({stateDir:state,keepState:true}); assert.ok(rt.ready); let client=new MainRpcClient(rt); await client.open();
try {
 const workspace=(await client.call('workspace.add',{path:project})).workspace;
 const createArgs={workspace_id:workspace.id,engine:'api',request_id:'mobile-create-test'};
 const chat=(await client.call('chat.create',createArgs)).chat;
 assert.equal((await client.call('chat.create',createArgs)).chat.id,chat.id,'retry must not create a second chat');
 const args={workspace_id:workspace.id,chat_id:chat.id,text:'First message',request_id:'mobile-test-request'};
 const first=await client.call('turn.submit',args);
 const retry=await client.call('turn.submit',args);
 assert.equal(retry.turn_id,first.turn_id);
 const history=await client.call('turn.history',{workspace_id:workspace.id,chat_id:chat.id});
 assert.equal(history.messages.filter(m=>m.role==='user' && m.text===args.text).length,1);
 await assert.rejects(client.call('turn.submit',{...args,text:'Different message'}),/request/i);
 await assert.rejects(client.call('chat.create',{...createArgs,model:'different'}),/request/i);
 client.close(); await rt.stop();
 rt=await startRuntime({stateDir:state,keepState:true}); assert.ok(rt.ready); client=new MainRpcClient(rt); await client.open();
 assert.equal((await client.call('chat.create',createArgs)).chat.id,chat.id,'created chat survives runtime restart');
 assert.equal((await client.call('turn.submit',args)).turn_id,first.turn_id,'retried turn survives runtime restart');
 console.log('PASS runtime deduplicates retried mobile turns and rejects changed content');
} finally {client.close();await rt.stop();rmSync(dir,{recursive:true,force:true});}
