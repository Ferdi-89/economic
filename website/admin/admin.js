/* ═══════════════════════════════════════════════
   FINANCIER ADMIN — JAVASCRIPT
   Full Admin Control Center
   ═══════════════════════════════════════════════ */

'use strict';

// ── STATE ────────────────────────────────────────
const STATE = {
  supabaseUrl: '',
  supabaseKey: '',
  sb: null,
  currentPage: 'dashboard',
  adminPassword: '',
  charts: {},
  log: [],
  pagination: {},
  pageSize: 20,
  searchTimers: {},
  userCache: {}, // id -> {full_name, email, avatar_url}
};

// ── STORAGE ──────────────────────────────────────
const STORE = {
  get: k => { try { return JSON.parse(localStorage.getItem('fadmin_' + k)); } catch { return null; } },
  set: (k, v) => localStorage.setItem('fadmin_' + k, JSON.stringify(v)),
  del: k => localStorage.removeItem('fadmin_' + k),
};

// ── UTILS ────────────────────────────────────────
const $ = id => document.getElementById(id);
const fmt = {
  currency: (n, cur = 'IDR') => new Intl.NumberFormat('id-ID', { style: 'currency', currency: cur, maximumFractionDigits: 0 }).format(n || 0),
  number: n => new Intl.NumberFormat('id-ID').format(n || 0),
  date: d => d ? new Intl.DateTimeFormat('id-ID', { day: '2-digit', month: 'short', year: 'numeric' }).format(new Date(d)) : '—',
  dateTime: d => d ? new Intl.DateTimeFormat('id-ID', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }).format(new Date(d)) : '—',
  relTime: d => { if (!d) return '—'; const s = Math.floor((Date.now() - new Date(d)) / 1000); if (s < 60) return 'baru saja'; if (s < 3600) return `${Math.floor(s/60)} mnt lalu`; if (s < 86400) return `${Math.floor(s/3600)} jam lalu`; return `${Math.floor(s/86400)} hari lalu`; },
  initials: name => name ? name.split(' ').map(w => w[0]).slice(0,2).join('').toUpperCase() : '?',
  truncate: (s, n=40) => s && s.length > n ? s.slice(0,n) + '…' : (s || '—'),
};

const COLORS = ['#6366f1','#10b981','#f59e0b','#ec4899','#8b5cf6','#06b6d4','#ef4444','#14b8a6','#f97316','#84cc16'];
const avatarColor = name => { if (!name) return '#6366f1'; let h = 0; for (let c of name) h = (h * 31 + c.charCodeAt(0)) & 0xffffffff; return COLORS[Math.abs(h) % COLORS.length]; };

function esc(s) {
  if (!s) return '';
  return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

// ── TOAST ────────────────────────────────────────
function toast(msg, type = 'info', dur = 3500) {
  const icons = { success: '✓', error: '✕', info: 'ℹ', warning: '⚠' };
  const el = document.createElement('div');
  el.className = `toast ${type}`;
  el.innerHTML = `<span>${icons[type]}</span><span>${esc(msg)}</span>`;
  $('toast-container').appendChild(el);
  setTimeout(() => { el.classList.add('toast-out'); setTimeout(() => el.remove(), 300); }, dur);
}

// ── LOG ──────────────────────────────────────────
function adminLog(msg, type = 'info') {
  const entry = { msg, type, time: new Date() };
  STATE.log.unshift(entry);
  if (STATE.log.length > 100) STATE.log.pop();
  STORE.set('log', STATE.log);
  renderLog();
}

function renderLog() {
  const el = $('admin-log');
  if (!el) return;
  if (!STATE.log.length) { el.innerHTML = '<div class="loading-row">Belum ada aktivitas.</div>'; return; }
  el.innerHTML = STATE.log.slice(0,50).map(e => `
    <div class="log-item">
      <span class="log-time">${fmt.dateTime(e.time)}</span>
      <span class="log-msg">${esc(e.msg)}</span>
      <span class="log-type ${e.type}">${e.type.toUpperCase()}</span>
    </div>
  `).join('');
}

// ── CONFIRM DIALOG ───────────────────────────────
function confirm(title, msg, icon = '⚠️') {
  return new Promise(resolve => {
    $('confirm-title').textContent = title;
    $('confirm-msg').textContent = msg;
    $('confirm-icon').textContent = icon;
    $('confirm-overlay').classList.remove('hidden');
    const ok = $('confirm-ok');
    const cancel = $('confirm-cancel');
    const close = () => { $('confirm-overlay').classList.add('hidden'); };
    ok.onclick = () => { close(); resolve(true); };
    cancel.onclick = () => { close(); resolve(false); };
  });
}

// ── MODAL ────────────────────────────────────────
function openModal(title, bodyHtml, footerHtml = '') {
  $('modal-title').textContent = title;
  $('modal-body').innerHTML = bodyHtml;
  $('modal-footer').innerHTML = footerHtml;
  $('modal-overlay').classList.remove('hidden');
}
function closeModal() { $('modal-overlay').classList.add('hidden'); }

// ── SUPABASE CLIENT ──────────────────────────────
function createClient(url, key) {
  return window.supabase.createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { 'apikey': key, 'Authorization': `Bearer ${key}` } }
  });
}

// ── LOGIN ────────────────────────────────────────
async function doLogin(e) {
  e.preventDefault();
  const url = $('inp-url').value.trim().replace(/\/$/, '');
  const key = $('inp-key').value.trim();
  const pw = $('inp-adminpw').value;

  if (!url || !key) { showLoginError('URL dan Service Role Key wajib diisi.'); return; }

  // Validate admin password
  const storedPw = STORE.get('adminpw');
  if (storedPw) {
    if (pw !== storedPw) { showLoginError('Password admin salah.'); return; }
  } else {
    if (!pw || pw.length < 4) { showLoginError('Buat password admin (min. 4 karakter) untuk penggunaan pertama.'); return; }
    STORE.set('adminpw', pw);
  }

  $('login-txt').textContent = 'Menghubungkan...';
  $('login-spin').classList.remove('hidden');

  try {
    const client = createClient(url, key);
    // Test connection
    const { error } = await client.from('profiles').select('id', { count: 'exact', head: true });
    if (error && error.code !== 'PGRST116') throw error;

    STATE.supabaseUrl = url;
    STATE.supabaseKey = key;
    STATE.adminPassword = pw;
    STATE.sb = client;

    STORE.set('url', url);
    STORE.set('key', key);

    adminLog(`Login berhasil. URL: ${url}`, 'success');
    toast('Berhasil terhubung ke Supabase!', 'success');
    bootApp();
  } catch (err) {
    showLoginError(`Gagal terhubung: ${err.message}`);
    adminLog(`Login gagal: ${err.message}`, 'danger');
  } finally {
    $('login-txt').textContent = 'Masuk ke Admin Panel';
    $('login-spin').classList.add('hidden');
  }
}

function showLoginError(msg) {
  const el = $('login-error');
  el.textContent = msg;
  el.classList.remove('hidden');
}

// ── BOOT APP ─────────────────────────────────────
function bootApp() {
  $('login-screen').classList.add('hidden');
  $('admin-app').classList.remove('hidden');

  // Set topbar info
  const short = STATE.supabaseUrl.replace('https://', '').split('.')[0];
  $('db-url-tag').textContent = short + '.supabase.co';
  $('set-url').value = STATE.supabaseUrl;
  $('set-key').value = STATE.supabaseKey;

  // Load log
  const saved = STORE.get('log');
  if (saved) STATE.log = saved;
  renderLog();

  // Init charts (create empty, fill later)
  initCharts();

  // Navigate to dashboard
  navigate('dashboard');
}

// ── NAVIGATION ───────────────────────────────────
function navigate(page) {
  STATE.currentPage = page;
  document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
  document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));

  const pageEl = $('page-' + page);
  if (pageEl) pageEl.classList.add('active');

  const navEl = document.querySelector(`.nav-item[data-page="${page}"]`);
  if (navEl) navEl.classList.add('active');

  const titles = {
    dashboard: 'Dashboard', users: 'Pengguna', transactions: 'Transaksi',
    accounts: 'Rekening', budgets: 'Anggaran', categories: 'Kategori',
    bills: 'Tagihan', goals: 'Tujuan Tabungan', debts: 'Hutang & Piutang',
    wishlist: 'Wishlist', analytics: 'Analitik', settings: 'Pengaturan',
  };
  $('page-title').textContent = titles[page] || page;

  loadPage(page);
}

function loadPage(page) {
  switch (page) {
    case 'dashboard': loadDashboard(); break;
    case 'users': loadUsers(); break;
    case 'transactions': loadTransactions(); break;
    case 'accounts': loadAccounts(); break;
    case 'budgets': loadBudgets(); break;
    case 'categories': loadCategories(); break;
    case 'bills': loadBills(); break;
    case 'goals': loadGoals(); break;
    case 'debts': loadDebts(); break;
    case 'wishlist': loadWishlist(); break;
    case 'analytics': loadAnalytics(); break;
    case 'settings': loadSettings(); break;
  }
}

// ── INIT CHARTS ──────────────────────────────────
function initCharts() {
  Chart.defaults.color = '#9499b0';
  Chart.defaults.borderColor = 'rgba(255,255,255,0.06)';
  Chart.defaults.font.family = 'Inter';
}

function makeChart(id, type, labels, datasets, opts = {}) {
  const el = $(id);
  if (!el) return null;
  if (STATE.charts[id]) STATE.charts[id].destroy();
  STATE.charts[id] = new Chart(el, {
    type,
    data: { labels, datasets },
    options: {
      responsive: true,
      plugins: {
        legend: { display: opts.legend ?? false, position: 'bottom', labels: { padding: 16, font: { size: 12 } } },
        tooltip: { backgroundColor: '#1d1f2e', borderColor: 'rgba(255,255,255,0.1)', borderWidth: 1, padding: 10, titleFont: { size: 12 }, bodyFont: { size: 12 } },
      },
      scales: type === 'doughnut' || type === 'pie' ? {} : {
        x: { grid: { color: 'rgba(255,255,255,0.04)' }, ticks: { font: { size: 11 } } },
        y: { grid: { color: 'rgba(255,255,255,0.04)' }, ticks: { font: { size: 11 } }, beginAtZero: true, ...(opts.yTicks || {}) },
      },
      animation: { duration: 400 },
      ...opts.extra,
    },
  });
  return STATE.charts[id];
}

