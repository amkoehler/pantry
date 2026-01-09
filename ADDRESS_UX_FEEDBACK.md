# UX Adjustments Implementation Plan

Based on testing feedback, these adjustments refine the draft interaction experience.

---

## Summary

8 UX changes grouped into 4 independent increments. Each increment can be shipped separately.

---

## Increment 1: Check-In Simplification (Low Risk)

### 1.1 Remove "Planning for N dinners" input

**Files:**
- `ios/pantry/pantry/Views/CheckInView.swift` - Delete `DinnerCountSection` struct and its usage
- `ios/pantry/pantry/ViewModels/WeeklyPlanViewModel.swift` - Always use `dinnerCount: 5`

**Changes:**
- Remove lines 50-84 (DinnerCountSection)
- Remove DinnerCountSection from CheckInView body
- Keep `WeeklyPlan.dinnerCount` for internal use, always default to 5

### 1.2 Bug fix: Constraints unchanged submission

**Files:**
- `ios/pantry/pantry/Views/CheckInView.swift`

**Changes:**
- In `ConstraintsSection`, track `lastSubmittedValue` state
- Only call `onSubmit()` if value differs from last submitted

```swift
@State private var lastSubmittedValue: String = ""

.onSubmit {
    let normalizedNew = localText.trimmingCharacters(in: .whitespaces)
    if normalizedNew != lastSubmittedValue {
        constraints = normalizedNew.isEmpty ? nil : normalizedNew
        lastSubmittedValue = normalizedNew
        onSubmit()
    }
}
.onAppear {
    localText = constraints ?? ""
    lastSubmittedValue = constraints ?? ""
}
```

### 1.3 Loading feedback for check-in changes

**Files:**
- `ios/pantry/pantry/Views/ThisWeekView.swift`

**Changes:**
- Pass `viewModel.isGeneratingDraft` to `WeekPageView`
- Add loading overlay on day cards when `isLoading == true`:

```swift
DayCardView(...)
    .overlay {
        if isLoading {
            RoundedRectangle(cornerRadius: PantryTheme.Radius.card)
                .fill(.ultraThinMaterial)
                .overlay { ProgressView() }
        }
    }
```

**Testing:**
- CheckInView no longer shows dinner count selector
- Submit unchanged constraints does NOT trigger regeneration
- Loading overlay appears during regeneration

---

## Increment 2: Past Days Display (iOS + Backend)

### 2.1 Show past days (disabled, non-interactive)

**Rationale:** Currently mid-week (e.g., Thursday) hides M-W entirely. Users want to see what was planned for context, but those days should be non-interactive.

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
- Disable tap: `if !isPastDay { onTap() }`
- Apply `.opacity(isPastDay ? 0.5 : 1.0)`
- Disable drag: `.draggable(meal, disabled: isPastDay)`

### 2.2 Mid-week regeneration preserves past days

**Rationale:** When regenerating on Thursday, past days (M-W) should not change. Only request new meals for today onwards.

**Backend files:**
- `backend/src/types/index.ts` - Add `startFromDay?: number` to DraftRequest
- `backend/src/api/draft.ts` - Pass through to generator
- `backend/src/ai/draft-generator.ts` - Adjust prompt to generate days `startFromDay` through end

**iOS files:**
- `ios/pantry/pantry/Services/APIService.swift` - Add `startFromDay` to request struct
- `ios/pantry/pantry/ViewModels/WeeklyPlanViewModel.swift` - Calculate startFromDay in `regenerateDraft(for:)`

**ViewModel regeneration changes:**
```swift
func regenerateDraft(for plan: WeeklyPlan) async {
    let today = currentDayOfWeek()
    let startFromDay = max(today, 1)  // At minimum, Monday
    let remainingDays = max(0, 6 - today)  // Days left M-F
    guard remainingDays > 0 else { return }  // Weekend: nothing to do

    // Delete only future meals
    if let existingMeals = plan.plannedMeals {
        for meal in existingMeals where meal.dayOfWeek >= startFromDay {
            modelContext.delete(meal)
        }
    }

    let request = APIService.buildDraftRequest(
        dinnerCount: remainingDays,
        startFromDay: startFromDay,
        // ... rest
    )
    // ... API call creates meals only for today onwards
}
```

**Testing:**
- Thursday: M-W visible but grayed/disabled, only Thu-Fri interactive
- Regenerating on Wednesday preserves Mon/Tue meals
- API with `startFromDay: 3` returns Wed-Fri only

---

## Increment 3: Weekend Days

### 3.1 Add weekend placeholder cards with "+" buttons

**Rationale:** Default is M-F, but users should be able to optionally plan Sat/Sun meals via individual "+" buttons.

**Files:**
- `ios/pantry/pantry/Views/DayCardView.swift` - New `WeekendPlaceholderCard` component
- `ios/pantry/pantry/Views/ThisWeekView.swift` - Add placeholders after weekday cards
- `ios/pantry/pantry/ViewModels/WeeklyPlanViewModel.swift` - Add `addWeekendMeal(for:dayOfWeek:)`

