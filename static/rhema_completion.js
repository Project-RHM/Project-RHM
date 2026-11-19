/* Completion data comes from the OCaml checker, not a second builtin list. */
(() => {
    function codeBefore(source, caret) {
        caret=Math.max(0,Math.min(caret,source.length));
        let quoted=false, comment=false, result='';
        for(let i=0;i<caret;i++) {
            const c=source[i];
            if(comment) { if(c==='\n')comment=false; result+=c==='\n'?'\n':' '; continue; }
            if(quoted) {
                if(c==='\\'&&(source[i+1]==='"'||source[i+1]==='\\')) {result+='  ';i++;continue;}
                if(c==='"')quoted=false;
                result+=c==='\n'?'\n':' ';continue;
            }
            if(c==='#') {comment=true;result+=' ';}
            else if(c==='"') {quoted=true;result+=' ';}
            else result+=c;
        }
        return {code:result,blocked:quoted||comment};
    }
    function context(source, caret, explicit=false) {
        caret=Math.max(0,Math.min(caret,source.length));
        const before=codeBefore(source,caret);
        if(before.blocked)return null;
        const child=before.code.match(/\$\d+\.([A-Za-z_][A-Za-z0-9_]*)?$/);
        const word=before.code.match(/[A-Za-z_][A-Za-z0-9_]*$/);
        const prefix=child?(child[1]||''):(word?.[0]||'');
        if(!explicit&&!child&&prefix.length<2)return null;
        if(!prefix&&!explicit&&!child)return null;
        const suffix=source.slice(caret).match(/^[A-Za-z0-9_]*/)[0];
        return {prefix,start:caret-prefix.length,end:caret+suffix.length,child:Boolean(child)};
    }
    function locals(source) {
        const code=codeBefore(source,source.length).code, result=[];
        for(const match of code.matchAll(/\b(random|let|attribute|synth|start)\s+([A-Za-z_][A-Za-z0-9_]*)/g))
            result.push({name:match[2],kind:match[1]==='synth'?'attribute':'local'});
        for(const match of code.matchAll(/\b([A-Za-z_][A-Za-z0-9_]*)\s*->/g))
            result.push({name:match[1],kind:'symbol'});
        return result;
    }
    function candidates(metadata, source, current) {
        if(!current)return [];
        const entries=current.child?locals(source).filter(x=>x.kind==='attribute'):[
            ...(metadata.functions||[]),...(metadata.keywords||[]).map(name=>({name,kind:'keyword'})),...locals(source)];
        const seen=new Set();
        return entries.filter(x=>/^[A-Za-z_][A-Za-z0-9_]*$/.test(x.name)&&
            x.name.startsWith(current.prefix)&&!seen.has(x.name)&&seen.add(x.name))
            .sort((a,b)=>a.name.localeCompare(b.name)).slice(0,15);
    }
    function insertion(item, following) {
        if(Number.isInteger(item.arity)&&!following.startsWith('('))
            return {text:item.name+'()',offset:item.name.length+(item.arity?1:2)};
        return {text:item.name,offset:item.name.length};
    }
    const api={codeBefore,context,locals,candidates,insertion};
    if(typeof module!=='undefined'&&module.exports)module.exports=api;
    if(typeof document==='undefined')return;
    window.RhemaCompletion=api;
    document.addEventListener('DOMContentLoaded',()=>{
        const editor=document.getElementById('rhemaGrammarText');
        if(!editor)return;
        const menu=document.createElement('div');menu.id='rhemaCompletionMenu';
        menu.className='rhema-completion-menu';menu.setAttribute('role','listbox');
        menu.setAttribute('aria-label','Rhema completions');menu.dataset.noTranslate='';menu.hidden=true;
        document.body.append(menu);
        editor.setAttribute('aria-autocomplete','list');editor.setAttribute('aria-controls',menu.id);
        let metadata={functions:[],keywords:[]}, choices=[], current=null, selected=0, composing=false;
        function hide() {
            menu.hidden=true;editor.setAttribute('aria-expanded','false');
            editor.removeAttribute('aria-activedescendant');choices=[];current=null;
        }
        function position() {
            const mirror=document.createElement('div'),style=getComputedStyle(editor);
            for(const key of ['font','fontVariantLigatures','letterSpacing','lineHeight','padding','border','boxSizing','tabSize'])
                mirror.style[key]=style[key];
            Object.assign(mirror.style,{position:'fixed',left:'-10000px',top:'0',whiteSpace:'pre',visibility:'hidden'});
            mirror.textContent=editor.value.slice(0,editor.selectionStart);
            const marker=document.createElement('span');marker.textContent='|';mirror.append(marker);document.body.append(mirror);
            const rect=editor.getBoundingClientRect();
            let x=rect.left+marker.offsetLeft-editor.scrollLeft;
            let y=rect.top+marker.offsetTop-editor.scrollTop+(parseFloat(style.lineHeight)||21);
            mirror.remove();
            const width=Math.min(420,innerWidth-20);menu.style.width=width+'px';
            menu.style.left=Math.max(8,Math.min(x,innerWidth-width-8))+'px';
            menu.style.top=Math.max(8,Math.min(y,innerHeight-menu.offsetHeight-8))+'px';
        }
        function render() {
            menu.replaceChildren();
            choices.forEach((item,index)=>{
                const option=document.createElement('div');option.id='rhemaCompletion'+index;
                option.setAttribute('role','option');option.setAttribute('aria-selected',String(index===selected));
                const name=document.createElement('strong');name.textContent=item.name;
                const detail=document.createElement('span');
                detail.textContent=Number.isInteger(item.arity)?item.arity+' argument'+(item.arity===1?'':'s'):item.kind;
                option.append(name,detail);option.addEventListener('pointerdown',event=>{event.preventDefault();selected=index;accept();});
                menu.append(option);
            });
            menu.hidden=false;editor.setAttribute('aria-expanded','true');
            editor.setAttribute('aria-activedescendant','rhemaCompletion'+selected);
            position();menu.children[selected]?.scrollIntoView({block:'nearest'});
        }
        function show(explicit=false) {
            if(composing||editor.readOnly||editor.disabled||document.activeElement!==editor){hide();return;}
            current=context(editor.value,editor.selectionStart,explicit);
            choices=candidates(metadata,editor.value,current);selected=0;
            if(!choices.length){hide();return;}render();
        }
        function accept() {
            if(!current||!choices[selected])return;
            const place=current.start, item=insertion(choices[selected],editor.value.slice(current.end));
            editor.setRangeText(item.text,current.start,current.end,'end');
            editor.setSelectionRange(place+item.offset,place+item.offset);hide();
            editor.dispatchEvent(new Event('input',{bubbles:true}));
        }
        editor.addEventListener('input',()=>show());
        editor.addEventListener('compositionstart',()=>{composing=true;hide();});
        editor.addEventListener('compositionend',()=>{composing=false;show();});
        editor.addEventListener('keydown',event=>{
            if((event.ctrlKey||event.metaKey)&&event.code==='Space') {
                event.preventDefault();event.stopImmediatePropagation();show(true);return;
            }
            if(menu.hidden)return;
            if(['ArrowDown','ArrowUp','Enter','Tab','Escape'].includes(event.key)) {
                event.preventDefault();event.stopImmediatePropagation();
                if(event.key==='Escape'){hide();return;}
                if(event.key==='Enter'||event.key==='Tab'){accept();return;}
                selected=(selected+(event.key==='ArrowDown'?1:-1)+choices.length)%choices.length;render();
            } else if(event.ctrlKey||event.metaKey)hide();
        },true);
        editor.addEventListener('blur',hide);editor.addEventListener('click',hide);
        document.addEventListener('scroll',event=>{if(!menu.contains(event.target))hide();},true);
        window.addEventListener('resize',hide);
        new MutationObserver(()=>{if(editor.readOnly)hide();}).observe(editor,{attributes:true,attributeFilter:['readonly']});
        fetch('/teacher/completions').then(r=>{if(!r.ok)throw new Error('Completion data unavailable');return r.json();})
            .then(data=>{metadata=data;document.dispatchEvent(new CustomEvent('rhema:language-data',{detail:data}));})
            .catch(()=>{hide();});
    });
})();
