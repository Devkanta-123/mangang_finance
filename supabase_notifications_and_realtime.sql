-- ==============================================================================
-- MANGANG FINANCE - SUPABASE NOTIFICATIONS & REALTIME CONFIGURATION SCRIPT
-- Run this script in the Supabase SQL Editor (https://supabase.com/dashboard)
-- ==============================================================================

-- 1. Create 'notifications' Table
CREATE TABLE IF NOT EXISTS public.notifications (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    recipient_user_id TEXT NOT NULL,
    sender_user_id TEXT,
    notification_type TEXT NOT NULL, -- 'collection_payment', 'collection_entry', 'loanee_created', 'system'
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    reference_id TEXT,
    is_read BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create indexes for ultra-fast notification queries and realtime filtering
CREATE INDEX IF NOT EXISTS idx_notifications_recipient ON public.notifications(recipient_user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON public.notifications(is_read);

-- 2. Enable Supabase Realtime Publication for Tables
-- This ensures Postgres Changes are broadcast over WebSockets to Flutter clients
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE public.ro_collection_entries;
ALTER PUBLICATION supabase_realtime ADD TABLE public.ro_collection_payments;
ALTER PUBLICATION supabase_realtime ADD TABLE public.loanee_accounts;

-- 3. Row Level Security (RLS) Configuration
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Allow anon & authenticated users full read/write for notifications
-- (or filtered by recipient ID / customer ID / mobile / admin role)
DROP POLICY IF EXISTS "Allow select notifications by recipient or admin" ON public.notifications;
CREATE POLICY "Allow select notifications by recipient or admin"
ON public.notifications FOR SELECT
USING (true);

DROP POLICY IF EXISTS "Allow insert notifications" ON public.notifications;
CREATE POLICY "Allow insert notifications"
ON public.notifications FOR INSERT
WITH CHECK (true);

DROP POLICY IF EXISTS "Allow update notifications" ON public.notifications;
CREATE POLICY "Allow update notifications"
ON public.notifications FOR UPDATE
USING (true);

DROP POLICY IF EXISTS "Allow delete notifications" ON public.notifications;
CREATE POLICY "Allow delete notifications"
ON public.notifications FOR DELETE
USING (true);

-- Ensure RLS on collection & payment tables allow Realtime reads
ALTER TABLE public.ro_collection_entries ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow public access to ro_collection_entries" ON public.ro_collection_entries;
CREATE POLICY "Allow public access to ro_collection_entries"
ON public.ro_collection_entries FOR ALL
USING (true);

ALTER TABLE public.ro_collection_payments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow public access to ro_collection_payments" ON public.ro_collection_payments;
CREATE POLICY "Allow public access to ro_collection_payments"
ON public.ro_collection_payments FOR ALL
USING (true);

-- 4. Database-Side Automatic Trigger: On RO Collection Payment Created
-- 4. Database-Side Automatic Trigger: On RO Collection Payment Created
-- Automatically creates realtime notifications for Admin and the specific Loanee (single entry each)
CREATE OR REPLACE FUNCTION public.fn_on_collection_payment_created()
RETURNS TRIGGER AS $$
DECLARE
    v_loanee_name TEXT := 'Loanee';
    v_account_number TEXT := '';
    v_customer_id TEXT := '';
    v_mobile_no TEXT := '';
    v_ro_name TEXT := COALESCE(NEW.ro_name, 'RO Field Officer');
    v_target_recipient TEXT := '';
BEGIN
    -- Fetch Loanee info from parent collection entry
    SELECT loanee_name, account_number, customer_id, mobile_no
    INTO v_loanee_name, v_account_number, v_customer_id, v_mobile_no
    FROM public.ro_collection_entries
    WHERE id = NEW.collection_id
    LIMIT 1;

    IF v_loanee_name IS NULL OR v_loanee_name = '' THEN
        v_loanee_name := 'Loanee';
    END IF;

    -- Determine loanee recipient identifier (prefer customer_id, fallback to mobile_no)
    IF v_customer_id IS NOT NULL AND v_customer_id <> '' THEN
        v_target_recipient := v_customer_id;
    ELSIF v_mobile_no IS NOT NULL AND v_mobile_no <> '' THEN
        v_target_recipient := v_mobile_no;
    END IF;

    -- 1. Create EXACTLY ONE Notification for the Loanee with deterministic ID
    IF v_target_recipient <> '' THEN
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
            'notif_pay_' || NEW.id || '_loanee',
            v_target_recipient,
            NEW.ro_id,
            'collection_payment',
            'Payment Received',
            'Dear ' || v_loanee_name || ', payment of ₹' || TO_CHAR(NEW.payment_amount, 'FM999,999,999.00') || ' was collected by ' || v_ro_name || '. Remaining balance: ₹' || TO_CHAR(NEW.remaining_balance, 'FM999,999,999.00') || '.',
            NEW.id,
            false,
            NEW.created_at
        ) ON CONFLICT (id) DO NOTHING;
    END IF;

    -- 2. Create EXACTLY ONE Notification for Admin Role with deterministic ID
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
        'notif_pay_' || NEW.id || '_admin',
        'admin',
        NEW.ro_id,
        'collection_payment',
        'New Collection Payment',
        v_ro_name || ' recorded payment of ₹' || TO_CHAR(NEW.payment_amount, 'FM999,999,999.00') || ' from ' || v_loanee_name || ' (' || COALESCE(v_account_number, v_customer_id) || ').',
        NEW.id,
        false,
        NEW.created_at
    ) ON CONFLICT (id) DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Attach trigger to ro_collection_payments table
DROP TRIGGER IF EXISTS trg_collection_payment_inserted ON public.ro_collection_payments;
CREATE TRIGGER trg_collection_payment_inserted
AFTER INSERT ON public.ro_collection_payments
FOR EACH ROW
EXECUTE FUNCTION public.fn_on_collection_payment_created();

-- 5. Database-Side Automatic Trigger: On RO Collection Entry / Card Created
CREATE OR REPLACE FUNCTION public.fn_on_collection_entry_created()
RETURNS TRIGGER AS $$
DECLARE
    v_target_recipient TEXT := '';
BEGIN
    -- Determine loanee recipient identifier
    IF NEW.customer_id IS NOT NULL AND NEW.customer_id <> '' THEN
        v_target_recipient := NEW.customer_id;
    ELSIF NEW.mobile_no IS NOT NULL AND NEW.mobile_no <> '' THEN
        v_target_recipient := NEW.mobile_no;
    END IF;

    -- 1. Notify the specific Loanee (single entry with deterministic ID)
    IF v_target_recipient <> '' THEN
        INSERT INTO public.notifications (
            id,
            recipient_user_id,
            notification_type,
            title,
            message,
            reference_id,
            is_read,
            created_at
        ) VALUES (
            'notif_entry_' || NEW.id || '_loanee',
            v_target_recipient,
            'collection_entry',
            'Collection Card Opened',
            'Your collection sheet card has been activated for Route: ' || NEW.route || ' (' || NEW.collection_type || ').',
            NEW.id,
            false,
            NEW.created_at
        ) ON CONFLICT (id) DO NOTHING;
    END IF;

    -- 2. Notify Admin Broadcast (single entry with deterministic ID)
    INSERT INTO public.notifications (
        id,
        recipient_user_id,
        notification_type,
        title,
        message,
        reference_id,
        is_read,
        created_at
    ) VALUES (
        'notif_entry_' || NEW.id || '_admin',
        'admin',
        'collection_entry',
        'New Collection Card Added',
        'New card added for ' || NEW.loanee_name || ' (' || NEW.account_number || ') on Route ' || NEW.route || '.',
        NEW.id,
        false,
        NEW.created_at
    ) ON CONFLICT (id) DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_collection_entry_inserted ON public.ro_collection_entries;
CREATE TRIGGER trg_collection_entry_inserted
AFTER INSERT ON public.ro_collection_entries
FOR EACH ROW
EXECUTE FUNCTION public.fn_on_collection_entry_created();

-- 6. Cleanup Utility: Remove existing duplicate notification entries (if any)
DELETE FROM public.notifications a
USING public.notifications b
WHERE a.id > b.id
  AND a.recipient_user_id = b.recipient_user_id
  AND a.notification_type = b.notification_type
  AND a.reference_id = b.reference_id
  AND a.reference_id IS NOT NULL;
