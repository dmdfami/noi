import AppKit
import Foundation
import WebKit

/// In-app ChatGPT session: cookies in shared WKWebsiteDataStore → access token.
/// Auto-refresh via /api/auth/session without re-pasting tokens.
@MainActor
enum ChatGPTSession {
    static let dataStore = WKWebsiteDataStore.default()
    private static var refreshTimer: Timer?
    private static var onToken: ((String, [String: Any]?) -> Void)?

    static func startAutoRefresh(every seconds: TimeInterval = 12 * 60, onUpdate: @escaping (String, [String: Any]?) -> Void) {
        onToken = onUpdate
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: true) { _ in
            Task { @MainActor in
                await refreshIfPossible()
            }
        }
        // Warm once shortly after launch
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await refreshIfPossible()
        }
    }

    static func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    /// Fetch session using cookies already stored in the shared data store.
    static func fetchAccessToken() async -> (token: String, session: [String: Any]?)? {
        let cookies = await allChatGPTCookies()
        guard !cookies.isEmpty else { return nil }

        var req = URLRequest(url: URL(string: "https://chatgpt.com/api/auth/session")!)
        req.httpMethod = "GET"
        req.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        req.setValue("https://chatgpt.com/", forHTTPHeaderField: "Referer")
        let cookieHeader = cookies
            .map { "\($0.name)=\($0.value)" }
            .joined(separator: "; ")
        req.setValue(cookieHeader, forHTTPHeaderField: "Cookie")

        do {
            let (data, res) = try await URLSession.shared.data(for: req)
            guard let http = res as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            // shapes: { accessToken } or { user, accessToken } or nested
            let token =
                (obj["accessToken"] as? String)
                ?? (obj["access_token"] as? String)
                ?? ((obj["token"] as? [String: Any])?["accessToken"] as? String)
            guard let token, !token.isEmpty else { return nil }
            return (token, obj)
        } catch {
            return nil
        }
    }

    static func refreshIfPossible() async {
        guard let result = await fetchAccessToken() else { return }
        onToken?(result.token, result.session)
    }

    /// Clear ChatGPT/OpenAI cookies so the login WebView can switch accounts.
    static func clearChatGPTCookies() async {
        let cookies = await allChatGPTCookies()
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            let store = dataStore.httpCookieStore
            guard !cookies.isEmpty else {
                cont.resume()
                return
            }
            let group = DispatchGroup()
            for c in cookies {
                group.enter()
                store.delete(c) { group.leave() }
            }
            group.notify(queue: .main) { cont.resume() }
        }
    }

    private static func allChatGPTCookies() async -> [HTTPCookie] {
        await withCheckedContinuation { cont in
            dataStore.httpCookieStore.getAllCookies { cookies in
                let filtered = cookies.filter {
                    let d = $0.domain.lowercased()
                    return d.contains("chatgpt.com") || d.contains("openai.com")
                }
                cont.resume(returning: filtered)
            }
        }
    }
}

// MARK: - Login window (WKWebView)

@MainActor
final class ChatGPTLoginWindowController: NSObject, WKNavigationDelegate {
    private var window: NSWindow?
    private var webView: WKWebView?
    private var pollTask: Task<Void, Never>?
    var onSuccess: ((String, [String: Any]?) -> Void)?
    var onCancel: (() -> Void)?

