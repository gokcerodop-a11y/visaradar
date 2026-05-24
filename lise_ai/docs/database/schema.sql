-- =============================================================================
-- LiseAI Production Database Schema
-- PostgreSQL 15+ / Supabase
-- Version : 1.0.0
-- Date    : 2026-05-24
-- =============================================================================
--
-- Run order:
--   1. Extensions
--   2. Helper functions
--   3. Tables (dependency order)
--   4. Indexes
--   5. Row Level Security policies
--   6. Triggers (updated_at, sync_version)
--   7. Retention / archival jobs (pg_cron)
--
-- Conventions:
--   • All PKs are UUID generated with gen_random_uuid().
--   • Every table has created_at, updated_at (auto-maintained by trigger).
--   • Soft-delete columns: deleted_at timestamptz (NULL = live).
--   • Optimistic sync fields: sync_version bigint, client_id text.
--   • Foreign keys use ON DELETE CASCADE unless stated otherwise.
--   • Text enums use CHECK constraints (easy to extend later).
-- =============================================================================


-- =============================================================================
-- 1. EXTENSIONS
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";     -- gen_random_uuid() fallback
CREATE EXTENSION IF NOT EXISTS "pgcrypto";      -- encode/decode helpers
-- CREATE EXTENSION IF NOT EXISTS "vector";     -- pgvector — enable when AI embeddings needed


-- =============================================================================
-- 2. HELPER FUNCTIONS
-- =============================================================================

-- Auto-update updated_at on every row modification.
CREATE OR REPLACE FUNCTION trigger_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- Bump sync_version atomically on every write.
CREATE OR REPLACE FUNCTION trigger_bump_sync_version()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.sync_version = OLD.sync_version + 1;
  RETURN NEW;
END;
$$;

-- Convenience macro: attach both triggers to a table.
-- Usage: SELECT attach_sync_triggers('my_table');
CREATE OR REPLACE FUNCTION attach_sync_triggers(tbl text)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE format(
    'CREATE TRIGGER set_updated_at
     BEFORE UPDATE ON %I
     FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at()',
    tbl
  );
  EXECUTE format(
    'CREATE TRIGGER bump_sync_version
     BEFORE UPDATE ON %I
     FOR EACH ROW WHEN (OLD.* IS DISTINCT FROM NEW.*)
     EXECUTE FUNCTION trigger_bump_sync_version()',
    tbl
  );
END;
$$;


-- =============================================================================
-- 3. TABLES
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 3.1  users
--      Public mirror of auth.users. RLS locks each row to its owner.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
  -- Identity
  id                uuid        PRIMARY KEY
                                REFERENCES auth.users(id) ON DELETE CASCADE,
  email             text        UNIQUE,
  display_name      text,
  avatar_url        text,

  -- Account type
  is_anonymous      boolean     NOT NULL DEFAULT true,
  locale            text        NOT NULL DEFAULT 'tr'
                                CHECK (char_length(locale) <= 10),

  -- Family accounts (future): parent links to children
  family_owner_id   uuid        REFERENCES users(id) ON DELETE SET NULL,
  family_role       text        CHECK (family_role IN ('owner', 'member')),

  -- Timestamps
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  deleted_at        timestamptz,                        -- soft delete

  -- Optimistic sync
  sync_version      bigint      NOT NULL DEFAULT 0,
  client_id         text,                               -- last-write client tag

  -- Conflict resolution
  last_sync_at      timestamptz DEFAULT now(),
  conflict_strategy text        NOT NULL DEFAULT 'last_write_wins'
                                CHECK (conflict_strategy IN (
                                  'last_write_wins', 'merge', 'server_wins'
                                ))
);

COMMENT ON TABLE  users IS 'Public user profile mirroring auth.users.';
COMMENT ON COLUMN users.is_anonymous IS 'True for Supabase anonymous sign-in sessions.';
COMMENT ON COLUMN users.family_owner_id IS 'Set for family-plan child accounts; parent owns subscription.';
COMMENT ON COLUMN users.sync_version IS 'Monotonically increasing counter for optimistic concurrency.';
COMMENT ON COLUMN users.client_id IS 'Identifier of the device/client that last wrote this row.';


