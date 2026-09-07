import AppKit
import ChatGPTTouchBarCore
import Foundation

let arguments = Set(CommandLine.arguments.dropFirst())

if arguments.contains("--help") {
    print("""
    ChatGPTTouchBar

      --once-json   Fetch the current Codex quota once and print JSON.
      --help        Show this help.
    """)
    exit(0)
}

if arguments.contains("--once-json") {
    guard let client = CodexAppServerClient() else {
        fputs("ChatGPTTouchBar: ChatGPT/Codex executable not found\n", stderr)
        exit(2)
    }
    do {
        let snapshot = try client.fetchUsage()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        FileHandle.standardOutput.write(try encoder.encode(snapshot))
        FileHandle.standardOutput.write(Data("\n".utf8))
        exit(0)
    } catch {
        fputs("ChatGPTTouchBar: \(error.localizedDescription)\n", stderr)
        exit(2)
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
