import { createServer } from "node:http";
import { readFileSync, existsSync } from "node:fs";
import { join, dirname, extname } from "node:path";
import { fileURLToPath } from "node:url";
import { randomBytes } from "node:crypto";
import {
  loadEnv,
  saveEnv,
  loadPrefs,
  savePrefs,
  publicSecrets,
  getLocalToken,
  ENV_PATH,
  PREFS_PATH,
  ensureConfigDir,
  MANAGED_SECRET_KEYS,
} from "./config.mjs";
import { catalogPublic } from "./providers/catalog.mjs";
import { transcribeChatGptWeb, sttReady } from "./providers/chatgpt-stt.mjs";
import { correctText, listProvidersPublic, correctReady } from "./providers/correct/index.mjs";
import { chatgptSessionFromToken } from "./chatgpt-session.mjs";
import { defaultPromptsMap } from "./prompts.mjs";
import { listModelsForProvider, listAllModels } from "./providers/list-models.mjs";

const __dirname = dirname(fileURLToPath(import.meta.url));
const PUBLIC = join(__dirname, "../public");

/** @type {{ stt?: number, correct?: number }} */
const lastLatency = {};

export function createAppServer(opts = {}) {
  ensureConfigDir();
  let env = loadEnv();
  let prefs = loadPrefs();

  // Bootstrap local token if missing (localhost auth for menu-bar client)
  if (!env.LOCAL_CORE_TOKEN) {
    env = saveEnv({ LOCAL_CORE_TOKEN: randomBytes(24).toString("hex") });
  }

  const port = Number(opts.port || prefs.port || 8797);
  const host = opts.host || "127.0.0.1";

  function reload() {
    env = loadEnv();
    prefs = loadPrefs();
  }

  function requireAuth(req) {
    // Local-only bind: loopback clients are trusted (menu bar, curl, UI).
    const ra = req.socket?.remoteAddress || "";
    if (ra === "127.0.0.1" || ra === "::1" || ra === ":ffff:127.0.0.1") return null;

    const token = getLocalToken(env);
    if (!token) return null;
    const h = req.headers.authorization || "";
    const m = /^Bearer\s+(.+)$/i.exec(h);
    if (m && m[1] === token) return null;
    const ref = req.headers.referer || "";
    if (ref.startsWith(`http://127.0.0.1:${port}`) || ref.startsWith(`http://localhost:${port}`)) {
      return null;
    }
    const cookie = req.headers.cookie || "";
    if (cookie.includes(`local_token=${token}`)) return null;
    return json(401, { error: "unauthorized", message: "Set Authorization: Bearer LOCAL_CORE_TOKEN" });
  }

  const server = createServer(async (req, res) => {
    try {
      const url = new URL(req.url || "/", `http://${host}:${port}`);
      const path = url.pathname.replace(/\/+$/, "") || "/";
      const method = (req.method || "GET").toUpperCase();

      // CORS local only
      if (method === "OPTIONS") {
        res.writeHead(204, corsHeaders());
        res.end();
        return;
      }

      // Public health
      if (method === "GET" && (path === "/healthz" || path === "/health")) {
        return send(res, json(200, { ok: true, version: 2 }));
      }

      // Static UI (no auth) — html/js/css under public/
      if (method === "GET" && isStaticPath(path)) {
        return serveStatic(res, path === "/" ? "/index.html" : path);
      }

      // Everything else under /v1 needs auth (except open status for UI bootstrap)
      reload();

      if (method === "GET" && path === "/v1/bootstrap") {
        // Returns token only to localhost UI so browser can store cookie
        const token = getLocalToken(env);
        res.setHeader(
          "set-cookie",
          `local_token=${token}; Path=/; HttpOnly; SameSite=Strict`,
        );
        return send(
          res,
          json(200, {
            ok: true,
            port,
            envPath: ENV_PATH,
            prefsPath: PREFS_PATH,
            catalog: catalogPublic(),
            secrets: publicSecrets(env),
            prefs,
            lastLatency,
            status: buildStatus(env, prefs),
          }),
        );
      }

      const denied = requireAuth(req);
      if (denied && path.startsWith("/v1/")) return send(res, denied);

      if (method === "GET" && path === "/v1/status") {
        return send(res, json(200, { ...buildStatus(env, prefs), lastLatency }));
      }

      if (method === "GET" && path === "/v1/catalog") {
        return send(
          res,
          json(200, {
            ...catalogPublic(),
            providers: listProvidersPublic(env),
            secrets: publicSecrets(env),
            prefs,
          }),
        );
      }

      // Live model lists (not hardcoded)
      if (method === "GET" && path === "/v1/models") {
        const providerId = url.searchParams.get("provider");
        if (providerId) {
          const one = await listModelsForProvider({ env, providerId });
          return send(res, json(200, one));
        }
        const all = await listAllModels({ env });
        return send(res, json(200, { providers: all }));
      }

      const modelsMatch = path.match(/^\/v1\/providers\/([^/]+)\/models$/);
      if (method === "GET" && modelsMatch) {
        const providerId = decodeURIComponent(modelsMatch[1]);
        const one = await listModelsForProvider({ env, providerId });
        return send(res, json(200, one));
      }

      if (method === "GET" && path === "/v1/config") {
        return send(
          res,
          json(200, {
            prefs,
            secrets: publicSecrets(env),
            envPath: ENV_PATH,
            prefsPath: PREFS_PATH,
          }),
        );
      }

      if (method === "GET" && path === "/v1/config/secrets") {
        const reveal = url.searchParams.get("reveal") === "1" || url.searchParams.get("reveal") === "true";
        return send(
          res,
          json(200, {
            secrets: publicSecrets(env, { reveal }),
            managedKeys: MANAGED_SECRET_KEYS,
            labels: SECRET_LABELS,
          }),
        );
      }

      if (method === "PUT" && path === "/v1/config/secrets") {
        const body = await readJson(req);
        const patch = {};
        for (const [k, v] of Object.entries(body || {})) {
          if (!MANAGED_SECRET_KEYS.includes(k)) continue;
          if (typeof v === "string") patch[k] = v;
        }
        env = saveEnv(patch);
        return send(res, json(200, { ok: true, secrets: publicSecrets(env) }));
      }

      if (method === "DELETE" && path === "/v1/config/secrets") {
        const body = await readJson(req);
        const keys = Array.isArray(body.keys) ? body.keys : body.key ? [body.key] : [];
        const patch = {};
        for (const k of keys) {
          if (MANAGED_SECRET_KEYS.includes(k)) patch[k] = "";
        }
        env = saveEnv(patch);
        return send(res, json(200, { ok: true, secrets: publicSecrets(env) }));
      }

      if (method === "PUT" && path === "/v1/config/prefs") {
        const body = await readJson(req);
        prefs = savePrefs(body || {});
        return send(res, json(200, { ok: true, prefs }));
      }

      if (method === "GET" && path === "/v1/config/prompts") {
        const locale = prefs.locale === "en" ? "en" : "vi";
        return send(
          res,
          json(200, {
            defaults: defaultPromptsMap(locale),
            prompts: prefs.prompts || {},
            activeProfile: prefs.correct?.profile || "light",
            locale,
            autoCorrectProfile: prefs.autoCorrectProfile || "light",
            hotkeyCorrectProfile: prefs.hotkeyCorrectProfile || "balanced",
          }),
        );
      }

      if (method === "PUT" && path === "/v1/config/prompts") {
        const body = await readJson(req);
        const profile = body.profile === "balanced" || body.profile === "rewrite" ? body.profile : "light";
        const system = typeof body.system === "string" ? body.system : "";
        const prompts = { ...(prefs.prompts || {}), [profile]: system };
        const correct =
          body.activeProfile && ["light", "balanced", "rewrite"].includes(body.activeProfile)
            ? { ...(prefs.correct || {}), profile: body.activeProfile }
            : prefs.correct;
        prefs = savePrefs({ prompts, correct });
        return send(res, json(200, { ok: true, prompts: prefs.prompts, correct: prefs.correct }));
      }

      if (method === "POST" && path === "/v1/audio/transcriptions") {
        const { buffer, fileName, mimeType } = await readAudio(req);
        const result = await transcribeChatGptWeb({
          accessToken: env.CHATGPT_ACCESS_TOKEN,
          audio: buffer,
          fileName,
          mimeType,
        });
        lastLatency.stt = result.latency_ms;
        return send(res, json(200, result));
      }

      if (method === "POST" && path === "/v1/text/correct") {
        const body = await readJson(req);
        // intent: auto = basic after STT; hotkey = stronger Option double-tap
        let profile = body.profile || prefs.correct?.profile || "light";
        if (body.intent === "auto") {
          profile = prefs.autoCorrectProfile || "light";
        } else if (body.intent === "hotkey") {
          profile = prefs.hotkeyCorrectProfile || "balanced";
        }
        const result = await correctText({
          env,
          prefsCorrect: prefs.correct,
          prefs,
          text: body.text || "",
          profile,
          contextHint: body.context_hint,
          customPrompts: prefs.prompts,
        });
        lastLatency.correct = result.latency_ms;
        return send(res, json(200, { ...result, profile }));
      }

      if (method === "POST" && path === "/v1/test/correct") {
        const body = await readJson(req);
        const result = await correctText({
          env,
          prefsCorrect: prefs.correct,
          prefs,
          text: body.text || "xin chao the gioi Clude Code",
          profile: body.profile || prefs.correct?.profile || "light",
          customPrompts: prefs.prompts,
        });
        lastLatency.correct = result.latency_ms;
        return send(res, json(200, result));
      }

      return send(res, json(404, { error: "not_found", path }));
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      return send(res, json(500, { error: "internal_error", message }));
    }
  });

  return {
    server,
    port,
    host,
    start() {
      return new Promise((resolve) => {
        server.listen(port, host, () => {
          console.error(`chatgpt-audio local-core v2 http://${host}:${port}`);
          console.error(`  UI:    http://${host}:${port}/`);
          console.error(`  env:   ${ENV_PATH}`);
          console.error(`  prefs: ${PREFS_PATH}`);
          resolve({ port, host });
        });
      });
    },
    close() {
      return new Promise((resolve, reject) => {
        server.close((e) => (e ? reject(e) : resolve()));
      });
    },
  };
}

