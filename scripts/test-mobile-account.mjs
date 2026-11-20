import assert from 'node:assert/strict';
import { MobileWorkspace } from '../dist/main/mobileWorkspace.js';
const calls = [];
const client = { call: async (method, args) => {
  calls.push([method, args]);
  if (method === 'accounts.list') return { accounts: [{ id:'primary', engine:'claude-code', is_default:true, active:true, status:{ signed_in:true, email:'user@example.com', secret:'never send' }, home:'/secret' }] };
  if (method === 'provider.list') return { providers:[{id:'anthropic',label:'Anthropic',configured:true,active:true,model:'model1',key_hint:'xxxx'}] };
  if (method === 'provider.select') return {};
  if (method === 'chat.list') return { chats: [{ id:'chat1', title:'Chat', mode:'supervised', engine:'claude-code' }] };
  if (method === 'chat.set_account') return { chat: { id:'chat1', title:'Chat', mode:'supervised', engine:'claude-code', account_id:args.account_id } };
  throw Error('unexpected ' + method);
} };
const workspace = new MobileWorkspace(() => client);
try {
  const listing = await workspace.request('phone', { op:'accounts' });
  assert.deepEqual(listing.accounts, [{id:'primary', engine:'claude-code', is_default:true, active:true, signed_in:true, email:'user@example.com'}]);
  assert.deepEqual((await workspace.request('phone', {op:'providers'})).providers, [{id:'anthropic',label:'Anthropic',active:true,model:'model1'}]);
  await workspace.request('phone', {op:'provider.select', provider:'anthropic'});
  assert.deepEqual(calls.at(-1), ['provider.select', {id:'anthropic'}]);
  await workspace.request('phone', { op:'chat.account', workspace:'project1', chat:'chat1', account:'primary' });
  assert.deepEqual(calls.at(-1), ['chat.set_account', {chat_id:'chat1', account_id:'primary'}]);
  await assert.rejects(workspace.request('phone', { op:'chat.account', workspace:'another', chat:'bad', account:'primary' }), /conversation/);
  console.log('PASS mobile account listing and project-scoped switching');
} finally { workspace.stop(); }
