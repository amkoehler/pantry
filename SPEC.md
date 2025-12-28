## Working Premise

This app helps households assemble a **trustworthy weekly dinner plan** by carrying forward context and outcomes so humans don’t have to start from scratch each week.

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
   Survivability > novelty. “Good enough” is a success state.

3. **Memory over configuration**  
   The system learns from outcomes, not explicit preferences.

4. **Silence is valid input**  
   If the user does nothing, the system should still improve.

5. **Calm over clever**  
   No gamification, no guilt, no urgency.

---

## Screen Inventory (v1)

### 1. First Launch / Empty State

**Purpose**  
Establish trust and scope without onboarding ceremony.

**Content**

- Single sentence:
  > “We help you plan weeknight dinners without starting from scratch every time.”
- Primary action:
  - **Make a first draft**

No tutorials, no preference setup, no long forms.

---

### 2. Weekly Draft (Primary Screen)

**Purpose**  
Present a complete, opinionated weekly plan that can be accepted with minimal effort.

**Structure**

- One week visible at a time
- Weeknights only by default
- Minimal visual hierarchy

**Each day displays**

- Day label
- Meal name (free text)
- Subtle tag:
  - Easy
  - Normal
  - Leftovers

**Explicitly excluded**

- Recipes
- Ingredients
- Nutrition
- Prep steps
- Ratings
- Checkboxes
- Timers

**Primary interactions**

- Tap meal → Swap
- Long-press meal → Replace
- Swipe day → Clear (creates signal)

No separate edit screens.

---

### 3. Weekly Check-In (Embedded)

**Purpose**  
Capture only what the system cannot reliably infer.

**Placement**

- Appears _below_ the weekly draft
- Framed as corrections, not setup

**Question 1: Scope**

> “Planning for **X dinners** this week. Change?”

- Quick tap adjustment
- Boundary condition, not planning

**Question 2: Disruptions**

> “We assumed this week is mostly normal. Anything unusually busy?”

- Days pre-filled by system guess
- User only corrects mismatches
- Binary states only: normal / busy

**Question 3: Constraints (Optional)**

> “Anything you want to use up?”

- Free text or quick picks:
  - Frozen meals
  - Leftovers
  - Produce expiring
  - Nothing special

No question is required.

---

### 4. Swap / Replace Sheet

**Purpose**  
Allow targeted correction without reopening planning.

**Behavior**

- Shows 3–5 alternatives
- Ranked by likelihood to survive this week
- Includes one safe fallback

No browsing.
No discovery.
No infinite lists.

---

### 5. History (Optional but Valuable)

**Purpose**  
Build trust by showing that the system remembers outcomes.

**Content**

- Past weeks, collapsed
- Read-only
- No editing or scoring

Answers:

> “Does this app remember our life?”

---

## Minimum Memory Model (v1)

The system remembers **outcomes**, not intentions.

### 1. Meal Entity

- Name (free text)
- Prep risk category (inferred):
  - fast
  - normal
  - effortful

No recipes, ingredients, or nutrition data.

---

### 2. Meal Outcomes (Critical)

For each meal instance:

- Date
- Outcome:
  - Kept
  - Swapped
  - Skipped
- Fallback used (yes/no)

Used to infer survivability and confidence.

---

### 3. Week Shape (Inferred)

Each week classified internally as:

- normal
- busy
- chaotic
- travel-light

Derived from overrides, swaps, and failures.

---

### 4. Repetition Fatigue (Inferred)

Detected when:

- Meals are swapped after recent repeats
- “Safe” meals fail despite low effort
- Variety correlates with overrides

No explicit user input.

---

## Draft Assumptions (v1-Safe)

The auto-generated draft may assume:

- Reuse beats novelty
- Busy nights get low-risk meals
- Leftovers are intentional when history supports it
- One flex night is acceptable

The draft must **not** assume:

- Desire for new recipes
- Experimental meals
- Evenly distributed energy
- Rapidly changing preferences

---

## What This App Is Not

Explicit non-goals for v1:

- Recipe app
- Grocery list manager
- Nutrition tracker
- Preference configuration system
- Notification engine
- Family profile manager

Adding these too early reintroduces ritual.

---

## Why this is better (and more defensible) than ChatGPT

ChatGPT is great at ideas, but it’s weak at:

- remembering your rotation without you re-explaining it
- keeping plans stable when you make one change (“swap Tuesday” shouldn’t reshuffle the week)
  making repeatable, low-friction weekly workflows
- A purpose-built app can beat it by being deterministic, fast, and consistent.

## Copy, Visual, and Interaction Rules

**Copy**

- Neutral, calm tone
- No cheerleading
- No guilt language

**Visual**

- Muted palette
- Low contrast
- Generous spacing
- Fewer UI elements than expected

**Interaction**

- One tap > two taps
- Defaults are confident
- Undo > confirmation dialogs

---

## Success Criteria (UX-Level)

The app is succeeding if users say:

- “That was easier than last week.”
- “I didn’t have to think as much.”
- “It kind of just knows us now.”
- "Easier than doing this in ChatGPT"

The app is failing if users say:

- “I need to set this up better.”
- “I should spend more time with it.”
- “It’s cool, but I forget to use it.”
- "I could do this same thing with ChatGPT"

---

## Mental Model to Protect

This app is a **quiet weekly decision that closes a mental loop**.

Not a planner.  
Not a coach.  
Not a tracker.
