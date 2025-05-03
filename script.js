let domains = [];
let certs = [];
let currentPage = 1;
let currentFilter = 'all';
let itemsPerPageRaw = localStorage.getItem('itemsPerPage');
let itemsPerPage = itemsPerPageRaw === 'All'
    ? 9999
    : parseInt(itemsPerPageRaw) || 20;
let showDetails = localStorage.getItem('showDetails') === 'true';
let groupByServer = localStorage.getItem('groupByServer') === 'true';

document.addEventListener('DOMContentLoaded', () => {
    loadData();
    document.getElementById('loginBtn').addEventListener('click', toggleLoginForm);
    const settingsBtn = document.getElementById('settingsBtn');
    if (settingsBtn) {
        settingsBtn.addEventListener('click', () => {
            const panel = document.getElementById('settingsPanel');
            panel.style.display = panel.style.display === 'none' ? 'block' : 'none';
        });
    }
});

function loadData() {
    fetch('?fetch_domains=1')
        .then(response => response.json())
        .then(data => {
            domains = data.domains || [];
            certs = data.certs || [];
            updateLoginButton(data.logged_in);
            window.isLoggedIn = data.logged_in;

            if (window.isLoggedIn) {
                renderContent();
            } else {
                toggleLoginForm();
            }
        })
        .catch(err => console.error('Error loading data:', err));
}

function renderContent() {
    const content = document.getElementById('content');
    let html = '';

    if (window.isLoggedIn) {
        html += `
            <form id="addDomainForm" onsubmit="addDomain(event)">
                <input type="text" id="server" required placeholder="Server (hostname or IP)" required>
                <input type="text" id="domain" required placeholder="Domain (e.g. www.example.com)" required>
                <div class="port-wrapper">
                    <input type="text" id="port" value="443" required placeholder="Port" oninput="syncPortInput()">
                    <select id="portSelector" onchange="syncPortSelect()">
                    <option value="443">443 (HTTPS)</option>
                    <option value="465">465 (SMTP SSL)</option>
                    <option value="993">993 (IMAP SSL)</option>
                    <option value="995">995 (POP3 SSL)</option>
                    </select>
                </div>
                <button type="submit" class="btn-add">➕ Add Domain</button>
            </form>
            <h4>My Domains:</h4>
            <ul id="userDomainsList" class="user-domains">
                ${domains.map(d => `
                    <li>
                        <span>${d.domain}:${d.port}</span>
                        <button class="btn-delete" onclick="deleteDomain('${d.domain}')">❌ Delete</button>
                    </li>
                `).join('')}
            </ul>
        `;
    }

    html += `
        <h3>SSL Certificates Status</h3>
        <div class="options">
            <button onclick="toggleDetails()" id="detailsBtn"></button>
            <button onclick="toggleGroup()" id="groupBtn"></button>
        </div>
        <div class="tabs">
            <button onclick="setFilter('all')" id="tab-all" class="active">All (0)</button>
            <button onclick="setFilter('warning')" id="tab-warning">Warning (0)</button>
            <button onclick="setFilter('expired')" id="tab-expired">Expired (0)</button>
            <button onclick="setFilter('domains')" id="tab-domains">Domains (0)</button>
            <button onclick="setFilter('imap')" id="tab-imap">IMAP/POP (0)</button>
        </div>
        <div class="controls">
            <div class="search-wrapper">
                <input type="text" id="searchInput" placeholder="Search domains..." onkeyup="renderTable()">
            </div>
            <div class="per-page-group">
                <label for="itemsPerPageSelect"></label>
                <select id="itemsPerPageSelect" onchange="changeItemsPerPage()">
                    <option disabled selected>Show</option>
                    <option value="20">20</option>
                    <option value="50">50</option>
                    <option value="100">100</option>
                    <option value="All">All</option>
                </select>
            </div>
        </div>
        <table>
            <thead id="table-head"></thead>
            <tbody id="certs-table-body"></tbody>
        </table>
        <div class="pagination" id="pagination"></div>
    `;
    
    html += `
        <div id="settingsModal" class="modal" style="display: none;">
          <div class="modal-content">
          <h3>Configuration Settings</h3>
          <form id="settingsForm" onsubmit="saveSettings(event)">
          <label>API Key</label>         
          <input type="text" name="API_KEY" required placeholder="e.g. 123abcXYZ!@#">

          <label>Path to domains.list</label>
          <input type="text" name="DOMAINS_LIST" required placeholder="/home/YOURUSER/web/YOURDOMAIN/private/domains.list">

          <label>Path to cert_status.json</label>
          <input type="text" name="CERT_STATUS_JSON" required placeholder="/home/YOURUSER/web/YOURDOMAIN/private/cert_status.json">

          <label>Login Username</label>
          <input type="text" name="LOGIN_USER" required placeholder="e.g. admin">

          <label>Login Password</label>
          <div class="password-wrapper">
          <input type="password" name="LOGIN_PASS" id="loginPassInput" required placeholder="e.g. MystrongPass@123">
          <span class="toggle-eye" onclick="togglePasswordVisibility(this)">👁️</span>
          </div>

          <label>Session Timeout (seconds)</label>
          <input type="number" name="SESSION_TIMEOUT" required placeholder="e.g. 900">

          <div class="modal-actions">
            <button type="submit" class="btn-add">💾 Save</button>
            <button type="button" onclick="closeSettings()" class="btn-delete">Cancel</button>
          </div>
          </form>
          </div>
        </div>
    `;

    content.innerHTML = html;
    renderTable();
}

