/* Form state stays separate from hand-written Rhema source. */
document.addEventListener('DOMContentLoaded', () => {
    const byId = id => document.getElementById(id);
    const select = byId('rhemaGrammarSelect');
    const panel = byId('teacherBuilder');
    const fields = byId('teacherFields');
    const questionSelect = byId('rhemaQuestionSelect');
    let mode = 'form', schema = null, config = null, loaded = '', sequence = 0, busy = false;
    const friendly = {
        cost:'Complexity budget', digit:'Maximum digits', dim:'Matrix dimension', first:'First term',
        difference:'Common difference', ratio:'Common ratio', index:'Term index', point:'Evaluation point',
        exponent:'Exponent', question_mode:'Question mode', calculus_mode:'Calculus mode',
        vector_mode:'Vector mode', set_mode:'Set mode', root:'Root', second_root:'Second root',
        arithmetic_nth:'Arithmetic sequence: nth term', geometric_nth:'Geometric sequence: nth term',
        arithmetic_sum:'Arithmetic sequence: sum', geometric_sum:'Geometric sequence: sum',
        arithmetic:'Arithmetic', conjugate:'Conjugate', modulus:'Modulus', power_i:'Power of i',
        dot:'Dot product', cross:'Cross product', norm:'Magnitude', unit:'Unit vector',
        parallel:'Parallel vector', same_direction:'Same direction', derivative:'Derivative', integral:'Integral',
        two_integer_roots:'Two integer roots', repeated_root:'Repeated root', no_real_roots:'No real roots',
        two_rational_roots:'Two rational roots', eigenvalues2:'2 x 2 eigenvalues', eigenvalues3:'3 x 3 eigenvalues',
        characteristic:'Characteristic polynomial', eigenvector:'Eigenvector'
    };
    const nameOf = name => friendly[name] || name.replaceAll('_',' ').replace(/^./, s => s.toUpperCase());
    function element(tag, text, className) {
        const node = document.createElement(tag);
        if (text !== undefined) node.textContent = text;
        if (className) node.className = className;
        return node;
    }
    function message(text, kind='error') {
        const box=byId('teacherMessage'); box.textContent=text; box.hidden=!text; box.dataset.kind=kind;
    }
    function changed() {
        byId('teacherState').textContent='Settings changed';
        byId('teacherSource').value='';
        message('');
        document.dispatchEvent(new Event('workspace:settings'));
    }
    function numberInput(value, label, onChange, options={}) {
        const input=element('input'); input.type='number'; input.step='1'; input.value=value;
        input.setAttribute('aria-label',label);
        for (const [key,value] of Object.entries(options)) input[key]=String(value);
        input.addEventListener('input',()=>{ onChange(input.value==='' ? null : Number(input.value)); changed(); });
        return input;
    }
    function inputField(field) {
        const labelText=(field.module==='root'?'':field.module.slice(5)+' / ')+nameOf(field.name);
        const label=element('label',labelText,'teacher-field');
        const value=config.values[field.id];
        if(field.kind==='range') {
            const range=element('span',undefined,'teacher-range');
            value.forEach((n,index)=>{
                const caption=value.length===1?'Digits':(index===0?'Minimum':'Maximum');
                const part=element('label',caption);
                part.append(numberInput(n,labelText+' '+caption,v=>{config.values[field.id][index]=v;}));
                range.append(part);
            }); label.append(range);
        } else if(field.kind==='boolean') {
            const input=element('select'); input.setAttribute('aria-label',labelText);
            for(const option of ['random','true','false']) input.add(new Option(nameOf(option),option));
            input.value=value;
            input.addEventListener('change',()=>{config.values[field.id]=input.value;changed();}); label.append(input);
        } else if(field.allowed?.length) {
            const input=element('select');input.setAttribute('aria-label',labelText);
            const modes = {calculus_mode:['Mixed','Derivative','Integral'],
                set_mode:['Mixed','Union','Intersection','Difference'],
                vector_mode:['Mixed','Dot product','Cross product','Magnitude','Unit vector','Parallel vector','Same direction']};
            for(const n of field.allowed)input.add(new Option(modes[field.name]?.[n] || (field.name.endsWith('mode')?(n===0?'Mixed':'Mode '+n):String(n)),String(n)));
            input.value=String(value);
            input.dataset.setting=field.id;
            input.addEventListener('change',()=>{config.values[field.id]=Number(input.value);changed();});label.append(input);
        } else label.append(numberInput(value,labelText,v=>{config.values[field.id]=v;},{min:0,max:60}));
        return label;
    }
    function fieldset(title, items) {
        const section=element('fieldset',undefined,'teacher-fieldset');
        section.append(element('legend',title));
        const grid=element('div',undefined,'teacher-grid'); items.forEach(item=>grid.append(inputField(item)));
        section.append(grid);return section;
    }
    function rulesView(ruleFields) {
        const section=element('details');section.append(element('summary','Question forms and rule settings'));
        const groups=new Map();
        for(const f of ruleFields.filter(f=>f.kind==='weight')) {
            const group=f.module+' / '+f.group;
            if(!groups.has(group)) {
                const block=element('div',undefined,'teacher-rule-group');block.append(element('h4',group));
                section.append(block);groups.set(group,block);
            }
            const row=element('div',undefined,'teacher-rule');
            const label=element('label',undefined,'teacher-rule-name');
            const toggle=element('input');toggle.type='checkbox';toggle.checked=config.values[f.id]>0;
            toggle.setAttribute('aria-label','Enable '+nameOf(f.rule));
            label.append(toggle,document.createTextNode(nameOf(f.rule)));
            const weightLabel=element('label','Weight');
            const weight=numberInput(config.values[f.id],'Weight '+f.rule,v=>{config.values[f.id]=v;toggle.checked=v>0;},{min:0,max:1000});
            weightLabel.append(weight);
            toggle.addEventListener('change',()=>{config.values[f.id]=toggle.checked?(f.value||1):0;weight.value=config.values[f.id];changed();});
            row.append(label,weightLabel);
            const price=ruleFields.find(x=>x.kind==='price'&&x.id===f.id.replace(/:weight$/,':cost'));
            if(price) {
                const priceLabel=element('label','Cost');priceLabel.append(numberInput(config.values[price.id],'Cost '+f.rule,v=>{
                    const previous=config.values[price.id];config.values[price.id]=v;
                    const budget=schema.fields.find(x=>x.id===f.module+':a:cost');
                    if(budget?.allowed?.length&&config.values[budget.id]===previous&&v!==null){
                        config.values[budget.id]=v;
                        const control=Array.from(fields.querySelectorAll('select')).find(x=>x.dataset.setting===budget.id);
                        if(control){if(!Array.from(control.options).some(o=>o.value===String(v)))control.add(new Option(String(v),String(v)));control.value=String(v);}
                    }
                },{min:0,max:30}));row.append(priceLabel);
            } else row.append(element('span'));
            groups.get(group).append(row);
        }
        return section;
    }
    function render() {
        fields.replaceChildren();
        byId('teacherTitle').textContent=schema.title;
        const advanced=element('details',undefined,'teacher-advanced');
        advanced.append(element('summary','Advanced settings'));
        const inherited=schema.fields.filter(f=>f.kind==='integer');
        const cost=inherited.find(f=>f.id==='root:a:cost');
        if(cost) {
            const section=fieldset('Generation budget',[cost]);
            const preset=element('select');preset.setAttribute('aria-label','Budget preset');
            const allowed=cost.allowed||[];
            const lower=allowed.length?allowed.filter(n=>n<cost.value).at(-1)??allowed[0]:Math.max(1,Math.floor(cost.value*.65));
            const higher=allowed.length?allowed.find(n=>n>cost.value)??allowed.at(-1):Math.min(60,Math.ceil(cost.value*1.4));
            for(const [name,value] of [['Custom',''],['Lower budget',lower],['Default',cost.value],['Higher budget',higher]]) preset.add(new Option(name,String(value)));
            preset.value='';
            preset.addEventListener('change',()=>{if(preset.value!==''){config.values[cost.id]=Number(preset.value);render();changed();}});
            const label=element('label','Budget preset','teacher-field');label.append(preset);section.querySelector('.teacher-grid').prepend(label);
            advanced.append(section);
        }
        if(inherited.some(f=>f!==cost)) fields.append(fieldset('Question parameters',inherited.filter(f=>f!==cost)));
        const randoms=schema.fields.filter(f=>f.id.includes(':r:')||f.kind==='boolean');
        if(randoms.length>12){const advanced=element('details');advanced.append(element('summary','Random values ('+randoms.length+')'),fieldset('Random values',randoms));fields.append(advanced);}
        else if(randoms.length) fields.append(fieldset('Random values',randoms));
        if(schema.length_supported) {
            const section=element('fieldset',undefined,'teacher-fieldset');section.append(element('legend','Expression operators'));
            const grid=element('div',undefined,'teacher-grid');
            for(const [key,label] of [['min_length','Minimum (optional)'],['max_length','Maximum (optional)']]) {
                const wrapper=element('label',label);const input=numberInput(config[key]??'',label,v=>{config[key]=v;},{min:0,max:30});input.placeholder='No limit';wrapper.append(input);grid.append(wrapper);
            } section.append(grid);fields.append(section);
        }
        advanced.append(rulesView(schema.fields));
        const leaves=schema.fields.filter(f=>f.id.includes(':leaf:'));
        if(leaves.length) { const leavesSection=element('details');leavesSection.append(element('summary','Expression leaf ranges'),fieldset('Leaf values',leaves));advanced.append(leavesSection); }
        fields.append(advanced);
        byId('teacherWidth').value=config.width;
        byId('teacherInstruction').value=config.instruction||'';
    }
    function defaults() {
        return {values:Object.fromEntries(schema.fields.map(f=>[f.id,structuredClone(f.value)])),width:schema.width||16,min_length:null,max_length:null,instruction:''};
    }
    async function load(force=false) {
        const name=select.value;
        if(!name||(!force&&loaded===name))return;
        const current=++sequence;loaded=name;schema=null;config=null;
        fields.replaceChildren();byId('teacherState').textContent='Loading settings';message('');
        try {
            const response=await fetch('/teacher/schema?grammar='+encodeURIComponent(name)); const data=await response.json();
            if(current!==sequence)return;
            if(!data.success)throw new Error(data.error);
            schema=data.schema;config=data.configuration||defaults();render();
            byId('teacherState').textContent=data.configuration?'Saved preset':'Default settings';
            byId('teacherPresetName').value=name.replace(/\.rhm$/,'')+'_custom.rhm';
        } catch(error) {if(current===sequence){byId('teacherState').textContent='Source mode available';message(error.message);}}
    }
    function sync() {
        const isGrammar=document.querySelector('input[name="generatorMode"]:checked')?.value==='ag';
        panel.hidden=!isGrammar||mode!=='form';
        panel.querySelectorAll('input,select,textarea,button').forEach(control=>{control.disabled=panel.hidden;});
        document.body.classList.toggle('teacher-form-mode',isGrammar&&mode==='form');
        byId('teacherFormMode').setAttribute('aria-selected',String(mode==='form'));
        byId('teacherSourceMode').setAttribute('aria-selected',String(mode==='source'));
        document.body.classList.toggle('rhema-source-mode',isGrammar&&mode==='source');
        if(isGrammar&&mode==='form')load();
    }
    function requestData() {
        if(!schema||!config||loaded!==select.value)throw new Error('Load a grammar before generating.');
        if(busy)throw new Error('Wait for the current operation to finish.');
        if(!byId('studentForm').reportValidity())throw new Error('Check the highlighted settings.');
        config.width=Number(byId('teacherWidth').value);
        config.instruction=byId('teacherInstruction').value;
        return {grammar:select.value,question:questionSelect.hidden?'main':(questionSelect.value||'main'),configuration:structuredClone(config),
            count:Number(byId('rhemaCount').value),student_id:byId('studentId').value.trim()};
    }
    function receive(data) {
        byId('teacherSource').value=data.source||'';
        byId('teacherState').textContent='Generated successfully';message('');
    }
    async function perform(action) {
        let payload;try{payload=requestData();}catch(e){message(e.message);return;}
        payload.name=byId('teacherPresetName').value.trim();
        busy=true;byId('teacherState').textContent=action==='save'?'Checking and saving':'Checking export';
        try {
            const response=await fetch('/teacher/'+action,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(payload)});
            if(!response.ok){const data=await response.json();throw new Error(data.error);}
            if(action==='export') {
                const url=URL.createObjectURL(await response.blob());const link=element('a');link.href=url;link.download='rhema-specification.zip';link.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
                message('Specification exported.','ok');
            } else {
                const data=await response.json();message('Saved '+data.name+'.','ok');
                select.add(new Option(data.name,data.name));
                document.dispatchEvent(new CustomEvent('rhema:preset-saved', {detail:{name:data.name}}));
            }
            byId('teacherState').textContent=action==='save'?'Preset saved':'Exported';
        }catch(error){message(error.message);byId('teacherState').textContent='Check settings';}
        finally{busy=false;}
    }
    byId('teacherFormMode').addEventListener('click',()=>{
        if(window.rhemaEditorState?.().dirty){
            const warning='Save the source draft before switching to the form editor.';
            const editorMessage=byId('rhemaGrammarMessage');
            editorMessage.textContent=warning;editorMessage.className='rhema-message error';editorMessage.style.display='block';
            return;
        }
        mode='form';sync();
    });
    byId('teacherSourceMode').addEventListener('click',()=>{
        mode='source';sync();if(byId('rhemaEditor').style.display==='none')byId('rhemaEditToggleBtn').click();
    });
    select.addEventListener('change',()=>{load(true);});
    questionSelect.addEventListener('change',()=>{
        if(!schema||!config)return;
        const q=schema.questions.find(q=>q.name===(questionSelect.value||'main'));
        if(q)for(const [name,value]of Object.entries(q.initials))if(('root:a:'+name) in config.values)config.values['root:a:'+name]=value;
        render();changed();
    });
    document.querySelectorAll('input[name="generatorMode"]').forEach(input=>input.addEventListener('change',sync));
    new MutationObserver(()=>{sync();}).observe(select,{childList:true});
    byId('teacherWidth').addEventListener('input',changed);
    byId('teacherInstruction').addEventListener('input',changed);
    byId('teacherSave').addEventListener('click',()=>perform('save'));
    byId('teacherExport').addEventListener('click',()=>perform('export'));
    byId('teacherReset').addEventListener('click',()=>{if(schema){config=defaults();render();changed();}});
    window.teacherBuilder={active:()=>mode==='form',request:requestData,receive,message};
    sync();
});
