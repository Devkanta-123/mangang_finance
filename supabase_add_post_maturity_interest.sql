-- ==============================================================================
-- MANGANG FINANCE - DB SCHEMA FOR post_maturity_interest
-- Table: public.ro_collection_payments
-- Default: 0.00 (numeric)
-- No dummy data inserted.
-- ==============================================================================

-- 1. ADD COLUMN TO EXISTING TABLE (Safe idempotent migration)
ALTER TABLE public.ro_collection_payments 
ADD COLUMN IF NOT EXISTS post_maturity_interest NUMERIC(12, 2) NOT NULL DEFAULT 0.00;

-- Optional: ensure standard interest column is also present with default 0.00
ALTER TABLE public.ro_collection_payments 
ADD COLUMN IF NOT EXISTS interest NUMERIC(12, 2) NOT NULL DEFAULT 0.00;

-- Optional: ensure ro_route column is present if not already added
ALTER TABLE public.ro_collection_payments 
ADD COLUMN IF NOT EXISTS ro_route TEXT;

-- 2. CREATE INDEX FOR FASTER FILTERING & AGGREGATIONS
CREATE INDEX IF NOT EXISTS idx_ro_collection_payments_collection_id 
ON public.ro_collection_payments(collection_id);

CREATE INDEX IF NOT EXISTS idx_ro_collection_payments_created_at 
ON public.ro_collection_payments(created_at DESC);

-- 3. COLUMN DOCUMENTATION COMMENT
COMMENT ON COLUMN public.ro_collection_payments.post_maturity_interest 
IS 'Accrued post maturity fine or interest portion for overdue loans (Default: 0.00)';
