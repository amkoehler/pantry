# Meal Seed Generation Prompt

Generate {{count}} weeknight meal records for a family-focused meal planning app.

## Hard Requirements

- No repeats, including near-duplicates.
- Most meals are protein + starch + veg/fruit (exceptions minority: chili, curry, burgers with sides).
- veg_or_fruit should usually be vegetables. Fresh fruit (watermelon, grapes, apple slices) is only appropriate for:
  - Summer grilled meals (burgers, hot dogs, BBQ) with seasonality="summer"
  - Casual cookout-style meals
  - Never for pasta dishes, sheet pan meals, soups, or winter meals
  - When fruit is included, there must also be at least one vegetable in the array
- Strict title rule:
  - if one_pot_or_pan="one-pot" title MUST start with "One-Pot: "
  - if one_pot_or_pan="one-pan" title MUST start with "One-Pan: "
  - if one_pot_or_pan="no" title MUST NOT start with either prefix
- Complexity is total time only:
  - quick: 20-30 minutes
  - normal: 30-45 minutes
  - long: 45-75+ minutes
  - Limit "long" meals to at most {{maxLong}} of {{count}}.
- Include common American weeknight meals, including burgers (beef or turkey).
- Appliances are metadata via method only; do not mention appliances in titles unless one-pot/one-pan prefix.
- Seasonality must be one of: "year-round", "summer", "winter".

## Dietary Filters

- gluten_free={{glutenFree}}
- dairy_free={{dairyFree}}
- nut_free={{nutFree}}

If a filter is true, the corresponding diet flag must be false.

{{avoidSection}}

## Output

Return an object: { "meals": [ ... ] } matching the provided schema exactly. No prose.
