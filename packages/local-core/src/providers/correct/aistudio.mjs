/**
 * Google AI Studio / Gemini generateContent.
 * Gemma 4: thinkingLevel=minimal (cannot fully disable).
 * Flash-Lite: no thinking config needed / optional.
 */

const GEMINI_ALIASES = {
  "gemini-3.5-flash-lite": ["gemini-3.5-flash-lite", "gemini-flash-lite-latest", "gemini-2.5-flash-lite"],
  "gemini-3.1-flash-lite": ["gemini-3.1-flash-lite", "gemini-flash-lite-latest", "gemini-2.5-flash-lite"],
};

/**
 * @param {object} opts
 */
export async function chatAiStudio({ env, modelId, system, user, timeoutMs = 30_000 }) {
  const key = env.GOOGLE_AI_STUDIO_API_KEY;
  if (!key?.trim()) throw new Error("GOOGLE_AI_STUDIO_API_KEY not set");

  const candidates = expandModelIds(modelId);
  let lastErr = "no attempt";
  for (const mid of candidates) {
    try {
      return await generateOnce({ key: key.trim(), modelId: mid, system, user, timeoutMs });
    } catch (e) {
      lastErr = e instanceof Error ? e.message : String(e);
    }
  }
  throw new Error(`AI Studio failed: ${lastErr}`);
}

function expandModelIds(modelId) {
  const aliases = GEMINI_ALIASES[modelId];
  if (aliases) return aliases;
  return [modelId];
}

async function generateOnce({ key, modelId, system, user, timeoutMs }) {
  const id = modelId.replace(/^models\//, "");
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(id)}:generateContent?key=${encodeURIComponent(key)}`;

  const isGemma = /gemma/i.test(id);
  /** @type {Record<string, unknown>} */
  const generationConfig = {
    temperature: 0,
    maxOutputTokens: 1024,
  };
  if (isGemma) {
    // Lowest supported thinking for Gemma 4 — vault: thinkingLevel=minimal
    generationConfig.thinkingConfig = {
      thinkingLevel: "minimal",
      includeThoughts: false,
    };
  }

  const body = {
    systemInstruction: { parts: [{ text: system }] },
    contents: [{ role: "user", parts: [{ text: user }] }],
    generationConfig,
  };

  const res = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(timeoutMs),
  });
  if (!res.ok) {
    const t = await res.text().catch(() => "");
    // Retry without thinkingConfig if rejected
    if (isGemma && /thinking|Thinking/i.test(t)) {
      delete generationConfig.thinkingConfig;
      const res2 = await fetch(url, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ ...body, generationConfig }),
        signal: AbortSignal.timeout(timeoutMs),
      });
      if (!res2.ok) {
        const t2 = await res2.text().catch(() => "");
        throw new Error(`AI Studio HTTP ${res2.status}: ${t2.slice(0, 200)}`);
      }
      return extractText(await res2.json());
    }
    throw new Error(`AI Studio HTTP ${res.status}: ${t.slice(0, 200)}`);
  }
  return extractText(await res.json());
}

function extractText(data) {
  const parts = data?.candidates?.[0]?.content?.parts;
  if (!Array.isArray(parts)) throw new Error("AI Studio empty candidates");
  const text = parts
    .filter((p) => p && typeof p.text === "string" && !p.thought)
    .map((p) => p.text)
    .join("");
  if (!text.trim()) throw new Error("AI Studio empty text (maybe thinking only)");
  return text;
}
