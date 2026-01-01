# Pantry - Product Specification v2

## Working Premise

This app helps households assemble a **trustworthy weekly dinner plan** by carrying forward context and outcomes so humans don't have to start from scratch each week.

It does **not** optimize food.
It optimizes **coordination and cognitive load**.

The app replaces humans as the weekly integration layer.

---

## Product Philosophy

- The app owns the plan.
- The user reviews and corrects.
- Memory matters more than configuration.
- Confidence beats variety.
- Silence is a valid interaction.

This is a **support beam**, not a productivity system.

---

## Core UX Principles (Non-Negotiable)

1. **The app owns the plan**
   Users never start from a blank slate. They react, not construct.

2. **Fewer choices beats better choices**
   Survivability > novelty. "Good enough" is a success state.

3. **Memory over configuration**
   The system learns from outcomes, not explicit preferences.

4. **Silence is valid input**
   If the user does nothing, the system should still improve.

5. **Calm over clever**
   No gamification, no guilt, no urgency.

---

## Platform & Technical Requirements

### Platform
- iOS native app (SwiftUI)
- **Minimum iOS 26.0** (Foundation Models hard requirement)
- iPhone only for v1 (iPad runs scaled version)
- iCloud sync via SwiftData + CloudKit
- Single-user for v1 (multi-user deferred)

### Data Architecture
- iCloud-first via SwiftData with CloudKit sync
- Works locally if offline with subtle sync warning indicator
- History kept forever (8-week decay for draft generation relevance)
- All-or-nothing data reset only (no granular deletion)

### App Size
- No size constraints for v1
- Bundle meal database for offline first-launch capability

### Monetization
- No monetization in v1
- Revisit before production launch

### Accessibility
- Standard iOS accessibility: system fonts, Dynamic Type, VoiceOver via standard components

---

## Navigation Structure

**3-tab bottom navigation:**
1. **This Week** - Primary screen showing current/next week draft
2. **History** - Past weeks in reverse chronological order
3. **Settings** - Preferences, dietary restrictions, data management

---

## Screen Inventory (v1)

### 1. First Launch / Onboarding

**Flow:**
1. **iCloud Permission** (if required by system)
2. **Value Proposition Screen**
   - Single sentence: "We help you plan weeknight dinners without starting from scratch every time."
3. **Dietary Restrictions** (optional, skippable)
   - Gluten-free toggle
   - Dairy-free toggle
   - Nut-free toggle
   - These are hard filters: non-compliant meals are excluded from all drafts and suggestions
4. **First Draft Generation**
   - Loading state (2-5 seconds with spinner)
   - Show generated draft

**Defaults:**
- 5 dinners per week (Monday-Friday)
- All dietary toggles OFF unless explicitly set

No tutorials, no gesture onboarding, no lengthy forms.

---

### 2. Weekly Draft (Primary Screen)

**Purpose:**
Present a complete, opinionated weekly plan that can be accepted with minimal effort.

**Structure:**
- One week visible at a time
- Horizontal swipe to navigate between current week and next week
- Monday through Friday by default (expandable to 7 days)
- Minimal visual hierarchy

**Each day card displays:**
- Day label (Monday, Tuesday, etc.)
- Meal name
- Prep risk tag: **Easy** (fast) or **Normal** (normal)
  - Effortful meals exist in database but not shown separately in v1
- **Staple indicator**: Subtle icon (checkmark or star) for meals with proven household survival rate

**Day states:**
- **Planned**: Shows meal with prep tag
- **Cleared**: Shows "Not cooking tonight" state (user explicitly cleared)

**Interactions:**
- **Tap meal** → Opens Swap Sheet
- **Tap cleared day** → Opens Swap Sheet to add meal back

**NOT included:**
- Swipe gestures (all interactions are tap-based)
- Long-press on day cards (only on meals in swap sheet)
- Recipes, ingredients, nutrition, prep steps, timers, checkboxes

**Mid-week behavior:**
- If user opens app Wednesday, draft shows Wed/Thu/Fri (today onwards)
- Past days are not shown in mid-week drafts

---

### 3. Weekly Check-In (Embedded)

**Purpose:**
Capture only what the system cannot reliably infer.

**Placement:**
- Always visible below the weekly draft
- User scrolls to see check-in section
- Framed as corrections, not setup

**Question 1: Scope**
> "Planning for **5 dinners** this week. Change?"

- Quick tap adjustment (1-7 range)
- Default always starts at 5 (Monday-Friday)
- No weekday/weekend distinction - all days treated equally

**Question 2: Disruptions (Week Shape)**
> "What kind of week is it?"

- Options: **Normal** / **Busy** / **Chaotic**
- This replaces per-day busy detection when calendar access is unavailable
- If calendar access granted: individual days shown with busy indicators

**Question 3: Calendar-Based Busy Days** (when calendar access granted)
- Days with 4-8pm events auto-marked as busy
- **Full transparency**: Tapping busy indicator shows actual calendar event names
- User can override system suggestions

