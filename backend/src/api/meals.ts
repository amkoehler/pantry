import { Hono } from 'hono';
import { getMeals } from '../db/client';
import { logger } from '../lib/logger';
import type { MealsResponse } from '../types';

export const mealsRoute = new Hono();

mealsRoute.get('/', (c) => {
  const glutenFree = c.req.query('gluten_free') === 'true';
  const dairyFree = c.req.query('dairy_free') === 'true';
  const nutFree = c.req.query('nut_free') === 'true';

  try {
    const meals = getMeals({ glutenFree, dairyFree, nutFree });

    logger.info('meals.fetch', {
      count: meals.length,
      glutenFree,
      dairyFree,
      nutFree,
    });

    const response: MealsResponse = {
      version: new Date().toISOString(),
      meals,
      count: meals.length,
    };

    return c.json(response);
  } catch (error) {
    logger.error('meals.fetch.failed', {
      error: error instanceof Error ? error.message : 'Unknown error',
    });
    return c.json({ error: 'Failed to fetch meals' }, 500);
  }
});
