/**
 * Correction prompts — bilingual (vi default / en).
 * Focus: ASR errors, stutters, proper nouns / technical terms.
 * light  = basic (auto after STT)
 * balanced / rewrite = stronger (Option double-tap)
 */

const LIGHT_VI = `Bạn là bộ sửa lỗi nhận dạng giọng nói (ASR) tiếng Việt và tiếng Anh.
Chỉ trả về văn bản đã sửa — không nhãn, không markdown, không giải thích.
Ưu tiên sửa: lỗi nghe nhầm theo ngữ cảnh, thiếu dấu, nói lắp/lặp từ, danh từ riêng và thuật ngữ kỹ thuật sai, dấu câu và viết hoa nhẹ.
Sửa tối thiểu — giữ nguyên ý và giọng điệu. Không thêm sự kiện. Đúng rồi thì trả nguyên văn.
Khi ngữ cảnh cho phép: ChatGPT, OpenAI, Claude, Anthropic, Gemini, DeepSeek, xAI, Grok, Cursor. Không bịa tên.`;

const LIGHT_EN = `You are an ASR (speech-to-text) correction engine for English and Vietnamese.
Return ONLY the final text — no labels, markdown, or explanation.
Fix: misheard words from context, missing diacritics, stutters/repeated words, wrong proper nouns and technical terms, light punctuation and capitalization.
Minimal edits — keep meaning and tone. Do not invent facts. If already correct, return unchanged.
When context supports them: ChatGPT, OpenAI, Claude, Anthropic, Gemini, DeepSeek, xAI, Grok, Cursor. Never invent names.`;

const BALANCED_VI = `Bạn là biên tập viên cẩn thận cho ghi chú nói (Việt/Anh).
Chỉ trả về văn bản cuối.
Sửa lỗi ASR, nói lắp, thuật ngữ, ngữ pháp, dấu câu, mạch câu. Giữ nghĩa và khẳng định. Không bịa. Không dịch sang ngôn ngữ khác.`;

const BALANCED_EN = `You are a careful editor for spoken notes (English/Vietnamese).
Return ONLY the final text.
Fix ASR errors, stutters, terminology, grammar, punctuation, and flow. Keep meaning and claims. Do not invent facts. Never translate to another language.`;

const REWRITE_VI = `Viết lại cho rõ ràng, cùng ngôn ngữ với đầu vào. Chỉ trả về văn bản cuối.
Giữ mọi khẳng định sự thật; không bịa. Cải thiện cấu trúc và dễ đọc. Không markdown.`;

const REWRITE_EN = `Rewrite for clarity in the SAME language as the input. Return ONLY the final text.
Keep all factual claims; do not invent. Improve structure and readability. No markdown fences.`;

/** @type {Record<string, Record<'vi'|'en', { system: string }>>} */
export const PROFILES = {
  light: { vi: { system: LIGHT_VI }, en: { system: LIGHT_EN } },
  balanced: { vi: { system: BALANCED_VI }, en: { system: BALANCED_EN } },
  rewrite: { vi: { system: REWRITE_VI }, en: { system: REWRITE_EN } },
};

/**
 * @param {string} profile
 * @param {string} [locale] 'vi' | 'en'
 */
export function resolveProfileSystem(profile, locale = "vi") {
  const loc = locale === "en" ? "en" : "vi";
  const p = PROFILES[profile] || PROFILES.light;
  return (p[loc] || p.vi).system;
}

/**
 * @param {string} profile
 * @param {string} text
 * @param {string} [contextHint]
 * @param {Record<string, string>} [customPrompts]
 * @param {string} [locale]
 */
export function buildMessages(profile, text, contextHint, customPrompts, locale = "vi") {
  const custom = customPrompts?.[profile];
  const system = custom?.trim() ? custom.trim() : resolveProfileSystem(profile, locale);
  const userParts = [];
  if (contextHint?.trim()) userParts.push(`Context: ${contextHint.trim()}`);
  userParts.push(`Text:\n${text}`);
  return { system, user: userParts.join("\n") };
}

export function defaultPromptsMap(locale = "vi") {
  return {
    light: resolveProfileSystem("light", locale),
    balanced: resolveProfileSystem("balanced", locale),
    rewrite: resolveProfileSystem("rewrite", locale),
  };
}

export function stripModelNoise(text) {
  let t = (text || "").trim();
  if ((t.startsWith('"') && t.endsWith('"')) || (t.startsWith("'") && t.endsWith("'"))) {
    t = t.slice(1, -1).trim();
  }
  if (t.startsWith("```") && t.endsWith("```")) {
    t = t.replace(/^```[a-zA-Z]*\n?/, "").replace(/\n?```$/, "").trim();
  }
  const labeled = t.match(/^(?:Corrected|Output|Result|Đã sửa)\s*:\s*([\s\S]+)$/i);
  if (labeled) t = labeled[1].trim();
  return t;
}
