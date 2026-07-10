// @ts-check
const path = require("path");
// browsers live on /data (repo-local) because /home is nearly full
process.env.PLAYWRIGHT_BROWSERS_PATH =
  process.env.PLAYWRIGHT_BROWSERS_PATH || path.join(__dirname, ".playwright-browsers");
const { defineConfig, devices } = require("@playwright/test");

module.exports = defineConfig({
  testDir: "test/e2e",
  timeout: 30000,
  retries: 0,
  use: {
    baseURL: "http://127.0.0.1:9393",
  },
  projects: [
    { name: "chromium", use: { ...devices["Desktop Chrome"] } },
  ],
  webServer: {
    command: "bundle exec rackup test/e2e/app.ru -p 9393 -o 127.0.0.1",
    url: "http://127.0.0.1:9393/",
    reuseExistingServer: true,
    timeout: 30000,
  },
});
