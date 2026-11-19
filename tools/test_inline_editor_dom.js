/* Dependency-free DOM integration tests. These do not substitute for visual QA. */
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const {codeBefore}=require('../static/rhema_completion.js');

class Text {
    constructor(value){this.textContent=value;this.nodeType=3;}
    cloneNode(){return new Text(this.textContent);}
    splitText(offset){const tail=new Text(this.textContent.slice(offset));this.textContent=this.textContent.slice(0,offset);this.parentNode.insertBefore(tail,this.parentNode.childNodes[this.parentNode.childNodes.indexOf(this)+1]);return tail;}
}
class Element {
    constructor(){this.childNodes=[];this.listeners={};this.attributes={};this.value='';this.checked=false;this.hidden=false;this.readOnly=false;this.disabled=false;this.selectionStart=0;this.selectionEnd=0;this.style={};this.dataset={};}
    get textContent(){return this.childNodes.map(node=>node.textContent).join('');}
    set textContent(value){this.replaceChildren(new Text(value));}
    replaceChildren(...nodes){this.childNodes=[];nodes.forEach(n=>this.append(n));}
    append(node){node.parentNode=this;this.childNodes.push(node);}
    insertBefore(node,before){node.parentNode=this;const index=this.childNodes.indexOf(before);this.childNodes.splice(index<0?this.childNodes.length:index,0,node);}
    cloneNode(){const node=new Element();node.className=this.className;node.replaceChildren(...this.childNodes.map(n=>n.cloneNode(true)));return node;}
    addEventListener(name,fn){(this.listeners[name]??=[]).push(fn);}
    async emit(name,event={}){for(const fn of this.listeners[name]||[])await fn(event);}
    dispatchEvent(event){for(const fn of this.listeners[event.type]||[])fn(event);}
    setRangeText(text,start,end){this.value=this.value.slice(0,start)+text+this.value.slice(end);this.selectionStart=this.selectionEnd=start+text.length;}
    getClientRects(){return this.visible===false?[]:[{}];}
    querySelector(){return new Element();}
}
function setup(){
    const elements=new Map(),events={},windowEvents={},calls=[],timers=new Map();let next=1,consent=true;
    const get=id=>{if(!elements.has(id))elements.set(id,new Element());return elements.get(id);};
    const editor=get('rhemaGrammarText'),highlight=get('rhemaHighlight');
    get('rhemaCompletionMenu').hidden=true;get('rhemaGrammarSelect').value='demo.rhm';
    const document={body:new Element(),activeElement:null,getElementById:get,createElement:()=>new Element(),
        createTreeWalker(root){const nodes=[];function visit(e){if(e.nodeType===3)nodes.push(e);else e.childNodes.forEach(visit);}visit(root);let i=0;return{nextNode:()=>nodes[i++]||null};},
        addEventListener(name,fn){(events[name]??=[]).push(fn);},
        dispatchEvent(event){for(const fn of events[event.type]||[])fn(event);}};
    editor.focus=()=>document.activeElement=editor;
    editor.addEventListener('input',()=>highlight.textContent=editor.value);
    const window={RhemaCompletion:{codeBefore},addEventListener(name,fn){(windowEvents[name]??=[]).push(fn);},showApiKeyModal(){window.modalOpened=true;}};
    const context=vm.createContext({window,document,NodeFilter:{SHOW_TEXT:4},MutationObserver:class{observe(){}},AbortController,
        Event:class{constructor(type){this.type=type;}},CustomEvent:class{constructor(type,options){this.type=type;this.detail=options.detail;}},
        confirm:()=>consent,setTimeout:fn=>{const id=next++;timers.set(id,fn);return id;},clearTimeout:id=>timers.delete(id),
        fetch:async(url,options)=>{
            calls.push({url,options});
            if(url==='/api_key_status')return {json:async()=>({verified:true,available:true})};
            return {ok:true,json:async()=>({success:true,completion:'$1.expr, $3.expr)'})};
        }});
    vm.runInContext(fs.readFileSync(path.join(__dirname,'../static/rhema_inline_completion.js'),'utf8'),context);
    for(const fn of events.DOMContentLoaded)fn();
    const settle=async()=>{for(let i=0;i<8;i++)await Promise.resolve();};
    return {get,editor,document,calls,window,settle,async enable(){await settle();get('rhemaAiEnabled').checked=true;await get('rhemaAiEnabled').emit('change');},
        decline(){consent=false;},async type(value){editor.focus();editor.value=value;editor.selectionStart=editor.selectionEnd=value.length;await editor.emit('input');},
        async flush(){const pending=Array.from(timers.values());timers.clear();for(const fn of pending)fn();await settle();},
        async key(key){const event={target:editor,key,preventDefault(){this.prevented=true;},stopImmediatePropagation(){this.stopped=true;}};for(const fn of windowEvents.keydown||[])fn(event);await settle();return event;},
        event(name,detail){document.dispatchEvent({type:name,detail});}};
}

