import { expect, type Page } from "@playwright/test";

import { Given, Then, When } from "./fixtures";

const firstTaskCard = (page: Page) => page.locator('[data-testid^="task-card-"]').first();
type LandingDiagnostics = {
  cfRay: string | null;
  consoleErrors: string[];
  pageErrors: string[];
  responseStatus: number | null;
  routeLabel: string;
  serverHeader: string | null;
  visitedUrl: string;
};

const routeLabel = process.env.E2E_ROUTE_LABEL || (process.env.E2E_PROXY_SERVER ? "proxy" : "direct");
const originForAuth = process.env.E2E_BASE_URL ? new URL(process.env.E2E_BASE_URL).origin : "";
const basicAuthHeader = (() => {
  const username = process.env.E2E_BASIC_AUTH_USER || "";
  const password = process.env.E2E_BASIC_AUTH_PASS || "";
  if (!username || !password) {
    return "";
  }

  return `Basic ${Buffer.from(`${username}:${password}`).toString("base64")}`;
})();
const assertLandingReady = async (page: Page) => {
  await expect(page.locator("#app")).toBeVisible();
  await expect(page.getByTestId("project-title")).toBeVisible();
  await expect(page.getByTestId("workflow-select")).toBeVisible();
  await expect(page.getByTestId("new-task-button")).toBeVisible();
};

Given("the DocuTranslate landing page is open", async ({ page, scenarioState }) => {
  const pageErrors: string[] = [];
  const consoleErrors: string[] = [];
  page.on("pageerror", (error) => {
    pageErrors.push(error.message);
  });
  page.on("console", (message) => {
    if (message.type() === "error") {
      consoleErrors.push(message.text());
    }
  });

  if (originForAuth && basicAuthHeader) {
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

  const response = await page.goto("/", { waitUntil: "networkidle" });
  await page.waitForLoadState("networkidle");
  await assertLandingReady(page);
  const landingState = scenarioState as typeof scenarioState & { landingDiagnostics?: LandingDiagnostics };
  landingState.landingDiagnostics = {
    cfRay: response?.headers()["cf-ray"] ?? null,
    consoleErrors,
    pageErrors,
    responseStatus: response?.status() ?? null,
    routeLabel,
    serverHeader: response?.headers().server ?? null,
    visitedUrl: page.url(),
  };

  expect(response?.status(), `Unexpected landing response status on route "${routeLabel}"`).toBe(200);
  expect(pageErrors, `Unexpected browser errors on route "${routeLabel}": ${pageErrors.join(" | ")}`).toEqual([]);
  expect(consoleErrors, `Unexpected console errors on route "${routeLabel}": ${consoleErrors.join(" | ")}`).toEqual([]);
});

Then("the app title is shown", async ({ page }) => {
  await expect(page).toHaveTitle(/DocuTranslate/i);
  await expect(page.getByTestId("project-title")).toBeVisible();
});

Then("the workflow selector is available", async ({ page }) => {
  await expect(page.getByTestId("workflow-select")).toBeVisible();
});

When("I create a new translation task", async ({ page }) => {
  await page.getByTestId("new-task-button").click();
});

Then("an empty task card is ready for upload", async ({ page }) => {
  const card = firstTaskCard(page);
  await expect(card).toBeVisible();
  await expect(card.getByTestId("task-file-input")).toHaveCount(1);
});
