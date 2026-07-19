-- Financier - Personal Finance App Schema
-- Migration 00002: Bills, Saving Goals, Debts & Wishlist

-- ============================================================
-- TABLES
-- ============================================================

-- Bills / Tagihan
CREATE TABLE IF NOT EXISTS bills (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    amount DECIMAL(15,2) NOT NULL CHECK (amount > 0),
    due_date DATE NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'paid')),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Saving Goals / Target Tabungan
CREATE TABLE IF NOT EXISTS saving_goals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    target_amount DECIMAL(15,2) NOT NULL CHECK (target_amount > 0),
    current_amount DECIMAL(15,2) NOT NULL DEFAULT 0 CHECK (current_amount >= 0),
    target_date DATE,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Debts / Hutang & Piutang
CREATE TABLE IF NOT EXISTS debts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    contact_name TEXT NOT NULL,
    amount DECIMAL(15,2) NOT NULL CHECK (amount > 0),
    type TEXT NOT NULL CHECK (type IN ('debt', 'loan')),
    due_date DATE,
    status TEXT NOT NULL DEFAULT 'unpaid' CHECK (status IN ('unpaid', 'paid')),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Wishlist / Simulasi Keinginan
CREATE TABLE IF NOT EXISTS wishlist (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    price DECIMAL(15,2) NOT NULL CHECK (price > 0),
    url TEXT,
    is_enabled BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_bills_user_id ON bills(user_id);
CREATE INDEX IF NOT EXISTS idx_bills_due_date ON bills(due_date);
CREATE INDEX IF NOT EXISTS idx_saving_goals_user_id ON saving_goals(user_id);
CREATE INDEX IF NOT EXISTS idx_debts_user_id ON debts(user_id);
CREATE INDEX IF NOT EXISTS idx_debts_type ON debts(type);
CREATE INDEX IF NOT EXISTS idx_debts_due_date ON debts(due_date);
CREATE INDEX IF NOT EXISTS idx_wishlist_user_id ON wishlist(user_id);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
ALTER TABLE bills ENABLE ROW LEVEL SECURITY;
ALTER TABLE saving_goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE debts ENABLE ROW LEVEL SECURITY;
ALTER TABLE wishlist ENABLE ROW LEVEL SECURITY;

-- Bills
CREATE POLICY "users can view own bills" ON bills FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "users can create own bills" ON bills FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "users can update own bills" ON bills FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "users can delete own bills" ON bills FOR DELETE USING (auth.uid() = user_id);

-- Saving Goals
CREATE POLICY "users can view own goals" ON saving_goals FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "users can create own goals" ON saving_goals FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "users can update own goals" ON saving_goals FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "users can delete own goals" ON saving_goals FOR DELETE USING (auth.uid() = user_id);

-- Debts
CREATE POLICY "users can view own debts" ON debts FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "users can create own debts" ON debts FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "users can update own debts" ON debts FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "users can delete own debts" ON debts FOR DELETE USING (auth.uid() = user_id);

-- Wishlist
CREATE POLICY "users can view own wishlist" ON wishlist FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "users can create own wishlist" ON wishlist FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "users can update own wishlist" ON wishlist FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "users can delete own wishlist" ON wishlist FOR DELETE USING (auth.uid() = user_id);
