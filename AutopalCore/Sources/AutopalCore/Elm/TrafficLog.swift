import Foundation

/// Records raw OBD traffic in the format shared with Android and the replay test harness.
public actor TrafficLog {
    public struct Entry: Sendable, Equatable {
        public enum Kind: String, Sendable {
            case tx = "TX"
            case rx = "RX"
            case info = "INFO"
        }

        public let timestampMs: Int64
        public let kind: Kind
        public let message: String

        public init(timestampMs: Int64, kind: Kind, message: String) {
            self.timestampMs = timestampMs
            self.kind = kind
            self.message = message
        }

        public var line: String {
            "\(timestampMs) \(kind.rawValue) \(message)"
        }
    }

    public let adapter: String
    public let transport: String
    public let device: String
    public let appVersion: String

    private let timeProvider: @Sendable () -> Int64
    private var entries: [Entry] = []

    public init(
        adapter: String = "ELM327",
        transport: String = "BLE",
        device: String = "Unknown",
        appVersion: String = "0.1.0",
        timeProvider: @escaping @Sendable () -> Int64
    ) {
        self.adapter = adapter
        self.transport = transport
        self.device = device
        self.appVersion = appVersion
        self.timeProvider = timeProvider
    }

    public init<C: Clock>(
        adapter: String = "ELM327",
        transport: String = "BLE",
        device: String = "Unknown",
        appVersion: String = "0.1.0",
        baseEpochMs: Int64 = 0,
        clock: C
    ) where C.Duration == Duration {
        self.adapter = adapter
        self.transport = transport
        self.device = device
        self.appVersion = appVersion
        let start = clock.now
        self.timeProvider = {
            let elapsed = start.duration(to: clock.now)
            let seconds = elapsed.components.seconds
            let millis = elapsed.components.attoseconds / 1_000_000_000_000_000
            return baseEpochMs + (seconds * 1000) + Int64(millis)
        }
    }

    public func logTx(_ command: String) {
        let ts = timeProvider()
        entries.append(Entry(timestampMs: ts, kind: .tx, message: command.trimmingCharacters(in: .whitespacesAndNewlines)))
    }

    public func logRx(_ rawReply: String) {
        let ts = timeProvider()
        let escaped = rawReply.replacingOccurrences(of: "\r", with: "\\r")
        entries.append(Entry(timestampMs: ts, kind: .rx, message: escaped))
    }

    public func logTimeout(afterMs: Int, command: String) {
        let ts = timeProvider()
        entries.append(Entry(timestampMs: ts, kind: .info, message: "TIMEOUT after \(afterMs)ms on \(command)"))
    }

    public func logUnsolicitedDropped(_ text: String) {
        let ts = timeProvider()
        let escaped = text.replacingOccurrences(of: "\r", with: "\\r")
        entries.append(Entry(timestampMs: ts, kind: .info, message: "Unsolicited reply dropped: \(escaped)"))
    }

    public func getEntries() -> [Entry] {
        entries
    }

    public func export(isoDate: String) -> String {
        var lines: [String] = []
        lines.append("# autopal-traffic-log v1")
        lines.append("# adapter=\(adapter) transport=\(transport) device=\(device) app=\(appVersion) exported=\(isoDate)")
        for entry in entries {
            lines.append(entry.line)
        }
        return lines.joined(separator: "\n")
    }
}
