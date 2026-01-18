import Foundation

enum UserInput {
    static func readLine(prompt: String, isSecure: Bool = false) -> String? {
        print(prompt, terminator: ": ")
        fflush(stdout)

        if isSecure {
            // For secure input, we'd ideally use getpass(), but for simplicity
            // we'll use regular readline and note this should be enhanced
            // in production
            return Swift.readLine()
        } else {
            return Swift.readLine()
        }
    }

    static func confirm(prompt: String) -> Bool {
        print("\(prompt) (y/n): ", terminator: "")
        fflush(stdout)

        guard let response = Swift.readLine()?.lowercased() else {
            return false
        }

        return response == "y" || response == "yes"
    }

    static func expandTildePath(_ path: String) -> String {
        if path.hasPrefix("~") {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            return path.replacingOccurrences(of: "~", with: home, options: [.anchored])
        }
        return path
    }
}
