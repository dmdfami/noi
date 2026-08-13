/* Nói — Settings (single page, minimal). locale vi|en */
const APP_VERSION = "1.0.0";

const state = {
  boot: null,
  prefs: null,
  secrets: null,
  locale: "vi",
  /** AI Studio models: { source, models[] } */
  models: null,
  modelsLoading: false,
  /** selected [{providerId, modelId}] */
  selected: [],
};

const I18N = {
  vi: {
    pageSub: "Cài đặt · chỉ khi cần",
    keyStt: "Nói",
    keyCorr: "Sửa",
    keyEsc: "Dừng",
    loginCtaTitle: "Đăng nhập ChatGPT",
    loginCtaSub: "Bắt buộc để nói ra chữ (STT). Đăng nhập ngay trong app.",
    loginCtaBtn: "Đăng nhập…",
    loginCtaSwitch: "Đổi tài khoản…",
    loginCtaAccount: "Tài khoản",
    sumCorrect: "Sửa văn bản (tuỳ chọn)",
    correctIntro:
      "Tuỳ chọn. Dán một API key Google AI Studio (miễn phí) để bật sửa chính tả sau khi nói và khi bấm ⌥⌥.",
    aistudioKeyLab: "Google AI Studio API key",
    aistudioKeyLink: "Lấy key miễn phí →",
    autoCorrect: "Tự sửa ngay sau khi nói",
    rotateLab: "Xoay vòng model (né giới hạn free)",
    usingLabel: "Đang dùng",
    rotateLabel: "Hàng xoay",
    rotateHint: "Mỗi lần sửa dùng model kế tiếp trong hàng (tự chuyển khi lỗi/hết lượt).",
    statusNeedsSetup: "Cần đăng nhập",
    statusReady: "Sẵn sàng",
    footNote: "Nói · nhấn phím là ra chữ",
    testBtn: "Thử sửa một câu",
    keySaved: "đã lưu",
    keyNone: "chưa có key",
    stStt: "Nói ra chữ (STT)",
    stCorr: "Sửa văn bản",
    stSttNeed: "Cần đăng nhập ChatGPT",
    stCorrNeed: "Tuỳ chọn — thêm key AI Studio",
    stCorrOk: "Đã cấu hình",
    statusTitle: "Trạng thái",
  },
  en: {
    pageSub: "Settings · only when needed",
    keyStt: "Dictate",
    keyCorr: "Fix",
    keyEsc: "Stop",
    loginCtaTitle: "Sign in to ChatGPT",
    loginCtaSub: "Required to turn speech into text (STT). Sign in inside the app.",
    loginCtaBtn: "Sign in…",
    loginCtaSwitch: "Switch account…",
    loginCtaAccount: "Account",
    sumCorrect: "Text fix (optional)",
    correctIntro:
      "Optional. Paste a free Google AI Studio API key to fix spelling after dictation and on ⌥⌥.",
    aistudioKeyLab: "Google AI Studio API key",
    aistudioKeyLink: "Get a free key →",
    autoCorrect: "Auto-fix right after dictation",
    rotateLab: "Rotate models (dodge free limits)",
    usingLabel: "In use",
    rotateLabel: "Rotate queue",
    rotateHint: "Each fix uses the next model in the queue (auto-switch on error/limit).",
    statusNeedsSetup: "Sign-in needed",
    statusReady: "Ready",
    footNote: "Nói · press a key, get text",
    testBtn: "Try fixing a sentence",
    keySaved: "saved",
    keyNone: "no key yet",
    stStt: "Dictate (STT)",
    stCorr: "Text fix",
    stSttNeed: "Sign in to ChatGPT required",
    stCorrNeed: "Optional — add an AI Studio key",
    stCorrOk: "Configured",
    statusTitle: "Status",
  },
};

