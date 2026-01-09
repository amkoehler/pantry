# Pantry Backend

## Project Structure

```
backend/
├── api/
│   └── index.ts           # Vercel entry point (re-exports Hono app)
├── src/
│   ├── index.ts           # Hono server entry point (local dev)
│   ├── api/
│   │   ├── meals.ts       # GET /api/meals
│   │   └── draft.ts       # POST /api/draft
│   ├── db/
│   │   └── client.ts      # SQLite client + queries
│   ├── ai/
│   │   └── draft-generator.ts  # GPT-4.1-mini draft generation
│   └── types/
│       └── index.ts
├── scripts/
│   ├── seed-meals.ts      # Generate meals JSON via OpenAI
│   ├── import-meals.ts    # Import JSON to SQLite
│   └── validate-meals.ts  # Check for duplicates/quality issues
├── tests/
│   └── draft.test.ts      # Draft generation tests (calls OpenAI)
├── pantry.sqlite          # 150 curated meals
└── vercel.json            # Vercel config (Bun runtime)
```

## Scripts

```sh
bun run dev        # Start server with hot reload (port 3000)
bun run start      # Start server
bun run seed       # Generate meals JSON (costs $)
bun run import     # Import meals JSON to SQLite
bun run validate   # Check meal quality
bun test tests/draft.test.ts  # Test draft generation (costs $)
```

## API Endpoints

- `GET /api/meals` - Returns meal database
  - Query params: `gluten_free`, `dairy_free`, `nut_free` (all boolean)
- `POST /api/draft` - Generate weekly meal plan
  - Body: `{ dinnerCount, busyDays, constraints, mealHistory, dietaryFilters }`
- `GET /health` - Health check

## Database

SQLite with 150 meals. Schema fields:

- `id`, `title`, `protein`, `starch`, `veg_or_fruit` (JSON)
- `cuisine`, `method`, `one_pot_or_pan`, `complexity`, `seasonality`
- `estimated_total_minutes`
- `contains_gluten`, `contains_dairy`, `contains_nuts` (0/1)
- `tags` (JSON)

## AI

Uses `gpt-4.1-mini` via Vercel AI SDK for draft generation. Prompt in `src/ai/draft-generator.ts`.

## Deployment

Hosted on Vercel with Bun runtime. SQLite is bundled with the serverless function (read-only).

```sh
bunx vercel --prod   # Deploy to production
```

- Production URL: `https://backend-six-silk-34.vercel.app`
- Config: `vercel.json` (Bun runtime, includes `pantry.sqlite`)
- Entry point: `api/index.ts` (Vercel-specific, re-exports Hono app)

---

Default to using Bun instead of Node.js.

- Use `bun <file>` instead of `node <file>` or `ts-node <file>`
- Use `bun test` instead of `jest` or `vitest`
- Use `bun build <file.html|file.ts|file.css>` instead of `webpack` or `esbuild`
- Use `bun install` instead of `npm install` or `yarn install` or `pnpm install`
- Use `bun run <script>` instead of `npm run <script>` or `yarn run <script>` or `pnpm run <script>`
- Use `bunx <package> <command>` instead of `npx <package> <command>`
- Bun automatically loads .env, so don't use dotenv.

## APIs

- `Bun.serve()` supports WebSockets, HTTPS, and routes. Don't use `express`.
- `bun:sqlite` for SQLite. Don't use `better-sqlite3`.
- `Bun.redis` for Redis. Don't use `ioredis`.
- `Bun.sql` for Postgres. Don't use `pg` or `postgres.js`.
- `WebSocket` is built-in. Don't use `ws`.
- Prefer `Bun.file` over `node:fs`'s readFile/writeFile
- Bun.$`ls` instead of execa.

## Testing

Use `bun test` to run tests.

```ts#index.test.ts
import { test, expect } from "bun:test";

test("hello world", () => {
  expect(1).toBe(1);
});
```

## Linting & Formatting

Always run linting and formatting after making code changes:

```sh
bun run lint:fix   # ESLint - fixes curly braces, unused vars, etc.
bun run format     # Prettier - single quotes, 2 spaces
```

For CI/checking without auto-fix:

```sh
bun run lint
bun run format:check
```

## Frontend

Use HTML imports with `Bun.serve()`. Don't use `vite`. HTML imports fully support React, CSS, Tailwind.

Server:

```ts#index.ts
import index from "./index.html"

Bun.serve({
  routes: {
    "/": index,
    "/api/users/:id": {
      GET: (req) => {
        return new Response(JSON.stringify({ id: req.params.id }));
      },
    },
  },
  // optional websocket support
  websocket: {
    open: (ws) => {
      ws.send("Hello, world!");
    },
    message: (ws, message) => {
      ws.send(message);
    },
    close: (ws) => {
      // handle close
    }
  },
  development: {
    hmr: true,
    console: true,
  }
})
```

HTML files can import .tsx, .jsx or .js files directly and Bun's bundler will transpile & bundle automatically. `<link>` tags can point to stylesheets and Bun's CSS bundler will bundle.

```html#index.html
<html>
  <body>
    <h1>Hello, world!</h1>
    <script type="module" src="./frontend.tsx"></script>
  </body>
</html>
```

With the following `frontend.tsx`:

```tsx#frontend.tsx
import React from "react";
import { createRoot } from "react-dom/client";

// import .css files directly and it works
import './index.css';

const root = createRoot(document.body);

export default function Frontend() {
  return <h1>Hello, world!</h1>;
}

root.render(<Frontend />);
```

Then, run index.ts

```sh
bun --hot ./index.ts
```

For more information, read the Bun API docs in `node_modules/bun-types/docs/**.mdx`.
