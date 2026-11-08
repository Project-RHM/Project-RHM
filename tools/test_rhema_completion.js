const test=require('node:test');
const assert=require('node:assert/strict');
const {context,locals,candidates,insertion}=require('../static/rhema_completion.js');
const metadata={keywords:['synth','when','require'],functions:[
    {name:'bool_var',arity:1},{name:'bool_not',arity:1},{name:'bool_and',arity:2},{name:'formula_add',arity:2}]};

test('bool_ filters registered functions and keeps replacement bounds',()=>{
    const source='  expr = bool_';
    const current=context(source,source.length);
    assert.equal(current.prefix,'bool_');
    assert.deepEqual(candidates(metadata,source,current).map(x=>x.name),['bool_and','bool_not','bool_var']);
    assert.equal(current.start,9);
});
test('comments and multiline strings do not trigger code completion',()=>{
    for(const source of ['# bool_','prompt "bool_','prompt "line\nbool_','let x = "a\\"bool_'])
        assert.equal(context(source,source.length),null,source);
    const source='# comment\nbool_';
    assert.equal(context(source,source.length)?.prefix,'bool_');
});
test('locals include declared symbols and attributes, not commented declarations',()=>{
    const source='synth expr on E\nrandom p_value = boolean\n# synth fake on E\nE -> "p" { expr = bool_var("p") }';
    const names=locals(source).map(x=>x.name);
    assert.ok(names.includes('expr'));assert.ok(names.includes('E'));assert.ok(names.includes('p_value'));
    assert.ok(!names.includes('fake'));
});
test('child property completion suggests synthesized attributes only',()=>{
    const source='synth expr on E\nlet other = 2\nvalue = $1.ex';
    const current=context(source,source.length);
    assert.ok(current.child);
    assert.deepEqual(candidates(metadata,source,current).map(x=>x.name),['expr']);
});
test('insertion opens parentheses, puts cursor inside and does not duplicate existing ones',()=>{
    assert.deepEqual(insertion({name:'bool_var',arity:1},''),{text:'bool_var()',offset:9});
    assert.deepEqual(insertion({name:'bool_true',arity:0},''),{text:'bool_true()',offset:11});
    assert.equal(insertion({name:'bool_var',arity:1},'("p")').text,'bool_var');
});
test('editing the middle of a name replaces its remaining suffix',()=>{
    const current=context('bool_and',5);
    assert.equal(current.start,0);assert.equal(current.end,8);
});
test('explicit completion works at empty positions and candidate count is bounded',()=>{
    assert.equal(context('',0),null);
    assert.ok(context('',0,true));
    const many={functions:Array.from({length:30},(_,i)=>({name:'bool_'+i,arity:1}))};
    assert.equal(candidates(many,'bool_',context('bool_',5)).length,15);
});
