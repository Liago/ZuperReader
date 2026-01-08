-- Migration to update the font_family check constraint in user_preferences table
-- This adds support for new custom fonts (and missing ones)

-- 1. Drop the existing check constraint
ALTER TABLE user_preferences
DROP CONSTRAINT IF EXISTS user_preferences_font_family_check;

-- 2. Add the new check constraint with all supported fonts
ALTER TABLE user_preferences
ADD CONSTRAINT user_preferences_font_family_check
CHECK (font_family IN (
    'sans',
    'serif',
    'mono',
    'inter',
    'poppins',
    'lora',
    'montserrat',
    'crimsonText',
    'roboto',
    'lato',
    'openSans',
    'ubuntu'
));

-- 3. Comment to verify
COMMENT ON COLUMN user_preferences.font_family IS 'Font family: sans, serif, mono, inter, poppins, lora, montserrat, crimsonText, roboto, lato, openSans, ubuntu';
