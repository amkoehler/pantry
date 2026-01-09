import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { mealsRoute } from '../src/api/meals';
import { draftRoute } from '../src/api/draft';

const app = new Hono().basePath('/api');

// Enable CORS for iOS app
app.use('/*', cors());

// Health check
app.get('/health', (c) => c.json({ status: 'ok' }));

// API routes
app.route('/meals', mealsRoute);
app.route('/draft', draftRoute);

export default app;
