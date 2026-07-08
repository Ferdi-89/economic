/* ═══════════════════════════════════════
   FINANCIER — APP.JS
   Scripts run via `defer` → DOM is ready
   AND all CDN libs are loaded when this runs.
   No DOMContentLoaded needed.
═══════════════════════════════════════ */

// ── Config ──
const SUPABASE_URL  = 'https://mgyohqvbcpripmkgipvs.supabase.co';
const SUPABASE_KEY  = 'sb_publishable_p0NuPgDrOUq8quIw1PFflg__T3UXHhz';

// ── Init Supabase ──
const sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY);

// ── State ──
let USER       = null;
let ACCOUNTS   = [];
let CATEGORIES = [];
let TRANSACTIONS = [];
let BUDGETS    = [];
let BUDGET_ITEMS = [];
let chartBar   = null;
let chartPie   = null;
let currentTab = 'dashboard';
let txFilter   = { q: '', type: '', month: '' };

// ── Helpers ──
const $ = id => document.getElementById(id);
const idr = n => new Intl.NumberFormat('id-ID', { style:'currency', currency:'IDR', minimumFractionDigits:0, maximumFractionDigits:0 }).format(n || 0);
const today = () => new Date().toISOString().split('T')[0];
const monthNow = () => new Date().toISOString().slice(0,7);

function showLoader()  { $('loader').classList.remove('hidden'); }
function hideLoader()  { $('loader').classList.add('hidden'); }
function show(id)      { $(id).classList.remove('hidden'); }
function hide(id)      { $(id).classList.add('hidden'); }
function openModal(id) { show(id); }
function closeModal(id){ hide(id); }

// ── Auth state listener ──
sb.auth.onAuthStateChange((_event, session) => {
  if (session?.user) {
    USER = session.user;
    showApp();
  } else {
    USER = null;
    showAuthScreen();
  }
});

// ── Show auth / app ──
function showAuthScreen() {
  hideLoader();
  hide('app');
  show('auth-screen');
}

async function showApp() {
  showLoader();
  hide('auth-screen');
  show('app');
  updateUserUI();
  await loadAll();
  hideLoader();
  renderAll();
  if (window.lucide) lucide.createIcons();
}

function updateUserUI() {
  const name  = USER?.user_metadata?.full_name || USER?.email?.split('@')[0] || 'U';
  const email = USER?.email || '';
  const init  = name.charAt(0).toUpperCase();
  $('sidebar-avatar').textContent = init;
  $('sidebar-name').textContent   = name;
  $('sidebar-email').textContent  = email;
}

// ── Data loading ──
async function loadAll() {
  try {
    await Promise.all([fetchAccounts(), fetchCategories(), fetchTransactions(), fetchBudgets(), fetchWishlist()]);
  } catch (e) {
    console.error('loadAll error:', e);
  }
}

async function fetchAccounts() {
  const { data, error } = await sb.from('accounts').select('*').eq('user_id', USER.id).eq('is_active', true).order('created_at');
  if (!error) ACCOUNTS = data || [];
}
async function fetchCategories() {
  const { data, error } = await sb.from('categories').select('*').or(`user_id.eq.${USER.id},is_default.eq.true`).eq('is_active', true).order('sort_order');
  if (!error) CATEGORIES = data || [];
}
async function fetchTransactions() {
  const { data, error } = await sb.from('transactions').select('*').eq('user_id', USER.id).order('date', { ascending: false }).order('created_at', { ascending: false }).limit(200);
  if (!error) TRANSACTIONS = data || [];
}
async function fetchBudgets() {
  const { data: budgets, error: e1 } = await sb.from('budgets').select('*').eq('user_id', USER.id).eq('is_active', true);
  if (!e1) BUDGETS = budgets || [];
  if (BUDGETS.length) {
    const ids = BUDGETS.map(b => b.id);
    const { data: items, error: e2 } = await sb.from('budget_items').select('*').in('budget_id', ids);
    if (!e2) BUDGET_ITEMS = items || [];
  }
}
async function fetchWishlist() {
  try {
    const { data, error } = await sb.from('wishlist').select('*').eq('user_id', USER.id).order('created_at');
    if (error) throw error;
    WISHLIST = (data || []).map(item => ({
      id: item.id,
      name: item.name,
      price: item.price,
      url: item.url,
      isEnabled: item.is_enabled ?? true
    }));
  } catch (e) {
    console.warn('Gagal memuat wishlist dari database, menggunakan local storage:', e.message);
    const localData = localStorage.getItem('wishlist_items');
    if (localData) {
      try { WISHLIST = JSON.parse(localData); } catch(_) { WISHLIST = []; }
    }
  }
}

// ── Render all ──
function renderAll() {
  renderDashboard();
  renderTransactions();
  renderAccounts();
  renderBudgets();
  renderReports();
  renderWishlist();
  populateSelects();
}

