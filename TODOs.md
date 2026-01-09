# Pantry - Implementation Roadmap

## Current Status

### Backend (MVP Complete)

- [x] SQLite database with 150 curated meals
- [x] GET /api/meals endpoint with dietary filters
- [x] POST /api/draft endpoint with GPT-4.1-mini
- [x] Seed → Import → Validate data pipeline
- [x] Unit tests for prompt building

### iOS (Core Features Complete - 75%)

- [x] 3-tab navigation (This Week, History, Settings)
- [x] SwiftData container with CloudKit configured
- [x] Background fetch enabled in Info.plist
- [x] SwiftData models (5 models implemented)
- [x] Services (APIService, FoundationModelsService, ServiceErrors)
- [x] Core UI (ThisWeekView, SwapSheetView, CheckInView, DayCardView)

---

## Workstreams

### A. SwiftData Models ✅

`ios/pantry/pantry/Models/*.swift`

- [x] `Meal.swift` - id, name, prepRisk enum, allergen flags, isCustom, createdAt
- [x] `UserPreferences.swift` - dietary toggles, defaultDinnerCount, hasCompletedOnboarding
- [x] `WeeklyPlan.swift` - weekStartDate, weekShape enum, plannedMeals, exported flag
- [x] `PlannedMeal.swift` - meal reference, dayOfWeek, isSkipped, outcome
- [x] `MealOutcome.swift` - outcome enum (kept/swapped/skipped), recordedAt
- [x] Register all models in pantryApp.swift schema

### B. API Integration ✅

`ios/pantry/pantry/Services/APIService.swift`

- [x] Create APIService class with configurable baseURL
- [x] Implement `fetchMeals(dietaryFilters:)` → GET /api/meals
- [x] Implement `generateDraft(request:)` → POST /api/draft
- [x] Define Codable structs matching backend types
- [x] Add custom error types (network, decode, server)
- [x] Cache fetched meals in SwiftData

### C. Weekly Draft View (Primary Screen) ✅

`ios/pantry/pantry/Views/ThisWeekView.swift`, `ViewModels/WeeklyPlanViewModel.swift`

- [x] Create WeeklyPlanViewModel with @Observable
- [x] Build DayCardView component (meal name, prep tag, staple indicator)
- [x] Implement 5-day vertical scroll (Mon-Fri default)
- [x] Add loading state during draft generation
- [x] Horizontal swipe for current/next week
- [x] Mid-week behavior: show today onwards only
- [x] "Cleared" day state ("Not cooking tonight")

### D. Swap Sheet ✅

`ios/pantry/pantry/Views/SwapSheetView.swift`

- [x] Modal sheet triggered by tapping meal card
- [x] Display exactly 3 curated alternatives
- [x] Show context hints ("Works well on busy days", etc.)
- [x] "Not cooking tonight" clear option
- [x] Free text field for custom meal entry
- [x] Long-press to hide meal from future plans
- [x] Wire selection to update WeeklyPlan

### E. Check-In Section ✅

`ios/pantry/pantry/Views/CheckInView.swift`

- [x] Scrollable section below weekly draft
- [x] Dinner count picker (1-7, default 5)
- [x] Week shape selector (Normal/Busy/Chaotic)
- [x] Optional "Anything to use up?" text field
- [x] Connect answers to draft regeneration

### F. Foundation Models (On-Device AI) ✅

`ios/pantry/pantry/Services/FoundationModelsService.swift`

- [x] FoundationModelsService with iOS 26.0+ requirement
- [x] `suggestSwaps(for:context:availableMeals:)` → 3 alternatives
- [x] `matchMeal(userInput:availableMeals:)` → fuzzy matching
- [x] SwapContext struct (day, busy status, week meals, history)
- [x] Fallback heuristics when FM unavailable

### G. History View

`ios/pantry/pantry/Views/HistoryView.swift`

- [ ] Query WeeklyPlans in reverse chronological order
- [ ] Week-by-week list with final meals
- [ ] Lazy loading / infinite scroll
- [ ] Read-only (no editing)

### H. Settings View

`ios/pantry/pantry/Views/SettingsView.swift`

- [ ] Dietary toggles (gluten-free, dairy-free, nut-free)
- [ ] Hidden meals list with unhide option
- [ ] "Reset Everything" with confirmation
- [ ] About section (app version, support link)

### I. Onboarding Flow

`ios/pantry/pantry/Views/OnboardingView.swift`

- [ ] Value proposition screen (single sentence)
- [ ] Optional dietary restrictions (skippable)
- [ ] Trigger first draft generation
- [ ] Loading state during generation
- [ ] Set hasCompletedOnboarding flag
- [ ] Skip if already completed

### J. Calendar Integration

`ios/pantry/pantry/Services/CalendarService.swift`

- [ ] Request EventKit access
- [ ] Detect busy days (events 4-8pm)
- [ ] Return busy day indices for week
- [ ] Handle permission denied

### K. Notifications

`ios/pantry/pantry/Services/NotificationService.swift`

- [ ] Request notification permission
- [ ] Schedule weekly reminder (Saturday 7am)
- [ ] Cancel if user opens app post-draft

---

## UI Enhancements (Future)

---

## Parallelization Strategy

### Phase 1: Foundation ✅

~~Complete Workstream A first - all other work depends on SwiftData models.~~

### Phase 2: Core Features ✅

~~Services (API + Foundation Models), Primary UI (Weekly Draft View), Interactions (Swap Sheet + Check-In)~~

### Phase 3: Secondary Features (2 Parallel Agents)

| Agent | Workstreams | Focus                                                      |
| ----- | ----------- | ---------------------------------------------------------- |
| 1     | G + H       | Supporting Views (History + Settings)                      |
| 2     | I + J + K   | System Integration (Onboarding + Calendar + Notifications) |

---

## Files Created / Remaining

```
ios/pantry/pantry/
├── Models/                          ✅ Complete
│   ├── Meal.swift                   ✅
│   ├── WeeklyPlan.swift             ✅
│   ├── PlannedMeal.swift            ✅
│   ├── MealOutcome.swift            ✅
│   └── UserPreferences.swift        ✅
├── Services/
│   ├── APIService.swift             ✅
│   ├── FoundationModelsService.swift ✅
│   ├── ServiceErrors.swift          ✅
│   ├── CalendarService.swift        ☐ TODO
│   └── NotificationService.swift    ☐ TODO
├── ViewModels/
│   └── WeeklyPlanViewModel.swift    ✅
└── Views/
    ├── ThisWeekView.swift           ✅
    ├── DayCardView.swift            ✅
    ├── DragPreviewCard.swift        ✅
    ├── SwapSheetView.swift          ✅
    ├── CheckInView.swift            ✅
    ├── HistoryView.swift            ☐ TODO (stub)
    ├── SettingsView.swift           ☐ TODO (stub)
    └── OnboardingView.swift         ☐ TODO (stub)
```
