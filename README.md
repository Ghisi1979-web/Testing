silentdrop

Overview
- React Native (Expo) + Supabase (Postgres, Auth, Storage, Realtime)
- EU region, RLS enabled, DSGVO features
- SAFE_MODE_FOR_REVIEW flag hides explicit content for store review

Getting Started
1. Prerequisites: Node 18+, pnpm or npm, Expo CLI, Supabase CLI
2. Copy .env.example to .env and fill Supabase keys
3. Supabase: run schema and functions
   - supabase start (local) or use hosted project
   - Apply SQL: supabase db reset or run schema.sql
4. App: install and run
   - cd apps/expo && pnpm install && pnpm start

Environment Variables (.env)
- SUPABASE_URL=
- SUPABASE_ANON_KEY=
- SUPABASE_SERVICE_ROLE_KEY=
- REGION=eu
- SAFE_MODE_FOR_REVIEW=true
- EXPLICIT_FEATURE_FLAG=true
- ALLOWED_COUNTRIES_EXPLICIT=DE,AT,CH

Structure
- apps/expo: Expo client
- supabase/schema.sql: Tables, RLS, buckets
- supabase/functions: Edge Functions (Deno TS)

Scripts
- pnpm -w install: install all
- pnpm -w build: typecheck/build functions and app

Notes
- Buckets: media_soft, media_explicit (private). Access via signed URLs and policies
- RLS strictly enforced across core tables

# Testing
Silentdropq
