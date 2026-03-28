import fs from "node:fs/promises";
import path from "node:path";

import { createBdd, test as base } from "playwright-bdd";

type ScenarioState = {
  downloadedText?: string;
  lastResponseBody?: string;
  lastResponseStatus?: number;
  previewText?: string;
};

type TranslationConfig = {
  apiKey: string;
  baseUrl: string;
  modelId: string;
  targetLanguage: string;
};

type Fixtures = {
  sampleFilePath: string;
  sampleFileText: string;
  sampleFiles: Record<string, string>;
  scenarioState: ScenarioState;
  translationConfig: TranslationConfig;
};

export const test = base.extend<Fixtures>({
  scenarioState: async ({}, use) => {
    await use({});
  },
  sampleFilePath: async ({}, use) => {
    await use(path.join(process.cwd(), "tests/e2e/fixtures/test_sample.txt"));
  },
  sampleFileText: async ({ sampleFilePath }, use) => {
    await use((await fs.readFile(sampleFilePath, "utf8")).trimEnd());
  },
  sampleFiles: async ({ sampleFilePath }, use) => {
    const generatedDir = path.join(process.cwd(), "tests/e2e/fixtures/generated");
    await use({
      txt: sampleFilePath,
      docx: path.join(generatedDir, "sample.docx"),
      docx_rich: path.join(generatedDir, "sample_rich.docx"),
      xlsx: path.join(generatedDir, "sample.xlsx"),
      xlsx_rich: path.join(generatedDir, "sample_rich.xlsx"),
      pptx: path.join(generatedDir, "sample.pptx"),
      pptx_rich: path.join(generatedDir, "sample_rich.pptx"),
      pdf: path.join(generatedDir, "sample.pdf"),
    });
  },
  translationConfig: async ({}, use) => {
    await use({
      apiKey: process.env.E2E_TRANSLATION_API_KEY ?? "",
      baseUrl: process.env.E2E_TRANSLATION_BASE_URL ?? "https://api.deepseek.com/v1",
      modelId: process.env.E2E_TRANSLATION_MODEL_ID ?? "",
      targetLanguage: process.env.E2E_TRANSLATION_TARGET_LANG ?? "Simplified Chinese",
    });
  },
});

export const { Given, When, Then } = createBdd(test);
