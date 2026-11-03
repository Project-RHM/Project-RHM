/* Dependency-free DOM unit tests; no browser, network, credentials or file uploads. */
const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const {webcrypto} = require('node:crypto');

class Element {
    constructor() {
        this.value = ''; this.hidden = false; this.srcdoc = ''; this.dataset = {};
        this.textContent = ''; this.listeners = {}; this.attributes = {}; this.children = [];
        this.label = {textContent:''}; this.classList = {add(){},remove(){}};
    }
    addEventListener(name, action) { (this.listeners[name] ||= []).push(action); }
    async emit(name, event = {}) {
        for (const action of this.listeners[name] || []) await action(event);
    }
    querySelector() { return this.label; }
    replaceChildren(...children) { this.children = children; }
    setAttribute(key, value) { this.attributes[key] = value; }
    removeAttribute(key) { delete this.attributes[key]; if(key === 'srcdoc') this.srcdoc = ''; }
    contains() { return false; }
    append(child) { this.children.push(child); }
    checkValidity() { return Number.isInteger(Number(this.value)) && Number(this.value) >= 1 && Number(this.value) <= 2147483647; }
    reportValidity() {}
    click() {}
}

function setup(importer = false) {
    const elements = new Map(), documentEvents = {}, windowEvents = {}, calls = [];
    const element = id => {
        if (!elements.has(id)) elements.set(id, new Element());
        return elements.get(id);
    };
    const document = {
        getElementById:element,
        createElement:() => new Element(),
        addEventListener(name, action) { (documentEvents[name] ||= []).push(action); }
    };
    const window = {addEventListener(name, action) { (windowEvents[name] ||= []).push(action); }};
    const emit = message => { for (const action of windowEvents.message || []) action(message); };
    for (const prefix of ['generated','history','import']) {
        const frame = element(prefix + 'RenderedFrame');
        frame.contentWindow = {postMessage(message) {
            emit({source:frame.contentWindow, data:{...message, type:'answers', answers:{AnSwEr0001:'2'}}});
        }};
    }
    element('pgImportSeed').value = '1';
    element('pgImportContent').dataset.maxSourceBytes = '262144';
    class DOMParser {
        parseFromString() { return {querySelectorAll:()=>[],createElement:()=>new Element(),body:new Element(),documentElement:{outerHTML:'<html>rendered</html>'}}; }
    }
    const context = vm.createContext({window, document, DOMParser, URL, crypto:webcrypto,
        TextDecoder, TextEncoder, setTimeout, clearTimeout,
        fetch:async(url, options) => {
            calls.push({url, data:JSON.parse(options.body)});
            return {ok:true, json:async()=>url.endsWith('/check')
                ? {success:true,score:1,correct_count:1,answer_count:1,answers:[{correct:true,score:1,feedback:''}]}
                : {success:true,html:'<html>rendered</html>'}};
        }});
    vm.runInContext(fs.readFileSync(path.join(__dirname,'../static/webwork_preview.js'),'utf8'), context);
    context.fetchRenderedPg = window.fetchRenderedPg;
    if (importer) {
        vm.runInContext(fs.readFileSync(path.join(__dirname,'../static/pg_import.js'),'utf8'),context);
        for (const action of documentEvents.DOMContentLoaded || []) action();
    }
    return {context, element, calls, emit,
        state:area=>vm.runInContext(`webworkPreviews[${JSON.stringify(area)}]`, context)};
}

const SOURCE = 'DOCUMENT();\nBEGIN_PGML\nQuestion [_____]{2}\nEND_PGML\nENDDOCUMENT();';
function file(name='test.pg', text=SOURCE) {
    const data = new TextEncoder().encode(text);
    return {name, size:data.length, arrayBuffer:async()=>data.buffer};
}
async function choose(env, files) {
    env.element('pgImportFile').files = files;
    await env.element('pgImportFile').emit('change');
}

test('render cache separates source and PG seed; force refresh preserves other entries', async()=>{
    const {context,calls} = setup();
    await context.fetchRenderedPg(SOURCE,false,1);
    await context.fetchRenderedPg(SOURCE,false,1);
    await context.fetchRenderedPg(SOURCE,false,2);
    assert.equal(calls.length,2);
    assert.equal(calls[1].data.problem_seed,2);
    await context.fetchRenderedPg(SOURCE,true,1);
    assert.equal(calls.length,3);
    await context.fetchRenderedPg(SOURCE,false,2);
    assert.equal(calls.length,3);
});

test('static preview removes incompatible parent messaging scripts without weakening iframe isolation',()=>{
    const {context}=setup();
    const script={getAttribute:()=>'/js/apps/CSSMessage/css-message.f1da4668.min.js',remove(){this.removed=true;}};
    context.DOMParser=class {
        parseFromString(){return {baseURI:'http://renderer.test/',querySelectorAll:()=>[script],
            createElement:()=>new Element(),body:new Element(),documentElement:{outerHTML:'<html>safe</html>'}};}
    };
    context.staticPreviewDocument('<html></html>','token');
    assert.equal(script.removed,true);
});

test('PG render and answer checking use exactly the same source and seed', async()=>{
    const env=setup();
    env.element('pgImportSource').value=SOURCE;
    env.element('pgImportSeed').value='47';
    await env.context.renderProblemPreview('import');
    assert.equal(env.element('importRenderedStatus').textContent,'Rendered by WeBWorK');
    const frame=env.element('importRenderedFrame'), state=env.state('import');
    env.emit({source:frame.contentWindow,data:{channel:'rhema-answer-check',token:state.token,type:'ready',answerCount:1}});
    assert.equal(env.element('importCheckAnswers').disabled,false);
    await env.context.checkPreviewAnswers('import');
    const [render, check] = env.calls;
    assert.equal(render.data.problem_seed,47);
    assert.equal(check.data.problem_seed,47);
    assert.equal(check.data.pg_source,render.data.pg_source);
    assert.equal(env.element('importAnswerFeedback').hidden,false);
});

