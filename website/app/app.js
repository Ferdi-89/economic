// ════════ FINANCIER APP JAVASCRIPT ════════

// 1. Supabase Initialization
const SUPABASE_URL = 'https://mgyohqvbcpripmkgipvs.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_p0NuPgDrOUq8quIw1PFflg__T3UXHhz';

const supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// 2. Global State Variables
let currentUser = null;
let currentProfile = null;
let userAccounts = [];
let userCategories = [];
let userTransactions = [];
let userBudgets = [];
let userBudgetItems = [];

// Chart instances
let incomeExpenseChart = null;
let categoryChart = null;

// UI State
let isSignUpMode = false;
let currentTab = 'overview';

// 3. Helper Functions
function showElement(id) {
  document.getElementById(id).classList.remove('hidden');
}

function hideElement(id) {
  document.getElementById(id).classList.add('hidden');
}

function showLoader() {
  showElement('global-loader');
}

function hideLoader() {
  hideElement('global-loader');
}

// Format Currency to IDR (Rupiah)
function formatIDR(amount) {
  return new Intl.NumberFormat('id-ID', {
    style: 'currency',
    currency: 'IDR',
    minimumFractionDigits: 0,
    maximumFractionDigits: 0
  }).format(amount);
}

// Format date to local Indonesian format
function formatDate(dateString) {
  const options = { day: 'numeric', month: 'short', year: 'numeric' };
  return new Date(dateString).toLocaleDateString('id-ID', options);
}

// 4. Initial Theme Setup & Theme Switcher
function initTheme() {
  const savedTheme = localStorage.getItem('theme') || 'dark';
  document.documentElement.setAttribute('data-theme', savedTheme);
  updateThemeIcons(savedTheme);
}

function toggleTheme() {
  const currentTheme = document.documentElement.getAttribute('data-theme');
  const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
  document.documentElement.setAttribute('data-theme', newTheme);
  localStorage.setItem('theme', newTheme);
  updateThemeIcons(newTheme);
}

function updateThemeIcons(theme) {
  const themeToggles = [
    document.getElementById('theme-toggle'),
    document.getElementById('mobile-theme-toggle')
  ];
  themeToggles.forEach(toggle => {
    if (!toggle) return;
    if (theme === 'light') {
      toggle.querySelector('.sun-icon')?.classList.add('hidden');
      toggle.querySelector('.moon-icon')?.classList.remove('hidden');
    } else {
      toggle.querySelector('.sun-icon')?.classList.remove('hidden');
      toggle.querySelector('.moon-icon')?.classList.add('hidden');
    }
  });
}

// 5. Auth Functions
async function checkSession() {
  showLoader();
  const { data: { session }, error } = await supabase.auth.getSession();
  
  if (session && session.user) {
    currentUser = session.user;
    await loadUserProfile();
    hideElement('auth-container');
    showElement('app-container');
    initApp();
  } else {
    currentUser = null;
    currentProfile = null;
    hideElement('app-container');
    showElement('auth-container');
    toggleAuthMode(false); // Default to login
    hideLoader();
  }
}

async function loadUserProfile() {
  if (!currentUser) return;
  try {
    const { data, error } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', currentUser.id)
      .single();
    
    if (data) {
      currentProfile = data;
      // Update sidebar details
      const initial = (data.full_name || currentUser.email || 'U').charAt(0).toUpperCase();
      document.getElementById('user-avatar-initial').innerText = initial;
      document.getElementById('mobile-user-avatar').innerText = initial;
      
      document.getElementById('user-display-name').innerText = data.full_name || 'Pengguna';
      document.getElementById('mobile-user-name').innerText = data.full_name || 'Pengguna';
      
      document.getElementById('user-display-email').innerText = currentUser.email;
      document.getElementById('mobile-user-email').innerText = currentUser.email;
    }
  } catch (err) {
    console.error('Gagal memuat profil pengguna:', err);
  }
}

function toggleAuthMode(signUpMode) {
  isSignUpMode = signUpMode;
  const nameGroup = document.getElementById('name-group');
  const authTitle = document.getElementById('auth-title');
  const authSubtitle = document.getElementById('auth-subtitle');
  const submitBtn = document.getElementById('auth-submit-btn').querySelector('span');
  const toggleText = document.getElementById('auth-toggle-text');
  
  if (isSignUpMode) {
    showElement('name-group');
    document.getElementById('auth-name').required = true;
    authTitle.innerText = 'Buat Akun Baru';
    authSubtitle.innerText = 'Mulai kelola keuangan Anda hari ini';
    submitBtn.innerText = 'Daftar';
    toggleText.innerHTML = 'Sudah punya akun? <a href="#" id="auth-toggle-btn">Masuk di sini</a>';
  } else {
    hideElement('name-group');
    document.getElementById('auth-name').required = false;
    authTitle.innerText = 'Masuk ke Akun Anda';
    authSubtitle.innerText = 'Kelola keuangan Anda secara realtime';
    submitBtn.innerText = 'Masuk';
    toggleText.innerHTML = 'Belum punya akun? <a href="#" id="auth-toggle-btn">Daftar sekarang</a>';
  }
  
  // Re-attach toggle listener
  document.getElementById('auth-toggle-btn').addEventListener('click', (e) => {
    e.preventDefault();
    toggleAuthMode(!isSignUpMode);
  });
}

// 6. Navigation Tabs
function initNavigation() {
  const navLinks = document.querySelectorAll('.nav-link, .mobile-nav-link');
  navLinks.forEach(link => {
    link.addEventListener('click', (e) => {
      e.preventDefault();
      const tabName = link.getAttribute('data-tab');
      if (tabName) {
        switchTab(tabName);
      }
    });
  });
  
  // Handle card shortcut clicks (Lihat Semua)
  document.querySelectorAll('[data-tab-go]').forEach(link => {
    link.addEventListener('click', (e) => {
      e.preventDefault();
      const tabName = link.getAttribute('data-tab-go');
      switchTab(tabName);
    });
  });
}

