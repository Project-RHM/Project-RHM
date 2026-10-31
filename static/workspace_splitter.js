document.addEventListener('DOMContentLoaded', () => {
    const layout = document.querySelector('.authoring-layout');
    const divider = document.getElementById('workspaceDivider');
    if (!layout || !divider) return;

    const storageKey = 'rhema.workspaceSplit';
    const desktop = matchMedia('(min-width: 961px)');
    const gutter = 12, minimumSettings = 280, minimumPreview = 320;
    let ratio = null, drag = null;
    try {
        const saved = localStorage.getItem(storageKey);
        const value = Number(saved);
        if (saved !== null && Number.isFinite(value) && value > 0 && value < 1) ratio = value;
    } catch {}

    function bounds() {
        const available = Math.max(0, layout.getBoundingClientRect().width - gutter);
        const minimum = Math.min(minimumSettings, available / 2);
        return {available, minimum, maximum:Math.max(minimum, available - minimumPreview)};
    }
    function currentWidth() {
        return document.getElementById('studentForm').getBoundingClientRect().width;
    }
    function apply() {
        divider.hidden = !desktop.matches;
        divider.tabIndex = desktop.matches ? 0 : -1;
        if (!desktop.matches) return;
        const {available, minimum, maximum} = bounds();
        if (!available) return;
        const defaultWidth = parseFloat(getComputedStyle(layout).getPropertyValue('--default-settings-width')) || 420;
        const width = Math.min(maximum, Math.max(minimum, ratio === null ? defaultWidth : ratio * available));
        layout.style.setProperty('--settings-pane-width', `${width}px`);
        divider.setAttribute('aria-valuemin', String(Math.round(minimum)));
        divider.setAttribute('aria-valuemax', String(Math.round(maximum)));
        divider.setAttribute('aria-valuenow', String(Math.round(width)));
        const t = text => window.RhemaI18n?.t(text) || text;
        const percent = Math.round(width / available * 100);
        divider.setAttribute('aria-valuetext', `${t('Question settings')} ${percent}%, ${t('Question preview')} ${100 - percent}%`);
    }
    function persist() {
        try {
            if (ratio === null) localStorage.removeItem(storageKey);
            else localStorage.setItem(storageKey, String(ratio));
        } catch {}
    }
    function resize(width) {
        const {available, minimum, maximum} = bounds();
        if (!available) return;
        ratio = Math.min(maximum, Math.max(minimum, width)) / available;
        apply();
    }
    function finish(save = true) {
        if (!drag) return;
        const {pointerId} = drag;
        drag = null;
        document.body.classList.remove('workspace-resizing');
        if (divider.hasPointerCapture(pointerId)) divider.releasePointerCapture(pointerId);
        if (save) persist();
    }
    divider.addEventListener('pointerdown', event => {
        if (!desktop.matches || event.button !== 0 || event.isPrimary === false) return;
        event.preventDefault();
        drag = {pointerId:event.pointerId, x:event.clientX, width:currentWidth(), previous:ratio};
        divider.setPointerCapture(event.pointerId);
        divider.focus({preventScroll:true});
        document.body.classList.add('workspace-resizing');
    });
    divider.addEventListener('pointermove', event => {
        if (drag?.pointerId === event.pointerId) resize(drag.width + event.clientX - drag.x);
    });
    divider.addEventListener('pointerup', () => finish());
    divider.addEventListener('pointercancel', () => finish());
    divider.addEventListener('lostpointercapture', () => finish());
    window.addEventListener('blur', () => finish());
    divider.addEventListener('dblclick', () => {ratio = null; apply(); persist();});
    divider.addEventListener('keydown', event => {
        if (!desktop.matches) return;
        if (event.key === 'Escape' && drag) {
            ratio = drag.previous; finish(false); apply(); return;
        }
        const step = event.shiftKey ? 48 : 16;
        const {minimum, maximum} = bounds();
        const widths = {ArrowLeft:currentWidth() - step, ArrowRight:currentWidth() + step, Home:minimum, End:maximum};
        if (!(event.key in widths)) return;
        event.preventDefault(); resize(widths[event.key]); persist();
    });
    desktop.addEventListener('change', () => {finish(); apply();});
    new ResizeObserver(apply).observe(layout);
    document.addEventListener('rhema:language', apply);
    apply();
});