**Question 4: Constraints (Optional)**
> "Anything you want to use up?"

- Free text or quick picks:
  - Frozen meals
  - Produce expiring
  - Nothing special
- Keyword matching boosts meals containing mentioned ingredients

No question is required. Unchanged answers generate no signal.

---

### 4. Swap Sheet

**Purpose:**
Allow targeted correction without reopening full planning.

**Trigger:**
- Tap any meal in the weekly draft
- Tap cleared day to add meal

**Content:**
- **3 curated alternatives** (exactly 3, no more)
- **Subtle context hints** beneath each:
  - "Works well on busy days"
  - "Haven't had in 3 weeks"
  - "Household favorite"
- Text field at bottom: "...or type your own"
- **"Not cooking tonight"** option to clear the day

**Ranking factors (handled by Foundation Models):**
- Survivability (high survival rate in household)
- Week balance (no duplicates, effort distribution)
- Day context (busy day = easier options prioritized)

**Custom meal entry:**
- Any free text accepted
- System attempts fuzzy match to database
- If no match: **silently** creates new custom meal
- Custom meals use **AI inference** for prep risk (Foundation Models guesses from name)

**Long-press interaction:**
- Long-press on any meal (in swap sheet or draft) reveals "Hide from future plans"
- **Purely discoverable** - no onboarding or hints for this feature
- Hidden meals never appear in drafts or suggestions (user can still type them manually)

**NOT included:**
- "Show more" or infinite lists
- Explicit "not tonight" vs "not ever" distinction during swap (swaps default to "not tonight")
- Browsing the full meal database

---

### 5. History

**Purpose:**
Build trust by showing that the system remembers outcomes.

**Content:**
- **Simple log**: Week-by-week list showing what was planned
- **Infinite scroll** in reverse chronological order, lazy-loaded
- Read-only
- Shows final plan only (not draft vs. changes)
- Kept forever

**NOT included:**
- Per-meal statistics
- Pattern insights ("Tuesdays are your most swapped day")
- Month grouping or search

---

### 6. Settings

**Contents:**
- **Dietary Preferences**
  - Gluten-free, Dairy-free, Nut-free toggles
  - Editable anytime
  - Per-draft override NOT available in v1

- **Hidden Meals**
  - List of meals user has permanently hidden via long-press
  - Can unhide from this list

- **Data Management**
  - "Reset Everything" - wipes all history and preferences
  - No granular deletion options

- **About / Help**
  - App version
  - Link to support

---

## Draft Generation

### Timing & Triggers

**Automatic generation:**
- Server sends silent push notification Saturday at 3am
- Push wakes the app to generate draft locally
- If push missed (device offline), draft generates on first app open after Saturday 3am
- Draft only auto-generates if one doesn't already exist for the week

**Manual generation:**
- User can tap "+" button anytime to generate draft for current/next week
- Available starting the week prior

**Week boundary:**
- Previous week archives automatically at **midnight Sunday**
- Unviewed drafts get "ghosted" treatment (see below)

### Composition

**60/40 split:**
- **60% staples**: Meals from top ~20 most-kept meals in household (proven survival rate)
- **40% novelty**: Anything not in recent staples (includes never-tried and infrequently-tried meals)

**Cold start behavior (first 4-6 weeks):**
- Lean **80%+ novelty** to rapidly build signal
- Use generic safe defaults filtered by dietary settings
- Accept higher swap rates initially

### Draft Assumptions (v1-Safe)

The auto-generated draft **may** assume:
- Reuse beats novelty (60% staples)
- Busy nights get low-risk meals
- One flex night is acceptable

The draft **must not** assume:
- Desire for complex new recipes
- Experimental meals on busy nights
- Evenly distributed energy
- Rapidly changing preferences

---

## Memory Model

### Meal Outcomes (Critical)

For each meal instance:
- Date
- Outcome:
  - **Kept** (no action taken = assumed kept)
  - **Swapped** (user selected alternative)
  - **Skipped** (user cleared the day)
- Custom entry flag

**Signal processing:**
- 3 consistent swaps → Meal **removed from auto-generated drafts** (still available in swap suggestions)
- **Hard cutoff**: Signals older than 8 weeks ignored completely
- Silent weeks (no app interaction) = "ghosted"

### Ghosted Weeks