    /// - Parameter forceRelogin: clear cookies and reload ChatGPT login (required for switch account).
    func show(forceRelogin: Bool = true) {
        if window == nil {
            buildWindow()
        }
        loginHelpLabel?.isHidden = true
        loginHelpLabel?.stringValue = ""
        progressControl?.startAnimation(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        Task { @MainActor in
            if forceRelogin {
                await ChatGPTSession.clearChatGPTCookies()
            }
            if let url = URL(string: "https://chatgpt.com/auth/login") {
                webView?.load(URLRequest(url: url))
            }
            startPolling()
        }
    }

    private func buildWindow() {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = ChatGPTSession.dataStore
        let wv = WKWebView(frame: NSRect(x: 0, y: 0, width: 920, height: 640), configuration: cfg)
        wv.navigationDelegate = self
        wv.customUserAgent =
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        wv.translatesAutoresizingMaskIntoConstraints = false

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 700),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = AppStrings.loginWindowTitle
        win.center()
        win.isReleasedWhenClosed = false
        win.titleVisibility = .visible

        let toolbar = NSToolbar(identifier: "LoginToolbar")
        toolbar.displayMode = .iconAndLabel
        win.toolbar = toolbar

        let subtitle = NSTextField(labelWithString: AppStrings.loginSubtitle)
        subtitle.font = .systemFont(ofSize: 11)
        subtitle.textColor = .secondaryLabelColor
        subtitle.translatesAutoresizingMaskIntoConstraints = false

        let progress = NSProgressIndicator()
        progress.style = .bar
        progress.isIndeterminate = true
        progress.controlSize = .small
        progress.startAnimation(nil)
        progress.translatesAutoresizingMaskIntoConstraints = false
        progressControl = progress

        let helpLabel = NSTextField(labelWithString: "")
        helpLabel.font = .systemFont(ofSize: 11)
        helpLabel.textColor = .systemOrange
        helpLabel.isHidden = true
        helpLabel.translatesAutoresizingMaskIntoConstraints = false
        loginHelpLabel = helpLabel

        let cancelBtn = NSButton(title: AppStrings.loginCancel, target: self, action: #selector(cancelLogin))
        cancelBtn.bezelStyle = .rounded
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false

        let bar = NSView()
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(subtitle)
        bar.addSubview(helpLabel)
        bar.addSubview(progress)
        bar.addSubview(cancelBtn)

        let box = NSView(frame: .zero)
        box.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(bar)
        box.addSubview(wv)
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: box.topAnchor),
            bar.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant: 44),
            subtitle.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 14),
            subtitle.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            helpLabel.leadingAnchor.constraint(equalTo: subtitle.trailingAnchor, constant: 10),
            helpLabel.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            progress.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 14),
            progress.trailingAnchor.constraint(equalTo: cancelBtn.leadingAnchor, constant: -12),
            progress.bottomAnchor.constraint(equalTo: bar.bottomAnchor, constant: -2),
            progress.heightAnchor.constraint(equalToConstant: 3),
            cancelBtn.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -14),
            cancelBtn.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            wv.topAnchor.constraint(equalTo: bar.bottomAnchor),
            wv.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            wv.bottomAnchor.constraint(equalTo: box.bottomAnchor),
        ])
        win.contentView = box
        win.delegate = self

        self.window = win
        self.webView = wv
    }

    private var progressControl: NSProgressIndicator?
    private var loginHelpLabel: NSTextField?

    @objc private func cancelLogin() {
        close()
        onCancel?()
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            for i in 0..<90 {
                if Task.isCancelled { return }
                if let result = await ChatGPTSession.fetchAccessToken() {
                    await MainActor.run {
                        self?.progressControl?.stopAnimation(nil)
                        self?.onSuccess?(result.token, result.session)
                        self?.close()
                    }
                    return
                }
                if i == 89 {
                    await MainActor.run {
                        self?.loginHelpLabel?.stringValue = AppStrings.loginTimeout
                        self?.loginHelpLabel?.isHidden = false
                        self?.progressControl?.stopAnimation(nil)
                    }
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    func close() {
        pollTask?.cancel()
        pollTask = nil
        window?.orderOut(nil)
        window = nil
        webView = nil
    }
}

extension ChatGPTLoginWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        pollTask?.cancel()
        pollTask = nil
        webView = nil
        window = nil
        onCancel?()
    }
}

// MARK: - Permissions setup (first-run + menu)

