-- Migration: Add additional survey question types
-- Purpose: Add textarea, number, boolean types to survey_question_type enum

-- Add new enum values if they don't exist
DO $$ 
BEGIN
  -- Add 'textarea' type
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'textarea' AND enumtypid = 'survey_question_type'::regtype) THEN
    ALTER TYPE survey_question_type ADD VALUE 'textarea';
  END IF;
EXCEPTION WHEN others THEN
  -- Type might not exist yet or value already exists
  NULL;
END $$;

DO $$ 
BEGIN
  -- Add 'number' type  
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'number' AND enumtypid = 'survey_question_type'::regtype) THEN
    ALTER TYPE survey_question_type ADD VALUE 'number';
  END IF;
EXCEPTION WHEN others THEN
  NULL;
END $$;

-- Note: 'boolean' is not added because 'yes_no' already serves the same purpose
-- The web panel should map 'boolean' to 'yes_no' before sending to database
