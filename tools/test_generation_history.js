const test=require('node:test'),assert=require('node:assert/strict');
const {label,populate,heading}=require('../static/generation_history.js');

class Element {
    constructor(){this.children=[];this.dataset={};this.value='';}
    set textContent(value){this.children=[String(value)];}
    get textContent(){return this.children.map(child=>typeof child==='string'?child:child.textContent).join('');}
    append(...children){this.children.push(...children);}
    replaceChildren(...children){this.children=[...children];}
}
function documentFor(t){const previous=global.document;global.document={createElement:()=>new Element()};t.after(()=>{global.document=previous;});}

test('identity uses explicit fields rather than the teacher filename',()=>{
    assert.equal(label({filename:'teacher_20261107_120000.pg',student_id:'STUDENT_A_01'}),'STUDENT_A_01');
    assert.equal(label({student_id:null,identity_status:'recorded'}),'Shared worksheet');
    assert.equal(label({student_id:null,identity_status:'unknown'}),'Legacy worksheet');
});
test('history rows preserve literal student identifiers and expose topic and time',t=>{
    documentFor(t);const button=new Element();
    populate(button,{filename:'worksheet.pg',student_id:'True',grammar:'boolean.rhm',timestamp:'2026-11-07 12:00:00'});
    assert.equal(button.dataset.filename,'worksheet.pg');
    assert.equal(button.children[1].textContent,'True');
    assert.equal(button.children[1].dataset.noTranslate,'');
    assert.equal(button.children[2].textContent,'boolean.rhm');
    assert.equal(button.children[3].textContent,'2026-11-07 12:00:00');
});
test('shared and unrecoverable legacy rows never invent a student identity',t=>{
    documentFor(t);
    for(const [identity_status,text,avatar] of [['recorded','Shared worksheet','WS'],['unknown','Legacy worksheet','?']]){
        const button=new Element();populate(button,{filename:'teacher_legacy.pg',student_id:null,identity_status});
        assert.equal(button.children[0].textContent,avatar);assert.equal(button.children[1].textContent,text);
    }
});
test('detail headings use the same identity as the list',t=>{
    documentFor(t);const element=new Element();
    heading(element,{student_id:'STUDENT_A_01',timestamp:'2026-11-07 12:00:00'});
    assert.match(element.textContent,/Student ID: STUDENT_A_01/);
    heading(element,{student_id:null,identity_status:'recorded'});
    assert.equal(element.textContent,'Shared worksheet');
    heading(element,{student_id:null,identity_status:'unknown'});
    assert.equal(element.textContent,'Legacy worksheet');
    heading(element,null);assert.equal(element.textContent,'Loading record...');
});
