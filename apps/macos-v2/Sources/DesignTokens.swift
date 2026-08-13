// Design tokens v3 — system materials + sparse indigo accent. Mirror design/tokens.md
import AppKit
import SwiftUI

enum DesignTokens {
    /// Sparse brand accent (primary buttons / active).
    static let accent = NSColor(hex: 0x6c7cff)
    static let accentSwiftUI = Color(nsColor: accent)

    static let radiusControl: CGFloat = 8
    static let radiusCard: CGFloat = 12
    static let menuBarIconSize: CGFloat = 18
    static let hudWidth: CGFloat = 220
    static let hudHeight: CGFloat = 42
    static let popoverWidth: CGFloat = 300

    // Legacy aliases used by older windows (map to semantic / accent)
    static var voice: NSColor { accent }
    static var tape: NSColor { .systemOrange }
    static var ready: NSColor { .systemGreen }
    static var panel: NSColor { .controlBackgroundColor }
    static var panelLift: NSColor { .windowBackgroundColor }
    static var mute: NSColor { .secondaryLabelColor }
    static var textPrimary: NSColor { .labelColor }
    static var line: NSColor { .separatorColor }
    static var ink: NSColor { .windowBackgroundColor }

    enum Symbol {
        static let menuIdle = "waveform"
        static let menuListening = "mic.fill"
        static let menuWorking = "ellipsis.circle"
        static let menuError = "exclamationmark.triangle.fill"
        static let mic = "mic.fill"
        static let accessibility = "accessibility"
        static let keyboard = "keyboard"
        static let hudListening = "mic.fill"
        static let hudTranscribing = "waveform"
        static let hudCorrecting = "wand.and.stars"
        static let hudDone = "checkmark.circle.fill"
        static let hudStopped = "stop.circle"
        static let hudError = "exclamationmark.circle.fill"
        static let settings = "gearshape"
        static let login = "person.crop.circle"
        static let stop = "stop.fill"
    }

    static func symbol(_ name: String, pointSize: CGFloat = 14, weight: NSFont.Weight = .medium) -> NSImage? {
        let cfg = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(cfg)
    }

    static func menuBarIcon(named symbolName: String) -> NSImage? {
        guard let img = symbol(symbolName, pointSize: menuBarIconSize - 2, weight: .semibold) else {
            return nil
        }
        img.isTemplate = true
        return img
    }

    static func statusBarImage(symbolName: String, showSetupBadge: Bool) -> NSImage {
        let size = NSSize(width: menuBarIconSize, height: menuBarIconSize)
        let base = menuBarIcon(named: symbolName) ?? NSImage(size: size)
        guard showSetupBadge else { return base }

        let composite = NSImage(size: size)
        composite.lockFocus()
        base.draw(in: NSRect(x: 0, y: 0, width: size.width, height: size.height))
        let dotR: CGFloat = 3.5
        let dotRect = NSRect(x: size.width - dotR * 2 - 1, y: 1, width: dotR * 2, height: dotR * 2)
        NSColor.systemOrange.setFill()
        NSBezierPath(ovalIn: dotRect).fill()
        composite.unlockFocus()
        composite.isTemplate = false
        return composite
    }
}

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        let r = CGFloat((hex >> 16) & 0xff) / 255
        let g = CGFloat((hex >> 8) & 0xff) / 255
        let b = CGFloat(hex & 0xff) / 255
        self.init(srgbRed: r, green: g, blue: b, alpha: alpha)
    }
}
