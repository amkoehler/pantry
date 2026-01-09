import { describe, test, expect } from 'bun:test';
import { getMeals, getMealById, getMealsByIds } from '../../src/db/client';
import type { DraftMeal, DraftResponse } from '../../src/types';

/**
 * Tests for draft validation logic.
 *
 * The generateDraft function validates that meal IDs returned by the AI
 * actually exist in the database. These tests verify that validation
 * approach works correctly.
 */

describe('Draft meal ID validation', () => {
  // Simulate the validation logic from draft-generator.ts
  function validateDraftMealIds(draft: DraftResponse, validMealIds: Set<number>): DraftMeal[] {
    return draft.meals.map((m) => {
      const isValidId = m.mealId !== null && validMealIds.has(m.mealId);
      return {
        dayOfWeek: m.dayOfWeek,
        mealId: isValidId ? m.mealId : null,
        mealTitle: m.mealTitle,
        reasoning: m.reasoning,
      };
    });
  }

  test('valid meal IDs are preserved', () => {
    const meals = getMeals({ glutenFree: false, dairyFree: false, nutFree: false });
    const validIds = new Set(meals.map((m) => m.id));
    const validId = meals[0]!.id;

    const draft: DraftResponse = {
      meals: [{ dayOfWeek: 1, mealId: validId, mealTitle: meals[0]!.title, reasoning: 'Test' }],
    };

    const validated = validateDraftMealIds(draft, validIds);

    expect(validated[0]!.mealId).toBe(validId);
  });

  test('invalid meal IDs are nullified', () => {
    const meals = getMeals({ glutenFree: false, dairyFree: false, nutFree: false });
    const validIds = new Set(meals.map((m) => m.id));

    const draft: DraftResponse = {
      meals: [{ dayOfWeek: 1, mealId: 999999, mealTitle: 'Fake Meal', reasoning: 'Test' }],
    };

    const validated = validateDraftMealIds(draft, validIds);

    expect(validated[0]!.mealId).toBeNull();
  });

  test('null meal IDs remain null', () => {
    const meals = getMeals({ glutenFree: false, dairyFree: false, nutFree: false });
    const validIds = new Set(meals.map((m) => m.id));

    const draft: DraftResponse = {
      meals: [{ dayOfWeek: 1, mealId: null, mealTitle: 'Custom Meal', reasoning: 'Test' }],
    };

    const validated = validateDraftMealIds(draft, validIds);

    expect(validated[0]!.mealId).toBeNull();
  });

  test('mixed valid and invalid IDs handled correctly', () => {
    const meals = getMeals({ glutenFree: false, dairyFree: false, nutFree: false });
    const validIds = new Set(meals.map((m) => m.id));
    const validId1 = meals[0]!.id;
    const validId2 = meals[1]!.id;

    const draft: DraftResponse = {
      meals: [
        { dayOfWeek: 1, mealId: validId1, mealTitle: meals[0]!.title, reasoning: 'Valid' },
        { dayOfWeek: 2, mealId: 999999, mealTitle: 'Invalid', reasoning: 'Invalid' },
        { dayOfWeek: 3, mealId: validId2, mealTitle: meals[1]!.title, reasoning: 'Valid' },
        { dayOfWeek: 4, mealId: null, mealTitle: 'Null', reasoning: 'Null' },
        { dayOfWeek: 5, mealId: -1, mealTitle: 'Negative', reasoning: 'Invalid' },
      ],
    };

    const validated = validateDraftMealIds(draft, validIds);

    expect(validated[0]!.mealId).toBe(validId1);
    expect(validated[1]!.mealId).toBeNull();
    expect(validated[2]!.mealId).toBe(validId2);
    expect(validated[3]!.mealId).toBeNull();
    expect(validated[4]!.mealId).toBeNull();
  });

  test('meal title is preserved regardless of ID validity', () => {
    const meals = getMeals({ glutenFree: false, dairyFree: false, nutFree: false });
    const validIds = new Set(meals.map((m) => m.id));

    const draft: DraftResponse = {
      meals: [{ dayOfWeek: 1, mealId: 999999, mealTitle: 'AI Invented Meal', reasoning: 'Test' }],
    };

    const validated = validateDraftMealIds(draft, validIds);

    expect(validated[0]!.mealTitle).toBe('AI Invented Meal');
  });

  test('dayOfWeek and reasoning preserved after validation', () => {
    const meals = getMeals({ glutenFree: false, dairyFree: false, nutFree: false });
    const validIds = new Set(meals.map((m) => m.id));

    const draft: DraftResponse = {
      meals: [
        { dayOfWeek: 5, mealId: 999999, mealTitle: 'Test', reasoning: 'Friday is pizza night' },
      ],
    };

    const validated = validateDraftMealIds(draft, validIds);

    expect(validated[0]!.dayOfWeek).toBe(5);
    expect(validated[0]!.reasoning).toBe('Friday is pizza night');
  });
});

