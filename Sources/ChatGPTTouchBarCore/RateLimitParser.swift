import Foundation

typealias JSONObject = [String: Any]

enum RateLimitParser {
    static func parse(result: JSONObject, fetchedAt: Date = Date()) throws -> UsageSnapshot {
        guard let main = result["rateLimits"] as? JSONObject else {
            throw CodexUsageError.malformedResponse("missing rateLimits")
        }
        guard let primary = parseWindow(main["primary"]) else {
            throw CodexUsageError.malformedResponse("missing primary quota window")
        }

        let mainLimitID = string(main["limitId"])
        let secondary = parseWindow(main["secondary"])
            ?? additionalWindow(in: result, excluding: mainLimitID)
        let planType = string(main["planType"])

        return UsageSnapshot(
            primary: primary,
            secondary: secondary,
            planType: planType,
            fetchedAt: fetchedAt
        )
    }

    private static func parseWindow(_ value: Any?) -> UsageWindow? {
        guard let raw = value as? JSONObject,
              let used = number(raw["usedPercent"]),
              let minutes = integer(raw["windowDurationMins"]),
              minutes > 0 else {
            return nil
        }

        let clampedUsed = min(100, max(0, used))
        let resetTimestamp = number(raw["resetsAt"])
        let resetDate = resetTimestamp.flatMap { $0 > 0 ? Date(timeIntervalSince1970: $0) : nil }

        return UsageWindow(
            label: label(for: minutes),
            usedPercent: clampedUsed,
            remainingPercent: 100 - clampedUsed,
            windowDurationMinutes: minutes,
            resetsAt: resetDate
        )
    }

    private static func additionalWindow(in result: JSONObject, excluding mainLimitID: String?) -> UsageWindow? {
        guard let buckets = result["rateLimitsByLimitId"] as? JSONObject else { return nil }
        let candidates = buckets.keys
            .filter { $0 != mainLimitID && $0 != "codex" }
            .sorted()

        for key in candidates {
            guard let bucket = buckets[key] as? JSONObject else { continue }
            if let window = parseWindow(bucket["primary"]) ?? parseWindow(bucket["secondary"]) {
                return window
            }
        }
        return nil
    }

    private static func label(for minutes: Int) -> String {
        switch minutes {
        case 300:
            return "5h"
        case 10_080:
            return "Week"
        case let value where value % 10_080 == 0:
            return "\(value / 10_080)w"
        case let value where value % 1_440 == 0:
            return "\(value / 1_440)d"
        case let value where value % 60 == 0:
            return "\(value / 60)h"
        default:
            return "\(minutes)m"
        }
    }

    private static func number(_ value: Any?) -> Double? {
        switch value {
        case let value as NSNumber:
            return value.doubleValue
        case let value as String:
            return Double(value)
        default:
            return nil
        }
    }

    private static func integer(_ value: Any?) -> Int? {
        number(value).map(Int.init)
    }

    private static func string(_ value: Any?) -> String? {
        guard let value = value as? String, !value.isEmpty else { return nil }
        return value
    }
}