-- ---------------------------------------------------------------------------
-- 3.2  student_profiles
--      One row per user. Stores the full learner model.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS student_profiles (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           uuid        NOT NULL
                                REFERENCES users(id) ON DELETE CASCADE
                                UNIQUE,                 -- 1:1 with users

  -- Learning preferences
  grade_level       text        NOT NULL DEFAULT 'sinif9',
  lesson_mode       text        NOT NULL DEFAULT 'ogretmenGibi',

  -- Topic mastery (arrays for cheap O(1) reads; denormalised intentionally)
  weak_topics       text[]      NOT NULL DEFAULT '{}',
  strong_topics     text[]      NOT NULL DEFAULT '{}',
  mastery_map       jsonb,                              -- topic→[0,1] map

  -- Session statistics
  total_sessions    integer     NOT NULL DEFAULT 0  CHECK (total_sessions >= 0),
  total_messages    integer     NOT NULL DEFAULT 0  CHECK (total_messages >= 0),
  avg_confidence    real        NOT NULL DEFAULT 0.5 CHECK (avg_confidence BETWEEN 0 AND 1),
  avg_success_rate  real                            CHECK (avg_success_rate BETWEEN 0 AND 1),

  -- Cognitive model snapshot (serialised CognitiveProfile)
  cognitive_style   jsonb,
  motivation_state  text        NOT NULL DEFAULT 'normal'
                                CHECK (motivation_state IN (
                                  'normal', 'excited', 'frustrated', 'bored'
                                )),

  -- Timestamps
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  deleted_at        timestamptz,

  -- Optimistic sync
  sync_version      bigint      NOT NULL DEFAULT 0,
  client_id         text,
  last_sync_at      timestamptz DEFAULT now()
);

COMMENT ON TABLE student_profiles IS 'Full learner model: one row per user.';
COMMENT ON COLUMN student_profiles.mastery_map IS 'JSONB topic→score map, e.g. {"türev": 0.8, "integral": 0.3}.';


-- ---------------------------------------------------------------------------
-- 3.3  conversations
--      A conversation is a single chat session thread.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS conversations (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           uuid        NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  title             text,
  topic             text,                               -- detected primary topic
  lesson_mode       text,
  message_count     integer     NOT NULL DEFAULT 0  CHECK (message_count >= 0),

  -- Retention / archival
  archived_at       timestamptz,                        -- set when moved to cold storage
  archive_tier      text        CHECK (archive_tier IN ('hot', 'warm', 'cold')),
  summary           text,                               -- LLM-generated summary on archive

  -- Timestamps
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  deleted_at        timestamptz,

  -- Optimistic sync
  sync_version      bigint      NOT NULL DEFAULT 0,
  client_id         text,
  last_sync_at      timestamptz DEFAULT now()
);

COMMENT ON TABLE conversations IS 'One row per chat thread.';
COMMENT ON COLUMN conversations.archived_at IS 'Filled by archival job; older than 90 days moves to warm tier.';
COMMENT ON COLUMN conversations.summary IS 'Optional LLM summary written before archiving full message rows.';


-- ---------------------------------------------------------------------------
-- 3.4  conversation_messages
--      Individual turns within a conversation.
--      Hot path: most reads/writes land here.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS conversation_messages (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id   uuid        NOT NULL
                                REFERENCES conversations(id) ON DELETE CASCADE,
  user_id           uuid        NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  -- Content
  role              text        NOT NULL
                                CHECK (role IN ('user', 'assistant', 'system')),
  content           text        NOT NULL,
  content_type      text        NOT NULL DEFAULT 'text'
                                CHECK (content_type IN ('text', 'image', 'pdf', 'audio')),

  -- Lesson context
  has_board_lesson  boolean     NOT NULL DEFAULT false,
  lesson_question   text,

  -- Token tracking (populated by server or client estimate)
  token_count       integer     CHECK (token_count >= 0),
  model_used        text,

  -- Timestamps
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  deleted_at        timestamptz,                        -- soft delete keeps stats intact

  -- Optimistic sync
  sync_version      bigint      NOT NULL DEFAULT 0,
  client_id         text,
  last_sync_at      timestamptz DEFAULT now()
);

