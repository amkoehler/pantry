import { Database } from 'bun:sqlite';

interface MealRow {
  id: number;
  title: string;
  protein: string;
  starch: string | null;
  veg_or_fruit: string;
  cuisine: string;
  method: string;
  complexity: string;
  estimated_total_minutes: number;
  tags: string;
}

const dbPath = process.argv[2] || 'pantry.sqlite';
const db = new Database(dbPath);

const meals = db.query<MealRow, []>('SELECT * FROM meals').all();

console.log(`\n🔍 Validating ${meals.length} meals...\n`);

interface Issue {
  id: number;
  title: string;
  reason: string;
  severity: 'high' | 'medium' | 'low';
}

const issues: Issue[] = [];

// --- 1. Near-duplicate detection (simple word overlap) ---
function tokenize(s: string): Set<string> {
  return new Set(
    s
      .toLowerCase()
      .replace(/one-pot:|one-pan:/gi, '')
      .replace(/[^a-z0-9\s]/g, '')
      .split(/\s+/)
      .filter((w) => w.length > 2)
  );
}

function jaccardSimilarity(a: Set<string>, b: Set<string>): number {
  const intersection = new Set([...a].filter((x) => b.has(x)));
  const union = new Set([...a, ...b]);
  return intersection.size / union.size;
}

const titleTokens = meals.map((m) => ({ id: m.id, title: m.title, tokens: tokenize(m.title) }));

for (let i = 0; i < titleTokens.length; i++) {
  for (let j = i + 1; j < titleTokens.length; j++) {
    const tokenA = titleTokens[i]!;
    const tokenB = titleTokens[j]!;
    const sim = jaccardSimilarity(tokenA.tokens, tokenB.tokens);
    if (sim > 0.7) {
      issues.push({
        id: tokenA.id,
        title: tokenA.title,
        reason: `Near-duplicate of "${tokenB.title}" (${(sim * 100).toFixed(0)}% similar)`,
        severity: sim > 0.85 ? 'high' : 'medium',
      });
    }
  }
}

// --- 2. Suspicious/unusual combinations ---
const suspiciousCombos: Array<{ test: (m: MealRow) => boolean; reason: string }> = [
  {
    test: (m) => m.cuisine === 'Asian' && /pasta|spaghetti|penne|rigatoni/i.test(m.starch || ''),
    reason: 'Asian cuisine with Italian pasta',
  },
  {
    test: (m) => m.cuisine === 'Italian' && /rice(?! pilaf)/i.test(m.starch || ''),
    reason: 'Italian cuisine with rice (unusual unless risotto)',
  },
  {
    test: (m) => m.cuisine === 'Mexican/Tex-Mex' && /pasta|noodles/i.test(m.starch || ''),
    reason: 'Mexican cuisine with pasta/noodles',
  },
  {
    test: (m) => /fish|salmon|tilapia|cod|shrimp/i.test(m.protein) && m.method === 'slow-cooker',
    reason: 'Seafood in slow-cooker (usually not ideal)',
  },
  {
    test: (m) => m.complexity === 'quick' && m.estimated_total_minutes > 35,
    reason: 'Marked as "quick" but takes >35 minutes',
  },
  {
    test: (m) => m.complexity === 'long' && m.estimated_total_minutes < 40,
    reason: 'Marked as "long" but takes <40 minutes',
  },
];

for (const m of meals) {
  for (const combo of suspiciousCombos) {
    if (combo.test(m)) {
      issues.push({
        id: m.id,
        title: m.title,
        reason: combo.reason,
        severity: 'medium',
      });
    }
  }
}

// --- 3. Generic/low-quality titles ---
const genericPatterns = [
  /^chicken$/i,
  /^beef$/i,
  /^pork$/i,
  /^fish$/i,
  /dinner$/i,
  /meal$/i,
  /^simple /i,
  /^easy /i,
  /^basic /i,
];

for (const m of meals) {
  const titleWithoutPrefix = m.title.replace(/^One-P(ot|an): /i, '');
  for (const pattern of genericPatterns) {
    if (pattern.test(titleWithoutPrefix)) {
      issues.push({
        id: m.id,
        title: m.title,
        reason: `Generic title pattern: ${pattern}`,
        severity: 'low',
      });
      break;
    }
  }
}

// --- 4. Missing key components ---
for (const m of meals) {
  const veg = JSON.parse(m.veg_or_fruit) as string[];
  const firstVeg = veg[0];
  if (veg.length === 0 || (veg.length === 1 && firstVeg && firstVeg.length < 3)) {
    issues.push({
      id: m.id,
      title: m.title,
      reason: 'Missing or invalid vegetables/fruit',
      severity: 'high',
    });
  }
}

// --- 5. Very short titles ---
for (const m of meals) {
  const titleWithoutPrefix = m.title.replace(/^One-P(ot|an): /i, '');
  if (titleWithoutPrefix.length < 15) {
    issues.push({
      id: m.id,
      title: m.title,
      reason: `Very short title (${titleWithoutPrefix.length} chars)`,
      severity: 'low',
    });
  }
}

// --- Output ---
db.close();

if (issues.length === 0) {
  console.log('✅ No issues found! All meals look good.\n');
} else {
  // Group by severity
  const high = issues.filter((i) => i.severity === 'high');
  const medium = issues.filter((i) => i.severity === 'medium');
  const low = issues.filter((i) => i.severity === 'low');

  console.log(`Found ${issues.length} potential issues:\n`);

  if (high.length > 0) {
    console.log(`🔴 HIGH PRIORITY (${high.length}):`);
    for (const i of high) {
      console.log(`   [ID ${i.id}] "${i.title}"`);
      console.log(`      → ${i.reason}\n`);
    }
  }

  if (medium.length > 0) {
    console.log(`🟡 MEDIUM PRIORITY (${medium.length}):`);
    for (const i of medium) {
      console.log(`   [ID ${i.id}] "${i.title}"`);
      console.log(`      → ${i.reason}\n`);
    }
  }

  if (low.length > 0) {
    console.log(`🟢 LOW PRIORITY (${low.length}):`);
    for (const i of low) {
      console.log(`   [ID ${i.id}] "${i.title}"`);
      console.log(`      → ${i.reason}\n`);
    }
  }

  // Summary
  console.log('─'.repeat(50));
  console.log(`Summary: ${high.length} high, ${medium.length} medium, ${low.length} low`);
  console.log(`Review high-priority items first.\n`);
}
