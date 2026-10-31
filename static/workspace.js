document.addEventListener('DOMContentLoaded', () => {
    const byId = id => document.getElementById(id);
    const select = byId('rhemaGrammarSelect');
    let catalog = [], library = 'all';
    const categories = {
        arithmetic:'Arithmetic and algebra', factoring:'Arithmetic and algebra',
        library_formula:'Arithmetic and algebra', library_linear:'Arithmetic and algebra',
        library_polynomial:'Arithmetic and algebra', library_quadratic:'Arithmetic and algebra',
        linear_equation:'Arithmetic and algebra', polynomial_expand:'Arithmetic and algebra', polynomial_forms:'Arithmetic and algebra',
        boolean:'Logic and sets', boolean_equiv:'Logic and sets', logic_forms:'Logic and sets', set:'Logic and sets',
        calculus:'Calculus and sequences', sequence:'Calculus and sequences', sequence_parts:'Calculus and sequences',
        limits:'Calculus and sequences', series:'Calculus and sequences', derivative_or_boolean:'Calculus and sequences',
        complex:'Vectors and linear algebra', vector:'Vectors and linear algebra', vector_expr:'Vectors and linear algebra',
        determinant:'Vectors and linear algebra', eigen:'Vectors and linear algebra', linear_system:'Vectors and linear algebra',
        matrix_expr:'Vectors and linear algebra', matrix_inverse:'Vectors and linear algebra',
        counting:'Other topics', number_theory:'Other topics', inequality:'Other topics'
    };
    const translated = value => window.RhemaI18n?.t(value) || value;
    function updateSelection() {
        const item = catalog.find(item => item.name === select.value);
        byId('workspaceSelection').textContent = document.body.classList.contains('classic-workspace')
            ? 'Classic generator' : (item?.title || select.value || 'Question workspace');
        for (const option of select.options) {
            const info = catalog.find(item => item.name === option.value);
            if (info && !option.dataset.draft) option.textContent = document.body.classList.contains('rhema-source-mode') ? info.name : info.title;
        }
        byId('grammarCatalog').querySelectorAll('[data-grammar]').forEach(button => {
            button.setAttribute('aria-current', String(button.dataset.grammar === select.value));
        });
    }
    function renderCatalog() {
        const container = byId('grammarCatalog'); container.replaceChildren();
        const query = byId('grammarSearch').value.trim().toLowerCase();
        const groups = new Map();
        for (const item of catalog) {
            if (library === 'presets' && !item.custom) continue;
            if (library === 'all' && item.custom) continue;
            if (query && !`${item.title} ${translated(item.title)} ${item.name}`.toLowerCase().includes(query)) continue;
            const group = item.custom ? 'My presets' : (categories[item.name.slice(0,-4)] || 'Other topics');
            if (!groups.has(group)) groups.set(group, []);
            groups.get(group).push(item);
        }
        for (const [group, items] of groups) {
            const heading = document.createElement('h3'); heading.className = 'catalog-group'; heading.textContent = group;
            container.append(heading);
            for (const item of items) {
                const button = document.createElement('button'); button.type = 'button';
                button.className = 'catalog-item'; button.textContent = item.title;
                button.dataset.grammar = item.name; button.title = item.name;
                button.addEventListener('click', () => {
                    byId('newQuestionBtn').click(); setGenerator('ag');
                    select.value = item.name; select.dispatchEvent(new Event('change', {bubbles:true}));
                    updateSelection();
                    closeMobileSidebar();
                }); container.append(button);
            }
        }
        if (!container.childNodes.length) {
            const empty = document.createElement('p'); empty.className = 'catalog-empty'; empty.textContent = 'No matching question types'; container.append(empty);
        }
        updateSelection();
    }
    function setGenerator(mode) {
        const control = document.querySelector(`input[name="generatorMode"][value="${mode}"]`);
        control.checked = true; control.dispatchEvent(new Event('change', {bubbles:true}));
        document.body.classList.toggle('classic-workspace', mode === 'classic');
        document.querySelector('label[for="studentId"]').textContent = mode === 'classic' ? 'Student ID' : 'Student ID (optional for Rhema)';
        byId('studentId').placeholder = mode === 'classic' ? 'Student ID' : 'Optional student ID';
        byId('studentId').required = mode === 'classic';
        if (mode === 'classic') byId('workspaceSelection').textContent = 'Classic generator';
    }
    function navigation(active) {
        for (const button of document.querySelectorAll('.workspace-nav-item')) button.classList.toggle('active', button.id === active);
        byId('grammarLibrary').hidden = active === 'generationHistoryBtn' || active === 'classicWorkspaceBtn';
        byId('sidebarHistory').hidden = active !== 'generationHistoryBtn';
    }
    function closeMobileSidebar() {
        if (innerWidth <= 768 && !byId('sidebar').classList.contains('collapsed')) byId('sidebarCollapseBtn').click();
    }
    document.addEventListener('rhema:catalog', event => {catalog = event.detail; renderCatalog();});
    document.addEventListener('rhema:preset-saved', event => {
        const name = event.detail.name;
        if (!catalog.some(item => item.name === name)) catalog.push({name, title:name.slice(0,-4).replaceAll('_',' '), custom:true});
        renderCatalog();
    });
    byId('grammarSearch').addEventListener('input', renderCatalog);
    byId('questionLibraryBtn').addEventListener('click', () => {library = 'all'; navigation('questionLibraryBtn'); byId('newQuestionBtn').click(); setGenerator('ag'); renderCatalog();});
    byId('presetLibraryBtn').addEventListener('click', () => {library = 'presets'; navigation('presetLibraryBtn'); byId('newQuestionBtn').click(); setGenerator('ag'); renderCatalog();});
    byId('generationHistoryBtn').addEventListener('click', () => navigation('generationHistoryBtn'));
    byId('classicWorkspaceBtn').addEventListener('click', () => {navigation('classicWorkspaceBtn'); byId('newQuestionBtn').click(); setGenerator('classic'); closeMobileSidebar();});
    byId('historyList').addEventListener('click', event => {if(event.target.closest('.history-item')) closeMobileSidebar();});
    select.addEventListener('change', () => {updateSelection(); stale();});
    for (const id of ['rhemaCount','studentId','rhemaQuestionSelect']) byId(id).addEventListener('input', stale);
    function stale() {
        if (byId('result').style.display === 'none') return;
        byId('previewQuestionCount').textContent = 'Settings changed';
        byId('previewQuestionCount').classList.add('stale');
    }
    document.addEventListener('workspace:settings', stale);
    function rendererState(ready) {
        const status = byId('rendererConnection'); status.dataset.ready = String(ready);
        status.textContent = ready ? 'WeBWorK connected' : 'WeBWorK offline';
    }
    async function checkRenderer() {
        try {const response = await fetch('/api/webwork/status'); const data = await response.json(); rendererState(Boolean(data.available));}
        catch {rendererState(false);}
    }
    function syncOutput() {
        const loading = byId('loading').style.display !== 'none';
        byId('previewPlaceholder').hidden = loading || byId('result').style.display !== 'none' || byId('error').style.display !== 'none';
        byId('generateQuestionsBtn').disabled = loading;
    }
    for (const id of ['result','loading','error']) new MutationObserver(syncOutput).observe(byId(id), {attributes:true, attributeFilter:['style']});
    document.addEventListener('rhema:language', () => {renderCatalog();});
    new MutationObserver(updateSelection).observe(document.body, {attributes:true, attributeFilter:['class']});
    window.workspaceUI = {
        rendererState,
        generated(data) {
            const isRhema = document.querySelector('input[name="generatorMode"]:checked').value === 'ag';
            const count = data.preview?.length || (isRhema ? Number(byId('rhemaCount').value) : null);
            byId('previewQuestionCount').textContent = count ? `${count} questions` : '';
            byId('previewQuestionCount').classList.remove('stale'); syncOutput();
        }
    };
    if (window.lucide) window.lucide.createIcons();
    byId('sidebarHistory').hidden = true;
    setGenerator('ag'); syncOutput(); checkRenderer();
});
