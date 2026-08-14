import { mkdirSync, readFileSync, writeFileSync, existsSync, chmodSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { DEFAULT_CORRECT, CORRECT_PROVIDERS } from "./providers/catalog.mjs";

const KNOWN_CORRECT_PROVIDERS = new Set(CORRECT_PROVIDERS.map((p) => p.id));

/** Drop leftover providers (workers_ai, …) from older internal builds. */
export function sanitizeCorrectPrefs(correct) {
  const src = correct && typeof correct === "object" ? correct : {};
  const next = { ...DEFAULT_CORRECT, ...src };
  next.activeProviderId = KNOWN_CORRECT_PROVIDERS.has(next.activeProviderId)
    ? next.activeProviderId
    : "aistudio";
  const selected = (Array.isArray(next.selected) ? next.selected : [])
    .map((s) => ({
      providerId: KNOWN_CORRECT_PROVIDERS.has(s?.providerId) ? s.providerId : "aistudio",
      modelId: String(s?.modelId || s?.id || ""),
    }))
    .filter((s) => s.modelId && isKeptCorrectModel(s.modelId));
  next.selected = selected.length ? selected : [...DEFAULT_CORRECT.selected];
  if (
    !next.selected.some(
      (s) => s.modelId === next.activeModelId && s.providerId === next.activeProviderId,
    )
  ) {
    next.activeModelId = next.selected[0].modelId;
    next.activeProviderId = next.selected[0].providerId;
  }
  if (next.mode === "rotate" && next.selected.length < 2) next.mode = "single";
  return next;
}

function isKeptCorrectModel(id) {
  if (CORRECT_PROVIDERS.some((p) => p.models.some((m) => m.id === id))) return true;
  // Live AI Studio ids not in the static fallback list
  return /^(gemma-|gemini-)/i.test(id);
}

export const CONFIG_DIR = join(homedir(), ".config", "chatgpt-audio");
export const ENV_PATH = join(CONFIG_DIR, "v2.env");
export const PREFS_PATH = join(CONFIG_DIR, "v2.json");

const SENSITIVE_KEYS = new Set([
  "CHATGPT_ACCESS_TOKEN",
  "GOOGLE_AI_STUDIO_API_KEY",
  "LOCAL_CORE_TOKEN",
]);

/** Ensure config dir exists (mode 0700). */
export function ensureConfigDir() {
  mkdirSync(CONFIG_DIR, { recursive: true, mode: 0o700 });
}

/**
 * Parse KEY=VALUE env file (no export, # comments).
 * @param {string} text
 * @returns {Record<string, string>}
 */
export function parseEnv(text) {
  /** @type {Record<string, string>} */
  const out = {};
  for (const raw of (text || "").split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith("#")) continue;
    const eq = line.indexOf("=");
    if (eq < 0) continue;
    const k = line.slice(0, eq).trim();
    let v = line.slice(eq + 1).trim();
    if (
      (v.startsWith('"') && v.endsWith('"')) ||
      (v.startsWith("'") && v.endsWith("'"))
    ) {
      v = v.slice(1, -1);
    }
    out[k] = v;
  }
  return out;
}

/**
 * @param {Record<string, string>} env
 */
export function serializeEnv(env) {
  const lines = [
    "# ChatGPT Audio v2 — local credentials (mode 0600)",
    "# Do not commit. Not Keychain — plain env file by design.",
    "",
  ];
  const order = ["LOCAL_CORE_TOKEN", "CHATGPT_ACCESS_TOKEN", "GOOGLE_AI_STUDIO_API_KEY"];
  const seen = new Set();
  for (const k of order) {
    if (env[k] != null && env[k] !== "") {
      lines.push(`${k}=${quoteIfNeeded(env[k])}`);
      seen.add(k);
    }
  }
  for (const [k, v] of Object.entries(env).sort()) {
    if (seen.has(k) || v == null || v === "") continue;
    lines.push(`${k}=${quoteIfNeeded(v)}`);
  }
  lines.push("");
  return lines.join("\n");
}

