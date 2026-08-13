// Floating HUD v3 — system material capsule
import AppKit
import QuartzCore

@MainActor
final class FloatingHUD {
    static let shared = FloatingHUD()
    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: DesignTokens.hudWidth, height: DesignTokens.hudHeight),
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    private let iconView = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private var hideWork: DispatchWorkItem?

    private init() {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.isFloatingPanel = true

        let blur = NSVisualEffectView(frame: panel.contentView!.bounds)
        blur.autoresizingMask = [.width, .height]
        blur.material = .popover
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = 21
        blur.layer?.masksToBounds = true

        iconView.imageScaling = .scaleProportionallyDown
        iconView.translatesAutoresizingMaskIntoConstraints = false

        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView(views: [iconView, label])
        row.orientation = .horizontal
        row.spacing = 8
        row.edgeInsets = NSEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        row.translatesAutoresizingMaskIntoConstraints = false
        blur.addSubview(row)
        NSLayoutConstraint.activate([
            row.centerXAnchor.constraint(equalTo: blur.centerXAnchor),
            row.centerYAnchor.constraint(equalTo: blur.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),
        ])
        panel.contentView = blur
    }

    func show(_ state: HUDState) {
        hideWork?.cancel()
        guard state != .idle else {
            animateOut()
            return
        }

        let (symbol, text, tint): (String, String, NSColor) = {
            switch state {
            case .listening:
                return (DesignTokens.Symbol.hudListening, AppStrings.hudListening, .systemRed)
            case .transcribing:
                return (DesignTokens.Symbol.hudTranscribing, AppStrings.hudTranscribing, .systemOrange)
            case .correcting:
                return (DesignTokens.Symbol.hudCorrecting, AppStrings.hudCorrecting, DesignTokens.accent)
            case .done:
                return (DesignTokens.Symbol.hudDone, AppStrings.hudDone, .systemGreen)
            case .stopped:
                return (DesignTokens.Symbol.hudStopped, AppStrings.hudStopped, .secondaryLabelColor)
            case .error(let m):
                return (DesignTokens.Symbol.hudError, AppStrings.hudError(m), .systemRed)
            case .idle:
                return ("", "", .labelColor)
            }
        }()

        iconView.image = DesignTokens.symbol(symbol, pointSize: 14, weight: .semibold)
        iconView.contentTintColor = tint
        label.stringValue = text
        position()
        animateIn()

        switch state {
        case .done: scheduleHide(0.9)
        case .stopped: scheduleHide(1.0)
        case .error: scheduleHide(2.2)
        default: break
        }
    }

    private func animateIn() {
        position()
        panel.alphaValue = 0
        let f = panel.frame
        panel.setFrame(
            NSRect(x: f.origin.x, y: f.origin.y - 4, width: f.width, height: f.height),
            display: false
        )
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.16
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(f, display: true)
        }
    }

    private func animateOut() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = 0
        }, completionHandler: {
            self.panel.orderOut(nil)
            self.panel.alphaValue = 1
        })
    }

    private func scheduleHide(_ sec: Double) {
        let w = DispatchWorkItem { [weak self] in self?.animateOut() }
        hideWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + sec, execute: w)
    }

    private func position() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else { return }
        let f = screen.visibleFrame
        let w = DesignTokens.hudWidth
        let h = DesignTokens.hudHeight
        panel.setFrame(
            NSRect(x: f.midX - w / 2, y: f.minY + 52, width: w, height: h),
            display: true
        )
    }
}
