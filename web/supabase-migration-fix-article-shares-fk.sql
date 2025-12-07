-- ============================================
-- MIGRATION: Fix article_shares foreign keys
-- ============================================
-- Problema: article_shares.shared_by e shared_with puntano a auth.users
-- ma le query Supabase cercano di fare join con user_profiles.
-- Soluzione: Aggiungere FK esplicite a user_profiles per permettere i join.

-- Aggiungi foreign key da article_shares.shared_by a user_profiles
ALTER TABLE article_shares
ADD CONSTRAINT article_shares_shared_by_profile_fkey
FOREIGN KEY (shared_by) REFERENCES user_profiles(id) ON DELETE CASCADE;

-- Aggiungi foreign key da article_shares.shared_with a user_profiles
ALTER TABLE article_shares
ADD CONSTRAINT article_shares_shared_with_profile_fkey
FOREIGN KEY (shared_with) REFERENCES user_profiles(id) ON DELETE CASCADE;
