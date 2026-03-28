import fs from "node:fs/promises";

import { expect, type Page } from "@playwright/test";

import { Given, Then, When, test } from "./fixtures";

const firstTaskCard = (page: Page) => page.locator('[data-testid^="task-card-"]').first();
const containsHanScript = /[\u3400-\u9FFF]/u;
const knownPlatformBaseUrls = new Set([
  "https://api.302.ai/v1",
  "https://api.openai.com/v1",
  "https://api.deepseek.com/v1",
  "https://openrouter.ai/api/v1",
  "https://api.minimaxi.com/v1",
  "https://dashscope.aliyuncs.com/compatible-mode/v1",
  "https://ark.cn-beijing.volces.com/api/v3",
  "https://api.siliconflow.cn/v1",
  "https://open.bigmodel.cn/api/paas/v4",
  "https://www.dmxapi.cn/v1",
  "https://www.dmxapi.com/v1",
  "https://ai.juguang.chat/v1",
  "http://127.0.0.1:1234/v1",
  "http://127.0.0.1:11434/v1",
]);

const getSampleTextForKey = (fixtureKey: string): string => {
  switch (fixtureKey) {
    case "txt":
    case "docx":
    case "xlsx":
    case "pptx":
    case "pdf":
      return "DocuTranslate end-to-end sample.";
    case "docx_rich":
      return "Quarterly brief";
    case "xlsx_rich":
      return "Compact office fixture";
    case "pptx_rich":
      return "Launch brief";
    default:
      throw new Error(`Unsupported fixture key: ${fixtureKey}`);
  }
};

const openAiSettings = async (page: Page) => {
  await page.getByTestId("ai-settings-toggle").click();
  const skipTranslateSwitch = page.locator('[data-testid="skip-translate-switch"]:visible').first();
  await expect(skipTranslateSwitch).toBeVisible();
  return skipTranslateSwitch;
};

const getTranslatedPreviewBody = (page: Page) =>
  page.frameLocator('[data-testid="translated-preview-frame"]').locator("body");

const applyRealTranslationConfig = async (
  page: Page,
  translationConfig: { apiKey: string; baseUrl: string; modelId: string; targetLanguage: string },
  workflow: string,
) => {
  await page.getByTestId("workflow-select").selectOption(workflow);
  const skipTranslateSwitch = await openAiSettings(page);
  if (await skipTranslateSwitch.isChecked()) {
    await skipTranslateSwitch.uncheck();
  }

  const targetLanguageSelect = page.locator('[data-testid="target-language-select"]:visible').first();
  if (await targetLanguageSelect.count()) {
    await targetLanguageSelect.selectOption(translationConfig.targetLanguage);
  }

  const platformSelect = page.locator('[data-testid="translator_platform-platform-select"]:visible').first();
  await expect(platformSelect).toBeVisible();
  if (!knownPlatformBaseUrls.has(translationConfig.baseUrl)) {
    await platformSelect.selectOption("custom");
    await page.locator('[data-testid="translator_platform-base-url-input"]:visible').first().fill(translationConfig.baseUrl);
  } else {
    await platformSelect.selectOption(translationConfig.baseUrl);
  }
  await page.locator('[data-testid="translator_platform-api-key-input"]:visible').first().fill(translationConfig.apiKey);
  await page.locator('[data-testid="translator_platform-model-id-input"]:visible').first().fill(translationConfig.modelId);
};

const normalizeText = (value: string) => value.replace(/\s+/g, " ").trim();

When("I configure text workflow with skip translation enabled", async ({ page }) => {
  await page.getByTestId("workflow-select").selectOption("txt");
  const skipTranslateSwitch = await openAiSettings(page);
  if (!(await skipTranslateSwitch.isChecked())) {
    await skipTranslateSwitch.check();
  }
});

When("I configure the {string} workflow for skip translation", async ({ page }, workflow: string) => {
  await page.getByTestId("workflow-select").selectOption(workflow);
  const skipTranslateSwitch = await openAiSettings(page);
  if (!(await skipTranslateSwitch.isChecked())) {
    await skipTranslateSwitch.check();
  }
});

Given("translation API credentials are configured for browser E2E", async ({ translationConfig }) => {
  if (!translationConfig.apiKey || !translationConfig.modelId) {
    test.skip(true, "E2E real translation credentials are not configured.");
  }
});

