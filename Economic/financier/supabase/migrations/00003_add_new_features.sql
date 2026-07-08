-- Migration 00003: Add Bills, Saving Goals, and Debts tables

-- 1. Bills (Tagihan)
CREATE TABLE IF NOT EXISTS bills (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    amount DECIMAL(15,2) NOT NULL CHECK (amount > 0),
    due_date DATE NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'paid')),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE bills ENABLE ROW LEVEL SECURITY;
CREATE POLICY "users can view own bills" ON bills FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "users can create own bills" ON bills FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "users can update own bills" ON bills FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "users can delete own bills" ON bills FOR DELETE USING (auth.uid() = user_id);

-- 2. Saving Goals (Target Tabungan)
CREATE TABLE IF NOT EXISTS saving_goals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    target_amount DECIMAL(15,2) NOT NULL CHECK (target_amount > 0),
    current_amount DECIMAL(15,2) DEFAULT 0 NOT NULL,
    target_date DATE,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE saving_goals ENABLE ROW LEVEL SECURITY;
CREATE POLICY "users can view own saving_goals" ON saving_goals FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "users can create own saving_goals" ON saving_goals FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "users can update own saving_goals" ON saving_goals FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "users can delete own saving_goals" ON saving_goals FOR DELETE USING (auth.uid() = user_id);

-- 3. Debts (Hutang & Piutang)
CREATE TABLE IF NOT EXISTS debts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    contact_name TEXT NOT NULL,
    amount DECIMAL(15,2) NOT NULL CHECK (amount > 0),
    type TEXT NOT NULL CHECK (type IN ('debt', 'loan')),
    due_date DATE,
    status TEXT DEFAULT 'unpaid' CHECK (status IN ('unpaid', 'paid')),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE debts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "users can view own debts" ON debts FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "users can create own debts" ON debts FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "users can update own debts" ON debts FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "users can delete own debts" ON debts FOR DELETE USING (auth.uid() = user_id);
