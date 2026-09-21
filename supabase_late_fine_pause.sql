
CREATE TABLE IF NOT EXISTS public.loanee_late_fine_pauses (
    id TEXT PRIMARY KEY,
    collection_id TEXT NOT NULL,
    customer_id TEXT,
    account_number TEXT,
    loanee_name TEXT NOT NULL,
    from_date DATE NOT NULL,
    to_date DATE NOT NULL,
    reason TEXT,
    paused_by TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for fast lookup by collection entry ID
CREATE INDEX IF NOT EXISTS idx_late_fine_pauses_collection_id 
ON public.loanee_late_fine_pauses(collection_id);

-- Index for lookup by customer ID
CREATE INDEX IF NOT EXISTS idx_late_fine_pauses_customer_id 
ON public.loanee_late_fine_pauses(customer_id);

-- Enable Row Level Security (RLS)
ALTER TABLE public.loanee_late_fine_pauses ENABLE ROW LEVEL SECURITY;

-- Allow public access policy (compatible with Supabase anon/service role)
DROP POLICY IF EXISTS "Allow public access to loanee_late_fine_pauses" ON public.loanee_late_fine_pauses;
CREATE POLICY "Allow public access to loanee_late_fine_pauses"
ON public.loanee_late_fine_pauses FOR ALL
USING (true)
WITH CHECK (true);

-- Add table to Realtime publication
ALTER PUBLICATION supabase_realtime ADD TABLE public.loanee_late_fine_pauses;
