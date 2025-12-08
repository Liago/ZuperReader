# User Preferences Migration Guide

## Overview
This migration adds database synchronization for user reading preferences (themes, fonts, etc.) across all devices.

## What's New
- 5 modern color themes: **Light**, **Dark**, **Ocean**, **Forest**, **Sunset**
- Cross-device synchronization via Supabase
- Offline support with localStorage fallback
- Automatic sync when preferences change

## Database Migration

### Step 1: Run the SQL Migration
Execute the SQL file in your Supabase dashboard:

```bash
# File location:
web/supabase-migration-user-preferences.sql
```

**How to execute:**
1. Go to your Supabase project dashboard
2. Navigate to **SQL Editor**
3. Click **"New Query"**
4. Copy and paste the contents of `supabase-migration-user-preferences.sql`
5. Click **"Run"** to execute the migration

### Step 2: Verify the Migration
After running the migration, verify that the table was created:

```sql
-- Check if the table exists
SELECT * FROM user_preferences LIMIT 1;

-- Check table structure
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'user_preferences';
```

## Features

### 1. Cross-Device Synchronization
- Preferences are saved to Supabase database
- Automatically sync across all devices
- Changes on one device appear on all devices

### 2. Offline Support
- Preferences cached in localStorage
- Works offline with cached data
- Syncs to database when online

### 3. Migration Strategy
- **First Load**: Tries database → falls back to localStorage
- **Every Update**: Saves to both database and localStorage
- **No User Required**: Works for anonymous users (localStorage only)

## New Color Themes

| Theme | Description | Colors |
|-------|-------------|--------|
| **Light** | Classic bright theme | White background, dark text |
| **Dark** | Dark slate theme | Dark slate background, light text |
| **Ocean** | Marine blue palette | Sky blue background, cyan accents |
| **Forest** | Nature green palette | Emerald background, green accents |
| **Sunset** | Twilight violet palette | Violet background, fuchsia accents |

## API Changes

### New Functions in `lib/api.ts`

```typescript
// Get user preferences from database
getUserPreferences(userId: string): Promise<UserPreferences | null>

// Save/update user preferences
saveUserPreferences(userId: string, preferences: Omit<UserPreferences, 'id' | 'created_at' | 'updated_at'>): Promise<UserPreferences>

// Delete user preferences
deleteUserPreferences(userId: string): Promise<void>
```

### New Types in `lib/supabase.ts`

```typescript
export type UserPreferences = {
    id: string; // User ID
    font_family: 'sans' | 'serif' | 'mono' | 'roboto' | 'lato' | 'openSans' | 'ubuntu';
    font_size: number; // 12-50
    color_theme: 'light' | 'dark' | 'ocean' | 'forest' | 'sunset';
    line_height: 'compact' | 'normal' | 'relaxed' | 'loose';
    content_width: 'narrow' | 'normal' | 'wide';
    view_mode: 'grid' | 'list';
    created_at: string;
    updated_at: string;
}
```

## Context Changes

### ReadingPreferencesContext
The context now:
- Uses `useAuth()` to get current user
- Loads preferences from database if user is logged in
- Falls back to localStorage if database is unavailable
- Saves to both database and localStorage on every change

## Testing

### Test Cross-Device Sync
1. Login to your account on Device A
2. Change theme to "Ocean"
3. Login to the same account on Device B
4. Theme should automatically be "Ocean"

### Test Offline Support
1. Change preferences while online
2. Go offline (disable network)
3. Preferences should still work (from localStorage)
4. Change preferences offline
5. Go back online
6. Changes should sync to database

### Test Anonymous Users
1. Use the app without logging in
2. Change preferences
3. Preferences should save to localStorage only
4. Login
5. Preferences should sync to database

## Rollback (if needed)

If you need to rollback this migration:

```sql
-- Drop the table
DROP TABLE IF EXISTS user_preferences CASCADE;

-- Drop the trigger function
DROP FUNCTION IF EXISTS update_user_preferences_updated_at() CASCADE;
```

## Security

- **Row Level Security (RLS)** is enabled
- Users can only read/write their own preferences
- Policies ensure data isolation per user

## Performance

- **localStorage cache**: Instant preference loading
- **Database sync**: Async, doesn't block UI
- **Optimistic updates**: UI updates immediately, database syncs in background