function switchTab(tabName) {
  currentTab = tabName;
  
  // Update sidebar and mobile nav active classes
  document.querySelectorAll('.nav-link, .mobile-nav-link').forEach(link => {
    if (link.getAttribute('data-tab') === tabName) {
      link.classList.add('active');
    } else {
      link.classList.remove('active');
    }
  });
  
  // Hide all panels
  document.querySelectorAll('.view-panel').forEach(panel => {
    panel.classList.add('hidden');
  });
  
  // Show active panel
  const activePanel = document.getElementById(`panel-${tabName}`);
  if (activePanel) {
    activePanel.classList.remove('hidden');
  }
  
  // Update Header Title
  const titleMap = {
    overview: 'Dashboard',
    transactions: 'Daftar Transaksi',
    accounts: 'Daftar Rekening',
    budgets: 'Anggaran Bulanan',
    reports: 'Laporan Keuangan'
  };
  const subtitleMap = {
    overview: 'Ringkasan kondisi keuangan Anda',
    transactions: 'Melacak seluruh riwayat pengeluaran dan pemasukan',
    accounts: 'Kelola semua rekening, bank, dan dompet digital',
    budgets: 'Atur batas pengeluaran bulanan per kategori',
    reports: 'Analisis visual tren pemasukan dan pengeluaran Anda'
  };
  
  document.getElementById('page-title').innerText = titleMap[tabName] || 'Financier';
  document.getElementById('page-subtitle').innerText = subtitleMap[tabName] || '';
  
  // Trigger tab-specific loaders
  if (tabName === 'reports') {
    renderCharts();
  }
}

// 7. Core Application Logic & Database operations
async function initApp() {
  showLoader();
  try {
    await Promise.all([
      fetchAccounts(),
      fetchCategories(),
      fetchTransactions(),
      fetchBudgets()
    ]);
    
    // Render initial views
    renderOverview();
    renderTransactionsList();
    renderAccountsList();
    renderBudgetsList();
    
    // Populate form dropdown selects
    populateSelectOptions();
    
  } catch (err) {
    console.error('Gagal mengambil data dari database:', err);
    alert('Terjadi kesalahan saat memuat data. Silakan refresh halaman.');
  } finally {
    hideLoader();
  }
}

// Database Fetchers
async function fetchAccounts() {
  const { data, error } = await supabase
    .from('accounts')
    .select('*')
    .eq('user_id', currentUser.id)
    .eq('is_active', true)
    .order('created_at');
    
  if (error) throw error;
  userAccounts = data || [];
}

async function fetchCategories() {
  const { data, error } = await supabase
    .from('categories')
    .select('*')
    .or(`user_id.eq.${currentUser.id},is_default.eq.true`)
    .eq('is_active', true)
    .order('sort_order');
    
  if (error) throw error;
  userCategories = data || [];
}

async function fetchTransactions() {
  const { data, error } = await supabase
    .from('transactions')
    .select('*')
    .eq('user_id', currentUser.id)
    .order('date', { ascending: false });
    
  if (error) throw error;
  userTransactions = data || [];
}

async function fetchBudgets() {
  const { data: budgetsData, error: budgetsErr } = await supabase
    .from('budgets')
    .select('*')
    .eq('user_id', currentUser.id)
    .eq('is_active', true);
    
  if (budgetsErr) throw budgetsErr;
  userBudgets = budgetsData || [];
  
  if (userBudgets.length > 0) {
    const budgetIds = userBudgets.map(b => b.id);
    const { data: itemsData, error: itemsErr } = await supabase
      .from('budget_items')
      .select('*')
      .in('budget_id', budgetIds);
      
    if (itemsErr) throw itemsErr;
    userBudgetItems = itemsData || [];
  } else {
    userBudgetItems = [];
  }
}

// 8. View Renderers