/// User-facing checklist: Mic · Accessibility · Input Monitoring.
/// macOS cannot grant these silently — we detect, open the right Settings pane, and re-check.
@MainActor
final class PermissionsSetupWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var progressLabel: NSTextField?
    private var summaryLabel: NSTextField?
    private var successPanel: NSView?
    private var stepsStack: NSStackView?
    private var micStatus: NSTextField?
    private var axStatus: NSTextField?
    private var imStatus: NSTextField?
    private var pollTimer: Timer?
    var onAllGranted: (() -> Void)?

    struct Snapshot {
        var mic: Bool
        var accessibility: Bool
        var inputMonitoring: Bool
        var allOK: Bool { mic && accessibility && inputMonitoring }
        var missingCount: Int {
            [mic, accessibility, inputMonitoring].filter { !$0 }.count
        }
    }

    static func snapshot() -> Snapshot {
        let mic: Bool
        switch MicRecorder.authStatus() {
        case .authorized: mic = true
        default: mic = false
        }
        return Snapshot(
            mic: mic,
            accessibility: SelectionService.isAXTrusted(prompt: false),
            inputMonitoring: SelectionService.hasInputMonitoring()
        )
    }

    func show(force: Bool = false) {
        let snap = Self.snapshot()
        if !force && snap.allOK {
            onAllGranted?()
            return
        }
        if window == nil { build() }
        refreshUI()
        startPolling()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        stopPolling()
        window?.orderOut(nil)
        window = nil
    }

    private func build() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 540),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = AppStrings.permsTitle
        win.isReleasedWhenClosed = false
        win.delegate = self
        win.center()

        let root = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 540))
        root.wantsLayer = true

        let hero = NSTextField(labelWithString: AppStrings.permsHero)
        hero.font = .systemFont(ofSize: 20, weight: .bold)
        hero.translatesAutoresizingMaskIntoConstraints = false

        let progress = NSTextField(labelWithString: AppStrings.permsProgress(done: 0, total: 3))
        progress.font = .systemFont(ofSize: 12, weight: .medium)
        progress.textColor = DesignTokens.accent
        progress.translatesAutoresizingMaskIntoConstraints = false
        progressLabel = progress

        let blurb = NSTextField(wrappingLabelWithString: AppStrings.permsBlurb)
        blurb.font = .systemFont(ofSize: 12)
        blurb.textColor = .secondaryLabelColor
        blurb.translatesAutoresizingMaskIntoConstraints = false

        let summary = NSTextField(wrappingLabelWithString: "…")
        summary.font = .systemFont(ofSize: 12, weight: .medium)
        summary.translatesAutoresizingMaskIntoConstraints = false
        summaryLabel = summary

        let success = makeSuccessPanel()
        success.isHidden = true
        success.translatesAutoresizingMaskIntoConstraints = false
        successPanel = success

        let micCard = makeStepCard(
            symbol: DesignTokens.Symbol.mic,
            title: AppStrings.micTitle,
            why: AppStrings.micWhy,
            action: #selector(openMic)
        )
        micStatus = micCard.statusLabel

        let axCard = makeStepCard(
            symbol: DesignTokens.Symbol.accessibility,
            title: AppStrings.axTitle,
            why: AppStrings.axWhy,
            action: #selector(openAX)
        )
        axStatus = axCard.statusLabel

        let imCard = makeStepCard(
            symbol: DesignTokens.Symbol.keyboard,
            title: AppStrings.imTitle,
            why: AppStrings.imWhy,
            action: #selector(openIM)
        )
        imStatus = imCard.statusLabel

        let steps = NSStackView(views: [micCard.view, axCard.view, imCard.view])
        steps.orientation = .vertical
        steps.spacing = 10
        steps.translatesAutoresizingMaskIntoConstraints = false
        stepsStack = steps

        let recheck = NSButton(title: AppStrings.permsRecheck, target: self, action: #selector(recheck))
        recheck.bezelStyle = .rounded
        recheck.translatesAutoresizingMaskIntoConstraints = false

        let done = NSButton(title: AppStrings.permsDone, target: self, action: #selector(doneTapped))
        done.bezelStyle = .rounded
        done.keyEquivalent = "\r"
        done.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(hero)
        root.addSubview(progress)
        root.addSubview(blurb)
        root.addSubview(summary)
        root.addSubview(success)
        root.addSubview(steps)
        root.addSubview(recheck)
        root.addSubview(done)

        NSLayoutConstraint.activate([
            hero.topAnchor.constraint(equalTo: root.topAnchor, constant: 24),
            hero.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            progress.topAnchor.constraint(equalTo: hero.bottomAnchor, constant: 4),
            progress.leadingAnchor.constraint(equalTo: hero.leadingAnchor),
            blurb.topAnchor.constraint(equalTo: progress.bottomAnchor, constant: 10),
            blurb.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            blurb.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            summary.topAnchor.constraint(equalTo: blurb.bottomAnchor, constant: 8),
            summary.leadingAnchor.constraint(equalTo: blurb.leadingAnchor),
            summary.trailingAnchor.constraint(equalTo: blurb.trailingAnchor),
            success.topAnchor.constraint(equalTo: summary.bottomAnchor, constant: 12),
            success.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            success.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            steps.topAnchor.constraint(equalTo: summary.bottomAnchor, constant: 16),
            steps.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            steps.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            micCard.view.widthAnchor.constraint(equalTo: steps.widthAnchor),
            axCard.view.widthAnchor.constraint(equalTo: steps.widthAnchor),
            imCard.view.widthAnchor.constraint(equalTo: steps.widthAnchor),
            recheck.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            recheck.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -20),
            done.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            done.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -20),
        ])

        win.contentView = root
        window = win
    }

    private struct StepCard {
        let view: NSView
        let statusLabel: NSTextField
    }

    private func makeStepCard(symbol: String, title: String, why: String, action: Selector) -> StepCard {
        let card = NSView()
        card.wantsLayer = true
        card.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        card.layer?.cornerRadius = DesignTokens.radiusCard
        card.translatesAutoresizingMaskIntoConstraints = false

        let icon = NSImageView()
        icon.image = DesignTokens.symbol(symbol, pointSize: 20, weight: .medium)
        icon.contentTintColor = DesignTokens.accent
        icon.translatesAutoresizingMaskIntoConstraints = false

        let name = NSTextField(labelWithString: title)
        name.font = .systemFont(ofSize: 14, weight: .semibold)
        name.translatesAutoresizingMaskIntoConstraints = false

        let sub = NSTextField(labelWithString: why)
        sub.font = .systemFont(ofSize: 11)
        sub.textColor = .secondaryLabelColor
        sub.translatesAutoresizingMaskIntoConstraints = false

        let status = NSTextField(labelWithString: AppStrings.permMissing)
        status.font = .systemFont(ofSize: 11, weight: .medium)
        status.translatesAutoresizingMaskIntoConstraints = false

        let btn = NSButton(title: AppStrings.openMacSettings, target: self, action: action)
        btn.bezelStyle = .rounded
        btn.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(icon)
        card.addSubview(name)
        card.addSubview(sub)
        card.addSubview(status)
        card.addSubview(btn)

        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 88),
            icon.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            icon.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 24),
            icon.heightAnchor.constraint(equalToConstant: 24),
            name.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),
            name.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            sub.leadingAnchor.constraint(equalTo: name.leadingAnchor),
            sub.topAnchor.constraint(equalTo: name.bottomAnchor, constant: 2),
            status.leadingAnchor.constraint(equalTo: name.leadingAnchor),
            status.topAnchor.constraint(equalTo: sub.bottomAnchor, constant: 4),
            status.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -14),
            btn.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            btn.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            name.trailingAnchor.constraint(lessThanOrEqualTo: btn.leadingAnchor, constant: -8),
        ])

        return StepCard(view: card, statusLabel: status)
    }

    private func makeSuccessPanel() -> NSView {
        let panel = NSView()
        panel.wantsLayer = true
        panel.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.12).cgColor
        panel.layer?.cornerRadius = DesignTokens.radiusControl

        let label = NSTextField(labelWithString: AppStrings.permsSuccess)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .systemGreen
        label.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(label)
        NSLayoutConstraint.activate([
            panel.heightAnchor.constraint(equalToConstant: 44),
            label.centerXAnchor.constraint(equalTo: panel.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: panel.centerYAnchor),
        ])
        return panel
    }

    private func startPolling() {
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshUI() }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func refreshUI() {
        let s = Self.snapshot()
        let granted = [s.mic, s.accessibility, s.inputMonitoring].filter { $0 }.count
        progressLabel?.stringValue = AppStrings.permsProgress(done: granted, total: 3)

        func paint(_ lab: NSTextField?, ok: Bool) {
            lab?.stringValue = ok ? AppStrings.permGranted : AppStrings.permMissing
            lab?.textColor = ok ? .systemGreen : .systemOrange
        }
        paint(micStatus, ok: s.mic)
        paint(axStatus, ok: s.accessibility)
        paint(imStatus, ok: s.inputMonitoring)

        if s.allOK {
            summaryLabel?.stringValue = AppStrings.permsSuccess
            summaryLabel?.textColor = .systemGreen
            successPanel?.isHidden = false
            stepsStack?.isHidden = true
        } else {
            summaryLabel?.stringValue = AppStrings.permsSummary(missing: s.missingCount)
            summaryLabel?.textColor = .systemOrange
            successPanel?.isHidden = true
            stepsStack?.isHidden = false
        }
    }

    @objc private func openMic() {
        Task { @MainActor in
            _ = await MicRecorder().requestAccess()
            // Also open Privacy Mic pane
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
            refreshUI()
        }
    }

    @objc private func openAX() {
        _ = SelectionService.isAXTrusted(prompt: true)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        refreshUI()
    }

    @objc private func openIM() {
        // Creating a tap may register the app in the list
        _ = SelectionService.hasInputMonitoring()
        SelectionService.requestInputMonitoring()
        refreshUI()
    }

    @objc private func recheck() {
        refreshUI()
        if Self.snapshot().allOK {
            onAllGranted?()
        }
    }

    @objc private func doneTapped() {
        if Self.snapshot().allOK {
            onAllGranted?()
        }
        close()
    }

    func windowWillClose(_ notification: Notification) {
        stopPolling()
        window = nil
    }
}