When("I configure real translation mode for the DeepSeek text workflow", async ({ page, translationConfig }) => {
  await applyRealTranslationConfig(page, translationConfig, "txt");
});

When("I configure real translation mode for the {string} workflow", async ({ page, translationConfig }, workflow: string) => {
  await applyRealTranslationConfig(page, translationConfig, workflow);
});

When("I upload the sample text document", async ({ page, sampleFilePath }) => {
  const card = firstTaskCard(page);
  await card.getByTestId("task-file-input").setInputFiles(sampleFilePath);
  await expect(card.getByTestId("task-filename")).toContainText("test_sample.txt");
});

When("I upload the {string} sample document", async ({ page, sampleFiles }, fixtureKey: string) => {
  const filePath = sampleFiles[fixtureKey];
  if (!filePath) {
    throw new Error(`No sample file configured for fixture key: ${fixtureKey}`);
  }

  const card = firstTaskCard(page);
  await card.getByTestId("task-file-input").setInputFiles(filePath);
  await expect(card.getByTestId("task-filename")).toContainText(pathBasename(filePath));
});

When("I start the active task", async ({ page }) => {
  await firstTaskCard(page).getByTestId("task-action-button").click();
});

Then("the active task finishes with downloadable results", async ({ page }) => {
  const card = firstTaskCard(page);
  await expect(card.getByTestId("task-preview-button")).toBeVisible({ timeout: 30_000 });
  await expect(card.getByTestId("task-download-toggle")).toBeVisible();
  await expect(card.getByTestId("task-status")).toContainText(/成功|success/i);
});

When("I download the translated text result", async ({ page, scenarioState }) => {
  const card = firstTaskCard(page);
  await card.getByTestId("task-download-toggle").click();

  const [download] = await Promise.all([
    page.waitForEvent("download"),
    card.getByTestId("task-download-link-txt").click(),
  ]);

  const downloadPath = await download.path();
  if (!downloadPath) {
    throw new Error("Playwright did not persist a local download path.");
  }

  scenarioState.downloadedText = (await fs.readFile(downloadPath, "utf8")).trimEnd();
});

Then("the downloaded text matches the sample document", async ({ sampleFileText, scenarioState }) => {
  expect(scenarioState.downloadedText).toBe(sampleFileText);
});

Then("the {string} download is available for the active task", async ({ page }, downloadType: string) => {
  const card = firstTaskCard(page);
  await card.getByTestId("task-download-toggle").click();

  const [download] = await Promise.all([
    page.waitForEvent("download"),
    card.getByTestId(`task-download-link-${downloadType}`).click(),
  ]);

  expect(download.suggestedFilename().toLowerCase()).toContain(`.${downloadType}`);
});

When("I open the translated preview", async ({ page }) => {
  await firstTaskCard(page).getByTestId("task-preview-button").click();
});

Then("the translated preview includes the sample document text", async ({ page, sampleFileText }) => {
  const previewFrame = page.frameLocator('[data-testid="translated-preview-frame"]');
  await expect(previewFrame.locator("pre")).toContainText(sampleFileText, { timeout: 30_000 });
});

Then("the translated preview contains text from the {string} sample document", async ({ page }, fixtureKey: string) => {
  await expect(getTranslatedPreviewBody(page)).toContainText(getSampleTextForKey(fixtureKey), { timeout: 30_000 });
});

Then("the translated preview is different from the original sample text", async ({ page, sampleFileText, scenarioState }) => {
  const body = getTranslatedPreviewBody(page);
  await expect(body).toBeVisible({ timeout: 30_000 });
  const previewText = (await body.textContent())?.trim() ?? "";
  scenarioState.previewText = previewText;

  expect(previewText).not.toBe("");
  expect(previewText).not.toContain(sampleFileText);
});

Then(
  "the translated preview for the {string} sample is different from the original text",
  async ({ page, scenarioState }, fixtureKey: string) => {
    const body = getTranslatedPreviewBody(page);
    await expect(body).toBeVisible({ timeout: 30_000 });
    const previewText = (await body.textContent())?.trim() ?? "";
    const sourceText = getSampleTextForKey(fixtureKey);
    scenarioState.previewText = previewText;

    expect(previewText).not.toBe("");
    expect(normalizeText(previewText)).not.toBe(normalizeText(sourceText));
    expect(containsHanScript.test(previewText) || !previewText.includes(sourceText)).toBeTruthy();
  },
);

const pathBasename = (filePath: string) => filePath.split("/").at(-1) ?? filePath;
