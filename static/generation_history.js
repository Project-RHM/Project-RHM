/* Identity comes from history metadata, never from splitting display filenames. */
(() => {
    function label(record) {
        if(typeof record?.student_id==='string'&&record.student_id)return record.student_id;
        return record?.identity_status==='unknown'?'Legacy worksheet':'Shared worksheet';
    }
    function populate(button,record) {
        const avatar=document.createElement('span'),identity=document.createElement('span'),time=document.createElement('span');
        button.type='button';button.className='history-item';button.dataset.filename=record.filename;
        button.title='Open '+record.filename;
        avatar.className='history-avatar';avatar.dataset.noTranslate='';
        avatar.textContent=record.student_id?record.student_id.slice(0,2).toUpperCase():(record.identity_status==='unknown'?'?':'WS');
        identity.className='student-id';identity.textContent=label(record);
        if(record.student_id)identity.dataset.noTranslate='';
        time.className='timestamp';time.textContent=record.timestamp||'';time.dataset.noTranslate='';
        button.replaceChildren(avatar,identity);
        if(record.grammar){const topic=document.createElement('span');topic.className='history-topic';topic.textContent=record.grammar;topic.dataset.noTranslate='';button.append(topic);}
        button.append(time);
    }
    function heading(element,record) {
        if(!record){element.textContent='Loading record...';return;}
        const identity=document.createElement('strong');
        if(record.student_id){
            const id=document.createElement('span');id.textContent=record.student_id;id.dataset.noTranslate='';
            identity.append('Student ID: ',id);
        }else identity.textContent=label(record);
        element.replaceChildren(identity);
        if(record.timestamp){const time=document.createElement('span');time.textContent=record.timestamp;time.dataset.noTranslate='';element.append(' · ',time);}
        if(record.grammar){const topic=document.createElement('span');topic.textContent=record.grammar;topic.dataset.noTranslate='';element.append(' · ',topic);}
    }
    const api={label,populate,heading};
    if(typeof module!=='undefined'&&module.exports)module.exports=api;
    if(typeof window!=='undefined')window.RhemaHistory=api;
})();
