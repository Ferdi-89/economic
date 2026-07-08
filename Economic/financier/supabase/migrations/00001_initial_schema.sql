-- Financier - Personal Finance App Schema
-- Migration 00001: Initial Schema

-- ============================================================
-- TABLES
-- ============================================================

-- Profiles (extends auth.users)
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    full_name TEXT,
    avatar_url TEXT,
    default_currency TEXT DEFAULT 'IDR',
    locale TEXT DEFAULT 'id_ID',
    theme TEXT DEFAULT 'system',
    email_notifications BOOLEAN DEFAULT false,
    push_notifications BOOLEAN DEFAULT false,
    monthly_budget_alert INTEGER DEFAULT 80,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Accounts (rekening/simpanan)
CREATE TABLE IF NOT EXISTS accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('cash', 'bank', 'ewallet', 'savings', 'investment')),
    balance DECIMAL(15,2) DEFAULT 0 NOT NULL,
    bank_name TEXT,
    account_number TEXT,
    icon TEXT,
    color TEXT,
    is_archived BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Categories (kategori transaksi)
CREATE TABLE IF NOT EXISTS categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
    icon TEXT,
    color TEXT,
    parent_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    sort_order INTEGER DEFAULT 0,
    is_default BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Transactions (transaksi keuangan)
CREATE TABLE IF NOT EXISTS transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    account_id UUID REFERENCES accounts(id) ON DELETE CASCADE NOT NULL,
    category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    type TEXT NOT NULL CHECK (type IN ('income', 'expense', 'transfer')),
    amount DECIMAL(15,2) NOT NULL CHECK (amount > 0),
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    note TEXT,
    description TEXT,
    tags TEXT,
    receipt_url TEXT,
    transfer_to_account_id UUID REFERENCES accounts(id) ON DELETE SET NULL,
    is_recurring BOOLEAN DEFAULT false,
    recurring_id TEXT,
    status TEXT DEFAULT 'completed' CHECK (status IN ('completed', 'pending', 'cancelled')),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT transfer_check CHECK (
        (type = 'transfer' AND transfer_to_account_id IS NOT NULL AND transfer_to_account_id != account_id)
        OR (type != 'transfer')
    )
);

-- Budgets (anggaran)
CREATE TABLE IF NOT EXISTS budgets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    amount DECIMAL(15,2) NOT NULL CHECK (amount > 0),
    period TEXT NOT NULL DEFAULT 'monthly' CHECK (period IN ('monthly', 'weekly', 'yearly', 'custom')),
    start_date DATE,
    end_date DATE,
    color TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Budget Items (kategori dalam budget)
