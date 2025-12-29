# Pantry - Architecture v1

## Overview

Pantry is a dinner planning app that helps households assemble trustworthy weekly plans by carrying forward context and outcomes. This document defines the technical architecture for implementation.

### Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| iOS Framework | SwiftUI | Native iCloud/CloudKit sync, Foundation Models API |
| Backend Runtime | Bun + TypeScript | Fast, TypeScript-native, Vercel AI compatible |
| AI Strategy | Hybrid | Server for draft generation, on-device for swaps |
| Meal Database | SQLite | Lightweight, perfect for ~150 meals |
| User Data | iCloud/CloudKit | Privacy-first, offline-capable, no auth needed |
| Deployment | Vercel Functions | Zero-ops, integrates with `ai` package |

### System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    iOS App (SwiftUI)                        │
│                                                             │
│  ┌─────────────────┐          ┌─────────────────────────┐  │
│  │   SwiftData     │          │   Foundation Models     │  │
│  │   + CloudKit    │          │   (On-Device LLM)       │  │
│  └────────┬────────┘          └────────────┬────────────┘  │
│           │                                │               │
│      User Data                        Quick AI             │
│   (plans, outcomes,               (swap suggestions,       │
│    preferences)                    meal matching)          │
└───────────┬────────────────────────────────┬───────────────┘
            │                                │
            │ iCloud Sync                    │ On-device only
            │ (automatic)                    │
            │                                │
┌───────────┴────────────────────────────────┴───────────────┐
│                 Bun + TypeScript Backend                    │
│                                                             │
│  ┌─────────────────┐          ┌─────────────────────────┐  │
│  │     SQLite      │          │      Vercel AI          │  │
│  │  (Meal Database)│          │   (Draft Generation)    │  │
│  └─────────────────┘          └─────────────────────────┘  │
│                                                             │
│  Endpoints:                                                 │
│  • GET  /api/meals  - Fetch meal database                  │
│  • POST /api/draft  - Generate weekly draft                │
└─────────────────────────────────────────────────────────────┘
```

---

## Monorepo Structure

```
pantry/
├── README.md
├── SPEC.md                    # Product specification
├── ARCHITECTURE.md            # This file
│
├── ios/                       # SwiftUI iOS app
│   ├── Pantry.xcodeproj
│   ├── Pantry/
│   │   ├── PantryApp.swift
│   │   ├── Models/
│   │   │   ├── Meal.swift
│   │   │   ├── WeeklyPlan.swift
│   │   │   ├── PlannedMeal.swift
│   │   │   ├── MealOutcome.swift
│   │   │   └── UserPreferences.swift
│   │   ├── Views/
│   │   │   ├── WeeklyDraftView.swift
│   │   │   ├── SwapSheetView.swift
│   │   │   ├── CheckInView.swift
│   │   │   ├── HistoryView.swift
│   │   │   └── OnboardingView.swift
│   │   ├── Services/
│   │   │   ├── CloudKitService.swift
│   │   │   ├── FoundationModelsService.swift
│   │   │   ├── APIService.swift
│   │   │   ├── CalendarService.swift
│   │   │   └── NotificationService.swift
│   │   ├── ViewModels/
│   │   │   └── WeeklyPlanViewModel.swift
│   │   └── Resources/
│   │       └── Assets.xcassets
│   └── PantryTests/
│
├── backend/                   # Bun + TypeScript API
│   ├── package.json
│   ├── tsconfig.json
│   ├── bun.lock
│   ├── src/
│   │   ├── index.ts           # Entry point, Hono server
│   │   ├── api/
│   │   │   ├── meals.ts       # GET /api/meals
│   │   │   └── draft.ts       # POST /api/draft
│   │   ├── db/
│   │   │   ├── schema.sql
│   │   │   ├── client.ts      # SQLite client
│   │   │   └── seed.ts        # Seed script
│   │   ├── ai/
│   │   │   └── draft-generator.ts
│   │   └── types/
│   │       └── index.ts
│   ├── data/
│   │   └── meals.db           # SQLite database file
│   └── tests/
│
└── shared/
    └── meals-seed.json        # Initial meal data (LLM-generated, human-curated)
