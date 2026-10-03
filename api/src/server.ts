import 'dotenv/config';

import { createApp } from './app.js';

// Validated with zod in S1-2.
const port = Number(process.env.PORT ?? 3000);

createApp().listen(port, () => {
  console.log(`marlix api listening on http://localhost:${port}`);
});
