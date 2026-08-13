#!/usr/bin/env node
import { createAppServer } from "./src/server.mjs";
import { loadEnv, loadPrefs, saveEnv, ENV_PATH, PREFS_PATH } from "./src/config.mjs";
import { correctText } from "./src/providers/correct/index.mjs";
import { catalogPublic } from "./src/providers/catalog.mjs";

const [cmd, ...rest] = process.argv.slice(2);

async function main() {
  switch (cmd || "serve") {
    case "serve":
    case "start": {
      const port = Number(process.env.PORT || loadPrefs().port || 8797);
      // Embedded in the menu-bar app: one bad async path must not kill the core.
      process.on("unhandledRejection", (e) => {
        console.error(`unhandled rejection: ${e instanceof Error ? e.message : e}`);
      });
      const app = createAppServer({ port });
      app.server.on("error", (e) => {
        const code = e && typeof e === "object" && "code" in e ? e.code : "";
        console.error(
          code === "EADDRINUSE"
            ? `port ${port} already in use — another Audio Local core is running`
            : `core server error: ${e instanceof Error ? e.message : e}`,
        );
        process.exit(1);
      });
      await app.start();
      // Survive stray sync errors, but only once we are actually serving:
      // a failure before this point must exit so the app can report it.
      process.on("uncaughtException", (e) => {
        console.error(`uncaught exception: ${e instanceof Error ? e.message : e}`);
      });
      break;
    }
    case "status": {
      const env = loadEnv();
      const prefs = loadPrefs();
      console.log(
        JSON.stringify(
          {
            envPath: ENV_PATH,
            prefsPath: PREFS_PATH,
            hasChatGpt: Boolean(env.CHATGPT_ACCESS_TOKEN),
            hasAiStudio: Boolean(env.GOOGLE_AI_STUDIO_API_KEY),
            correct: prefs.correct,
          },
          null,
          2,
        ),
      );
      break;
    }
    case "catalog": {
      console.log(JSON.stringify(catalogPublic(), null, 2));
      break;
    }
    case "set-env": {
      // chatgpt-audio-local set-env KEY=value KEY2=value2
      const patch = {};
      for (const arg of rest) {
        const i = arg.indexOf("=");
        if (i < 0) continue;
        patch[arg.slice(0, i)] = arg.slice(i + 1);
      }
      const next = saveEnv(patch);
      console.log(
        JSON.stringify(
          Object.fromEntries(Object.keys(patch).map((k) => [k, next[k] ? "set" : "cleared"])),
          null,
          2,
        ),
      );
      break;
    }
    case "correct": {
      const text = rest.join(" ") || "xin chao the gioi Clude Code";
      const env = loadEnv();
      const prefs = loadPrefs();
      const r = await correctText({ env, prefsCorrect: prefs.correct, text, profile: "light" });
      console.log(JSON.stringify(r, null, 2));
      break;
    }
    case "smoke": {
      const env = loadEnv();
      if (env.GOOGLE_AI_STUDIO_API_KEY) {
        console.error("smoke: correct…");
        const c0 = Date.now();
        const c = await correctText({
          env,
          prefsCorrect: loadPrefs().correct,
          text: "xin chao Clude Code",
          profile: "light",
        });
        // Never print corrected text: it is user content.
        console.error(`correct ok model=${c.model} ms=${Date.now() - c0} chars=${c.text.length}`);
      } else {
        console.error("smoke: skip correct (no GOOGLE_AI_STUDIO_API_KEY)");
      }
      console.error("smoke: ok");
      break;
    }
    case "help":
    default:
      console.log(`nói (chatgpt-audio-local)

Usage:
  serve|start          Start local API + web UI (default :8797)
  status               Show credential presence + active model
  catalog              Print fixed provider catalog
  set-env K=V …        Write secrets to ~/.config/chatgpt-audio/v2.env
  correct "text…"      Run correct with active model (Google AI Studio)
  smoke                Quick correct smoke (if GOOGLE_AI_STUDIO_API_KEY set)
`);
  }
}

main().catch((e) => {
  console.error(e instanceof Error ? e.message : e);
  process.exit(1);
});