// 8a. Dashboard (Overview)
function renderOverview() {
  // 1. Calculate Total Balance
  const totalBalance = userAccounts.reduce((sum, acc) => sum + parseFloat(acc.balance), 0);
  document.getElementById('dash-total-balance').innerText = formatIDR(totalBalance);
  document.getElementById('dash-active-accounts-count').innerText = `${userAccounts.length} Rekening Aktif`;
  
  // 2. Calculate Monthly Income & Expenses (Current calendar month)
  const now = new Date();
  const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
  const endOfMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0);
  
  const monthlyTxs = userTransactions.filter(t => {
    const txDate = new Date(t.date);
    return txDate >= startOfMonth && txDate <= endOfMonth;
  });
  
  const monthlyIncome = monthlyTxs
    .filter(t => t.type === 'income' && t.status === 'completed')
    .reduce((sum, t) => sum + parseFloat(t.amount), 0);
    
  const monthlyExpense = monthlyTxs
    .filter(t => t.type === 'expense' && t.status === 'completed')
    .reduce((sum, t) => sum + parseFloat(t.amount), 0);
    
  document.getElementById('dash-monthly-income').innerText = formatIDR(monthlyIncome);
  document.getElementById('dash-monthly-expense').innerText = formatIDR(monthlyExpense);
  
  // 3. Render Accounts Summary
  const dashAccountsContainer = document.getElementById('dash-accounts-list');
  dashAccountsContainer.innerHTML = '';
  
  if (userAccounts.length === 0) {
    dashAccountsContainer.innerHTML = `
      <div class="empty-state">
        <i data-lucide="credit-card"></i>
        <p>Belum ada rekening dibuat</p>
      </div>`;
  } else {
    // Show top 3 accounts in Dashboard
    userAccounts.slice(0, 3).forEach(acc => {
      const icon = acc.type === 'bank' ? 'landmark' : 'wallet';
      const item = document.createElement('div');
      item.className = 'account-item-mini';
      item.innerHTML = `
        <div class="account-info-left">
          <div class="account-icon-badge" style="color: ${acc.color || 'var(--primary)'}; background-color: ${acc.color}15">
            <i data-lucide="${icon}"></i>
          </div>
          <div class="account-details-mini">
            <span class="account-name-mini">${acc.name}</span>
            <span class="account-type-mini">${acc.type}</span>
          </div>
        </div>
        <span class="account-balance-mini">${formatIDR(acc.balance)}</span>
      `;
      dashAccountsContainer.appendChild(item);
    });
  }
  
  // 4. Render Budgets Progress
  const dashBudgetsContainer = document.getElementById('dash-budgets-list');
  dashBudgetsContainer.innerHTML = '';
  
  if (userBudgets.length === 0) {
    dashBudgetsContainer.innerHTML = `
      <div class="empty-state">
        <i data-lucide="pie-chart"></i>
        <p>Belum ada anggaran aktif</p>
      </div>`;
  } else {
    // Show top 2 budgets in Dashboard
    userBudgets.slice(0, 2).forEach(b => {
      const budgetItems = userBudgetItems.filter(item => item.budget_id === b.id);
      const budgetCatIds = budgetItems.map(item => item.category_id);
      
      // Calculate Spent for this budget categories
      const budgetSpent = monthlyTxs
        .filter(t => t.type === 'expense' && t.status === 'completed' && budgetCatIds.includes(t.category_id))
        .reduce((sum, t) => sum + parseFloat(t.amount), 0);
        
      const percentage = Math.min(Math.round((budgetSpent / b.amount) * 100), 100);
      const color = b.color || 'var(--primary)';
      
      const item = document.createElement('div');
      item.className = 'budget-item-card';
      item.innerHTML = `
        <div class="budget-header-mini">
          <span>${b.name}</span>
          <span>${percentage}%</span>
        </div>
        <div class="budget-progress-bar-bg">
          <div class="budget-progress-bar-fill" style="width: ${percentage}%; background-color: ${color}"></div>
        </div>
        <div class="budget-meta-mini">
          <span>Sisa: ${formatIDR(Math.max(0, b.amount - budgetSpent))}</span>
          <span>Target: ${formatIDR(b.amount)}</span>
        </div>
      `;
      dashBudgetsContainer.appendChild(item);
    });
  }
  
  // 5. Render Recent Transactions Table
  const tableBody = document.getElementById('dash-transactions-body');
  const emptyPlaceholder = document.getElementById('dash-transactions-empty');
  tableBody.innerHTML = '';
  
  if (userTransactions.length === 0) {
    emptyPlaceholder.classList.remove('hidden');
    document.getElementById('dash-transactions-table').classList.add('hidden');
  } else {
    emptyPlaceholder.classList.add('hidden');
    document.getElementById('dash-transactions-table').classList.remove('hidden');
    
    const accountMap = new Map(userAccounts.map(a => [a.id, a]));
    const categoryMap = new Map(userCategories.map(c => [c.id, c]));
    
    // Show top 5 recent transactions
    userTransactions.slice(0, 5).forEach(t => {
      const accName = accountMap.get(t.account_id)?.name || 'Rekening';
      const cat = categoryMap.get(t.category_id);
      const catName = cat?.name || (t.type === 'transfer' ? 'Transfer Saldo' : 'Lainnya');
      
      let amountClass = 'color-expense';
      let icon = 'arrow-up-right';
      let prefix = '-';
      let rowBg = 'background-danger';
      
      if (t.type === 'income') {
        amountClass = 'color-income';
        icon = 'arrow-down-left';
        prefix = '+';
        rowBg = 'background-success';
      } else if (t.type === 'transfer') {
        amountClass = 'color-transfer';
        icon = 'repeat';
        prefix = '';
        rowBg = 'background-transfer';
      }
      
      const row = document.createElement('tr');
      row.innerHTML = `
        <td>
          <div class="table-tx-info">
            <div class="table-tx-icon ${rowBg} ${amountClass}">
              <i data-lucide="${icon}"></i>
            </div>
            <div class="table-tx-details">
              <span class="table-tx-note">${t.note || catName}</span>
              <span class="table-tx-type-badge">${t.type}</span>
            </div>
          </div>
        </td>
        <td>${catName}</td>
        <td>${accName}</td>
        <td>${formatDate(t.date)}</td>
        <td class="text-right table-amount ${amountClass}">${prefix}${formatIDR(t.amount)}</td>
        <td class="text-right">
          <button class="btn-delete-tx" onclick="deleteTransaction('${t.id}')" title="Hapus Transaksi">
            <i data-lucide="trash-2"></i>
          </button>
        </td>
      `;
      tableBody.appendChild(row);
    });
  }
  
  lucide.createIcons();
}

