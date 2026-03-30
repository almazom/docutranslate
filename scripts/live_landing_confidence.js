#!/usr/bin/env node

const fs = require("node:fs");
const path = require("node:path");
const { chromium } = require("playwright");

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

const readProxy = () => {
  const server = process.env.E2E_PROXY_SERVER || "";
  if (!server) {
    return undefined;
  }

  return {
    server,
    bypass: process.env.E2E_PROXY_BYPASS || undefined,
    username: process.env.E2E_PROXY_USERNAME || undefined,
    password: process.env.E2E_PROXY_PASSWORD || undefined,
  };
};

loadLocalEnv();

const baseURL = process.env.E2E_BASE_URL || "https://docutranslate.ru";
const authUser = process.env.E2E_BASIC_AUTH_USER || "";
const authPass = process.env.E2E_BASIC_AUTH_PASS || "";
const proxy = readProxy();
const routeLabel = process.env.E2E_ROUTE_LABEL || (proxy ? "proxy" : "direct");
const originForAuth = new URL(baseURL).origin;
const basicAuthHeader = authUser && authPass
  ? `Basic ${Buffer.from(`${authUser}:${authPass}`).toString("base64")}`
  : "";
const rounds = Math.max(1, Number(process.env.E2E_LANDING_CONFIDENCE_ROUNDS || "10"));
const threshold = Number(process.env.E2E_LANDING_CONFIDENCE_THRESHOLD || "0.95");
const requiredPasses = Math.ceil(rounds * threshold);
const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
const screenshotDir = path.resolve(process.cwd(), "tests/e2e/screenshots/landing-confidence", timestamp);
const reportDir = path.resolve(process.cwd(), "test-results/landing-confidence", timestamp);

fs.mkdirSync(screenshotDir, { recursive: true });
fs.mkdirSync(reportDir, { recursive: true });

const createContextOptions = () => ({
  ignoreHTTPSErrors: true,
  viewport: { width: 1440, height: 900 },
  locale: "en-US",
  httpCredentials: authUser && authPass
    ? {
        username: authUser,
        password: authPass,
      }
    : undefined,
});

