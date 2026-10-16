// Lupy — reading and operating other apps through macOS Accessibility (the same permission
// screen readers use). Everything here acts on UI elements directly (AXPress, AXValue): the
// founder's own pointer is never moved, so it stays free while Lupy works. Keyboard input is
// used only as a fallback (paste into a field Lupy focused, or Return when the founder approved).
// All calls run on the main actor with short messaging timeouts and node/time budgets.

import AppKit
import ApplicationServices
import CoreGraphics
import LupyCore

@MainActor
enum LupyAX {
    // MARK: Permission

    /// Whether macOS lets Lupy use Accessibility. With `prompt`, macOS shows its permission dialog.
    static func isTrusted(prompt: Bool = false) -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: Attributes

    static func attribute(_ el: AXUIElement, _ name: String) -> AnyObject? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(el, name as CFString, &value) == .success else { return nil }
        return value
    }

    static func string(_ el: AXUIElement, _ name: String) -> String {
        guard let v = attribute(el, name) else { return "" }
        if let s = v as? String { return s }
        if let n = v as? NSNumber { return n.stringValue }
        return ""
    }

    static func bool(_ el: AXUIElement, _ name: String) -> Bool {
        (attribute(el, name) as? NSNumber)?.boolValue ?? false
    }

    static func children(_ el: AXUIElement) -> [AXUIElement] {
        (attribute(el, "AXChildren") as? [AXUIElement]) ?? []
    }

    /// Frame in global screen points, origin top-left of the primary screen (Accessibility's space).
    static func frame(_ el: AXUIElement) -> UIRect {
        var point = CGPoint.zero
        var size = CGSize.zero
        if let v = attribute(el, "AXPosition"), CFGetTypeID(v) == AXValueGetTypeID() {
            AXValueGetValue(v as! AXValue, .cgPoint, &point)   // swiftlint:disable:this force_cast
        }
        if let v = attribute(el, "AXSize"), CFGetTypeID(v) == AXValueGetTypeID() {
            AXValueGetValue(v as! AXValue, .cgSize, &size)   // swiftlint:disable:this force_cast
        }
        return UIRect(x: Double(point.x), y: Double(point.y), width: Double(size.width), height: Double(size.height))
    }

    static func actions(_ el: AXUIElement) -> [String] {
        var names: CFArray?
        guard AXUIElementCopyActionNames(el, &names) == .success, let list = names as? [String] else { return [] }
        return list
    }

    // MARK: Apps and windows

    static func appElement(_ app: NSRunningApplication) -> AXUIElement {
        let el = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(el, 0.6)
        // Chrome and Electron apps expose their web content only when asked to.
        AXUIElementSetAttributeValue(el, "AXEnhancedUserInterface" as CFString, true as CFTypeRef)
        AXUIElementSetAttributeValue(el, "AXManualAccessibility" as CFString, true as CFTypeRef)
        return el
    }

    static func frontmostApp() -> NSRunningApplication? { NSWorkspace.shared.frontmostApplication }

    static func focusedWindow(_ appEl: AXUIElement) -> AXUIElement? {
        if let w = attribute(appEl, "AXFocusedWindow") { return (w as! AXUIElement) }   // swiftlint:disable:this force_cast
        if let ws = attribute(appEl, "AXWindows") as? [AXUIElement] { return ws.first }
        return nil
    }

    // MARK: Snapshot

    /// The focused window of `app` as Lupy sees it: interactive and text elements with their frames.
    /// `elements[i]` in the returned table is the live element for snapshot id `i`.
    static func snapshot(of app: NSRunningApplication, maxElements: Int = 700, maxDepth: Int = 40,
                         timeBudget: TimeInterval = 2.0) -> (UISnapshot, [AXUIElement]) {
        let appEl = appElement(app)
        let name = app.localizedName ?? app.bundleIdentifier ?? "app"
        guard let window = focusedWindow(appEl) else {
            return (UISnapshot(appName: name, bundleID: app.bundleIdentifier ?? "", windowTitle: "", elements: [], truncated: false), [])
        }
        let title = string(window, "AXTitle")
        var infos: [UIElementInfo] = []
        var table: [AXUIElement] = []
        var queue: [(AXUIElement, Int)] = [(window, 0)]
        var head = 0
        var truncated = false
        let deadline = Date().addingTimeInterval(timeBudget)
        let keep: Set<String> = ["AXButton", "AXLink", "AXTextField", "AXTextArea", "AXComboBox", "AXSearchField", "AXCheckBox",
                                 "AXRadioButton", "AXPopUpButton", "AXMenuButton", "AXMenuItem", "AXTab", "AXStaticText",
                                 "AXSecureTextField", "AXDisclosureTriangle", "AXHeading", "AXCell"]
        while head < queue.count {
            if infos.count >= maxElements || Date() > deadline { truncated = true; break }
            let (el, depth) = queue[head]
            head += 1
            AXUIElementSetMessagingTimeout(el, 0.4)
            let role = string(el, "AXRole")
            let editable = bool(el, "AXEditable")
            if keep.contains(role) || editable {
                let f = frame(el)
                if !f.isEmpty {
                    let value = role == "AXSecureTextField" ? "" : TextUtil.truncate(string(el, "AXValue"), 300)
                    let info = UIElementInfo(id: infos.count, role: role, subrole: string(el, "AXSubrole"),
                                             title: TextUtil.truncate(string(el, "AXTitle"), 120),
                                             label: TextUtil.truncate(string(el, "AXDescription"), 120),
                                             value: value, placeholder: TextUtil.truncate(string(el, "AXPlaceholderValue"), 120),
                                             identifier: TextUtil.truncate(string(el, "AXIdentifier"), 80), frame: f,
                                             enabled: attribute(el, "AXEnabled") == nil ? true : bool(el, "AXEnabled"),
                                             focused: bool(el, "AXFocused"), editable: editable,
                                             actions: role == "AXStaticText" ? [] : actions(el))
                    infos.append(info)
                    table.append(el)
                }
            }
            if depth < maxDepth {
                for c in children(el) { queue.append((c, depth + 1)) }
            }
        }
        let snap = UISnapshot(appName: name, bundleID: app.bundleIdentifier ?? "", windowTitle: title, elements: infos, truncated: truncated)
        return (snap, table)
    }

    // MARK: Actions (each returns what macOS answered — the caller reads back the result)

    static func press(_ el: AXUIElement) -> AXError {
        AXUIElementPerformAction(el, "AXPress" as CFString)
    }

    static func setValue(_ el: AXUIElement, _ text: String) -> AXError {
        AXUIElementSetAttributeValue(el, "AXValue" as CFString, text as CFTypeRef)
    }

    static func focus(_ el: AXUIElement) -> AXError {
        AXUIElementSetAttributeValue(el, "AXFocused" as CFString, true as CFTypeRef)
    }

    static func value(_ el: AXUIElement) -> String { string(el, "AXValue") }

    static func describe(_ e: AXError) -> String {
        switch e {
        case .success: return "ok"
        case .apiDisabled: return "Accessibility is not allowed for Lupy"
        case .actionUnsupported: return "the element does not support that action"
        case .attributeUnsupported: return "the element cannot take text that way"
        case .cannotComplete: return "the app did not answer in time"
        case .invalidUIElement: return "the element disappeared"
        case .notImplemented: return "the app does not implement that"
        default: return "macOS refused (\(e.rawValue))"
        }
    }

    // MARK: Keyboard (fallbacks; the target app must be frontmost)

    /// Pastes `text` into the focused field with ⌘V, then restores the founder's clipboard.
    static func paste(_ text: String) {
        let pb = NSPasteboard.general
        let previous = pb.string(forType: .string)
        pb.clearContents()
        pb.setString(text, forType: .string)
        key(9, flags: .maskCommand)   // V
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            if let previous {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(previous, forType: .string)
            }
        }
    }

    static func selectAll() { key(0, flags: .maskCommand) }   // A

    static func press(key k: ControlKey) {
        switch k {
        case .returnKey: key(36)
        case .tab: key(48)
        case .escape: key(53)
        }
    }

    private static func key(_ code: CGKeyCode, flags: CGEventFlags = []) {
        let src = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: true),
              let up = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: false) else { return }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
