import { describe, test, expect } from 'bun:test';
import { rowToMeal, getMeals, getMealById, getMealsByIds } from '../../src/db/client';
import type { MealRow } from '../../src/types';

describe('rowToMeal', () => {
  test('converts snake_case to camelCase', () => {
    const row: MealRow = {
      id: 1,
      title: 'Test Meal',
      protein: 'chicken',
      starch: 'rice',
      veg_or_fruit: '["broccoli"]',
      cuisine: 'American',
      method: 'stovetop',
      one_pot_or_pan: 'one-pot',
      complexity: 'quick',
      estimated_total_minutes: 25,
      seasonality: 'year-round',
      contains_gluten: 0,
      contains_dairy: 1,
      contains_nuts: 0,
      tags: '["family-favorite"]',
    };

    const meal = rowToMeal(row);

    expect(meal.id).toBe(1);
    expect(meal.title).toBe('Test Meal');
    expect(meal.vegOrFruit).toEqual(['broccoli']);
    expect(meal.onePotOrPan).toBe('one-pot');
    expect(meal.estimatedTotalMinutes).toBe(25);
  });

  test('converts integer booleans to actual booleans', () => {
    const row: MealRow = {
      id: 1,
      title: 'Test',
      protein: 'beef',
      starch: null,
      veg_or_fruit: '[]',
      cuisine: 'Mexican',
      method: 'grill',
      one_pot_or_pan: 'no',
      complexity: 'normal',
      estimated_total_minutes: 30,
      seasonality: 'summer',
      contains_gluten: 1,
      contains_dairy: 0,
      contains_nuts: 1,
      tags: '[]',
    };

    const meal = rowToMeal(row);

    expect(meal.containsGluten).toBe(true);
    expect(meal.containsDairy).toBe(false);
    expect(meal.containsNuts).toBe(true);
  });

  test('parses JSON array fields correctly', () => {
    const row: MealRow = {
      id: 1,
      title: 'Test',
      protein: 'fish',
      starch: 'pasta',
      veg_or_fruit: '["spinach", "tomatoes", "garlic"]',
      cuisine: 'Italian',
      method: 'stovetop',
      one_pot_or_pan: 'no',
      complexity: 'normal',
      estimated_total_minutes: 35,
      seasonality: 'year-round',
      contains_gluten: 1,
      contains_dairy: 1,
      contains_nuts: 0,
      tags: '["seafood", "date-night"]',
    };

    const meal = rowToMeal(row);

    expect(meal.vegOrFruit).toEqual(['spinach', 'tomatoes', 'garlic']);
    expect(meal.tags).toEqual(['seafood', 'date-night']);
  });

  test('handles null starch field', () => {
    const row: MealRow = {
      id: 1,
      title: 'Starchless Meal',
      protein: 'salmon',
      starch: null,
      veg_or_fruit: '["asparagus"]',
      cuisine: 'American',
      method: 'oven',
      one_pot_or_pan: 'one-pan',
      complexity: 'quick',
      estimated_total_minutes: 20,
      seasonality: 'spring',
      contains_gluten: 0,
      contains_dairy: 0,
      contains_nuts: 0,
      tags: '[]',
    };

    const meal = rowToMeal(row);

    expect(meal.starch).toBeNull();
  });

  test('handles empty JSON arrays', () => {
    const row: MealRow = {
      id: 1,
      title: 'Minimal Meal',
      protein: 'eggs',
      starch: 'toast',
      veg_or_fruit: '[]',
      cuisine: 'American',
      method: 'stovetop',
      one_pot_or_pan: 'one-pan',
      complexity: 'quick',
      estimated_total_minutes: 15,
      seasonality: 'year-round',
      contains_gluten: 1,
      contains_dairy: 0,
      contains_nuts: 0,
      tags: '[]',
    };

    const meal = rowToMeal(row);

    expect(meal.vegOrFruit).toEqual([]);
    expect(meal.tags).toEqual([]);
  });
});

