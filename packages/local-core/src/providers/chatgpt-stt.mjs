/**
 * ChatGPT Web STT — local device egress.
 * POST https://chatgpt.com/backend-api/transcribe
 */

const UA =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15";

/**
 * @param {object} opts
 * @param {string} opts.accessToken
 * @param {Buffer|Uint8Array|ArrayBuffer} opts.audio
 * @param {string} [opts.fileName]
 * @param {string} [opts.mimeType]
 * @param {number} [opts.timeoutMs]
 */
export async function transcribeChatGptWeb({
  accessToken,
  audio,
  fileName = "audio.m4a",
  mimeType = "audio/mp4",
  timeoutMs = 30_000,
}) {
  if (!accessToken?.trim()) {
    throw new Error("CHATGPT_ACCESS_TOKEN not set — paste token in Settings → STT");
  }
  const started = Date.now();
  const buf = Buffer.isBuffer(audio)
    ? audio
    : Buffer.from(audio instanceof ArrayBuffer ? new Uint8Array(audio) : audio);

  const form = new FormData();
  form.append("file", new Blob([buf], { type: mimeType }), fileName);

  const paths = ["/backend-api/transcribe"];
  let lastErr = "no attempt";
  for (const path of paths) {
    const headers = {
      authorization: `Bearer ${accessToken.trim()}`,
      "user-agent": UA,
      accept: "*/*",
      origin: "https://chatgpt.com",
      referer: "https://chatgpt.com/",
    };
    try {
      const res = await fetch(`https://chatgpt.com${path}`, {
        method: "POST",
        headers,
        body: form,
        signal: AbortSignal.timeout(timeoutMs),
      });
      const text = await res.text();
      if (!res.ok) {
        lastErr = `HTTP ${res.status}: ${text.slice(0, 160)}`;
        continue;
      }
      const data = JSON.parse(text);
      const out = (data.text || "").trim();
      if (!out) {
        lastErr = "empty transcript";
        continue;
      }
      return {
        text: out,
        provider: "chatgpt_web",
        latency_ms: Date.now() - started,
        mode: "local",
      };
    } catch (e) {
      lastErr = e instanceof Error ? e.message : String(e);
    }
  }
  throw new Error(`ChatGPT Web STT failed: ${lastErr}`);
}

export function sttReady(env) {
  return Boolean(env.CHATGPT_ACCESS_TOKEN?.trim());
}
