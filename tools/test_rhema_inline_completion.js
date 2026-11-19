const test=require('node:test');
const assert=require('node:assert/strict');
const {payload,same,InlineRequest}=require('../static/rhema_inline_completion.js');
const original={source:'expr = bool_and(',caret:16,file:'demo.rhm'};

function fixture(request){
    let current={...original};const shown=[],errors=[];
    const state=new InlineRequest(request,()=>current,value=>shown.push(value),error=>errors.push(error));
    return {state,shown,errors,set:value=>{current=value;}};
}

test('context is bounded and includes only selected source declarations',()=>{
    const source='attribute cost = 3 split\nsynth expr on E\n'+'x'.repeat(9000);
    const context=payload(source,source.length-3);
    assert.equal(context.prefix.length,6000);assert.equal(context.suffix,'xxx');
    assert.match(context.declarations,/synth expr/);assert.equal(context.consent,true);
    assert.deepEqual(Object.keys(context).sort(),['consent','declarations','prefix','suffix']);
});
test('candidate is preview only, accepted once for the same source and caret',async()=>{
    const {state,shown}=fixture(async()=>'$1.expr, $3.expr)');
    await state.complete(original);
    assert.equal(original.source,'expr = bool_and(');
    assert.equal(shown.at(-1).text,'$1.expr, $3.expr)');
    assert.equal(state.take(original),'$1.expr, $3.expr)');assert.equal(state.take(original),null);
});
test('a delayed result cannot replace newly edited source',async()=>{
    let resolve;const {state,set}=fixture(()=>new Promise(r=>resolve=r));
    const pending=state.complete(original);set({...original,source:'changed'});resolve('old');await pending;
    assert.equal(state.candidate,null);
});
test('file and caret changes reject delayed suggestions',async()=>{
    for(const change of [{file:'other.rhm'},{caret:3}]){
        let resolve;const {state,set}=fixture(()=>new Promise(r=>resolve=r));
        const pending=state.complete(original);set({...original,...change});resolve('old');await pending;
        assert.equal(state.candidate,null);
    }
});
test('Escape or disabling cancels requests and ignores their results',async()=>{
    let resolve,signal;const {state}=fixture((_,s)=>{signal=s;return new Promise(r=>resolve=r);});
    const pending=state.complete(original);state.invalidate();assert.equal(signal.aborted,true);
    resolve('old');await pending;assert.equal(state.candidate,null);
});
test('new requests supersede earlier ones',async()=>{
    const resolves=[];const {state}=fixture(()=>new Promise(r=>resolves.push(r)));
    const first=state.complete(original),second=state.complete(original);
    resolves[1]('new');await second;resolves[0]('old');await first;
    assert.equal(state.candidate.text,'new');
});
test('multi-line, oversized and missing suggestions are not inserted',async()=>{
    for(const value of ['one\ntwo','x'.repeat(301),null,'']){
        const {state}=fixture(async()=>value);await state.complete(original);assert.equal(state.candidate,null);
    }
});
test('network errors are reported without modifying the source',async()=>{
    const {state,errors}=fixture(async()=>{throw new Error('Offline');});
    await state.complete(original);assert.equal(errors[0].message,'Offline');assert.equal(state.candidate,null);
    assert.equal(same(original,{...original}),true);assert.equal(same(null,original),false);
});
