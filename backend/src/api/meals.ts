import { Hono } from 'hono';
import { getMeals } from '../db/client';
import type { MealsResponse } from '../types';

export const mealsRoute = new Hono();

mealsRoute.get('/', (c) => {
  const glutenFree = c.req.query('gluten_free') === 'true';
  const dairyFree = c.req.query('dairy_free') === 'true';
  const nutFree = c.req.query('nut_free') === 'true';

  const meals = getMeals({ glutenFree, dairyFree, nutFree });

  const response: MealsResponse = {
    version: new Date().toISOString(),
    meals,
    count: meals.length,
  };

  return c.json(response);
});