COMMENT ON TABLE conversation_messages IS 'Individual turns within a conversation thread.';
COMMENT ON COLUMN conversation_messages.token_count IS 'Set by client from API usage object; NULL until known.';


-- ---------------------------------------------------------------------------
-- 3.5  lesson_sessions
--      One row per structured lesson attempt (StructuredLessonFlowEngine output).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS lesson_sessions (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           uuid        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  conversation_id   uuid        REFERENCES conversations(id) ON DELETE SET NULL,

  topic             text        NOT NULL,
  mode              text        NOT NULL,
  final_phase       text,                               -- which StructuredPhase was reached

  -- Outcome metrics
  duration_secs     integer     NOT NULL DEFAULT 0  CHECK (duration_secs >= 0),
  message_count     integer     NOT NULL DEFAULT 0  CHECK (message_count >= 0),
  success_rate      real                            CHECK (success_rate BETWEEN 0 AND 1),
  hints_used        integer     NOT NULL DEFAULT 0,
  board_opened      boolean     NOT NULL DEFAULT false,
  voice_used        boolean     NOT NULL DEFAULT false,

  -- Timestamps
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  deleted_at        timestamptz,

  -- Optimistic sync
  sync_version      bigint      NOT NULL DEFAULT 0,
  client_id         text,
  last_sync_at      timestamptz DEFAULT now()
);

COMMENT ON TABLE lesson_sessions IS 'Structured lesson outcomes produced by LessonFlowEngine.';


-- ---------------------------------------------------------------------------
-- 3.6  memory_items
--      Five-tier cognitive memory model (short/working/long/episodic/semantic).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS memory_items (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           uuid        NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  -- Memory type taxonomy
  memory_type       text        NOT NULL
                                CHECK (memory_type IN (
                                  'short_term', 'working', 'long_term',
                                  'episodic', 'semantic'
                                )),
  topic             text,
  content           text        NOT NULL,

  -- Semantic search (enable when pgvector is available)
  -- embedding        vector(1536),

  -- Salience / decay
  importance        real        NOT NULL DEFAULT 0.5 CHECK (importance BETWEEN 0 AND 1),
  access_count      integer     NOT NULL DEFAULT 0   CHECK (access_count >= 0),
  last_accessed_at  timestamptz,

  -- Retention management
  expires_at        timestamptz,                        -- short_term: auto-expire after 24h
  compressed        boolean     NOT NULL DEFAULT false, -- candidate for summarisation
  compression_group text,                               -- batch ID for group compression

  -- Timestamps
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  deleted_at        timestamptz,

  -- Optimistic sync
  sync_version      bigint      NOT NULL DEFAULT 0,
  client_id         text,
  last_sync_at      timestamptz DEFAULT now()
);

COMMENT ON TABLE memory_items IS 'Five-layer cognitive memory model per user.';
COMMENT ON COLUMN memory_items.expires_at IS 'short_term rows expire after 24h; cleaned by pg_cron job.';
COMMENT ON COLUMN memory_items.compressed IS 'Flag set before LLM summarisation; row deleted after merge.';


-- ---------------------------------------------------------------------------
-- 3.7  achievements
--      Gamification: badges, levels, progress.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS achievements (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           uuid        NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  achievement_key   text        NOT NULL,               -- e.g. 'streak_7', 'topic_master_math'
  label             text        NOT NULL,
  icon              text,                               -- emoji or asset key
  level             integer     NOT NULL DEFAULT 1  CHECK (level >= 1),
  progress          real        NOT NULL DEFAULT 0.0 CHECK (progress BETWEEN 0 AND 1),
  unlocked_at       timestamptz,                        -- NULL = locked

  -- Timestamps
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  deleted_at        timestamptz,

  -- Optimistic sync
  sync_version      bigint      NOT NULL DEFAULT 0,
  client_id         text,
  last_sync_at      timestamptz DEFAULT now(),

  UNIQUE (user_id, achievement_key)
);

