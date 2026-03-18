-- Phase 2 - Personalization
-- Migration: create user_profiles table for personalization agent
-- Safe to re-run (IF NOT EXISTS guards everywhere)

-- ============================================================
-- USER PROFILES TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.user_profiles (
    profile_id                SERIAL PRIMARY KEY,
    user_id                   UUID NOT NULL UNIQUE
                              REFERENCES auth.app_users(user_id) ON DELETE CASCADE,

    preferred_cuisines        JSONB DEFAULT '[]',
    top_items                 JSONB DEFAULT '[]',
    top_deals                 JSONB DEFAULT '[]',
    disliked_items            JSONB DEFAULT '[]',
    preference_vector         JSONB DEFAULT '{}',

    cached_recommendations    JSONB DEFAULT NULL,
    cached_recommendations_ts TIMESTAMP DEFAULT NULL,

    last_updated              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at                TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_user_profiles_user_id
    ON public.user_profiles(user_id);

CREATE INDEX IF NOT EXISTS idx_user_profiles_updated
    ON public.user_profiles(last_updated);

CREATE INDEX IF NOT EXISTS idx_user_profiles_cache_ts
    ON public.user_profiles(cached_recommendations_ts);
