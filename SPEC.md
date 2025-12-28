# Pantry - Product Specification v1

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

## Platform & Architecture

### Platform
- iOS native app
- iCloud sync for data persistence
- Single-user for v1 (multi-user deferred to v2)

### Data Architecture
- Cloud-first via iCloud
- Works locally if offline with subtle sync warning indicator
- History kept forever
- Partial reset available (clear history, keep dietary settings)

### Analytics
- Deferred decision for v1
- Build without analytics initially

---

## Screen Inventory (v1)

### 1. First Launch / Empty State

**Purpose**
Establish trust and scope without onboarding ceremony.

**Content**
- Single sentence:
  > "We help you plan weeknight dinners without starting from scratch every time."
- Primary action: **Make a first draft**

**Dietary Question (Optional)**
- Appears after tapping "Make a first draft"
- Skippable - user can proceed without answering
- Common allergies only:
  - Gluten-free
  - Dairy-free
  - Nut-free
- Hard filter: non-compliant meals are completely invisible, never suggested

No tutorials, no preference setup, no long forms, no onboarding for gestures.

---

### 2. Weekly Draft (Primary Screen)

**Purpose**
Present a complete, opinionated weekly plan that can be accepted with minimal effort.

**Structure**
- One week visible at a time
- Horizontal swipe to navigate between current and next week
- Monday through Friday by default (adjustable via check-in)
- Minimal visual hierarchy

