import Foundation

public struct TargetWebPageMatcher: Sendable {
    private let allowedHosts: Set<String>

    public init(allowedHosts: Set<String>) {
        self.allowedHosts = Set(allowedHosts.compactMap(Self.normalizedHost))
    }

    public func matches(_ urlString: String?) -> Bool {
        guard
            let urlString,
            let components = URLComponents(string: urlString),
            let scheme = components.scheme?.lowercased(),
            scheme == "https" || scheme == "http",
            let host = components.host.flatMap(Self.normalizedHost)
        else {
            return false
        }

        return allowedHosts.contains { allowedHost in
            host == allowedHost || host.hasSuffix(".\(allowedHost)")
        }
    }

    private static func normalizedHost(_ value: String) -> String? {
        let host = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()
        return host.isEmpty ? nil : host
    }
}
