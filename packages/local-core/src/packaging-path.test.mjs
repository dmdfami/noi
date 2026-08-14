/**
 * Packaging path: cli must serve static UI relative to import.meta (not process.cwd).
 * Simulates embedded layout: invoke from a foreign working directory.
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { createServer } from "node:http";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { existsSync } from "node:fs";

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

test("cli serve from foreign cwd exposes healthz + index.html", async () => {
  assert.ok(existsSync(CLI), "cli.mjs must exist");
  const port = await freePort();
  const child = spawn(process.execPath, [CLI, "serve"], {
    cwd: "/tmp", // not the package directory
    env: { ...process.env, PORT: String(port) },
    stdio: ["ignore", "pipe", "pipe"],
  });
  let stderr = "";
  child.stderr.on("data", (d) => {
    stderr += d.toString();
  });

  const url = `http://127.0.0.1:${port}`;
  try {
    let ok = false;
    for (let i = 0; i < 40; i++) {
      try {
        const res = await fetch(`${url}/healthz`, { signal: AbortSignal.timeout(500) });
        if (res.ok) {
          const j = await res.json();
          assert.equal(j.ok, true);
          assert.equal(j.version, 2);
          ok = true;
          break;
        }
      } catch {
        /* retry */
      }
      await new Promise((r) => setTimeout(r, 100));
    }
    assert.ok(ok, `healthz not ready: ${stderr.slice(0, 400)}`);

    const h1 = await (await fetch(`${url}/healthz`)).json();
    const h2 = await (await fetch(`${url}/healthz`)).json();
    assert.equal(h1.ok, true);
    assert.equal(h2.ok, true);
    assert.equal(h1.version, h2.version);
    assert.equal(h1.app, "noi");
    assert.equal(h1.ui, true);

    const htmlRes = await fetch(`${url}/`);
    assert.equal(htmlRes.ok, true);
    const html = await htmlRes.text();
    assert.match(html, /Audio Local|html/i);
  } finally {
    child.kill("SIGTERM");
    await new Promise((r) => {
      child.once("exit", r);
      setTimeout(r, 2000);
    });
  }
});
