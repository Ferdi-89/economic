-- Migration 00006: Add NFC Card ID to Profiles for Hardware Identity Binding
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS nfc_card_id TEXT UNIQUE;
CREATE INDEX IF NOT EXISTS idx_profiles_nfc_card_id ON profiles(nfc_card_id);