describe('getMeals', () => {
  test('returns meals with no filters', () => {
    const meals = getMeals({ glutenFree: false, dairyFree: false, nutFree: false });

    expect(meals.length).toBeGreaterThan(0);
    expect(meals[0]).toHaveProperty('id');
    expect(meals[0]).toHaveProperty('title');
    expect(meals[0]).toHaveProperty('containsGluten');
  });

  test('filters gluten-free meals', () => {
    const meals = getMeals({ glutenFree: true, dairyFree: false, nutFree: false });

    expect(meals.length).toBeGreaterThan(0);
    for (const meal of meals) {
      expect(meal.containsGluten).toBe(false);
    }
  });

  test('filters dairy-free meals', () => {
    const meals = getMeals({ glutenFree: false, dairyFree: true, nutFree: false });

    expect(meals.length).toBeGreaterThan(0);
    for (const meal of meals) {
      expect(meal.containsDairy).toBe(false);
    }
  });

  test('filters nut-free meals', () => {
    const meals = getMeals({ glutenFree: false, dairyFree: false, nutFree: true });

    expect(meals.length).toBeGreaterThan(0);
    for (const meal of meals) {
      expect(meal.containsNuts).toBe(false);
    }
  });

  test('combines multiple dietary filters', () => {
    const meals = getMeals({ glutenFree: true, dairyFree: true, nutFree: false });

    expect(meals.length).toBeGreaterThan(0);
    for (const meal of meals) {
      expect(meal.containsGluten).toBe(false);
      expect(meal.containsDairy).toBe(false);
    }
  });

  test('applies all three filters simultaneously', () => {
    const meals = getMeals({ glutenFree: true, dairyFree: true, nutFree: true });

    // Should still return some meals (allergen-safe options exist)
    for (const meal of meals) {
      expect(meal.containsGluten).toBe(false);
      expect(meal.containsDairy).toBe(false);
      expect(meal.containsNuts).toBe(false);
    }
  });

  test('returns meals in consistent order', () => {
    const meals1 = getMeals({ glutenFree: false, dairyFree: false, nutFree: false });
    const meals2 = getMeals({ glutenFree: false, dairyFree: false, nutFree: false });

    // Same query should return same order
    expect(meals1.length).toBe(meals2.length);
    for (let i = 0; i < meals1.length; i++) {
      expect(meals1[i].id).toBe(meals2[i].id);
    }
  });

  test('returns properly transformed meal objects', () => {
    const meals = getMeals({ glutenFree: false, dairyFree: false, nutFree: false });
    const meal = meals[0];

    // Check camelCase properties exist (not snake_case)
    expect(meal).toHaveProperty('vegOrFruit');
    expect(meal).toHaveProperty('onePotOrPan');
    expect(meal).toHaveProperty('estimatedTotalMinutes');
    expect(meal).toHaveProperty('containsGluten');

    // Check types are correct
    expect(Array.isArray(meal.vegOrFruit)).toBe(true);
    expect(Array.isArray(meal.tags)).toBe(true);
    expect(typeof meal.containsGluten).toBe('boolean');
  });
});

describe('getMealById', () => {
  test('returns meal for valid ID', () => {
    // First get a valid ID from the database
    const meals = getMeals({ glutenFree: false, dairyFree: false, nutFree: false });
    const validId = meals[0].id;

    const meal = getMealById(validId);

    expect(meal).not.toBeNull();
    expect(meal!.id).toBe(validId);
  });

  test('returns null for non-existent ID', () => {
    const meal = getMealById(999999);

    expect(meal).toBeNull();
  });

  test('returns null for ID 0', () => {
    const meal = getMealById(0);

    expect(meal).toBeNull();
  });

  test('returns null for negative ID', () => {
    const meal = getMealById(-1);

    expect(meal).toBeNull();
  });

  test('returns properly transformed meal object', () => {
    const meals = getMeals({ glutenFree: false, dairyFree: false, nutFree: false });
    const validId = meals[0].id;

    const meal = getMealById(validId);

    expect(meal).not.toBeNull();
    expect(typeof meal!.containsGluten).toBe('boolean');
    expect(Array.isArray(meal!.vegOrFruit)).toBe(true);
  });
});

describe('getMealsByIds', () => {
  test('returns empty array for empty input', () => {
    const meals = getMealsByIds([]);

    expect(meals).toEqual([]);
  });

  test('returns meals for valid IDs', () => {
    // Get some valid IDs
    const allMeals = getMeals({ glutenFree: false, dairyFree: false, nutFree: false });
    const validIds = allMeals.slice(0, 3).map((m) => m.id);

    const meals = getMealsByIds(validIds);

    expect(meals.length).toBe(3);
    for (const id of validIds) {
      expect(meals.some((m) => m.id === id)).toBe(true);
    }
  });

  test('returns single meal for single ID', () => {
    const allMeals = getMeals({ glutenFree: false, dairyFree: false, nutFree: false });
    const singleId = allMeals[0].id;

    const meals = getMealsByIds([singleId]);

    expect(meals.length).toBe(1);
    expect(meals[0].id).toBe(singleId);
  });

  test('ignores non-existent IDs', () => {
    const allMeals = getMeals({ glutenFree: false, dairyFree: false, nutFree: false });
    const validId = allMeals[0].id;
    const mixedIds = [validId, 999999, 888888];

    const meals = getMealsByIds(mixedIds);

    // Should only return the valid one
    expect(meals.length).toBe(1);
    expect(meals[0].id).toBe(validId);
  });

  test('returns empty array when all IDs are invalid', () => {
    const meals = getMealsByIds([999999, 888888, 777777]);

    expect(meals).toEqual([]);
  });

  test('handles duplicate IDs', () => {
    const allMeals = getMeals({ glutenFree: false, dairyFree: false, nutFree: false });
    const singleId = allMeals[0].id;

    const meals = getMealsByIds([singleId, singleId, singleId]);

    // SQLite IN clause handles duplicates - returns unique rows
    expect(meals.length).toBe(1);
    expect(meals[0].id).toBe(singleId);
  });
});