test('AI starts off and typing does not contact the provider',async()=>{
    const env=setup();await env.type('expr = bool_and(');await env.flush();
    assert.equal(env.calls.filter(c=>c.url==='/api/rhema/complete').length,0);
    assert.equal(env.get('rhemaGhost').hidden,true);
});
test('declining disclosure never enables paid requests',async()=>{
    const env=setup();env.decline();await env.enable();await env.type('expr = bool_and(');await env.flush();
    assert.equal(env.get('rhemaAiEnabled').checked,false);
    assert.equal(env.calls.filter(c=>c.url==='/api/rhema/complete').length,0);
});
test('gray candidate does not modify source; Tab inserts it and emits input',async()=>{
    const env=setup();await env.enable();await env.type('expr = bool_and(');await env.flush();
    assert.equal(env.editor.value,'expr = bool_and(');
    assert.equal(env.get('rhemaGhost').hidden,false);
    assert.equal(env.get('rhemaGhost').textContent,'expr = bool_and($1.expr, $3.expr)');
    const call=env.calls.find(c=>c.url==='/api/rhema/complete');
    assert.equal(call.options.headers['X-Rhema-Request'],'1');
    const event=await env.key('Tab');assert.equal(event.prevented,true);
    assert.equal(env.editor.value,'expr = bool_and($1.expr, $3.expr)');
    assert.equal(env.get('rhemaHighlight').textContent,env.editor.value);
});
test('Escape discards the suggestion without changing source',async()=>{
    const env=setup();await env.enable();await env.type('expr = bool_and(');await env.flush();await env.key('Escape');
    assert.equal(env.editor.value,'expr = bool_and(');assert.equal(env.get('rhemaGhost').hidden,true);
});
test('local popup keeps Tab priority over AI',async()=>{
    const env=setup();await env.enable();await env.type('expr = bool_and(');await env.flush();
    env.get('rhemaCompletionMenu').hidden=false;
    const event=await env.key('Tab');assert.equal(event.prevented,undefined);
    assert.equal(env.editor.value,'expr = bool_and(');
});
test('read-only sources, comments and strings never request suggestions',async()=>{
    const env=setup();await env.enable();
    env.editor.readOnly=true;await env.type('expr = bool_and(');await env.flush();env.editor.readOnly=false;
    for(const text of ['# bool_and(', 'prompt "bool_and(']){await env.type(text);await env.flush();}
    assert.equal(env.calls.filter(c=>c.url==='/api/rhema/complete').length,0);
});
test('removing a key disables AI and drops any pending candidate',async()=>{
    const env=setup();await env.enable();await env.type('expr = bool_and(');await env.flush();
    env.event('rhema:api-key-status',{verified:false,available:false});
    assert.equal(env.get('rhemaAiEnabled').checked,false);assert.equal(env.get('rhemaGhost').hidden,true);
    assert.equal(env.editor.value,'expr = bool_and(');
});