const $ = (id) => document.getElementById(id);
const esc = (s) =>
  String(s ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");

function t() {
  return I18N[state.locale] || I18N.vi;
}

async function api(path, opts = {}) {
  const res = await fetch(path, {
    ...opts,
    headers: { "content-type": "application/json", ...(opts.headers || {}) },
  });
  const ct = res.headers.get("content-type") || "";
  const body = ct.includes("json") ? await res.json() : await res.text();
  if (!res.ok) throw new Error(body?.message || body?.error || res.statusText);
  return body;
}

function toast(msg, ok = true) {
  const el = $("toast");
  el.hidden = false;
  el.textContent = msg;
  el.style.borderColor = ok ? "var(--ok)" : "var(--err)";
  clearTimeout(toast._t);
  toast._t = setTimeout(() => {
    el.hidden = true;
  }, 2600);
}

function ms(n) {
  if (n == null) return "—";
  return n >= 1000 ? `${(n / 1000).toFixed(1)}s` : `${Math.round(n)}ms`;
}

function hasKey() {
  return !!state.secrets?.GOOGLE_AI_STUDIO_API_KEY?.set;
}

function openChatGPTLoginDeepLink() {
  window.location.href = "chatgpt-audio-local://login";
}

/* —— locale —— */
function applyLocaleStrings() {
  const L = t();
  document.documentElement.lang = state.locale;
  const set = (id, v) => {
    const el = $(id);
    if (el) el.textContent = v;
  };
  set("page-sub", L.pageSub);
  set("key-stt-lab", L.keyStt);
  set("key-corr-lab", L.keyCorr);
  set("key-esc-lab", L.keyEsc);
  set("login-cta-title", L.loginCtaTitle);
  set("login-cta-sub", L.loginCtaSub);
  set("sum-correct", L.sumCorrect);
  set("correct-intro", L.correctIntro);
  set("aistudio-key-lab", L.aistudioKeyLab);
  set("aistudio-key-link", L.aistudioKeyLink);
  set("auto-correct-lab", L.autoCorrect);
  set("rotate-lab", L.rotateLab);
  set("foot-note", L.footNote);
  set("btn-test-correct", L.testBtn);
  updateLoginCta();
  document.querySelectorAll(".seg-btn").forEach((b) => {
    b.classList.toggle("active", b.dataset.locale === state.locale);
  });
}

document.querySelectorAll(".seg-btn").forEach((btn) => {
  btn.addEventListener("click", async () => {
    const locale = btn.dataset.locale === "en" ? "en" : "vi";
    state.locale = locale;
    try {
      await api("/v1/config/prefs", {
        method: "PUT",
        body: JSON.stringify({ locale, stt: { language: locale } }),
      });
      await refresh();
      toast(locale === "en" ? "Language: English" : "Ngôn ngữ: Tiếng Việt");
    } catch (e) {
      toast(String(e.message || e), false);
    }
  });
});

/* —— login CTA —— */
function updateLoginCta() {
  const L = t();
  const stt = state.boot?.status?.stt || {};
  const ready = !!stt.ready;
  const email = stt.account?.email || stt.account?.name || "";
  const btn = $("btn-chatgpt-login");
  const acc = $("login-cta-account");
  if (btn) btn.textContent = ready ? L.loginCtaSwitch : L.loginCtaBtn;
  $("login-cta")?.classList.toggle("ready", ready);
  if (acc) {
    if (ready && email) {
      acc.hidden = false;
      acc.textContent = `${L.loginCtaAccount}: ${email}`;
    } else {
      acc.hidden = true;
      acc.textContent = "";
    }
  }
}

/* —— status —— */
function renderSetupStatus() {
  const L = t();
  const st = state.boot?.status || {};
  const stt = !!st.stt?.ready;
  const corr = !!st.correction?.ready;
  const row = (label, ok, detail) => `
    <div class="setup-row ${ok ? "ok" : "todo"}">
      <span class="setup-dot">${ok ? "✓" : "○"}</span>
      <div>
        <strong>${esc(label)}</strong>
        <span class="setup-detail">${esc(detail)}</span>
      </div>
    </div>`;
  $("setup-status").innerHTML = `
    <h2 class="setup-title">${L.statusTitle}</h2>
    ${row(L.stStt, stt, stt ? st.stt?.account?.email || "ChatGPT" : L.stSttNeed)}
    ${row(L.stCorr, corr, corr ? (st.correction?.model || L.stCorrOk) : L.stCorrNeed)}`;
}

/* —— AI Studio key —— */
function renderKeyRow() {
  const L = t();
  const s = state.secrets?.GOOGLE_AI_STUDIO_API_KEY || {};
  const input = $("aistudio-key");
  if (input && document.activeElement !== input) input.value = "";
  if (input) input.placeholder = s.set ? `${s.hint || "••••"} — ${L.keySaved}` : "Dán key AI Studio…";
  $("btn-aistudio-del").disabled = !s.set;
  $("aistudio-key-state").textContent = s.set ? `● ${L.keySaved}` : `○ ${L.keyNone}`;
}

$("btn-aistudio-save").onclick = async () => {
  const v = $("aistudio-key").value.trim();
  if (!v) return toast(state.locale === "en" ? "Paste a key first" : "Dán key trước đã", false);
  try {
    await api("/v1/config/secrets", {
      method: "PUT",
      body: JSON.stringify({ GOOGLE_AI_STUDIO_API_KEY: v }),
    });
    $("aistudio-key").value = "";
    await refresh();
    await loadModels();
    toast(state.locale === "en" ? "Key saved" : "Đã lưu key");
  } catch (e) {
    toast(String(e.message || e), false);
  }
};

$("btn-aistudio-del").onclick = async () => {
  try {
    await api("/v1/config/secrets", {
      method: "DELETE",
      body: JSON.stringify({ key: "GOOGLE_AI_STUDIO_API_KEY" }),
    });
    await refresh();
    toast(state.locale === "en" ? "Key removed" : "Đã xoá key");
  } catch (e) {
    toast(String(e.message || e), false);
  }
};

/* —— models (AI Studio only) —— */
function catalogModels() {
  const cat = state.boot?.catalog?.correct?.[0]?.models || [];
  return cat.map((m) => ({ id: m.id, label: m.label || m.id }));
}
function modelList() {
  if (state.models?.models?.length) return state.models.models;
  return catalogModels();
}
function isSelected(modelId) {
  return state.selected.some((s) => s.modelId === modelId);
}
function isActive(modelId) {
  return state.prefs?.correct?.activeModelId === modelId;
}
function labelFor(modelId) {
  const m = modelList().find((x) => x.id === modelId);
  return m?.label || modelId;
}

async function loadModels() {
  state.modelsLoading = true;
  renderModels();
  try {
    state.models = await api("/v1/models?provider=aistudio");
  } catch {
    state.models = null;
  } finally {
    state.modelsLoading = false;
    renderModels();
  }
}

async function saveCorrect(patch) {
  await api("/v1/config/prefs", {
    method: "PUT",
    body: JSON.stringify({
      correct: { ...(state.prefs?.correct || {}), ...patch },
    }),
  });
  await refresh();
}

async function toggleModel(modelId) {
  let selected = [...state.selected];
  if (isSelected(modelId)) {
    if (selected.length <= 1)
      return toast(state.locale === "en" ? "Keep ≥ 1 model" : "Cần ≥ 1 model", false);
    selected = selected.filter((s) => s.modelId !== modelId);
  } else {
    selected.push({ providerId: "aistudio", modelId });
  }
  let activeModelId = state.prefs?.correct?.activeModelId;
  if (!selected.some((s) => s.modelId === activeModelId)) activeModelId = selected[0].modelId;
  const rotate = $("rotate-toggle").checked && selected.length > 1;
  state.selected = selected;
  await saveCorrect({
    mode: rotate ? "rotate" : "single",
    selected,
    activeProviderId: "aistudio",
    activeModelId,
  });
}

function renderActiveBox() {
  const L = t();
  const corr = state.prefs?.correct || {};
  const rotating = corr.mode === "rotate";
  const queue = state.selected
    .map((s) => {
      const cls = isActive(s.modelId) ? "active" : "picked";
      return `<span class="queue-pill ${cls}" title="${esc(s.modelId)}">${esc(labelFor(s.modelId))}</span>`;
    })
    .join("");
  $("active-model-box").innerHTML = `
    <div class="label">${rotating ? L.rotateLabel : L.usingLabel}</div>
    <div class="name">${esc(labelFor(corr.activeModelId) || "—")}</div>
    <div class="id">${esc(corr.activeModelId || "—")} · Google AI Studio</div>
    <div class="queue">${queue}</div>
    ${rotating ? `<p class="queue-hint">${esc(L.rotateHint)}</p>` : ""}`;
}

function renderModels() {
  const st = state.boot?.status?.correction || {};
  const corr = state.prefs?.correct || {};
  $("correct-status").className = `status ${st.ready ? "ok" : "warn"}`;
  $("correct-status").textContent = st.label || (st.ready ? "OK" : "");
  $("correct-lat").textContent = `${state.locale === "en" ? "Fix" : "Sửa"} ${ms(state.boot?.lastLatency?.correct)}`;
  $("rotate-toggle").checked = corr.mode === "rotate";
  $("auto-correct-toggle").checked = !!state.prefs?.autoCorrectAfterDictate;
  $("selected-count").textContent = state.modelsLoading
    ? state.locale === "en"
      ? "Loading models…"
      : "Đang tải model…"
    : `${state.selected.length} model`;

  renderActiveBox();

  const enabled = hasKey();
  const rows = modelList()
    .map((m) => {
      const picked = isSelected(m.id);
      const active = isActive(m.id);
      return `<button type="button" class="model-row ${picked ? "picked" : ""} ${active ? "active" : ""}"
        data-m="${esc(m.id)}" ${enabled ? "" : "disabled"} title="${esc(m.id)}">
        <span class="model-row-check">${picked ? "●" : "○"}</span>
        <span class="model-row-label">${esc(m.label || m.id)}</span>
        ${active ? `<span class="model-row-badge">${state.locale === "en" ? "Active" : "Đang dùng"}</span>` : ""}
      </button>`;
    })
    .join("");
  const note = enabled
    ? state.models?.source === "live"
      ? ""
      : `<p class="hint">${state.locale === "en" ? "Catalog fallback — reload after adding key." : "Danh sách mặc định — tải lại sau khi thêm key."}</p>`
    : `<p class="hint">${state.locale === "en" ? "Add a key to enable text fixing." : "Thêm key để bật sửa văn bản."}</p>`;
  $("aistudio-models").innerHTML = `<div class="model-list">${rows}</div>${note}`;

  document.querySelectorAll(".model-row[data-m]").forEach((btn) => {
    btn.onclick = async () => {
      if (btn.disabled) return;
      await toggleModel(btn.dataset.m);
    };
  });
}

$("rotate-toggle").onchange = async () => {
  const on = $("rotate-toggle").checked;
  if (on && state.selected.length < 2) {
    $("rotate-toggle").checked = false;
    return toast(state.locale === "en" ? "Pick ≥ 2 models" : "Chọn ≥ 2 model", false);
  }
  await saveCorrect({ mode: on ? "rotate" : "single", selected: state.selected });
  toast(on ? (state.locale === "en" ? "Rotate on" : "Xoay bật") : "1 model");
};

$("auto-correct-toggle").onchange = async () => {
  const on = $("auto-correct-toggle").checked;
  await api("/v1/config/prefs", {
    method: "PUT",
    body: JSON.stringify({ autoCorrectAfterDictate: on }),
  });
  await refresh();
  toast(on ? (state.locale === "en" ? "Auto-fix ON" : "Tự sửa: BẬT") : (state.locale === "en" ? "Auto-fix OFF" : "Tự sửa: TẮT"));
};

$("btn-test-correct").onclick = async () => {
  if (!hasKey()) return toast(state.locale === "en" ? "Add a key first" : "Thêm key trước đã", false);
  try {
    const r = await api("/v1/test/correct", {
      method: "POST",
      body: JSON.stringify({ text: "xin chao Clude Code", profile: "light" }),
    });
    $("test-out").hidden = false;
    $("test-out").textContent = `${r.text}\n// ${r.model} · ${ms(r.latency_ms)}`;
    await refresh();
    toast(`OK · ${ms(r.latency_ms)}`);
  } catch (e) {
    toast(String(e.message || e), false);
  }
};

$("btn-chatgpt-login").addEventListener("click", (e) => {
  e.preventDefault();
  openChatGPTLoginDeepLink();
});

/* —— render / refresh —— */
function render() {
  const L = t();
  const st = state.boot?.status || {};
  const ready = st.status === "ready";
  $("system-pill").className = `pill ${ready ? "ok" : "warn"}`;
  $("system-pill").textContent = ready ? L.statusReady : L.statusNeedsSetup;
  $("foot-version").textContent = `Nói ${APP_VERSION}`;
  applyLocaleStrings();
  renderSetupStatus();
  renderKeyRow();
  renderModels();
}

async function refresh() {
  const boot = await api("/v1/bootstrap");
  state.boot = boot;
  state.prefs = boot.prefs;
  state.secrets = boot.secrets;
  state.locale = boot.prefs?.locale === "en" ? "en" : "vi";
  const corr = state.prefs?.correct || {};
  state.selected =
    Array.isArray(corr.selected) && corr.selected.length
      ? corr.selected.map((s) => ({ providerId: "aistudio", modelId: s.modelId }))
      : [{ providerId: "aistudio", modelId: corr.activeModelId || "gemma-4-26b-a4b-it" }];
  render();
  if (hasKey() && !state.models) loadModels().catch(() => {});
}

refresh().catch((e) => {
  document.body.innerHTML = `<pre style="color:#b4261a;padding:24px">local-core offline\n${e}</pre>`;
});
