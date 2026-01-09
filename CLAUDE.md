# Pantry

Weeknight dinner planning app for iOS. Generates weekly meal plans and learns from user behavior over time.

## Philosophy

- **App owns the plan** — users react, not construct
- **Memory over configuration** — learns from outcomes, not explicit preferences
- **Calm over clever** — no gamification, guilt, or urgency

## Architecture

Monorepo with iOS app (`ios/`) and Bun backend (`backend/`).

**iOS**: SwiftUI + SwiftData + CloudKit. Requires iOS 26.0+ for Foundation Models.

**Backend**: Bun + Hono + SQLite. Uses Vercel AI SDK (gpt-4.1-mini) for draft generation.

**AI Strategy**: Server-side for weekly drafts, on-device Foundation Models for swap suggestions.

## Key Files

- `SPEC.md` — Product specification (source of truth for features)
- `ARCHITECTURE.md` — Technical implementation details
- `backend/src/index.ts` — API entry point
- `backend/src/api/draft.ts` — Draft generation endpoint
- `backend/src/db/` — SQLite schema and client

## Commands

```bash
# Backend
cd backend
bun install          # Install dependencies
bun run dev          # Start dev server (hot reload)
bun run seed         # Generate meals JSON (calls OpenAI)
bun run import       # Import meals JSON to SQLite
bun run validate     # Check meal quality/duplicates
bun test tests/draft.test.ts  # Test draft generation

# iOS
cd ios/pantry
xcodebuild -scheme pantry -destination 'platform=iOS Simulator,name=iPhone 16' -quiet build
xcodebuild -scheme pantry -destination 'platform=iOS Simulator,name=iPhone 16' test
swiftlint lint pantry --quiet          # Requires: brew install swiftlint

# Full iOS validation (build + lint)
./scripts/validate-ios.sh
./scripts/validate-ios.sh --test   # Include tests (slower)
```

## Backend Notes

- Use Bun APIs: `bun:sqlite` (not better-sqlite3), `Bun.serve()` (not express)
- Bun auto-loads `.env` — no dotenv needed
- SQLite stores ~150 curated meals with allergen/prep tags

## API Endpoints

- `GET /api/meals` — Fetch meal database (supports dietary filters)
- `POST /api/draft` — Generate weekly plan from history + constraints

## Deployment

**Backend**: Deployed to Vercel with Bun runtime. SQLite bundled with function (read-only).

- Production: `https://backend-six-silk-34.vercel.app`
- Deploy: `cd backend && bunx vercel --prod`

**iOS API URL**: Configured via `#if DEBUG` in `APIService.swift`

- Debug builds → `localhost:3000`
- Release builds → production Vercel URL

## Git and version control

- Do not ever put "Co-Authored by" in commit messages, PR descriptions, or anywhere else
