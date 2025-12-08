# Troubleshooting: User Preferences Migration Error

## Error Message
```
Error: Failed to run sql query: ERROR: 42703: column "font_family" of relation "user_preferences" does not exist
```

## Cause
This error occurs when:
1. The table `user_preferences` exists but has incorrect or incomplete structure
2. The initial migration was partially executed
3. A previous version of the table was created with different column names

## Solution

Follow these steps in order:

### Step 1: Check Current Table Status

Run this SQL in Supabase SQL Editor:

```sql
-- File: web/supabase-check-user-preferences.sql
SELECT
    column_name,
    data_type,
    column_default,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'user_preferences'
ORDER BY ordinal_position;
```

**Expected Result:**
- If the table doesn't exist: No rows returned
- If the table exists with wrong structure: You'll see the incorrect columns

### Step 2: Clean Recreation

Execute the clean migration script to drop and recreate the table correctly:

**File:** `web/supabase-migration-user-preferences-clean.sql`

This script will:
1. ✅ Drop the existing `user_preferences` table (if it exists)
2. ✅ Drop any related triggers and functions
3. ✅ Create the table with correct structure
4. ✅ Set up Row Level Security policies
5. ✅ Create triggers for auto-updating timestamps
6. ✅ Verify the final structure

**How to execute:**
1. Go to Supabase Dashboard → SQL Editor
2. Click "New Query"
3. Copy all contents from `supabase-migration-user-preferences-clean.sql`
4. Click "Run"

### Step 3: Verify the Migration

After running the clean migration, you should see output showing all columns:

```
column_name     | data_type            | column_default | is_nullable
----------------|---------------------|----------------|-------------
id              | uuid                | NULL           | NO
font_family     | text                | 'serif'        | NO
font_size       | integer             | 16             | NO
color_theme     | text                | 'light'        | NO
line_height     | text                | 'relaxed'      | NO
content_width   | text                | 'normal'       | NO
view_mode       | text                | 'grid'         | NO
created_at      | timestamp with tz   | now()          | NO
updated_at      | timestamp with tz   | now()          | NO
```

### Step 4: Test the Application

After successful migration:

1. **Clear your browser cache and localStorage:**
   - Open browser console (F12)
   - Run: `localStorage.clear()`
   - Refresh the page

2. **Test preference saving:**
   - Open an article
   - Click the Settings FAB button (bottom right)
   - Change the theme (e.g., to "Ocean")
   - Refresh the page
   - Theme should persist

3. **Test cross-device sync:**
   - Login on Device A
   - Change theme to "Forest"
   - Login on Device B (or different browser)
   - Theme should be "Forest"

## Common Issues

### Issue 1: "relation user_preferences already exists"
**Solution:** The clean script handles this automatically with `DROP TABLE IF EXISTS`

### Issue 2: "must be owner of table user_preferences"
**Solution:** Make sure you're executing the SQL as the database owner (default in Supabase Dashboard)

### Issue 3: Policies not working
**Solution:**
```sql
-- Check if RLS is enabled
SELECT tablename, rowsecurity
FROM pg_tables
WHERE tablename = 'user_preferences';

-- Re-enable if needed
ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;
```

### Issue 4: Changes not syncing
**Checklist:**
- [ ] User is logged in (check `user?.id` in browser console)
- [ ] Table was created successfully
- [ ] RLS policies are active
- [ ] No console errors in browser developer tools
- [ ] Network requests to Supabase are successful

## Verification Queries

### Check if table exists and has correct structure:
```sql
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'user_preferences';
```

### Check RLS policies:
```sql
SELECT policyname, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'user_preferences';
```

### Check triggers:
```sql
SELECT trigger_name, event_manipulation, event_object_table
FROM information_schema.triggers
WHERE event_object_table = 'user_preferences';
```

### Test insert (replace USER_ID with actual user ID):
```sql
INSERT INTO user_preferences (
    id,
    font_family,
    font_size,
    color_theme,
    line_height,
    content_width,
    view_mode
) VALUES (
    'USER_ID'::uuid,
    'serif',
    16,
    'light',
    'relaxed',
    'normal',
    'grid'
);
```

### Test select:
```sql
SELECT * FROM user_preferences WHERE id = 'USER_ID'::uuid;
```

## Still Having Issues?

If problems persist:

1. Check Supabase logs in Dashboard → Logs
2. Check browser console for JavaScript errors
3. Verify Supabase connection strings in `.env`
4. Make sure you're using the correct Supabase project

## Rollback (Emergency)

If you need to completely remove the feature:

```sql
-- Remove everything
DROP TABLE IF EXISTS user_preferences CASCADE;
DROP FUNCTION IF EXISTS update_user_preferences_updated_at() CASCADE;
```

Then the app will fall back to localStorage-only mode (no cross-device sync).
