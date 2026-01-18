import { describe, test, expect } from 'bun:test';
import { getMeals } from '../../src/db/client';
import type { DietaryFilters } from '../../src/types';

// Default filters for tests (no dietary restrictions)
const defaultFilters: DietaryFilters = {
  glutenFree: false,
  dairyFree: false,
  nutFree: false,
};

describe('getMeals', () => {
  test('returns onePotOrPan field for each meal', () => {
    const meals = getMeals(defaultFilters);
    expect(meals.length).toBeGreaterThan(0);

    for (const meal of meals) {
      expect(meal).toHaveProperty('onePotOrPan');
      expect(['one-pot', 'one-pan', 'no']).toContain(meal.onePotOrPan);
    }
  });

  test('meal titles do not contain One-Pot or One-Pan prefixes', () => {
    const meals = getMeals(defaultFilters);

    for (const meal of meals) {
      expect(meal.title).not.toMatch(/^One-Pot:/);
      expect(meal.title).not.toMatch(/^One-Pan:/);
    }
  });

  test('one-pot meals have onePotOrPan set to one-pot', () => {
    const meals = getMeals(defaultFilters);
    const onePotMeals = meals.filter((m) => m.onePotOrPan === 'one-pot');

    expect(onePotMeals.length).toBeGreaterThan(0);
  });

  test('one-pan meals have onePotOrPan set to one-pan', () => {
    const meals = getMeals(defaultFilters);
    const onePanMeals = meals.filter((m) => m.onePotOrPan === 'one-pan');

    expect(onePanMeals.length).toBeGreaterThan(0);
  });
});