const SECRET_LABELS = {
  CHATGPT_ACCESS_TOKEN: "ChatGPT (đăng nhập trên menu bar)",
  GOOGLE_AI_STUDIO_API_KEY: "Google AI Studio — 1 key (miễn phí)",
};

function buildStatus(env, prefs) {
  const stt = sttReady(env);
  const corrReady = correctReady(env, prefs.correct);
  const session = chatgptSessionFromToken(env.CHATGPT_ACCESS_TOKEN);
  const sttReadyOk = stt && !session.expired;
  return {
    // STT is the core feature; correction is optional and never blocks "ready".
    status: sttReadyOk ? "ready" : "degraded",
    stt: {
      provider: "chatgpt_web",
      mode: "local",
      ready: sttReadyOk,
      label: !stt
        ? "Chưa đăng nhập"
        : session.expired
          ? "Token hết hạn — làm mới"
          : "Đã đăng nhập",
      account: session.loggedIn
        ? {
            email: session.email,
            name: session.name,
            userId: session.userId,
            expLabel: session.expLabel,
            expired: session.expired,
            hint: session.hint,
          }
        : null,
    },
    correction: {
      provider: prefs.correct?.activeProviderId || "aistudio",
      model: prefs.correct?.activeModelId || "gemma-4-26b-a4b-it",
      mode: prefs.correct?.mode || "single",
      selected: prefs.correct?.selected || [],
      ready: corrReady,
      label: corrReady ? "Sẵn sàng" : "Chưa có key AI Studio",
    },
  };
}

