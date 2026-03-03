-- ============================================================
-- Go Telegram Bot - Supabase Schema
-- ============================================================
-- Run this in your Supabase SQL editor to set up the database.
-- Supabase Dashboard → SQL Editor → New Query → Paste & Run
--
-- IMPORTANT: This script is SAFE for existing databases.
-- All statements use IF NOT EXISTS — they will NOT drop or
-- overwrite existing tables or data. If you have an existing
-- Supabase project, only missing tables will be created.
--
-- DO NOT manually drop tables to "fix" schema conflicts.
-- If you have existing data you want to keep, create a
-- separate Supabase project for the bot instead.
-- ============================================================

-- Enable pgvector extension (required for embedding column and semantic search)
CREATE EXTENSION IF NOT EXISTS vector;

-- Messages table (conversation history)
CREATE TABLE IF NOT EXISTS messages (
  id BIGSERIAL PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  chat_id TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
  content TEXT NOT NULL,
  metadata JSONB DEFAULT '{}'::jsonb,
  embedding VECTOR(1536)  -- Optional: for semantic search via OpenAI embeddings
);

-- Memory table (facts, goals, preferences)
CREATE TABLE IF NOT EXISTS memory (
  id BIGSERIAL PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  type TEXT NOT NULL CHECK (type IN ('fact', 'goal', 'completed_goal', 'preference')),
  content TEXT NOT NULL,
  deadline TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  priority INTEGER DEFAULT 0,
  metadata JSONB DEFAULT '{}'::jsonb
);

-- Logs table (observability)
CREATE TABLE IF NOT EXISTS logs (
  id BIGSERIAL PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  level TEXT NOT NULL CHECK (level IN ('debug', 'info', 'warn', 'error')),
  event TEXT NOT NULL,
  message TEXT,
  metadata JSONB DEFAULT '{}'::jsonb,
  session_id TEXT,
  duration_ms INTEGER
);

-- Call transcripts table (optional: for voice call history)
CREATE TABLE IF NOT EXISTS call_transcripts (
  id BIGSERIAL PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  conversation_id TEXT UNIQUE NOT NULL,
  transcript TEXT,
  summary TEXT,
  action_items TEXT[] DEFAULT '{}',
  duration_seconds INTEGER,
  metadata JSONB DEFAULT '{}'::jsonb
);

-- Async tasks table (human-in-the-loop: VPS mode)
-- Used when Claude pauses to ask the user a question via inline buttons.
CREATE TABLE IF NOT EXISTS async_tasks (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  chat_id TEXT NOT NULL,
  original_prompt TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'running', 'needs_input', 'completed', 'failed')),
  result TEXT,
  session_id TEXT,
  current_step TEXT,
  pending_question TEXT,
  pending_options JSONB,        -- [{label, value}]
  user_response TEXT,
  thread_id INTEGER,
  processed_by TEXT,            -- 'vps', 'local', etc.
  reminder_sent BOOLEAN DEFAULT FALSE,
  metadata JSONB DEFAULT '{}'::jsonb  -- messages_snapshot, assistant_content, tool_use_id
);

-- Node heartbeat table (hybrid mode: VPS ↔ local machine health tracking)
CREATE TABLE IF NOT EXISTS node_heartbeat (
  node_id TEXT PRIMARY KEY,
  last_heartbeat TIMESTAMPTZ DEFAULT NOW(),
  metadata JSONB DEFAULT '{}'::jsonb
);

-- Assets table (persistent image/file storage with AI descriptions)
CREATE TABLE IF NOT EXISTS assets (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  storage_path TEXT NOT NULL,
  public_url TEXT,
  original_filename TEXT,
  file_type TEXT NOT NULL,  -- 'image', 'document', 'audio'
  mime_type TEXT,
  file_size_bytes INTEGER,
  description TEXT NOT NULL,
  user_caption TEXT,
  conversation_context TEXT,
  related_project TEXT,
  tags TEXT[] DEFAULT '{}',
  channel TEXT DEFAULT 'telegram',
  metadata JSONB DEFAULT '{}',
  embedding VECTOR(1536)
);

-- ============================================================
-- INDEXES
-- ============================================================

