import { mkdirSync, readFileSync, writeFileSync, existsSync, chmodSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { DEFAULT_CORRECT } from "./providers/catalog.mjs";

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
    const correct = { ...DEFAULT_CORRECT, ...(raw.correct || {}) };
    // Migrate: ensure selected[] includes active model
    if (!Array.isArray(correct.selected) || !correct.selected.length) {
      correct.selected = [
        {
          providerId: correct.activeProviderId || "aistudio",
          modelId: correct.activeModelId || "gemma-4-26b-a4b-it",
        },
      ];
    } else {
      const ap = correct.activeProviderId;
      const am = correct.activeModelId;
      if (
        ap &&
        am &&
        !correct.selected.some((s) => s.providerId === ap && s.modelId === am)
      ) {
        correct.selected = [{ providerId: ap, modelId: am }, ...correct.selected];
      }
    }
    return {
      ...defaultPrefs(),
      ...raw,
      correct,
    };
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
    correct: { ...cur.correct, ...(patch.correct || {}) },
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