function quoteIfNeeded(v) {
  if (/[\s#"']/.test(v)) return JSON.stringify(v);
  return v;
}

/** Load env: process.env overlays file. */
export function loadEnv() {
  ensureConfigDir();
  /** @type {Record<string, string>} */
  let file = {};
  if (existsSync(ENV_PATH)) {
    file = parseEnv(readFileSync(ENV_PATH, "utf8"));
  }
  /** @type {Record<string, string>} */
  const merged = { ...file };
  for (const k of SENSITIVE_KEYS) {
    if (process.env[k]) merged[k] = process.env[k];
  }
  // Also accept common aliases
  if (process.env.GEMINI_API_KEY && !merged.GOOGLE_AI_STUDIO_API_KEY) {
    merged.GOOGLE_AI_STUDIO_API_KEY = process.env.GEMINI_API_KEY;
  }
  return merged;
}

/**
 * @param {Record<string, string>} patch
 */
export function saveEnv(patch) {
  ensureConfigDir();
  const current = existsSync(ENV_PATH) ? parseEnv(readFileSync(ENV_PATH, "utf8")) : {};
  const next = { ...current };
  for (const [k, v] of Object.entries(patch || {})) {
    if (v == null || v === "") delete next[k];
    else next[k] = String(v);
  }
  writeFileSync(ENV_PATH, serializeEnv(next), { mode: 0o600 });
  try {
    chmodSync(ENV_PATH, 0o600);
  } catch {
    /* ignore */
  }
  return next;
}

export function defaultPrefs() {
  return {
    version: 2,
    port: 8797,
    /** UI + system-prompt language: vi (default) | en */
    locale: "vi",
    correct: { ...DEFAULT_CORRECT },
    /** Custom system prompts per profile (empty string = use built-in) */
    prompts: {
      light: "",
      balanced: "",
      rewrite: "",
    },
    stt: { language: "vi" },
    hotkeys: {
      stt: "Control+Option hold / double-tap",
      correct: "Option double-tap (strong)",
    },
    /** After STT paste: also run correct at basic profile (adds latency) */
    autoCorrectAfterDictate: false,
    /** Profile for auto-correct after STT — basic ASR cleanup */
    autoCorrectProfile: "light",
    /** Profile for ⌥⌥ hotkey — stronger edit */
    hotkeyCorrectProfile: "balanced",
  };
}

export function loadPrefs() {
  ensureConfigDir();
  if (!existsSync(PREFS_PATH)) return defaultPrefs();
  try {
    const raw = JSON.parse(readFileSync(PREFS_PATH, "utf8"));
    const correct = sanitizeCorrectPrefs({ ...DEFAULT_CORRECT, ...(raw.correct || {}) });
    const next = {
      ...defaultPrefs(),
      ...raw,
      correct,
    };
    try {
      if (JSON.stringify(raw.correct || {}) !== JSON.stringify(correct)) {
        writeFileSync(PREFS_PATH, JSON.stringify(next, null, 2) + "\n", { mode: 0o600 });
      }
    } catch {
      /* keep memory copy even if disk write fails */
    }
    return next;
  } catch {
    return defaultPrefs();
  }
}

/**
 * @param {object} patch
 */
export function savePrefs(patch) {
  ensureConfigDir();
  const cur = loadPrefs();
  const next = {
    ...cur,
    ...patch,
    correct: sanitizeCorrectPrefs({ ...cur.correct, ...(patch.correct || {}) }),
    prompts: { ...cur.prompts, ...(patch.prompts || {}) },
    stt: { ...cur.stt, ...(patch.stt || {}) },
  };
  writeFileSync(PREFS_PATH, JSON.stringify(next, null, 2) + "\n", { mode: 0o600 });
  try {
    chmodSync(PREFS_PATH, 0o600);
  } catch {
    /* ignore */
  }
  return next;
}

/**
 * Secrets for UI. Loopback may request reveal=true for manage keys.
 * @param {Record<string,string>} env
 * @param {{ reveal?: boolean }} [opts]
 */
export function publicSecrets(env, opts = {}) {
  /** @type {Record<string, { set: boolean, hint?: string, value?: string }>} */
  const out = {};
  for (const k of SENSITIVE_KEYS) {
    if (k === "LOCAL_CORE_TOKEN") continue; // never expose local core token in UI
    const v = env[k] || "";
    out[k] = {
      set: Boolean(v),
      hint: v ? `${v.slice(0, 4)}…${v.slice(-3)}` : undefined,
    };
    if (opts.reveal && v) out[k].value = v;
  }
  return out;
}

/** Keys the dashboard can manage (add/show/delete). */
export const MANAGED_SECRET_KEYS = ["CHATGPT_ACCESS_TOKEN", "GOOGLE_AI_STUDIO_API_KEY"];

export function getLocalToken(env) {
  return env.LOCAL_CORE_TOKEN || "";
}