-- Messages: fast lookup by chat, time, and role
CREATE INDEX IF NOT EXISTS idx_messages_chat_id ON messages (chat_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_role ON messages (role);

-- Memory: fast lookup by type
CREATE INDEX IF NOT EXISTS idx_memory_type ON memory (type);
CREATE INDEX IF NOT EXISTS idx_memory_created_at ON memory (created_at DESC);

-- Logs: fast lookup by event and level
CREATE INDEX IF NOT EXISTS idx_logs_event ON logs (event);
CREATE INDEX IF NOT EXISTS idx_logs_level ON logs (level);
CREATE INDEX IF NOT EXISTS idx_logs_created_at ON logs (created_at DESC);

-- Async tasks: fast lookup by chat and status
CREATE INDEX IF NOT EXISTS idx_async_tasks_chat_id ON async_tasks (chat_id);
CREATE INDEX IF NOT EXISTS idx_async_tasks_status ON async_tasks (status);
CREATE INDEX IF NOT EXISTS idx_async_tasks_updated_at ON async_tasks (updated_at DESC);

-- Assets: fast lookup by type and time
CREATE INDEX IF NOT EXISTS idx_assets_file_type ON assets (file_type);
CREATE INDEX IF NOT EXISTS idx_assets_created_at ON assets (created_at DESC);

-- ============================================================
-- ROW LEVEL SECURITY (Optional but recommended)
-- ============================================================

-- Enable RLS on all tables
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE memory ENABLE ROW LEVEL SECURITY;
ALTER TABLE logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE call_transcripts ENABLE ROW LEVEL SECURITY;
ALTER TABLE async_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE node_heartbeat ENABLE ROW LEVEL SECURITY;
ALTER TABLE assets ENABLE ROW LEVEL SECURITY;

-- Allow service role full access (your bot uses service role key)
CREATE POLICY "Service role full access" ON messages
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access" ON memory
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access" ON logs
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access" ON call_transcripts
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access" ON async_tasks
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access" ON node_heartbeat
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access" ON assets
  FOR ALL USING (auth.role() = 'service_role');

-- Allow anon key read access (for dashboard, if you build one)
CREATE POLICY "Anon read access" ON messages
  FOR SELECT USING (auth.role() = 'anon');

CREATE POLICY "Anon read access" ON memory
  FOR SELECT USING (auth.role() = 'anon');

-- Allow anon key insert (for the bot when using anon key)
CREATE POLICY "Anon insert access" ON messages
  FOR INSERT WITH CHECK (auth.role() = 'anon');

CREATE POLICY "Anon insert access" ON memory
  FOR INSERT WITH CHECK (auth.role() = 'anon');

CREATE POLICY "Anon insert access" ON logs
  FOR INSERT WITH CHECK (auth.role() = 'anon');

CREATE POLICY "Anon insert access" ON async_tasks
  FOR INSERT WITH CHECK (auth.role() = 'anon');

CREATE POLICY "Anon update access" ON async_tasks
  FOR UPDATE USING (auth.role() = 'anon');

CREATE POLICY "Anon insert access" ON node_heartbeat
  FOR INSERT WITH CHECK (auth.role() = 'anon');

CREATE POLICY "Anon update access" ON node_heartbeat
  FOR UPDATE USING (auth.role() = 'anon');

CREATE POLICY "Anon read access" ON assets
  FOR SELECT USING (auth.role() = 'anon');

CREATE POLICY "Anon insert access" ON assets
  FOR INSERT WITH CHECK (auth.role() = 'anon');

-- ============================================================
-- MIGRATION: If upgrading from an older schema
-- ============================================================
-- If you have the old messages table with message_text/sender_type columns,
-- run this to migrate:
--
-- ALTER TABLE messages RENAME COLUMN message_text TO content;
-- ALTER TABLE messages RENAME COLUMN sender_type TO role;
-- ALTER TABLE messages ADD COLUMN IF NOT EXISTS chat_id TEXT DEFAULT '';
-- UPDATE messages SET chat_id = COALESCE(chat_telegram_id, '') WHERE chat_id = '';
-- ALTER TABLE messages DROP COLUMN IF EXISTS user_telegram_id;
-- ALTER TABLE messages DROP COLUMN IF EXISTS chat_telegram_id;

-- ============================================================
-- OPTIONAL: Semantic Search Function
-- ============================================================
-- Requires pgvector extension and embeddings stored in messages.embedding
-- Run this after deploying the store-telegram-message edge function

CREATE OR REPLACE FUNCTION match_messages(
  query_embedding VECTOR(1536),
  filter_chat_id TEXT DEFAULT NULL,
  match_threshold FLOAT DEFAULT 0.7,
  match_count INT DEFAULT 5
)
RETURNS TABLE (
  id BIGINT,
  content TEXT,
  role TEXT,
  chat_id TEXT,
  created_at TIMESTAMPTZ,
  similarity FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    m.id,
    m.content,
    m.role,
    m.chat_id,
    m.created_at,
    1 - (m.embedding <=> query_embedding) AS similarity
  FROM messages m
  WHERE m.embedding IS NOT NULL
    AND (filter_chat_id IS NULL OR m.chat_id = filter_chat_id)
    AND 1 - (m.embedding <=> query_embedding) > match_threshold
  ORDER BY m.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;

-- ============================================================
-- OPTIONAL: Asset Semantic Search Function
-- ============================================================
-- Requires pgvector extension and embeddings stored in assets.embedding

CREATE OR REPLACE FUNCTION match_assets(
  query_embedding VECTOR(1536),
  match_threshold FLOAT DEFAULT 0.7,
  match_count INT DEFAULT 5
)
RETURNS TABLE (
  id UUID,
  description TEXT,
  tags TEXT[],
  file_type TEXT,
  public_url TEXT,
  created_at TIMESTAMPTZ,
  similarity FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    a.id,
    a.description,
    a.tags,
    a.file_type,
    a.public_url,
    a.created_at,
    1 - (a.embedding <=> query_embedding) AS similarity
  FROM assets a
  WHERE a.embedding IS NOT NULL
    AND 1 - (a.embedding <=> query_embedding) > match_threshold
  ORDER BY a.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;

-- ============================================================
-- Invoice Verifications (audit trail for automated invoice processing)
-- ============================================================

CREATE TABLE IF NOT EXISTS invoice_verifications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  vendor TEXT,
  vendor_display TEXT,
  invoice_number TEXT,
  po_number TEXT,
  invoice_date TEXT,
  invoice_total NUMERIC(12, 2),
  line_item_count INTEGER DEFAULT 0,
  verdict TEXT NOT NULL CHECK (verdict IN ('GOOD_TO_PAY', 'REVIEW_REQUIRED', 'ISSUES_FOUND')),
  issues TEXT[] DEFAULT '{}',
  summary TEXT,
  raw_result JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_invoice_verifications_vendor ON invoice_verifications (vendor);
CREATE INDEX IF NOT EXISTS idx_invoice_verifications_verdict ON invoice_verifications (verdict);
CREATE INDEX IF NOT EXISTS idx_invoice_verifications_created_at ON invoice_verifications (created_at DESC);

ALTER TABLE invoice_verifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role full access" ON invoice_verifications
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Anon read access" ON invoice_verifications
  FOR SELECT USING (auth.role() = 'anon');

CREATE POLICY "Anon insert access" ON invoice_verifications
  FOR INSERT WITH CHECK (auth.role() = 'anon');

-- ============================================================
-- Contracts (track vendor agreements, renewals, expirations)
-- ============================================================

CREATE TABLE IF NOT EXISTS contracts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  vendor TEXT NOT NULL,
  contract_number TEXT,
  contract_type TEXT NOT NULL DEFAULT 'other'
    CHECK (contract_type IN ('MSA', 'SOW', 'amendment', 'service_agreement', 'other')),
  description TEXT,
  start_date DATE,
  end_date DATE,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'expired', 'pending_renewal', 'terminated')),
  total_value NUMERIC(14, 2),
  renewal_notice_days INTEGER DEFAULT 90,
  notes TEXT,
  metadata JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_contracts_vendor ON contracts (vendor);
CREATE INDEX IF NOT EXISTS idx_contracts_status ON contracts (status);
CREATE INDEX IF NOT EXISTS idx_contracts_end_date ON contracts (end_date);

ALTER TABLE contracts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role full access" ON contracts
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Anon read access" ON contracts
  FOR SELECT USING (auth.role() = 'anon');

CREATE POLICY "Anon insert access" ON contracts
  FOR INSERT WITH CHECK (auth.role() = 'anon');

CREATE POLICY "Anon update access" ON contracts
  FOR UPDATE USING (auth.role() = 'anon');

-- ============================================================
-- Purchase Orders (track PO spend, expiry, utilization)
-- ============================================================

CREATE TABLE IF NOT EXISTS purchase_orders (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  vendor TEXT NOT NULL,
  po_number TEXT NOT NULL,
  description TEXT,
  contract_id UUID REFERENCES contracts(id),
  issued_date DATE DEFAULT CURRENT_DATE,
  expiry_date DATE,
  total_amount NUMERIC(14, 2) NOT NULL,
  spent_amount NUMERIC(14, 2) DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'closed', 'exhausted', 'cancelled')),
  notes TEXT,
  metadata JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_purchase_orders_vendor ON purchase_orders (vendor);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_po_number ON purchase_orders (po_number);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_status ON purchase_orders (status);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_expiry_date ON purchase_orders (expiry_date);