test('seed changes clear iframe and grades, and reject stale iframe messages', async()=>{
    const env=setup();env.element('pgImportSource').value=SOURCE;
    await env.context.renderProblemPreview('import');
    const oldToken=env.state('import').token;
    env.element('importAnswerFeedback').hidden=false;
    env.element('pgImportSeed').value='2';
    await env.element('pgImportSeed').emit('input');
    const frame=env.element('importRenderedFrame');
    assert.equal(frame.hidden,true);assert.equal(frame.srcdoc,'');
    assert.equal(env.element('importAnswerFeedback').hidden,true);
    env.emit({source:frame.contentWindow,data:{channel:'rhema-answer-check',token:oldToken,type:'ready',answerCount:1}});
    assert.equal(env.state('import').ready,false);
    await env.context.checkPreviewAnswers('import');
    assert.equal(env.calls.length,1);
});

test('a stale render response cannot replace a newer file', async()=>{
    const env=setup();env.element('pgImportSource').value=SOURCE;
    let finish;
    env.context.window.fetchRenderedPg=()=>new Promise(resolve=>{finish=resolve;});
    const pending=env.context.renderProblemPreview('import');
    env.element('pgImportSource').value=SOURCE+'\n# second';
    await env.element('pgImportSource').emit('input');
    finish('<html>old</html>');await pending;
    assert.equal(env.element('importRenderedFrame').srcdoc,'');
    assert.equal(env.state('import').ready,false);
});

test('invalid seeds never contact renderer', async()=>{
    const env=setup();env.element('pgImportSource').value=SOURCE;
    for(const seed of ['','0','-1','1.5','2147483648']) {
        env.element('pgImportSeed').value=seed;
        await env.context.renderProblemPreview('import');
        assert.equal(env.element('importRenderedStatus').className,'rendered-preview-status error');
    }
    assert.equal(env.calls.length,0);
});

test('no answer fields leaves checking disabled; original areas still default to seed 1', async()=>{
    const env=setup();env.element('output').value=SOURCE;
    await env.context.renderProblemPreview('generate');
    assert.equal(env.calls[0].data.problem_seed,1);
    const frame=env.element('generatedRenderedFrame');
    env.emit({source:frame.contentWindow,data:{channel:'rhema-answer-check',token:env.state('generate').token,type:'ready',answerCount:0}});
    assert.equal(env.element('generatedCheckAnswers').disabled,true);
    assert.match(env.element('generatedRenderedStatus').textContent,/No answer fields/);
    env.element('historyOutput').value=SOURCE;
    await env.context.renderProblemPreview('history');
    assert.equal(env.state('history').seed,1);
});

test('loading UTF-8 PG is read-only and does not render until requested', async()=>{
    const env=setup(true);
    await choose(env,[file('question.pg','\uFEFF'+SOURCE)]);
    assert.equal(env.element('pgImportSource').value,SOURCE);
    assert.equal(env.element('pgImportFilename').textContent,'question.pg');
    assert.equal(env.element('pgImportRender').disabled,false);
    assert.equal(env.calls.length,0);
    await env.element('pgImportRender').emit('click');
    assert.equal(env.calls.length,1);
});

test('invalid files clear old preview and do not contact renderer', async()=>{
    const env=setup(true);
    const badFiles = [[file('a.txt')],[file('a.pg','')],[file('a.pg','  ')],
        [file('a.pg','bad PG')],[file('a.pg',SOURCE+'\0')],
        [{...file(),size:262145}],[file(),file('b.pg')],
        [{name:'binary.pg',size:1,arrayBuffer:async()=>new Uint8Array([255]).buffer}]];
    for(const files of badFiles) {
        await choose(env,[file()]);
        await choose(env,files);
        assert.equal(env.element('pgImportSource').value,'');
        assert.equal(env.element('pgImportMessage').hidden,false);
        assert.equal(env.element('pgImportRender').disabled,true);
        assert.equal(env.element('importRenderedFrame').srcdoc,'');
    }
    assert.equal(env.calls.length,0);
});

test('a delayed file read cannot undo Clear or replace the latest file', async()=>{
    const env=setup(true);let finish;
    const delayed={...file(),arrayBuffer:()=>new Promise(resolve=>{finish=resolve;})};
    const pending=choose(env,[delayed]);
    await env.element('pgImportClear').emit('click');
    await choose(env,[file('latest.pg')]);
    finish(new TextEncoder().encode(SOURCE+'\n# old').buffer);
    await pending;
    assert.equal(env.element('pgImportFilename').textContent,'latest.pg');
    assert.equal(env.element('pgImportSource').value,SOURCE);
});

test('clear removes imported data, grades and resets seed', async()=>{
    const env=setup(true);await choose(env,[file()]);
    env.element('pgImportSeed').value='19';
    await env.element('pgImportClear').emit('click');
    assert.equal(env.element('pgImportSource').value,'');
    assert.equal(env.element('pgImportSeed').value,'1');
    assert.equal(env.element('pgImportRender').disabled,true);
    assert.equal(env.element('pgImportClear').disabled,true);
    assert.equal(env.element('importAnswerFeedback').hidden,true);
});
