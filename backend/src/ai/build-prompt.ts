import type { DraftRequest, Meal } from '../types';

function dayName(day: number): string {
  const days = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  return days[day] || `Day ${day}`;
}

export function buildPrompt(request: DraftRequest, availableMeals: Meal[]): string {
  // Build meal list - group by complexity for clarity
  const quickMeals = availableMeals.filter((m) => m.complexity === 'quick');
  const normalMeals = availableMeals.filter((m) => m.complexity === 'normal');
  const longMeals = availableMeals.filter((m) => m.complexity === 'long');

  const formatMeal = (m: Meal) =>
    `- [ID:${m.id}] ${m.title} (${m.estimatedTotalMinutes}min, ${m.cuisine})`;

  const mealList = [
    '### Quick meals (≤30 min) - USE FOR BUSY DAYS',
    ...quickMeals.map(formatMeal),
    '',
    '### Normal meals (30-45 min)',
    ...normalMeals.map(formatMeal),
    '',
    '### Long meals (45+ min) - AVOID ON BUSY DAYS',
    ...longMeals.map(formatMeal),
  ].join('\n');

  // Build history - separate kept vs rejected
  const keptMeals = request.mealHistory.filter((h) => h.outcome === 'kept');
  const rejectedMeals = request.mealHistory.filter((h) => h.outcome !== 'kept');

  let historySection = '';
  if (keptMeals.length > 0) {
    historySection += '**Household favorites (kept):**\n';
    historySection += keptMeals.map((h) => `- "${h.mealTitle}" (${h.weeksAgo}w ago)`).join('\n');
    historySection += '\n\n';
  }
  if (rejectedMeals.length > 0) {
    historySection += '**Recently rejected (avoid):**\n';
    historySection += rejectedMeals
      .map((h) => `- "${h.mealTitle}" was ${h.outcome} (${h.weeksAgo}w ago)`)
      .join('\n');
  }
  if (!historySection) {
    historySection = 'No history yet - pick a balanced variety of meals.';
  }

  // Build busy days context with emphasis
  let busyDaysSection = '';
  if (request.busyDays.length > 0) {
    const busyDayNames = request.busyDays.map(dayName).join(', ');
    busyDaysSection = `**BUSY DAYS: ${busyDayNames}**\nThese days MUST have "quick" complexity meals (≤30 min).`;
  } else {
    busyDaysSection = 'No particularly busy days this week.';
  }

  // Build constraints
  const constraintsSection = request.constraints
    ? `**User wants to use:** "${request.constraints}" - prioritize meals with these ingredients.`
    : '';

  return `You are a meal planning assistant for a family household. Generate a dinner plan for ${request.dinnerCount} nights this week.

## Available Meals

Pick ONLY from these meals by ID. Do not invent meals.

${mealList}

## Household History

${historySection}

## This Week's Context

${busyDaysSection}
${constraintsSection}

## Rules (in priority order)

1. **ONLY pick meals from the list above** - Every mealId MUST match an ID from Available Meals
2. **Busy days get quick meals** - Days marked busy MUST have "quick" complexity meals (≤30 min)
3. **No repeats this week** - Never suggest the same meal twice
4. **Avoid recently rejected meals** - Skip meals marked "swapped" or "skipped" in history
5. **Variety** - Mix cuisines (don't do 3 Italian dishes in a row) and cooking methods
6. **Staples vs novelty** - If history shows "kept" meals, favor those (~60% of plan)
7. **Honor constraints** - If user mentioned ingredients, prioritize meals containing them

## Output

Generate exactly ${request.dinnerCount} meals for days 1-${request.dinnerCount} (Monday=1, Tuesday=2, etc.)
For each meal:
- dayOfWeek: the day number (1-7)
- mealId: the ID from Available Meals (MUST be a valid ID from the list)
- mealTitle: the exact meal title from the list
- reasoning: 1 sentence explaining why this meal fits this day
`.trim();
}
