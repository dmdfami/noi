/**
 * Decode ChatGPT access token JWT (unverified) for UI account display.
 * Does not validate signature — local UX only.
 */

/**
 * @param {string | undefined} accessToken
 * @returns {{
 *  loggedIn: boolean,
 *  email?: string,
 *  name?: string,
 *  userId?: string,
 *  exp?: number,
 *  expLabel?: string,
 *  expired?: boolean,
 *  hint?: string
 * }}
 */
export function chatgptSessionFromToken(accessToken) {
  const tok = (accessToken || "").trim();
  if (!tok) return { loggedIn: false };

  const hint = `${tok.slice(0, 4)}…${tok.slice(-3)}`;
  try {
    const parts = tok.split(".");
    if (parts.length < 2) {
      return { loggedIn: true, hint, name: "Session token" };
    }
    const payload = JSON.parse(base64UrlDecode(parts[1]));
    const profile = payload["https://api.openai.com/profile"] || {};
    const auth = payload["https://api.openai.com/auth"] || {};
    const exp = typeof payload.exp === "number" ? payload.exp : undefined;
    const expired = exp != null ? Date.now() / 1000 > exp : false;
    let expLabel;
    if (exp) {
      const d = new Date(exp * 1000);
      expLabel = d.toLocaleString();
    }
    return {
      loggedIn: true,
      email: profile.email || undefined,
      name: profile.name || undefined,
      userId: auth.user_id || payload.sub || undefined,
      exp,
      expLabel,
      expired,
      hint,
    };
  } catch {
    return { loggedIn: true, hint, name: "Session token" };
  }
}

function base64UrlDecode(s) {
  const pad = "=".repeat((4 - (s.length % 4)) % 4);
  const b64 = (s + pad).replace(/-/g, "+").replace(/_/g, "/");
  return Buffer.from(b64, "base64").toString("utf8");
}
