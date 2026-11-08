import {test} from 'node:test';
import assert from 'node:assert/strict';
import {analyze} from '../worker/analyze.ts';
const req=()=>new Request('https://example.com/api/analyze',{method:'POST',headers:{Authorization:'Bearer session'},body:JSON.stringify({updateId:'11111111-1111-1111-1111-111111111111'})});
const response=(body:unknown)=>Response.json(body);
test('anonymous callers cannot spend API credits',async()=>{const r=await analyze(new Request('https://example.com',{method:'POST'}),'key',()=>{throw Error('must not fetch');});assert.equal(r.status,401);});
test('RLS denial stops model requests',async()=>{let calls=0;const r=await analyze(req(),'key',async()=>{calls++;return response([]);});assert.equal(r.status,404);assert.equal(calls,1);});
test('source evidence must be verbatim and no AI action is committed',async()=>{for(const evidence of ['needs diapers','invented quote']){let calls=0;const r=await analyze(req(),'key',async(input,options)=>{calls++;if(calls===1)return response([{source_message:'The family needs diapers.',status:'review'}]);assert.equal(String(input),'https://api.openai.com/v1/responses');assert.equal(JSON.parse(String(options?.body)).store,false);return response({output:[{content:[{type:'output_text',text:JSON.stringify({title:'Diapers',evidence})}]}]});});assert.equal(r.status,evidence==='needs diapers'?200:502);assert.equal(calls,2);}});
