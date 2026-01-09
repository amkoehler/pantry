import { describe, test, expect, mock } from 'bun:test';

// Mock generateDraft BEFORE importing app to prevent real OpenAI calls
mock.module('../../src/ai/draft-generator', () => ({
  generateDraft: async () => ({
    meals: [{ dayOfWeek: 1, mealId: 1, mealTitle: 'Mock Meal', reasoning: 'Mocked for testing' }],
  }),
  buildPrompt: () => 'mock prompt',
}));

// Import app AFTER mock is set up
const { app } = await import('../../src/index');

// Response types for type-safe JSON parsing
interface ErrorResponse {
  error: string;
}

interface DraftResponse {
  meals: Array<{
    dayOfWeek: number;
    mealId: number | null;
    mealTitle: string;
    reasoning: string;
  }>;
}

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
    const json = (await res.json()) as ErrorResponse;

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
    const json = (await res.json()) as ErrorResponse;

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
    const json = (await res.json()) as ErrorResponse;

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
    const json = (await res.json()) as ErrorResponse;

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
    const json = (await res.json()) as ErrorResponse;

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
    const json = (await res.json()) as ErrorResponse;

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

    // With mock, should succeed with 200
    expect(res.status).toBe(200);
  });

  test('accepts dinnerCount of 7 (maximum)', async () => {
    const res = await postDraft({
      dinnerCount: 7,
      busyDays: [],
      constraints: null,
      mealHistory: [],
      dietaryFilters: { glutenFree: false, dairyFree: false, nutFree: false },
    });

    expect(res.status).toBe(200);
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

      expect(res.status).toBe(200);
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

    expect(res.status).toBe(200);
  });

  test('accepts request with busy days', async () => {
    const res = await postDraft({
      dinnerCount: 5,
      busyDays: [1, 3, 5],
      constraints: null,
      mealHistory: [],
      dietaryFilters: { glutenFree: false, dairyFree: false, nutFree: false },
    });

    expect(res.status).toBe(200);
  });

  test('accepts request with constraints', async () => {
    const res = await postDraft({
      dinnerCount: 4,
      busyDays: [],
      constraints: 'chicken in the freezer',
      mealHistory: [],
      dietaryFilters: { glutenFree: false, dairyFree: false, nutFree: false },
    });

    expect(res.status).toBe(200);
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

    expect(res.status).toBe(200);
  });

  test('returns mocked draft response structure', async () => {
    const res = await postDraft({
      dinnerCount: 3,
      busyDays: [],
      constraints: null,
      mealHistory: [],
      dietaryFilters: { glutenFree: false, dairyFree: false, nutFree: false },
    });
    const json = (await res.json()) as DraftResponse;

    expect(res.status).toBe(200);
    expect(json).toHaveProperty('meals');
    expect(Array.isArray(json.meals)).toBe(true);
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