/**
 * No `access-control-allow-origin`: the Settings UI is same-origin on
 * 127.0.0.1:<port>, so it never needs CORS. Omitting it means a page on any
 * other origin cannot read secrets or trigger STT/correct on this machine.
 */
function corsHeaders() {
  return {
    "access-control-allow-headers": "authorization,content-type",
    "access-control-allow-methods": "GET,POST,PUT,DELETE,OPTIONS",
    vary: "origin",
  };
}

function json(status, body) {
  return {
    status,
    headers: { "content-type": "application/json; charset=utf-8", ...corsHeaders() },
    body: JSON.stringify(body),
  };
}

function send(res, packed) {
  res.writeHead(packed.status, packed.headers);
  res.end(packed.body);
}

/** Allow only known static extensions from public/ (never /v1/*). */
function isStaticPath(path) {
  if (path === "/" || path === "/index.html") return true;
  if (path.startsWith("/v1/") || path === "/healthz" || path === "/health") return false;
  return /\.(js|css|html|svg|png|ico|map|woff2?|ttf)$/i.test(path) || path.startsWith("/assets/");
}

function serveStatic(res, path) {
  const safe = path.replace(/\.\./g, "");
  const rel = safe === "/index.html" || safe === "/" ? "index.html" : safe.replace(/^\//, "");
  const file = join(PUBLIC, rel);
  // Prevent path escape outside PUBLIC
  if (!file.startsWith(PUBLIC) || !existsSync(file)) {
    return send(res, json(404, { error: "not_found", path }));
  }
  const ext = extname(file);
  const types = {
    ".html": "text/html; charset=utf-8",
    ".js": "text/javascript; charset=utf-8",
    ".css": "text/css; charset=utf-8",
    ".svg": "image/svg+xml",
    ".json": "application/json",
    ".png": "image/png",
    ".ico": "image/x-icon",
    ".map": "application/json",
  };
  res.writeHead(200, {
    "content-type": types[ext] || "application/octet-stream",
    "cache-control": "no-cache",
    ...corsHeaders(),
  });
  res.end(readFileSync(file));
}

async function readJson(req) {
  const chunks = [];
  for await (const c of req) chunks.push(c);
  const raw = Buffer.concat(chunks).toString("utf8");
  if (!raw.trim()) return {};
  return JSON.parse(raw);
}

async function readAudio(req) {
  const ct = req.headers["content-type"] || "";
  if (ct.includes("multipart/form-data")) {
    const chunks = [];
    for await (const c of req) chunks.push(c);
    const buf = Buffer.concat(chunks);
    const parsed = parseMultipart(buf, ct);
    const file = parsed.find((p) => p.name === "file" || p.name === "audio") || parsed[0];
    if (!file) throw new Error("multipart field 'file' required");
    return {
      buffer: file.body,
      fileName: file.filename || "audio.m4a",
      mimeType: file.ctype || "audio/mp4",
    };
  }
  if (ct.includes("application/json")) {
    const body = await readJson(req);
    if (!body.audio_base64) throw new Error("audio_base64 required");
    return {
      buffer: Buffer.from(body.audio_base64, "base64"),
      fileName: body.file_name || "audio.m4a",
      mimeType: body.mime_type || "audio/mp4",
    };
  }
  const chunks = [];
  for await (const c of req) chunks.push(c);
  return {
    buffer: Buffer.concat(chunks),
    fileName: "audio.m4a",
    mimeType: ct.startsWith("audio/") ? ct : "audio/mp4",
  };
}

function parseMultipart(buf, contentType) {
  const m = /boundary=(?:"([^"]+)"|([^;]+))/i.exec(contentType || "");
  if (!m) throw new Error("missing multipart boundary");
  const boundary = m[1] || m[2];
  const sep = Buffer.from(`--${boundary}`);
  const parts = [];
  let start = buf.indexOf(sep) + sep.length;
  while (start < buf.length) {
    if (buf[start] === 45 && buf[start + 1] === 45) break;
    if (buf[start] === 13 && buf[start + 1] === 10) start += 2;
    const next = buf.indexOf(sep, start);
    if (next < 0) break;
    let part = buf.subarray(start, next - 2);
    const headerEnd = part.indexOf(Buffer.from("\r\n\r\n"));
    if (headerEnd >= 0) {
      const headers = part.subarray(0, headerEnd).toString("utf8");
      const body = part.subarray(headerEnd + 4);
      parts.push({
        name: /name="([^"]+)"/.exec(headers)?.[1],
        filename: /filename="([^"]+)"/.exec(headers)?.[1],
        ctype: /Content-Type:\s*(.+)/i.exec(headers)?.[1]?.trim(),
        body,
      });
    }
    start = next + sep.length;
  }
  return parts;
}
