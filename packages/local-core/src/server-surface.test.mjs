/**
 * Shipped HTTP surface: loopback bind, no cross-origin read access,
 * secrets exposed as hints only, config files created 0600.
 * Runs the real CLI with an isolated HOME so the developer's
 * ~/.config/chatgpt-audio is never touched.
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { createServer } from "node:http";
import { mkdtempSync, statSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const CLI = join(__dirname, "../cli.mjs");

async function freePort() {
  return new Promise((resolve, reject) => {
    const s = createServer();
    s.listen(0, "127.0.0.1", () => {
      const { port } = s.address();
      s.close(() => resolve(port));
    });
    s.on("error", reject);
  });
}

async function startCore() {
  const home = mkdtempSync(join(tmpdir(), "chatgpt-audio-home-"));
  const port = await freePort();
  const child = spawn(process.execPath, [CLI, "serve"], {
    cwd: tmpdir(),
    env: { ...process.env, HOME: home, PORT: String(port) },
    stdio: ["ignore", "pipe", "pipe"],
  });
  let stderr = "";
  child.stderr.on("data", (d) => {
    stderr += d.toString();
  });
  const url = `http://127.0.0.1:${port}`;
  for (let i = 0; i < 40; i++) {
    try {
      const res = await fetch(`${url}/healthz`, { signal: AbortSignal.timeout(500) });
      if (res.ok) return { url, port, home, child, stderr: () => stderr };
    } catch {
      /* retry */
    }
    await new Promise((r) => setTimeout(r, 100));
  }
  child.kill("SIGTERM");
  throw new Error(`core did not start: ${stderr.slice(0, 400)}`);
}

async function stopCore(core) {
  core.child.kill("SIGTERM");
  await new Promise((r) => {
    core.child.once("exit", r);
    setTimeout(r, 2000);
  });
}

test("local API is not readable cross-origin", async () => {
  const core = await startCore();
  try {
    const health = await fetch(`${core.url}/healthz`);
    assert.equal(
      health.headers.get("access-control-allow-origin"),
      null,
      "wildcard CORS would let any website read local secrets",
    );

    const boot = await fetch(`${core.url}/v1/bootstrap`);
    assert.equal(boot.headers.get("access-control-allow-origin"), null);

    const preflight = await fetch(`${core.url}/v1/config/secrets`, {
      method: "OPTIONS",
      headers: { origin: "https://evil.example", "access-control-request-method": "GET" },
    });
    assert.equal(preflight.headers.get("access-control-allow-origin"), null);
  } finally {
    await stopCore(core);
  }
});

test("bootstrap and status expose secret hints only", async () => {
  const core = await startCore();
  try {
    const boot = await (await fetch(`${core.url}/v1/bootstrap`)).json();
    assert.equal(boot.ok, true);
    assert.ok(boot.catalog, "catalog present for the Settings UI");
    assert.ok(boot.prefs, "prefs present");
    assert.equal(
      Object.prototype.hasOwnProperty.call(boot.secrets, "LOCAL_CORE_TOKEN"),
      false,
      "local core token must never reach the UI payload",
    );
    for (const [key, meta] of Object.entries(boot.secrets)) {
      assert.equal(meta.value, undefined, `${key} must not be returned in plaintext`);
    }

    const secrets = await (await fetch(`${core.url}/v1/config/secrets`)).json();
    for (const [key, meta] of Object.entries(secrets.secrets)) {
      assert.equal(meta.value, undefined, `${key} must stay hidden without reveal=1`);
    }

    const status = await (await fetch(`${core.url}/v1/status`)).json();
    for (const part of ["stt", "correction"]) {
      assert.ok(status[part], `${part} status present`);
      assert.equal(typeof status[part].ready, "boolean");
      assert.equal(typeof status[part].label, "string");
    }
    assert.equal(status.tts, undefined, "TTS removed from status");
  } finally {
    await stopCore(core);
  }
});

test("a busy port fails loudly instead of leaving a dead core", async () => {
  const core = await startCore();
  try {
    const second = spawn(process.execPath, [CLI, "serve"], {
      cwd: tmpdir(),
      env: { ...process.env, HOME: core.home, PORT: String(core.port) },
      stdio: ["ignore", "pipe", "pipe"],
    });
    let err = "";
    second.stderr.on("data", (d) => {
      err += d.toString();
    });
    const code = await new Promise((resolve) => {
      second.once("exit", resolve);
      setTimeout(() => {
        second.kill("SIGKILL");
        resolve("timeout");
      }, 5000);
    });
    assert.equal(code, 1, `second core must exit, got ${code}: ${err.slice(0, 200)}`);
    assert.match(err, /already in use/);

    // The first core keeps serving.
    assert.equal((await (await fetch(`${core.url}/healthz`)).json()).ok, true);
  } finally {
    await stopCore(core);
  }
});

test("first run creates config with owner-only permissions", async () => {
  const core = await startCore();
  try {
    const envPath = join(core.home, ".config", "chatgpt-audio", "v2.env");
    assert.ok(existsSync(envPath), "env file bootstrapped on first serve");
    assert.equal(statSync(envPath).mode & 0o777, 0o600, "secrets file must be 0600");
    assert.equal(
      statSync(join(core.home, ".config", "chatgpt-audio")).mode & 0o777,
      0o700,
      "config dir must be 0700",
    );

    const missing = await fetch(`${core.url}/v1/does-not-exist`);
    assert.equal(missing.status, 404);
    assert.equal((await missing.json()).error, "not_found");
  } finally {
    await stopCore(core);
  }
});
