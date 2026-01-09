# UX Adjustments Implementation Plan

Based on testing feedback, these adjustments refine the draft interaction experience.

---

## Summary

6 UX changes grouped into 3 independent increments. Each increment can be shipped separately.

---

## Increment 1: Check-In Simplification (Low Risk)

### 1.1 Remove "Planning for N dinners" input

**Decision:** Always use 5 dinners. Simplicity wins over flexibility. Users who cook fewer nights can skip/swap days.

**Files:**

- `ios/pantry/pantry/Views/CheckInView.swift` - Delete `DinnerCountSection` struct and its usage
- `ios/pantry/pantry/ViewModels/WeeklyPlanViewModel.swift` - Always use `dinnerCount: 5`

**Changes:**

- Remove lines 50-84 (DinnerCountSection)
- Remove DinnerCountSection from CheckInView body
- Keep `WeeklyPlan.dinnerCount` for internal use, always default to 5

### 1.2 Explicit "Update Plan" button for constraints

**Decision:** Replace auto-submit-on-Return with explicit sticky footer button. Button appears when ANY check-in field differs from last-applied values. Partial updates allowed.

**Files:**

- `ios/pantry/pantry/Views/CheckInView.swift`

**Changes:**

- Remove `.onSubmit` handler from constraints field
- Add sticky footer with "Update Plan" button
- Track dirty state: compare current field values vs. last-applied values
- Button visible only when dirty state is true
- On tap: apply all current values, trigger regeneration, reset dirty state

```swift
@State private var lastAppliedConstraints: String = ""
@State private var lastAppliedStuffToUseUp: String = ""

var hasUnappliedChanges: Bool {
    localConstraints != lastAppliedConstraints ||
    localStuffToUseUp != lastAppliedStuffToUseUp
}

// Sticky footer at bottom of check-in section
if hasUnappliedChanges {
    Button("Update Plan") {
        constraints = localConstraints.isEmpty ? nil : localConstraints
        stuffToUseUp = localStuffToUseUp.isEmpty ? nil : localStuffToUseUp
        lastAppliedConstraints = localConstraints
        lastAppliedStuffToUseUp = localStuffToUseUp
        onSubmit()
    }
    .buttonStyle(.borderedProminent)
}
```

### 1.3 Food-themed loading spinner for draft regeneration

**Decision:** When regeneration starts, check-in section collapses to minimal bar. Full-screen food-themed spinner displays with rotating cooking verb messages. Main draft regeneration only (not swap suggestions).

**Files:**

- `ios/pantry/pantry/Views/ThisWeekView.swift`
- New: `ios/pantry/pantry/Views/Components/CookingSpinner.swift`

**Loading Messages (rotate every 2-3 seconds):**

1. Sautéing...
2. Simmering...
3. Toasting...
4. Chopping...
5. Whisking...
6. Seasoning...

**Changes:**

- Create `CookingSpinner` component with animated message rotation
- When `viewModel.isGeneratingDraft == true`:
  - Collapse check-in section to thin bar showing "Updating..."
  - Show full-screen `CookingSpinner` over the cards area
- When generation completes, restore normal view

```swift
struct CookingSpinner: View {
    @State private var currentMessage = 0
    let messages = ["Sautéing...", "Simmering...", "Toasting...", "Chopping...", "Whisking...", "Seasoning..."]

    let timer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text(messages[currentMessage])
                .font(PantryTheme.Typography.headline)
                .foregroundStyle(PantryTheme.Colors.secondaryText)
                .animation(.easeInOut, value: currentMessage)
        }
        .onReceive(timer) { _ in
            currentMessage = (currentMessage + 1) % messages.count
        }
    }
}
```

**Error Handling:** If regeneration fails (network error, timeout), show error toast and preserve existing meals. User can retry via check-in.

**Testing:**

- CheckInView no longer shows dinner count selector
- "Update Plan" button appears only when fields have changed
- Tapping "Update Plan" collapses check-in and shows cooking spinner
- Error shows toast, preserves existing meals

---

## Increment 2: Past Days Display (iOS + Backend)

### 2.1 Show past days (disabled, non-interactive)

**Rationale:** Currently mid-week (e.g., Thursday) hides M-W entirely. Users want to see what was planned for context, but those days should be non-interactive.

**Decision:** Past days shown with outline-only card style (no fill). Display original planned meal with full info including badges. Non-interactive (no tap, no drag).

**Files:**

- `ios/pantry/pantry/ViewModels/WeeklyPlanViewModel.swift`
- `ios/pantry/pantry/Views/DayCardView.swift`
- `ios/pantry/pantry/Views/ThisWeekView.swift`

**ViewModel changes (lines 62-77):**

```swift
var currentWeekFilteredMeals: [PlannedMeal] {
    guard let plan = currentWeekPlan,
          let meals = plan.plannedMeals else { return [] }
    // Show all weekdays M-F, no longer filtering past days
    return meals
        .filter { $0.dayOfWeek <= 5 }
        .sorted { $0.dayOfWeek < $1.dayOfWeek }
}

func isPastDay(_ dayOfWeek: Int) -> Bool {
    return dayOfWeek < currentDayOfWeek()
}
```

