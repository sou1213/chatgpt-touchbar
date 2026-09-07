import AppKit
import ChatGPTTouchBarCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let touchBarController = TouchBarController()
    private let refreshInterval: TimeInterval = 30
    private var monitor: FrontmostAppMonitor?
    private var refreshTimer: Timer?
    private var isTargetFrontmost = false
    private var isRefreshing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.set(false, forKey: "DFRSystemModalShowsCloseBox")
        let monitor = FrontmostAppMonitor(
            targetTokens: targetApplicationTokens(),
            targetWebHosts: targetWebHosts()
        ) { [weak self] visible in
            self?.handleVisibilityChange(visible)
        }
        self.monitor = monitor
        monitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopRefreshing()
        touchBarController.hide()
    }

    private func handleVisibilityChange(_ visible: Bool) {
        guard visible != isTargetFrontmost else { return }
        isTargetFrontmost = visible
        if visible {
            touchBarController.showLoading()
            startRefreshing()
        } else {
            stopRefreshing()
            touchBarController.hide()
        }
    }

    private func startRefreshing() {
        stopRefreshing()
        refresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        refreshTimer?.tolerance = 3
    }

    private func stopRefreshing() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func refresh() {
        guard isTargetFrontmost, !isRefreshing else { return }
        guard let client = CodexAppServerClient() else {
            touchBarController.showUnavailable("codex not found")
            return
        }
        isRefreshing = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            do {
                let snapshot = try client.fetchUsage()
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.isRefreshing = false
                    guard self.isTargetFrontmost else { return }
                    self.touchBarController.update(snapshot)
                }
            } catch {
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.isRefreshing = false
                    guard self.isTargetFrontmost else { return }
                    self.touchBarController.showUnavailable("usage unavailable")
                    NSLog("ChatGPTTouchBar: refresh failed: %@", error.localizedDescription)
                }
            }
        }
    }

    private func targetApplicationTokens() -> Set<String> {
        let raw = ProcessInfo.processInfo.environment["CHATGPT_TOUCHBAR_TARGET_APPS"]
            ?? "ChatGPT,Codex,com.openai.codex"
        return Set(
            raw.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }

    private func targetWebHosts() -> Set<String> {
        let raw = ProcessInfo.processInfo.environment["CHATGPT_TOUCHBAR_TARGET_WEB_HOSTS"]
            ?? "chatgpt.com,chat.openai.com"
        return Set(
            raw.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }
}
