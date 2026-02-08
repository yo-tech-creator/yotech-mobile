-- Add pinned_at column to announcements table
-- This column tracks when an announcement was pinned for proper ordering

ALTER TABLE public.announcements 
ADD COLUMN IF NOT EXISTS pinned_at TIMESTAMPTZ;

-- Set pinned_at for existing pinned announcements
UPDATE public.announcements 
SET pinned_at = published_at 
WHERE pinned = true AND pinned_at IS NULL;

-- Create index for efficient ordering
CREATE INDEX IF NOT EXISTS idx_announcements_pinned_at 
ON public.announcements(pinned_at DESC NULLS LAST);

COMMENT ON COLUMN public.announcements.pinned_at IS 'Timestamp when the announcement was pinned. Used for ordering pinned items (most recently pinned first).';
