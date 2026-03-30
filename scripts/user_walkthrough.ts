import * as fs from "node:fs";
import { chromium, type Page } from "playwright";
import * as path from "path";

const loadLocalEnv = () => {
  const envPath = path.resolve(process.cwd(), ".env");
  if (!fs.existsSync(envPath)) {
    return;
  }

  for (const rawLine of fs.readFileSync(envPath, "utf8").split(/\r?\n/u)) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) {
      continue;
    }

    const separatorIndex = line.indexOf("=");
    if (separatorIndex <= 0) {
      continue;
    }

    const key = line.slice(0, separatorIndex).trim();
    let value = line.slice(separatorIndex + 1);
    if (
      (value.startsWith("\"") && value.endsWith("\"")) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }

    if (process.env[key] === undefined) {
      process.env[key] = value;
    }
  }
};

loadLocalEnv();

const BASE_URL = process.env.E2E_BASE_URL || "https://docutranslate.ru";
const BASIC_AUTH_USER = process.env.E2E_BASIC_AUTH_USER || "";
const BASIC_AUTH_PASS = process.env.E2E_BASIC_AUTH_PASS || "";
const SHOT_DIR = path.resolve(__dirname, "../tests/e2e/screenshots/user-walkthrough");

async function shot(page: Page, name: string) {
  const file = path.join(SHOT_DIR, `${name}.png`);
  await page.screenshot({ path: file, fullPage: true });
  console.log(`📸  ${name}  →  ${file}`);
}

async function main() {
  const browser = await chromium.launch({ headless: true });
  const ctx = await browser.newContext({
    ignoreHTTPSErrors: true,
    viewport: { width: 1440, height: 900 },
    locale: "en-US",
    httpCredentials: BASIC_AUTH_USER && BASIC_AUTH_PASS
      ? {
          username: BASIC_AUTH_USER,
          password: BASIC_AUTH_PASS,
        }
      : undefined,
  });
  const page = await ctx.newPage();

  // ── 1. Landing page ──────────────────────────────────────
  console.log("\n🌐  Opening landing page …");
  await page.goto(BASE_URL + "/", { waitUntil: "networkidle" });
  await shot(page, "01-landing");

  // ── 2. Check the title and project name ──────────────────
  const title = await page.title();
  console.log(`   Title: ${title}`);

  const projectTitle = page.getByTestId("project-title");
  if (await projectTitle.isVisible()) {
    const text = await projectTitle.textContent();
    console.log(`   Project: ${text}`);
  }

  // ── 3. Workflow selector ─────────────────────────────────
  const workflowSelect = page.getByTestId("workflow-select");
  if (await workflowSelect.isVisible()) {
    const currentWorkflow = await workflowSelect.inputValue();
    console.log(`   Workflow: ${currentWorkflow}`);
    // Cycle through workflows for screenshots
    await workflowSelect.selectOption("docx");
    await page.waitForTimeout(300);
    await shot(page, "02-workflow-docx");

    await workflowSelect.selectOption("xlsx");
    await page.waitForTimeout(300);
    await shot(page, "03-workflow-xlsx");

    // Reset to markdown
    await workflowSelect.selectOption("markdown_based");
    await page.waitForTimeout(300);
  }

  // ── 4. Open AI Settings panel ────────────────────────────
  console.log("\n⚙️  Opening AI Settings …");
  const aiToggle = page.getByTestId("ai-settings-toggle");
  if (await aiToggle.isVisible()) {
    await aiToggle.click();
    await page.waitForTimeout(500);
    await shot(page, "04-ai-settings-panel");
  }

  // Check platform selector
  const platformSelect = page.locator("[data-testid$='-platform-select']").first();
  if (await platformSelect.isVisible()) {
    const platforms = await platformSelect.locator("option").allTextContents();
    console.log(`   Platforms: ${platforms.join(", ")}`);
  }

  // Close accordion
  await aiToggle.click();
  await page.waitForTimeout(300);

  // ── 5. Create a new task ─────────────────────────────────
  console.log("\n➕  Creating a new translation task …");
  const newTaskBtn = page.getByTestId("new-task-button");
  if (await newTaskBtn.isVisible()) {
    await newTaskBtn.click();
    await page.waitForTimeout(500);
    await shot(page, "05-new-task-created");
  }

  // ── 6. Upload a test file ────────────────────────────────
  console.log("\n📁  Uploading a test file …");
  const fileInput = page.locator("[data-testid^='task-file-input-']").first();
  const sampleFile = path.resolve(__dirname, "../tests/e2e/fixtures/test_sample.txt");
  if (await fileInput.isVisible() || await fileInput.count() > 0) {
    await fileInput.setInputFiles(sampleFile);
    await page.waitForTimeout(800);

    // Check filename shown
    const filenameEl = page.locator("[data-testid^='task-filename-']").first();
    if (await filenameEl.isVisible()) {
      const fn = await filenameEl.textContent();
      console.log(`   Uploaded: ${fn}`);
    }
    await shot(page, "06-file-uploaded");
  }

  // ── 7. Task card details ─────────────────────────────────
  const taskCard = page.locator("[data-testid^='task-card-']").first();
  if (await taskCard.isVisible()) {
    const statusEl = taskCard.locator("[data-testid^='task-status-']").first();
    if (await statusEl.isVisible()) {
      const status = await statusEl.textContent();
      console.log(`   Status: ${status}`);
    }
  }

  // ── 8. Check the target language selector ────────────────
  const langSelect = page.getByTestId("target-language-select");
  if (await langSelect.isVisible()) {
    const langs = await langSelect.locator("option").allTextContents();
    console.log(`\n🌐  Target languages: ${langs.join(", ")}`);
    await shot(page, "07-target-languages");
  }

  // ── 9. Scroll through full page ──────────────────────────
  console.log("\n📜  Full page scroll …");
  await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
  await page.waitForTimeout(500);
  await shot(page, "08-page-bottom");

  await page.evaluate(() => window.scrollTo(0, 0));
  await page.waitForTimeout(300);

  // ── 10. Swagger /docs ────────────────────────────────────
  console.log("\n📖  Opening Swagger docs …");
  await page.goto(BASE_URL + "/docs", { waitUntil: "networkidle" });
  await page.waitForTimeout(1000);
  await shot(page, "09-swagger-docs");

  // ── 11. Health endpoint ──────────────────────────────────
  console.log("\n❤️  Checking health endpoint …");
  await page.goto(BASE_URL + "/health", { waitUntil: "networkidle" });
  const healthText = await page.textContent("body");
  console.log(`   Health: ${healthText}`);
  await shot(page, "10-health-endpoint");

  // ── Done ──────────────────────────────────────────────────
  await browser.close();
  console.log("\n✅  User walkthrough complete! Screenshots saved to tests/e2e/screenshots/user-walkthrough/");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