// ── Dashboard ──
function renderDashboard() {
  const totalBalance = ACCOUNTS.reduce((s, a) => s + (a.balance || 0), 0);
  const now = monthNow();
  const monthTx = TRANSACTIONS.filter(t => t.date?.startsWith(now));
  const income   = monthTx.filter(t => t.type === 'income').reduce((s, t) => s + (t.amount || 0), 0);
  const expense  = monthTx.filter(t => t.type === 'expense').reduce((s, t) => s + (t.amount || 0), 0);

  // Wishlist simulation logic
  const totalSimulated = WISHLIST.filter(item => item.isEnabled).reduce((s, item) => s + (item.price || 0), 0);
  
  if (wishlistSimulationActive) {
    $('stat-balance').textContent = idr(totalBalance - totalSimulated);
    $('stat-accounts-count').innerHTML = `<span style="color:var(--amber); font-weight:600;">Mode Simulasi Aktif</span> (Asli: ${idr(totalBalance)})`;
  } else {
    $('stat-balance').textContent = idr(totalBalance);
    $('stat-accounts-count').textContent = `${ACCOUNTS.length} rekening aktif`;
  }

  $('stat-income').textContent  = idr(income);
  $('stat-expense').textContent = idr(expense);

  // Accounts mini list
  const accEl = $('dash-accounts');
  if (!ACCOUNTS.length) {
    accEl.innerHTML = '<div class="empty-msg">Belum ada rekening</div>';
  } else {
    accEl.innerHTML = ACCOUNTS.slice(0,5).map(a => `
      <div class="mini-item">
        <div class="mini-icon" style="background:${a.color || '#0ea5e9'}22; color:${a.color || '#0ea5e9'};">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect width="20" height="14" x="2" y="5" rx="2"/><line x1="2" x2="22" y1="10" y2="10"/></svg>
        </div>
        <div class="mini-info">
          <div class="mini-title">${a.name}</div>
          <div class="mini-sub">${accountTypeLabel(a.account_type)}</div>
        </div>
        <div class="mini-right">
          <div class="mini-amount">${idr(a.balance)}</div>
        </div>
      </div>`).join('');
  }

  // Recent tx
  const txEl = $('dash-transactions');
  if (!TRANSACTIONS.length) {
    txEl.innerHTML = '<div class="empty-msg">Belum ada transaksi</div>';
  } else {
    txEl.innerHTML = TRANSACTIONS.slice(0,5).map(t => txItemHTML(t)).join('');
  }
}

// ── Transactions ──
function renderTransactions() {
  let list = [...TRANSACTIONS];
  if (txFilter.q)    list = list.filter(t => (t.notes||'').toLowerCase().includes(txFilter.q.toLowerCase()));
  if (txFilter.type) list = list.filter(t => t.type === txFilter.type);
  if (txFilter.month) list = list.filter(t => t.date?.startsWith(txFilter.month));

  const el = $('tx-list');
  if (!list.length) {
    el.innerHTML = '<div class="empty-msg">Tidak ada transaksi yang sesuai</div>';
    return;
  }
  el.innerHTML = list.map(t => `
    <div class="tx-item">
      <div class="tx-type-badge ${t.type}">${typeIcon(t.type)}</div>
      <div class="tx-body">
        <div class="tx-note">${t.notes || '–'}</div>
        <div class="tx-meta">${categoryName(t.category_id)} · ${accountName(t.account_id)}</div>
      </div>
      <div class="tx-right">
        <div class="tx-amount ${t.type}">${t.type === 'income' ? '+' : t.type === 'expense' ? '-' : '⇄'} ${idr(t.amount)}</div>
        <div class="tx-date">${formatDate(t.date)}</div>
      </div>
      <div class="tx-actions">
        <button class="btn-icon" onclick="editTx('${t.id}')" title="Edit">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 20h9M16.5 3.5a2.12 2.12 0 0 1 3 3L7 19l-4 1 1-4Z"/></svg>
        </button>
        <button class="btn-icon btn-danger" onclick="deleteTx('${t.id}')" title="Hapus">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h18M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2"/></svg>
        </button>
      </div>
    </div>`).join('');
}

function txItemHTML(t) {
  return `
    <div class="mini-item">
      <div class="mini-icon ${t.type}">${typeIcon(t.type)}</div>
      <div class="mini-info">
        <div class="mini-title">${t.notes || categoryName(t.category_id) || '–'}</div>
        <div class="mini-sub">${accountName(t.account_id)} · ${formatDate(t.date)}</div>
      </div>
      <div class="mini-right">
        <div class="mini-amount ${t.type}">${t.type === 'income' ? '+' : t.type === 'expense' ? '-' : ''}${idr(t.amount)}</div>
      </div>
    </div>`;
}

// ── Accounts ──
function renderAccounts() {
  const el = $('accounts-grid');
  if (!ACCOUNTS.length) {
    el.innerHTML = '<div class="empty-msg">Belum ada rekening. Klik Tambah untuk membuat rekening baru!</div>';
    return;
  }
  el.innerHTML = ACCOUNTS.map(a => `
    <div class="account-card" style="--card-color:${a.color || '#0ea5e9'}">
      <div class="acc-type-label">${accountTypeLabel(a.account_type)}</div>
      <div class="acc-name">${a.name}</div>
      <div class="acc-balance">${idr(a.balance)}</div>
      <div class="acc-footer">
        <span class="acc-bank">${a.bank_name || a.account_number || ''}</span>
        <div class="acc-actions">
          <button onclick="editAccount('${a.id}')">Ubah</button>
          <button onclick="deleteAccount('${a.id}')" title="Hapus">
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h18M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2"/></svg>
          </button>
        </div>
      </div>
    </div>`).join('');
}

