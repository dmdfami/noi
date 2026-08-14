// Localized strings — VI default, EN parity. Sync locale from local-core prefs.
import Foundation

enum AppLocale: String {
    case vi, en
}

@MainActor
enum AppStrings {
    private(set) static var locale: AppLocale = .vi

    static func setLocale(from prefs: [String: Any]?) {
        if let loc = prefs?["locale"] as? String, loc == "en" {
            locale = .en
        } else if let loc = prefs?["locale"] as? String, loc == "vi" {
            locale = .vi
        } else if Locale.preferredLanguages.first?.hasPrefix("en") == true {
            locale = .en
        } else {
            locale = .vi
        }
    }

    static func setLocale(_ loc: AppLocale) {
        locale = loc
    }

    static var productName: String { L("Nói", "Nói") }

    // MARK: - Status item / popover

    static var menuTooltipReady: String {
        L(
            "Nói — giữ ⌃⌥ để nói · ⌥⌥ sửa · Esc dừng",
            "Nói — hold ⌃⌥ to dictate · ⌥⌥ fix · Esc stop"
        )
    }

    static func menuTooltipNeedsSetup(_ count: Int) -> String {
        L(
            "Thiếu \(count) quyền — mở để thiết lập",
            "\(count) permission(s) missing — open to set up"
        )
    }

    static var statusReady: String { L("Đã sẵn sàng", "Ready") }
    static var statusSetupNeeded: String { L("Cần thiết lập", "Setup needed") }

    static func statusLine(sttReady: Bool, corrReady: Bool) -> String {
        if sttReady && corrReady {
            return L("STT sẵn sàng · Sửa đã cấu hình", "STT ready · Fix configured")
        }
        if sttReady {
            return L("STT sẵn sàng · Sửa tuỳ chọn", "STT ready · Fix optional")
        }
        return L("Chưa đăng nhập ChatGPT", "ChatGPT not signed in")
    }

    static var hotkeySTT: String { L("Giữ hoặc chạm đôi · nói", "Hold or double-tap · dictate") }
    static var hotkeyCorrect: String { L("Chạm đôi · sửa vùng chọn", "Double-tap · fix selection") }
    static var hotkeySTTKeys: String { "⌃⌥" }
    static var hotkeyCorrectKeys: String { "⌥⌥" }

    static func permissionsRow(mic: Bool, ax: Bool, im: Bool) -> String {
        let m = mic ? "●" : "○"
        let a = ax ? "●" : "○"
        let i = im ? "●" : "○"
        return L(
            "\(m) Mic  \(a) Trợ năng  \(i) Phím",
            "\(m) Mic  \(a) Accessibility  \(i) Keys"
        )
    }

    static var permissionsLabel: String { L("Quyền macOS", "macOS permissions") }
    static var loginChatGPT: String { L("Đăng nhập ChatGPT…", "Sign in to ChatGPT…") }
    static var switchChatGPT: String { L("Đổi tài khoản…", "Switch account…") }
    static var openSettings: String { L("Cài đặt…", "Settings…") }
    static var stopEsc: String { L("Dừng (Esc)", "Stop (Esc)") }
    static var preferences: String { L("Tuỳ chọn", "Preferences") }
    static var autoCorrectAfterSTT: String {
        L("Tự sửa sau khi dán STT", "Auto-fix after dictation")
    }
    static var launchAtLogin: String { L("Mở cùng hệ thống", "Open at login") }
    static var quit: String { L("Thoát Nói", "Quit Nói") }
    static var setupPermissions: String { L("Thiết lập quyền…", "Set up permissions…") }
    static var reviewPermissions: String { L("Xem lại quyền…", "Review permissions…") }
    static var signedInAs: String { L("Đã đăng nhập", "Signed in") }

    // MARK: - HUD

    static var hudListening: String { L("Đang nghe · Esc", "Listening · Esc") }
    static var hudTranscribing: String { L("Đang chuyển · Esc", "Transcribing · Esc") }
    static var hudCorrecting: String { L("Đang sửa · Esc", "Fixing · Esc") }
    static var hudDone: String { L("Xong", "Done") }
    static var hudStopped: String { L("Đã dừng", "Stopped") }
    static func hudError(_ msg: String) -> String {
        msg.isEmpty ? L("Lỗi", "Error") : String(msg.prefix(32))
    }

    // MARK: - Permissions

    static var permsTitle: String { L("Nói · Quyền", "Nói · Permissions") }
    static var permsHero: String { L("Ba quyền để bắt đầu", "Three permissions to start") }
    static var permsBlurb: String {
        L(
            "Cùng app Nói — bản ký Developer ID là chữ ký mới nên macOS hỏi lại Trợ năng và Theo dõi phím một lần. Micro giữ nguyên. Bật xong thì các bản sau không hỏi lại.",
            "Same Nói app — the Developer ID signature is new, so macOS asks again for Accessibility and Input Monitoring once. Microphone stays. Later updates will not ask again."
        )
    }

    static func permsProgress(done: Int, total: Int) -> String {
        L("\(done) / \(total) hoàn tất", "\(done) of \(total) done")
    }

    static var micTitle: String { L("Microphone", "Microphone") }
    static var micWhy: String { L("Để nghe bạn nói", "So we can hear you speak") }
    static var axTitle: String { L("Trợ năng", "Accessibility") }
    static var axWhy: String { L("Để dán chữ vào app đang gõ", "To paste into the app you're typing in") }
    static var imTitle: String { L("Theo dõi phím", "Input Monitoring") }
    static var imWhy: String { L("Để dán vào Terminal và CLI", "To paste into Terminal and CLI") }
    static var permGranted: String { L("Đã bật", "On") }
    static var permMissing: String { L("Chưa bật", "Off") }
    static var openMacSettings: String { L("Mở Cài đặt", "Open Settings") }
    static var permsRecheck: String { L("Kiểm tra lại", "Check again") }
    static var permsDone: String { L("Xong", "Done") }
    static var permsSuccess: String {
        L("Đã sẵn sàng — giữ ⌃⌥ để nói", "Ready — hold ⌃⌥ to speak")
    }

    static func permsSummary(missing: Int) -> String {
        missing == 0
            ? permsSuccess
            : L("Còn thiếu \(missing) quyền", "\(missing) still missing")
    }

    // MARK: - Login

    static var loginWindowTitle: String {
        L("Nói · ChatGPT", "Nói · ChatGPT")
    }
    static var loginHeader: String { L("Đăng nhập ChatGPT", "Sign in to ChatGPT") }
    static var loginSubtitle: String {
        L(
            "Phiên được lấy tự động và làm mới định kỳ.",
            "Your session is captured and refreshed automatically."
        )
    }
    static var loginCancel: String { L("Huỷ", "Cancel") }
    static var loginTimeout: String {
        L(
            "Chưa xong — thử lại hoặc kiểm tra mạng.",
            "Not finished — try again or check your network."
        )
    }

    static var configWindowTitle: String { L("Nói · Cài đặt", "Nói · Settings") }

    private static func L(_ vi: String, _ en: String) -> String {
        locale == .en ? en : vi
    }
}