ALTER TABLE purchase_orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role full access" ON purchase_orders
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Anon read access" ON purchase_orders
  FOR SELECT USING (auth.role() = 'anon');

CREATE POLICY "Anon insert access" ON purchase_orders
  FOR INSERT WITH CHECK (auth.role() = 'anon');

CREATE POLICY "Anon update access" ON purchase_orders
  FOR UPDATE USING (auth.role() = 'anon');

-- ============================================================
-- Vendor Master (single source of truth for vendor identity)
-- ============================================================

CREATE TABLE IF NOT EXISTS vendor_master (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  name TEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  vendor_code TEXT,
  aliases TEXT[] DEFAULT '{}',
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'inactive', 'suspended')),
  contact_name TEXT,
  contact_email TEXT,
  contact_phone TEXT,
  payment_terms_days INTEGER DEFAULT 30,
  notes TEXT,
  metadata JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_vendor_master_name ON vendor_master (name);
CREATE INDEX IF NOT EXISTS idx_vendor_master_status ON vendor_master (status);

ALTER TABLE vendor_master ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role full access" ON vendor_master
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Anon read access" ON vendor_master
  FOR SELECT USING (auth.role() = 'anon');

CREATE POLICY "Anon insert access" ON vendor_master
  FOR INSERT WITH CHECK (auth.role() = 'anon');

