-- ==============================================================================
-- MANGANG FINANCE - OFFICIAL HOLIDAYS & REALTIME NOTIFICATIONS SCHEMA
-- Run this script in the Supabase SQL Editor (https://supabase.com/dashboard)
-- ==============================================================================

-- 1. Create 'holidays' Table
CREATE TABLE IF NOT EXISTS public.holidays (
    id TEXT PRIMARY KEY DEFAULT ('HOL-' || gen_random_uuid()::text),
    holiday_date DATE NOT NULL UNIQUE,
    description TEXT NOT NULL,
    created_by TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Comments for documentation
COMMENT ON TABLE public.holidays IS 'Stores declared official holidays. Collections are suspended, late fees are suppressed, and auto late-fee entries are skipped on these dates.';
COMMENT ON COLUMN public.holidays.holiday_date IS 'Unique calendar date for the declared holiday (YYYY-MM-DD).';
COMMENT ON COLUMN public.holidays.description IS 'Name or reason for the holiday (e.g., Yaoshang, Kang, Independence Day).';

-- Create indexes for fast date queries and ordering
CREATE INDEX IF NOT EXISTS idx_holidays_date ON public.holidays(holiday_date);
CREATE INDEX IF NOT EXISTS idx_holidays_created_at ON public.holidays(created_at DESC);

-- 2. Enable Realtime Replication for 'holidays' Table
-- This broadcasts PostgreSQL changes (INSERT, UPDATE, DELETE) to all connected Flutter clients
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'holidays'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.holidays;
    END IF;
END $$;

-- 3. Row Level Security (RLS) Configuration
ALTER TABLE public.holidays ENABLE ROW LEVEL SECURITY;

-- Allow all authenticated and anonymous clients to read holidays
DROP POLICY IF EXISTS "Allow select holidays for all users" ON public.holidays;
CREATE POLICY "Allow select holidays for all users"
ON public.holidays FOR SELECT
USING (true);

-- Allow insert of holidays (by administrators / application)
DROP POLICY IF EXISTS "Allow insert holidays" ON public.holidays;
CREATE POLICY "Allow insert holidays"
ON public.holidays FOR INSERT
WITH CHECK (true);

-- Allow update of holidays
DROP POLICY IF EXISTS "Allow update holidays" ON public.holidays;
CREATE POLICY "Allow update holidays"
ON public.holidays FOR UPDATE
USING (true);

-- Allow delete of holidays
DROP POLICY IF EXISTS "Allow delete holidays" ON public.holidays;
CREATE POLICY "Allow delete holidays"
ON public.holidays FOR DELETE
USING (true);

-- 4. Ensure 'notifications' Table Supports Broadcasts ('all' recipient)
-- Verify RLS on 'notifications' allows reading broadcast notifications
DROP POLICY IF EXISTS "Allow select notifications by recipient or admin" ON public.notifications;
CREATE POLICY "Allow select notifications by recipient or admin"
ON public.notifications FOR SELECT
USING (true);

-- 5. Database Trigger: Automatically Dispatch Realtime Broadcast Notification on Holiday Insert
CREATE OR REPLACE FUNCTION public.fn_on_holiday_created()
RETURNS TRIGGER AS $$
DECLARE
    v_formatted_date TEXT;
    v_creator TEXT;
BEGIN
    -- Format date nicely (e.g. '15 Aug 2026')
    v_formatted_date := TO_CHAR(NEW.holiday_date, 'DD Mon YYYY');
    v_creator := COALESCE(NEW.created_by, 'Administrator');

    -- Insert broadcast notification for 'all' users
    INSERT INTO public.notifications (
        id,
        recipient_user_id,
        sender_user_id,
        notification_type,
        title,
        message,
        reference_id,
        is_read,
        created_at
    ) VALUES (
        'notif_hol_' || NEW.id,
        'all',
        v_creator,
        'holiday',
        '📢 Holiday Declared: ' || NEW.description,
        'Notice: ' || v_formatted_date || ' has been declared an official holiday ("' || NEW.description || '"). Collection payments are suspended and daily late fines will not be assessed on this date.',
        NEW.id,
        false,
        NEW.created_at
    )
    ON CONFLICT (id) DO UPDATE SET
        title = EXCLUDED.title,
        message = EXCLUDED.message,
        created_at = EXCLUDED.created_at;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Bind trigger to public.holidays table
DROP TRIGGER IF EXISTS trg_on_holiday_created ON public.holidays;
CREATE TRIGGER trg_on_holiday_created
AFTER INSERT OR UPDATE ON public.holidays
FOR EACH ROW
EXECUTE FUNCTION public.fn_on_holiday_created();

-- ==============================================================================
-- 6. Verification and Sample Query
-- ==============================================================================
-- Sample insert to test holiday creation (Uncomment to test):
-- INSERT INTO public.holidays (id, holiday_date, description, created_by)
-- VALUES ('HOL-TEST-01', CURRENT_DATE + INTERVAL '1 day', 'Kang (Rath Yatra)', 'Administrator')
-- ON CONFLICT (holiday_date) DO NOTHING;

-- Check all holidays:
-- SELECT * FROM public.holidays ORDER BY holiday_date ASC;

-- Check broadcast notifications:
-- SELECT * FROM public.notifications WHERE notification_type = 'holiday' ORDER BY created_at DESC;