// 8b. Transactions List Panel
function renderTransactionsList() {
  const tableBody = document.getElementById('transactions-list-body');
  const emptyPlaceholder = document.getElementById('transactions-list-empty');
  tableBody.innerHTML = '';
  
  // Apply Filter Logic
  const searchQuery = document.getElementById('filter-search').value.toLowerCase();
  const filterType = document.getElementById('filter-type').value;
  const filterAcc = document.getElementById('filter-account').value;
  const filterCat = document.getElementById('filter-category').value;
  const startDate = document.getElementById('filter-start-date').value;
  const endDate = document.getElementById('filter-end-date').value;
  
  const filteredTxs = userTransactions.filter(t => {
    const matchesSearch = !searchQuery || (t.note && t.note.toLowerCase().includes(searchQuery));
    const matchesType = !filterType || t.type === filterType;
    const matchesAcc = !filterAcc || t.account_id === filterAcc || t.transfer_to_account_id === filterAcc;
    const matchesCat = !filterCat || t.category_id === filterCat;
    
    let matchesDate = true;
    if (startDate) {
      matchesDate = matchesDate && new Date(t.date) >= new Date(startDate);
    }
    if (endDate) {
      matchesDate = matchesDate && new Date(t.date) <= new Date(endDate);
    }
    
    return matchesSearch && matchesType && matchesAcc && matchesCat && matchesDate;
  });
  
  if (filteredTxs.length === 0) {
    emptyPlaceholder.classList.remove('hidden');
  } else {
    emptyPlaceholder.classList.add('hidden');
    
    const accountMap = new Map(userAccounts.map(a => [a.id, a]));
    const categoryMap = new Map(userCategories.map(c => [c.id, c]));
    
    filteredTxs.forEach(t => {
      const acc = accountMap.get(t.account_id);
      const accName = acc ? acc.name : 'Rekening';
      const cat = categoryMap.get(t.category_id);
      const catName = cat?.name || (t.type === 'transfer' ? 'Transfer Saldo' : 'Lainnya');
      
      let amountClass = 'color-expense';
      let icon = 'arrow-up-right';
      let prefix = '-';
      let rowBg = 'background-danger';
      
      if (t.type === 'income') {
        amountClass = 'color-income';
        icon = 'arrow-down-left';
        prefix = '+';
        rowBg = 'background-success';
      } else if (t.type === 'transfer') {
        amountClass = 'color-transfer';
        icon = 'repeat';
        prefix = '';
        rowBg = 'background-transfer';
      }
      
      const row = document.createElement('tr');
      row.innerHTML = `
        <td>
          <div class="table-tx-info">
            <div class="table-tx-icon ${rowBg} ${amountClass}">
              <i data-lucide="${icon}"></i>
            </div>
            <div class="table-tx-details">
              <span class="table-tx-note">${t.note || catName}</span>
              <span class="table-tx-type-badge">${t.type}</span>
            </div>
          </div>
        </td>
        <td>${catName}</td>
        <td>${accName} ${t.type === 'transfer' ? `→ ${accountMap.get(t.transfer_to_account_id)?.name || ''}` : ''}</td>
        <td>${formatDate(t.date)}</td>
        <td class="text-right table-amount ${amountClass}">${prefix}${formatIDR(t.amount)}</td>
        <td class="text-center">
          <button class="btn-delete-tx" onclick="deleteTransaction('${t.id}')" title="Hapus Transaksi">
            <i data-lucide="trash-2"></i>
          </button>
        </td>
      `;
      tableBody.appendChild(row);
    });
  }
  
  lucide.createIcons();
}

// 8c. Accounts Panel
function renderAccountsList() {
  const accountsGrid = document.getElementById('accounts-grid');
  const emptyState = document.getElementById('accounts-empty');
  accountsGrid.innerHTML = '';
  
  if (userAccounts.length === 0) {
    emptyState.classList.remove('hidden');
    accountsGrid.classList.add('hidden');
  } else {
    emptyState.classList.add('hidden');
    accountsGrid.classList.remove('hidden');
    
    userAccounts.forEach(acc => {
      const themeColor = acc.color || '#00668A';
      const icon = acc.type === 'bank' ? 'landmark' : 'wallet';
      
      const card = document.createElement('div');
      card.className = 'account-card-premium';
      card.style = `--account-theme: ${themeColor}; --account-theme-glow: ${themeColor}20`;
      card.innerHTML = `
        <div class="acc-card-header">
          <div class="acc-card-details">
            <h3 class="acc-card-name">${acc.name}</h3>
            <span class="acc-card-number">${acc.bank_name || ''} ${acc.account_number ? `(${acc.account_number})` : ''}</span>
          </div>
          <div class="acc-card-icon">
            <i data-lucide="${icon}"></i>
          </div>
        </div>
        <div class="acc-card-footer">
          <div>
            <span class="acc-card-balance-label">Saldo Saat Ini</span>
            <div class="acc-card-balance">${formatIDR(acc.balance)}</div>
          </div>
          <button class="btn-archive-account" onclick="deleteAccount('${acc.id}', '${acc.name}')" title="Arsipkan / Hapus Rekening">
            <i data-lucide="trash-2"></i>
          </button>
        </div>
      `;
      accountsGrid.appendChild(card);
    });
  }
  lucide.createIcons();
}

// 8d. Budgets Panel
function renderBudgetsList() {
  const budgetsGrid = document.getElementById('budgets-grid');
  const emptyState = document.getElementById('budgets-empty');
  budgetsGrid.innerHTML = '';
  
  if (userBudgets.length === 0) {
    emptyState.classList.remove('hidden');
    budgetsGrid.classList.add('hidden');
  } else {
    emptyState.classList.add('hidden');
    budgetsGrid.classList.remove('hidden');
    
    const now = new Date();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    const endOfMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0);
    
    const monthlyExpenses = userTransactions.filter(t => {
      const txDate = new Date(t.date);
      return t.type === 'expense' && t.status === 'completed' && txDate >= startOfMonth && txDate <= endOfMonth;
    });
    
    userBudgets.forEach(b => {
      const budgetItems = userBudgetItems.filter(item => item.budget_id === b.id);
      const budgetCatIds = budgetItems.map(item => item.category_id);
      
      const spent = monthlyExpenses
        .filter(t => budgetCatIds.includes(t.category_id))
        .reduce((sum, t) => sum + parseFloat(t.amount), 0);
        
      const percentage = Math.round((spent / b.amount) * 100);
      const color = b.color || '#10B981';
      
      let statusClass = 'status-safe';
      let statusText = 'Aman';
      
      if (percentage >= 100) {
        statusClass = 'status-over';
        statusText = 'Over Budget';
      } else if (percentage >= 80) {
        statusClass = 'status-warning';
        statusText = 'Mendekati Batas';
      }
      
      const card = document.createElement('div');
      card.className = 'budget-card-premium';
      card.innerHTML = `
        <div class="budget-card-header">
          <h3 class="budget-card-title">${b.name}</h3>
          <span class="budget-card-status-badge ${statusClass}">${statusText}</span>
        </div>
        
        <div class="budget-progress-bar-bg" style="height: 12px; border-radius: 6px;">
          <div class="budget-progress-bar-fill" style="width: ${Math.min(percentage, 100)}%; background-color: ${color}; border-radius: 6px;"></div>
        </div>
        
        <div class="budget-card-limit-row">
          <span>Terpakai: <strong class="color-expense">${formatIDR(spent)}</strong> (${percentage}%)</span>
          <span>Batas: <strong class="budget-card-limit-val">${formatIDR(b.amount)}</strong></span>
        </div>
        
        <div style="margin-top: auto; padding-top: 16px; display: flex; justify-content: space-between; align-items: center;">
          <span class="text-muted" style="font-size: 0.75rem;">Periode: Bulanan (${now.toLocaleString('id-ID', { month: 'long' })})</span>
          <button class="btn-delete-tx" onclick="deleteBudget('${b.id}')" title="Hapus Anggaran"><i data-lucide="trash-2"></i></button>
        </div>
      `;
      budgetsGrid.appendChild(card);
    });
  }
  lucide.createIcons();
}

