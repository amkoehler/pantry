// Meal from database
export interface Meal {
  id: number;
  title: string;
  protein: string;
  starch: string | null;
  vegOrFruit: string[];
  cuisine: string;
  method: string;
  onePotOrPan: string;
  complexity: 'quick' | 'normal' | 'long';
  estimatedTotalMinutes: number;
  seasonality: string;
  containsGluten: boolean;
  containsDairy: boolean;
  containsNuts: boolean;
  tags: string[];
}

// Raw DB row (snake_case, integers for booleans)
export interface MealRow {
  id: number;
  title: string;
  protein: string;
  starch: string | null;
  veg_or_fruit: string; // JSON string
  cuisine: string;
  method: string;
  one_pot_or_pan: string;
  complexity: 'quick' | 'normal' | 'long';
  estimated_total_minutes: number;
  seasonality: string;
  contains_gluten: number;
  contains_dairy: number;
  contains_nuts: number;
  tags: string; // JSON string
}

// API request/response types
export interface DietaryFilters {
  glutenFree: boolean;
  dairyFree: boolean;
  nutFree: boolean;
}

export interface MealHistoryItem {
  mealTitle: string;
  outcome: 'kept' | 'swapped' | 'skipped';
  weeksAgo: number;
}

export interface DraftRequest {
  dinnerCount: number;
  busyDays: number[]; // 1=Monday, 7=Sunday
  constraints: string | null;
  mealHistory: MealHistoryItem[];
  dietaryFilters: DietaryFilters;
}

export interface DraftMeal {
  dayOfWeek: number;
  mealId: number | null;
  mealTitle: string;
  reasoning: string | null;
}

export interface DraftResponse {
  meals: DraftMeal[];
}

export interface MealsResponse {
  version: string;
  meals: Meal[];
  count: number;
}
