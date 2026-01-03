import { Database } from 'bun:sqlite';

const jsonPath = process.argv[2] || 'meals_seed_v1_3.json';
const dbPath = process.argv[3] || 'pantry.sqlite';

interface MealJson {
  title: string;
  protein: string;
  starch: string | null;
  veg_or_fruit: string[];
  cuisine: string;
  method: string;
  one_pot_or_pan: string;
  complexity: string;
  estimated_total_minutes: number;
  seasonality: string;
  diet_flags: {
    contains_gluten: boolean;
    contains_dairy: boolean;
    contains_nuts: boolean;
  };
  tags: string[];
}

const meals: MealJson[] = await Bun.file(jsonPath).json();

console.log(`\n📥 Importing ${meals.length} meals from ${jsonPath} into ${dbPath}...\n`);

const db = new Database(dbPath);

// Ensure table exists
db.exec(`
  CREATE TABLE IF NOT EXISTS meals (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL UNIQUE,
    protein TEXT NOT NULL,
    starch TEXT NULL,
    veg_or_fruit TEXT NOT NULL,
    cuisine TEXT NOT NULL,
    method TEXT NOT NULL,
    one_pot_or_pan TEXT NOT NULL,
    complexity TEXT NOT NULL,
    estimated_total_minutes INTEGER NOT NULL,
    seasonality TEXT NOT NULL,
    contains_gluten INTEGER NOT NULL,
    contains_dairy INTEGER NOT NULL,
    contains_nuts INTEGER NOT NULL,
    tags TEXT NOT NULL,
    CHECK (cuisine IN ('American','Mexican/Tex-Mex','Italian','Asian','Mediterranean','Other')),
    CHECK (method IN ('stovetop','oven','grill','air-fryer','slow-cooker','instant-pot','mixed')),
    CHECK (one_pot_or_pan IN ('one-pot','one-pan','no')),
    CHECK (complexity IN ('quick','normal','long')),
    CHECK (seasonality IN ('year-round','summer','winter'))
  );
`);

const insert = db.prepare(`
  INSERT OR IGNORE INTO meals (
    title, protein, starch,
    veg_or_fruit, cuisine, method, one_pot_or_pan, complexity,
    estimated_total_minutes, seasonality,
    contains_gluten, contains_dairy, contains_nuts,
    tags
  ) VALUES (
    $title, $protein, $starch,
    $veg_or_fruit, $cuisine, $method, $one_pot_or_pan, $complexity,
    $estimated_total_minutes, $seasonality,
    $contains_gluten, $contains_dairy, $contains_nuts,
    $tags
  );
`);

let inserted = 0;
let skipped = 0;

for (const m of meals) {
  const result = insert.run({
    $title: m.title.trim(),
    $protein: m.protein,
    $starch: m.starch,
    $veg_or_fruit: JSON.stringify(m.veg_or_fruit),
    $cuisine: m.cuisine,
    $method: m.method,
    $one_pot_or_pan: m.one_pot_or_pan,
    $complexity: m.complexity,
    $estimated_total_minutes: m.estimated_total_minutes,
    $seasonality: m.seasonality,
    $contains_gluten: m.diet_flags.contains_gluten ? 1 : 0,
    $contains_dairy: m.diet_flags.contains_dairy ? 1 : 0,
    $contains_nuts: m.diet_flags.contains_nuts ? 1 : 0,
    $tags: JSON.stringify(m.tags),
  });

  if (result.changes > 0) {
    inserted++;
  } else {
    skipped++;
  }
}

db.close();

console.log(`✅ Imported ${inserted} meals (${skipped} skipped as duplicates)`);