// 8e. Reports & Charts (ChartJS)
function renderCharts() {
  if (userTransactions.length === 0) return;
  
  const ctxBar = document.getElementById('chart-income-expense').getContext('2d');
  const ctxPie = document.getElementById('chart-category-breakdown').getContext('2d');
  
  // Destroy old charts if exist
  if (incomeExpenseChart) incomeExpenseChart.destroy();
  if (categoryChart) categoryChart.destroy();
  
  // 1. Group income & expenses by month (last 6 months)
  const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
  const dataMonths = [];
  const incomeData = [];
  const expenseData = [];
  
  for (let i = 5; i >= 0; i--) {
    const d = new Date();
    d.setMonth(d.getMonth() - i);
    const month = d.getMonth();
    const year = d.getFullYear();
    
    dataMonths.push(`${monthNames[month]} ${year.toString().slice(-2)}`);
    
    const monthlyTxs = userTransactions.filter(t => {
      const txDate = new Date(t.date);
      return txDate.getMonth() === month && txDate.getFullYear() === year && t.status === 'completed';
    });
    
    const inc = monthlyTxs.filter(t => t.type === 'income').reduce((sum, t) => sum + parseFloat(t.amount), 0);
    const exp = monthlyTxs.filter(t => t.type === 'expense').reduce((sum, t) => sum + parseFloat(t.amount), 0);
    
    incomeData.push(inc);
    expenseData.push(exp);
  }
  
  // Render Bar Chart
  incomeExpenseChart = new Chart(ctxBar, {
    type: 'bar',
    data: {
      labels: dataMonths,
      datasets: [
        {
          label: 'Pemasukan',
          data: incomeData,
          backgroundColor: '#10B981',
          borderRadius: 6
        },
        {
          label: 'Pengeluaran',
          data: expenseData,
          backgroundColor: '#EF4444',
          borderRadius: 6
        }
      ]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      scales: {
        y: {
          beginAtZero: true,
          grid: { color: 'rgba(255, 255, 255, 0.05)' }
        },
        x: { grid: { display: false } }
      },
      plugins: {
        legend: { labels: { color: 'var(--text-primary)' } }
      }
    }
  });
  
  // 2. Calculate expenses by category for current month
  const now = new Date();
  const currentMonthTxs = userTransactions.filter(t => {
    const txDate = new Date(t.date);
    return t.type === 'expense' && t.status === 'completed' && txDate.getMonth() === now.getMonth() && txDate.getFullYear() === now.getFullYear();
  });
  
  const categoryMap = new Map(userCategories.map(c => [c.id, c]));
  const catSums = {};
  
  currentMonthTxs.forEach(t => {
    const cat = categoryMap.get(t.category_id);
    const catName = cat ? cat.name : 'Lainnya';
    catSums[catName] = (catSums[catName] || 0) + parseFloat(t.amount);
  });
  
  const pieLabels = Object.keys(catSums);
  const pieData = Object.values(catSums);
  const pieColors = ['#0EA5E9', '#10B981', '#F59E0B', '#EF4444', '#8B5CF6', '#EC4899', '#3B82F6', '#14B8A6', '#64748B'];
  
  // Render Pie Chart
  categoryChart = new Chart(ctxPie, {
    type: 'doughnut',
    data: {
      labels: pieLabels.length > 0 ? pieLabels : ['Tidak ada pengeluaran'],
      datasets: [{
        data: pieData.length > 0 ? pieData : [1],
        backgroundColor: pieColors.slice(0, pieLabels.length > 0 ? pieLabels.length : 1),
        borderWidth: 0
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          position: 'right',
          labels: { color: 'var(--text-primary)', boxWidth: 12 }
        }
      }
    }
  });
}

// 9. Populating select dropdown options dynamically
function populateSelectOptions() {
  const accountSelects = [
    document.getElementById('filter-account'),
    document.getElementById('tx-account'),
    document.getElementById('tx-transfer-to')
  ];
  
  const categorySelects = [
    document.getElementById('filter-category'),
    document.getElementById('tx-category')
  ];
  
  // Clear select items but keep first defaults
  accountSelects.forEach(select => {
    if (!select) return;
    const defaultOpt = select.options[0];
    select.innerHTML = '';
    select.appendChild(defaultOpt);
  });
  
  categorySelects.forEach(select => {
    if (!select) return;
    const defaultOpt = select.options[0];
    select.innerHTML = '';
    select.appendChild(defaultOpt);
  });
  
  // Add accounts
  userAccounts.forEach(acc => {
    accountSelects.forEach(select => {
      if (!select) return;
      const opt = document.createElement('option');
      opt.value = acc.id;
      opt.innerText = `${acc.name} (${formatIDR(acc.balance)})`;
      select.appendChild(opt);
    });
  });
  
  // Add categories
  userCategories.forEach(cat => {
    categorySelects.forEach(select => {
      if (!select) return;
      const opt = document.createElement('option');
      opt.value = cat.id;
      opt.innerText = `${cat.name} (${cat.type === 'income' ? 'Pemasukan' : 'Pengeluaran'})`;
      // Don't show default category selection in filters when they don't match or add logic
      select.appendChild(opt);
    });
  });
  
  // Update budget categories checkboxes in modal
  const budgetCatContainer = document.getElementById('budget-categories-selector');
  budgetCatContainer.innerHTML = '';
  userCategories
    .filter(cat => cat.type === 'expense')
    .forEach(cat => {
      const item = document.createElement('label');
      item.className = 'budget-cat-item';
      item.innerHTML = `
        <input type="checkbox" name="budget-cats" value="${cat.id}">
        <span>${cat.name}</span>
      `;
      budgetCatContainer.appendChild(item);
    });
}

