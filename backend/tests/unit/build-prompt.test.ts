import { describe, test, expect } from 'bun:test';
import { buildPrompt } from '../../src/ai/build-prompt';
import type { DraftRequest, Meal } from '../../src/types';

// Mock meals for testing - covers quick/normal/long complexity
const mockMeals: Meal[] = [
  {
    id: 1,
    title: 'Quick Tacos',
    protein: 'beef',
    starch: 'tortillas',
    vegOrFruit: ['lettuce', 'tomato'],
    cuisine: 'Mexican',
    method: 'stovetop',
    onePotOrPan: 'no',
    complexity: 'quick',
    estimatedTotalMinutes: 25,
    seasonality: 'year-round',
    containsGluten: true,
    containsDairy: true,
    containsNuts: false,
    tags: ['family-favorite'],
  },
  {
    id: 2,
    title: 'Pasta Primavera',
    protein: 'none',
    starch: 'pasta',
    vegOrFruit: ['zucchini', 'bell pepper'],
    cuisine: 'Italian',
    method: 'stovetop',
    onePotOrPan: 'one-pot',
    complexity: 'normal',
    estimatedTotalMinutes: 35,
    seasonality: 'year-round',
    containsGluten: true,
    containsDairy: true,
    containsNuts: false,
    tags: ['vegetarian'],
  },
  {
    id: 3,
    title: 'Slow Roasted Chicken',
    protein: 'chicken',
    starch: 'potatoes',
    vegOrFruit: ['carrots', 'green beans'],
    cuisine: 'American',
    method: 'oven',
    onePotOrPan: 'one-pan',
    complexity: 'long',
    estimatedTotalMinutes: 75,
    seasonality: 'year-round',
    containsGluten: false,
    containsDairy: true,
    containsNuts: false,
    tags: ['sunday-dinner'],
  },
];

describe('buildPrompt', () => {
  test('includes dinner count in prompt', () => {
    const request: DraftRequest = {
      dinnerCount: 5,
      busyDays: [],
      constraints: null,
      mealHistory: [],
      dietaryFilters: { glutenFree: false, dairyFree: false, nutFree: false },
    };

    const prompt = buildPrompt(request, mockMeals);

    expect(prompt).toContain('5 nights');
    expect(prompt).toContain('exactly 5 meals');
  });

  test('groups meals by complexity', () => {
    const request: DraftRequest = {
      dinnerCount: 3,
      busyDays: [],
      constraints: null,
      mealHistory: [],
      dietaryFilters: { glutenFree: false, dairyFree: false, nutFree: false },
    };

    const prompt = buildPrompt(request, mockMeals);

    // Check complexity sections exist
    expect(prompt).toContain('### Quick meals');
    expect(prompt).toContain('### Normal meals');
    expect(prompt).toContain('### Long meals');

    // Quick meal should be under quick section
    const quickSectionStart = prompt.indexOf('### Quick meals');
    const normalSectionStart = prompt.indexOf('### Normal meals');
    const tacoPosition = prompt.indexOf('Quick Tacos');
    expect(tacoPosition).toBeGreaterThan(quickSectionStart);
    expect(tacoPosition).toBeLessThan(normalSectionStart);
  });

  test('highlights busy days', () => {
    const request: DraftRequest = {
      dinnerCount: 5,
      busyDays: [2, 4],
      constraints: null,
      mealHistory: [],
      dietaryFilters: { glutenFree: false, dairyFree: false, nutFree: false },
    };

    const prompt = buildPrompt(request, mockMeals);

    expect(prompt).toContain('BUSY DAYS');
    expect(prompt).toContain('Tuesday');
    expect(prompt).toContain('Thursday');
    expect(prompt).toContain('quick');
  });

  test('no busy days section when empty', () => {
    const request: DraftRequest = {
      dinnerCount: 3,
      busyDays: [],
      constraints: null,
      mealHistory: [],
      dietaryFilters: { glutenFree: false, dairyFree: false, nutFree: false },
    };

    const prompt = buildPrompt(request, mockMeals);

    expect(prompt).toContain('No particularly busy days');
    expect(prompt).not.toContain('BUSY DAYS:');
  });

  test('separates kept vs rejected meal history', () => {
    const request: DraftRequest = {
      dinnerCount: 3,
      busyDays: [],
      constraints: null,
      mealHistory: [
        { mealTitle: 'Tacos', outcome: 'kept', weeksAgo: 2 },
        { mealTitle: 'Pasta', outcome: 'swapped', weeksAgo: 1 },
        { mealTitle: 'Chicken', outcome: 'skipped', weeksAgo: 3 },
      ],
      dietaryFilters: { glutenFree: false, dairyFree: false, nutFree: false },
    };

    const prompt = buildPrompt(request, mockMeals);

    expect(prompt).toContain('Household favorites');
    expect(prompt).toContain('Tacos');
    expect(prompt).toContain('Recently rejected');
    expect(prompt).toContain('swapped');
  });

  test('includes constraints when provided', () => {
    const request: DraftRequest = {
      dinnerCount: 3,
      busyDays: [],
      constraints: 'chicken thighs in the freezer',
      mealHistory: [],
      dietaryFilters: { glutenFree: false, dairyFree: false, nutFree: false },
    };

    const prompt = buildPrompt(request, mockMeals);

    expect(prompt).toContain('chicken thighs in the freezer');
    expect(prompt).toContain('prioritize');
  });

  test('no constraints section when null', () => {
    const request: DraftRequest = {
      dinnerCount: 3,
      busyDays: [],
      constraints: null,
      mealHistory: [],
      dietaryFilters: { glutenFree: false, dairyFree: false, nutFree: false },
    };

    const prompt = buildPrompt(request, mockMeals);

    expect(prompt).not.toContain('User wants to use');
  });

  test('includes meal IDs in format for parsing', () => {
    const request: DraftRequest = {
      dinnerCount: 3,
      busyDays: [],
      constraints: null,
      mealHistory: [],
      dietaryFilters: { glutenFree: false, dairyFree: false, nutFree: false },
    };

    const prompt = buildPrompt(request, mockMeals);

    expect(prompt).toContain('[ID:1]');
    expect(prompt).toContain('[ID:2]');
    expect(prompt).toContain('[ID:3]');
  });

  test('includes cuisine in meal listing', () => {
    const request: DraftRequest = {
      dinnerCount: 3,
      busyDays: [],
      constraints: null,
      mealHistory: [],
      dietaryFilters: { glutenFree: false, dairyFree: false, nutFree: false },
    };

    const prompt = buildPrompt(request, mockMeals);

    expect(prompt).toContain('Mexican');
    expect(prompt).toContain('Italian');
    expect(prompt).toContain('American');
  });

  test('includes time estimate in meal listing', () => {
    const request: DraftRequest = {
      dinnerCount: 3,
      busyDays: [],
      constraints: null,
      mealHistory: [],
      dietaryFilters: { glutenFree: false, dairyFree: false, nutFree: false },
    };

    const prompt = buildPrompt(request, mockMeals);

    expect(prompt).toContain('25min');
    expect(prompt).toContain('35min');
    expect(prompt).toContain('75min');
  });
});
