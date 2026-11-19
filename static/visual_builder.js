/* The browser edits a typed definition; only the existing Rhema runtime does mathematics. */
(() => {
    const clone = value => structuredClone(value);
    const compatibleType = (actual,expected) => actual===expected || (actual==='FiniteSet'&&expected==='Set');
    function symbolsBefore(spec, operations, index=spec.steps.length) {
        const symbols = spec.parameters.map(p => ({name:p.name, type:p.kind==='boolean'?'Truth':'Number'}));
        for (const step of spec.steps.slice(0,index)) {
            const operation = operations.find(op=>op.id===step.operation);
            if (operation) symbols.push({name:step.name,type:operation.output});
        }
        return symbols;
    }
    function rename(spec, before, after) {
        if (!/^[A-Za-z][A-Za-z0-9_]{0,31}$/.test(after) || [...spec.parameters,...spec.steps].some(n=>n.name===after && n.name!==before)) return false;
        for(const node of [...spec.parameters,...spec.steps]) {
            if(node.name===before)node.name=after;
            for(const arg of node.arguments||[])if(arg.ref===before)arg.ref=after;
        }
        for(const condition of spec.constraints)if(condition.ref===before)condition.ref=after;
        if(spec.answer===before)spec.answer=after;
        spec.prompt=spec.prompt.replaceAll('{'+before+'}','{'+after+'}');
        return true;
    }
    function isReferenced(spec,name) {
        return spec.answer===name || spec.prompt.includes('{'+name+'}') || spec.constraints.some(c=>c.ref===name)
            || spec.steps.some(s=>s.arguments.some(a=>a.ref===name));
    }
    function defaultArguments(operation, symbols) {
        return operation.arguments.map(field=>{
            if(field.default!==null)return {literal:field.default};
            const candidate=symbols.filter(s=>compatibleType(s.type,field.type)).at(-1);
            return {ref:candidate?.name||''};
        });
    }
    const model = {symbolsBefore,rename,isReferenced,defaultArguments,compatibleType};
    if(typeof module!=='undefined'&&module.exports)module.exports=model;
    if(typeof document==='undefined')return;
    document.addEventListener('DOMContentLoaded',()=>{
        const byId=id=>document.getElementById(id);
        const page=byId('visualBuilderContent');
        let catalog=null, catalogPromise=null, spec=null, revision=null, loadedName='', dirty=false, busy=false, version=0, sourceTimer;
        const noTranslate = node => {node.dataset.noTranslate='';return node;};
        function element(tag,text,className) {
            const node=document.createElement(tag);if(text!==undefined)node.textContent=text;if(className)node.className=className;return node;
        }
        function icons(){window.lucide?.createIcons();}
        function button(label,icon,handler,className='btn btn-secondary') {
            const node=element('button',undefined,className);node.type='button';node.setAttribute('aria-label',label);node.title=label;
            const mark=element('i');mark.dataset.lucide=icon;mark.setAttribute('aria-hidden','true');node.append(mark);
            if(className!=='visual-icon')node.append(element('span',label));node.addEventListener('click',handler);return node;
        }
        function message(text='',kind='error') {
            const box=byId('visualMessage');box.textContent=text;box.hidden=!text;box.dataset.kind=kind;
        }
        function setBusy(value,label) {
            busy=value;
            page.querySelectorAll('input,select,textarea,button').forEach(control=>{control.disabled=value;});
            if(label)byId('visualDraftStatus').textContent=label;
            if(!value){
                updateCheckButton('visual');updateSelectors();
                if(!spec)for(const id of ['visualCheck','visualSave','visualGenerate'])byId(id).disabled=true;
            }
        }
        async function jsonRequest(url,body) {
            const response=await fetch(url,body?{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)}:undefined);
            const data=await response.json();
            if(!response.ok||!data.success){const error=new Error(data.error||'The visual definition could not be processed.');error.status=response.status;throw error;}
            return data;
        }
        async function loadCatalog() {
            if(catalog)return catalog;
            if(!catalogPromise)catalogPromise=jsonRequest('/teacher/visual/catalog').then(data=>{catalog=data;return data;}).catch(error=>{catalogPromise=null;throw error;});
            return catalogPromise;
        }
        function clearPreview() {
            byId('visualPgSource').value='';
            invalidateProblemPreview('visual','Settings changed. Generate again.','stale');
            byId('visualStandardAnswers').hidden=true;byId('visualAnswerList').replaceChildren();
            byId('visualTreeFrame').hidden=true;byId('visualTreeFrame').src='about:blank';byId('visualTreeEmpty').hidden=false;
        }
        function requestData() {
            const name=byId('visualFilename').value.trim();
            return {name,specification:clone(spec),student_id:byId('visualStudent').value.trim(),count:Number(byId('visualCount').value),
                ...(revision&&loadedName===name?{revision}:{})};
        }
        function scheduleSource() {
            clearTimeout(sourceTimer);
            const expected=version;
            sourceTimer=setTimeout(async()=>{
                if(busy||!spec)return;
                try {
                    const data=await jsonRequest('/teacher/visual/source',{specification:clone(spec)});
                    if(expected!==version||busy)return;
                    byId('visualRhemaSource').value=data.source;byId('visualContext').textContent=data.context;
                } catch(error) {
                    if(expected!==version||busy)return;
                    byId('visualRhemaSource').value='';byId('visualContext').textContent='Incomplete definition';
                }
            },300);
        }
        function changed() {
            dirty=true;version++;byId('visualDraftStatus').textContent='Changes not checked';message();
            byId('visualOpenConfigure').hidden=true;byId('visualOpenSource').hidden=true;
            clearPreview();scheduleSource();
        }
        function uniqueName(prefix) {
            const names=new Set([...spec.parameters,...spec.steps].map(x=>x.name));
            let n=1;while(names.has(prefix+n))n++;return prefix+n;
        }
        function field(label,control) {const node=element('label',label);node.append(control);return node;}
        function input(value,label,change,type='text',limits={}) {
            const node=element('input');node.type=type;node.value=value??'';node.setAttribute('aria-label',label);
            Object.assign(node,limits);node.required=true;
            node.addEventListener(type==='number'?'input':'change',()=>change(type==='number'?(node.value===''?null:Number(node.value)):node.value,node));
            return node;
        }
        function select(options,value,label,change) {
            const node=element('select');node.setAttribute('aria-label',label);node.required=true;
            for(const [key,text] of options)node.add(new Option(text,key));
            node.value=String(value??'');
            if(node.selectedIndex<0){const option=new Option('Missing or incompatible value',String(value??''),false,true);node.add(option);}
            node.addEventListener('change',()=>change(node.value));return node;
        }
        function renameNode(node,next,control) {
            if(!rename(spec,node.name,next)){control.value=node.name;message('Use a unique name starting with a letter, with at most 32 letters, numbers or underscores.');return;}
            byId('visualPrompt').value=spec.prompt;changed();renderDefinition();
        }
        function deleteNode(collection,index) {
            const node=collection[index];
            if(isReferenced(spec,node.name)){message('This value is still used. Remove its references, question-text inserts and answer binding first.');return;}
            collection.splice(index,1);changed();renderDefinition();
        }
        function renderParameters() {
            const container=byId('visualParameters');container.replaceChildren();
            if(!spec.parameters.length)container.append(element('p','No random parameters','visual-empty'));
            spec.parameters.forEach((parameter,index)=>{
                const row=element('div',undefined,'visual-parameter');
                row.append(field('Name',input(parameter.name,'Parameter '+(index+1)+' name',(name,control)=>renameNode(parameter,name,control),'text',{maxLength:32})),
                    field('Type',select([['integer','Integer'],['nonzero_integer','Nonzero'],['boolean','Boolean']],parameter.kind,'Parameter '+parameter.name+' type',kind=>{
                        const previous=parameter.kind;parameter.kind=kind;
                        if(kind==='boolean'){delete parameter.min;delete parameter.max;parameter.mode='random';}
                        else{delete parameter.mode;parameter.min=previous==='boolean'?-5:parameter.min;parameter.max=previous==='boolean'?5:parameter.max;}
                        changed();renderDefinition();
                    })));
                if(parameter.kind==='boolean') {
                    const mode=field('Value',select([['random','Random'],['true','True'],['false','False']],parameter.mode,'Value of '+parameter.name,value=>{parameter.mode=value;changed();}));
                    mode.className='visual-boolean-mode';row.append(mode);
                }else{
                    for(const [part,label]of [['min','Minimum'],['max','Maximum']])row.append(field(label,input(parameter[part],parameter.name+' '+label,value=>{parameter[part]=value;changed();},'number',{min:-1000,max:1000})));
                }
                row.append(button('Delete parameter '+parameter.name,'trash-2',()=>deleteNode(spec.parameters,index),'visual-icon'));container.append(row);
            });
        }
        function argumentControl(step,index,description,available) {
            const node=element('div',undefined,'visual-argument-control');
            let argument=step.arguments[index];
            const choices=[];
            const literalAllowed=['Number','Truth','Text'].includes(description.type);
            if(literalAllowed)choices.push(['literal','Value']);
            for(const symbol of available.filter(s=>compatibleType(s.type,description.type)))choices.push(['ref:'+symbol.name,symbol.name]);
            if(!choices.length)choices.push(['ref:','Select an earlier '+description.type]);
            const pick=select(choices,argument.ref!==undefined?'ref:'+argument.ref:'literal',step.name+' '+description.name+' input',value=>{
                step.arguments[index]=value==='literal'?{literal:description.default??(description.type==='Text'?'x':description.type==='Truth'?true:1)}:{ref:value.slice(4)};
                changed();renderDefinition();
            });
            node.append(pick);
            if(argument.literal!==undefined) {
                let control;
                if(description.type==='Truth')control=select([['true','True'],['false','False']],String(argument.literal),step.name+' '+description.name+' value',value=>{argument.literal=value==='true';changed();});
                else control=input(argument.literal,step.name+' '+description.name+' value',value=>{argument.literal=value;changed();},description.type==='Number'?'number':'text',description.type==='Number'?{min:-1000,max:1000}:{maxLength:80});
                control.classList.add('visual-literal');node.append(control);
            }
            return field(description.name+' · '+description.type,node);
        }
        function renderSteps() {
            const container=byId('visualSteps');container.replaceChildren();
            if(!spec.steps.length)container.append(element('p','No mathematical steps','visual-empty'));
            spec.steps.forEach((step,index)=>{
                const operation=catalog.operations.find(o=>o.id===step.operation);
                const section=element('section',undefined,'visual-step');section.setAttribute('aria-label','Step '+(index+1));
                const heading=element('div',undefined,'visual-step-head');
                heading.append(element('span',String(index+1),'visual-step-number'),input(step.name,'Step '+(index+1)+' name',(name,control)=>renameNode(step,name,control),'text',{maxLength:32}),element('span',operation.output,'visual-type'),button('Delete step '+step.name,'trash-2',()=>deleteNode(spec.steps,index),'visual-icon'));
                const operationSelect=element('select');operationSelect.className='visual-step-operation';operationSelect.setAttribute('aria-label','Step '+(index+1)+' operation');
                const groups=new Map();
                for(const op of catalog.operations){if(!groups.has(op.group)){const group=element('optgroup');group.label=op.group;groups.set(op.group,group);operationSelect.append(group);}groups.get(op.group).append(new Option(op.label,op.id));}
                operationSelect.value=step.operation;
                operationSelect.title=operation.label;
                operationSelect.addEventListener('change',()=>{
                    const next=catalog.operations.find(o=>o.id===operationSelect.value);
                    const old=step.arguments;step.operation=next.id;step.arguments=defaultArguments(next,symbolsBefore(spec,catalog.operations,index));
                    next.arguments.forEach((arg,i)=>{if(old[i]?.ref && symbolsBefore(spec,catalog.operations,index).some(s=>s.name===old[i].ref&&compatibleType(s.type,arg.type)))step.arguments[i]=old[i];});
                    changed();renderDefinition();
                });
                const argumentsPanel=element('div',undefined,'visual-arguments');
                operation.arguments.forEach((arg,i)=>argumentsPanel.append(argumentControl(step,i,arg,symbolsBefore(spec,catalog.operations,index))));
                section.append(heading,operationSelect,argumentsPanel);container.append(section);
            });
        }
        function populate(selectElement,options,value,placeholder) {
            selectElement.replaceChildren(new Option(placeholder,''));
            for(const symbol of options){const option=new Option(symbol.name+' · '+symbol.type,symbol.name);option.dataset.noTranslate='';selectElement.add(option);}
            selectElement.value=value||'';
            if(value&&selectElement.selectedIndex<0)selectElement.add(new Option('Missing or incompatible: '+value,value,false,true));
        }
        function updateSelectors() {
            if(!spec||!catalog)return;
            const symbols=symbolsBefore(spec,catalog.operations);
            const lastInsert=byId('visualInsertValue').value;
            populate(byId('visualInsertValue'),symbols.filter(s=>catalog.display_types.includes(s.type)),lastInsert,'Select value');
            populate(byId('visualAnswer'),symbols.filter(s=>catalog.answer_types.includes(s.type)),spec.answer,'Select answer');
            byId('visualAddConstraint').disabled=busy||!symbols.some(s=>s.type==='Truth');
        }
        function renderConstraints() {
            const container=byId('visualConstraints');container.replaceChildren();
            const symbols=symbolsBefore(spec,catalog.operations).filter(s=>s.type==='Truth');
            spec.constraints.forEach((constraint,index)=>{
                const row=element('div',undefined,'visual-constraint');const source=element('select');source.setAttribute('aria-label','Constraint '+(index+1)+' result');
                populate(source,symbols,constraint.ref,'Select condition');source.addEventListener('change',()=>{constraint.ref=source.value;changed();});
                row.append(source,select([['true','Must be true'],['false','Must be false']],String(constraint.expected),'Constraint '+(index+1)+' expected value',value=>{constraint.expected=value==='true';changed();}),button('Delete constraint '+(index+1),'trash-2',()=>{spec.constraints.splice(index,1);changed();renderConstraints();},'visual-icon'));container.append(row);
            });
        }
        function renderDefinition() {
            if(!spec||!catalog)return;
            renderParameters();renderSteps();renderConstraints();updateSelectors();icons();
        }
        function displayDefinition() {
            byId('visualTitle').value=spec.title;byId('visualPrompt').value=spec.prompt;byId('visualWidth').value=spec.width;
            renderDefinition();scheduleSource();
        }
        function switchView(view) {
            for(const [key,id]of [['questions','Questions'],['rhema','Rhema'],['pgml','Pgml'],['tree','Tree']]) {
                byId('visual'+id+'Panel').hidden=key!==view;
                byId('visual'+id+'Tab').setAttribute('aria-selected',String(key===view));
            }
        }
        async function perform(action) {
            if(busy||!spec)return;
            if(!byId('visualDefinitionPanel').reportValidity()||!byId('visualCount').reportValidity())return;
            const payload=requestData(), expected=version;
            clearTimeout(sourceTimer);setBusy(true,action==='preview'?'Generating questions...':action==='save'?'Checking and saving...':'Checking definition...');message();
            try {
                const data=await jsonRequest('/teacher/visual/'+action,payload);
                if(expected!==version)return;
                byId('visualRhemaSource').value=data.source;byId('visualContext').textContent=data.context;
                if(action==='save') {
                    revision=data.revision;loadedName=data.name;dirty=false;
                    byId('visualDraftStatus').textContent='Question type saved';message('Saved '+data.name+'.','ok');
                    byId('visualOpenConfigure').hidden=false;byId('visualOpenSource').hidden=false;
                    await window.rhemaAuthoring.refreshCatalog(data.name);
                } else if(action==='preview') {
                    byId('visualPgSource').value=data.pgml_code;
                    byId('visualPgSource').dispatchEvent(new Event('input'));
                    const list=byId('visualAnswerList');list.replaceChildren();
                    for(const question of data.preview||[]){
                        const answer=data.types?.[spec.answer]==='Truth'?(question.answer==='true'?'1':'0'):question.answer;
                        list.append(noTranslate(element('li',answer)));
                    }
                    byId('visualStandardAnswers').hidden=!list.children.length;
                    if(data.visualization_path){byId('visualTreeFrame').src='/tree_visualization?filename='+encodeURIComponent(data.visualization_path.split('/').pop());byId('visualTreeFrame').hidden=false;byId('visualTreeEmpty').hidden=true;}
                    byId('visualDraftStatus').textContent='Generated successfully';switchView('questions');
                    document.dispatchEvent(new Event('rhema:visual-generated'));
                    await renderProblemPreview('visual',true);
                }else{
                    byId('visualDraftStatus').textContent='Check passed';message('Rhema check and sample generation passed.','ok');
                }
            }catch(error){byId('visualDraftStatus').textContent='Check definition';message(error.message);}
            finally{setBusy(false);}
        }
        function refreshEditButton() {
            const current=window.rhemaCatalog?.find(item=>item.name===byId('rhemaGrammarSelect').value);
            byId('visualEditDefinition').hidden=!current?.visual;
        }
        window.visualBuilder={
            async start(name) {
                version++;revision=null;loadedName='';dirty=true;byId('visualFilename').value=name;setBusy(true,'Loading library...');
                try {
                    await loadCatalog();spec=clone(catalog.starters.polynomial);
                    byId('visualStarter').replaceChildren(new Option('Empty definition','blank'));
                    for(const [key,value]of Object.entries(catalog.starters))byId('visualStarter').add(new Option(value.title,key));
                    byId('visualStarter').value='polynomial';displayDefinition();clearPreview();
                    byId('visualOpenConfigure').hidden=true;byId('visualOpenSource').hidden=true;message();byId('visualDraftStatus').textContent='New visual definition';
                }catch(error){message(error.message);}
                finally{setBusy(false);scheduleSource();}
            },
            async load(name) {
                version++;spec=null;revision=null;loadedName='';dirty=false;setBusy(true,'Loading definition...');
                byId('visualFilename').value=name;byId('visualTitle').value='';byId('visualPrompt').value='';
                byId('visualParameters').replaceChildren();byId('visualSteps').replaceChildren();byId('visualConstraints').replaceChildren();
                byId('visualRhemaSource').value='';byId('visualOpenConfigure').hidden=true;byId('visualOpenSource').hidden=true;clearPreview();
                try {
                    await loadCatalog();const data=await jsonRequest('/teacher/visual/definition?name='+encodeURIComponent(name));
                    spec=clone(data.specification);revision=data.revision;loadedName=name;dirty=false;byId('visualFilename').value=name;
                    byId('visualStarter').replaceChildren(new Option('Saved definition','saved'),new Option('Empty definition','blank'));
                    for(const [key,value]of Object.entries(catalog.starters))byId('visualStarter').add(new Option(value.title,key));
                    byId('visualStarter').value='saved';displayDefinition();clearPreview();byId('visualRhemaSource').value=data.source;
                    byId('visualOpenConfigure').hidden=false;byId('visualOpenSource').hidden=false;message();byId('visualDraftStatus').textContent='Saved visual definition';
                }catch(error){
                    message(error.message);
                    if(error.status===409){loadedName=name;byId('visualOpenConfigure').hidden=false;byId('visualOpenSource').hidden=false;}
                }
                finally{setBusy(false);}
            },
            canLeave() {
                if(!page.classList.contains('active'))return true;
                if(busy){message('Wait for the current operation to finish.');return false;}
                if(dirty&&!confirm('Leave the unsaved visual definition?'))return false;
                dirty=false;return true;
            }
        };
        byId('visualTitle').addEventListener('input',()=>{if(spec){spec.title=byId('visualTitle').value;changed();}});
        byId('visualFilename').addEventListener('input',()=>{if(spec)changed();});
        byId('visualPrompt').addEventListener('input',()=>{if(spec){spec.prompt=byId('visualPrompt').value;changed();}});
        byId('visualWidth').addEventListener('input',()=>{if(spec){spec.width=Number(byId('visualWidth').value);changed();}});
        byId('visualAnswer').addEventListener('change',()=>{spec.answer=byId('visualAnswer').value;changed();});
        byId('visualStarter').addEventListener('change',()=>{
            if(dirty&&!confirm('Replace the current visual definition with this starting point?')){byId('visualStarter').value='';return;}
            const selected=byId('visualStarter').value;
            if(selected==='saved'){window.visualBuilder.load(loadedName);return;}
            spec=selected==='blank'?{version:1,title:'New question type',parameters:[],steps:[],prompt:'',answer:'',constraints:[],width:12}:clone(catalog.starters[selected]);
            changed();displayDefinition();
        });
        byId('visualAddParameter').addEventListener('click',()=>{
            if(spec.parameters.length>=12){message('Use at most 12 random parameters.');return;}
            spec.parameters.push({name:uniqueName('a'),kind:'integer',min:-5,max:5});changed();renderDefinition();
        });
        byId('visualAddStep').addEventListener('click',()=>{
            if(spec.steps.length>=30){message('Use at most 30 mathematical steps.');return;}
            const op=catalog.operations.find(o=>o.id==='add');
            spec.steps.push({name:uniqueName('result'),operation:op.id,arguments:defaultArguments(op,symbolsBefore(spec,catalog.operations))});changed();renderDefinition();
        });
        byId('visualAddConstraint').addEventListener('click',()=>{
            if(spec.constraints.length>=12){message('Use at most 12 semantic constraints.');return;}
            const source=symbolsBefore(spec,catalog.operations).find(s=>s.type==='Truth');if(source){spec.constraints.push({ref:source.name,expected:true});changed();renderConstraints();icons();}
        });
        byId('visualInsert').addEventListener('click',()=>{
            const name=byId('visualInsertValue').value;if(!name)return;
            const input=byId('visualPrompt');input.setRangeText('{'+name+'}',input.selectionStart,input.selectionEnd,'end');spec.prompt=input.value;input.focus();changed();
        });
        for(const id of ['visualStudent','visualCount'])byId(id).addEventListener('input',()=>{version++;clearPreview();});
        byId('visualCheck').addEventListener('click',()=>perform('check'));
        byId('visualSave').addEventListener('click',()=>perform('save'));
        byId('visualGenerate').addEventListener('click',()=>perform('preview'));
        byId('visualCheckAnswers').addEventListener('click',()=>checkPreviewAnswers('visual'));
        byId('visualOpenConfigure').addEventListener('click',()=>window.rhemaAuthoring.openExisting(loadedName));
        byId('visualOpenSource').addEventListener('click',()=>{if(window.rhemaAuthoring.openExisting(loadedName))window.teacherBuilder.setMode('source');});
        byId('visualEditDefinition').addEventListener('click',()=>window.rhemaAuthoring.openVisual(byId('rhemaGrammarSelect').value));
        page.querySelectorAll('[data-visual-view]').forEach(tab=>tab.addEventListener('click',()=>switchView(tab.dataset.visualView)));
        byId('visualCopyRhema').addEventListener('click',async()=>{try{await navigator.clipboard.writeText(byId('visualRhemaSource').value);message('Rhema copied.','ok');}catch{message('Copy failed. Select the source to copy it.');}});
        byId('visualDefinitionPanel').addEventListener('submit',event=>{event.preventDefault();perform('preview');});
        byId('rhemaGrammarSelect').addEventListener('change',refreshEditButton);
        document.addEventListener('rhema:catalog',refreshEditButton);
        window.addEventListener('beforeunload',event=>{if(dirty){event.preventDefault();event.returnValue='';}});
    });
})();
