import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { mealsRoute } from './api/meals';
import { draftRoute } from './api/draft';
import { logger } from './lib/logger';

const app = new Hono();

// Enable CORS for iOS app
app.use('/*', cors());

// Request logging middleware
app.use('/*', async (c, next) => {
  const start = Date.now();
  await next();
  const duration = Date.now() - start;
  logger.info('request', {
    method: c.req.method,
    path: c.req.path,
    status: c.res.status,
    duration,
  });
});

// Health check
app.get('/health', (c) => c.json({ status: 'ok' }));

// API routes
app.route('/api/meals', mealsRoute);
app.route('/api/draft', draftRoute);

// Start server
const port = Number(process.env.PORT) || 3000;

logger.info('server.start', { port });

// Export app for testing
export { app };

export default {
  port,
  fetch: app.fetch,
};
