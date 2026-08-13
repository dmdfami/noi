import AppKit
import AVFoundation
import ApplicationServices
import Carbon.HIToolbox
import Foundation
import ServiceManagement

// MARK: - Config (env file — not Keychain)

enum V2Config {
    static let defaultURL = "http://127.0.0.1:8797"
    static var baseURL: String {
        ProcessInfo.processInfo.environment["CHATGPT_AUDIO_LOCAL_URL"]
            ?? UserDefaults.standard.string(forKey: "localCoreURL")
            ?? defaultURL
    }

    /// Resolved launch paths for local-core (bundled first, then dev checkout).
    struct CoreLaunch: Equatable {
        let nodePath: String
        let cliPath: String
        let coreDir: String
        /// "bundled" | "dev"
        let source: String
    }

    /// Prefer embedded Resources/runtime/node + Resources/local-core (shipped).
    /// Dev machines fall back to system `node` + git checkout.
    static func resolveCoreLaunch(bundle: Bundle = .main) -> CoreLaunch? {
        let fm = FileManager.default
        // 1) Shipped layout inside .app
        if let res = bundle.resourceURL {
            let node = res.appendingPathComponent("runtime/node").path
            let coreDir = res.appendingPathComponent("local-core").path
            let cli = (coreDir as NSString).appendingPathComponent("cli.mjs")
            if fm.isExecutableFile(atPath: node), fm.fileExists(atPath: cli) {
                return CoreLaunch(nodePath: node, cliPath: cli, coreDir: coreDir, source: "bundled")
            }
        }
        // 2) Dev: repo checkout + PATH node
        let repo = findDevRepoRoot()
        let cli = (repo as NSString).appendingPathComponent("packages/local-core/cli.mjs")
        guard fm.fileExists(atPath: cli) else { return nil }
        let node = resolveSystemNode() ?? "/usr/bin/env"
        // When using env, arguments still pass "node" as first arg — handled by caller
        return CoreLaunch(nodePath: node, cliPath: cli, coreDir: (cli as NSString).deletingLastPathComponent, source: "dev")
    }

    static func findDevRepoRoot() -> String {
        let fm = FileManager.default
        // Optional legacy hint file (older builds)
        if let bundleRoot = Bundle.main.resourceURL?
            .appendingPathComponent("repo-root.txt").path,
            let text = try? String(contentsOfFile: bundleRoot, encoding: .utf8)
        {
            let path = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if fm.fileExists(atPath: path + "/packages/local-core/cli.mjs") {
                return path
            }
        }
        let candidates = [
            NSHomeDirectory() + "/dev/chatgpt-audio-client",
            FileManager.default.currentDirectoryPath,
        ]
        for c in candidates {
            if fm.fileExists(atPath: c + "/packages/local-core/cli.mjs") {
                return c
            }
        }
        return candidates[0]
    }

    static func resolveSystemNode() -> String? {
        let fm = FileManager.default
        let candidates = [
            ProcessInfo.processInfo.environment["CHATGPT_AUDIO_NODE_BIN"],
            NSHomeDirectory() + "/.hermes/node/bin/node",
            NSHomeDirectory() + "/.local/bin/node",
            "/opt/homebrew/bin/node",
            "/usr/local/bin/node",
        ].compactMap { $0 }
        for c in candidates where fm.isExecutableFile(atPath: c) {
            return c
        }
        // which node via PATH
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        p.arguments = ["node"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        try? p.run()
        p.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !path.isEmpty, fm.isExecutableFile(atPath: path) { return path }
        return nil
    }

    static var token: String {
        if let t = ProcessInfo.processInfo.environment["LOCAL_CORE_TOKEN"], !t.isEmpty { return t }
        // Read from ~/.config/chatgpt-audio/v2.env
        let path = NSHomeDirectory() + "/.config/chatgpt-audio/v2.env"
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return "" }
        for line in text.split(separator: "\n") {
            let s = line.trimmingCharacters(in: .whitespaces)
            if s.hasPrefix("LOCAL_CORE_TOKEN=") {
                return String(s.dropFirst("LOCAL_CORE_TOKEN=".count))
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            }
        }
        return ""
    }
}

// MARK: - Local HTTP client

final class LocalCoreClient: @unchecked Sendable {
    let baseURL: String
    let token: String
    init(baseURL: String = V2Config.baseURL, token: String = V2Config.token) {
        self.baseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.token = token
    }

    func health() async throws -> Bool {
        let (data, _) = try await get("/healthz")
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return (obj?["ok"] as? Bool) == true
    }

    func transcribe(fileURL: URL) async throws -> String {
        let fileData = try Data(contentsOf: fileURL)
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        let data = try await request(
            path: "/v1/audio/transcriptions",
            method: "POST",
            body: body,
            contentType: "multipart/form-data; boundary=\(boundary)"
        )
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let text = obj?["text"] as? String else { throw LocalError.decode }
        return text
    }

