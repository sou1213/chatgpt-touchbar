import Foundation
import XCTest
@testable import ChatGPTTouchBarCore

final class RateLimitParsingTests: XCTestCase {
    func testParsesPrimaryAndSecondaryAsRemainingPercent() throws {
        let result: JSONObject = [
            "rateLimits": [
                "limitId": "codex",
                "planType": "plus",
                "primary": [
                    "usedPercent": 25,
                    "windowDurationMins": 300,
                    "resetsAt": 1_800_000_000
                ],
                "secondary": [
                    "usedPercent": 41,
                    "windowDurationMins": 10_080,
                    "resetsAt": 1_800_100_000
                ]
            ]
        ]

        let snapshot = try RateLimitParser.parse(
            result: result,
            fetchedAt: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(snapshot.primary.label, "5h")
        XCTAssertEqual(snapshot.primary.remainingPercent, 75)
        XCTAssertEqual(snapshot.secondary?.label, "Week")
        XCTAssertEqual(snapshot.secondary?.remainingPercent, 59)
        XCTAssertEqual(snapshot.planType, "plus")
    }

    func testClampsPercentages() throws {
        let result: JSONObject = [
            "rateLimits": [
                "limitId": "codex",
                "primary": [
                    "usedPercent": 140,
                    "windowDurationMins": 60,
                    "resetsAt": 0
                ]
            ]
        ]

        let snapshot = try RateLimitParser.parse(result: result)
        XCTAssertEqual(snapshot.primary.usedPercent, 100)
        XCTAssertEqual(snapshot.primary.remainingPercent, 0)
        XCTAssertNil(snapshot.primary.resetsAt)
    }

    func testUsesAdditionalBucketWhenSecondaryIsMissing() throws {
        let result: JSONObject = [
            "rateLimits": [
                "limitId": "codex",
                "primary": [
                    "usedPercent": 10,
                    "windowDurationMins": 300,
                    "resetsAt": 1_800_000_000
                ]
            ],
            "rateLimitsByLimitId": [
                "codex": ["primary": NSNull()],
                "codex_weekly": [
                    "primary": [
                        "usedPercent": 30,
                        "windowDurationMins": 10_080,
                        "resetsAt": 1_800_100_000
                    ]
                ]
            ]
        ]

        let snapshot = try RateLimitParser.parse(result: result)
        XCTAssertEqual(snapshot.secondary?.label, "Week")
        XCTAssertEqual(snapshot.secondary?.remainingPercent, 70)
    }

    func testRequestSequenceIncludesHandshakeAndRateLimitRead() {
        let methods = CodexAppServerClient.requestMessages().compactMap { $0["method"] as? String }
        XCTAssertEqual(methods, ["initialize", "initialized", "account/rateLimits/read"])
    }

    func testMatchesChatGPTWebURLs() {
        let matcher = TargetWebPageMatcher(
            allowedHosts: ["chatgpt.com", "chat.openai.com"]
        )

        XCTAssertTrue(matcher.matches("https://chatgpt.com/"))
        XCTAssertTrue(matcher.matches("https://chatgpt.com/c/123"))
        XCTAssertTrue(matcher.matches("https://www.chatgpt.com/"))
        XCTAssertTrue(matcher.matches("https://chat.openai.com/c/123"))
    }

    func testRejectsLookalikeAndNonWebURLs() {
        let matcher = TargetWebPageMatcher(allowedHosts: ["chatgpt.com"])

        XCTAssertFalse(matcher.matches("https://chatgpt.com.example.org/"))
        XCTAssertFalse(matcher.matches("https://notchatgpt.com/"))
        XCTAssertFalse(matcher.matches("file:///tmp/chatgpt.com"))
        XCTAssertFalse(matcher.matches(nil))
    }
}