COMMENT ON TABLE achievements IS 'Gamification badges and progress. Unique per user+key.';


-- ---------------------------------------------------------------------------
-- 3.8  streaks
--      One row per user; updated daily.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS streaks (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           uuid        NOT NULL REFERENCES users(id) ON DELETE CASCADE
                                UNIQUE,

  current_streak    integer     NOT NULL DEFAULT 0  CHECK (current_streak >= 0),
  longest_streak    integer     NOT NULL DEFAULT 0  CHECK (longest_streak >= 0),
  last_study_date   date,
  total_study_days  integer     NOT NULL DEFAULT 0  CHECK (total_study_days >= 0),

  -- Freeze / grace day (premium feature)
  freeze_count      integer     NOT NULL DEFAULT 0,
  grace_used_at     date,

  -- Timestamps
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  deleted_at        timestamptz,

  -- Optimistic sync
  sync_version      bigint      NOT NULL DEFAULT 0,
  client_id         text,
  last_sync_at      timestamptz DEFAULT now()
);

COMMENT ON TABLE streaks IS 'Daily study streak tracking; one row per user.';
COMMENT ON COLUMN streaks.freeze_count IS 'Remaining streak freezes granted by premium plan.';


-- ---------------------------------------------------------------------------
-- 3.9  analytics_events
--      High-volume telemetry. Auto-expires after 90 days via pg_cron.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS analytics_events (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           uuid        NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  event_type        text        NOT NULL,               -- e.g. 'lessonStarted', 'boardOpened'
  payload           jsonb,                              -- arbitrary event properties
  session_id        text,
  client_version    text,
  platform          text        CHECK (platform IN ('ios', 'macos', 'android', 'web')),

  -- Retention: row auto-deleted by pg_cron after expires_at
  expires_at        timestamptz NOT NULL
                                DEFAULT (now() + interval '90 days'),

  -- Timestamps (no updated_at — events are immutable)
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),

  -- Sync (client generated, pushed once, never updated)
  sync_version      bigint      NOT NULL DEFAULT 0,
  client_id         text
);

COMMENT ON TABLE analytics_events IS 'Telemetry events. TTL = 90 days; no PII in payload.';
COMMENT ON COLUMN analytics_events.expires_at IS 'pg_cron job deletes rows where expires_at < now() daily.';


-- ---------------------------------------------------------------------------
-- 3.10 sync_queue
--      Server-side mirror of the client offline queue.
--      Used for cross-device conflict detection and audit.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sync_queue (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           uuid        NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  operation         text        NOT NULL
                                CHECK (operation IN ('upsert', 'delete', 'merge')),
  target_table      text        NOT NULL,
  record_id         uuid        NOT NULL,
  payload           jsonb,

  -- Processing state
  status            text        NOT NULL DEFAULT 'pending'
                                CHECK (status IN ('pending', 'processing', 'done', 'failed')),
  retry_count       integer     NOT NULL DEFAULT 0  CHECK (retry_count >= 0),
  max_retries       integer     NOT NULL DEFAULT 5,
  error_message     text,
  processed_at      timestamptz,

  -- Conflict resolution metadata
  client_sync_version bigint,                           -- client's sync_version at time of op
  conflict_detected boolean     NOT NULL DEFAULT false,
  conflict_resolution text,                             -- how conflict was resolved

  -- Timestamps
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),

  -- Sync
  sync_version      bigint      NOT NULL DEFAULT 0,
  client_id         text
);

COMMENT ON TABLE sync_queue IS 'Server-side audit log of all offline-originated write operations.';
COMMENT ON COLUMN sync_queue.client_sync_version IS 'Client sync_version at enqueue time; used for conflict detection.';