    /// intent: "auto" (basic after STT) | "hotkey" (stronger ⌥⌥) | nil + profile
    func correct(text: String, profile: String? = nil, intent: String? = nil) async throws -> String {
        var payload: [String: Any] = ["text": text]
        if let intent, !intent.isEmpty { payload["intent"] = intent }
        if let profile, !profile.isEmpty { payload["profile"] = profile }
        let body = try JSONSerialization.data(withJSONObject: payload)
        let data = try await request(
            path: "/v1/text/correct",
            method: "POST",
            body: body,
            contentType: "application/json"
        )
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let out = obj?["text"] as? String else { throw LocalError.decode }
        return out
    }

    /// Save secrets to local-core v2.env
    func putSecrets(_ patch: [String: String]) async throws {
        let body = try JSONSerialization.data(withJSONObject: patch)
        _ = try await request(
            path: "/v1/config/secrets",
            method: "PUT",
            body: body,
            contentType: "application/json"
        )
    }

    func status() async throws -> [String: Any] {
        let (data, _) = try await get("/v1/status")
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LocalError.decode
        }
        return obj
    }

    func prefs() async throws -> [String: Any] {
        let (data, _) = try await get("/v1/config")
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LocalError.decode
        }
        return (obj["prefs"] as? [String: Any]) ?? obj
    }

    func putPrefs(_ patch: [String: Any]) async throws {
        let body = try JSONSerialization.data(withJSONObject: patch)
        _ = try await request(
            path: "/v1/config/prefs",
            method: "PUT",
            body: body,
            contentType: "application/json"
        )
    }

    private func get(_ path: String) async throws -> (Data, HTTPURLResponse) {
        var req = URLRequest(url: URL(string: baseURL + path)!)
        req.httpMethod = "GET"
        if !token.isEmpty { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, res) = try await URLSession.shared.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw LocalError.network }
        return (data, http)
    }

    private func request(path: String, method: String, body: Data?, contentType: String?) async throws -> Data {
        var req = URLRequest(url: URL(string: baseURL + path)!)
        req.httpMethod = method
        req.httpBody = body
        if let contentType { req.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        if !token.isEmpty { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        req.timeoutInterval = 60
        let (data, res) = try await URLSession.shared.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw LocalError.network }
        if http.statusCode >= 400 {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw LocalError.http(http.statusCode, msg)
        }
        return data
    }
}

enum LocalError: LocalizedError {
    case network, decode, http(Int, String), noMic, empty
    var errorDescription: String? {
        switch self {
        case .network: return "Local core unreachable — start packages/local-core"
        case .decode: return "Bad response"
        case .http(let c, let m): return "HTTP \(c): \(m.prefix(120))"
        case .noMic: return "Microphone permission required"
        case .empty: return "Empty result"
        }
    }
}

// MARK: - Mic

final class MicRecorder: NSObject {
    private var recorder: AVAudioRecorder?
    private(set) var isRecording = false
    private var fileURL: URL?

    static func authStatus() -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .audio)
    }

    func requestAccess() async -> Bool {
        await withCheckedContinuation { cont in
            AVCaptureDevice.requestAccess(for: .audio) { cont.resume(returning: $0) }
        }
    }

    func start() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("v2-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        let r = try AVAudioRecorder(url: url, settings: settings)
        r.record()
        recorder = r
        fileURL = url
        isRecording = true
    }

    func stop() -> URL? {
        recorder?.stop()
        isRecording = false
        let url = fileURL
        recorder = nil
        fileURL = nil
        return url
    }
}

// MARK: - Selection / paste / clipboard (terminal-aware)

/// Where target text came from — drives how we write the result back.
enum TextSource: String {
    /// Highlighted selection in an editor
    case selection
    /// Full content of focused text field (no selection)
    case field
    /// Pasteboard — terminals that auto-copy on select then clear highlight
    case clipboard
}

enum SelectionService {
    /// Cap full-field grabs so terminal scrollbacks never freeze correct/TTS
    private static let maxFieldChars = 12_000