```

---

## iOS App Architecture

### SwiftData Models

All user data persists via SwiftData with automatic CloudKit sync.

```swift
// Models/Meal.swift
@Model
class Meal {
    var id: UUID
    var name: String
    var prepRisk: PrepRisk        // .fast, .normal, .effortful
    var batchFriendly: Bool
    var containsGluten: Bool
    var containsDairy: Bool
    var containsNuts: Bool
    var isCustom: Bool            // User-created meal
    var createdAt: Date

    enum PrepRisk: String, Codable {
        case fast       // "Easy" in UI
        case normal     // "Normal" in UI
        case effortful  // Not shown in v1
    }
}

// Models/WeeklyPlan.swift
@Model
class WeeklyPlan {
    var id: UUID
    var weekStartDate: Date       // Monday of the week
    var plannedMeals: [PlannedMeal]
    var weekShape: WeekShape      // Inferred from outcomes
    var createdAt: Date
    var exported: Bool            // Soft signal of commitment

    enum WeekShape: String, Codable {
        case normal
        case busy
        case chaotic
        case travelLight
    }
}

// Models/PlannedMeal.swift
@Model
class PlannedMeal {
    var id: UUID
    var meal: Meal?               // nil if "Leftovers" or skipped
    var dayOfWeek: Int            // 1=Monday, 5=Friday, etc.
    var isLeftovers: Bool
    var isSkipped: Bool           // User cleared this day
    var outcome: MealOutcome?
}

// Models/MealOutcome.swift
@Model
class MealOutcome {
    var id: UUID
    var plannedMeal: PlannedMeal
    var outcome: Outcome
    var recordedAt: Date

    enum Outcome: String, Codable {
        case kept                 // No action taken (silence = kept)
        case swapped              // User selected alternative
        case skipped              // User cleared the day
    }
}

// Models/UserPreferences.swift
@Model
class UserPreferences {
    var id: UUID
    var glutenFree: Bool
    var dairyFree: Bool
    var nutFree: Bool
    var defaultDinnerCount: Int   // Default: 5 (Mon-Fri)
    var hasCompletedOnboarding: Bool
}
```

### CloudKit Configuration

SwiftData syncs automatically with CloudKit when configured correctly.

**Requirements**:
1. Enable iCloud capability in Xcode
2. Enable CloudKit in Signing & Capabilities
3. Create CloudKit container: `iCloud.com.yourteam.pantry`
4. Use `ModelConfiguration` with CloudKit sync enabled

```swift
// PantryApp.swift
@main
struct PantryApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            Meal.self,
            WeeklyPlan.self,
            PlannedMeal.self,
            MealOutcome.self,
            UserPreferences.self
        ], inMemory: false, isAutosaveEnabled: true, isUndoEnabled: false)
    }
}
```

**CloudKit Constraints** (important):
- No `@Attribute(.unique)` - CloudKit doesn't support unique constraints
- Relationships must be optional
- All properties must be Codable

### Foundation Models Integration

On-device AI for quick interactions (swap suggestions, meal fuzzy matching).

```swift
// Services/FoundationModelsService.swift
import FoundationModels

@available(iOS 26.0, *)
class FoundationModelsService {
    private let session: LanguageModelSession

    init() async throws {
        // Request model with appropriate guardrails
        let config = LanguageModelSession.Configuration(
            instructions: """
            You are a meal planning assistant. Given a list of meals and context,
            suggest alternatives that match the user's patterns.
            """
        )
        self.session = try await LanguageModelSession(configuration: config)
    }

    // Generate swap suggestions for a given meal
    func suggestSwaps(
        for meal: Meal,
        context: SwapContext,
        availableMeals: [Meal]
    ) async throws -> [Meal] {
        let prompt = buildSwapPrompt(meal: meal, context: context, meals: availableMeals)
        let response = try await session.respond(to: prompt)
        return parseSwapResponse(response, from: availableMeals)
    }

    // Fuzzy match user input to database meals
    func matchMeal(userInput: String, availableMeals: [Meal]) async throws -> Meal? {
        // Use Foundation Models for semantic matching
        // Falls back to string similarity if no match
    }
}

