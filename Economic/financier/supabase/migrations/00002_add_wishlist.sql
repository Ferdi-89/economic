-- Migration 00002: Add Wishlist Schema
-- Buka Supabase SQL Editor → copy paste script ini untuk membuat tabel wishlist di remote database

CREATE TABLE IF NOT EXISTS wishlist_items (
    id TEXT PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    price DECIMAL(15,2) NOT NULL CHECK (price > 0),
    is_enabled BOOLEAN DEFAULT true,
    url TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Row Level Security
ALTER TABLE wishlist_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users can view own wishlist" ON wishlist_items FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "users can create own wishlist" ON wishlist_items FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "users can update own wishlist" ON wishlist_items FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "users can delete own wishlist" ON wishlist_items FOR DELETE USING (auth.uid() = user_id);