CREATE TABLE IF NOT EXISTS budget_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    budget_id UUID REFERENCES budgets(id) ON DELETE CASCADE NOT NULL,
    category_id UUID REFERENCES categories(id) ON DELETE CASCADE NOT NULL,
    allocated DECIMAL(15,2) NOT NULL CHECK (allocated > 0),
    spent DECIMAL(15,2) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    UNIQUE(budget_id, category_id)
);

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_account_id ON transactions(account_id);
CREATE INDEX IF NOT EXISTS idx_transactions_category_id ON transactions(category_id);
CREATE INDEX IF NOT EXISTS idx_transactions_type ON transactions(type);
CREATE INDEX IF NOT EXISTS idx_transactions_user_date ON transactions(user_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_accounts_user_id ON accounts(user_id);
CREATE INDEX IF NOT EXISTS idx_categories_user_id ON categories(user_id);
CREATE INDEX IF NOT EXISTS idx_categories_type ON categories(type);
CREATE INDEX IF NOT EXISTS idx_budgets_user_id ON budgets(user_id);

-- ============================================================
-- TRIGGERS
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER update_accounts_updated_at
    BEFORE UPDATE ON accounts FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER update_transactions_updated_at
    BEFORE UPDATE ON transactions FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER update_budgets_updated_at
    BEFORE UPDATE ON budgets FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER update_budget_items_updated_at
    BEFORE UPDATE ON budget_items FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- RPC FUNCTIONS
-- ============================================================

CREATE OR REPLACE FUNCTION get_total_income(p_user_id UUID, p_start TIMESTAMPTZ, p_end TIMESTAMPTZ)
RETURNS DECIMAL(15,2) LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    total DECIMAL(15,2);
BEGIN
    SELECT COALESCE(SUM(amount), 0) INTO total
    FROM transactions
    WHERE user_id = p_user_id
      AND type = 'income'
      AND date >= p_start::DATE
      AND date <= p_end::DATE
      AND status = 'completed';
    RETURN total;
END;
$$;

CREATE OR REPLACE FUNCTION get_total_expense(p_user_id UUID, p_start TIMESTAMPTZ, p_end TIMESTAMPTZ)
RETURNS DECIMAL(15,2) LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    total DECIMAL(15,2);
BEGIN
    SELECT COALESCE(SUM(amount), 0) INTO total
    FROM transactions
    WHERE user_id = p_user_id
      AND type = 'expense'
      AND date >= p_start::DATE
      AND date <= p_end::DATE
      AND status = 'completed';
    RETURN total;
END;
$$;

CREATE OR REPLACE FUNCTION get_budgets_with_spent(p_user_id UUID)
RETURNS TABLE (
    id UUID, user_id UUID, name TEXT, amount DECIMAL,
    period TEXT, start_date DATE, end_date DATE,
    color TEXT, is_active BOOLEAN, spent DECIMAL,
    created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ
) LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    RETURN QUERY
    SELECT
        b.id, b.user_id, b.name, b.amount, b.period,
        b.start_date, b.end_date, b.color, b.is_active,
        COALESCE(SUM(t.amount), 0) AS spent,
        b.created_at, b.updated_at
    FROM budgets b
    LEFT JOIN budget_items bi ON bi.budget_id = b.id
    LEFT JOIN transactions t ON t.category_id = bi.category_id
        AND t.user_id = b.user_id
        AND t.type = 'expense'
        AND t.status = 'completed'
        AND (
            (b.period = 'monthly' AND t.date >= date_trunc('month', CURRENT_DATE) AND t.date < date_trunc('month', CURRENT_DATE) + INTERVAL '1 month')
            OR (b.period = 'weekly' AND t.date >= date_trunc('week', CURRENT_DATE) AND t.date < date_trunc('week', CURRENT_DATE) + INTERVAL '1 week')
            OR (b.period = 'yearly' AND t.date >= date_trunc('year', CURRENT_DATE) AND t.date < date_trunc('year', CURRENT_DATE) + INTERVAL '1 year')
            OR (b.period = 'custom' AND t.date >= b.start_date AND t.date <= b.end_date)
        )
    WHERE b.user_id = p_user_id AND b.is_active = true
    GROUP BY b.id
    ORDER BY b.created_at;
END;
$$;

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE budgets ENABLE ROW LEVEL SECURITY;
ALTER TABLE budget_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users can view own profile" ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "users can insert own profile" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "users can view own accounts" ON accounts FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "users can create own accounts" ON accounts FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "users can update own accounts" ON accounts FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "users can delete own accounts" ON accounts FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "users can view categories" ON categories FOR SELECT USING (auth.uid() = user_id OR is_default = true);
CREATE POLICY "users can create categories" ON categories FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "users can update own categories" ON categories FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "users can delete own categories" ON categories FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "users can view own transactions" ON transactions FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "users can create own transactions" ON transactions FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "users can update own transactions" ON transactions FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "users can delete own transactions" ON transactions FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "users can view own budgets" ON budgets FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "users can create own budgets" ON budgets FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "users can update own budgets" ON budgets FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "users can delete own budgets" ON budgets FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "users can view own budget items" ON budget_items FOR SELECT USING (
    budget_id IN (SELECT id FROM budgets WHERE user_id = auth.uid())
);
CREATE POLICY "users can create own budget items" ON budget_items FOR INSERT WITH CHECK (
    budget_id IN (SELECT id FROM budgets WHERE user_id = auth.uid())
);
CREATE POLICY "users can update own budget items" ON budget_items FOR UPDATE USING (
    budget_id IN (SELECT id FROM budgets WHERE user_id = auth.uid())
);
CREATE POLICY "users can delete own budget items" ON budget_items FOR DELETE USING (
    budget_id IN (SELECT id FROM budgets WHERE user_id = auth.uid())
);

-- ============================================================
-- SEED DATA
-- ============================================================
INSERT INTO categories (name, type, icon, sort_order, is_default) VALUES
    ('Makanan & Minuman', 'expense', 'restaurant', 1, true),
    ('Transportasi', 'expense', 'directions_car', 2, true),
    ('Belanja', 'expense', 'shopping_cart', 3, true),
    ('Tagihan & Utilitas', 'expense', 'receipt', 4, true),
    ('Hiburan', 'expense', 'movie', 5, true),
    ('Kesehatan', 'expense', 'local_hospital', 6, true),
    ('Pendidikan', 'expense', 'school', 7, true),
    ('Tempat Tinggal', 'expense', 'home', 8, true),
    ('Investasi', 'expense', 'trending_up', 9, true),
    ('Lainnya', 'expense', 'more_horiz', 10, true),
    ('Gaji', 'income', 'work', 1, true),
    ('Freelance', 'income', 'code', 2, true),
    ('Bisnis', 'income', 'store', 3, true),
    ('Investasi', 'income', 'trending_up', 4, true),
    ('Hadiah', 'income', 'card_giftcard', 5, true),
    ('Lainnya', 'income', 'more_horiz', 6, true);

-- ============================================================
-- AUTO-CREATE PROFILE ON SIGNUP
-- ============================================================
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER SECURITY DEFINER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name, avatar_url)
    VALUES (
        NEW.id,
        NEW.email,
        NEW.raw_user_meta_data->>'full_name',
        NEW.raw_user_meta_data->>'avatar_url'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();
