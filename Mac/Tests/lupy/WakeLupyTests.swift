import Foundation

// Lupy: "OK Lupy" wakes Lupy, and Coucou's own phrases keep working.
// Compiled with Mac/Sources/App/Voice/WakePhrase.swift by Mac/Tests/lupy/test-wake-lupy.sh.
@main
enum WakeLupyTests {
    static func expectWake(_ text: String, _ command: String) {
        let r = WakePhrase.split(text)
        precondition(r.matched, "should wake: \(text)")
        precondition(r.command == command, "command for “\(text)”: got “\(r.command)”, expected “\(command)”")
        print("✓  \(text)")
    }

    static func main() {
        expectWake("OK Lupy, open my tasks", "open my tasks")
        expectWake("Hey Lupy", "")
        expectWake("okay loopy what's next", "what's next")
        expectWake("OK Coucou, mets de la musique", "mets de la musique")
        precondition(!WakePhrase.split("I like lollipops").matched, "no wake on ordinary words")
        print("Wake phrase (Lupy) tests passed")
    }
}