// ── DASHBOARD ────────────────────────────────────
async function loadDashboard() {
  const sb = STATE.sb;

  try {
    // Parallel stats fetch
    const [
      { count: userCount },
      { count: txnCount },
      { count: accCount },
      { count: budgetActiveCount },
      { count: billPendingCount },
    ] = await Promise.all([
      sb.from('profiles').select('*', { count: 'exact', head: true }),
      sb.from('transactions').select('*', { count: 'exact', head: true }),
      sb.from('accounts').select('*', { count: 'exact', head: true }),
      sb.from('budgets').select('*', { count: 'exact', head: true }).eq('is_active', true),
      sb.from('bills').select('*', { count: 'exact', head: true }).eq('status', 'pending'),
    ]);

    $('sv-users').textContent = fmt.number(userCount);
    $('sv-txn').textContent = fmt.number(txnCount);
    $('sv-acc').textContent = fmt.number(accCount);
    $('sv-budget').textContent = fmt.number(budgetActiveCount);
    $('sv-bills').textContent = fmt.number(billPendingCount);

    $('badge-users').textContent = userCount || 0;

    // Volume
    const { data: volData } = await sb.from('transactions').select('amount').eq('status', 'completed');
    const vol = (volData || []).reduce((s, r) => s + Number(r.amount), 0);
    $('sv-vol').textContent = fmt.currency(vol);
    $('ss-vol').textContent = 'total semua transaksi selesai';
    $('ss-users').textContent = 'pengguna terdaftar';
    $('ss-txn').textContent = 'semua transaksi';
    $('ss-acc').textContent = 'rekening aktif';
    $('ss-budget').textContent = 'anggaran aktif';
    $('ss-bills').textContent = 'belum dibayar';

    // Recent users
    const { data: recentUsers } = await sb.from('profiles').select('id,full_name,email,created_at,default_currency').order('created_at', { ascending: false }).limit(6);
    $('recent-users').innerHTML = (recentUsers || []).map(u => `
      <div class="recent-item">
        <div class="recent-avatar" style="background:${avatarColor(u.full_name || u.email)}">${fmt.initials(u.full_name || u.email)}</div>
        <div class="recent-info">
          <div class="recent-name">${esc(u.full_name || '—')}</div>
          <div class="recent-sub">${esc(u.email)}</div>
        </div>
        <div class="recent-val" style="color:var(--text3);font-size:11px">${fmt.relTime(u.created_at)}</div>
      </div>
    `).join('') || '<div class="loading-row">Tidak ada data.</div>';

    // Recent transactions
    const { data: recentTxns } = await sb.from('transactions').select('id,amount,type,date,note,user_id').order('created_at', { ascending: false }).limit(6);
    // Pre-fetch user names
    if (recentTxns) {
      const uids = [...new Set(recentTxns.map(t => t.user_id).filter(Boolean))];
      await cacheUsers(uids);
    }
    $('recent-txns').innerHTML = (recentTxns || []).map(t => {
      const u = STATE.userCache[t.user_id] || {};
      const cls = t.type === 'income' ? 'money-pos' : t.type === 'expense' ? 'money-neg' : 'money-neu';
      return `
        <div class="recent-item">
          <div class="recent-info">
            <div class="recent-name">${esc(t.note || '(Tanpa catatan)')}</div>
            <div class="recent-sub">${esc(u.full_name || u.email || 'Unknown')} · ${fmt.date(t.date)}</div>
          </div>
          <div class="recent-val ${cls}">${t.type === 'income' ? '+' : t.type === 'expense' ? '-' : ''}${fmt.currency(t.amount)}</div>
        </div>
      `;
    }).join('') || '<div class="loading-row">Tidak ada data.</div>';

    // Chart: daily transactions (30 days)
    await loadDailyChart(30);

    // Chart: account types
    const { data: accTypes } = await sb.from('accounts').select('type');
    const typeCounts = {};
    (accTypes || []).forEach(a => { typeCounts[a.type] = (typeCounts[a.type] || 0) + 1; });
    const typeLabels = { cash: 'Tunai', bank: 'Bank', ewallet: 'E-Wallet', savings: 'Tabungan', investment: 'Investasi' };
    makeChart('chart-account-types', 'doughnut',
      Object.keys(typeCounts).map(k => typeLabels[k] || k),
      [{ data: Object.values(typeCounts), backgroundColor: COLORS, borderWidth: 2, borderColor: '#161821' }],
      { legend: true }
    );

    // Sys summary
    const { count: catCount } = await sb.from('categories').select('*', { count: 'exact', head: true });
    const { count: goalCount } = await sb.from('saving_goals').select('*', { count: 'exact', head: true });
    const { count: debtCount } = await sb.from('debts').select('*', { count: 'exact', head: true });
    const { count: wishCount } = await sb.from('wishlist').select('*', { count: 'exact', head: true });
    $('sys-summary').innerHTML = [
      ['Kategori', catCount],
      ['Target Tabungan', goalCount],
      ['Hutang & Piutang', debtCount],
      ['Wishlist Items', wishCount],
      ['Anggaran Total', budgetActiveCount],
      ['Bill Pending', billPendingCount],
    ].map(([k, v]) => `<div class="sys-row"><span class="sys-key">${k}</span><span class="sys-val">${fmt.number(v)}</span></div>`).join('');

  } catch (err) {
    toast('Gagal memuat dashboard: ' + err.message, 'error');
    console.error(err);
  }
}

async function loadDailyChart(days) {
  const since = new Date();
  since.setDate(since.getDate() - days);
  const { data } = await STATE.sb.from('transactions')
    .select('date,type,amount')
    .gte('date', since.toISOString().split('T')[0])
    .eq('status', 'completed');

  const dayMap = {};
  for (let i = 0; i < days; i++) {
    const d = new Date();
    d.setDate(d.getDate() - (days - 1 - i));
    dayMap[d.toISOString().split('T')[0]] = { income: 0, expense: 0 };
  }
  (data || []).forEach(t => {
    if (dayMap[t.date]) {
      if (t.type === 'income') dayMap[t.date].income += Number(t.amount);
      if (t.type === 'expense') dayMap[t.date].expense += Number(t.amount);
    }
  });

  const labels = Object.keys(dayMap).map(d => { const dt = new Date(d); return `${dt.getDate()}/${dt.getMonth()+1}`; });
  makeChart('chart-txn-daily', 'line', labels, [
    { label: 'Pemasukan', data: Object.values(dayMap).map(v => v.income), borderColor: '#10b981', backgroundColor: 'rgba(16,185,129,0.08)', tension: 0.4, fill: true, pointRadius: 0 },
    { label: 'Pengeluaran', data: Object.values(dayMap).map(v => v.expense), borderColor: '#ef4444', backgroundColor: 'rgba(239,68,68,0.08)', tension: 0.4, fill: true, pointRadius: 0 },
  ], { legend: true, yTicks: { callback: v => 'Rp' + fmt.number(v/1000) + 'K' } });
}

// ── USER CACHE ───────────────────────────────────
async function cacheUsers(ids) {
  const missing = ids.filter(id => !STATE.userCache[id]);
  if (!missing.length) return;
  const { data } = await STATE.sb.from('profiles').select('id,full_name,email,avatar_url').in('id', missing);
  (data || []).forEach(u => { STATE.userCache[u.id] = u; });
}

// ── GENERIC TABLE LOADER ──────────────────────────
function buildPagination(containerId, total, page, pageSize, onPage) {
  const totalPages = Math.ceil(total / pageSize);
  const el = $(containerId);
  if (!el) return;
  if (totalPages <= 1) { el.innerHTML = ''; return; }

  let html = `<button class="page-btn" ${page <= 1 ? 'disabled' : ''} onclick="(${onPage})(${page - 1})">‹</button>`;
  const range = [];
  for (let p = 1; p <= totalPages; p++) {
    if (p === 1 || p === totalPages || (p >= page - 2 && p <= page + 2)) range.push(p);
    else if (range[range.length-1] !== '…') range.push('…');
  }
  range.forEach(p => {
    if (p === '…') html += `<span class="page-btn">…</span>`;
    else html += `<button class="page-btn ${p === page ? 'active' : ''}" onclick="(${onPage})(${p})">${p}</button>`;
  });
  html += `<button class="page-btn" ${page >= totalPages ? 'disabled' : ''} onclick="(${onPage})(${page + 1})">›</button>`;
  el.innerHTML = html;
}

// ── USERS PAGE ────────────────────────────────────
async function loadUsers(page = 1, search = '', sort = 'created_at-desc') {
  const [sortField, sortDir] = sort.split('-');
  const size = STATE.pageSize;
  const from = (page - 1) * size;

  let query = STATE.sb.from('profiles').select('*', { count: 'exact' })
    .order(sortField, { ascending: sortDir === 'asc' })
    .range(from, from + size - 1);

  if (search) query = query.or(`email.ilike.%${search}%,full_name.ilike.%${search}%`);

  const { data, count, error } = await query;
  if (error) { toast('Gagal memuat pengguna: ' + error.message, 'error'); return; }

  // Get account & txn counts per user
  const ids = (data || []).map(u => u.id);
  let accCounts = {}, txnCounts = {};
  if (ids.length) {
    const [{ data: accs }, { data: txns }] = await Promise.all([
      STATE.sb.from('accounts').select('user_id').in('user_id', ids),
      STATE.sb.from('transactions').select('user_id').in('user_id', ids),
    ]);
    (accs || []).forEach(a => { accCounts[a.user_id] = (accCounts[a.user_id] || 0) + 1; });
    (txns || []).forEach(t => { txnCounts[t.user_id] = (txnCounts[t.user_id] || 0) + 1; });
  }

  const tbody = $('tbody-users');
  tbody.innerHTML = (data || []).map(u => `
    <tr>
      <td>
        <div class="user-cell">
          <div class="user-cell-avatar" style="background:${avatarColor(u.full_name || u.email)}">${fmt.initials(u.full_name || u.email)}</div>
          <div>
            <div class="user-cell-name">${esc(u.full_name || '—')}</div>
            <div class="user-cell-email">${esc(u.id.slice(0,8))}…</div>
          </div>
        </div>
      </td>
      <td>${esc(u.email)}</td>
      <td><span class="badge badge-active">${esc(u.default_currency || 'IDR')}</span></td>
      <td>${fmt.date(u.created_at)}</td>
      <td>${fmt.number(accCounts[u.id] || 0)}</td>
      <td>${fmt.number(txnCounts[u.id] || 0)}</td>
      <td>
        <div class="action-btns">
          <button class="btn-icon view" title="Lihat Detail" onclick="viewUser('${u.id}')">
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
          </button>
          <button class="btn-icon edit" title="Edit Profil" onclick="editUser('${u.id}')">
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
          </button>
          <button class="btn-icon del" title="Hapus Pengguna" onclick="deleteUser('${u.id}','${esc(u.email)}')">
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/><path d="M10 11v6M14 11v6"/><path d="M9 6V4h6v2"/></svg>
          </button>
        </div>
      </td>
    </tr>
  `).join('') || `<tr><td colspan="7" class="td-loading">Tidak ada pengguna ditemukan.</td></tr>`;

  $('info-users').textContent = `Menampilkan ${from+1}–${Math.min(from+size, count)} dari ${fmt.number(count)} pengguna`;
  buildPagination('pag-users', count, page, size, `(p) => loadUsers(p, ${JSON.stringify(search)}, ${JSON.stringify(sort)})`);
}