    static func isAXTrusted(prompt: Bool) -> Bool {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    /**
     Resolve text for Speak / Correct (fast path, no main-thread hang):

     1. AX **selected** text only (if non-empty)
     2. **Clipboard** if non-empty (CLI auto-copy / user Cmd+C without caret)
     3. Full focused **real** text field/area (not terminal scrollback)
     4. Never synthetic Cmd+C when clipboard already has content (would clear it & freeze)
     */
    static func resolveTargetText() -> (text: String, source: TextSource)? {
        let clipRaw = NSPasteboard.general.string(forType: .string) ?? ""
        let clip = clipRaw.trimmingCharacters(in: .whitespacesAndNewlines)

        // AX can hang; keep timeouts short and never treat "any AXValue" as a field.
        if isAXTrusted(prompt: false), let el = focusedElement() {
            AXUIElementSetMessagingTimeout(el, 0.35)

            if let sel = axString(el, kAXSelectedTextAttribute as CFString) {
                let t = sel.trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { return (sel, .selection) }
            }

            // Prefer clipboard over full field when user already copied and nothing is highlighted.
            // (Terminals often leave focus on a huge AXValue "field" with no caret/selection.)
            if !clip.isEmpty {
                return (clipRaw, .clipboard)
            }

            if isEditableTextControl(el), let full = axString(el, kAXValueAttribute as CFString) {
                let t = full.trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty {
                    if full.count > maxFieldChars {
                        // Too large (e.g. terminal buffer) — refuse rather than freeze
                        return nil
                    }
                    return (full, .field)
                }
            }
        }

        if !clip.isEmpty {
            return (clipRaw, .clipboard)
        }

        // No clipboard + no AX text: do NOT Cmd+C (blocks UI, often empty). Fail fast.
        return nil
    }

    /// Non-blocking resolve for use from async MainActor tasks.
    static func resolveTargetTextAsync() async -> (text: String, source: TextSource)? {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                cont.resume(returning: resolveTargetText())
            }
        }
    }

    /// Apply corrected/result text back to the source.
    static func applyResult(_ text: String, source: TextSource) {
        switch source {
        case .selection, .field:
            insertText(text, activate: NSWorkspace.shared.frontmostApplication)
        case .clipboard:
            // No caret: only update pasteboard — never inject keys into random front app
            copyToClipboard(text)
        }
    }

    static func readSelection() -> String? {
        resolveTargetText()?.text
    }

    /// Leave text on clipboard.
    static func copyToClipboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    /// True when Input Monitoring is granted (needed for CGEvent key posting on recent macOS).
    static func hasInputMonitoring() -> Bool {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, _, event, _ in
                Unmanaged.passUnretained(event)
            },
            userInfo: nil
        ) else { return false }
        CFMachPortInvalidate(tap)
        return true
    }

    static func requestInputMonitoring() {
        _ = hasInputMonitoring()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    /**
     Insert at caret.
     - TextEdit / Notes / native fields: AX insert (works with Accessibility).
     - Terminal / browser / Electron / IDE: **keyboard paste only** (AX lies or is wrong).
     - Always keep clipboard for manual Cmd+V.
     */
    @discardableResult
    static func insertText(_ text: String, activate app: NSRunningApplication? = nil) -> Bool {
        guard !text.isEmpty else { return false }
        _ = isAXTrusted(prompt: true)

        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)

        var targetApp = app
        if targetApp == nil || targetApp?.isTerminated == true {
            targetApp = NSWorkspace.shared.frontmostApplication
        }
        var pid = targetApp?.processIdentifier

        if let app = targetApp, !app.isTerminated {
            let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
            if front != app.processIdentifier {
                app.activate()
                usleep(200_000)
            }
            pid = app.processIdentifier
        }

        releaseModifierKeys()

        let keyboardOnly = pid.map { prefersKeyboardPaste(pid: $0) } ?? true

        // AX only for real text fields (TextEdit etc.) — NOT Terminal/CLI
        if !keyboardOnly, let pid, pid > 0, insertViaAX(text, pid: pid) {
            pb.clearContents()
            pb.setString(text, forType: .string)
            return true
        }

        // Keyboard paste path (Terminal, browsers, IDEs…)
        if !hasInputMonitoring() {
            if !didPromptInputMonitoring {
                didPromptInputMonitoring = true
                requestInputMonitoring()
            }
        }

        // Longer settle for terminal after modifier release
        usleep(keyboardOnly ? 80_000 : 30_000)
        postCommandV()
        usleep(keyboardOnly ? 180_000 : 120_000)

        // System Events backup (needs Automation / Accessibility for this app)
        _ = pasteViaSystemEvents()
        usleep(80_000)

        pb.clearContents()
        pb.setString(text, forType: .string)
        return true
    }

    private static var didPromptInputMonitoring = false

    static func pasteText(_ text: String) {
        insertText(text, activate: nil)
    }

    static func replaceSelection(with text: String) {
        insertText(text, activate: nil)
    }

    /// Exposed for HUD hints after STT.
    static func prefersKeyboardPastePublic(pid: pid_t) -> Bool {
        prefersKeyboardPaste(pid: pid)
    }

    /// Terminals / browsers / Electron: never trust AX value/selected-text writes.
    private static func prefersKeyboardPaste(pid: pid_t) -> Bool {
        let bid = (NSRunningApplication(processIdentifier: pid)?.bundleIdentifier ?? "").lowercased()
        if bid.isEmpty { return true }
        // Terminals / shells
        if bid == "com.apple.terminal"
            || bid.hasPrefix("com.googlecode.iterm2")
            || bid.contains("iterm")
            || bid.contains("warp")
            || bid.contains("alacritty")
            || bid.contains("kitty")
            || bid.contains("wezterm")
            || bid.contains("ghostty")
            || bid.contains("hyper")
            || bid.contains("cmux")
            || bid.contains("tabby")
            || bid.contains("rio")
        {
            return true
        }
        // Browsers
        if bid.contains("safari") || bid.contains("chrome") || bid.contains("firefox")
            || bid.contains("edge") || bid.contains("brave") || bid.contains("arc")
            || bid.contains("chromium")
        {
            return true
        }
        // Editors / Electron
        if bid.contains("code") || bid.contains("cursor") || bid.contains("vscode")
            || bid.contains("electron") || bid.contains("slack") || bid.contains("discord")
            || bid.contains("notion") || bid.contains("figma") || bid.contains("zed")
        {
            return true
        }
        return false
    }

    // MARK: AX insert (native text fields only)

    private static func insertViaAX(_ text: String, pid: pid_t) -> Bool {
        let appEl = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appEl, 0.5)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appEl, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused
        else { return false }
        let el = focused as! AXUIElement
        AXUIElementSetMessagingTimeout(el, 0.5)

        // Only real editable roles — never Terminal scrollback “value”
        guard isEditableTextControl(el) else { return false }

        var settable = DarwinBoolean(false)
        if AXUIElementIsAttributeSettable(el, kAXSelectedTextAttribute as CFString, &settable) == .success,
           !settable.boolValue
        {
            // Not settable → keyboard path
            return false
        }

        AXUIElementSetAttributeValue(el, kAXFocusedAttribute as CFString, kCFBooleanTrue)

        let setSel = AXUIElementSetAttributeValue(el, kAXSelectedTextAttribute as CFString, text as CFTypeRef)
        if setSel == .success {
            // Verify when possible
            var after: CFTypeRef?
            if AXUIElementCopyAttributeValue(el, kAXValueAttribute as CFString, &after) == .success,
               let s = after as? String, s.contains(text)
            {
                return true
            }
            // Some fields don't expose value but did accept selected text
            return true
        }
        return false
    }

    // MARK: Keyboard

    private static func releaseModifierKeys() {
        let codes: [CGKeyCode] = [59, 62, 58, 61, 56, 60]
        guard let src = CGEventSource(stateID: .hidSystemState) else { return }
        for code in codes {
            if let up = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: false) {
                up.flags = []
                up.post(tap: .cghidEventTap)
                up.post(tap: .cgSessionEventTap)
            }
        }
        usleep(30_000)
    }

    private static func postCommandV() {
        let vKey = CGKeyCode(kVK_ANSI_V)
        let cmdKey = CGKeyCode(kVK_Command)
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let commandDown = CGEvent(keyboardEventSource: source, virtualKey: cmdKey, keyDown: true),
              let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false),
              let commandUp = CGEvent(keyboardEventSource: source, virtualKey: cmdKey, keyDown: false)
        else { return }

        commandDown.flags = [.maskCommand]
        down.flags = [.maskCommand]
        up.flags = [.maskCommand]
        commandUp.flags = []

        for e in [commandDown, down, up, commandUp] {
            e.post(tap: .cghidEventTap)
            e.post(tap: .cgSessionEventTap)
        }
    }

    private static func pasteViaSystemEvents() -> Bool {
        let source = """
        tell application "System Events"
          keystroke "v" using {command down}
        end tell
        """
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return false }
        _ = script.executeAndReturnError(&error)
        return error == nil
    }

    // MARK: AX helpers (resolveTargetText)

    private static func focusedElement() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.35)
        var ref: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &ref)
        guard err == .success, let ref else { return nil }
        return (ref as! AXUIElement)
    }

    private static func axString(_ el: AXUIElement, _ attr: CFString) -> String? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attr, &ref) == .success else { return nil }
        if let s = ref as? String { return s }
        return nil
    }

    private static func isEditableTextControl(_ el: AXUIElement) -> Bool {
        guard let role = axString(el, kAXRoleAttribute as CFString) else { return false }
        switch role {
        case "AXTextField", "AXTextArea", "AXComboBox", "AXSearchField":
            return true
        default:
            return false
        }
    }
}