// ── Budgets ──
function renderBudgets() {
  const el = $('budgets-grid');
  if (!BUDGETS.length) {
    el.innerHTML = '<div class="empty-msg">Belum ada anggaran. Klik Tambah untuk membuat anggaran!</div>';
    return;
  }
  const now = monthNow();
  el.innerHTML = BUDGETS.map(b => {
    const itemIds  = BUDGET_ITEMS.filter(i => i.budget_id === b.id).map(i => i.category_id);
    const spent    = TRANSACTIONS
      .filter(t => t.type === 'expense' && t.date?.startsWith(now) && itemIds.includes(t.category_id))
      .reduce((s, t) => s + (t.amount || 0), 0);
    const pct      = b.monthly_limit ? Math.min(Math.round(spent / b.monthly_limit * 100), 100) : 0;
    const over     = spent > b.monthly_limit;
    const catNames = itemIds.map(id => categoryName(id)).filter(Boolean);
    return `
      <div class="budget-card" style="--bud-accent:${b.color || '#10b981'}">
        <div class="bud-header">
          <div class="bud-name-wrap">
            <span class="bud-name">${b.name}</span>
            <span class="bud-period">Bulan Ini</span>
          </div>
          <button class="btn-icon" onclick="deleteBudget('${b.id}')" title="Hapus">🗑️</button>
        </div>
        <div class="bud-numbers">
          <span class="bud-spent" style="color:${over?'var(--red)':'inherit'}">${idr(spent)}</span>
          <span class="bud-of">dari</span>
          <span class="bud-limit">${idr(b.monthly_limit)}</span>
        </div>
        <div class="progress-track">
          <div class="progress-bar${over?' over':''}" style="width:${pct}%"></div>
        </div>
        <div class="bud-meta">
          <span class="bud-pct${over?' over':''}">${pct}% terpakai</span>
          <span>${over ? 'Melebihi Limit! ⚠️' : 'Aman'}</span>
        </div>
        ${catNames.length ? `<div class="bud-tags">${catNames.map(n=>`<span class="bud-tag">${n}</span>`).join('')}</div>` : ''}
      </div>`;
  }).join('');
}

// ── Reports ──
function renderReports() {
  renderBarChart();
  renderPieChart();
  renderSummaryStats();
}

function renderSummaryStats() {
  const now = monthNow();
  const monthTx = TRANSACTIONS.filter(t => t.date?.startsWith(now));
  
  const income  = monthTx.filter(t => t.type === 'income').reduce((s, t) => s + (t.amount || 0), 0);
  const expense = monthTx.filter(t => t.type === 'expense').reduce((s, t) => s + (t.amount || 0), 0);
  const netSavings = income - expense;
  
  // 1. Savings Rate
  const savingsRate = income > 0 ? Math.round((netSavings / income) * 100) : 0;
  const savingsRateEl = $('report-savings-rate');
  if (savingsRateEl) {
    savingsRateEl.textContent = `${savingsRate}%`;
    savingsRateEl.style.color = netSavings >= 0 ? 'var(--green)' : 'var(--red)';
  }
  const savingsValEl = $('report-savings-value');
  if (savingsValEl) {
    savingsValEl.textContent = `Bersih: ${idr(netSavings)}`;
  }
  
  // 2. Average Expense
  const expenses = monthTx.filter(t => t.type === 'expense');
  const avgExpense = expenses.length > 0 ? Math.round(expense / expenses.length) : 0;
  const avgExpenseEl = $('report-avg-expense');
  if (avgExpenseEl) {
    avgExpenseEl.textContent = idr(avgExpense);
  }
  const avgSubEl = $('report-avg-sub');
  if (avgSubEl) {
    avgSubEl.textContent = `${expenses.length} transaksi bulan ini`;
  }
  
  // 3. Top Category
  const catMap = {};
  expenses.forEach(t => {
    catMap[t.category_id] = (catMap[t.category_id] || 0) + t.amount;
  });
  let topCatId = null;
  let topCatVal = 0;
  for (const cid in catMap) {
    if (catMap[cid] > topCatVal) {
      topCatVal = catMap[cid];
      topCatId = cid;
    }
  }
  const topCatEl = $('report-top-category');
  if (topCatEl) {
    topCatEl.textContent = topCatId ? categoryName(topCatId) : '–';
  }
  const topCatValEl = $('report-top-category-value');
  if (topCatValEl) {
    topCatValEl.textContent = topCatId ? `Total: ${idr(topCatVal)}` : 'Belum ada pengeluaran';
  }
}

function renderBarChart() {
  const ctx = $('chart-bar')?.getContext('2d');
  if (!ctx) return;
  const months = getLast6Months();
  const incomes  = months.map(m => TRANSACTIONS.filter(t => t.type==='income'  && t.date?.startsWith(m)).reduce((s,t)=>s+t.amount,0));
  const expenses = months.map(m => TRANSACTIONS.filter(t => t.type==='expense' && t.date?.startsWith(m)).reduce((s,t)=>s+t.amount,0));
  if (chartBar) chartBar.destroy();

  const textColor = getComputedStyle(document.documentElement).getPropertyValue('--text-secondary').trim() || '#94a3b8';
  const gridColor = getComputedStyle(document.documentElement).getPropertyValue('--border-strong').trim() || 'rgba(120,120,120,0.1)';

  chartBar = new Chart(ctx, {
    type: 'bar',
    data: {
      labels: months.map(m => { const d=new Date(m+'-01'); return d.toLocaleDateString('id-ID',{month:'short',year:'2-digit'}); }),
      datasets: [
        { label:'Pemasukan',  data: incomes,  backgroundColor:'rgba(16,185,129,.7)',  borderRadius:4 },
        { label:'Pengeluaran',data: expenses, backgroundColor:'rgba(239,68,68,.7)',   borderRadius:4 }
      ]
    },
    options: { 
      responsive:true, 
      maintainAspectRatio:false, 
      plugins:{legend:{labels:{color:textColor}}}, 
      scales:{
        x:{ticks:{color:textColor},grid:{color:gridColor}},
        y:{ticks:{color:textColor,callback:v=>idr(v)},grid:{color:gridColor}}
      }
    }
  });
}