struct SwapContext {
    let dayOfWeek: Int
    let isBusyDay: Bool
    let otherMealsThisWeek: [Meal]
    let recentMealHistory: [Meal]
}
```

**Fallback**: If Foundation Models unavailable (older iOS), use simple heuristics:
- Filter by prep risk for busy days
- Avoid duplicates in same week
- Prioritize high-survival-rate meals

### Calendar Integration (EventKit)

Detect busy days by reading calendar events between 4-8pm.

```swift
// Services/CalendarService.swift
import EventKit

class CalendarService {
    private let store = EKEventStore()

    func requestAccess() async -> Bool {
        return await withCheckedContinuation { continuation in
            store.requestAccess(to: .event) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    func busyDays(for week: Date) -> [Int] {
        guard let weekStart = week.startOfWeek else { return [] }
        var busyDays: [Int] = []

        for dayOffset in 0..<7 {
            let day = Calendar.current.date(byAdding: .day, value: dayOffset, to: weekStart)!
            if hasBusyEvening(on: day) {
                busyDays.append(dayOffset + 1) // 1-indexed (Mon=1)
            }
        }
        return busyDays
    }

    private func hasBusyEvening(on date: Date) -> Bool {
        let start = Calendar.current.date(bySettingHour: 16, minute: 0, second: 0, of: date)!
        let end = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: date)!

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate)

        // Consider busy if any event exists in 4-8pm window
        return !events.isEmpty
    }
}
```

### Notification Scheduling

Single weekly notification: "Your week is ready" on Saturday 7am.

```swift
// Services/NotificationService.swift
import UserNotifications

class NotificationService {
    func scheduleWeeklyReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Your week is ready"
        content.body = "Your dinner plan for next week is waiting."
        content.sound = .default

        // Saturday at 7am
        var dateComponents = DateComponents()
        dateComponents.weekday = 7  // Saturday
        dateComponents.hour = 7
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: "weekly-reminder",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    func cancelIfAppOpened() {
        // Remove pending notification if user already opened app
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["weekly-reminder"])
    }
}
```

### API Service

Communicates with Bun backend for meal database sync and draft generation.

```swift
// Services/APIService.swift
import Foundation

class APIService {
    private let baseURL = URL(string: "https://api.pantry.app")!

    // Fetch meal database (weekly sync)
    func fetchMeals(
        since: Date? = nil,
        dietaryFilters: DietaryFilters
    ) async throws -> [Meal] {
        var components = URLComponents(url: baseURL.appendingPathComponent("/api/meals"), resolvingAgainstBaseURL: false)!

        var queryItems: [URLQueryItem] = []
        if let since = since {
            queryItems.append(URLQueryItem(name: "since", value: ISO8601DateFormatter().string(from: since)))
        }
        if dietaryFilters.glutenFree {
            queryItems.append(URLQueryItem(name: "gluten_free", value: "true"))
        }
        if dietaryFilters.dairyFree {
            queryItems.append(URLQueryItem(name: "dairy_free", value: "true"))
        }
        if dietaryFilters.nutFree {
            queryItems.append(URLQueryItem(name: "nut_free", value: "true"))
        }
        components.queryItems = queryItems

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let response = try JSONDecoder().decode(MealsResponse.self, from: data)
        return response.meals.map { $0.toMeal() }
    }

    // Request draft generation from server
    func generateDraft(request: DraftRequest) async throws -> DraftResponse {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("/api/draft"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, _) = try await URLSession.shared.data(for: urlRequest)
        return try JSONDecoder().decode(DraftResponse.self, from: data)
    }
}

struct DietaryFilters {
    let glutenFree: Bool
    let dairyFree: Bool
    let nutFree: Bool
}

struct DraftRequest: Codable {
    let dinnerCount: Int
    let busyDays: [Int]
    let constraints: String?          // "chicken", "frozen meals", etc.
    let mealHistory: [MealHistoryItem]
    let dietaryFilters: DietaryFilters
}

