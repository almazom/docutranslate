import { chromium, type Page, type BrowserContext } from "playwright";
import * as path from "path";
import * as fs from "fs";

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

const API_KEY = process.env.TRANSLATION_API_KEY || "sk-5f90b459a99a41469f866aa94eaf079a";
const MODEL_ID = process.env.TRANSLATION_MODEL_ID || "deepseek-chat";
const PLATFORM = "https://api.deepseek.com/v1";

const FIXTURES = [
  { name: "txt",  path: path.resolve(__dirname, "../tests/e2e/fixtures/test_sample.txt"), workflow: "markdown_based" },
  { name: "docx", path: path.resolve(__dirname, "../tests/e2e/fixtures/generated/sample.docx"), workflow: "docx" },
  { name: "xlsx", path: path.resolve(__dirname, "../tests/e2e/fixtures/generated/sample.xlsx"), workflow: "xlsx" },
  { name: "pptx", path: path.resolve(__dirname, "../tests/e2e/fixtures/generated/sample.pptx"), workflow: "markdown_based" },
];

function log(phase: string, msg: string) {
  const ts = new Date().toISOString().slice(11, 19);
  console.log(`[${ts}] ${phase}  ${msg}`);
}

async function shot(page: Page, name: string) {
  const file = path.join(SHOT_DIR, `${name}.png`);
  await page.screenshot({ path: file, fullPage: true });
  log("📸", `${name}.png`);
  return file;
}

async function sendTG(msg: string) {
  try { await execAsync(`t2me send --markdown "${msg.replace(/"/g, '\\"')}"`); } catch {}
}

async function sendTGFile(f: string, caption: string) {
  try { await execAsync(`t2me send --file "${f}" --caption "${caption.replace(/"/g, '\\"')}"`); } catch {}
}

function execAsync(cmd: string): Promise<string> {
  const { exec } = require("child_process");
  return new Promise((res, rej) => exec(cmd, (e: any, o: string) => e ? rej(e) : res(o)));
}

async function configureAI(page: Page) {
  log("⚙️", "Opening AI settings panel …");
  const aiToggle = page.getByTestId("ai-settings-toggle");
  await aiToggle.click();
  await page.waitForTimeout(500);

  // Select DeepSeek platform
  const platformSelect = page.getByTestId("translator_platform-platform-select");
  await platformSelect.selectOption(PLATFORM);
  await page.waitForTimeout(300);
  log("🔧", `Platform set to DeepSeek (${PLATFORM})`);

  // Fill API key
  const apiKeyInput = page.getByTestId("translator_platform-api-key-input");
  await apiKeyInput.fill(API_KEY);
  await page.waitForTimeout(200);
  log("🔑", "API key filled");

  // Fill model ID
  const modelIdInput = page.getByTestId("translator_platform-model-id-input");
  await modelIdInput.fill(MODEL_ID);
  await page.waitForTimeout(200);
  log("🤖", `Model set to ${MODEL_ID}`);

  await shot(page, "00-ai-configured");
  await sendTGFile(path.join(SHOT_DIR, "00-ai-configured.png"), "⚙️ AI Settings: DeepSeek configured");
  await sendTG("✅ *AI settings configured*\nPlatform: DeepSeek\nModel: `deepseek-chat`");

  // Close panel
  await aiToggle.click();
  await page.waitForTimeout(300);
}

async function waitForTaskDone(page: Page, label: string, timeoutMs = 300_000): Promise<{ status: string; downloads: boolean }> {
  const card = page.locator("[data-testid^='task-card-']").first();
  const statusEl = card.locator("[data-testid^='task-status-']").first();
  const start = Date.now();
  let lastSent = 0;

  while (Date.now() - start < timeoutMs) {
    const text = (await statusEl.textContent() ?? "").trim();
    
    // Success states
    if (text.includes("completed") || text.includes("完成") || text.includes("done") || text.includes("success") || text.includes("翻译完成")) {
      const hasDownloads = await card.locator("[data-testid^='task-download-toggle-']").first().isVisible().catch(() => false);
      return { status: text, downloads: hasDownloads };
    }
    // Failure states
    if (text.includes("failed") || text.includes("error") || text.includes("失败") || text.includes("Please check") || text.includes("fill in")) {
      return { status: text, downloads: false };
    }

    // Progress report every 15s
    const elapsed = Math.round((Date.now() - start) / 1000);
    if (elapsed - lastSent >= 15) {
      lastSent = elapsed;
      log("⏳", `[${label}] ${elapsed}s — status: "${text}"`);
    }
    await page.waitForTimeout(2000);
  }
  const text = (await statusEl.textContent() ?? "").trim();
  return { status: `TIMEOUT (${timeoutMs/1000}s) last="${text}"`, downloads: false };
}

