import { Database } from 'bun:sqlite';
import { join } from 'path';
import type { Meal, MealRow, DietaryFilters } from '../types';

// Database is in backend root, src/db is two levels down
const DB_PATH = join(import.meta.dir, '../../pantry.sqlite');

let db: Database | null = null;

export function getDb(): Database {
  if (!db) {
    db = new Database(DB_PATH);
  }
  return db;
}

export function rowToMeal(row: MealRow): Meal {
  return {
    id: row.id,
    title: row.title,
    protein: row.protein,
    starch: row.starch,
    vegOrFruit: JSON.parse(row.veg_or_fruit),
    cuisine: row.cuisine,
    method: row.method,
    onePotOrPan: row.one_pot_or_pan,
    complexity: row.complexity,
    estimatedTotalMinutes: row.estimated_total_minutes,
    seasonality: row.seasonality,
    containsGluten: row.contains_gluten === 1,
    containsDairy: row.contains_dairy === 1,
    containsNuts: row.contains_nuts === 1,
    tags: JSON.parse(row.tags),
  };
}

export function getMeals(filters: DietaryFilters): Meal[] {
  const db = getDb();

  let query = 'SELECT * FROM meals WHERE 1=1';

  if (filters.glutenFree) {
    query += ' AND contains_gluten = 0';
  }
  if (filters.dairyFree) {
    query += ' AND contains_dairy = 0';
  }
  if (filters.nutFree) {
    query += ' AND contains_nuts = 0';
  }

  query += ' ORDER BY title';

  const rows = db.query<MealRow, []>(query).all();
  return rows.map(rowToMeal);
}

export function getMealById(id: number): Meal | null {
  const db = getDb();
  const row = db.query<MealRow, [number]>('SELECT * FROM meals WHERE id = ?').get(id);
  return row ? rowToMeal(row) : null;
}

export function getMealsByIds(ids: number[]): Meal[] {
  if (ids.length === 0) {
    return [];
  }

  const db = getDb();
  const placeholders = ids.map(() => '?').join(',');
  const rows = db
    .query<MealRow, number[]>(`SELECT * FROM meals WHERE id IN (${placeholders})`)
    .all(...ids);
  return rows.map(rowToMeal);
}