// MARK: - In-app config dashboard (local-core UI)

/// Loads the local-core web dashboard inside the app (not Safari).
/// Intercepts `chatgpt-audio-local://…` deep links (login, etc.).
@MainActor
final class ConfigDashboardWindowController: NSObject, NSWindowDelegate, WKNavigationDelegate {
    private var window: NSWindow?
    private var webView: WKWebView?
    private var lastURL: URL?
    /// Called for chatgpt-audio-local://login and similar
    var onDeepLink: ((URL) -> Void)?

    /// Show dashboard at `urlString` (e.g. http://127.0.0.1:8797/).
    func show(urlString: String) {
        let url = URL(string: urlString) ?? URL(string: "http://127.0.0.1:8797/")!
        lastURL = url
        if let window {
            webView?.load(URLRequest(url: url))
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let cfg = WKWebViewConfiguration()
        let wv = WKWebView(frame: NSRect(x: 0, y: 0, width: 780, height: 720), configuration: cfg)
        wv.setValue(false, forKey: "drawsBackground")
        wv.navigationDelegate = self
        webView = wv

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = AppStrings.configWindowTitle
        win.contentView = wv
        win.delegate = self
        win.isReleasedWhenClosed = false
        win.center()
        win.setFrameAutosaveName("ConfigDashboard")
        window = win

        wv.load(URLRequest(url: url))
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func reload() {
        if let url = lastURL {
            webView?.load(URLRequest(url: url))
        } else {
            webView?.reload()
        }
    }

    func close() {
        window?.orderOut(nil)
        window = nil
        webView = nil
    }

    func windowWillClose(_ notification: Notification) {
        webView = nil
        window = nil
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        if url.scheme?.lowercased() == "chatgpt-audio-local" {
            onDeepLink?(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
}