// 10. Operations: Create / Delete

// 10a. Transactions
async function createTransaction(e) {
  e.preventDefault();
  
  const txId = document.getElementById('transaction-edit-id').value;
  const type = document.querySelector('input[name="tx-type"]:checked').value;
  const amount = parseFloat(document.getElementById('tx-amount').value);
  const accountId = document.getElementById('tx-account').value;
  const transferToAccountId = document.getElementById('tx-transfer-to').value;
  const categoryId = document.getElementById('tx-category').value;
  const date = document.getElementById('tx-date').value;
  const note = document.getElementById('tx-note').value;
  
  if (!accountId || (type === 'transfer' && !transferToAccountId) || (!categoryId && type !== 'transfer') || amount <= 0 || !date) {
    alert('Mohon lengkapi semua field bertanda bintang (*)');
    return;
  }
  
  showLoader();
  try {
    const data = {
      user_id: currentUser.id,
      account_id: accountId,
      category_id: type === 'transfer' ? null : categoryId,
      type: type,
      amount: amount,
      date: date,
      note: note,
      status: 'completed',
      transfer_to_account_id: type === 'transfer' ? transferToAccountId : null
    };
    
    // 1. Insert Transaction to Supabase
    let txResponse;
    if (txId) {
      txResponse = await supabase.from('transactions').update(data).eq('id', txId).select().single();
    } else {
      txResponse = await supabase.from('transactions').insert(data).select().single();
    }
    
    if (txResponse.error) throw txResponse.error;
    
    // 2. CLIENT-SIDE ACCOUNT BALANCE UPDATE (Safely updates account balances)
    const sourceAcc = userAccounts.find(a => a.id === accountId);
    if (sourceAcc) {
      let sourceNewBalance = parseFloat(sourceAcc.balance);
      if (type === 'income') {
        sourceNewBalance += amount;
      } else if (type === 'expense' || type === 'transfer') {
        sourceNewBalance -= amount;
      }
      await supabase.from('accounts').update({ balance: sourceNewBalance }).eq('id', accountId);
    }
    
    if (type === 'transfer' && transferToAccountId) {
      const destAcc = userAccounts.find(a => a.id === transferToAccountId);
      if (destAcc) {
        const destNewBalance = parseFloat(destAcc.balance) + amount;
        await supabase.from('accounts').update({ balance: destNewBalance }).eq('id', transferToAccountId);
      }
    }
    
    // Close modal and reload app
    hideElement('modal-transaction');
    document.getElementById('form-transaction').reset();
    await initApp();
    
  } catch (err) {
    console.error('Error saat menyimpan transaksi:', err);
    alert('Gagal menyimpan transaksi: ' + err.message);
  } finally {
    hideLoader();
  }
}

async function deleteTransaction(id) {
  if (!confirm('Apakah Anda yakin ingin menghapus transaksi ini? Saldo rekening Anda akan disesuaikan kembali.')) return;
  
  showLoader();
  try {
    // Get the transaction details before deleting so we can adjust balances
    const tx = userTransactions.find(t => t.id === id);
    if (!tx) return;
    
    // 1. Delete Transaction from Supabase
    const { error } = await supabase.from('transactions').delete().eq('id', id);
    if (error) throw error;
    
    // 2. Adjust account balances (REVERT balance changes)
    const sourceAcc = userAccounts.find(a => a.id === tx.account_id);
    if (sourceAcc) {
      let sourceNewBalance = parseFloat(sourceAcc.balance);
      if (tx.type === 'income') {
        sourceNewBalance -= parseFloat(tx.amount);
      } else if (tx.type === 'expense' || tx.type === 'transfer') {
        sourceNewBalance += parseFloat(tx.amount);
      }
      await supabase.from('accounts').update({ balance: sourceNewBalance }).eq('id', tx.account_id);
    }
    
    if (tx.type === 'transfer' && tx.transfer_to_account_id) {
      const destAcc = userAccounts.find(a => a.id === tx.transfer_to_account_id);
      if (destAcc) {
        const destNewBalance = parseFloat(destAcc.balance) - parseFloat(tx.amount);
        await supabase.from('accounts').update({ balance: destNewBalance }).eq('id', tx.transfer_to_account_id);
      }
    }
    
    await initApp();
  } catch (err) {
    console.error('Gagal menghapus transaksi:', err);
    alert('Error menghapus transaksi: ' + err.message);
  } finally {
    hideLoader();
  }
}

// 10b. Accounts
async function createAccount(e) {
  e.preventDefault();
  
  const name = document.getElementById('account-name').value;
  const type = document.getElementById('account-type').value;
  const balance = parseFloat(document.getElementById('account-balance').value);
  const bankName = document.getElementById('account-bank-name').value;
  const accountNumber = document.getElementById('account-number').value;
  const color = document.querySelector('input[name="account-color"]:checked').value;
  
  if (!name || !type || isNaN(balance)) {
    alert('Silakan lengkapi semua field utama');
    return;
  }
  
  showLoader();
  try {
    const data = {
      user_id: currentUser.id,
      name,
      type,
      balance,
      bank_name: bankName || null,
      account_number: accountNumber || null,
      color,
      is_active: true,
      is_archived: false
    };
    
    const { error } = await supabase.from('accounts').insert(data);
    if (error) throw error;
    
    hideElement('modal-account');
    document.getElementById('form-account').reset();
    await initApp();
    
  } catch (err) {
    console.error('Gagal membuat rekening:', err);
    alert('Gagal membuat rekening: ' + err.message);
  } finally {
    hideLoader();
  }
}

