import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { mealsRoute } from './api/meals';
import { draftRoute } from './api/draft';

const app = new Hono();

// Enable CORS for iOS app
app.use('/*', cors());

// Health check
app.get('/health', (c) => c.json({ status: 'ok' }));

// API routes
app.route('/api/meals', mealsRoute);
app.route('/api/draft', draftRoute);

// Start server
const port = Number(process.env.PORT) || 3000;

console.log(`Server running on http://localhost:${port}`);

// Export app for testing
export { app };

export default {
  port,
  fetch: app.fetch,
};
