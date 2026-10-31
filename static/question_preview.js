/* A clearly labelled fallback, never a substitute for a WeBWorK render. */
(() => {
    const panel = document.getElementById('generatedLocalPreview');
    const toggle = document.getElementById('generatedLocalToggle');
    const answers = document.getElementById('generatedAnswers');
    const answerList = document.getElementById('generatedAnswerList');
    let source = null;
    function node(tag, text) {
        const result = document.createElement(tag);
        if (text !== undefined) result.textContent = text;
        return result;
    }
    function mathText(parent, text) {
        let offset = 0;
        for (const match of text.matchAll(/\[`([\s\S]*?)`\]/g)) {
            parent.append(document.createTextNode(text.slice(offset, match.index)));
            const span = node('span');
            if (window.katex) window.katex.render(match[1], span, {throwOnError:false, trust:false, strict:false});
            else span.textContent = match[1];
            parent.append(span);
            offset = match.index + match[0].length;
        }
        parent.append(document.createTextNode(text.slice(offset)));
    }
    function useLocal(active) {
        panel.hidden = !active;
        if (active) {
            document.getElementById('generatedRenderedFrame').hidden = true;
            document.getElementById('generatedRenderedStatus').textContent = 'Local preview - not rendered by WeBWorK';
        }
        toggle.setAttribute('aria-pressed', String(active));
        document.dispatchEvent(new CustomEvent('webwork:local-preview', {detail:{active}}));
    }
    function clear() {
        source = null;
        panel.replaceChildren(); panel.hidden = true; toggle.hidden = true;
        answerList.replaceChildren(); answers.hidden = true; answers.open = false;
    }
    function show(data) {
        clear(); source = data.pgml_code || '';
        const questions = data.preview || [];
        if (!questions.length) return;
        toggle.hidden = false;
        questions.forEach((question, index) => {
            const article = node('article');
            article.dataset.noTranslate = '';
            const body = node('div'); body.className = 'local-question-body';
            article.append(node('strong', `${index + 1}.`), body);
            let buffer = '';
            const flush = () => { mathText(body, buffer); buffer = ''; };
            for (const piece of question.pieces) {
                if (piece.text !== undefined) buffer += piece.text;
                else { flush(); const blank = node('span'); blank.className = 'teacher-answer-blank'; body.append(blank); }
            }
            flush(); panel.append(article);
            if (question.answer !== undefined) answerList.append(node('p', `${index + 1}.  ${question.answer}`));
        });
        answers.hidden = !answerList.childNodes.length;
    }
    toggle.addEventListener('click', () => {
        if (panel.hidden) useLocal(true);
        else renderProblemPreview('generate');
    });
    document.getElementById('output').addEventListener('input', event => {
        if (source !== null && event.target.value !== source) clear();
    });
    window.questionPreview = {show, clear, useLocal};
})();