// MARK: - Hotkeys
// STT:  Control+Option hold (push-to-talk) OR double-tap chord (toggle).
// Correct: double-tap bare Option.
// Speak: double-tap bare Control (Control alone no longer owns STT → Ctrl+C/V safe).
// Cancel: Escape anytime (stop record / correct / speak).

final class HotKeyMonitor {
    /// Toggle STT (double-tap ⌃⌥) — start if idle, stop if recording
    var onSTTToggle: (() -> Void)?
    /// Hold ⌃⌥ long enough → start recording (no-op if already recording)
    var onSTTHoldStart: (() -> Void)?
    /// Release after hold-started recording → finish STT
    var onSTTHoldEnd: (() -> Void)?
    var onCorrect: (() -> Void)?
    /// Escape → cancel in-flight work
    var onCancel: (() -> Void)?

    private var controlDown = false
    private var optionDown = false
    private var controlSawOtherKey = false
    private var optionSawOtherKey = false
    private var chordSawOtherKey = false

    private var lastBareControlUp: TimeInterval = 0
    private var lastBareOptionUp: TimeInterval = 0
    private var lastChordUp: TimeInterval = 0
    private let doubleTapWindow: TimeInterval = 0.40
    /// Hold threshold before PTT starts (avoids treating a quick chord tap as hold)
    private let holdThreshold: TimeInterval = 0.18

    private var chordActive = false
    private var chordDownAt: TimeInterval = 0
    private var holdStarted = false
    private var holdTimer: DispatchWorkItem?

