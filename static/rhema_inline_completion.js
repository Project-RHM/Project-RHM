/* AI suggestions are preview-only until Tab; credentials never reach this module. */
(() => {
    function payload(source, caret) {
        return {consent:true,prefix:source.slice(Math.max(0,caret-6000),caret),suffix:source.slice(caret,caret+2000),
            declarations:source.split('\n').filter(line=>/^\s*(attribute|random|let|synth|start|context|precedence)\b/.test(line)).join('\n').slice(0,2000)};
    }
    const same=(a,b)=>Boolean(a&&b&&a.source===b.source&&a.caret===b.caret&&a.file===b.file);
    class InlineRequest {
        constructor(request, current, changed, failed) {
            this.request=request;this.current=current;this.changed=changed;this.failed=failed;this.version=0;this.candidate=null;
        }
        invalidate() {
            this.version++;this.controller?.abort();this.controller=null;this.candidate=null;this.changed(null);
        }
        async complete(snapshot) {
            this.invalidate();const version=this.version;this.controller=new AbortController();
            try {
                const text=await this.request(payload(snapshot.source,snapshot.caret),this.controller.signal);
                if(version!==this.version||!same(snapshot,this.current()))return;
                if(typeof text==='string'&&text&&text.length<=300&&!/[\r\n\x00]/.test(text)) {
                    this.candidate={...snapshot,text};this.changed(this.candidate);
                }else this.changed(null);
            }catch(error){if(version===this.version&&error.name!=='AbortError')this.failed(error);}
        }
        take(snapshot) {
            const text=same(this.candidate,snapshot)?this.candidate.text:null;
            this.invalidate();return text;
        }
    }
    const api={payload,same,InlineRequest};
    if(typeof module!=='undefined'&&module.exports)module.exports=api;
    if(typeof document==='undefined')return;
    document.addEventListener('DOMContentLoaded',()=>{
        const byId=id=>document.getElementById(id),editor=byId('rhemaGrammarText');
        if(!editor)return;
        const toggle=byId('rhemaAiEnabled'),status=byId('rhemaAiStatus'),ghost=byId('rhemaGhost'),highlight=byId('rhemaHighlight');
        let enabled=false,credentials={verified:false,available:false},timer=null,composing=false;
        const localMenuOpen=()=>{const menu=byId('rhemaCompletionMenu');return menu&&!menu.hidden;};
        const writable=()=>!editor.readOnly&&!editor.disabled&&editor.getClientRects().length>0&&editor.selectionStart===editor.selectionEnd;
        const snapshot=()=>({source:editor.value,caret:editor.selectionStart,file:byId('rhemaGrammarSelect').value});
        const setStatus=value=>{status.textContent=value;};
        function syncScroll(){ghost.scrollTop=editor.scrollTop;ghost.scrollLeft=editor.scrollLeft;}
        function render(candidate) {
            ghost.hidden=true;ghost.replaceChildren();
            if(!candidate){setStatus(enabled?'AI ready':'AI off');return;}
            if(!enabled||!writable()||document.activeElement!==editor||localMenuOpen())return;
            ghost.replaceChildren(...Array.from(highlight.childNodes,node=>node.cloneNode(true)));
            const walker=document.createTreeWalker(ghost,NodeFilter.SHOW_TEXT);
            let remaining=candidate.caret,node;
            while((node=walker.nextNode())) {
                if(remaining<=node.textContent.length){
                    const tail=node.splitText(remaining),insert=document.createElement('span');
                    insert.className='rhema-ghost-insertion';insert.textContent=candidate.text;
                    tail.parentNode.insertBefore(insert,tail);break;
                }
                remaining-=node.textContent.length;
            }
            if(!node){const insert=document.createElement('span');insert.className='rhema-ghost-insertion';insert.textContent=candidate.text;ghost.append(insert);}
            ghost.hidden=false;syncScroll();setStatus('Suggestion available');
        }
        function cancel(){clearTimeout(timer);timer=null;session.invalidate();}
        function disable(message){enabled=false;toggle.checked=false;cancel();setStatus(message||'AI off');}
        const session=new InlineRequest(async(body,signal)=>{
            setStatus('Requesting suggestion...');
            const response=await fetch('/api/rhema/complete',{method:'POST',headers:{'Content-Type':'application/json','X-Rhema-Request':'1'},body:JSON.stringify(body),signal});
            const data=await response.json();
            if(!response.ok||!data.success){const error=new Error(data.error||'AI completion unavailable.');error.code=data.code;throw error;}
            return data.completion;
        },snapshot,render,error=>{
            if(error.code==='completion_busy'){setStatus('AI ready');return;}
            disable(error.message||'AI completion unavailable.');
        });
        function schedule() {
            cancel();
            if(!enabled||composing||!writable()||document.activeElement!==editor||localMenuOpen())return;
            if(window.RhemaCompletion?.codeBefore(editor.value,editor.selectionStart).blocked)return;
            if(!editor.value.slice(0,editor.selectionStart).trim())return;
            timer=setTimeout(()=>{
                if(enabled&&writable()&&document.activeElement===editor&&!localMenuOpen())session.complete(snapshot());
            },1000);
        }
        toggle.addEventListener('change',()=>{
            if(!toggle.checked){disable();return;}
            if(!credentials.verified||!credentials.available){disable('Import and validate a key first.');window.showApiKeyModal();return;}
            if(!confirm('Enable AI completion for this session? Code near the cursor and selected declarations will be sent to DeepSeek with the Rhema guide. API charges apply. Do not include credentials or personal data in the source.')){disable();return;}
            enabled=true;setStatus('AI ready');editor.focus();
        });
        byId('rhemaAiSettingsBtn').addEventListener('click',()=>window.showApiKeyModal());
        document.addEventListener('rhema:api-key-status',event=>{
            credentials=event.detail;cancel();if(!credentials.verified||!credentials.available)disable();
        });
        fetch('/api_key_status',{cache:'no-store'}).then(r=>r.json()).then(data=>{credentials=data;}).catch(()=>{});
        editor.addEventListener('input',schedule);
        editor.addEventListener('compositionstart',()=>{composing=true;cancel();});
        editor.addEventListener('compositionend',()=>{composing=false;schedule();});
        editor.addEventListener('blur',cancel);editor.addEventListener('click',cancel);editor.addEventListener('scroll',syncScroll);
        window.addEventListener('keydown',event=>{
            if(event.target!==editor)return;
            if(event.key==='Tab'&&!event.shiftKey&&enabled&&session.candidate&&!localMenuOpen()) {
                const current=snapshot(),text=session.take(current);
                if(text&&writable()){
                    event.preventDefault();event.stopImmediatePropagation();
                    editor.setRangeText(text,current.caret,current.caret,'end');
                    editor.dispatchEvent(new Event('input',{bubbles:true}));
                }
            }else if(event.key==='Escape')cancel();
            else if(!['Shift','Control','Alt','Meta'].includes(event.key))cancel();
        },true);
        byId('rhemaGrammarSelect').addEventListener('change',cancel);
        document.addEventListener('selectionchange',()=>{
            if(session.candidate&&!same(session.candidate,snapshot()))cancel();
        });
        new MutationObserver(()=>{if(!writable()||(session.candidate&&!same(session.candidate,snapshot())))cancel();})
            .observe(editor,{attributes:true,attributeFilter:['readonly','disabled']});
        new MutationObserver(()=>{if(session.candidate&&!same(session.candidate,snapshot()))cancel();})
            .observe(highlight,{childList:true,subtree:true});
        new MutationObserver(()=>{if(!editor.getClientRects().length)cancel();})
            .observe(document.body,{attributes:true,attributeFilter:['class']});
        const menu=byId('rhemaCompletionMenu');
        if(menu)new MutationObserver(()=>{if(!menu.hidden)cancel();}).observe(menu,{attributes:true,attributeFilter:['hidden']});
    });
})();
