-- ==============================================================================
-- MANGANG FINANCE - MISSING PAYMENT RECORDS TABLE & CONSTRAINTS
-- Table: public.missing_payment_records
-- Dedicated storage for missing-payment logs (MISSING != PAYMENT)
-- Run this script in your Supabase SQL Editor (https://supabase.com/dashboard)
-- ==============================================================================

-- 1. CREATE TABLE
CREATE TABLE IF NOT EXISTS public.missing_payment_records (
    id TEXT PRIMARY KEY,
    account_id TEXT,
    collection_id TEXT NOT NULL,
    loanee_id TEXT,
    customer_id TEXT,
    account_no TEXT,
    loanee_name TEXT NOT NULL,
    mobile_no TEXT,
    route TEXT,
    collection_type TEXT NOT NULL,
    missed_date DATE NOT NULL,
    day_payment NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    missing_pay NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    missing_fine NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    missing_week INT NOT NULL DEFAULT 0,
    missing_balance NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    status TEXT NOT NULL DEFAULT 'missing', -- 'missing', 'partially_resolved', 'resolved'
    source TEXT NOT NULL DEFAULT 'system',
    remarks TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    -- Database-level duplicate protection
    CONSTRAINT uq_missing_payment_records_collection_date_type UNIQUE (collection_id, missed_date, collection_type)
);

-- 2. CREATE INDEXES
CREATE INDEX IF NOT EXISTS idx_missing_payment_records_account_id ON public.missing_payment_records(account_id);
CREATE INDEX IF NOT EXISTS idx_missing_payment_records_loanee_id ON public.missing_payment_records(loanee_id);
CREATE INDEX IF NOT EXISTS idx_missing_payment_records_collection_id ON public.missing_payment_records(collection_id);
CREATE INDEX IF NOT EXISTS idx_missing_payment_records_customer_id ON public.missing_payment_records(customer_id);
CREATE INDEX IF NOT EXISTS idx_missing_payment_records_missed_date ON public.missing_payment_records(missed_date);
CREATE INDEX IF NOT EXISTS idx_missing_payment_records_route ON public.missing_payment_records(route);
CREATE INDEX IF NOT EXISTS idx_missing_payment_records_collection_type ON public.missing_payment_records(collection_type);
CREATE INDEX IF NOT EXISTS idx_missing_payment_records_status ON public.missing_payment_records(status);

-- 3. ENABLE ROW LEVEL SECURITY (RLS)
ALTER TABLE public.missing_payment_records ENABLE ROW LEVEL SECURITY;

-- 4. RLS POLICIES FOR FULL COMPATIBILITY WITH APPLICATION
DROP POLICY IF EXISTS "Allow public access to missing_payment_records" ON public.missing_payment_records;
CREATE POLICY "Allow public access to missing_payment_records"
ON public.missing_payment_records FOR ALL
TO anon, authenticated, service_role
USING (true)
WITH CHECK (true);

-- 5. PERMISSIONS
GRANT ALL ON TABLE public.missing_payment_records TO anon, authenticated, service_role, postgres;

-- 6. ADD TO REALTIME PUBLICATION
ALTER PUBLICATION supabase_realtime ADD TABLE public.missing_payment_records;

-- 7. CLEANUP MIGRATION FOR OLD ARCHITECTURE (OPTIONAL & SAFE)
-- Removes old fake payment PAY-LATE records from ro_collection_payments
-- (Leaving Post-Maturity PAY-POSTMAT records intact)
-- DELETE FROM public.ro_collection_payments
-- WHERE id LIKE 'PAY-LATE-%'
--   AND ro_id = 'SYS-AUTO'
--   AND payment_amount = 0.00
--   AND payment_type = 'Late Fee';
