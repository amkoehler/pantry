import { Hono } from 'hono';
import { generateDraft } from '../ai/draft-generator';
import { logger } from '../lib/logger';
import type { DraftRequest, DraftResponse } from '../types';

export const draftRoute = new Hono();

draftRoute.post('/', async (c) => {
  const request = await c.req.json<DraftRequest>();

  // Validate request
  if (!request.dinnerCount || request.dinnerCount < 1 || request.dinnerCount > 7) {
    logger.warn('draft.validation.failed', { reason: 'invalid dinnerCount' });
    return c.json({ error: 'dinnerCount must be between 1 and 7' }, 400);
  }

  if (!request.dietaryFilters) {
    logger.warn('draft.validation.failed', { reason: 'missing dietaryFilters' });
    return c.json({ error: 'dietaryFilters is required' }, 400);
  }

  try {
    logger.info('draft.generate.start', {
      dinnerCount: request.dinnerCount,
      busyDays: request.busyDays?.length ?? 0,
      historyCount: request.mealHistory?.length ?? 0,
    });

    const draft = await generateDraft(request);

    logger.info('draft.generate.success', {
      dinnerCount: request.dinnerCount,
      mealsGenerated: draft.dinners.length,
    });

    return c.json<DraftResponse>(draft);
  } catch (error) {
    logger.error('draft.generate.failed', {
      error: error instanceof Error ? error.message : 'Unknown error',
      dinnerCount: request.dinnerCount,
    });
    return c.json({ error: 'Failed to generate draft' }, 500);
  }
});