window.viewUser = async function(id) {
  const { data: u } = await STATE.sb.from('profiles').select('*').eq('id', id).single();
  if (!u) return;
  const { count: ac } = await STATE.sb.from('accounts').select('*', { count: 'exact', head: true }).eq('user_id', id);
  const { count: tc } = await STATE.sb.from('transactions').select('*', { count: 'exact', head: true }).eq('user_id', id);
  const { count: bc } = await STATE.sb.from('budgets').select('*', { count: 'exact', head: true }).eq('user_id', id);

  openModal(`Detail Pengguna — ${u.full_name || u.email}`, `
    <div class="detail-grid">
      <div class="detail-item"><div class="detail-label">ID</div><div class="detail-val" style="font-family:monospace;font-size:12px">${u.id}</div></div>
      <div class="detail-item"><div class="detail-label">Email</div><div class="detail-val">${esc(u.email)}</div></div>
      <div class="detail-item"><div class="detail-label">Nama Lengkap</div><div class="detail-val">${esc(u.full_name || '—')}</div></div>
      <div class="detail-item"><div class="detail-label">Mata Uang</div><div class="detail-val">${esc(u.default_currency || 'IDR')}</div></div>
      <div class="detail-item"><div class="detail-label">Locale</div><div class="detail-val">${esc(u.locale || '—')}</div></div>
      <div class="detail-item"><div class="detail-label">Tema</div><div class="detail-val">${esc(u.theme || 'system')}</div></div>
      <div class="detail-item"><div class="detail-label">Notif Email</div><div class="detail-val">${u.email_notifications ? '✓ Aktif' : '✗ Nonaktif'}</div></div>
      <div class="detail-item"><div class="detail-label">Notif Push</div><div class="detail-val">${u.push_notifications ? '✓ Aktif' : '✗ Nonaktif'}</div></div>
      <div class="detail-item"><div class="detail-label">Alert Anggaran</div><div class="detail-val">${u.monthly_budget_alert || 80}%</div></div>
      <div class="detail-item"><div class="detail-label">Bergabung</div><div class="detail-val">${fmt.dateTime(u.created_at)}</div></div>
      <div class="detail-item"><div class="detail-label">Update Terakhir</div><div class="detail-val">${fmt.dateTime(u.updated_at)}</div></div>
      <hr class="detail-sep">
      <div class="detail-item"><div class="detail-label">Jumlah Rekening</div><div class="detail-val">${ac}</div></div>
      <div class="detail-item"><div class="detail-label">Jumlah Transaksi</div><div class="detail-val">${tc}</div></div>
      <div class="detail-item"><div class="detail-label">Jumlah Anggaran</div><div class="detail-val">${bc}</div></div>
    </div>
  `, `<button class="btn-secondary" onclick="closeModal()">Tutup</button><button class="btn-primary" onclick="editUser('${id}')">Edit</button>`);
};

window.editUser = async function(id) {
  const { data: u } = await STATE.sb.from('profiles').select('*').eq('id', id).single();
  if (!u) return;
  openModal(`Edit Pengguna — ${u.email}`, `
    <div class="field-group"><label>Nama Lengkap</label><input class="input-full" id="eu-name" value="${esc(u.full_name || '')}"></div>
    <div class="field-group"><label>Mata Uang Default</label>
      <select class="input-full" id="eu-currency">
        ${['IDR','USD','SGD','EUR','MYR','JPY','AUD'].map(c => `<option ${u.default_currency===c?'selected':''}>${c}</option>`).join('')}
      </select>
    </div>
    <div class="field-group"><label>Tema</label>
      <select class="input-full" id="eu-theme">
        ${['system','light','dark'].map(t => `<option value="${t}" ${u.theme===t?'selected':''}>${t}</option>`).join('')}
      </select>
    </div>
    <div class="field-group"><label>Alert Anggaran (%)</label><input class="input-full" id="eu-alert" type="number" min="0" max="100" value="${u.monthly_budget_alert || 80}"></div>
  `, `
    <button class="btn-secondary" onclick="closeModal()">Batal</button>
    <button class="btn-primary" onclick="saveUser('${id}')">Simpan</button>
  `);
};

window.saveUser = async function(id) {
  const updates = {
    full_name: $('eu-name').value.trim(),
    default_currency: $('eu-currency').value,
    theme: $('eu-theme').value,
    monthly_budget_alert: parseInt($('eu-alert').value) || 80,
  };
  const { error } = await STATE.sb.from('profiles').update(updates).eq('id', id);
  if (error) { toast('Gagal menyimpan: ' + error.message, 'error'); return; }
  toast('Profil berhasil diperbarui!', 'success');
  adminLog(`Edit user ${id}`, 'success');
  closeModal();
  loadUsers();
};

window.deleteUser = async function(id, email) {
  const yes = await confirm('Hapus Pengguna?', `Apakah Anda yakin ingin menghapus pengguna "${email}"? Semua data akan terhapus permanen.`, '🗑️');
  if (!yes) return;
  // Delete from auth (only via admin API — here we delete profile, cascade will handle the rest)
  const { error } = await STATE.sb.from('profiles').delete().eq('id', id);
  if (error) { toast('Gagal hapus: ' + error.message, 'error'); return; }
  toast('Pengguna berhasil dihapus!', 'success');
  adminLog(`Hapus user ${email}`, 'danger');
  loadUsers();
};

// ── ADD USER MODAL ────────────────────────────────
window.openAddUser = function() {
  openModal('Tambah Pengguna Baru', `
    <div class="field-group"><label>Nama Lengkap</label><input class="input-full" id="au-name" placeholder="Nama Lengkap"></div>
    <div class="field-group"><label>Email</label><input class="input-full" id="au-email" type="email" placeholder="user@email.com"></div>
    <div class="field-group"><label>Password</label><input class="input-full" id="au-pw" type="password" placeholder="Min. 6 karakter"></div>
    <div class="field-group"><label>Mata Uang</label>
      <select class="input-full" id="au-currency">
        ${['IDR','USD','SGD','EUR','MYR','JPY','AUD'].map(c => `<option ${c==='IDR'?'selected':''}>${c}</option>`).join('')}
      </select>
    </div>
  `, `
    <button class="btn-secondary" onclick="closeModal()">Batal</button>
    <button class="btn-primary" onclick="doAddUser()">Buat Akun</button>
  `);
};

window.doAddUser = async function() {
  const email = $('au-email').value.trim();
  const pw = $('au-pw').value;
  const name = $('au-name').value.trim();
  const cur = $('au-currency').value;
  if (!email || !pw) { toast('Email dan password wajib!', 'error'); return; }
  
  // Use admin.createUser via REST
  try {
    const res = await fetch(`${STATE.supabaseUrl}/auth/v1/admin/users`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'apikey': STATE.supabaseKey, 'Authorization': `Bearer ${STATE.supabaseKey}` },
      body: JSON.stringify({ email, password: pw, email_confirm: true, user_metadata: { full_name: name } }),
    });
    const json = await res.json();
    if (!res.ok) throw new Error(json.msg || json.message || 'Gagal');
    
    // Update profile with currency
    await STATE.sb.from('profiles').update({ full_name: name, default_currency: cur }).eq('id', json.id);
    toast('Pengguna berhasil dibuat!', 'success');
    adminLog(`Buat user baru: ${email}`, 'success');
    closeModal();
    loadUsers();
  } catch (err) {
    toast('Gagal membuat pengguna: ' + err.message, 'error');
  }
};

// ── TRANSACTIONS PAGE ─────────────────────────────
async function loadTransactions(page = 1, search = '', type = '', status = '', from_date = '', to_date = '') {
  const size = STATE.pageSize;
  const from = (page - 1) * size;

  let query = STATE.sb.from('transactions').select(`
    id, amount, type, date, note, status, user_id,
    categories(name), accounts(name)
  `, { count: 'exact' })
    .order('date', { ascending: false })
    .order('created_at', { ascending: false })
    .range(from, from + size - 1);

  if (type) query = query.eq('type', type);
  if (status) query = query.eq('status', status);
  if (from_date) query = query.gte('date', from_date);
  if (to_date) query = query.lte('date', to_date);
  if (search) query = query.ilike('note', `%${search}%`);

  const { data, count, error } = await query;
  if (error) { toast('Gagal memuat transaksi: ' + error.message, 'error'); return; }

  const uids = [...new Set((data || []).map(t => t.user_id).filter(Boolean))];
  await cacheUsers(uids);

  const tbody = $('tbody-txns');
  tbody.innerHTML = (data || []).map(t => {
    const u = STATE.userCache[t.user_id] || {};
    const cls = t.type === 'income' ? 'money-pos' : t.type === 'expense' ? 'money-neg' : 'money-neu';
    const prefix = t.type === 'income' ? '+' : t.type === 'expense' ? '-' : '';
    return `
      <tr>
        <td style="white-space:nowrap">${fmt.date(t.date)}</td>
        <td>
          <div class="user-cell">
            <div class="user-cell-avatar" style="background:${avatarColor(u.full_name||u.email)};width:24px;height:24px;font-size:10px">${fmt.initials(u.full_name||u.email)}</div>
            <span style="font-size:12px">${esc(u.full_name||u.email||'Unknown')}</span>
          </div>
        </td>
        <td><span class="badge badge-${t.type}">${typeLbl(t.type)}</span></td>
        <td>${esc(t.categories?.name || '—')}</td>
        <td class="${cls}">${prefix}${fmt.currency(t.amount)}</td>
        <td><span class="badge badge-${t.status}">${statusLbl(t.status)}</span></td>
        <td style="max-width:180px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${esc(t.note || '—')}</td>
        <td>
          <div class="action-btns">
            <button class="btn-icon view" title="Detail" onclick="viewTxn('${t.id}')">
              <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
            </button>
            <button class="btn-icon del" title="Hapus" onclick="deleteTxn('${t.id}')">
              <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/></svg>
            </button>
          </div>
        </td>
      </tr>
    `;
  }).join('') || `<tr><td colspan="8" class="td-loading">Tidak ada transaksi.</td></tr>`;

  $('info-txns').textContent = `Menampilkan ${Math.min(from+1,count||0)}–${Math.min(from+size, count||0)} dari ${fmt.number(count)} transaksi`;
  buildPagination('pag-txns', count, page, size, `(p) => loadTransactions(p, ${JSON.stringify(search)}, ${JSON.stringify(type)}, ${JSON.stringify(status)}, ${JSON.stringify(from_date)}, ${JSON.stringify(to_date)})`);
}

function typeLbl(t) { return { income: 'Pemasukan', expense: 'Pengeluaran', transfer: 'Transfer' }[t] || t; }
function statusLbl(s) { return { completed: 'Selesai', pending: 'Pending', cancelled: 'Batal' }[s] || s; }
function periodLbl(p) { return { monthly: 'Bulanan', weekly: 'Mingguan', yearly: 'Tahunan', custom: 'Custom' }[p] || p; }