CREATE POLICY "Anon update access" ON vendor_master
  FOR UPDATE USING (auth.role() = 'anon');

-- ============================================================
-- Contract Rates (versioned rate master — replaces CSV files)
-- ============================================================

CREATE TABLE IF NOT EXISTS contract_rates (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  vendor TEXT NOT NULL,
  description TEXT NOT NULL,
  catalog_number TEXT,
  unit TEXT NOT NULL,
  rate NUMERIC(12, 2) NOT NULL,
  effective_date DATE NOT NULL DEFAULT CURRENT_DATE,
  end_date DATE,
  category TEXT,
  notes TEXT,
  metadata JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_contract_rates_vendor ON contract_rates (vendor);
CREATE INDEX IF NOT EXISTS idx_contract_rates_vendor_effective ON contract_rates (vendor, effective_date DESC);
CREATE INDEX IF NOT EXISTS idx_contract_rates_catalog ON contract_rates (catalog_number);

ALTER TABLE contract_rates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role full access" ON contract_rates
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Anon read access" ON contract_rates
  FOR SELECT USING (auth.role() = 'anon');

CREATE POLICY "Anon insert access" ON contract_rates
  FOR INSERT WITH CHECK (auth.role() = 'anon');

-- ============================================================
-- Composite Indexes (performance for ops queries)
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_invoice_verifications_vendor_date
  ON invoice_verifications (vendor, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_invoice_verifications_verdict_date
  ON invoice_verifications (verdict, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_contracts_vendor_status_end
  ON contracts (vendor, status, end_date);

CREATE INDEX IF NOT EXISTS idx_purchase_orders_vendor_status
  ON purchase_orders (vendor, status);

-- ============================================================
-- MIGRATION v2: Asset Storage (2026-02)
-- ============================================================
-- If upgrading from a previous version, just run this entire file again.
-- All CREATE TABLE IF NOT EXISTS statements are safe to re-run.
-- New: assets table for persistent image/file storage
-- Action needed: Create a Storage bucket named "gobot-assets" in Supabase Dashboard
-- (Settings → Storage → New Bucket → Name: "gobot-assets" → Make public)
