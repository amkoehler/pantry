import { generateObject } from 'ai';
import { openai } from '@ai-sdk/openai';
import { z } from 'zod';

// ---- enums ----
const Cuisine = z.enum([
  'American',
  'Mexican/Tex-Mex',
  'Italian',
  'Asian',
  'Mediterranean',
  'Other',
]);
const Method = z.enum([
  'stovetop',
  'oven',
  'grill',
  'air-fryer',
  'slow-cooker',
  'instant-pot',
  'mixed',
]);
const OnePotOrPan = z.enum(['one-pot', 'one-pan', 'no']);
const Complexity = z.enum(['quick', 'normal', 'long']);
const Seasonality = z.enum(['year-round', 'summer', 'winter']);

// ---- v1.3 meal schema ----
const MealSchema = z
  .object({
    title: z.string().min(3),
    protein: z.string().min(2),
    starch: z.string().nullable(),
    veg_or_fruit: z.array(z.string().min(2)).min(1).max(3),
    cuisine: Cuisine,
    method: Method,
    one_pot_or_pan: OnePotOrPan,
    complexity: Complexity,
    estimated_total_minutes: z.number().int().min(10).max(180),
    seasonality: Seasonality,
    diet_flags: z.object({
      contains_gluten: z.boolean(),
      contains_dairy: z.boolean(),
      contains_nuts: z.boolean(),
    }),
    tags: z.array(z.string().min(2)).min(3).max(7),
  })
  .strict();

type Meal = z.infer<typeof MealSchema>;

const MealsEnvelopeSchema = z
  .object({
    meals: z.array(MealSchema).min(1).max(60),
  })
  .strict();

// ---- prompt ----
const PROMPT_TEMPLATE = await Bun.file(new URL('./seed-prompt.md', import.meta.url)).text();

function buildPrompt(args: {
  n: number;
  maxLong: number;
  glutenFree: boolean;
  dairyFree: boolean;
  nutFree: boolean;
  avoidTitles: string[];
}) {
  const avoidSection =
    args.avoidTitles.length > 0
      ? `## Avoid These Titles\n\nAvoid producing any meals with these titles (exact match) and avoid near-duplicates:\n${args.avoidTitles
          .slice(0, 400)
          .map((t) => `- ${t}`)
          .join('\n')}`
      : '';

  return PROMPT_TEMPLATE.replace(/{{count}}/g, String(args.n))
    .replace(/{{maxLong}}/g, String(args.maxLong))
    .replace(/{{glutenFree}}/g, String(args.glutenFree))
    .replace(/{{dairyFree}}/g, String(args.dairyFree))
    .replace(/{{nutFree}}/g, String(args.nutFree))
    .replace(/{{avoidSection}}/g, avoidSection)
    .trim();
}

// ---- business rules (beyond Zod) ----
function validateMealBusinessRules(m: Meal): string[] {
  const errors: string[] = [];
  const t = m.title.trim();

  const startsOnePot = t.startsWith('One-Pot: ');
  const startsOnePan = t.startsWith('One-Pan: ');

  if (m.one_pot_or_pan === 'one-pot' && !startsOnePot) {
    errors.push(`one-pot missing title prefix`);
  }
  if (m.one_pot_or_pan === 'one-pan' && !startsOnePan) {
    errors.push(`one-pan missing title prefix`);
  }
  if (m.one_pot_or_pan === 'no' && (startsOnePot || startsOnePan)) {
    errors.push(`no but title has prefix`);
  }

  return errors;
}

function isLong(m: Meal) {
  return m.complexity === 'long';
}

// ---- model call ----
async function generateMealsChunk(args: {
  n: number;
  maxLong: number;
  glutenFree: boolean;
  dairyFree: boolean;
  nutFree: boolean;
  avoidTitles: string[];
  modelId: string;
}) {
  const prompt = buildPrompt(args);
  const { object } = await generateObject({
    model: openai(args.modelId),
    schema: MealsEnvelopeSchema,
    schemaName: 'meal_set_v1_3',
    prompt,
    temperature: 0.3,
  });
  return object.meals;
}