function renderPieChart() {
  const ctx = $('chart-pie')?.getContext('2d');
  if (!ctx) return;
  const now = monthNow();
  const expTx = TRANSACTIONS.filter(t => t.type==='expense' && t.date?.startsWith(now));
  const catMap = {};
  expTx.forEach(t => {
    const name = categoryName(t.category_id) || 'Lainnya';
    catMap[name] = (catMap[name] || 0) + t.amount;
  });
  const labels = Object.keys(catMap);
  const values = Object.values(catMap);
  const colors = ['#6366f1','#10b981','#f59e0b','#ef4444','#8b5cf6','#ec4899','#0ea5e9','#14b8a6'];
  if (chartPie) chartPie.destroy();

  const textColor = getComputedStyle(document.documentElement).getPropertyValue('--text-secondary').trim() || '#94a3b8';

  chartPie = new Chart(ctx, {
    type: 'doughnut',
    data: { labels, datasets:[{ data:values, backgroundColor:colors.slice(0,labels.length), borderWidth:0 }] },
    options: { 
      responsive:true, 
      maintainAspectRatio:false, 
      cutout:'60%', 
      plugins:{legend:{position:'bottom',labels:{color:textColor,padding:12}}} 
    }
  });
}

function getLast6Months() {
  const months = [];
  const d = new Date();
  for (let i = 5; i >= 0; i--) {
    const m = new Date(d.getFullYear(), d.getMonth() - i, 1);
    months.push(`${m.getFullYear()}-${String(m.getMonth()+1).padStart(2,'0')}`);
  }
  return months;
}

// ── Populate Selects ──
function populateSelects() {
  // Account selects
  const accOpts = ACCOUNTS.map(a => `<option value="${a.id}">${a.name}</option>`).join('');
  $('tx-account').innerHTML   = '<option value="">Pilih rekening</option>' + accOpts;
  $('tx-to-account').innerHTML = '<option value="">Pilih tujuan</option>' + accOpts;
  $('filter-account') && ($('filter-account').innerHTML = '<option value="">Semua Rekening</option>' + accOpts);

  // tx-category will be populated dynamically inside setTxType() to ensure cross-browser compatibility

  // Budget category checkboxes
  const budCats = $('bud-cats');
  if (budCats) {
    budCats.innerHTML = CATEGORIES.filter(c => c.type === 'expense' || c.type === 'both').map(c => `
      <label class="checkbox-item">
        <input type="checkbox" name="bud-cat" value="${c.id}">
        <span>${c.name}</span>
      </label>`).join('');
  }

  // Filter month default
  if ($('filter-month') && !$('filter-month').value) $('filter-month').value = monthNow();
  txFilter.month = monthNow();
}

// ── Navigation ──
function switchTab(tab) {
  currentTab = tab;
  document.querySelectorAll('.panel').forEach(p => p.classList.add('hidden'));
  document.querySelectorAll('.nav-item, .bottom-nav-item').forEach(n => {
    n.classList.toggle('active', n.dataset.tab === tab);
  });
  const panel = $(`tab-${tab}`);
  if (panel) panel.classList.remove('hidden');
  $('page-title').textContent = { dashboard:'Dashboard', transactions:'Transaksi', accounts:'Rekening', budgets:'Anggaran', reports:'Laporan' }[tab] || tab;
  if (tab === 'reports') renderReports();
}

// ── CRUD: Transactions ──
function openTxModal(type = 'expense') {
  $('tx-edit-id').value = '';
  $('form-tx').reset();
  $('tx-date').value = today();
  populateSelects();
  setTxType(type);
  openModal('modal-tx');
}

function setTxType(type) {
  document.querySelectorAll('.seg-tab').forEach(t => {
    t.classList.toggle('active', t.dataset.type === type);
    t.querySelector('input').checked = t.dataset.type === type;
  });
  $('tx-to-field').style.display  = type === 'transfer' ? '' : 'none';
  $('tx-cat-field').style.display = type === 'transfer' ? 'none' : '';
  
  // Rebuild category options dynamically (works 100% on Safari, Chrome, and Mobile browsers)
  const filteredCats = CATEGORIES.filter(c => 
    c.type === 'both' || 
    c.type === type || 
    (type === 'income' && c.type === 'income') || 
    (type === 'expense' && c.type === 'expense')
  );
  
  $('tx-category').innerHTML = '<option value="">Pilih kategori…</option>' +
    filteredCats.map(c => `<option value="${c.id}">${c.name}</option>`).join('');
}

