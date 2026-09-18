import Foundation

public final class CodexAppServerClient {
    private let executableURL: URL
    private let timeout: TimeInterval

    public init?(timeout: TimeInterval = 12) {
        guard let executableURL = Self.findCodexExecutable() else { return nil }
        self.executableURL = executableURL
        self.timeout = max(5, timeout)
    }

    init(executableURL: URL, timeout: TimeInterval = 12) {
        self.executableURL = executableURL
        self.timeout = max(5, timeout)
    }

    public func fetchUsage() throws -> UsageSnapshot {
        let process = Process()
        let input = Pipe()
        let output = Pipe()
        process.executableURL = executableURL
        process.arguments = ["app-server", "--listen", "stdio://"]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        let stateQueue = DispatchQueue(label: "chatgpt.touchbar.app-server")
        let completed = DispatchSemaphore(value: 0)
        var pending = Data()
        var responseResult: JSONObject?
        var responseError: String?
        var didComplete = false

        output.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            stateQueue.sync {
                pending.append(data)
                while let newline = pending.firstIndex(of: 10) {
                    let line = pending[..<newline]
                    pending.removeSubrange(...newline)
                    guard let message = try? JSONSerialization.jsonObject(with: line) as? JSONObject,
                          Self.integer(message["id"]) == 1 else {
                        continue
                    }
                    responseResult = message["result"] as? JSONObject
                    if let error = message["error"] as? JSONObject {
                        responseError = error["message"] as? String
                    }
                    if !didComplete {
                        didComplete = true
                        completed.signal()
                    }
                }
            }
        }

        try process.run()
        do {
            for message in Self.requestMessages() {
                var data = try JSONSerialization.data(withJSONObject: message)
                data.append(10)
                try input.fileHandleForWriting.write(contentsOf: data)
            }
        } catch {
            output.fileHandleForReading.readabilityHandler = nil
            if process.isRunning { process.terminate() }
            throw error
        }

        let waitResult = completed.wait(timeout: .now() + timeout)
        output.fileHandleForReading.readabilityHandler = nil
        try? input.fileHandleForWriting.close()
        if process.isRunning { process.terminate() }

        guard waitResult == .success else {
            throw CodexUsageError.timedOut
        }
        let response = stateQueue.sync { (responseResult, responseError) }
        if let message = response.1 {
            throw CodexUsageError.server(message)
        }
        guard let result = response.0 else {
            throw CodexUsageError.malformedResponse("missing request result")
        }
        return try RateLimitParser.parse(result: result)
    }

    static func requestMessages() -> [JSONObject] {
        [
            [
                "method": "initialize",
                "id": 0,
                "params": [
                    "clientInfo": [
                        "name": "chatgpt_touchbar",
                        "title": "ChatGPT Touch Bar",
                        "version": Bundle.main.object(
                            forInfoDictionaryKey: "CFBundleShortVersionString"
                        ) as? String ?? "development"
                    ]
                ]
            ],
            ["method": "initialized", "params": JSONObject()],
            ["method": "account/rateLimits/read", "id": 1, "params": JSONObject()]
        ]
    }

    private static func findCodexExecutable() -> URL? {
        var candidates: [String] = []
        let environment = ProcessInfo.processInfo.environment
        if let configured = environment["CHATGPT_TOUCHBAR_CODEX_BINARY"], !configured.isEmpty {
            candidates.append(NSString(string: configured).expandingTildeInPath)
        }

        let userApplications = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications")
            .path
        candidates.append(contentsOf: [
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
            "\(userApplications)/ChatGPT.app/Contents/Resources/codex",
            "\(userApplications)/Codex.app/Contents/Resources/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex"
        ])

        if let path = environment["PATH"] {
            candidates.append(contentsOf: path.split(separator: ":").map { "\($0)/codex" })
        }

        return candidates.first(where: FileManager.default.isExecutableFile(atPath:))
            .map(URL.init(fileURLWithPath:))
    }

    private static func integer(_ value: Any?) -> Int? {
        switch value {
        case let value as NSNumber:
            return value.intValue
        case let value as String:
            return Int(value)
        default:
            return nil
        }
    }
}
