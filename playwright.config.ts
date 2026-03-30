import fs from "node:fs";
import path from "node:path";
import { defineConfig, devices } from "@playwright/test";
import { defineBddConfig } from "playwright-bdd";

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

const testDir = defineBddConfig({
  features: "tests/e2e/features/**/*.feature",
  steps: "tests/e2e/steps/**/*.ts",
  outputDir: "tests/e2e/.features-gen",
});

const defaultHttpsPort = process.env.DOCUTRANSLATE_HTTPS_PORT || "443";
const baseURL = process.env.E2E_BASE_URL || `https://127.0.0.1:${defaultHttpsPort}`;
const basicAuthUser = process.env.E2E_BASIC_AUTH_USER || "";
const basicAuthPass = process.env.E2E_BASIC_AUTH_PASS || "";
const proxyServer = process.env.E2E_PROXY_SERVER || "";
const proxyUsername = process.env.E2E_PROXY_USERNAME || "";
const proxyPassword = process.env.E2E_PROXY_PASSWORD || "";
const proxyBypass = process.env.E2E_PROXY_BYPASS || "";
const routeLabel = process.env.E2E_ROUTE_LABEL || (proxyServer ? "proxy" : "direct");
const httpCredentials = basicAuthUser && basicAuthPass
  ? {
      username: basicAuthUser,
      password: basicAuthPass,
    }
  : undefined;
const proxy = proxyServer
  ? {
      server: proxyServer,
      bypass: proxyBypass || undefined,
      username: proxyUsername || undefined,
      password: proxyPassword || undefined,
    }
  : undefined;

export default defineConfig({
  testDir,
  timeout: 60_000,
  expect: {
    timeout: 15_000,
  },
  workers: 1,
  outputDir: "test-results",
  metadata: {
    baseURL,
    routeLabel,
    basicAuthConfigured: Boolean(httpCredentials),
    proxyEnabled: Boolean(proxy),
    proxyServer: proxy?.server || null,
  },
  reporter: [
    ["list"],
    ["html", { open: "never", outputFolder: "playwright-report" }],
  ],
  use: {
    baseURL,
    headless: true,
    ignoreHTTPSErrors: true,
    httpCredentials,
    proxy,
    screenshot: "only-on-failure",
    trace: "retain-on-failure",
    video: "retain-on-failure",
  },
  projects: [
    {
      name: "chromium",
      use: {
        ...devices["Desktop Chrome"],
      },
    },
  ],
});