$('form-tx').addEventListener('submit', async e => {
  e.preventDefault();
  const type     = document.querySelector('.seg-tab.active')?.dataset.type || 'expense';
  const amount   = parseFloat($('tx-amount').value);
  const accountId= $('tx-account').value;
  const catId    = $('tx-category').value;
  const toAccId  = $('tx-to-account').value;
  const date     = $('tx-date').value;
  const notes    = $('tx-note').value.trim();
  const editId   = $('tx-edit-id').value;

  if (!amount || amount <= 0) return alert('Jumlah harus lebih dari 0');
  if (!accountId) return alert('Pilih rekening');
  if (type !== 'transfer' && !catId) return alert('Pilih kategori');
  if (type === 'transfer' && !toAccId) return alert('Pilih rekening tujuan');

  showLoader();
  try {
    if (editId) {
      const oldTx = TRANSACTIONS.find(t => t.id === editId);
      await sb.from('transactions').update({ type, amount, account_id: accountId, category_id: catId || null, transfer_to_account_id: toAccId || null, date, notes }).eq('id', editId);
      
      if (oldTx) {
        // 1. Revert old transaction effect on account balances
        const oldAcc = ACCOUNTS.find(a => a.id === oldTx.account_id);
        if (oldAcc) {
          let revDelta = oldTx.type === 'income' ? -oldTx.amount : oldTx.amount;
          let newBal = (oldAcc.balance || 0) + revDelta;
          await sb.from('accounts').update({ balance: newBal }).eq('id', oldTx.account_id);
          oldAcc.balance = newBal; // Temporarily update local reference
        }
        if (oldTx.type === 'transfer' && oldTx.transfer_to_account_id) {
          const oldToAcc = ACCOUNTS.find(a => a.id === oldTx.transfer_to_account_id);
          if (oldToAcc) {
            let newBal = (oldToAcc.balance || 0) - oldTx.amount;
            await sb.from('accounts').update({ balance: newBal }).eq('id', oldTx.transfer_to_account_id);
            oldToAcc.balance = newBal;
          }
        }
        
        // Reload ACCOUNTS to fetch latest modified balances
        await fetchAccounts();
        
        // 2. Apply new transaction effect on account balances
        const newAcc = ACCOUNTS.find(a => a.id === accountId);
        if (newAcc) {
          let newDelta = type === 'income' ? amount : -amount;
          await sb.from('accounts').update({ balance: (newAcc.balance || 0) + newDelta }).eq('id', accountId);
        }
        if (type === 'transfer' && toAccId) {
          const newToAcc = ACCOUNTS.find(a => a.id === toAccId);
          if (newToAcc) {
            await sb.from('accounts').update({ balance: (newToAcc.balance || 0) + amount }).eq('id', toAccId);
          }
        }
      }
    } else {
      await sb.from('transactions').insert({ user_id: USER.id, type, amount, account_id: accountId, category_id: catId || null, transfer_to_account_id: toAccId || null, date, notes });
      // Update balance
      const account = ACCOUNTS.find(a => a.id === accountId);
      if (account) {
        const delta = type === 'income' ? amount : -amount;
        await sb.from('accounts').update({ balance: (account.balance || 0) + delta }).eq('id', accountId);
        if (type === 'transfer' && toAccId) {
          const toAcc = ACCOUNTS.find(a => a.id === toAccId);
          if (toAcc) await sb.from('accounts').update({ balance: (toAcc.balance || 0) + amount }).eq('id', toAccId);
        }
      }
    }
    closeModal('modal-tx');
    await loadAll();
    renderAll();
  } catch(err) {
    alert('Gagal menyimpan transaksi: ' + err.message);
  } finally {
    hideLoader();
  }
});

async function editTx(id) {
  const t = TRANSACTIONS.find(t => t.id === id);
  if (!t) return;
  $('tx-edit-id').value = id;
  $('tx-amount').value  = t.amount;
  $('tx-date').value    = t.date;
  $('tx-note').value    = t.notes || '';
  populateSelects();
  setTxType(t.type);
  $('tx-account').value    = t.account_id || '';
  $('tx-category').value   = t.category_id || '';
  $('tx-to-account').value = t.transfer_to_account_id || '';
  openModal('modal-tx');
}

async function deleteTx(id) {
  if (!confirm('Hapus transaksi ini?')) return;
  showLoader();
  try {
    const t = TRANSACTIONS.find(t => t.id === id);
    await sb.from('transactions').delete().eq('id', id);
    if (t) {
      const account = ACCOUNTS.find(a => a.id === t.account_id);
      if (account) {
        const delta = t.type === 'income' ? -t.amount : t.type === 'expense' ? t.amount : t.amount;
        await sb.from('accounts').update({ balance: (account.balance || 0) + delta }).eq('id', t.account_id);
        if (t.type === 'transfer' && t.transfer_to_account_id) {
          const toAcc = ACCOUNTS.find(a => a.id === t.transfer_to_account_id);
          if (toAcc) await sb.from('accounts').update({ balance: (toAcc.balance || 0) - t.amount }).eq('id', t.transfer_to_account_id);
        }
      }
    }
    await loadAll(); renderAll();
  } catch(err) { alert('Gagal: ' + err.message); }
  finally { hideLoader(); }
}

// ── CRUD: Accounts ──
function openAccountModal() {
  $('acc-edit-id').value = '';
  $('form-account').reset();
  document.querySelector('[name="acc-color"][value="#0ea5e9"]').checked = true;
  openModal('modal-account');
}

$('form-account').addEventListener('submit', async e => {
  e.preventDefault();
  const editId  = $('acc-edit-id').value;
  const name    = $('acc-name').value.trim();
  const type    = $('acc-type').value;
  const balance = parseFloat($('acc-balance').value) || 0;
  const bank    = $('acc-bank').value.trim();
  const number  = $('acc-number').value.trim();
  const color   = document.querySelector('[name="acc-color"]:checked')?.value || '#0ea5e9';
  if (!name) return alert('Nama rekening wajib diisi');

  showLoader();
  try {
    if (editId) {
      await sb.from('accounts').update({ name, account_type: type, balance, bank_name: bank, account_number: number, color }).eq('id', editId);
    } else {
      await sb.from('accounts').insert({ user_id: USER.id, name, account_type: type, balance, bank_name: bank, account_number: number, color, is_active: true });
    }
    closeModal('modal-account');
    await loadAll(); renderAll();
  } catch(err) { alert('Gagal: ' + err.message); }
  finally { hideLoader(); }
});

