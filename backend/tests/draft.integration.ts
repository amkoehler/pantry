import { test, expect, describe } from 'bun:test';
import { generateDraft, buildPrompt } from '../src/ai/draft-generator';
import { getMeals } from '../src/db/client';
import type { DraftRequest } from '../src/types';

// Default test request - minimal to reduce API costs
const testRequest: DraftRequest = {
  dinnerCount: 3,
  busyDays: [2], // Tuesday
  constraints: null,
  mealHistory: [],
  dietaryFilters: {
    glutenFree: false,
    dairyFree: false,
    nutFree: false,
  },
};

describe('Draft Generator', () => {
  test('buildPrompt creates valid prompt', () => {
    const meals = getMeals(testRequest.dietaryFilters);
    const prompt = buildPrompt(testRequest, meals);

    // Prompt should include key elements
    expect(prompt).toContain('dinner plan for 3 nights');
    expect(prompt).toContain('Tuesday');
    expect(prompt).toContain('Available Meals');
    expect(prompt).toContain('[ID:');

    // Print prompt for inspection
    console.log('\n--- Generated Prompt ---');
    console.log(prompt);
    console.log('--- End Prompt ---\n');
  });

  test(
    'generateDraft returns valid draft (calls OpenAI API)',
    async () => {
      console.log('\n--- Calling OpenAI API ---');
      console.log('This test incurs API costs!\n');

      const draft = await generateDraft(testRequest, { verbose: true });

      // Should have correct number of meals
      expect(draft.meals.length).toBe(testRequest.dinnerCount);

      // Each meal should have required fields
      for (const meal of draft.meals) {
        expect(meal.dayOfWeek).toBeGreaterThanOrEqual(1);
        expect(meal.dayOfWeek).toBeLessThanOrEqual(7);
        expect(meal.mealTitle).toBeTruthy();
      }

      // No duplicate days
      const days = draft.meals.map((m) => m.dayOfWeek);
      const uniqueDays = new Set(days);
      expect(uniqueDays.size).toBe(days.length);

      // No duplicate meals
      const titles = draft.meals.map((m) => m.mealTitle);
      const uniqueTitles = new Set(titles);
      expect(uniqueTitles.size).toBe(titles.length);

      // Print results
      console.log('\n--- Generated Draft ---');
      for (const meal of draft.meals) {
        const dayNames = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        console.log(`${dayNames[meal.dayOfWeek]}: ${meal.mealTitle}`);
        console.log(`     Reason: ${meal.reasoning}`);
      }
      console.log('--- End Draft ---\n');
    },
    { timeout: 30_000 }
  );

  test('generateDraft with meal history context', async () => {
    const requestWithHistory: DraftRequest = {
      ...testRequest,
      mealHistory: [
        { mealTitle: 'Tacos', outcome: 'kept', weeksAgo: 1 },
        { mealTitle: 'Spaghetti', outcome: 'swapped', weeksAgo: 1 },
        { mealTitle: 'Burgers', outcome: 'kept', weeksAgo: 2 },
      ],
    };

    const meals = getMeals(requestWithHistory.dietaryFilters);
    const prompt = buildPrompt(requestWithHistory, meals);

    // Prompt should include history
    expect(prompt).toContain('Tacos');
    expect(prompt).toContain('kept');
    expect(prompt).toContain('swapped');

    console.log('\n--- Prompt with History ---');
    console.log(prompt.substring(0, 1000) + '...');
    console.log('--- End ---\n');
  });
});
