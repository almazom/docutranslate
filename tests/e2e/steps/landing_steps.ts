import { expect, type Page } from "@playwright/test";

import { Given, Then, When } from "./fixtures";

const firstTaskCard = (page: Page) => page.locator('[data-testid^="task-card-"]').first();

Given("the DocuTranslate landing page is open", async ({ page }) => {
  await page.goto("/");
  await page.waitForLoadState("networkidle");
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