**DayCardView changes:**

- Add `isPastDay: Bool` parameter
- Past day card style: outline-only (no background fill), solid border
- Keep full content: meal title, prep time, all badges (Easy, One-Pot/Pan)
- Disable tap: `if !isPastDay { onTap() }`
- Disable drag: `.draggable(meal, disabled: isPastDay)`

```swift
// Past day card style
.background(isPastDay ? Color.clear : PantryTheme.Colors.cardBackground)
.overlay {
    if isPastDay {
        RoundedRectangle(cornerRadius: PantryTheme.Radius.card)
            .strokeBorder(PantryTheme.Colors.tertiaryText.opacity(0.3), lineWidth: 1)
    }
}
```

**Week boundary behavior:** Starting Saturday, show next week's plan (drafts generated overnight via 7am notification). User never sees a "week complete" state.

### 2.2 Mid-week regeneration preserves past days

**Rationale:** When regenerating on Thursday, past days (M-W) should not change. Only request new meals for today onwards.

**Decision:** Change API from `startFromDay: number` to `days: number[]` for flexibility. Examples:

- Full week: `[1, 2, 3, 4, 5]`
- Mid-week (Thursday): `[4, 5]`
- Single day: `[3]`

**Backend files:**

- `backend/src/types/index.ts` - Change `startFromDay?: number` to `days?: number[]` in DraftRequest
- `backend/src/api/draft.ts` - Pass through to generator
- `backend/src/ai/draft-generator.ts` - Adjust prompt to generate only requested days

**iOS files:**

- `ios/pantry/pantry/Services/APIService.swift` - Change `startFromDay` to `days` array in request struct
- `ios/pantry/pantry/ViewModels/WeeklyPlanViewModel.swift` - Calculate days array in `regenerateDraft(for:)`

**ViewModel regeneration changes:**

```swift
func regenerateDraft(for plan: WeeklyPlan) async {
    let today = currentDayOfWeek()
    guard today <= 5 else { return }  // Weekend: show next week instead

    // Build array of days to regenerate (today through Friday)
    let daysToGenerate = Array(today...5)

    // Delete only future meals
    if let existingMeals = plan.plannedMeals {
        for meal in existingMeals where meal.dayOfWeek >= today {
            modelContext.delete(meal)
        }
    }

    let request = APIService.buildDraftRequest(
        days: daysToGenerate,
        // ... rest
    )
    // ... API call creates meals only for requested days
}
```

**Testing:**

- Thursday: M-W visible as outline cards, only Thu-Fri interactive
- Regenerating on Wednesday preserves Mon/Tue meals
- API with `days: [3, 4, 5]` returns Wed-Fri only
- Saturday/Sunday: shows next week's plan

---

## Increment 3: Pre-Cache Swap Alternatives

### 3.1 Pre-cache swap alternatives on plan load

**Rationale:** Currently every swap sheet open shows a loading spinner while Foundation Models generates alternatives. Pre-loading when the plan loads provides instant feedback.

**Decision:** Pre-cache all 5 meals on plan load. Acceptable battery/thermal tradeoff for instant UX. If user opens swap sheet before cache completes, show loading spinner (fallback to current behavior).

**Files:**

- `ios/pantry/pantry/ViewModels/WeeklyPlanViewModel.swift`
- `ios/pantry/pantry/Views/SwapSheetView.swift`

**ViewModel additions:**

```swift
private var cachedSuggestions: [UUID: [MealSuggestion]] = [:]
private var cacheLoadingTasks: [UUID: Task<Void, Never>] = [:]

func loadPlans() async {
    // ... existing loading
    if let plan = currentWeekPlan {
        await preCacheSuggestions(for: plan)
    }
}

private func preCacheSuggestions(for plan: WeeklyPlan) async {
    guard let meals = plan.plannedMeals else { return }

    // Launch parallel cache tasks for all meals
    for plannedMeal in meals {
        cacheLoadingTasks[plannedMeal.id] = Task {
            let suggestions = await generateSuggestions(for: plannedMeal)
            cachedSuggestions[plannedMeal.id] = suggestions
        }
    }
}

func getCachedSuggestions(for plannedMeal: PlannedMeal) -> [MealSuggestion]? {
    cachedSuggestions[plannedMeal.id]
}

func isCacheLoading(for plannedMeal: PlannedMeal) -> Bool {
    cacheLoadingTasks[plannedMeal.id]?.isCancelled == false
}
```

**SwapSheetView changes:**

- Accept `cachedSuggestions: [MealSuggestion]?` parameter
- In `loadSuggestions()`, use cache if available, skip loading spinner
- If cache miss, show standard loading spinner while generating

```swift
func loadSuggestions() async {
    if let cached = viewModel.getCachedSuggestions(for: plannedMeal) {
        suggestions = cached
        return
    }

    // Fall back to loading with spinner
    isLoading = true
    suggestions = await viewModel.generateSuggestions(for: plannedMeal)
    isLoading = false
}
```