-- ---------------------------------------------------------------------------
-- 3.11 subscriptions
--      Subscription plan state. One row per user.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS subscriptions (
  id                        uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                   uuid        NOT NULL REFERENCES users(id) ON DELETE CASCADE
                                        UNIQUE,

  plan                      text        NOT NULL DEFAULT 'free'
                                        CHECK (plan IN ('free', 'premium', 'family')),
  status                    text        NOT NULL DEFAULT 'active'
                                        CHECK (status IN (
                                          'active', 'trial', 'expired',
                                          'cancelled', 'paused', 'grace_period'
                                        )),

  -- Platform billing
  platform                  text        CHECK (platform IN ('ios', 'android', 'web', 'promo')),
  platform_product_id       text,
  platform_subscription_id  text,
  platform_receipt          text,                       -- encrypted receipt for validation

  -- Billing period
  current_period_start      timestamptz,
  current_period_end        timestamptz,
  trial_ends_at             timestamptz,
  cancelled_at              timestamptz,
  grace_period_ends_at      timestamptz,

  -- Family plan
  family_owner_id           uuid        REFERENCES users(id) ON DELETE SET NULL,
  family_seat_limit         integer     NOT NULL DEFAULT 1,

  -- Timestamps
  created_at                timestamptz NOT NULL DEFAULT now(),
  updated_at                timestamptz NOT NULL DEFAULT now(),
  deleted_at                timestamptz,

  -- Optimistic sync
  sync_version              bigint      NOT NULL DEFAULT 0,
  client_id                 text,
  last_sync_at              timestamptz DEFAULT now()
);

COMMENT ON TABLE subscriptions IS 'Subscription / billing state; one row per user.';
COMMENT ON COLUMN subscriptions.platform_receipt IS 'Stored encrypted; validated server-side via StoreKit/Play Billing.';
COMMENT ON COLUMN subscriptions.family_seat_limit IS 'Max members under this family plan (default 1 = solo).';


-- ---------------------------------------------------------------------------
-- 3.12 feature_flags
--      Per-user flag overrides. NULL user_id = global default.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS feature_flags (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           uuid        REFERENCES users(id) ON DELETE CASCADE,  -- NULL = global

  flag_key          text        NOT NULL,
  flag_value        boolean     NOT NULL DEFAULT false,
  rollout_pct       real        CHECK (rollout_pct BETWEEN 0 AND 1),
  notes             text,

  -- TTL for temporary experiments
  expires_at        timestamptz,

  -- Timestamps
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),

  -- Sync
  sync_version      bigint      NOT NULL DEFAULT 0,
  client_id         text,

  UNIQUE (user_id, flag_key)
);

COMMENT ON TABLE feature_flags IS 'Feature flag overrides. user_id=NULL is the global default row.';
COMMENT ON COLUMN feature_flags.rollout_pct IS '0.0–1.0 gradual rollout; evaluated client-side by hashing user_id.';


-- =============================================================================
-- 4. INDEXES
-- =============================================================================

-- ── users ────────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_users_family_owner     ON users(family_owner_id) WHERE family_owner_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_deleted          ON users(deleted_at)      WHERE deleted_at IS NULL;

-- ── student_profiles ─────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_student_profiles_user  ON student_profiles(user_id);