struct MealHistoryItem: Codable {
    let mealName: String
    let outcome: String
    let weeksAgo: Int
}

struct DraftResponse: Codable {
    let meals: [DraftMeal]
}

struct DraftMeal: Codable {
    let dayOfWeek: Int
    let mealId: String?
    let mealName: String
    let isLeftovers: Bool
    let reasoning: String?           // Why this meal was chosen (internal)
}
```

---

## Backend Architecture

### Tech Stack

- **Runtime**: Bun
- **Framework**: Hono (lightweight, fast, TypeScript-native)
- **Database**: SQLite via `bun:sqlite`
- **AI**: Vercel AI SDK (`ai` package)
- **Deployment**: Vercel Functions

### Package Setup

```json
// backend/package.json
{
  "name": "pantry-backend",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "bun run --hot src/index.ts",
    "build": "bun build src/index.ts --outdir dist --target bun",
    "seed": "bun run src/db/seed.ts",
    "test": "bun test"
  },
  "dependencies": {
    "hono": "^4.0.0",
    "ai": "^3.0.0",
    "@ai-sdk/anthropic": "^0.0.0"
  },
  "devDependencies": {
    "@types/bun": "latest",
    "typescript": "^5.0.0"
  }
}
```

### SQLite Schema

```sql
-- backend/src/db/schema.sql

