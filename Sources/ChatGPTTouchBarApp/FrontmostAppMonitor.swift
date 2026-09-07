import AppKit
import ChatGPTTouchBarCore

final class FrontmostAppMonitor {
    private static let safariBundleIdentifier = "com.apple.Safari"

    private let targetTokens: Set<String>
    private let webPageMatcher: TargetWebPageMatcher
    private let onChange: (Bool) -> Void
    private let safariScriptQueue = DispatchQueue(label: "com.local.chatgpt-touchbar.safari")
    private let safariURLReader = SafariTabURLReader()

    private var lastValue: Bool?
    private var safariPollTimer: Timer?
    private var safariGeneration = 0
    private var safariReadToken: UUID?
    private var lastSafariError: String?
    private var lastSafariHost: String?

    init(
        targetTokens: Set<String>,
        targetWebHosts: Set<String>,
        onChange: @escaping (Bool) -> Void
    ) {
        self.targetTokens = targetTokens
        self.webPageMatcher = TargetWebPageMatcher(allowedHosts: targetWebHosts)
        self.onChange = onChange
    }

    func start() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeApplicationChanged(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        evaluate(NSWorkspace.shared.frontmostApplication)
    }

    deinit {
        safariPollTimer?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func activeApplicationChanged(_ notification: Notification) {
        let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        evaluate(app ?? NSWorkspace.shared.frontmostApplication)
    }

    private func evaluate(_ application: NSRunningApplication?) {
        let candidates = [
            application?.localizedName,
            application?.bundleIdentifier,
            application?.executableURL?.deletingPathExtension().lastPathComponent,
            application?.bundleURL?.deletingPathExtension().lastPathComponent
        ].compactMap { $0 }
        let isTarget = candidates.contains { targetTokens.contains($0) }

        if isTarget {
            stopSafariMonitoring()
            publish(true)
        } else if application?.bundleIdentifier == Self.safariBundleIdentifier {
            startSafariMonitoring()
        } else {
            stopSafariMonitoring()
            publish(false)
        }
    }

    private func startSafariMonitoring() {
        guard safariPollTimer == nil else { return }
        safariGeneration += 1
        publish(false)
        readSafariURL()

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.readSafariURL()
        }
        safariPollTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopSafariMonitoring() {
        guard safariPollTimer != nil else { return }
        safariGeneration += 1
        safariPollTimer?.invalidate()
        safariPollTimer = nil
    }

    private func readSafariURL() {
        guard safariReadToken == nil else { return }
        let token = UUID()
        let generation = safariGeneration
        safariReadToken = token

        safariScriptQueue.async { [weak self] in
            guard let self else { return }
            let result = self.safariURLReader.read()
            DispatchQueue.main.async {
                guard self.safariReadToken == token else { return }
                self.safariReadToken = nil
                guard
                    self.safariGeneration == generation,
                    NSWorkspace.shared.frontmostApplication?.bundleIdentifier
                        == Self.safariBundleIdentifier
                else {
                    return
                }

                switch result {
                case .success(let urlString):
                    self.lastSafariError = nil
                    let host = urlString
                        .flatMap { URLComponents(string: $0)?.host?.lowercased() }
                        ?? "(no web page)"
                    if host != self.lastSafariHost {
                        self.lastSafariHost = host
                        NSLog("ChatGPTTouchBar: Safari tab host: %@", host)
                    }
                    self.publish(self.webPageMatcher.matches(urlString))
                case .failure(let error):
                    if error.message != self.lastSafariError {
                        self.lastSafariError = error.message
                        NSLog("ChatGPTTouchBar: Safari URL unavailable: %@", error.message)
                    }
                    self.publish(false)
                }
            }
        }
    }

    private func publish(_ value: Bool) {
        guard value != lastValue else { return }
        lastValue = value
        onChange(value)
    }
}

private final class SafariTabURLReader {
    private let script: NSAppleScript?

    init() {
        script = NSAppleScript(source: """
        tell application id "com.apple.Safari"
            if (count of windows) is 0 then return ""
            return URL of current tab of front window
        end tell
        """)
    }

    func read() -> Result<String?, SafariScriptError> {
        guard let script else {
            return .failure(SafariScriptError(message: "could not create AppleScript"))
        }

        var errorInfo: NSDictionary?
        let value = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let message = errorInfo[NSAppleScript.errorMessage] as? String
                ?? "AppleScript error"
            return .failure(SafariScriptError(message: message))
        }
        return .success(value.stringValue)
    }
}

private struct SafariScriptError: Error {
    let message: String
}
