import { expect } from "@playwright/test";

import { Then, When } from "./fixtures";

When("I request the health endpoint", async ({ request, scenarioState }) => {
  const response = await request.get("/health", { failOnStatusCode: false });
  scenarioState.lastResponseStatus = response.status();
  scenarioState.lastResponseBody = await response.text();
});

When("I request the docs endpoint", async ({ request, scenarioState }) => {
  const response = await request.get("/docs", { failOnStatusCode: false });
  scenarioState.lastResponseStatus = response.status();
  scenarioState.lastResponseBody = await response.text();
});

Then("the last API response status should be {int}", async ({ scenarioState }, expectedStatus: number) => {
  expect(scenarioState.lastResponseStatus).toBe(expectedStatus);
});

Then("the health response reports the running version", async ({ scenarioState }) => {
  const payload = JSON.parse(scenarioState.lastResponseBody ?? "{}") as {
    status?: string;
    version?: string;
  };

  expect(payload.status).toBe("ok");
  expect(payload.version).toMatch(/\d+\.\d+\.\d+/);
});

Then("the last API response contains {string}", async ({ scenarioState }, expectedText: string) => {
  expect((scenarioState.lastResponseBody ?? "").toLowerCase()).toContain(expectedText.toLowerCase());
});