async function deleteAccount(id, name) {
  if (!confirm(`Apakah Anda yakin ingin menghapus rekening "${name}"? Seluruh transaksi yang terikat pada rekening ini juga akan ikut terhapus.`)) return;
  
  showLoader();
  try {
    const { error } = await supabase.from('accounts').delete().eq('id', id);
    if (error) throw error;
    await initApp();
  } catch (err) {
    console.error('Gagal menghapus rekening:', err);
    alert('Gagal menghapus rekening: ' + err.message);
  } finally {
    hideLoader();
  }
}

// 10c. Budgets
async function createBudget(e) {
  e.preventDefault();
  
  const name = document.getElementById('budget-name').value;
  const amount = parseFloat(document.getElementById('budget-amount').value);
  const color = document.querySelector('input[name="budget-color"]:checked').value;
  
  // Get selected category checkboxes
  const checkboxes = document.querySelectorAll('input[name="budget-cats"]:checked');
  const selectedCatIds = Array.from(checkboxes).map(cb => cb.value);
  
  if (!name || isNaN(amount) || selectedCatIds.length === 0) {
    alert('Mohon isi nama anggaran, nominal, dan pilih minimal 1 kategori');
    return;
  }
  
  showLoader();
  try {
    // 1. Insert Budget
    const { data: budgetData, error: budgetErr } = await supabase
      .from('budgets')
      .insert({
        user_id: currentUser.id,
        name,
        amount,
        period: 'monthly',
        color,
        is_active: true
      })
      .select()
      .single();
      
    if (budgetErr) throw budgetErr;
    
    // 2. Insert Budget Items
    const allocatedPerCat = amount / selectedCatIds.length;
    const itemsToInsert = selectedCatIds.map(catId => ({
      budget_id: budgetData.id,
      category_id: catId,
      allocated: allocatedPerCat,
      spent: 0
    }));
    
    const { error: itemsErr } = await supabase.from('budget_items').insert(itemsToInsert);
    if (itemsErr) throw itemsErr;
    
    hideElement('modal-budget');
    document.getElementById('form-budget').reset();
    await initApp();
    
  } catch (err) {
    console.error('Gagal membuat anggaran:', err);
    alert('Gagal membuat anggaran: ' + err.message);
  } finally {
    hideLoader();
  }
}

async function deleteBudget(id) {
  if (!confirm('Apakah Anda yakin ingin menghapus anggaran ini?')) return;
  
  showLoader();
  try {
    const { error } = await supabase.from('budgets').delete().eq('id', id);
    if (error) throw error;
    await initApp();
  } catch (err) {
    console.error('Gagal menghapus anggaran:', err);
    alert('Gagal menghapus anggaran: ' + err.message);
  } finally {
    hideLoader();
  }
}

// 11. Modal UI Event Listeners
function initModalListeners() {
  // Modal Account
  document.getElementById('qa-add-account').addEventListener('click', (e) => {
    e.preventDefault();
    hideElement('quick-action-menu');
    document.getElementById('modal-account-title').innerText = 'Buat Rekening Baru';
    document.getElementById('form-account').reset();
    showElement('modal-account');
  });
  
  document.getElementById('btn-add-account-empty').addEventListener('click', () => {
    showElement('modal-account');
  });
  
  document.getElementById('btn-close-account-modal').addEventListener('click', () => hideElement('modal-account'));
  document.getElementById('btn-cancel-account').addEventListener('click', () => hideElement('modal-account'));
  document.getElementById('form-account').addEventListener('submit', createAccount);

  // Modal Transaction
  const showTxModal = (type = 'expense') => {
    hideElement('quick-action-menu');
    document.getElementById('modal-transaction-title').innerText = 'Catat Transaksi Baru';
    document.getElementById('form-transaction').reset();
    document.getElementById('transaction-edit-id').value = '';
    
    // Set active type segment button
    document.querySelectorAll('.type-btn').forEach(btn => {
      if (btn.getAttribute('data-type') === type) {
        btn.classList.add('active');
        btn.querySelector('input').checked = true;
      } else {
        btn.classList.remove('active');
      }
    });
    
    // Trigger form inputs visibility based on type
    toggleTxTypeFields(type);
    
    // Set default date to today
    document.getElementById('tx-date').value = new Date().toISOString().split('T')[0];
    
    showElement('modal-transaction');
  };

  document.getElementById('qa-add-income').addEventListener('click', (e) => { e.preventDefault(); showTxModal('income'); });
  document.getElementById('qa-add-expense').addEventListener('click', (e) => { e.preventDefault(); showTxModal('expense'); });
  document.getElementById('qa-add-transfer').addEventListener('click', (e) => { e.preventDefault(); showTxModal('transfer'); });
  
  document.getElementById('btn-close-transaction-modal').addEventListener('click', () => hideElement('modal-transaction'));
  document.getElementById('btn-cancel-transaction').addEventListener('click', () => hideElement('modal-transaction'));
  document.getElementById('form-transaction').addEventListener('submit', createTransaction);

  // Transaction type toggle inside modal
  document.querySelectorAll('.type-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.type-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      const radio = btn.querySelector('input');
      radio.checked = true;
      toggleTxTypeFields(radio.value);
    });
  });

  // Modal Budget
  document.getElementById('qa-add-budget').addEventListener('click', (e) => {
    e.preventDefault();
    hideElement('quick-action-menu');
    showElement('modal-budget');
  });
  
  document.getElementById('btn-add-budget-empty').addEventListener('click', () => {
    showElement('modal-budget');
  });
  
  document.getElementById('btn-close-budget-modal').addEventListener('click', () => hideElement('modal-budget'));
  document.getElementById('btn-cancel-budget').addEventListener('click', () => hideElement('modal-budget'));
  document.getElementById('form-budget').addEventListener('submit', createBudget);

  // Mobile menu/profil drawer
  document.getElementById('mobile-menu-btn').addEventListener('click', (e) => {
    e.preventDefault();
    showElement('modal-mobile-menu');
  });
  document.getElementById('btn-close-mobile-menu').addEventListener('click', () => hideElement('modal-mobile-menu'));

  // Quick Action menu toggle
  document.getElementById('btn-quick-action').addEventListener('click', (e) => {
    e.stopPropagation();
    document.getElementById('quick-action-menu').classList.toggle('hidden');
  });
  
  // Close dropdowns/modals on background clicks
  window.addEventListener('click', () => {
    const menu = document.getElementById('quick-action-menu');
    if (menu) menu.classList.add('hidden');
  });
}