    private var monitor: Any?
    private var localMonitor: Any?

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] e in
            self?.handle(e)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] e in
            self?.handle(e)
            return e
        }
    }

    private func handle(_ e: NSEvent) {
        let flags = e.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let c = flags.contains(.control)
        let o = flags.contains(.option)
        let cmd = flags.contains(.command)
        let shift = flags.contains(.shift)

        if e.type == .keyDown {
            // Escape = cancel current STT/correct/TTS (keyCode 53)
            if e.keyCode == 53 && !cmd && !shift {
                onCancel?()
                return
            }
            let isModifierOnly =
                e.keyCode == 59 || e.keyCode == 62 // left/right control
                || e.keyCode == 58 || e.keyCode == 61 // option
                || e.keyCode == 55 || e.keyCode == 54 // command
                || e.keyCode == 56 || e.keyCode == 60 // shift
            if !isModifierOnly {
                if controlDown { controlSawOtherKey = true }
                if optionDown { optionSawOtherKey = true }
                if controlDown && optionDown { chordSawOtherKey = true }
            }
            return
        }

        guard e.type == .flagsChanged else { return }

        let both = c && o && !cmd
        let wasBoth = controlDown && optionDown

        // —— Control+Option chord (STT) ——
        if both && !wasBoth {
            // Chord just engaged
            controlSawOtherKey = true // bare Control/Option double-taps cancelled
            optionSawOtherKey = true
            chordSawOtherKey = false
            chordActive = true
            chordDownAt = ProcessInfo.processInfo.systemUptime
            holdStarted = false
            scheduleHoldStart()
        } else if wasBoth && !both {
            // Chord released (either modifier up)
            cancelHoldTimer()
            let now = ProcessInfo.processInfo.systemUptime
            let held = now - chordDownAt
            if holdStarted {
                // Push-to-talk end
                holdStarted = false
                onSTTHoldEnd?()
                lastChordUp = 0
            } else if !chordSawOtherKey && held < holdThreshold {
                // Short chord tap → double-tap toggle window
                if lastChordUp > 0, now - lastChordUp <= doubleTapWindow {
                    lastChordUp = 0
                    onSTTToggle?()
                } else {
                    lastChordUp = now
                }
            } else {
                lastChordUp = 0
            }
            // Don't let chord release seed bare Control/Option double-taps
            lastBareControlUp = 0
            lastBareOptionUp = 0
            chordActive = false
            chordSawOtherKey = false
        }

        // Bare Control is no longer a hotkey (TTS removed). Just keep tracking state.
        if controlDown && !c {
            controlSawOtherKey = false
        }
        if !controlDown && c {
            controlSawOtherKey = false
        }

        // —— Bare Option released → double-tap Correct ——
        if optionDown && !o {
            let bare =
                !optionSawOtherKey
                && !c && !cmd && !shift
                && !chordActive
            if bare {
                let now = ProcessInfo.processInfo.systemUptime
                if now - lastBareOptionUp <= doubleTapWindow, lastBareOptionUp > 0 {
                    lastBareOptionUp = 0
                    onCorrect?()
                } else {
                    lastBareOptionUp = now
                }
            } else {
                lastBareOptionUp = 0
            }
            optionSawOtherKey = false
        }
        if !optionDown && o {
            optionSawOtherKey = false
        }

        controlDown = c
        optionDown = o
    }

    private func scheduleHoldStart() {
        cancelHoldTimer()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            // Still holding both, no other keys, not already armed
            guard self.controlDown, self.optionDown, !self.chordSawOtherKey, !self.holdStarted else { return }
            self.holdStarted = true
            self.lastChordUp = 0 // don't also fire double-tap
            self.onSTTHoldStart?()
        }
        holdTimer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + holdThreshold, execute: work)
    }

    private func cancelHoldTimer() {
        holdTimer?.cancel()
        holdTimer = nil
    }
}

// MARK: - HUD (same essence as v1: Listening / Transcribing / Correcting / Speaking)

enum HUDState: Equatable {
    case idle, listening, transcribing, correcting, done, stopped, error(String)
}