### 3.2 One-Pot/One-Pan badges instead of prefixes

**Rationale:** Current meal titles have "One-Pot:" or "One-Pan:" prefixes baked in. This is visual noise. Show as badges instead, alongside "Easy".

**Note:** Dietary badges (Vegetarian, GF, etc.) deferred to future iteration - data model not ready.

**Files:**

- `backend/meals_seed_v1_3.json` - Remove "One-Pot:" and "One-Pan:" prefixes from titles
- `backend/scripts/import-meals.ts` - Optional: strip prefixes during import
- `ios/pantry/pantry/Services/APIService.swift` - Add `onePotOrPan` to APIMeal
- `ios/pantry/pantry/Models/Meal.swift` - Add `onePotOrPan: String?` property
- `ios/pantry/pantry/Views/DayCardView.swift` - Show badge below title

**DayCardView badge display:**

```swift
VStack(alignment: .leading, spacing: 4) {
    Text(meal.title)
        .font(PantryTheme.Typography.title)

    HStack(spacing: 6) {
        if meal.prepRisk == .fast {
            PrepBadge(label: "Easy")
        }
        if meal.onePotOrPan == "one-pot" {
            PrepBadge(label: "One-Pot")
        } else if meal.onePotOrPan == "one-pan" {
            PrepBadge(label: "One-Pan")
        }
    }
}
```

**Testing:**

- Run `bun run import` after updating seed data
- Badges display correctly in day cards
- SwapSheetView also shows badges
- Swap sheet opens instantly when cache is ready
- Swap sheet shows spinner briefly on cache miss

---

## Recommended Implementation Order

1. **Increment 1** - Check-in simplification (smallest, lowest risk, iOS only)
2. **Increment 2** - Past days + mid-week regen (requires backend change for `days` array)
3. **Increment 3** - Pre-caching + badges (no blocking dependencies)

---

## Verification Plan

After each increment:

1. Run iOS simulator and manually test the changed flows
2. For backend changes: `bun test tests/draft.test.ts`
3. For data changes: `bun run import && bun run validate`

End-to-end test after all increments:

1. Fresh install (no data)
2. Generate first draft - see M-F meals
3. Mid-week: verify past days shown as outline cards but disabled
4. Change constraints - verify "Update Plan" button appears
5. Tap "Update Plan" - verify cooking spinner with rotating messages
6. Open swap sheet - verify instant load from cache
7. Verify One-Pot/One-Pan badges display correctly
8. On Saturday: verify next week's plan is shown

---

## SPEC.md Updates (Post-Implementation)

After implementation, update these sections in SPEC.md:

**Section "2. Weekly Draft (Primary Screen)" > "Mid-week behavior":**

- Change from "Past days are not shown" to "Past days are shown with outline card style (non-interactive). Full meal info displayed including badges."

**Section "3. Weekly Check-In (Embedded)" > "Question 1: Scope":**

- Remove this question entirely (dinners count is always 5)

**Section "3. Weekly Check-In (Embedded)" > "Submission":**

- Change from auto-submit to explicit "Update Plan" button in sticky footer

**Section "2. Weekly Draft" > Add "Loading state":**

- "When regenerating, check-in collapses to minimal bar. Full-screen cooking spinner displays with rotating messages (Sautéing, Simmering, Toasting, Chopping, Whisking, Seasoning)."

---

## Decisions Log

Documented from implementation planning interview:

| Topic                  | Decision                      | Rationale                                 |
| ---------------------- | ----------------------------- | ----------------------------------------- |
| Dinner count           | Always 5                      | Simplicity wins; users can skip days      |
| Constraint submission  | Explicit "Update Plan" button | Prevents accidental regeneration          |
| Update button location | Sticky footer                 | Appears when any field has changes        |
| Loading UX             | Food-themed spinner           | Whimsical, on-brand for "calm" philosophy |
| Loading messages       | Cooking verbs only            | Purely whimsical, not contextual          |
| Check-in during load   | Collapse to minimal           | Give full screen to spinner               |
| Past day data          | Original plan only            | No outcome tracking needed                |
| Past day style         | Outline-only card             | Distinct from filled active cards         |
| Past day badges        | Full info displayed           | Consistency, just visually muted          |
| API for days           | `days: number[]` array        | Flexible: `[1,2,3,4,5]`, `[4,5]`, etc.    |
| Weekend support        | Removed                       | Doesn't fit core M-F use case             |
| Week boundary          | Saturday shows next week      | Drafts generated overnight                |
| Pre-cache scope        | All 5 meals                   | Acceptable device impact for instant UX   |
| Cache miss UX          | Show loading spinner          | Fallback to current behavior              |
| Badge scope            | Easy + One-Pot/Pan only       | Dietary badges deferred (data not ready)  |
| Error handling         | Toast + preserve meals        | Non-destructive failure mode              |
