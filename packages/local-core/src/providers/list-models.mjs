/**
 * Model listing for Google AI Studio.
 * Live `/models` when a key is present; otherwise the static catalog fallback.
 */
import { allCorrectProviders, resolveProviderId } from "./catalog.mjs";

/**
 * @param {object} opts
 * @param {Record<string,string>} opts.env
 * @param {string} opts.providerId
 * @returns {Promise<{
 *   providerId: string,
 *   source: 'live'|'catalog'|'error',
 *   models: {id:string,label:string,group?:string}[],
 *   billing?: string,
 *   error?: string
 * }>}
 */
export async function listModelsForProvider({ env, providerId }) {
  const pid = resolveProviderId(providerId);
  const providers = allCorrectProviders();
  const provider = providers.find((p) => p.id === pid);
  if (!provider) {
    return { providerId: pid, source: "error", models: [], error: "unknown provider" };
  }

  const fallback = () =>
    (provider.models || []).map((m) => ({
      id: m.id,
      label: m.label || m.id,
      group: m.group || groupFromId(m.id),
    }));

  const wrap = (source, models, error) => ({
    providerId: pid,
    source,
    models: dedupe(models),
    billing: provider.billing,
    ...(error ? { error } : {}),
  });

  try {
    const models = await listAiStudio(env);
    if (!models.length) return wrap("catalog", fallback());
    return wrap("live", models);
  } catch (e) {
    return wrap("catalog", fallback(), e instanceof Error ? e.message : String(e));
  }
}

/** All providers' models (only AI Studio in Nói 1.0). */
export async function listAllModels({ env }) {
  const out = [];
  for (const p of allCorrectProviders()) {
    out.push(await listModelsForProvider({ env, providerId: p.id }));
  }
  return out;
}

function dedupe(models) {
  const seen = new Set();
  return (models || []).filter((m) => {
    if (!m?.id || seen.has(m.id)) return false;
    seen.add(m.id);
    return true;
  });
}

function groupFromId(id) {
  const s = String(id || "");
  return /gemma/i.test(s) ? "Gemma" : /gemini/i.test(s) ? "Gemini" : "Other";
}

async function listAiStudio(env) {
  const key = env.GOOGLE_AI_STUDIO_API_KEY?.trim();
  if (!key) throw new Error("Cần khóa Google AI Studio");
  const url = `https://generativelanguage.googleapis.com/v1beta/models?key=${encodeURIComponent(key)}&pageSize=100`;
  const res = await fetch(url, { signal: AbortSignal.timeout(20_000) });
  if (!res.ok) {
    const t = await res.text().catch(() => "");
    throw new Error(`AI Studio models HTTP ${res.status}: ${t.slice(0, 120)}`);
  }
  const data = await res.json();
  const models = data.models || [];
  return models
    .filter((m) => {
      const methods = m.supportedGenerationMethods || m.supported_generation_methods || [];
      if (Array.isArray(methods) && methods.length) return methods.includes("generateContent");
      return true;
    })
    .map((m) => {
      const id = String(m.name || "").replace(/^models\//, "");
      if (/embedding|embed-content|imagen|aqa/i.test(id)) return null;
      return { id, label: m.displayName || id, group: groupFromId(id) };
    })
    .filter(Boolean)
    .sort((a, b) => a.id.localeCompare(b.id));
}