**Each day displays**
- Day label
- Meal name (free text)
- Subtle tag:
  - Easy (= fast prep risk)
  - Normal (= normal prep risk)
  - Leftovers (system-suggested based on previous day's batch-friendly meal)
- Confidence indicator shown only for staples (meals that have worked well)

**Navigation**
- Horizontal swipe between current week and next week
- Can view/plan up to one week ahead

**Explicitly excluded**
- Recipes
- Ingredients
- Nutrition
- Prep steps
- Ratings
- Checkboxes
- Timers

**Primary interactions**
- Tap meal → Opens swap sheet
- Swipe day → Clear (shows "not cooking tonight" state)

No long-press distinction. No separate edit screens. No undo/confirmation dialogs.

---

### 3. Weekly Check-In (Embedded)

**Purpose**
Capture only what the system cannot reliably infer.

**Placement**
- Appears _below_ the weekly draft
- Framed as corrections, not setup

**Question 1: Scope**
> "Planning for **5 dinners** this week. Change?"

- Quick tap adjustment (5 = weeknights, can increase for weekends)
- Default always starts at 5 (Monday-Friday)
- Boundary condition, not planning

**Question 2: Disruptions**
> "We assumed this week is mostly normal. Anything unusually busy?"

- Days pre-filled by system guess
- Calendar integration: events between 4-8pm mark day as busy
- Historical patterns as secondary signal
- Calendar wins when conflicting with history
- User only corrects mismatches
- Binary states only: normal / busy
- Unchanged answers generate no signal (only explicit changes recorded)

**Question 3: Constraints (Optional)**
> "Anything you want to use up?"

- Free text or quick picks:
  - Frozen meals
  - Leftovers
  - Produce expiring
  - Nothing special
- Keyword matching: input like "chicken" boosts meals containing that ingredient

No question is required.

---

### 4. Swap Sheet

**Purpose**
Allow targeted correction without reopening planning.

**Trigger**
- Tap any meal in the weekly draft

**Content**
- Shows 3–5 alternatives
- Text field at bottom: "...or type your own"
- Alternatives ranked by:
  - Survivability (high survival rate)
  - Week balance (no duplicates, effort distribution)
  - Day context (busy day = easier options prioritized)
- Includes one safe fallback (emergent from data: high survival rate across busy weeks)

**Behavior**
- Short list is final (no "show more")
- Custom entry: any free text accepted
- System attempts fuzzy match to database; creates new custom meal if no match

No browsing. No discovery. No infinite lists.

---

### 5. History

**Purpose**
Build trust by showing that the system remembers outcomes.

**Content**
- Past weeks, collapsed
- Expandable to see full week
- Read-only
- Shows final plan only (not draft vs. changes)
- Kept forever

Answers:
> "Does this app remember our life?"

---

## Minimum Memory Model (v1)

The system remembers **outcomes**, not intentions.

### 1. Meal Entity

- Name (free text)
- Prep risk category (inferred from meal name via NLP/heuristics):
  - fast (Easy)
  - normal (Normal)
  - effortful
- Allergen tags (from database)
- Batch-friendly flag (generates leftovers)

No recipes, ingredients, or nutrition data.

---

### 2. Meal Outcomes (Critical)

For each meal instance:
- Date
- Outcome (inferred from silence):
  - Kept (no action taken = assumed kept)
  - Swapped (user selected alternative)
  - Skipped (user cleared the day)
- Custom entry flag (not from database)

**Signal Processing**
- 3 consistent signals to shift confidence on a meal
- Signals decay after ~8 weeks
- Signal tolerance is configurable
- Silent weeks (no app interaction) are skipped in history entirely

---

### 3. Week Shape (Inferred)

Each week classified internally as:
- normal
- busy
- chaotic
- travel-light

Derived from overrides, swaps, and failures.

---

### 4. Repetition Rule

Simple rule: **Do not recommend the same meal in consecutive weeks.**

No complex fatigue modeling. Survivability and recency are the only factors.

---

## Draft Generation

### Timing
- Auto-generated Saturday morning (before 7am) if user hasn't created one
- User can manually generate draft anytime via + button
- Draft is always for current week
- Mid-week drafts show remaining nights only (smart detection)

### Composition
- **60% staples**: meals with proven survival rate in this household
- **40% novelty**: variations on familiar meals or new suggestions
  - "Novelty" includes variations (salmon rice bowl → shrimp rice bowl)
  - Variations are not tracked with relationship to parent meal
  - Each meal tracked independently

### Draft Assumptions (v1-Safe)

The auto-generated draft may assume:
- Reuse beats novelty (60% staples)
- Busy nights get low-risk meals
- Leftovers are intentional when previous day had batch-friendly meal
- One flex night is acceptable

The draft must **not** assume:
- Desire for complex new recipes
- Experimental meals on busy nights
- Evenly distributed energy
- Rapidly changing preferences

---

## Meal Database

### Structure
- LLM-generated, human-curated database
- Start with ~150 meals, grow over time
- Focus on common American weeknight meals including:
  - Mexican (tacos, enchiladas)
  - Italian (pasta, pizza)
  - Chinese/Asian (stir fry, rice bowls)
  - American (burgers, chili, grilled salmon)

### Tagging
- Allergen tags (gluten, dairy, nuts) on all meals
- Batch-friendly flag for leftover-generating meals
- Prep risk inferred from meal name

### Updates
- Remote-refreshable (not baked into app bundle)
- Syncs weekly with draft generation (Saturday morning)
- Global database filtered at runtime per user's dietary settings

### Meal Context
- Each meal shows prep tag (Easy/Normal/Effortful)
- Meal name tappable to open web search (Google, or AI search if available)
- No in-app recipes or detailed descriptions

---

## Notifications

### Weekly Nudge
- Single notification: "Your week is ready"
- Fixed timing: Saturday 7am
- Suppressed if user already opened app since draft was generated
- Not configurable in v1

No other notifications. No nagging. No daily reminders.

---

## Export & Sharing

### Purpose
- Signal that plan is "locked in" for the week
- Share with other household members

### Format
- Formatted message (styled text, looks nice in iMessage/Notes)
- Example:
  ```
  This Week's Dinners

  Monday: Tacos
  Tuesday: Pasta Primavera
  Wednesday: Chicken Stir Fry
  Thursday: Leftovers
  Friday: Grilled Salmon
  ```

### Behavior
- Export is a soft signal (increases confidence in plan but doesn't hard-lock)
- Available via share sheet
- v2: Calendar export, widget display

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

Adding these too early reintroduces ritual.

---

## Why This Is Better Than ChatGPT

ChatGPT is great at ideas, but it's weak at:

- Remembering your rotation without you re-explaining it
- Keeping plans stable when you make one change ("swap Tuesday" shouldn't reshuffle the week)
- Making repeatable, low-friction weekly workflows
- Tracking outcomes and learning from them

A purpose-built app beats it by being **deterministic, fast, and consistent**.

---

## Copy, Visual, and Interaction Rules

### Copy
- Neutral, calm tone
- No cheerleading
- No guilt language
- No time estimates or urgency

### Visual
- **Unique but calm** aesthetic
- Muted palette
- Low contrast
- Generous spacing
- Fewer UI elements than expected

### Interaction
- One tap > two taps
- Defaults are confident
- No confirmation dialogs
- No undo system in v1
- Standard iOS gestures (trust discoverability)

---

## Success Criteria (UX-Level)

The app is succeeding if users say:

- "That was easier than last week."
- "I didn't have to think as much."
- "It kind of just knows us now."
- "Easier than doing this in ChatGPT."

The app is failing if users say:

- "I need to set this up better."
- "I should spend more time with it."
- "It's cool, but I forget to use it."
- "I could do this same thing with ChatGPT."

---

## Mental Model to Protect

This app is a **quiet weekly decision that closes a mental loop**.

Not a planner.
Not a coach.
Not a tracker.

---

## Technical Implementation Notes

### Cold Start
- First draft uses generic safe defaults (pasta, tacos, etc.)
- Filtered by dietary settings if provided
- No seed meal collection required

### Confidence Scoring
- Based on survival rate (kept vs. swapped/skipped)
- Day-appropriate: busy day survival weighted more heavily
- Staples visually indicated; other confidence scores internal only

### Calendar Integration
- Read device calendar
- Events between 4-8pm mark day as busy
- Calendar signal overrides historical patterns when conflicting

### iCloud Sync
- Primary data store
- Graceful offline: app works locally with subtle sync warning
- No complex conflict resolution in v1

### Leftovers Logic
- Meals tagged "batch-friendly" in database
- System suggests "Leftovers" for day after batch-friendly meal
- "Leftovers" = generic "eat what's there" (not tracking specific leftover meals)

### Valid Edge States
- Empty week (all days cleared) is valid
- System learns from this pattern
- User can have 0 meals planned

---

## Future Considerations (Not v1)

- Multi-user/household support
- Widget for daily glance
- Calendar event export
- Grocery list generation
- Recipe links or partnerships
- Analytics for product learning
- Configurable notification timing
- Undo/redo system if needed
