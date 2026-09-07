import AppKit
import ChatGPTTouchBarCore

final class TouchBarController: NSObject, NSTouchBarDelegate {
    private let itemIdentifier = NSTouchBarItem.Identifier("chatgpt.touchbar.usage.item")
    private let trayIdentifier = "chatgpt.touchbar.usage.tray" as NSString
    private let usageView = UsageTouchBarView(frame: NSRect(x: 0, y: 0, width: 720, height: 30))
    private var isPresented = false

    private lazy var touchBar: NSTouchBar = {
        let bar = NSTouchBar()
        bar.delegate = self
        bar.defaultItemIdentifiers = [itemIdentifier]
        bar.customizationIdentifier = NSTouchBar.CustomizationIdentifier("chatgpt.touchbar.usage")
        return bar
    }()

    func showLoading() {
        usageView.state = .loading
        presentIfNeeded()
    }

    func update(_ snapshot: UsageSnapshot) {
        usageView.state = .loaded(snapshot)
        presentIfNeeded()
    }

    func showUnavailable(_ message: String) {
        usageView.state = .unavailable(message)
        presentIfNeeded()
    }

    func hide() {
        guard isPresented else { return }
        performClassSelector("dismissSystemModalTouchBar:", first: touchBar, second: nil)
        isPresented = false
    }

    func touchBar(
        _ touchBar: NSTouchBar,
        makeItemForIdentifier identifier: NSTouchBarItem.Identifier
    ) -> NSTouchBarItem? {
        guard identifier == itemIdentifier else { return nil }
        let item = NSCustomTouchBarItem(identifier: identifier)
        item.customizationLabel = "ChatGPT Usage"
        item.view = usageView
        return item
    }

    private func presentIfNeeded() {
        guard !isPresented else { return }
        let didPerform = performClassSelector(
            "presentSystemModalTouchBar:systemTrayItemIdentifier:",
            first: touchBar,
            second: trayIdentifier
        )
        isPresented = didPerform
    }

    @discardableResult
    private func performClassSelector(
        _ selectorName: String,
        first: AnyObject,
        second: AnyObject?
    ) -> Bool {
        let host = NSTouchBar.self as AnyObject
        let selector = NSSelectorFromString(selectorName)
        guard host.responds(to: selector) else {
            NSLog("ChatGPTTouchBar: Touch Bar selector unavailable: %@", selectorName)
            return false
        }
        if let second {
            _ = host.perform(selector, with: first, with: second)
        } else {
            _ = host.perform(selector, with: first)
        }
        return true
    }
}