function setFilter(filter) {
    currentFilter = filter;
    document.querySelectorAll('.tabs button').forEach(btn => btn.classList.remove('active'));
    document.getElementById('tab-' + filter).classList.add('active');
    renderTable();
}

function toggleDetails() {
    showDetails = !showDetails;
    localStorage.setItem('showDetails', showDetails);
    renderTable();
}

function toggleGroup() {
    groupByServer = !groupByServer;
    localStorage.setItem('groupByServer', groupByServer);
    renderTable();
}

function renderTable() {
    const tableBody = document.getElementById('certs-table-body');
    const tableHead = document.getElementById('table-head');
    const searchTerm = document.getElementById('searchInput') ? document.getElementById('searchInput').value.toLowerCase() : '';

    let all = 0, warning = 0, expired = 0, domainsCount = 0, imap = 0;

    certs.forEach(item => {
        const status = item.status.toLowerCase();
        const port = parseInt(item.port);
        all++;
        if (status.includes('expired') || status.includes('error')) expired++;
        else if (item.days_left <= 15) warning++;
        if (port === 443) domainsCount++;
        if (port === 993 || port === 995) imap++;
    });

    document.getElementById('tab-all').innerText = `All (${all})`;
    document.getElementById('tab-warning').innerText = `Warning (${warning})`;
    document.getElementById('tab-expired').innerText = `Error/Expired (${expired})`;
    document.getElementById('tab-domains').innerText = `Domains (${domainsCount})`;
    document.getElementById('tab-imap').innerText = `IMAP/POP (${imap})`;

    let filtered = certs.filter(item => {
        const status = item.status.toLowerCase();
        const port = parseInt(item.port);
        if (currentFilter === 'warning') return item.days_left <= 15 && !status.includes('expired') && !status.includes('error');
        if (currentFilter === 'expired') return status.includes('expired') || status.includes('error');
        if (currentFilter === 'domains') return port === 443;
        if (currentFilter === 'imap') return port === 993 || port === 995;
        return true;
    }).filter(item => item.domain.toLowerCase().includes(searchTerm));

    const totalPages = Math.ceil(filtered.length / itemsPerPage);
    if (currentPage > totalPages) currentPage = 1;
    const start = (currentPage - 1) * itemsPerPage;
    const pageData = filtered.slice(start, start + itemsPerPage);

    tableBody.innerHTML = '';
    tableHead.innerHTML = `<tr>
        ${showDetails ? `<th>Server</th><th>Domain</th><th>Port</th>` : `<th>Domain</th>`}
        <th>Expires In (Days)</th>
        <th>Status</th>
    </tr>`;

    if (groupByServer) {
        const grouped = {};
        pageData.forEach(cert => {
            const server = cert.server || 'Unknown Server';
            if (!grouped[server]) grouped[server] = [];
            grouped[server].push(cert);
        });

        for (const server in grouped) {
            tableBody.innerHTML += `<tr><td colspan="${showDetails ? 5 : 3}" style="background:#f0f0f0;font-weight:bold;">Server: ${server}</td></tr>`;
            grouped[server].forEach(cert => {
                tableBody.innerHTML += createRow(cert);
            });
        }
    } else {
        pageData.forEach(cert => {
            tableBody.innerHTML += createRow(cert);
        });
    }

    const detailsBtn = document.getElementById('detailsBtn');
    const groupBtn = document.getElementById('groupBtn');
    if (detailsBtn) detailsBtn.textContent = showDetails ? 'Hide Extra Details' : 'Show All Details';
    if (groupBtn) groupBtn.textContent = groupByServer ? 'Ungroup' : 'Group by Server';

    renderPagination(totalPages);
    
    const select = document.getElementById('itemsPerPageSelect');
    if (select) {
        const currentValue = localStorage.getItem('itemsPerPage') || '20';
        select.value = currentValue;
    }
}