-- ── conversations ─────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_conversations_user     ON conversations(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_conversations_archived ON conversations(archived_at) WHERE archived_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_conversations_live     ON conversations(user_id)     WHERE deleted_at IS NULL AND archived_at IS NULL;

-- ── conversation_messages ─────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_messages_conversation  ON conversation_messages(conversation_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_messages_user          ON conversation_messages(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_live          ON conversation_messages(conversation_id) WHERE deleted_at IS NULL;

-- ── lesson_sessions ───────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_sessions_user_topic    ON lesson_sessions(user_id, topic, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sessions_conversation  ON lesson_sessions(conversation_id) WHERE conversation_id IS NOT NULL;

-- ── memory_items ──────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_memory_user_type       ON memory_items(user_id, memory_type, importance DESC);
CREATE INDEX IF NOT EXISTS idx_memory_expires         ON memory_items(expires_at)    WHERE expires_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_memory_compress        ON memory_items(compressed, user_id) WHERE NOT compressed AND memory_type IN ('short_term','episodic');

-- ── achievements ──────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_achievements_user      ON achievements(user_id, unlocked_at DESC);

-- ── streaks ───────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_streaks_user           ON streaks(user_id);

-- ── analytics_events ─────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_analytics_user_type    ON analytics_events(user_id, event_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_analytics_expires      ON analytics_events(expires_at);  -- for TTL deletion
CREATE INDEX IF NOT EXISTS idx_analytics_session      ON analytics_events(session_id)   WHERE session_id IS NOT NULL;

-- ── sync_queue ────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_sync_queue_user_status ON sync_queue(user_id, status, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_sync_queue_pending     ON sync_queue(status, retry_count) WHERE status IN ('pending','failed');

-- ── subscriptions ─────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_subscriptions_user     ON subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_family   ON subscriptions(family_owner_id) WHERE family_owner_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_subscriptions_expiry   ON subscriptions(current_period_end) WHERE status = 'active';

-- ── feature_flags ─────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_flags_user             ON feature_flags(user_id, flag_key) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_flags_global           ON feature_flags(flag_key)           WHERE user_id IS NULL;
CREATE INDEX IF NOT EXISTS idx_flags_expires          ON feature_flags(expires_at)         WHERE expires_at IS NOT NULL;


-- =============================================================================
-- 5. ROW LEVEL SECURITY
-- =============================================================================

-- Enable RLS on all tables.
ALTER TABLE users                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_profiles       ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations          ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversation_messages  ENABLE ROW LEVEL SECURITY;
ALTER TABLE lesson_sessions        ENABLE ROW LEVEL SECURITY;
ALTER TABLE memory_items           ENABLE ROW LEVEL SECURITY;
ALTER TABLE achievements           ENABLE ROW LEVEL SECURITY;
ALTER TABLE streaks                ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_events       ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_queue             ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions          ENABLE ROW LEVEL SECURITY;
ALTER TABLE feature_flags          ENABLE ROW LEVEL SECURITY;

-- ── users ─────────────────────────────────────────────────────────────────────
-- Users can read/write their own row. Family owners can also read member rows.
CREATE POLICY users_self
  ON users FOR ALL
  USING  (auth.uid() = id);

CREATE POLICY users_family_read
  ON users FOR SELECT
  USING  (family_owner_id = auth.uid());

-- ── student_profiles ──────────────────────────────────────────────────────────
CREATE POLICY student_profiles_self
  ON student_profiles FOR ALL
  USING  (auth.uid() = user_id);

-- ── conversations ─────────────────────────────────────────────────────────────
CREATE POLICY conversations_self
  ON conversations FOR ALL
  USING  (auth.uid() = user_id);

-- ── conversation_messages ─────────────────────────────────────────────────────
CREATE POLICY messages_self
  ON conversation_messages FOR ALL
  USING  (auth.uid() = user_id);

-- ── lesson_sessions ───────────────────────────────────────────────────────────
CREATE POLICY sessions_self
  ON lesson_sessions FOR ALL
  USING  (auth.uid() = user_id);

-- ── memory_items ──────────────────────────────────────────────────────────────
CREATE POLICY memory_self
  ON memory_items FOR ALL
  USING  (auth.uid() = user_id);

-- ── achievements ──────────────────────────────────────────────────────────────
CREATE POLICY achievements_self
  ON achievements FOR ALL
  USING  (auth.uid() = user_id);

-- ── streaks ───────────────────────────────────────────────────────────────────
CREATE POLICY streaks_self
  ON streaks FOR ALL
  USING  (auth.uid() = user_id);

-- ── analytics_events ─────────────────────────────────────────────────────────
-- Users can INSERT their own events; read-only for own events.
CREATE POLICY analytics_insert_self
  ON analytics_events FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY analytics_read_self
  ON analytics_events FOR SELECT
  USING  (auth.uid() = user_id);

-- ── sync_queue ────────────────────────────────────────────────────────────────
CREATE POLICY sync_queue_self
  ON sync_queue FOR ALL
  USING  (auth.uid() = user_id);

-- ── subscriptions ─────────────────────────────────────────────────────────────
-- Users can read their own row. Family members can read the owner's plan.
CREATE POLICY subscriptions_self
  ON subscriptions FOR ALL
  USING  (auth.uid() = user_id);

CREATE POLICY subscriptions_family_read
  ON subscriptions FOR SELECT
  USING  (
    family_owner_id IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND   users.family_owner_id = subscriptions.family_owner_id
    )
  );

-- ── feature_flags ─────────────────────────────────────────────────────────────
-- All users can read global flags (user_id IS NULL) and their own overrides.
CREATE POLICY feature_flags_read
  ON feature_flags FOR SELECT
  USING  (user_id IS NULL OR user_id = auth.uid());

-- Only server-side (service role) can write flags.
CREATE POLICY feature_flags_write_service
  ON feature_flags FOR ALL
  USING  (auth.role() = 'service_role');


-- =============================================================================
-- 6. TRIGGERS
-- =============================================================================

SELECT attach_sync_triggers('users');
SELECT attach_sync_triggers('student_profiles');
SELECT attach_sync_triggers('conversations');
SELECT attach_sync_triggers('conversation_messages');
SELECT attach_sync_triggers('lesson_sessions');
SELECT attach_sync_triggers('memory_items');
SELECT attach_sync_triggers('achievements');
SELECT attach_sync_triggers('streaks');
SELECT attach_sync_triggers('analytics_events');
SELECT attach_sync_triggers('sync_queue');
SELECT attach_sync_triggers('subscriptions');
SELECT attach_sync_triggers('feature_flags');


-- =============================================================================
-- 7. RETENTION / ARCHIVAL JOBS  (requires pg_cron extension)
-- =============================================================================
-- Uncomment after enabling pg_cron in Supabase Dashboard → Database → Extensions.

/*

-- 7.1 Delete expired analytics events daily at 03:00 UTC.
SELECT cron.schedule(
  'expire-analytics',
  '0 3 * * *',
  $$DELETE FROM analytics_events WHERE expires_at < now()$$
);

-- 7.2 Delete expired memory items (short_term TTL = 24h) daily at 03:05 UTC.
SELECT cron.schedule(
  'expire-memory',
  '5 3 * * *',
  $$DELETE FROM memory_items WHERE expires_at IS NOT NULL AND expires_at < now()$$
);

-- 7.3 Archive old conversations (> 90 days, no recent message) daily at 03:10 UTC.
SELECT cron.schedule(
  'archive-conversations',
  '10 3 * * *',
  $$
  UPDATE conversations
  SET    archived_at  = now(),
         archive_tier = 'warm'
  WHERE  archived_at  IS NULL
  AND    deleted_at   IS NULL
  AND    updated_at   < now() - interval '90 days'
  $$
);

-- 7.4 Soft-purge cold-tier conversation messages (> 180 days) weekly.
SELECT cron.schedule(
  'softdelete-cold-messages',
  '0 4 * * 0',
  $$
  UPDATE conversation_messages
  SET    deleted_at = now()
  WHERE  deleted_at IS NULL
  AND    created_at < now() - interval '180 days'
  AND    conversation_id IN (
    SELECT id FROM conversations WHERE archive_tier = 'cold'
  )
  $$
);

-- 7.5 Clean up done/failed sync_queue entries older than 7 days daily.
SELECT cron.schedule(
  'cleanup-sync-queue',
  '15 3 * * *',
  $$
  DELETE FROM sync_queue
  WHERE  status IN ('done', 'failed')
  AND    processed_at < now() - interval '7 days'
  $$
);

-- 7.6 Expire feature_flags past their TTL daily.
SELECT cron.schedule(
  'expire-feature-flags',
  '20 3 * * *',
  $$DELETE FROM feature_flags WHERE expires_at IS NOT NULL AND expires_at < now()$$
);

*/


-- =============================================================================
-- END OF SCHEMA
-- =============================================================================
