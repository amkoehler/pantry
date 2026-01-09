import { describe, test, expect } from 'bun:test';
import { app } from '../../src/index';

interface MealResponse {
  id: number;
  title: string;
  protein: string;
  starch: string | null;
  vegOrFruit: string[];
  cuisine: string;
  method: string;
  onePotOrPan: boolean;
  complexity: string;
  estimatedTotalMinutes: number;
  seasonality: string;
  containsGluten: boolean;
  containsDairy: boolean;
  containsNuts: boolean;
  tags: string[];
}

interface MealsApiResponse {
  version: string;
  meals: MealResponse[];
  count: number;
}

describe('GET /api/meals', () => {
  test('returns meals with correct response structure', async () => {
    const res = await app.request('/api/meals');
    const json = (await res.json()) as MealsApiResponse;

    expect(res.status).toBe(200);
    expect(json).toHaveProperty('version');
    expect(json).toHaveProperty('meals');
    expect(json).toHaveProperty('count');
    expect(Array.isArray(json.meals)).toBe(true);
    expect(json.count).toBe(json.meals.length);
  });

  test('returns version as ISO date string', async () => {
    const res = await app.request('/api/meals');
    const json = (await res.json()) as MealsApiResponse;

    // Should be a valid ISO date
    const date = new Date(json.version);
    expect(date.toString()).not.toBe('Invalid Date');
  });

  test('returns meal objects with all required properties', async () => {
    const res = await app.request('/api/meals');
    const json = (await res.json()) as MealsApiResponse;
    const meal = json.meals[0];

    // Check all expected properties exist
    expect(meal).toHaveProperty('id');
    expect(meal).toHaveProperty('title');
    expect(meal).toHaveProperty('protein');
    expect(meal).toHaveProperty('starch');
    expect(meal).toHaveProperty('vegOrFruit');
    expect(meal).toHaveProperty('cuisine');
    expect(meal).toHaveProperty('method');
    expect(meal).toHaveProperty('onePotOrPan');
    expect(meal).toHaveProperty('complexity');
    expect(meal).toHaveProperty('estimatedTotalMinutes');
    expect(meal).toHaveProperty('seasonality');
    expect(meal).toHaveProperty('containsGluten');
    expect(meal).toHaveProperty('containsDairy');
    expect(meal).toHaveProperty('containsNuts');
    expect(meal).toHaveProperty('tags');
  });

  test('filters gluten-free meals with query param', async () => {
    const res = await app.request('/api/meals?gluten_free=true');
    const json = (await res.json()) as MealsApiResponse;

    expect(res.status).toBe(200);
    expect(json.meals.length).toBeGreaterThan(0);
    for (const meal of json.meals) {
      expect(meal.containsGluten).toBe(false);
    }
  });

  test('filters dairy-free meals with query param', async () => {
    const res = await app.request('/api/meals?dairy_free=true');
    const json = (await res.json()) as MealsApiResponse;

    expect(res.status).toBe(200);
    expect(json.meals.length).toBeGreaterThan(0);
    for (const meal of json.meals) {
      expect(meal.containsDairy).toBe(false);
    }
  });

  test('filters nut-free meals with query param', async () => {
    const res = await app.request('/api/meals?nut_free=true');
    const json = (await res.json()) as MealsApiResponse;

    expect(res.status).toBe(200);
    expect(json.meals.length).toBeGreaterThan(0);
    for (const meal of json.meals) {
      expect(meal.containsNuts).toBe(false);
    }
  });

  test('combines multiple dietary filters', async () => {
    const res = await app.request('/api/meals?gluten_free=true&dairy_free=true');
    const json = (await res.json()) as MealsApiResponse;

    expect(res.status).toBe(200);
    for (const meal of json.meals) {
      expect(meal.containsGluten).toBe(false);
      expect(meal.containsDairy).toBe(false);
    }
  });

  test('applies all three dietary filters', async () => {
    const res = await app.request('/api/meals?gluten_free=true&dairy_free=true&nut_free=true');
    const json = (await res.json()) as MealsApiResponse;

    expect(res.status).toBe(200);
    for (const meal of json.meals) {
      expect(meal.containsGluten).toBe(false);
      expect(meal.containsDairy).toBe(false);
      expect(meal.containsNuts).toBe(false);
    }
  });

  test('ignores invalid query param values (treats as false)', async () => {
    const res = await app.request('/api/meals?gluten_free=yes');
    const json = (await res.json()) as MealsApiResponse;

    // "yes" !== "true", so filter not applied
    expect(res.status).toBe(200);
    // Should include some gluten-containing meals
    const hasGluten = json.meals.some((m) => m.containsGluten);
    expect(hasGluten).toBe(true);
  });

  test('ignores unrecognized query params', async () => {
    const res = await app.request('/api/meals?foo=bar&unknown=param');
    const json = (await res.json()) as MealsApiResponse;

    expect(res.status).toBe(200);
    expect(json.meals.length).toBeGreaterThan(0);
  });

  test('count matches actual meals returned with filters', async () => {
    const res = await app.request('/api/meals?gluten_free=true');
    const json = (await res.json()) as MealsApiResponse;

    expect(json.count).toBe(json.meals.length);
  });
});
