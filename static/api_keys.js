/* Only credential status lives in the browser; validation happens server-side. */
(() => {
    const byId = id => document.getElementById(id);
    let status = {has_api_key:false, verified:false, available:false}, busy = false;
    try { localStorage.removeItem('lastApiKey'); } catch {}
    function update() {
        hasApiKey = Boolean(status.verified && status.available);
        const text = !status.has_api_key ? 'API key not configured' : !status.verified
            ? 'Saved key needs validation' : !status.available ? 'Verified key: insufficient balance' : 'API key verified';
        byId('apiKeyInfo').style.display = 'flex';
        byId('apiKeyStatusText').textContent = text;
        byId('apiKeyStatusText').style.color = hasApiKey ? '#315c46' : '#7a343b';
        byId('editApiKeyBtn').style.display = status.has_api_key ? 'inline-block' : 'none';
        byId('removeApiKeyBtn').hidden = !status.has_api_key;
        byId('apiKeyVerifiedAt').textContent = status.verified_at ? 'Verified at: ' + new Date(status.verified_at).toLocaleString() : '';
        if (!hasApiKey) byId('addContextCheckbox').checked = false;
    }
    function message(text, error=false) {
        const box = byId('apiKeyMessage');
        box.textContent = text; box.className = 'message ' + (error ? 'error' : 'success'); box.style.display = text ? 'block' : 'none';
    }
    function pending(value) {
        busy = value;
        for (const id of ['saveApiKeyBtn','removeApiKeyBtn','cancelApiKeyBtn','apiKeyInput']) byId(id).disabled = value;
        byId('apiKeyModal').querySelector('.api-close-btn').disabled = value;
        byId('saveApiKeyBtn').textContent = value ? 'Validating...' : 'Validate and save';
    }
    window.checkApiKeyStatus = async () => {
        try {
            const response = await fetch('/api_key_status', {cache:'no-store'});
            if (!response.ok) throw new Error();
            status = await response.json(); update();
        } catch { status = {has_api_key:false}; update(); }
    };
    window.updateAddContextUI = update;
    function open() {
        if (busy) return;
        byId('apiKeyInput').value = '';
        message(''); update();
        byId('apiKeyModal').style.display = 'block';
        byId('apiKeyInput').focus();
    }
    window.showEditApiKeyModal = open;
    window.showApiKeyModal = open;
    window.saveApiKey = async () => {
        if (busy) return;
        const key = byId('apiKeyInput').value.trim();
        if (!key) { message('Enter a DeepSeek API key.',true); return; }
        pending(true); message('Validating with DeepSeek...');
        try {
            const response = await fetch('/save_api_key', {method:'POST', headers:{'Content-Type':'application/x-www-form-urlencoded'},
                body:new URLSearchParams({api_key:key})});
            const data = await response.json();
            if (!response.ok || !data.success) throw new Error(data.error || 'Validation failed.');
            status = data; update(); byId('apiKeyInput').value = ''; message(data.message);
        } catch (error) { message(error.message,true); }
        finally { pending(false); }
    };
    document.addEventListener('DOMContentLoaded', () => {
        byId('removeApiKeyBtn').addEventListener('click', async () => {
            if (busy || !confirm('Remove the saved API key from this application? This does not revoke it at DeepSeek.')) return;
            pending(true);
            try {
                const response = await fetch('/api_key', {method:'DELETE'});
                const data = await response.json();
                if (!response.ok || !data.success) throw new Error(data.error || 'Could not remove the key.');
                try { localStorage.removeItem('lastApiKey'); } catch {}
                status = data; byId('apiKeyInput').value = ''; update(); message('Saved API key removed.');
            } catch (error) { message(error.message,true); }
            finally { pending(false); }
        });
    });
})();