async function editAccount(id) {
  const a = ACCOUNTS.find(a => a.id === id);
  if (!a) return;
  $('acc-edit-id').value = id;
  $('acc-name').value    = a.name;
  $('acc-type').value    = a.account_type;
  $('acc-balance').value = a.balance;
  $('acc-bank').value    = a.bank_name || '';
  $('acc-number').value  = a.account_number || '';
  const colorRadio = document.querySelector(`[name="acc-color"][value="${a.color}"]`);
  if (colorRadio) colorRadio.checked = true;
  openModal('modal-account');
}

async function deleteAccount(id) {
  if (!confirm('Hapus rekening ini? Semua transaksi terkait akan tetap ada.')) return;
  showLoader();
  try {
    await sb.from('accounts').update({ is_active: false }).eq('id', id);
    await loadAll(); renderAll();
  } catch(err) { alert('Gagal: ' + err.message); }
  finally { hideLoader(); }
}

// ── CRUD: Budgets ──
function openBudgetModal() {
  $('bud-edit-id').value = '';
  $('form-budget').reset();
  document.querySelector('[name="bud-color"][value="#10b981"]').checked = true;
  populateSelects();
  openModal('modal-budget');
}

$('form-budget').addEventListener('submit', async e => {
  e.preventDefault();
  const name   = $('bud-name').value.trim();
  const amount = parseFloat($('bud-amount').value) || 0;
  const color  = document.querySelector('[name="bud-color"]:checked')?.value || '#10b981';
  const catIds = [...document.querySelectorAll('[name="bud-cat"]:checked')].map(c => c.value);
  if (!name) return alert('Nama anggaran wajib diisi');
  if (!amount) return alert('Batas anggaran harus lebih dari 0');

  showLoader();
  try {
    const { data: bud, error } = await sb.from('budgets').insert({ user_id: USER.id, name, monthly_limit: amount, color, is_active: true }).select().single();
    if (error) throw error;
    if (catIds.length && bud) {
      await sb.from('budget_items').insert(catIds.map(cid => ({ budget_id: bud.id, category_id: cid })));
    }
    closeModal('modal-budget');
    await loadAll(); renderAll();
  } catch(err) { alert('Gagal: ' + err.message); }
  finally { hideLoader(); }
});

async function deleteBudget(id) {
  if (!confirm('Hapus anggaran ini?')) return;
  showLoader();
  try {
    await sb.from('budget_items').delete().eq('budget_id', id);
    await sb.from('budgets').update({ is_active: false }).eq('id', id);
    await loadAll(); renderAll();
  } catch(err) { alert('Gagal: ' + err.message); }
  finally { hideLoader(); }
}

// ── Auth ──
let isSignUp = false;

function toggleAuthMode(signUp) {
  isSignUp = signUp;
  $('auth-title').textContent    = signUp ? 'Buat Akun Baru' : 'Masuk ke Akun';
  $('auth-subtitle').textContent = signUp ? 'Mulai kelola keuangan Anda hari ini' : 'Kelola keuangan Anda secara realtime';
  $('auth-btn-text').textContent = signUp ? 'Daftar' : 'Masuk';
  $('auth-switch-label').textContent = signUp ? 'Sudah punya akun?' : 'Belum punya akun?';
  $('auth-switch-btn').textContent  = signUp ? 'Masuk sekarang' : 'Daftar sekarang';
  signUp ? show('name-field') : hide('name-field');
  hide('auth-error');
}

$('auth-switch-btn').addEventListener('click', () => toggleAuthMode(!isSignUp));

$('btn-pw-toggle').addEventListener('click', () => {
  const inp = $('input-password');
  const isPw = inp.type === 'password';
  inp.type = isPw ? 'text' : 'password';
  $('eye-off').classList.toggle('hidden', !isPw);
  $('eye-on').classList.toggle('hidden', isPw);
});

$('auth-form').addEventListener('submit', async e => {
  e.preventDefault();
  const email    = $('input-email').value.trim();
  const password = $('input-password').value;
  const name     = $('input-name').value.trim();

  hide('auth-error');
  $('auth-btn-text').classList.add('hidden');
  show('auth-btn-spinner');
  $('auth-submit').disabled = true;

  try {
    let result;
    if (isSignUp) {
      result = await sb.auth.signUp({ email, password, options: { data: { full_name: name } } });
    } else {
      result = await sb.auth.signInWithPassword({ email, password });
    }
    if (result.error) throw result.error;
    if (isSignUp && !result.data?.session) {
      showAuthError('Pendaftaran berhasil! Silakan cek email Anda untuk konfirmasi.');
    }
  } catch(err) {
    showAuthError(translateAuthError(err.message));
  } finally {
    $('auth-btn-text').classList.remove('hidden');
    hide('auth-btn-spinner');
    $('auth-submit').disabled = false;
  }
});

function showAuthError(msg) {
  $('auth-error').textContent = msg;
  show('auth-error');
}

function translateAuthError(msg) {
  if (msg.includes('Invalid login credentials')) return 'Email atau kata sandi salah.';
  if (msg.includes('Email not confirmed'))       return 'Email belum dikonfirmasi. Cek kotak masuk email Anda.';
  if (msg.includes('User already registered'))   return 'Email sudah terdaftar. Silakan masuk.';
  if (msg.includes('Password should be'))        return 'Kata sandi minimal 6 karakter.';
  return msg;
}

$('btn-logout').addEventListener('click', async () => {
  if (!confirm('Yakin ingin keluar?')) return;
  await sb.auth.signOut();
});

// ── Theme ──
function initTheme() {
  const saved = localStorage.getItem('theme') || 'dark';
  document.documentElement.dataset.theme = saved;
  updateThemeIcon(saved);
}

