import Foundation
import CrispCore

/// Installs and removes the display override that adds extra sizes.
/// Writing under /Library needs admin rights: each action shows the standard macOS
/// password prompt once. There is no background helper.
enum OverrideInstaller {
    enum Failure: LocalizedError {
        case cancelled
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .cancelled: return "Cancelled."
            case .failed(let message): return message
            }
        }
    }

    private static let backupDirectory = "/Library/Application Support/CrispMac/Backups"

    /// True when a CrispMac-written override exists for this monitor model.
    static func isInstalled(vendor: UInt32, model: UInt32) -> Bool {
        guard
            let data = FileManager.default.contents(atPath: DisplayOverride.path(vendor: vendor, model: model)),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return false }
        return plist[DisplayOverride.marker] as? Bool == true
    }

    static func install(for display: ExternalDisplay) throws {
        let command = try installCommand(for: display)
        try runAsAdmin(command, prompt: "CrispMac wants to add sharp sizes for \(display.name).")
    }

    static func remove(for display: ExternalDisplay) throws {
        try runAsAdmin(
            removeCommand(vendor: display.vendor, model: display.model),
            prompt: "CrispMac wants to remove the extra sizes for \(display.name)."
        )
    }

    /// Writes the override to a temporary file and returns the shell command that installs it.
    /// An existing override from another tool is backed up first.
    static func installCommand(for display: ExternalDisplay) throws -> String {
        let contents = DisplayOverride.contents(
            vendor: display.vendor,
            model: display.model,
            name: display.name,
            native: display.catalog.nativeSize
        )
        let data = try PropertyListSerialization.data(fromPropertyList: contents, format: .xml, options: 0)
        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("CrispMac-\(UUID().uuidString).plist")
        try data.write(to: temporary)

        let (directory, file, backup) = paths(vendor: display.vendor, model: display.model)
        return """
        set -e
        mkdir -p \(quoted(directory))
        if [ -f \(quoted(file)) ] && ! grep -q \(DisplayOverride.marker) \(quoted(file)) && [ ! -f \(quoted(backup)) ]; then
          mkdir -p \(quoted(backupDirectory))
          cp -p \(quoted(file)) \(quoted(backup))
        fi
        install -o root -g wheel -m 644 \(quoted(temporary.path)) \(quoted(file))
        rm -f \(quoted(temporary.path))
        """
    }

    /// Removes CrispMac's override and restores any backed-up one. Leaves other tools' files alone.
    static func removeCommand(vendor: UInt32, model: UInt32) -> String {
        let (directory, file, backup) = paths(vendor: vendor, model: model)
        return """
        set -e
        if [ -f \(quoted(file)) ] && grep -q \(DisplayOverride.marker) \(quoted(file)); then
          if [ -f \(quoted(backup)) ]; then
            install -o root -g wheel -m 644 \(quoted(backup)) \(quoted(file))
            rm -f \(quoted(backup))
          else
            rm -f \(quoted(file))
          fi
        fi
        rmdir \(quoted(directory)) 2>/dev/null || true
        """
    }

    private static func paths(vendor: UInt32, model: UInt32) -> (directory: String, file: String, backup: String) {
        let file = DisplayOverride.path(vendor: vendor, model: model)
        let directory = DisplayOverride.directory(vendor: vendor)
        let backup = "\(backupDirectory)/\((directory as NSString).lastPathComponent)-\((file as NSString).lastPathComponent)"
        return (directory, file, backup)
    }

    private static func quoted(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Runs a shell command as root behind the standard macOS password prompt.
    private static func runAsAdmin(_ command: String, prompt: String) throws {
        let source = "do shell script \(appleScriptString(command)) with prompt \(appleScriptString(prompt)) with administrator privileges"
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        guard let error else { return }
        if error[NSAppleScript.errorNumber] as? Int == -128 { throw Failure.cancelled }
        throw Failure.failed(error[NSAppleScript.errorMessage] as? String ?? "The admin command failed.")
    }

    private static func appleScriptString(_ text: String) -> String {
        "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}