const runRound = async (roundIndex) => {
  const browser = await chromium.launch({
    headless: true,
    proxy,
  });
  const context = await browser.newContext(createContextOptions());
  const page = await context.newPage();
  const pageErrors = [];
  const consoleErrors = [];
  const failedRequests = [];
  const badResponses = [];

  page.on("pageerror", (error) => {
    pageErrors.push(error.message);
  });
  page.on("console", (message) => {
    if (message.type() === "error") {
      consoleErrors.push(message.text());
    }
  });
  page.on("requestfailed", (request) => {
    failedRequests.push({
      url: request.url(),
      method: request.method(),
      error: request.failure(),
    });
  });
  page.on("response", (response) => {
    if (response.status() >= 400) {
      badResponses.push({
        url: response.url(),
        method: response.request().method(),
        status: response.status(),
      });
    }
  });
  if (basicAuthHeader) {
    await page.route("**/*", async (route) => {
      if (new URL(route.request().url()).origin !== originForAuth) {
        await route.continue();
        return;
      }

      await route.continue({
        headers: {
          ...route.request().headers(),
          authorization: basicAuthHeader,
        },
      });
    });
  }

  let state = null;
  let status = null;
  let passed = false;
  let failureReason = "";
  let responseHeaders = {};
  const roundLabel = String(roundIndex).padStart(2, "0");
  const screenshotPath = path.join(screenshotDir, `landing-round-${roundLabel}.png`);

  try {
    const response = await page.goto(`${baseURL}/`, { waitUntil: "networkidle", timeout: 60_000 });
    await page.waitForTimeout(1_000);
    status = response ? response.status() : null;
    responseHeaders = response ? response.headers() : {};
    state = await page.evaluate(() => {
      const isVisible = (selector) => {
        const element = document.querySelector(selector);
        if (!element) {
          return false;
        }

        const style = window.getComputedStyle(element);
        const rect = element.getBoundingClientRect();
        return (
          style.display !== "none" &&
          style.visibility !== "hidden" &&
          style.opacity !== "0" &&
          rect.width > 0 &&
          rect.height > 0
        );
      };

      return {
        title: document.title,
        appVisible: isVisible("#app"),
        projectTitleVisible: isVisible("[data-testid='project-title']"),
        workflowSelectVisible: isVisible("[data-testid='workflow-select']"),
        newTaskButtonVisible: isVisible("[data-testid='new-task-button']"),
        bodyTextLength: (document.body.innerText || "").trim().length,
        bodyHtmlLength: document.body.innerHTML.length,
        apiKeyDefaultsSnippet: document.documentElement.outerHTML.includes("const apiKeyDefaults = {};"),
      };
    });

    passed = Boolean(
      status === 200 &&
      state.appVisible &&
      state.projectTitleVisible &&
      state.workflowSelectVisible &&
      state.newTaskButtonVisible &&
      pageErrors.length === 0 &&
      consoleErrors.length === 0 &&
      failedRequests.length === 0 &&
      badResponses.length === 0,
    );

    if (!passed) {
      failureReason = [
        status === 200 ? "" : `status=${status}`,
        state.appVisible ? "" : "app hidden",
        state.projectTitleVisible ? "" : "project-title hidden",
        state.workflowSelectVisible ? "" : "workflow-select hidden",
        state.newTaskButtonVisible ? "" : "new-task-button hidden",
        pageErrors.length ? `pageerror=${pageErrors.join(" | ")}` : "",
        consoleErrors.length ? `console=${consoleErrors.join(" | ")}` : "",
        failedRequests.length ? `requestfailed=${failedRequests.length}` : "",
        badResponses.length ? `badResponses=${badResponses.length}` : "",
      ].filter(Boolean).join("; ");
    }

    fs.mkdirSync(screenshotDir, { recursive: true });
    await page.screenshot({ path: screenshotPath, fullPage: true });
  } finally {
    await context.close();
    await browser.close();
  }

  const roundReport = {
    round: roundIndex,
    baseURL,
    routeLabel,
    authConfigured: Boolean(basicAuthHeader),
    proxyEnabled: Boolean(proxy),
    proxyServer: proxy ? proxy.server : null,
    status,
    passed,
    failureReason,
    state,
    responseHeaders,
    pageErrors,
    consoleErrors,
    failedRequests,
    badResponses,
    screenshotPath,
    checkedAt: new Date().toISOString(),
  };

  fs.mkdirSync(reportDir, { recursive: true });
  fs.writeFileSync(
    path.join(reportDir, `landing-round-${roundLabel}.json`),
    JSON.stringify(roundReport, null, 2),
  );

  return roundReport;
};

const main = async () => {
  const results = [];
  let lastSuccessScreenshot = null;

  for (let round = 1; round <= rounds; round += 1) {
    const result = await runRound(round);
    results.push(result);
    if (result.passed) {
      lastSuccessScreenshot = result.screenshotPath;
    } else {
      break;
    }
  }

  const passCount = results.filter((result) => result.passed).length;
  const totalExecuted = results.length;
  const confidence = totalExecuted === 0 ? 0 : passCount / totalExecuted;
  const success = totalExecuted === rounds && passCount >= requiredPasses;
  const summary = {
    baseURL,
    routeLabel,
    authConfigured: Boolean(basicAuthHeader),
    proxyEnabled: Boolean(proxy),
    proxyServer: proxy ? proxy.server : null,
    roundsRequested: rounds,
    roundsExecuted: totalExecuted,
    requiredPasses,
    passCount,
    threshold,
    confidence,
    success,
    lastSuccessScreenshot,
    reportDir,
    screenshotDir,
    finishedAt: new Date().toISOString(),
  };

  if (success && lastSuccessScreenshot) {
    fs.mkdirSync(screenshotDir, { recursive: true });
    const latestSuccessPath = path.join(screenshotDir, "landing-success-latest.png");
    fs.copyFileSync(lastSuccessScreenshot, latestSuccessPath);
    summary.lastSuccessScreenshot = latestSuccessPath;
  }

  fs.mkdirSync(reportDir, { recursive: true });
  fs.writeFileSync(path.join(reportDir, "summary.json"), JSON.stringify(summary, null, 2));
  console.log(JSON.stringify(summary, null, 2));
  process.exit(success ? 0 : 1);
};

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
