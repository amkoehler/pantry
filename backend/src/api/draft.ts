import { Hono } from 'hono';
import { generateDraft } from '../ai/draft-generator';
import type { DraftRequest, DraftResponse } from '../types';

export const draftRoute = new Hono();

draftRoute.post('/', async (c) => {
  const request = await c.req.json<DraftRequest>();

  // Validate request
  if (!request.dinnerCount || request.dinnerCount < 1 || request.dinnerCount > 7) {
    return c.json({ error: 'dinnerCount must be between 1 and 7' }, 400);
  }

  if (!request.dietaryFilters) {
    return c.json({ error: 'dietaryFilters is required' }, 400);
  }

  try {
    const draft = await generateDraft(request);
    return c.json<DraftResponse>(draft);
  } catch (error) {
    console.error('Draft generation error:', error);
    return c.json({ error: 'Failed to generate draft' }, 500);
  }
});