function toggleTheme() {
  const curr = document.documentElement.dataset.theme;
  const next = curr === 'dark' ? 'light' : 'dark';
  document.documentElement.dataset.theme = next;
  localStorage.setItem('theme', next);
  updateThemeIcon(next);
}

function updateThemeIcon(theme) {
  document.querySelectorAll('.icon-sun').forEach(el => el.classList.toggle('hidden', theme === 'light'));
  document.querySelectorAll('.icon-moon').forEach(el => el.classList.toggle('hidden', theme === 'dark'));
}

// ── Filter Listeners ──
$('filter-q').addEventListener('input', e => { txFilter.q = e.target.value; renderTransactions(); });
$('filter-type').addEventListener('change', e => { txFilter.type = e.target.value; renderTransactions(); });
$('filter-month').addEventListener('change', e => { txFilter.month = e.target.value; renderTransactions(); });
$('btn-reset-filter').addEventListener('click', () => {
  txFilter = { q:'', type:'', month: monthNow() };
  $('filter-q').value = '';
  $('filter-type').value = '';
  $('filter-month').value = monthNow();
  renderTransactions();
});

// ── Quick Add ──
function openQuickMenu() {
  const menu = $('quick-menu');
  menu.classList.toggle('hidden');
}
$('btn-add').addEventListener('click', openQuickMenu);
$('mobile-add').addEventListener('click', e => { e.preventDefault(); openQuickMenu(); });
$('quick-menu').querySelector('.quick-backdrop').addEventListener('click', () => hide('quick-menu'));

document.querySelectorAll('.quick-item').forEach(btn => {
  btn.addEventListener('click', () => {
    hide('quick-menu');
    const action = btn.dataset.action;
    if (action === 'account') { openAccountModal(); return; }
    if (action === 'budget')  { openBudgetModal();  return; }
    openTxModal(action);
  });
});

// ── Nav ──
document.querySelectorAll('[data-tab]').forEach(el => {
  el.addEventListener('click', e => { e.preventDefault(); switchTab(el.dataset.tab); });
});
document.querySelectorAll('[data-tab-go]').forEach(el => {
  el.addEventListener('click', e => { e.preventDefault(); switchTab(el.dataset.tabGo); });
});

// ── Modal close ──
document.querySelectorAll('.modal-close').forEach(btn => {
  btn.addEventListener('click', () => { const mid = btn.dataset.modal; if (mid) closeModal(mid); });
});
document.querySelectorAll('.modal').forEach(modal => {
  modal.addEventListener('click', e => { if (e.target === modal) closeModal(modal.id); });
});

// ── Segment tabs ──
document.querySelectorAll('.seg-tab').forEach(tab => {
  tab.addEventListener('click', () => {
    const type = tab.dataset.type;
    setTxType(type);
  });
});

// ── Theme button ──
$('btn-theme').addEventListener('click', toggleTheme);

// ── Util ──
function accountName(id)   { return ACCOUNTS.find(a => a.id === id)?.name || '–'; }
function categoryName(id)  { return CATEGORIES.find(c => c.id === id)?.name || '–'; }
function accountTypeLabel(t) {
  return { cash:'Tunai', bank:'Bank', ewallet:'E-Wallet', savings:'Tabungan', investment:'Investasi' }[t] || t;
}
function typeIcon(t) {
  if (t === 'income') {
    return `<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M7 17L17 7M17 7H7M17 7V17"/></svg>`;
  }
  if (t === 'expense') {
    return `<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M7 7l10 10M17 7v10H7"/></svg>`;
  }
  return `<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M20 17H4M4 17l4 4M4 17l4-4M4 7h16M20 7l-4-4M20 7l-4 4"/></svg>`;
}
function typeColor(t)  { return { income:'#10b981', expense:'#ef4444', transfer:'#f59e0b' }[t] || '#6366f1'; }
function formatDate(d) {
  if (!d) return '';
  return new Date(d + 'T00:00:00').toLocaleDateString('id-ID', { day:'numeric', month:'short', year:'numeric' });
}

// ── Wishlist Simulation Logic ──
let WISHLIST = [];
let wishlistSimulationActive = false;

function initWishlist() {
  const data = localStorage.getItem('wishlist_items');
  if (data) {
    try { WISHLIST = JSON.parse(data); } catch(e) { WISHLIST = []; }
  }
  wishlistSimulationActive = localStorage.getItem('wishlist_sim_active') === 'true';
  
  const toggle = $('wishlist-sim-toggle');
  if (toggle) {
    toggle.checked = wishlistSimulationActive;
    // Remove previous listeners first to prevent duplicates
    const newToggle = toggle.cloneNode(true);
    toggle.parentNode.replaceChild(newToggle, toggle);
    newToggle.addEventListener('change', e => {
      wishlistSimulationActive = e.target.checked;
      localStorage.setItem('wishlist_sim_active', wishlistSimulationActive);
      renderAll();
    });
  }
  
  const form = $('form-wishlist');
  if (form) {
    // Prevent duplicate event listener registration
    const newForm = form.cloneNode(true);
    form.parentNode.replaceChild(newForm, form);
    newForm.addEventListener('submit', async e => {
      e.preventDefault();
      const name = $('wish-name').value.trim();
      const price = parseFloat($('wish-price').value) || 0;
      const url = $('wish-url').value.trim();
      if (!name) return alert('Nama barang wajib diisi');
      if (price <= 0) return alert('Harga barang harus lebih dari 0');
      
      showLoader();
      try {
        const newItem = {
          user_id: USER.id,
          name,
          price,
          url: url || null,
          is_enabled: true
        };
        
        const { data: dbItem, error } = await sb.from('wishlist').insert(newItem).select().single();
        if (error) throw error;
        
        if (dbItem) {
          WISHLIST.push({
            id: dbItem.id,
            name: dbItem.name,
            price: dbItem.price,
            url: dbItem.url,
            isEnabled: dbItem.is_enabled ?? true
          });
        } else {
          newItem.id = Date.now().toString();
          newItem.isEnabled = true;
          WISHLIST.push(newItem);
        }
        saveWishlistLocal();
        closeModal('modal-wishlist');
        renderAll();
      } catch(err) {
        console.warn('Gagal menyimpan ke database Supabase, menyimpan lokal:', err.message);
        // Fallback to local storage
        const item = {
          id: Date.now().toString(),
          name,
          price,
          url: url || null,
          isEnabled: true
        };
        WISHLIST.push(item);
        saveWishlistLocal();
        closeModal('modal-wishlist');
        renderAll();
      } finally {
        hideLoader();
      }
    });
  }
  
  const btnAdd = $('btn-add-wishlist');
  if (btnAdd) {
    const newBtnAdd = btnAdd.cloneNode(true);
    btnAdd.parentNode.replaceChild(newBtnAdd, btnAdd);
    newBtnAdd.addEventListener('click', () => {
      $('form-wishlist').reset();
      openModal('modal-wishlist');
    });
  }
}