When a draft goes untouched through the week:
- Week expires with no recorded outcomes
- **Optimistically assume the draft was kept** for next week's recommendations
- No outcome data stored (we didn't observe actual behavior)

### Repetition Rule

**Do not recommend the same meal in consecutive weeks.**

No complex fatigue modeling. Survivability and recency are the only factors.

---

## Meal Database

### Structure
- LLM-generated, human-curated database
- ~150 meals at launch, grows over time
- Remote-refreshable (syncs with app)

### Categories
- Mexican (tacos, enchiladas, burrito bowls)
- Italian (pasta varieties, pizza, risotto)
- Asian (stir fry, rice bowls, noodles, curry)
- American (burgers, grilled chicken, meatloaf, chili)
- Mediterranean (Greek salads, falafel, kebabs)
- Simple/Quick (sandwiches, eggs, soup)

### Tagging
- Allergen flags: gluten, dairy, nuts
- Batch-friendly flag (not used in v1 for leftovers, but tracked)
- Prep risk: fast, normal, effortful
- Cuisine category
- Keywords for constraint matching

### Database Updates
- **Silent updates** - new meals appear in suggestions without notification
- Weekly sync with draft generation
- Filtered at runtime per user's dietary settings

### Meal Recipe Lookup
- Tap meal name opens **system default browser search**
- Query format: "[meal name] easy weeknight recipe"
- Respects user's default search engine (Safari settings)

---

## Calendar Integration

### Purpose
Detect busy evenings by reading calendar events.

### Logic
- Events between 4-8pm mark day as busy
- Busy days get "Easy" (fast) prep risk meals prioritized

### User visibility
- **Full transparency**: Tapping busy day indicator shows actual calendar event names
- User can override busy status for any day

### Fallback (no calendar access)
- Weekly "What kind of week is it?" prompt (Normal/Busy/Chaotic)
- Applies uniform difficulty adjustment across the week

---

## Export & Sharing

### v1 Scope
- **Share sheet only** (formatted text)
- Calendar event export deferred to v2

### Format
```
This Week's Dinners

Monday: Tacos
Tuesday: Pasta Primavera
Wednesday: Chicken Stir Fry
Thursday: Grilled Salmon
Friday: Burgers
```

### Behavior
- Available via share sheet
- "Export" is a soft signal (internal confidence boost)
- Can paste into iMessage, Notes, etc.

---

## Notifications

### Weekly Nudge
- Single notification: **"Your week is ready"**
- Fixed timing: **Saturday 7am**
- Suppressed if user already opened app since draft was generated
- Not configurable in v1

No other notifications. No nagging. No daily reminders.

---

## Foundation Models (On-Device AI)

### Usage
- **Swap suggestions**: Generate 3 contextual alternatives
- **Fuzzy meal matching**: Match user input to database meals
- **Custom meal prep risk**: Infer prep risk from meal name (e.g., "frozen pizza" = Easy)

### Requirements
- iOS 26.0+ required (hard dependency)
- No fallback for older iOS versions - app won't install

### Context for swap suggestions
- Current meal being swapped
- Day of week and busy status
- Other meals planned this week
- Recent meal history (last 8 weeks)
- Household survival rates

---

## Error Handling

### Network errors (draft generation)
- **Clear error + retry button**: "No connection - tap to retry when back online"
- No offline draft generation fallback
- User can manually retry when connection available

### iCloud sync issues
- Subtle sync warning indicator
- App continues to work locally
- Data syncs when connection restored

---

## Visual Design

### Aesthetic
- **Warm, food-adjacent palette**
- Earthy tones, kitchen-inspired colors
- Muted, low contrast
- Generous spacing
- Fewer UI elements than expected

### Copy
- Neutral, calm tone
- No cheerleading ("Great choice!")
- No guilt language
- No time estimates or urgency

### Interaction
- One tap > two taps
- Defaults are confident
- No confirmation dialogs
- No undo system in v1
- Standard iOS gestures only

---

## What This App Is Not

Explicit non-goals for v1:

- Recipe app
- Grocery list manager
- Nutrition tracker
- Preference configuration system
- Notification engine
- Family profile manager
- Multi-user household app
- Meal database browser
- iPad-optimized app

---

## Success Criteria

The app is succeeding if users say:
- "That was easier than last week."
- "I didn't have to think as much."
- "It kind of just knows us now."

The app is failing if users say:
- "I need to set this up better."
- "I should spend more time with it."
- "It's cool, but I forget to use it."

---

## Key v1 Decisions Summary

| Decision | Choice | Rationale |
|----------|--------|-----------|
| iOS minimum | 26.0+ | Foundation Models required |
| Leftovers feature | Removed for v1 | Simplifies mental model |
| Week shape inference | Removed for v1 | Just use busy days |
| Calendar export | v2 | Share sheet sufficient for v1 |
| Swap gesture | Tap only | No swipe-to-clear, cleaner UX |
| Cold start strategy | Heavy novelty (80%+) | Build signal quickly |
| Ghosted weeks | Assume kept | Keep flywheel spinning |
| Custom meal metadata | Name only | Minimal friction |
| Meal browsing | None | Purely suggestion-driven |
| Signal decay | Hard 8-week cutoff | Simple implementation |
| Dietary filtering | Filter from suggestions | Non-compliant meals excluded from drafts |
| Navigation | 3 tabs | This Week / History / Settings |

---

## Future Considerations (Not v1)

- Multi-user/household support
- Widget for daily glance
- Calendar event export
- Grocery list generation
- Recipe links or partnerships
- Analytics for product learning
- Configurable notification timing
- Undo/redo system
- iPad-optimized layouts
- Leftovers auto-suggestion
- Week shape inference
- Per-meal statistics in history
- Granular data deletion
