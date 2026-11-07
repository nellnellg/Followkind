import test from 'node:test';
import assert from 'node:assert/strict';
import {validateHours,summarize,csvCell} from '../app/lib/domain.ts';
const base={date:'2026-11-07',family:'Lopez',message:'visit',status:'confirmed'};
test('hours must be explicit, positive, finite and at most 24',()=>{for(const v of ['', ' ', '0','-1','25','Infinity','abc','1.234'])assert.notEqual(validateHours(v),'');for(const v of ['1','0.25','24','2.50'])assert.equal(validateHours(v),'');});
test('shared visit preserves each volunteer contribution and excludes pending records',()=>{const records=[{...base,id:'a',volunteer:'James',visit_id:'same',hours:2},{...base,id:'b',volunteer:'Maria',visit_id:'same',hours:2},{...base,id:'c',volunteer:'Maya',visit_id:'second',hours:1},{...base,id:'d',volunteer:'Other',visit_id:'pending',hours:3,status:'review'}];const result=summarize(records,[{id:'n',title:'Crib',family_reference:'Lopez',status:'received'}],'2026-11-02','2026-11-08');assert.equal(result.hours,5);assert.equal(result.visits,2);assert.equal(result.pending,3);assert.equal(result.open,1);});
test('reports exclude records outside date range',()=>{assert.equal(summarize([{...base,id:'a',volunteer:'A',visit_id:'v',hours:2}],[],'2026-11-09','2026-11-15').hours,0);});
test('CSV neutralizes formulas and quotes safely',()=>{assert.equal(csvCell('=1+1'),'"\'=1+1"');assert.equal(csvCell('A "quote"'),'"A ""quote"""');});
