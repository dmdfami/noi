// Menu bar status item — icon + popover (v3)
import AppKit

@MainActor
final class MenuBarController: NSObject {
    weak var statusItem: NSStatusItem?
    /// Kept for AppState.cancel enablement binding
    weak var menuCancel: NSMenuItem?
    weak var menuAutoCorrect: NSMenuItem?
    weak var menuLaunchLogin: NSMenuItem?

    let popoverController = StatusPopoverController()

    private var showSetupBadge = false
    private var idleSymbol = DesignTokens.Symbol.menuIdle
    /// Hidden menu items so AppState can still toggle checkbox state without a visible NSMenu.
    private let shadowMenu = NSMenu()

    func install(on delegate: AppDelegate) -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = DesignTokens.menuBarIcon(named: idleSymbol)
        item.button?.imagePosition = .imageOnly
        item.button?.title = ""
        item.button?.toolTip = AppStrings.menuTooltipReady

        // Shadow items for AppState state sync (not shown)
        let cancel = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        cancel.isEnabled = false
        shadowMenu.addItem(cancel)
        menuCancel = cancel

        let auto = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        auto.state = .off
        shadowMenu.addItem(auto)
        menuAutoCorrect = auto

        let launch = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        launch.state = .off
        shadowMenu.addItem(launch)
        menuLaunchLogin = launch

        statusItem = item
        applyBarIcon(symbol: idleSymbol)
        popoverController.attach(to: item)
        _ = delegate // retain wiring symmetry; actions go through AppState from popover
        return item
    }

    func applyBarIcon(symbol: String, badge: Bool? = nil) {
        idleSymbol = symbol
        if let badge { showSetupBadge = badge }
        statusItem?.button?.title = ""
        statusItem?.button?.image = DesignTokens.statusBarImage(
            symbolName: symbol,
            showSetupBadge: showSetupBadge
        )
        statusItem?.button?.imagePosition = .imageOnly
    }

    func updatePermissionsMenu(snapshot: PermissionsSetupWindowController.Snapshot) {
        showSetupBadge = !snapshot.allOK
        if snapshot.allOK {
            statusItem?.button?.toolTip = AppStrings.menuTooltipReady
        } else {
            statusItem?.button?.toolTip = AppStrings.menuTooltipNeedsSetup(snapshot.missingCount)
        }
        if !AppState.shared.isActiveWork {
            applyBarIcon(symbol: idleSymbol)
        }
    }

    func updateStatusHeader(sttReady: Bool, corrReady: Bool, allPermsOK: Bool) {
        // PopoverModel is updated from AppState.refreshMenuStatus
        _ = (sttReady, corrReady, allPermsOK)
    }

    func updateAccount(name: String?, email: String?, sttReady: Bool) {
        _ = (name, email, sttReady)
    }

    func hudSymbol(for state: HUDState) -> String {
        switch state {
        case .idle: return DesignTokens.Symbol.menuIdle
        case .listening: return DesignTokens.Symbol.menuListening
        case .transcribing, .correcting: return DesignTokens.Symbol.menuWorking
        case .done: return DesignTokens.Symbol.hudDone
        case .stopped: return DesignTokens.Symbol.hudStopped
        case .error: return DesignTokens.Symbol.menuError
        }
    }
}
