/**
 * Fixed provider catalog.
 *
 * Nói 1.0 is intentionally minimal:
 *  - STT: your ChatGPT web session (no key).
 *  - Correct (optional): Google AI Studio only, using your free API key.
 *
 * The static model list below is a fallback for the UI; when a key is set the
 * live list from AI Studio `/models` is preferred (see list-models.mjs).
 * NOTE: verify these ids against a live AI Studio key before a public release —
 * they are defaults, not a guarantee the ids exist on your account/tier.
 */

/** @typedef {{ id: string, label: string, provider: string, free?: boolean, note?: string, group?: string }} ModelDef */
/** @typedef {{
 *  id: string,
 *  label: string,
 *  kind: 'aistudio',
 *  baseUrl: string,
 *  envKeys: string[],
 *  models: ModelDef[],
 *  docs?: string,
 *  note?: string,
 *  billing?: 'provider',
 * }} ProviderDef */

/** @type {ProviderDef[]} */
export const CORRECT_PROVIDERS = [
  {
    id: "aistudio",
    label: "Google AI Studio",
    kind: "aistudio",
    baseUrl: "https://generativelanguage.googleapis.com/v1beta",
    envKeys: ["GOOGLE_AI_STUDIO_API_KEY"],
    docs: "https://aistudio.google.com/apikey",
    billing: "provider",
    models: [
      {
        id: "gemma-4-26b-a4b-it",
        label: "Gemma 4 26B (mặc định, free)",
        provider: "aistudio",
        free: true,
        note: "thinkingLevel=minimal · free tier rộng",
      },
      {
        id: "gemma-4-31b-it",
        label: "Gemma 4 31B",
        provider: "aistudio",
        free: true,
        note: "thinkingLevel=minimal",
      },
      {
        id: "gemini-flash-lite-latest",
        label: "Gemini Flash-Lite (latest)",
        provider: "aistudio",
        free: true,
        note: "nhanh nhất trên free tier Google",
      },
    ],
  },
];

export function resolveProviderId(id) {
  return id || "aistudio";
}

export const DEFAULT_CORRECT = {
  /** single = only active; rotate = round-robin over `selected` (né rate-limit free tier) */
  mode: "single",
  activeModelId: "gemma-4-26b-a4b-it",
  activeProviderId: "aistudio",
  /** @type {{ providerId: string, modelId: string }[]} */
  selected: [{ providerId: "aistudio", modelId: "gemma-4-26b-a4b-it" }],
  profile: "light",
};

export const STT_PROVIDER = {
  id: "chatgpt_web",
  label: "ChatGPT Web (local)",
  baseUrl: "https://chatgpt.com",
  paths: ["/backend-api/transcribe"],
  envKeys: ["CHATGPT_ACCESS_TOKEN"],
  note: "Dùng phiên đăng nhập ChatGPT web (không chính thức).",
};

/** Only the fixed AI Studio provider — no custom endpoints. */
export function allCorrectProviders() {
  return CORRECT_PROVIDERS;
}

/** Prefer providerId when set — supports live model ids not in static catalog. */
export function findModel(modelId, providerId) {
  const list = allCorrectProviders();
  const pid = resolveProviderId(providerId);
  const p = list.find((x) => x.id === pid) || list[0];
  if (!p) return null;
  const m = p.models.find((x) => x.id === modelId);
  if (m) return { provider: p, model: m };
  if (modelId) {
    // Live-listed model: provider known, id arbitrary
    return { provider: p, model: { id: modelId, label: modelId, provider: p.id } };
  }
  return null;
}

export function catalogPublic() {
  return {
    stt: STT_PROVIDER,
    correct: allCorrectProviders(),
    defaults: DEFAULT_CORRECT,
  };
}