function createRow(cert) {
    let rowClass = '';
    const status = cert.status.toLowerCase();
    if (status.includes('expired') || status.includes('error')) rowClass = 'expired';
    else if (cert.days_left <= 15) rowClass = 'warning';
    else rowClass = 'valid';

    return `<tr class="${rowClass}">
        ${showDetails ? `<td>${cert.server}</td><td>${cert.domain}</td><td>${cert.port}</td>` : `<td>${cert.domain} ${cert.server ? '(' + cert.server + ')' : ''}</td>`}
        <td>${cert.days_left}</td>
        <td>${cert.status}</td>
    </tr>`;
}

function renderPagination(totalPages) {
    const pagination = document.getElementById('pagination');
    pagination.innerHTML = '';
    if (totalPages <= 1) return;
    if (currentPage > 1) pagination.innerHTML += `<button onclick="changePage(${currentPage - 1})">Prev</button>`;
    if (currentPage < totalPages) pagination.innerHTML += `<button onclick="changePage(${currentPage + 1})">Next</button>`;
}

function changePage(page) {
    currentPage = page;
    renderTable();
}

function addDomain(e) {
    e.preventDefault();
    const server = document.getElementById('server').value.trim();
    const domain = document.getElementById('domain').value.trim();
    const port = document.getElementById('port').value.trim() || '443';

    if (!server || !domain) {
        showNotification('Please enter both server and domain.', true);
        return;
    }

    fetch('', {
        method: 'POST',
        body: new URLSearchParams({
            api_key: window.API_KEY || '',
            server: server,
            domain: domain,
            port: port,
            action: 'add'
        })
    })
    .then(r => r.json())
    .then(data => {
        if (data.success) {
            showNotification('Domain added successfully!', false);
            document.getElementById('server').value = '';
            document.getElementById('domain').value = '';
            document.getElementById('port').value = '443';
            loadData();
        } else showNotification(data.message, true);
    })
    .catch(err => {
        console.error('Error adding domain:', err);
        showNotification('Error adding domain!', true);
    });
}

function deleteDomain(domain) {
    if (!confirm(`Are you sure you want to delete ${domain}?`)) return;
    fetch('', {
        method: 'POST',
        body: new URLSearchParams({
            api_key: window.API_KEY,
            domain: domain,
            action: 'delete'
        })
    })
    .then(r => r.json())
    .then(data => {
        if (data.success) {
            showNotification('Domain deleted successfully!', false);
            loadData();
        } else showNotification(data.message, true);
    })
    .catch(err => {
        console.error('Error deleting domain:', err);
        showNotification('Error deleting domain!', true);
    });
}

function showNotification(message, isError) {
    let notification = document.getElementById('notification');
    if (!notification) {
        notification = document.createElement('div');
        notification.id = 'notification';
        document.body.appendChild(notification);
    }
    notification.className = isError ? 'show error' : 'show';
    notification.textContent = message;
    setTimeout(() => { notification.className = ''; }, 3000);
}

function toggleLoginForm() {
    const content = document.getElementById('content');
    if (window.isLoggedIn) {
        fetch('', {
            method: 'POST',
            body: new URLSearchParams({ logout: true })
        }).then(r => r.json()).then(() => {
            window.isLoggedIn = false;
            loadData();
        });
    } else {
        content.innerHTML = `
            <form id="loginForm" onsubmit="login(event)">
                <input type="text" id="username" placeholder="Username" required>
                <input type="password" id="password" placeholder="Password" required>
                <button type="submit">Login</button>
            </form>
        `;
    }
}

