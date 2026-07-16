// @ts-check
// End-to-end tests for the public site (dictio.js behaviour).
// The app serves fixture data via FakeMongo — see test/e2e/app.ru.
const { test, expect } = require("@playwright/test");
const path = require("path");

// Hermetic runs: serve jQuery locally (same file the SRI hash expects) and
// block analytics, so flaky CDNs can't fail or slow down tests.
test.beforeEach(async ({ page }) => {
  await page.route("**://code.jquery.com/jquery-3.7.0.min.js*", (route) =>
    route.fulfill({
      path: path.join(__dirname, "vendor", "jquery-3.7.0.min.js"),
      contentType: "application/javascript",
    })
  );
  await page.route("**://www.googletagmanager.com/**", (route) => route.abort());
});

// fixture entries (test/fixtures/entries.json)
const WRITE_ENTRY = { url: "/cs/show/3881", lemma: "vosk", examples: 4 };
const SIGN_ENTRY = { url: "/czj/show/10000", video: "A_velryba1.mp4" };

/** Fail the test on any uncaught JS error on the page. */
function trackPageErrors(page) {
  const errors = [];
  page.on("pageerror", (err) => errors.push(err.message));
  return errors;
}

test("homepage renders with entry counts and no JS errors", async ({ page }) => {
  const errors = trackPageErrors(page);
  await page.goto("/");
  await expect(page).toHaveTitle(/Dictio/);
  await expect(page.locator(".translation__count-desktop")).toContainText(/\d/);
  expect(errors).toEqual([]);
});

test("public pages never load edit-tools.js", async ({ page }) => {
  const editToolRequests = [];
  page.on("request", (req) => {
    if (req.url().includes("edit-tools")) editToolRequests.push(req.url());
  });
  for (const url of ["/", WRITE_ENTRY.url, SIGN_ENTRY.url]) {
    await page.goto(url);
  }
  expect(editToolRequests).toEqual([]);
});

test("write entry page collapses extra examples", async ({ page }) => {
  const errors = trackPageErrors(page);
  await page.goto(WRITE_ENTRY.url);
  await expect(page.locator("h2, h1").filter({ hasText: WRITE_ENTRY.lemma }).first()).toBeVisible();

  // 4 examples in the fixture: JS hides all but the first two
  await expect(page.locator("p.example:visible")).toHaveCount(2);
  const more = page.locator(".more-example:visible");
  await expect(more).toHaveCount(1);

  await more.click();
  await expect(page.locator("p.example:visible")).toHaveCount(WRITE_ENTRY.examples);
  await expect(page.locator(".more-example:visible")).toHaveCount(0);
  expect(errors).toEqual([]);
});

test("sign entry page switches between front and side video", async ({ page }) => {
  const errors = trackPageErrors(page);
  await page.goto(SIGN_ENTRY.url);
  await expect(page.locator(".video-top .video-front")).toBeVisible();

  await page.locator(".btn-side").first().click();
  await expect(page.locator(".video-top .video-side")).toBeVisible();
  await expect(page.locator(".video-top .video-front")).toBeHidden();

  await page.locator(".btn-front").first().click();
  await expect(page.locator(".video-top .video-front")).toBeVisible();
  await expect(page.locator(".video-top .video-side")).toBeHidden();
  expect(errors).toEqual([]);
});

test("sign keyboard: select keys, show images, reset", async ({ page }) => {
  const errors = trackPageErrors(page);
  await page.goto("/");

  // keyboard only appears for sign dictionaries; pick czj as search source
  await page.evaluate(() => {
    // eslint-disable-next-line no-undef
    $(".search-alt__wrap .translate-from").val("czj");
  });
  await page.locator("#expression_search").focus();
  const keyboard = page.locator(".search-alt__wrapper .keyboard");
  await expect(keyboard).toBeVisible();

  // click a hand key: image appears, text input hides
  await keyboard.locator(".buttons-hand button.js-key[data-hand]").first().click();
  await expect(page.locator(".keyboard-target .keyboard-images img")).toHaveCount(1);
  await expect(page.locator("#expression_search")).toBeHidden();

  // clicking the selected image deselects the key again
  await page.locator(".keyboard-target .keyboard-images img").click();
  await expect(page.locator(".keyboard-target .keyboard-images img")).toHaveCount(0);
  await expect(page.locator("#expression_search")).toBeVisible();

  // select a key again, then reset via backspace key
  await keyboard.locator(".buttons-hand button.js-key[data-hand]").first().click();
  await expect(page.locator(".keyboard-target .keyboard-images img")).toHaveCount(1);
  await keyboard.locator(".buttons-hand .js-key-back").click();
  // back key hides the image strip (images stay in the DOM) and clears selection
  await expect(page.locator(".keyboard-target .keyboard-images")).toBeHidden();
  await expect(page.locator("#expression_search")).toBeVisible();
  await expect(page.locator(".js-key-selected")).toHaveCount(0);
  expect(errors).toEqual([]);
});

test("entry pages load without JS errors", async ({ page }) => {
  const errors = trackPageErrors(page);
  await page.goto(WRITE_ENTRY.url);
  await page.goto(SIGN_ENTRY.url);
  await page.goto("/cs/show/99999999"); // notfound page
  expect(errors).toEqual([]);
});