CREATE TABLE IF NOT EXISTS meals (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    prep_risk TEXT NOT NULL CHECK (prep_risk IN ('fast', 'normal', 'effortful')),
    batch_friendly INTEGER NOT NULL DEFAULT 0,
    contains_gluten INTEGER NOT NULL DEFAULT 0,
    contains_dairy INTEGER NOT NULL DEFAULT 0,
    contains_nuts INTEGER NOT NULL DEFAULT 0,
    cuisine TEXT,                              -- 'mexican', 'italian', 'asian', 'american'
    keywords TEXT,                             -- JSON array for search: ["chicken", "quick"]
    curation_status TEXT DEFAULT 'published',  -- 'draft', 'published', 'deprecated'
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_meals_updated ON meals(updated_at);
CREATE INDEX idx_meals_prep_risk ON meals(prep_risk);
CREATE INDEX idx_meals_curation ON meals(curation_status);
```

### Database Client

```typescript
// backend/src/db/client.ts
import { Database } from "bun:sqlite";
import { join } from "path";

const db = new Database(join(import.meta.dir, "../../data/meals.db"));

export interface DBMeal {
  id: string;
  name: string;
  prep_risk: "fast" | "normal" | "effortful";
  batch_friendly: number;
  contains_gluten: number;
  contains_dairy: number;
  contains_nuts: number;
  cuisine: string | null;
  keywords: string | null;
  curation_status: string;
  created_at: string;
  updated_at: string;
}

export function getMeals(filters: {
  since?: string;
  glutenFree?: boolean;
  dairyFree?: boolean;
  nutFree?: boolean;
}): DBMeal[] {
  let query = `SELECT * FROM meals WHERE curation_status = 'published'`;
  const params: any[] = [];

  if (filters.glutenFree) {
    query += ` AND contains_gluten = 0`;
  }
  if (filters.dairyFree) {
    query += ` AND contains_dairy = 0`;
  }
  if (filters.nutFree) {
    query += ` AND contains_nuts = 0`;
  }
  if (filters.since) {
    query += ` AND updated_at > ?`;
    params.push(filters.since);
  }

  query += ` ORDER BY updated_at DESC`;

  return db.prepare(query).all(...params) as DBMeal[];
}

export function getMealById(id: string): DBMeal | null {
  return db.prepare(`SELECT * FROM meals WHERE id = ?`).get(id) as DBMeal | null;
}

export function getMealsByIds(ids: string[]): DBMeal[] {
  const placeholders = ids.map(() => "?").join(",");
  return db
    .prepare(`SELECT * FROM meals WHERE id IN (${placeholders})`)
    .all(...ids) as DBMeal[];
}
```

### API Routes

```typescript
// backend/src/index.ts
import { Hono } from "hono";
import { cors } from "hono/cors";
import { mealsRoute } from "./api/meals";
import { draftRoute } from "./api/draft";

const app = new Hono();

app.use("/*", cors());

app.route("/api/meals", mealsRoute);
app.route("/api/draft", draftRoute);

app.get("/health", (c) => c.json({ status: "ok" }));

export default app;
```

```typescript
// backend/src/api/meals.ts
import { Hono } from "hono";
import { getMeals } from "../db/client";
import type { Meal } from "../types";

export const mealsRoute = new Hono();

mealsRoute.get("/", (c) => {
  const since = c.req.query("since");
  const glutenFree = c.req.query("gluten_free") === "true";
  const dairyFree = c.req.query("dairy_free") === "true";
  const nutFree = c.req.query("nut_free") === "true";

  const dbMeals = getMeals({ since, glutenFree, dairyFree, nutFree });

  const meals: Meal[] = dbMeals.map((m) => ({
    id: m.id,
    name: m.name,
    prepRisk: m.prep_risk,
    batchFriendly: m.batch_friendly === 1,
    containsGluten: m.contains_gluten === 1,
    containsDairy: m.contains_dairy === 1,
    containsNuts: m.contains_nuts === 1,
    cuisine: m.cuisine,
    keywords: m.keywords ? JSON.parse(m.keywords) : [],
  }));

  return c.json({
    version: new Date().toISOString(),
    meals,
    count: meals.length,
  });
});
```

```typescript
// backend/src/api/draft.ts
import { Hono } from "hono";
import { generateDraft } from "../ai/draft-generator";
import type { DraftRequest, DraftResponse } from "../types";

export const draftRoute = new Hono();

draftRoute.post("/", async (c) => {
  const request = await c.req.json<DraftRequest>();

  const draft = await generateDraft(request);

  return c.json<DraftResponse>(draft);
});
```

### AI Draft Generation

```typescript
// backend/src/ai/draft-generator.ts
import { generateObject } from "ai";
import { anthropic } from "@ai-sdk/anthropic";
import { z } from "zod";
import { getMeals, getMealsByIds } from "../db/client";
import type { DraftRequest, DraftResponse, DraftMeal } from "../types";

const DraftSchema = z.object({
  meals: z.array(
    z.object({
      dayOfWeek: z.number().min(1).max(7),
      mealId: z.string().nullable(),
      mealName: z.string(),
      isLeftovers: z.boolean(),
      reasoning: z.string(),
    })
  ),
});

export async function generateDraft(request: DraftRequest): Promise<DraftResponse> {
  // Fetch available meals with dietary filters applied
  const availableMeals = getMeals({
    glutenFree: request.dietaryFilters.glutenFree,
    dairyFree: request.dietaryFilters.dairyFree,
    nutFree: request.dietaryFilters.nutFree,
  });

  // Build context for the LLM
  const mealList = availableMeals
    .map((m) => `- ${m.name} (${m.prep_risk}, ${m.batch_friendly ? "batch-friendly" : "single"})`)
    .join("\n");

  const historyContext = request.mealHistory
    .map((h) => `- ${h.mealName}: ${h.outcome} (${h.weeksAgo} weeks ago)`)
    .join("\n");

  const busyDaysContext = request.busyDays.length > 0
    ? `Busy days (prefer easy meals): ${request.busyDays.map(d => dayName(d)).join(", ")}`
    : "No particularly busy days this week.";

  const prompt = `
You are a meal planning assistant for a household. Generate a dinner plan for ${request.dinnerCount} nights.

## Available Meals
${mealList}

## Recent History
${historyContext || "No recent history."}

## This Week's Context
${busyDaysContext}
${request.constraints ? `User mentioned: "${request.constraints}"` : ""}

## Rules
1. 60% should be "staple" meals (meals that were kept in history, not swapped)
2. 40% can be new or varied meals
3. Busy days should get "fast" prep risk meals
4. If a batch-friendly meal is used, consider suggesting "Leftovers" for the next day
5. Never repeat the same meal in one week
6. Avoid meals that were swapped/skipped recently

Generate a plan for days 1-${request.dinnerCount} (Monday=1, Sunday=7).
`;

  const { object } = await generateObject({
    model: anthropic("claude-sonnet-4-20250514"),
    schema: DraftSchema,
    prompt,
  });

  // Validate meal IDs exist and enrich response
  const draftMeals: DraftMeal[] = object.meals.map((m) => {
    const dbMeal = m.mealId ? availableMeals.find((am) => am.id === m.mealId) : null;
    return {
      dayOfWeek: m.dayOfWeek,
      mealId: dbMeal?.id ?? null,
      mealName: dbMeal?.name ?? m.mealName,
      isLeftovers: m.isLeftovers,
      reasoning: m.reasoning,
    };
  });

  return { meals: draftMeals };
}

function dayName(day: number): string {
  const days = ["", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
  return days[day] || "";
}
```

### Shared Types

```typescript
// backend/src/types/index.ts

export interface Meal {
  id: string;
  name: string;
  prepRisk: "fast" | "normal" | "effortful";
  batchFriendly: boolean;
  containsGluten: boolean;
  containsDairy: boolean;
  containsNuts: boolean;
  cuisine: string | null;
  keywords: string[];
}

export interface DietaryFilters {
  glutenFree: boolean;
  dairyFree: boolean;
  nutFree: boolean;
}

export interface MealHistoryItem {
  mealName: string;
  outcome: "kept" | "swapped" | "skipped";
  weeksAgo: number;
}

export interface DraftRequest {
  dinnerCount: number;
  busyDays: number[];
  constraints: string | null;
  mealHistory: MealHistoryItem[];
  dietaryFilters: DietaryFilters;
}

export interface DraftMeal {
  dayOfWeek: number;
  mealId: string | null;
  mealName: string;
  isLeftovers: boolean;
  reasoning: string | null;
}

export interface DraftResponse {
  meals: DraftMeal[];
}

export interface MealsResponse {
  version: string;
  meals: Meal[];
  count: number;
}
```

---

## Data Flows

### 1. Weekly Draft Generation (Hybrid AI)

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  iOS App    │────▶│   Backend   │────▶│  Vercel AI  │
│             │     │             │     │  (Claude)   │
└─────────────┘     └─────────────┘     └─────────────┘
       │                   │                   │
       │ DraftRequest      │ getMeals()        │ generateObject()
       │ (history,         │ (filtered by      │ (60% staples,
       │  busy days,       │  dietary prefs)   │  40% novelty)
       │  constraints)     │                   │
       │                   ▼                   │
       │            ┌─────────────┐            │
       │            │   SQLite    │            │
       │            │  (150 meals)│            │
       │            └─────────────┘            │
       │                                       │
       ◀───────────────────────────────────────┘
              DraftResponse (7 meals)
```

**Trigger**: Saturday morning (automatic) or user-initiated

### 2. Swap Suggestions (On-Device)

```
┌─────────────┐     ┌─────────────────────┐
│  iOS App    │────▶│  Foundation Models  │
│  (SwapSheet)│     │    (On-Device)      │
└─────────────┘     └─────────────────────┘
       │                      │
       │ SwapContext          │ 3-5 alternatives
       │ (meal, day,          │ (ranked by:
       │  week balance)       │  - survival rate
       │                      │  - day context
       │                      │  - week balance)
       ◀──────────────────────┘

No network required. Works offline.
```

### 3. Meal Database Sync

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  iOS App    │────▶│   Backend   │────▶│   SQLite    │
│  (weekly)   │     │             │     │             │
└─────────────┘     └─────────────┘     └─────────────┘
       │                   │                   │
       │ GET /api/meals    │                   │
       │ ?since=<date>     │                   │
       │ &gluten_free=true │                   │
       │                   │                   │
       ◀───────────────────┴───────────────────┘
              MealsResponse (incremental)
       │
       ▼
┌─────────────┐
│ Local Cache │  (Persisted for offline)
│  (CoreData) │
└─────────────┘
```

**Sync timing**: Saturday morning before draft generation, or on-demand.

### 4. User Data Persistence (iCloud)

```
┌─────────────┐                    ┌─────────────┐
│  iOS App    │◀──────────────────▶│   iCloud    │
│ (SwiftData) │    Automatic       │  (CloudKit) │
└─────────────┘      Sync          └─────────────┘
       │
       │ Stores:
       │ • WeeklyPlan
       │ • PlannedMeal
       │ • MealOutcome
       │ • UserPreferences
       │ • Custom Meals
       │
       │ Never touches backend server.
```

---

## Type Synchronization (Swift ↔ TypeScript)

Types are maintained manually. Keep these files in sync:

| Swift | TypeScript |
|-------|------------|
| `ios/Pantry/Models/Meal.swift` | `backend/src/types/index.ts` |
| `ios/Pantry/Services/APIService.swift` | `backend/src/types/index.ts` |

**Sync checklist when changing types**:
1. Update Swift model
2. Update TypeScript type
3. Update API request/response structs in both
4. Test with actual API call

---

## Deployment

### Backend (Vercel)

```bash
# Deploy to Vercel
cd backend
vercel deploy --prod
```

**Environment Variables**:
- `ANTHROPIC_API_KEY` - For Vercel AI SDK

**Vercel Configuration**:
```json
// backend/vercel.json
{
  "builds": [
    {
      "src": "src/index.ts",
      "use": "@vercel/bun"
    }
  ],
  "routes": [
    {
      "src": "/(.*)",
      "dest": "src/index.ts"
    }
  ]
}
```

### iOS App (App Store)

Standard Xcode archive → App Store Connect workflow.

**Required Capabilities**:
- iCloud (CloudKit)
- Background Modes (Background fetch)
- Push Notifications (local only)

### Meal Database Updates

Weekly curation workflow:
1. Review/add meals in `shared/meals-seed.json`
2. Run `bun run seed` to update SQLite
3. Deploy backend (`vercel deploy --prod`)
4. iOS clients fetch updated meals on next sync

---

## Implementation Order

1. **Backend: SQLite schema + seed data**
   - Create schema.sql
   - Create initial 150 meals in meals-seed.json
   - Implement seed script

2. **Backend: Bun server with `/api/meals`**
   - Set up Hono
   - Implement meals endpoint with filtering
   - Deploy to Vercel

3. **iOS: Xcode project + SwiftData models**
   - Create project structure
   - Implement data models
   - Set up model container

4. **iOS: CloudKit configuration**
   - Enable capabilities
   - Test sync between devices

5. **iOS: Basic UI (weekly draft screen)**
   - WeeklyDraftView
   - Day cards with meal display

6. **Backend: Vercel AI draft generation**
   - Implement `/api/draft` endpoint
   - Test with various inputs

7. **iOS: API integration + meal sync**
   - APIService implementation
   - Local meal cache
   - Weekly sync logic

8. **iOS: Foundation Models for swap suggestions**
   - FoundationModelsService
   - SwapSheet with alternatives

9. **iOS: Calendar + notifications**
   - CalendarService for busy day detection
   - NotificationService for Saturday reminder

10. **Integration testing**
    - End-to-end draft generation flow
    - Offline behavior
    - iCloud sync across devices

---

## Appendix: Initial Meal Categories

For the initial 150-meal database, target this distribution:

| Category | Count | Examples |
|----------|-------|----------|
| Mexican | 20 | Tacos, enchiladas, burrito bowls, quesadillas |
| Italian | 25 | Pasta varieties, pizza, risotto, chicken parm |
| Asian | 25 | Stir fry, rice bowls, noodles, curry |
| American | 30 | Burgers, grilled chicken, meatloaf, chili |
| Mediterranean | 15 | Greek salads, falafel, kebabs, hummus bowls |
| Simple/Quick | 25 | Sandwiches, eggs, soup, frozen meal upgrades |
| Batch-Friendly | 10 | Casseroles, big-batch chili, lasagna |

Each meal should be tagged with:
- `prep_risk`: fast (< 20 min), normal (20-40 min), effortful (> 40 min)
- Allergen flags: gluten, dairy, nuts
- `batch_friendly`: generates leftovers
- `cuisine`: category for variety tracking
- `keywords`: ingredient hints for constraint matching