function login(e) {
    e.preventDefault();
    const username = document.getElementById('username').value.trim();
    const password = document.getElementById('password').value.trim();

    fetch('', {
        method: 'POST',
        body: new URLSearchParams({
            login: true,
            username: username,
            password: password
        })
    })
    .then(r => r.json())
    .then(data => {
        if (data.success) {
            window.isLoggedIn = true;
            loadData();
        } else showNotification(data.message, true);
    })
    .catch(err => {
        console.error('Error logging in:', err);
        showNotification('Error logging in!', true);
    });
}

function updateLoginButton(isLogged) {
    const btn = document.getElementById('loginBtn');
    const settingsBtn = document.getElementById('settingsBtn');
    window.isLoggedIn = isLogged;

    if (isLogged) {
        btn.style.display = 'inline-block';
        btn.textContent = '➡️ Logout';
        if (settingsBtn) settingsBtn.style.display = 'inline-block';
    } else {
        btn.style.display = 'none';
        if (settingsBtn) settingsBtn.style.display = 'none';
    }
}

function changeItemsPerPage() {
    const select = document.getElementById('itemsPerPageSelect');
    const value = select.value;
    localStorage.setItem('itemsPerPage', value);

    if (value === 'All') {
        itemsPerPage = 9999;
    } else {
        itemsPerPage = parseInt(value);
    }

    currentPage = 1;
    renderTable();
}

function saveSettings(e) {
    e.preventDefault();
    const form = e.target;
    const data = new FormData(form);

    // Fallback in case window.API_KEY wasn't set properly
    if (!window.API_KEY || window.API_KEY === 'null') {
        console.warn('API_KEY fallback applied');
        window.API_KEY = 'abc123'; // <-- βάλε εδώ το σωστό key αν κάνεις τοπικά dev
    }

    // Prepare POST data
    const postData = new URLSearchParams([
        ...data.entries(),
        ['action', 'save_settings'],
        ['api_key', window.API_KEY]
    ]);

    fetch('', {
        method: 'POST',
        body: postData
    })
    .then(response => response.json())
    .then(res => {
        if (res.success) {
            showNotification('Settings saved!', false);
            closeSettings(); // Hide modal
        } else {
            showNotification(res.message || 'Failed to save settings.', true);
        }
    })
    .catch(err => {
        console.error('Error saving settings:', err);
        showNotification('Error communicating with server.', true);
    });
}

document.getElementById('settingsBtn').addEventListener('click', () => {
    document.getElementById('settingsModal').style.display = 'flex';
    loadSettingsToForm();
});

function closeSettings() {
    document.getElementById('settingsModal').style.display = 'none';
}

function loadSettingsToForm() {
    fetch('?get_settings=1')
        .then(res => res.json())
        .then(config => {
            const form = document.getElementById('settingsForm');
            if (!form) return;

            for (const key in config) {
                if (form.elements[key]) {
                    form.elements[key].value = config[key];
                }
            }
        })
        .catch(err => {
            console.error('Failed to load settings:', err);
            showNotification('Failed to load config settings.', true);
        });
}

function togglePasswordVisibility(el) {
    const input = document.getElementById('loginPassInput');
    if (!input) return;

    if (input.type === 'password') {
        input.type = 'text';
        el.textContent = '🙈';
    } else {
        input.type = 'password';
        el.textContent = '👁️';
    }
}

function syncPortSelect() {
    const selector = document.getElementById('portSelector');
    const portInput = document.getElementById('port');
    if (selector && portInput) {
        portInput.value = selector.value;
    }
}

function syncPortInput() {
    const portInput = document.getElementById('port');
    const portSelector = document.getElementById('portSelector');
    if (!portInput || !portSelector) return;

    const value = portInput.value.trim();

    let found = false;
    for (const opt of portSelector.options) {
        if (opt.value === value) {
            portSelector.value = value;
            found = true;
            break;
        }
    }

    if (!found) {
        portSelector.value = ''; // deselect if not a known option
    }
}
