import { test } from "node:test";
import assert from "node:assert/strict";
import { sanitizeCorrectPrefs } from "./config.mjs";
import { findModel, resolveProviderId } from "./providers/catalog.mjs";

test("sanitizeCorrectPrefs drops leftover workers_ai and CF model ids", () => {
  const out = sanitizeCorrectPrefs({
    mode: "rotate",
    activeProviderId: "workers_ai",
    activeModelId: "@cf/meta/llama-4-scout-17b-16e-instruct",
    selected: [
      { providerId: "aistudio", modelId: "gemma-4-26b-a4b-it" },
      { providerId: "workers_ai", modelId: "@cf/meta/llama-4-scout-17b-16e-instruct" },
    ],
  });
  assert.equal(out.activeProviderId, "aistudio");
  assert.equal(out.activeModelId, "gemma-4-26b-a4b-it");
  assert.deepEqual(out.selected, [{ providerId: "aistudio", modelId: "gemma-4-26b-a4b-it" }]);
  assert.equal(out.mode, "single");
});

test("sanitizeCorrectPrefs keeps live gemini ids not in the static catalog", () => {
  const out = sanitizeCorrectPrefs({
    activeProviderId: "aistudio",
    activeModelId: "gemini-3.1-flash-lite",
    selected: [{ providerId: "aistudio", modelId: "gemini-3.1-flash-lite" }],
  });
  assert.equal(out.activeModelId, "gemini-3.1-flash-lite");
  assert.equal(out.selected[0].modelId, "gemini-3.1-flash-lite");
});

test("unknown provider id resolves to aistudio; CF model is not a live Studio model", () => {
  assert.equal(resolveProviderId("workers_ai"), "aistudio");
  assert.equal(findModel("@cf/meta/llama-4-scout-17b-16e-instruct", "workers_ai"), null);
  assert.ok(findModel("gemma-4-26b-a4b-it", "aistudio"));
});