window.viewTxn = async function(id) {
  const { data: t } = await STATE.sb.from('transactions').select(`*, categories(name), accounts(name,type), profiles(full_name,email)`).eq('id', id).single();
  if (!t) return;
  const cls = t.type === 'income' ? 'money-pos' : t.type === 'expense' ? 'money-neg' : 'money-neu';
  openModal('Detail Transaksi', `
    <div class="detail-grid">
      <div class="detail-item full"><div class="detail-label">ID</div><div class="detail-val" style="font-family:monospace;font-size:12px">${t.id}</div></div>
      <div class="detail-item"><div class="detail-label">Tipe</div><div class="detail-val"><span class="badge badge-${t.type}">${typeLbl(t.type)}</span></div></div>
      <div class="detail-item"><div class="detail-label">Status</div><div class="detail-val"><span class="badge badge-${t.status}">${statusLbl(t.status)}</span></div></div>
      <div class="detail-item"><div class="detail-label">Jumlah</div><div class="detail-val ${cls}" style="font-size:20px;font-weight:800">${fmt.currency(t.amount)}</div></div>
      <div class="detail-item"><div class="detail-label">Tanggal</div><div class="detail-val">${fmt.date(t.date)}</div></div>
      <div class="detail-item"><div class="detail-label">Pengguna</div><div class="detail-val">${esc(t.profiles?.full_name || t.profiles?.email || '—')}</div></div>
      <div class="detail-item"><div class="detail-label">Rekening</div><div class="detail-val">${esc(t.accounts?.name || '—')}</div></div>
      <div class="detail-item"><div class="detail-label">Kategori</div><div class="detail-val">${esc(t.categories?.name || '—')}</div></div>
      <div class="detail-item full"><div class="detail-label">Catatan</div><div class="detail-val">${esc(t.note || '—')}</div></div>
      <div class="detail-item full"><div class="detail-label">Deskripsi</div><div class="detail-val">${esc(t.description || '—')}</div></div>
      <div class="detail-item"><div class="detail-label">Dibuat</div><div class="detail-val">${fmt.dateTime(t.created_at)}</div></div>
      <div class="detail-item"><div class="detail-label">Diupdate</div><div class="detail-val">${fmt.dateTime(t.updated_at)}</div></div>
    </div>
  `, `<button class="btn-secondary" onclick="closeModal()">Tutup</button>`);
};

window.deleteTxn = async function(id) {
  const yes = await confirm('Hapus Transaksi?', 'Transaksi ini akan dihapus secara permanen.', '🗑️');
  if (!yes) return;
  const { error } = await STATE.sb.from('transactions').delete().eq('id', id);
  if (error) { toast('Gagal hapus: ' + error.message, 'error'); return; }
  toast('Transaksi dihapus!', 'success');
  adminLog(`Hapus transaksi ${id}`, 'danger');
  loadTransactions();
};

