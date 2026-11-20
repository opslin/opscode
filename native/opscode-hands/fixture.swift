// A tiny Mac app for testing opscode-hands (scripts/test-phase58.mjs). It never takes focus on launch, sits in a corner,
// and writes every change to OPSCODE_FIXTURE_LOG (one JSON line each) so a test can check that a click or a typed word
// really reached it. Not part of the product.

import AppKit

let logPath = ProcessInfo.processInfo.environment["OPSCODE_FIXTURE_LOG"] ?? NSTemporaryDirectory() + "opscode-fixture.log"
func log(_ o: [String: Any]) {
    guard let d = try? JSONSerialization.data(withJSONObject: o), let h = FileHandle(forWritingAtPath: logPath) ?? {
        FileManager.default.createFile(atPath: logPath, contents: nil); return FileHandle(forWritingAtPath: logPath)
    }() else { return }
    h.seekToEndOfFile(); h.write(d); h.write(Data("\n".utf8)); h.closeFile()
}

final class Delegate: NSObject, NSApplicationDelegate, NSTextFieldDelegate {
    var window: NSWindow!
    let count = NSTextField(labelWithString: "Count: 0")
    let name = NSTextField(string: "")
    let password = NSSecureTextField(string: "")
    let remember = NSButton(checkboxWithTitle: "Remember me", target: nil, action: nil)
    var n = 0

    func applicationDidFinishLaunching(_ note: Notification) {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        window = NSWindow(contentRect: NSRect(x: screen.maxX - 380, y: screen.minY + 20, width: 360, height: 250), styleMask: [.titled], backing: .buffered, defer: false)
        window.title = "Hands Fixture"
        let add = NSButton(title: "Add one", target: self, action: #selector(addOne))
        let buy = NSButton(title: "Buy now", target: self, action: #selector(buyNow))
        name.placeholderString = "Name"; name.setAccessibilityLabel("Name"); name.delegate = self
        password.placeholderString = "Password"; password.setAccessibilityLabel("Password")
        remember.target = self; remember.action = #selector(toggled)
        let stack = NSStackView(views: [count, add, name, password, remember, buy])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        name.widthAnchor.constraint(equalToConstant: 220).isActive = true
        password.widthAnchor.constraint(equalToConstant: 220).isActive = true
        window.contentView = stack
        // Shown without taking focus: the test checks that the person's front app stays in front.
        window.orderFrontRegardless()
        let menu = NSMenu(), appItem = NSMenuItem(), appMenu = NSMenu(title: "Fixture")
        appMenu.addItem(NSMenuItem(title: "Say Hello", action: #selector(sayHello), keyEquivalent: "h"))
        appMenu.addItem(NSMenuItem(title: "Quit Fixture", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appItem.submenu = appMenu; menu.addItem(appItem); NSApp.mainMenu = menu
        log(["ev": "ready", "pid": ProcessInfo.processInfo.processIdentifier])
    }
    @objc func addOne() { n += 1; count.stringValue = "Count: \(n)"; log(["ev": "add", "count": n]) }
    @objc func buyNow() { log(["ev": "buy"]) }
    @objc func toggled() { log(["ev": "remember", "on": remember.state == .on]) }
    @objc func sayHello() { count.stringValue = "Hello"; log(["ev": "hello"]) }
    func controlTextDidChange(_ obj: Notification) { log(["ev": "name", "value": name.stringValue]) }
    func controlTextDidEndEditing(_ obj: Notification) { log(["ev": "name", "value": name.stringValue]) }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = Delegate()
app.delegate = delegate
app.run()