async function runTranslation(ctx: BrowserContext, fixture: typeof FIXTURES[0]) {
  const page = await ctx.newPage();
  const tag = fixture.name;

  log("🌐", `[${tag}] Opening UI …`);
  await page.goto(BASE_URL + "/", { waitUntil: "networkidle" });
  await shot(page, `RT-${tag}-01-landing`);

  // Configure AI
  await configureAI(page);

  // Select workflow
  const wf = page.getByTestId("workflow-select");
  await wf.selectOption(fixture.workflow);
  await page.waitForTimeout(300);
  log("⚙️", `[${tag}] Workflow: ${fixture.workflow}`);
  await shot(page, `RT-${tag}-02-workflow`);

  // Create task
  await page.getByTestId("new-task-button").click();
  await page.waitForTimeout(500);
  log("➕", `[${tag}] Task card created`);
  await shot(page, `RT-${tag}-03-task-created`);

  // Upload file
  const fileInput = page.locator("[data-testid^='task-file-input-']").first();
  await fileInput.setInputFiles(fixture.path);
  await page.waitForTimeout(800);
  const fn = await page.locator("[data-testid^='task-filename-']").first().textContent().catch(() => "?");
  log("📁", `[${tag}] Uploaded: ${fn?.trim()}`);
  await shot(page, `RT-${tag}-04-file-uploaded`);
  await sendTGFile(path.join(SHOT_DIR, `RT-${tag}-04-file-uploaded.png`), `📁 ${tag.toUpperCase()} uploaded: ${path.basename(fixture.path)}`);

  // Start translation
  const actionBtn = page.locator("[data-testid^='task-action-button-']").first();
  log("🚀", `[${tag}] Starting translation …`);
  await actionBtn.click();
  await page.waitForTimeout(1500);
  await shot(page, `RT-${tag}-05-translation-started`);
  await sendTG(`🔄 *${tag.toUpperCase()} translation started …*`);

  // Wait for completion
  const result = await waitForTaskDone(page, tag);
  const ok = result.downloads;
  log(ok ? "✅" : "❌", `[${tag}] ${result.status}`);
  await shot(page, `RT-${tag}-06-${ok ? "done" : "failed"}`);
  await sendTGFile(path.join(SHOT_DIR, `RT-${tag}-06-${ok ? "done" : "failed"}.png`),
    `${ok ? "✅" : "❌"} ${tag.toUpperCase()} ${ok ? "translation complete!" : "FAILED"} — ${result.status.slice(0, 60)}`);

  // Expand downloads if available
  if (ok) {
    const dlToggle = page.locator("[data-testid^='task-download-toggle-']").first();
    await dlToggle.click();
    await page.waitForTimeout(500);
    await shot(page, `RT-${tag}-07-downloads`);
    await sendTGFile(path.join(SHOT_DIR, `RT-${tag}-07-downloads.png`), `📦 ${tag.toUpperCase()} download options`);
  }

  await page.close();
  return { format: tag, workflow: fixture.workflow, fixture: path.basename(fixture.path), ...result };
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

  log("🎬", "Real Translation Walkthrough v2");
  log("🔗", BASE_URL);
  log("🤖", `DeepSeek ${MODEL_ID}`);
  log("📂", FIXTURES.map(f => `${f.name}=${path.basename(f.path)}`).join(", "));

  await sendTG("*🎬 Real Translation v2 — starting*\n\nDeepSeek `deepseek-chat`\nFormats: TXT → DOCX → XLSX → PPTX\nWill configure AI settings in UI first.");

  const results: any[] = [];

  for (const fixture of FIXTURES) {
    try {
      const r = await runTranslation(ctx, fixture);
      results.push(r);
    } catch (e: any) {
      log("💥", `${fixture.name} crashed: ${e.message}`);
      results.push({ format: fixture.name, workflow: fixture.workflow, fixture: path.basename(fixture.path), status: `CRASH: ${e.message}`, downloads: false });
      await sendTG(`💥 *${fixture.name.toUpperCase()} crashed:* ${e.message}`);
    }
  }

  const passCount = results.filter(r => r.downloads).length;
  const summary = [
    "*🏁 Real Translation Walkthrough Complete*",
    "",
    `*${passCount}/${results.length} formats translated successfully*`,
    "",
    ...results.map(r => `${r.downloads ? "✅" : "❌"} *${r.format.toUpperCase()}* (${r.workflow}): ${r.status}`),
    "",
    "API: DeepSeek `deepseek-chat`",
  ].join("\n");

  log("🏁", `${passCount}/${results.length} passed`);
  await sendTG(summary);

  // Write diagnostics
  const diagPath = path.join(SHOT_DIR, "diagnostics.json");
  fs.writeFileSync(diagPath, JSON.stringify({ base_url: BASE_URL, api: "deepseek-chat", results, total: results.length, passed: passCount, failed: results.length - passCount, ts: new Date().toISOString() }, null, 2));

  await browser.close();
}

main().catch((e) => { console.error("FATAL:", e); process.exit(1); });
