// Status item popover — primary daily UI (SwiftUI + NSPopover)
import AppKit
import SwiftUI

/// Snapshot driving the menu-bar popover. Updated from AppState.
@MainActor
final class PopoverModel: ObservableObject {
    static let shared = PopoverModel()

    @Published var aggregateReady = false
    @Published var statusDetail = ""
    @Published var sttReady = false
    @Published var accountLine: String?
    @Published var micOK = false
    @Published var axOK = false
    @Published var imOK = false
    @Published var missingPerms = 3
    @Published var autoCorrect = false
    @Published var launchAtLogin = false
    @Published var canStop = false

    func apply(
        sttReady: Bool,
        corrReady: Bool,
        allPermsOK: Bool,
        accountName: String?,
        accountEmail: String?,
        snap: PermissionsSetupWindowController.Snapshot,
        autoCorrect: Bool,
        launchAtLogin: Bool,
        canStop: Bool
    ) {
        self.sttReady = sttReady
        aggregateReady = allPermsOK && sttReady
        statusDetail = AppStrings.statusLine(sttReady: sttReady, corrReady: corrReady)
        if let accountName, let accountEmail, sttReady {
            accountLine = "\(accountName) · \(accountEmail)"
        } else {
            accountLine = nil
        }
        micOK = snap.mic
        axOK = snap.accessibility
        imOK = snap.inputMonitoring
        missingPerms = snap.missingCount
        self.autoCorrect = autoCorrect
        self.launchAtLogin = launchAtLogin
        self.canStop = canStop
    }
}

struct StatusPopoverView: View {
    @ObservedObject var model = PopoverModel.shared
    var onLogin: () -> Void
    var onPermissions: () -> Void
    var onSettings: () -> Void
    var onStop: () -> Void
    var onToggleAutoCorrect: () -> Void
    var onToggleLaunch: () -> Void
    var onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().padding(.vertical, 8)
            hotkeys
            Divider().padding(.vertical, 8)
            actions
            Divider().padding(.vertical, 8)
            prefs
            Divider().padding(.vertical, 8)
            Button(action: onQuit) {
                HStack {
                    Text(AppStrings.quit)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
        .padding(14)
        .frame(width: DesignTokens.popoverWidth)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppStrings.productName)
                    .font(.system(size: 15, weight: .semibold))
                Text(model.statusDetail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Text(model.aggregateReady ? AppStrings.statusReady : AppStrings.statusSetupNeeded)
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(model.aggregateReady
                        ? Color.green.opacity(0.15)
                        : Color.orange.opacity(0.15))
                )
                .foregroundStyle(model.aggregateReady ? Color.green : Color.orange)
        }
    }

    private var hotkeys: some View {
        VStack(spacing: 6) {
            hotkeyRow(keys: AppStrings.hotkeySTTKeys, label: AppStrings.hotkeySTT)
            hotkeyRow(keys: AppStrings.hotkeyCorrectKeys, label: AppStrings.hotkeyCorrect)
        }
    }

    private func hotkeyRow(keys: String, label: String) -> some View {
        HStack(spacing: 10) {
            Text(keys)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .frame(width: 36, alignment: .leading)
                .foregroundStyle(DesignTokens.accentSwiftUI)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
    }

    private var actions: some View {
        VStack(spacing: 6) {
            if let account = model.accountLine {
                Label(account, systemImage: "person.crop.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }

            popButton(
                title: model.sttReady ? AppStrings.switchChatGPT : AppStrings.loginChatGPT,
                systemImage: "person.crop.circle",
                action: onLogin
            )
            popButton(
                title: model.missingPerms == 0
                    ? AppStrings.reviewPermissions
                    : AppStrings.setupPermissions,
                systemImage: "checkmark.shield",
                detail: AppStrings.permissionsRow(mic: model.micOK, ax: model.axOK, im: model.imOK),
                action: onPermissions
            )
            popButton(
                title: AppStrings.openSettings,
                systemImage: "gearshape",
                action: onSettings
            )
            if model.canStop {
                popButton(
                    title: AppStrings.stopEsc,
                    systemImage: "stop.fill",
                    destructive: true,
                    action: onStop
                )
            }
        }
    }

    private var prefs: some View {
        VStack(spacing: 8) {
            Toggle(isOn: Binding(
                get: { model.autoCorrect },
                set: { _ in onToggleAutoCorrect() }
            )) {
                Text(AppStrings.autoCorrectAfterSTT)
                    .font(.system(size: 12))
            }
            .toggleStyle(.checkbox)

            Toggle(isOn: Binding(
                get: { model.launchAtLogin },
                set: { _ in onToggleLaunch() }
            )) {
                Text(AppStrings.launchAtLogin)
                    .font(.system(size: 12))
            }
            .toggleStyle(.checkbox)
        }
        .padding(.horizontal, 4)
    }

    private func popButton(
        title: String,
        systemImage: String,
        detail: String? = nil,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .frame(width: 16)
                    .foregroundStyle(destructive ? Color.red : DesignTokens.accentSwiftUI)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                    if let detail {
                        Text(detail)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor).opacity(0.6)))
        }
        .buttonStyle(.plain)
    }
}

@MainActor
final class StatusPopoverController: NSObject, NSPopoverDelegate {
    private let popover = NSPopover()
    private weak var statusItem: NSStatusItem?
    private var eventMonitor: Any?

    func attach(to item: NSStatusItem) {
        statusItem = item
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self

        let root = StatusPopoverView(
            onLogin: { AppState.shared.openChatGPTLogin(); self.close() },
            onPermissions: { AppState.shared.openPermissions(force: true); self.close() },
            onSettings: { AppState.shared.openDashboard(); self.close() },
            onStop: { AppState.shared.cancelAll(); self.close() },
            onToggleAutoCorrect: { AppState.shared.toggleAutoCorrect() },
            onToggleLaunch: { AppState.shared.toggleLaunchAtLogin() },
            onQuit: {
                AppState.shared.cancelAll()
                NSApp.terminate(nil)
            }
        )
        let host = NSHostingController(rootView: root)
        popover.contentViewController = host
        popover.contentSize = NSSize(width: DesignTokens.popoverWidth, height: 460)

        item.button?.target = self
        item.button?.action = #selector(toggle)
        item.menu = nil
    }

    @objc func toggle() {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            close()
        } else {
            PopoverModel.shared.objectWillChange.send()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            startMonitor()
        }
    }

    func close() {
        popover.performClose(nil)
        stopMonitor()
    }

    private func startMonitor() {
        stopMonitor()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }
    }

    private func stopMonitor() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        eventMonitor = nil
    }

    func popoverDidClose(_ notification: Notification) {
        stopMonitor()
    }
}
