/* Returned PG HTML runs only inside a script-enabled, opaque-origin iframe. */
const webworkPreviews = {
    generate: {source: null, requestId: 0, checkId: 0, ready: false, checking: false},
    history: {source: null, requestId: 0, checkId: 0, ready: false, checking: false},
    import: {source: null, requestId: 0, checkId: 0, ready: false, checking: false}
};
const renderedPgCache = new Map();
window.fetchRenderedPg = function(source, force = false, seed = 1) {
    const key = JSON.stringify([source, seed]);
    if (force) renderedPgCache.delete(key);
    if (renderedPgCache.has(key)) return renderedPgCache.get(key);
    const pending = fetch('/api/webwork/render', {
        method: 'POST', headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({pg_source: source, problem_seed: seed})
    }).then(async response => {
        const data = await response.json();
        if (!response.ok || !data.success) {
            const error = new Error(data.error || `Preview failed with HTTP ${response.status}.`);
            error.code = data.code;
            throw error;
        }
        return data.html;
    }).catch(error => {
        if (renderedPgCache.get(key) === pending) renderedPgCache.delete(key);
        throw error;
    });
    renderedPgCache.set(key, pending);
    if (renderedPgCache.size > 4) renderedPgCache.delete(renderedPgCache.keys().next().value);
    return pending;
};
function previewElements(area) {
    const prefix = {generate:'generated', history:'history', import:'import'}[area];
    return {
        source: document.getElementById({generate:'output', history:'historyOutput', import:'pgImportSource'}[area]),
        seed: area === 'import' ? document.getElementById('pgImportSeed') : null,
        frame: document.getElementById(`${prefix}RenderedFrame`),
        status: document.getElementById(`${prefix}RenderedStatus`),
        check: document.getElementById(`${prefix}CheckAnswers`),
        feedback: document.getElementById(`${prefix}AnswerFeedback`)
    };
}
function previewSeed(area) {
    return Number(previewElements(area).seed?.value ?? 1);
}
function previewStatus(elements, message, kind) {
    elements.status.textContent = message;
    elements.status.className = `rendered-preview-status ${kind}`;
}
function updateCheckButton(area) {
    const state = webworkPreviews[area];
    const elements = previewElements(area);
    elements.check.disabled = !state.ready || state.checking || elements.frame.hidden
        || state.source !== elements.source.value || state.seed !== previewSeed(area);
    elements.check.querySelector('span').textContent = state.checking ? 'Checking answers...' : 'Check answers';
}
function resetAnswerCheck(area) {
    const state = webworkPreviews[area];
    state.checkId++;
    state.ready = false;
    state.checking = false;
    state.token = null;
    state.pending?.reject(new Error('Preview changed. Check answers again.'));
    state.pending = null;
    const feedback = previewElements(area).feedback;
    feedback.replaceChildren();
    feedback.hidden = true;
    updateCheckButton(area);
}
function invalidateProblemPreview(area, message = 'Source changed. Refresh the preview.', kind = 'stale') {
    const state = webworkPreviews[area];
    const elements = previewElements(area);
    state.requestId++;
    resetAnswerCheck(area);
    state.source = null;
    state.seed = null;
    elements.frame.hidden = true;
    elements.frame.removeAttribute('srcdoc');
    previewStatus(elements, message, kind);
}
// The iframe cannot read the parent DOM or storage. This bridge sends only
// named answer controls; it never submits hidden session tokens or PG options.
function iframeAnswerBridge(token) {
    const channel = 'rhema-answer-check';
    const answerName = /^AnSwEr[0-9]{4,}(?:_[0-9]+)*$/;
    const send = (type, extra = {}) => parent.postMessage({channel, token, type, ...extra}, '*');
    const controls = () => [...document.querySelectorAll('#problem_body input[name], #problem_body select[name], #problem_body textarea[name]')]
        .filter(input => answerName.test(input.name) && !input.disabled);
    window.addEventListener('message', event => {
        const message = event.data;
        if (event.source !== parent || message?.channel !== channel || message.token !== token
            || message.type !== 'collect' || !Number.isInteger(message.requestId)) return;
        const answers = {};
        for (const input of controls()) {
            if (!(input.name in answers)) answers[input.name] = '';
            if ((input.type === 'radio' || input.type === 'checkbox') && !input.checked) continue;
            answers[input.name] = input.value;
        }
        send('answers', {requestId: message.requestId, answers});
    });
    const changed = event => {
        if (answerName.test(event.target.name || '')) send('changed');
    };
    document.addEventListener('input', changed);
    document.addEventListener('change', changed);
    document.addEventListener('submit', event => event.preventDefault());
    send('ready', {answerCount: controls().length});
}
function staticPreviewDocument(html, token) {
    const document = new DOMParser().parseFromString(html, 'text/html');
    // These optional editors/interaction trackers require parent-frame access
    // or localStorage. Static previews keep ordinary inputs and MathJax instead.
    for (const script of document.querySelectorAll('script[src]')) {
        const path = new URL(script.getAttribute('src'), document.baseURI).pathname;
        if (/^\/js\/apps\/Problem\/problem(?:\.[a-f0-9]+\.min)?\.js$/.test(path)
            || /^\/js\/apps\/CSSMessage\/css-message(?:\.[a-f0-9]+\.min)?\.js$/.test(path)
            || /^\/pg_files\/js\/MathQuill\/mqeditor(?:\.[a-f0-9]+\.min)?\.js$/.test(path)) {
            script.remove();
        }
    }
    const bridge = document.createElement('script');
    bridge.textContent = `(${iframeAnswerBridge.toString()})(${JSON.stringify(token)});`;
    document.body.append(bridge);
    return '<!DOCTYPE html>\n' + document.documentElement.outerHTML;
}
async function renderProblemPreview(area, force = false) {
    const state = webworkPreviews[area];
    const elements = previewElements(area);
    const source = elements.source.value;
    const seed = previewSeed(area);
    const requestId = ++state.requestId;
    if (area === 'generate') window.questionPreview?.useLocal(false);
    if (!Number.isInteger(seed) || seed < 1 || seed > 2147483647) {
        invalidateProblemPreview(area, 'PG problem seed must be an integer between 1 and 2147483647.', 'error');
        return;
    }
    if (!source.trim()) {
        invalidateProblemPreview(area, area === 'import' ? 'No PG file loaded' : 'No questions generated', 'empty');
        return;
    }
    if (!force && state.source === source && state.seed === seed && elements.frame.srcdoc) {
        elements.frame.hidden = false;
        previewStatus(elements, 'Rendered by WeBWorK', 'ready');
        updateCheckButton(area);
        return;
    }
    resetAnswerCheck(area);
    elements.frame.removeAttribute('srcdoc');
    elements.frame.hidden = true;
    previewStatus(elements, 'Rendering with WeBWorK...', 'loading');
    try {
        const html = await window.fetchRenderedPg(source, force, seed);
        if (state.requestId !== requestId) return;
        if (elements.source.value !== source || previewSeed(area) !== seed) {
            previewStatus(elements, 'Source changed. Refresh the preview.', 'stale');
            return;
        }
        const token = [...crypto.getRandomValues(new Uint8Array(24))].map(n => n.toString(16).padStart(2, '0')).join('');
        state.token = token;
        state.source = source;
        state.seed = seed;
        elements.frame.srcdoc = staticPreviewDocument(html, token);
        elements.frame.hidden = false;
        previewStatus(elements, 'Rendered by WeBWorK', 'ready');
        window.workspaceUI?.rendererState(true);
    } catch (error) {
        if (state.requestId !== requestId) return;
        previewStatus(elements, error.code === 'renderer_unavailable'
            ? 'WeBWorK is offline. Start the renderer and refresh.' : error.message, 'error');
        if (error.code === 'renderer_unavailable') window.workspaceUI?.rendererState(false);
    }
}
function showAnswerFeedback(area, text, grade = null) {
    const feedback = previewElements(area).feedback;
    const summary = document.createElement('p');
    summary.textContent = text;
    feedback.replaceChildren(summary);
    feedback.hidden = false;
    delete feedback.dataset.stale;
    if (!grade) return;
    const list = document.createElement('ol');
    for (const answer of grade.answers) {
        const item = document.createElement('li');
        item.dataset.correct = String(answer.correct);
        const status = document.createElement('span');
        status.textContent = answer.correct ? 'Correct' : answer.score > 0 ? 'Partially correct' : 'Incorrect';
        item.append(status);
        if (answer.feedback) {
            const detail = document.createElement('span');
            detail.dataset.noTranslate = '';
            detail.textContent = `: ${answer.feedback}`;
            item.append(detail);
        }
        list.append(item);
    }
    feedback.append(list);
}
window.addEventListener('message', event => {
    const message = event.data;
    if (message?.channel !== 'rhema-answer-check') return;
    for (const area of Object.keys(webworkPreviews)) {
        const state = webworkPreviews[area];
        const elements = previewElements(area);
        if (!state.token || event.source !== elements.frame.contentWindow || message.token !== state.token
            || state.source !== elements.source.value || state.seed !== previewSeed(area)) continue;
        if (message.type === 'ready') {
            state.ready = Number.isInteger(message.answerCount) && message.answerCount > 0;
            if (!state.ready) previewStatus(elements, 'Rendered by WeBWorK. No answer fields found.', 'empty');
            updateCheckButton(area);
        } else if (message.type === 'answers' && state.pending?.id === message.requestId) {
            state.pending.resolve(message.answers);
        } else if (message.type === 'changed') {
            state.checkId++;
            if (!elements.feedback.hidden) {
                showAnswerFeedback(area, 'Answers changed. Check again.');
                elements.feedback.dataset.stale = 'true';
            }
        }
    }
});
async function checkPreviewAnswers(area) {
    const state = webworkPreviews[area];
    const elements = previewElements(area);
    if (!state.ready || state.checking || elements.frame.hidden || state.source !== elements.source.value
        || state.seed !== previewSeed(area)) return;
    const checkId = ++state.checkId;
    const source = state.source;
    const seed = state.seed;
    const token = state.token;
    state.checking = true;
    updateCheckButton(area);
    try {
        const answers = await new Promise((resolve, reject) => {
            const timer = setTimeout(() => reject(new Error('Could not read answer inputs. Refresh the preview.')), 3_000);
            state.pending = {id: checkId,
                resolve: value => {clearTimeout(timer); resolve(value);},
                reject: error => {clearTimeout(timer); reject(error);}};
            elements.frame.contentWindow.postMessage({channel: 'rhema-answer-check', token,
                type: 'collect', requestId: checkId}, '*');
        });
        state.pending = null;
        if (state.checkId !== checkId || previewSeed(area) !== seed) return;
        const response = await fetch('/api/webwork/check', {
            method: 'POST', headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({pg_source: source, problem_seed: seed, answers})
        });
        const grade = await response.json();
        if (state.token !== token || state.checkId !== checkId || elements.source.value !== source
            || previewSeed(area) !== seed) return;
        if (!response.ok || !grade.success) throw new Error(grade.error || 'Answer checking failed.');
        showAnswerFeedback(area, `Score: ${Math.round(grade.score * 100)}% (${grade.correct_count}/${grade.answer_count} correct)`, grade);
    } catch (error) {
        if (state.token === token && state.checkId === checkId) showAnswerFeedback(area, error.message);
    } finally {
        if (state.token === token) {
            state.checking = false;
            state.pending = null;
            updateCheckButton(area);
        }
    }
}
for (const area of Object.keys(webworkPreviews)) {
    const elements = previewElements(area);
    elements.source.addEventListener('input', () => invalidateProblemPreview(area));
    elements.seed?.addEventListener('input', () => invalidateProblemPreview(area, 'Seed changed. Render again.'));
}
document.addEventListener('webwork:local-preview', event => {
    if (event.detail.active) previewElements('generate').feedback.hidden = true;
    updateCheckButton('generate');
});
