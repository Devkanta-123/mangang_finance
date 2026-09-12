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

-- 4. OPTIONAL BACKFILL FOR PREVIOUSLY IMPORTED RECORDS FROM REMARKS
-- Safely extracts post maturity interest, late fees, and interest from remarks text for records where columns are 0.00
UPDATE public.ro_collection_payments
SET 
  post_maturity_interest = CASE 
    WHEN post_maturity_interest = 0.00 THEN COALESCE(
      NULLIF(SUBSTRING(remarks FROM 'Post\s*Maturity(?:\s*(?:Fine|Interest))?:\s*₹?\s*([0-9.]+)'), '')::NUMERIC(12, 2),
      post_maturity_interest
    )
    ELSE post_maturity_interest
  END,
  late_fine = CASE 
    WHEN late_fine = 0.00 THEN COALESCE(
      NULLIF(SUBSTRING(remarks FROM 'Late\s*(?:Payment\s*)?(?:Fee|Fine|Interest):\s*₹?\s*([0-9.]+)'), '')::NUMERIC(12, 2),
      late_fine
    )
    ELSE late_fine
  END,
  interest = CASE 
    WHEN interest = 0.00 THEN COALESCE(
      NULLIF(SUBSTRING(remarks FROM '(?:Daily/Weekly\s*)?Late\s*(?:Payment\s*)?(?:Fee|Fine|Interest):\s*₹?\s*([0-9.]+)'), '')::NUMERIC(12, 2),
      NULLIF(SUBSTRING(remarks FROM '(?:Total\s*)?Interest:\s*₹?\s*([0-9.]+)'), '')::NUMERIC(12, 2),
      interest
    )
    ELSE interest
  END
WHERE remarks LIKE 'Historical Excel Import%'
  AND (post_maturity_interest = 0.00 OR interest = 0.00);
