const {test}=require('node:test');
const assert=require('node:assert/strict');
const model=require('../static/visual_builder.js');

const operations=[{id:'add',output:'Number',arguments:[{type:'Number',default:1},{type:'Number',default:2}]},
    {id:'poly',output:'Polynomial',arguments:[]},{id:'derive',output:'Polynomial',arguments:[{type:'Polynomial',default:null}]}];
function definition(){return {parameters:[{name:'a',kind:'integer'},{name:'flag',kind:'boolean'}],
    steps:[{name:'p',operation:'poly',arguments:[]},{name:'d',operation:'derive',arguments:[{ref:'p'}]}],
    prompt:'Given {p}, find {d}.',answer:'d',constraints:[{ref:'flag',expected:true}]};}

test('only earlier values are available and Boolean parameters have Truth type',()=>{
    const before=model.symbolsBefore(definition(),operations,1);
    assert.deepEqual(before,[{name:'a',type:'Number'},{name:'flag',type:'Truth'},{name:'p',type:'Polynomial'}]);
    assert.ok(!before.some(x=>x.name==='d'));
});
test('renaming changes structured references, question text, answer and constraints',()=>{
    const spec=definition();assert.equal(model.rename(spec,'p','polynomial'),true);
    assert.equal(spec.steps[1].arguments[0].ref,'polynomial');assert.ok(spec.prompt.includes('{polynomial}'));
    assert.equal(model.rename(spec,'flag','condition'),true);assert.equal(spec.constraints[0].ref,'condition');
    assert.equal(model.rename(spec,'d','answer'),true);assert.equal(spec.answer,'answer');
});
test('invalid and duplicate names are rejected without modifying the graph',()=>{
    const spec=definition(),before=structuredClone(spec);
    assert.equal(model.rename(spec,'p','a'),false);assert.equal(model.rename(spec,'p','../x'),false);
    assert.deepEqual(spec,before);
});
test('used results cannot be silently deleted',()=>{
    const spec=definition();assert.equal(model.isReferenced(spec,'p'),true);assert.equal(model.isReferenced(spec,'d'),true);
    assert.equal(model.isReferenced(spec,'flag'),true);assert.equal(model.isReferenced(spec,'a'),false);
});
test('new mathematical steps choose compatible references, not arbitrary previous values',()=>{
    const symbols=model.symbolsBefore(definition(),operations,1);
    assert.deepEqual(model.defaultArguments(operations[2],symbols),[{ref:'p'}]);
    assert.deepEqual(model.defaultArguments(operations[0],symbols),[{literal:1},{literal:2}]);
    assert.deepEqual(model.defaultArguments(operations[2],[]),[{ref:''}]);
});
test('finite sets can feed set operations but intervals cannot feed finite-set insertion',()=>{
    assert.equal(model.compatibleType('FiniteSet','Set'),true);
    assert.equal(model.compatibleType('Set','FiniteSet'),false);
    assert.equal(model.compatibleType('Polynomial','Number'),false);
});
