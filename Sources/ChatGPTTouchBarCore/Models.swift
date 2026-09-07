import Foundation

public struct UsageWindow: Codable, Equatable, Sendable {
    public let label: String
    public let usedPercent: Double
    public let remainingPercent: Double
    public let windowDurationMinutes: Int
    public let resetsAt: Date?

    public init(
        label: String,
        usedPercent: Double,
        remainingPercent: Double,
        windowDurationMinutes: Int,
        resetsAt: Date?
    ) {
        self.label = label
        self.usedPercent = usedPercent
        self.remainingPercent = remainingPercent
        self.windowDurationMinutes = windowDurationMinutes
        self.resetsAt = resetsAt
    }
}

public struct UsageSnapshot: Codable, Equatable, Sendable {
    public let primary: UsageWindow
    public let secondary: UsageWindow?
    public let planType: String?
    public let fetchedAt: Date

    public init(primary: UsageWindow, secondary: UsageWindow?, planType: String?, fetchedAt: Date) {
        self.primary = primary
        self.secondary = secondary
        self.planType = planType
        self.fetchedAt = fetchedAt
    }
}

public enum CodexUsageError: LocalizedError, Equatable {
    case executableNotFound
    case timedOut
    case server(String)
    case malformedResponse(String)

    public var errorDescription: String? {
        switch self {
        case .executableNotFound:
            return "ChatGPT app bundled Codex executable was not found"
        case .timedOut:
            return "Codex app-server usage request timed out"
        case .server(let message):
            return "Codex app-server error: \(message)"
        case .malformedResponse(let message):
            return "Invalid Codex app-server response: \(message)"
        }
    }
}