**WeekendPlaceholderCard:**
```swift
struct WeekendPlaceholderCard: View {
    let dayOfWeek: Int  // 6=Saturday, 7=Sunday
    let onAdd: () -> Void

    var body: some View {
        Button(action: onAdd) {
            VStack(spacing: 8) {
                Text(WeeklyPlanViewModel.dayName(for: dayOfWeek))
                    .font(PantryTheme.Typography.subheadline)
                    .foregroundStyle(PantryTheme.Colors.tertiaryText)
                Image(systemName: "plus.circle")
                    .font(.system(size: 24))
                    .foregroundStyle(PantryTheme.Colors.tertiaryText)
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(PantryTheme.Colors.cardBackground.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: PantryTheme.Radius.card))
            .overlay {
                RoundedRectangle(cornerRadius: PantryTheme.Radius.card)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [8, 4]))
                    .foregroundStyle(PantryTheme.Colors.tertiaryText.opacity(0.5))
            }
        }
        .buttonStyle(.plain)
    }
}
```

**Behavior:** Tapping "+" opens SwapSheetView in "add mode" (no current meal), letting user pick from suggestions.

**Testing:**
- Weekend cards appear below Friday
- Tapping "+" opens meal selection
- Once added, converts to regular DayCardView

---

## Increment 4: Data & Display Enhancements

### 4.1 Pre-cache swap alternatives

**Rationale:** Currently every swap sheet open shows a loading spinner while Foundation Models generates alternatives. Pre-loading when the plan loads provides instant feedback.

**Files:**
- `ios/pantry/pantry/ViewModels/WeeklyPlanViewModel.swift`
- `ios/pantry/pantry/Views/SwapSheetView.swift`

**ViewModel additions:**
```swift
private var cachedSuggestions: [UUID: [MealSuggestion]] = [:]

func loadPlans() async {
    // ... existing loading
    if let plan = currentWeekPlan {
        await preCacheSuggestions(for: plan)
    }
}

private func preCacheSuggestions(for plan: WeeklyPlan) async {
    guard let meals = plan.plannedMeals else { return }
    for plannedMeal in meals {
        // Generate suggestions via Foundation Models
        // Store in cachedSuggestions[plannedMeal.id]
    }
}

func getCachedSuggestions(for plannedMeal: PlannedMeal) -> [MealSuggestion]? {
    cachedSuggestions[plannedMeal.id]
}
```

**SwapSheetView changes:**
- Accept `cachedSuggestions: [MealSuggestion]?` parameter
- In `loadSuggestions()`, use cache if available, skip loading spinner

### 4.2 One-Pot/One-Pan badges instead of prefixes

**Rationale:** Current meal titles have "One-Pot:" or "One-Pan:" prefixes baked in. This is visual noise. Show as badges instead, alongside "Easy".

**Files:**
- `backend/meals_seed_v1_3.json` - Remove "One-Pot:" and "One-Pan:" prefixes from titles
- `backend/scripts/import-meals.ts` - Optional: strip prefixes during import
- `ios/pantry/pantry/Services/APIService.swift` - Add `onePotOrPan` to APIMeal
- `ios/pantry/pantry/Models/Meal.swift` - Add `onePotOrPan: String` property
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

---

## Recommended Implementation Order

1. **Increment 1** - Check-in simplification (smallest, lowest risk, iOS only)
2. **Increment 3** - Weekend days (self-contained, iOS only)
3. **Increment 4** - Pre-caching + badges (no blocking dependencies)
4. **Increment 2** - Past days + mid-week regen (requires backend change, most complex)

---

## Verification Plan

After each increment:
1. Run iOS simulator and manually test the changed flows
2. For backend changes: `bun test tests/draft.test.ts`
3. For data changes: `bun run import && bun run validate`

End-to-end test after all increments:
1. Fresh install (no data)
2. Generate first draft - see M-F with weekend placeholders
3. Mid-week: verify past days shown but disabled
4. Change week shape - verify loading feedback
5. Open swap sheet - verify instant load from cache
6. Add weekend meal via "+" button
7. Verify One-Pot/One-Pan badges display correctly

---

## SPEC.md Updates (Post-Implementation)

After implementation, update these sections in SPEC.md:

**Section "2. Weekly Draft (Primary Screen)" > "Mid-week behavior":**
- Change from "Past days are not shown" to "Past days are shown but visually disabled (grayed out, non-interactive)"

**Section "3. Weekly Check-In (Embedded)" > "Question 1: Scope":**
- Remove this question entirely (dinners count is always 5)

**Section "2. Weekly Draft" > Add new subsection "Weekend days":**
- "Saturday and Sunday are not planned by default. Users can add individual weekend meals via a '+' button on placeholder cards."