describe('Dietary filter validation for drafts', () => {
  test('gluten-free filter excludes gluten-containing meals', () => {
    const glutenFreeMeals = getMeals({ glutenFree: true, dairyFree: false, nutFree: false });
    const validIds = new Set(glutenFreeMeals.map((m) => m.id));

    // Find a gluten-containing meal
    const allMeals = getMeals({ glutenFree: false, dairyFree: false, nutFree: false });
    const glutenMeal = allMeals.find((m) => m.containsGluten);

    if (glutenMeal) {
      // This ID should NOT be in the gluten-free set
      expect(validIds.has(glutenMeal.id)).toBe(false);
    }
  });

  test('dairy-free filter excludes dairy-containing meals', () => {
    const dairyFreeMeals = getMeals({ glutenFree: false, dairyFree: true, nutFree: false });
    const validIds = new Set(dairyFreeMeals.map((m) => m.id));

    const allMeals = getMeals({ glutenFree: false, dairyFree: false, nutFree: false });
    const dairyMeal = allMeals.find((m) => m.containsDairy);

    if (dairyMeal) {
      expect(validIds.has(dairyMeal.id)).toBe(false);
    }
  });

  test('nut-free filter excludes nut-containing meals', () => {
    const nutFreeMeals = getMeals({ glutenFree: false, dairyFree: false, nutFree: true });
    const validIds = new Set(nutFreeMeals.map((m) => m.id));

    const allMeals = getMeals({ glutenFree: false, dairyFree: false, nutFree: false });
    const nutMeal = allMeals.find((m) => m.containsNuts);

    if (nutMeal) {
      expect(validIds.has(nutMeal.id)).toBe(false);
    }
  });

  test('combined filters reduce valid meal set appropriately', () => {
    const allMeals = getMeals({ glutenFree: false, dairyFree: false, nutFree: false });
    const restrictedMeals = getMeals({ glutenFree: true, dairyFree: true, nutFree: false });

    // Restricted set should be smaller or equal
    expect(restrictedMeals.length).toBeLessThanOrEqual(allMeals.length);

    // All restricted meals should have no gluten and no dairy
    for (const meal of restrictedMeals) {
      expect(meal.containsGluten).toBe(false);
      expect(meal.containsDairy).toBe(false);
    }
  });
});

describe('Meal lookup functions for draft building', () => {
  test('getMealById returns correct meal for building response', () => {
    const meals = getMeals({ glutenFree: false, dairyFree: false, nutFree: false });
    const targetId = meals[0]!.id;
    const targetTitle = meals[0]!.title;

    const meal = getMealById(targetId);

    expect(meal).not.toBeNull();
    expect(meal!.id).toBe(targetId);
    expect(meal!.title).toBe(targetTitle);
  });

  test('getMealsByIds retrieves batch of meals efficiently', () => {
    const meals = getMeals({ glutenFree: false, dairyFree: false, nutFree: false });
    const targetIds = meals.slice(0, 5).map((m) => m.id);

    const fetchedMeals = getMealsByIds(targetIds);

    expect(fetchedMeals.length).toBe(5);
    for (const id of targetIds) {
      expect(fetchedMeals.some((m) => m.id === id)).toBe(true);
    }
  });

  test('getMealsByIds filters out invalid IDs automatically', () => {
    const meals = getMeals({ glutenFree: false, dairyFree: false, nutFree: false });
    const validId = meals[0]!.id;
    const mixedIds = [validId, 999999, -1, 0];

    const fetchedMeals = getMealsByIds(mixedIds);

    expect(fetchedMeals.length).toBe(1);
    expect(fetchedMeals[0]!.id).toBe(validId);
  });
});