// MARK: - App

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()
    let client = LocalCoreClient()
    let mic = MicRecorder()
    let chatLogin = ChatGPTLoginWindowController()
    let configDashboard = ConfigDashboardWindowController()
    let permissionsWindow = PermissionsSetupWindowController()
    let menuBar = MenuBarController()
    var busy = false
    weak var statusItem: NSStatusItem?
    weak var menuCancel: NSMenuItem?
    weak var menuAutoCorrect: NSMenuItem?
    weak var menuLaunchLogin: NSMenuItem?
    private var statusTimer: Timer?
    /// Spawned local-core process (bundled or dev)
    private var coreProcess: Process?
    /// In-flight STT/correct task — cancelled by Esc / menu / re-trigger
    private var workTask: Task<Void, Never>?
    /// App that had focus when dictation started — restore before paste
    private var sttTargetApp: NSRunningApplication?
    var autoCorrectAfterDictate = false
    /// Last resolve source for diagnostics ("bundled" | "dev" | "running" | "none")
    private(set) var coreSource: String = "none"

    var isActiveWork: Bool {
        busy || mic.isRecording
    }

    func setHUD(_ state: HUDState) {
        FloatingHUD.shared.show(state)
        let sym = menuBar.hudSymbol(for: state)
        menuBar.applyBarIcon(symbol: sym, badge: !PermissionsSetupWindowController.snapshot().allOK)
        menuCancel?.isEnabled = isActiveWork || state == .listening || state == .transcribing
            || state == .correcting
        PopoverModel.shared.canStop = menuCancel?.isEnabled == true
        if case .done = state, !busy, !mic.isRecording {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self, !self.isActiveWork else { return }
                self.menuBar.applyBarIcon(
                    symbol: DesignTokens.Symbol.menuIdle,
                    badge: !PermissionsSetupWindowController.snapshot().allOK
                )
                PopoverModel.shared.canStop = self.isActiveWork
            }
        }
    }

    /// Stop recording (discard), cancel network task.
    func cancelAll() {
        workTask?.cancel()
        workTask = nil
        if mic.isRecording {
            if let url = mic.stop() {
                try? FileManager.default.removeItem(at: url)
            }
        }
        busy = false
        setHUD(.stopped)
        menuCancel?.isEnabled = false
    }

    /// Primary (only) config surface: in-app WKWebView after ensureCore.
    func openDashboard() {
        Task { @MainActor in
            await ensureCore()
            configDashboard.onDeepLink = { [weak self] url in
                self?.handleDeepLink(url)
            }
            configDashboard.show(urlString: V2Config.baseURL + "/")
        }
    }

    /// Deep links from dashboard / URL scheme: chatgpt-audio-local://login
    func handleDeepLink(_ url: URL) {
        let host = (url.host ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))).lowercased()
        switch host {
        case "login", "chatgpt", "auth":
            openChatGPTLogin()
        case "config", "settings", "":
            openDashboard()
        case "cancel", "stop":
            cancelAll()
        default:
            if url.path.contains("login") {
                openChatGPTLogin()
            }
        }
    }

    func openChatGPTLogin() {
        chatLogin.onSuccess = { [weak self] token, _ in
            Task { @MainActor in
                do {
                    try await self?.client.putSecrets(["CHATGPT_ACCESS_TOKEN": token])
                    self?.setHUD(.done)
                    await self?.refreshMenuStatus()
                    self?.configDashboard.reload()
                } catch {
                    self?.setHUD(.error("Save token failed"))
                }
            }
        }
        // Always clear session + reload login so "Đổi tài khoản" works even if window already open.
        Task { @MainActor in
            try? await client.putSecrets(["CHATGPT_ACCESS_TOKEN": ""])
            chatLogin.show(forceRelogin: true)
        }
    }

    func startTokenRefresh() {
        ChatGPTSession.startAutoRefresh { token, _ in
            Task { @MainActor in
                try? await AppState.shared.client.putSecrets(["CHATGPT_ACCESS_TOKEN": token])
                await AppState.shared.refreshMenuStatus()
            }
        }
    }

    func startStatusPolling() {
        statusTimer?.invalidate()
        statusTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { _ in
            Task { @MainActor in await AppState.shared.refreshMenuStatus() }
        }
        Task { await refreshMenuStatus() }
    }

    func refreshMenuStatus() async {
        do {
            let st = try await client.status()
            if let p = try? await client.prefs() {
                AppStrings.setLocale(from: p)
                autoCorrectAfterDictate = p["autoCorrectAfterDictate"] as? Bool ?? false
                menuAutoCorrect?.state = autoCorrectAfterDictate ? .on : .off
            }
            let stt = st["stt"] as? [String: Any]
            let corr = st["correction"] as? [String: Any]
            let acc = stt?["account"] as? [String: Any]
            let sttReady = stt?["ready"] as? Bool ?? false
            let corrReady = corr?["ready"] as? Bool ?? false
            let email = acc?["email"] as? String
            let name = acc?["name"] as? String
            let perms = PermissionsSetupWindowController.snapshot()

            menuBar.updateStatusHeader(sttReady: sttReady, corrReady: corrReady, allPermsOK: perms.allOK)
            menuBar.updateAccount(name: name, email: email, sttReady: sttReady)
            menuBar.updatePermissionsMenu(snapshot: perms)
            PopoverModel.shared.apply(
                sttReady: sttReady,
                corrReady: corrReady,
                allPermsOK: perms.allOK,
                accountName: name,
                accountEmail: email,
                snap: perms,
                autoCorrect: autoCorrectAfterDictate,
                launchAtLogin: launchAtLoginEnabled,
                canStop: isActiveWork
            )

            if !busy {
                menuBar.applyBarIcon(
                    symbol: DesignTokens.Symbol.menuIdle,
                    badge: !perms.allOK
                )
            }
        } catch {
            PopoverModel.shared.statusDetail = AppStrings.statusSetupNeeded
            PopoverModel.shared.aggregateReady = false
        }
    }

    /// Start embedded (or dev) local-core if /healthz is not already OK.
    func ensureCore() async {
        do {
            if try await client.health() {
                if coreSource == "none" { coreSource = "running" }
                return
            }
        } catch { /* need spawn */ }

        // Reap dead process handle
        if let old = coreProcess, !old.isRunning {
            coreProcess = nil
        }
        if coreProcess?.isRunning == true {
            // Wait a bit for still-starting process
            for _ in 0..<15 {
                try? await Task.sleep(nanoseconds: 200_000_000)
                if (try? await client.health()) == true { return }
            }
        }

        guard let launch = V2Config.resolveCoreLaunch() else {
            coreSource = "none"
            return
        }
        coreSource = launch.source

        let p = Process()
        p.executableURL = URL(fileURLWithPath: launch.nodePath)
        // Bundled node: argv = [cli.mjs, serve]
        // Dev node binary same; if path is node itself:
        p.arguments = [launch.cliPath, "serve"]
        p.currentDirectoryURL = URL(fileURLWithPath: launch.coreDir)
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        // Detach so core outlives brief app hiccups; still child of app session
        p.qualityOfService = .userInitiated
        do {
            try p.run()
            coreProcess = p
        } catch {
            coreSource = "none"
            return
        }

        for _ in 0..<40 {
            try? await Task.sleep(nanoseconds: 150_000_000)
            if (try? await client.health()) == true { return }
        }
    }

    /// Double-tap ⌃⌥: start listening, finish if recording, cancel if transcribing.
    func toggleSTT() {
        if busy && !mic.isRecording {
            cancelAll()
            return
        }
        if mic.isRecording {
            finishSTT()
            return
        }
        startSTT()
    }

    /// Hold ⌃⌥ (≥ hold threshold): begin push-to-talk if idle.
    func holdSTTStart() {
        guard !mic.isRecording, !busy else { return }
        startSTT()
    }

    /// Release after hold-started recording.
    func holdSTTEnd() {
        guard mic.isRecording else { return }
        finishSTT()
    }

    private func startSTT() {
        if busy { cancelAll() }
        guard !busy else { return }
        // Remember where the user was typing (not this menu-bar app)
        let front = NSWorkspace.shared.frontmostApplication
        if let front, front.bundleIdentifier != Bundle.main.bundleIdentifier {
            sttTargetApp = front
        }
        Task { @MainActor in
            if MicRecorder.authStatus() != .authorized {
                let ok = await mic.requestAccess()
                if !ok {
                    setHUD(.error("Mic permission"))
                    return
                }
            }
            // If permissions incomplete, open guided UI instead of silent failure
            let snap = PermissionsSetupWindowController.snapshot()
            if !snap.allOK {
                setHUD(.error("Thiếu quyền · xem menu AL"))
                openPermissions(force: true)
                // Still allow mic record if only paste perms missing — but warn
                if !snap.mic {
                    return
                }
            }
            do {
                try mic.start()
                setHUD(.listening)
                menuCancel?.isEnabled = true
            } catch {
                setHUD(.error("Mic error"))
            }
        }
    }

    func finishSTT() {
        guard mic.isRecording else { return }
        guard let url = mic.stop() else { return }
        let targetApp = sttTargetApp
        busy = true
        setHUD(.transcribing)
        workTask?.cancel()
        workTask = Task { @MainActor in
            defer {
                if !Task.isCancelled { busy = false }
                menuCancel?.isEnabled = self.isActiveWork
            }
            do {
                try Task.checkCancellation()
                let text = try await client.transcribe(fileURL: url)
                try Task.checkCancellation()
                var out = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !out.isEmpty else {
                    setHUD(.error("Empty"))
                    try? FileManager.default.removeItem(at: url)
                    return
                }
                if autoCorrectAfterDictate {
                    setHUD(.correcting)
                    if let fixed = try? await client.correct(text: out, intent: "auto") {
                        try Task.checkCancellation()
                        let t = fixed.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !t.isEmpty { out = t }
                    }
                }
                try Task.checkCancellation()
                // Let ⌃⌥ release settle, then paste (AX for TextEdit; keyboard for Terminal)
                try? await Task.sleep(nanoseconds: 200_000_000)
                try Task.checkCancellation()
                SelectionService.insertText(out, activate: targetApp)
                if let pid = targetApp?.processIdentifier,
                   SelectionService.prefersKeyboardPastePublic(pid: pid),
                   !SelectionService.hasInputMonitoring()
                {
                    setHUD(.error("Bật Input Monitoring"))
                } else {
                    setHUD(.done)
                }
                try? FileManager.default.removeItem(at: url)
            } catch is CancellationError {
                try? FileManager.default.removeItem(at: url)
                busy = false
                setHUD(.stopped)
            } catch {
                try? FileManager.default.removeItem(at: url)
                setHUD(.error(error.localizedDescription))
            }
        }
    }

    func toggleAutoCorrect() {
        autoCorrectAfterDictate.toggle()
        menuAutoCorrect?.state = autoCorrectAfterDictate ? .on : .off
        PopoverModel.shared.autoCorrect = autoCorrectAfterDictate
        Task {
            try? await client.putPrefs(["autoCorrectAfterDictate": autoCorrectAfterDictate])
        }
    }

    /// macOS 13+ SMAppService — start Local at login.
    var launchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func toggleLaunchAtLogin() {
        do {
            if launchAtLoginEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            menuLaunchLogin?.state = launchAtLoginEnabled ? .on : .off
            PopoverModel.shared.launchAtLogin = launchAtLoginEnabled
        } catch {
            setHUD(.error("Login item: \(error.localizedDescription)"))
        }
    }

    func refreshLaunchAtLoginMenu() {
        menuLaunchLogin?.state = launchAtLoginEnabled ? .on : .off
        PopoverModel.shared.launchAtLogin = launchAtLoginEnabled
    }

    func runCorrect() {
        // Second ⌥⌥ while correcting → cancel
        if busy {
            cancelAll()
            return
        }
        if mic.isRecording {
            if let url = mic.stop() {
                try? FileManager.default.removeItem(at: url)
            }
        }
        busy = true
        setHUD(.correcting)
        workTask?.cancel()
        workTask = Task { @MainActor in
            defer {
                if !Task.isCancelled { busy = false }
                menuCancel?.isEnabled = self.isActiveWork
            }
            do {
                guard let target = await SelectionService.resolveTargetTextAsync() else {
                    setHUD(.error("No text / clipboard"))
                    return
                }
                try Task.checkCancellation()
                let out = try await client.correct(text: target.text, intent: "hotkey")
                try Task.checkCancellation()
                SelectionService.applyResult(out, source: target.source)
                setHUD(.done)
            } catch is CancellationError {
                busy = false
                setHUD(.stopped)
            } catch {
                setHUD(.error(error.localizedDescription))
            }
        }
    }

    /// Enable launch-at-login once on first open (user can turn off in menu).
    func enableLaunchAtLoginIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: "v2.launchLoginPrimed") else {
            refreshLaunchAtLoginMenu()
            return
        }
        UserDefaults.standard.set(true, forKey: "v2.launchLoginPrimed")
        if !launchAtLoginEnabled {
            do {
                try SMAppService.mainApp.register()
            } catch {
                // Non-fatal — user can enable later
            }
        }
        refreshLaunchAtLoginMenu()
    }

    func openPermissions(force: Bool = true) {
        permissionsWindow.onAllGranted = { [weak self] in
            self?.refreshPermissionsMenu()
            self?.setHUD(.done)
        }
        permissionsWindow.show(force: force)
        refreshPermissionsMenu()
    }

    func refreshPermissionsMenu() {
        let s = PermissionsSetupWindowController.snapshot()
        menuBar.updatePermissionsMenu(snapshot: s)
        PopoverModel.shared.micOK = s.mic
        PopoverModel.shared.axOK = s.accessibility
        PopoverModel.shared.imOK = s.inputMonitoring
        PopoverModel.shared.missingPerms = s.missingCount
    }

}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    let hotkeys = HotKeyMonitor()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let item = AppState.shared.menuBar.install(on: self)
        statusItem = item
        AppState.shared.statusItem = item
        AppState.shared.menuCancel = AppState.shared.menuBar.menuCancel
        AppState.shared.menuAutoCorrect = AppState.shared.menuBar.menuAutoCorrect
        AppState.shared.menuLaunchLogin = AppState.shared.menuBar.menuLaunchLogin
        AppState.shared.refreshLaunchAtLoginMenu()
        AppState.shared.refreshPermissionsMenu()

        hotkeys.onSTTToggle = {
            Task { @MainActor in AppState.shared.toggleSTT() }
        }
        hotkeys.onSTTHoldStart = {
            Task { @MainActor in AppState.shared.holdSTTStart() }
        }
        hotkeys.onSTTHoldEnd = {
            Task { @MainActor in AppState.shared.holdSTTEnd() }
        }
        hotkeys.onCorrect = {
            Task { @MainActor in AppState.shared.runCorrect() }
        }
        hotkeys.onCancel = {
            Task { @MainActor in AppState.shared.cancelAll() }
        }
        hotkeys.start()

        Task { @MainActor in
            await AppState.shared.ensureCore()
            AppState.shared.startTokenRefresh()
            AppState.shared.startStatusPolling()
            AppState.shared.enableLaunchAtLoginIfNeeded()
            AppState.shared.refreshPermissionsMenu()
            // First launch OR missing permissions → guided setup (not buried in docs)
            let perms = PermissionsSetupWindowController.snapshot()
            let first = !UserDefaults.standard.bool(forKey: "v2.openedOnce")
            if first || !perms.allOK {
                AppState.shared.openPermissions(force: true)
                if first {
                    // Config after perms or alongside
                    AppState.shared.openDashboard()
                    UserDefaults.standard.set(true, forKey: "v2.openedOnce")
                }
            }
            // Keep menu status fresh while app lives
            Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                Task { @MainActor in AppState.shared.refreshPermissionsMenu() }
            }
        }
    }

    @objc func openDash() {
        Task { @MainActor in AppState.shared.openDashboard() }
    }
    @objc func openPerms() {
        Task { @MainActor in AppState.shared.openPermissions(force: true) }
    }
    @objc func loginGPT() {
        Task { @MainActor in AppState.shared.openChatGPTLogin() }
    }

    /// Handle chatgpt-audio-local://login from Finder / deep links
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            Task { @MainActor in AppState.shared.handleDeepLink(url) }
        }
    }
    @objc func toggleAutoCorrect() {
        Task { @MainActor in AppState.shared.toggleAutoCorrect() }
    }
    @objc func toggleLaunchLogin() {
        Task { @MainActor in AppState.shared.toggleLaunchAtLogin() }
    }
    @objc func cancelWork() {
        Task { @MainActor in AppState.shared.cancelAll() }
    }
    @objc func perms() {
        Task { @MainActor in AppState.shared.openPermissions(force: true) }
    }
    @objc func quit() {
        Task { @MainActor in AppState.shared.cancelAll() }
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
