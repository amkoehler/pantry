import { describe, test, expect } from 'bun:test';
import { app } from '../../src/index';

// Helper to make POST request with JSON body
async function postDraft(body: unknown) {
  return app.request('/api/draft', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
}

describe('POST /api/draft validation', () => {
  test('rejects missing dinnerCount', async () => {
    const res = await postDraft({
      busyDays: [],
      constraints: null,
      mealHistory: [],
      dietaryFilters: { glutenFree: false, dairyFree: false, nutFree: false },
    });
    const json = await res.json();

    expect(res.status).toBe(400);
    expect(json.error).toContain('dinnerCount');
  });

  test('rejects dinnerCount of 0', async () => {
    const res = await postDraft({
      dinnerCount: 0,
      busyDays: [],
      constraints: null,
      mealHistory: [],
      dietaryFilters: { glutenFree: false, dairyFree: false, nutFree: false },
    });
    const json = await res.json();

    expect(res.status).toBe(400);
    expect(json.error).toContain('dinnerCount');
    expect(json.error).toContain('between 1 and 7');
  });

  test('rejects negative dinnerCount', async () => {
    const res = await postDraft({
      dinnerCount: -1,
      busyDays: [],
      constraints: null,
      mealHistory: [],
      dietaryFilters: { glutenFree: false, dairyFree: false, nutFree: false },
    });
    const json = await res.json();

    expect(res.status).toBe(400);
    expect(json.error).toContain('dinnerCount');
  });

  test('rejects dinnerCount greater than 7', async () => {
    const res = await postDraft({
      dinnerCount: 8,
      busyDays: [],
      constraints: null,
      mealHistory: [],
      dietaryFilters: { glutenFree: false, dairyFree: false, nutFree: false },
    });
    const json = await res.json();

    expect(res.status).toBe(400);
    expect(json.error).toContain('dinnerCount');
    expect(json.error).toContain('between 1 and 7');
  });

  test('rejects dinnerCount of 100', async () => {
    const res = await postDraft({
      dinnerCount: 100,
      busyDays: [],
      constraints: null,
      mealHistory: [],
      dietaryFilters: { glutenFree: false, dairyFree: false, nutFree: false },
    });
    const json = await res.json();

    expect(res.status).toBe(400);
    expect(json.error).toContain('dinnerCount');
  });

  test('rejects missing dietaryFilters', async () => {
    const res = await postDraft({
      dinnerCount: 5,
      busyDays: [],
      constraints: null,
      mealHistory: [],
    });
    const json = await res.json();

    expect(res.status).toBe(400);
    expect(json.error).toContain('dietaryFilters');
  });

  test('accepts dinnerCount of 1 (minimum)', async () => {
    const res = await postDraft({
      dinnerCount: 1,
      busyDays: [],
      constraints: null,
      mealHistory: [],
      dietaryFilters: { glutenFree: false, dairyFree: false, nutFree: false },
    });

    // Should either succeed (200) or fail with 500 due to API call
    // The validation should pass, so we shouldn't get 400
    expect(res.status).not.toBe(400);
  });

  test('accepts dinnerCount of 7 (maximum)', async () => {
    const res = await postDraft({
      dinnerCount: 7,
      busyDays: [],
      constraints: null,
      mealHistory: [],
      dietaryFilters: { glutenFree: false, dairyFree: false, nutFree: false },
    });

    // Validation should pass (not 400)
    expect(res.status).not.toBe(400);
  });

  test('accepts all valid dinnerCount values 1-7', async () => {
    for (let i = 1; i <= 7; i++) {
      const res = await postDraft({
        dinnerCount: i,
        busyDays: [],
        constraints: null,
        mealHistory: [],
        dietaryFilters: { glutenFree: false, dairyFree: false, nutFree: false },
      });

      // Validation passes if not 400
      expect(res.status).not.toBe(400);
    }
  });

  test('accepts request with dietary filters enabled', async () => {
    const res = await postDraft({
      dinnerCount: 3,
      busyDays: [],
      constraints: null,
      mealHistory: [],
      dietaryFilters: { glutenFree: true, dairyFree: true, nutFree: true },
    });

    expect(res.status).not.toBe(400);
  });

  test('accepts request with busy days', async () => {
    const res = await postDraft({
      dinnerCount: 5,
      busyDays: [1, 3, 5],
      constraints: null,
      mealHistory: [],
      dietaryFilters: { glutenFree: false, dairyFree: false, nutFree: false },
    });

    expect(res.status).not.toBe(400);
  });

  test('accepts request with constraints', async () => {
    const res = await postDraft({
      dinnerCount: 4,
      busyDays: [],
      constraints: 'chicken in the freezer',
      mealHistory: [],
      dietaryFilters: { glutenFree: false, dairyFree: false, nutFree: false },
    });

    expect(res.status).not.toBe(400);
  });

  test('accepts request with meal history', async () => {
    const res = await postDraft({
      dinnerCount: 3,
      busyDays: [],
      constraints: null,
      mealHistory: [
        { mealTitle: 'Tacos', outcome: 'kept', weeksAgo: 1 },
        { mealTitle: 'Pasta', outcome: 'swapped', weeksAgo: 2 },
      ],
      dietaryFilters: { glutenFree: false, dairyFree: false, nutFree: false },
    });

    expect(res.status).not.toBe(400);
  });
});

describe('POST /api/draft error handling', () => {
  test('handles invalid JSON gracefully', async () => {
    const res = await app.request('/api/draft', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: 'not valid json',
    });

    // Should return an error status, not crash
    expect(res.status).toBeGreaterThanOrEqual(400);
  });

  test('handles empty body', async () => {
    const res = await app.request('/api/draft', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: '',
    });

    expect(res.status).toBeGreaterThanOrEqual(400);
  });
});
