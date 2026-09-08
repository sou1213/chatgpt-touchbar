import AppKit
import ChatGPTTouchBarCore

final class UsageTouchBarView: NSView {
    enum State {
        case loading
        case loaded(UsageSnapshot)
        case unavailable(String)
    }

    var state: State = .loading {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 720, height: 30) }

    private static let chatGPTIcon = loadChatGPTIcon()
    private var survivalMode = UserDefaults.standard.bool(forKey: "survivalMode")
    private var logoTapTimes: [TimeInterval] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let button = NSButton(frame: NSRect(x: 4, y: 0, width: 32, height: 30))
        button.isTransparent = true
        button.title = ""
        button.target = self
        button.action = #selector(tapLogo)
        button.setAccessibilityLabel("ChatGPT: tap five times to switch theme")
        addSubview(button)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func tapLogo() {
        let now = ProcessInfo.processInfo.systemUptime
        logoTapTimes = logoTapTimes.filter { now - $0 < 3 }
        logoTapTimes.append(now)
        if logoTapTimes.count >= 5 {
            survivalMode.toggle()
            UserDefaults.standard.set(survivalMode, forKey: "survivalMode")
            logoTapTimes.removeAll()
            needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        Palette.background.setFill()
        bounds.fill()
        drawProvider()
        if survivalMode {
            drawSurvivalState()
            return
        }
        drawDivider()

        switch state {
        case .loading:
            drawMetric(window: nil, label: "5h", originX: 110)
            drawMetric(window: nil, label: "Week", originX: 318)
            drawText("loading…", in: NSRect(x: 548, y: 9, width: 150, height: 14), style: .caption)
        case .loaded(let snapshot):
            drawMetric(window: snapshot.primary, label: snapshot.primary.label, originX: 110)
            drawMetric(window: snapshot.secondary, label: snapshot.secondary?.label ?? "Week", originX: 318)
            drawReset(for: snapshot.primary)
        case .unavailable(let message):
            drawMetric(window: nil, label: "5h", originX: 110)
            drawMetric(window: nil, label: "Week", originX: 318)
            drawText(message, in: NSRect(x: 548, y: 9, width: 150, height: 14), style: .caption)
        }
    }

    private func drawProvider() {
        Palette.iconBackground.setFill()
        NSBezierPath(roundedRect: NSRect(x: 8, y: 3, width: 24, height: 24), xRadius: 12, yRadius: 12).fill()

        if survivalMode {
            PixelMeterArt.drawLogo(at: NSPoint(x: 10, y: 5))
        } else if let chatGPTIcon = Self.chatGPTIcon {
            chatGPTIcon.draw(
                in: NSRect(x: 11, y: 6, width: 18, height: 18),
                from: .zero,
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: true,
                hints: [.interpolation: NSImageInterpolation.high]
            )
        } else {
            drawText("✦", in: NSRect(x: 11, y: 5, width: 18, height: 20), style: .icon, alignment: .center)
        }

        if !survivalMode {
            drawText("ChatGPT", in: NSRect(x: 36, y: 7, width: 58, height: 16), style: .provider)
        }
    }

    private func drawSurvivalState() {
        switch state {
        case .loaded(let snapshot):
            drawSurvivalMetric(snapshot.primary, label: snapshot.primary.label, x: 44, food: false)
            drawSurvivalMetric(snapshot.secondary, label: snapshot.secondary?.label ?? "Week", x: 288, food: true)
            drawReset(for: snapshot.primary)
        case .loading, .unavailable:
            drawSurvivalMetric(nil, label: "5h", x: 44, food: false)
            drawSurvivalMetric(nil, label: "Week", x: 288, food: true)
            let message: String
            if case .unavailable(let reason) = state { message = reason } else { message = "loading…" }
            drawText(message, in: NSRect(x: 568, y: 9, width: 150, height: 14), style: .caption)
        }
    }

    private func drawSurvivalMetric(_ window: UsageWindow?, label: String, x: CGFloat, food: Bool) {
        let labelWidth: CGFloat = food ? 38 : 24
        drawText(label, in: NSRect(x: x, y: 8, width: labelWidth, height: 15), style: .metricLabel)
        let start = x + labelWidth + 4
        let halves = window.map { SurvivalMeter.halfSlots(remainingPercent: $0.remainingPercent) } ?? 0
        for slot in 0..<10 {
            PixelMeterArt.draw(food: food, halves: min(2, max(0, halves - slot * 2)),
                               at: NSPoint(x: start + CGFloat(slot * 17), y: 7), unknown: window == nil)
        }
        let value = window.map { "\(Int($0.remainingPercent.rounded()))%" } ?? "—"
        drawText(value, in: NSRect(x: start + 173, y: 7, width: 38, height: 17), style: .value)
    }

    private static func loadChatGPTIcon() -> NSImage? {
        let workspace = NSWorkspace.shared
        let applicationURLs = [
            workspace.urlForApplication(withBundleIdentifier: "com.openai.codex"),
            URL(fileURLWithPath: "/Applications/ChatGPT.app")
        ].compactMap { $0 }

        for applicationURL in applicationURLs {
            let resourceURL = applicationURL
                .appendingPathComponent("Contents/Resources/chatgptTemplate@2x.png")

            guard let source = NSImage(contentsOf: resourceURL) else { continue }
            let size = NSSize(width: 18, height: 18)
            return NSImage(size: size, flipped: false) { rect in
                Palette.primaryText.setFill()
                rect.fill()
                source.draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1)
                return true
            }
        }

        return nil
    }

    private func drawDivider() {
        Palette.track.setFill()
        NSRect(x: 100, y: 8, width: 1, height: 14).fill()
    }

    private func drawMetric(window: UsageWindow?, label: String, originX: CGFloat) {
        let labelWidth: CGFloat = label.count > 3 ? 38 : 24
        drawText(label, in: NSRect(x: originX, y: 8, width: labelWidth, height: 15), style: .metricLabel)

        let barX = originX + labelWidth + 6
        let barRect = NSRect(x: barX, y: 12, width: 118, height: 6)
        Palette.track.setFill()
        NSBezierPath(roundedRect: barRect, xRadius: 3, yRadius: 3).fill()

        if let window {
            let progress = CGFloat(window.remainingPercent / 100)
            if progress > 0 {
                healthColor(for: window.remainingPercent).setFill()
                let fillRect = NSRect(x: barX, y: 12, width: max(4, barRect.width * progress), height: 6)
                NSBezierPath(roundedRect: fillRect, xRadius: 3, yRadius: 3).fill()
            }
            drawText(
                "\(Int(window.remainingPercent.rounded()))%",
                in: NSRect(x: barRect.maxX + 9, y: 7, width: 42, height: 17),
                style: .value
            )
        } else {
            drawText("—", in: NSRect(x: barRect.maxX + 9, y: 7, width: 42, height: 17), style: .value)
        }
    }

    private func drawReset(for window: UsageWindow) {
        let resetX: CGFloat = survivalMode ? 568 : 548
        guard let resetsAt = window.resetsAt else {
            drawText("reset —", in: NSRect(x: resetX, y: 9, width: 150, height: 14), style: .caption)
            return
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        drawText(
            "\(window.label) reset \(formatter.string(from: resetsAt))",
            in: NSRect(x: resetX, y: 9, width: 150, height: 14),
            style: .caption
        )
    }

    private func healthColor(for remaining: Double) -> NSColor {
        switch remaining {
        case 50...:
            return Palette.good
        case 20..<50:
            return Palette.warning
        default:
            return Palette.critical
        }
    }

    private func drawText(
        _ text: String,
        in rect: NSRect,
        style: TextStyle,
        alignment: NSTextAlignment = .left
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byClipping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: style.font,
            .foregroundColor: style.color,
            .paragraphStyle: paragraph
        ]
        (text as NSString).draw(in: rect, withAttributes: attributes)
    }
}

