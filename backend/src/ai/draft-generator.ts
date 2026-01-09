import { generateObject } from 'ai';
import { openai } from '@ai-sdk/openai';
import { z } from 'zod';
import { getMeals } from '../db/client';
import { buildPrompt } from './build-prompt';
import type { DraftRequest, DraftResponse, DraftMeal } from '../types';

// Re-export for backwards compatibility
export { buildPrompt } from './build-prompt';

const MODEL = 'gpt-4.1-mini';

const DraftSchema = z.object({
  meals: z.array(
    z.object({
      dayOfWeek: z.number().min(1).max(7),
      mealId: z.number().nullable(),
      mealTitle: z.string(),
      reasoning: z.string(),
    })
  ),
});

export async function generateDraft(
  request: DraftRequest,
  options?: { verbose?: boolean }
): Promise<DraftResponse> {
  // Fetch available meals with dietary filters applied
  const availableMeals = getMeals(request.dietaryFilters);

  // Build prompt
  const prompt = buildPrompt(request, availableMeals);

  if (options?.verbose) {
    console.log('\n=== PROMPT ===\n');
    console.log(prompt);
    console.log('\n=== END PROMPT ===\n');
  }

  // Generate with AI
  const { object } = await generateObject({
    model: openai(MODEL),
    schema: DraftSchema,
    prompt,
    temperature: 0.3,
  });

  // Validate meal IDs exist and build response
  const mealMap = new Map(availableMeals.map((m) => [m.id, m]));

  const draftMeals: DraftMeal[] = object.meals.map((m) => {
    const dbMeal = m.mealId ? mealMap.get(m.mealId) : null;
    return {
      dayOfWeek: m.dayOfWeek,
      mealId: dbMeal?.id ?? null,
      mealTitle: dbMeal?.title ?? m.mealTitle,
      reasoning: m.reasoning,
    };
  });

  return { meals: draftMeals };
}
