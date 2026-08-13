import { test } from "node:test";
import assert from "node:assert/strict";
import { buildMessages, resolveProfileSystem, defaultPromptsMap } from "./prompts.mjs";

test("locale vi/en produce different light systems", () => {
  const vi = resolveProfileSystem("light", "vi");
  const en = resolveProfileSystem("light", "en");
  assert.notEqual(vi, en);
  assert.match(vi, /nhận dạng giọng nói|ASR/i);
  assert.match(en, /ASR|speech-to-text/i);
});

test("buildMessages uses locale for system prompt", () => {
  const { system: sVi } = buildMessages("light", "xin chao", null, null, "vi");
  const { system: sEn } = buildMessages("balanced", "hello", null, null, "en");
  assert.match(sVi, /Việt|ASR|giọng/i);
  assert.match(sEn, /English|editor|ASR/i);
});

test("defaultPromptsMap has three profiles", () => {
  const m = defaultPromptsMap("vi");
  assert.ok(m.light && m.balanced && m.rewrite);
});