private enum TextStyle {
    case provider
    case value
    case caption
    case metricLabel
    case icon

    var font: NSFont {
        switch self {
        case .provider:
            return .systemFont(ofSize: 11, weight: .semibold)
        case .value:
            return .monospacedDigitSystemFont(ofSize: 12, weight: .bold)
        case .caption:
            return .systemFont(ofSize: 9, weight: .medium)
        case .icon:
            return .systemFont(ofSize: 15, weight: .semibold)
        case .metricLabel:
            return .systemFont(ofSize: 10, weight: .medium)
        }
    }

    var color: NSColor {
        switch self {
        case .caption:
            return Palette.mutedText
        case .metricLabel:
            return Palette.metricLabelText
        default:
            return Palette.primaryText
        }
    }
}

private enum Palette {
    static let background = NSColor.black
    static let primaryText = NSColor(calibratedWhite: 0.97, alpha: 1)
    static let mutedText = NSColor(calibratedWhite: 0.57, alpha: 1)
    static let metricLabelText = NSColor(calibratedWhite: 0.68, alpha: 1)
    static let iconBackground = NSColor(calibratedWhite: 0.10, alpha: 1)
    static let track = NSColor(calibratedWhite: 0.19, alpha: 1)
    static let good = NSColor(calibratedRed: 0.22, green: 0.85, blue: 0.54, alpha: 1)
    static let warning = NSColor(calibratedRed: 0.96, green: 0.78, blue: 0.30, alpha: 1)
    static let critical = NSColor(calibratedRed: 1.00, green: 0.36, blue: 0.36, alpha: 1)
}
