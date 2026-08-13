import { findModel, allCorrectProviders, resolveProviderId } from "../catalog.mjs";
import { buildMessages, stripModelNoise } from "../../prompts.mjs";
import { chatAiStudio } from "./aistudio.mjs";

/** @type {number} */
let rotateIndex = 0;

/**
 * Correct text with Google AI Studio (single model, or rotate across a few
 * free models to spread free-tier rate limits).
 * @param {object} opts
 * @param {Record<string,string>} opts.env
 * @param {object} opts.prefsCorrect  // prefs.correct
 * @param {object} [opts.prefs] full prefs (locale)
 * @param {string} opts.text
 * @param {string} [opts.profile]
 * @param {string} [opts.contextHint]
 */
export async function correctText({
  env,
  prefsCorrect,
  prefs,
  text,
  profile,
  contextHint,
  customPrompts,
}) {
  const original = text ?? "";
  if (!original.trim()) {
    return { text: original, changed: false, provider: "none", model: "none", latency_ms: 0 };
  }

  const corr = prefsCorrect || {};
  const prof = profile || corr.profile || "light";
  const locale = prefs?.locale === "en" ? "en" : "vi";
  const { system, user } = buildMessages(prof, original, contextHint, customPrompts, locale);
  const started = Date.now();

  const candidates = resolveCandidates(corr);
  if (!candidates.length) {
    throw new Error("No correct model configured — pick a model in Settings");
  }

  let lastErr = "no attempt";
  for (const cand of candidates) {
    try {
      const raw = await dispatch({ env, modelId: cand.model.id, system, user });
      const cleaned = stripModelNoise(raw).trim() || original;
      if (corr.mode === "rotate") {
        const n = Math.max(1, normalizeSelected(corr).length);
        rotateIndex = (rotateIndex + 1) % n;
      }
      return {
        text: cleaned,
        changed: cleaned !== original.trim(),
        profile: prof,
        provider: cand.provider.id,
        model: cand.model.id,
        latency_ms: Date.now() - started,
      };
    } catch (e) {
      lastErr = e instanceof Error ? e.message : String(e);
      continue;
    }
  }
  throw new Error(`Correct failed: ${lastErr}`);
}

/** Normalize selected list: [{providerId, modelId}] with active-model fallback. */
function normalizeSelected(corr) {
  if (Array.isArray(corr.selected) && corr.selected.length) {
    return corr.selected
      .map((s) => ({
        providerId: resolveProviderId(s.providerId || corr.activeProviderId),
        modelId: s.modelId || s.id || "",
      }))
      .filter((s) => s.modelId);
  }
  return [
    {
      providerId: resolveProviderId(corr.activeProviderId),
      modelId: corr.activeModelId || "gemma-4-26b-a4b-it",
    },
  ];
}

function resolveCandidates(corr) {
  const selected = normalizeSelected(corr || {});
  if (corr.mode === "rotate" && selected.length > 0) {
    const ordered = [];
    for (let i = 0; i < selected.length; i++) {
      const s = selected[(rotateIndex + i) % selected.length];
      const hit = findModel(s.modelId, s.providerId);
      if (hit) ordered.push(hit);
    }
    return ordered;
  }
  const active =
    selected.find(
      (s) => s.modelId === corr.activeModelId && s.providerId === corr.activeProviderId,
    ) || selected[0];
  if (!active) return [];
  const hit = findModel(active.modelId, active.providerId);
  return hit ? [hit] : [];
}

async function dispatch({ env, modelId, system, user }) {
  // Only Google AI Studio is supported.
  return chatAiStudio({ env, modelId, system, user });
}

function providerHasCreds(env) {
  return Boolean(env.GOOGLE_AI_STUDIO_API_KEY?.trim());
}

export function correctReady(env, prefsCorrect) {
  const corr = prefsCorrect || {};
  const cands = resolveCandidates(corr);
  if (!cands.length) return false;
  return providerHasCreds(env);
}

export function listProvidersPublic(env) {
  return allCorrectProviders().map((p) => ({
    id: p.id,
    label: p.label,
    baseUrl: p.baseUrl,
    docs: p.docs,
    note: p.note,
    billing: p.billing || "provider",
    envKeys: (p.envKeys || []).map((k) => ({ key: k, set: Boolean(env[k]?.trim()) })),
    models: p.models,
  }));
}
