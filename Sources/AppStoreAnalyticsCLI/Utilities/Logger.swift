import Foundation

enum Logger {
    static func success(_ message: String) {
        print("[SUCCESS] \(message)")
    }

    static func info(_ message: String) {
        print("[INFO] \(message)")
    }

    static func ok(_ message: String) {
        print("[OK] \(message)")
    }

    static func error(_ message: String) {
        print("[ERROR] \(message)")
    }

    static func fail(_ message: String) {
        print("[FAIL] \(message)")
    }
}