// ---- main loop ----
async function main() {
  const TARGET = 130;
  const CHUNK = 5;
  const MAX_LONG_RATIO = 0.2;
  const MODEL = 'gpt-4.1';

  const glutenFree = false;
  const dairyFree = false;
  const nutFree = false;

  console.log(`\n🍽️  Meal Seeder starting...`);
  console.log(`   Target: ${TARGET} meals | Chunk size: ${CHUNK} | Model: ${MODEL}`);
  console.log(
    `   Filters: gluten-free=${glutenFree}, dairy-free=${dairyFree}, nut-free=${nutFree}\n`
  );

  const titleSet = new Set<string>();
  const all: Meal[] = [];

  let round = 0;
  while (all.length < TARGET) {
    round++;
    const remaining = TARGET - all.length;
    const desiredThisRound = Math.min(CHUNK, remaining);

    console.log(`── Round ${round}: requesting ${desiredThisRound} meals...`);

    let addedThisRound = 0;

    // Helper: attempt generation for N, filter valid+new, insert them, return how many added.
    const attempt = async (n: number, label = 'generate') => {
      if (n <= 0) {
        return 0;
      }

      console.log(`   [${label}] Calling API for ${n} meals...`);
      const meals = await generateMealsChunk({
        n,
        maxLong: Math.floor(n * MAX_LONG_RATIO),
        glutenFree,
        dairyFree,
        nutFree,
        avoidTitles: Array.from(titleSet),
        modelId: MODEL,
      });

      console.log(`   [${label}] Received ${meals.length} meals from API`);

      // optional: soft check that batch isn't wildly long-heavy
      const longCount = meals.filter(isLong).length;
      if (longCount > Math.floor(n * MAX_LONG_RATIO) + 1) {
        // not fatal; just a warning
        console.warn(
          `   [${label}] ⚠️  Long meals (${longCount}/${meals.length}) exceeds target ratio`
        );
      }

      let added = 0;
      let skippedRules = 0;
      let skippedDupe = 0;
      for (const m of meals) {
        // business rules
        if (validateMealBusinessRules(m).length > 0) {
          skippedRules++;
          continue;
        }

        const title = m.title.trim();
        if (titleSet.has(title)) {
          skippedDupe++;
          continue;
        }

        titleSet.add(title);

        all.push(m);
        added++;
        if (all.length >= TARGET) {
          break;
        }
      }

      if (skippedRules > 0 || skippedDupe > 0) {
        console.log(
          `   [${label}] Skipped: ${skippedRules} failed rules, ${skippedDupe} duplicates`
        );
      }
      console.log(`   [${label}] ✓ Added ${added} meals`);
      return added;
    };

    // 1) Initial attempt
    addedThisRound += await attempt(desiredThisRound, 'initial');

    // 2) Repair loop: ask for exactly what we're missing, repeat a few times
    let missing = desiredThisRound - addedThisRound;
    let repairs = 0;
    const MAX_REPAIRS = 4;

    while (missing > 0 && repairs < MAX_REPAIRS && all.length < TARGET) {
      repairs++;
      const added = await attempt(missing, `repair-${repairs}`);
      addedThisRound += added;
      missing = desiredThisRound - addedThisRound;

      // If we fail to make progress (e.g., near-duplicates), widen by asking for a few extra
      if (added === 0) {
        const extra = Math.min(5, missing); // small nudge
        console.warn(
          `   ⚠️  No progress on repair #${repairs}, requesting ${missing + extra} to break logjam`
        );
        addedThisRound += await attempt(missing + extra, `repair-${repairs}-extra`);
        missing = desiredThisRound - addedThisRound;
      }
    }

    console.log(
      `── Round ${round} complete: +${addedThisRound} meals (total: ${all.length}/${TARGET})\n`
    );
  }

  await Bun.write('meals_seed_v1_3.json', JSON.stringify(all, null, 2));
  console.log(`✅ Done! Generated ${all.length} meals in ${round} rounds`);
  console.log(`   Output: meals_seed_v1_3.json`);
  console.log(`   Run 'bun scripts/import-meals.ts' to load into SQLite`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