// ── ACCOUNTS PAGE ─────────────────────────────────
async function loadAccounts(page = 1, search = '', type = '', statusFilter = '') {
  const size = STATE.pageSize;
  const from = (page - 1) * size;

  let query = STATE.sb.from('accounts').select('*, profiles(full_name,email)', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(from, from + size - 1);

  if (type) query = query.eq('type', type);
  if (statusFilter === 'active') query = query.eq('is_active', true);
  if (statusFilter === 'archived') query = query.eq('is_archived', true);
  if (search) query = query.or(`name.ilike.%${search}%,bank_name.ilike.%${search}%`);

  const { data, count, error } = await query;
  if (error) { toast('Gagal memuat rekening: ' + error.message, 'error'); return; }

  const accTypeMap = { cash: 'Tunai', bank: 'Bank', ewallet: 'E-Wallet', savings: 'Tabungan', investment: 'Investasi' };
  const tbody = $('tbody-accounts');
  tbody.innerHTML = (data || []).map(a => `
    <tr>
      <td><strong>${esc(a.name)}</strong></td>
      <td>
        <div class="user-cell">
          <div class="user-cell-avatar" style="background:${avatarColor(a.profiles?.full_name||a.profiles?.email)};width:24px;height:24px;font-size:10px">${fmt.initials(a.profiles?.full_name||a.profiles?.email)}</div>
          <span style="font-size:12px">${esc(a.profiles?.full_name||a.profiles?.email||'—')}</span>
        </div>
      </td>
      <td><span class="badge badge-active">${esc(accTypeMap[a.type] || a.type)}</span></td>
      <td>${esc(a.bank_name || '—')}</td>
      <td style="font-family:monospace;font-size:12px">${esc(a.account_number || '—')}</td>
      <td class="${a.balance >= 0 ? 'money-pos' : 'money-neg'}">${fmt.currency(a.balance)}</td>
      <td>
        ${a.is_archived ? '<span class="badge badge-archived">Diarsipkan</span>' : '<span class="badge badge-active">Aktif</span>'}
      </td>
      <td>
        <div class="action-btns">
          <button class="btn-icon view" onclick="viewAccount('${a.id}')">
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
          </button>
          <button class="btn-icon edit" onclick="editAccount('${a.id}')">
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
          </button>
          <button class="btn-icon del" onclick="deleteAccount('${a.id}')">
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/></svg>
          </button>
        </div>
      </td>
    </tr>
  `).join('') || `<tr><td colspan="8" class="td-loading">Tidak ada rekening.</td></tr>`;

  $('info-accounts').textContent = `Menampilkan ${Math.min(from+1,count||0)}–${Math.min(from+size,count||0)} dari ${fmt.number(count)} rekening`;
  buildPagination('pag-accounts', count, page, size, `(p) => loadAccounts(p, ${JSON.stringify(search)}, ${JSON.stringify(type)}, ${JSON.stringify(statusFilter)})`);
}

window.viewAccount = async function(id) {
  const { data: a } = await STATE.sb.from('accounts').select('*, profiles(full_name,email)').eq('id', id).single();
  if (!a) return;
  const { count: tc } = await STATE.sb.from('transactions').select('*', { count: 'exact', head: true }).eq('account_id', id);
  openModal('Detail Rekening', `
    <div class="detail-grid">
      <div class="detail-item full"><div class="detail-label">ID</div><div class="detail-val" style="font-family:monospace;font-size:12px">${a.id}</div></div>
      <div class="detail-item"><div class="detail-label">Nama</div><div class="detail-val">${esc(a.name)}</div></div>
      <div class="detail-item"><div class="detail-label">Tipe</div><div class="detail-val">${esc(a.type)}</div></div>
      <div class="detail-item"><div class="detail-label">Saldo</div><div class="detail-val money-pos" style="font-size:18px;font-weight:800">${fmt.currency(a.balance)}</div></div>
      <div class="detail-item"><div class="detail-label">Bank</div><div class="detail-val">${esc(a.bank_name || '—')}</div></div>
      <div class="detail-item"><div class="detail-label">No. Rekening</div><div class="detail-val">${esc(a.account_number || '—')}</div></div>
      <div class="detail-item"><div class="detail-label">Pengguna</div><div class="detail-val">${esc(a.profiles?.full_name || a.profiles?.email || '—')}</div></div>
      <div class="detail-item"><div class="detail-label">Transaksi</div><div class="detail-val">${tc}</div></div>
      <div class="detail-item"><div class="detail-label">Status Arsip</div><div class="detail-val">${a.is_archived ? 'Diarsipkan' : 'Aktif'}</div></div>
      <div class="detail-item"><div class="detail-label">Aktif</div><div class="detail-val">${a.is_active ? 'Ya' : 'Tidak'}</div></div>
      <div class="detail-item"><div class="detail-label">Dibuat</div><div class="detail-val">${fmt.dateTime(a.created_at)}</div></div>
    </div>
  `, `<button class="btn-secondary" onclick="closeModal()">Tutup</button>`);
};

window.editAccount = async function(id) {
  const { data: a } = await STATE.sb.from('accounts').select('*').eq('id', id).single();
  if (!a) return;
  openModal('Edit Rekening', `
    <div class="field-group"><label>Nama Rekening</label><input class="input-full" id="ea-name" value="${esc(a.name)}"></div>
    <div class="field-group"><label>Saldo</label><input class="input-full" id="ea-bal" type="number" step="0.01" value="${a.balance}"></div>
    <div class="field-group"><label>Nama Bank</label><input class="input-full" id="ea-bank" value="${esc(a.bank_name || '')}"></div>
    <div class="field-group"><label>No. Rekening</label><input class="input-full" id="ea-accno" value="${esc(a.account_number || '')}"></div>
    <div class="field-group"><label>Tipe</label>
      <select class="input-full" id="ea-type">
        ${['cash','bank','ewallet','savings','investment'].map(t => `<option value="${t}" ${a.type===t?'selected':''}>${t}</option>`).join('')}
      </select>
    </div>
    <div class="field-group"><label>Status Arsip</label>
      <select class="input-full" id="ea-arch">
        <option value="false" ${!a.is_archived?'selected':''}>Aktif</option>
        <option value="true" ${a.is_archived?'selected':''}>Diarsipkan</option>
      </select>
    </div>
  `, `
    <button class="btn-secondary" onclick="closeModal()">Batal</button>
    <button class="btn-primary" onclick="saveAccount('${id}')">Simpan</button>
  `);
};

window.saveAccount = async function(id) {
  const updates = {
    name: $('ea-name').value.trim(),
    balance: parseFloat($('ea-bal').value) || 0,
    bank_name: $('ea-bank').value.trim() || null,
    account_number: $('ea-accno').value.trim() || null,
    type: $('ea-type').value,
    is_archived: $('ea-arch').value === 'true',
  };
  const { error } = await STATE.sb.from('accounts').update(updates).eq('id', id);
  if (error) { toast('Gagal: ' + error.message, 'error'); return; }
  toast('Rekening diperbarui!', 'success');
  adminLog(`Edit rekening ${id}`, 'success');
  closeModal();
  loadAccounts();
};

window.deleteAccount = async function(id) {
  const yes = await confirm('Hapus Rekening?', 'Rekening dan semua transaksinya akan dihapus permanen.', '🗑️');
  if (!yes) return;
  const { error } = await STATE.sb.from('accounts').delete().eq('id', id);
  if (error) { toast('Gagal: ' + error.message, 'error'); return; }
  toast('Rekening dihapus!', 'success');
  adminLog(`Hapus rekening ${id}`, 'danger');
  loadAccounts();
};

// ── BUDGETS PAGE ──────────────────────────────────
async function loadBudgets(page = 1, search = '', period = '') {
  const size = STATE.pageSize;
  const from = (page - 1) * size;

  let query = STATE.sb.from('budgets').select('*, profiles(full_name,email)', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(from, from + size - 1);

  if (period) query = query.eq('period', period);
  if (search) query = query.ilike('name', `%${search}%`);

  const { data, count, error } = await query;
  if (error) { toast('Gagal: ' + error.message, 'error'); return; }

  const tbody = $('tbody-budgets');
  tbody.innerHTML = (data || []).map(b => `
    <tr>
      <td><strong>${esc(b.name)}</strong></td>
      <td>
        <div class="user-cell">
          <div class="user-cell-avatar" style="background:${avatarColor(b.profiles?.full_name||b.profiles?.email)};width:24px;height:24px;font-size:10px">${fmt.initials(b.profiles?.full_name||b.profiles?.email)}</div>
          <span style="font-size:12px">${esc(b.profiles?.full_name||b.profiles?.email||'—')}</span>
        </div>
      </td>
      <td><span class="badge badge-${b.period === 'custom' ? 'custom-period' : b.period}">${periodLbl(b.period)}</span></td>
      <td class="money-pos">${fmt.currency(b.amount)}</td>
      <td>${b.is_active ? '<span class="badge badge-active">Aktif</span>' : '<span class="badge badge-archived">Nonaktif</span>'}</td>
      <td>${fmt.date(b.created_at)}</td>
      <td>
        <div class="action-btns">
          <button class="btn-icon edit" onclick="editBudget('${b.id}')">
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
          </button>
          <button class="btn-icon del" onclick="deleteBudget('${b.id}')">
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/></svg>
          </button>
        </div>
      </td>
    </tr>
  `).join('') || `<tr><td colspan="7" class="td-loading">Tidak ada anggaran.</td></tr>`;

  $('info-budgets').textContent = `${fmt.number(count)} anggaran`;
  buildPagination('pag-budgets', count, page, size, `(p) => loadBudgets(p, ${JSON.stringify(search)}, ${JSON.stringify(period)})`);
}

window.editBudget = async function(id) {
  const { data: b } = await STATE.sb.from('budgets').select('*').eq('id', id).single();
  if (!b) return;
  openModal('Edit Anggaran', `
    <div class="field-group"><label>Nama</label><input class="input-full" id="eb-name" value="${esc(b.name)}"></div>
    <div class="field-group"><label>Jumlah (IDR)</label><input class="input-full" id="eb-amount" type="number" value="${b.amount}"></div>
    <div class="field-group"><label>Periode</label>
      <select class="input-full" id="eb-period">
        ${['monthly','weekly','yearly','custom'].map(p => `<option value="${p}" ${b.period===p?'selected':''}>${periodLbl(p)}</option>`).join('')}
      </select>
    </div>
    <div class="field-group"><label>Status</label>
      <select class="input-full" id="eb-active">
        <option value="true" ${b.is_active?'selected':''}>Aktif</option>
        <option value="false" ${!b.is_active?'selected':''}>Nonaktif</option>
      </select>
    </div>
  `, `
    <button class="btn-secondary" onclick="closeModal()">Batal</button>
    <button class="btn-primary" onclick="saveBudget('${id}')">Simpan</button>
  `);
};

window.saveBudget = async function(id) {
  const updates = { name: $('eb-name').value.trim(), amount: parseFloat($('eb-amount').value), period: $('eb-period').value, is_active: $('eb-active').value === 'true' };
  const { error } = await STATE.sb.from('budgets').update(updates).eq('id', id);
  if (error) { toast('Gagal: ' + error.message, 'error'); return; }
  toast('Anggaran diperbarui!', 'success');
  adminLog(`Edit budget ${id}`, 'success');
  closeModal();
  loadBudgets();
};

window.deleteBudget = async function(id) {
  const yes = await confirm('Hapus Anggaran?', 'Anggaran ini akan dihapus permanen.', '🗑️');
  if (!yes) return;
  const { error } = await STATE.sb.from('budgets').delete().eq('id', id);
  if (error) { toast('Gagal: ' + error.message, 'error'); return; }
  toast('Anggaran dihapus!', 'success');
  adminLog(`Hapus budget ${id}`, 'danger');
  loadBudgets();
};

// ── CATEGORIES PAGE ───────────────────────────────
async function loadCategories(page = 1, search = '', type = '', scope = '') {
  const size = STATE.pageSize;
  const from = (page - 1) * size;

  let query = STATE.sb.from('categories').select('*', { count: 'exact' })
    .order('is_default', { ascending: false })
    .order('sort_order', { ascending: true })
    .range(from, from + size - 1);

  if (type) query = query.eq('type', type);
  if (scope === 'default') query = query.eq('is_default', true);
  if (scope === 'custom') query = query.eq('is_default', false);
  if (search) query = query.ilike('name', `%${search}%`);

  const { data, count, error } = await query;
  if (error) { toast('Gagal: ' + error.message, 'error'); return; }

  const tbody = $('tbody-categories');
  tbody.innerHTML = (data || []).map(c => `
    <tr>
      <td><strong>${esc(c.name)}</strong></td>
      <td><span class="badge badge-${c.type}">${c.type === 'income' ? 'Pemasukan' : 'Pengeluaran'}</span></td>
      <td><span class="badge ${c.is_default ? 'badge-default' : 'badge-custom'}">${c.is_default ? 'Default' : 'Custom'}</span></td>
      <td>${esc(c.icon || '—')}</td>
      <td>${c.color ? `<div style="display:flex;align-items:center;gap:8px"><div class="color-swatch" style="background:${c.color}"></div><span style="font-size:12px;font-family:monospace">${c.color}</span></div>` : '—'}</td>
      <td>${c.sort_order ?? '—'}</td>
      <td>${c.is_active ? '<span class="badge badge-active">Aktif</span>' : '<span class="badge badge-archived">Nonaktif</span>'}</td>
      <td>
        <div class="action-btns">
          <button class="btn-icon edit" onclick="editCategory('${c.id}')">
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
          </button>
          <button class="btn-icon del" onclick="deleteCategory('${c.id}','${esc(c.name)}')">
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/></svg>
          </button>
        </div>
      </td>
    </tr>
  `).join('') || `<tr><td colspan="8" class="td-loading">Tidak ada kategori.</td></tr>`;

  $('info-categories').textContent = `${fmt.number(count)} kategori`;
  buildPagination('pag-categories', count, page, size, `(p) => loadCategories(p, ${JSON.stringify(search)}, ${JSON.stringify(type)}, ${JSON.stringify(scope)})`);
}

window.editCategory = async function(id) {
  const { data: c } = await STATE.sb.from('categories').select('*').eq('id', id).single();
  if (!c) return;
  openModal('Edit Kategori', `
    <div class="field-group"><label>Nama</label><input class="input-full" id="ec-name" value="${esc(c.name)}"></div>
    <div class="field-group"><label>Tipe</label>
      <select class="input-full" id="ec-type">
        <option value="income" ${c.type==='income'?'selected':''}>Pemasukan</option>
        <option value="expense" ${c.type==='expense'?'selected':''}>Pengeluaran</option>
      </select>
    </div>
    <div class="field-group"><label>Icon</label><input class="input-full" id="ec-icon" value="${esc(c.icon || '')}"></div>
    <div class="field-group"><label>Warna</label><input class="input-full" id="ec-color" type="color" value="${c.color || '#6366f1'}" style="height:40px;padding:4px"></div>
    <div class="field-group"><label>Urutan</label><input class="input-full" id="ec-sort" type="number" value="${c.sort_order || 0}"></div>
    <div class="field-group"><label>Status</label>
      <select class="input-full" id="ec-active">
        <option value="true" ${c.is_active?'selected':''}>Aktif</option>
        <option value="false" ${!c.is_active?'selected':''}>Nonaktif</option>
      </select>
    </div>
  `, `
    <button class="btn-secondary" onclick="closeModal()">Batal</button>
    <button class="btn-primary" onclick="saveCategory('${id}')">Simpan</button>
  `);
};

window.saveCategory = async function(id) {
  const updates = { name: $('ec-name').value.trim(), type: $('ec-type').value, icon: $('ec-icon').value.trim() || null, color: $('ec-color').value, sort_order: parseInt($('ec-sort').value) || 0, is_active: $('ec-active').value === 'true' };
  const { error } = await STATE.sb.from('categories').update(updates).eq('id', id);
  if (error) { toast('Gagal: ' + error.message, 'error'); return; }
  toast('Kategori diperbarui!', 'success');
  adminLog(`Edit kategori ${id}`, 'success');
  closeModal();
  loadCategories();
};

window.deleteCategory = async function(id, name) {
  const yes = await confirm('Hapus Kategori?', `Kategori "${name}" akan dihapus. Transaksi terkait akan kehilangan kategorinya.`, '🗑️');
  if (!yes) return;
  const { error } = await STATE.sb.from('categories').delete().eq('id', id);
  if (error) { toast('Gagal: ' + error.message, 'error'); return; }
  toast('Kategori dihapus!', 'success');
  adminLog(`Hapus kategori ${name}`, 'danger');
  loadCategories();
};

window.openAddCategory = function() {
  openModal('Tambah Kategori', `
    <div class="field-group"><label>Nama</label><input class="input-full" id="nc-name" placeholder="Nama Kategori"></div>
    <div class="field-group"><label>Tipe</label>
      <select class="input-full" id="nc-type">
        <option value="expense">Pengeluaran</option>
        <option value="income">Pemasukan</option>
      </select>
    </div>
    <div class="field-group"><label>Icon (Material Icon name)</label><input class="input-full" id="nc-icon" placeholder="restaurant"></div>
    <div class="field-group"><label>Warna</label><input class="input-full" id="nc-color" type="color" value="#6366f1" style="height:40px;padding:4px"></div>
    <div class="field-group"><label>Urutan</label><input class="input-full" id="nc-sort" type="number" value="99"></div>
  `, `
    <button class="btn-secondary" onclick="closeModal()">Batal</button>
    <button class="btn-primary" onclick="doAddCategory()">Tambah</button>
  `);
};

window.doAddCategory = async function() {
  const data = { name: $('nc-name').value.trim(), type: $('nc-type').value, icon: $('nc-icon').value.trim() || null, color: $('nc-color').value, sort_order: parseInt($('nc-sort').value) || 99, is_default: true, is_active: true };
  if (!data.name) { toast('Nama wajib diisi!', 'error'); return; }
  const { error } = await STATE.sb.from('categories').insert([data]);
  if (error) { toast('Gagal: ' + error.message, 'error'); return; }
  toast('Kategori berhasil ditambahkan!', 'success');
  adminLog(`Tambah kategori: ${data.name}`, 'success');
  closeModal();
  loadCategories();
};

// ── BILLS PAGE ────────────────────────────────────
async function loadBills(page = 1, search = '', status = '') {
  const size = STATE.pageSize;
  const from = (page - 1) * size;

  let query = STATE.sb.from('bills').select('*, profiles(full_name,email)', { count: 'exact' })
    .order('due_date', { ascending: true })
    .range(from, from + size - 1);

  if (status) query = query.eq('status', status);
  if (search) query = query.ilike('name', `%${search}%`);

  const { data, count, error } = await query;
  if (error) { toast('Gagal: ' + error.message, 'error'); return; }

  const today = new Date().toISOString().split('T')[0];
  const tbody = $('tbody-bills');
  tbody.innerHTML = (data || []).map(b => {
    const overdue = b.status === 'pending' && b.due_date < today;
    return `
      <tr>
        <td><strong>${esc(b.name)}</strong></td>
        <td><span style="font-size:12px">${esc(b.profiles?.full_name||b.profiles?.email||'—')}</span></td>
        <td class="money-neg">${fmt.currency(b.amount)}</td>
        <td style="${overdue ? 'color:var(--red2)' : ''}">${fmt.date(b.due_date)} ${overdue ? '⚠️' : ''}</td>
        <td><span class="badge badge-${b.status}">${b.status === 'paid' ? 'Dibayar' : 'Pending'}</span></td>
        <td>${fmt.date(b.created_at)}</td>
        <td>
          <div class="action-btns">
            <button class="btn-icon edit" onclick="editBill('${b.id}')">
              <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
            </button>
            <button class="btn-icon del" onclick="deleteBill('${b.id}')">
              <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/></svg>
            </button>
          </div>
        </td>
      </tr>
    `;
  }).join('') || `<tr><td colspan="7" class="td-loading">Tidak ada tagihan.</td></tr>`;

  $('info-bills').textContent = `${fmt.number(count)} tagihan`;
  buildPagination('pag-bills', count, page, size, `(p) => loadBills(p, ${JSON.stringify(search)}, ${JSON.stringify(status)})`);
}

window.editBill = async function(id) {
  const { data: b } = await STATE.sb.from('bills').select('*').eq('id', id).single();
  if (!b) return;
  openModal('Edit Tagihan', `
    <div class="field-group"><label>Nama</label><input class="input-full" id="bi-name" value="${esc(b.name)}"></div>
    <div class="field-group"><label>Jumlah</label><input class="input-full" id="bi-amount" type="number" value="${b.amount}"></div>
    <div class="field-group"><label>Jatuh Tempo</label><input class="input-full" id="bi-due" type="date" value="${b.due_date}"></div>
    <div class="field-group"><label>Status</label>
      <select class="input-full" id="bi-status">
        <option value="pending" ${b.status==='pending'?'selected':''}>Pending</option>
        <option value="paid" ${b.status==='paid'?'selected':''}>Dibayar</option>
      </select>
    </div>
  `, `
    <button class="btn-secondary" onclick="closeModal()">Batal</button>
    <button class="btn-primary" onclick="saveBill('${id}')">Simpan</button>
  `);
};

window.saveBill = async function(id) {
  const updates = { name: $('bi-name').value.trim(), amount: parseFloat($('bi-amount').value), due_date: $('bi-due').value, status: $('bi-status').value };
  const { error } = await STATE.sb.from('bills').update(updates).eq('id', id);
  if (error) { toast('Gagal: ' + error.message, 'error'); return; }
  toast('Tagihan diperbarui!', 'success');
  adminLog(`Edit tagihan ${id}`, 'success');
  closeModal();
  loadBills();
};

window.deleteBill = async function(id) {
  const yes = await confirm('Hapus Tagihan?', 'Tagihan ini akan dihapus permanen.', '🗑️');
  if (!yes) return;
  const { error } = await STATE.sb.from('bills').delete().eq('id', id);
  if (error) { toast('Gagal: ' + error.message, 'error'); return; }
  toast('Tagihan dihapus!', 'success');
  adminLog(`Hapus tagihan ${id}`, 'danger');
  loadBills();
};

// ── GOALS PAGE ────────────────────────────────────
async function loadGoals(page = 1, search = '') {
  const size = STATE.pageSize;
  const from = (page - 1) * size;

  let query = STATE.sb.from('saving_goals').select('*, profiles(full_name,email)', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(from, from + size - 1);

  if (search) query = query.ilike('name', `%${search}%`);

  const { data, count, error } = await query;
  if (error) { toast('Gagal: ' + error.message, 'error'); return; }

  const tbody = $('tbody-goals');
  tbody.innerHTML = (data || []).map(g => {
    const pct = g.target_amount > 0 ? Math.min(100, Math.round(g.current_amount / g.target_amount * 100)) : 0;
    return `
      <tr>
        <td><strong>${esc(g.name)}</strong></td>
        <td><span style="font-size:12px">${esc(g.profiles?.full_name||g.profiles?.email||'—')}</span></td>
        <td class="money-pos">${fmt.currency(g.target_amount)}</td>
        <td>${fmt.currency(g.current_amount)}</td>
        <td>
          <div class="prog-wrap">
            <div class="prog-bar"><div class="prog-fill" style="width:${pct}%"></div></div>
            <span class="prog-pct">${pct}%</span>
          </div>
        </td>
        <td>${g.target_date ? fmt.date(g.target_date) : '—'}</td>
        <td>${fmt.date(g.created_at)}</td>
        <td>
          <div class="action-btns">
            <button class="btn-icon edit" onclick="editGoal('${g.id}')">
              <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
            </button>
            <button class="btn-icon del" onclick="deleteGoal('${g.id}')">
              <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/></svg>
            </button>
          </div>
        </td>
      </tr>
    `;
  }).join('') || `<tr><td colspan="8" class="td-loading">Tidak ada target tabungan.</td></tr>`;

  $('info-goals').textContent = `${fmt.number(count)} target`;
  buildPagination('pag-goals', count, page, size, `(p) => loadGoals(p, ${JSON.stringify(search)})`);
}

window.editGoal = async function(id) {
  const { data: g } = await STATE.sb.from('saving_goals').select('*').eq('id', id).single();
  if (!g) return;
  openModal('Edit Target Tabungan', `
    <div class="field-group"><label>Nama</label><input class="input-full" id="eg-name" value="${esc(g.name)}"></div>
    <div class="field-group"><label>Target</label><input class="input-full" id="eg-target" type="number" value="${g.target_amount}"></div>
    <div class="field-group"><label>Terkumpul</label><input class="input-full" id="eg-current" type="number" value="${g.current_amount}"></div>
    <div class="field-group"><label>Deadline</label><input class="input-full" id="eg-date" type="date" value="${g.target_date || ''}"></div>
  `, `
    <button class="btn-secondary" onclick="closeModal()">Batal</button>
    <button class="btn-primary" onclick="saveGoal('${id}')">Simpan</button>
  `);
};

window.saveGoal = async function(id) {
  const updates = { name: $('eg-name').value.trim(), target_amount: parseFloat($('eg-target').value), current_amount: parseFloat($('eg-current').value) || 0, target_date: $('eg-date').value || null };
  const { error } = await STATE.sb.from('saving_goals').update(updates).eq('id', id);
  if (error) { toast('Gagal: ' + error.message, 'error'); return; }
  toast('Target tabungan diperbarui!', 'success');
  adminLog(`Edit saving_goal ${id}`, 'success');
  closeModal();
  loadGoals();
};

window.deleteGoal = async function(id) {
  const yes = await confirm('Hapus Target Tabungan?', 'Target tabungan ini akan dihapus permanen.', '🗑️');
  if (!yes) return;
  const { error } = await STATE.sb.from('saving_goals').delete().eq('id', id);
  if (error) { toast('Gagal: ' + error.message, 'error'); return; }
  toast('Target dihapus!', 'success');
  adminLog(`Hapus saving_goal ${id}`, 'danger');
  loadGoals();
};

// ── DEBTS PAGE ────────────────────────────────────
async function loadDebts(page = 1, search = '', type = '', status = '') {
  const size = STATE.pageSize;
  const from = (page - 1) * size;

  let query = STATE.sb.from('debts').select('*, profiles(full_name,email)', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(from, from + size - 1);

  if (type) query = query.eq('type', type);
  if (status) query = query.eq('status', status);
  if (search) query = query.ilike('contact_name', `%${search}%`);

  const { data, count, error } = await query;
  if (error) { toast('Gagal: ' + error.message, 'error'); return; }

  const today = new Date().toISOString().split('T')[0];
  const tbody = $('tbody-debts');
  tbody.innerHTML = (data || []).map(d => {
    const overdue = d.status === 'unpaid' && d.due_date && d.due_date < today;
    return `
      <tr>
        <td><strong>${esc(d.contact_name)}</strong></td>
        <td><span style="font-size:12px">${esc(d.profiles?.full_name||d.profiles?.email||'—')}</span></td>
        <td><span class="badge badge-${d.type}">${d.type === 'debt' ? 'Hutang' : 'Piutang'}</span></td>
        <td class="${d.type === 'debt' ? 'money-neg' : 'money-pos'}">${fmt.currency(d.amount)}</td>
        <td><span class="badge badge-${d.status}">${d.status === 'paid' ? 'Lunas' : 'Belum Lunas'}</span></td>
        <td style="${overdue ? 'color:var(--red2)' : ''}">${d.due_date ? fmt.date(d.due_date) : '—'} ${overdue ? '⚠️' : ''}</td>
        <td>${fmt.date(d.created_at)}</td>
        <td>
          <div class="action-btns">
            <button class="btn-icon edit" onclick="editDebt('${d.id}')">
              <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
            </button>
            <button class="btn-icon del" onclick="deleteDebt('${d.id}')">
              <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/></svg>
            </button>
          </div>
        </td>
      </tr>
    `;
  }).join('') || `<tr><td colspan="8" class="td-loading">Tidak ada hutang/piutang.</td></tr>`;

  $('info-debts').textContent = `${fmt.number(count)} record`;
  buildPagination('pag-debts', count, page, size, `(p) => loadDebts(p, ${JSON.stringify(search)}, ${JSON.stringify(type)}, ${JSON.stringify(status)})`);
}

window.editDebt = async function(id) {
  const { data: d } = await STATE.sb.from('debts').select('*').eq('id', id).single();
  if (!d) return;
  openModal('Edit Hutang/Piutang', `
    <div class="field-group"><label>Nama Kontak</label><input class="input-full" id="ed-contact" value="${esc(d.contact_name)}"></div>
    <div class="field-group"><label>Tipe</label>
      <select class="input-full" id="ed-type">
        <option value="debt" ${d.type==='debt'?'selected':''}>Hutang</option>
        <option value="loan" ${d.type==='loan'?'selected':''}>Piutang</option>
      </select>
    </div>
    <div class="field-group"><label>Jumlah</label><input class="input-full" id="ed-amount" type="number" value="${d.amount}"></div>
    <div class="field-group"><label>Status</label>
      <select class="input-full" id="ed-status">
        <option value="unpaid" ${d.status==='unpaid'?'selected':''}>Belum Lunas</option>
        <option value="paid" ${d.status==='paid'?'selected':''}>Lunas</option>
      </select>
    </div>
    <div class="field-group"><label>Jatuh Tempo</label><input class="input-full" id="ed-due" type="date" value="${d.due_date || ''}"></div>
  `, `
    <button class="btn-secondary" onclick="closeModal()">Batal</button>
    <button class="btn-primary" onclick="saveDebt('${id}')">Simpan</button>
  `);
};

window.saveDebt = async function(id) {
  const updates = { contact_name: $('ed-contact').value.trim(), type: $('ed-type').value, amount: parseFloat($('ed-amount').value), status: $('ed-status').value, due_date: $('ed-due').value || null };
  const { error } = await STATE.sb.from('debts').update(updates).eq('id', id);
  if (error) { toast('Gagal: ' + error.message, 'error'); return; }
  toast('Data diperbarui!', 'success');
  adminLog(`Edit debt ${id}`, 'success');
  closeModal();
  loadDebts();
};

window.deleteDebt = async function(id) {
  const yes = await confirm('Hapus Record?', 'Data hutang/piutang ini akan dihapus permanen.', '🗑️');
  if (!yes) return;
  const { error } = await STATE.sb.from('debts').delete().eq('id', id);
  if (error) { toast('Gagal: ' + error.message, 'error'); return; }
  toast('Data dihapus!', 'success');
  adminLog(`Hapus debt ${id}`, 'danger');
  loadDebts();
};

// ── WISHLIST PAGE ─────────────────────────────────
async function loadWishlist(page = 1, search = '', statusFilter = '') {
  const size = STATE.pageSize;
  const from = (page - 1) * size;

  let query = STATE.sb.from('wishlist').select('*, profiles(full_name,email)', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(from, from + size - 1);

  if (statusFilter === 'enabled') query = query.eq('is_enabled', true);
  if (statusFilter === 'disabled') query = query.eq('is_enabled', false);
  if (search) query = query.ilike('name', `%${search}%`);

  const { data, count, error } = await query;
  if (error) { toast('Gagal: ' + error.message, 'error'); return; }

  const tbody = $('tbody-wishlist');
  tbody.innerHTML = (data || []).map(w => `
    <tr>
      <td><strong>${esc(w.name)}</strong></td>
      <td><span style="font-size:12px">${esc(w.profiles?.full_name||w.profiles?.email||'—')}</span></td>
      <td class="money-pos">${fmt.currency(w.price)}</td>
      <td>${w.url ? `<a href="${esc(w.url)}" target="_blank" style="color:var(--accent2);font-size:12px">Buka Link ↗</a>` : '—'}</td>
      <td>${w.is_enabled ? '<span class="badge badge-active">Aktif</span>' : '<span class="badge badge-archived">Nonaktif</span>'}</td>
      <td>${fmt.date(w.created_at)}</td>
      <td>
        <div class="action-btns">
          <button class="btn-icon edit" onclick="editWishlist('${w.id}')">
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
          </button>
          <button class="btn-icon del" onclick="deleteWishlist('${w.id}')">
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/></svg>
          </button>
        </div>
      </td>
    </tr>
  `).join('') || `<tr><td colspan="7" class="td-loading">Tidak ada wishlist.</td></tr>`;

  $('info-wishlist').textContent = `${fmt.number(count)} item`;
  buildPagination('pag-wishlist', count, page, size, `(p) => loadWishlist(p, ${JSON.stringify(search)}, ${JSON.stringify(statusFilter)})`);
}

window.editWishlist = async function(id) {
  const { data: w } = await STATE.sb.from('wishlist').select('*').eq('id', id).single();
  if (!w) return;
  openModal('Edit Wishlist Item', `
    <div class="field-group"><label>Nama Item</label><input class="input-full" id="wi-name" value="${esc(w.name)}"></div>
    <div class="field-group"><label>Harga</label><input class="input-full" id="wi-price" type="number" value="${w.price}"></div>
    <div class="field-group"><label>URL</label><input class="input-full" id="wi-url" type="url" value="${esc(w.url || '')}"></div>
    <div class="field-group"><label>Status</label>
      <select class="input-full" id="wi-enabled">
        <option value="true" ${w.is_enabled?'selected':''}>Aktif</option>
        <option value="false" ${!w.is_enabled?'selected':''}>Nonaktif</option>
      </select>
    </div>
  `, `
    <button class="btn-secondary" onclick="closeModal()">Batal</button>
    <button class="btn-primary" onclick="saveWishlist('${id}')">Simpan</button>
  `);
};

window.saveWishlist = async function(id) {
  const updates = { name: $('wi-name').value.trim(), price: parseFloat($('wi-price').value), url: $('wi-url').value.trim() || null, is_enabled: $('wi-enabled').value === 'true' };
  const { error } = await STATE.sb.from('wishlist').update(updates).eq('id', id);
  if (error) { toast('Gagal: ' + error.message, 'error'); return; }
  toast('Wishlist diperbarui!', 'success');
  adminLog(`Edit wishlist ${id}`, 'success');
  closeModal();
  loadWishlist();
};

window.deleteWishlist = async function(id) {
  const yes = await confirm('Hapus Item?', 'Item wishlist ini akan dihapus permanen.', '🗑️');
  if (!yes) return;
  const { error } = await STATE.sb.from('wishlist').delete().eq('id', id);
  if (error) { toast('Gagal: ' + error.message, 'error'); return; }
  toast('Item dihapus!', 'success');
  adminLog(`Hapus wishlist ${id}`, 'danger');
  loadWishlist();
};

// ── ANALYTICS PAGE ────────────────────────────────
async function loadAnalytics() {
  try {
    const sb = STATE.sb;

    // Income vs Expense last 6 months
    const since = new Date();
    since.setMonth(since.getMonth() - 5);
    since.setDate(1);
    const { data: txnData } = await sb.from('transactions')
      .select('date,type,amount')
      .gte('date', since.toISOString().split('T')[0])
      .eq('status', 'completed')
      .in('type', ['income', 'expense']);

    const months = {};
    for (let i = 0; i < 6; i++) {
      const d = new Date();
      d.setMonth(d.getMonth() - (5 - i));
      const k = `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}`;
      months[k] = { income: 0, expense: 0, label: new Intl.DateTimeFormat('id-ID', { month: 'short', year: '2-digit' }).format(d) };
    }
    (txnData || []).forEach(t => {
      const k = t.date.slice(0,7);
      if (months[k]) {
        if (t.type === 'income') months[k].income += Number(t.amount);
        if (t.type === 'expense') months[k].expense += Number(t.amount);
      }
    });

    makeChart('chart-income-expense', 'bar',
      Object.values(months).map(m => m.label),
      [
        { label: 'Pemasukan', data: Object.values(months).map(m => m.income), backgroundColor: 'rgba(16,185,129,0.7)', borderRadius: 6 },
        { label: 'Pengeluaran', data: Object.values(months).map(m => m.expense), backgroundColor: 'rgba(239,68,68,0.7)', borderRadius: 6 },
      ],
      { legend: true }
    );

    // User growth
    const { data: users } = await sb.from('profiles').select('created_at').order('created_at');
    const ug = {};
    for (let i = 0; i < 6; i++) {
      const d = new Date();
      d.setMonth(d.getMonth() - (5 - i));
      const k = `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}`;
      ug[k] = { count: 0, label: new Intl.DateTimeFormat('id-ID', { month: 'short', year: '2-digit' }).format(d) };
    }
    (users || []).forEach(u => {
      const k = u.created_at.slice(0,7);
      if (ug[k]) ug[k].count++;
    });
    makeChart('chart-user-growth', 'line',
      Object.values(ug).map(m => m.label),
      [{ label: 'Pengguna Baru', data: Object.values(ug).map(m => m.count), borderColor: '#6366f1', backgroundColor: 'rgba(99,102,241,0.1)', tension: 0.4, fill: true }],
      { legend: false }
    );

    // Category expense distribution
    const { data: catTxn } = await sb.from('transactions').select('amount, categories(name)').eq('type', 'expense').eq('status', 'completed');
    const catMap = {};
    (catTxn || []).forEach(t => {
      const name = t.categories?.name || 'Tanpa Kategori';
      catMap[name] = (catMap[name] || 0) + Number(t.amount);
    });
    const sorted = Object.entries(catMap).sort((a,b) => b[1]-a[1]).slice(0,8);
    makeChart('chart-cat-expense', 'doughnut',
      sorted.map(e => e[0]),
      [{ data: sorted.map(e => e[1]), backgroundColor: COLORS, borderWidth: 2, borderColor: '#161821' }],
      { legend: true }
    );

    // Account type dist
    const { data: accData } = await sb.from('accounts').select('type, balance');
    const atm = {};
    (accData || []).forEach(a => { atm[a.type] = (atm[a.type] || 0) + 1; });
    const accTypeMap = { cash: 'Tunai', bank: 'Bank', ewallet: 'E-Wallet', savings: 'Tabungan', investment: 'Investasi' };
    makeChart('chart-acc-dist', 'pie',
      Object.keys(atm).map(k => accTypeMap[k] || k),
      [{ data: Object.values(atm), backgroundColor: COLORS, borderWidth: 2, borderColor: '#161821' }],
      { legend: true }
    );

    // Full stats
    const counts = await Promise.all([
      sb.from('profiles').select('*', { count: 'exact', head: true }),
      sb.from('transactions').select('*', { count: 'exact', head: true }),
      sb.from('accounts').select('*', { count: 'exact', head: true }),
      sb.from('budgets').select('*', { count: 'exact', head: true }),
      sb.from('categories').select('*', { count: 'exact', head: true }),
      sb.from('bills').select('*', { count: 'exact', head: true }),
      sb.from('saving_goals').select('*', { count: 'exact', head: true }),
      sb.from('debts').select('*', { count: 'exact', head: true }),
      sb.from('wishlist').select('*', { count: 'exact', head: true }),
      sb.from('transactions').select('*', { count: 'exact', head: true }).eq('type','income').eq('status','completed'),
      sb.from('transactions').select('*', { count: 'exact', head: true }).eq('type','expense').eq('status','completed'),
      sb.from('transactions').select('*', { count: 'exact', head: true }).eq('status','pending'),
    ]);

    const statItems = [
      ['Total Pengguna', counts[0].count],
      ['Total Transaksi', counts[1].count],
      ['Total Rekening', counts[2].count],
      ['Total Anggaran', counts[3].count],
      ['Total Kategori', counts[4].count],
      ['Total Tagihan', counts[5].count],
      ['Target Tabungan', counts[6].count],
      ['Hutang & Piutang', counts[7].count],
      ['Wishlist Items', counts[8].count],
      ['Transaksi Pemasukan', counts[9].count],
      ['Transaksi Pengeluaran', counts[10].count],
      ['Transaksi Pending', counts[11].count],
    ];

    $('full-stats').innerHTML = statItems.map(([label, val]) => `
      <div class="full-stat-item">
        <div class="label">${label}</div>
        <div class="val">${fmt.number(val)}</div>
      </div>
    `).join('');

  } catch (err) {
    toast('Gagal memuat analitik: ' + err.message, 'error');
    console.error(err);
  }
}

// ── SETTINGS PAGE ─────────────────────────────────
function loadSettings() {
  $('set-url').value = STATE.supabaseUrl;
  $('set-key').value = STATE.supabaseKey;
  renderLog();
}

// ── EXPORT CSV ────────────────────────────────────
window.exportTxnCSV = async function() {
  try {
    toast('Mengekspor transaksi...', 'info');
    const { data } = await STATE.sb.from('transactions').select('id,date,type,amount,status,note,description,tags,created_at').order('date', { ascending: false });
    if (!data || !data.length) { toast('Tidak ada data untuk diekspor.', 'warning'); return; }
    const headers = Object.keys(data[0]);
    const csv = [headers.join(','), ...data.map(row => headers.map(h => `"${(row[h] ?? '').toString().replace(/"/g, '""')}"`).join(','))].join('\n');
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url; a.download = `financier_transactions_${new Date().toISOString().split('T')[0]}.csv`;
    a.click(); URL.revokeObjectURL(url);
    toast('Berhasil mengekspor!', 'success');
    adminLog('Ekspor CSV transaksi', 'info');
  } catch (err) {
    toast('Gagal ekspor: ' + err.message, 'error');
  }
};

window.exportAllData = async function() {
  try {
    toast('Mengekspor semua data...', 'info');
    const tables = ['profiles','accounts','categories','transactions','budgets','bills','saving_goals','debts','wishlist'];
    const allData = {};
    for (const t of tables) {
      const { data } = await STATE.sb.from(t).select('*');
      allData[t] = data || [];
    }
    const blob = new Blob([JSON.stringify(allData, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url; a.download = `financier_export_${new Date().toISOString().split('T')[0]}.json`;
    a.click(); URL.revokeObjectURL(url);
    toast('Export selesai!', 'success');
    adminLog('Export semua data JSON', 'info');
  } catch (err) {
    toast('Gagal: ' + err.message, 'error');
  }
};

window.cleanTestUsers = async function() {
  const yes = await confirm('Hapus Test Users?', 'Semua pengguna dengan email yang mengandung "+test" akan dihapus.', '🧹');
  if (!yes) return;
  const { data, error } = await STATE.sb.from('profiles').select('id,email').ilike('email', '%+test%');
  if (error) { toast('Error: ' + error.message, 'error'); return; }
  if (!data || !data.length) { toast('Tidak ada test user ditemukan.', 'info'); return; }
  for (const u of data) {
    await STATE.sb.from('profiles').delete().eq('id', u.id);
  }
  toast(`${data.length} test user dihapus!`, 'success');
  adminLog(`Hapus ${data.length} test users`, 'warn');
  loadUsers();
};

// ── SEARCH DEBOUNCE ───────────────────────────────
function debounce(fn, key, ms = 350) {
  clearTimeout(STATE.searchTimers[key]);
  STATE.searchTimers[key] = setTimeout(fn, ms);
}

// ── DEFAULT CONFIG ───────────────────────────────
const DEFAULT_URL = 'https://mgyohqvbcpripmkgipvs.supabase.co';
const DEFAULT_KEY = 'sb_publishable_p0NuPgDrOUq8quIw1PFflg__T3UXHhz';
const DEFAULT_ADMIN_PW = 'admin';

// ── EVENT LISTENERS ───────────────────────────────
document.addEventListener('DOMContentLoaded', () => {

  // Auto-fill saved credentials OR use project defaults
  const savedUrl = STORE.get('url') || DEFAULT_URL;
  const savedKey = STORE.get('key') || DEFAULT_KEY;
  $('inp-url').value = savedUrl;
  $('inp-key').value = savedKey;

  // Set default admin password if first time
  if (!STORE.get('adminpw')) {
    STORE.set('adminpw', DEFAULT_ADMIN_PW);
  }

  // Login form
  $('login-form').addEventListener('submit', doLogin);

  // Toggle key visibility
  $('toggle-key').addEventListener('click', () => {
    const inp = $('inp-key');
    const isPass = inp.type === 'password';
    inp.type = isPass ? 'text' : 'password';
    $('eye-off').classList.toggle('hidden', isPass);
    $('eye-on').classList.toggle('hidden', !isPass);
  });

  // Nav links
  document.querySelectorAll('.nav-item[data-page]').forEach(el => {
    el.addEventListener('click', e => { e.preventDefault(); navigate(el.dataset.page); });
  });

  // Dashboard link buttons
  document.addEventListener('click', e => {
    const lb = e.target.closest('.link-btn[data-page]');
    if (lb) navigate(lb.dataset.page);
  });

  // Sidebar toggle
  const sidebar = document.getElementById('sidebar');
  $('sidebar-toggle').addEventListener('click', () => {
    sidebar.classList.toggle('collapsed');
  });
  $('topbar-menu').addEventListener('click', () => {
    sidebar.classList.toggle('mobile-open');
  });

  // Logout
  $('btn-logout').addEventListener('click', async () => {
    const yes = await confirm('Keluar?', 'Sesi admin akan diakhiri.', '👋');
    if (!yes) return;
    STORE.del('url'); STORE.del('key');
    STATE.sb = null;
    $('admin-app').classList.add('hidden');
    $('login-screen').classList.remove('hidden');
    Object.values(STATE.charts).forEach(c => c.destroy());
    STATE.charts = {};
    adminLog('Logout admin', 'info');
  });

  // Refresh
  $('btn-refresh').addEventListener('click', () => {
    $('btn-refresh').classList.add('spinning');
    loadPage(STATE.currentPage);
    setTimeout(() => $('btn-refresh').classList.remove('spinning'), 1000);
  });

  // Modal close
  $('modal-close').addEventListener('click', closeModal);
  $('modal-overlay').addEventListener('click', e => { if (e.target === $('modal-overlay')) closeModal(); });

  // Chart day toggles
  document.addEventListener('click', e => {
    const cb = e.target.closest('.chip-btn[data-chart]');
    if (!cb) return;
    cb.closest('.card-actions')?.querySelectorAll('.chip-btn').forEach(b => b.classList.remove('active'));
    cb.classList.add('active');
    loadDailyChart(cb.dataset.chart === '7d' ? 7 : 30);
  });

  // Search inputs
  const searches = [
    { id: 'search-users', fn: () => loadUsers(1, $('search-users').value) },
    { id: 'search-txns', fn: () => loadTransactions(1, $('search-txns').value, $('filter-txn-type').value, $('filter-txn-status').value, $('filter-txn-from').value, $('filter-txn-to').value) },
    { id: 'search-accounts', fn: () => loadAccounts(1, $('search-accounts').value, $('filter-acc-type').value, $('filter-acc-status').value) },
    { id: 'search-budgets', fn: () => loadBudgets(1, $('search-budgets').value, $('filter-budget-period').value) },
    { id: 'search-categories', fn: () => loadCategories(1, $('search-categories').value, $('filter-cat-type').value, $('filter-cat-scope').value) },
    { id: 'search-bills', fn: () => loadBills(1, $('search-bills').value, $('filter-bill-status').value) },
    { id: 'search-goals', fn: () => loadGoals(1, $('search-goals').value) },
    { id: 'search-debts', fn: () => loadDebts(1, $('search-debts').value, $('filter-debt-type').value, $('filter-debt-status').value) },
    { id: 'search-wishlist', fn: () => loadWishlist(1, $('search-wishlist').value, $('filter-wish-status').value) },
  ];
  searches.forEach(({ id, fn }) => {
    const el = $(id);
    if (el) el.addEventListener('input', () => debounce(fn, id));
  });

  // Filter selects
  const filters = [
    { id: 'filter-users-sort', fn: () => loadUsers(1, $('search-users').value, $('filter-users-sort').value) },
    { id: 'filter-txn-type', fn: () => loadTransactions(1, $('search-txns').value, $('filter-txn-type').value, $('filter-txn-status').value, $('filter-txn-from').value, $('filter-txn-to').value) },
    { id: 'filter-txn-status', fn: () => loadTransactions(1, $('search-txns').value, $('filter-txn-type').value, $('filter-txn-status').value, $('filter-txn-from').value, $('filter-txn-to').value) },
    { id: 'filter-txn-from', fn: () => loadTransactions(1, $('search-txns').value, $('filter-txn-type').value, $('filter-txn-status').value, $('filter-txn-from').value, $('filter-txn-to').value) },
    { id: 'filter-txn-to', fn: () => loadTransactions(1, $('search-txns').value, $('filter-txn-type').value, $('filter-txn-status').value, $('filter-txn-from').value, $('filter-txn-to').value) },
    { id: 'filter-acc-type', fn: () => loadAccounts(1, $('search-accounts').value, $('filter-acc-type').value, $('filter-acc-status').value) },
    { id: 'filter-acc-status', fn: () => loadAccounts(1, $('search-accounts').value, $('filter-acc-type').value, $('filter-acc-status').value) },
    { id: 'filter-budget-period', fn: () => loadBudgets(1, $('search-budgets').value, $('filter-budget-period').value) },
    { id: 'filter-cat-type', fn: () => loadCategories(1, $('search-categories').value, $('filter-cat-type').value, $('filter-cat-scope').value) },
    { id: 'filter-cat-scope', fn: () => loadCategories(1, $('search-categories').value, $('filter-cat-type').value, $('filter-cat-scope').value) },
    { id: 'filter-bill-status', fn: () => loadBills(1, $('search-bills').value, $('filter-bill-status').value) },
    { id: 'filter-debt-type', fn: () => loadDebts(1, $('search-debts').value, $('filter-debt-type').value, $('filter-debt-status').value) },
    { id: 'filter-debt-status', fn: () => loadDebts(1, $('search-debts').value, $('filter-debt-type').value, $('filter-debt-status').value) },
    { id: 'filter-wish-status', fn: () => loadWishlist(1, $('search-wishlist').value, $('filter-wish-status').value) },
  ];
  filters.forEach(({ id, fn }) => {
    const el = $(id);
    if (el) el.addEventListener('change', fn);
  });

  // Add buttons
  $('btn-add-user').addEventListener('click', openAddUser);
  $('btn-add-cat').addEventListener('click', openAddCategory);
  $('btn-export-txn').addEventListener('click', exportTxnCSV);
  $('btn-export-all').addEventListener('click', exportAllData);
  $('btn-refresh-stats').addEventListener('click', () => { loadDashboard(); toast('Stats direfresh!', 'success'); });
  $('btn-clean-test').addEventListener('click', cleanTestUsers);
  $('btn-change-conn').addEventListener('click', () => {
    STORE.del('url'); STORE.del('key');
    $('admin-app').classList.add('hidden');
    $('login-screen').classList.remove('hidden');
    $('inp-url').value = $('inp-key').value = $('inp-adminpw').value = '';
  });

  // Change password
  $('btn-change-pw').addEventListener('click', () => {
    const p1 = $('set-newpw1').value;
    const p2 = $('set-newpw2').value;
    if (!p1 || p1 !== p2) { toast('Password tidak cocok atau kosong!', 'error'); return; }
    if (p1.length < 4) { toast('Password min 4 karakter!', 'error'); return; }
    STORE.set('adminpw', p1);
    $('set-newpw1').value = $('set-newpw2').value = '';
    toast('Password admin berhasil diubah!', 'success');
    adminLog('Ganti password admin', 'warn');
  });

  // Settings key toggle
  $('set-toggle-key').addEventListener('click', () => {
    const inp = $('set-key');
    inp.type = inp.type === 'password' ? 'text' : 'password';
  });
});
