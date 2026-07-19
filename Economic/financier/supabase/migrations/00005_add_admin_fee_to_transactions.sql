-- Migration 00005: Add admin_fee to transactions table
ALTER TABLE transactions ADD COLUMN admin_fee DECIMAL(15,2) DEFAULT 0.00 NOT NULL;