function toggleTxTypeFields(type) {
  const destGroup = document.getElementById('tx-dest-account-group');
  const catGroup = document.getElementById('tx-category-group');
  const sourceLabel = document.getElementById('tx-source-account-group').querySelector('label');
  
  if (type === 'transfer') {
    destGroup.classList.remove('hidden');
    catGroup.classList.add('hidden');
    document.getElementById('tx-transfer-to').required = true;
    document.getElementById('tx-category').required = false;
    sourceLabel.innerText = 'Rekening Asal *';
  } else {
    destGroup.classList.add('hidden');
    catGroup.classList.remove('hidden');
    document.getElementById('tx-transfer-to').required = false;
    document.getElementById('tx-category').required = true;
    sourceLabel.innerText = 'Rekening *';
    
    // Filter categories shown based on transaction type (income/expense)
    const catSelect = document.getElementById('tx-category');
    Array.from(catSelect.options).forEach(opt => {
      if (opt.value === "") return;
      const cat = userCategories.find(c => c.id === opt.value);
      if (cat && cat.type !== type) {
        opt.style.display = 'none';
      } else {
        opt.style.display = 'block';
      }
    });
    catSelect.value = ""; // Reset value
  }
}

// 12. Register filters change listeners
function initFiltersListeners() {
  const searchInput = document.getElementById('filter-search');
  const typeSelect = document.getElementById('filter-type');
  const accSelect = document.getElementById('filter-account');
  const catSelect = document.getElementById('filter-category');
  const startDate = document.getElementById('filter-start-date');
  const endDate = document.getElementById('filter-end-date');
  
  const triggerFilter = () => renderTransactionsList();
  
  searchInput.addEventListener('input', triggerFilter);
  typeSelect.addEventListener('change', triggerFilter);
  accSelect.addEventListener('change', triggerFilter);
  catSelect.addEventListener('change', triggerFilter);
  startDate.addEventListener('change', triggerFilter);
  endDate.addEventListener('change', triggerFilter);
  
  document.getElementById('btn-reset-filters').addEventListener('click', () => {
    searchInput.value = '';
    typeSelect.value = '';
    accSelect.value = '';
    catSelect.value = '';
    startDate.value = '';
    endDate.value = '';
    triggerFilter();
  });
}

// 13. Registration/Login Handler
async function handleAuthSubmit(e) {
  e.preventDefault();
  
  const name = document.getElementById('auth-name').value;
  const email = document.getElementById('auth-email').value;
  const password = document.getElementById('auth-password').value;
  
  const submitBtn = document.getElementById('auth-submit-btn');
  const spinner = submitBtn.querySelector('.btn-spinner');
  const btnText = submitBtn.querySelector('span');
  
  spinner.classList.remove('hidden');
  btnText.classList.add('hidden');
  submitBtn.disabled = true;
  
  try {
    if (isSignUpMode) {
      // 1. Sign Up User
      const { data, error } = await supabase.auth.signUp({
        email,
        password,
        options: {
          data: {
            full_name: name
          }
        }
      });
      
      if (error) throw error;
      
      alert('Registrasi Berhasil! Silakan cek email Anda untuk memverifikasi akun Anda, kemudian masuk.');
      toggleAuthMode(false); // Switch to login
      
    } else {
      // 2. Log In User
      const { data, error } = await supabase.auth.signInWithPassword({ email, password });
      if (error) throw error;
      
      // Load app
      await checkSession();
    }
  } catch (err) {
    console.error('Proses Auth Gagal:', err);
    alert('Gagal melakukan otentikasi: ' + err.message);
  } finally {
    spinner.classList.add('hidden');
    btnText.classList.remove('hidden');
    submitBtn.disabled = false;
  }
}

// 14. Logout Handler
async function handleLogout() {
  if (!confirm('Apakah Anda yakin ingin keluar dari aplikasi?')) return;
  showLoader();
  try {
    await supabase.auth.signOut();
    currentUser = null;
    currentProfile = null;
    
    // Reset view variables
    userAccounts = [];
    userCategories = [];
    userTransactions = [];
    userBudgets = [];
    userBudgetItems = [];
    
    hideElement('app-container');
    showElement('auth-container');
    toggleAuthMode(false);
  } catch (err) {
    console.error('Logout Gagal:', err);
  } finally {
    hideLoader();
  }
}

// 15. DOM Content Loaded Bootstrapping
document.addEventListener('DOMContentLoaded', () => {
  initTheme();
  
  // Theme Toggle Button Listeners
  document.getElementById('theme-toggle').addEventListener('click', toggleTheme);
  document.getElementById('mobile-theme-toggle').addEventListener('click', toggleTheme);
  
  // Form submission
  document.getElementById('auth-form').addEventListener('submit', handleAuthSubmit);
  
  // Logout
  document.getElementById('logout-btn').addEventListener('click', handleLogout);
  document.getElementById('mobile-logout-btn').addEventListener('click', handleLogout);
  
  // Navigation & Modals Init
  initNavigation();
  initModalListeners();
  initFiltersListeners();
  
  // Check active user session on startup
  checkSession();
});
