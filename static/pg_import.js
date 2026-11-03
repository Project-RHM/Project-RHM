/* Imported PG stays in this page; only an explicit Render sends it to WeBWorK. */
document.addEventListener('DOMContentLoaded', () => {
    const byId = id => document.getElementById(id);
    const page = byId('pgImportContent');
    const source = byId('pgImportSource'), input = byId('pgImportFile');
    const render = byId('pgImportRender'), clear = byId('pgImportClear');
    const dropzone = byId('pgImportDropzone'), message = byId('pgImportMessage');
    const limit = Number(page.dataset.maxSourceBytes);
    let readVersion = 0, renderVersion = 0;

    function showMessage(text = '') {
        message.textContent = text;
        message.hidden = !text;
    }
    function clearFile(resetSeed = false) {
        readVersion++; renderVersion++;
        source.value = ''; input.value = '';
        byId('pgImportTitle').textContent = 'No file selected';
        byId('pgImportTitle').removeAttribute('data-no-translate');
        byId('pgImportFileInfo').hidden = true;
        byId('pgImportFilename').textContent = '';
        byId('pgImportFilesize').textContent = '';
        byId('pgImportSourcePanel').open = false;
        render.disabled = true; clear.disabled = true;
        render.querySelector('span').textContent = 'Render';
        if (resetSeed) byId('pgImportSeed').value = '1';
        showMessage();
        invalidateProblemPreview('import', 'No PG file loaded', 'empty');
    }
    async function loadFiles(files) {
        const choices = Array.from(files);
        clearFile();
        const version = readVersion;
        if (choices.length !== 1) { showMessage('Choose one .pg file at a time.'); return; }
        const file = choices[0];
        if (!/\.pg$/i.test(file.name)) { showMessage('Choose a .pg file.'); return; }
        if (!file.size) { showMessage('The selected file is empty.'); return; }
        if (file.size > limit) { showMessage('The selected file exceeds the PG preview size limit.'); return; }
        clear.disabled = false;
        previewStatus(previewElements('import'), 'Reading PG file...', 'loading');
        try {
            const bytes = await file.arrayBuffer();
            if (version !== readVersion) return;
            const text = new TextDecoder('utf-8', {fatal:true}).decode(bytes).replace(/^\uFEFF/, '');
            if (!text.trim()) throw new Error('The selected file is empty.');
            if (text.includes('\0')) throw new Error('Choose a UTF-8 text PG file.');
            if (!text.includes('DOCUMENT();') || !text.includes('ENDDOCUMENT();')) {
                throw new Error('Choose a complete PG document with DOCUMENT(); and ENDDOCUMENT();.');
            }
            source.value = text;
            byId('pgImportTitle').textContent = file.name;
            byId('pgImportTitle').dataset.noTranslate = '';
            byId('pgImportFilename').textContent = file.name;
            byId('pgImportFilesize').textContent = file.size.toLocaleString() + ' bytes';
            byId('pgImportFileInfo').hidden = false;
            render.disabled = false;
            invalidateProblemPreview('import', 'Ready to render', 'empty');
        } catch (error) {
            if (version !== readVersion) return;
            clear.disabled = true;
            showMessage(error instanceof TypeError ? 'Choose a UTF-8 text PG file.' : error.message);
            invalidateProblemPreview('import', 'No PG file loaded', 'empty');
        }
    }
    byId('pgChooseFile').addEventListener('click', () => input.click());
    input.addEventListener('change', () => { if (input.files.length) return loadFiles(input.files); });
    for (const type of ['dragenter','dragover']) dropzone.addEventListener(type, event => {
        event.preventDefault(); dropzone.classList.add('dragging');
    });
    dropzone.addEventListener('dragleave', event => {
        if (!dropzone.contains(event.relatedTarget)) dropzone.classList.remove('dragging');
    });
    dropzone.addEventListener('drop', event => {
        event.preventDefault(); dropzone.classList.remove('dragging');
        return loadFiles(event.dataTransfer.files);
    });
    // Prevent a missed drop from navigating away and discarding the workspace.
    page.addEventListener('dragover', event => event.preventDefault());
    page.addEventListener('drop', event => event.preventDefault());
    clear.addEventListener('click', () => clearFile(true));
    byId('pgImportSeed').addEventListener('input', () => {
        renderVersion++;
        render.disabled = !source.value;
        render.querySelector('span').textContent = 'Render';
    });
    render.addEventListener('click', async () => {
        const seed = byId('pgImportSeed');
        if (!seed.checkValidity()) { seed.reportValidity(); return; }
        const version = ++renderVersion;
        render.disabled = true;
        render.querySelector('span').textContent = 'Rendering...';
        await renderProblemPreview('import', true);
        if (version !== renderVersion) return;
        render.disabled = !source.value;
        render.querySelector('span').textContent = 'Render';
    });
    byId('importCheckAnswers').addEventListener('click', () => checkPreviewAnswers('import'));
});
