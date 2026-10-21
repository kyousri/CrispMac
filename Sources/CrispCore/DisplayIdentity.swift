import Foundation

/// What the system tells us about a connected display that can identify it across reconnects.
public struct DisplayIdentity: Hashable, Sendable {
    public let uuid: String?
    public let vendor: UInt32
    public let model: UInt32
    public let serial: UInt32
    /// Changes with the port the display is plugged into.
    public let unit: UInt32

    public init(uuid: String?, vendor: UInt32, model: UInt32, serial: UInt32, unit: UInt32) {
        self.uuid = uuid
        self.vendor = vendor
        self.model = model
        self.serial = serial
        self.unit = unit
    }

    var baseKey: String {
        if let uuid, !uuid.isEmpty { return uuid }
        return "\(vendor)-\(model)-\(serial)"
    }
}

public enum DisplayKey {
    /// Stable settings keys for the connected displays, in the same order.
    ///
    /// Displays are keyed by the system's display UUID (derived from vendor, model and serial).
    /// When two connected displays would share a key, as identical monitors without a real
    /// serial can, each gets the port it is plugged into appended.
    public static func keys(for identities: [DisplayIdentity]) -> [String] {
        let counts = Dictionary(grouping: identities, by: \.baseKey).mapValues(\.count)
        return identities.map { identity in
            counts[identity.baseKey, default: 0] > 1
                ? "\(identity.baseKey)-port\(identity.unit)"
                : identity.baseKey
        }
    }
}