function saveWishlistLocal() {
  localStorage.setItem('wishlist_items', JSON.stringify(WISHLIST));
}

async function deleteWishlistItem(id) {
  if (!confirm('Hapus barang ini dari wishlist?')) return;
  showLoader();
  try {
    const { error } = await sb.from('wishlist').delete().eq('id', id);
    if (error) throw error;
  } catch (err) {
    console.warn('Gagal menghapus dari database, melakukan hapus lokal:', err.message);
  }
  WISHLIST = WISHLIST.filter(item => item.id !== id);
  saveWishlistLocal();
  renderAll();
  hideLoader();
}

async function toggleWishlistItem(id) {
  const item = WISHLIST.find(i => i.id === id);
  if (!item) return;
  const nextState = !item.isEnabled;
  
  showLoader();
  try {
    const { error } = await sb.from('wishlist').update({ is_enabled: nextState }).eq('id', id);
    if (error) throw error;
  } catch (err) {
    console.warn('Gagal memperbarui database, melakukan pembaruan lokal:', err.message);
  }
  item.isEnabled = nextState;
  saveWishlistLocal();
  renderAll();
  hideLoader();
}

function renderWishlist() {
  const listEl = $('wishlist-items-list');
  if (!listEl) return;
  
  const totalBalance = ACCOUNTS.reduce((s, a) => s + (a.balance || 0), 0);
  const totalSimulated = WISHLIST.filter(item => item.isEnabled).reduce((s, item) => s + (item.price || 0), 0);
  
  const realBalEl = $('wishlist-real-balance');
  if (realBalEl) realBalEl.textContent = idr(totalBalance);
  
  const totalPrEl = $('wishlist-total-price');
  if (totalPrEl) totalPrEl.textContent = `- ${idr(totalSimulated)}`;
  
  const simBalEl = $('wishlist-simulated-balance');
  if (simBalEl) {
    simBalEl.textContent = idr(wishlistSimulationActive ? (totalBalance - totalSimulated) : totalBalance);
    simBalEl.style.color = wishlistSimulationActive ? 'var(--amber)' : 'var(--text-primary)';
  }
  
  const labelEl = $('wishlist-estimate-label');
  if (labelEl) {
    labelEl.textContent = wishlistSimulationActive ? 'Estimasi Sisa Saldo (Simulasi)' : 'Total Saldo Asli';
  }
  
  if (!WISHLIST.length) {
    listEl.innerHTML = '<div class="empty-msg" style="padding: 30px 16px;">Belum ada barang di wishlist simulasi</div>';
    return;
  }
  
  listEl.innerHTML = WISHLIST.map(item => {
    const isChecked = item.isEnabled ? 'checked' : '';
    const nameStyle = item.isEnabled ? '' : 'text-decoration: line-through; color: var(--text-muted);';
    const priceStyle = item.isEnabled && wishlistSimulationActive ? 'color: var(--brand); font-weight: 700;' : 'color: var(--text-secondary);';
    
    const linkBtn = item.url ? `
      <a href="${item.url}" target="_blank" class="btn-icon" title="Buka Link Barang" style="color:var(--brand); display:inline-flex; align-items:center;">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/></svg>
      </a>` : '';
      
    return `
      <div class="mini-item" style="padding: 10px 16px; align-items: center;">
        <input type="checkbox" ${isChecked} onchange="toggleWishlistItem('${item.id}')" style="width: 16px; height: 16px; accent-color: var(--text-primary); cursor: pointer; margin-right: 8px;">
        <div class="mini-info" style="margin-left: 0;">
          <div class="mini-title" style="${nameStyle}">${item.name}</div>
          <div class="mini-sub" style="${priceStyle}">${idr(item.price)}</div>
        </div>
        <div style="display: flex; align-items: center; gap: 4px;">
          ${linkBtn}
          <button class="btn-icon btn-danger" onclick="deleteWishlistItem('${item.id}')" title="Hapus">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h18M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2"/></svg>
          </button>
        </div>
      </div>
    `;
  }).join('');
}

// Bind to window to allow inline html event calls
window.toggleWishlistItem = toggleWishlistItem;
window.deleteWishlistItem = deleteWishlistItem;

// ── Init theme and wishlist ──
initTheme();
initWishlist();
